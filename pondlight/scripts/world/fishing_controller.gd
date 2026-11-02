class_name FishingController
extends Node
## Fishing loop: aim -> charge -> cast -> wait (nibbles) -> bite -> fight -> result.
## Pure rules live in core/ (CastModel, FishSelector, RarityTable, FightModel, Valuation).

signal catch_made(record: Dictionary, flags: Dictionary)
signal state_changed(state: int)
signal tutorial_event(name: String)

enum State { IDLE, CHARGING, FLYING, WAITING, BITE, FIGHT, RESULT, LOST }

var pond: PondView
var rod: RodRig
var hud: Hud
var state := State.IDLE
var enabled := true
var rng := RandomNumberGenerator.new()
var cast := CastModel.new()
var fight: FightModel

var hover_cell := Vector2i(-1, -1)
var pad_cell := Vector2i(-1, -1)
var target_cell := Vector2i(-1, -1)
var land_pos := Vector2.ZERO
var land_cell := Vector2i(-1, -1)
var cast_zone := CastModel.Zone.NORMAL
var _using_pad := false
var _action_down := false
var _pressed_this_frame := false
var _wait_left := 0.0
var _nibbles: Array[float] = []
var _nibble_recent := 0.0
var _bite_left := 0.0
var _pending_species := ""
var _pending_rarity := 0
var _fx_t := 0.0
var _fish_anchor := Vector2.ZERO
var _fish_wobble := 0.0
var _reel_sound_t := 0.0
var _tension_warned := false
var _repeat_t := 0.0
var _last_dir := Vector2i.ZERO
var _charge_sound_t := 0.0
var _hitstop := 0.0
var tutorial_active := false
var tutorial_cell := Vector2i(-1, -1)
var golden_cell := Vector2i(-1, -1)
var _golden_left := 0.0
var _golden_next := 0.0
var _hover_reported := false
var _from_golden := false
var _hook_bait := "worm"
var frenzy_left := 0.0
var touch_cell := Vector2i(-1, -1)  # touch screens: first tap picks a spot, the next press on it casts
var _press_local := Vector2(-1, -1)  # where the last press landed, in pond coordinates


func setup(p: PondView, r: RodRig, h: Hud) -> void:
	pond = p
	rod = r
	hud = h
	rng.randomize()
	rod.landed.connect(_on_landed)
	rod.reeled_in.connect(_on_reeled_in)
	var cells := Data.fishable_cells(pond.pond_id)
	pad_cell = cells[cells.size() / 2] if not cells.is_empty() else Vector2i(0, 0)
	golden_cell = Vector2i(-1, -1)
	_golden_next = float(Data.balance["golden_spot"]["first"])
	if not Settings.input_device_changed.is_connected(_on_device_changed):
		Settings.input_device_changed.connect(_on_device_changed)
	_set_state(State.IDLE)


func _on_device_changed(_pad: bool) -> void:
	if is_inside_tree():
		_update_hint()


func _set_state(s: State) -> void:
	state = s
	if s == State.IDLE:
		_hover_reported = false
	hud.set_menu_enabled(s in [State.IDLE, State.WAITING])
	_update_hint()
	state_changed.emit(s)


func _update_hint() -> void:
	var a := Settings.prompt("fish_action")
	var c := Settings.prompt("fish_cancel")
	_update_coach()
	match state:
		State.IDLE:
			if Settings.using_touch:
				hud.set_hint("Tap a spot to see its fish - then hold it to cast")
			else:
				hud.set_hint(UIKit.T("[%s] hold on water to cast   [%s] habitats") % [a, Settings.prompt("habitat_view")])
		State.CHARGING:
			hud.set_hint("Release in the green zone!")
		State.WAITING:
			if Settings.using_touch:
				hud.set_hint("Wait for the bite... (a tap now reels in)")
			else:
				hud.set_hint(UIKit.T("Wait for the bite...  [%s] reel in") % c)
		State.BITE:
			hud.set_hint(UIKit.T("[%s] NOW!") % a)
		State.FIGHT:
			if Settings.using_touch:
				hud.set_hint("Tap in the zone - hold to reel - let go on SURGE")
			else:
				hud.set_hint(UIKit.T("[%s] tap in zone  -  hold to reel  -  let go on SURGE") % a)
		_:
			hud.set_hint("")


