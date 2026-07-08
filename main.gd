extends Control
## Dead Air — table view.
## LEFT (character + condition) | CENTER (3 card rows) | RIGHT (time / temp / log).
## Single-card actions: click a card -> menu. Two-card actions: drag a card onto a
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
const PLAYER_STRIKE := 10.0  ## unarmed base damage per Strike (varies: miss/glance/solid/good)
const COMBAT_ROUND_MINS := 3  ## in-game minutes each combat swing/round takes
var ENEMIES := {
	"rat": {"name": "Rat", "hp": 8.0, "damage": 6.0, "flee_hit": 2.0, "verb": "bites", "mins": 5},
	"zombie": {"name": "Zombie", "hp": 34.0, "damage": 15.0, "flee_hit": 9.0, "verb": "tears at", "bite_infection": 20.0, "mins": 10},
}

const CARD_FILES := {
	"hearth": "res://data/cards/hearth.tres",
	"oak_tree": "res://data/cards/oak_tree.tres",
	"lordly_manor": "res://data/cards/lordly_manor.tres",
	"rain_barrel": "res://data/cards/rain_barrel.tres",
	"the_woods": "res://data/cards/the_woods.tres",
	"firewood": "res://data/cards/firewood.tres",
	"dirty_water": "res://data/cards/dirty_water.tres",
	"canned_food": "res://data/cards/canned_food.tres",
	"bandage": "res://data/cards/bandage.tres",
	"matches": "res://data/cards/matches.tres",
	"wool_blanket": "res://data/cards/wool_blanket.tres",
	"cellar": "res://data/cards/cellar.tres",
	"stream": "res://data/cards/stream.tres",
	"forage_food": "res://data/cards/forage_food.tres",
	"log": "res://data/cards/log.tres",
	"gas_canister": "res://data/cards/gas_canister.tres",
	"plastic_bottle": "res://data/cards/plastic_bottle.tres",
	"lighter": "res://data/cards/lighter.tres",
	"tinder": "res://data/cards/tinder.tres",
	"burning_tinder": "res://data/cards/burning_tinder.tres",
	"herbs": "res://data/cards/herbs.tres",
	"herbal_remedy": "res://data/cards/herbal_remedy.tres",
	"antibiotics": "res://data/cards/antibiotics.tres",
	"rat": "res://data/cards/rat.tres",
	"zombie": "res://data/cards/zombie.tres",
	"radio": "res://data/cards/radio.tres",
}

