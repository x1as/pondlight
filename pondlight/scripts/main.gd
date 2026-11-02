extends Node
## Root: switches between the title screen and the game with a fade, sets the pixel cursor,
## and supports a screenshot/QA mode (--shot=<path> [--pond=id] [--hour=0..1] [--weather=x]).

var current: Node
var _fade: ColorRect
var _shot_path := ""
var _shot_args: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.06, 0.04, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_set_cursor()
	get_tree().root.size_changed.connect(_set_cursor)
	Loc.language_changed.connect(_on_language_changed)
	_parse_args()
	if _shot_args.has("lang"):
		Loc.apply(String(_shot_args["lang"]))
	if _shot_args.has("save_dir"):
		Save.save_dir = String(_shot_args["save_dir"])
	if Save.has_save():
		Save.load_game()
	if _shot_args.has("scene") and _shot_args["scene"] == "game":
		_start_game(false)
	else:
		_show_menu()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.5)
	if _shot_path != "":
		_take_shot.call_deferred()


func _on_language_changed(_code: String) -> void:
	## Rebuild the current screen so every caption is created in the new language.
	get_tree().paused = false
	if current is Game:
		Save.save_game()
		_start_game(false)
	elif current is MainMenu:
		_show_menu()


func _exit_tree() -> void:
	# release cached resources so the engine shuts down cleanly
	Input.set_custom_mouse_cursor(null)
	UIKit.release()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_shot_args[kv[0]] = kv[1]
	_shot_path = String(_shot_args.get("shot", ""))


func _set_cursor() -> void:
	var scale := clampi(int(get_tree().root.size.y / 360.0), 1, 4)
	var tex: Texture2D = load(UIKit.T("res://assets/art/ui/cursor_%dx.png") % scale)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2.ZERO)


func _swap(n: Node) -> void:
	if current != null:
		current.queue_free()
	current = n
	add_child(n)


func _show_menu() -> void:
	var m := MainMenu.new()
	m.start_game.connect(_on_start)
	_swap(m)


func _on_start(new_game: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.3)
	tw.tween_callback(func() -> void: _start_game(new_game))
	tw.tween_property(_fade, "color:a", 0.0, 0.4)


func _start_game(new_game: bool) -> void:
	if new_game or not Save.has_save():
		Save.new_game()
	else:
		Save.load_game()
	if _shot_args.has("pond") and Data.ponds.has(_shot_args["pond"]):
		Save.profile["current_pond"] = _shot_args["pond"]
		if not (Save.profile["ponds_unlocked"] as Array).has(_shot_args["pond"]):
			(Save.profile["ponds_unlocked"] as Array).append(_shot_args["pond"])
	if _shot_args.has("gear"):
		for slot in Data.slot_order:
			Save.profile["equipment"][slot] = clampi(int(_shot_args["gear"]) - 1, 0, Data.tier_count(slot) - 1)
		Save.profile["coins"] = 25000
	if _shot_args.has("notut"):
		Save.profile["tutorial_done"] = true
	if _shot_args.has("hour"):
		Save.profile["clock"]["time"] = float(_shot_args["hour"])
	if _shot_args.has("weather"):
		Save.profile["clock"]["weather"][Save.profile["current_pond"]] = _shot_args["weather"]
	var g := Game.new()
	g.to_menu.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, 0.3)
		tw.tween_callback(_show_menu)
		tw.tween_property(_fade, "color:a", 0.0, 0.4))
	_swap(g)


