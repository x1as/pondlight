class_name ModalPanel
extends Control
## Base for all centred menus: dim backdrop, wood frame with a title plaque,
## slide/fade transitions, ui_cancel to close and gamepad focus on open.

signal closed

var title := ""
var panel_size := Vector2(420, 260)
var content: VBoxContainer
var frame: PanelContainer
var close_button: Button
var _dim: ColorRect
var _closing := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UIKit.theme()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = Color(0.03, 0.06, 0.04, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	frame = UIKit.panel()
	frame.custom_minimum_size = panel_size
	frame.size = panel_size
	frame.position = ((Vector2(640, 360) - panel_size) * 0.5).floor()
	add_child(frame)
	var outer := UIKit.vbox(4)
	frame.add_child(outer)
	var head := UIKit.hbox(4)
	outer.add_child(head)
	var t := UIKit.label(title, 20, UIKit.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	close_button = UIKit.button("", "close")
	close_button.tooltip_text = "Close"
	close_button.pressed.connect(close)
	head.add_child(close_button)
	content = UIKit.vbox(4)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(content)
	_build()
	# open transition
	Audio.play("ui_open", 0.05, -3.0)
	var target_y := frame.position.y
	frame.position.y += 14
	frame.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.55, 0.16)
	tw.tween_property(frame, "position:y", target_y, 0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(frame, "modulate:a", 1.0, 0.14)
	focus_first.call_deferred()
	_recenter.call_deferred()


func _recenter() -> void:
	## Panels can grow with their content (e.g. longer translations): keep them centred on screen.
	## Containers never shrink on their own, so the frame is first reset to its real minimum size.
	frame.size = Vector2.ZERO
	frame.size = frame.get_combined_minimum_size().max(panel_size)
	var target := ((Vector2(640, 360) - frame.size) * 0.5).floor()
	target.x = maxf(0.0, target.x)
	target.y = maxf(0.0, target.y)
	frame.position.x = target.x
	if not _closing:
		create_tween().tween_property(frame, "position:y", target.y, 0.12)


func _build() -> void:
	pass


func focus_first() -> void:
	var b := _find_focusable(content)
	if b != null:
		b.grab_focus()
	elif close_button:
		close_button.grab_focus()


func _find_focusable(n: Node) -> Control:
	for c in n.get_children():
		if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL and (c as Control).is_visible_in_tree():
			if c is BaseButton and (c as BaseButton).disabled:
				continue
			return c
		var r := _find_focusable(c)
		if r != null:
			return r
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("fish_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	Audio.play("ui_close", 0.05, -4.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.0, 0.12)
	tw.tween_property(frame, "position:y", frame.position.y + 10, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_property(frame, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(func() -> void:
		closed.emit()
		queue_free())


func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
