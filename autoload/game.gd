extends Node
## Autoload "Game" — the whole M0 game state.
## Time is ACTION-DRIVEN: the clock only advances when advance_time() is called
## by an action. There is no real-time _process tick. Waiting is an action.

signal changed

var day: int = 1
var minute: int = 8 * 60  ## minutes since midnight (starts 08:00)
const HEARTH_BURN_PER_HOUR := 12.0  ## the hearth's Fuel % burns down this fast
const FATIGUE_ACCRUAL := 4.5   ## sleep-debt gained per waking hour (scales with duration)
const FATIGUE_SLEEP_CLEAR := 14.0  ## sleep-debt cleared per sleeping hour * sleep_quality
var temperature: float = 14.0  ## indoor °C — rises while the fire is lit, falls when it's out
var outdoor_temp: float = 1.0  ## outdoor °C (weather + season drive it)
## SEASONS — start in Autumn so the first winter is on its way. Cyclical: Autumn/Winter/Spring/Summer.
const SEASONS := ["Autumn", "Winter", "Spring", "Summer"]
const SEASON_LENGTH := 6  ## in-game days per season (tunable)
const SEASON_TEMP := [0.0, -8.0, -2.0, 8.0]  ## °C offset onto the weather-derived outdoor temp, per season
var _last_season: int = 0  ## for detecting season transitions (telegraph logs)
var _season_warned: bool = false  ## one-shot "next season is coming" telegraph, reset each season
var current_location: String = "lordly_manor"
var card_state: Dictionary = {}  ## persistent per-card state (card id -> value) across travel/rebuilds
var location_ground: Dictionary = {}  ## per-location loose items (location id -> [card ids])
var pool_state: Dictionary = {}  ## per-location exploration reveal progress
var location_indoor: bool = true  ## is the current location sheltered (drives Warmth)
var lit_sources: Dictionary = {}  ## fire-source card id -> currently burning (fuel can sit unlit)
var weather: String = "overcast"  ## clear / overcast / rain
var wet: float = 0.0  ## 0..100; rises outdoors in rain, dries indoors/by fire
var force_sleep: bool = false  ## set when Energy hits 0 -> main triggers a collapse-sleep

## Continuous needs, 0..100 (the CSTI-style sliders). Provisional values.
var meters := {
	"Calories": 82.0,
	"Hydration": 74.0,
	"Warmth": 70.0,
	"Energy": 85.0,
	"Immune": 78.0,
	"Mental": 64.0,
}

## Drain per in-game HOUR of elapsed action-time (provisional). Warmth is handled
## separately by the fire, so it is not in this table.
var _drain := {
	"Calories": 4.5,
	"Hydration": 5.0,
	"Energy": 2.5,
	"Immune": 0.2,
	"Mental": 0.3,
}

var log_lines: Array[String] = []

## NO need is instantly lethal at 0 now — deprivation spawns a growing CONDITION that kills:
## low Hydration -> Dehydration, low Warmth -> Hypothermia, low Calories -> Weight (starvation).
## Energy -> forced sleep; Immune/Mental are modifiers.
const LETHAL_METERS := []

