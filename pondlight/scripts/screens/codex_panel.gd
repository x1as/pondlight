class_name CodexPanel
extends ModalPanel
## Fish Codex: every species per pond, silhouettes for undiscovered fish, rarity collection,
## records, mastery and the rarity odds that mastery currently gives.

const PHASE_NAMES := {"morning": "Morning", "day": "Day", "evening": "Evening", "night": "Night"}

var _pond := "willow"
var _selected := ""
var _list: GridContainer
var _detail: VBoxContainer
var _header: Label
var _pond_buttons: Dictionary = {}


func _init() -> void:
	super._init()
	title = "Fish Codex"
	panel_size = Vector2(520, 318)


func _build() -> void:
	_pond = String(Save.profile["current_pond"])
	var top := UIKit.hbox(4)
	for pid in Data.pond_order:
		var b := UIKit.button(Data.pond_name(pid))
		var key: String = pid
		b.pressed.connect(func() -> void:
			_pond = key
			_selected = ""
			_refresh())
		top.add_child(b)
		_pond_buttons[pid] = b
	content.add_child(top)
	_header = UIKit.label("", 10, UIKit.GOLD)
	content.add_child(_header)
	var row := UIKit.hbox(6)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	_list = GridContainer.new()
	_list.columns = 2
	_list.add_theme_constant_override("h_separation", 3)
	_list.add_theme_constant_override("v_separation", 3)
	row.add_child(_list)
	var page := UIKit.panel("ParchmentPanel")
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(page)
	_detail = UIKit.vbox(2)
	page.add_child(_detail)
	_refresh()


func _refresh() -> void:
	var comp := Progression.completion()
	_header.text = UIKit.T("Collection %d%%  -  %d/%d species") % [comp["percent"], comp["species"], comp["total_species"]]
	for pid in _pond_buttons.keys():
		(_pond_buttons[pid] as Button).theme_type_variation = "PrimaryButton" if pid == _pond else ""
	clear(_list)
	var first := ""
	for id in Data.species_of(_pond):
		if first == "":
			first = id
		_list.add_child(_species_button(id))
	if _selected == "":
		_selected = first
	_show(_selected)
	_recenter.call_deferred()


