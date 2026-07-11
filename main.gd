extends Control
## Dead Air — table view.
## LEFT (character + condition) | CENTER (3 card rows) | RIGHT (time / temp / log).
## Single-card actions: click a card -> detail modal. Two-card actions: drag a card onto a
## target -> a hover label shows the action; release to perform it.

const BG := Color(0.039, 0.055, 0.075)
const PANEL := Color(0.067, 0.098, 0.133)
const PANEL2 := Color(0.055, 0.082, 0.114)
const BORDER := Color(0.118, 0.169, 0.220)
const INK := Color(0.776, 0.824, 0.867)
const INK_STRONG := Color(0.906, 0.933, 0.957)
const MUTED := Color(0.490, 0.549, 0.604)
const COLD := Color(0.412, 0.714, 0.839)
const WARM := Color(0.910, 0.678, 0.361)
const WARM_SOFT := Color(0.941, 0.769, 0.514)
const BLOOD := Color(0.788, 0.412, 0.369)
const GREEN := Color(0.545, 0.690, 0.541)

const INV_CAP := 6
const SIP := 25.0  ## a standard mouthful of liquid, in fill units — drinks pull this much (or the last of it)
const COMBAT_ROUND_MINS := 3  ## in-game minutes each combat swing/round takes

var CARD_FILES := {}

## Locations: the fixtures/stations present there, and where you can travel from it.
var LOCATIONS := {
	"lordly_manor": {"title": "Manor", "the": true, "indoor": true, "fixtures": ["radio"], "connections": {"the_grounds": 0}, "stripped_log": "You have been through every room. The house has given up all it holds.",
		"pool": {"finite": [{"kind": "fixture", "id": "broken_hearth", "milestone": 1, "log": "A hearth at the far end of the hall, fallen in and long cold."}, {"kind": "location", "id": "cellar", "milestone": 50, "mins": 0}, {"kind": "ground", "id": "canned_food", "between": [15, 85]}, {"kind": "flavor", "milestone": 65, "log": "Framed faces on the mantel, gone soft and brown with the damp. No one you know, and no one left to ask."}, {"kind": "ground", "id": "wool_blanket", "milestone": 90, "log": "In a back bedroom, folded in a cedar chest, a heavy wool blanket. Dry, somehow, after all this time."}], "renewable": []}},
	"the_grounds": {"title": "Grounds", "the": true, "indoor": false, "fixtures": ["rain_barrel"], "connections": {"the_woods": 45},
		"pool": {"finite": [{"kind": "location", "id": "lordly_manor", "milestone": 40, "mins": 0, "log": "Past a fallen gate, the house stands dark. A way in, at last."}], "renewable": [{"kind": "ground", "id": "firewood", "max": 2}, {"kind": "ground", "id": "stone", "max": 4}]}},
	"the_woods": {"title": "Woods", "the": true, "indoor": false, "fixtures": ["oak_tree"], "connections": {"the_grounds": 45},
		"pool": {"finite": [{"kind": "fixture", "id": "stream", "milestone": 30}, {"kind": "fixture", "id": "zombie", "milestone": 45, "log": "Something moves between the trees, slow and wrong. It turns toward you."}], "renewable": [{"kind": "ground", "id": "forage_food", "max": 3}, {"kind": "ground", "id": "tinder", "max": 3}, {"kind": "fixture", "id": "oak_tree", "max": 3, "log": "Deeper in, you find another good oak."}, {"kind": "ground", "id": "herbs", "max": 3}, {"kind": "ground", "id": "firewood", "max": 3}]}},
	"cellar": {"title": "Cellar", "the": true, "indoor": true, "fixtures": [], "connections": {"lordly_manor": 0}, "stripped_log": "The cellar is turned out to the bare shelves now. There is nothing more down here.",
		"pool": {"finite": [{"kind": "ground", "id": "canned_food", "milestone": 40}, {"kind": "ground", "id": "gas_canister", "milestone": 75, "content": "fuel", "fill": 50.0}, {"kind": "ground", "id": "antibiotics", "milestone": 60}], "renewable": [{"kind": "fixture", "id": "rat", "max": 1, "log": "Something skitters in the dark. A big rat, cornered and bold."}]}},
}

## What's lying around on the ground at each location to begin with (mutated as you play).
var GROUND_START := {
	"lordly_manor": ["firewood", "tinder"],
	"the_woods": [],
}

## Single-card (click) actions.
var ACTIONS := {
	"hearth": [
		{"label": "Sit by the fire (30m)", "mins": 30, "needs_fire": true, "audio": "hearth_add_wood", "fx": {"Warmth": 15.0, "Mental": 3.0}, "log": "You sit close and let the warmth reach your hands.", "once_log": "You reach back for how you came to be here. Only the edge of it, and cold beyond.", "once_key": "fireside_amnesia"},
	],
	"oak_tree": [
		{"label": "Fell the tree (30m)", "mins": 30, "audio": "wood_axe_oak", "fx": {"Energy": -8.0, "Calories": -7.0, "Hydration": -6.0, "Warmth": 5.0}, "state_delta": 50.0, "log": "You swing until your shoulders burn. The old oak groans a little lower."},
	],
	"the_woods": [
		{"label": "Forage (45m)", "mins": 45, "audio": "search_outdoors", "fx": {"Energy": -6.0, "Mental": 2.0, "Calories": -6.0, "Hydration": -5.0, "Warmth": 3.0}, "state_delta": 8.0, "log": "You move quiet through the trees. A few late berries, kindling, tracks that are not yours."},
	],
	"lordly_manor": [
		{"label": "Search the manor (30m)", "mins": 30, "audio": "search_interior", "fx": {"Mental": -1.0}, "state_delta": 15.0, "log": "You search the cold rooms. A door you had not tried opens onto stairs going down."},
	],
	"the_grounds": [
		{"label": "Search the grounds (15m)", "mins": 15, "audio": "search_outdoors", "fx": {"Mental": -1.0}, "state_delta": 15.0, "log": "You walk the overgrown grounds, turning over what the weather left behind."},
	],
	"broken_hearth": [
		{"label": "Rebuild the hearth", "buildsite": "manor_hearth"},
	],
	"spoiled_meat": [
		{"label": "Choke it down (10m)", "mins": 10, "audio": "eat_meat", "fx": {"Satiation": 4.0, "Mental": -9.0}, "cond": {"gut_bug": 35.0}, "cond_cause": "spoiled meat", "consume": true, "log": "It is rank and slick and your throat fights it, but hunger wins out. Your gut will turn on you for it."},
	],
	"rain_barrel": [
		{"label": "Drink from the barrel (5m)", "mins": 5, "drink": true, "clean": false},
	],
	"stream": [
		{"label": "Drink from the stream (5m)", "mins": 5, "drink": true, "clean": false},
	],
	"canned_food": [
		{"label": "Eat cold (15m)", "mins": 15, "audio": "eat_tinned", "fx": {"Satiation": 35.0, "Mental": 1.0}, "consume": true, "log": "You eat cold from the tin. It helps, a little."},
	],
	"wool_blanket": [
		{"label": "Wrap up (30m)", "mins": 30, "audio": "cloth_wrap", "fx": {"Warmth": 12.0, "Mental": 2.0}, "log": "You pull the blanket close. Quiet warmth, the kind that draws nothing."},
	],
	"hide_coat": [
		{"label": "Wear it", "wear": "hide_coat", "log": "You shrug the coat on. Stiff and heavy, but it cuts the cold at once."},
	],
	"cellar": [
		{"label": "Search the cellar (30m)", "mins": 30, "audio": "search_interior", "fx": {"Mental": -1.0}, "state_delta": 25.0, "log": "Cold shelves in the dark. You work through them slowly."},
	],
	"forage_food": [
		{"label": "Eat (10m)", "mins": 10, "audio": "eat_dry", "fx": {"Satiation": 18.0, "Mental": 1.0}, "consume": true, "log": "Bitter and stringy, but it is food."},
	],
	"rat_meat": [
		{"label": "Eat it raw (10m)", "mins": 10, "audio": "eat_meat", "fx": {"Satiation": 8.0, "Mental": -12.0}, "cond": {"gut_bug": 20.0}, "cond_cause": "raw rat meat", "consume": true, "log": "You force the raw meat down cold, gagging. Your gut coils in protest."},
	],
	"cooked_rat_meat": [
		{"label": "Eat (10m)", "mins": 10, "audio": "eat_meat", "fx": {"Satiation": 18.0, "Calories": 4.0, "Mental": -3.0}, "consume": true, "log": "You eat it off the fire, chewing slow. Not good, but it stays down."},
	],
	"preserved_meat": [
		{"label": "Eat (10m)", "mins": 10, "audio": "eat_dry", "fx": {"Satiation": 16.0, "Calories": 3.0}, "consume": true, "log": "You gnaw a strip of the smoked meat. Lean and tough, but it holds you together."},
	],
	"log": [
		{"label": "Split for firewood (15m)", "mins": 15, "audio": "wood_split", "fx": {"Energy": -6.0, "Calories": -6.0, "Hydration": -5.0, "Warmth": 4.0}, "spawn": "firewood", "state_delta": -34.0, "log": "You set the wedge and swing. The log gives up a few good splits."},
	],
	"herbal_remedy": [
		{"label": "Drink the remedy (5m)", "mins": 5, "audio": "drink", "fx": {"Mental": 1.0}, "cure": {"gut_bug": -15.0}, "consume": true, "log": "Bitter and earthy. Your gut eases, a little."},
	],
	"antibiotics": [
		{"label": "Take antibiotics (5m)", "mins": 5, "audio": "medicine_pills", "cure": {"gut_bug": -50.0, "infection": -50.0}, "consume": true, "log": "You dry-swallow two. Real medicine, and not much left."},
	],
	"bandage": [
		{"label": "Bind your wounds (10m)", "mins": 10, "audio": "bandage_apply", "cure": {"wound": -45.0}, "consume": true, "log": "You clean it out and bind it tight. Not clever work, but it will hold."},
	],
	"radio": [
		{"label": "Listen (15m)", "mins": 15, "fx": {"Mental": -2.0}, "radio_listen": true},
	],
	"rat": [
		{"label": "Deal with it", "fight": true},
	],
	"zombie": [
		{"label": "Fight it", "fight": true},
	],
	"snare": [
		{"label": "Set the snare (10m)", "mins": 10, "place_snare": true},
	],
	"set_snare": [
		{"label": "Check the snare (10m)", "mins": 10, "check_snare": true},
	],
}

## Two-card (drag item onto target) recipes: item_id -> target_id -> {label, mins}.
var RECIPES := {
	"firewood": {"hearth": {"label": "Lay on wood", "mins": 10, "effect": "add_fuel", "amount": 40, "audio": "hearth_add_wood"}},
	"gas_canister": {"stream": {"label": "Fill with water", "mins": 10}, "rain_barrel": {"label": "Fill with water", "mins": 10}, "lighter": {"label": "Top up the lighter", "mins": 3}, "plastic_bottle": {"label": "Pour into bottle", "mins": 3}, "hearth": {"label": "Boil the water", "mins": 15}},
	"plastic_bottle": {"stream": {"label": "Fill with water", "mins": 10}, "rain_barrel": {"label": "Fill with water", "mins": 10}, "lighter": {"label": "Top up the lighter", "mins": 3}, "gas_canister": {"label": "Pour into canister", "mins": 3}, "hearth": {"label": "Boil the water", "mins": 15}},
	"lighter": {"tinder": {"label": "Light the tinder", "mins": 3, "effect": "light_tinder", "audio": "lighter_flick"}},
	"burning_tinder": {"hearth": {"label": "Set it alight", "mins": 3, "effect": "set_alight", "audio": "hearth_ignite"}},
	"herbs": {"hearth": {"label": "Steep a remedy", "mins": 15, "effect": "steep_remedy", "audio": "herbs_steep"}},
	"rat_meat": {"hearth": {"label": "Cook the meat", "mins": 15, "effect": "cook", "spawn": "cooked_rat_meat", "audio": "cook_meat"}},
	"cooked_rat_meat": {"hearth": {"label": "Smoke it to keep", "mins": 60, "effect": "smoke", "spawn": "preserved_meat", "audio": "cook_meat"}},
}