func _onboarding() -> bool:
	return int(Save.profile["stats"]["catches"]) == 0


func _update_coach() -> void:
	## Fallback coaching line (only when the guided tutorial was skipped on a fresh save).
	if tutorial_active or not _onboarding() or not bool(Save.profile.get("tutorial_done", true)):
		hud.set_coach("")
		return
	var a := Settings.prompt("fish_action")
	match state:
		State.IDLE:
			hud.set_coach(UIKit.T("Each spot has its own fish - hover one, then hold %s") % a)
		State.CHARGING:
			hud.set_coach("Release when the needle is in the GREEN zone")
		State.FLYING, State.WAITING:
			hud.set_coach("Watch the bobber... wait for it to DIVE")
		State.BITE:
			hud.set_coach(UIKit.T("NOW! Press %s") % a)
		State.FIGHT:
			hud.set_coach(UIKit.T("Tap %s in the green zone, hold to reel, let go on SURGE") % a)
		_:
			hud.set_coach("")


func stats() -> PlayerStats:
	return Economy.stats()


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion:
		_using_pad = false
	if event.is_action_pressed("habitat_view"):
		pond.habitat.toggle()
		Audio.play("ui_click", 0.05, -6.0)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("fish_action"):
		_action_down = true
		_pressed_this_frame = true
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			_press_local = pond.make_input_local(event).get("position")
		if event is InputEventMouseButton:
			_using_pad = false
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fish_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()
	for dir_action in ["cursor_up", "cursor_down", "cursor_left", "cursor_right"]:
		if event.is_action_pressed(dir_action):
			_using_pad = true
			_move_pad(_dir_of(dir_action))
			_repeat_t = 0.28
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# releases are tracked even if a GUI element ate the event
	if event.is_action_released("fish_action"):
		_action_down = false


func _dir_of(action: String) -> Vector2i:
	match action:
		"cursor_up":
			return Vector2i(0, -1)
		"cursor_down":
			return Vector2i(0, 1)
		"cursor_left":
			return Vector2i(-1, 0)
	return Vector2i(1, 0)


func _move_pad(d: Vector2i) -> void:
	if state != State.IDLE:
		return
	_last_dir = d
	var c := pad_cell
	for i in 14:
		c += d
		if c.x < 0 or c.y < 0 or c.x >= Data.pond_cols(pond.pond_id) or c.y >= Data.pond_rows(pond.pond_id):
			return
		if Data.is_fishable(pond.pond_id, c):
			pad_cell = c
			Audio.play("ui_hover", 0.1, -10.0)
			return


func _cancel() -> void:
	match state:
		State.CHARGING:
			Audio.stop("cast_charge")
			rod.charge = 0.0
			hud.cast_meter.visible = false
			_set_state(State.IDLE)
		State.WAITING, State.BITE:
			hud.hide_bite()
			rod.clear_bite()
			rod.reel_in()
			_set_state(State.LOST)


# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	if not enabled:
		_pressed_this_frame = false
		return
	# gamepad cursor key-repeat
	if _using_pad and state == State.IDLE:
		var held := Vector2i.ZERO
		for a in ["cursor_up", "cursor_down", "cursor_left", "cursor_right"]:
			if Input.is_action_pressed(a):
				held = _dir_of(a)
		if held != Vector2i.ZERO:
			_repeat_t -= delta
			if _repeat_t <= 0.0:
				_repeat_t = 0.1
				_move_pad(held)
	_process_golden(delta)
	if frenzy_left > 0.0:
		frenzy_left -= delta
		hud.frenzy_time(frenzy_left)
		if frenzy_left <= 0.0:
			_end_frenzy()
	match state:
		State.IDLE:
			_process_idle()
		State.CHARGING:
			_process_charging(delta)
		State.WAITING:
			_process_waiting(delta)
		State.BITE:
			_process_bite(delta)
		State.FIGHT:
			_process_fight(delta)
	_pressed_this_frame = false


