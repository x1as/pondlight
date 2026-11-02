class_name CastMeter
extends Control
## Cast power bar: weak / normal / PERFECT / normal / over zones with a ping-pong needle.

var value := 0.0
var bounds := {"weak": 0.42, "perfect_lo": 0.72, "perfect_hi": 0.86}
var _t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(132, 18)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := 128.0
	var x0 := 2.0
	var y0 := 6.0
	var h := 8.0
	draw_rect(Rect2(x0 - 2, y0 - 2, w + 4, h + 4), Color("#120c08"))
	draw_rect(Rect2(x0 - 1, y0 - 1, w + 2, h + 2), Color("#6b4021"))
	var zones := [
		[0.0, bounds["weak"], Color("#8c592d")],
		[bounds["weak"], bounds["perfect_lo"], Color("#e3cc98")],
		[bounds["perfect_lo"], bounds["perfect_hi"], Color("#56c043")],
		[bounds["perfect_hi"], 0.94, Color("#e3cc98")],
		[0.94, 1.0, Color("#e2433a")],
	]
	for z in zones:
		var a := floorf(x0 + w * float(z[0]))
		var b := floorf(x0 + w * float(z[1]))
		draw_rect(Rect2(a, y0, b - a, h), z[2])
		draw_rect(Rect2(a, y0, b - a, 1), (z[2] as Color).lightened(0.3))
		draw_rect(Rect2(a, y0 + h - 1, b - a, 1), (z[2] as Color).darkened(0.25))
	# perfect zone gold frame
	var pa := floorf(x0 + w * bounds["perfect_lo"])
	var pb := floorf(x0 + w * bounds["perfect_hi"])
	draw_rect(Rect2(pa, y0 - 1, pb - pa, 1), Color("#ffd04a"))
	draw_rect(Rect2(pa, y0 + h, pb - pa, 1), Color("#ffd04a"))
	# needle
	var nx := floorf(x0 + w * value)
	var in_perfect: bool = value >= float(bounds["perfect_lo"]) and value <= float(bounds["perfect_hi"])
	var col := Color("#fff6dc") if not in_perfect else Color("#fff0a0")
	draw_rect(Rect2(nx - 2, y0 - 4, 5, h + 8), Color("#120c08"))
	draw_rect(Rect2(nx - 1, y0 - 3, 3, h + 6), col)
	draw_rect(Rect2(nx - 1, y0 - 3, 3, 1), Color.WHITE)
	if in_perfect and not Settings.reduced_flashing and int(_t * 12.0) % 2 == 0:
		draw_rect(Rect2(pa, y0, pb - pa, h), Color(1, 1, 0.8, 0.25))
