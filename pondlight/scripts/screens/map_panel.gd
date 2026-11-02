class_name MapPanel
extends ModalPanel
## Pond selection and the pond unlock screen (requirements, progress, purchase).

signal travel(pond_id: String)
signal pond_unlocked(pond_id: String)

var _cards: GridContainer


func _init() -> void:
	super._init()
	title = "Fishing Spots"
	panel_size = Vector2(560, 300)


func _build() -> void:
	_cards = GridContainer.new()
	_cards.columns = 2
	_cards.add_theme_constant_override("h_separation", 6)
	_cards.add_theme_constant_override("v_separation", 6)
	content.add_child(_cards)
	_refresh()


func _refresh() -> void:
	clear(_cards)
	for pid in Data.pond_order:
		_cards.add_child(_card(pid))


func _card(pid: String) -> Control:
	var pond: Dictionary = Data.ponds[pid]
	var st := Economy.unlock_status(pid)
	var unlocked := bool(st["unlocked"])
	var p := UIKit.panel("DarkPanel")
	p.custom_minimum_size = Vector2(266, 118)
	var row := UIKit.hbox(5)
	p.add_child(row)
	var thumb := TextureRect.new()
	thumb.texture = load("res://assets/art/world/%s/thumb.png" % pid)
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	thumb.custom_minimum_size = Vector2(128, 64)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not unlocked:
		thumb.modulate = Color(0.45, 0.5, 0.6)
	row.add_child(thumb)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UIKit.label(Data.pond_name(pid), 10, UIKit.GOLD))
	var sub := UIKit.label(String(pond["subtitle"]), 10, UIKit.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size.x = 124
	v.add_child(sub)
	var n := Progression.discovered_count(pid)
	v.add_child(UIKit.label(UIKit.T("Species: %d / %d") % [n, Data.species_of(pid).size()], 10, UIKit.CREAM))
	if unlocked:
		var here := String(Save.profile["current_pond"]) == pid
		var b := UIKit.button("You are here" if here else "Travel", "map", not here)
		b.disabled = here
		b.pressed.connect(func() -> void:
			travel.emit(pid)
			close())
		v.add_child(b)
	else:
		var src := Data.pond_name(st["source"])
		v.add_child(_req(UIKit.T("All %s fish (%d/%d)") % [src, st["have_species"], st["need_species"]], st["species_ok"]))
		v.add_child(_req(UIKit.T("%s coins") % UIKit.fmt_int(int(st["cost"])), st["coins_ok"]))
		var b2 := UIKit.button(UIKit.T("Unlock  %s") % UIKit.fmt_int(int(st["cost"])), "lock", bool(st["ok"]))
		b2.disabled = not bool(st["ok"])
		b2.pressed.connect(func() -> void:
			if Economy.unlock_pond(pid):
				Audio.play("unlock")
				pond_unlocked.emit(pid)
				_refresh()
				focus_first.call_deferred())
		v.add_child(b2)
	return p


func _req(text: String, ok: bool) -> HBoxContainer:
	var h := UIKit.hbox(3)
	h.add_child(UIKit.icon("check" if ok else "close"))
	var l := UIKit.label(text, 10, UIKit.GREEN if ok else UIKit.CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 108
	h.add_child(l)
	return h
