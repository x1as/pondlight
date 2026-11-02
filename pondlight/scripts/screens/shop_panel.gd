class_name ShopPanel
extends ModalPanel
## Tackle shop: equipment tiers (before/after), talent sectors and bait.
## Every stat, item and talent explains itself on hover / gamepad focus (HoverTip).

const STAT_NAMES := {"gear": "GEAR", "power": "POWER", "reel": "REEL", "control": "CONTROL", "line": "LINE", "luck": "LUCK", "reach": "REACH"}
const STAT_ICONS := {"gear": "gear", "power": "rod", "reel": "reel", "line": "line", "control": "target", "luck": "clover", "reach": "reach"}
const STAT_DESC := {
	"gear": "Your whole kit in one number: the average of Power, Reel and Line/10. Compare it with a fish's power - equal is a fair fight, half is brutal, double is easy. Rarer fish are stronger.",
	"power": "Rod power. How far each well-timed tap drags the fish. Below the fish's power your strikes barely move it.",
	"reel": "Reel speed. Progress while you hold to reel in. A weak reel cannot land a strong fish before it escapes.",
	"line": "Line strength (shown as Line/10 against the fish's power). A strong line keeps tension low; a weak one snaps on big fish.",
	"control": "Steadier hands: a wider target zone, tension that eases faster, a calmer cast and a longer bite window.",
	"luck": "Nudges rarity rolls upward (up to 3 points), grows bigger specimens and finds more treasure.",
	"reach": "How many rows of water you can cast to. Wild waters start further out, so they need more reach.",
}
const SLOT_ICONS := {"rod": "rod", "reel": "reel", "line": "line", "charm": "charm"}

var _tab := "gear"
var _body: VBoxContainer
var _stats_row: HBoxContainer
var _coins: HBoxContainer
var _tab_buttons: Dictionary = {}


func _init() -> void:
	super._init()
	title = "Tackle Shop"
	panel_size = Vector2(500, 320)


func _build() -> void:
	var top := UIKit.hbox(4)
	for t in [["gear", "Equipment", "rod"], ["talents", "Talents", "star"], ["bait", "Bait", "worm"]]:
		var b := UIKit.button(t[1], t[2])
		var key: String = t[0]
		b.pressed.connect(func() -> void:
			_tab = key
			_refresh())
		top.add_child(b)
		_tab_buttons[key] = b
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	_coins = UIKit.hbox(2)
	_coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_coins)
	content.add_child(top)
	_stats_row = UIKit.hbox(3)
	_stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(_stats_row)
	_body = UIKit.vbox(3)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_body)
	Economy.coins_changed.connect(_on_coins)
	_refresh()


func _on_coins(_c: int, _d: int) -> void:
	if is_inside_tree():
		_refresh()


func _refresh() -> void:
	clear(_coins)
	_coins.add_child(UIKit.coin_row(Economy.coins()))
	clear(_stats_row)
	var s := Economy.stats().to_dict()
	for k in ["gear", "power", "reel", "line", "control", "luck", "reach"]:
		_stats_row.add_child(_stat_chip(k, s))
	clear(_body)
	for k in _tab_buttons.keys():
		(_tab_buttons[k] as Button).theme_type_variation = "PrimaryButton" if k == _tab else ""
	if _tab == "gear":
		for slot in Data.slot_order:
			_body.add_child(_gear_row(slot))
		_body.add_child(_gear_check())
	elif _tab == "talents":
		_build_talents()
	else:
		_build_bait()


static func stat_text(k: String, s: Dictionary) -> String:
	if k == "line":
		return str(int(round(float(s["line"]) / 10.0)))
	return str(int(round(float(s[k]))))


func _stat_chip(k: String, s: Dictionary) -> Control:
	var p := UIKit.panel("DarkPanel")
	p.focus_mode = Control.FOCUS_ALL
	var h := UIKit.hbox(2)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	h.add_child(UIKit.icon(STAT_ICONS[k]))
	var v := UIKit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UIKit.label(UIKit.T(STAT_NAMES[k]), 10, UIKit.MUTED))
	v.add_child(UIKit.label(stat_text(k, s), 10, UIKit.GOLD if k == "gear" else UIKit.CREAM))
	h.add_child(v)
	HoverTip.attach(p, UIKit.T(STAT_NAMES[k]) + "  " + stat_text(k, s), STAT_DESC[k])
	return p