func _take_shot() -> void:
	var delay := float(_shot_args.get("delay", "2.0"))
	await get_tree().create_timer(delay).timeout
	if _shot_args.has("panel") and current is Game:
		var pn := String(_shot_args["panel"])
		if pn == "pops":
			var h := (current as Game).hud
			var fx := (current as Game).pond.over_fx
			h.pop(Vector2(200, 140), "PERFECT x4", "perfect")
			fx.burst(Vector2(200, 140), UIKit.GOLD, 16)
			h.pop(Vector2(330, 120), "GOOD x2", "good")
			fx.burst(Vector2(330, 120), UIKit.GREEN, 7)
			h.pop(Vector2(450, 140), "MISS", "miss")
			h.pop(Vector2(240, 210), "COMBO x8!", "combo")
			h.pop(Vector2(420, 220), "LEGENDARY!", "rare", Data.rarity_color(4))
			await get_tree().create_timer(0.16).timeout
		elif pn == "celebrate":
			(current as Game).hud.celebrate(4, Vector2(300, 150))
			(current as Game).pond.over_fx.burst(Vector2(300, 150), Data.rarity_color(4), 40)
			await get_tree().create_timer(0.25).timeout
		elif pn == "golden":
			(current as Game).controller._golden_next = 0.0
			await get_tree().create_timer(1.2).timeout
		elif pn == "shop_tip" or pn == "talents_tip":
			(current as Game).open_panel("shop")
			await get_tree().create_timer(0.5).timeout
			var sp := (current as Game).modal as ShopPanel
			if pn == "talents_tip":
				sp._tab = "talents"
				sp._refresh()
				await get_tree().create_timer(0.2).timeout
			var chip: Control = sp._stats_row.get_child(1)
			HoverTip._show(chip, "POWER  40", ShopPanel.STAT_DESC["power"])
		elif pn == "treasure":
			var crec := {"species": "arapaima", "rarity": 3, "weight": 120.0, "value": 2400, "pond": "delta", "time": 0}
			var cf := Progression.register_catch(crec)
			cf["treasure"] = {"kind": "coins", "coins": 1240}
			(current as Game)._show_modal(CatchPanel.new().setup(crec, cf))
		elif pn == "prismatic":
			var prec := {"species": "megalodon", "rarity": 4, "weight": 6200.0, "value": 0, "pond": "trench", "time": 0, "prismatic": true,
				"parts": [["Base", 2200.0], ["Rarity", 8.0], ["Size", 2.1], ["Skill", 1.19], ["Streak", 1.3], ["Frenzy", 1.5], ["Prismatic", 5.0]]}
			prec["value"] = int(round(2200.0 * 8.0 * 2.1 * 1.19 * 1.3 * 1.5 * 5.0))
			(current as Game)._show_modal(CatchPanel.new().setup(prec, Progression.register_catch(prec)))
			await get_tree().create_timer(2.2).timeout
		elif pn == "frenzy":
			var gc := (current as Game).controller
			Save.profile["stats"]["streak"] = 4
			gc.frenzy_left = 0.0
			Save.profile["stats"]["streak"] = 5
			gc._check_frenzy()
			await get_tree().create_timer(1.0).timeout
		elif pn == "cinematic":
			(current as Game).hud.cinematic(UIKit.T("%s LANDED!") % Data.fish_name("kraken").to_upper(), Color("#ffbe3d"), Vector2(320, 150))
			await get_tree().create_timer(0.25, true, false, true).timeout
		elif pn == "welcome":
			var wp := WelcomePanel.new()
			wp.haul = 4321
			(current as Game)._show_modal(wp)
			await get_tree().create_timer(1.4).timeout
		elif pn == "sabit":
			for k in [KEY_S, KEY_A, KEY_B, KEY_I, KEY_T]:
				var ev := InputEventKey.new()
				ev.keycode = k
				ev.unicode = OS.get_keycode_string(k).to_lower().unicode_at(0)
				ev.pressed = true
				Input.parse_input_event(ev)
				await get_tree().process_frame
			await get_tree().create_timer(0.9).timeout
			print("QA sabit gift: ", Save.profile["flags"].get("sabit_gift", false), " coins ", Economy.coins())
		elif pn == "touch":
			# QA: real InputEventScreenTouch events (mouse is emulated from them) - tap selects, hold casts
			var gt := current as Game
			var cell := Data.fishable_cells(gt.pond.pond_id)[Data.fishable_cells(gt.pond.pond_id).size() - 3]
			var at := gt.pond.cell_center(cell) * (Vector2(get_window().size) / Vector2(640, 360))
			for step in [[true, 0.1], [false, 0.5], [true, 0.95], [false, 0.3]]:
				var tev := InputEventScreenTouch.new()
				tev.position = at
				tev.pressed = step[0]
				Input.parse_input_event(tev)
				await get_tree().create_timer(step[1]).timeout
				print("QA touch: pressed=", step[0], " state=", gt.controller.state, " selected=", gt.controller.touch_cell, " touch_mode=", Settings.using_touch)
			await get_tree().create_timer(0.6).timeout
		elif pn == "tide":
			var trec := {"species": "megalodon", "rarity": 4, "weight": 4200.0, "value": 9800, "pond": "trench", "time": 0}
			(current as Game)._show_modal(TidePanel.new().setup(trec))
			await get_tree().create_timer(0.9).timeout
		elif pn == "catch":
			var rec := {"species": "golden_tench", "rarity": 3, "weight": 3.42, "value": 268, "pond": "willow", "time": 0}
			(current as Game)._show_modal(CatchPanel.new().setup(rec, Progression.register_catch(rec)))
		elif pn != "celebrate" and pn != "golden" and pn != "pops":
			(current as Game).open_panel(pn)
		if pn != "celebrate" and pn != "pops":
			await get_tree().create_timer(0.8).timeout
	if _shot_args.has("overlay") and current is Game:
		(current as Game).pond.habitat.toggle()
		await get_tree().create_timer(0.4).timeout
	if _shot_args.has("tour") and current is Game:
		await _ui_tour(current as Game)
	if _shot_args.has("demo") and current is Game:
		await _demo(current as Game, String(_shot_args["demo"]))
	if current is Game and (current as Game).modal != null and OS.get_cmdline_user_args().has("--sizes=1"):
		_dump_sizes((current as Game).modal.frame, 0)
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_path)
	print("SHOT saved ", _shot_path)
	Save.quit_game()


