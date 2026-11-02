class_name FxLayer
extends Node2D
## Pixel-exact water effects: elliptical ripples, bubbles, splash droplets.
## One instance sits under the ground layer (ripples are clipped by the shore),
## one sits above props (droplets fly over everything).

var ripples: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var bubbles: Array[Dictionary] = []
var ripple_color := Color(0.77, 0.96, 0.89, 1.0)
var drop_colors: Array[Color] = [Color("#c4f5e2"), Color("#7fdcc2"), Color("#ffffff")]


func ripple(pos: Vector2, max_r: float = 10.0, life: float = 0.9, delay: float = 0.0) -> void:
	ripples.append({"p": pos.round(), "r": 1.0, "max": max_r, "t": -delay, "life": life})


var sparks: Array[Dictionary] = []
var rings: Array[Dictionary] = []


func burst(pos: Vector2, color: Color, count: int = 12) -> void:
	for i in count:
		var a := TAU * i / count + randf_range(-0.2, 0.2)
		var v := randf_range(50.0, 110.0)
		sparks.append({"p": pos, "v": Vector2(cos(a), sin(a) * 0.8) * v, "t": 0.0, "life": randf_range(0.25, 0.5),
			"c": color.lerp(Color.WHITE, randf() * 0.4)})
	rings.append({"p": pos.floor(), "t": 0.0, "life": 0.25, "c": color, "max": 8.0 + count * 0.4})


func splash(pos: Vector2, power: float = 1.0) -> void:
	var n := int(8 + power * 10)
	for i in n:
		var a := randf_range(-PI * 0.92, -PI * 0.08)
		var v := randf_range(30.0, 70.0) * (0.6 + power * 0.5)
		drops.append({"p": pos + Vector2(randf_range(-2, 2), 0), "v": Vector2(cos(a) * v * 0.7, sin(a) * v),
			"t": 0.0, "life": randf_range(0.35, 0.65), "c": drop_colors[i % drop_colors.size()], "floor": pos.y + randf_range(-1, 2)})
	ripple(pos, 7.0 + power * 6.0, 0.8)
	ripple(pos, 4.0 + power * 3.0, 0.6, 0.15)


func bubble(pos: Vector2) -> void:
	bubbles.append({"p": pos.round(), "t": 0.0, "life": randf_range(0.5, 0.9)})


func _process(delta: float) -> void:
	for r in ripples:
		r["t"] = float(r["t"]) + delta
		var k := clampf(float(r["t"]) / float(r["life"]), 0.0, 1.0)
		r["r"] = 1.0 + (float(r["max"]) - 1.0) * (1.0 - pow(1.0 - k, 2.0))
	ripples = ripples.filter(func(r: Dictionary) -> bool: return float(r["t"]) < float(r["life"]))
	for d in drops:
		d["t"] = float(d["t"]) + delta
		d["v"] = (d["v"] as Vector2) + Vector2(0, 220.0) * delta
		d["p"] = (d["p"] as Vector2) + (d["v"] as Vector2) * delta
	drops = drops.filter(func(d: Dictionary) -> bool:
		return float(d["t"]) < float(d["life"]) and (d["p"] as Vector2).y <= float(d["floor"]) + 1.0 or float(d["t"]) < 0.08)
	for s in sparks:
		s["t"] = float(s["t"]) + delta
		s["v"] = (s["v"] as Vector2) * pow(0.05, delta)
		s["p"] = (s["p"] as Vector2) + (s["v"] as Vector2) * delta
	sparks = sparks.filter(func(s: Dictionary) -> bool: return float(s["t"]) < float(s["life"]))
	for r in rings:
		r["t"] = float(r["t"]) + delta
	rings = rings.filter(func(r: Dictionary) -> bool: return float(r["t"]) < float(r["life"]))
	for b in bubbles:
		b["t"] = float(b["t"]) + delta
	bubbles = bubbles.filter(func(b: Dictionary) -> bool: return float(b["t"]) < float(b["life"]))
	queue_redraw()


func _px(p: Vector2, c: Color) -> void:
	draw_rect(Rect2(p.floor(), Vector2.ONE), c)


func _draw() -> void:
	for r in ripples:
		if float(r["t"]) < 0.0:
			continue
		var k := float(r["t"]) / float(r["life"])
		var rad := float(r["r"])
		var c := ripple_color
		c.a = (1.0 - k) * 0.85
		var center: Vector2 = r["p"]
		var steps := int(clampf(rad * 5.0, 12.0, 80.0))
		var seen := {}
		for i in steps:
			var a := TAU * float(i) / float(steps)
			var p := center + Vector2(cos(a) * rad, sin(a) * rad * 0.42)
			var key := p.floor()
			if seen.has(key):
				continue
			seen[key] = true
			# break the ring into dashes as it fades: reads as water, not as a vector circle
			if k > 0.45 and (int(key.x) + int(key.y)) % 3 == 0:
				continue
			_px(p, c)
	for b in bubbles:
		var k := float(b["t"]) / float(b["life"])
		var p: Vector2 = b["p"] + Vector2(0, -k * 2.0)
		var c := Color(0.86, 1.0, 0.95, 1.0 - k)
		_px(p, c)
		if k > 0.6:
			_px(p + Vector2(1, 0), c)
			_px(p + Vector2(-1, 0), c)
	for r in rings:
		var k := float(r["t"]) / float(r["life"])
		var rad := 2.0 + float(r["max"]) * ease(k, 0.4)
		var col: Color = r["c"]
		var seen := {}
		for i in 40:
			var a := TAU * i / 40.0
			var p := ((r["p"] as Vector2) + Vector2(cos(a), sin(a)) * rad).floor()
			if not seen.has(p):
				seen[p] = true
				_px(p, Color(col.lerp(Color.WHITE, 0.4), 1.0 - k))
	for s in sparks:
		var k := float(s["t"]) / float(s["life"])
		var p: Vector2 = s["p"]
		_px(p, Color(s["c"], 1.0 - k * 0.6))
		if k < 0.35:
			_px(p - (s["v"] as Vector2).normalized(), Color(s["c"], 0.6))
	for d in drops:
		var c: Color = d["c"]
		c.a = 1.0 - float(d["t"]) / float(d["life"]) * 0.5
		_px(d["p"], c)
