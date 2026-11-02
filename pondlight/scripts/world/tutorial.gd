class_name Tutorial
extends Control
## Hand-held first session: Old Croak (the frog guide) walks a new player through one
## complete catch, then points at the Shop and steps aside. Skippable at any time.

signal finished

var controller: FishingController
var hud: Hud
var game: Node
var step := ""
var _bubble: PanelContainer
var _text: Label
var _next: UIButton
var _skip: UIButton
var _arrow_target := Vector2(-1, -1)
var _t := 0.0


func start(g: Node, c: FishingController, h: Hud) -> void:
	game = g
	controller = c
	hud = h
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UIKit.theme()
	_build()
	controller.tutorial_active = true
	controller.tutorial_cell = _pick_cell()
	controller.tutorial_event.connect(_on_event)
	_go("intro")


func _build() -> void:
	_bubble = UIKit.panel("PlainPanel")
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bubble)
	var h := UIKit.hbox(6)
	_bubble.add_child(h)
	var frog := TextureRect.new()
	var path := "res://assets/art/spritecook/frog_guide.png"
	frog.texture = load(path) if ResourceLoader.exists(path) else UIKit.icon_tex("fish")
	frog.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	frog.custom_minimum_size = Vector2(42, 42)
	frog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(frog)
	var v := UIKit.vbox(3)
	h.add_child(v)
	_text = UIKit.label("", 10)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(250, 0)
	v.add_child(_text)
	var row := UIKit.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_END
	_skip = UIKit.button("Skip tutorial")
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.pressed.connect(finish)
	row.add_child(_skip)
	_next = UIKit.button("Let's go!", "check", true)
	_next.focus_mode = Control.FOCUS_NONE
	_next.pressed.connect(_on_next)
	row.add_child(_next)
	v.add_child(row)


func _pick_cell() -> Vector2i:
	## The easiest spot: a reachable open-water cell closest to the dock.
	var pond := controller.pond
	var dock := Vector2(Data.ponds[pond.pond_id]["dock_tip"][0], Data.ponds[pond.pond_id]["dock_tip"][1])
	var best := Vector2i(-1, -1)
	var best_d := 1e9
	var reach := Economy.stats().reach
	for c in Data.fishable_cells(pond.pond_id):
		if not pond.is_reachable(c, reach):
			continue
		var d := pond.cell_center(c).distance_to(dock)
		if Data.spot_at(pond.pond_id, c) in ["~", "p", "o"]:
			d -= 20.0
		if d < best_d:
			best_d = d
			best = c
	return best


func _say(text: String, next_label: String = "") -> void:
	var a := Settings.prompt("fish_action")
	_text.text = UIKit.T(text).replace("{a}", a)
	_next.visible = next_label != ""
	if next_label != "":
		_next.caption = next_label
	_bubble.reset_size()
	_bubble.position = Vector2(floorf((640 - _bubble.size.x) / 2.0), 300 if step == "shop_open" else 22)
	_bubble.modulate.a = 0.0
	create_tween().tween_property(_bubble, "modulate:a", 1.0, 0.18)
	Audio.play("ui_open", 0.1, -8.0)


func _go(s: String) -> void:
	step = s
	_arrow_target = Vector2(-1, -1)
	match s:
		"intro":
			controller.enabled = false
			_say("Hello, I'm Old Croak! Let's catch your very first fish together.", "Let's go!")
		"hover":
			controller.enabled = true
			_arrow_target = controller.pond.cell_rect(controller.tutorial_cell).get_center() + Vector2(0, -10)
			_say("Every patch of water hides different fish. Point at the glowing spot.")
		"cast":
			_arrow_target = controller.pond.cell_rect(controller.tutorial_cell).get_center() + Vector2(0, -10)
			_say("Hold {a} to charge, and let go when the needle is in the GREEN zone.")
		"wait":
			_say("Now wait... When the bobber DIVES - press {a} right away!")
		"fight":
			_say("Tap {a} when the needle is in the green zone. Hold to reel. Let go when the fish SURGES!")
		"retry":
			_arrow_target = controller.pond.cell_rect(controller.tutorial_cell).get_center() + Vector2(0, -10)
			_say("So close! Fish are slippery. Cast again - you've got this.")
		"result":
			_bubble.visible = false
		"shop":
			_bubble.visible = true
			var b: Control = hud.menu_buttons[0]
			_arrow_target = b.global_position + Vector2(b.size.x / 2.0, -4)
			_say("Wonderful catch! Coins buy better gear. Open the Shop.")
		"shop_open":
			_say("Upgrade your rod here, and learn Talents to speed everything up. The pond is yours now!", "Got it!")


func _on_next() -> void:
	match step:
		"intro":
			_go("hover")
		"shop_open":
			finish()


func _on_event(name: String) -> void:
	match name:
		"hover":
			if step == "hover":
				_go("cast")
		"landed":
			if step in ["hover", "cast", "retry"]:
				_go("wait")
		"fight":
			_go("fight")
		"failed":
			_go("retry")
		"caught":
			_go("result")


func result_closed() -> void:
	if step == "result":
		controller.tutorial_active = false
		_go("shop")


func panel_opened(name: String) -> void:
	if step == "shop" and name == "shop":
		_go("shop_open")


func finish() -> void:
	controller.tutorial_active = false
	controller.enabled = true
	Save.profile["tutorial_done"] = true
	Save.save_game()
	hud.refresh_orders()
	finished.emit()
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _arrow_target.x < 0:
		return
	# bouncing pixel arrow pointing down at the target
	var bob := roundf(sin(_t * 6.0) * 2.0)
	var tip := (_arrow_target + Vector2(0, bob)).floor()
	var ink := Color(0.07, 0.04, 0.03)
	var gold := Color("#ffd04a")
	for i in 6:
		var w := 6 - i
		draw_rect(Rect2(tip + Vector2(-w - 1, -i - 1), Vector2(w * 2 + 3, 1)), ink)
		draw_rect(Rect2(tip + Vector2(-w, -i - 1), Vector2(w * 2 + 1, 1)), gold)
	draw_rect(Rect2(tip + Vector2(-3, -14), Vector2(7, 8)), ink)
	draw_rect(Rect2(tip + Vector2(-2, -13), Vector2(5, 7)), gold)
	draw_rect(Rect2(tip + Vector2(-2, -13), Vector2(1, 6)), Color("#fff0a0"))