func _gear_row(slot: String) -> Control:
	var p := UIKit.panel("DarkPanel")
	var h := UIKit.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var tier := Economy.tier_of(slot)
	var cur := Data.tier(slot, tier)
	if slot == "rod":
		var rp := RodPreview.new()
		rp.tier = tier
		rp.custom_minimum_size = Vector2(22, 22)
		h.add_child(rp)
	else:
		h.add_child(UIKit.icon(SLOT_ICONS[slot]))
	var nv := UIKit.vbox(0)
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nv.custom_minimum_size.x = 132
	nv.add_child(UIKit.label(String(cur["name"]), 10, UIKit.GOLD))
	nv.add_child(_pips(tier + 1, Data.tier_count(slot)))
	h.add_child(nv)
	var cost := Economy.next_cost(slot)
	var diff := UIKit.vbox(0)
	diff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(diff)
	var tip := String(Data.slots[slot]["stat_desc"])
	if cost < 0:
		diff.add_child(UIKit.label("Fully upgraded", 10, UIKit.GREEN))
	else:
		var nxt := Data.tier(slot, tier + 1)
		var eq: Dictionary = (Save.profile["equipment"] as Dictionary).duplicate()
		var before := PlayerStats.from_equipment(eq).apply_talents(Save.profile["talents"]).to_dict()
		eq[slot] = tier + 1
		var after := PlayerStats.from_equipment(eq).apply_talents(Save.profile["talents"]).to_dict()
		diff.add_child(UIKit.label(UIKit.T("Next: %s") % UIKit.T(nxt["name"]), 10, UIKit.CREAM))
		var changes := UIKit.hbox(6)
		changes.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lines: Array[String] = []
		for k in ["power", "reel", "line", "control", "luck", "reach", "gear"]:
			if stat_text(k, after) != stat_text(k, before):
				var t := UIKit.T("%s %s>%s") % [UIKit.T(STAT_NAMES[k]), stat_text(k, before), stat_text(k, after)]
				lines.append(t)
				if k != "gear" or lines.size() <= 2:
					changes.add_child(UIKit.label(t, 10, UIKit.GOLD if k == "gear" else UIKit.GREEN))
		diff.add_child(changes)
		tip += "\n" + UIKit.T("Next tier: %s") % ", ".join(lines)
	HoverTip.attach(p, UIKit.T(Data.slots[slot]["name"]), tip)
	var buy := UIKit.button("Max" if cost < 0 else UIKit.fmt_int(cost), "coin", cost >= 0 and Economy.coins() >= cost)
	buy.set_min_width(76)
	buy.disabled = cost < 0 or Economy.coins() < cost
	buy.pressed.connect(func() -> void:
		if Economy.buy_upgrade(slot):
			Audio.play("purchase")
			_refresh()
			focus_first.call_deferred()
			_flash(_body.get_child(Data.slot_order.find(slot))))
	h.add_child(buy)
	return p


func _pips(n: int, total: int) -> Control:
	## Tier pips as tiny gold/dark squares.
	var c := Pips.new()
	c.n = n
	c.total = total
	c.custom_minimum_size = Vector2(total * 5, 7)
	return c


