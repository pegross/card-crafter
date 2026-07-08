extends Node
## Autoload "Game" — the whole M0 game state.
## Time is ACTION-DRIVEN: the clock only advances when advance_time() is called
## by an action. There is no real-time _process tick. Waiting is an action.

signal changed

var rng := RandomNumberGenerator.new()  ## seedable sim RNG; tests set Game.rng.seed for reproducibility

var day: int = 1
var minute: int = 8 * 60  ## minutes since midnight (starts 08:00)
const HEARTH_BURN_PER_HOUR := 12.0  ## the hearth's Fuel % burns down this fast
const SNARE_CATCH_PER_HOUR := 7.0  ## a set snare fills this much per in-world hour; a catch comes at 100 (~14h)
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
var current_location: String = "the_grounds"  ## you start on the grounds; the manor is found by exploring
var card_state: Dictionary = {}  ## persistent per-card state (card id -> value) across travel/rebuilds
var location_ground: Dictionary = {}  ## per-location loose items (location id -> [card ids])
var pool_state: Dictionary = {}  ## per-location exploration reveal progress
var traps: Dictionary = {}  ## per-location set snares: location id -> catch progress 0..100
var location_indoor: bool = false  ## is the current location sheltered (drives Warmth); start outdoors
var lit_sources: Dictionary = {}  ## fire-source card id -> currently burning (fuel can sit unlit)
var weather: String = "overcast"  ## clear / overcast / rain
var wet: float = 0.0  ## 0..100; rises outdoors in rain, dries indoors/by fire
var force_sleep: bool = false  ## set when Energy hits 0 -> main triggers a collapse-sleep

## EQUIPMENT — a single worn slot. The card id of the garment on your back, "" = nothing worn.
## Worn clothing has no loose card while it is on you; taking it off re-spawns the card.
var worn: String = ""

## RENEWABLE STOCKS — a time-based logistic stock per location+resource, grown on the clock in
## _tick_stocks() (called from advance_time). Each resource regrows toward its K with a seed floor
## (so a barren spot still recovers) and a per-season pace. main.gd surfaces ground cards up to
## stock_count() and calls harvest_stock() whenever something is taken. Overharvest/collapse: later.
## "seasons" is indexed by season(): 0 Autumn, 1 Winter, 2 Spring, 3 Summer.
const RESOURCE_REGEN := {
	"firewood": {"r": 0.25, "seed": 0.06, "seasons": [1.0, 1.0, 1.0, 1.0]},
	"tinder": {"r": 0.25, "seed": 0.06, "seasons": [1.0, 1.0, 1.0, 1.0]},
	"forage_food": {"r": 0.30, "seed": 0.03, "seasons": [0.5, 0.0, 1.0, 1.2]},
	"herbs": {"r": 0.20, "seed": 0.02, "seasons": [0.5, 0.1, 1.0, 1.0]},
}
var stocks := {}  ## loc -> { id -> {"S": float, "K": float} }; cleared in reset()
var loc_indoor := {}  ## loc -> bool; set at boot by main.gd, drives which stocks a windfall/rain reaches

## EVENT DIRECTOR — deterministic, telegraphed "worse times".
var scheduled_events: Array = []    ## upcoming instances: {id, day, telegraphed, fired, waves?}
var active_events: Array = []       ## live effects: {id, ends_day, temp_drop}
var _schedule_seeded_year: int = 0  ## highest year already seeded (endless generator)
## RADIO — the telegraph channel and the title.
var radio_powered: bool = true          ## mains power; fails permanently at grid_failure
var radio_last_broadcast_day: int = 0   ## last day a broadcast was drawn (repeat-listen = static)
## SIEGE bridge — set by the Director, consumed by main.gd like force_sleep.
var pending_siege: int = 0  ## zombie waves queued for the shelter (0 = none)

## SKILLS (0..100, learn-by-doing) and background RESEARCH (progresses in waking time).
var skills := {"woodworking": 0.0, "cooking": 0.0, "crafting": 0.0, "tailoring": 0.0}
const SKILL_LABEL := {"woodworking": "Woodworking", "cooking": "Cooking", "crafting": "Crafting", "tailoring": "Tailoring"}
const SKILL_ACTIVE := ["woodworking", "cooking"]  ## skills that have XP sources today (always shown)
var researched: Dictionary = {}     ## project id -> true once complete
var current_research: String = ""   ## the project being worked out, or ""
var research_progress: float = 0.0  ## waking hours accrued on the current project
## Research UNLOCKS a recipe/build; it never applies an effect directly. The unlocked
## thing (a shuttered window, a workbench) is what carries the benefit once you build it.
const RESEARCH := {
	"r_shutters": {
		"label": "Window shutters", "skill": "woodworking", "level": 25, "hours": 24.0,
		"desc": "Work out how to build proper timber shutters for the manor's broken windows.",
		"unlocks": "manor_windows",
		"done_log": "You have the measure of it now. You can build shutters for the windows."
	},
	"r_workbench": {
		"label": "Workbench", "skill": "woodworking", "level": 45, "hours": 36.0,
		"desc": "Plan out a solid workbench, the heart of any proper workshop.",
		"unlocks": "manor_workbench",
		"done_log": "You have a workbench worked out. You can build one now."
	},
	"r_trapping": {
		"label": "Snare trapping", "skill": "woodworking", "level": 20, "hours": 18.0,
		"desc": "Work out how to bend and set a snare that will take small game while you are away.",
		"done_log": "You have the trick of the snare now. You can make one when you have the wood."
	},
	"r_tailoring": {
		"label": "Tailoring a coat", "skill": "tailoring", "level": 20, "hours": 18.0,
		"desc": "Work out how to cut and stitch cured hide into a coat that will hold the warmth in.",
		"done_log": "You have the pattern of it in your head now. You can tailor a coat when you have the hide."
	}
}

