class_name CardIcon
extends PanelContainer
## A big, card-shaped tile.
## - Click (release without dragging) opens the card detail view.
## - Drag a mobile card ONTO another card: if there's a two-card recipe
##   (e.g. Firewood -> Hearth) it performs that action; otherwise it reorders /
##   moves the card between rows.
## Immobile cards (locations/fixtures/stations) can't be dragged, but can be
## recipe TARGETS.

const PANELC := Color(0.078, 0.110, 0.145)
const PANELC2 := Color(0.055, 0.082, 0.114)
const BORDER := Color(0.133, 0.188, 0.243)
const INK_STRONG := Color(0.906, 0.933, 0.957)
const MUTED := Color(0.490, 0.549, 0.604)
const WARM := Color(0.910, 0.678, 0.361)
const COLD := Color(0.412, 0.714, 0.839)
const GREEN := Color(0.545, 0.690, 0.541)
const BLOOD := Color(0.788, 0.412, 0.369)

const CARD_SIZE := Vector2(176, 230)
const CLICK_DRAG_THRESHOLD := 8.0

var data: CardData
var main
var mobile: bool = true
var state_value: float = 0.0
var _state_bar: ProgressBar
var _state_label: Label
var _kind_label: Label
var _panel_sb: StyleBoxFlat
var _title_label: Label
var _card_status_label: Label
var _cover_rect: TextureRect
var _state_fill: StyleBoxFlat
var _left_press_active: bool = false
var _click_candidate: bool = false
var _drag_started: bool = false
var _press_position := Vector2.ZERO
var content: String = ""  ## for containers: current contents id ("" = empty)
var cools_at: int = -1  ## boiling liquid: absolute game-minute when it becomes normal water
var spoil_at: int = -1  ## perishable food: absolute game-minute it spoils (-1 = never)
var _fresh_label: Label
var _fresh_bar: ProgressBar
var _fresh_fill: StyleBoxFlat
var expires_at: int = -1  ## temporary card: absolute game-minute it disappears (-1 = permanent)