func _current_cell() -> Vector2i:
	if _using_pad:
		return pad_cell
	if Settings.using_touch:
		if _pressed_this_frame:
			var c := pond.cell_at(_press_local)
			if c != touch_cell and c.x >= 0 and Data.is_fishable(pond.pond_id, c):
				touch_cell = c
				_pressed_this_frame = false  # this tap only selects the spot and shows its fish
				Audio.play("ui_hover", 0.1, -6.0)
		return touch_cell
	return pond.cell_at(pond.get_local_mouse_position())


func _process_idle() -> void:
	var c := _current_cell()
	hover_cell = c
	var st := stats()
	pond.habitat.reach = pond.effective_reach(st.reach)
	if c.x >= 0 and Data.is_fishable(pond.pond_id, c):
		var reachable := pond.is_reachable(c, st.reach)
		var r := pond.cell_rect(c)
		pond.cursor.show_cell(r, "valid" if reachable else "far")
		rod.aim_at(pond.cell_center(c), 0.35)
		var spot := Data.spot_at(pond.pond_id, c)
		hud.show_cell_info(r, spot, _odds(spot, false), "valid" if reachable else "far", _bait_note())
		if reachable and not _hover_reported and (not tutorial_active or c == tutorial_cell):
			_hover_reported = true
			tutorial_event.emit("hover")
		if _pressed_this_frame:
			if reachable:
				_start_charge(c)
			else:
				Audio.play("strike_miss", 0.05, -6.0)
				hud.float_text(pond.cell_center(c), "Too far!", UIKit.RED)
	else:
		pond.cursor.hide_cursor()
		hud.hide_cell_info()
		rod.aim_target = rod.rest_angle


func _bait_note() -> String:
	var b := Economy.selected_bait()
	if b == "worm":
		return ""
	if not Economy.bait_active_here(b, pond.pond_id):
		return UIKit.T("%s has no effect here") % UIKit.T(Data.bait[b]["name"])
	return UIKit.T("Using %s") % UIKit.T(Data.bait[b]["name"])


func _odds(spot: String, perfect: bool) -> Dictionary:
	var pid := pond.pond_id
	var bait := Economy.selected_bait()
	if not Economy.bait_active_here(bait, pid):
		bait = "worm"
	return FishSelector.odds(pid, spot, {
		"phase": Clock.phase(), "weather": Clock.weather(pid), "bait": bait,
		"discovered": Progression.discovered_map(pid), "bad_luck": int(Save.profile["bad_luck"].get(pid, 0)),
		"perfect": perfect, "rare_bite": stats().rare_bite,
	})


func _start_charge(c: Vector2i) -> void:
	target_cell = c
	cast.reset()
	var st := stats()
	cast.control = st.control
	cast.widen_bonus = st.perfect_widen
	cast.tempo_slow = st.charge_slow + (float(Data.balance["tutorial"]["charge_slow"]) if tutorial_active else 0.0)
	hud.cast_meter.bounds = cast.zone_bounds()
	hud.cast_meter.visible = true
	hud.hide_cell_info()
	_charge_sound_t = 0.0
	Audio.play("cast_charge", 0.0, -6.0)
	_set_state(State.CHARGING)


func _process_charging(delta: float) -> void:
	cast.update(delta)
	rod.charge = cast.charge
	rod.aim_at(pond.cell_center(target_cell), 0.4)
	hud.cast_meter.value = cast.charge
	_charge_sound_t += delta
	if _charge_sound_t > 1.2:
		_charge_sound_t = 0.0
		Audio.play("cast_charge", 0.0, -8.0)
	if not _action_down:
		_release_cast()


