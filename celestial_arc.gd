class_name CelestialArc
extends Control
## Compact day/night indicator. Its boundaries intentionally match main.gd's environment curve:
## dawn 05:00–08:00, full day, dusk 18:00–21:00, then moon through the night.

const SUN := preload("res://assets/ui/celestial_sun.png")
const MOON := preload("res://assets/ui/celestial_moon.png")
const DAWN_START := 5 * 60
const DAWN_END := 8 * 60
const DUSK_START := 18 * 60
const DUSK_END := 21 * 60
const DAY_SPAN := DUSK_END - DAWN_START
const NIGHT_SPAN := 24 * 60 - DAY_SPAN

var minute_of_day: int = 8 * 60
var season_index: int = 0
var showing_sun: bool = true
var displayed_progress: float = 0.0
var _move_tween: Tween

static func is_sun_time(minute: int) -> bool:
	var m := posmod(minute, 24 * 60)
	return m >= DAWN_START and m < DUSK_END

static func arc_progress(minute: int) -> float:
	var m := posmod(minute, 24 * 60)
	if is_sun_time(m):
		return clampf(float(m - DAWN_START) / float(DAY_SPAN), 0.0, 1.0)
	var night_elapsed := m - DUSK_END if m >= DUSK_END else m + 24 * 60 - DUSK_END
	return clampf(float(night_elapsed) / float(NIGHT_SPAN), 0.0, 1.0)

static func phase_name(minute: int) -> String:
	var m := posmod(minute, 24 * 60)
	if m >= DAWN_START and m < DAWN_END:
		return "Dawn"
	if m >= DAWN_END and m < DUSK_START:
		return "Daylight"
	if m >= DUSK_START and m < DUSK_END:
		return "Dusk"
	return "Night"

func set_time(minute: int, season: int, animate: bool = true) -> void:
	minute_of_day = posmod(minute, 24 * 60)
	season_index = posmod(season, 4)
	var next_sun := is_sun_time(minute_of_day)
	var target := arc_progress(minute_of_day)
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	if is_equal_approx(target, displayed_progress):
		showing_sun = next_sun
		_set_displayed_progress(target)
	elif not animate or next_sun != showing_sun or absf(target - displayed_progress) > 0.55:
		showing_sun = next_sun
		_set_displayed_progress(target)
	else:
		showing_sun = next_sun
		_move_tween = create_tween()
		_move_tween.tween_method(_set_displayed_progress, displayed_progress, target, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tooltip_text = "%s · %s %s" % [phase_name(minute_of_day), ("sun" if showing_sun else "moon"), ("rising" if target < 0.5 else "setting")]
	queue_redraw()

func _set_displayed_progress(value: float) -> void:
	displayed_progress = clampf(value, 0.0, 1.0)
	queue_redraw()

func _season_arc_color() -> Color:
	match season_index:
		1: return Color(0.48, 0.65, 0.76, 0.62)  # winter
		2: return Color(0.55, 0.70, 0.63, 0.62)  # spring
		3: return Color(0.91, 0.67, 0.36, 0.70)  # summer
		_: return Color(0.72, 0.55, 0.39, 0.62)  # autumn

func _arc_position(progress: float) -> Vector2:
	var pad := 21.0
	var horizon := size.y - 21.0
	var x := lerpf(pad, size.x - pad, progress)
	var y := horizon - sin(progress * PI) * maxf(16.0, size.y - 42.0)
	return Vector2(x, y)

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var horizon := size.y - 21.0
	var arc_points := PackedVector2Array()
	for i in 33:
		arc_points.append(_arc_position(float(i) / 32.0))
	var arc_color := _season_arc_color()
	draw_polyline(arc_points, arc_color, 1.4, true)
	draw_line(Vector2(8.0, horizon), Vector2(size.x - 8.0, horizon), Color(0.31, 0.38, 0.44, 0.55), 1.0)
	# Small horizon ticks make rise/set readable without labels crowding the compact widget.
	draw_line(Vector2(21.0, horizon - 3.0), Vector2(21.0, horizon + 3.0), arc_color, 1.0)
	draw_line(Vector2(size.x - 21.0, horizon - 3.0), Vector2(size.x - 21.0, horizon + 3.0), arc_color, 1.0)
	var body_pos := _arc_position(displayed_progress)
	var body_size := 38.0 if showing_sun else 34.0
	var glow := Color(0.95, 0.66, 0.24, 0.13) if showing_sun else Color(0.45, 0.67, 0.88, 0.12)
	draw_circle(body_pos, body_size * 0.55, glow)
	var texture: Texture2D = SUN if showing_sun else MOON
	draw_texture_rect(texture, Rect2(body_pos - Vector2.ONE * body_size * 0.5, Vector2.ONE * body_size), false)
