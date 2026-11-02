class_name PopText
extends Control
## Punchy pixel feedback text: 1-px dark outline, a quick "punch" (drops in from above,
## overshoots, settles), style per event kind, then rises and fades. Integer pixel motion only.

const STYLES := {
	"perfect": {"color": Color("#ffe066"), "size": 20, "life": 0.85, "shake": 0.0},
	"good": {"color": Color("#9cf06a"), "size": 10, "life": 0.7, "shake": 0.0},
	"miss": {"color": Color("#ff6f5a"), "size": 10, "life": 0.7, "shake": 2.0},
	"combo": {"color": Color("#d9a2ff"), "size": 20, "life": 1.0, "shake": 0.0},
	"warn": {"color": Color("#ff9a3c"), "size": 20, "life": 0.6, "shake": 1.0},
	"info": {"color": Color("#c7a670"), "size": 10, "life": 0.9, "shake": 0.0},
	"rare": {"color": Color("#4fb6ff"), "size": 20, "life": 1.6, "shake": 0.0},
}

var text := ""
var kind := "good"
var color := Color.WHITE
var _t := 0.0
var _life := 0.8
var _size := 10
var _shake := 0.0


func setup(t: String, k: String, c: Color = Color(0, 0, 0, 0)) -> PopText:
	text = UIKit.T(t)
	kind = k
	var st: Dictionary = STYLES.get(k, STYLES["good"])
	color = c if c.a > 0.0 else st["color"]
	_life = st["life"]
	_size = st["size"]
	_shake = st["shake"]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var font := UIKit.font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size).x
	var k := _t / _life
	# punch: start 6 px high, overshoot 2 px past rest within 0.12 s, then drift up
	var y := 0.0
	if _t < 0.06:
		y = -6.0 + _t / 0.06 * 8.0
	elif _t < 0.12:
		y = 2.0 - (_t - 0.06) / 0.06 * 2.0
	else:
		y = -16.0 * ease((_t - 0.12) / (_life - 0.12), 0.4)
	var x := 0.0
	if _shake > 0.0 and _t < 0.3:
		x = _shake * (1.0 if int(_t * 40.0) % 2 == 0 else -1.0)
	var a := 1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3
	var p := Vector2(roundf(-w / 2.0 + x), roundf(y))
	var ink := Color(0.07, 0.04, 0.03, a)
	for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		draw_string(font, p + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, ink)
	if _size >= 20:
		draw_string(font, p + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, ink)  # chunky drop shadow
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, Color(color, a))
	# a white flash on the first frames makes the hit read instantly
	if _t < 0.05 and not Settings.reduced_flashing:
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, Color(1, 1, 1, 0.8))
