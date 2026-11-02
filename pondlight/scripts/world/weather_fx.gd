class_name WeatherFx
extends Node2D
## Rain streaks, snowfall, drifting leaves and night fireflies - all drawn per pixel.

signal raindrop_hit(pos: Vector2)

var mode := ""          # "rain", "snow" or ""
var leaves := false
var fireflies := false
var lamps: Array[Vector2] = []
var night := 0.0
var water_rects: Array[Rect2] = []
var _rain: Array[Dictionary] = []
var _snow: Array[Dictionary] = []
var _leaves: Array[Dictionary] = []
var _flies: Array[Dictionary] = []
var _leaf_tex: Texture2D
var _intensity := 0.0


func _ready() -> void:
	_leaf_tex = load("res://assets/art/fx/leaves.png")
	for i in 14:
		_flies.append({"p": Vector2(randf_range(40, 600), randf_range(60, 330)), "ph": randf() * TAU, "sp": randf_range(0.4, 1.0)})


func _process(delta: float) -> void:
	var target := 1.0 if mode != "" else 0.0
	_intensity = move_toward(_intensity, target, delta * 0.4)
	if mode == "rain" or (_intensity > 0.0 and not _rain.is_empty()):
		var want := int(160 * _intensity) if mode == "rain" else 0
		while _rain.size() < want:
			_rain.append(_new_drop(true))
	if mode == "snow" or (_intensity > 0.0 and not _snow.is_empty()):
		var want_s := int(140 * _intensity) if mode == "snow" else 0
		while _snow.size() < want_s:
			_snow.append(_new_flake(true))
	for d in _rain:
		d["p"] = (d["p"] as Vector2) + Vector2(-60, 300) * delta * float(d["s"])
		if (d["p"] as Vector2).y >= float(d["end"]):
			if _on_water(d["p"]) and randf() < 0.5:
				raindrop_hit.emit((d["p"] as Vector2).round())
			d["dead"] = true
	_rain = _rain.filter(func(d: Dictionary) -> bool: return not d.has("dead"))
	if mode != "rain":
		_rain = _rain.slice(0, int(_rain.size() * 0.97))
	for f in _snow:
		f["ph"] = float(f["ph"]) + delta
		f["p"] = (f["p"] as Vector2) + Vector2(sin(float(f["ph"]) * 1.3) * 8.0 - 6.0, 18.0 * float(f["s"])) * delta
		if (f["p"] as Vector2).y > float(f["end"]):
			f["dead"] = true
	_snow = _snow.filter(func(f: Dictionary) -> bool: return not f.has("dead"))
	if mode != "snow":
		_snow = _snow.slice(0, int(_snow.size() * 0.98))
	if leaves and _leaves.size() < 6 and randf() < delta * 0.5:
		_leaves.append({"p": Vector2(randf_range(60, 640), -6), "ph": randf() * TAU, "k": randi() % 3,
			"end": randf_range(80, 340), "rest": 0.0})
	for l in _leaves:
		if float(l["rest"]) > 0.0:
			l["rest"] = float(l["rest"]) + delta
			if float(l["rest"]) > 4.0:
				l["dead"] = true
			continue
		l["ph"] = float(l["ph"]) + delta * 2.0
		l["p"] = (l["p"] as Vector2) + Vector2(sin(float(l["ph"])) * 16.0 - 8.0, 14.0) * delta
		if (l["p"] as Vector2).y > float(l["end"]):
			l["rest"] = 0.01
	_leaves = _leaves.filter(func(l: Dictionary) -> bool: return not l.has("dead"))
	for f in _flies:
		f["ph"] = float(f["ph"]) + delta * float(f["sp"])
	queue_redraw()


func _on_water(p: Vector2) -> bool:
	for r in water_rects:
		if r.has_point(p):
			return true
	return false


func _new_drop(anywhere: bool) -> Dictionary:
	var y := randf_range(-40, 360) if anywhere else -10.0
	return {"p": Vector2(randf_range(0, 700), y), "s": randf_range(0.8, 1.2), "end": randf_range(maxf(y, 40.0), 365.0)}


func _new_flake(anywhere: bool) -> Dictionary:
	var y := randf_range(-20, 360) if anywhere else -6.0
	return {"p": Vector2(randf_range(0, 680), y), "s": randf_range(0.5, 1.4), "ph": randf() * TAU,
		"end": randf_range(maxf(y, 90.0), 365.0), "big": randf() < 0.25}


func _draw() -> void:
	var rc := Color(0.78, 0.9, 1.0, 0.55)
	for d in _rain:
		var p: Vector2 = (d["p"] as Vector2).floor()
		draw_rect(Rect2(p, Vector2.ONE), rc)
		draw_rect(Rect2(p + Vector2(1, -3), Vector2.ONE), Color(rc, 0.35))
		draw_rect(Rect2(p + Vector2(0, -2), Vector2.ONE), Color(rc, 0.45))
	for f in _snow:
		var p: Vector2 = (f["p"] as Vector2).floor()
		draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, 0.9))
		if f["big"]:
			draw_rect(Rect2(p + Vector2(1, 0), Vector2.ONE), Color(0.86, 0.93, 1.0, 0.8))
			draw_rect(Rect2(p + Vector2(0, 1), Vector2.ONE), Color(0.86, 0.93, 1.0, 0.6))
	for l in _leaves:
		var a := 1.0
		if float(l["rest"]) > 0.0:
			a = 1.0 - float(l["rest"]) / 4.0
		var src := Rect2(int(l["k"]) * 5, 0, 5, 4)
		var flip := sin(float(l["ph"])) < 0.0
		var dst := Rect2((l["p"] as Vector2).floor(), Vector2(-5 if flip else 5, 4))
		draw_texture_rect_region(_leaf_tex, dst, src, Color(1, 1, 1, a))
	if not lamps.is_empty() and night > 0.15:
		var la := clampf((night - 0.15) / 0.5, 0.0, 1.0)
		var flick := 0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.011)
		for lp in lamps:
			for r in [9.0, 6.0, 3.5]:
				var a := la * flick * (0.10 if r > 8.0 else (0.16 if r > 5.0 else 0.28))
				draw_circle(lp, r, Color(1.0, 0.82, 0.45, a))
	if fireflies and night > 0.3:
		var na := clampf((night - 0.3) / 0.5, 0.0, 1.0)
		for f in _flies:
			var ph := float(f["ph"])
			var p := (f["p"] as Vector2) + Vector2(sin(ph * 0.7) * 22.0, sin(ph * 1.1) * 10.0)
			var glow := (sin(ph * 3.0) * 0.5 + 0.5)
			if glow < 0.25:
				continue
			var c := Color(0.95, 1.0, 0.55, na * glow)
			p = p.floor()
			draw_rect(Rect2(p, Vector2.ONE), c)
			var halo := Color(0.85, 1.0, 0.4, na * glow * 0.3)
			for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_rect(Rect2(p + o, Vector2.ONE), halo)