## Conditions: hidden gauges (0..100) that bend a slider's drain and surface as a chip
## at breakpoints. Stage 0 = latent (no chip). enter/exit give hysteresis; mult scales _drain.
const CONDITIONS := {
	"gut_bug": {
		"decay_per_hour": 8.0,
		"incubation_hours": 6.0,
		"title": "Gut Illness",
		"desc": "A waterborne gut infection. Unboiled water is the usual cause.",
		"stages": [
			{"name": "", "enter": 0.0, "exit": 0.0, "tell": "", "mult": {}, "decay": 1.5},
			{"name": "Queasy", "enter": 18.0, "exit": 12.0, "tell": "Your stomach tightens and gurgles.", "mult": {"Hydration": 1.2}, "decay": 1.2},
			{"name": "Loose Stool", "enter": 50.0, "exit": 38.0, "tell": "It runs through you, fast and foul.", "mult": {"Hydration": 1.6}, "decay": 0.9},
			{"name": "Dysentery", "enter": 78.0, "exit": 62.0, "tell": "Blood in it now. You are in real trouble.", "mult": {"Hydration": 2.2}, "decay": 0.6},
		],
	},
	"hypo": {
		"decay_per_hour": 0.0,
		"title": "Hypothermia",
		"desc": "Your core is losing heat faster than your body can replace it.",
		"stages": [
			{"name": "", "enter": 0.0, "exit": 0.0, "tell": "", "mult": {}, "decay": 0.0},
			{"name": "Shivering", "enter": 25.0, "exit": 15.0, "tell": "You can't stop shivering.", "mult": {}, "decay": 0.0},
			{"name": "Frostnip", "enter": 55.0, "exit": 42.0, "tell": "Your fingers have gone white and stiff.", "mult": {}, "decay": 0.0},
			{"name": "Deep Cold", "enter": 82.0, "exit": 68.0, "tell": "You feel almost warm now. That is the cold lying to you.", "mult": {}, "decay": 0.0, "lethal": true, "death": "the cold"},
		],
	},
	"wound": {
		"decay_per_hour": 1.2,
		"title": "Wound",
		"desc": "Torn flesh from a fight. Bind it before it turns bad.",
		"stages": [
			{"name": "", "enter": 0.0, "exit": 0.0, "tell": "", "mult": {}, "decay": 1.2},
			{"name": "Scratched", "enter": 15.0, "exit": 8.0, "tell": "Cuts and scrapes, stinging but shallow.", "mult": {}, "decay": 1.2},
			{"name": "Bleeding", "enter": 45.0, "exit": 34.0, "tell": "You are bleeding, and it will not stop on its own.", "mult": {"Immune": 1.3}, "decay": 0.5},
			{"name": "Grievous", "enter": 80.0, "exit": 66.0, "tell": "Deep wounds. You are losing more blood than you can spare.", "mult": {"Immune": 1.6}, "decay": 0.3, "lethal": true, "death": "your wounds"},
		],
	},
	"dehydration": {
		"decay_per_hour": 0.0,
		"title": "Dehydration",
		"desc": "Your body is running dry. You need water, and soon.",
		"stages": [
			{"name": "", "enter": 0.0, "exit": 0.0, "tell": "", "mult": {}, "decay": 0.0},
			{"name": "Parched", "enter": 18.0, "exit": 10.0, "tell": "Cracked lips, a pounding skull. You need water badly.", "mult": {"Mental": 1.3}, "decay": 0.0},
			{"name": "Delirious", "enter": 50.0, "exit": 38.0, "tell": "Your thoughts swim. The thirst is all there is.", "mult": {"Mental": 1.5}, "decay": 0.0},
			{"name": "Failing", "enter": 82.0, "exit": 68.0, "tell": "Your body is shutting down for want of water.", "mult": {"Mental": 1.6}, "decay": 0.0, "lethal": true, "death": "thirst"},
		],
	},
	"infection": {
		"decay_per_hour": 0.0,
		"incubation_hours": 8.0,
		"title": "Infection",
		"desc": "A bite gone bad. Heat and swelling, and it is spreading.",
		"stages": [
			{"name": "", "enter": 0.0, "exit": 0.0, "tell": "", "mult": {}, "decay": 0.0},
			{"name": "Feverish", "enter": 20.0, "exit": 12.0, "tell": "The bite is hot and swollen, and a fever creeps in.", "mult": {"Immune": 1.3}, "decay": 0.0},
			{"name": "Septic", "enter": 55.0, "exit": 42.0, "tell": "Red lines climb from the wound. This is turning bad.", "mult": {"Immune": 1.6, "Mental": 1.3}, "decay": 0.0},
			{"name": "Blood Poisoning", "enter": 82.0, "exit": 68.0, "tell": "Fever burns through you and your thoughts scatter. It is in your blood now.", "mult": {"Immune": 1.8}, "decay": 0.0, "lethal": true, "death": "the infection"},
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
var cond_pending: Array = []  ## incubating doses: {id, amt, ready (abs minute), cause}
var fatigue: float = 0.0  ## sleep-debt 0..100; accrues awake, cleared only by sleep; caps Energy
var mental_driver: String = ""  ## biggest current Mental drain source (for tooltip + obituary)
var weight: float = 55.0  ## body mass 0..100 (~50 ideal); Calorie surplus feeds it, deficit burns it
var weight_warned: bool = false  ## one-shot "wasting away" tell latch

func is_fire_lit() -> bool:
	return is_lit("hearth")

func is_lit(id: String) -> bool:
	return bool(lit_sources.get(id, false)) and card_state.get(id, 0.0) > 0.0

func energy_cap() -> float:
	return 100.0 - 0.6 * fatigue

func hhmm() -> String:
	@warning_ignore("integer_division")
	return "%02d:%02d" % [minute / 60, minute % 60]

func sleep_quality() -> float:
	var q: float = 0.35 + 0.45 * float(meters["Warmth"]) / 100.0 + 0.20 * float(meters["Mental"]) / 100.0
	if meters["Calories"] < 20.0 or meters["Hydration"] < 20.0:
		q = minf(q, 0.5)
	return clampf(q, 0.3, 1.0)

func weight_toll() -> float:
	# overweight makes physical effort cost more (actions run longer); healthy weight = no toll
	return 1.0 + maxf(0.0, weight - 78.0) * 0.02

func weather_line() -> String:
	var w: String = {"clear": "Clear and cold.", "overcast": "Overcast, still.", "rain": "Cold rain, steady."}.get(weather, "Overcast, still.")
	if wet > 40.0:
		w += " You are soaked."
	elif wet > 10.0:
		w += " You are damp."
	return w

func season() -> int:
	return int(float(day - 1) / float(SEASON_LENGTH)) % 4

func season_name() -> String:
	return SEASONS[season()]

func season_offset() -> float:
	return SEASON_TEMP[season()]

func days_left_in_season() -> int:
	return SEASON_LENGTH - ((day - 1) % SEASON_LENGTH)

func _season_arrival_line(s: int) -> String:
	match s:
		1: return "A hard frost overnight, and it did not lift. Winter has closed in."
		2: return "The snow is going soft and grey at the edges. Spring, at last."
		3: return "The air has turned dry and warm. High summer now."
		_: return "The leaves are down and the nights draw in. Autumn."

func _season_warning_line(next_s: int) -> String:
	match next_s:
		1: return "The light is thin and the cold has teeth in the mornings now. Winter is close. Lay in wood and food while you still can."
		2: return "The worst of the cold feels like it is starting to break. Spring is not far off."
		3: return "The days are stretching long and warm. High summer is coming on."
		_: return "There is a chill creeping into the mornings now. The warm season is ending."

func advance_time(mins: int, sleeping := false) -> void:
	var hours := float(mins) / 60.0
	# mature any incubating doses that come due within this step: full fixed dose, drink-time cause kept (earliest wins)
	var target_abs: int = day * 1440 + minute + mins
	var still: Array = []
	for dose in cond_pending:
		if int(dose["ready"]) <= target_abs:
			conditions[dose["id"]] = clampf(conditions.get(dose["id"], 0.0) + float(dose["amt"]), 0.0, 100.0)
			if not cond_cause.has(dose["id"]):
				cond_cause[dose["id"]] = str(dose["cause"])
		else:
			still.append(dose)
	cond_pending = still
	# trajectory basis: each gauge as of the END of the previous action (before any new insult)
	for id in conditions:
		cond_prev[id] = cond_last.get(id, 0.0)
	# active conditions compose a multiplier onto the drain (illness dehydrates you faster)
	var cmult := _condition_multipliers()
	for k in _drain:
		var mk := float(cmult.get(k, 1.0))
		if sleeping and k == "Hydration":
			mk = 1.0  # illness dehydration suspended while prone
		meters[k] = clampf(meters[k] - _drain[k] * hours * mk, 0.0, 100.0)
	_tick_conditions(hours)
	_apply_influences(hours)
	# every LIT fire source burns its fuel down; unlit fuel just sits. Out of fuel = out.
	for src_id in lit_sources.keys():
		if lit_sources[src_id]:
			var fuel: float = maxf(0.0, card_state.get(src_id, 0.0) - HEARTH_BURN_PER_HOUR * hours)
			card_state[src_id] = fuel
			if fuel <= 0.0:
				lit_sources[src_id] = false
	# WEATHER drifts over hours and sets the outdoor temperature
	if randf() < 0.05 * hours:
		var roll := randf()
		var s := season()
		if s == 1:  # Winter: colder and wetter (sleet/snow), rarely a clear break
			weather = "rain" if roll < 0.45 else ("clear" if roll > 0.9 else "overcast")
		elif s == 3:  # Summer: mostly dry and clear
			weather = "rain" if roll < 0.12 else ("clear" if roll > 0.5 else "overcast")
		else:  # Autumn / Spring: the mixed baseline
			weather = "rain" if roll < 0.35 else ("clear" if roll > 0.75 else "overcast")
	outdoor_temp = {"clear": 4.0, "overcast": 1.0, "rain": -1.0}.get(weather, 1.0) + season_offset()
	# WET: soaked by rain outdoors; dries indoors or by a fire
	if weather == "rain" and not location_indoor:
		wet = clampf(wet + 30.0 * hours, 0.0, 100.0)
	else:
		wet = maxf(0.0, wet - (25.0 if (location_indoor or is_fire_lit()) else 8.0) * hours)
	# the rain barrel catches the sky wherever it sits, so rain slowly refills it
	if weather == "rain":
		card_state["rain_barrel"] = minf(100.0, float(card_state.get("rain_barrel", 100.0)) + 8.0 * hours)
	# an unlit shelter can't beat the season: it blocks ~60% of the seasonal swing, so a deep
	# winter still creeps in (a lit fire overrides it). A stopgap until per-location insulation lands.
	var target := 19.0 if is_fire_lit() else (7.0 + season_offset() * 0.4)
	temperature = lerpf(temperature, target, clampf(hours * 0.6, 0.0, 1.0))
	# your Warmth follows the AMBIENT temperature where you actually are:
	# indoors = the room (fire-warmed); outdoors = the weather. Below ~10C you lose heat.
	var ambient := temperature if location_indoor else outdoor_temp
	var warm_delta := (ambient - 10.0) * 0.6 * hours
	if warm_delta < 0.0:
		warm_delta *= (1.0 + wet / 100.0)  # being wet steepens the chill
	meters["Warmth"] = clampf(meters["Warmth"] + warm_delta, 0.0, 100.0)
	# FATIGUE: cleared only by sleep (raising the Energy ceiling FIRST), accrues while awake
	if sleeping:
		var f0 := fatigue
		fatigue = maxf(0.0, fatigue - FATIGUE_SLEEP_CLEAR * sleep_quality() * hours)
		# Energy recovered is tied to fatigue ACTUALLY cleared (kills the nap/oversleep farm)
		meters["Energy"] = clampf(meters["Energy"] + (f0 - fatigue) * 1.4, 0.0, energy_cap())
	else:
		fatigue = clampf(fatigue + FATIGUE_ACCRUAL * hours, 0.0, 100.0)
	meters["Energy"] = minf(meters["Energy"], energy_cap())
	# WEIGHT: the slow body-mass reservoir — Calorie surplus feeds it, a deficit burns it
	weight = clampf(weight + (meters["Calories"] - 50.0) * 0.025 * hours, 0.0, 100.0)
	if weight < 20.0 and not weight_warned:
		weight_warned = true
		add_log("Your clothes hang loose on you now. You are wasting away.")
	elif weight > 26.0 and weight_warned:
		weight_warned = false
	minute += mins
	while minute >= 1440:
		minute -= 1440
		day += 1
		var s := season()
		if s != _last_season:
			_last_season = s
			_season_warned = false
			add_log(_season_arrival_line(s))
		elif not _season_warned and days_left_in_season() <= 1:
			_season_warned = true
			add_log(_season_warning_line((s + 1) % 4))
	_check_collapse()
	for id in conditions:
		cond_last[id] = conditions[id]
	changed.emit()

func add_condition(id: String, amt: float, cause: String = "") -> void:
	if not CONDITIONS.has(id):
		return
	var stamp := ""
	if cause != "":
		stamp = "%s, Day %d %s" % [cause, day, hhmm()]
	var inc: float = float(CONDITIONS[id].get("incubation_hours", 0.0))
	if inc > 0.0:
		cond_pending.append({"id": id, "amt": amt, "ready": (day * 1440 + minute) + int(inc * 60.0), "cause": stamp})
	else:
		conditions[id] = clampf(conditions.get(id, 0.0) + amt, 0.0, 100.0)
		if stamp != "" and not cond_cause.has(id):
			cond_cause[id] = stamp

func cure_condition(id: String, amt: float) -> void:
	# meds directly reduce an ACTIVE condition gauge (amt is negative); pending incubation is untouched
	if conditions.has(id):
		conditions[id] = clampf(conditions[id] + amt, 0.0, 100.0)

func take_wound(amount: float) -> void:
	conditions["wound"] = clampf(conditions.get("wound", 0.0) + amount, 0.0, 100.0)
	# combat-only: surface the stage and register a lethal wound the instant it lands,
	# before _tick_conditions can decay the gauge back under the Grievous threshold
	_eval_stage("wound")
	_check_collapse()

func _condition_multipliers() -> Dictionary:
	var m: Dictionary = {}
	for id in conditions:
		var st: int = cond_stage.get(id, 0)
		var mult: Dictionary = CONDITIONS[id]["stages"][st].get("mult", {})
		for k in mult:
			m[k] = float(m.get(k, 1.0)) * float(mult[k])
	for k in m:
		m[k] = minf(float(m[k]), 1.8)  # frozen cap: composed drain mult per meter <= 1.8
	return m

func _tick_conditions(hours: float) -> void:
	for id in conditions.keys():
		var st: int = cond_stage.get(id, 0)
		var decay: float = float(CONDITIONS[id]["stages"][st].get("decay", CONDITIONS[id].get("decay_per_hour", 8.0)))
		var rmod := 1.0
		if meters["Hydration"] > 60.0:
			rmod *= 1.4
		if meters["Immune"] < 40.0:
			rmod *= 0.6
		conditions[id] = maxf(0.0, conditions[id] - decay * rmod * hours)
		if conditions[id] <= 0.0:
			cond_cause.erase(id)
		_eval_stage(id)

func _apply_influences(hours: float) -> void:
	# additive cross-influences (base drains already applied). First edges -> Mental.
	var contrib := {}
	if fatigue > 20.0:
		contrib["fatigue"] = (fatigue / 100.0) * 3.0 * hours
	if cond_stage.get("gut_bug", 0) >= 3:
		contrib["Dysentery"] = 2.0 * hours
	var total := 0.0
	var top := ""
	var top_amt := 0.0
	for src in contrib:
		total += float(contrib[src])
		if float(contrib[src]) > top_amt:
			top_amt = float(contrib[src])
			top = src
	if total > 0.0:
		meters["Mental"] = clampf(meters["Mental"] - total, 0.0, 100.0)
	mental_driver = top
	# HYPOTHERMIA: low Warmth drives it up (wet accelerates it); getting warm lets it recede.
	# This is the ONLY cold-death path now — Warmth is no longer instantly lethal.
	var h: float = float(conditions.get("hypo", 0.0))
	if meters["Warmth"] < 35.0:
		h += (35.0 - meters["Warmth"]) * (1.0 + wet / 100.0) * 0.3 * hours
	else:
		h -= 8.0 * hours
	conditions["hypo"] = clampf(h, 0.0, 100.0)
	_eval_stage("hypo")  # re-evaluate now so severity + lethal check are current this tick
	var hst: int = cond_stage.get("hypo", 0)
	if hst >= 1:
		meters["Energy"] = clampf(meters["Energy"] - float(hst) * 1.5 * hours, 0.0, 100.0)
	# DEHYDRATION: low Hydration drives it up; drinking (raising Hydration) lets it recede.
	# Thirst is a growing condition now, never an instant Hydration-zero death.
	var dh: float = float(conditions.get("dehydration", 0.0))
	if meters["Hydration"] < 25.0:
		dh += (25.0 - meters["Hydration"]) * 0.5 * hours
	else:
		dh -= 10.0 * hours
	conditions["dehydration"] = clampf(dh, 0.0, 100.0)
	_eval_stage("dehydration")
	# INFECTION festers and spreads on its own until antibiotics clear it
	if conditions.get("infection", 0.0) > 0.0:
		conditions["infection"] = clampf(float(conditions["infection"]) + 1.5 * hours, 0.0, 100.0)
		_eval_stage("infection")

func need_desc(m: String) -> String:
	match m:
		"Calories":
			return "Fuel in the tank. Spent as you act,\nrefilled by eating. Hitting empty won't\nkill you; it burns your Weight instead."
		"Hydration":
			return "Body water. Drops faster when you're ill\nor working hard. Let it run low and\ndehydration takes hold."
		"Warmth":
			return "Body heat. Cold, wet, and time outdoors\nbleed it away; fire and shelter bring it back.\nLet it fall far and hypothermia sets in."
		"Energy":
			return "What you have left in you. Spent by action,\nand capped by your sleep-debt. At zero you\ncollapse into sleep where you stand."
		"Immune":
			return "Your resistance to illness. When it's low,\ninfections take hold and worsen faster.\nNot deadly on its own."
		"Mental":
			return "Your grip. Frayed by exhaustion, sickness\nand cold; steadied by rest, warmth and food.\nWon't kill you, but it colours everything."
		"Sleep-debt":
			return "How tired you are, built up over the\nwaking day. The higher it climbs, the lower\nyour Energy can rise. Only sleep clears it."
		"Weight":
			return "Your body mass, the slow reserve beneath\nhunger. Eat well and it builds; go hungry\nand it burns. Bottom out and you starve;\nrun heavy and hard work costs more."
		_:
			return ""

func need_influences(m: String) -> String:
	var notes: Array = []
	if float(_condition_multipliers().get(m, 1.0)) > 1.05:
		notes.append("illness is draining it faster")
	match m:
		"Mental":
			if fatigue > 40.0:
				notes.append("exhaustion is wearing on you")
			if cond_stage.get("gut_bug", 0) >= 3:
				notes.append("the sickness drags at you")
		"Energy":
			if fatigue > 15.0:
				notes.append("sleep-debt is holding the ceiling down")
		"Warmth":
			var ambient: float = temperature if location_indoor else outdoor_temp
			if ambient < 10.0:
				notes.append("the cold is pulling it down" + (", worse while you're wet" if wet > 40.0 else ""))
			elif is_fire_lit() and location_indoor:
				notes.append("the fire is holding it up")
	if notes.is_empty():
		return ""
	return "Right now: " + ", ".join(PackedStringArray(notes)) + "."

func need_tooltip(m: String) -> String:
	var d := need_desc(m)
	var inf := need_influences(m)
	return (d + "\n\n" + inf) if inf != "" else d

func condition_desc(id: String) -> String:
	var cond: Dictionary = CONDITIONS.get(id, {})
	var parts: Array = []
	if str(cond.get("desc", "")) != "":
		parts.append(str(cond["desc"]))
	var st: int = cond_stage.get(id, 0)
	if st > 0:
		var stg: Dictionary = cond["stages"][st]
		if str(stg.get("tell", "")) != "":
			parts.append(str(stg["tell"]))
		var fx: Array = []
		for k in stg.get("mult", {}):
			if float(stg["mult"][k]) > 1.0:
				fx.append("%s drains ×%.1f" % [k, minf(float(stg["mult"][k]), 1.8)])
		if id == "gut_bug" and st >= 3:
			fx.append("Mental −2/hr")
		if id == "hypo" and st >= 1:
			fx.append("Energy −%.1f/hr" % (float(st) * 1.5))
		if stg.get("lethal", false):
			fx.append("can turn fatal")
		if not fx.is_empty():
			parts.append("%s: %s." % [str(stg["name"]), ", ".join(PackedStringArray(fx))])
	return "\n".join(PackedStringArray(parts))

func drain_breakdown(m: String) -> String:
	var parts := []
	if _drain.has(m):
		parts.append("base %.1f/hr" % _drain[m])
	var cm := _condition_multipliers()
	if cm.has(m):
		parts.append("illness x%.2f" % float(cm[m]))
	if m == "Mental":
		if fatigue > 20.0:
			parts.append("fatigue -%.1f/hr" % ((fatigue / 100.0) * 3.0))
		if cond_stage.get("gut_bug", 0) >= 3:
			parts.append("dysentery -2.0/hr")
	if m == "Energy":
		parts.append("ceiling %d%% (sleep-debt)" % int(energy_cap()))
	if m == "Warmth":
		var ambient := temperature if location_indoor else outdoor_temp
		var rate := (ambient - 10.0) * 0.6
		if rate >= 0.0:
			parts.append("warming +%.1f/hr (%d°C)" % [rate, int(round(ambient))])
		else:
			parts.append("cooling %.1f/hr (%d°C)" % [rate, int(round(ambient))])
	return "\n".join(PackedStringArray(parts))

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
		health_log.append("Day %d %s — %s%s" % [day, hhmm(), str(s["name"]), stamp])
	while cur > 0 and g < float(stages[cur]["exit"]):
		cur -= 1
		if cur == 0:
			var msg := "The cramps pass. Your gut settles."
			if id == "hypo":
				msg = "The shivering fades; warmth creeps back."
			elif id == "wound":
				msg = "The bleeding has stopped. The wound is closing."
			elif id == "infection":
				msg = "The fever breaks and the swelling goes down."
			elif id == "dehydration":
				msg = "The thirst loosens its grip."
			add_log(msg)
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
	# a lethal condition stage (e.g. hypothermia Deep Cold) kills with its own cause
	for id in conditions:
		var cst: int = cond_stage.get(id, 0)
		if cst > 0 and CONDITIONS[id]["stages"][cst].get("lethal", false):
			dead = true
			obituary = _cond_obituary(id, cst)
			log_lines.append("%s  %s" % [hhmm(), obituary])
			while log_lines.size() > 6:
				log_lines.pop_front()
			health_log.append(obituary)
			return
	# only certain needs are lethal at 0
	for k in LETHAL_METERS:
		if meters[k] <= 0.0:
			dead = true
			obituary = _build_obituary(k)
			log_lines.append("%s  %s" % [hhmm(), obituary])
			while log_lines.size() > 6:
				log_lines.pop_front()
			health_log.append(obituary)
			return
	# wasting away: weight is the true starvation death (Calories at 0 only starts the burn)
	if weight <= 0.0:
		dead = true
		obituary = "You have wasted down to nothing. It was starvation."
		log_lines.append("%s  %s" % [hhmm(), obituary])
		while log_lines.size() > 6:
			log_lines.pop_front()
		health_log.append(obituary)
		return
	# Energy at 0 forces a collapse-sleep, not death
	if meters["Energy"] <= 0.0:
		force_sleep = true

func _cond_obituary(id: String, stage: int) -> String:
	var s: Dictionary = CONDITIONS[id]["stages"][stage]
	var lead: String = "You stop shivering, and then you stop." if id == "hypo" else "You go down, and you do not get up."
	return "%s It was %s. (%s)" % [lead, str(s.get("death", "it")), str(s["name"])]

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
	if meter == "Mental" and mental_driver != "":
		s += " Worn down by %s." % mental_driver
	return s

func reset() -> void:
	day = 1
	minute = 8 * 60
	temperature = 4.0
	outdoor_temp = 1.0
	_last_season = 0
	_season_warned = false
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
	cond_pending = []
	cond_cause = {}
	health_log = []
	log_lines = []
	dead = false
	obituary = ""
	fatigue = 0.0
	mental_driver = ""
	weather = "overcast"
	wet = 0.0
	force_sleep = false
	weight = 55.0
	weight_warned = false

func modify(m: String, amount: float) -> void:
	if meters.has(m):
		meters[m] = clampf(meters[m] + amount, 0.0, 100.0)

func add_log(line: String) -> void:
	log_lines.append("%s  %s" % [hhmm(), line])
	while log_lines.size() > 6:
		log_lines.pop_front()
	changed.emit()

func log_quiet(line: String) -> void:
	# append to the day log WITHOUT emitting changed (for batching, e.g. per-turn combat lines)
	log_lines.append("%s  %s" % [hhmm(), line])
	while log_lines.size() > 6:
		log_lines.pop_front()

func time_string() -> String:
	return "Day %d  ·  %s  ·  %s" % [day, season_name(), hhmm()]

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
