class_name Toasts
extends Control
## Small wooden notification plaques that slide in at the top centre, plus big banners.

var _stack: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UIKit.theme()
	_stack = UIKit.vbox(3)
	_stack.position = Vector2(0, 40)
	_stack.size = Vector2(640, 0)
	_stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack)


func toast(text: String, icon_name: String = "", color: Color = UIKit.CREAM, duration: float = 2.4) -> void:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := UIKit.panel("DarkPanel")
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UIKit.hbox(4)
	if icon_name != "":
		h.add_child(UIKit.icon(icon_name))
	h.add_child(UIKit.label(text, 10, color))
	p.add_child(h)
	holder.add_child(p)
	_stack.add_child(holder)
	if _stack.get_child_count() > 4:
		_stack.get_child(0).queue_free()
	holder.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(holder, "modulate:a", 1.0, 0.15)
	tw.tween_interval(duration)
	tw.tween_property(holder, "modulate:a", 0.0, 0.3)
	tw.tween_callback(holder.queue_free)


func banner(title: String, subtitle: String, color: Color = UIKit.GOLD) -> void:
	## Big centred celebration banner (discoveries, unlocks).
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var p := UIKit.panel("HeaderPanel")
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(2)
	v.add_child(UIKit.label(title, 20, color, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label(subtitle, 10, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	p.add_child(v)
	holder.add_child(p)
	holder.modulate.a = 0.0
	holder.position.y = -60
	var tw := create_tween()
	tw.tween_property(holder, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(holder, "position:y", -80.0, 0.35).from(-60.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(holder, "modulate:a", 0.0, 0.4)
	tw.tween_callback(holder.queue_free)
