class_name FightPanel
extends PanelContainer
## Dedicated fight interface: timing bar, catch progress, line tension, fish state, timer, combo.

const STATE_TEXT := {
	"calm": ["CALM - reel steadily", Color("#bdf06a")],
	"struggle": ["STRUGGLING - tap in the zone", Color("#ffd04a")],
	"surge": ["SURGE! let go of the line!", Color("#ff6f5a")],
	"recovery": ["TIRED - reel it in!", Color("#7fdcc2")],
	"final_burst": ["FINAL BURST!", Color("#c983ff")],
	"telegraph": ["It's gathering strength...", Color("#ff9a3c")],
}

var timing: TimingBar
var progress_bar: ProgressBar
var tension_bar: ProgressBar
var state_label: Label
var combo_label: Label
var time_label: Label
var title_label: Label
var gem_rect: TextureRect
var match_label: Label
var _tension_fill_gold: StyleBox
var _tension_fill_red: StyleBox
var _shown_progress := 0.0
var _shown_tension := 0.0


func _init() -> void:
	theme_type_variation = "PlainPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var v := UIKit.vbox(1)
	add_child(v)
	var head := UIKit.hbox(4)
	gem_rect = UIKit.gem(0)
	head.add_child(gem_rect)
	title_label = UIKit.label("A fish!", 10)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	match_label = UIKit.label("", 10)
	head.add_child(match_label)
	head.add_child(UIKit.icon("sun"))
	time_label = UIKit.label("30s", 10, UIKit.CREAM)
	time_label.custom_minimum_size.x = 22
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(time_label)
	v.add_child(head)
	timing = TimingBar.new()
	timing.custom_minimum_size = Vector2(236, 16)
	v.add_child(timing)
	var r1 := UIKit.hbox(3)
	r1.add_child(UIKit.icon("fish"))
	progress_bar = UIKit.bar("green", 98, 8)
	progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r1.add_child(progress_bar)
	r1.add_child(UIKit.icon("line"))
	tension_bar = UIKit.bar("gold", 98, 8)
	tension_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r1.add_child(tension_bar)
	v.add_child(r1)
	_tension_fill_gold = tension_bar.get_theme_stylebox("fill")
	_tension_fill_red = UIKit._fill("red")
	var r3 := UIKit.hbox(3)
	state_label = UIKit.label("", 10)
	state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r3.add_child(state_label)
	combo_label = UIKit.label("", 10, UIKit.GOLD)
	r3.add_child(combo_label)
	v.add_child(r3)


func begin(rarity: int, species_name: String, match: Array = []) -> void:
	## match = FightModel.match_info(): how your gear compares with this fish.
	gem_rect.texture = UIKit.gem_tex(rarity)
	match_label.text = UIKit.T(String(match[0])) if not match.is_empty() else ""
	if not match.is_empty():
		match_label.add_theme_color_override("font_color", match[1])
	title_label.text = UIKit.T("%s  %s") % [Data.rarity_name(rarity), species_name]
	title_label.add_theme_color_override("font_color", Data.rarity_color(rarity))
	_shown_progress = 0.0
	_shown_tension = 0.0
	combo_label.text = ""


func update_from(m: FightModel, delta: float) -> void:
	_shown_progress = lerpf(_shown_progress, m.progress / 100.0, minf(1.0, delta * 14.0))
	_shown_tension = lerpf(_shown_tension, m.tension_ratio(), minf(1.0, delta * 16.0))
	progress_bar.value = _shown_progress
	tension_bar.value = _shown_tension
	var danger := m.tension_ratio() > 0.75
	tension_bar.add_theme_stylebox_override("fill", _tension_fill_red if danger else _tension_fill_gold)
	time_label.text = UIKit.T("%ds") % int(ceil(m.time_left))
	time_label.add_theme_color_override("font_color", UIKit.RED if m.time_left < 6.0 else UIKit.CREAM)
	var key := "telegraph" if m.telegraph > 0.0 else m.state
	var st: Array = STATE_TEXT.get(key, ["", UIKit.CREAM])
	state_label.text = UIKit.T(st[0])
	state_label.add_theme_color_override("font_color", st[1])
	combo_label.text = (UIKit.T("x%d") % m.combo) if m.combo >= 2 else ""
	timing.marker = m.marker
	timing.zone_center = m.zone_center
	timing.zone_half = m.zone_half
	timing.perfect_half = m.perfect_half()
	timing.surge = m.state == "surge" or m.state == "final_burst"


func flash(perfect: bool, hit: bool) -> void:
	timing.flash(perfect, hit)


class TimingBar:
	extends Control
	var marker := 0.5
	var zone_center := 0.5
	var zone_half := 0.12
	var perfect_half := 0.03
	var surge := false
	var _flash := 0.0
	var _flash_col := Color.WHITE
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(200, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func flash(perfect: bool, hit: bool) -> void:
		_flash = 0.22
		_flash_col = Color("#fff0a0") if perfect else (Color("#bdf06a") if hit else Color("#ff6f5a"))
		if Settings.reduced_flashing:
			_flash = 0.1

	func _process(delta: float) -> void:
		_t += delta
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()

	func _draw() -> void:
		var w := size.x - 4.0
		var x0 := 2.0
		var y0 := 3.0
		var h := 10.0
		draw_rect(Rect2(x0 - 2, y0 - 2, w + 4, h + 4), Color("#120c08"))
		draw_rect(Rect2(x0 - 1, y0 - 1, w + 2, h + 2), Color("#4a2b17"))
		draw_rect(Rect2(x0, y0, w, h), Color("#e3cc98") if not surge else Color("#d9a08a"))
		for i in range(1, 10):
			draw_rect(Rect2(floorf(x0 + w * i / 10.0), y0 + h - 2, 1, 2), Color("#c7a670"))
		var za := floorf(x0 + w * (zone_center - zone_half))
		var zb := floorf(x0 + w * (zone_center + zone_half))
		var zc := Color("#56c043")
		draw_rect(Rect2(za, y0, zb - za, h), zc)
		draw_rect(Rect2(za, y0, zb - za, 1), Color("#bdf06a"))
		draw_rect(Rect2(za, y0 + h - 1, zb - za, 1), Color("#2a8536"))
		var pa := floorf(x0 + w * (zone_center - perfect_half))
		var pb := ceilf(x0 + w * (zone_center + perfect_half))
		draw_rect(Rect2(pa, y0, maxf(2.0, pb - pa), h), Color("#ffd04a"))
		draw_rect(Rect2(pa, y0, maxf(2.0, pb - pa), 1), Color("#fff0a0"))
		if _flash > 0.0:
			var c := _flash_col
			c.a = _flash * 3.0
			draw_rect(Rect2(za - 1, y0 - 1, zb - za + 2, h + 2), c, false)
			draw_rect(Rect2(x0, y0, w, h), Color(c, _flash * 1.2))
		var nx := floorf(x0 + w * marker)
		draw_rect(Rect2(nx - 2, y0 - 3, 5, h + 6), Color("#120c08"))
		draw_rect(Rect2(nx - 1, y0 - 2, 3, h + 4), Color("#fff6dc"))
		draw_rect(Rect2(nx, y0 - 2, 1, h + 4), Color.WHITE)