var rows := {}
var bars := {}
var clock_label: Label
var temp_label: Label
var top_head: Label
var log_label: Label
var inv_head: Label
var cond_tray: VBoxContainer
var fatigue_bar: ProgressBar
var weight_bar: ProgressBar
var weight_fill: StyleBoxFlat
var weather_label: Label
var _collapsing: bool = false
var _locations_initial: Dictionary
var _last_present := {}  ## renewable ground id -> present count at the CURRENT location (harvest detection)
var _death_shown: bool = false
var death_layer: Control
var death_dim: ColorRect
var death_obit_label: Label
var death_badge: Button
var overlay: Control
var hint_box: PanelContainer
var hint_label: Label
var menu_layer: Control
var menu_panel: PanelContainer
var menu_vbox: VBoxContainer
var _menu_card: CardIcon
var _menu_actions: Array = []
var _dragging: CardIcon = null
var detail_layer: Control
var detail_panel: PanelContainer
var detail_body: VBoxContainer
var _detail_mode: String = "card"  ## card | craft | buildsite | skills | research
var _build_project: String = ""
var _craft_tab: String = "shelter"
const CRAFT_TABS := [["shelter", "Shelter"], ["tools", "Tools"], ["tailoring", "Tailoring"]]
var combat_layer: Control
var combat_title: Label
var combat_hp_bar: ProgressBar
var combat_hp_fill: StyleBoxFlat
var combat_blurb: Label
var combat_log_label: Label
var combat_wound_label: Label
var _combat_id: String = ""
var _combat_card: CardIcon = null
var _combat_hp: float = 0.0
var _combat_hp_max: float = 0.0
var _combat_log: Array = []
var _combat_before: Dictionary = {}
var _combat_resolving: bool = false
var _combat_context: String = "table"  ## table (normal) | siege (unfleeable horde wave)
var _siege_waves_left: int = 0
var combat_flee_btn: Button
var hurt_flash: ColorRect
var _shake_tween: Tween
var time_layer: Control
var _clock_face: ClockFace
var _clock_dur: Label
var _clock_sub: Label
var _time_tween: Tween

func _scan_cards() -> void:
	# DirAccess enumerates data/cards when running from source/CLI/editor; a packed .pck export would need a generated manifest instead (out of scope).
	var dir := DirAccess.open("res://data/cards")
	if dir == null:
		return
	for name in dir.get_files():
		if not name.ends_with(".tres"):
			continue
		var path := "res://data/cards/" + name
		var cd: CardData = load(path)
		if cd == null or cd.id == "":
			continue
		CARD_FILES[cd.id] = path

func _ready() -> void:
	_scan_cards()
	randomize()
	_locations_initial = LOCATIONS.duplicate(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_tooltip_theme()
	_build_background()
	_build_ui()
	_build_overlay()
	_build_time_popup()
	_build_menu()
	_build_detail()
	_build_death()
	_build_combat()
	_build_hurt_flash()
	_populate()
	Game.changed.connect(_refresh)
	Game.add_log("Day 1. You wake on the grounds of a great old house, cold to the bone and remembering little. Frost on the weeds, your breath white, no sound anywhere. A way in, somewhere past the overgrowth.")
	_refresh()
	_sync_world_audio()
	on_layout_changed()
	_validate_content()

## Boot-time content check: turn silent bad-id no-ops into loud, named errors.
## Reports ALL problems via push_error; never crashes. Run at the end of _ready().
func _validate_content() -> void:
	# (a) RECIPES: source id, target id, and any recipe "spawn" id must be cards.
	for src in RECIPES:
		if not CARD_FILES.has(src):
			push_error("CONTENT: RECIPES source id '%s' is not a known card" % src)
		var targets: Dictionary = RECIPES[src]
		for tgt in targets:
			if not CARD_FILES.has(tgt):
				push_error("CONTENT: RECIPES['%s'] target id '%s' is not a known card" % [src, tgt])
			var rec: Dictionary = targets[tgt]
			if rec.has("spawn") and not CARD_FILES.has(str(rec["spawn"])):
				push_error("CONTENT: RECIPES['%s']['%s'] spawn id '%s' is not a known card" % [src, tgt, str(rec["spawn"])])
	# (b) ACTIONS: spawn -> card, cure/cond keys -> condition, fx keys -> meter.
	for aid in ACTIONS:
		for act in ACTIONS[aid]:
			if act.has("spawn") and not CARD_FILES.has(str(act["spawn"])):
				push_error("CONTENT: ACTIONS['%s'] spawn id '%s' is not a known card" % [aid, str(act["spawn"])])
			for cid in act.get("cure", {}):
				if not Game.CONDITIONS.has(cid):
					push_error("CONTENT: ACTIONS['%s'] cure key '%s' is not a known condition" % [aid, str(cid)])
			for ck in act.get("cond", {}):
				if not Game.CONDITIONS.has(ck):
					push_error("CONTENT: ACTIONS['%s'] cond key '%s' is not a known condition" % [aid, str(ck)])
			for fk in act.get("fx", {}):
				if not Game.meters.has(fk):
					push_error("CONTENT: ACTIONS['%s'] fx key '%s' is not a known meter" % [aid, str(fk)])
	# (c) CONSTRUCTION phase materials, requires_research; RESEARCH unlocks + skill.
	for pid in Game.CONSTRUCTION:
		var proj: Dictionary = Game.CONSTRUCTION[pid]
		for phase in proj.get("phases", []):
			for mid in phase.get("materials", {}):
				if not CARD_FILES.has(str(mid)):
					push_error("CONTENT: CONSTRUCTION['%s'] phase material id '%s' is not a known card" % [pid, str(mid)])
		var req := str(proj.get("requires_research", ""))
		if req != "" and not Game.RESEARCH.has(req):
			push_error("CONTENT: CONSTRUCTION['%s'] requires_research '%s' is not a known research project" % [pid, req])
	for rid in Game.RESEARCH:
		var r: Dictionary = Game.RESEARCH[rid]
		var unlocks := str(r.get("unlocks", ""))
		if unlocks != "" and not Game.CONSTRUCTION.has(unlocks):
			push_error("CONTENT: RESEARCH['%s'] unlocks '%s' is not a known construction project" % [rid, unlocks])
		var skill := str(r.get("skill", ""))
		if not Game.skills.has(skill):
			push_error("CONTENT: RESEARCH['%s'] skill '%s' is not a known skill" % [rid, skill])
	# (c2) CRAFTS: material + produces ids must be cards; requires_research must be known; skill known.
	for cid in Game.CRAFTS:
		var craft: Dictionary = Game.CRAFTS[cid]
		for mid in craft.get("materials", {}):
			if not CARD_FILES.has(str(mid)):
				push_error("CONTENT: CRAFTS['%s'] material id '%s' is not a known card" % [cid, str(mid)])
		if not CARD_FILES.has(str(craft.get("produces", ""))):
			push_error("CONTENT: CRAFTS['%s'] produces id '%s' is not a known card" % [cid, str(craft.get("produces", ""))])
		var creq := str(craft.get("requires_research", ""))
		if creq != "" and not Game.RESEARCH.has(creq):
			push_error("CONTENT: CRAFTS['%s'] requires_research '%s' is not a known research project" % [cid, creq])
		var csk: Array = craft.get("skill", [])
		if csk.size() == 2 and not Game.skills.has(str(csk[0])):
			push_error("CONTENT: CRAFTS['%s'] skill '%s' is not a known skill" % [cid, str(csk[0])])
	# (d) LOCATIONS fixtures, pool ids, connection targets; GROUND_START ids.
	for loc in LOCATIONS:
		var ld: Dictionary = LOCATIONS[loc]
		for fxid in ld.get("fixtures", []):
			if not CARD_FILES.has(str(fxid)):
				push_error("CONTENT: LOCATIONS['%s'] fixture id '%s' is not a known card" % [loc, str(fxid)])
		var pool: Dictionary = ld.get("pool", {})
		for bucket in ["finite", "renewable"]:
			for entry in pool.get(bucket, []):
				var eid := str(entry.get("id", ""))
				if eid != "" and not CARD_FILES.has(eid):
					push_error("CONTENT: LOCATIONS['%s'] pool %s id '%s' is not a known card" % [loc, bucket, eid])
		for tgt in ld.get("connections", {}):
			if not LOCATIONS.has(tgt):
				push_error("CONTENT: LOCATIONS['%s'] connection target '%s' is not a known location" % [loc, str(tgt)])
	for gloc in GROUND_START:
		for gid in GROUND_START[gloc]:
			if not CARD_FILES.has(str(gid)):
				push_error("CONTENT: GROUND_START['%s'] id '%s' is not a known card" % [gloc, str(gid)])
	# (e) EVENT_SPINE ids exist; every EVENT has _telegraph and _onset flavor.
	for ev in Game.EVENT_SPINE:
		var evid := str(ev["id"])
		if not Game.EVENTS.has(evid):
			push_error("CONTENT: EVENT_SPINE id '%s' is not a known event" % evid)
	for eid in Game.EVENTS:
		if not Game.EVENT_FLAVOR.has(eid + "_telegraph"):
			push_error("CONTENT: EVENT_FLAVOR missing '%s_telegraph' for event '%s'" % [eid, eid])
		if not Game.EVENT_FLAVOR.has(eid + "_onset"):
			push_error("CONTENT: EVENT_FLAVOR missing '%s_onset' for event '%s'" % [eid, eid])

func _build_tooltip_theme() -> void:
	# global styling for hover tooltips: a solid, readable panel instead of the faint default
	var th := Theme.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.086, 0.125, 0.165, 0.98)
	sb.border_color = Color(0.235, 0.337, 0.435)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	th.set_stylebox("panel", "TooltipPanel", sb)
	th.set_color("font_color", "TooltipLabel", Color(0.863, 0.894, 0.925))
	th.set_font_size("font_size", "TooltipLabel", 13)
	theme = th

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if detail_layer and detail_layer.visible:
			_hide_detail()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var m := DisplayServer.window_get_mode()
		if m == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# ---------- style helpers ----------
func _flat(bg: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	return sb

func _pad(parent: Control, px: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", px)
	m.add_theme_constant_override("margin_right", px)
	m.add_theme_constant_override("margin_top", px)
	m.add_theme_constant_override("margin_bottom", px)
	parent.add_child(m)
	return m

func _label(txt: String, col: Color, sz: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", sz)
	return l

# ---------- build ----------
func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 10)
	add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	margin.add_child(cols)
	cols.add_child(_build_left())
	cols.add_child(_build_center())
	cols.add_child(_build_right())

func _build_left() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(236, 0)
	panel.add_theme_stylebox_override("panel", _flat(PANEL, BORDER, 12))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 13)
	_pad(panel, 16).add_child(vb)

	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(0, 148)
	portrait.add_theme_stylebox_override("panel", _flat(PANEL2, BORDER, 10))
	portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait.gui_input.connect(_on_portrait_input)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(cc)
	var pvb := VBoxContainer.new()
	pvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(pvb)
	var you := _label("YOU", WARM, 24)
	you.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	you.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pvb.add_child(you)
	var phint := _label("rest, or sleep off the day", MUTED, 10)
	phint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pvb.add_child(phint)
	vb.add_child(portrait)

	var build_btn := _btn("Construction")
	build_btn.pressed.connect(_open_craft_hub)
	vb.add_child(build_btn)

	clock_label = _label("", INK_STRONG, 18)
	vb.add_child(clock_label)
	temp_label = _label("", COLD, 14)
	vb.add_child(temp_label)
	weather_label = _label("Overcast, still.", MUTED, 12)
	vb.add_child(weather_label)

	vb.add_child(HSeparator.new())
	vb.add_child(_label("CONDITION", COLD, 11))
	for m in ["Calories", "Satiation", "Hydration", "Warmth", "Energy", "Immune", "Mental"]:
		vb.add_child(_make_meter(m))
	var fbox := VBoxContainer.new()
	fbox.add_theme_constant_override("separation", 4)
	fbox.add_child(_label("Sleep-debt", INK, 12))
	fatigue_bar = ProgressBar.new()
	fatigue_bar.min_value = 0.0
	fatigue_bar.max_value = 100.0
	fatigue_bar.show_percentage = false
	fatigue_bar.custom_minimum_size = Vector2(0, 11)
	fatigue_bar.add_theme_stylebox_override("background", _flat(BG, BORDER, 5))
	var ffill := StyleBoxFlat.new()
	ffill.bg_color = WARM
	ffill.set_corner_radius_all(5)
	fatigue_bar.add_theme_stylebox_override("fill", ffill)
	fatigue_bar.tooltip_text = Game.need_desc("Sleep-debt")
	fbox.add_child(fatigue_bar)
	vb.add_child(fbox)
	var wbox := VBoxContainer.new()
	wbox.add_theme_constant_override("separation", 4)
	wbox.add_child(_label("Weight", INK, 12))
	weight_bar = ProgressBar.new()
	weight_bar.min_value = 0.0
	weight_bar.max_value = 100.0
	weight_bar.show_percentage = false
	weight_bar.custom_minimum_size = Vector2(0, 11)
	weight_bar.add_theme_stylebox_override("background", _flat(BG, BORDER, 5))
	weight_fill = StyleBoxFlat.new()
	weight_fill.bg_color = GREEN
	weight_fill.set_corner_radius_all(5)
	weight_bar.add_theme_stylebox_override("fill", weight_fill)
	weight_bar.tooltip_text = Game.need_desc("Weight")
	wbox.add_child(weight_bar)
	vb.add_child(wbox)
	cond_tray = VBoxContainer.new()
	cond_tray.add_theme_constant_override("separation", 5)
	vb.add_child(cond_tray)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	vb.add_child(_label("F11  ·  fullscreen", MUTED, 10))
	return panel

func _skill_row(id: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.tooltip_text = Game.skill_desc(id)
	var head := HBoxContainer.new()
	var nm := _label(str(Game.SKILL_LABEL.get(id, id)), INK, 12)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(nm)
	var val := _label(str(Game.skill_level(id)), MUTED, 12)
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(val)
	box.add_child(head)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = Game.skills.get(id, 0.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 7)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _flat(BG, BORDER, 4))
	var sb := StyleBoxFlat.new()
	sb.bg_color = GREEN
	sb.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", sb)
	box.add_child(bar)
	return box

func _render_skills_screen() -> void:
	detail_body.add_child(_char_tabs("skills"))
	detail_body.add_child(_label("Skills", INK_STRONG, 20))
	detail_body.add_child(_wrapped("What your hands have learned. Each one rises as you use it.", MUTED, 12))
	detail_body.add_child(HSeparator.new())
	for id in Game.skills:
		if id in Game.SKILL_ACTIVE or Game.skills[id] > 0.0:
			detail_body.add_child(_skill_row(id))
	var closeb := _detail_action_btn("Close")
	closeb.pressed.connect(_hide_detail)
	detail_body.add_child(closeb)

func _render_research_screen() -> void:
	detail_body.add_child(_char_tabs("research"))
	detail_body.add_child(_label("Research", INK_STRONG, 20))
	if Game.current_research != "":
		var r: Dictionary = Game.RESEARCH[Game.current_research]
		detail_body.add_child(_wrapped("Working out: %s" % str(r["label"]), INK, 13))
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = Game.research_fraction()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", _flat(BG, BORDER, 4))
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = COLD
		fsb.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fsb)
		detail_body.add_child(bar)
		detail_body.add_child(_wrapped("You turn it over in your spare hours. It will come in time.", MUTED, 11))
	else:
		detail_body.add_child(_wrapped("Things you might work out, given the skill and the time. Pick one to turn over.", MUTED, 12))
	detail_body.add_child(HSeparator.new())
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var any := false
	for id in Game.RESEARCH:
		if Game.researched.has(id):
			continue
		hb.add_child(_research_card(id))
		any = true
	if any:
		detail_body.add_child(hb)
	else:
		detail_body.add_child(_label("Nothing left to work out.", MUTED, 12))
	var closeb := _detail_action_btn("Close")
	closeb.pressed.connect(_hide_detail)
	detail_body.add_child(closeb)

