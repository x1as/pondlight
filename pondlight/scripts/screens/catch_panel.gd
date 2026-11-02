class_name CatchPanel
extends ModalPanel
## Fish catch result: reveal, rarity, weight, value, record / discovery / mastery flags, treasure.
## The fish is sold on the spot - or its value rides the Tide of Fortune (go_tide).

var record: Dictionary
var flags: Dictionary
var _resolved := false
var go_tide := false
var tide_allowed := true
var _sparkle: Sparkles


func _init() -> void:
	super._init()
	panel_size = Vector2(400, 200)


func setup(rec: Dictionary, f: Dictionary) -> CatchPanel:
	record = rec
	flags = f
	var r := int(rec["rarity"])
	title = "New Species!" if f.get("new_species", false) else (UIKit.T("%s Catch!") % Data.rarity_name(r))
	if bool(rec.get("prismatic", false)):
		title = "Prismatic Catch!"
	return self


func _build() -> void:
	var species: Dictionary = Data.fish[record["species"]]
	var r := int(record["rarity"])
	var rc := Data.rarity_color(r)
	var row := UIKit.hbox(8)
	content.add_child(row)
	# --- left: the fish on parchment
	var card := UIKit.panel("ParchmentPanel")
	card.custom_minimum_size = Vector2(150, 108)
	row.add_child(card)
	var cv := UIKit.vbox(2)
	card.add_child(cv)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(138, 78)
	cv.add_child(stage)
	_sparkle = Sparkles.new()
	_sparkle.color = rc
	_sparkle.amount = 4 + r * 4
	_sparkle.size = Vector2(138, 78)
	stage.add_child(_sparkle)
	var fish := UIKit.fish_sprite(record["species"], 2)
	var fsz := fish.custom_minimum_size
	if fsz.x > 136 or fsz.y > 78:
		fish.custom_minimum_size = fsz * 0.5
		fsz = fish.custom_minimum_size
	fish.size = fsz
	fish.position = ((Vector2(138, 78) - fsz) * 0.5).floor()
	stage.add_child(fish)
	if bool(record.get("prismatic", false)):
		UIKit.make_prismatic(fish)
		_sparkle.color = Color("#bdf6ff")
	var target_y := fish.position.y
	fish.position.y += 10
	fish.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(fish, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(fish, "position:y", target_y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rh := UIKit.hbox(3)
	rh.alignment = BoxContainer.ALIGNMENT_CENTER
	rh.add_child(UIKit.gem(r))
	rh.add_child(UIKit.label(Data.rarity_name(r).to_upper(), 10, rc.darkened(0.35)))
	cv.add_child(rh)
	# --- right: details
	var info := UIKit.vbox(3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(UIKit.label(Data.fish_name(record["species"]), 20, rc))
	var tags := UIKit.hbox(4)
	if bool(record.get("prismatic", false)):
		tags.add_child(_tag("PRISMATIC", Color("#bdf6ff")))
	if flags.get("new_species", false):
		tags.add_child(_tag("NEW SPECIES", UIKit.GREEN))
	elif flags.get("new_rarity", false):
		tags.add_child(_tag("NEW RARITY", rc))
	if flags.get("record", false):
		tags.add_child(_tag("RECORD!", UIKit.GOLD))
	if flags.get("level_up", false):
		tags.add_child(_tag(UIKit.T("MASTERY Lv%d") % int(flags["level"]), Color("#7fdcc2")))
	if tags.get_child_count() > 0:
		info.add_child(tags)
	var e := Progression.entry(record["species"])
	info.add_child(_kv("Weight", UIKit.fmt_weight(float(record["weight"])) + (UIKit.T("   (best %s)") % UIKit.fmt_weight(float(e["record"])))))
	info.add_child(_tally())
	var where := Data.pond_name(record["pond"])
	if record.has("spot") and Data.spot_types.has(record["spot"]):
		where += " - " + Data.spot_name(record["spot"])
	info.add_child(_kv("Caught at", where))
	var lv := int(e["level"])
	var mrow := UIKit.hbox(3)
	mrow.add_child(UIKit.label(UIKit.T("Mastery Lv%d") % lv, 10, Color("#7fdcc2")))
	if int(flags.get("xp", 0)) > 0:
		mrow.add_child(UIKit.label(UIKit.T("+%d XP") % int(flags["xp"]), 10, UIKit.GREEN))
	var mb := UIKit.bar("blue", 70, 8)
	mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var target := 1.0 if lv >= Progression.max_level() else float(e["xp"]) / float(Progression.xp_needed(lv))
	mb.value = 0.0
	create_tween().tween_property(mb, "value", target, 0.6).set_delay(0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	mrow.add_child(mb)
	info.add_child(mrow)
	var loot: Dictionary = flags.get("treasure", {})
	if not loot.is_empty():
		var th := UIKit.hbox(3)
		var chest := TextureRect.new()
		chest.texture = load("res://assets/art/spritecook/treasure_chest.png")
		chest.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		chest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		th.add_child(chest)
		var txt := ""
		if String(loot["kind"]) == "bait":
			txt = UIKit.T("Treasure! %s x%d") % [UIKit.T(Data.bait[loot["bait"]]["name"]), int(loot["count"])]
		else:
			txt = UIKit.T("Treasure! +%s coins") % UIKit.fmt_int(int(loot["coins"]))
		th.add_child(UIKit.label(txt, 10, UIKit.GOLD))
		info.add_child(th)
	info.add_child(UIKit.spacer(0, 2))
	var btns := UIKit.hbox(6)
	var sell := UIKit.button(UIKit.T("Sell  +%s") % UIKit.fmt_int(int(record["value"])), "coin", true)
	sell.pressed.connect(_sell)
	btns.add_child(sell)
	if tide_allowed and bool(Data.balance["tide"].get("enabled", true)) and int(record["value"]) >= int(Data.balance["tide"]["min_value"]):
		var tide := UIKit.button("Tide of Fortune", "wave")
		tide.tooltip_text = UIKit.T("Risk this fish's value on up to 3 waves: x0 to x3")
		tide.pressed.connect(_tide)
		btns.add_child(tide)
	info.add_child(btns)


const PART_DESC := {
	"Base": "The species' base price.", "Rarity": "Rarer catches are worth far more.", "Size": "Heavier than usual = pricier.",
	"Skill": "Perfect cast and clean strikes in the fight.", "Record": "A new personal weight record.",
	"Streak": "Hot streak and the Fishmonger talent.", "Golden": "Caught on a golden spot.",
	"Frenzy": "Caught during a Feeding Frenzy.", "Prismatic": "A holographic variant - one in a hundred.",
}


func _tally() -> Control:
	## The price builds up chip by chip (base x multipliers), then the total counts up.
	var v := UIKit.vbox(1)
	var chips := UIKit.hbox(2)
	v.add_child(chips)
	var total_row := UIKit.hbox(3)
	total_row.add_child(UIKit.label("=", 20, UIKit.MUTED))
	var total := UIKit.label("0", 20, UIKit.GOLD)
	total_row.add_child(total)
	total_row.add_child(UIKit.icon("coin"))
	v.add_child(total_row)
	var parts: Array = record.get("parts", [["Base", float(record["value"])]])
	var tw := create_tween()
	tw.tween_interval(0.35)
	var running := 0.0
	for i in parts.size():
		var key := String(parts[i][0])
		var val := float(parts[i][1])
		running = val if i == 0 else running * val
		var chip := UIKit.panel("DarkPanel")
		var txt := UIKit.fmt_int(int(round(val))) if i == 0 else "x" + (str(snappedf(val, 0.1)) if val < 10.0 else str(int(val)))
		var col := Color("#4fb6ff") if i == 0 else (Color("#bdf6ff") if key == "Prismatic" else (UIKit.GOLD if val >= 2.0 else Color("#ff6f5a")))
		chip.add_child(UIKit.label(txt, 10, col))
		chip.modulate.a = 0.0
		HoverTip.attach(chip, UIKit.T(key), PART_DESC.get(key, ""))
		chips.add_child(chip)
		var shown := int(round(running))
		var pitch := 1.0 + i * 0.09
		tw.tween_callback(func() -> void:
			chip.modulate = Color(2.0, 2.0, 2.0, 1.0)
			total.text = UIKit.fmt_int(shown)
			Audio.play_pitched("strike_good", pitch, -6.0))
		tw.tween_property(chip, "modulate", Color.WHITE, 0.12)
	var final_v := int(record["value"])
	tw.tween_method(func(x: float) -> void: total.text = UIKit.fmt_int(int(round(x))), running, float(final_v), 0.25)
	tw.tween_callback(func() -> void:
		Audio.play_pitched("catch_rare" if final_v >= float(parts[0][1]) * 8.0 else "strike_perfect", 1.0, -4.0)
		var tw2 := create_tween()
		tw2.tween_property(total, "modulate", Color(1.8, 1.6, 0.6), 0.06)
		tw2.tween_property(total, "modulate", Color.WHITE, 0.3))
	return v


func focus_first() -> void:
	var btns := content.get_child(0).get_child(1).get_child(-1)
	for b in btns.get_children():
		if b is Button and not (b as Button).disabled:
			(b as Button).grab_focus()
			return


func _tag(text: String, c: Color) -> Control:
	var p := UIKit.panel("DarkPanel")
	p.add_child(UIKit.label(text, 10, c))
	return p


func _kv(k: String, v: String) -> HBoxContainer:
	var h := UIKit.hbox(3)
	var kl := UIKit.label(k, 10, UIKit.MUTED)
	kl.custom_minimum_size.x = 50
	h.add_child(kl)
	h.add_child(UIKit.label(v))
	return h


func _sell() -> void:
	if _resolved:
		return
	_resolved = true
	Economy.sell_catch(record)
	Audio.play("sell")
	close()


func _tide() -> void:
	if _resolved:
		return
	_resolved = true
	go_tide = true
	Audio.play("splash", 0.05, -4.0)
	close()


func close() -> void:
	if not _resolved:
		# closing without a choice sells the fish
		_resolved = true
		Economy.sell_catch(record)
		Audio.play("sell")
	super.close()


class Sparkles:
	extends Control
	var color := Color.WHITE
	var amount := 4
	var _pts: Array[Dictionary] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in amount:
			_pts.append({"p": Vector2(randf() * size.x, randf() * size.y), "t": randf() * 2.0, "s": randf_range(0.8, 1.6)})

	func _process(delta: float) -> void:
		for p in _pts:
			p["t"] = float(p["t"]) + delta * float(p["s"])
			if float(p["t"]) > 2.0:
				p["t"] = 0.0
				p["p"] = Vector2(randf() * size.x, randf() * size.y)
		queue_redraw()

	func _draw() -> void:
		for p in _pts:
			var k := float(p["t"]) / 2.0
			var a := sin(k * PI)
			var c := Color(color, a)
			var pos := (p["p"] as Vector2).floor()
			draw_rect(Rect2(pos, Vector2.ONE), Color(1, 1, 1, a))
			if a > 0.5:
				for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
					draw_rect(Rect2(pos + o, Vector2.ONE), c)
			if a > 0.85:
				for o in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
					draw_rect(Rect2(pos + o, Vector2.ONE), Color(c, 0.5))
