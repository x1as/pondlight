class_name HabitatOverlay
extends Node2D
## Toggleable field-guide layer: labels every fishable cell with its habitat and shows
## reach. Hidden by default so the pond stays clean; never draws grid lines.

var pond_id := ""
var reach := 3
var cell_rect_fn: Callable
var _alpha := 0.0
var shown := false


func toggle() -> void:
	shown = not shown


func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, 1.0 if shown else 0.0, delta * 6.0)
	if _alpha > 0.0 or shown:
		queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01 or pond_id == "":
		return
	var font := UIKit.font()
	var rows := Data.pond_rows(pond_id)
	for c in Data.fishable_cells(pond_id):
		var r: Rect2 = cell_rect_fn.call(c)
		var st: Dictionary = Data.spot_types[Data.spot_at(pond_id, c)]
		var col := Color(st["color"])
		var far := rows - 1 - c.y >= reach
		var text := String(st["short"])
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var center := r.get_center().floor()
		var plate := Rect2(center - Vector2(floorf(w / 2.0) + 4, 6), Vector2(w + 8, 12))
		draw_rect(plate, Color(0.07, 0.05, 0.03, 0.72 * _alpha))
		draw_rect(Rect2(plate.position, Vector2(plate.size.x, 1)), Color(col, _alpha))
		draw_string(font, plate.position + Vector2(4, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(1, 0.55, 0.45, _alpha) if far else Color(1, 0.97, 0.88, _alpha))
		# soft corner ticks in the habitat colour (not grid lines)
		var tick := Color(col, 0.65 * _alpha)
		var inner := r.grow(-3)
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var p := (inner.position + inner.size * corner - corner).floor()
			var dx := -1.0 if corner.x > 0 else 1.0
			var dy := -1.0 if corner.y > 0 else 1.0
			draw_rect(Rect2(p, Vector2(3 * dx, 1)).abs(), tick)
			draw_rect(Rect2(p, Vector2(1, 3 * dy)).abs(), tick)
