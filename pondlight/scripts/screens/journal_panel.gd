class_name JournalPanel
extends ModalPanel
## Achievements and optional daily bounties.

var _body: VBoxContainer


func _init() -> void:
	super._init()
	title = "Angler's Journal"
	panel_size = Vector2(450, 296)


func _build() -> void:
	_body = UIKit.vbox(3)
	content.add_child(_body)
	_refresh()


func _refresh() -> void:
	clear(_body)
	_body.add_child(UIKit.label("Daily bounties  (optional - nothing is lost if you skip them)", 10, UIKit.GOLD))
	var tasks := Achievements.daily_tasks()
	for i in tasks.size():
		var t: Dictionary = tasks[i]
		var p := UIKit.panel("DarkPanel")
		var h := UIKit.hbox(5)
		p.add_child(h)
		h.add_child(UIKit.icon("scroll"))
		var txt := UIKit.T(String(t["tmpl"])).replace("{n}", str(int(t["target"]))) if t.has("tmpl") else String(t["text"])
		var l := UIKit.label(txt, 10)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 190
		h.add_child(l)
		var bar := UIKit.bar("green", 70, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.value = float(t["progress"]) / float(t["target"])
		h.add_child(bar)
		h.add_child(UIKit.label(UIKit.T("%d/%d") % [int(t["progress"]), int(t["target"])], 10, UIKit.MUTED))
		h.add_child(UIKit.spacer())
		var idx := i
		if bool(t["claimed"]):
			h.add_child(UIKit.label("Claimed", 10, UIKit.GREEN))
		else:
			var b := UIKit.button(UIKit.T("+%d") % int(t["reward"]), "coin", int(t["progress"]) >= int(t["target"]))
			b.disabled = int(t["progress"]) < int(t["target"])
			b.pressed.connect(func() -> void:
				if Achievements.claim_daily(idx) > 0:
					Audio.play("purchase")
				_refresh()
				focus_first.call_deferred())
			h.add_child(b)
		_body.add_child(p)
	_body.add_child(UIKit.label(UIKit.T("Achievements  %d / %d") % [Achievements.trophy_count(), Data.achievements.size() - 1], 10, UIKit.GOLD))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 84)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	scroll.add_child(grid)
	for a in Data.achievements:
		var got := Achievements.is_unlocked(a["id"])
		var p2 := UIKit.panel("DarkPanel")
		p2.custom_minimum_size.x = 204
		var h2 := UIKit.hbox(4)
		p2.add_child(h2)
		var ic := UIKit.icon("trophy" if got else "lock")
		h2.add_child(ic)
		var v := UIKit.vbox(0)
		v.add_child(UIKit.label(String(a["name"]), 10, UIKit.GOLD if got else UIKit.MUTED))
		var dl := UIKit.label(String(a["desc"]), 10, UIKit.CREAM if got else Color("#8a919a"))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 178
		v.add_child(dl)
		h2.add_child(v)
		grid.add_child(p2)