func setup(card_data: CardData, main_ref) -> void:
	data = card_data
	main = main_ref
	mobile = data.kind in ["item", "resource", "tool"]
	if data.spoil_hours > 0.0:
		spoil_at = Game.abs_minute() + int(data.spoil_hours * 60.0)  # fresh; a loader may override
	if data.lifetime_mins > 0:
		expires_at = Game.abs_minute() + data.lifetime_mins  # a loader may restore the original deadline
	custom_minimum_size = CARD_SIZE
	self.clip_contents = true
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "%s  (%s)" % [data.title, data.kind]

	_panel_sb = StyleBoxFlat.new()
	_panel_sb.bg_color = PANELC
	_panel_sb.border_color = _accent().lerp(BORDER, 0.4)
	_panel_sb.set_border_width_all(1)
	_panel_sb.set_border_width(SIDE_TOP, 3)
	_panel_sb.set_corner_radius_all(12)
	_panel_sb.content_margin_left = 12.0
	_panel_sb.content_margin_right = 12.0
	_panel_sb.content_margin_top = 8.0
	_panel_sb.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", _panel_sb)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)

	_kind_label = _ilabel(data.kind.to_upper(), _accent(), 10)
	vb.add_child(_kind_label)

	var art := PanelContainer.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.custom_minimum_size = Vector2(0, 132)
	art.clip_contents = true
	var artsb := StyleBoxFlat.new()
	artsb.bg_color = PANELC2
	artsb.border_color = BORDER
	artsb.set_border_width_all(1)
	artsb.set_corner_radius_all(8)
	art.add_theme_stylebox_override("panel", artsb)
	if data.cover_image != null:
		_cover_rect = TextureRect.new()
		_cover_rect.texture = data.cover_image
		_cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_cover_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_cover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cover_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_cover_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		art.add_child(_cover_rect)
	else:
		var glyph_name := data.title
		if glyph_name.begins_with("The "):
			glyph_name = glyph_name.substr(4)
		var glyph := _ilabel(glyph_name.substr(0, 1).to_upper(), _accent(), 42)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		art.add_child(glyph)
	vb.add_child(art)

	_title_label = _ilabel(data.title, INK_STRONG, 16)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_title_label)
	if data.id == "alarm_clock":
		_card_status_label = _ilabel("", MUTED, 10)
		vb.add_child(_card_status_label)
		_refresh_card_status()

	# perishables show a freshness read-out (a word + a shrinking bar) so you can see them turning
	if data.spoil_hours > 0.0:
		var fbox := VBoxContainer.new()
		fbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fbox.add_theme_constant_override("separation", 2)
		vb.add_child(fbox)
		_fresh_label = _ilabel("", GREEN, 10)
		fbox.add_child(_fresh_label)
		_fresh_bar = ProgressBar.new()
		_fresh_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fresh_bar.min_value = 0.0
		_fresh_bar.max_value = 100.0
		_fresh_bar.show_percentage = false
		_fresh_bar.custom_minimum_size = Vector2(0, 5)
		var fbg := StyleBoxFlat.new()
		fbg.bg_color = Color(0.039, 0.055, 0.075)
		fbg.border_color = BORDER
		fbg.set_border_width_all(1)
		fbg.set_corner_radius_all(3)
		_fresh_bar.add_theme_stylebox_override("background", fbg)
		_fresh_fill = StyleBoxFlat.new()
		_fresh_fill.bg_color = GREEN
		_fresh_fill.set_corner_radius_all(3)
		_fresh_bar.add_theme_stylebox_override("fill", _fresh_fill)
		fbox.add_child(_fresh_bar)
		_refresh_freshness()

	if data.is_container:
		var cst: Dictionary = Game.card_state.get(data.id, {})
		content = str(cst.get("content", ""))
		state_value = float(cst.get("fill", 0.0))
		cools_at = int(cst.get("cools_at", -1))
	else:
		state_value = Game.card_state.get(data.id, data.state_start)
	if data.state_kind != "" or data.is_container:
		var statebox := VBoxContainer.new()
		statebox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		statebox.add_theme_constant_override("separation", 2)
		vb.add_child(statebox)
		_state_label = _ilabel("", COLD, 10)
		statebox.add_child(_state_label)
		_state_bar = ProgressBar.new()
		_state_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_state_bar.min_value = 0.0
		_state_bar.max_value = data.capacity if data.is_container else data.state_max
		_state_bar.show_percentage = false
		_state_bar.custom_minimum_size = Vector2(0, 7)
		var sbg := StyleBoxFlat.new()
		sbg.bg_color = Color(0.039, 0.055, 0.075)
		sbg.border_color = BORDER
		sbg.set_border_width_all(1)
		sbg.set_corner_radius_all(4)
		_state_bar.add_theme_stylebox_override("background", sbg)
		_state_fill = StyleBoxFlat.new()
		_state_fill.bg_color = _state_color()
		_state_fill.set_corner_radius_all(4)
		_state_bar.add_theme_stylebox_override("fill", _state_fill)
		statebox.add_child(_state_bar)
		if data.is_container:
			_refresh_container()
		else:
			_refresh_state()

	gui_input.connect(_on_gui_input)