func _release_cast() -> void:
	Audio.stop("cast_charge")
	hud.cast_meter.visible = false
	cast_zone = cast.zone_of(cast.charge)
	rod.charge = 0.0
	var st: Dictionary = Save.profile["stats"]
	st["casts"] = int(st["casts"]) + 1
	land_cell = target_cell
	var center := pond.cell_center(target_cell)
	var jitter := 1.0
	match cast_zone:
		CastModel.Zone.PERFECT:
			jitter = 1.0
			st["perfect_casts"] = int(st["perfect_casts"]) + 1
			hud.pop(center, "PERFECT CAST!", "perfect")
			pond.over_fx.burst(center, UIKit.GOLD, 14)
			Achievements.on_event("perfect_cast", {})
			Orders.on_perfect_cast()
		CastModel.Zone.WEAK:
			var nearer := target_cell + Vector2i(0, 1)
			if Data.is_fishable(pond.pond_id, nearer):
				land_cell = nearer
			jitter = 5.0
			hud.float_text(center, "Weak cast", UIKit.MUTED)
		CastModel.Zone.OVER:
			var opts: Array[Vector2i] = []
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				if Data.is_fishable(pond.pond_id, target_cell + d):
					opts.append(target_cell + d)
			if not opts.is_empty():
				land_cell = opts[rng.randi_range(0, opts.size() - 1)]
			jitter = 4.0
			hud.float_text(center, "Overcast!", UIKit.RED)
		_:
			jitter = 4.0
	var spread := 3.0 if bool(pond.pond.get("holes", false)) else jitter
	land_pos = (pond.cell_center(land_cell) + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread * 0.6, spread * 0.6))).round()
	rod.aim_at(land_pos, 0.45)
	rod.cast_to(land_pos)
	pond.cursor.hide_cursor()
	Audio.play("cast_release")
	Save.mark_dirty()
	_set_state(State.FLYING)


func _on_landed(pos: Vector2) -> void:
	if state != State.FLYING:
		return
	pond.over_fx.splash(pos, 0.5)
	pond.under_fx.ripple(pos, 12.0, 1.0)
	Audio.play("splash", 0.08, -4.0)
	var c: Dictionary = Data.balance["cast"]
	var st := stats()
	var bait := Economy.selected_bait()
	var wait_mult := cast.wait_mult(cast_zone)
	if Economy.bait_active_here(bait, pond.pond_id):
		wait_mult *= float(Data.bait[bait]["wait_mult"])
	wait_mult *= clampf(1.0 - st.luck * 0.004, 0.8, 1.0)
	wait_mult *= maxf(0.4, 1.0 - st.wait_cut)
	if frenzy_left > 0.0:
		wait_mult *= float(Data.balance["frenzy"]["wait_mult"])
	_wait_left = rng.randf_range(float(c["wait_min"]), float(c["wait_max"])) * wait_mult
	_nibbles.clear()
	if tutorial_active:
		_wait_left = float(Data.balance["tutorial"]["wait"])
	else:
		for i in rng.randi_range(int(c["nibbles_min"]), int(c["nibbles_max"])):
			_nibbles.append(rng.randf_range(1.0, maxf(1.2, _wait_left - 0.8)))
	tutorial_event.emit("landed")
	_nibbles.sort()
	_nibble_recent = 0.0
	_set_state(State.WAITING)


func _process_waiting(delta: float) -> void:
	_wait_left -= delta
	_nibble_recent = maxf(0.0, _nibble_recent - delta)
	# nibbles are stored as "time remaining" thresholds
	for i in range(_nibbles.size() - 1, -1, -1):
		if _wait_left <= _nibbles[i]:
			_nibbles.remove_at(i)
			rod.nibble()
			pond.under_fx.ripple(land_pos, 6.0, 0.6)
			pond.under_fx.bubble(land_pos + Vector2(rng.randf_range(-4, 4), -1))
			Audio.play("plop", 0.15, -6.0)
			_nibble_recent = 0.4
	if rng.randf() < delta * 0.8:
		pond.under_fx.bubble(land_pos + Vector2(rng.randf_range(-6, 6), rng.randf_range(-3, 3)))
	if _pressed_this_frame:
		if _nibble_recent > 0.0:
			hud.float_text(land_pos, "Too early!", UIKit.RED)
			Audio.play("escape", 0.05, -6.0)
		rod.reel_in()
		_set_state(State.LOST)
		return
	if _wait_left <= 0.0:
		_start_bite()