## BASE-BUILDING: phased construction projects attached to a shelter. Each phase needs
## materials and up to ~2h of work; a project can have several phases. See main.gd for the
## buildsite UI and material consumption. builds = completed ids; build_progress = phase idx.
var builds: Dictionary = {}          ## project id -> true once fully built
var build_progress: Dictionary = {}  ## project id -> next phase index to do
const CONSTRUCTION := {
	"manor_door": {
		"shelter": "lordly_manor",
		"label": "Repair the front door",
		"broken_desc": "The front door hangs off one hinge, the latch smashed. It keeps out neither the cold nor anything that might come looking.",
		"done_label": "Braced door",
		"done_desc": "Back on solid hinges with a stout crossbrace, the gaps packed tight. It holds the warmth in and the weather out.",
		"done_log": "The door is sound again. The manor feels a shade warmer already.",
		"phases": [
			{"label": "Rehang the door", "materials": {"firewood": 2}, "work_mins": 90,
			 "log": "You lift the door back onto fresh pins and plane it to sit square in the frame."},
			{"label": "Brace and seal it", "materials": {"firewood": 1}, "work_mins": 60,
			 "log": "You fit a crossbrace across the back and pack the gaps. It shuts with a solid thud."}
		]
	},
	"manor_windows": {
		"shelter": "lordly_manor",
		"requires_research": "r_shutters",
		"label": "Board and shutter the windows",
		"broken_desc": "Two of the front windows are just jagged holes stuffed with rag. The cold pours straight through them.",
		"done_label": "Shuttered windows",
		"done_desc": "Stout timber shutters, closed and barred against the weather.",
		"done_log": "The windows are shuttered tight. The draught through the front rooms is gone.",
		"phases": [
			{"label": "Cut the boards", "materials": {"firewood": 2}, "work_mins": 90,
			 "log": "You saw and plane the timber down into shutter boards."},
			{"label": "Hang and bar the shutters", "materials": {"firewood": 2}, "work_mins": 90,
			 "log": "You hang the shutters and fit a bar across each. They close out the cold."}
		]
	},
	"manor_workbench": {
		"shelter": "lordly_manor",
		"requires_research": "r_workbench",
		"label": "Build a workbench",
		"broken_desc": "There is a clear stretch of the back wall that would take a proper workbench.",
		"done_label": "Workbench",
		"done_desc": "A heavy, solid workbench. A place to make and mend properly.",
		"done_log": "The workbench is built. It will open up sturdier work down the line.",
		"phases": [
			{"label": "Build the frame", "materials": {"firewood": 3}, "work_mins": 120,
			 "log": "You joint and peg the heavy frame together."},
			{"label": "Fit the top", "materials": {"firewood": 2}, "work_mins": 90,
			 "log": "You lay and fix the thick top. It does not so much as wobble."}
		]
	}
}