## Locations: the fixtures/stations present there, and where you can travel from it.
var LOCATIONS := {
	"lordly_manor": {"title": "Lordly Manor", "indoor": true, "fixtures": ["hearth", "rain_barrel", "radio"], "connections": {"the_woods": 45},
		"pool": {"finite": [{"kind": "location", "id": "cellar", "milestone": 50, "mins": 5}, {"kind": "ground", "id": "canned_food", "between": [15, 85]}], "renewable": []}},
	"the_woods": {"title": "Woods", "the": true, "indoor": false, "fixtures": ["oak_tree"], "connections": {"lordly_manor": 45},
		"pool": {"finite": [{"kind": "fixture", "id": "stream", "milestone": 30}, {"kind": "fixture", "id": "zombie", "milestone": 45, "log": "Something moves between the trees, slow and wrong. It turns toward you."}], "renewable": [{"kind": "ground", "id": "forage_food", "max": 3}, {"kind": "ground", "id": "tinder", "max": 3}, {"kind": "fixture", "id": "oak_tree", "max": 3, "log": "Deeper in, you find another good oak."}, {"kind": "ground", "id": "herbs", "max": 3}, {"kind": "ground", "id": "firewood", "max": 3}]}},
	"cellar": {"title": "Cellar", "the": true, "indoor": true, "fixtures": [], "connections": {"lordly_manor": 5},
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
		{"label": "Sit by the fire (30m)", "mins": 30, "needs_fire": true, "fx": {"Warmth": 15.0, "Mental": 3.0}, "log": "You sit close and let the warmth reach your hands."},
	],
	"oak_tree": [
		{"label": "Fell the tree (30m)", "mins": 30, "fx": {"Energy": -8.0, "Calories": -7.0, "Hydration": -6.0, "Warmth": 5.0}, "state_delta": 50.0, "log": "You swing until your shoulders burn. The old oak groans a little lower."},
	],
	"the_woods": [
		{"label": "Forage (45m)", "mins": 45, "fx": {"Energy": -6.0, "Mental": 2.0, "Calories": -6.0, "Hydration": -5.0, "Warmth": 3.0}, "state_delta": 8.0, "log": "You move quiet through the trees. A few late berries, kindling, tracks that are not yours."},
	],
	"lordly_manor": [
		{"label": "Search the Manor (30m)", "mins": 30, "fx": {"Mental": -1.0}, "state_delta": 15.0, "log": "You search the cold rooms. A door you had not tried opens onto stairs going down."},
	],
	"rain_barrel": [
		{"label": "Drink from the barrel (5m)", "mins": 5, "drink": true, "clean": false},
	],
	"stream": [
		{"label": "Drink from the stream (5m)", "mins": 5, "drink": true, "clean": false},
	],
	"canned_food": [
		{"label": "Eat cold (15m)", "mins": 15, "fx": {"Calories": 30.0, "Mental": 1.0}, "consume": true, "log": "You eat cold from the tin. It helps, a little."},
	],
	"wool_blanket": [
		{"label": "Wrap up (30m)", "mins": 30, "fx": {"Warmth": 12.0, "Mental": 2.0}, "log": "You pull the blanket close. Quiet warmth - the kind that draws nothing."},
	],
	"cellar": [
		{"label": "Search the cellar (30m)", "mins": 30, "fx": {"Mental": -1.0}, "state_delta": 25.0, "log": "Cold shelves in the dark. You work through them slowly."},
	],
	"forage_food": [
		{"label": "Eat (10m)", "mins": 10, "fx": {"Calories": 15.0, "Mental": 1.0}, "consume": true, "log": "Bitter and stringy, but it is food."},
	],
	"log": [
		{"label": "Split for firewood (15m)", "mins": 15, "fx": {"Energy": -6.0, "Calories": -6.0, "Hydration": -5.0, "Warmth": 4.0}, "spawn": "firewood", "state_delta": -34.0, "log": "You set the wedge and swing. The log gives up a few good splits."},
	],
	"herbal_remedy": [
		{"label": "Drink the remedy (5m)", "mins": 5, "fx": {"Mental": 1.0}, "cure": {"gut_bug": -15.0}, "consume": true, "log": "Bitter and earthy. Your gut eases, a little."},
	],
	"antibiotics": [
		{"label": "Take antibiotics (5m)", "mins": 5, "cure": {"gut_bug": -50.0, "infection": -50.0}, "consume": true, "log": "You dry-swallow two. Real medicine - and not much left."},
	],
	"bandage": [
		{"label": "Bind your wounds (10m)", "mins": 10, "cure": {"wound": -45.0}, "consume": true, "log": "You clean it out and bind it tight. Not clever work, but it will hold."},
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
}

## Two-card (drag item onto target) recipes: item_id -> target_id -> {label, mins}.
var RECIPES := {
	"firewood": {"hearth": {"label": "Add fuel", "mins": 10}},
	"gas_canister": {"stream": {"label": "Fill with water", "mins": 10}, "rain_barrel": {"label": "Fill with water", "mins": 10}, "lighter": {"label": "Refuel lighter", "mins": 3}, "plastic_bottle": {"label": "Pour into bottle", "mins": 3}, "hearth": {"label": "Boil the water", "mins": 15}},
	"plastic_bottle": {"stream": {"label": "Fill with water", "mins": 10}, "rain_barrel": {"label": "Fill with water", "mins": 10}, "lighter": {"label": "Refuel lighter", "mins": 3}, "gas_canister": {"label": "Pour into canister", "mins": 3}, "hearth": {"label": "Boil the water", "mins": 15}},
	"lighter": {"tinder": {"label": "Light the tinder", "mins": 3}},
	"burning_tinder": {"hearth": {"label": "Set it alight", "mins": 3}},
	"herbs": {"hearth": {"label": "Steep a remedy", "mins": 15}},
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

func _ready() -> void:
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
	Game.add_log("Day 1. The power is still on, for now. Outside, it is very quiet.")
	_refresh()
	on_layout_changed()

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
	var phint := _label("click to rest or sleep", MUTED, 10)
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
	for m in ["Calories", "Hydration", "Warmth", "Energy", "Immune", "Mental"]:
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
	box.add_child(_label(m, INK, 12))
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
	panel.custom_minimum_size = Vector2(256, 0)
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
	detail_body = VBoxContainer.new()
	detail_body.add_theme_constant_override("separation", 9)
	_pad(detail_panel, 22).add_child(detail_body)

func _detail_category(card: CardIcon) -> String:
	if card.data.kind == "location":
		return "PLACE"
	return str(card.data.kind).to_upper()

func _detail_action_btn(txt: String) -> Button:
	var b := _btn(txt)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b

func _open_detail() -> void:
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
	var desc := "Rest to steady your nerves, or sleep off the day's weariness." if card == null else card.current_blurb()
	detail_body.add_child(_wrapped(desc, MUTED, 13))
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
	var closeb := _detail_action_btn("Close")
	closeb.pressed.connect(_hide_detail)
	detail_body.add_child(closeb)

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
		detail_body.add_child(_label(_craft_tab_title(_craft_tab), INK_STRONG, 20))
		detail_body.add_child(_wrapped("Nothing you can make here yet. Research and the right tools will open this up.", MUTED, 12))
	var closeb := _detail_action_btn("Close")
	closeb.pressed.connect(_hide_detail)
	detail_body.add_child(closeb)

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
			Game.add_log("You do not have the materials for that yet.")
			return
	for mid in mats:
		_consume_materials(str(mid), int(mats[mid]))
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
	_animate_meters(before, fx)
	on_layout_changed()
	if detail_layer and detail_layer.visible:
		_open_detail()

func _on_detail_pick(i: int) -> void:
	_hide_detail()
	if i >= 0 and i < _menu_actions.size():
		_perform(_menu_card, _menu_actions[i])

func _hide_detail() -> void:
	if detail_layer:
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
	var title := _label("—   you did not make it   —", BLOOD, 14)
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
	death_badge = _btn("You died  ·  review")
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

func _refresh_combat() -> void:
	if _combat_id == "" or not ENEMIES.has(_combat_id):
		return
	var e: Dictionary = ENEMIES[_combat_id]
	combat_title.text = str(e["name"])
	if _combat_card:
		combat_blurb.text = str(_combat_card.data.blurb)
	elif _combat_context == "siege":
		combat_blurb.text = "It came over the threshold, out of the crush of them. Put it down."
	combat_hp_bar.max_value = _combat_hp_max
	combat_hp_bar.value = maxf(0.0, _combat_hp)
	combat_wound_label.text = "Your wounds: %d%%" % int(round(Game.conditions.get("wound", 0.0)))
	combat_log_label.text = "\n".join(_combat_tail())

func _start_combat(enemy_id: String, card: CardIcon = null, context: String = "table") -> void:
	if Game.dead or not ENEMIES.has(enemy_id):
		return
	_combat_id = enemy_id
	_combat_card = card
	_combat_context = context
	_combat_hp_max = float(ENEMIES[_combat_id]["hp"])
	_combat_hp = _combat_hp_max
	_combat_before = Game.meters.duplicate()
	_combat_log = []
	_combat_say("A %s, and it has seen you." % str(ENEMIES[_combat_id]["name"]).to_lower())
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

func _strike_roll() -> Dictionary:
	# combat is NOT deterministic — a swing can miss, glance, land solid, or land hard
	var r := randf()
	if r < 0.10:
		return {"dmg": 0.0, "q": "miss"}
	elif r < 0.32:
		return {"dmg": PLAYER_STRIKE * 0.6, "q": "glance"}
	elif r < 0.84:
		return {"dmg": PLAYER_STRIKE, "q": "solid"}
	return {"dmg": PLAYER_STRIKE * 1.6, "q": "good"}

func _combat_strike() -> void:
	if not combat_layer.visible or _combat_resolving:
		return
	var e: Dictionary = ENEMIES[_combat_id]
	var enemy_name: String = str(e["name"]).to_lower()
	var roll := _strike_roll()
	var dmg: float = float(roll["dmg"])
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
		_screen_shake(3.0 + dmg * 0.35)
	var killed := _combat_hp <= 0.0
	if killed:
		_combat_say("The %s drops, and does not get up." % enemy_name)
	else:
		var edmg: float = float(e["damage"]) * randf_range(0.6, 1.4)
		Game.take_wound(edmg)
		_flash_hurt()
		_screen_shake(6.0 + edmg * 0.25)
		_combat_say("The %s %s you." % [enemy_name, str(e.get("verb", "hits"))])
		if e.has("bite_infection"):
			# cap the infection a single fight can seed below the lethal threshold, so it
			# surfaces and festers (a treatable emergency) instead of maturing straight to death
			var seeded := 0.0
			for dose in Game.cond_pending:
				if str(dose.get("id", "")) == "infection":
					seeded += float(dose.get("amt", 0.0))
			var add: float = minf(float(e["bite_infection"]) * randf_range(0.7, 1.3), maxf(0.0, 55.0 - seeded))
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
	var e: Dictionary = ENEMIES[_combat_id]
	var hit: float = float(e.get("flee_hit", 0.0)) * randf_range(0.6, 1.4)
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
	var e: Dictionary = ENEMIES[_combat_id]
	_refresh_combat()
	await get_tree().create_timer(0.7).timeout
	combat_layer.visible = false
	if outcome == "win":
		if _combat_card:
			# an enemy lives in the location's fixtures; killing it removes it for good
			LOCATIONS[Game.current_location]["fixtures"].erase(_combat_card.data.id)
			_consume_card(_combat_card)
		Game.add_log("You put the %s down." % str(e["name"]).to_lower())
	elif outcome == "flee":
		Game.add_log("You back off from the %s." % str(e["name"]).to_lower())
	else:
		Game.add_log("The %s has the better of you." % str(e["name"]).to_lower())
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
	var breaches := int(round(float(waves) * (1.0 - defense)))
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
	Game.add_log("Day 1. The power is still on, for now. Outside, it is very quiet.")
	_refresh()
	on_layout_changed()

func _populate() -> void:
	for loc in LOCATIONS:
		Game.location_ground[loc] = GROUND_START.get(loc, []).duplicate()
	for id in ["canned_food", "plastic_bottle", "lighter", "wool_blanket"]:
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
	for id in Game.location_ground.get(loc, []):
		_spawn(id, "middle")

func _save_ground(loc: String) -> void:
	var ids: Array = []
	for c in rows["middle"].get_children():
		if c is CardIcon:
			ids.append((c as CardIcon).data.id)
	Game.location_ground[loc] = ids

func _travel_to(dest: String, mins: int) -> void:
	_save_ground(Game.current_location)
	var before := Game.meters.duplicate()
	Game.current_location = dest
	Game.location_indoor = bool(LOCATIONS[dest].get("indoor", true))
	Game.advance_time(mins)
	_show_time_passing(mins)
	Game.add_log("You set out. You reach %s as the light thins." % _place_prose(dest))
	_animate_meters(before, {})
	_rebuild_out_there()
	_load_ground(dest)

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
			_reveal(e)
	var renew: Array = pool.get("renewable", [])
	for j in renew.size():
		var e2: Dictionary = renew[j]
		var mx: int = int(e2.get("max", 1))
		# cap on what's CURRENTLY present (gathering frees a slot to restock),
		# not how many were ever revealed — the latter makes "renewable" run dry.
		if _renew_present(loc, e2) < mx and _roll_renewable(new_pct):
			_reveal(e2)

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

func _reveal(e: Dictionary) -> bool:
	var loc := Game.current_location
	match e["kind"]:
		"ground":
			var gc := _spawn(e["id"], "middle")
			if e.has("content"):
				gc.fill_with(str(e["content"]), float(e.get("fill", 100.0)))
			Game.add_log(str(e.get("log", "You turn up: %s." % _card_title(e["id"]))))
			return true
		"fixture":
			var fxs: Array = LOCATIONS[loc]["fixtures"]
			if e["id"] in fxs:
				return false
			fxs.append(e["id"])
			Game.add_log(str(e.get("log", "You uncover the %s." % _card_title(e["id"]))))
			_rebuild_out_there()
			return true
		"location":
			var conns: Dictionary = LOCATIONS[loc]["connections"]
			if conns.has(e["id"]):
				return false
			conns[e["id"]] = int(e.get("mins", 30))
			Game.add_log("A way opens toward %s." % _place_prose(e["id"]))
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
		Game.add_log("You set the %s down here." % card.data.title.to_lower())
	elif parent == rows.get("middle"):
		if rows["inv"].get_child_count() >= INV_CAP:
			Game.add_log("Your hands and pockets are full.")
			return
		_move_card(card, "inv")
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
		Game.add_log("The %s is empty." % target.data.title.to_lower())
		on_drag_end()
		return
	var before := Game.meters.duplicate()
	var fx := {}
	if src.data.id == "firewood" and target.data.id == "hearth":
		target.set_state(target.state_value + 40.0)
		if Game.is_fire_lit():
			Game.add_log("You feed the fire. It flares - warm, bright, and loud.")
			fx = {"Warmth": 8.0}
		else:
			Game.add_log("You lay wood in the cold grate. It only wants a light now.")
		_consume_card(src)
	elif src.data.id == "lighter" and target.data.id == "tinder":
		if src.state_value <= 0.0:
			Game.add_log("The lighter sparks and dies - no charge left.")
			on_drag_end()
			return
		src.set_state(src.state_value - 1.0)
		_consume_card(target)
		_spawn("burning_tinder", "middle")
		Game.add_log("You thumb the lighter; the tinder catches and curls into flame.")
	elif src.data.id == "burning_tinder" and target.data.id == "hearth":
		Game.lit_sources[target.data.id] = true
		if target.state_value <= 0.0:
			target.set_state(1.0)
		_consume_card(src)
		Game.add_log("You feed the burning tinder in. The fire takes - warm light, and a beacon.")
	elif src.data.id == "herbs" and target.data.id == "hearth":
		if not Game.is_fire_lit():
			Game.add_log("You need a live fire to steep them.")
			on_drag_end()
			return
		_consume_card(src)
		_spawn("herbal_remedy", "middle")
		Game.add_log("You steep the herbs over the fire into a bitter, cloudy tea.")
		Game.gain_skill("cooking", 2.5)
	elif src.data.is_container and target.data.id == "lighter":
		if src.content != "fuel" or src.state_value <= 0.0:
			Game.add_log("There's no fuel in the %s to draw from." % src.data.title.to_lower())
			on_drag_end()
			return
		var room: float = 100.0 - target.state_value
		if room <= 0.0:
			Game.add_log("The lighter is already full.")
			on_drag_end()
			return
		var moved: float = minf(room, src.state_value)
		target.set_state(target.state_value + moved)
		src.drain_content(moved)
		Game.add_log("You top the lighter up from the %s." % src.data.title.to_lower())
	elif src.data.is_container and target.data.is_container:
		if src.content == "":
			Game.add_log("The %s is empty." % src.data.title.to_lower())
			on_drag_end()
			return
		var room: float = target.data.capacity - target.state_value
		if room <= 0.0:
			Game.add_log("The %s is already full." % target.data.title.to_lower())
			on_drag_end()
			return
		var moved: float = minf(src.state_value, room)
		var poured: String = src.content
		var target_was: String = target.content
		if not target.fill_with(src.content, moved):
			Game.add_log("You can't mix %s and %s." % [target._content_display(target.content).to_lower(), src._content_display(src.content).to_lower()])
			on_drag_end()
			return
		src.drain_content(moved)
		if target.content == "dirty_water" and (target_was == "water" or poured == "water"):
			Game.add_log("The clean water clouds as it meets the dirty. It needs boiling again.")
		else:
			Game.add_log("You pour %s into the %s." % [src._content_display(poured).to_lower(), target.data.title.to_lower()])
	elif src.data.is_container and target.data.id == "hearth":
		if src.content != "dirty_water" or src.state_value <= 0.0:
			Game.add_log("There's no dirty water in the %s to boil." % src.data.title.to_lower())
			on_drag_end()
			return
		if not Game.is_fire_lit():
			Game.add_log("You need a live fire to boil it.")
			on_drag_end()
			return
		src.boil()
		Game.add_log("You set the %s by the fire until it steams. The water runs clean." % src.data.title.to_lower())
		Game.gain_skill("cooking", 2.0)
	elif src.data.is_container and (target.data.id == "stream" or target.data.id == "rain_barrel"):
		var room: float = src.data.capacity - src.state_value
		if room <= 0.0:
			Game.add_log("The %s is already full." % src.data.title.to_lower())
			on_drag_end()
			return
		var avail: float = target.state_value if target.data.state_kind == "water" else room
		var moved2: float = minf(room, avail)
		if moved2 <= 0.0:
			Game.add_log("The %s is empty." % target.data.title.to_lower())
			on_drag_end()
			return
		var src_was: String = src.content
		if not src.fill_with("dirty_water", moved2):
			Game.add_log("The %s already holds %s." % [src.data.title.to_lower(), src._content_display(src.content).to_lower()])
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
		_menu_actions = [{"label": "Travel to %s (%dm)" % [_place_prose(card.data.id), mins], "travel_to": card.data.id, "mins": mins}]
	elif card.data.is_container:
		_menu_actions = _container_actions(card)
	else:
		_menu_actions = ACTIONS.get(card.data.id, [])
	# a small cursor menu with the action(s) and their durations; none gives a hint
	if _menu_actions.is_empty():
		if RECIPES.has(card.data.id):
			Game.add_log("Drag the %s onto a target to use it." % card.data.title.to_lower())
		elif _is_recipe_target(card.data.id):
			Game.add_log("Drag the right item onto the %s to use it." % card.data.title.to_lower())
		else:
			Game.add_log("There's nothing to do with the %s just now." % card.data.title.to_lower())
		return
	_open_menu()

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
	_open_detail()

func _on_portrait_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_open_char_menu()

func _sleep() -> void:
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
	if act.get("needs_fire", false) and not Game.is_fire_lit():
		Game.add_log("There is no fire lit.")
		return
	if act.has("drink"):
		_do_drink(card, bool(act.get("clean", false)), int(act.get("mins", 5)))
		return
	if act.has("fight"):
		_start_combat(card.data.id, card)
		return
	if act.has("radio_listen"):
		var line := Game.radio_listen()
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
	if act.has("state_delta"):
		var old_pct: float = card.state_value
		card.set_state(card.state_value + act["state_delta"])
		if card.data.kind == "location":
			_process_reveals(card.data.id, old_pct, card.state_value)
		elif card.data.state_kind == "fell" and card.state_value >= 100.0 and card.data.becomes != "":
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

func _refresh() -> void:
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
