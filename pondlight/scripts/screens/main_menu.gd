class_name MainMenu
extends Node
## Title screen over the living diorama of the water you last fished (Willow Pond for a new player).

signal start_game(new_game: bool)

var pond: PondView
var ui: CanvasLayer
var _logo: TextureRect
var _t := 0.0
var _buttons: VBoxContainer
var _modal: ModalPanel


func _ready() -> void:
	var bg := "willow"
	if Save.has_save():
		var peek := Save._read(Save.path_main())
		if Data.ponds.has(String(peek.get("current_pond", ""))):
			bg = String(peek["current_pond"])
	pond = PondView.new()
	add_child(pond)
	pond.build(bg)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	# soft vignette band behind the menu so the text reads over the pond
	var band := ColorRect.new()
	band.color = Color(0.03, 0.07, 0.05, 0.35)
	band.position = Vector2(0, 0)
	band.size = Vector2(640, 96)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)
	_logo = TextureRect.new()
	_logo.texture = UIKit.tex("logo")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.size = _logo.texture.get_size() * 2
	_logo.position = Vector2(floorf((640 - _logo.size.x) / 2.0), 14)
	root.add_child(_logo)
	var tag := UIKit.label("a cozy fishing tale", 10, Color("#ecd2a0"), HORIZONTAL_ALIGNMENT_CENTER)
	tag.size = Vector2(640, 12)
	tag.position = Vector2(0, 80)
	root.add_child(tag)
	var panel := UIKit.panel()
	panel.position = Vector2(232, 196)
	panel.custom_minimum_size = Vector2(176, 0)
	root.add_child(panel)
	_buttons = UIKit.vbox(4)
	panel.add_child(_buttons)
	if Save.has_save():
		_add("Continue", "rod", true, func() -> void: start_game.emit(false))
	_add("New Game", "star", not Save.has_save(), _on_new)
	_add("Settings", "gear", false, func() -> void: _open(SettingsPanel.new()))
	if Platform.can_fullscreen() and Settings.using_touch:
		_add("Fullscreen", "map", false, func() -> void: Platform.toggle_fullscreen())
	if not Platform.is_web:
		_add("Quit", "close", false, func() -> void: Save.quit_game())
	var ver := UIKit.label(UIKit.T("v%s  -  offline, no microtransactions") % ProjectSettings.get_setting("application/config/version"), 10, Color(1, 1, 1, 0.55))
	ver.position = Vector2(6, 346)
	root.add_child(ver)
	Audio.music(String(Data.ponds[bg]["music"]))
	Audio.ambient(String(Data.ponds[bg]["ambient"]), "")
	(_buttons.get_child(0) as Button).grab_focus.call_deferred()
	Platform.game_ready()
	Platform.set_gameplay(false)


func _add(text: String, icon_name: String, primary: bool, cb: Callable) -> void:
	var b := UIKit.button(text, icon_name, primary)
	b.set_min_size(Vector2(152, 20))
	b.pressed.connect(cb)
	_buttons.add_child(b)


func _on_new() -> void:
	if not Save.has_save():
		start_game.emit(true)
		return
	_open(ConfirmPanel.new().setup("Start over?", "This replaces your current save.", func() -> void: start_game.emit(true)))


func _open(p: ModalPanel) -> void:
	if _modal != null:
		return
	_modal = p
	ui.add_child(p)
	p.closed.connect(func() -> void:
		_modal = null
		(_buttons.get_child(0) as Button).grab_focus())


func _process(delta: float) -> void:
	_t += delta
	_logo.position.y = 14 + roundf(sin(_t * 1.4) * 1.0)


class ConfirmPanel:
	extends ModalPanel
	var _text := ""
	var _cb: Callable

	func setup(t: String, text: String, cb: Callable) -> ConfirmPanel:
		title = t
		_text = text
		_cb = cb
		panel_size = Vector2(240, 100)
		return self

	func _build() -> void:
		content.add_child(UIKit.label(_text))
		var h := UIKit.hbox(6)
		var no := UIKit.button("Cancel")
		no.pressed.connect(close)
		var yes := UIKit.button("Start over", "check", true)
		yes.pressed.connect(func() -> void:
			close()
			_cb.call())
		h.add_child(no)
		h.add_child(yes)
		content.add_child(h)
