class_name WoundCard
extends PanelContainer

var wound_uid: int = -1
var main
var title_label: Label
var state_label: Label
var danger_label: Label

func setup(uid: int, main_ref) -> void:
	wound_uid = uid
	main = main_ref
	custom_minimum_size = Vector2(0, 72)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.075, 0.075, 0.98)
	sb.border_color = Color(0.79, 0.40, 0.36)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(7)
	sb.content_margin_left = 9.0
	sb.content_margin_right = 9.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	add_child(vb)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.78))
	vb.add_child(title_label)
	state_label = Label.new()
	state_label.add_theme_font_size_override("font_size", 10)
	state_label.add_theme_color_override("font_color", Color(0.76, 0.78, 0.80))
	vb.add_child(state_label)
	danger_label = Label.new()
	danger_label.add_theme_font_size_override("font_size", 10)
	danger_label.add_theme_color_override("font_color", Color(0.93, 0.57, 0.48))
	vb.add_child(danger_label)
	gui_input.connect(_on_input)
	refresh()

func refresh() -> void:
	if main == null:
		return
	var wound: Dictionary = Game.get_wound(wound_uid)
	if wound.is_empty():
		queue_free()
		return
	title_label.text = str(wound.get("label", "Wound"))
	state_label.text = "%s · %s" % [str(wound.get("body_part", "body")), ("clean" if wound.get("cleaned", false) else "unclean")]
	if wound.get("bandaged", false):
		danger_label.text = "Bandaged · bleeding stopped"
	else:
		danger_label.text = "Bleeding %.2f Blood/min" % float(wound.get("bleed_per_minute", 0.0))
	tooltip_text = "Drag clean water here to wash it, or a bandage here to stop the bleeding."

func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and main:
		main.on_wound_clicked(wound_uid)

func _can_drop_data(_at: Vector2, incoming) -> bool:
	if main == null or typeof(incoming) != TYPE_DICTIONARY or not incoming.has("card"):
		return false
	return main.can_treat_wound(incoming["card"], wound_uid)

func _drop_data(_at: Vector2, incoming) -> void:
	if main and typeof(incoming) == TYPE_DICTIONARY and incoming.has("card"):
		main.treat_wound(incoming["card"], wound_uid)