func _research_card(id: String) -> Control:
	var r: Dictionary = Game.RESEARCH[id]
	var avail := Game.research_available(id)
	var active := Game.current_research == id
	var can_start := avail and Game.current_research == ""
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 0)
	panel.add_theme_stylebox_override("panel", _flat(PANEL2, (COLD if active else BORDER), 8))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	_pad(panel, 10).add_child(vb)
	vb.add_child(_wrapped(str(r["label"]), INK, 13, 126))
	var unlocks_id := str(r.get("unlocks", ""))
	if unlocks_id != "" and Game.CONSTRUCTION.has(unlocks_id):
		vb.add_child(_wrapped("Lets you build: %s" % str(Game.CONSTRUCTION[unlocks_id]["label"]), MUTED, 10, 126))
	var skill_name: String = str(Game.SKILL_LABEL.get(str(r["skill"]), str(r["skill"])))
	vb.add_child(_label("%s %d" % [skill_name, int(r["level"])], (WARM_SOFT if avail else BLOOD), 11))
	if active:
		vb.add_child(_label("in progress", COLD, 11))
	elif can_start:
		var b := _btn("Study")
		b.add_theme_font_size_override("font_size", 12)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_research_pick.bind(id))
		vb.add_child(b)
	elif not avail:
		vb.add_child(_label("needs more skill", MUTED, 11))
	else:
		vb.add_child(_label("another time", MUTED, 11))
	return panel

func _char_tabs(active: String) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	for t in [["card", "You"], ["skills", "Skills"], ["research", "Research"]]:
		var b := _tab_btn(str(t[1]), str(t[0]) == active)
		b.pressed.connect(_goto_detail_mode.bind(str(t[0])))
		hb.add_child(b)
	return hb

func _tab_btn(txt: String, active: bool) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", WARM if active else INK)
	b.add_theme_color_override("font_hover_color", WARM_SOFT)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL2 if active else BG
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 11.0
	sb.content_margin_right = 11.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("hover", sb)
	return b

func _on_research_pick(id: String) -> void:
	if Game.start_research(id):
		if detail_layer and detail_layer.visible:
			_open_detail()
		else:
			on_layout_changed()

func _make_meter(m: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_label("Immunity" if m == "Immune" else m, INK, 12))
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = Game.meters[m]
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 11)
	bar.add_theme_stylebox_override("background", _flat(BG, BORDER, 5))
	var fillsb := StyleBoxFlat.new()
	fillsb.bg_color = COLD
	fillsb.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fillsb)
	box.add_child(bar)
	bars[m] = {"bar": bar, "fill": fillsb}
	return box

func _make_chip(cname: String, traj: String, severity: int) -> Control:
	var col := WARM
	if severity >= 3:
		col = BLOOD
	elif severity == 1:
		col = MUTED
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.10, 0.10) if severity >= 2 else Color(0.10, 0.13, 0.16)
	sb.border_color = col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.add_child(_label("%s   ·   %s" % [cname, traj], col, 11))
	return panel

func _make_cond_bar(id: String, cname: String, level: float, severity: int, traj: String) -> Control:
	var col := WARM
	if severity >= 3:
		col = BLOOD
	elif severity == 1:
		col = GREEN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.tooltip_text = Game.condition_desc(id)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 5)
	var title_lbl := _label(str(Game.CONDITIONS[id].get("title", id.capitalize())), INK, 11)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title_lbl)
	var lbl := _label(cname, col, 11)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(lbl)
	var tj := _label(traj, MUTED, 10)
	tj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tj)
	box.add_child(head)
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = level
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 9)
	bar.add_theme_stylebox_override("background", _flat(BG, BORDER, 5))
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	return box

func _build_center() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	vb.add_child(_row_section("OUT THERE   ·   locations & fixtures", "top", false, -1))
	var mid := _row_section("ON THE GROUND   ·   what's lying around here", "middle", true, -1)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(mid)
	vb.add_child(_row_section("INVENTORY", "inv", true, INV_CAP))
	return vb

func _row_section(title: String, key: String, accepts: bool, cap: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(PANEL, BORDER, 12))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_pad(panel, 10).add_child(vb)

	var head := _label(title, COLD, 11)
	if key == "inv":
		inv_head = head
	elif key == "top":
		top_head = head
	vb.add_child(head)

	var row := CardRow.new()
	row.main = self
	row.accepts_items = accepts
	row.capacity = cap
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows[key] = row

	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, CardIcon.CARD_SIZE.y + 6)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(row)
	vb.add_child(sc)
	return panel

func _build_right() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	panel.add_theme_stylebox_override("panel", _flat(PANEL, BORDER, 12))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_pad(panel, 16).add_child(vb)

	vb.add_child(_label("THE DAY", COLD, 11))
	log_label = _label("", INK, 12)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vb.add_child(log_label)
	return panel

func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	hint_box = PanelContainer.new()
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_box.visible = false
	hint_box.add_theme_stylebox_override("panel", _flat(PANEL2, WARM, 6))
	overlay.add_child(hint_box)
	hint_label = _label("", WARM_SOFT, 13)
	_pad(hint_box, 8).add_child(hint_label)

func _build_time_popup() -> void:
	time_layer = Control.new()
	time_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	time_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(time_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.4)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_layer.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	_clock_face = ClockFace.new()
	_clock_face.custom_minimum_size = Vector2(104, 104)
	_clock_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_clock_face)
	_clock_sub = _label("", INK_STRONG, 30)
	_clock_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_clock_sub)
	_clock_dur = _label("", MUTED, 14)
	_clock_dur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_dur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_dur.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_clock_dur)
	time_layer.modulate.a = 0.0
	time_layer.visible = false

func _hide_time_layer() -> void:
	if time_layer:
		time_layer.visible = false
		time_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE  # release the input block

func _dur_text(mins: int) -> String:
	if mins < 60:
		return "%d min" % mins
	@warning_ignore("integer_division")
	var h := mins / 60
	var m := mins % 60
	return ("%d hr" % h) if m == 0 else ("%dh %02dm" % [h, m])

func _show_time_passing(mins: int) -> void:
	if mins <= 0 or _clock_face == null or Game.dead:
		return
	Audio.play_cue("ui_time_pass")
	_clock_dur.text = _dur_text(mins)
	_clock_sub.text = Game.hhmm()
	_clock_face.set_sweep(0.0)
	time_layer.visible = true
	time_layer.mouse_filter = Control.MOUSE_FILTER_STOP  # block input for the length of the wait
	if _time_tween and _time_tween.is_valid():
		_time_tween.kill()
	var hold: float = clampf(0.15 + float(mins) * 0.006, 0.2, 0.6)
	var turns: float = clampf(float(mins) / 60.0, 0.15, 1.0)
	_time_tween = create_tween()
	_time_tween.tween_property(time_layer, "modulate:a", 1.0, 0.08)
	_time_tween.parallel().tween_method(_clock_face.set_sweep, 0.0, turns, hold).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_time_tween.tween_property(time_layer, "modulate:a", 0.0, 0.16)
	_time_tween.tween_callback(_hide_time_layer)
	if clock_label:
		clock_label.pivot_offset = clock_label.size * 0.5
		clock_label.scale = Vector2(1.16, 1.16)
		var lt := create_tween()
		lt.tween_property(clock_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_menu() -> void:
	menu_layer = Control.new()
	menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.visible = false
	add_child(menu_layer)
	var catcher := Control.new()
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_on_catcher_input)
	menu_layer.add_child(catcher)
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", _flat(PANEL2, BORDER, 8))
	menu_layer.add_child(menu_panel)
	menu_vbox = VBoxContainer.new()
	menu_vbox.add_theme_constant_override("separation", 2)
	_pad(menu_panel, 3).add_child(menu_vbox)

# ---------- card detail view (left-click) ----------
func _build_detail() -> void:
	detail_layer = Control.new()
	detail_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_layer.visible = false
	add_child(detail_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_detail_dim_input)
	detail_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_layer.add_child(center)
	detail_panel = PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(440, 0)
	detail_panel.add_theme_stylebox_override("panel", _flat(PANEL, BORDER, 14))
	detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(detail_panel)
	var detail_shell := VBoxContainer.new()
	detail_shell.add_theme_constant_override("separation", 4)
	_pad(detail_panel, 22).add_child(detail_shell)
	var close_row := HBoxContainer.new()
	var close_spacer := Control.new()
	close_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_row.add_child(close_spacer)
	var close_x := Button.new()
	close_x.text = "X"
	close_x.tooltip_text = "Close"
	close_x.flat = true
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.custom_minimum_size = Vector2(28, 26)
	close_x.add_theme_font_size_override("font_size", 18)
	close_x.add_theme_color_override("font_color", MUTED)
	close_x.add_theme_color_override("font_hover_color", INK_STRONG)
	close_x.pressed.connect(_hide_detail)
	close_row.add_child(close_x)
	detail_shell.add_child(close_row)
	detail_body = VBoxContainer.new()
	detail_body.add_theme_constant_override("separation", 9)
	detail_shell.add_child(detail_body)

func _detail_category(card: CardIcon) -> String:
	if card.data.kind == "location":
		return "PLACE"
	return str(card.data.kind).to_upper()

func _detail_action_btn(txt: String) -> Button:
	var b := _btn(txt)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b

func _detail_card_art(card: CardIcon) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(500, 434)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _flat(PANEL2, BORDER, 8))
	var art := TextureRect.new()
	art.texture = card.data.cover_image_lit if card.data.is_fire_source and Game.is_lit(card.data.id) and card.data.cover_image_lit != null else card.data.cover_image
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad(frame, 3).add_child(art)
	return frame

func _open_detail() -> void:
	var was_hidden := not detail_layer.visible
	for c in detail_body.get_children():
		detail_body.remove_child(c)
		c.queue_free()
	match _detail_mode:
		"craft": _render_craft_hub()
		"buildsite": _render_buildsite()
		"skills": _render_skills_screen()
		"research": _render_research_screen()
		_: _render_card_detail()
	detail_panel.reset_size()
	detail_layer.visible = true
	if was_hidden:
		Audio.play_cue("ui_card_detail_open")

func _wrapped(txt: String, col: Color, sz: int, w: int = 396) -> Label:
	var l := _label(txt, col, sz)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	return l

