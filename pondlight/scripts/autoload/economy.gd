extends Node
## Coins, catch sales, treasure, equipment purchases, talents, bait and pond unlock payments.
## Every mutation saves immediately so sales/rewards can never be duplicated by quitting.

signal coins_changed(coins: int, delta: int)
signal equipment_changed(slot: String, tier: int)
signal bait_changed
signal pond_unlocked(pond_id: String)


func p() -> Dictionary:
	return Save.profile


func coins() -> int:
	return int(p()["coins"])


func add_coins(amount: int, from_sale := false) -> void:
	if amount <= 0:
		return
	p()["coins"] = coins() + amount
	if from_sale:
		p()["stats"]["coins_earned"] = int(p()["stats"]["coins_earned"]) + amount
		Achievements.on_event("earn", {"amount": amount})
	coins_changed.emit(coins(), amount)


func spend(amount: int) -> bool:
	if amount < 0 or coins() < amount:
		return false
	p()["coins"] = coins() - amount
	coins_changed.emit(coins(), -amount)
	return true


# ------------------------------------------------------------------ catches
func sell_catch(record: Dictionary, amount: int = -1) -> int:
	## Pays out a fresh catch exactly once (the record is marked before coins move).
	## amount < 0 pays the fish's own value; Tide of Fortune passes its final pot (0 = the tide took it).
	if bool(record.get("paid", false)):
		return 0
	record["paid"] = true
	var v := int(record["value"]) if amount < 0 else maxi(0, amount)
	record["sold_for"] = v
	add_coins(v, true)
	Save.save_game()
	return v


func roll_treasure(rng: RandomNumberGenerator, pond_id: String, bait_id: String) -> Dictionary:
	## A sunken chest tangled on the hook now and then. Loot is paid out immediately.
	var tr: Dictionary = Data.balance["treasure"]
	var chance := float(tr["chance"]) + stats().chest_bonus
	if Data.bait.has(bait_id) and bait_active_here(bait_id, pond_id):
		chance *= float(Data.bait[bait_id].get("treasure_mult", 1.0))
	if rng.randf() >= chance:
		return {}
	var total := 0.0
	for l in tr["loot"]:
		total += float(l["w"])
	var r := rng.randf() * total
	var pick: Dictionary = tr["loot"][0]
	for l in tr["loot"]:
		r -= float(l["w"])
		if r <= 0.0:
			pick = l
			break
	var loot := {"kind": String(pick["kind"])}
	if loot["kind"] == "bait":
		var opts: Array[String] = []
		for id in Data.bait_order:
			if int(Data.bait[id]["cost"]) > 0 and bait_active_here(id, pond_id):
				opts.append(id)
		var bid: String = opts[rng.randi_range(0, opts.size() - 1)]
		loot["bait"] = bid
		loot["count"] = int(Data.bait[bid]["pack"])
		p()["bait"][bid] = maxi(0, bait_count(bid)) + int(loot["count"])
		bait_changed.emit()
	else:
		var cc: Array = Data.ponds[pond_id]["chest_coins"]
		loot["coins"] = int(round(rng.randf_range(float(cc[0]), float(cc[1])) * float(pick.get("mult", 1.0))))
		loot["jackpot"] = float(pick.get("mult", 1.0)) > 1.0
		add_coins(int(loot["coins"]), true)
	p()["stats"]["chests"] = int(p()["stats"].get("chests", 0)) + 1
	Save.save_game()
	Achievements.check_all()
	return loot


# ------------------------------------------------------------------ fish traps (offline income)
func trap_rate() -> float:
	## Coins per hour from every unlocked water's traps, scaled by how well the gear suits that water.
	var st := stats()
	var total := 0.0
	for pid in Data.pond_order:
		if not is_unlocked(pid):
			continue
		var strongest := 0.0
		for id in Data.species_of(pid):
			strongest = maxf(strongest, float(Data.fish[id]["fight"]["power"]))
		var fit := clampf(st.gear_rating() / maxf(1.0, strongest), 0.25, 1.0)
		total += float(Data.ponds[pid].get("trap_per_hour", 0)) * fit
	return total


func trap_haul(seconds: float) -> int:
	var t: Dictionary = Data.balance["traps"]
	if seconds < float(t["min_minutes"]) * 60.0:
		return 0
	var hours := minf(seconds / 3600.0, float(t["cap_hours"]))
	return int(round(trap_rate() * hours))


func claim_traps(amount: int) -> int:
	## Paid once: the away timer is reset by the save that follows.
	if amount <= 0:
		return 0
	add_coins(amount, true)
	Save.save_game()
	return amount