func _start_bite() -> void:
	var spot := Data.spot_at(pond.pond_id, land_cell)
	var odds := _odds(spot, cast_zone == CastModel.Zone.PERFECT)
	_pending_species = FishSelector.pick(rng, odds)
	var lvl := Progression.level(_pending_species)
	var bait := Economy.selected_bait()
	if Economy.bait_active_here(bait, pond.pond_id):
		lvl += int(Data.bait[bait]["mastery_bonus"])
	_from_golden = land_cell == golden_cell
	if _from_golden:
		lvl += int(Data.balance["golden_spot"]["mastery_bonus"])
	_pending_rarity = RarityTable.roll(rng, mini(lvl, Progression.max_level()), stats().luck)
	var c: Dictionary = Data.balance["cast"]
	_bite_left = float(c["bite_window"]) + stats().control * float(c["bite_window_per_control"]) + stats().bite_bonus
	if frenzy_left > 0.0:
		_bite_left += float(Data.balance["frenzy"]["bite_bonus"])
	if tutorial_active:
		# the guided first fish: the likeliest species here, common, with a generous window
		var best := ""
		for k in odds:
			if best == "" or float(odds[k]) > float(odds[best]):
				best = k
		_pending_species = best
		_pending_rarity = 0
		_bite_left = float(Data.balance["tutorial"]["bite_window"])
	rod.bite()
	pond.over_fx.splash(land_pos, 0.7)
	pond.under_fx.ripple(land_pos, 14.0, 0.8)
	hud.show_bite(land_pos)
	Audio.play("bite")
	_set_state(State.BITE)


func _process_bite(delta: float) -> void:
	_bite_left -= delta
	if _pressed_this_frame:
		hud.hide_bite()
		_start_fight()
		return
	if _bite_left <= 0.0:
		hud.hide_bite()
		rod.clear_bite()
		hud.pop(land_pos, "It got away...", "info")
		Audio.play("escape", 0.05, -4.0)
		Save.profile["stats"]["escapes"] = int(Save.profile["stats"]["escapes"]) + 1
		_break_streak()
		rod.reel_in()
		_set_state(State.LOST)


func _start_fight() -> void:
	_hook_bait = Economy.selected_bait()
	Economy.consume_bait()
	fight = FightModel.new()
	fight.setup(Data.fish[_pending_species], _pending_rarity, stats())
	if tutorial_active:
		var tu: Dictionary = Data.balance["tutorial"]
		fight.apply_onboarding(float(tu["time_bonus"]), float(tu["tension_mult"]))
	elif _onboarding():
		var ob: Dictionary = Data.balance["onboarding"]
		fight.apply_onboarding(float(ob["first_fight_time_bonus"]), float(ob["first_fight_tension_mult"]))
	_fish_anchor = land_pos
	rod.start_fight(land_pos)
	rod.tension = 0.0
	hud.fight_panel.visible = true
	var known := Progression.is_discovered(_pending_species)
	hud.fight_panel.begin(_pending_rarity, Data.fish_name(_pending_species) if known else "???",
		FightModel.match_info(stats(), Data.fish[_pending_species], _pending_rarity))
	hud.fight_panel.modulate.a = 0.0
	var tw := hud.create_tween()
	tw.tween_property(hud.fight_panel, "modulate:a", 1.0, 0.15)
	pond.over_fx.splash(land_pos, 1.0)
	Audio.play("splash")
	_tension_warned = false
	_hitstop = 0.0
	_set_state(State.FIGHT)
	tutorial_event.emit("fight")
	if _pending_rarity >= 3:
		hud.toasts.toast(UIKit.T("%s fish on the line!") % Data.rarity_name(_pending_rarity), "star", Data.rarity_color(_pending_rarity))


