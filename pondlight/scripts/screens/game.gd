class_name Game
extends Node
## Gameplay screen: pond diorama + rod + fishing controller + HUD + menus.

signal to_menu

var world_root: Node2D
var pond: PondView
var rod: RodRig
var controller: FishingController
var ui_layer: CanvasLayer
var hud: Hud
var modal: ModalPanel
var _shake_amt := 0.0
var _shake_t := 0.0
var _fade: ColorRect
var _typed := ""  # last letters typed, for the developer's secret
var tutorial: Tutorial


func _ready() -> void:
	world_root = Node2D.new()
	world_root.name = "World"
	add_child(world_root)
	pond = PondView.new()
	world_root.add_child(pond)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(hud)
	hud.open_requested.connect(open_panel)
	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.06, 0.04, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_fade)
	controller = FishingController.new()
	controller.name = "Fishing"
	add_child(controller)
	controller.catch_made.connect(_on_catch)
	controller.state_changed.connect(func(s: int) -> void: hud.set_fight_mode(s == FishingController.State.FIGHT))
	Economy.equipment_changed.connect(func(_s: String, _t: int) -> void: rod.set_equipment(Save.profile["equipment"]))
	Economy.pond_unlocked.connect(_on_pond_unlocked)
	Achievements.unlocked.connect(func(id: String) -> void:
		var a := Achievements.def(id)
		Audio.play("purchase", 0.02, -4.0)
		if String(a.get("type", "")) == "all":
			hud.toasts.banner("Master of Pondlight", "All 25 trophies collected!", Color("#bdf6ff"))
			hud.celebrate(4, Vector2(320, 180))
		else:
			hud.toasts.toast(UIKit.T("Trophy: %s") % UIKit.T(a.get("name", id)), "trophy", UIKit.GOLD, 3.0))
	Progression.mastery_up.connect(func(id: String, lv: int) -> void:
		Audio.play("levelup")
		hud.toasts.toast(UIKit.T("%s mastery Lv %d - better rarity odds!") % [Data.fish_name(id), lv], "star", Color("#7fdcc2")))
	Clock.weather_changed.connect(_on_weather)
	Clock.running = true
	_load_pond(String(Save.profile["current_pond"]))
	if not bool(Save.profile.get("tutorial_done", false)) and int(Save.profile["stats"]["catches"]) == 0:
		var tl := CanvasLayer.new()
		tl.layer = 20
		tl.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(tl)
		tutorial = Tutorial.new()
		tutorial.process_mode = Node.PROCESS_MODE_ALWAYS
		tl.add_child(tutorial)
		tutorial.start(self, controller, hud)
	elif int(Save.profile["stats"]["catches"]) > 0:
		Save.profile["tutorial_done"] = true
	Achievements.ensure_daily()
	_welcome_back.call_deferred()
	Platform.game_ready()
	Platform.set_gameplay(true)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.6)


func _exit_tree() -> void:
	Clock.running = false
	Engine.time_scale = 1.0


func _welcome_back() -> void:
	## Fish traps filled while the game was closed: claim them with a little ceremony.
	var haul := Economy.trap_haul(Save.away_seconds)
	Save.away_seconds = 0.0
	if haul <= 0 or is_instance_valid(tutorial):
		return
	var p := WelcomePanel.new()
	p.haul = haul
	_show_modal(p)


func _load_pond(pid: String) -> void:
	pond.build(pid)
	if rod != null and is_instance_valid(rod):
		rod.queue_free()
	rod = RodRig.new()
	pond.actor_layer.add_child(rod)
	var pd: Dictionary = Data.ponds[pid]
	rod.configure(Vector2(pd["rod_base"][0], pd["rod_base"][1]), Vector2(pd["dock_tip"][0], pd["dock_tip"][1]))
	rod.set_equipment(Save.profile["equipment"])
	controller.setup(pond, rod, hud)
	hud.refresh()
	Audio.music(String(pd["music"]))
	_update_ambient()


