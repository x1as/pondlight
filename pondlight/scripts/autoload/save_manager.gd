extends Node
## Versioned, crash-safe save file.
##
## Write path: JSON -> save.tmp -> (save.json moved to save.bak) -> save.tmp renamed to save.json.
## Load path: save.json -> save.bak -> save.tmp. Missing keys are filled from defaults,
## so older saves keep working when new fields are added (see _migrate).

signal saved
signal loaded

const SAVE_VERSION := 2
var save_dir := "user://"
var profile: Dictionary = {}
var _dirty := false
var away_seconds := 0.0  # time the game was closed, measured once at load (fish traps)
var _autosave_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	profile = default_profile()


func _save_name() -> String:
	return "save"


func path_main() -> String:
	return save_dir.path_join(_save_name() + ".json")


func path_backup() -> String:
	return save_dir.path_join(_save_name() + ".bak.json")


func path_tmp() -> String:
	return save_dir.path_join(_save_name() + ".tmp")


func default_profile() -> Dictionary:
	var bait := {}
	for b in Data.bait_order:
		bait[b] = -1 if int(Data.bait[b]["cost"]) == 0 else 0
	var bad_luck := {}
	var weather := {}
	for p in Data.pond_order:
		bad_luck[p] = 0
		weather[p] = "clear"
	return {
		"version": SAVE_VERSION,
		"created": int(Time.get_unix_time_from_system()),
		"coins": int(Data.balance["economy"]["start_coins"]),
		"equipment": {"rod": 0, "reel": 0, "line": 0, "charm": 0},
		"talents": {},
		"bait": bait,
		"selected_bait": "worm",
		"next_uid": 1,
		"codex": {},
		"ponds_unlocked": ["willow"],
		"current_pond": "willow",
		"stats": {
			"casts": 0, "catches": 0, "escapes": 0, "snaps": 0, "perfect_casts": 0,
			"best_combo": 0, "coins_earned": 0, "records": 0, "play_time": 0.0,
			"streak": 0, "best_streak": 0, "golden_catches": 0, "legendaries": 0, "habitats": {},
			"chests": 0, "tide_best": 0.0, "tides_won": 0, "tides_lost": 0,
			"prismatics": 0, "frenzies": 0, "orders_done": 0,
		},
		"bad_luck": bad_luck,
		"achievements": {},
		"daily": {"date": "", "tasks": []},
		"clock": {"time": float(Data.balance["clock"]["start_time"]), "weather": weather, "weather_timer": 200.0},
		"flags": {},
		"tutorial_done": false,
		"orders": [],
		"last_seen": int(Time.get_unix_time_from_system()),
	}


func has_save() -> bool:
	return FileAccess.file_exists(path_main()) or FileAccess.file_exists(path_backup())


func new_game() -> void:
	away_seconds = 0.0
	profile = default_profile()
	save_game()
	loaded.emit()


func load_game() -> bool:
	for p in [path_main(), path_backup(), path_tmp()]:
		var d := _read(p)
		if not d.is_empty():
			profile = _migrate(d)
			away_seconds = maxf(0.0, float(Time.get_unix_time_from_system()) - float(profile.get("last_seen", Time.get_unix_time_from_system())))
			loaded.emit()
			return true
	profile = default_profile()
	return false


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(f.get_as_text()) == OK else null
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("version"):
		push_warning(UIKit.T("Save: %s is corrupted, trying fallback") % path)
		return {}
	return parsed


func _migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	if v < 2:
		_migrate_v2(d)
	if v > SAVE_VERSION:
		push_warning(UIKit.T("Save: file from a newer version (%d)") % v)
	_fill_defaults(d, default_profile())
	d["version"] = SAVE_VERSION
	# sanitize numbers that JSON turned into floats
	d["coins"] = maxi(0, int(d["coins"]))
	d["next_uid"] = int(d["next_uid"])
	for k in d["equipment"].keys():
		d["equipment"][k] = clampi(int(d["equipment"][k]), 0, Data.tier_count(k) - 1)
	for k in d["bait"].keys():
		d["bait"][k] = int(d["bait"][k])
	if not Data.ponds.has(d["current_pond"]) or not (d["ponds_unlocked"] as Array).has(d["current_pond"]):
		d["current_pond"] = "willow"
	return d


func _migrate_v2(d: Dictionary) -> void:
	## v0.4 removed the bag: every fish still in it is sold for its value, and the removed
	## Big Basket talent is refunded at the price that was paid for it.
	var refund := 0
	for rec in d.get("inventory", []):
		refund += int((rec as Dictionary).get("value", 0))
	d.erase("inventory")
	var tal: Dictionary = d.get("talents", {})
	if tal.has("big_basket"):
		for i in int(tal["big_basket"]):
			refund += int(round(40.0 * pow(1.6, i)))
		tal.erase("big_basket")
	d["coins"] = int(d.get("coins", 0)) + refund
	if refund > 0:
		var st: Dictionary = d.get("stats", {})
		st["coins_earned"] = int(st.get("coins_earned", 0)) + refund


func _fill_defaults(target: Dictionary, defaults: Dictionary) -> void:
	for k in defaults.keys():
		if not target.has(k):
			target[k] = defaults[k]
		elif typeof(defaults[k]) == TYPE_DICTIONARY and typeof(target[k]) == TYPE_DICTIONARY:
			_fill_defaults(target[k], defaults[k])


func save_game() -> bool:
	_dirty = false
	if profile.has("stats"):
		profile["last_seen"] = int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
	var text := JSON.stringify(profile, "\t")
	var f := FileAccess.open(path_tmp(), FileAccess.WRITE)
	if f == null:
		push_error(UIKit.T("Save: cannot write %s") % path_tmp())
		return false
	f.store_string(text)
	f.flush()
	f.close()
	var main_abs := ProjectSettings.globalize_path(path_main())
	var bak_abs := ProjectSettings.globalize_path(path_backup())
	var tmp_abs := ProjectSettings.globalize_path(path_tmp())
	if FileAccess.file_exists(path_main()):
		if FileAccess.file_exists(path_backup()):
			DirAccess.remove_absolute(bak_abs)
		DirAccess.rename_absolute(main_abs, bak_abs)
	var err := DirAccess.rename_absolute(tmp_abs, main_abs)
	if err != OK:
		push_error(UIKit.T("Save: rename failed (%d)") % err)
		return false
	saved.emit()
	return true


func quit_game() -> void:
	## Graceful quit used by every quit path: save, silence audio, let the audio thread settle.
	if profile.has("stats") and has_save():
		save_game()
	Audio.shutdown()
	await get_tree().create_timer(0.12, true).timeout
	get_tree().quit()


func mark_dirty() -> void:
	_dirty = true


func _process(delta: float) -> void:
	if profile.has("stats"):
		profile["stats"]["play_time"] = float(profile["stats"]["play_time"]) + delta
	_autosave_timer += delta
	if _dirty and _autosave_timer > 2.0:
		_autosave_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if profile.has("stats") and has_save():
			save_game()
