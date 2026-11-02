class_name SettingsPanel
extends ModalPanel
## Audio, display and accessibility options + control reference.

var _body: VBoxContainer


func _init() -> void:
	super._init()
	title = "Settings"
	panel_size = Vector2(440, 306)


func _build() -> void:
	_body = UIKit.vbox(3)
	content.add_child(_body)
	_language_row()
	_slider("Master", "master_volume")
	_slider("Music", "music_volume")
	_slider("Sound effects", "sfx_volume")
	_slider("Ambience", "ambient_volume")
	_toggle("Fullscreen", "fullscreen")
	if not Platform.is_web:
		_scale_row()
	_toggle("Screen shake", "screen_shake")
	_toggle("Reduced flashing", "reduced_flashing")
	var ctl := UIKit.panel("DarkPanel")
	var cv := UIKit.vbox(1)
	ctl.add_child(cv)
	if Settings.using_touch:
		cv.add_child(UIKit.label("Touch: tap a spot to see its fish, hold it to cast, tap/hold to fight", 10, UIKit.MUTED))
	cv.add_child(UIKit.label("Mouse: hover water, hold LMB to cast, LMB tap/hold to fight, RMB reel in", 10, UIKit.MUTED))
	cv.add_child(UIKit.label("Keys: Space action  C codex  U shop  M map  J journal  Q bait  Esc pause", 10, UIKit.MUTED))
	cv.add_child(UIKit.label("Pad: stick/D-pad aim  A action  B cancel  Y codex  LB/RB shop/map", 10, UIKit.MUTED))
	_body.add_child(ctl)


func _row(name: String) -> HBoxContainer:
	var h := UIKit.hbox(6)
	var l := UIKit.label(name, 10, UIKit.CREAM)
	l.custom_minimum_size.x = 120
	h.add_child(l)
	_body.add_child(h)
	return h


func _slider(name: String, prop: String) -> void:
	var h := _row(name)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Settings.get(prop))
	s.custom_minimum_size = Vector2(170, 12)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	var pct := UIKit.label(UIKit.T("%d%%") % int(s.value * 100))
	s.value_changed.connect(func(v: float) -> void:
		Settings.set(prop, v)
		pct.text = UIKit.T("%d%%") % int(v * 100)
		Settings.apply()
		Settings.save_settings())
	s.drag_ended.connect(func(_c: bool) -> void: Audio.play("ui_click"))
	h.add_child(s)
	h.add_child(pct)


func _toggle(name: String, prop: String) -> void:
	var h := _row(name)
	var b := UIKit.button("On" if Settings.get(prop) else "Off", "check" if Settings.get(prop) else "close")
	b.set_min_width(60)
	b.pressed.connect(func() -> void:
		Settings.set(prop, not bool(Settings.get(prop)))
		b.caption = "On" if Settings.get(prop) else "Off"
		b.set_icon_texture(UIKit.icon_tex("check" if Settings.get(prop) else "close"))
		Settings.apply()
		Settings.save_settings())
	h.add_child(b)


func _scale_row() -> void:
	var h := _row("Window scale")
	var minus := UIKit.button("-")
	var val := UIKit.label(UIKit.T("x%d") % Settings.window_scale)
	var plus := UIKit.button("+")
	minus.pressed.connect(func() -> void:
		Settings.window_scale = maxi(1, Settings.window_scale - 1)
		Settings.apply()
		val.text = UIKit.T("x%d") % Settings.window_scale
		Settings.save_settings())
	plus.pressed.connect(func() -> void:
		Settings.window_scale = mini(6, Settings.window_scale + 1)
		Settings.apply()
		val.text = UIKit.T("x%d") % Settings.window_scale
		Settings.save_settings())
	h.add_child(minus)
	h.add_child(val)
	h.add_child(plus)


func _language_row() -> void:
	var h := _row("Language")
	for code: String in ["auto", "en", "ru"]:
		var label := "Auto" if code == "auto" else String(Loc.LANGUAGES[code])
		var b := UIKit.button(label, "", Settings.language == code)
		b.set_min_width(64)
		b.pressed.connect(func() -> void:
			if Settings.language == code:
				return
			Settings.language = code
			Settings.save_settings()
			Settings.apply())
		h.add_child(b)
