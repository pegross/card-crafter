extends Node
## Autoload "Game" — the whole M0 game state.
## Time is ACTION-DRIVEN: the clock only advances when advance_time() is called
## by an action. There is no real-time _process tick. Waiting is an action.

signal changed

var day: int = 1
var minute: int = 8 * 60  ## minutes since midnight (starts 08:00)
const HEARTH_BURN_PER_HOUR := 12.0  ## the hearth's Fuel % burns down this fast
var temperature: float = 4.0  ## indoor °C — rises while the fire is lit, falls when it's out
var outdoor_temp: float = 1.0  ## outdoor °C (weather-driven later; static for now)
var current_location: String = "lordly_manor"
var card_state: Dictionary = {}  ## persistent per-card state (card id -> value) across travel/rebuilds
var location_ground: Dictionary = {}  ## per-location loose items (location id -> [card ids])
var pool_state: Dictionary = {}  ## per-location exploration reveal progress
var location_indoor: bool = true  ## is the current location sheltered (drives Warmth)
var lit_sources: Dictionary = {}  ## fire-source card id -> currently burning (fuel can sit unlit)

## Continuous needs, 0..100 (the CSTI-style sliders). Provisional values.
var meters := {
	"Calories": 82.0,
	"Hydration": 74.0,
	"Warmth": 55.0,
	"Energy": 70.0,
	"Immune": 78.0,
	"Mental": 64.0,
}

## Drain per in-game HOUR of elapsed action-time (provisional). Warmth is handled
## separately by the fire, so it is not in this table.
var _drain := {
	"Calories": 4.5,
	"Hydration": 5.0,
	"Energy": 4.0,
	"Immune": 0.2,
	"Mental": 0.3,
}

var log_lines: Array[String] = []

## Conditions: hidden gauges (0..100) that bend a slider's drain and surface as a chip
## at breakpoints. Stage 0 = latent (no chip). enter/exit give hysteresis; mult scales _drain.
const CONDITIONS := {
	"gut_bug": {
		"decay_per_hour": 8.0,
		"stages": [
			{"name": "", "enter": 0.0, "exit": 0.0, "tell": "", "mult": {}},
			{"name": "Queasy", "enter": 25.0, "exit": 15.0, "tell": "Your stomach tightens and gurgles.", "mult": {"Hydration": 1.2}},
			{"name": "Loose Stool", "enter": 50.0, "exit": 38.0, "tell": "It runs through you, fast and foul.", "mult": {"Hydration": 1.6}},
			{"name": "Dysentery", "enter": 78.0, "exit": 62.0, "tell": "Blood in it now. You are in real trouble.", "mult": {"Hydration": 2.2}},
		],
	},
}

var conditions: Dictionary = {}   ## id -> hidden gauge 0..100
var cond_stage: Dictionary = {}   ## id -> current surfaced stage index
var cond_prev: Dictionary = {}    ## id -> gauge at the START of this action (trajectory basis)
var cond_last: Dictionary = {}    ## id -> gauge at the END of the previous action
var cond_cause: Dictionary = {}   ## id -> cause stamp, for the obituary
var health_log: Array[String] = []  ## persistent, cause-stamped condition history
var dead: bool = false
var obituary: String = ""

func is_fire_lit() -> bool:
	return is_lit("hearth")

func is_lit(id: String) -> bool:
	return bool(lit_sources.get(id, false)) and card_state.get(id, 0.0) > 0.0

func advance_time(mins: int) -> void:
	var hours := float(mins) / 60.0
	# trajectory basis: each gauge as of the END of the previous action (before any new insult)
	for id in conditions:
		cond_prev[id] = cond_last.get(id, 0.0)
	# active conditions compose a multiplier onto the drain (illness dehydrates you faster)
	var cmult := _condition_multipliers()
	for k in _drain:
		meters[k] = clampf(meters[k] - _drain[k] * hours * float(cmult.get(k, 1.0)), 0.0, 100.0)
	_tick_conditions(hours)
	# every LIT fire source burns its fuel down; unlit fuel just sits. Out of fuel = out.
	for src_id in lit_sources.keys():
		if lit_sources[src_id]:
			var fuel: float = maxf(0.0, card_state.get(src_id, 0.0) - HEARTH_BURN_PER_HOUR * hours)
			card_state[src_id] = fuel
			if fuel <= 0.0:
				lit_sources[src_id] = false
	var target := 19.0 if is_fire_lit() else 2.0
	temperature = lerpf(temperature, target, clampf(hours * 0.6, 0.0, 1.0))
	# your Warmth follows the AMBIENT temperature where you actually are:
	# indoors = the room (fire-warmed); outdoors = the weather. Below ~10C you lose heat.
	var ambient := temperature if location_indoor else outdoor_temp
	meters["Warmth"] = clampf(meters["Warmth"] + (ambient - 10.0) * 0.6 * hours, 0.0, 100.0)
	minute += mins
	while minute >= 1440:
		minute -= 1440
		day += 1
	_check_collapse()
	for id in conditions:
		cond_last[id] = conditions[id]
	changed.emit()

