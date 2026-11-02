class_name Hud
extends Control
## In-game HUD: pond/time plaque, coins, menu buttons, bait, contextual hints,
## cell odds tooltip, cast meter, fight panel, bite marker and floating text.

signal open_requested(panel: String)

var pond_label: Label
var clock_label: Label
var phase_icon: TextureRect
var weather_icon: TextureRect
var coins_label: Label
var rod_label: Label
var coach: PanelContainer
var streak_panel: PanelContainer
var streak_label: Label
var coach_label: Label
var bait_button: UIButton
var hint_label: Label
var hint_panel: PanelContainer
var tooltip: PanelContainer
var tip_box: VBoxContainer
var cast_meter: CastMeter
var fight_panel: FightPanel
var bite_mark: TextureRect
var toasts: Toasts
var menu_buttons: Array[UIButton] = []
var _bottom: VBoxContainer
var _float_layer: Control
var _shown_coins := 0.0
var _coin_target := 0
var _bite_t := 0.0
var orders_box: PanelContainer
var _orders_list: VBoxContainer
var frenzy_frame: Juice.FrenzyFrame
var _letterbox: Juice.Letterbox
var _fx_layer: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UIKit.theme()
	_build_top()
	_build_bottom()
	tooltip = UIKit.panel("DarkPanel")
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.visible = false
	tip_box = UIKit.vbox(1)
	tooltip.add_child(tip_box)
	add_child(tooltip)
	cast_meter = CastMeter.new()
	cast_meter.position = Vector2(254, 300)
	cast_meter.visible = false
	add_child(cast_meter)
	fight_panel = FightPanel.new()
	fight_panel.position = Vector2(4, 287)
	fight_panel.visible = false
	add_child(fight_panel)
	bite_mark = TextureRect.new()
	bite_mark.texture = load("res://assets/art/fx/bite_mark.png")
	bite_mark.visible = false
	bite_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bite_mark)
	_float_layer = Control.new()
	_float_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_float_layer)
	coach = UIKit.panel("HeaderPanel")
	coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coach_label = UIKit.label("", 10, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	coach.add_child(coach_label)
	coach.visible = false
	add_child(coach)
	frenzy_frame = Juice.FrenzyFrame.new()
	add_child(frenzy_frame)
	_fx_layer = Control.new()
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)
	_build_orders()
	_letterbox = Juice.Letterbox.new()
	add_child(_letterbox)
	toasts = Toasts.new()
	add_child(toasts)
	Economy.coins_changed.connect(_on_coins)
	Economy.equipment_changed.connect(func(_s: String, _t: int) -> void: refresh())
	Economy.talents_changed.connect(refresh)
	Economy.bait_changed.connect(refresh)
	Settings.input_device_changed.connect(func(_p: bool) -> void: refresh())
	_shown_coins = Economy.coins()
	_coin_target = Economy.coins()
	refresh()


func _plaque(variation: String = "DarkPanel") -> PanelContainer:
	var p := UIKit.panel(variation)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _build_top() -> void:
	var left := _plaque("HeaderPanel")
	left.position = Vector2(4, 3)
	var lh := UIKit.hbox(4)
	pond_label = UIKit.label("Willow Pond", 10, UIKit.GOLD)
	lh.add_child(pond_label)
	phase_icon = UIKit.icon("sun")
	lh.add_child(phase_icon)
	clock_label = UIKit.label("07:00")
	lh.add_child(clock_label)
	weather_icon = UIKit.icon("rain")
	lh.add_child(weather_icon)
	left.add_child(lh)
	add_child(left)
	var right := _plaque("HeaderPanel")
	var rh := UIKit.hbox(4)
	rh.add_child(UIKit.icon("coin"))
	coins_label = UIKit.label("0", 10, UIKit.GOLD)
	coins_label.custom_minimum_size.x = 40
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rh.add_child(coins_label)
	rh.add_child(UIKit.icon("rod"))
	rod_label = UIKit.label("10")
	rh.add_child(rod_label)
	streak_panel = _plaque("DarkPanel")
	var sh := UIKit.hbox(3)
	sh.add_child(UIKit.icon("star"))
	streak_label = UIKit.label("", 10, Color("#ffb53d"))
	sh.add_child(streak_label)
	streak_panel.add_child(sh)
	streak_panel.visible = false
	add_child(streak_panel)
	right.add_child(rh)
	add_child(right)
	right.reset_size()
	right.position = Vector2(640 - 4 - 150, 3)
	right.custom_minimum_size.x = 150


