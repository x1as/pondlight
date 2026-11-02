extends Node
## Fish codex, species mastery levels (1..20), personal records and catch statistics.

signal species_discovered(id: String)
signal rarity_discovered(id: String, rarity: int)
signal mastery_up(id: String, level: int)
signal record_set(id: String, weight: float)
signal catch_registered(record: Dictionary, flags: Dictionary)


func p() -> Dictionary:
	return Save.profile


func entry(id: String) -> Dictionary:
	var codex: Dictionary = p()["codex"]
	if not codex.has(id):
		codex[id] = {"caught": 0, "rarities": [0, 0, 0, 0, 0], "record": 0.0, "best_value": 0, "xp": 0, "level": 1, "prismatic": 0}
	return codex[id]


func has_entry(id: String) -> bool:
	return (p()["codex"] as Dictionary).has(id) and int(p()["codex"][id]["caught"]) > 0


func is_discovered(id: String) -> bool:
	return has_entry(id)


func discovered_map(pond_id: String) -> Dictionary:
	var d := {}
	for id in Data.species_of(pond_id):
		d[id] = is_discovered(id)
	return d


func discovered_count(pond_id: String) -> int:
	var n := 0
	for id in Data.species_of(pond_id):
		if is_discovered(id):
			n += 1
	return n


func level(id: String) -> int:
	if not (p()["codex"] as Dictionary).has(id):
		return 1
	return int(p()["codex"][id]["level"])


func xp_needed(lvl: int) -> int:
	var m: Dictionary = Data.balance["mastery"]
	return int(m["xp_base"]) + int(m["xp_per_level"]) * lvl


func max_level() -> int:
	return int(Data.balance["mastery"]["max_level"])


func completion() -> Dictionary:
	## Species discovered and species x rarity entries discovered, across all ponds.
	var species := 0
	var entries := 0
	for id in Data.fish_order:
		if is_discovered(id):
			species += 1
			for v in entry(id)["rarities"]:
				if int(v) > 0:
					entries += 1
	var total_species := Data.fish_order.size()
	var total_entries := total_species * RarityTable.COUNT
	return {
		"species": species, "total_species": total_species, "entries": entries, "total_entries": total_entries,
		"percent": int(round(100.0 * float(entries) / float(total_entries))),
	}


func register_catch(rec: Dictionary) -> Dictionary:
	var id := String(rec["species"])
	var r := int(rec["rarity"])
	var pond := String(rec["pond"])
	var first := not is_discovered(id)
	var e := entry(id)
	var flags := {"new_species": first, "new_rarity": false, "record": false, "level_up": false, "level": int(e["level"])}
	e["caught"] = int(e["caught"]) + 1
	var rar: Array = e["rarities"]
	if int(rar[r]) == 0:
		flags["new_rarity"] = true
	rar[r] = int(rar[r]) + 1
	var w := float(rec["weight"])
	if w > float(e["record"]):
		flags["record"] = float(e["record"]) > 0.0
		flags["prev_record"] = float(e["record"])
		e["record"] = w
	e["best_value"] = maxi(int(e["best_value"]), int(rec["value"]))
	# mastery xp: this species only; bonuses are capped so nothing can run away
	var m: Dictionary = Data.balance["mastery"]
	var gain := int(Data.rarity(r)["xp"])
	if first:
		gain += int(m["bonus_discovery"])
	if flags["record"]:
		gain += int(m["bonus_record"])
	if flags["new_rarity"] and not first:
		gain += int(m["bonus_new_rarity"])
	var xp_mult := 1.0 + Economy.stats().xp_bonus
	if bool(rec.get("prismatic", false)):
		xp_mult *= float(Data.balance["variants"]["xp_mult"])
		e["prismatic"] = int(e.get("prismatic", 0)) + 1
		p()["stats"]["prismatics"] = int(p()["stats"].get("prismatics", 0)) + 1
	gain = mini(int(round(gain * xp_mult)), int(round(int(m["max_xp_per_catch"]) * xp_mult)))
	flags["xp"] = gain if int(e["level"]) < max_level() else 0
	if int(e["level"]) < max_level():
		e["xp"] = int(e["xp"]) + gain
		while int(e["level"]) < max_level() and int(e["xp"]) >= xp_needed(int(e["level"])):
			e["xp"] = int(e["xp"]) - xp_needed(int(e["level"]))
			e["level"] = int(e["level"]) + 1
			flags["level_up"] = true
		if int(e["level"]) >= max_level():
			e["xp"] = 0
	flags["level"] = int(e["level"])
	# stats & bad luck protection
	var st: Dictionary = p()["stats"]
	st["catches"] = int(st["catches"]) + 1
	if flags["record"]:
		st["records"] = int(st["records"]) + 1
	var bl: Dictionary = p()["bad_luck"]
	if first:
		bl[pond] = 0
	elif discovered_count(pond) < Data.species_of(pond).size():
		bl[pond] = int(bl.get(pond, 0)) + 1
	Save.mark_dirty()
	if first:
		species_discovered.emit(id)
	if flags["new_rarity"]:
		rarity_discovered.emit(id, r)
	if flags["level_up"]:
		mastery_up.emit(id, int(e["level"]))
	if flags["record"]:
		record_set.emit(id, w)
	catch_registered.emit(rec, flags)
	Achievements.on_catch(rec, flags)
	return flags
