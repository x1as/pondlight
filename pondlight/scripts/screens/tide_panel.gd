class_name TidePanel
extends ModalPanel
## Tide of Fortune: ride a fresh catch's sale value on up to three waves (see TideModel).
## In-game coins only; nothing here can ever be bought with real money.

const SEG_COLORS := {0.0: Color("#7a1f2a"), 1.0: Color("#46607a"), 1.5: Color("#1f8a96"), 2.0: Color("#3aa23b"), 3.0: Color("#f2a531")}

var record: Dictionary
var model: TideModel
var _bar: WaveBar
var _pot_label: Label
var _wave_label: Label
var _hint: Label
var _btns: HBoxContainer
var _sweeping := true
var _settled := false


func _init() -> void:
	super._init()
	title = "Tide of Fortune"
	panel_size = Vector2(430, 196)


func setup(rec: Dictionary) -> TidePanel:
	record = rec
	model = TideModel.new().setup(int(rec["value"]), Economy.stats().gamble_bonus)
	return self


func _build() -> void:
	var top := UIKit.hbox(8)
	content.add_child(top)
	var card := UIKit.panel("ParchmentPanel")
	card.add_child(UIKit.fish_sprite(String(record["species"]), 1))
	top.add_child(card)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(v)
	v.add_child(UIKit.label(UIKit.T("Riding: %s") % Data.fish_name(String(record["species"])), 10, Data.rarity_color(int(record["rarity"]))))
	_pot_label = UIKit.label("", 20, UIKit.GOLD)
	v.add_child(_pot_label)
	_wave_label = UIKit.label("", 10, UIKit.CREAM)
	v.add_child(_wave_label)
	_bar = WaveBar.new()
	_bar.custom_minimum_size = Vector2(404, 30)
	_bar.model = model
	content.add_child(_bar)
	_hint = UIKit.label("", 10, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_hint)
	_btns = UIKit.hbox(6)
	_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(_btns)
	_show_sweep()


func _update_labels() -> void:
	_pot_label.text = UIKit.T("%s coins") % UIKit.fmt_int(model.pot)
	_wave_label.text = UIKit.T("Wave %d / %d    x%.1f so far") % [mini(model.wave + 1, model.rounds()), model.rounds(), model.total_mult()]


func _show_sweep() -> void:
	_sweeping = true
	_update_labels()
	_hint.text = UIKit.T("Stop the bobber on a good wave! It gets faster every wave.")
	clear(_btns)
	var stop := UIKit.button("STOP!", "wave", true)
	stop.set_min_width(120)
	stop.pressed.connect(_stop)
	_btns.add_child(stop)
	stop.grab_focus.call_deferred()


func _process(delta: float) -> void:
	if _sweeping and model != null:
		model.step(delta)
		_bar.queue_redraw()


func _stop() -> void:
	if not _sweeping:
		return
	_sweeping = false
	var before := model.pot
	var m := model.stop()
	_bar.flash_at(model.pos, m)
	_update_labels()
	clear(_btns)
	var st: Dictionary = Save.profile["stats"]
	if m <= 0.0:
		st["tides_lost"] = int(st.get("tides_lost", 0)) + 1
		Audio.play("escape")
		_shake()
		_hint.text = UIKit.T("The tide took it... (%s coins lost)") % UIKit.fmt_int(before)
		_pot_label.add_theme_color_override("font_color", UIKit.RED)
		_settle(0)
		var ok := UIKit.button("Close", "close")
		ok.pressed.connect(close)
		_btns.add_child(ok)
		ok.grab_focus.call_deferred()
		return
	Audio.play("catch_rare" if m >= 2.0 else "strike_good", 0.03, -2.0)
	if m > 1.0:
		Orders.on_tide_win()
	if m >= 3.0:
		_shake()
	_hint.text = UIKit.T("x%.1f!  The wave carries your fish higher.") % m if m > 1.0 else UIKit.T("x1 - the tide holds steady.")
	if model.done:
		var collect := UIKit.button(UIKit.T("Collect  +%s") % UIKit.fmt_int(model.pot), "coin", true)
		collect.pressed.connect(func() -> void:
			_cash_out()
			close())
		_btns.add_child(collect)
		collect.grab_focus.call_deferred()
		return
	var cash := UIKit.button(UIKit.T("Cash out  +%s") % UIKit.fmt_int(model.pot), "coin", true)
	cash.pressed.connect(func() -> void:
		_cash_out()
		close())
	_btns.add_child(cash)
	var ride := UIKit.button("Ride the next wave", "wave")
	ride.pressed.connect(_show_sweep)
	_btns.add_child(ride)
	cash.grab_focus.call_deferred()