## CRAFTING: single-step recipes that make an ITEM card (parallel to CONSTRUCTION, which is
## phased and site-bound). A craft consumes materials, costs one session of work, and yields a
## card to hand or ground. tab groups them in the craft hub; requires_research gates them, exactly
## like construction. The made item is what carries any benefit; the craft only produces it.
const CRAFTS := {
	"craft_tinder": {
		"tab": "tools",
		"label": "Split kindling",
		"materials": {"firewood": 1},
		"work_mins": 15,
		"produces": "tinder",
		"skill": ["crafting", 2.0],
		"desc": "Baton a length of firewood down into a fistful of dry kindling.",
		"log": "You split the firewood down into a heap of fine, dry kindling."
	},
	"craft_mallet": {
		"tab": "tools",
		"requires_research": "r_workbench",
		"label": "Carve a wooden mallet",
		"materials": {"firewood": 2},
		"work_mins": 45,
		"produces": "wooden_mallet",
		"skill": ["crafting", 3.0],
		"desc": "Shape a heavy mallet from a seasoned billet. Rough, but it will drive a stake or knock a joint home.",
		"log": "You shape and smooth the mallet. It sits heavy and true in your hand."
	},
	"craft_snare": {
		"tab": "tools",
		"requires_research": "r_trapping",
		"label": "Bend a snare",
		"materials": {"firewood": 1},
		"work_mins": 30,
		"produces": "snare",
		"skill": ["crafting", 3.0],
		"desc": "Split a stave down, bend it under tension, and rig a running noose to snap shut on whatever trips it.",
		"log": "You bend the stave, notch the trigger, and set the noose. A patient little trap."
	},
	"craft_hide_coat": {
		"tab": "tailoring",
		"requires_research": "r_tailoring",
		"label": "Tailor a hide coat",
		"materials": {"hide": 2},
		"work_mins": 60,
		"produces": "hide_coat",
		"skill": ["tailoring", 4.0],
		"desc": "Cut and stitch two cured hides into a rough coat. Heavy and stiff, but it turns the wind and keeps the warmth in.",
		"log": "You cut, fit, and stitch the hides into a coat. It sits heavy on your shoulders, and warm."
	}
}

## EVENT DIRECTOR data. Events are mechanical here; all prose lives in EVENT_FLAVOR and is
## picked at runtime. category drives the radio: "weather" forecasts, "threat" warns, "power" = soft clock.
const EVENTS := {
	"cold_snap":    {"category": "weather", "telegraph_days": 2, "duration_days": 3, "temp_drop": -7.0, "winter_bonus": -4.0},
	"drought":      {"category": "weather", "telegraph_days": 3, "duration_days": 5, "stream_drain_per_hour": 10.0},
	"horde_surge":  {"category": "threat",  "telegraph_days": 2, "duration_days": 1, "base_waves": 1},
	"grid_failure": {"category": "power",   "telegraph_days": 3, "duration_days": 0},
	"gale":         {"category": "weather", "telegraph_days": 1, "duration_days": 0},
}
## The authored year-0 spine, by absolute day. First Winter = days 7-12, first Summer = 19-24.
const EVENT_SPINE := [
	{"id": "gale",         "day": 4},   ## early first autumn: a windstorm throws down deadwood
	{"id": "grid_failure", "day": 8},   ## early first winter: the power goes for good
	{"id": "cold_snap",    "day": 9},   ## first winter bites
	{"id": "horde_surge",  "day": 11},  ## the first siege, a fixed day of the first winter
	{"id": "drought",      "day": 21},  ## first summer: the stream slows, the barrel dries
]
const EVENT_FLAVOR := {
	"cold_snap_telegraph": [
		"The light goes thin and hard, and the air tastes of iron.",
		"A stillness settles. The cold is coming, and the sky has already gone quiet for it."],
	"cold_snap_onset": [
		"The cold arrives without a sound and takes the warmth out of everything.",
		"Frost creeps up the inside of the glass. The world has locked shut."],
	"cold_snap_end": [
		"The cold loosens its grip. You can feel your hands again.",
		"The freeze breaks at last, and the air softens by a degree."],
	"cold_snap_radio": [
		"a front, moving down out of the north, colder air behind it, expect...",
		"hard freeze warning for, the name is lost, overnight and into the."],
	"drought_telegraph": [
		"The sky has been bare for days and the ground is going pale and cracked.",
		"No dew this morning, no damp in the air. The wet is draining out of the land."],
	"drought_onset": [
		"The last of the puddles are gone. Everything is dust and dry wind.",
		"The dry has set in properly now. The taps sigh and give nothing."],
	"drought_end": [
		"The air turns heavy and damp again. Rain cannot be far off.",
		"The dry spell breaks. You smell wet earth for the first time in days."],
	"drought_radio": [
		"a dry spell holding, no cloud, the reader sounds tired, unbroken for some days.",
		"clear and dry through the week, the automated tone repeats it, dry, dry."],
	"horde_surge_telegraph": [
		"The birds go up all at once, far off, and do not come back down.",
		"A sound reaches you, low and many and shapeless, and it is getting nearer.",
		"The quiet before them is the worst part. You can feel it coming through the floor."],
	"horde_surge_onset": [
		"They are here. The dark outside is full of slow, shuffling movement.",
		"The roamers have found the house. There is no outrunning this many."],
	"horde_surge_radio": [
		"movement reported along the, the road name breaks up, do not travel by night.",
		"a large group pushing through the low ground, keep off the streets, keep quiet, keep.",
		"numbers on the move to the, the direction is swallowed, seek a hard door."],
	"horde_surge_away": [
		"You come back to claw marks gouged in the door and the frame sprung. Something worked hard to get in while you were gone."],
	"grid_failure_telegraph": [
		"The lights dip, hold, dip again. The power will not last much longer.",
		"A brownout, then another. Whatever keeps the grid alive is losing the fight."],
	"grid_failure_onset": [
		"The power dies for good. A hum you had long stopped hearing is gone, and the house goes truly quiet."],
	"grid_failure_radio": [
		"rolling blackouts across the, the grid failing region by, expect to lose power in your."],
	"gale_telegraph": [
		"The wind is getting up, worrying at the eaves, and the trees have begun to thrash.",
		"A hard wind is building. The air has an edge to it and the whole house creaks and shifts."],
	"gale_onset": [
		"The gale tore through in the night and brought branches down all across the grounds.",
		"By morning the wind has spent itself, leaving the open ground littered with fallen wood."],
}
const RADIO_STATIC := [
	"Static, and under it nothing. You listen anyway, the way you listen for rain.",
	"A flat carrier hum, steady as a held breath. No one is speaking behind it.",
	"For a moment the hiss thins, and you lean in. Then it closes over again.",
	"A scrap of an old station ident, three notes looping, worn to a ghost of themselves.",
	"The channel that carried a voice yesterday is only white noise now.",
	"The signal surges, fades, surges. Weather, or someone very far away, or nothing.",
	"Somewhere in the wash of it you think you hear a word. You know you did not.",
	"The dial finds the same grey sea at every number. You turn it slowly all the same.",
	"A dead hum, warm and empty. It sounds almost like company.",
	"Silence with a shape to it, patient on the air, waiting for a voice that does not come.",
]
const RADIO_DEAD := [
	"The set is dark and silent. No power reaches it now.",
	"You thumb the dial out of old habit. Nothing answers. The grid is gone, and the radio with it.",
]
const STREAM_DRY_LINE := "The stream has slowed to a dirty trickle, barely enough to wet a hand."
const SIEGE := {
	"horde_arrives": [
		"They come up out of the grey all at once and press against the walls.",
		"The dark outside fills with them. Every window has a shape leaning on it."],
	"testing_the_door": [
		"Hands find the door and worry at it, patient, endless.",
		"A slow drumming starts on the shutters, then another, then too many to count."],
	"holding": [
		"The barricade groans and holds. You press your back to it and wait."],
	"straining": [
		"The wood shrieks against the frame. A nail works loose and rings on the floor."],
	"breach": [
		"The door gives with a crack, and the cold and the reek of them come pouring in."],
	"repelled": [
		"The pressure eases. The sounds thin out and drift off into the dark, and you are still here."],
	"open_ground": [
		"They are on you in the open. There is nowhere to put your back."],
}

