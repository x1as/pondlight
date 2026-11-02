class_name Celebration
extends Control
## Catch celebration scaled by rarity: screen flash, rotating light rays from the fish,
## confetti in the rarity colour and a big rarity banner. Respects Reduced flashing.

var rarity := 0
var origin := Vector2(320, 180)
var _t := 0.0
var _life := 1.4
var _confetti: Array[Dictionary] = []
var _col := Color.WHITE


func setup(r: int, at: Vector2) -> Celebration:
	rarity = r
	origin = at
	_col = Data.rarity_color(r)
	_life = 1.0 + r * 0.25
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n: int = [0, 0, 24, 48, 90][clampi(r, 0, 4)]
	for i in n:
		var a := randf_range(-PI * 0.95, -PI * 0.05)
		var v := randf_range(60.0, 170.0)
		_confetti.append({"p": at, "v": Vector2(cos(a) * v, sin(a) * v), "c": _col.lerp(Color.WHITE, randf() * 0.5) if i % 3 else Color("#ffe066"),
			"s": randi_range(1, 2), "w": randf() * TAU})
	return self


func _process(delta: float) -> void:
	_t += delta
	for c in _confetti:
		c["v"] = (c["v"] as Vector2) * pow(0.25, delta) + Vector2(0, 120) * delta
		c["p"] = (c["p"] as Vector2) + (c["v"] as Vector2) * delta + Vector2(sin(_t * 6.0 + float(c["w"])) * 0.6, 0)
	if _t >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / _life
	var fade := 1.0 - k
	# flash
	var flash: float = [0.0, 0.0, 0.18, 0.28, 0.42][clampi(rarity, 0, 4)]
	if Settings.reduced_flashing:
		flash *= 0.3
	if _t < 0.25 and flash > 0.0:
		draw_rect(Rect2(0, 0, 640, 360), Color(_col.lerp(Color.WHITE, 0.6), flash * (1.0 - _t / 0.25)))
	# rays
	if rarity >= 2:
		var rays := 6 + rarity * 2
		var r_len := 60.0 + rarity * 30.0
		for i in rays:
			var a := TAU * i / rays + _t * 0.8
			var p2 := origin + Vector2(cos(a), sin(a)) * r_len
			draw_line(origin.round(), p2.round(), Color(_col, 0.22 * fade), 3.0)
			draw_line(origin.round(), p2.round(), Color(1, 1, 1, 0.18 * fade), 1.0)
	# confetti
	for c in _confetti:
		var s := int(c["s"])
		draw_rect(Rect2((c["p"] as Vector2).floor(), Vector2(s, s if int(_t * 12.0 + float(c["w"]) * 3.0) % 2 == 0 else 1)), Color(c["c"], fade))