func _gear_check() -> Control:
	## How the current kit fares against each unlocked pond's toughest regular fish.
	var p := UIKit.panel("DarkPanel")
	var outer := UIKit.hbox(10)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(outer)
	outer.add_child(UIKit.label("Gear check:", 10, UIKit.MUTED))
	var h := GridContainer.new()
	h.columns = 2
	h.add_theme_constant_override("h_separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(h)
	var st := Economy.stats()
	var body := ""
	for pid in Data.pond_order:
		var strongest := ""
		for id in Data.species_of(pid):
			if strongest == "" or float(Data.fish[id]["fight"]["power"]) > float(Data.fish[strongest]["fight"]["power"]):
				strongest = id
		var mi := FightModel.match_info(st, Data.fish[strongest], 0)
		var row := UIKit.hbox(2)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(UIKit.label(Data.pond_name(pid) + ":", 10, UIKit.CREAM if Economy.is_unlocked(pid) else UIKit.MUTED))
		row.add_child(UIKit.label(UIKit.T(String(mi[0])), 10, mi[1]))
		h.add_child(row)
		body += UIKit.T("%s - strongest fish %s (power %d, legendary %d)") % [Data.pond_name(pid), Data.fish_name(strongest),
			int(Data.fish[strongest]["fight"]["power"]), int(round(FightModel.power_of(Data.fish[strongest], 4)))] + "\n"
	HoverTip.attach(p, UIKit.T("Your gear %d") % int(round(st.gear_rating())), body.strip_edges())
	return p


func _flash(c: Control) -> void:
	var tw := create_tween()
	tw.tween_property(c, "modulate", Color(1.5, 1.4, 0.9), 0.08)
	tw.tween_property(c, "modulate", Color.WHITE, 0.3)


func _scroll() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(470, 216)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_body.add_child(scroll)
	var list := UIKit.vbox(2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _build_talents() -> void:
	var list := _scroll()
	for sec in Data.talent_sectors:
		var head := UIKit.hbox(4)
		head.add_child(UIKit.icon(String(sec["icon"])))
		head.add_child(UIKit.label(String(sec["name"]), 10, UIKit.GOLD))
		list.add_child(head)
		for t in sec["talents"]:
			list.add_child(_talent_row(t))


static func talent_value(t: Dictionary, lv: int) -> String:
	var v := float(t["per"]) * lv
	match String(t["effect"]):
		"bite_window":
			return UIKit.T("+%.2f s") % v
		"luck", "reach":
			return "+%d" % int(v)
		"chest":
			return "+%.1f%%" % (v * 100.0)
	return "+%d%%" % int(round(v * 100.0))


func _talent_row(t: Dictionary) -> Control:
	var id := String(t["id"])
	var lv := Economy.talent_level(id)
	var mx := int(t["max"])
	var p := UIKit.panel("DarkPanel")
	var h := UIKit.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var nv := UIKit.vbox(0)
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UIKit.hbox(6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(UIKit.label(String(t["name"]), 10, UIKit.CREAM))
	var pp := _pips(lv, mx)
	pp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(pp)
	top.add_child(UIKit.label("%d/%d" % [lv, mx], 10, UIKit.GREEN if lv > 0 else UIKit.MUTED))
	top.add_child(UIKit.label(talent_value(t, lv), 10, UIKit.GOLD))
	nv.add_child(top)
	nv.add_child(UIKit.label(String(t["desc"]), 10, UIKit.MUTED))
	h.add_child(nv)
	var tip := UIKit.T(t["desc"]) + "\n" + UIKit.T("Now: %s") % talent_value(t, lv)
	if lv < mx:
		tip += "   " + UIKit.T("Next: %s") % talent_value(t, lv + 1)
	HoverTip.attach(p, UIKit.T(t["name"]), tip)
	var cost := Economy.talent_cost(id)
	var buy := UIKit.button("Max" if cost < 0 else UIKit.fmt_int(cost), "coin", cost >= 0 and Economy.coins() >= cost)
	buy.set_min_width(76)
	buy.disabled = cost < 0 or Economy.coins() < cost
	buy.pressed.connect(func() -> void:
		if Economy.buy_talent(id):
			Audio.play("purchase")
			_refresh()
			_flash(_stats_row))
	h.add_child(buy)
	return p


func _build_bait() -> void:
	var list := _scroll()
	for b in Data.bait_order:
		if int(Data.bait[b]["cost"]) > 0:
			list.add_child(_bait_row(b))
	list.add_child(UIKit.label("Bait is used only when a fish is hooked. Worms are free.", 10, UIKit.MUTED))


func _bait_row(id: String) -> Control:
	var b: Dictionary = Data.bait[id]
	var p := UIKit.panel("DarkPanel")
	var h := UIKit.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	h.add_child(UIKit.icon(String(b["icon"]).replace("bait_", "")))
	var nv := UIKit.vbox(0)
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.add_child(UIKit.label(UIKit.T("%s   (owned: %d)") % [UIKit.T(b["name"]), Economy.bait_count(id)], 10, UIKit.GOLD))
	nv.add_child(UIKit.label(String(b["desc"]), 10, UIKit.MUTED))
	h.add_child(nv)
	var where := UIKit.T("Works in every pond.")
	if not (b["ponds"] as Array).is_empty():
		var names: Array[String] = []
		for pid in b["ponds"]:
			names.append(Data.pond_name(pid))
		where = UIKit.T("Works only in: %s") % ", ".join(names)
	HoverTip.attach(p, UIKit.T(b["name"]), UIKit.T(b["desc"]) + "\n" + where)
	var buy := UIKit.button(UIKit.T("x%d  %s") % [int(b["pack"]), UIKit.fmt_int(int(b["cost"]))], "coin", Economy.coins() >= int(b["cost"]))
	buy.disabled = Economy.coins() < int(b["cost"])
	buy.pressed.connect(func() -> void:
		if Economy.buy_bait(id):
			Audio.play("purchase")
			Economy.select_bait(id)
			_refresh())
	h.add_child(buy)
	var sel := UIKit.button("Use")
	sel.disabled = Economy.bait_count(id) == 0 or Economy.selected_bait() == id
	sel.pressed.connect(func() -> void:
		Economy.select_bait(id)
		_refresh())
	h.add_child(sel)
	return p


class Pips:
	extends Control
	var n := 0
	var total := 5

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in total:
			var r := Rect2(i * 5, 1, 4, 5)
			draw_rect(r, UIKit.DARK)
			draw_rect(r.grow(-1), Color("#ffd04a") if i < n else Color("#4a2b17"))


class RodPreview:
	extends Control
	## A tiny diagonal rod in the current tier's colours, so every upgrade is visible in the shop.
	var tier := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var t := Data.tier("rod", tier)
		var col := Color(String(t["color"]))
		var acc := Color(String(t["accent"]))
		for i in 20:
			var p := Vector2(1 + i, 20 - i)
			draw_rect(Rect2(p + Vector2(0, -1), Vector2(2, 2)), UIKit.DARK)
		for i in 19:
			var p := Vector2(2 + i, 19 - i)
			draw_rect(Rect2(p, Vector2.ONE), acc if i % 5 == 4 else col)
		draw_rect(Rect2(1, 17, 4, 4), Color("#c8955a") if tier < 3 else (Color("#4a2b17") if tier < 5 else (Color("#ecd2a0") if tier < 9 else Color("#ffd04a"))))
		draw_rect(Rect2(20, 0, 2, 2), acc)