func _process_fight(delta: float) -> void:
	if _pressed_this_frame:
		rod.tap()  # every press answers instantly, the strike is judged below
	var sim_delta := delta
	if _hitstop > 0.0:
		_hitstop -= delta
		sim_delta = delta * 0.1
	fight.step(sim_delta, _pressed_this_frame, _action_down)
	rod.tension = fight.tension_ratio()
	rod.reel_held = fight.held
	for e in fight.pop_events():
		_on_fight_event(e)
	# fish movement: drifts with behaviour, dragged toward the dock as progress rises
	var dock := Vector2(Data.ponds[pond.pond_id]["dock_tip"][0], Data.ponds[pond.pond_id]["dock_tip"][1]) + Vector2(0, -16)
	var anchor := land_pos.lerp(dock, fight.progress / 100.0 * 0.55)
	var amp := 3.0
	var spd := 2.0
	match fight.state:
		"struggle":
			amp = 6.0
			spd = 4.0
		"surge", "final_burst":
			amp = 11.0
			spd = 7.5
		"recovery":
			amp = 2.0
			spd = 1.2
	if bool(pond.pond.get("holes", false)):
		amp = minf(amp, 4.0)  # the fish is confined to the ice hole
		anchor = land_pos
	_fish_wobble += delta * spd
	var target := anchor + Vector2(sin(_fish_wobble * 1.3) * amp, sin(_fish_wobble * 2.1) * amp * 0.45)
	rod.fish_point = rod.fish_point.lerp(target, minf(1.0, delta * 6.0))
	_fx_t -= delta
	if _fx_t <= 0.0:
		var big := fight.state in ["surge", "final_burst"]
		_fx_t = 0.12 if big else (0.35 if fight.state == "struggle" else 0.7)
		pond.under_fx.ripple(rod.fish_point, 8.0 if big else 5.0, 0.7)
		if big or rng.randf() < 0.5:
			pond.over_fx.splash(rod.fish_point, 0.6 if big else 0.25)
	if fight.held:
		_reel_sound_t -= delta
		if _reel_sound_t <= 0.0:
			_reel_sound_t = 0.45
			Audio.play("reel", 0.05, -6.0)
	if fight.tension_ratio() > 0.8 and not _tension_warned:
		_tension_warned = true
		Audio.play("tension")
	elif fight.tension_ratio() < 0.6:
		_tension_warned = false
	hud.fight_panel.update_from(fight, delta)
	if fight.result != "":
		_end_fight()


func _on_fight_event(e: Dictionary) -> void:
	match String(e["type"]):
		"strike":
			var perfect: bool = e["perfect"]
			var combo := int(e["combo"])
			rod.strike(perfect)
			hud.fight_panel.flash(perfect, true)
			Audio.play("strike_perfect" if perfect else "strike_good", 0.04 + combo * 0.01, -2.0)
			var txt := UIKit.T("PERFECT") if perfect else UIKit.T("GOOD")
			if combo >= 2:
				txt += " x%d" % combo
			hud.pop(rod.fish_point, txt, "perfect" if perfect else "good")
			if perfect:
				_hitstop = 0.06
				pond.over_fx.burst(rod.fish_point, UIKit.GOLD, 16)
				get_parent().call("shake", 1.0, 0.1)
			else:
				pond.over_fx.burst(rod.fish_point, UIKit.GREEN, 7)
			if combo == 4 or combo == 8:
				hud.pop(rod.fish_point + Vector2(0, -18), UIKit.T("COMBO x%d!") % combo, "combo")
				pond.over_fx.burst(rod.fish_point, Color("#c983ff"), 24)
				Audio.play("levelup", 0.02, -4.0)
		"miss":
			rod.miss()
			hud.fight_panel.flash(false, false)
			Audio.play("strike_miss", 0.05, -2.0)
			hud.pop(rod.fish_point, "MISS", "miss")
			pond.over_fx.burst(rod.fish_point, UIKit.RED, 6)
			get_parent().call("shake", 1.5, 0.12)
		"telegraph":
			hud.pop(rod.fish_point, "!", "warn")
			Audio.play("plop", 0.05, -2.0)
		"state":
			var s := String(e["state"])
			if s == "surge" or s == "final_burst":
				Audio.play("surge", 0.05, -2.0)
				get_parent().call("shake", 2.0 if s == "surge" else 3.0, 0.35)
				if s == "final_burst":
					hud.pop(rod.fish_point, "FINAL BURST!", "combo")


func _end_fight() -> void:
	hud.fight_panel.visible = false
	rod.reel_held = false
	var st: Dictionary = Save.profile["stats"]
	st["best_combo"] = maxi(int(st["best_combo"]), fight.best_combo)
	Orders.on_combo(fight.best_combo)
	match fight.result:
		"caught":
			_on_caught()
		"snapped":
			rod.snap_line()
			Audio.play("line_snap")
			hud.pop(rod.tip(), "Line snapped!", "miss")
			hud.toasts.toast("Too much tension - release during surges", "line", UIKit.RED)
			st["snaps"] = int(st["snaps"]) + 1
			get_parent().call("shake", 3.0, 0.3)
			_break_streak()
			tutorial_event.emit("failed")
			_set_state(State.LOST)
		"escaped":
			hud.pop(rod.fish_point, "It escaped!", "info")
			Audio.play("escape")
			st["escapes"] = int(st["escapes"]) + 1
			_break_streak()
			tutorial_event.emit("failed")
			rod.reel_in()
			_set_state(State.LOST)
	Achievements.check_all()
	Save.mark_dirty()