## Continuous needs, 0..100 (the CSTI-style sliders). Provisional values.
var meters := {
	"Satiation": 65.0,
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
	"Satiation": 4.0,
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

func _ready() -> void:
	rng.randomize()  # normal play stays varied; tests overwrite rng.seed after reset()
	_seed_schedule()  # lay down the deterministic event spine for a fresh game (reset() re-seeds)

func is_fire_lit() -> bool:
	return is_lit("hearth")

func is_lit(id: String) -> bool:
	return bool(lit_sources.get(id, false)) and card_state.get(id, 0.0) > 0.0

func energy_cap() -> float:
	return 100.0 - 0.6 * fatigue

func hhmm() -> String:
	@warning_ignore("integer_division")
	return "%02d:%02d" % [minute / 60, minute % 60]

func abs_minute() -> int:
	return day * 1440 + minute

## Freshness of a perishable, from its absolute spoil-minute. 0 fresh, 1 turning (last 4h), 2 spoiled.
func spoil_stage(spoil_at: int) -> int:
	if spoil_at < 0:
		return 0
	var now := abs_minute()
	if now >= spoil_at:
		return 2
	if now >= spoil_at - 240:
		return 1
	return 0

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

func skill_level(id: String) -> int:
	return int(skills.get(id, 0.0))

func gain_skill(id: String, amt: float) -> void:
	if not skills.has(id) or amt <= 0.0:
		return
	var cur: float = skills[id]
	skills[id] = clampf(cur + amt * (1.0 - cur / 130.0), 0.0, 100.0)  # gains taper toward mastery

func wood_speed() -> float:
	return 1.0 - float(skill_level("woodworking")) * 0.003  # up to ~30% faster felling/splitting at mastery

func warmth_insulation() -> float:
	# Multiplier applied to Warmth LOSS while a garment is worn: < 1.0 means you shed less heat.
	# A hide coat cuts roughly a third of the chill. Tunable, and testable via make_sim.
	return 0.65

func skill_desc(id: String) -> String:
	match id:
		"woodworking": return "Your hand with axe and saw. Higher woodworking makes felling and splitting quicker and opens up sturdier things to build."
		"cooking": return "Your feel for food, fire and herbs. Higher cooking opens up better ways to prepare what you gather."
		"crafting": return "Your knack for making and mending gear. It will matter more as you start building the place up."
		"tailoring": return "Your work with needle, thread and hide. It will matter once there are clothes and coverings to make."
		_: return ""

func research_available(id: String) -> bool:
	if researched.has(id) or not RESEARCH.has(id):
		return false
	var r: Dictionary = RESEARCH[id]
	return skill_level(str(r["skill"])) >= int(r["level"])

func research_hours(id: String) -> float:
	return float(RESEARCH[id]["hours"]) if RESEARCH.has(id) else 0.0

func research_fraction() -> float:
	if current_research == "":
		return 0.0
	var need := research_hours(current_research)
	return clampf(research_progress / need, 0.0, 1.0) if need > 0.0 else 0.0

func start_research(id: String) -> bool:
	if current_research != "" or not research_available(id):
		return false
	current_research = id
	research_progress = 0.0
	add_log("You start puzzling out %s in what spare time you can find." % str(RESEARCH[id]["label"]).to_lower())
	return true

func _complete_research(id: String) -> void:
	researched[id] = true
	current_research = ""
	research_progress = 0.0
	add_log(str(RESEARCH[id].get("done_log", "You have it worked out at last.")))

func construction_for(loc: String) -> Array:
	# only projects for this shelter whose unlocking research (if any) is done
	var out: Array = []
	for id in CONSTRUCTION:
		if str(CONSTRUCTION[id]["shelter"]) != loc:
			continue
		var req := str(CONSTRUCTION[id].get("requires_research", ""))
		if req == "" or researched.has(req):
			out.append(id)
	return out

func crafts_for(tab: String) -> Array:
	# craftables in this hub tab whose unlocking research (if any) is done
	var out: Array = []
	for id in CRAFTS:
		if str(CRAFTS[id]["tab"]) != tab:
			continue
		var req := str(CRAFTS[id].get("requires_research", ""))
		if req == "" or researched.has(req):
			out.append(id)
	return out

# ---------- TRAPPING ----------
# A snare set on open ground fills toward a catch over in-world time (see advance_time). The
# outdoor gate lives in the UI; here every set snare simply progresses, so it stays headless-testable.
func place_snare(loc: String) -> void:
	traps[loc] = 0.0

func snare_ready(loc: String) -> bool:
	return float(traps.get(loc, 0.0)) >= 100.0

func collect_snare(loc: String) -> Array:
	# a sprung snare gives up small game (meat + a hide) and resets to catch again; else nothing
	if snare_ready(loc):
		traps[loc] = 0.0
		return ["rat_meat", "hide"]
	return []

# ---------- RENEWABLE STOCKS ----------
# A logistic stock per location+resource that regrows on the clock (see _tick_stocks, called from
# advance_time). main.gd surfaces ground cards up to stock_count() and calls harvest_stock() when
# something is taken. Registration is idempotent, so a restart never wipes a stock mid-game.
func register_stock(loc: String, id: String, K: int) -> void:
	if not stocks.has(loc):
		stocks[loc] = {}
	if not stocks[loc].has(id):
		stocks[loc][id] = {"S": float(K) * 0.5, "K": float(K)}  # start half-stocked so a spot is not barren

func set_location_indoor(loc: String, indoor: bool) -> void:
	# main.gd registers each location's shelter status at boot so events (gale, rain) know which
	# stocks sit under open sky. Game itself has no map, only this flag.
	loc_indoor[loc] = indoor

func stock_count(loc: String, id: String) -> int:
	if stocks.has(loc) and stocks[loc].has(id):
		return int(floor(float(stocks[loc][id]["S"])))
	return 0

func harvest_stock(loc: String, id: String, n: int = 1) -> void:
	if stocks.has(loc) and stocks[loc].has(id):
		stocks[loc][id]["S"] = maxf(0.0, float(stocks[loc][id]["S"]) - float(n))

func add_stock(loc: String, id: String, amt: float) -> void:
	# used by events later; harmless no-op on an unregistered slot
	if stocks.has(loc) and stocks[loc].has(id):
		var K: float = float(stocks[loc][id]["K"])
		stocks[loc][id]["S"] = clampf(float(stocks[loc][id]["S"]) + amt, 0.0, K)

func _tick_stocks(hours: float) -> void:
	var s := season()
	var drought := _event_active("drought")  # the dry kills new forage/herb growth; wood is unaffected
	for loc in stocks:
		for id in stocks[loc]:
			var K: float = float(stocks[loc][id]["K"])
			if K <= 0.0:
				continue
			var p: Dictionary = RESOURCE_REGEN.get(id, {"r": 0.2, "seed": 0.04, "seasons": [1, 1, 1, 1]})
			var mult: float = float(p["seasons"][s])
			if drought and (id == "forage_food" or id == "herbs"):
				mult = 0.0
			var S: float = float(stocks[loc][id]["S"])
			S += (float(p["seed"]) + float(p["r"]) * S * (1.0 - S / K)) * mult * hours
			stocks[loc][id]["S"] = clampf(S, 0.0, K)

func build_done(id: String) -> bool:
	return builds.has(id)

func build_phase_idx(id: String) -> int:
	return int(build_progress.get(id, 0))

func build_phase_count(id: String) -> int:
	return (CONSTRUCTION[id]["phases"] as Array).size() if CONSTRUCTION.has(id) else 0

func build_current_phase(id: String) -> Dictionary:
	if build_done(id) or not CONSTRUCTION.has(id):
		return {}
	var phases: Array = CONSTRUCTION[id]["phases"]
	var idx := build_phase_idx(id)
	return phases[idx] if idx < phases.size() else {}

func complete_build_phase(id: String) -> void:
	# called after the caller has consumed materials + spent the work time
	var idx := build_phase_idx(id) + 1
	build_progress[id] = idx
	if idx >= build_phase_count(id):
		builds[id] = true
		add_log(str(CONSTRUCTION[id].get("done_log", "The work is finished.")))

func shelter_damp() -> float:
	# how much of the seasonal swing an unlit shelter blocks (lower = tighter). Built sealing stacks;
	# the benefit lives on the BUILDS, not on research. Global for now (only the manor exists);
	# make per-location when multiple shelters land.
	var d := 0.4
	if builds.has("manor_door"):
		d -= 0.08
	if builds.has("manor_windows"):
		d -= 0.12
	return maxf(0.15, d)

func is_shelter(loc: String) -> bool:
	# a defensible base = any location construction targets (only the manor for now)
	for id in CONSTRUCTION:
		if str(CONSTRUCTION[id]["shelter"]) == loc:
			return true
	return false

func shelter_defense(loc: String) -> float:
	# 0.0 = open ground. Higher = fewer of the horde break in. The benefit lives on the
	# BUILDS, exactly like shelter_damp(): a braced door and shuttered windows are what save you.
	if not is_shelter(loc):
		return 0.0
	var d := 0.20                        # bare walls and a roof: some cover even unimproved
	if builds.has("manor_door"):
		d += 0.24                        # the braced door is the main thing between you and them
	if builds.has("manor_windows"):
		d += 0.22                        # shuttered windows close the other way in
	return minf(d, 0.90)                 # never total: a big enough surge always gets someone through

# ---------- COMBAT / SIEGE MATH (pure, uses rng — headlessly testable) ----------
const PLAYER_STRIKE := 10.0  ## unarmed base damage per Strike (varies: miss/glance/solid/good)

func strike_roll() -> Dictionary:
	# combat is NOT deterministic — a swing can miss, glance, land solid, or land hard
	var r := rng.randf()
	if r < 0.10:
		return {"dmg": 0.0, "q": "miss"}
	elif r < 0.32:
		return {"dmg": PLAYER_STRIKE * 0.6, "q": "glance"}
	elif r < 0.84:
		return {"dmg": PLAYER_STRIKE, "q": "solid"}
	return {"dmg": PLAYER_STRIKE * 1.6, "q": "good"}

func enemy_damage_roll(base: float) -> float:
	return base * rng.randf_range(0.6, 1.4)

func infection_roll(base: float) -> float:
	return base * rng.randf_range(0.7, 1.3)

func siege_breaches(waves: int, loc: String) -> int:
	# deterministic: more waves and less defense means more of them break in
	return int(round(float(waves) * (1.0 - shelter_defense(loc))))

# ---------- EVENT DIRECTOR ----------
const RADIO_THREAT_HORIZON := 4   ## days ahead the radio can warn of a coming horde
const RADIO_WEATHER_HORIZON := 3  ## days ahead the radio forecasts weather / the grid dying

func _pick(arr: Array) -> String:
	return str(arr[rng.randi() % arr.size()]) if not arr.is_empty() else ""

func _event_line(id: String, phase: String) -> String:
	return _pick(EVENT_FLAVOR.get(id + "_" + phase, []))

func _seed_schedule() -> void:
	scheduled_events.clear()
	for e in EVENT_SPINE:
		scheduled_events.append({"id": str(e["id"]), "day": int(e["day"]), "telegraphed": false, "fired": false})
	_schedule_seeded_year = 1

func _extend_schedule(year: int) -> void:
	# endless sandbox: deterministically append a winter surge + snap and a summer drought per year
	if year <= _schedule_seeded_year:
		return
	var autumn_start := year * 4 * SEASON_LENGTH + 1
	var winter_start := year * 4 * SEASON_LENGTH + SEASON_LENGTH + 1
	var summer_start := year * 4 * SEASON_LENGTH + 3 * SEASON_LENGTH + 1
	scheduled_events.append({"id": "gale",        "day": autumn_start + 3, "telegraphed": false, "fired": false})
	scheduled_events.append({"id": "cold_snap",   "day": winter_start + 2, "telegraphed": false, "fired": false})
	scheduled_events.append({"id": "horde_surge", "day": winter_start + 4, "telegraphed": false, "fired": false, "waves": 1 + year})
	scheduled_events.append({"id": "drought",     "day": summer_start + 2, "telegraphed": false, "fired": false})
	_schedule_seeded_year = year

func _event_active(id: String) -> bool:
	for a in active_events:
		if str(a["id"]) == id:
			return true
	return false

func _event_temp_offset() -> float:
	var t := 0.0
	for a in active_events:
		t += float(a.get("temp_drop", 0.0))
	return t

func _director_tick() -> void:
	_extend_schedule(int(float(day - 1) / float(4 * SEASON_LENGTH)) + 1)
	# end any active event whose window has closed
	var still: Array = []
	for a in active_events:
		if day >= int(a["ends_day"]):
			var el := _event_line(str(a["id"]), "end")
			if el != "":
				add_log(el)
		else:
			still.append(a)
	active_events = still
	# telegraph and fire scheduled events
	for ev in scheduled_events:
		if bool(ev["fired"]):
			continue
		var def: Dictionary = EVENTS[str(ev["id"])]
		var due: int = int(ev["day"])
		if not bool(ev["telegraphed"]) and day >= due - int(def["telegraph_days"]):
			ev["telegraphed"] = true
			var tl := _event_line(str(ev["id"]), "telegraph")
			if tl != "":
				add_log(tl)
		if day >= due:
			ev["fired"] = true
			_fire_event(ev)

func _fire_event(ev: Dictionary) -> void:
	var id: String = str(ev["id"])
	var def: Dictionary = EVENTS[id]
	var ol := _event_line(id, "onset")
	if ol != "":
		add_log(ol)
	match id:
		"cold_snap":
			var drop: float = float(def["temp_drop"])
			if season() == 1:
				drop += float(def["winter_bonus"])  # harsher in winter
			active_events.append({"id": id, "ends_day": day + int(def["duration_days"]), "temp_drop": drop})
		"drought":
			active_events.append({"id": id, "ends_day": day + int(def["duration_days"]), "temp_drop": 0.0})
		"horde_surge":
			pending_siege = int(ev.get("waves", def["base_waves"]))  # main.gd consumes this
		"grid_failure":
			radio_powered = false  # permanent dead air from here on
		"gale":
			# a windstorm throws deadwood down across the open ground: a firewood + tinder windfall,
			# but only outdoors (a roofed location catches nothing)
			for loc in stocks:
				if bool(loc_indoor.get(loc, false)):
					continue
				add_stock(loc, "firewood", 3.0)
				add_stock(loc, "tinder", 1.5)

func radio_listen() -> String:
	# power gone -> permanent dead air. This IS the title, and the soft clock.
	if not radio_powered:
		return _pick(RADIO_DEAD)
	# one broadcast draw per day; listening again the same day is only static
	if radio_last_broadcast_day == day:
		return _pick(RADIO_STATIC)
	var b := _radio_broadcast_for_today()
	if b == "":
		return _pick(RADIO_STATIC)  # the usual case: mostly dead air
	radio_last_broadcast_day = day
	return b

func _radio_broadcast_for_today() -> String:
	# DETERMINISTIC: broadcasts come only from the Director's scheduled events. Threats
	# outrank weather; within a tier the nearest event wins.
	var best := ""
	var best_lead := 9999
	var best_is_threat := false
	for ev in scheduled_events:
		if bool(ev["fired"]):
			continue
		var def: Dictionary = EVENTS[str(ev["id"])]
		var lead: int = int(ev["day"]) - day
		if lead <= 0:
			continue
		var cat := str(def["category"])
		var horizon: int = RADIO_THREAT_HORIZON if cat == "threat" else RADIO_WEATHER_HORIZON
		if lead > horizon:
			continue
		var is_threat := cat == "threat"
		if best == "" or (is_threat and not best_is_threat) or (is_threat == best_is_threat and lead < best_lead):
			best = _event_line(str(ev["id"]), "radio")
			best_lead = lead
			best_is_threat = is_threat
	return best

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
	# CALORIES: the slow reservoir under Satiation. A full belly rebuilds it; an empty one burns it.
	meters["Calories"] = clampf(meters["Calories"] + (meters["Satiation"] - 45.0) * 0.03 * hours, 0.0, 100.0)
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
	if rng.randf() < 0.05 * hours:
		var roll := rng.randf()
		var s := season()
		if s == 1:  # Winter: colder and wetter (sleet/snow), rarely a clear break
			weather = "rain" if roll < 0.45 else ("clear" if roll > 0.9 else "overcast")
		elif s == 3:  # Summer: mostly dry and clear
			weather = "rain" if roll < 0.12 else ("clear" if roll > 0.5 else "overcast")
		else:  # Autumn / Spring: the mixed baseline
			weather = "rain" if roll < 0.35 else ("clear" if roll > 0.75 else "overcast")
	if _event_active("drought"):
		if weather == "rain":
			weather = "overcast"  # no rain in a drought: the barrel stops filling for free
		card_state["stream"] = maxf(0.0, float(card_state.get("stream", 100.0)) - float(EVENTS["drought"]["stream_drain_per_hour"]) * hours)
	else:
		card_state["stream"] = minf(100.0, float(card_state.get("stream", 100.0)) + 6.0 * hours)  # recovers between droughts
	outdoor_temp = {"clear": 4.0, "overcast": 1.0, "rain": -1.0}.get(weather, 1.0) + season_offset() + _event_temp_offset()
	# WET: soaked by rain outdoors; dries indoors or by a fire
	if weather == "rain" and not location_indoor:
		wet = clampf(wet + 30.0 * hours, 0.0, 100.0)
	else:
		wet = maxf(0.0, wet - (25.0 if (location_indoor or is_fire_lit()) else 8.0) * hours)
	# the rain barrel catches the sky wherever it sits, so rain slowly refills it
	if weather == "rain":
		card_state["rain_barrel"] = minf(100.0, float(card_state.get("rain_barrel", 100.0)) + 8.0 * hours)
		# rain feeds the wild growth: a gentle nudge to forage and herbs at every outdoor stock
		for loc in stocks:
			if bool(loc_indoor.get(loc, false)):
				continue
			add_stock(loc, "forage_food", 0.4 * hours)
			add_stock(loc, "herbs", 0.2 * hours)
	# TRAPPING: any snare set on open ground fills toward a catch on the clock (deterministic)
	for tloc in traps:
		traps[tloc] = minf(100.0, float(traps[tloc]) + SNARE_CATCH_PER_HOUR * hours)
	# RENEWABLE STOCKS: every registered location+resource regrows on its own logistic clock
	_tick_stocks(hours)
	# an unlit shelter can't beat the season: it blocks most of the seasonal swing, so a deep
	# winter still creeps in (a lit fire overrides it). Draught-proofing research seals it tighter.
	# A stopgap until per-location insulation lands.
	var damp := shelter_damp()
	var target := 19.0 if is_fire_lit() else (7.0 + season_offset() * damp)
	temperature = lerpf(temperature, target, clampf(hours * 0.6, 0.0, 1.0))
	# your Warmth follows the AMBIENT temperature where you actually are:
	# indoors = the room (fire-warmed); outdoors = the weather. Below ~10C you lose heat.
	var ambient := temperature if location_indoor else outdoor_temp
	var warm_delta := (ambient - 10.0) * 0.6 * hours
	if warm_delta < 0.0:
		warm_delta *= (1.0 + wet / 100.0)  # being wet steepens the chill
		if worn != "":
			warm_delta *= warmth_insulation()  # a worn garment cuts the heat you shed
	meters["Warmth"] = clampf(meters["Warmth"] + warm_delta, 0.0, 100.0)
	# FATIGUE: cleared only by sleep (raising the Energy ceiling FIRST), accrues while awake
	if sleeping:
		var f0 := fatigue
		fatigue = maxf(0.0, fatigue - FATIGUE_SLEEP_CLEAR * sleep_quality() * hours)
		# Energy recovered is tied to fatigue ACTUALLY cleared (kills the nap/oversleep farm)
		meters["Energy"] = clampf(meters["Energy"] + (f0 - fatigue) * 1.4, 0.0, energy_cap())
	else:
		fatigue = clampf(fatigue + FATIGUE_ACCRUAL * hours, 0.0, 100.0)
		# RESEARCH advances in the background, in your waking hours (never while asleep)
		if current_research != "":
			research_progress += hours
			if research_progress >= research_hours(current_research):
				_complete_research(current_research)
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
		_director_tick()  # schedule/telegraph/fire the "worse times", once per new day
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
		"Satiation":
			return "How full you are right now. Meals fill it\nfast and it falls off through the day.\nKeep it up and your reserves recover."
		"Calories":
			return "Your body's deeper reserves. They fill\nwhen you eat well and burn when you go\nwithout. Hitting empty won't kill you; it\nburns your Weight instead."
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
	skills = {"woodworking": 0.0, "cooking": 0.0, "crafting": 0.0, "tailoring": 0.0}
	researched = {}
	current_research = ""
	research_progress = 0.0
	builds = {}
	build_progress = {}
	active_events = []
	radio_powered = true
	radio_last_broadcast_day = 0
	pending_siege = 0
	_seed_schedule()
	current_location = "the_grounds"
	location_indoor = false
	card_state = {}
	location_ground = {}
	pool_state = {}
	traps = {}
	stocks = {}
	loc_indoor = {}
	lit_sources = {}
	meters = {"Satiation": 65.0, "Calories": 82.0, "Hydration": 74.0, "Warmth": 55.0, "Energy": 70.0, "Immune": 78.0, "Mental": 64.0}
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
	worn = ""
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