func _render_card_detail() -> void:
	var card := _menu_card
	if card == null:
		detail_body.add_child(_char_tabs("card"))
	detail_body.add_child(_label("YOU" if card == null else _detail_category(card), COLD, 11))
	detail_body.add_child(_label("You" if card == null else card.data.title, INK_STRONG, 22))
	if card != null and card.data.cover_image != null:
		detail_body.add_child(_detail_card_art(card))
	var desc := "Rest to steady your nerves, or sleep off the day's weariness." if card == null else card.current_blurb()
	detail_body.add_child(_wrapped(desc, MUTED, 13))
	if card == null and Game.worn != "":
		detail_body.add_child(_label("Wearing: a %s" % _card_title(Game.worn).to_lower(), WARM_SOFT, 12))
	if card != null:
		var st := card.state_summary()
		if st != "":
			detail_body.add_child(_label(st, WARM_SOFT, 12))
	detail_body.add_child(HSeparator.new())
	if _menu_actions.is_empty():
		var hint := "Nothing to do with it just now."
		if card != null:
			if RECIPES.has(card.data.id):
				hint = "Drag it onto a target to use it."
			elif _is_recipe_target(card.data.id):
				hint = "Drag the right item onto it to use it."
		detail_body.add_child(_label(hint, MUTED, 12))
	else:
		for i in _menu_actions.size():
			var b := _detail_action_btn(str(_menu_actions[i]["label"]))
			b.pressed.connect(_on_detail_pick.bind(i))
			detail_body.add_child(b)

func _open_craft_hub() -> void:
	_menu_card = null
	_detail_mode = "craft"
	_craft_tab = "shelter"
	_open_detail()

func _goto_craft_tab(tab: String) -> void:
	_craft_tab = tab
	_detail_mode = "craft"
	_open_detail()

func _craft_tab_title(tab: String) -> String:
	for t in CRAFT_TABS:
		if str(t[0]) == tab:
			return str(t[1])
	return tab

func _craft_tabs(active: String) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	for t in CRAFT_TABS:
		var b := _tab_btn(str(t[1]), str(t[0]) == active)
		b.pressed.connect(_goto_craft_tab.bind(str(t[0])))
		hb.add_child(b)
	return hb

func _render_craft_hub() -> void:
	detail_body.add_child(_craft_tabs(_craft_tab))
	if _craft_tab == "shelter":
		_render_shelter_construction()
	else:
		_render_item_crafts(_craft_tab)
	var closeb := _detail_action_btn("Close")
	closeb.pressed.connect(_hide_detail)
	detail_body.add_child(closeb)

func _render_item_crafts(tab: String) -> void:
	detail_body.add_child(_label(_craft_tab_title(tab), INK_STRONG, 20))
	var ids := Game.crafts_for(tab)
	if ids.is_empty():
		detail_body.add_child(_wrapped("Nothing to make here yet. Come back with the research and the right tools.", MUTED, 12))
		return
	detail_body.add_child(_wrapped("Things you can make here, each in a single session of work.", MUTED, 12))
	detail_body.add_child(HSeparator.new())
	for id in ids:
		var craft: Dictionary = Game.CRAFTS[id]
		detail_body.add_child(_label(str(craft["label"]), INK, 14))
		detail_body.add_child(_wrapped(str(craft.get("desc", "")), MUTED, 11))
		var mats: Dictionary = craft.get("materials", {})
		var have_all := true
		for mid in mats:
			var need: int = int(mats[mid])
			var have: int = _count_available(str(mid))
			if have < need:
				have_all = false
			detail_body.add_child(_label("%s   %d / %d" % [_card_title(str(mid)), have, need], (WARM_SOFT if have >= need else BLOOD), 12))
		var wmin: int = int(craft.get("work_mins", 30))
		var b := _detail_action_btn("Make it  (%s)" % _dur_text(wmin))
		b.disabled = not have_all
		b.pressed.connect(_do_craft.bind(id))
		detail_body.add_child(b)
		if not have_all:
			detail_body.add_child(_wrapped("You need the materials to hand first, on the ground here or in your pack.", MUTED, 11))
		detail_body.add_child(HSeparator.new())

func _render_shelter_construction() -> void:
	var loc := Game.current_location
	if not Game.is_shelter(loc):
		detail_body.add_child(_label("Shelter", INK_STRONG, 20))
		detail_body.add_child(_wrapped("You are not at one of your shelters just now. Come back to the place to work on it.", MUTED, 12))
		return
	detail_body.add_child(_label(str(LOCATIONS[loc]["title"]), INK_STRONG, 20))
	detail_body.add_child(_wrapped("Repairs and improvements, each done in stages, a session of work at a time.", MUTED, 12))
	detail_body.add_child(HSeparator.new())
	for id in Game.construction_for(loc):
		var proj: Dictionary = Game.CONSTRUCTION[id]
		var status := ""
		if Game.build_done(id):
			status = "   ·   done"
		elif Game.build_phase_idx(id) > 0:
			status = "   ·   in progress"
		var b := _detail_action_btn(str(proj["label"]) + status)
		b.pressed.connect(_open_buildsite.bind(id))
		detail_body.add_child(b)

func _render_buildsite() -> void:
	var id := _build_project
	if not Game.CONSTRUCTION.has(id):
		_open_craft_hub()
		return
	var proj: Dictionary = Game.CONSTRUCTION[id]
	detail_body.add_child(_label("CONSTRUCTION", COLD, 11))
	if Game.build_done(id):
		detail_body.add_child(_label(str(proj.get("done_label", proj["label"])), INK_STRONG, 20))
		detail_body.add_child(_wrapped(str(proj.get("done_desc", "")), MUTED, 13))
		detail_body.add_child(_label("Finished.", WARM_SOFT, 12))
	else:
		detail_body.add_child(_label(str(proj["label"]), INK_STRONG, 20))
		detail_body.add_child(_wrapped(str(proj.get("broken_desc", "")), MUTED, 13))
		var phases: Array = proj["phases"]
		var idx := Game.build_phase_idx(id)
		var phase: Dictionary = phases[idx]
		detail_body.add_child(HSeparator.new())
		detail_body.add_child(_label("Stage %d of %d:  %s" % [idx + 1, phases.size(), str(phase["label"])], INK, 13))
		var mats: Dictionary = phase.get("materials", {})
		var have_all := true
		for mid in mats:
			var need: int = int(mats[mid])
			var have: int = _count_available(str(mid))
			if have < need:
				have_all = false
			detail_body.add_child(_label("%s   %d / %d" % [_card_title(str(mid)), have, need], (WARM_SOFT if have >= need else BLOOD), 12))
		var wmin: int = int(phase.get("work_mins", 60))
		var wb := _detail_action_btn("Work on it  (%s)" % _dur_text(wmin))
		wb.disabled = not have_all
		wb.pressed.connect(_do_build_phase.bind(id))
		detail_body.add_child(wb)
		if not have_all:
			detail_body.add_child(_wrapped("You need the materials to hand first, on the ground here or in your pack.", MUTED, 11))
	var back := _detail_action_btn("Back")
	back.pressed.connect(_open_craft_hub)
	detail_body.add_child(back)

func _goto_detail_mode(mode: String) -> void:
	_detail_mode = mode
	_open_detail()

func _open_buildsite(id: String) -> void:
	_build_project = id
	_detail_mode = "buildsite"
	_open_detail()

func _count_available(mid: String) -> int:
	var n := 0
	for key in ["inv", "middle"]:
		if rows.has(key):
			for c in rows[key].get_children():
				if c is CardIcon and (c as CardIcon).data.id == mid:
					n += 1
	return n

func _consume_materials(mid: String, n: int) -> void:
	var remaining := n
	for key in ["middle", "inv"]:
		if not rows.has(key):
			continue
		for c in rows[key].get_children().duplicate():
			if remaining <= 0:
				break
			if c is CardIcon and (c as CardIcon).data.id == mid:
				_consume_card(c)
				remaining -= 1

func _do_build_phase(id: String) -> void:
	if Game.dead or Game.build_done(id):
		return
	var phase: Dictionary = Game.build_current_phase(id)
	if phase.is_empty():
		return
	var mats: Dictionary = phase.get("materials", {})
	for mid in mats:
		if _count_available(str(mid)) < int(mats[mid]):
			_blocked("You do not have the materials for that yet.")
			return
	for mid in mats:
		_consume_materials(str(mid), int(mats[mid]))
	Audio.play_cue(str(phase.get("audio", "construction_wood")))
	var wmin: int = int(phase.get("work_mins", 60))
	var before := Game.meters.duplicate()
	var fx := {"Energy": -6.0, "Calories": -4.0, "Hydration": -4.0, "Warmth": 4.0}
	for k in fx:
		Game.modify(k, fx[k])
	Game.advance_time(wmin)
	_show_time_passing(wmin)
	Game.gain_skill("crafting", 3.0)
	if phase.has("log"):
		Game.add_log(str(phase["log"]))
	Game.complete_build_phase(id)
	# a finished project can swap a board fixture in place (the broken hearth becomes the working one)
	if Game.build_done(id) and Game.CONSTRUCTION[id].has("on_done_swap"):
		var sw: Array = Game.CONSTRUCTION[id]["on_done_swap"]
		_swap_fixture(str(sw[0]), str(sw[1]))
	_animate_meters(before, fx)
	on_layout_changed()
	if detail_layer and detail_layer.visible:
		_open_detail()

func _do_craft(id: String) -> void:
	if Game.dead or not Game.CRAFTS.has(id):
		return
	var craft: Dictionary = Game.CRAFTS[id]
	var req := str(craft.get("requires_research", ""))
	if req != "" and not Game.researched.has(req):
		return
	var mats: Dictionary = craft.get("materials", {})
	for mid in mats:
		if _count_available(str(mid)) < int(mats[mid]):
			_blocked("You do not have the materials for that yet.")
			return
	for mid in mats:
		_consume_materials(str(mid), int(mats[mid]))
	Audio.play_cue(str(craft.get("audio", "construction_wood")))
	var wmin: int = int(craft.get("work_mins", 30))
	var before := Game.meters.duplicate()
	var fx := {"Energy": -5.0, "Calories": -3.0, "Hydration": -3.0}
	for k in fx:
		Game.modify(k, fx[k])
	Game.advance_time(wmin)
	_show_time_passing(wmin)
	var sk: Array = craft.get("skill", [])
	if sk.size() == 2:
		Game.gain_skill(str(sk[0]), float(sk[1]))
	var produces := str(craft["produces"])
	var row_key := "inv" if (rows.has("inv") and rows["inv"].get_child_count() < INV_CAP) else "middle"
	_spawn(produces, row_key)
	Game.add_log(str(craft.get("log", "You finish the %s." % _card_title(produces).to_lower())))
	_animate_meters(before, fx)
	on_layout_changed()
	if detail_layer and detail_layer.visible:
		_open_detail()

func _on_detail_pick(i: int) -> void:
	_hide_detail()
	if i >= 0 and i < _menu_actions.size():
		_perform(_menu_card, _menu_actions[i])

func _hide_detail() -> void:
	if detail_layer == null or not detail_layer.visible:
		return
	Audio.play_cue("ui_panel_close")
	detail_layer.visible = false

func _on_detail_dim_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_hide_detail()

