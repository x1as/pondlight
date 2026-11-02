extends Node
## Data-driven achievements and optional daily bounties (local date, no server).
## Achievements are reported through Platform so a Steam backend can mirror them.

signal unlocked(id: String)
signal daily_progress(index: int)


func p() -> Dictionary:
	return Save.profile


func is_unlocked(id: String) -> bool:
	return (p()["achievements"] as Dictionary).has(id)


func _unlock(id: String) -> void:
	if is_unlocked(id):
		return
	p()["achievements"][id] = int(Time.get_unix_time_from_system())
	Save.mark_dirty()
	Platform.unlock_achievement(id)
	unlocked.emit(id)


func def(id: String) -> Dictionary:
	for a in Data.achievements:
		if a["id"] == id:
			return a
	return {}


func check_all() -> void:
	var st: Dictionary = p()["stats"]
	for a in Data.achievements:
		var id: String = a["id"]
		if is_unlocked(id):
			continue
		var target := int(a["target"])
		var ok := false
		match String(a["type"]):
			"catches":
				ok = int(st["catches"]) >= target
			"perfect_casts":
				ok = int(st["perfect_casts"]) >= target
			"combo":
				ok = int(st["best_combo"]) >= target
			"record":
				ok = int(st["records"]) >= target
			"pond_species":
				ok = Progression.discovered_count(String(a["pond"])) >= target
			"unlock":
				ok = (p()["ponds_unlocked"] as Array).has(String(a["pond"]))
			"mastery":
				for f in Data.fish_order:
					if Progression.level(f) >= target:
						ok = true
			"full_gear":
				ok = true
				for s in Data.slot_order:
					if int(p()["equipment"][s]) + 1 < target:
						ok = false
			"rarity":
				for f in Data.fish_order:
					if Progression.has_entry(f):
						var rar: Array = Progression.entry(f)["rarities"]
						for i in range(target, rar.size()):
							if int(rar[i]) > 0:
								ok = true
			"earned":
				ok = int(st["coins_earned"]) >= target
			"talents":
				ok = Economy.talent_points() >= target
			"streak":
				ok = int(st.get("best_streak", 0)) >= target
			"golden":
				ok = int(st.get("golden_catches", 0)) >= target
			"habitats":
				var n := 0
				for k in (st.get("habitats", {}) as Dictionary).keys():
					if String(k).begins_with(String(a["pond"]) + ":"):
						n += 1
				ok = n >= target
			"species":
				ok = Progression.has_entry(String(a["fish"]))
			"prismatic":
				ok = int(st.get("prismatics", 0)) >= target
			"chests":
				ok = int(st.get("chests", 0)) >= target
			"tide":
				ok = float(st.get("tide_best", 0.0)) >= float(target)
			"all":
				ok = trophy_count() >= target
		if ok:
			_unlock(id)


func trophy_count() -> int:
	## Unlocked trophies, not counting the grand trophy itself.
	var n := 0
	for a in Data.achievements:
		if String(a["type"]) != "all" and is_unlocked(String(a["id"])):
			n += 1
	return n


func on_catch(rec: Dictionary, flags: Dictionary) -> void:
	_daily_event("catch_any", 1)
	if int(rec["rarity"]) >= 2:
		_daily_event("catch_rarity", 1)
	if flags.get("record", false):
		_daily_event("record", 1)
	check_all()


func on_event(kind: String, data: Dictionary) -> void:
	match kind:
		"perfect_cast":
			_daily_event("perfect_cast", 1)
		"earn":
			_daily_event("earn", int(data.get("amount", 0)))
	check_all()


# ------------------------------------------------------------------ daily bounties
func today() -> String:
	var d := Time.get_date_dict_from_system()
	return UIKit.T("%04d-%02d-%02d") % [d["year"], d["month"], d["day"]]


func ensure_daily() -> void:
	var daily: Dictionary = p()["daily"]
	if daily.get("date", "") == today() and not (daily.get("tasks", []) as Array).is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today())
	var pool := Data.daily_templates.duplicate()
	var tasks: Array = []
	for i in 3:
		var t: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var n := rng.randi_range(int(t["min"]), int(t["max"]))
		if String(t["type"]) == "earn":
			n = int(round(n / 50.0) * 50)
		var reward := int(round(float(t["reward_per"]) * n))
		tasks.append({"type": t["type"], "text": String(t["text"]).replace("{n}", str(n)), "tmpl": t["text"], "target": n, "progress": 0,
			"reward": maxi(20, reward), "claimed": false})
	daily["date"] = today()
	daily["tasks"] = tasks
	Save.mark_dirty()


func daily_tasks() -> Array:
	ensure_daily()
	return p()["daily"]["tasks"]


func _daily_event(kind: String, amount: int) -> void:
	var tasks := daily_tasks()
	for i in tasks.size():
		var t: Dictionary = tasks[i]
		if t["type"] == kind and int(t["progress"]) < int(t["target"]):
			t["progress"] = mini(int(t["target"]), int(t["progress"]) + amount)
			Save.mark_dirty()
			daily_progress.emit(i)


func claim_daily(i: int) -> int:
	var tasks := daily_tasks()
	if i < 0 or i >= tasks.size():
		return 0
	var t: Dictionary = tasks[i]
	if bool(t["claimed"]) or int(t["progress"]) < int(t["target"]):
		return 0
	t["claimed"] = true  # mark before paying: rewards cannot be claimed twice
	Economy.add_coins(int(t["reward"]))
	Save.save_game()
	return int(t["reward"])
