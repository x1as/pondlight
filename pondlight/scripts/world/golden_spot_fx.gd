class_name GoldenSpotFx
extends Node2D
## A golden spot: a pulsing pixel ring of light on the water with sparkles rising from it.

var cell_rect := Rect2()
var active := false
var _t := 0.0
var _sparks: Array[Dictionary] = []


func _process(delta: float) -> void:
	_t += delta
	if active and randf() < delta * 14.0:
		var c := cell_rect.get_center()
		_sparks.append({"p": c + Vector2(randf_range(-14, 14), randf_range(-6, 6)), "t": 0.0, "life": randf_range(0.5, 1.0)})
	for s in _sparks:
		s["t"] = float(s["t"]) + delta
		s["p"] = (s["p"] as Vector2) + Vector2(0, -10) * delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return float(s["t"]) < float(s["life"]))
	queue_redraw()


func _draw() -> void:
	if active:
		var c := cell_rect.get_center().floor()
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		var rx := 15.0 + pulse * 3.0
		var ry := rx * 0.42
		var seen := {}
		for i in 64:
			var a := TAU * i / 64.0
			var p := (c + Vector2(cos(a) * rx, sin(a) * ry)).floor()
			if seen.has(p):
				continue
			seen[p] = true
			draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.85, 0.3, 0.55 + pulse * 0.4))
		for i in 48:
			var a2 := TAU * i / 48.0 + _t
			var p2 := (c + Vector2(cos(a2) * (rx - 5.0), sin(a2) * (ry - 2.0))).floor()
			draw_rect(Rect2(p2, Vector2.ONE), Color(1.0, 0.95, 0.6, 0.35 + pulse * 0.3))
		draw_rect(Rect2(c - Vector2(1, 0), Vector2(3, 1)), Color(1, 0.95, 0.6, 0.8))
	for s in _sparks:
		var k := float(s["t"]) / float(s["life"])
		var p: Vector2 = (s["p"] as Vector2).floor()
		var col := Color(1.0, 0.9, 0.4, 1.0 - k)
		draw_rect(Rect2(p, Vector2.ONE), col)
		if k < 0.4:
			for o: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_rect(Rect2(p + o, Vector2.ONE), Color(col, 0.5))