func _species_button(id: String) -> Button:
	var known := Progression.is_discovered(id)
	var b := UIKit.button("")
	b.set_min_size(Vector2(84, 40))
	b.toggle_mode = false
	var v := UIKit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size = Vector2(84, 40)
	b.resized.connect(func() -> void: v.size = b.size)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var spr := UIKit.fish_sprite(id, 1, not known)
	spr.custom_minimum_size = Vector2(76, 22)
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spr)
	var l := UIKit.label(Data.fish_name(id) if known else "???", 10, UIKit.CREAM if known else UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.add_child(v)
	if id == _selected:
		b.theme_type_variation = "PrimaryButton"
	b.pressed.connect(func() -> void:
		_selected = id
		_refresh())
	b.focus_entered.connect(func() -> void:
		if Settings.using_gamepad and _selected != id:
			_selected = id
			_show(id))
	return b


func _line(k: String, v: String, color: Color = UIKit.PARCH_TEXT) -> HBoxContainer:
	var h := UIKit.hbox(3)
	var kl := UIKit.label(k, 10, Color("#74492a"))
	kl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	kl.custom_minimum_size.x = 52
	h.add_child(kl)
	var vl := UIKit.label(v, 10, color)
	vl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vl.custom_minimum_size.x = 196
	h.add_child(vl)
	return h


func _show(id: String) -> void:
	clear(_detail)
	if id == "":
		return
	var f: Dictionary = Data.fish[id]
	var known := Progression.is_discovered(id)
	var head := UIKit.hbox(6)
	var spr := UIKit.fish_sprite(id, 2 if UIKit.fish_tex(id).get_width() <= 54 else 1, not known)
	if known and int(Progression.entry(id).get("prismatic", 0)) > 0:
		UIKit.make_prismatic(spr)
	head.add_child(spr)
	var hv := UIKit.vbox(1)
	var name_l := UIKit.label(Data.fish_name(id) if known else "Undiscovered", 20, UIKit.PARCH_TEXT)
	name_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	hv.add_child(name_l)
	var gems := UIKit.hbox(2)
	var e := Progression.entry(id) if known else {}
	for r in RarityTable.COUNT:
		var g := UIKit.gem(r)
		if not known or int((e["rarities"] as Array)[r]) == 0:
			g.modulate = Color(0.2, 0.2, 0.2, 0.55)
		g.tooltip_text = UIKit.T("%s: %d") % [Data.rarity_name(r), int((e["rarities"] as Array)[r]) if known else 0]
		g.mouse_filter = Control.MOUSE_FILTER_PASS
		gems.add_child(g)
	if known and int(Progression.entry(id).get("prismatic", 0)) > 0:
		gems.add_child(UIKit.label(UIKit.T("Prismatic x%d") % int(Progression.entry(id)["prismatic"]), 10, Color("#4f8ab6")))
	hv.add_child(gems)
	head.add_child(hv)
	_detail.add_child(head)
	var desc := UIKit.label(String(f["desc"]) if known else "Catch this fish to fill in its page.", 10, Color("#56361f"))
	desc.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 250
	_detail.add_child(desc)
	_detail.add_child(_line("Hint", String(f["hint"]), Color("#1f6a31")))
	_detail.add_child(_line("Best spots", _best_spots(f)))
	_detail.add_child(_line("Active", _best_key(f["time"], PHASE_NAMES)))
	var mi := FightModel.match_info(Economy.stats(), f, 0)
	var ml := FightModel.match_info(Economy.stats(), f, 4)
	_detail.add_child(_line("Power", UIKit.T("%d (legendary %d)   you: %s / %s") % [int(f["fight"]["power"]),
		int(round(FightModel.power_of(f, 4))), UIKit.T(String(mi[0])), UIKit.T(String(ml[0]))], mi[1].darkened(0.45)))
	if known:
		_detail.add_child(_line("Record", UIKit.T("%s   caught %d   best %s c") % [UIKit.fmt_weight(float(e["record"])), int(e["caught"]), UIKit.fmt_int(int(e["best_value"]))]))
		var lv := int(e["level"])
		var xp_txt := "MAX" if lv >= Progression.max_level() else UIKit.T("%d/%d XP") % [int(e["xp"]), Progression.xp_needed(lv)]
		_detail.add_child(_line("Mastery", UIKit.T("Lv %d/%d   %s") % [lv, Progression.max_level(), xp_txt], Color("#165a78")))
		var base := RarityTable.weights(lv, 0.0)
		var luck := Economy.stats().luck
		var adj := RarityTable.weights(lv, luck)
		var odds := ""
		for r in RarityTable.COUNT:
			odds += UIKit.T("%s %s%%  ") % [Data.rarity_name(r).substr(0, 1), _pct(base[r])]
		_detail.add_child(_line("Rarity", odds, Color("#165a78")))
		if luck > 0.0 and absf(adj[4] - base[4]) + absf(adj[0] - base[0]) > 0.0005:
			var o2 := ""
			for r in RarityTable.COUNT:
				o2 += UIKit.T("%s %s%%  ") % [Data.rarity_name(r).substr(0, 1), _pct(adj[r])]
			_detail.add_child(_line("With Luck", o2, Color("#1f6a31")))
	else:
		_detail.add_child(_line("Weight", UIKit.T("%s - %s") % [UIKit.fmt_weight(float(f["min_weight"])), UIKit.fmt_weight(float(f["max_weight"]))]))


func _pct(v: float) -> String:
	var p := v * 100.0
	if p > 0.0 and p < 1.0:
		return UIKit.T("%.1f") % p
	return str(int(round(p)))


func _best_spots(f: Dictionary) -> String:
	var spots: Dictionary = f["spots"]
	var keys := spots.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return float(spots[a]) > float(spots[b]))
	var names: Array[String] = []
	for k in keys.slice(0, 2):
		names.append(Data.spot_name(k))
	return ", ".join(names)


func _best_key(d: Dictionary, names: Dictionary) -> String:
	var best := ""
	var bv := -1.0
	for k in d.keys():
		if float(d[k]) > bv:
			bv = float(d[k])
			best = k
	return String(names.get(best, best))
