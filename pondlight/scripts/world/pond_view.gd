class_name PondView
extends Node2D
## Builds and animates one pond diorama from its generated layers and pond data.
##
## Draw order: sky, water(shader), ripples, ground, props, canopy, fog, weather,
## [rod + splashes added by the fishing controller], night multiply overlay, glow (aurora/fireflies), cursor.

const W := 640
const H := 360

var pond_id := ""
var pond: Dictionary = {}
var cell_size := Vector2(26, 26)
var origin := Vector2.ZERO
var under_fx: FxLayer
var over_fx: FxLayer
var weather_fx: WeatherFx
var glow_fx: WeatherFx
var cursor: CellCursor
var golden_fx: GoldenSpotFx
var golden_cell := Vector2i(-1, -1):
	set(v):
		golden_cell = v
		if golden_fx:
			golden_fx.active = v.x >= 0
			if v.x >= 0:
				golden_fx.cell_rect = cell_rect(v)
var habitat: HabitatOverlay
var actor_layer: Node2D
var water_mat: ShaderMaterial
var night_overlay: ColorRect
var aurora: ColorRect
var fog: ColorRect
var _bubble_t := 0.0
var _ambient_ripple_t := 1.0


func build(id: String) -> void:
	for c in get_children():
		c.queue_free()
	pond_id = id
	pond = Data.ponds[id]
	cell_size = Vector2(pond["cell_size"][0], pond["cell_size"][1])
	origin = Vector2(pond["grid_origin"][0], pond["grid_origin"][1])
	var dir := "res://assets/art/world/%s/" % id
	if ResourceLoader.exists(dir + "sky.png"):
		_sprite(dir + "sky.png")
	var water := _sprite(dir + "water.png")
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://assets/shaders/water.gdshader")
	water_mat.set_shader_parameter("flow_tex", load(dir + "flow.png"))
	var wc: Variant = pond.get("water")
	if wc is Array:
		water_mat.set_shader_parameter("hi_color", Color(String(wc[0])))
		water_mat.set_shader_parameter("mid_color", Color(String(wc[1])))
		water_mat.set_shader_parameter("foam_color", Color(String(wc[2])))
	water.material = water_mat
	under_fx = FxLayer.new()
	add_child(under_fx)
	_sprite(dir + "ground.png")
	_sprite(dir + "props.png")
	_sprite(dir + "canopy.png")
	if Data.pond_flag(id, "fog") or Data.pond_flag(id, "mist"):
		fog = ColorRect.new()
		fog.size = Vector2(W, H)
		fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fm := ShaderMaterial.new()
		fm.shader = load("res://assets/shaders/fog.gdshader")
		fog.material = fm
		add_child(fog)
	golden_fx = GoldenSpotFx.new()
	add_child(golden_fx)
	weather_fx = WeatherFx.new()
	weather_fx.leaves = Data.pond_flag(id, "leaves")
	weather_fx.water_rects = _water_rects()
	weather_fx.raindrop_hit.connect(func(p: Vector2) -> void: under_fx.ripple(p, 4.0, 0.5))
	add_child(weather_fx)
	actor_layer = Node2D.new()
	actor_layer.name = "Actors"
	add_child(actor_layer)
	over_fx = FxLayer.new()
	add_child(over_fx)
	night_overlay = ColorRect.new()
	night_overlay.size = Vector2(W, H)
	night_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mm := CanvasItemMaterial.new()
	mm.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	night_overlay.material = mm
	add_child(night_overlay)
	if Data.pond_flag(id, "aurora"):
		aurora = ColorRect.new()
		aurora.size = Vector2(W, H)
		aurora.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var am := ShaderMaterial.new()
		am.shader = load("res://assets/shaders/aurora.gdshader")
		am.set_shader_parameter("occluder", load(dir + "ground.png"))
		aurora.material = am
		add_child(aurora)
	glow_fx = WeatherFx.new()
	glow_fx.fireflies = Data.pond_flag(id, "fireflies")
	for l in pond.get("lamps", []):
		glow_fx.lamps.append(Vector2(float(l[0]), float(l[1])))
	add_child(glow_fx)
	habitat = HabitatOverlay.new()
	habitat.pond_id = id
	habitat.cell_rect_fn = cell_rect
	add_child(habitat)
	cursor = CellCursor.new()
	add_child(cursor)
	apply_weather(Clock.weather(id))
	_update_light()


