class_name TrophyPanel
extends ModalPanel
## Trophy cabinet: 25 trophies (bronze / silver / gold) on wooden shelves, and the grand
## platinum trophy that is awarded for collecting all of them.

const SC := "res://assets/art/spritecook/"

var _detail_name: Label
var _detail_desc: Label


func _init() -> void:
	super._init()
	title = "Trophy Cabinet"
	panel_size = Vector2(450, 296)


static func trophy_tex(tier: String, big := false) -> Texture2D:
	var path := SC + "trophy_%s%s.png" % [tier, "_big" if big else ""]
	if ResourceLoader.exists(path):
		return load(path)
	return UIKit.icon_tex("trophy")


func _build() -> void:
	var row := UIKit.hbox(8)
	content.add_child(row)
	# --- left: the grand trophy and the detail plate
	var left := UIKit.vbox(4)
	left.custom_minimum_size.x = 132
	row.add_child(left)
	var grand_def: Dictionary = Achievements.def("PONDLIGHT_MASTER")
	var have := Achievements.trophy_count()
	var got_grand := Achievements.is_unlocked("PONDLIGHT_MASTER")
	var plate := UIKit.panel("ParchmentPanel")
	var pv := UIKit.vbox(2)
	plate.add_child(pv)
	var cup := TextureRect.new()
	cup.texture = trophy_tex("platinum", true)
	cup.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	cup.custom_minimum_size = Vector2(118, 52)
	if not got_grand:
		cup.modulate = Color(0.12, 0.14, 0.16, 0.8)
	pv.add_child(cup)
	var gname := UIKit.label(String(grand_def.get("name", "")), 10, UIKit.PARCH_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	gname.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	pv.add_child(gname)
	var bar := UIKit.bar("gold", 110, 8)
	bar.value = float(have) / 25.0
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pv.add_child(bar)
	var cnt := UIKit.label(UIKit.T("%d / %d trophies") % [have, 25], 10, Color("#56361f"), HORIZONTAL_ALIGNMENT_CENTER)
	cnt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	pv.add_child(cnt)
	left.add_child(plate)
	var info := UIKit.panel("DarkPanel")
	info.custom_minimum_size = Vector2(132, 70)
	var iv := UIKit.vbox(2)
	info.add_child(iv)
	_detail_name = UIKit.label("Hover a trophy", 10, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_name.custom_minimum_size.x = 120
	iv.add_child(_detail_name)
	_detail_desc = UIKit.label("", 10, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.custom_minimum_size.x = 120
	iv.add_child(_detail_desc)
	left.add_child(info)
	# --- right: shelves
	var shelf := UIKit.panel("DarkPanel")
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(shelf)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	shelf.add_child(grid)
	for a in Data.achievements:
		if String(a["type"]) == "all":
			continue
		grid.add_child(_slot(a))


func _slot(a: Dictionary) -> Control:
	var got := Achievements.is_unlocked(String(a["id"]))
	var b := UIKit.button("")
	b.set_min_size(Vector2(50, 40))
	var cup := TextureRect.new()
	cup.texture = trophy_tex(String(a.get("tier", "bronze")))
	cup.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	cup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cup.size = Vector2(50, 40)
	b.resized.connect(func() -> void: cup.size = b.size)
	if not got:
		cup.modulate = Color(0.1, 0.08, 0.06, 0.75)
	b.add_child(cup)
	if got:
		b.theme_type_variation = "PrimaryButton"
	var show := func() -> void:
		var tier := UIKit.T(String(a.get("tier", "bronze")).capitalize())
		_detail_name.text = "%s  (%s)" % [UIKit.T(a["name"]), tier]
		_detail_desc.text = UIKit.T(a["desc"]) + ("" if got else "\n" + UIKit.T("Not yet earned"))
	b.mouse_entered.connect(show)
	b.focus_entered.connect(show)
	return b