func _update_ambient() -> void:
	var pid := String(Save.profile["current_pond"])
	var pd: Dictionary = Data.ponds[pid]
	var w := Clock.weather(pid)
	var layer := String((pd["weather_ambient"] as Dictionary).get(w, ""))
	if layer == String(pd["ambient"]):
		layer = ""
	Audio.ambient(String(pd["ambient"]), layer)


func _on_weather(pid: String, w: String) -> void:
	if pid == String(Save.profile["current_pond"]):
		pond.apply_weather(w)
		_update_ambient()
		hud.toasts.toast("It started to rain" if w == "rain" else ("Snow is falling" if w == "snow" else "The weather clears"), "rain" if w == "rain" else ("snow" if w == "snow" else "sun"))


func travel(pid: String) -> void:
	if pid == String(Save.profile["current_pond"]) or not Economy.is_unlocked(pid):
		return
	controller.enabled = false
	Platform.show_break_ad()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func() -> void:
		controller.force_idle()
		Save.profile["current_pond"] = pid
		Save.save_game()
		_load_pond(pid)
		Orders.refresh_for_pond()
		hud.toasts.toast(Data.pond_name(pid), "map", UIKit.GOLD))
	tw.tween_property(_fade, "color:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: controller.enabled = modal == null)


# ------------------------------------------------------------------ menus
func open_panel(name: String) -> void:
	if modal != null:
		return
	var p: ModalPanel
	match name:
		"shop":
			p = ShopPanel.new()
		"codex":
			p = CodexPanel.new()
		"map":
			var m := MapPanel.new()
			m.travel.connect(func(pid: String) -> void: travel.call_deferred(pid))
			p = m
		"trophies":
			p = TrophyPanel.new()
		"habitats":
			pond.habitat.toggle()
			Audio.play("ui_click", 0.05, -6.0)
			return
		"journal":
			p = JournalPanel.new()
		"settings":
			p = SettingsPanel.new()
		"pause":
			var pp := PausePanel.new()
			pp.open.connect(func(k: String) -> void:
				pp.closed.connect(func() -> void: open_panel.call_deferred(k), CONNECT_ONE_SHOT)
				pp.close())
			pp.to_menu.connect(func() -> void:
				Save.save_game()
				get_tree().paused = false
				to_menu.emit())
			pp.quit_game.connect(func() -> void: Save.quit_game())
			p = pp
		_:
			return
	_show_modal(p)


func _show_modal(p: ModalPanel) -> void:
	modal = p
	if is_instance_valid(tutorial) and p is ShopPanel:
		tutorial.panel_opened("shop")
	controller.enabled = false
	pond.cursor.hide_cursor()
	hud.hide_cell_info()
	get_tree().paused = true
	ui_layer.add_child(p)
	p.closed.connect(func() -> void:
		modal = null
		get_tree().paused = false
		controller.enabled = true
		hud.refresh())


func _on_catch(rec: Dictionary, flags: Dictionary) -> void:
	await get_tree().create_timer(0.45).timeout
	var cp := CatchPanel.new().setup(rec, flags)
	cp.tide_allowed = not is_instance_valid(tutorial)
	var finish := func() -> void:
		controller.result_closed()
		if is_instance_valid(tutorial):
			tutorial.result_closed()
		_after_catch(rec, flags)
	cp.closed.connect(func() -> void:
		if cp.go_tide:
			var tp := TidePanel.new().setup(rec)
			tp.closed.connect(finish, CONNECT_ONE_SHOT)
			_show_modal.call_deferred(tp)
		else:
			finish.call(), CONNECT_ONE_SHOT)
	_show_modal(cp)
	if flags.has("treasure"):
		Audio.play("discovery", 0.02, -2.0)
		hud.toasts.toast("You fished up a treasure chest!", "chest", UIKit.GOLD, 3.0)


func _after_catch(rec: Dictionary, flags: Dictionary) -> void:
	if flags.get("new_species", false):
		var pid := String(rec["pond"])
		var n := Progression.discovered_count(pid)
		var total := Data.species_of(pid).size()
		hud.toasts.toast(UIKit.T("Codex: %d / %d %s species") % [n, total, Data.pond_name(pid)], "book", UIKit.GREEN)
		if n == total:
			hud.toasts.banner("Pond Complete!", UIKit.T("Every species of %s discovered") % Data.pond_name(pid))
	for pid in Data.pond_order:
		var st := Economy.unlock_status(pid)
		if not st["unlocked"] and st["species_ok"] and not Save.profile["flags"].get("hint_unlock_" + pid, false):
			Save.profile["flags"]["hint_unlock_" + pid] = true
			hud.toasts.toast(UIKit.T("%s can be unlocked on the Map!") % Data.pond_name(pid), "map", UIKit.GOLD, 4.0)


func _on_pond_unlocked(pid: String) -> void:
	hud.toasts.banner(UIKit.T("%s Unlocked") % Data.pond_name(pid), "Open the Map to travel there")
	shake(2.0, 0.3)


func _input(event: InputEvent) -> void:
	# A little signature from the developer: type "sabit" once for a gift.
	if event is InputEventKey and event.pressed and not event.echo:
		var ch := char((event as InputEventKey).unicode).to_lower()
		if ch.length() == 1 and ch >= "a" and ch <= "z":
			_typed = (_typed + ch).right(8)
			if _typed.ends_with("sabit"):
				_typed = ""
				_developer_gift()


func _developer_gift() -> void:
	var flags: Dictionary = Save.profile["flags"]
	if flags.get("sabit_gift", false):
		hud.toasts.toast("Sabit waves at you again!", "star", UIKit.GOLD)
		return
	flags["sabit_gift"] = true
	var coins := maxi(1500, int(round(Economy.trap_rate() * 1.5 / 100.0)) * 100)
	for b in [["lucky_fly", 5], ["monster_chum", 3]]:
		Save.profile["bait"][b[0]] = maxi(0, Economy.bait_count(b[0])) + int(b[1])
	Economy.add_coins(coins, true)
	Economy.bait_changed.emit()
	controller._golden_next = 0.0
	Save.save_game()
	Audio.play("catch_legendary")
	hud.celebrate(4, Vector2(320, 170))
	hud.toasts.banner("A gift from Sabit, the developer!", UIKit.T("+%s coins, Lucky Flies and Monster Chum. Thanks for playing!") % UIKit.fmt_int(coins), Color("#bdf6ff"))
	shake(2.0, 0.3)


func _unhandled_input(event: InputEvent) -> void:
	if modal != null:
		return
	var idle := controller.state in [FishingController.State.IDLE, FishingController.State.WAITING]
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_panel("pause")
	elif not idle:
		return
	elif event.is_action_pressed("open_codex"):
		open_panel("codex")
	elif event.is_action_pressed("open_shop"):
		open_panel("shop")
	elif event.is_action_pressed("open_map"):
		open_panel("map")
	elif event.is_action_pressed("open_journal"):
		open_panel("journal")
	elif event.is_action_pressed("cycle_bait"):
		Economy.cycle_bait()
		Audio.play("ui_click")


func shake(amount: float, duration: float) -> void:
	if not Settings.screen_shake:
		return
	_shake_amt = maxf(_shake_amt, amount)
	_shake_t = maxf(_shake_t, duration)


func _process(delta: float) -> void:
	if _shake_t > 0.0:
		_shake_t -= delta
		world_root.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * ceilf(_shake_amt * clampf(_shake_t * 4.0, 0.0, 1.0))
		if _shake_t <= 0.0:
			_shake_amt = 0.0
			world_root.position = Vector2.ZERO
