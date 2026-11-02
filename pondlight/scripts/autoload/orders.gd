extends Node
## Captain's Orders: three short goals that are always open. Finishing one pays at once and a new one
## takes its place, so there is always a "next little thing" to chase. Rewards scale with the water you fish.

signal order_done(order: Dictionary, reward: int)
signal orders_changed

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func p() -> Dictionary:
	return Save.profile


func list() -> Array:
	if not p().has("orders"):
		p()["orders"] = []
	var arr: Array = p()["orders"]
	while arr.size() < int(Data.balance["orders"]["active"]):
		arr.append(_make(arr))
	return arr


func text(o: Dictionary) -> String:
	var t := UIKit.T(String(o["tmpl"])).replace("{n}", str(int(o["target"])))
	if o.has("fish"):
		t = t.replace("{fish}", Data.fish_name(String(o["fish"])))
	if o.has("spot"):
		t = t.replace("{spot}", Data.spot_name(String(o["spot"])))
	return t


func _pond() -> String:
	return String(p().get("current_pond", "willow"))


func _avg_value(pid: String) -> float:
	var tot := 0.0
	var ids := Data.species_of(pid)
	for id in ids:
		tot += float(Data.fish[id]["base_value"])
	return tot / maxf(1.0, ids.size())


func _make(existing: Array) -> Dictionary:
	var pid := _pond()
	var used := {}
	for o in existing:
		used[String(o["type"])] = true
	var pool: Array = []
	for t in Data.order_templates:
		if not used.has(String(t["type"])):
			pool.append(t)
	var known: Array[String] = []
	for id in Data.species_of(pid):
		if Progression.is_discovered(id):
			known.append(id)
	for i in 10:
		var t: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
		var type := String(t["type"])
		if type == "catch_species" and known.is_empty():
			continue
		var n := _rng.randi_range(int(t["min"]), int(t["max"]))
		var o := {"type": type, "tmpl": String(t["text"]), "target": n, "progress": 0, "pond": pid}
		var base := _avg_value(pid)
		match type:
			"catch_species":
				var f: String = known[_rng.randi_range(0, known.size() - 1)]
				o["fish"] = f
				base = float(Data.fish[f]["base_value"])
			"catch_spot":
				var spots: Array[String] = []
				for c in Data.fishable_cells(pid):
					var s := Data.spot_at(pid, c)
					if not spots.has(s):
						spots.append(s)
				o["spot"] = spots[_rng.randi_range(0, spots.size() - 1)]
		var per := 1 if type in ["combo", "tide"] else n
		o["reward"] = maxi(10, int(round(float(t["reward"]) * per * base * float(Data.balance["orders"]["reward_mult"]))))
		return o
	return {"type": "perfect_cast", "tmpl": "Land {n} perfect casts", "target": 2, "progress": 0, "pond": pid, "reward": 20}


func _advance(type: String, amount: int, match_fn: Callable = Callable(), absolute := false) -> void:
	var arr := list()
	var changed := false
	for i in arr.size():
		var o: Dictionary = arr[i]
		if String(o["type"]) != type:
			continue
		if match_fn.is_valid() and not match_fn.call(o):
			continue
		var before := int(o["progress"])
		o["progress"] = mini(int(o["target"]), maxi(before, amount) if absolute else before + amount)
		changed = changed or int(o["progress"]) != before
	if changed:
		_complete_finished()
		Save.mark_dirty()
		orders_changed.emit()


func _complete_finished() -> void:
	var arr := list()
	for i in arr.size():
		var o: Dictionary = arr[i]
		if int(o["progress"]) >= int(o["target"]):
			var reward := int(o["reward"])
			arr[i] = _make(arr)  # replace first: an order can only ever pay once
			p()["stats"]["orders_done"] = int(p()["stats"].get("orders_done", 0)) + 1
			Economy.add_coins(reward, true)
			Save.save_game()
			order_done.emit(o, reward)


func refresh_for_pond() -> void:
	## Travelling replaces orders that point at another water's fish or habitats.
	var arr := list()
	var pid := _pond()
	for i in arr.size():
		var o: Dictionary = arr[i]
		if (o.has("fish") or o.has("spot")) and String(o["pond"]) != pid:
			arr[i] = _make(arr)
	orders_changed.emit()


# ------------------------------------------------------------------ events
func on_catch(rec: Dictionary) -> void:
	var sp := String(rec["species"])
	var spot := String(rec.get("spot", ""))
	var pid := String(rec["pond"])
	_advance("catch_species", 1, func(o: Dictionary) -> bool: return String(o["fish"]) == sp)
	_advance("catch_spot", 1, func(o: Dictionary) -> bool: return String(o["spot"]) == spot and String(o["pond"]) == pid)
	if int(rec["rarity"]) >= 2:
		_advance("catch_rarity", 1)
	_advance("streak", int(p()["stats"].get("streak", 0)), Callable(), true)


func on_lost() -> void:
	## A lost fish restarts "in a row" orders.
	for o in list():
		if String(o["type"]) == "streak":
			o["progress"] = 0
	orders_changed.emit()


func on_perfect_cast() -> void:
	_advance("perfect_cast", 1)


func on_combo(n: int) -> void:
	_advance("combo", n, Callable(), true)


func on_tide_win() -> void:
	_advance("tide", 1)