func _ilabel(txt: String, col: Color, sz: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", sz)
	return l

func _accent() -> Color:
	match data.kind:
		"location": return COLD
		"station", "fixture": return WARM
		"character": return GREEN
		"creature": return BLOOD
		_: return MUTED

func set_state(v: float) -> void:
	state_value = clampf(v, 0.0, data.state_max)
	Game.card_state[data.id] = state_value
	_refresh_state()

func _refresh_state() -> void:
	_refresh_cover_image()
	if _state_label == null:
		return
	if data.state_kind == "charges":
		var count := int(round(state_value))
		_state_label.text = "%d pill%s left" % [count, "" if count == 1 else "s"]
		if _state_bar:
			_state_bar.value = state_value
		return
	if data.is_fire_source:
		var pct := int(round(state_value))
		if Game.is_lit(data.id):
			_state_label.text = "Burning  %d%%" % pct
			_state_label.add_theme_color_override("font_color", WARM)
			if _state_fill:
				_state_fill.bg_color = WARM
			if _panel_sb:
				_panel_sb.border_color = WARM
		else:
			_state_label.text = ("Unlit  %d%%" % pct) if state_value > 0.0 else "Cold"
			_state_label.add_theme_color_override("font_color", MUTED)
			if _state_fill:
				_state_fill.bg_color = Color(0.42, 0.36, 0.27)
			if _panel_sb:
				_panel_sb.border_color = _accent().lerp(BORDER, 0.4)
		if _state_bar:
			_state_bar.value = state_value
		return
	_state_label.text = "%s  %d%%" % [_state_word(), int(round(state_value))]
	if _state_bar:
		_state_bar.value = state_value

func _refresh_cover_image() -> void:
	if _cover_rect == null:
		return
	_cover_rect.texture = current_cover_image()

func current_cover_image() -> Texture2D:
	if data.state_kind == "charges" and not data.cover_images_by_state.is_empty():
		var state_index := clampi(int(round(state_value)), 0, data.cover_images_by_state.size() - 1)
		if data.cover_images_by_state[state_index] != null:
			return data.cover_images_by_state[state_index]
	if data.is_container:
		match content:
			"water":
				if data.cover_image_water != null: return data.cover_image_water
			"dirty_water":
				if data.cover_image_dirty_water != null: return data.cover_image_dirty_water
			"boiling_water":
				if data.cover_image_boiling_water != null: return data.cover_image_boiling_water
			"fuel":
				if data.cover_image_fuel != null: return data.cover_image_fuel
			"":
				if data.cover_image_empty != null: return data.cover_image_empty
	# Stateful tools such as lighters can opt into zero-state art without needing
	# item-specific display code. Containers select by contents above; fire sources
	# continue into their lit/low-fuel matrix below.
	if not data.is_container and state_value <= 0.0 and data.cover_image_empty != null:
		return data.cover_image_empty
	if data.is_fire_source:
		var low_fuel := state_value > 0.0 and state_value < 40.0
		if Game.is_lit(data.id):
			if low_fuel and data.cover_image_lit_low != null:
				return data.cover_image_lit_low
			if data.cover_image_lit != null:
				return data.cover_image_lit
		if state_value <= 0.0 and data.cover_image_empty != null:
			return data.cover_image_empty
		if low_fuel and data.cover_image_low != null:
			return data.cover_image_low
	return data.cover_image

func _refresh_freshness() -> void:
	# read the perishable's remaining life off its absolute spoil-minute: a shrinking bar that
	# goes green -> amber -> red, with a plain-language word (Fresh / Turning / Spoiled).
	if _fresh_bar == null or spoil_at < 0:
		return
	var total := maxf(1.0, data.spoil_hours * 60.0)
	var remain := float(spoil_at - Game.abs_minute())
	_fresh_bar.value = clampf(remain / total, 0.0, 1.0) * 100.0
	var stage := Game.spoil_stage(spoil_at)
	var col := GREEN
	var word := "Fresh"
	if stage == 2:
		col = BLOOD
		word = "Spoiled"
	elif stage == 1:
		col = WARM
		word = "Turning"
	_fresh_fill.bg_color = col
	_fresh_label.text = word
	_fresh_label.add_theme_color_override("font_color", col)

func sync_state() -> void:
	# Re-read persistent state (e.g. the hearth fuel burning down over time) so
	# passive changes from advance_time show without an explicit set_state.
	if spoil_at >= 0:
		_refresh_freshness()
	if data.is_container:
		var cst: Dictionary = Game.card_state.get(data.id, {})
		content = str(cst.get("content", ""))
		state_value = float(cst.get("fill", 0.0))
		cools_at = int(cst.get("cools_at", -1))
		_refresh_container()
	elif data.state_kind != "":
		state_value = Game.card_state.get(data.id, data.state_start)
		_refresh_state()
	_refresh_card_status()

func _refresh_card_status() -> void:
	if _card_status_label == null:
		return
	if data.id == "alarm_clock" and Game.alarm_is_pending():
		_card_status_label.text = "DAILY ALARM  ·  %s" % Game.alarm_hhmm()
		_card_status_label.add_theme_color_override("font_color", WARM)
	else:
		_card_status_label.text = "ALARM NOT SET"
		_card_status_label.add_theme_color_override("font_color", MUTED)

# --- summaries for the card detail view ---
func current_blurb() -> String:
	if data.is_fire_source:
		if Game.is_lit(data.id) and data.blurb_lit != "":
			return data.blurb_lit
		elif state_value > 0.0 and data.blurb_fueled != "":
			return data.blurb_fueled
	return data.blurb

func state_summary() -> String:
	if data.is_container:
		return "Empty" if content == "" else "%s  %d%%" % [_content_display(content), int(round(state_value))]
	if data.is_fire_source:
		if Game.is_lit(data.id):
			return "Burning  %d%%" % int(round(state_value))
		return ("Unlit  %d%%" % int(round(state_value))) if state_value > 0.0 else "Cold"
	if data.state_kind != "":
		if data.state_kind == "charges":
			var count := int(round(state_value))
			return "%d pill%s remaining" % [count, "" if count == 1 else "s"]
		return "%s  %d%%" % [_state_word(), int(round(state_value))]
	return ""

func _state_word() -> String:
	match data.state_kind:
		"explore": return "Explored"
		"water": return "Dirty Water"
		"fell": return "Felled"
		"wood": return "Wood"
		"fuel": return "Fuel"
		_: return ""

func _state_color() -> Color:
	match data.state_kind:
		"water": return Color(0.46, 0.42, 0.30)
		"explore": return GREEN
		"fell": return WARM
		"wood": return WARM
		"fuel": return WARM
		_: return COLD

# --- containers (canister etc.): hold one resource at a time, with a fill % ---
func _content_display(c: String) -> String:
	match c:
		"water": return "Water"
		"dirty_water": return "Dirty Water"
		"boiling_water": return "Boiling Water"
		"fuel": return "Fuel"
		"charges": return "Remaining"
		_: return c.capitalize()

func _content_color(c: String) -> Color:
	match c:
		"water": return COLD
		"dirty_water": return Color(0.46, 0.42, 0.30)
		"boiling_water": return Color(0.72, 0.82, 0.86)
		"fuel": return WARM
		"charges": return COLD
		_: return COLD

func _persist_container() -> void:
	Game.card_state[data.id] = {"content": content, "fill": state_value, "cools_at": cools_at}

func _refresh_container() -> void:
	_refresh_cover_image()
	# Title stays plain ("Plastic Bottle"); the contents read as a small tag by the bar.
	if _title_label:
		_title_label.text = data.title
	if _state_bar == null:
		return
	var has := content != ""
	_state_bar.visible = has
	if has and _state_fill:
		_state_fill.bg_color = _content_color(content)
	_state_bar.value = state_value
	if _state_label:
		if has:
			_state_label.text = "%s  %d%%" % [_content_display(content), int(round(state_value / maxf(data.capacity, 1.0) * 100.0))]
		else:
			_state_label.text = "Empty"

func _is_water(c: String) -> bool:
	return c == "water" or c == "dirty_water" or c == "boiling_water"

func fill_with(content_id: String, amount: float) -> bool:
	if content_id == "fuel" and not data.sealable:
		return false  # only sealable containers (bottle/jerry) hold fuel
	if content == "":
		content = content_id
		cools_at = Game.abs_minute() + 30 if content_id == "boiling_water" else -1
	elif content != content_id:
		if _is_water(content) and _is_water(content_id):
			if content == "dirty_water" or content_id == "dirty_water":
				content = "dirty_water"  # any dirty water contaminates the whole container
				cools_at = -1
			else:
				content = "boiling_water" if content == "boiling_water" or content_id == "boiling_water" else "water"
				if content == "boiling_water":
					cools_at = Game.abs_minute() + 30
		else:
			return false  # water and fuel do not mix
	state_value = clampf(state_value + amount, 0.0, data.capacity)
	_persist_container()
	_refresh_container()
	return true

func drain_content(amount: float) -> void:
	state_value = maxf(0.0, state_value - amount)
	if state_value <= 0.0:
		content = ""
		cools_at = -1
	_persist_container()
	_refresh_container()

func boil(ready_in_mins: int = 30) -> void:
	# dirty water boiled clean; fuel or empty containers are unaffected
	if content == "dirty_water":
		content = "boiling_water"
		cools_at = Game.abs_minute() + ready_in_mins
		_persist_container()
		_refresh_container()

func cool_if_ready() -> bool:
	if content != "boiling_water" or cools_at < 0 or Game.abs_minute() < cools_at:
		return false
	content = "water"
	cools_at = -1
	_persist_container()
	_refresh_container()
	return true

func set_location_badge(mode: String) -> void:
	if _kind_label == null:
		return
	if mode == "here":
		_kind_label.text = "YOU ARE HERE"
		_kind_label.add_theme_color_override("font_color", GREEN)
		if _panel_sb:
			_panel_sb.border_color = GREEN
	elif mode == "travel":
		_kind_label.text = "TRAVEL"
		_kind_label.add_theme_color_override("font_color", COLD)
		if _panel_sb:
			_panel_sb.border_color = Color(0.247, 0.427, 0.510)

# --- click vs drag: release opens detail only when no drag gesture began ---
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_left_press_active = true
			_click_candidate = true
			_drag_started = false
			_press_position = event.position
		else:
			var should_open := _left_press_active and _click_candidate and not _drag_started
			_left_press_active = false
			_click_candidate = false
			if should_open and main:
				main.on_card_clicked(self)
	elif event is InputEventMouseMotion and _left_press_active:
		if event.position.distance_to(_press_position) > CLICK_DRAG_THRESHOLD:
			_click_candidate = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		main.on_card_right_clicked(self)

# --- drag & drop ---
func _get_drag_data(_at: Vector2):
	if not mobile:
		return null
	_drag_started = true
	_click_candidate = false
	main.on_drag_begin(self)
	set_drag_preview(_make_preview())
	modulate.a = 0.35
	return {"card": self}

func _can_drop_data(_at: Vector2, incoming) -> bool:
	if typeof(incoming) != TYPE_DICTIONARY or not incoming.has("card"):
		return false
	var src: CardIcon = incoming["card"]
	if src == self:
		return false
	if main.recipe_for(src.data.id, data.id) != null:
		return true
	var row := get_parent()
	return row is CardRow and (row as CardRow).can_accept(src)

func _drop_data(at: Vector2, incoming) -> void:
	var src: CardIcon = incoming["card"]
	var rec = main.recipe_for(src.data.id, data.id)
	if rec != null:
		main.perform_recipe(src, self, rec)
		return
	# otherwise: reorder relative to this card
	var row: CardRow = get_parent() as CardRow
	if row == null or not row.can_accept(src):
		return
	var idx := get_index()
	if at.x > size.x * 0.5:
		idx += 1
	if src.get_parent() == row and src.get_index() < idx:
		idx -= 1
	if src.get_parent() != row:
		src.get_parent().remove_child(src)
		row.add_child(src)
	row.move_child(src, clampi(idx, 0, row.get_child_count() - 1))
	main.on_card_reordered()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0
		_left_press_active = false
		_click_candidate = false
		_drag_started = false
		if main and main._dragging == self:
			main.on_drag_end()

func _make_preview() -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = CARD_SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANELC
	sb.border_color = _accent()
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel", sb)
	var l := _ilabel(data.title, INK_STRONG, 15)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.modulate.a = 0.9
	return p