func _demo(g: Game, kind: String) -> void:
	## Drives the real fishing controller for visual QA screenshots.
	var c := g.controller
	var cells := Data.fishable_cells(g.pond.pond_id)
	var cell: Vector2i = cells[cells.size() - 3]
	if is_instance_valid(g.tutorial):
		g.tutorial._on_next()
		cell = c.tutorial_cell
		print("QA tutorial step: ", g.tutorial.step)
	c._using_pad = true
	c.pad_cell = cell
	await get_tree().create_timer(0.3).timeout
	if kind == "hover":
		return
	c._action_down = true
	c._pressed_this_frame = true
	await get_tree().create_timer(0.75).timeout
	if kind == "charge":
		return
	c._action_down = false
	await get_tree().create_timer(1.2).timeout
	if kind == "wait":
		return
	c._wait_left = 0.0
	await get_tree().create_timer(0.15).timeout
	if kind == "bite":
		return
	c._pressed_this_frame = true
	if kind == "catch":
		await _auto_fight(g)
		return
	await get_tree().create_timer(1.6).timeout
	c._action_down = true
	await get_tree().create_timer(0.5).timeout


func _auto_fight(g: Game) -> void:
	## QA: plays the real fight like an attentive human, then sells the fish and verifies the payout survives a reload.
	var c := g.controller
	var tap_cd := 0.0
	while c.state == FishingController.State.FIGHT or c.state == FishingController.State.BITE:
		await get_tree().process_frame
		if c.fight == null:
			continue
		var m := c.fight
		var danger := m.state == "surge" or m.state == "final_burst" or m.telegraph > 0.0 or m.tension_ratio() > 0.55
		c._action_down = not danger and m.tension_ratio() < 0.45
		tap_cd -= get_process_delta_time()
		if tap_cd <= 0.0 and absf(m.marker - m.zone_center) < m.zone_half * 0.7:
			c._pressed_this_frame = true
			tap_cd = 0.3
	c._action_down = false
	print("QA fight result: ", c.fight.result if c.fight else "none", "  state=", c.state)
	await get_tree().create_timer(1.3).timeout
	if g.modal is CatchPanel:
		var before := Economy.coins()
		print("QA catch panel open: ", (g.modal as CatchPanel).record)
		var shot := get_viewport().get_texture().get_image()
		shot.save_png(_shot_path.replace(".png", "_panel.png"))
		(g.modal as CatchPanel)._sell()
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(g.tutorial):
			print("QA tutorial step after catch: ", g.tutorial.step)
			g.open_panel("shop")
			await get_tree().create_timer(0.6).timeout
			print("QA tutorial step in shop: ", g.tutorial.step)
			get_viewport().get_texture().get_image().save_png(_shot_path.replace(".png", "_tutshop.png"))
			g.tutorial._on_next()
			await get_tree().create_timer(0.3).timeout
			print("QA tutorial done flag: ", Save.profile["tutorial_done"])
		print("QA coins before/after sale: ", before, " -> ", Economy.coins(), "  codex species: ", Progression.discovered_count("willow"))
		var paid := Economy.coins()
		Save.profile = {}
		Save.load_game()
		print("QA after reload: coins=", Economy.coins(), " (", "ok" if Economy.coins() == paid else "MISMATCH", ") catches=", Save.profile["stats"]["catches"])