func _build_bottom() -> void:
	var bar := UIKit.vbox(3)
	bar.position = Vector2(4, 296)
	add_child(bar)
	_bottom = bar
	bait_button = UIKit.button("Worm", "worm")
	bait_button.tooltip_text = "Change bait"
	bait_button.pressed.connect(func() -> void: Economy.cycle_bait())
	bait_button.focus_mode = Control.FOCUS_NONE
	bar.add_child(bait_button)
	var row := UIKit.hbox(2)
	bar.add_child(row)
	for spec in [["shop", "shop", "Shop"], ["codex", "book", "Codex"], ["map", "map", "Map"], ["trophies", "trophy", "Trophies"], ["journal", "scroll", "Journal"], ["habitats", "target", "Spots"], ["pause", "gear", "Menu"]]:
		var b := UIKit.button("", spec[1])
		b.tooltip_text = spec[2]
		b.set_min_size(Vector2(34, 28) if Settings.using_touch else Vector2(26, 22))
		b.focus_mode = Control.FOCUS_NONE
		var key: String = spec[0]
		b.pressed.connect(func() -> void: open_requested.emit(key))
		row.add_child(b)
		menu_buttons.append(b)
	hint_panel = _plaque()
	hint_label = UIKit.label("", 10)
	hint_panel.add_child(hint_label)
	add_child(hint_panel)


func set_menu_enabled(on: bool) -> void:
	for b in menu_buttons:
		b.disabled = not on
	bait_button.disabled = not on


func set_coach(text: String) -> void:
	## First-session coaching line (onboarding). Empty text hides it.
	if UIKit.T(text) == coach_label.text and coach.visible == (text != ""):
		return
	coach_label.text = UIKit.T(text)
	coach.visible = text != ""
	if text == "":
		return
	coach.reset_size()
	coach.position = Vector2(floorf((640 - coach.size.x) / 2.0), 21)
	coach.modulate.a = 0.0
	create_tween().tween_property(coach, "modulate:a", 1.0, 0.2)


func set_fight_mode(on: bool) -> void:
	_bottom.visible = not on
	orders_box.visible = not on and bool(Save.profile.get("tutorial_done", false))


func set_hint(text: String) -> void:
	hint_label.text = UIKit.T(text)
	hint_panel.visible = text != ""
	hint_panel.reset_size()
	hint_panel.position = Vector2(floorf((640 - hint_panel.size.x) / 2.0), 3)


func refresh() -> void:
	if not Save.profile.has("current_pond"):
		return
	var pid := String(Save.profile["current_pond"])
	pond_label.text = Data.pond_name(pid)
	rod_label.text = UIKit.T("Gear %d") % int(round(Economy.stats().gear_rating()))
	var b := Economy.selected_bait()
	var bd: Dictionary = Data.bait[b]
	var cnt := Economy.bait_count(b)
	bait_button.caption = UIKit.T("%s%s   (%s)") % [UIKit.T(bd["name"]), ("" if cnt < 0 else UIKit.T(" x%d") % cnt), Settings.prompt("cycle_bait")]
	bait_button.set_icon_texture(UIKit.icon_tex(String(bd["icon"]).replace("bait_", "")))
	if not Economy.bait_active_here(b, pid):
		bait_button.caption = UIKit.T("%s - no effect here   (%s)") % [UIKit.T(bd["name"]), Settings.prompt("cycle_bait")]


func _on_coins(c: int, delta: int) -> void:
	_coin_target = c
	if delta > 0 and is_inside_tree():
		coin_fly(Vector2(320, 170), delta)
	if delta > 0:
		var tw := create_tween()
		coins_label.pivot_offset = coins_label.size * 0.5
		tw.tween_property(coins_label, "modulate", Color(1.4, 1.3, 0.8), 0.08)
		tw.tween_property(coins_label, "modulate", Color.WHITE, 0.25)


func _process(delta: float) -> void:
	_shown_coins = lerpf(_shown_coins, float(_coin_target), minf(1.0, delta * 8.0))
	if absf(_shown_coins - _coin_target) < 0.6:
		_shown_coins = _coin_target
	coins_label.text = UIKit.fmt_int(int(round(_shown_coins)))
	if Save.profile.has("clock"):
		clock_label.text = Clock.clock_text()
		var ph := Clock.phase()
		phase_icon.texture = UIKit.icon_tex("moon" if ph == "night" else "sun")
		var w := Clock.weather(String(Save.profile["current_pond"]))
		weather_icon.visible = w != "clear"
		weather_icon.texture = UIKit.icon_tex("snow" if w == "snow" else "rain")
	if Save.profile.has("stats"):
		var sk := int(Save.profile["stats"].get("streak", 0))
		streak_panel.visible = sk >= 2
		if streak_panel.visible:
			var per: float = float(Data.balance["streak"]["per"]) * mini(sk, int(Data.balance["streak"]["max"]))
			streak_label.text = UIKit.T("Streak x%d  +%d%%") % [sk, int(round(per * 100.0))]
			streak_panel.reset_size()
			streak_panel.position = Vector2(640 - 4 - streak_panel.size.x, 24)
	if bite_mark.visible:
		_bite_t += delta
		bite_mark.modulate.a = 1.0 if (Settings.reduced_flashing or int(_bite_t * 10.0) % 2 == 0) else 0.6


