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
}

## Locations: the fixtures/stations present there, and where you can travel from it.
var LOCATIONS := {
	"lordly_manor": {"title": "Lordly Manor", "indoor": true, "fixtures": ["hearth", "rain_barrel"], "connections": {"the_woods": 45},
		"pool": {"finite": [{"kind": "location", "id": "cellar", "milestone": 50, "mins": 5}, {"kind": "ground", "id": "canned_food", "between": [15, 85]}], "renewable": []}},
	"the_woods": {"title": "Woods", "the": true, "indoor": false, "fixtures": ["oak_tree"], "connections": {"lordly_manor": 45},
		"pool": {"finite": [{"kind": "fixture", "id": "stream", "milestone": 30}], "renewable": [{"kind": "ground", "id": "forage_food", "max": 3}, {"kind": "ground", "id": "tinder", "max": 3}, {"kind": "fixture", "id": "oak_tree", "max": 3, "log": "Deeper in, you find another good oak."}]}},
	"cellar": {"title": "Cellar", "the": true, "indoor": true, "fixtures": [], "connections": {"lordly_manor": 5},
		"pool": {"finite": [{"kind": "ground", "id": "canned_food", "milestone": 40}, {"kind": "ground", "id": "gas_canister", "milestone": 75, "content": "fuel", "fill": 50.0}], "renewable": []}},
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
		{"label": "Fell the tree (25m)", "mins": 25, "fx": {"Energy": -8.0}, "state_delta": 20.0, "log": "You swing until your shoulders burn. The old oak groans a little lower."},
	],
	"the_woods": [
		{"label": "Forage (40m)", "mins": 40, "fx": {"Energy": -6.0, "Mental": 2.0}, "state_delta": 8.0, "log": "You move quiet through the trees. A few late berries, kindling, tracks that are not yours."},
	],
	"lordly_manor": [
		{"label": "Search the Manor (30m)", "mins": 30, "fx": {"Mental": -1.0}, "state_delta": 15.0, "log": "You search the cold rooms. A door you had not tried opens onto stairs going down."},
	],
	"rain_barrel": [
		{"label": "Drink from the barrel (5m)", "mins": 5, "fx": {"Hydration": 18.0, "Immune": -6.0}, "state_delta": -20.0, "cond": {"gut_bug": 20.0}, "cond_cause": "unboiled water", "log": "You cup the cold water and drink. Unboiled - your gut may regret it."},
	],
	"stream": [
		{"label": "Drink from the stream (5m)", "mins": 5, "fx": {"Hydration": 18.0, "Immune": -6.0}, "cond": {"gut_bug": 20.0}, "cond_cause": "unboiled water", "log": "You drink straight from the stream. Achingly cold, and unboiled."},
	],
	"canned_food": [
		{"label": "Eat cold (20m)", "mins": 20, "fx": {"Calories": 30.0, "Mental": 1.0}, "consume": true, "log": "You eat cold from the tin. It helps, a little."},
	],
	"wool_blanket": [
		{"label": "Wrap up (30m)", "mins": 30, "fx": {"Warmth": 12.0, "Mental": 2.0}, "log": "You pull the blanket close. Quiet warmth - the kind that draws nothing."},
	],
	"cellar": [
		{"label": "Search the cellar (25m)", "mins": 25, "fx": {"Mental": -1.0}, "state_delta": 25.0, "log": "Cold shelves in the dark. You work through them slowly."},
	],
	"forage_food": [
		{"label": "Eat (10m)", "mins": 10, "fx": {"Calories": 15.0, "Mental": 1.0}, "consume": true, "log": "Bitter and stringy, but it is food."},
	],
	"log": [
		{"label": "Split for firewood (20m)", "mins": 20, "fx": {"Energy": -6.0}, "spawn": "firewood", "state_delta": -34.0, "log": "You set the wedge and swing. The log gives up a few good splits."},
	],
}

## Two-card (drag item onto target) recipes: item_id -> target_id -> {label, mins}.
var RECIPES := {
	"firewood": {"hearth": {"label": "Add fuel", "mins": 10}},
	"gas_canister": {"stream": {"label": "Fill with water", "mins": 10}, "rain_barrel": {"label": "Fill with water", "mins": 10}, "lighter": {"label": "Refuel lighter", "mins": 2}, "plastic_bottle": {"label": "Pour into bottle", "mins": 2}},
	"plastic_bottle": {"stream": {"label": "Fill with water", "mins": 10}, "rain_barrel": {"label": "Fill with water", "mins": 10}, "lighter": {"label": "Refuel lighter", "mins": 2}, "gas_canister": {"label": "Pour into canister", "mins": 2}},
	"lighter": {"tinder": {"label": "Light the tinder", "mins": 1}},
	"burning_tinder": {"hearth": {"label": "Set it alight", "mins": 1}},
}

var rows := {}
var bars := {}
var clock_label: Label
var temp_label: Label
var top_head: Label
var log_label: Label
var inv_head: Label
var cond_tray: VBoxContainer
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

