extends Node
## Player settings (user://settings.cfg), audio buses, window mode and the input map.

signal changed
signal input_device_changed(is_gamepad: bool)

const PATH := "user://settings.cfg"
const BUSES: Array[String] = ["Music", "SFX", "Ambient"]

var master_volume := 0.8
var music_volume := 0.6
var sfx_volume := 0.8
var ambient_volume := 0.7
var fullscreen := false
var window_scale := 2
var screen_shake := true
var reduced_flashing := false
var using_gamepad := false
var using_touch := DisplayServer.is_touchscreen_available() and (OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"))
var language := "auto"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_setup_input()
	load_settings()
	apply()


func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = clampf(cfg.get_value("audio", "master", master_volume), 0.0, 1.0)
	music_volume = clampf(cfg.get_value("audio", "music", music_volume), 0.0, 1.0)
	sfx_volume = clampf(cfg.get_value("audio", "sfx", sfx_volume), 0.0, 1.0)
	ambient_volume = clampf(cfg.get_value("audio", "ambient", ambient_volume), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	window_scale = clampi(int(cfg.get_value("video", "window_scale", window_scale)), 1, 6)
	screen_shake = bool(cfg.get_value("access", "screen_shake", screen_shake))
	reduced_flashing = bool(cfg.get_value("access", "reduced_flashing", reduced_flashing))
	language = String(cfg.get_value("general", "language", language))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ambient", ambient_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "window_scale", window_scale)
	cfg.set_value("access", "screen_shake", screen_shake)
	cfg.set_value("access", "reduced_flashing", reduced_flashing)
	cfg.set_value("general", "language", language)
	cfg.save(PATH)


func apply() -> void:
	Loc.apply(language)
	_set_bus("Master", master_volume)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)
	_set_bus("Ambient", ambient_volume)
	if DisplayServer.get_name() != "headless":
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size := Vector2i(640, 360) * window_scale
			var screen := DisplayServer.screen_get_usable_rect()
			while window_scale > 1 and (size.x > screen.size.x or size.y > screen.size.y):
				window_scale -= 1
				size = Vector2i(640, 360) * window_scale
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
	changed.emit()


func _set_bus(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.001)


# ------------------------------------------------------------------ input
func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _mouse(btn: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	e.device = -1  # all devices: touches arrive as emulated mouse events from device -1
	return e


func _joy(btn: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = btn
	return e


func _axis(axis: JoyAxis, dir: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = dir
	return e


func _add(action: String, events: Array, deadzone := 0.5) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	for e in events:
		if not InputMap.action_has_event(action, e):
			InputMap.action_add_event(action, e)


func _setup_input() -> void:
	_add("fish_action", [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_SPACE), _joy(JOY_BUTTON_A)])
	_add("fish_cancel", [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_BACKSPACE), _joy(JOY_BUTTON_B)])
	_add("pause", [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)])
	_add("cursor_up", [_key(KEY_W), _key(KEY_UP), _joy(JOY_BUTTON_DPAD_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add("cursor_down", [_key(KEY_S), _key(KEY_DOWN), _joy(JOY_BUTTON_DPAD_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add("cursor_left", [_key(KEY_A), _key(KEY_LEFT), _joy(JOY_BUTTON_DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add("cursor_right", [_key(KEY_D), _key(KEY_RIGHT), _joy(JOY_BUTTON_DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add("open_codex", [_key(KEY_C), _key(KEY_TAB), _joy(JOY_BUTTON_Y)])
	_add("open_shop", [_key(KEY_U), _joy(JOY_BUTTON_LEFT_SHOULDER)])
	_add("open_map", [_key(KEY_M), _joy(JOY_BUTTON_RIGHT_SHOULDER)])
	_add("cycle_bait", [_key(KEY_Q), _joy(JOY_BUTTON_BACK)])
	_add("open_journal", [_key(KEY_J)])
	_add("habitat_view", [_key(KEY_F), _joy(JOY_BUTTON_RIGHT_STICK)])
	# make sure menus are fully navigable with a gamepad
	_add("ui_accept", [_joy(JOY_BUTTON_A)])
	_add("ui_cancel", [_joy(JOY_BUTTON_B)])
	_add("ui_up", [_joy(JOY_BUTTON_DPAD_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add("ui_down", [_joy(JOY_BUTTON_DPAD_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add("ui_left", [_joy(JOY_BUTTON_DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add("ui_right", [_joy(JOY_BUTTON_DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])


func _input(event: InputEvent) -> void:
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4)
	# touches also arrive as emulated mouse events (device -1): those must not switch the game to mouse mode
	var real_mouse := (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device != InputEvent.DEVICE_ID_EMULATION
	var kbm := event is InputEventKey or (real_mouse and (event is InputEventMouseButton or (event as InputEventMouseMotion).relative.length() > 2.0))
	if event is InputEventScreenTouch and not using_touch:
		using_touch = true
		input_device_changed.emit(false)
	elif real_mouse and event is InputEventMouseButton and using_touch:
		using_touch = false
		input_device_changed.emit(false)
	if pad and not using_gamepad:
		using_gamepad = true
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		input_device_changed.emit(true)
	elif kbm and using_gamepad:
		using_gamepad = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		input_device_changed.emit(false)


func prompt(action: String) -> String:
	## Short contextual prompt text for the active device.
	var pad := {
		"fish_action": "A", "fish_cancel": "B", "pause": "Start", "open_codex": "Y",
		"open_shop": "LB", "open_map": "RB", "cycle_bait": "Back", "cursor": "D-Pad", "habitat_view": "R3",
	}
	var kb := {
		"fish_action": "LMB", "fish_cancel": "RMB", "pause": "Esc", "open_codex": "C",
		"open_shop": "U", "open_map": "M", "cycle_bait": "Q", "cursor": "Mouse", "habitat_view": "F",
	}
	var touch := {
		"fish_action": "screen", "fish_cancel": "tap", "pause": "menu", "open_codex": "book",
		"open_shop": "shop", "open_map": "map", "cycle_bait": "bait", "cursor": "finger", "habitat_view": "Spots",
	}
	if using_touch and not using_gamepad:
		return UIKit.T(String(touch.get(action, "?")))
	return UIKit.T(String((pad if using_gamepad else kb).get(action, "?")))
