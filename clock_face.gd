class_name ClockFace
extends Control
## A minimal analog clock face; `sweep` (0..1) rotates the single hand clockwise from 12.

var sweep: float = 0.0
var accent: Color = Color(0.910, 0.678, 0.361)
const RING := Color(0.49, 0.55, 0.60, 0.75)
const FACE := Color(0.067, 0.098, 0.133, 0.96)

func set_sweep(v: float) -> void:
	sweep = v
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.5
	draw_circle(c, r, FACE)
	draw_arc(c, r - 2.0, 0.0, TAU, 64, RING, 2.0, true)
	for i in 12:
		var a := float(i) * TAU / 12.0 - PI / 2.0
		var inner: float = r - (7.0 if i % 3 == 0 else 4.0)
		draw_line(c + Vector2(cos(a), sin(a)) * inner, c + Vector2(cos(a), sin(a)) * (r - 2.0), RING, 1.5)
	var ang := -PI / 2.0 + sweep * TAU
	draw_line(c, c + Vector2(cos(ang), sin(ang)) * (r - 14.0), accent, 2.5)
	draw_circle(c, 3.0, accent)