func _ready() -> void:
	randomize()
	_locations_initial = LOCATIONS.duplicate(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_ui()
	_build_overlay()
	_build_menu()
	_build_death()
	_populate()
	Game.changed.connect(_refresh)
	Game.add_log("Day 1. The power is still on, for now. Outside, it is very quiet.")
	_refresh()
	on_layout_changed()

func _unhandled_input(event: InputEvent) -> void:
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
	var cc := CenterContainer.new()
	portrait.add_child(cc)
	var you := _label("YOU", WARM, 24)
	you.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cc.add_child(you)
	vb.add_child(portrait)

	clock_label = _label("", INK_STRONG, 18)
	vb.add_child(clock_label)
	temp_label = _label("", COLD, 14)
	vb.add_child(temp_label)
	vb.add_child(_label("Overcast, still.", MUTED, 12))

	vb.add_child(HSeparator.new())
	vb.add_child(_label("CONDITION", COLD, 11))
	for m in ["Calories", "Hydration", "Warmth", "Energy", "Immune", "Mental"]:
		vb.add_child(_make_meter(m))
	cond_tray = VBoxContainer.new()
	cond_tray.add_theme_constant_override("separation", 5)
	vb.add_child(cond_tray)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	vb.add_child(_label("F11  ·  fullscreen", MUTED, 10))
	return panel

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
		var cnt: int = int(st["renew"].get(j, 0))
		var mx: int = int(e2.get("max", 1))
		if cnt < mx and _roll_renewable(new_pct):
			if _reveal(e2):
				st["renew"][j] = cnt + 1

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
	elif src.data.is_container and target.data.id == "lighter":
		if src.content != "fuel" or src.state_value <= 0.0:
			Game.add_log("There's no fuel in the %s to draw from." % src.data.title.to_lower())
			on_drag_end()
			return
		target.set_state(100.0)
		src.drain_content(10.0)
		Game.add_log("You top the lighter up from the %s." % src.data.title.to_lower())
	elif src.data.is_container and target.data.is_container:
		if src.content == "":
			Game.add_log("The %s is empty." % src.data.title.to_lower())
			on_drag_end()
			return
		if target.content != "" and target.content != src.content:
			Game.add_log("You can't mix %s and %s." % [src._content_display(target.content).to_lower(), src._content_display(src.content).to_lower()])
			on_drag_end()
			return
		var room: float = target.data.capacity - target.state_value
		if room <= 0.0:
			Game.add_log("The %s is already full." % target.data.title.to_lower())
			on_drag_end()
			return
		var moved: float = minf(src.state_value, room)
		target.fill_with(src.content, moved)
		src.drain_content(moved)
		Game.add_log("You pour %s into the %s." % [src._content_display(src.content).to_lower(), target.data.title.to_lower()])
	elif src.data.is_container and (target.data.id == "stream" or target.data.id == "rain_barrel"):
		if src.content != "" and src.content != "dirty_water":
			Game.add_log("The %s already holds %s." % [src.data.title.to_lower(), src._content_display(src.content).to_lower()])
			on_drag_end()
			return
		src.fill_with("dirty_water", src.data.capacity)
		if target.data.state_kind == "water":
			target.set_state(target.state_value - 25.0)
		Game.add_log("You fill the %s with cold, clouded water." % src.data.title.to_lower())
	for k in fx:
		Game.modify(k, fx[k])
	Game.advance_time(int(rec.get("mins", 10)))
	on_drag_end()
	_animate_meters(before, fx)
	on_layout_changed()

# ---------- click menu ----------
func _container_actions(card: CardIcon) -> Array:
	# Any container holding a drinkable liquid can be drunk from.
	if card.content == "dirty_water":
		return [{"label": "Drink (5m)", "mins": 5, "fx": {"Hydration": 18.0, "Immune": -6.0}, "drain_content": 25.0, "cond": {"gut_bug": 20.0}, "cond_cause": "unboiled water", "log": "You drink it unboiled - cold and gritty. Your gut may regret it."}]
	elif card.content == "water":
		return [{"label": "Drink (5m)", "mins": 5, "fx": {"Hydration": 20.0}, "drain_content": 25.0, "log": "Clean water, boiled and left to cool. It goes down easy."}]
	return []

func on_card_clicked(card: CardIcon) -> void:
	_menu_card = card
	if card.data.kind == "location" and card.data.id != Game.current_location:
		var mins: int = _travel_mins(Game.current_location, card.data.id)
		_menu_actions = [{"label": "Travel to %s (%dm)" % [_place_prose(card.data.id), mins], "travel_to": card.data.id, "mins": mins}]
	elif card.data.is_container:
		_menu_actions = _container_actions(card)
	else:
		_menu_actions = ACTIONS.get(card.data.id, [])
	if _menu_actions.is_empty():
		if RECIPES.has(card.data.id):
			Game.add_log("Drag the %s onto a target to use it." % card.data.title.to_lower())
		elif _is_recipe_target(card.data.id):
			Game.add_log("Drag the right item onto the %s to use it." % card.data.title.to_lower())
		else:
			Game.add_log("There is nothing to do with the %s just now." % card.data.title.to_lower())
		return
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
	if act.has("travel_to"):
		_travel_to(act["travel_to"], int(act.get("mins", 30)))
		return
	if act.get("needs_fire", false) and not Game.is_fire_lit():
		Game.add_log("There is no fire lit.")
		return
	if act.has("state_delta"):
		var d: float = act["state_delta"]
		if d < 0.0 and card.state_value <= 0.0:
			Game.add_log("The %s is empty." % card.data.title.to_lower())
			return
		if d > 0.0 and card.data.state_kind == "fell" and card.state_value >= 100.0:
			Game.add_log("The %s is already felled." % card.data.title.to_lower())
			return
	var before := Game.meters.duplicate()
	var fx: Dictionary = act.get("fx", {})
	for k in fx:
		Game.modify(k, fx[k])
	if act.has("cond"):
		for cid in act["cond"]:
			Game.add_condition(cid, float(act["cond"][cid]), str(act.get("cond_cause", "")))
	Game.advance_time(int(act.get("mins", 30)))
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
	if act.has("drain_content"):
		card.drain_content(act["drain_content"])
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
		bars[m]["bar"].queue_redraw()
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
			cond_tray.add_child(_make_chip(str(stg["name"]), Game.cond_trajectory(id), cst))
	if Game.dead and not _death_shown:
		_death_shown = true
		_show_death()
