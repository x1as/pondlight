class_name UIKit
extends RefCounted
## Wood-and-leaf UI theme and small widget factory. No default Godot look anywhere.

const CREAM := Color("#fff6dc")
const PARCH_TEXT := Color("#3a2414")
const MUTED := Color("#c7a670")
const GOLD := Color("#ffd04a")
const GREEN := Color("#86dc4c")
const RED := Color("#ff6f5a")
const DARK := Color("#120c08")
const UI_DIR := "res://assets/art/ui/"

static var _theme: Theme
static var _font: Font


static func font() -> Font:
	if _font == null:
		var f: FontFile = load("res://assets/fonts/pond_font.fnt")
		f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
		_font = f
	return _font


static func T(s: String) -> String:
	## Translate a UI string (English source text is the key). Unknown text is returned as is.
	if s == "":
		return s
	return String(TranslationServer.translate(s))


static func release() -> void:
	_theme = null
	_font = null


static func tex(name: String) -> Texture2D:
	return load(UI_DIR + name + ".png")


static func icon_tex(name: String) -> Texture2D:
	return load(UI_DIR + "icons/icon_" + name + ".png")


static func gem_tex(rarity: int) -> Texture2D:
	return load(UI_DIR + "icons/gem_" + String(Data.rarity(rarity)["id"]) + ".png")


static func box(name: String, margin: int, content: Vector4 = Vector4(-1, -1, -1, -1), tile := true) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	if tile:
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	var c := content if content.x >= 0 else Vector4(margin, margin, margin, margin)
	sb.content_margin_left = c.x
	sb.content_margin_top = c.y
	sb.content_margin_right = c.z
	sb.content_margin_bottom = c.w
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 10
	var shadow := Color(0.05, 0.03, 0.02, 0.75)
	# Label
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_shadow_color", "Label", shadow)
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("line_spacing", "Label", 1)
	# Button
	var bc := Vector4(6, 3, 6, 5)
	t.set_stylebox("normal", "Button", box("btn_normal", 5, bc))
	t.set_stylebox("hover", "Button", box("btn_hover", 5, bc))
	t.set_stylebox("pressed", "Button", box("btn_pressed", 5, Vector4(6, 4, 6, 4)))
	t.set_stylebox("disabled", "Button", box("btn_disabled", 5, bc))
	t.set_stylebox("focus", "Button", box("focus_frame", 4, Vector4(0, 0, 0, 0), false))
	t.set_stylebox("hover_pressed", "Button", box("btn_pressed", 5, Vector4(6, 4, 6, 4)))
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color("#ecd2a0"))
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("#8a919a"))
	t.set_color("font_hover_pressed_color", "Button", Color("#ecd2a0"))
	t.set_color("font_outline_color", "Button", DARK)
	t.set_constant("h_separation", "Button", 4)
	t.set_constant("separation", "HBoxContainer", 4)
	t.set_constant("icon_max_width", "Button", 12)
	# primary (green) buttons use the "PrimaryButton" variation
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", box("btn_green", 5, bc))
	t.set_stylebox("hover", "PrimaryButton", box("btn_green_hover", 5, bc))
	t.set_stylebox("pressed", "PrimaryButton", box("btn_green_pressed", 5, Vector4(6, 4, 6, 4)))
	t.set_stylebox("hover_pressed", "PrimaryButton", box("btn_green_pressed", 5, Vector4(6, 4, 6, 4)))
	# Panels
	t.set_stylebox("panel", "PanelContainer", box("panel_wood", 14, Vector4(12, 14, 12, 10)))
	t.set_type_variation("ParchmentPanel", "PanelContainer")
	t.set_stylebox("panel", "ParchmentPanel", box("panel_parchment", 5, Vector4(6, 5, 6, 5)))
	t.set_type_variation("DarkPanel", "PanelContainer")
	t.set_stylebox("panel", "DarkPanel", box("panel_dark", 4, Vector4(5, 4, 5, 4)))
	t.set_type_variation("HeaderPanel", "PanelContainer")
	t.set_stylebox("panel", "HeaderPanel", box("panel_header", 10, Vector4(10, 8, 10, 6)))
	t.set_type_variation("PlainPanel", "PanelContainer")
	t.set_stylebox("panel", "PlainPanel", box("panel_wood_plain", 14, Vector4(10, 9, 10, 8)))
	# ProgressBar
	t.set_stylebox("background", "ProgressBar", box("bar_frame", 3, Vector4(0, 0, 0, 0)))
	t.set_stylebox("fill", "ProgressBar", _fill("green"))
	t.set_font_size("font_size", "ProgressBar", 10)
	t.set_color("font_color", "ProgressBar", CREAM)
	# Slider
	var track := box("bar_frame", 3, Vector4(0, 3, 0, 3))
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", _fill("gold"))
	t.set_stylebox("grabber_area_highlight", "HSlider", _fill("gold"))
	t.set_icon("grabber", "HSlider", icon_tex("coin"))
	t.set_icon("grabber_highlight", "HSlider", icon_tex("coin"))
	t.set_stylebox("focus", "HSlider", box("focus_frame", 4, Vector4(0, 0, 0, 0), false))
	# Scroll bars
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color("#2a170c")
	sb_bg.content_margin_left = 2
	sb_bg.content_margin_right = 2
	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = Color("#ad7439")
	sb_grab.border_color = Color("#120c08")
	sb_grab.set_border_width_all(1)
	var sb_grab_h := sb_grab.duplicate() as StyleBoxFlat
	sb_grab_h.bg_color = Color("#cc934e")
	for sbt in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sbt, sb_bg)
		t.set_stylebox("grabber", sbt, sb_grab)
		t.set_stylebox("grabber_highlight", sbt, sb_grab_h)
		t.set_stylebox("grabber_pressed", sbt, sb_grab_h)
	t.set_constant("separation", "VBoxContainer", 3)
	t.set_constant("separation", "HBoxContainer", 4)
	t.set_constant("h_separation", "GridContainer", 3)
	t.set_constant("v_separation", "GridContainer", 3)
	# Tooltip
	t.set_stylebox("panel", "TooltipPanel", box("panel_dark", 4, Vector4(5, 4, 5, 4)))
	t.set_color("font_color", "TooltipLabel", CREAM)
	_theme = t
	return t


