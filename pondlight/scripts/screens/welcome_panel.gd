class_name WelcomePanel
extends ModalPanel
## Shown when the game is opened again: the fish traps filled while you were away.

var haul := 0
var _claimed := false


func _init() -> void:
	super._init()
	title = "Welcome back!"
	panel_size = Vector2(320, 160)


func _build() -> void:
	var row := UIKit.hbox(8)
	content.add_child(row)
	var chest := TextureRect.new()
	chest.texture = load("res://assets/art/spritecook/treasure_chest.png")
	chest.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	chest.custom_minimum_size = Vector2(40, 40)
	row.add_child(chest)
	var v := UIKit.vbox(2)
	row.add_child(v)
	v.add_child(UIKit.label("Your fish traps filled up while you were away:", 10, UIKit.CREAM))
	var amount := UIKit.label("0", 20, UIKit.GOLD)
	v.add_child(amount)
	var cap := float(Data.balance["traps"]["cap_hours"])
	v.add_child(UIKit.label(UIKit.T("Traps earn %s coins per hour (up to %d h)") % [UIKit.fmt_int(int(Economy.trap_rate())), int(cap)], 10, UIKit.MUTED))
	v.add_child(UIKit.label("Better gear and new waters fill them faster.", 10, UIKit.MUTED))
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_method(func(x: float) -> void: amount.text = UIKit.T("+%s coins") % UIKit.fmt_int(int(round(x))), 0.0, float(haul), 0.9).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	var b := UIKit.button(UIKit.T("Collect  +%s") % UIKit.fmt_int(haul), "coin", true)
	b.pressed.connect(close)
	var bh := UIKit.hbox(6)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_child(b)
	if Platform.ads_available():
		var ad := UIKit.button(UIKit.T("x2 for an ad  +%s") % UIKit.fmt_int(haul * 2), "star")
		ad.pressed.connect(func() -> void:
			ad.disabled = true
			if await Platform.show_rewarded():
				haul *= 2
				amount.text = UIKit.T("+%s coins") % UIKit.fmt_int(haul)
			close())
		bh.add_child(ad)
	content.add_child(bh)


func close() -> void:
	if not _claimed:
		_claimed = true
		Economy.claim_traps(haul)
		Audio.play("sell")
	super.close()