# ------------------------------------------------------------------ cell tooltip
static func forecast_tier(p: float) -> Array:
	## Likelihood tier for a species-appearance probability: [label, colour].
	var colours := [Color("#bdf06a"), Color("#86dc4c"), Color("#fff6dc"), Color("#c7a670"), Color("#8a919a")]
	var tiers: Array = Data.balance["forecast"]["tiers"]
	for i in tiers.size():
		if p >= float(tiers[i][0]):
			return [String(tiers[i][1]), colours[mini(i, colours.size() - 1)]]
	return ["Very rare", colours[-1]]


func show_cell_info(cell_rect: Rect2, spot: String, odds: Dictionary, state: String, extra: String = "") -> void:
	## Fishing forecast for one cell: which species appear here (stage A), never the rarity roll (stage B).
	for c in tip_box.get_children():
		tip_box.remove_child(c)
		c.queue_free()
	var st: Dictionary = Data.spot_types.get(spot, {})
	tip_box.add_child(UIKit.label(String(st.get("name", "")), 10, UIKit.GOLD))
	tip_box.add_child(UIKit.label(String(st.get("hint", "")), 10, Color("#a7c6e6")))
	if state == "far":
		tip_box.add_child(UIKit.label("Out of reach - upgrade your Rod", 10, UIKit.RED))
	else:
		var st_now := Economy.stats()
		var keys := odds.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return float(odds[a]) > float(odds[b]))
		var learn_at := int(Data.balance["forecast"]["exact_after_catches"])
		for id in keys:
			var h := UIKit.hbox(3)
			var known := Progression.is_discovered(id)
			var nm := UIKit.label(Data.fish_name(id) if known else "???", 10, UIKit.CREAM if known else UIKit.MUTED)
			nm.custom_minimum_size.x = 104
			h.add_child(nm)
			var tier := forecast_tier(float(odds[id]))
			var txt := String(tier[0])
			# exact chances are learned by experience: shown after a few catches of that species
			if known and int(Progression.entry(id)["caught"]) >= learn_at:
				txt += UIKit.T(" %d%%") % maxi(1, int(round(float(odds[id]) * 100.0)))
			var tl := UIKit.label(txt, 10, tier[1])
			tl.custom_minimum_size.x = 76
			h.add_child(tl)
			var mi := FightModel.match_info(st_now, Data.fish[id], 0)
			var mtxt := UIKit.T(String(mi[0]))
			if float(mi[2]) < 0.65:
				mtxt += " " + UIKit.T("(gear %d+)") % int(ceil(FightModel.power_of(Data.fish[id], 0) * 0.9))
			var ml := UIKit.label(mtxt, 10, mi[1])
			ml.custom_minimum_size.x = 64
			h.add_child(ml)
			if known:
				h.add_child(UIKit.label(UIKit.T("Lv%d") % Progression.level(id), 10, Color("#7fdcc2")))
			tip_box.add_child(h)
		if extra != "":
			tip_box.add_child(UIKit.label(extra, 10, UIKit.MUTED))
		tip_box.add_child(UIKit.label("Fight: your gear vs each fish (common). Rarer fish are stronger.", 10, Color(1, 1, 1, 0.45)))
	tooltip.visible = true
	tooltip.reset_size()
	var pos := cell_rect.position + Vector2(cell_rect.size.x + 6, -4)
	if pos.x + tooltip.size.x > 636:
		pos.x = cell_rect.position.x - tooltip.size.x - 6
	pos.x = clampf(pos.x, 4, 636 - tooltip.size.x)
	pos.y = clampf(pos.y, 24, 360 - tooltip.size.y - 4)
	tooltip.position = pos.floor()


func hide_cell_info() -> void:
	tooltip.visible = false


# ------------------------------------------------------------------ fishing feedback
func show_bite(world_pos: Vector2) -> void:
	bite_mark.visible = true
	_bite_t = 0.0
	bite_mark.position = (world_pos + Vector2(-4, -24)).floor()
	var tw := create_tween()
	tw.tween_property(bite_mark, "position:y", bite_mark.position.y - 3, 0.08)
	tw.tween_property(bite_mark, "position:y", bite_mark.position.y, 0.12).set_trans(Tween.TRANS_BOUNCE)