func _dump_sizes(n: Node, depth: int) -> void:
	if n is Control and depth < 7:
		print("  ".repeat(depth), n.get_class(), " min ", (n as Control).get_combined_minimum_size(), " size ", (n as Control).size, " ", (n as Label).text.substr(0, 30) if n is Label else "")
	for c in n.get_children():
		_dump_sizes(c, depth + 1)


func _find_button(n: Node, text_part: String) -> Button:
	for c in n.get_children():
		if c is UIButton and (c as UIButton).caption.contains(UIKit.T(text_part)) and not (c as Button).disabled:
			return c
		var r := _find_button(c, text_part)
		if r != null:
			return r
	return null


func _press(g: Game, text_part: String) -> bool:
	var b := _find_button(g.modal if g.modal != null else g, text_part)
	if b == null:
		print("QA tour: button not found: ", text_part)
		return false
	b.pressed.emit()
	await get_tree().create_timer(0.4).timeout
	return true


func _ui_tour(g: Game) -> void:
	## QA: exercises every menu through its real buttons.
	Economy.add_coins(6000)
	for id in Data.species_of("willow"):
		Progression.register_catch({"species": id, "rarity": 1, "weight": 1.0, "value": 10, "pond": "willow"})
	var t := get_tree()
	g.open_panel("shop")
	await t.create_timer(0.5).timeout
	var c0 := Economy.coins()
	await _press(g, "140")
	print("QA shop: rod tier ", Economy.tier_of("rod"), " coins ", c0, " -> ", Economy.coins())
	await _press(g, "Bait")
	await _press(g, "x5")
	print("QA shop: golden larva ", Economy.bait_count("golden_larva"))
	g.modal.close()
	await t.create_timer(0.4).timeout
	g.open_panel("map")
	await t.create_timer(0.5).timeout
	await _press(g, "Unlock")
	print("QA map: frostmere unlocked ", Economy.is_unlocked("frostmere"))
	await t.create_timer(2.5).timeout
	await _press(g, "Travel")
	await t.create_timer(1.6).timeout
	print("QA travel: current pond ", Save.profile["current_pond"], " view ", g.pond.pond_id)
	g.open_panel("codex")
	await t.create_timer(0.5).timeout
	await _press(g, "Willow Pond")
	g.modal.close()
	await t.create_timer(0.4).timeout
	var rec := {"species": "bluegill", "rarity": 2, "weight": 0.5, "value": 300, "pond": "willow", "time": 0}
	g._show_modal(TidePanel.new().setup(rec))
	await t.create_timer(0.7).timeout
	var c1 := Economy.coins()
	await _press(g, "STOP!")
	await t.create_timer(0.3).timeout
	g.modal.close()
	await t.create_timer(0.5).timeout
	print("QA tide: coins ", c1, " -> ", Economy.coins(), " paid=", rec.get("paid", false), " sold_for=", rec.get("sold_for", -1))
	g.open_panel("journal")
	await t.create_timer(0.5).timeout
	g.modal.close()
	await t.create_timer(0.4).timeout
	g.open_panel("settings")
	await t.create_timer(0.5).timeout
	g.modal.close()  # opened only: QA must not change the player's real settings file
	await t.create_timer(0.4).timeout
	g.open_panel("pause")
	await t.create_timer(0.5).timeout
	await _press(g, "Main Menu")
	await t.create_timer(1.2).timeout
	print("QA pause->menu: current is MainMenu ", current is MainMenu)
	var cont := _find_button(current, "Continue")
	cont.pressed.emit()
	await t.create_timer(1.5).timeout
	print("QA continue: current is Game ", current is Game, " pond ", Save.profile["current_pond"], " rod tier ", Economy.tier_of("rod"))
