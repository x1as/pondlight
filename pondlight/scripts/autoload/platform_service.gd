extends Node
## Platform integration layer.
##
## The game only talks to this node for achievements and stats. Today the
## "local" backend is active: achievements are stored in the save file and
## shown in the in-game Journal. When a GodotSteam build for Godot 4.7 and a
## real App ID are configured (see STEAM_SETUP.md), the "steam" backend is
## picked automatically - nothing in the gameplay code has to change.
##
## Web builds talk to web/pl_bridge.js (window.PL): on Yandex Games it drives the SDK
## (LoadingAPI.ready, GameplayAPI, ads, language); elsewhere every call is a safe no-op.

signal achievement_unlocked(id: String)

var backend := "local"
var _steam: Object = null
var is_web := OS.has_feature("web")
var _web_poll := 0.0
var _web_paused := false
var _lang_checked := false
var _last_fullscreen_ad := -1000.0
var _rotate: CanvasLayer


func _ready() -> void:
	if is_web:
		# browser frames come in any size: fill them (nearest filtering keeps pixels crisp)
		get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		var ok := false
		if _steam.has_method("steamInitEx"):
			var res: Variant = _steam.call("steamInitEx")
			ok = typeof(res) == TYPE_DICTIONARY and int(res.get("status", 1)) == 0
		if ok:
			backend = "steam"
		else:
			_steam = null


func _process(delta: float) -> void:
	if _steam != null:
		_steam.call("run_callbacks")
	if is_web:
		_web_poll -= delta
		if _web_poll <= 0.0:
			_web_poll = 0.25
			_poll_web()
			_check_orientation()


# ------------------------------------------------------------------ web / Yandex Games
func _js(code: String) -> Variant:
	if not is_web:
		return null
	return JavaScriptBridge.eval(code, true)


func web_sdk() -> bool:
	return is_web and int(_js("window.PL ? PL.has_sdk() : 0")) == 1


func _poll_web() -> void:
	# ads or a hidden tab: silence everything (and freeze time) until the player is back
	var pause := int(_js("window.PL ? PL.should_pause() : (document.hidden ? 1 : 0)")) == 1
	if pause != _web_paused:
		_web_paused = pause
		AudioServer.set_bus_mute(0, pause)
		Engine.time_scale = 0.0 if pause else 1.0
	if not _lang_checked and web_sdk():
		_lang_checked = true
		var lang := String(_js("PL.lang"))
		if lang != "" and Settings.language == "auto":
			Loc.apply("ru" if lang in ["ru", "be", "kk", "uk", "uz"] else "en")


func is_mobile_web() -> bool:
	return is_web and (OS.has_feature("web_android") or OS.has_feature("web_ios"))


func can_fullscreen() -> bool:
	## Android browsers allow it from a tap; iPhone Safari does not support fullscreen for pages.
	return is_web and not OS.has_feature("web_ios") and int(_js("document.fullscreenEnabled ? 1 : 0")) == 1


func toggle_fullscreen() -> void:
	## Must be called from a tap/click (browsers require a user gesture).
	_js("""(function(){
		if (document.fullscreenElement) { document.exitFullscreen(); return; }
		var p = document.documentElement.requestFullscreen({navigationUI: 'hide'});
		if (p && p.then) { p.then(function(){ try { screen.orientation.lock('landscape').catch(function(){}); } catch(e) {} }).catch(function(){}); }
	})()""")


func _check_orientation() -> void:
	## Phones held upright get a friendly "turn your phone" card (the game is 16:9).
	var sz := DisplayServer.window_get_size()
	var portrait := is_mobile_web() and sz.y > sz.x
	if portrait == (_rotate != null):
		return
	if portrait:
		_rotate = CanvasLayer.new()
		_rotate.layer = 120
		var bg := ColorRect.new()
		bg.color = Color("#0b2418")
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_rotate.add_child(bg)
		var v := UIKit.vbox(8)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.theme = UIKit.theme()
		bg.add_child(v)
		var logo := TextureRect.new()
		logo.texture = UIKit.tex("logo")
		logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		v.add_child(logo)
		v.add_child(UIKit.label("Turn your phone sideways", 20, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UIKit.label("PONDLIGHT is played in landscape", 10, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
		get_tree().root.add_child(_rotate)
	else:
		_rotate.queue_free()
		_rotate = null


func game_ready() -> void:
	## Yandex: the loading screen is done and the player can interact.
	_js("window.PL && PL.loaded()")


func set_gameplay(on: bool) -> void:
	_js("window.PL && PL.set_gameplay(%s)" % ("true" if on else "false"))


func ads_available() -> bool:
	return web_sdk()


func show_break_ad() -> void:
	## Interstitial at natural breaks only (travelling between waters), at most every 3 minutes.
	var now := Time.get_ticks_msec() / 1000.0
	if not web_sdk() or now - _last_fullscreen_ad < 180.0:
		return
	_last_fullscreen_ad = now
	_js("PL.fullscreen()")


func show_rewarded() -> bool:
	## Rewarded video. Returns true only when the player watched it to the end.
	if not web_sdk():
		return false
	_js("PL.rewarded()")
	var waited := 0.0
	while waited < 90.0:
		await get_tree().create_timer(0.25, true, false, true).timeout
		waited += 0.25
		var r := int(_js("PL.reward"))
		if r != 0:
			return r == 1
	return false


func has_store_page() -> bool:
	return String(Data.store.get("store_url", "")).begins_with("https://store.steampowered.com/app/")


func open_store_page() -> void:
	## Opens the real Steam page (overlay when Steam is running). Never a guessed URL.
	if not has_store_page():
		return
	OS.shell_open(String(Data.store["store_url"]))


func is_steam() -> bool:
	return backend == "steam"


func unlock_achievement(id: String) -> void:
	if _steam != null:
		_steam.call("setAchievement", id)
		_steam.call("storeStats")
	achievement_unlocked.emit(id)


func set_stat_int(stat: String, value: int) -> void:
	if _steam != null:
		_steam.call("setStatInt", stat, value)