func _cash_out() -> void:
	if _settled:
		return
	var st: Dictionary = Save.profile["stats"]
	st["tides_won"] = int(st.get("tides_won", 0)) + 1
	st["tide_best"] = maxf(float(st.get("tide_best", 0.0)), model.total_mult())
	Audio.play("sell")
	_settle(model.pot)


func _settle(amount: int) -> void:
	if _settled:
		return
	_settled = true
	Economy.sell_catch(record, amount)
	Achievements.check_all()


func _shake() -> void:
	if not Settings.screen_shake:
		return
	var p0 := frame.position
	var tw := create_tween()
	for i in 5:
		tw.tween_property(frame, "position", p0 + Vector2(randi_range(-3, 3), randi_range(-2, 2)), 0.03)
	tw.tween_property(frame, "position", p0, 0.04)


func close() -> void:
	# leaving mid-wave stops the bobber where it is; leaving between waves cashes out
	if not _settled:
		if _sweeping:
			_stop()
		if not _settled:
			_cash_out()
	super.close()


class WaveBar:
	extends Control
	var model: TideModel
	var _flash := 0.0
	var _flash_x := 0.0
	var _flash_c := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func flash_at(x: float, m: float) -> void:
		_flash = 1.0
		_flash_x = x
		_flash_c = TidePanel.SEG_COLORS.get(m, Color.WHITE)

	func _process(delta: float) -> void:
		if _flash > 0.0:
			_flash = maxf(0.0, _flash - delta * 2.0)
			queue_redraw()

	func _draw() -> void:
		if model == null:
			return
		var w := size.x
		var y0 := 8.0
		var h := 14.0
		draw_rect(Rect2(-1, y0 - 1, w + 2, h + 2), UIKit.DARK)
		var font := UIKit.font()
		for s in model.segments:
			var x0 := floorf(float(s["from"]) * w)
			var x1 := floorf(float(s["to"]) * w)
			var m := float(s["mult"])
			var c: Color = TidePanel.SEG_COLORS.get(m, Color.GRAY)
			draw_rect(Rect2(x0, y0, x1 - x0, h), c)
			draw_rect(Rect2(x0, y0, x1 - x0, 2), c.lightened(0.3))
			draw_rect(Rect2(x0, y0 + h - 2, x1 - x0, 2), c.darkened(0.3))
			draw_rect(Rect2(x1 - 1, y0, 1, h), UIKit.DARK)
			var txt := "x%s" % (str(int(m)) if m == floorf(m) else str(m))
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			if x1 - x0 > tw + 2:
				draw_string(font, Vector2(floorf((x0 + x1 - tw) / 2.0), y0 + 11), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIKit.CREAM)
		if _flash > 0.0:
			draw_rect(Rect2(floorf(_flash_x * w) - 6, y0 - 4, 12, h + 8), Color(_flash_c.lightened(0.5), _flash * 0.8))
		# the bobber
		var bx := floorf(model.pos * (w - 1))
		draw_rect(Rect2(bx - 2, 0, 5, 6), Color("#e2433a"))
		draw_rect(Rect2(bx - 2, 6, 5, 3), Color("#fff8ee"))
		draw_rect(Rect2(bx, -2, 1, 2), Color("#ffd84a"))
		draw_rect(Rect2(bx, 9, 1, h + 4), UIKit.DARK)
		draw_rect(Rect2(bx - 3, 0, 1, 9), UIKit.DARK)
		draw_rect(Rect2(bx + 3, 0, 1, 9), UIKit.DARK)