func _sprite(path: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	add_child(s)
	return s


func _water_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for c in Data.fishable_cells(pond_id):
		out.append(cell_rect(c))
	return out


# ------------------------------------------------------------------ grid
func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(c) * cell_size, cell_size)


func cell_center(c: Vector2i) -> Vector2:
	var r := cell_rect(c)
	return (r.position + r.size * 0.5 + Vector2(0, 1)).floor()


func cell_at(pos: Vector2) -> Vector2i:
	var rel := (pos - origin) / cell_size
	var c := Vector2i(floori(rel.x), floori(rel.y))
	if c.x < 0 or c.y < 0 or c.x >= Data.pond_cols(pond_id) or c.y >= Data.pond_rows(pond_id):
		return Vector2i(-1, -1)
	return c


func effective_reach(reach: int) -> int:
	return reach - int(pond.get("reach_offset", 0))


func is_reachable(c: Vector2i, reach: int) -> bool:
	## Wilder waters start further out: a pond's reach_offset is subtracted from the rod's reach.
	return Data.pond_rows(pond_id) - 1 - c.y < reach - int(pond.get("reach_offset", 0))


# ------------------------------------------------------------------ atmosphere
func apply_weather(w: String) -> void:
	weather_fx.mode = w if w in ["rain", "snow"] else ""
	if water_mat:
		water_mat.set_shader_parameter("rain", 1.0 if w == "rain" else 0.0)


func _update_light() -> void:
	var dl := Clock.daylight()
	var tint: Color = dl["tint"]
	var night: float = dl["night"]
	if weather_fx and weather_fx.mode == "rain":
		tint = tint * Color(0.82, 0.86, 0.92)
	night_overlay.color = tint
	glow_fx.night = night
	if aurora:
		var s := clampf((night - 0.4) / 0.5, 0.0, 1.0) * (0.7 if Clock.weather(pond_id) == "snow" else 1.0)
		(aurora.material as ShaderMaterial).set_shader_parameter("strength", s)
	if fog:
		var dens := 0.16 + night * 0.08 + (0.08 if weather_fx.mode == "snow" else 0.0)
		if Data.pond_flag(pond_id, "mist"):
			dens = 0.06 + night * 0.06 + (0.05 if weather_fx.mode == "rain" else 0.0)
		(fog.material as ShaderMaterial).set_shader_parameter("density", dens)


func _process(delta: float) -> void:
	if night_overlay == null:
		return
	_update_light()
	# ambient life: bubbles and occasional rings so the pond never looks frozen in time
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble_t = randf_range(0.6, 1.8)
		var cells := Data.fishable_cells(pond_id)
		if not cells.is_empty():
			var c: Vector2i = cells[randi() % cells.size()]
			var r := cell_rect(c)
			var p := r.position + Vector2(randf_range(4, r.size.x - 4), randf_range(4, r.size.y - 4))
			if bool(pond.get("holes", false)):
				p = cell_center(c) + Vector2(randf_range(-4, 4), randf_range(-1, 2))
			under_fx.bubble(p)
	_ambient_ripple_t -= delta
	if _ambient_ripple_t <= 0.0 and Data.pond_flag(pond_id, "ripples"):
		_ambient_ripple_t = randf_range(2.5, 6.0)
		var cells2 := Data.fishable_cells(pond_id)
		var c2: Vector2i = cells2[randi() % cells2.size()]
		under_fx.ripple(cell_rect(c2).get_center() + Vector2(randf_range(-8, 8), randf_range(-6, 6)), randf_range(5, 9), 1.3)