func add_condition(id: String, amt: float, cause: String = "") -> void:
	if not CONDITIONS.has(id):
		return
	conditions[id] = clampf(conditions.get(id, 0.0) + amt, 0.0, 100.0)
	if cause != "":
		cond_cause[id] = "%s, Day %d %02d:%02d" % [cause, day, minute / 60, minute % 60]

func _condition_multipliers() -> Dictionary:
	var m: Dictionary = {}
	for id in conditions:
		var st: int = cond_stage.get(id, 0)
		var mult: Dictionary = CONDITIONS[id]["stages"][st].get("mult", {})
		for k in mult:
			m[k] = float(m.get(k, 1.0)) * float(mult[k])
	return m

func _tick_conditions(hours: float) -> void:
	for id in conditions.keys():
		conditions[id] = maxf(0.0, conditions[id] - float(CONDITIONS[id]["decay_per_hour"]) * hours)
		_eval_stage(id)

func _eval_stage(id: String) -> void:
	var stages: Array = CONDITIONS[id]["stages"]
	var cur: int = cond_stage.get(id, 0)
	var g: float = conditions[id]
	while cur + 1 < stages.size() and g >= float(stages[cur + 1]["enter"]):
		cur += 1
		var s: Dictionary = stages[cur]
		if str(s.get("tell", "")) != "":
			add_log(str(s["tell"]))
		var stamp: String = (" (%s)" % cond_cause[id]) if cond_cause.has(id) else ""
		health_log.append("Day %d %02d:%02d — %s%s" % [day, minute / 60, minute % 60, str(s["name"]), stamp])
	while cur > 0 and g < float(stages[cur]["exit"]):
		cur -= 1
		if cur == 0:
			add_log("The cramps pass. Your gut settles.")
	cond_stage[id] = cur

func cond_trajectory(id: String) -> String:
	var now: float = conditions.get(id, 0.0)
	var prev: float = cond_prev.get(id, now)
	if now > prev + 0.05:
		return "rising"
	if now < prev - 0.05:
		return "easing"
	return "steady"

func _check_collapse() -> void:
	if dead:
		return
	for k in meters:
		if meters[k] <= 0.0:
			dead = true
			var ob := _build_obituary(k)
			obituary = ob
			log_lines.append("%02d:%02d  %s" % [minute / 60, minute % 60, ob])
			while log_lines.size() > 6:
				log_lines.pop_front()
			health_log.append(ob)
			return

func _build_obituary(meter: String) -> String:
	var death: String = {"Hydration": "dehydration", "Calories": "starvation", "Warmth": "the cold", "Energy": "sheer exhaustion", "Immune": "sickness", "Mental": "despair"}.get(meter, meter)
	var worst := ""
	var worst_stage := 0
	for id in conditions:
		var st: int = cond_stage.get(id, 0)
		if st > worst_stage:
			worst_stage = st
			worst = id
	var s := "You sink down and do not get up. It was %s." % death
	if worst != "":
		s += " Following %s" % str(CONDITIONS[worst]["stages"][worst_stage]["name"])
		if cond_cause.has(worst):
			s += " (%s)" % cond_cause[worst]
		s += "."
	return s

func reset() -> void:
	day = 1
	minute = 8 * 60
	temperature = 4.0
	outdoor_temp = 1.0
	current_location = "lordly_manor"
	location_indoor = true
	card_state = {}
	location_ground = {}
	pool_state = {}
	lit_sources = {}
	meters = {"Calories": 82.0, "Hydration": 74.0, "Warmth": 55.0, "Energy": 70.0, "Immune": 78.0, "Mental": 64.0}
	conditions = {}
	cond_stage = {}
	cond_prev = {}
	cond_last = {}
	cond_cause = {}
	health_log = []
	log_lines = []
	dead = false
	obituary = ""

func modify(m: String, amount: float) -> void:
	if meters.has(m):
		meters[m] = clampf(meters[m] + amount, 0.0, 100.0)

func add_log(line: String) -> void:
	log_lines.append("%02d:%02d  %s" % [minute / 60, minute % 60, line])
	while log_lines.size() > 6:
		log_lines.pop_front()
	changed.emit()

func time_string() -> String:
	return "Day %d  ·  %02d:%02d" % [day, minute / 60, minute % 60]

func temp_string() -> String:
	return "%d°C" % int(round(temperature))

func temp_word(t: float) -> String:
	if t <= 2.0:
		return "freezing"
	elif t < 8.0:
		return "cold"
	elif t < 14.0:
		return "chilly"
	elif t < 22.0:
		return "comfortable"
	return "warm"
