class_name HoverTip
extends PanelContainer
## Instant wood-and-parchment tooltip: shown while the mouse is over (or gamepad focus is on) a control.
## One shared instance lives on its own top CanvasLayer so it draws above every menu.

static var _tip: HoverTip
static var _owner_id := 0
var _title: Label
var _body: Label


static func attach(target: Control, title: String, body: String) -> void:
	target.mouse_filter = Control.MOUSE_FILTER_STOP if target.mouse_filter == Control.MOUSE_FILTER_IGNORE else target.mouse_filter
	var show := func() -> void: _show(target, title, body)
	var hide := func() -> void: _hide(target)
	target.mouse_entered.connect(show)
	target.focus_entered.connect(show)
	target.mouse_exited.connect(hide)
	target.focus_exited.connect(hide)
	target.tree_exiting.connect(hide)


static func _ensure(target: Control) -> HoverTip:
	if _tip != null and is_instance_valid(_tip):
		return _tip
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	target.get_tree().root.add_child(layer)
	_tip = HoverTip.new()
	layer.add_child(_tip)
	return _tip


func _init() -> void:
	theme = UIKit.theme()
	theme_type_variation = "DarkPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var v := UIKit.vbox(1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_title = UIKit.label("", 10, UIKit.GOLD)
	v.add_child(_title)
	_body = UIKit.label("", 10, UIKit.CREAM)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = 196
	v.add_child(_body)


static func _show(target: Control, title: String, body: String) -> void:
	if not target.is_inside_tree() or not target.is_visible_in_tree():
		return
	var t := _ensure(target)
	_owner_id = target.get_instance_id()
	t._title.text = UIKit.T(title)
	t._body.text = UIKit.T(body)
	t.visible = true
	t.reset_size()
	var r := target.get_global_rect()
	var pos := Vector2(r.position.x, r.end.y + 3)
	if pos.y + t.size.y > 356:
		pos.y = r.position.y - t.size.y - 3
	pos.x = clampf(pos.x, 4, 636 - t.size.x)
	pos.y = clampf(pos.y, 4, 356 - t.size.y)
	t.position = pos.floor()


static func _hide(target: Control) -> void:
	if _tip != null and is_instance_valid(_tip) and _owner_id == target.get_instance_id():
		_tip.visible = false
		_owner_id = 0
