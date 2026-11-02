class_name CellCursor
extends Node2D
## Subtle selection effect: four pulsing pixel corner brackets + a faint inner tint.
## Grid lines are never drawn.

var cell_rect := Rect2()
var target_rect := Rect2()
var state := "hidden"   # hidden | valid | far | blocked
var _t := 0.0
var _alpha := 0.0


func show_cell(r: Rect2, s: String) -> void:
	if state == "hidden" or _alpha < 0.05:
		cell_rect = r
	target_rect = r
	state = s


func hide_cursor() -> void:
	state = "hidden"


func _process(delta: float) -> void:
	_t += delta
	var want := 0.0 if state == "hidden" else 1.0
	_alpha = move_toward(_alpha, want, delta * 6.0)
	# glide smoothly between cells (eased, then snapped to whole pixels when drawn)
	cell_rect.position = cell_rect.position.lerp(target_rect.position, minf(1.0, delta * 22.0))
	cell_rect.size = target_rect.size
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01:
		return
	var col := Color("#fff6dc")
	if state == "far":
		col = Color("#ff8a6a")
	elif state == "blocked":
		col = Color("#9aa7b2")
	var pulse := 1.0 + floorf((sin(_t * 4.0) * 0.5 + 0.5) * 2.0)
	var r := Rect2(cell_rect.position.round() - Vector2(pulse, pulse), cell_rect.size + Vector2(pulse, pulse) * 2.0)
	var fill := col
	fill.a = 0.10 * _alpha
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), fill)
	var c := col
	c.a = _alpha
	var sh := Color(0.05, 0.08, 0.06, 0.55 * _alpha)
	var L := 5.0
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := r.position + r.size * corner - corner
		var dx := -1.0 if corner.x > 0 else 1.0
		var dy := -1.0 if corner.y > 0 else 1.0
		# shadow first, then the bright bracket
		draw_rect(Rect2(p + Vector2(0, 1), Vector2(L * dx, 1)).abs(), sh)
		draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, L * dy)).abs(), sh)
		draw_rect(Rect2(p, Vector2(L * dx, 1)).abs(), c)
		draw_rect(Rect2(p, Vector2(1, L * dy)).abs(), c)
