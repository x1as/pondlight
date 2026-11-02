class_name PausePanel
extends ModalPanel
## Pause menu.

signal resume
signal open(panel: String)
signal to_menu
signal quit_game


func _init() -> void:
	super._init()
	title = "Paused"
	panel_size = Vector2(220, 190)


func _build() -> void:
	for spec in [["Resume", "check", "resume"], ["Journal", "scroll", "journal"], ["Settings", "gear", "settings"],
			["Main Menu", "map", "menu"], ["Quit Game", "close", "quit"]]:
		if spec[2] == "quit" and Platform.is_web:
			continue  # browser games have no quit button
		var b := UIKit.button(spec[0], spec[1], spec[2] == "resume")
		b.set_min_width(180)
		var key: String = spec[2]
		b.pressed.connect(_on_button.bind(key))
		content.add_child(b)
	var comp := Progression.completion()
	var st: Dictionary = Save.profile["stats"]
	content.add_child(UIKit.label(UIKit.T("Fish caught %d   Collection %d%%") % [int(st["catches"]), comp["percent"]], 10, UIKit.MUTED))


func _on_button(key: String) -> void:
	if key == "resume":
		close()
	elif key == "journal" or key == "settings":
		open.emit(key)
	elif key == "menu":
		to_menu.emit()
	elif key == "quit":
		quit_game.emit()