func _on_caught() -> void:
	var species: Dictionary = Data.fish[_pending_species]
	var st := stats()
	var w := Valuation.roll_weight(rng, species, _pending_rarity, st.luck)
	var q := Valuation.quality(cast_zone == CastModel.Zone.PERFECT, fight.precision())
	var value := Valuation.value(species, _pending_rarity, w, q)
	# the catch card counts the price up factor by factor (chips x mult)
	var parts: Array = [["Base", float(species["base_value"])], ["Rarity", float(Data.rarity(_pending_rarity)["value_mult"])],
		["Size", Valuation.weight_mult(species, w)], ["Skill", q]]
	var prev_record := float(Progression.entry(_pending_species)["record"]) if Progression.has_entry(_pending_species) else 0.0
	if prev_record > 0.0 and w > prev_record:
		var rb := 1.0 + float(Data.balance["valuation"]["record_bonus_mult"])
		value = int(round(value * rb))
		parts.append(["Record", rb])
	# hot streak, talents, golden spots, frenzy and prismatic variants multiply the sale value
	var stt: Dictionary = Save.profile["stats"]
	stt["streak"] = int(stt["streak"]) + 1
	stt["best_streak"] = maxi(int(stt["best_streak"]), int(stt["streak"]))
	var mult := 1.0 + st.sell_bonus + streak_bonus()
	if mult > 1.001:
		parts.append(["Streak", mult])
	if _from_golden:
		mult *= float(Data.balance["golden_spot"]["value_mult"])
		parts.append(["Golden", float(Data.balance["golden_spot"]["value_mult"])])
		stt["golden_catches"] = int(stt["golden_catches"]) + 1
		golden_cell = Vector2i(-1, -1)
		_golden_left = 0.0
		pond.golden_cell = golden_cell
	if frenzy_left > 0.0:
		mult *= float(Data.balance["frenzy"]["value_mult"])
		parts.append(["Frenzy", float(Data.balance["frenzy"]["value_mult"])])
	var prismatic := false
	if not tutorial_active:
		var vr: Dictionary = Data.balance["variants"]
		prismatic = rng.randf() < float(vr["prismatic_chance"]) + st.luck * float(vr["luck_per_point"])
		if prismatic:
			mult *= float(vr["value_mult"])
			parts.append(["Prismatic", float(vr["value_mult"])])
	value = int(round(value * mult))
	if _pending_rarity >= 4:
		stt["legendaries"] = int(stt["legendaries"]) + 1
	(stt["habitats"] as Dictionary)[pond.pond_id + ":" + Data.spot_at(pond.pond_id, land_cell)] = true
	var rec := {
		"species": _pending_species, "rarity": _pending_rarity, "weight": w, "value": value,
		"pond": pond.pond_id, "time": int(Time.get_unix_time_from_system()), "quality": snappedf(q, 0.01),
		"spot": Data.spot_at(pond.pond_id, land_cell), "prismatic": prismatic, "parts": parts,
	}
	var flags := Progression.register_catch(rec)
	if not tutorial_active:
		var loot := Economy.roll_treasure(rng, pond.pond_id, _hook_bait)
		if not loot.is_empty():
			flags["treasure"] = loot
	pond.over_fx.splash(rod.fish_point, 1.2)
	pond.over_fx.burst(rod.fish_point, Data.rarity_color(_pending_rarity), 18 + _pending_rarity * 10)
	Audio.play(["catch", "catch", "catch_rare", "catch_rare", "catch_legendary"][_pending_rarity])
	if flags["new_species"]:
		Audio.play("discovery")
	get_parent().call("shake", 1.0 + _pending_rarity * 0.8, 0.2 + _pending_rarity * 0.08)
	hud.celebrate(_pending_rarity, rod.fish_point)
	Orders.on_catch(rec)
	_check_frenzy()
	var boss := _pending_species in ["kraken", "megalodon"]
	if prismatic or boss or _pending_rarity >= int(Data.balance["cinematic"]["min_rarity"]):
		var ttl := UIKit.T("%s LANDED!") % Data.fish_name(_pending_species).to_upper() if boss else ("PRISMATIC!" if prismatic else "LEGENDARY!")
		hud.cinematic(ttl, Color("#bdf6ff") if prismatic else Data.rarity_color(_pending_rarity), rod.fish_point)
	if int(Save.profile["stats"]["streak"]) >= 3:
		hud.pop(rod.fish_point + Vector2(0, -20), UIKit.T("STREAK x%d") % int(Save.profile["stats"]["streak"]), "combo")
	rod.celebrate()
	rod.reel_in()
	_set_state(State.RESULT)
	catch_made.emit(rec, flags)
	tutorial_event.emit("caught")


