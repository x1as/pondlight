class_name FishSelector
extends RefCounted
## Weighted species selection for one pond cell.
##
## weight = spawn_weight x spot affinity x time x weather x bait x rare-bait bonus
##          x perfect-cast rare bonus x bad-luck protection (undiscovered species only)


static func odds(pond_id: String, spot: String, ctx: Dictionary) -> Dictionary:
	var out := {}
	var total := 0.0
	var phase := String(ctx.get("phase", "day"))
	var weather := String(ctx.get("weather", "clear"))
	var bait_id := String(ctx.get("bait", "worm"))
	var bait: Dictionary = Data.bait.get(bait_id, {})
	var discovered: Dictionary = ctx.get("discovered", {})
	var bad_luck := int(ctx.get("bad_luck", 0))
	var sel: Dictionary = Data.balance["selection"]
	var bl_mult := minf(float(sel["bad_luck_max_mult"]), 1.0 + float(sel["bad_luck_per_cast"]) * bad_luck)
	for id in Data.species_of(pond_id):
		var f: Dictionary = Data.fish[id]
		var w := float(f["spawn_weight"])
		w *= float((f["spots"] as Dictionary).get(spot, 0.0))
		w *= float((f["time"] as Dictionary).get(phase, 1.0))
		w *= float((f["weather"] as Dictionary).get(weather, 1.0))
		w *= float((f["bait"] as Dictionary).get(bait_id, 1.0))
		if float(f["spawn_weight"]) <= 10.0:
			w *= float(bait.get("species_mult_rare", 1.0)) * (1.0 + float(ctx.get("rare_bite", 0.0)))
			if bool(ctx.get("perfect", false)):
				w *= float(sel["perfect_cast_rare_bonus"])
		if not discovered.get(id, false):
			w *= bl_mult
		if w > 0.0:
			out[id] = w
			total += w
	if total > 0.0:
		for k in out.keys():
			out[k] = out[k] / total
	return out


static func pick(rng: RandomNumberGenerator, table: Dictionary) -> String:
	var r := rng.randf()
	var acc := 0.0
	var last := ""
	for k in table.keys():
		acc += float(table[k])
		last = k
		if r <= acc:
			return k
	return last