func _btn_sb(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(7)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 9.0
	sb.content_margin_bottom = 9.0
	return sb

func _btn(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", WARM_SOFT)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_stylebox_override("normal", _btn_sb(PANEL2))
	b.add_theme_stylebox_override("pressed", _btn_sb(PANEL2))
	b.add_theme_stylebox_override("hover", _btn_sb(Color(0.16, 0.20, 0.25)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

func _build_death() -> void:
	death_layer = Control.new()
	death_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_layer.visible = false
	add_child(death_layer)

	death_dim = ColorRect.new()
	death_dim.color = Color(0.02, 0.03, 0.045, 0.80)
	death_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	death_layer.add_child(death_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_stylebox_override("panel", _flat(PANEL, BLOOD, 14))
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	_pad(panel, 28).add_child(vb)
	var title := _label("this is where you stopped", BLOOD, 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	death_obit_label = _label("", INK, 15)
	death_obit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	death_obit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(death_obit_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var retry := _btn("Begin again")
	retry.pressed.connect(_restart)
	row.add_child(retry)
	var sit := _btn("Sit with it")
	sit.pressed.connect(_hide_death_modal)
	row.add_child(sit)

	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_layer.add_child(holder)
	death_badge = _btn("gone  ·  look back")
	death_badge.anchor_left = 1.0
	death_badge.anchor_right = 1.0
	death_badge.offset_left = -210.0
	death_badge.offset_right = -14.0
	death_badge.offset_top = 12.0
	death_badge.offset_bottom = 50.0
	death_badge.visible = false
	death_badge.pressed.connect(_show_death_modal)
	holder.add_child(death_badge)

func _build_combat() -> void:
	combat_layer = Control.new()
	combat_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(combat_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	combat_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(PANEL, BORDER, 10))
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(pad)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pad.add_child(vb)
	combat_title = _label("", INK_STRONG, 22)
	vb.add_child(combat_title)
	combat_hp_bar = ProgressBar.new()
	combat_hp_bar.show_percentage = false
	combat_hp_bar.custom_minimum_size = Vector2(0, 14)
	combat_hp_bar.add_theme_stylebox_override("background", _flat(BG, BORDER, 5))
	combat_hp_fill = StyleBoxFlat.new()
	combat_hp_fill.bg_color = BLOOD
	combat_hp_fill.set_corner_radius_all(5)
	combat_hp_bar.add_theme_stylebox_override("fill", combat_hp_fill)
	vb.add_child(combat_hp_bar)
	combat_blurb = _label("", MUTED, 12)
	combat_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat_blurb.custom_minimum_size = Vector2(420, 0)
	vb.add_child(combat_blurb)
	vb.add_child(HSeparator.new())
	combat_log_label = _label("", INK, 13)
	combat_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat_log_label.custom_minimum_size = Vector2(420, 76)
	combat_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vb.add_child(combat_log_label)
	combat_wound_label = _label("", WARM, 13)
	vb.add_child(combat_wound_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	var strike_btn := Button.new()
	strike_btn.text = "Strike"
	strike_btn.custom_minimum_size = Vector2(120, 34)
	strike_btn.pressed.connect(_combat_strike)
	row.add_child(strike_btn)
	combat_flee_btn = Button.new()
	combat_flee_btn.text = "Flee"
	combat_flee_btn.custom_minimum_size = Vector2(120, 34)
	combat_flee_btn.pressed.connect(_combat_flee)
	row.add_child(combat_flee_btn)
	combat_layer.visible = false

func _combat_tail() -> PackedStringArray:
	var out: Array = []
	var start: int = maxi(0, _combat_log.size() - 4)
	for i in range(start, _combat_log.size()):
		out.append(_combat_log[i])
	return PackedStringArray(out)

func enemy_data(id: String) -> CardData:
	return load(CARD_FILES[id])

func is_enemy(id: String) -> bool:
	return CARD_FILES.has(id) and load(CARD_FILES[id]).hp > 0.0

func _refresh_combat() -> void:
	if _combat_id == "" or not is_enemy(_combat_id):
		return
	var e: CardData = enemy_data(_combat_id)
	combat_title.text = e.title
	if _combat_card:
		combat_blurb.text = str(_combat_card.data.blurb)
	elif _combat_context == "siege":
		combat_blurb.text = "It came over the threshold, out of the crush of them. Put it down."
	combat_hp_bar.max_value = _combat_hp_max
	combat_hp_bar.value = maxf(0.0, _combat_hp)
	combat_wound_label.text = "Your wounds: %d%%" % int(round(Game.conditions.get("wound", 0.0)))
	combat_log_label.text = "\n".join(_combat_tail())

func _start_combat(enemy_id: String, card: CardIcon = null, context: String = "table") -> void:
	if Game.dead or not is_enemy(enemy_id):
		return
	_combat_id = enemy_id
	_combat_card = card
	_combat_context = context
	_combat_hp_max = enemy_data(_combat_id).hp
	_combat_hp = _combat_hp_max
	_combat_before = Game.meters.duplicate()
	_combat_log = []
	Audio.play_cue("encounter_rat" if enemy_id == "rat" else "encounter_zombie")
	_combat_say("A %s, and it has seen you." % enemy_data(_combat_id).title.to_lower())
	if combat_flee_btn:
		combat_flee_btn.visible = (context == "table")  # a siege is unfleeable
	combat_layer.visible = true
	_refresh_combat()

func _build_hurt_flash() -> void:
	hurt_flash = ColorRect.new()
	hurt_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_flash.color = Color(0.75, 0.12, 0.12, 0.0)
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hurt_flash)

func _screen_shake(intensity: float) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()  # one shake at a time — no overlapping jitter-fight
	_shake_tween = create_tween()
	for i in 4:
		var damp := 1.0 - float(i) / 4.0
		_shake_tween.tween_property(self, "position", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)) * damp, 0.045)
	_shake_tween.tween_property(self, "position", Vector2.ZERO, 0.05)

func _flash_hurt() -> void:
	if hurt_flash == null:
		return
	hurt_flash.color = Color(0.75, 0.12, 0.12, 0.42)
	var t := create_tween()
	t.tween_property(hurt_flash, "color:a", 0.0, 0.4)

func _combat_say(line: String) -> void:
	# combat lines go to the popup log AND the persistent day log, so they're readable
	# after the fight; quiet (no changed.emit) so refresh/death only fire when it resolves
	_combat_log.push_back(line)
	Game.log_quiet(line)

func _combat_strike() -> void:
	if not combat_layer.visible or _combat_resolving:
		return
	var e: CardData = enemy_data(_combat_id)
	var enemy_name: String = e.title.to_lower()
	var roll := Game.strike_roll()
	var dmg: float = float(roll["dmg"])
	Audio.play_cue("combat_swing")
	_combat_hp -= dmg
	match str(roll["q"]):
		"miss":
			_combat_say("You swing at the %s and miss." % enemy_name)
		"glance":
			_combat_say("A glancing blow catches the %s." % enemy_name)
		"good":
			_combat_say("You catch the %s clean and hard." % enemy_name)
		_:
			_combat_say("You strike the %s." % enemy_name)
	if dmg > 0.0:
		Audio.play_cue("combat_hit")
		_screen_shake(3.0 + dmg * 0.35)
	var killed := _combat_hp <= 0.0
	if killed:
		Audio.play_cue("combat_enemy_down")
		_combat_say("The %s drops, and does not get up." % enemy_name)
	else:
		var edmg: float = Game.enemy_damage_roll(e.damage)
		Game.take_wound(edmg)
		Audio.play_cue("combat_rat_attack" if _combat_id == "rat" else "combat_zombie_attack")
		Audio.play_cue("combat_player_hurt", -5.0)
		_flash_hurt()
		_screen_shake(6.0 + edmg * 0.25)
		_combat_say("The %s %s you." % [enemy_name, (e.verb if e.verb != "" else "hits")])
		if e.bite_infection > 0.0:
			# cap the infection a single fight can seed below the lethal threshold, so it
			# surfaces and festers (a treatable emergency) instead of maturing straight to death
			var seeded := 0.0
			for dose in Game.cond_pending:
				if str(dose.get("id", "")) == "infection":
					seeded += float(dose.get("amt", 0.0))
			var add: float = minf(Game.infection_roll(e.bite_infection), maxf(0.0, 55.0 - seeded))
			if add > 0.0:
				Game.add_condition("infection", add, "a bite")
	# each swing costs time — the survival sim ticks for the round (may turn a wound
	# or a low need lethal); death is surfaced by _combat_end, not mid-swing
	Game.advance_time(COMBAT_ROUND_MINS)
	_refresh_combat()
	if killed:
		_combat_end("win")
	elif Game.dead:
		_combat_end("downed")

func _combat_flee() -> void:
	if not combat_layer.visible or _combat_resolving or _combat_context != "table":
		return  # a siege wave cannot be fled
	var e: CardData = enemy_data(_combat_id)
	Audio.play_cue("combat_flee")
	var hit: float = Game.enemy_damage_roll(e.flee_hit)
	Game.take_wound(hit)
	if hit > 0.0:
		_flash_hurt()
		_screen_shake(6.0)
	_combat_say("You break away. It gets a piece of you as you go.")
	Game.advance_time(COMBAT_ROUND_MINS)
	_refresh_combat()
	if Game.dead:
		_combat_end("downed")
	else:
		_combat_end("flee")

func _combat_end(outcome: String) -> void:
	_combat_resolving = true
	var e: CardData = enemy_data(_combat_id)
	_refresh_combat()
	await get_tree().create_timer(0.7).timeout
	combat_layer.visible = false
	if outcome == "win":
		var defeated_id := _combat_id  # capture before it is cleared below; drives any drop
		if _combat_card:
			# an enemy lives in the location's fixtures; killing it removes it for good
			LOCATIONS[Game.current_location]["fixtures"].erase(_combat_card.data.id)
			_consume_card(_combat_card)
		Game.add_log("You put the %s down." % e.title.to_lower())
		var drops := enemy_data(defeated_id).drops
		if drops != "":
			_spawn(drops, "middle")
			Game.add_log("You cut what little meat you can from it.")
	elif outcome == "flee":
		Game.add_log("You back off from the %s." % e.title.to_lower())
	else:
		Game.add_log("The %s has the better of you." % e.title.to_lower())
	_combat_card = null
	_combat_id = ""
	var ctx := _combat_context
	_combat_context = "table"
	# time already passed per round; settle the bars to their post-fight values. combat is
	# hidden now, so the add_log above already let _refresh surface any death / forced sleep.
	_animate_meters(_combat_before, {})
	on_layout_changed()
	_combat_resolving = false
	# a siege chains breach by breach until the surge is spent or you go down
	if ctx == "siege" and outcome == "win" and not Game.dead:
		_siege_waves_left -= 1
		if _siege_waves_left > 0:
			_spawn_siege_wave.call_deferred()
		else:
			_end_siege()

# ---------- siege (a horde surge, driven by Game.pending_siege) ----------
func _start_siege(waves: int) -> void:
	if waves <= 0 or Game.dead:
		return
	var loc := Game.current_location
	var sheltered := Game.is_shelter(loc)
	var defense := Game.shelter_defense(loc)
	# deterministic: more waves and less defense means more of them break in
	var breaches := Game.siege_breaches(waves, loc)
	Game.add_log(Game._pick(Game.SIEGE["horde_arrives"]))
	if sheltered:
		Game.add_log(Game._pick(Game.SIEGE["testing_the_door"]))
		if breaches <= 0:
			Game.add_log(Game._pick(Game.SIEGE["holding"]))
			Game.add_log(Game._pick(Game.SIEGE["repelled"]))
			return
		if defense > 0.2:
			Game.add_log(Game._pick(Game.SIEGE["straining"]))
		Game.add_log(Game._pick(Game.SIEGE["breach"]))
	else:
		Game.add_log(Game._pick(Game.SIEGE["open_ground"]))
		breaches = maxi(1, waves)
	_siege_waves_left = breaches
	_spawn_siege_wave()

func _spawn_siege_wave() -> void:
	if _siege_waves_left <= 0 or Game.dead:
		_end_siege()
		return
	_start_combat("zombie", null, "siege")

func _end_siege() -> void:
	_siege_waves_left = 0
	if not Game.dead:
		Game.add_log(Game._pick(Game.SIEGE["repelled"]))

func _show_death() -> void:
	Audio.stop_all(1.0)
	Audio.play_cue("death")
	if death_obit_label:
		death_obit_label.text = Game.obituary
	death_layer.visible = true
	death_dim.visible = true
	death_badge.visible = false

func _show_death_modal() -> void:
	death_dim.visible = true
	death_badge.visible = false

func _hide_death_modal() -> void:
	death_dim.visible = false
	death_badge.visible = true

func _restart() -> void:
	Audio.stop_all(0.2)
	Game.reset()
	LOCATIONS = _locations_initial.duplicate(true)
	for key in rows:
		for c in rows[key].get_children():
			rows[key].remove_child(c)
			c.queue_free()
	_death_shown = false
	death_layer.visible = false
	death_dim.visible = true
	death_badge.visible = false
	_populate()
	for m in bars:
		var d: Dictionary = bars[m]
		if d.has("tw") and d["tw"] != null:
			(d["tw"] as Tween).kill()
			d["tw"] = null
		d["bar"].value = Game.meters[m]
	Game.add_log("Day 1. You wake on the grounds of a great old house, cold to the bone and remembering little. Frost on the weeds, your breath white, no sound anywhere. A way in, somewhere past the overgrowth.")
	_refresh()
	_sync_world_audio()
	on_layout_changed()

func _populate() -> void:
	for loc in LOCATIONS:
		Game.location_ground[loc] = GROUND_START.get(loc, []).duplicate()
	# register the logistic stock for every renewable GROUND resource (idempotent across restart)
	for loc in LOCATIONS:
		# tell Game which locations sit under open sky, so gale/rain windfalls only reach outdoor stocks
		Game.set_location_indoor(loc, bool(LOCATIONS[loc].get("indoor", true)))
		for e in LOCATIONS[loc].get("pool", {}).get("renewable", []):
			if str((e as Dictionary).get("kind", "")) == "ground":
				Game.register_stock(loc, str(e["id"]), int(e.get("max", 1)))
	for id in ["canned_food", "plastic_bottle", "lighter"]:
		_spawn(id, "inv")
	_rebuild_out_there()
	_load_ground(Game.current_location)

func _rebuild_out_there() -> void:
	var row: CardRow = rows["top"]
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	var loc: Dictionary = LOCATIONS[Game.current_location]
	Game.location_indoor = bool(loc.get("indoor", true))
	# locations first (grouped left): current, then travel destinations
	var here := _spawn(Game.current_location, "top")
	here.set_location_badge("here")
	for conn in loc["connections"]:
		var cc := _spawn(conn, "top")
		cc.set_location_badge("travel")
	# then this location's fixtures/stations
	for fid in loc["fixtures"]:
		_spawn(fid, "top")
	if top_head:
		top_head.text = "OUT THERE   ·   " + str(loc["title"])

func _load_ground(loc: String) -> void:
	var row: CardRow = rows["middle"]
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	for entry in Game.location_ground.get(loc, []):
		if entry is Dictionary:
			var c := _spawn(str(entry["id"]), "middle")
			c.spoil_at = int(entry.get("spoil_at", -1))  # keep perishables aging on absolute time
		else:
			_spawn(str(entry), "middle")
	# renewables are NOT laid out on arrival; they are found only by SEARCHING (see _process_reveals),
	# which surfaces up to floor(stock). The stock is what is there to find, not scenery on the ground.
	_rot_food()  # catch anything that spoiled here while you were away, on arrival

func _save_ground(loc: String) -> void:
	var renewable := _renewable_ground_ids(loc)
	var ids: Array = []
	for c in rows["middle"].get_children():
		if c is CardIcon:
			var ci := c as CardIcon
			if str(ci.data.id) in renewable:
				continue  # renewable ground is re-derived from the stock on arrival, never persisted
			if ci.spoil_at >= 0:
				ids.append({"id": ci.data.id, "spoil_at": ci.spoil_at})
			else:
				ids.append(ci.data.id)
	Game.location_ground[loc] = ids

func _rot_food() -> void:
	# perishables past their spoil time turn to spoiled_meat, wherever they sit
	var rotting: Array = []
	for key in ["middle", "inv"]:
		if not rows.has(key):
			continue
		for c in rows[key].get_children():
			if c is CardIcon:
				var ci := c as CardIcon
				if ci.spoil_at >= 0 and ci.data.id != "spoiled_meat" and Game.spoil_stage(ci.spoil_at) == 2:
					rotting.append([ci, key])
	for pair in rotting:
		var rc: CardIcon = pair[0]
		Game.add_log("The %s has turned. It is not fit to eat now." % rc.data.title.to_lower())
		_consume_card(rc)
		_spawn("spoiled_meat", str(pair[1]))

func _travel_to(dest: String, mins: int) -> void:
	var from_loc := Game.current_location
	_save_ground(from_loc)
	var before := Game.meters.duplicate()
	Game.current_location = dest
	Game.location_indoor = bool(LOCATIONS[dest].get("indoor", true))
	if mins > 0:
		Audio.play_cue("travel_outdoor")
		# a real expedition out into the world: time passes and the light moves on
		Game.advance_time(mins)
		_show_time_passing(mins)
		Game.add_log("You set out. You reach %s as the light thins." % _place_prose(dest))
	else:
		Audio.play_cue("threshold_interior")
		# free movement within the base compound: a threshold, not a journey
		Game.add_log(_step_log(from_loc, dest))
	_animate_meters(before, {})
	_rebuild_out_there()
	_load_ground(dest)
	_last_present = {}  # a new region starts fresh; the next _refresh re-baselines its present counts

# The manor, its grounds, and the cellar are one base compound: moving between them is free.
# Those hops read as crossing a threshold, so they get their own prose, not the journey line.
func _step_log(from_loc: String, dest: String) -> String:
	if dest == "cellar":
		return "You head down into the cellar."
	if from_loc == "cellar":
		return "You climb back up into the house."
	if bool(LOCATIONS.get(dest, {}).get("indoor", true)):
		return "You step inside, out of the weather."
	return "You step out onto %s." % _place_prose(dest)

func _step_label(from_loc: String, dest: String) -> String:
	if dest == "cellar":
		return "Go down to the cellar"
	if from_loc == "cellar":
		return "Go back up into the house"
	if bool(LOCATIONS.get(dest, {}).get("indoor", true)):
		return "Go inside"
	return "Step out onto %s" % _place_prose(dest)

# ---------- exploration reveal pool ----------
func _pool_state(loc: String) -> Dictionary:
	if not Game.pool_state.has(loc):
		Game.pool_state[loc] = {"revealed": [], "rolls": {}, "renew": {}}
	return Game.pool_state[loc]

func _process_reveals(loc: String, old_pct: float, new_pct: float) -> void:
	var pool: Dictionary = LOCATIONS.get(loc, {}).get("pool", {})
	if pool.is_empty():
		return
	var st: Dictionary = _pool_state(loc)
	var finite: Array = pool.get("finite", [])
	for i in finite.size():
		if i in st["revealed"]:
			continue
		var e: Dictionary = finite[i]
		var thr: float = _entry_threshold(i, e, st)
		if new_pct >= thr and old_pct < thr:
			st["revealed"].append(i)
			_reveal(e, true)  # finite = looted from the place's limited stash
	_check_pool_stripped(loc, finite, st)
	var renew: Array = pool.get("renewable", [])
	for j in renew.size():
		var e2: Dictionary = renew[j]
		if str(e2.get("kind", "")) == "ground":
			# GROUND renewables: a search turns up at most ONE (rarely two), never the whole stock.
			# The stock is the ceiling you draw down over repeated searches, not a one-time dump.
			var room := Game.stock_count(loc, str(e2["id"])) - _renew_present(loc, e2)
			if room > 0:
				_reveal(e2)
				if room >= 2 and Game.rng.randf() < 0.15:
					_reveal(e2)  # now and then a search turns up a second
		else:
			# FIXTURE renewables (oak_tree, rat) keep the present-count cap + chance roll unchanged.
			var mx: int = int(e2.get("max", 1))
			if _renew_present(loc, e2) < mx and _roll_renewable(new_pct):
				_reveal(e2)

func _check_pool_stripped(loc: String, finite: Array, st: Dictionary) -> void:
	# grim note when a place's LIMITED loot is all taken. Only counts finite GROUND items whose id
	# does NOT also renew here, so a spot that keeps regrowing (e.g. stones) never reads "empty".
	if st.get("stripped", false):
		return
	var renew_ids := {}
	for r in LOCATIONS.get(loc, {}).get("pool", {}).get("renewable", []):
		renew_ids[str((r as Dictionary).get("id", ""))] = true
	var loot: Array = []
	for i in finite.size():
		var fe: Dictionary = finite[i]
		if str(fe.get("kind", "")) == "ground" and not renew_ids.has(str(fe.get("id", ""))):
			loot.append(i)
	if loot.is_empty():
		return
	for i in loot:
		if not (i in st["revealed"]):
			return  # still limited loot to find here
	st["stripped"] = true
	Game.add_log(str(LOCATIONS.get(loc, {}).get("stripped_log", "You have picked over the last of it. This place has nothing left to give up.")))

func _renewable_ground_ids(loc: String) -> Array:
	# the ids of this location's renewable pool entries with kind == "ground" (deduplicated)
	var out: Array = []
	for e in LOCATIONS.get(loc, {}).get("pool", {}).get("renewable", []):
		if str((e as Dictionary).get("kind", "")) == "ground":
			var id := str(e.get("id", ""))
			if id != "" and not (id in out):
				out.append(id)
	return out

func _renew_present(loc: String, e: Dictionary) -> int:
	if e.get("kind", "") == "fixture":
		return 1 if e["id"] in LOCATIONS.get(loc, {}).get("fixtures", []) else 0
	var n := 0
	if rows.has("middle"):
		for c in rows["middle"].get_children():
			if c is CardIcon and c.data.id == e["id"]:
				n += 1
	return n

func _entry_threshold(i: int, e: Dictionary, st: Dictionary) -> float:
	if e.has("milestone"):
		return float(e["milestone"])
	if e.has("between"):
		if not st["rolls"].has(i):
			var b: Array = e["between"]
			st["rolls"][i] = randf_range(float(b[0]), float(b[1]))
		return float(st["rolls"][i])
	return 101.0

func _roll_renewable(pct: float) -> bool:
	var chance := 0.7 if pct >= 100.0 else 0.3
	return randf() < chance

func _reveal(e: Dictionary, is_loot := false) -> bool:
	var loc := Game.current_location
	match e["kind"]:
		"flavor":
			Game.add_log(str(e.get("log", "")))  # a one-time, log-only discovery beat (no card)
			return true
		"ground":
			var gc := _spawn(e["id"], "middle")
			if e.has("content"):
				gc.fill_with(str(e["content"]), float(e.get("fill", 100.0)))
			var default_log: String = ("You turn up %s among what the place still holds." % _card_title(e["id"]).to_lower()) if is_loot else ("You turn up: %s." % _card_title(e["id"]))
			Game.add_log(str(e.get("log", default_log)))
			Audio.play_cue("ui_item_revealed")
			return true
		"fixture":
			var fxs: Array = LOCATIONS[loc]["fixtures"]
			if e["id"] in fxs:
				return false
			fxs.append(e["id"])
			Game.add_log(str(e.get("log", "You uncover the %s." % _card_title(e["id"]))))
			Audio.play_cue("ui_item_revealed")
			_rebuild_out_there()
			return true
		"location":
			var conns: Dictionary = LOCATIONS[loc]["connections"]
			if conns.has(e["id"]):
				return false
			conns[e["id"]] = int(e.get("mins", 30))
			Game.add_log(str(e.get("log", "A way opens toward %s." % _place_prose(e["id"]))))
			Audio.play_cue("ui_item_revealed")
			_rebuild_out_there()
			return true
	return false

func _card_title(id: String) -> String:
	if CARD_FILES.has(id):
		var d: CardData = load(CARD_FILES[id])
		return d.title
	return id

func _location_title(id: String) -> String:
	return str(LOCATIONS.get(id, {}).get("title", id))

func _place_prose(loc_id: String) -> String:
	# Log/prose name: the terse title, with "the" where it reads naturally ("the Woods").
	var l: Dictionary = LOCATIONS.get(loc_id, {})
	var t: String = str(l.get("title", loc_id))
	return ("the " + t) if l.get("the", false) else t

func _travel_mins(from_id: String, to_id: String) -> int:
	# Travel time belongs to the edge, not the destination, so a trip costs the same both ways.
	var conns: Dictionary = LOCATIONS.get(from_id, {}).get("connections", {})
	return int(conns.get(to_id, 30))

func _spawn(id: String, row_key: String) -> CardIcon:
	var data: CardData = load(CARD_FILES[id])
	var card := CardIcon.new()
	rows[row_key].add_child(card)
	card.setup(data, self)
	return card

func _consume_card(c: CardIcon) -> void:
	var p := c.get_parent()
	if p:
		p.remove_child(c)
	c.queue_free()

# Right-click MOVES a movable card. With no buildsite open it toggles between
# your inventory and the current area's ground (3c adds "into an open buildsite").
func on_card_right_clicked(card: CardIcon) -> void:
	if Game.dead or not card.mobile:
		return
	var parent := card.get_parent()
	if parent == rows.get("inv"):
		_move_card(card, "middle")
		Audio.play_cue("ui_card_place")
		Game.add_log("You set the %s down here." % card.data.title.to_lower())
	elif parent == rows.get("middle"):
		if rows["inv"].get_child_count() >= INV_CAP:
			Game.add_log("Your hands and pockets are full.")
			return
		_move_card(card, "inv")
		Audio.play_cue("ui_card_place")
		Game.add_log("You pick up the %s." % card.data.title.to_lower())
	else:
		return
	on_layout_changed()

func _move_card(card: CardIcon, dest_key: String) -> void:
	var id: String = card.data.id
	_consume_card(card)
	_spawn(id, dest_key)

func _transform_fixture(card: CardIcon, new_id: String) -> void:
	var loc := Game.current_location
	var fxs: Array = LOCATIONS[loc]["fixtures"]
	fxs.erase(card.data.id)
	Game.card_state.erase(card.data.id)
	Game.add_log("The %s comes down at last." % card.data.title.to_lower())
	_spawn(new_id, "middle")
	_rebuild_out_there()

# swap one FIXTURE for another in place (stays in the location row), e.g. broken hearth -> hearth
func _swap_fixture(old_id: String, new_id: String) -> void:
	var loc := Game.current_location
	var fxs: Array = LOCATIONS[loc]["fixtures"]
	var idx := fxs.find(old_id)
	Game.card_state.erase(old_id)
	# replace in place so the rebuilt fixture keeps its slot in the row (no reposition)
	if new_id in fxs:
		if idx != -1:
			fxs.remove_at(idx)
	elif idx != -1:
		fxs[idx] = new_id
	else:
		fxs.append(new_id)
	_rebuild_out_there()

# ---------- trapping ----------
func _set_snare(card: CardIcon, mins: int) -> void:
	var loc := Game.current_location
	if Game.location_indoor:
		_blocked("There is nothing to catch in here. A snare wants open ground.")
		return
	var fxs: Array = LOCATIONS[loc]["fixtures"]
	if "set_snare" in fxs:
		_blocked("You already have a snare set here.")
		return
	Game.place_snare(loc)
	Audio.play_cue("snare_set")
	fxs.append("set_snare")
	_consume_card(card)
	Game.advance_time(mins)
	_show_time_passing(mins)
	Game.add_log("You set the snare low against a run in the brush and cover your tracks. Now the waiting.")
	_rebuild_out_there()
	on_layout_changed()

func _check_snare(mins: int) -> void:
	var loc := Game.current_location
	Game.advance_time(mins)
	_show_time_passing(mins)
	if Game.snare_ready(loc):
		Audio.play_cue("snare_catch")
		for yid in Game.collect_snare(loc):
			_spawn(str(yid), "middle")
		Game.add_log("The noose has pulled tight on something small. Meat, and a hide worth keeping.")
	else:
		Audio.play_cue("snare_empty")
		Game.add_log("The snare sits sprung on nothing. No catch yet.")
	on_layout_changed()

# ---------- recipes / drag ----------
func recipe_for(item_id: String, target_id: String) -> Variant:
	if RECIPES.has(item_id) and RECIPES[item_id].has(target_id):
		return RECIPES[item_id][target_id]
	return null

func _is_recipe_target(id: String) -> bool:
	for src in RECIPES:
		if RECIPES[src].has(id):
			return true
	return false

func on_drag_begin(card: CardIcon) -> void:
	_dragging = card
	Audio.play_cue("ui_card_lift")

func on_card_reordered() -> void:
	Audio.play_cue("ui_card_place")
	on_layout_changed()

func on_drag_end() -> void:
	_dragging = null
	_hide_hint()

func _hide_hint() -> void:
	if hint_box:
		hint_box.visible = false

func _process(_dt: float) -> void:
	if _dragging == null or not is_instance_valid(_dragging):
		_dragging = null
		return
	var mp := get_global_mouse_position()
	var target: CardIcon = null
	for key in rows:
		for c in rows[key].get_children():
			if not (c is CardIcon) or c == _dragging:
				continue
			var ci: CardIcon = c
			if ci.get_global_rect().has_point(mp) and recipe_for(_dragging.data.id, ci.data.id) != null:
				target = ci
				break
		if target != null:
			break
	if target != null:
		var rec: Dictionary = recipe_for(_dragging.data.id, target.data.id)
		hint_label.text = "%s   (%dm)" % [rec["label"], int(rec["mins"])]
		hint_box.reset_size()
		var tr := target.get_global_rect()
		hint_box.position = Vector2(tr.position.x + tr.size.x * 0.5 - hint_box.size.x * 0.5, tr.position.y - hint_box.size.y - 8.0)
		hint_box.visible = true
	else:
		_hide_hint()

func perform_recipe(src: CardIcon, target: CardIcon, rec: Dictionary) -> void:
	if Game.dead:
		on_drag_end()
		return
	if target.data.state_kind == "water" and target.state_value <= 0.0:
		_blocked("The %s is empty." % target.data.title.to_lower())
		on_drag_end()
		return
	var before := Game.meters.duplicate()
	var fx := {}
	if rec.has("effect"):
		match rec["effect"]:
			"add_fuel":
				target.set_state(target.state_value + float(rec.get("amount", 40)))
				if Game.is_fire_lit():
					Game.add_log("You feed the fire. It flares: warm, bright, and loud.")
					fx = {"Warmth": 8.0}
				else:
					Game.add_log("You lay wood in the cold grate. It only wants a light now.")
				_consume_card(src)
			"light_tinder":
				if src.state_value <= 0.0:
					_blocked("The lighter sparks and dies. No charge left.")
					on_drag_end()
					return
				src.set_state(src.state_value - 1.0)
				_consume_card(target)
				_spawn("burning_tinder", "middle")
				Game.add_log("You thumb the lighter; the tinder catches and curls into flame.")
			"set_alight":
				Game.lit_sources[target.data.id] = true
				if target.state_value <= 0.0:
					target.set_state(1.0)
				_consume_card(src)
				Game.add_log("You feed the burning tinder in. The fire takes: warm light, and a beacon.")
			"steep_remedy":
				if not Game.is_fire_lit():
					_blocked("You need a live fire to steep them.")
					on_drag_end()
					return
				_consume_card(src)
				_spawn("herbal_remedy", "middle")
				Game.add_log("You steep the herbs over the fire into a bitter, cloudy tea.")
				Game.gain_skill("cooking", 2.5)
			"cook":
				if not Game.is_fire_lit():
					_blocked("You need a live fire to cook it.")
					on_drag_end()
					return
				_consume_card(src)
				_spawn(str(rec.get("spawn", "")), "middle")
				Game.add_log("You spit the meat and hold it to the flame until it browns and spits fat.")
				Game.gain_skill("cooking", 2.0)
			"smoke":
				if not Game.is_fire_lit():
					_blocked("You need a live fire to smoke it.")
					on_drag_end()
					return
				_consume_card(src)
				_spawn(str(rec.get("spawn", "")), "middle")
				Game.add_log("You hang the meat low in the smoke and tend it for hours, until it goes dark and dry and will keep.")
				Game.gain_skill("cooking", 1.5)
	elif src.data.is_container and target.data.id == "lighter":
		if src.content != "fuel" or src.state_value <= 0.0:
			_blocked("There's no fuel in the %s to draw from." % src.data.title.to_lower())
			on_drag_end()
			return
		var room: float = 100.0 - target.state_value
		if room <= 0.0:
			_blocked("The lighter is already full.")
			on_drag_end()
			return
		var moved: float = minf(room, src.state_value)
		target.set_state(target.state_value + moved)
		src.drain_content(moved)
		Game.add_log("You top the lighter up from the %s." % src.data.title.to_lower())
	elif src.data.is_container and target.data.is_container:
		if src.content == "":
			_blocked("The %s is empty." % src.data.title.to_lower())
			on_drag_end()
			return
		var room: float = target.data.capacity - target.state_value
		if room <= 0.0:
			_blocked("The %s is already full." % target.data.title.to_lower())
			on_drag_end()
			return
		var moved: float = minf(src.state_value, room)
		var poured: String = src.content
		var target_was: String = target.content
		if not target.fill_with(src.content, moved):
			_blocked("You can't mix %s and %s." % [target._content_display(target.content).to_lower(), src._content_display(src.content).to_lower()])
			on_drag_end()
			return
		src.drain_content(moved)
		if target.content == "dirty_water" and (target_was == "water" or poured == "water"):
			Game.add_log("The clean water clouds as it meets the dirty. It needs boiling again.")
		else:
			Game.add_log("You pour %s into the %s." % [src._content_display(poured).to_lower(), target.data.title.to_lower()])
	elif src.data.is_container and target.data.id == "hearth":
		if src.content != "dirty_water" or src.state_value <= 0.0:
			_blocked("There's no dirty water in the %s to boil." % src.data.title.to_lower())
			on_drag_end()
			return
		if not Game.is_fire_lit():
			_blocked("You need a live fire to boil it.")
			on_drag_end()
			return
		src.boil()
		Game.add_log("You set the %s by the fire until it steams. The water runs clean." % src.data.title.to_lower())
		Game.gain_skill("cooking", 2.0)
	elif src.data.is_container and (target.data.id == "stream" or target.data.id == "rain_barrel"):
		var room: float = src.data.capacity - src.state_value
		if room <= 0.0:
			_blocked("The %s is already full." % src.data.title.to_lower())
			on_drag_end()
			return
		var avail: float = target.state_value if target.data.state_kind == "water" else room
		var moved2: float = minf(room, avail)
		if moved2 <= 0.0:
			_blocked("The %s is empty." % target.data.title.to_lower())
			on_drag_end()
			return
		var src_was: String = src.content
		if not src.fill_with("dirty_water", moved2):
			_blocked("The %s already holds %s." % [src.data.title.to_lower(), src._content_display(src.content).to_lower()])
			on_drag_end()
			return
		if target.data.state_kind == "water":
			target.set_state(target.state_value - moved2)
		if src_was == "water":
			Game.add_log("The clean water in the %s clouds with dirt. It needs boiling again." % src.data.title.to_lower())
		else:
			Game.add_log("You fill the %s with cold, clouded water." % src.data.title.to_lower())
	for k in fx:
		Game.modify(k, fx[k])
	if rec.has("audio"):
		Audio.play_cue(str(rec["audio"]))
	elif src.data.is_container and target.data.id == "lighter":
		Audio.play_cue("liquid_pour", -4.0)
	elif src.data.is_container and target.data.is_container:
		Audio.play_cue("liquid_pour")
	elif src.data.is_container and target.data.id == "hearth":
		Audio.play_cue("water_boiling")
	elif src.data.is_container and (target.data.id == "stream" or target.data.id == "rain_barrel"):
		Audio.play_cue("water_fill")
	var rmins := int(rec.get("mins", 10))
	Game.advance_time(rmins)
	_show_time_passing(rmins)
	on_drag_end()
	_animate_meters(before, fx)
	on_layout_changed()

# ---------- click menu ----------
func _container_actions(card: CardIcon) -> Array:
	# Any container holding a drinkable liquid can be drunk from.
	if card.content == "dirty_water":
		return [{"label": "Drink (5m)", "mins": 5, "drink": true, "clean": false}]
	elif card.content == "water":
		return [{"label": "Drink (5m)", "mins": 5, "drink": true, "clean": true}]
	return []

func _do_drink(card: CardIcon, clean: bool, mins: int) -> void:
	# every drink pulls one SIP (or the last of what's there, for less hydration)
	if card.data.id == "stream" and float(Game.card_state.get("stream", 100.0)) <= 15.0:
		Game.add_log(Game.STREAM_DRY_LINE)  # a drought has slowed it to nothing
		return
	var infinite := card.data.id == "stream"  # a flowing stream doesn't deplete; drought gates it (above)
	var avail: float = SIP if infinite else card.state_value
	if not infinite and avail <= 0.0:
		Game.add_log("The %s is empty." % card.data.title.to_lower())
		return
	var drunk: float = minf(SIP, avail)
	Audio.play_cue("drink")
	var frac: float = drunk / SIP
	var before := Game.meters.duplicate()
	var fx := {"Hydration": (20.0 if clean else 18.0) * frac}
	if not clean:
		fx["Immune"] = -6.0 * frac
	for k in fx:
		Game.modify(k, fx[k])
	if not clean:
		Game.add_condition("gut_bug", 20.0 * frac, "unboiled water")
	if not infinite:
		if card.data.is_container:
			card.drain_content(drunk)
		else:
			card.set_state(card.state_value - drunk)
	Game.advance_time(mins)
	_show_time_passing(mins)
	var partial := drunk < SIP - 0.01
	if clean:
		Game.add_log("You get a last clean mouthful before it runs dry." if partial else "Clean water, boiled and left to cool. It goes down easy.")
	else:
		Game.add_log("You drain the last gritty dregs, barely a mouthful." if partial else "You drink it unboiled, cold and gritty. Your gut may regret it.")
	_animate_meters(before, fx)
	on_layout_changed()

func on_card_clicked(card: CardIcon) -> void:
	_menu_card = card
	_detail_mode = "card"
	if card.data.kind == "location" and card.data.id != Game.current_location:
		var mins: int = _travel_mins(Game.current_location, card.data.id)
		var tlabel: String = _step_label(Game.current_location, card.data.id) if mins <= 0 else ("Travel to %s (%dm)" % [_place_prose(card.data.id), mins])
		_menu_actions = [{"label": tlabel, "travel_to": card.data.id, "mins": mins}]
	elif card.data.is_container:
		_menu_actions = _container_actions(card)
	else:
		_menu_actions = ACTIONS.get(card.data.id, [])
	_open_detail()

func _open_menu() -> void:
	for c in menu_vbox.get_children():
		menu_vbox.remove_child(c)
		c.queue_free()
	for i in _menu_actions.size():
		var b := Button.new()
		b.text = _menu_actions[i]["label"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2.ZERO
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", WARM_SOFT)
		b.add_theme_font_size_override("font_size", 13)
		var sb_n := StyleBoxEmpty.new()
		sb_n.content_margin_left = 8.0
		sb_n.content_margin_right = 8.0
		sb_n.content_margin_top = 3.0
		sb_n.content_margin_bottom = 3.0
		b.add_theme_stylebox_override("normal", sb_n)
		b.add_theme_stylebox_override("pressed", sb_n)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var sb_h := StyleBoxFlat.new()
		sb_h.bg_color = Color(0.129, 0.180, 0.235)
		sb_h.set_corner_radius_all(4)
		sb_h.content_margin_left = 8.0
		sb_h.content_margin_right = 8.0
		sb_h.content_margin_top = 3.0
		sb_h.content_margin_bottom = 3.0
		b.add_theme_stylebox_override("hover", sb_h)
		b.pressed.connect(_on_menu_pick.bind(i))
		menu_vbox.add_child(b)
	menu_panel.reset_size()
	menu_panel.position = get_global_mouse_position()
	menu_layer.visible = true
	_clamp_menu.call_deferred()

func _open_char_menu() -> void:
	if Game.dead:
		return
	_menu_card = null
	_detail_mode = "card"
	_menu_actions = [
		{"label": "Rest (15m)", "mins": 15, "fx": {"Mental": 3.0}, "log": "You sit a while, eyes shut. Not sleep, but it steadies you a little."},
		{"label": "Sleep until rested", "sleep": true},
	]
	if Game.worn != "":
		_menu_actions.append({"label": "Take off the %s" % _card_title(Game.worn).to_lower(), "take_off": true})
	_open_detail()

func _on_portrait_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_open_char_menu()

func _sleep() -> void:
	Audio.play_cue("sleep_settle")
	var before := Game.meters.duplicate()
	var guard := 0
	var _t0 := Game.day * 1440 + Game.minute
	while guard < 48 and not Game.dead and Game.fatigue > 0.0:
		guard += 1
		Game.advance_time(30, true)
		if Game.meters["Hydration"] < 10.0 or Game.meters["Calories"] < 10.0 or Game.meters["Warmth"] < 10.0:
			var hyd: float = Game.meters["Hydration"]
			var cal: float = Game.meters["Calories"]
			var wrm: float = Game.meters["Warmth"]
			if wrm <= hyd and wrm <= cal:
				Game.add_log("You jolt awake shivering, too cold to lie still. A ruined night.")
			elif hyd <= cal:
				Game.add_log("You jolt awake with your throat like paper, too parched to sleep. A ruined night.")
			else:
				Game.add_log("You jolt awake with your stomach clawing at itself, too hungry to rest. A ruined night.")
			break
	_show_time_passing(Game.day * 1440 + Game.minute - _t0)
	if not Game.dead and Game.fatigue <= 0.0:
		Game.add_log("You sleep hard and wake clear-headed. The debt is paid.")
	_animate_meters(before, {})
	on_layout_changed()

func _collapse_sleep() -> void:
	if Game.dead:
		return
	_collapsing = true
	Audio.play_cue("collapse")
	var before := Game.meters.duplicate()
	Game.add_log("Your legs go. You are asleep before you hit the floor.")
	var guard := 0
	var _t0 := Game.day * 1440 + Game.minute
	while guard < 48 and not Game.dead and Game.fatigue > 0.0:
		guard += 1
		Game.advance_time(30, true)
		if Game.meters["Hydration"] < 5.0 or Game.meters["Calories"] < 5.0 or Game.meters["Warmth"] < 5.0:
			break  # wake before a cold/thirst/hunger collapse turns lethal
	_show_time_passing(Game.day * 1440 + Game.minute - _t0)
	if not Game.dead:
		Game.meters["Energy"] = maxf(Game.meters["Energy"], 20.0)
	_animate_meters(before, {})
	on_layout_changed()
	_collapsing = false

func _clamp_menu() -> void:
	var vp := get_viewport_rect().size
	var pos := menu_panel.position
	var sz := menu_panel.size
	pos.x = clampf(pos.x, 4.0, maxf(4.0, vp.x - sz.x - 4.0))
	pos.y = clampf(pos.y, 4.0, maxf(4.0, vp.y - sz.y - 4.0))
	menu_panel.position = pos

func _on_catcher_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_hide_menu()

func _hide_menu() -> void:
	menu_layer.visible = false

func _on_menu_pick(i: int) -> void:
	_hide_menu()
	if i >= 0 and i < _menu_actions.size():
		_perform(_menu_card, _menu_actions[i])

func _perform(card: CardIcon, act: Dictionary) -> void:
	if Game.dead:
		return
	if act.has("sleep"):
		_sleep()
		return
	if act.has("travel_to"):
		_travel_to(act["travel_to"], int(act.get("mins", 30)))
		return
	if act.has("wear"):
		Audio.play_cue("coat_on_off")
		Game.worn = str(act["wear"])
		if act.has("log"):
			Game.add_log(str(act["log"]))
		if card != null:
			_consume_card(card)  # it is on your back now, not a loose card
		on_layout_changed()
		return
	if act.has("take_off"):
		var wid: String = Game.worn
		Game.worn = ""
		if wid != "":
			Audio.play_cue("coat_on_off")
			var row_key := "inv" if (rows.has("inv") and rows["inv"].get_child_count() < INV_CAP) else "middle"
			_spawn(wid, row_key)
			Game.add_log("You shrug the %s off." % _card_title(wid).to_lower())
		on_layout_changed()
		return
	if act.get("needs_fire", false) and not Game.is_fire_lit():
		Game.add_log("There is no fire lit.")
		return
	if act.has("drink"):
		_do_drink(card, bool(act.get("clean", false)), int(act.get("mins", 5)))
		return
	if act.has("fight"):
		_start_combat(card.data.id, card)
		return
	if act.has("place_snare"):
		_set_snare(card, int(act.get("mins", 10)))
		return
	if act.has("check_snare"):
		_check_snare(int(act.get("mins", 10)))
		return
	if act.has("radio_listen"):
		var was_powered := Game.radio_powered
		var previous_broadcast_day := Game.radio_last_broadcast_day
		var line := Game.radio_listen()
		Audio.play_radio_listen(was_powered, Game.radio_last_broadcast_day != previous_broadcast_day)
		var rbefore := Game.meters.duplicate()
		var rfx: Dictionary = act.get("fx", {})
		for k in rfx:
			Game.modify(k, rfx[k])
		var rmins := int(act.get("mins", 15))
		Game.advance_time(rmins)
		_show_time_passing(rmins)
		Game.add_log(line)
		_animate_meters(rbefore, rfx)
		on_layout_changed()
		return
	if act.has("buildsite"):
		_open_buildsite(str(act["buildsite"]))  # a fixture built through the construction popup, in phases
		return
	if act.has("state_delta"):
		var d: float = act["state_delta"]
		if d < 0.0 and card.state_value <= 0.0:
			Game.add_log("The %s is empty." % card.data.title.to_lower())
			return
		if d > 0.0 and card.data.state_kind == "fell" and card.state_value >= 100.0:
			Game.add_log("The %s is already felled." % card.data.title.to_lower())
			return
	if act.has("cure"):
		var any_active := false
		for cid in act["cure"]:
			if Game.conditions.get(cid, 0.0) > 0.0:
				any_active = true
		if not any_active:
			Game.add_log("There's nothing it would help right now.")
			return
	var before := Game.meters.duplicate()
	var fx: Dictionary = act.get("fx", {})
	for k in fx:
		Game.modify(k, fx[k])
	if act.has("cond"):
		for cid in act["cond"]:
			Game.add_condition(cid, float(act["cond"][cid]), str(act.get("cond_cause", "")))
	if act.has("cure"):
		for cid in act["cure"]:
			Game.cure_condition(cid, float(act["cure"][cid]))
	var _mins := int(act.get("mins", 30))
	if act.has("audio"):
		Audio.play_cue(str(act["audio"]))
	if float(fx.get("Energy", 0.0)) < 0.0:
		_mins = int(round(float(_mins) * Game.weight_toll()))  # overweight = physical work runs longer
	var wood_work: bool = card != null and (card.data.state_kind == "fell" or card.data.state_kind == "wood")
	if wood_work:
		_mins = maxi(1, int(round(float(_mins) * Game.wood_speed())))  # skill makes wood work quicker
	Game.advance_time(_mins)
	_show_time_passing(_mins)
	if wood_work:
		Game.gain_skill("woodworking", 3.0)
	if act.has("log"):
		Game.add_log(act["log"])
	if act.has("once_log") and Game.mark_beat(str(act.get("once_key", act["once_log"]))):
		Game.add_log(str(act["once_log"]))  # a one-time narrative beat, shown only the first time
	if act.has("state_delta"):
		var old_pct: float = card.state_value
		card.set_state(card.state_value + act["state_delta"])
		if card.data.kind == "location":
			_process_reveals(card.data.id, old_pct, card.state_value)
		elif card.data.state_kind == "fell" and card.state_value >= 100.0 and card.data.becomes != "":
			Audio.play_cue("wood_oak_fall")
			_transform_fixture(card, card.data.becomes)
		elif card.data.state_kind == "wood" and card.state_value <= 0.0:
			Game.add_log("The %s is split down to the last of it." % card.data.title.to_lower())
			_consume_card(card)
	if act.has("spawn"):
		_spawn(act["spawn"], "middle")
	if act.get("consume", false):
		_consume_card(card)
	_animate_meters(before, fx)
	on_layout_changed()

# ---------- feedback ----------
func _animate_meters(_before: Dictionary, fx: Dictionary) -> void:
	# Bars ease to their true new value; the popped label shows the ACTION's own
	# modifier (e.g. -8 Energy), not the net including drain.
	for m in bars:
		_tween_bar(m, Game.meters[m])
	for m in fx:
		if not bars.has(m):
			continue
		var amt: float = fx[m]
		if absf(amt) >= 1.0:
			_spawn_diff_label(bars[m]["bar"], amt)

func _tween_bar(m: String, target: float) -> void:
	var d: Dictionary = bars[m]
	if d.has("tw") and d["tw"] != null:
		(d["tw"] as Tween).kill()
	var tw := create_tween()
	tw.tween_interval(0.55)              # hold — let the diff highlight read first
	tw.tween_property(d["bar"], "value", target, 0.6)  # then animate the change
	d["tw"] = tw

func _spawn_diff_label(bar: Control, net: float) -> void:
	var lbl := _label(("+%d" % int(round(net))) if net > 0.0 else ("%d" % int(round(net))), GREEN if net > 0.0 else BLOOD, 20)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(lbl)
	lbl.position = bar.global_position + Vector2(bar.size.x * 0.5 - 14.0, -24.0)
	var tw := create_tween()
	tw.tween_interval(1.25)             # hold clearly visible, past the bar animation
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 24.0, 0.7)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)

func on_layout_changed() -> void:
	if inv_head and rows.has("inv"):
		inv_head.text = "INVENTORY   ·   %d / %d" % [rows["inv"].get_child_count(), INV_CAP]

func _blocked(line: String) -> void:
	Game.add_log(line)
	Audio.play_cue("ui_action_blocked")

func _sync_world_audio() -> void:
	Audio.set_location(Game.current_location)
	Audio.set_hearth_active(Game.current_location == "lordly_manor" and Game.is_fire_lit())

func _refresh() -> void:
	_sync_world_audio()
	if clock_label:
		clock_label.text = Game.time_string()
	if temp_label:
		var indoors: bool = LOCATIONS.get(Game.current_location, {}).get("indoor", true)
		var t: float = Game.temperature if indoors else Game.outdoor_temp
		var where := "Indoors" if indoors else "Outside"
		temp_label.text = "%s   %d°C   %s" % [where, int(round(t)), Game.temp_word(t)]
		temp_label.add_theme_color_override("font_color", COLD if t < 12.0 else WARM)
	for m in bars:
		var v: float = Game.meters[m]
		var c := COLD
		if v < 20.0:
			c = BLOOD
		elif v < 45.0:
			c = WARM
		bars[m]["fill"].bg_color = c
		bars[m]["bar"].tooltip_text = Game.need_tooltip(m)
		bars[m]["bar"].queue_redraw()
	if fatigue_bar:
		fatigue_bar.value = Game.fatigue
	if weight_bar:
		weight_bar.value = Game.weight
		var wc := GREEN
		if Game.weight < 20.0 or Game.weight > 85.0:
			wc = BLOOD
		elif Game.weight < 30.0 or Game.weight > 78.0:
			wc = WARM
		weight_fill.bg_color = wc
		weight_bar.queue_redraw()
	if log_label:
		log_label.text = "\n".join(PackedStringArray(Game.log_lines))
	# keep card state bars (e.g. the hearth fuel burning down) in sync with the model
	for key in rows:
		for c in rows[key].get_children():
			if c is CardIcon:
				(c as CardIcon).sync_state()
	# HARVEST DETECTION (single chokepoint): any DROP in a renewable ground id's present count is a
	# harvest (eat / pick up / craft / feed the fire / drag). Surfacing only ever RAISES present, so
	# it is never a false harvest. The stock is pulled down by the exact number removed.
	if rows.has("middle"):
		var hloc := Game.current_location
		for id in _renewable_ground_ids(hloc):
			var present := 0
			for c in rows["middle"].get_children():
				if c is CardIcon and str((c as CardIcon).data.id) == id:
					present += 1
			var last := int(_last_present.get(id, present))
			if present < last:
				Game.harvest_stock(hloc, id, last - present)
			_last_present[id] = present
	_rot_food()
	# condition chips: show only conditions that have surfaced (stage >= 1)
	if cond_tray:
		for c in cond_tray.get_children():
			cond_tray.remove_child(c)
			c.queue_free()
		for id in Game.conditions:
			var cst: int = Game.cond_stage.get(id, 0)
			if cst <= 0:
				continue
			var stg: Dictionary = Game.CONDITIONS[id]["stages"][cst]
			cond_tray.add_child(_make_cond_bar(id, str(stg["name"]), float(Game.conditions[id]), cst, Game.cond_trajectory(id)))
	if weather_label:
		weather_label.text = Game.weather_line()
	if Game.force_sleep and not Game.dead and (not combat_layer or not combat_layer.visible):
		Game.force_sleep = false
		if not _collapsing:
			_collapse_sleep.call_deferred()
	if Game.pending_siege > 0 and not Game.dead and (not combat_layer or not combat_layer.visible) and not _collapsing:
		var _waves: int = Game.pending_siege
		Game.pending_siege = 0
		_start_siege.call_deferred(_waves)
	if Game.dead and not _death_shown and (not combat_layer or not combat_layer.visible):
		_death_shown = true
		_show_death()
