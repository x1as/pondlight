class_name UIButton
extends Button
## Wooden button whose icon + caption are centred together as one group, horizontally and
## vertically (Godot's built-in Button pins the icon to the left edge). The caption is
## translated, follows the button state colours and sinks 1 px while pressed.

var caption: String = "":
	set = set_caption
var _box: HBoxContainer
var _icon: TextureRect
var _label: Label
var _min_user := Vector2.ZERO


func _init() -> void:
	clip_contents = false
	_box = HBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 4)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_icon = TextureRect.new()
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon.custom_minimum_size = Vector2(12, 12)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.visible = false
	_box.add_child(_icon)
	_label = Label.new()
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	_box.add_child(_label)
	draw.connect(_sync_state)
	resized.connect(_layout)


func set_caption(t: String) -> void:
	caption = UIKit.T(t)
	_label.text = caption
	_label.visible = caption != ""
	_fit()


func set_icon_texture(tex: Texture2D) -> void:
	_icon.texture = tex
	_icon.visible = tex != null
	_fit()


func set_min_width(w: float) -> void:
	_min_user.x = w
	_fit()


func set_min_size(v: Vector2) -> void:
	_min_user = v
	_fit()


func _fit() -> void:
	var need := _box.get_combined_minimum_size() + Vector2(14, 8)
	custom_minimum_size = Vector2(maxf(need.x, _min_user.x), maxf(need.y, maxf(_min_user.y, 18.0)))
	_layout()


func _notification(what: int) -> void:
	# captions are measured again once the pixel-font theme is actually in effect
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_fit.call_deferred()


func _layout() -> void:
	_box.position = Vector2(0, 1 if _pressed_look() else 0)
	_box.size = size


func _pressed_look() -> bool:
	var m := get_draw_mode()
	return m == DRAW_PRESSED or m == DRAW_HOVER_PRESSED


func _sync_state() -> void:
	var key := "font_color"
	match get_draw_mode():
		DRAW_HOVER:
			key = "font_hover_color"
		DRAW_PRESSED, DRAW_HOVER_PRESSED:
			key = "font_pressed_color"
		DRAW_DISABLED:
			key = "font_disabled_color"
	if has_focus() and get_draw_mode() == DRAW_NORMAL:
		key = "font_focus_color"
	_label.add_theme_color_override("font_color", get_theme_color(key, "Button"))
	_icon.modulate = Color(1, 1, 1, 0.5) if disabled else Color.WHITE
	_layout()