# ------------------------------------------------------------------ equipment
func tier_of(slot: String) -> int:
	return int(p()["equipment"][slot])


func next_cost(slot: String) -> int:
	var t := tier_of(slot) + 1
	if t >= Data.tier_count(slot):
		return -1
	return int(Data.tier(slot, t)["cost"])


func buy_upgrade(slot: String) -> bool:
	var cost := next_cost(slot)
	if cost < 0 or not spend(cost):
		return false
	p()["equipment"][slot] = tier_of(slot) + 1
	Save.save_game()
	equipment_changed.emit(slot, tier_of(slot))
	Achievements.on_event("gear", {})
	return true


func stats() -> PlayerStats:
	return PlayerStats.from_equipment(p()["equipment"]).apply_talents(p()["talents"])


# ------------------------------------------------------------------ talents
signal talents_changed


func talent_level(id: String) -> int:
	return int((p()["talents"] as Dictionary).get(id, 0))


func talent_cost(id: String) -> int:
	## -1 when maxed. cost x growth^level.
	var t: Dictionary = Data.talents[id]
	var lv := talent_level(id)
	if lv >= int(t["max"]):
		return -1
	return int(round(float(t["cost"]) * pow(float(t["growth"]), lv)))


func talent_points() -> int:
	var n := 0
	for id in (p()["talents"] as Dictionary).keys():
		n += int(p()["talents"][id])
	return n


func buy_talent(id: String) -> bool:
	var cost := talent_cost(id)
	if cost < 0 or not spend(cost):
		return false
	p()["talents"][id] = talent_level(id) + 1
	Save.save_game()
	talents_changed.emit()
	Achievements.on_event("talent", {})
	return true


# ------------------------------------------------------------------ bait
func bait_count(id: String) -> int:
	return int(p()["bait"].get(id, 0))


func buy_bait(id: String) -> bool:
	var b: Dictionary = Data.bait[id]
	if int(b["cost"]) <= 0:
		return false
	if not spend(int(b["cost"])):
		return false
	p()["bait"][id] = bait_count(id) + int(b["pack"])
	Save.save_game()
	bait_changed.emit()
	return true


func selected_bait() -> String:
	var id := String(p()["selected_bait"])
	if not Data.bait.has(id) or (bait_count(id) == 0):
		return "worm"
	return id


func select_bait(id: String) -> void:
	if Data.bait.has(id) and (bait_count(id) != 0):
		p()["selected_bait"] = id
		Save.mark_dirty()
		bait_changed.emit()


func cycle_bait() -> void:
	var order := Data.bait_order
	var i := order.find(selected_bait())
	for k in range(1, order.size() + 1):
		var id: String = order[(i + k) % order.size()]
		if bait_count(id) != 0:
			select_bait(id)
			return


func bait_active_here(id: String, pond_id: String) -> bool:
	var ponds: Array = Data.bait[id].get("ponds", [])
	return ponds.is_empty() or ponds.has(pond_id)


func consume_bait() -> void:
	var id := selected_bait()
	if bait_count(id) > 0:
		p()["bait"][id] = bait_count(id) - 1
		if bait_count(id) == 0:
			p()["selected_bait"] = "worm"
		Save.mark_dirty()
		bait_changed.emit()


# ------------------------------------------------------------------ ponds
func unlock_status(pond_id: String) -> Dictionary:
	var pond: Dictionary = Data.ponds[pond_id]
	var u: Variant = pond.get("unlock")
	if u == null:
		return {"ok": true, "unlocked": true}
	var src := String(u["species_of"])
	var need := Data.species_of(src).size()
	var have := Progression.discovered_count(src)
	var cost := int(u["coins"])
	var unlocked: bool = (p()["ponds_unlocked"] as Array).has(pond_id)
	return {
		"ok": have >= need and coins() >= cost, "unlocked": unlocked,
		"have_species": have, "need_species": need, "cost": cost, "source": src,
		"species_ok": have >= need, "coins_ok": coins() >= cost,
	}


func unlock_pond(pond_id: String) -> bool:
	var st := unlock_status(pond_id)
	if st["unlocked"] or not st["ok"]:
		return false
	if not spend(int(st["cost"])):
		return false
	(p()["ponds_unlocked"] as Array).append(pond_id)
	Save.save_game()
	pond_unlocked.emit(pond_id)
	Achievements.on_event("unlock", {"pond": pond_id})
	return true


func is_unlocked(pond_id: String) -> bool:
	return (p()["ponds_unlocked"] as Array).has(pond_id)