func hide_bite() -> void:
	bite_mark.visible = false


func pop(world_pos: Vector2, text: String, kind: String = "good", color: Color = Color(0, 0, 0, 0)) -> void:
	var p := PopText.new().setup(text, kind, color)
	p.position = (world_pos - Vector2(0, 22)).floor()
	_float_layer.add_child(p)


func celebrate(rarity: int, world_pos: Vector2) -> void:
	if rarity >= 2:
		_float_layer.add_child(Celebration.new().setup(rarity, world_pos))
		var names := ["", "", "RARE!", "EPIC!", "LEGENDARY!"]
		pop(world_pos + Vector2(0, -26), names[rarity], "rare", Data.rarity_color(rarity))


func float_text(world_pos: Vector2, text: String, color: Color, big := false) -> void:
	var l := UIKit.label(text, 20 if big else 10, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(l)
	l.reset_size()
	l.position = (world_pos - Vector2(l.size.x * 0.5, 18)).floor()
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 14, 0.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------------------ orders, coins, frenzy, cinematic
func _build_orders() -> void:
	orders_box = _plaque("DarkPanel")
	orders_box.position = Vector2(4, 22)
	_orders_list = UIKit.vbox(0)
	_orders_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orders_box.add_child(_orders_list)
	add_child(orders_box)
	Orders.orders_changed.connect(refresh_orders)
	Orders.order_done.connect(_on_order_done)
	refresh_orders()


func refresh_orders() -> void:
	if not Save.profile.has("stats") or _orders_list == null:
		return
	# the guided first catch keeps the screen clean: orders appear once it is done
	orders_box.visible = bool(Save.profile.get("tutorial_done", false)) and _bottom.visible
	for c in _orders_list.get_children():
		_orders_list.remove_child(c)
		c.queue_free()
	var head := UIKit.hbox(3)
	head.add_child(UIKit.icon("scroll"))
	head.add_child(UIKit.label("Captain's Orders", 10, UIKit.GOLD))
	_orders_list.add_child(head)
	for o in Orders.list():
		var h := UIKit.hbox(3)
		var t := UIKit.label(Orders.text(o), 10, UIKit.CREAM)
		h.add_child(t)
		h.add_child(UIKit.label("%d/%d" % [int(o["progress"]), int(o["target"])], 10, UIKit.GREEN if int(o["progress"]) > 0 else UIKit.MUTED))
		h.add_child(UIKit.label("+" + UIKit.fmt_int(int(o["reward"])), 10, UIKit.GOLD))
		_orders_list.add_child(h)
	orders_box.reset_size()


func _on_order_done(o: Dictionary, reward: int) -> void:
	Audio.play("purchase", 0.02, -2.0)
	toasts.toast(UIKit.T("Order complete: %s  +%s") % [Orders.text(o), UIKit.fmt_int(reward)], "check", UIKit.GOLD, 3.0)
	var tw := create_tween()
	tw.tween_property(orders_box, "modulate", Color(1.6, 1.5, 0.8), 0.08)
	tw.tween_property(orders_box, "modulate", Color.WHITE, 0.4)


func coin_fly(from: Vector2, amount: int) -> void:
	var f := Juice.CoinFlight.new()
	f.from = from
	f.to = coins_label.global_position + Vector2(coins_label.size.x - 6, 6)
	f.count = clampi(3 + int(log(maxf(1.0, float(amount))) / log(3.0)), 3, 16)
	_fx_layer.add_child(f)


func set_frenzy(on: bool) -> void:
	frenzy_frame.time_left = 0.0 if not on else 1.0


func frenzy_time(t: float) -> void:
	frenzy_frame.time_left = t


func cinematic(title: String, color: Color, at: Vector2) -> void:
	## Legendary / prismatic / boss moment: slow motion, cinema bars and a stamped title.
	var c: Dictionary = Data.balance["cinematic"]
	orders_box.visible = false
	tooltip.visible = false
	var tw := create_tween()
	tw.tween_property(_letterbox, "bar", 1.0, 0.18)
	var t := PopText.new().setup(title, "rare", color)
	t.position = Vector2(320, 98)
	_letterbox.add_child(t)
	Engine.time_scale = float(c["slowmo"])
	await get_tree().create_timer(float(c["time"]), true, false, true).timeout
	Engine.time_scale = 1.0
	var tw2 := create_tween()
	tw2.tween_property(_letterbox, "bar", 0.0, 0.3).set_delay(0.6)
	tw2.tween_callback(func() -> void: orders_box.visible = _bottom.visible and bool(Save.profile.get("tutorial_done", false)))


func _exit_tree() -> void:
	Engine.time_scale = 1.0