func streak_bonus() -> float:
	var s: Dictionary = Data.balance["streak"]
	return float(s["per"]) * mini(int(Save.profile["stats"]["streak"]), int(s["max"]))


func _check_frenzy() -> void:
	var f: Dictionary = Data.balance["frenzy"]
	var sk := int(Save.profile["stats"]["streak"])
	if tutorial_active or sk < int(f["at"]) or (sk - int(f["at"])) % int(f["every"]) != 0:
		return
	frenzy_left = float(f["duration"])
	Save.profile["stats"]["frenzies"] = int(Save.profile["stats"].get("frenzies", 0)) + 1
	hud.set_frenzy(true)
	hud.toasts.banner("FEEDING FRENZY!", "Fish bite fast and sell for more. Keep the streak alive!", Color("#ff9a3c"))
	Audio.play("surge", 0.02, -2.0)
	Audio.music_pitch(float(f["music_pitch"]))
	get_parent().call("shake", 2.5, 0.35)


func _end_frenzy() -> void:
	frenzy_left = 0.0
	hud.set_frenzy(false)
	Audio.music_pitch(1.0)


func _break_streak() -> void:
	Orders.on_lost()
	if frenzy_left > 0.0:
		_end_frenzy()
	var stt: Dictionary = Save.profile["stats"]
	if int(stt["streak"]) >= 3:
		hud.toasts.toast(UIKit.T("Streak lost (x%d)") % int(stt["streak"]), "close", UIKit.MUTED)
	stt["streak"] = 0


func _process_golden(delta: float) -> void:
	## Golden spots: a sparkling cell appears now and then; fish caught there roll rarer and sell for more.
	if tutorial_active:
		return
	var g: Dictionary = Data.balance["golden_spot"]
	if golden_cell.x >= 0:
		_golden_left -= delta
		if _golden_left <= 0.0 and state != State.WAITING and state != State.BITE and state != State.FIGHT:
			golden_cell = Vector2i(-1, -1)
			pond.golden_cell = golden_cell
			_golden_next = rng.randf_range(float(g["min"]), float(g["max"]))
		return
	_golden_next -= delta
	if _golden_next <= 0.0:
		var st := stats()
		var opts: Array[Vector2i] = []
		for c in Data.fishable_cells(pond.pond_id):
			if pond.is_reachable(c, st.reach):
				opts.append(c)
		if opts.is_empty():
			_golden_next = 30.0
			return
		golden_cell = opts[rng.randi_range(0, opts.size() - 1)]
		_golden_left = float(g["duration"])
		pond.golden_cell = golden_cell
		hud.toasts.toast("A golden spot sparkles on the water!", "star", UIKit.GOLD, 3.0)
		Audio.play("discovery", 0.02, -6.0)


func result_closed() -> void:
	if state == State.RESULT:
		_set_state(State.IDLE)


func _on_reeled_in() -> void:
	if state == State.LOST:
		_set_state(State.IDLE)


func force_idle() -> void:
	## Used when travelling between ponds or returning to the menu.
	if frenzy_left > 0.0:
		_end_frenzy()
	Audio.stop("cast_charge")
	hud.cast_meter.visible = false
	hud.fight_panel.visible = false
	hud.hide_bite()
	rod.charge = 0.0
	rod.reset_hanging()
	_set_state(State.IDLE)
