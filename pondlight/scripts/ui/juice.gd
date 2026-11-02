class_name Juice
extends RefCounted
## Small reusable spectacle pieces for the HUD: coin flights, the frenzy frame and the letterbox cinematic.


class CoinFlight:
	extends Control
	## Coins arc from a point on screen into the coin counter, each landing with a rising "ting".
	var from := Vector2(320, 180)
	var to := Vector2(600, 12)
	var count := 6
	var _coins: Array[Dictionary] = []
	var _t := 0.0
	var _landed := 0
	var _tex: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		_tex = UIKit.icon_tex("coin")
		for i in count:
			var side := Vector2(randf_range(-40, 40), randf_range(-50, -10))
			_coins.append({"delay": i * 0.045, "mid": from + side, "done": false})

	func _process(delta: float) -> void:
		_t += delta
		var alive := false
		for c in _coins:
			var k := clampf((_t - float(c["delay"])) / 0.55, 0.0, 1.0)
			if k < 1.0:
				alive = true
			elif not bool(c["done"]):
				c["done"] = true
				_landed += 1
				Audio.play_pitched("ui_click", 1.0 + _landed * 0.07, -8.0)
		if not alive:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for c in _coins:
			var k := clampf((_t - float(c["delay"])) / 0.55, 0.0, 1.0)
			if k <= 0.0 or k >= 1.0:
				continue
			var e := k * k * (3.0 - 2.0 * k)
			var mid: Vector2 = c["mid"]
			var p := from.lerp(mid, e).lerp(mid.lerp(to, e), e)
			draw_texture(_tex, (p - Vector2(6, 6)).floor())


class FrenzyFrame:
	extends Control
	## Flickering pixel flames around the screen edge while a Feeding Frenzy lasts.
	var time_left := 0.0
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if time_left <= 0.0:
			return
		var cols := [Color("#ffd84a"), Color("#ff9a3c"), Color("#e2433a")]
		var a := 0.75 if Settings.reduced_flashing else 0.85 + 0.15 * sin(_t * 9.0)
		for x in range(0, 640, 2):
			var h := 2 + int(3.0 * (0.5 + 0.5 * sin(x * 0.37 + _t * 11.0)) * (0.6 + 0.4 * sin(x * 0.11 - _t * 5.0)))
			for y in h:
				var c: Color = cols[mini(2, y)]
				draw_rect(Rect2(x, 359 - y, 2, 1), Color(c, a))
				draw_rect(Rect2(x, y, 2, 1), Color(c, a * 0.7))
		for y in range(0, 360, 2):
			var w := 1 + int(2.0 * (0.5 + 0.5 * sin(y * 0.41 + _t * 10.0)))
			for x in w:
				draw_rect(Rect2(x, y, 1, 2), Color(cols[mini(2, x)], a * 0.8))
				draw_rect(Rect2(639 - x, y, 1, 2), Color(cols[mini(2, x)], a * 0.8))
		var txt := UIKit.T("FRENZY %ds") % int(ceil(time_left))
		var f := UIKit.font()
		var w2 := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var pos := Vector2(floorf((640 - w2) / 2.0), 352)
		draw_rect(Rect2(pos.x - 4, 342, w2 + 8, 13), Color("#120c08"))
		draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ffd84a"))


class Letterbox:
	extends Control
	## Cinema bars + a stamped title for legendary, prismatic and boss catches.
	var bar := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var h := floorf(bar * 30.0)
		if h <= 0.0:
			return
		draw_rect(Rect2(0, 0, 640, h), Color(0, 0, 0, 0.92))
		draw_rect(Rect2(0, 360 - h, 640, h), Color(0, 0, 0, 0.92))
		draw_rect(Rect2(0, h, 640, 1), Color("#ffd04a", bar * 0.6))
		draw_rect(Rect2(0, 359 - h, 640, 1), Color("#ffd04a", bar * 0.6))