static func _fill(color: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex("bar_fill_" + color)
	sb.texture_margin_left = 1
	sb.texture_margin_right = 1
	sb.texture_margin_top = 2
	sb.texture_margin_bottom = 2
	sb.expand_margin_top = -1
	sb.expand_margin_bottom = -1
	sb.expand_margin_left = -1
	sb.expand_margin_right = -1
	return sb


# ------------------------------------------------------------------ factory
static func label(text: String, size: int = 10, color: Color = CREAM, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = T(text)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if size != 10:
		l.add_theme_font_size_override("font_size", size)
	if color != CREAM:
		l.add_theme_color_override("font_color", color)
	if color == PARCH_TEXT or color == Color("#56361f"):
		l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.0))
	return l


static func button(text: String, icon_name: String = "", primary := false) -> UIButton:
	var b := UIButton.new()
	if icon_name != "":
		b.set_icon_texture(icon_tex(icon_name))
	b.caption = text
	if primary:
		b.theme_type_variation = "PrimaryButton"
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			Audio.play("ui_hover", 0.1, -6.0))
	b.focus_entered.connect(func() -> void:
		if Settings.using_gamepad:
			Audio.play("ui_hover", 0.1, -6.0))
	b.pressed.connect(func() -> void: Audio.play("ui_click"))
	return b


static func icon(name: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon_tex(name)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.custom_minimum_size = Vector2(12, 12)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


static func gem(rarity: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = gem_tex(rarity)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.custom_minimum_size = Vector2(8, 10)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


static func fish_tex(id: String) -> Texture2D:
	## SpriteCook-generated (hand-polished) art where it exists, procedural art otherwise.
	var sc := UIKit.T("res://assets/art/spritecook/fish_%s.png") % id
	if ResourceLoader.exists(sc):
		return load(sc)
	return load(UIKit.T("res://assets/art/fish/fish_%s.png") % id)


static func make_prismatic(t: CanvasItem) -> void:
	## Holographic foil for Prismatic catches (assets/shaders/holo.gdshader).
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/holo.gdshader")
	t.material = m


static func fish_sprite(id: String, scale_px: int = 1, silhouette := false) -> TextureRect:
	var t := TextureRect.new()
	t.texture = fish_tex(id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = t.texture.get_size() * scale_px
	if silhouette:
		t.modulate = Color(0.05, 0.08, 0.07, 0.85)
	return t


static func bar(color: String, w: int = 80, h: int = 8) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(w, h)
	p.add_theme_stylebox_override("fill", _fill(color))
	p.max_value = 1.0
	p.step = 0.0
	return p


static func panel(variation: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != "":
		p.theme_type_variation = variation
	return p


static func hbox(sep: int = 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = 3) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func spacer(w: int = 0, h: int = 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	if w == 0 and h == 0:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func coin_row(amount: int, color: Color = GOLD) -> HBoxContainer:
	var h := hbox(2)
	h.add_child(icon("coin"))
	h.add_child(label(fmt_int(amount), 10, color))
	return h


static func fmt_int(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


static func fmt_weight(kg: float) -> String:
	if kg < 1.0:
		return T("%d g") % int(round(kg * 1000.0))
	return T("%.2f kg") % kg
