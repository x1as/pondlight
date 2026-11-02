extends Node
## Content & balance database. Everything tunable lives in res://data/*.json.

var fish: Dictionary = {}
var fish_order: Array[String] = []
var ponds: Dictionary = {}
var pond_order: Array[String] = []
var spot_types: Dictionary = {}
var balance: Dictionary = {}
var slots: Dictionary = {}
var slot_order: Array[String] = []
var bait: Dictionary = {}
var bait_order: Array[String] = []
var achievements: Array = []
var daily_templates: Array = []
var order_templates: Array = []
var rarities: Array = []
var store: Dictionary = {}
var talent_sectors: Array = []
var talents: Dictionary = {}


func _init() -> void:
	var f := _read("res://data/fish.json")
	for e in f.get("fish", []):
		fish[e["id"]] = e
		fish_order.append(e["id"])
	var p := _read("res://data/ponds.json")
	for e in p.get("ponds", []):
		ponds[e["id"]] = e
		pond_order.append(e["id"])
	spot_types = p.get("spot_types", {})
	balance = _read("res://data/balance.json")
	rarities = balance.get("rarities", [])
	var eq := _read("res://data/equipment.json")
	for s in eq.get("slots", []):
		slots[s["id"]] = s
		slot_order.append(s["id"])
	for b in eq.get("bait", []):
		bait[b["id"]] = b
		bait_order.append(b["id"])
	var ach := _read("res://data/achievements.json")
	achievements = ach.get("achievements", [])
	store = _read("res://data/store.json")
	talent_sectors = _read("res://data/talents.json").get("sectors", [])
	for sec in talent_sectors:
		for t in sec["talents"]:
			talents[t["id"]] = t
	daily_templates = ach.get("daily_templates", [])
	order_templates = ach.get("order_templates", [])


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Data: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Data: invalid JSON in %s" % path)
		return {}
	return parsed


# ------------------------------------------------------------------ translated names
func fish_name(id: String) -> String:
	return UIKit.T(String(fish[id]["name"]))


func pond_name(id: String) -> String:
	return UIKit.T(String(ponds[id]["name"]))


func spot_name(ch: String) -> String:
	return UIKit.T(String(spot_types.get(ch, {}).get("name", "")))


func rarity_name(idx: int) -> String:
	return UIKit.T(String(rarity(idx)["name"]))


func species_of(pond_id: String) -> Array[String]:
	var out: Array[String] = []
	for id in fish_order:
		if fish[id]["pond"] == pond_id:
			out.append(id)
	return out


func pond_flag(pond_id: String, fx: String) -> bool:
	## Visual/behaviour flags of a pond (fog, aurora, leaves, fireflies, ripples, mist, abyss).
	return (ponds[pond_id].get("fx", []) as Array).has(fx)


func rarity(idx: int) -> Dictionary:
	return rarities[clampi(idx, 0, rarities.size() - 1)]


func rarity_color(idx: int) -> Color:
	return Color(rarity(idx)["color"])


func tier(slot: String, idx: int) -> Dictionary:
	var tiers: Array = slots[slot]["tiers"]
	return tiers[clampi(idx, 0, tiers.size() - 1)]


func tier_count(slot: String) -> int:
	return (slots[slot]["tiers"] as Array).size()


func pond_rows(pond_id: String) -> int:
	return (ponds[pond_id]["layout"] as Array).size()


func pond_cols(pond_id: String) -> int:
	return String(ponds[pond_id]["layout"][0]).length()


func spot_at(pond_id: String, cell: Vector2i) -> String:
	var layout: Array = ponds[pond_id]["layout"]
	if cell.y < 0 or cell.y >= layout.size():
		return "."
	var row: String = layout[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return "."
	return row[cell.x]


func is_fishable(pond_id: String, cell: Vector2i) -> bool:
	var ch := spot_at(pond_id, cell)
	return spot_types.has(ch) and bool(spot_types[ch].get("fishable", false))


func fishable_cells(pond_id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in pond_rows(pond_id):
		for x in pond_cols(pond_id):
			if is_fishable(pond_id, Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out
