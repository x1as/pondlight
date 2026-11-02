extends Node
## Headless test suite. Run:  godot --headless --path pondlight res://tests/test_runner.tscn
## Exit code = number of failed checks. Uses a separate save folder, never the player's save.

var failures := 0
var checks := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 12345
	Save.save_dir = "user://test_saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Save.save_dir))
	for f in ["save.json", "save.bak.json", "save.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.save_dir.path_join(f)))
	print("=== PONDLIGHT TESTS ===")
	test_scripts_compile()
	test_rarity_table()
	test_species_independence()
	test_habitats()
	test_visual_rules()
	test_selector()
	test_valuation()
	test_fight()
	test_economy()
	test_progression_and_unlock()
	test_save_load()
	test_talents()
	test_trophies()
	test_tide_and_treasure()
	test_gear_gating()
	test_engagement()
	test_localization()
	test_balance_simulation()
	print("=== %d checks, %d failures ===" % [checks, failures])
	get_tree().quit(failures)


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		printerr("  FAIL ", what)


func _all_scripts(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_all_scripts(dir.path_join(sub), out)


func test_scripts_compile() -> void:
	print("[scripts]")
	var files: Array[String] = []
	_all_scripts("res://scripts", files)
	for f in files:
		var s: GDScript = load(f)
		check(s != null and s.can_instantiate(), "compiles: " + f)


func test_rarity_table() -> void:
	print("[rarity]")
	var anchors := {1: [65.0, 25.0, 8.0, 1.8, 0.2], 5: [48.0, 28.0, 16.0, 7.0, 1.0], 10: [28.0, 28.0, 24.0, 15.0, 5.0],
		15: [12.0, 18.0, 25.0, 27.0, 18.0], 20: [0.0, 0.0, 5.0, 45.0, 50.0]}
	for lvl in anchors:
		var w := RarityTable.weights(lvl, 0.0)
		var ok := true
		for i in 5:
			if absf(w[i] * 100.0 - float(anchors[lvl][i])) > 0.0001:
				ok = false
		check(ok, "level %d matches the published anchor row %s" % [lvl, str(anchors[lvl])])
	var mono := true
	var totals := true
	var smooth := true
	var prev: Array[float] = RarityTable.weights(1.0, 0.0)
	var prev_l := -1.0
	for step in range(0, 191):
		var lvl := 1.0 + step * 0.1
		var w := RarityTable.weights(lvl, 0.0)
		var sum := 0.0
		for i in 5:
			sum += w[i]
			if w[i] < -0.0000001:
				totals = false
			if absf(w[i] - prev[i]) > 0.012:
				smooth = false  # no sudden jumps anywhere, including at 5/10/15
		if absf(sum - 1.0) > 0.000001:
			totals = false
		if w[4] < prev_l - 0.0000001:
			mono = false
		prev_l = w[4]
		prev = w
	check(totals, "every level 1..20 (step 0.1) sums to exactly 100%% with no negative tier")
	check(mono, "Legendary odds never decrease as mastery rises")
	check(smooth, "interpolation is smooth (max change < 1.2 pp per 0.1 level)")
	var w20 := RarityTable.weights(20, 0.0)
	check(w20[0] == 0.0 and w20[1] == 0.0, "level 20: no Common or Uncommon catches")
	check(RarityTable.weights(0, 0.0) == RarityTable.weights(1, 0.0) and RarityTable.weights(25, 0.0) == w20, "levels clamp to 1..20")
	var l20_luck := RarityTable.weights(20, 24.0)
	check(absf(l20_luck[4] - 0.5) < 0.000001, "Luck cannot lift Legendary above 50%% at level 20")
	var l1 := RarityTable.weights(1, 0.0)
	var l1_luck := RarityTable.weights(1, 24.0)
	var shift := (l1[0] + l1[1]) - (l1_luck[0] + l1_luck[1])
	check(shift > 0.0 and shift <= 0.03 + 0.000001, "Luck shift is capped at 3 pp (%.3f)" % shift)
	var big_luck := RarityTable.weights(1, 1000.0)
	check(absf((l1[0] + l1[1]) - (big_luck[0] + big_luck[1]) - 0.03) < 0.000001, "even huge Luck stays within the cap")
	var counts := [0, 0, 0, 0, 0]
	for i in 40000:
		counts[RarityTable.roll(rng, 20, 0.0)] += 1
	check(absf(counts[4] / 40000.0 - 0.5) < 0.015 and absf(counts[3] / 40000.0 - 0.45) < 0.015 and counts[0] == 0 and counts[1] == 0,
		"rolled L20: %.3f Legendary, %.3f Epic, no Common/Uncommon" % [counts[4] / 40000.0, counts[3] / 40000.0])


func test_species_independence() -> void:
	print("[mastery independence]")
	Save.new_game()
	for i in 400:
		Progression.register_catch({"species": "bluegill", "rarity": 4, "weight": 0.2, "value": 6, "pond": "willow"})
	check(Progression.level("bluegill") == 20, "Bluegill reaches mastery 20 (got %d)" % Progression.level("bluegill"))
	check(Progression.level("river_perch") == 1, "River Perch stays at level 1")
	var blue := RarityTable.weights(Progression.level("bluegill"), 0.0)
	var perch := RarityTable.weights(Progression.level("river_perch"), 0.0)
	check(absf(blue[4] - 0.5) < 0.000001 and absf(perch[4] - 0.002) < 0.000001, "rarity odds follow each species' own level")
	for id in Data.fish_order:
		if id != "bluegill":
			check(Progression.level(id) == 1, "%s untouched by Bluegill mastery" % id)
	var f := Progression.register_catch({"species": "river_perch", "rarity": 0, "weight": 0.3, "value": 6, "pond": "willow"})
	check(int(f["xp"]) <= int(Data.balance["mastery"]["max_xp_per_catch"]) and int(f["xp"]) > 1, "discovery XP bonus applied and capped (%d)" % int(f["xp"]))
	var max_lv := Progression.max_level()
	Progression.register_catch({"species": "bluegill", "rarity": 4, "weight": 9.0, "value": 6, "pond": "willow"})
	check(Progression.level("bluegill") == max_lv and int(Progression.entry("bluegill")["xp"]) == 0, "mastery is capped at 20")


func test_habitats() -> void:
	print("[habitat cells]")
	var ctx := {"phase": "day", "weather": "clear", "bait": "worm", "discovered": {}, "bad_luck": 0}
	for pid in Data.pond_order:
		check(Data.pond_cols(pid) == 8 and Data.pond_rows(pid) == 6, "%s uses the 8x6 logical grid" % pid)
		var kinds := {}
		for c in Data.fishable_cells(pid):
			kinds[Data.spot_at(pid, c)] = true
		check(kinds.size() >= 4, "%s has %d distinct fishable habitats" % [pid, kinds.size()])
	var pairs := [["willow", "golden_tench", "m", "~"], ["willow", "moonlit_eel", "n", "p"], ["willow", "willow_pike", "=", "p"],
		["willow", "bluegill", "p", "="], ["willow", "river_perch", "r", "m"], ["willow", "silver_carp", "=", "r"],
		["frostmere", "frost_sturgeon", "O", "o"], ["frostmere", "glass_pike", "v", "o"], ["frostmere", "ice_minnow", "o", "O"],
		["delta", "arapaima", "B", "M"], ["delta", "peacock_bass", "V", "B"], ["delta", "piranha", "M", "B"], ["delta", "arowana", "F", "R"],
		["trench", "kraken", "A", "C"], ["trench", "megalodon", "X", "K"], ["trench", "coelacanth", "K", "S"], ["trench", "anglerfish", "W", "C"]]
	for pr in pairs:
		var a := FishSelector.odds(pr[0], pr[2], ctx)
		var b := FishSelector.odds(pr[0], pr[3], ctx)
		var pa := float(a.get(pr[1], 0.0))
		var pb := float(b.get(pr[1], 0.0))
		check(pa > pb * 1.5, "%s: %s far likelier in '%s' (%.2f) than '%s' (%.2f)" % [pr[0], pr[1], pr[2], pa, pr[3], pb])
	# the most likely species differs across the pond
	var leaders := {}
	for c in Data.fishable_cells("willow"):
		var o := FishSelector.odds("willow", Data.spot_at("willow", c), ctx)
		var best := ""
		for k in o:
			if best == "" or float(o[k]) > float(o[best]):
				best = k
		leaders[best] = true
	check(leaders.size() >= 3, "%d different species lead the forecast in different Willow cells" % leaders.size())


func test_visual_rules() -> void:
	print("[rod/line + pond rules]")
	for pid in Data.pond_order:
		var pv := PondView.new()
		add_child(pv)
		pv.build(pid)
		var fish_nodes := 0
		var animated := 0
		var stack: Array[Node] = [pv]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is AnimatedSprite2D:
				animated += 1
			if n is Sprite2D and (n as Sprite2D).texture and (n as Sprite2D).texture.resource_path.contains("fish_"):
				fish_nodes += 1
		check(fish_nodes == 0 and animated == 0, "%s: no fish sprites or sprite animations inside the pond" % pid)
		var rod := RodRig.new()
		pv.actor_layer.add_child(rod)
		var pd: Dictionary = Data.ponds[pid]
		rod.configure(Vector2(pd["rod_base"][0], pd["rod_base"][1]), Vector2(pd["dock_tip"][0], pd["dock_tip"][1]))
		var visible := rod.tip().x > 0 and rod.tip().x < 640 and rod.tip().y > 0 and rod.tip().y < 360
		check(visible, "%s: rod tip is on screen at %s" % [pid, rod.tip()])
		var target := pv.cell_center(Data.fishable_cells(pid)[0])
		rod.cast_to(target)
		for i in 90:
			rod._process(1.0 / 60.0)
		check(rod.mode == RodRig.Mode.FLOATING and rod.bobber.distance_to(target) < 2.0, "%s: bobber lands on the target cell" % pid)
		rod.start_fight(target)
		var ok := true
		var max_jump := 0.0
		var prev_tip := rod.tip()
		for i in 240:
			if i % 2 == 0:
				rod.tap()
			if i % 3 == 0:
				rod.strike(i % 6 == 0)
			if i % 7 == 0:
				rod.miss()
			rod.tension = float(i % 40) / 40.0
			rod.fish_point = target + Vector2(sin(i * 0.3) * 10.0, cos(i * 0.2) * 4.0)
			rod._process(1.0 / 60.0)
			var t := rod.tip()
			max_jump = maxf(max_jump, t.distance_to(prev_tip))
			prev_tip = t
			if not (is_finite(t.x) and is_finite(t.y)) or absf(rod.bend) > 1.2 or rod._line_end() != rod.fish_point:
				ok = false
		check(ok, "%s: rapid taps/strikes/misses keep the line attached and the rod finite" % pid)
		check(max_jump < 12.0, "%s: rod tip never teleports under spam (max %.1f px/frame)" % [pid, max_jump])
		pv.queue_free()
	# buffered input: a press during the cooldown still counts
	var m := FightModel.new()
	m.setup(Data.fish["bluegill"], 0, PlayerStats.from_equipment({"rod": 0, "reel": 0, "line": 0, "charm": 0}), 5)
	m.step(0.016, true, false)
	var judged := m.strikes + m.misses
	m.step(0.016, true, false)
	for i in 6:
		m.step(0.016, false, false)
	check(m.strikes + m.misses == judged + 1, "a press inside the cooldown is buffered, not dropped")


func test_selector() -> void:
	print("[selector]")
	var reach := int(Data.tier("rod", 0)["reach"])
	for pid in Data.pond_order:
		var reachable_any := {}
		var rows := Data.pond_rows(pid)
		var tier := 0 if pid == "willow" else (1 if pid == "frostmere" else Data.tier_count("rod") - 1)
		var r := (reach if pid == "willow" else int(Data.tier("rod", tier)["reach"])) - int(Data.ponds[pid].get("reach_offset", 0))
		for c in Data.fishable_cells(pid):
			if rows - 1 - c.y >= r:
				continue
			var odds := FishSelector.odds(pid, Data.spot_at(pid, c), {"phase": "day", "weather": "clear", "bait": "worm", "discovered": {}, "bad_luck": 0})
			var sum := 0.0
			for k in odds:
				sum += float(odds[k])
				if float(odds[k]) > 0.0:
					reachable_any[k] = true
			check(absf(sum - 1.0) < 0.0001, "%s %s odds sum to 1" % [pid, c])
		for id in Data.species_of(pid):
			check(reachable_any.has(id), "%s: %s catchable from reachable cells (rod tier %d)" % [pid, id, tier + 1])
	var a := FishSelector.odds("willow", "m", {"phase": "day", "weather": "clear", "bait": "worm", "discovered": {}, "bad_luck": 0})
	var b := FishSelector.odds("willow", "m", {"phase": "day", "weather": "clear", "bait": "moss_grub", "discovered": {}, "bad_luck": 0})
	check(float(b["golden_tench"]) > float(a["golden_tench"]), "Moss Grub raises Golden Tench odds on moss")
	var n1 := FishSelector.odds("willow", "k", {"phase": "day", "weather": "clear", "bait": "worm", "discovered": {}, "bad_luck": 0})
	var n2 := FishSelector.odds("willow", "k", {"phase": "night", "weather": "clear", "bait": "worm", "discovered": {}, "bad_luck": 0})
	check(float(n2["moonlit_eel"]) > float(n1["moonlit_eel"]), "Moonlit Eel more likely at night")
	var disc := {"bluegill": true, "river_perch": true, "silver_carp": true, "golden_tench": true, "moonlit_eel": true}
	var p0 := FishSelector.odds("willow", "~", {"phase": "day", "weather": "clear", "bait": "worm", "discovered": disc, "bad_luck": 0})
	var p1 := FishSelector.odds("willow", "~", {"phase": "day", "weather": "clear", "bait": "worm", "discovered": disc, "bad_luck": 10})
	check(float(p1["willow_pike"]) > float(p0["willow_pike"]) * 2.0, "bad-luck protection boosts missing species")


func test_valuation() -> void:
	print("[valuation]")
	var f: Dictionary = Data.fish["bluegill"]
	var v0 := Valuation.value(f, 0, float(f["base_weight"]), 1.0)
	var v4 := Valuation.value(f, 4, float(f["base_weight"]), 1.0)
	check(v0 == int(f["base_value"]), "common base-weight bluegill is worth base value (%d)" % v0)
	check(v4 == int(f["base_value"]) * 8, "legendary multiplies value x8 (%d)" % v4)
	check(Valuation.value(f, 0, float(f["max_weight"]), 1.0) > v0, "heavier specimen is worth more")
	var heavy := 0.0
	var light := 0.0
	for i in 2000:
		light += Valuation.roll_weight(rng, f, 0, 0.0)
		heavy += Valuation.roll_weight(rng, f, 4, 0.0)
	check(heavy > light, "higher rarity rolls heavier fish on average")


# ------------------------------------------------------------------ fight bots
func _bot_fight(species: String, rarity: int, eq: Dictionary, style: String, seed_v: int) -> Dictionary:
	## "skilled" = an attentive human: ~0.22 s reaction lag, timing noise, not every chance taken.
	var m := FightModel.new()
	m.setup(Data.fish[species], rarity, PlayerStats.from_equipment(eq), seed_v)
	var br := RandomNumberGenerator.new()
	br.seed = seed_v * 31 + 7
	var dt := 1.0 / 60.0
	var t := 0.0
	var held := false
	var danger_t := 0.0
	var safe_t := 0.0
	var tap_cd := 0.0
	var cautious := false
	while m.result == "" and t < 60.0:
		var press := false
		match style:
			"skilled":
				var danger := m.state == "surge" or m.state == "final_burst" or m.telegraph > 0.0 or m.tension_ratio() > 0.6
				if danger:
					danger_t += dt
					safe_t = 0.0
				else:
					safe_t += dt
					danger_t = 0.0
				if danger_t > 0.22:
					cautious = true
				elif safe_t > 0.3:
					cautious = false
				held = not cautious and m.state in ["calm", "recovery", "struggle"] and m.tension_ratio() < 0.5
				tap_cd -= dt
				var seen := m.marker + br.randf_range(-0.05, 0.05)
				if tap_cd <= 0.0 and absf(seen - m.zone_center) < m.zone_half * 0.85 and br.randf() < 0.35:
					press = true
					tap_cd = br.randf_range(0.22, 0.4)
			"idle":
				held = false
			"spam":
				press = true
				held = true
		m.step(dt, press, held)
		t += dt
	return {"result": m.result, "time": t}


func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for k in a:
			if not (b as Dictionary).has(k) or not _same(a[k], b[k]):
				return false
		return true
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not _same(a[i], b[i]):
				return false
		return true
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return absf(float(a) - float(b)) < 0.0001
	return a == b


func test_fight() -> void:
	print("[fight]")
	var base := {"rod": 0, "reel": 0, "line": 0, "charm": 0}
	var maxed := {"rod": 9, "reel": 9, "line": 9, "charm": 9}
	var wins := 0
	var t_base := 0.0
	for i in 20:
		var r := _bot_fight("bluegill", 0, base, "skilled", 100 + i)
		if r["result"] == "caught":
			wins += 1
			t_base += float(r["time"])
	check(wins >= 18, "skilled player catches common Bluegill with starter gear (%d/20)" % wins)
	var r_idle := _bot_fight("bluegill", 0, base, "idle", 7)
	check(r_idle["result"] == "escaped", "doing nothing lets the fish escape")
	var spam_ok := 0
	for i in 10:
		if _bot_fight("silver_carp", 1, base, "spam", 300 + i)["result"] == "caught":
			spam_ok += 1
	check(spam_ok <= 3, "mashing the button is punished (spam wins %d/10)" % spam_ok)
	var t_max := 0.0
	var wins_max := 0
	for i in 20:
		var r := _bot_fight("bluegill", 0, maxed, "skilled", 100 + i)
		if r["result"] == "caught":
			wins_max += 1
			t_max += float(r["time"])
	check(wins_max == 20 and t_max / 20.0 < t_base / maxi(1, wins) * 0.85, "upgraded gear makes fights clearly faster (%.1fs vs %.1fs)" % [t_max / 20.0, t_base / maxi(1, wins)])
	var hard_base := 0
	var hard_max := 0
	for i in 20:
		if _bot_fight("willow_pike", 4, base, "skilled", 500 + i)["result"] == "caught":
			hard_base += 1
		if _bot_fight("willow_pike", 4, maxed, "skilled", 500 + i)["result"] == "caught":
			hard_max += 1
	check(hard_max > hard_base, "legendary pike: maxed gear wins more (%d vs %d of 20)" % [hard_max, hard_base])
	check(hard_max >= 14, "legendary pike is beatable with maxed gear (%d/20)" % hard_max)
	# every species is beatable at Rare once the kit matches its power
	var fs := 0
	for id in Data.fish_order:
		var need := FightModel.power_of(Data.fish[id], 2) * 1.1
		var t := 0
		while t < Data.tier_count("rod") - 1 and float(Data.tier("rod", t)["power"]) < need:
			t += 1
		if _bot_fight(id, 2, {"rod": t, "reel": t, "line": t, "charm": 0}, "skilled", 900)["result"] == "caught":
			fs += 1
	check(fs >= Data.fish_order.size() - 1, "every species beatable at Rare with matching gear (%d/%d)" % [fs, Data.fish_order.size()])
	# distinct behaviours
	var m1 := FightModel.new()
	m1.setup(Data.fish["bluegill"], 0, PlayerStats.from_equipment(base), 1)
	var m2 := FightModel.new()
	m2.setup(Data.fish["frost_sturgeon"], 0, PlayerStats.from_equipment(base), 1)
	check(m2.difficulty > m1.difficulty * 1.8 and m2.strength > m1.strength * 2.0, "small fish and giant fish fight differently")


func test_economy() -> void:
	print("[economy]")
	Save.new_game()
	check(Economy.coins() == 0, "new game starts with 0 coins")
	check(Economy.stats().reach == 3, "starter rod reaches the 3 nearest rows")
	var rec := {"species": "bluegill", "rarity": 0, "weight": 0.4, "value": 25, "pond": "willow", "time": 0}
	check(Economy.sell_catch(rec) == 25 and Economy.coins() == 25, "a catch sells for its value on the spot")
	check(Economy.sell_catch(rec) == 0 and Economy.coins() == 25, "the same catch cannot be sold twice")
	check(not Save.profile.has("inventory"), "there is no bag any more")
	check(not Economy.buy_upgrade("rod"), "cannot buy an upgrade without coins")
	Economy.add_coins(10000)
	var before := Economy.stats()
	check(Economy.buy_upgrade("rod"), "rod upgrade purchased")
	var after := Economy.stats()
	check(after.power > before.power and after.reach > before.reach, "rod upgrade raises POWER and REACH")
	check(Economy.coins() == 10025 - int(Data.tier("rod", 1)["cost"]), "upgrade cost deducted exactly")
	Economy.buy_upgrade("reel")
	Economy.buy_upgrade("line")
	Economy.buy_upgrade("charm")
	var s2 := Economy.stats()
	check(s2.reel > before.reel and s2.line > before.line and s2.luck > before.luck, "reel/line/charm upgrades change REEL/LINE/LUCK")
	var c0 := Economy.coins()
	check(Economy.buy_bait("golden_larva") and Economy.bait_count("golden_larva") == 5, "bait pack bought")
	check(Economy.coins() == c0 - int(Data.bait["golden_larva"]["cost"]), "bait cost deducted")
	Economy.select_bait("golden_larva")
	Economy.consume_bait()
	check(Economy.bait_count("golden_larva") == 4, "bait consumed on hook")
	# daily reward cannot be claimed twice
	var tasks := Achievements.daily_tasks()
	tasks[0]["progress"] = tasks[0]["target"]
	var c2 := Economy.coins()
	var got := Achievements.claim_daily(0)
	check(got > 0 and Achievements.claim_daily(0) == 0 and Economy.coins() == c2 + got, "daily bounty pays once")


func test_progression_and_unlock() -> void:
	print("[progression + unlock]")
	Save.new_game()
	check(not Economy.unlock_pond("frostmere"), "Frostmere locked at start")
	var flags := Progression.register_catch({"species": "bluegill", "rarity": 0, "weight": 0.3, "value": 6, "pond": "willow"})
	check(flags["new_species"], "first bluegill is a discovery")
	var f2 := Progression.register_catch({"species": "bluegill", "rarity": 2, "weight": 0.5, "value": 20, "pond": "willow"})
	check(not f2["new_species"] and f2["new_rarity"] and f2["record"], "second catch: new rarity + record")
	for i in 60:
		Progression.register_catch({"species": "bluegill", "rarity": 4, "weight": 0.2, "value": 6, "pond": "willow"})
	check(Progression.level("bluegill") > 5, "mastery levels up from catches (Lv %d)" % Progression.level("bluegill"))
	for id in Data.species_of("willow"):
		Progression.register_catch({"species": id, "rarity": 0, "weight": 1.0, "value": 6, "pond": "willow"})
	check(Progression.discovered_count("willow") == 6, "all six Willow species discovered")
	check(not Economy.unlock_pond("frostmere"), "Frostmere still needs coins")
	Economy.add_coins(int(Data.ponds["frostmere"]["unlock"]["coins"]))
	check(Economy.unlock_pond("frostmere"), "Frostmere unlocked with species + coins")
	check(Economy.coins() == 0 and Economy.is_unlocked("frostmere"), "unlock paid and permanent")
	check(not Economy.unlock_pond("frostmere"), "cannot pay for the unlock twice")
	var fr := Progression.register_catch({"species": "ice_minnow", "rarity": 0, "weight": 0.1, "value": 15, "pond": "frostmere"})
	check(fr["new_species"] and Progression.discovered_count("frostmere") == 1, "Frostmere fish can be caught and recorded")
	check(Achievements.is_unlocked("FIRST_CATCH") and Achievements.is_unlocked("WILLOW_COMPLETE"), "achievements unlocked by progress")
	for pid in ["delta", "trench"]:
		var src := String(Data.ponds[pid]["unlock"]["species_of"])
		check(not Economy.unlock_pond(pid), "%s locked until %s is complete" % [pid, src])
		for id in Data.species_of(src):
			Progression.register_catch({"species": id, "rarity": 0, "weight": 1.0, "value": 6, "pond": src})
		Economy.add_coins(int(Data.ponds[pid]["unlock"]["coins"]))
		check(Economy.unlock_pond(pid) and Economy.is_unlocked(pid), "%s unlocked after %s" % [pid, src])
	check(Achievements.is_unlocked("UNLOCK_TRENCH"), "reaching the trench awards its trophy")
	check(Progression.completion()["species"] == 18, "codex completion counts species (%d)" % Progression.completion()["species"])


func test_save_load() -> void:
	print("[save/load]")
	Save.new_game()
	Economy.add_coins(1234)
	Economy.add_coins(1)
	Save.profile["equipment"]["reel"] = 2
	Progression.register_catch({"species": "river_perch", "rarity": 1, "weight": 0.7, "value": 16, "pond": "willow"})
	check(Save.save_game(), "save written")
	var snapshot: Dictionary = Save.profile.duplicate(true)
	Save.profile = {}
	check(Save.load_game(), "save loaded after 'restart'")
	check(Economy.coins() == 1235 and int(Save.profile["equipment"]["reel"]) == 2, "coins and equipment restored")
	check(Progression.is_discovered("river_perch"), "codex restored")
	snapshot["stats"]["play_time"] = Save.profile["stats"]["play_time"]
	check(_same(Save.profile, snapshot), "profile identical after reload")
	# corruption -> backup recovery
	Save.save_game()
	var f := FileAccess.open(Save.path_main(), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	Save.profile = {}
	check(Save.load_game() and Economy.coins() == 1235, "corrupted save recovered from backup")
	# missing keys are filled by migration
	var g := FileAccess.open(Save.path_main(), FileAccess.WRITE)
	g.store_string(JSON.stringify({"version": 1, "coins": 77}))
	g.close()
	Save.profile = {}
	check(Save.load_game() and Economy.coins() == 77 and Save.profile.has("codex") and Save.profile.has("equipment"), "old/partial save migrated with defaults")
	# v1 -> v2: the bag is sold and the removed Big Basket talent refunded
	var old := {"version": 1, "coins": 100, "inventory": [{"value": 30}, {"value": 20}], "talents": {"big_basket": 2, "quick_bites": 1},
		"stats": {"coins_earned": 5}}
	var h := FileAccess.open(Save.path_main(), FileAccess.WRITE)
	h.store_string(JSON.stringify(old))
	h.close()
	Save.profile = {}
	var refund := 50 + 40 + int(round(40.0 * 1.6))
	check(Save.load_game() and Economy.coins() == 100 + refund and not Save.profile.has("inventory"), "v1 bag sold on upgrade (+%d)" % refund)
	check(not (Save.profile["talents"] as Dictionary).has("big_basket") and Economy.talent_level("quick_bites") == 1, "removed talent refunded, others kept")
	check(int(Save.profile["version"]) == Save.SAVE_VERSION, "save version bumped to %d" % Save.SAVE_VERSION)
	Save.new_game()
	check(Economy.coins() == 0 and Progression.discovered_count("willow") == 0, "new game resets progress")


func test_balance_simulation() -> void:
	## Simulated players: how many catches / minutes until all Willow species + unlock money.
	print("[balance simulation]")
	var catches_needed: Array[int] = []
	var minutes: Array[float] = []
	for run in 30:
		Save.new_game()
		var r := RandomNumberGenerator.new()
		r.seed = 777 + run
		var n := 0
		var t := 0.0
		var goal := int(Data.ponds["frostmere"]["unlock"]["coins"])
		while n < 600:
			var st := Economy.stats()
			# player aims at the reachable cell with the best odds for something undiscovered
			var best := Vector2i(-1, -1)
			var best_score := -1.0
			var phase := Clock.phase_at(fmod(0.3 + t / 720.0, 1.0))
			var ctx := {"phase": phase, "weather": "clear", "bait": "worm", "discovered": Progression.discovered_map("willow"),
				"bad_luck": int(Save.profile["bad_luck"]["willow"])}
			for c in Data.fishable_cells("willow"):
				if Data.pond_rows("willow") - 1 - c.y >= st.reach:
					continue
				var odds := FishSelector.odds("willow", Data.spot_at("willow", c), ctx)
				var score := 0.0
				for id in odds:
					score += float(odds[id]) * (5.0 if not Progression.is_discovered(id) else 1.0)
				if score > best_score:
					best_score = score
					best = c
			var odds2 := FishSelector.odds("willow", Data.spot_at("willow", best), ctx)
			var id2 := FishSelector.pick(r, odds2)
			var rar := RarityTable.roll(r, Progression.level(id2), st.luck)
			var fight := _bot_fight(id2, rar, Save.profile["equipment"], "skilled", r.randi())
			t += 1.5 + r.randf_range(3.5, 9.0) * 0.85 + float(fight["time"]) + 3.0
			n += 1
			if fight["result"] != "caught":
				continue
			var w := Valuation.roll_weight(r, Data.fish[id2], rar, st.luck)
			var v := Valuation.value(Data.fish[id2], rar, w, 1.08)
			Progression.register_catch({"species": id2, "rarity": rar, "weight": w, "value": v, "pond": "willow"})
			Economy.add_coins(v, true)
			# sensible shopping: buy the cheapest upgrade when affordable while keeping the unlock goal in sight
			for slot in ["rod", "reel", "line"]:
				var cost := Economy.next_cost(slot)
				if cost > 0 and cost <= 600 and Economy.coins() >= cost + 0:
					Economy.buy_upgrade(slot)
			if Progression.discovered_count("willow") == 6 and Economy.coins() >= goal:
				break
		catches_needed.append(n)
		minutes.append(t / 60.0)
	catches_needed.sort()
	minutes.sort()
	var med_n := catches_needed[catches_needed.size() / 2]
	var med_t := minutes[minutes.size() / 2]
	print("  median: %d casts, %.0f min to unlock Frostmere (worst %d casts, %.0f min)" % [med_n, med_t, catches_needed[-1], minutes[-1]])
	check(catches_needed[-1] < 600, "every simulated player completes Willow and affords Frostmere")
	check(med_t > 25.0 and med_t < 90.0, "Frostmere unlock lands in the 25-90 minute window (%.0f min)" % med_t)


func test_talents() -> void:
	print("[talents]")
	Save.new_game()
	var s0 := Economy.stats()
	check(Economy.talent_cost("quick_bites") > 0 and not Economy.buy_talent("quick_bites"), "talents cost coins")
	Economy.add_coins(50000000)
	var c0 := Economy.coins()
	var cost := Economy.talent_cost("quick_bites")
	check(Economy.buy_talent("quick_bites") and Economy.coins() == c0 - cost, "talent bought for its exact price")
	check(Economy.talent_cost("quick_bites") > cost, "next level costs more")
	for id in Data.talents.keys():
		while Economy.buy_talent(id):
			pass
	var s1 := Economy.stats()
	check(Economy.talent_cost("quick_bites") == -1, "talents cap at max level")
	check(s1.wait_cut > s0.wait_cut and s1.reel_bonus > 0.0 and s1.strike_bonus > 0.0 and s1.decay_bonus > 0.0, "fight/patience talents raise stats")
	check(s1.sell_bonus > 0.0 and s1.xp_bonus > 0.0 and s1.perfect_widen > 0.0 and s1.charge_slow > 0.0, "trade/cast talents raise stats")
	check(s1.power > s0.power and s1.reel > s0.reel and s1.line > s0.line, "Angler's Might raises Power, Reel and Line")
	check(s1.reach == s0.reach + 2 and s1.luck > s0.luck and s1.rare_bite > 0.0 and s1.gamble_bonus > 0.0 and s1.chest_bonus > 0.0,
		"Long Arm, Lucky Charm, Whisperer, Nerve and Treasure Nose apply")
	var c := CastModel.new()
	var narrow := c.zone_bounds()
	c.widen_bonus = s1.perfect_widen
	var wide := c.zone_bounds()
	check(float(wide["perfect_hi"]) - float(wide["perfect_lo"]) > float(narrow["perfect_hi"]) - float(narrow["perfect_lo"]), "Steady Hands widens the perfect zone")
	var t_plain := 0.0
	var t_tal := 0.0
	var base := {"rod": 0, "reel": 0, "line": 0, "charm": 0}
	for i in 15:
		var m1 := FightModel.new()
		m1.setup(Data.fish["silver_carp"], 0, PlayerStats.from_equipment(base), 40 + i)
		var m2 := FightModel.new()
		m2.setup(Data.fish["silver_carp"], 0, PlayerStats.from_equipment(base).apply_talents(Save.profile["talents"]), 40 + i)
		for k in 600:
			m1.step(1.0 / 60.0, false, true)
			m2.step(1.0 / 60.0, false, true)
		t_plain += m1.progress
		t_tal += m2.progress
	check(t_tal > t_plain * 1.15, "talented angler reels clearly faster (%.0f vs %.0f)" % [t_tal, t_plain])
	check(Achievements.is_unlocked("TALENT_50"), "talent trophy awarded")


func test_trophies() -> void:
	print("[trophies]")
	Save.new_game()
	check(Data.achievements.size() == 26, "26 trophies defined (%d)" % Data.achievements.size())
	var tiers := {}
	for a in Data.achievements:
		tiers[a["tier"]] = true
	check(tiers.has("bronze") and tiers.has("silver") and tiers.has("gold") and tiers.has("platinum"), "all four trophy tiers used")
	check(not Achievements.is_unlocked("PONDLIGHT_MASTER"), "grand trophy starts locked")
	for a in Data.achievements:
		if String(a["type"]) != "all":
			Save.profile["achievements"][a["id"]] = 1
	Achievements.check_all()
	check(Achievements.trophy_count() == 25 and Achievements.is_unlocked("PONDLIGHT_MASTER"), "collecting all 25 awards the grand trophy")
	for tier in ["bronze", "silver", "gold", "platinum"]:
		check(TrophyPanel.trophy_tex(tier) != null and TrophyPanel.trophy_tex(tier, true) != null, "trophy art exists: " + tier)


func test_tide_and_treasure() -> void:
	print("[tide of fortune + treasure]")
	Save.new_game()
	var t := TideModel.new().setup(1000, 0.0, 77)
	var covered := 0.0
	for seg in t.segments:
		covered += float(seg["to"]) - float(seg["from"])
	check(absf(covered - 1.0) < 0.0001 and float(t.segments[0]["from"]) == 0.0, "wave segments tile the whole bar")
	var ev := t.expected_mult()
	check(ev > 0.95 and ev < 1.2, "a blind stop is roughly break-even (EV x%.2f)" % ev)
	var t2 := TideModel.new().setup(1000, 0.5, 77)
	check(t2.expected_mult() > ev, "Gambler's Nerve widens the winning waves (x%.2f)" % t2.expected_mult())
	var lost := 0
	var rounds_ok := true
	for i in 300:
		var m := TideModel.new().setup(100, 0.0, 1000 + i)
		var waves := 0
		while m.can_ride():
			m.pos = rng.randf()
			m.stop()
			waves += 1
		if m.lost:
			lost += 1
			rounds_ok = rounds_ok and m.pot == 0
		rounds_ok = rounds_ok and waves <= m.rounds()
	check(rounds_ok, "at most 3 waves; a bust always empties the pot")
	check(lost > 60 and lost < 260, "riding every wave is a real risk (%d/300 busts)" % lost)
	var m2 := TideModel.new().setup(100, 0.0, 5)
	var inside := true
	for k in 200:
		m2.step(0.05)
		inside = inside and m2.pos >= 0.0 and m2.pos <= 1.0
	check(inside, "the bobber stays on the wave bar")
	var rec := {"species": "bluegill", "rarity": 0, "weight": 0.4, "value": 40, "pond": "willow", "time": 0}
	var c0 := Economy.coins()
	check(Economy.sell_catch(rec, 120) == 120 and Economy.coins() == c0 + 120, "a winning tide pays the pot")
	check(Economy.sell_catch(rec, 999) == 0, "the pot can be paid only once")
	var rec2 := {"species": "bluegill", "rarity": 0, "weight": 0.4, "value": 40, "pond": "willow", "time": 0}
	check(Economy.sell_catch(rec2, 0) == 0 and bool(rec2["paid"]), "a bust settles the catch for nothing")
	var r := RandomNumberGenerator.new()
	r.seed = 9
	var chests := 0
	var coins_before := Economy.coins()
	for i in 4000:
		if not Economy.roll_treasure(r, "willow", "worm").is_empty():
			chests += 1
	check(chests > 60 and chests < 200, "treasure chests are rare (%d / 4000)" % chests)
	check(Economy.coins() > coins_before and int(Save.profile["stats"]["chests"]) == chests, "chest loot is paid and counted")
	var lucky := 0
	for i in 4000:
		if not Economy.roll_treasure(r, "willow", "lucky_fly").is_empty():
			lucky += 1
	check(lucky > chests * 2, "Lucky Fly triples chest chances (%d vs %d)" % [lucky, chests])
	check(Achievements.is_unlocked("TREASURE_5"), "Treasure Hunter trophy")
	Save.profile["stats"]["tide_best"] = 4.5
	Achievements.check_all()
	check(Achievements.is_unlocked("HIGH_TIDE"), "High Tide trophy")


func test_gear_gating() -> void:
	print("[gear vs fish power]")
	var base := {"rod": 0, "reel": 0, "line": 0, "charm": 0}
	var t5 := {"rod": 4, "reel": 4, "line": 4, "charm": 0}
	var mx := {"rod": 9, "reel": 9, "line": 9, "charm": 9}
	var weak := 0
	var strong := 0
	for i in 12:
		if _bot_fight("willow_pike", 4, base, "skilled", 700 + i)["result"] == "caught":
			weak += 1
		if _bot_fight("willow_pike", 4, t5, "skilled", 700 + i)["result"] == "caught":
			strong += 1
	check(weak <= 2 and strong >= 10, "legendary pike: starter gear %d/12, tier-5 gear %d/12" % [weak, strong])
	var lm := 0
	var lr := 0
	for i in 12:
		if _bot_fight("megalodon", 0, {"rod": 7, "reel": 7, "line": 7, "charm": 0}, "skilled", 800 + i)["result"] == "caught":
			lm += 1
		if _bot_fight("megalodon", 0, mx, "skilled", 800 + i)["result"] == "caught":
			lr += 1
	check(lm <= 2 and lr >= 10, "Megalodon needs top gear (tier 8: %d/12, tier 10: %d/12)" % [lm, lr])
	var a := FightModel.match_info(PlayerStats.from_equipment(base), Data.fish["bluegill"], 0)
	var b := FightModel.match_info(PlayerStats.from_equipment(base), Data.fish["frost_sturgeon"], 4)
	check(String(a[0]) == "Easy" and String(b[0]) == "Too strong", "difficulty labels: %s vs bluegill, %s vs legendary sturgeon" % [a[0], b[0]])
	var pv := PondView.new()
	add_child(pv)
	pv.build("trench")
	var far := Vector2i(3, 0)
	check(not pv.is_reachable(far, int(Data.tier("rod", 6)["reach"])) and pv.is_reachable(far, int(Data.tier("rod", 9)["reach"])),
		"the far Abyss needs the best rods")
	pv.queue_free()


func test_engagement() -> void:
	print("[orders, traps, prismatic]")
	Save.new_game()
	check(Orders.list().size() == int(Data.balance["orders"]["active"]), "three Captain's Orders are always open")
	var target := -1
	var reward := 0
	for o in Orders.list():
		if String(o["type"]) == "perfect_cast":
			target = int(o["target"])
			reward = int(o["reward"])
	if target < 0:
		Save.profile["orders"][0] = {"type": "perfect_cast", "tmpl": "Land {n} perfect casts", "target": 2, "progress": 0, "pond": "willow", "reward": 50}
		target = 2
		reward = 50
	var c0 := Economy.coins()
	for i in target:
		Orders.on_perfect_cast()
	check(Economy.coins() == c0 + reward and int(Save.profile["stats"]["orders_done"]) == 1, "a finished order pays its reward once (+%d)" % reward)
	check(Orders.list().size() == 3, "a new order replaces the finished one")
	for o in Orders.list():
		check(not Orders.text(o).contains("{"), "order text is filled in: " + Orders.text(o))
	check(Economy.trap_haul(60.0) == 0, "no trap haul for a short break")
	var h8 := Economy.trap_haul(8.0 * 3600.0)
	check(h8 > 0 and Economy.trap_haul(100.0 * 3600.0) == h8, "fish traps fill up to the 8 h cap (%d coins)" % h8)
	Economy.add_coins(int(Data.ponds["frostmere"]["unlock"]["coins"]))
	for id in Data.species_of("willow"):
		Progression.register_catch({"species": id, "rarity": 0, "weight": 1.0, "value": 6, "pond": "willow"})
	Economy.unlock_pond("frostmere")
	check(Economy.trap_haul(8.0 * 3600.0) > h8, "every unlocked water adds traps")
	var c1 := Economy.coins()
	check(Economy.claim_traps(500) == 500 and Economy.coins() == c1 + 500, "trap haul is paid")
	Save.profile["last_seen"] = int(Time.get_unix_time_from_system()) - 7200
	var f := FileAccess.open(Save.path_main(), FileAccess.WRITE)
	f.store_string(JSON.stringify(Save.profile))
	f.close()
	Save.profile = {}
	Save.load_game()
	check(absf(Save.away_seconds - 7200.0) < 30.0, "time away is measured at load (%.0f s)" % Save.away_seconds)
	var fl := Progression.register_catch({"species": "bluegill", "rarity": 0, "weight": 0.3, "value": 30, "pond": "willow", "prismatic": true})
	check(int(Progression.entry("bluegill")["prismatic"]) == 1 and Achievements.is_unlocked("PRISMATIC"), "prismatic catches are collected and earn their trophy")
	check(int(fl["xp"]) > 0, "prismatic catches give mastery XP")


func test_localization() -> void:
	print("[localization]")
	check(Loc.message_count("ru") > 350, "Russian translation loaded (%d strings)" % Loc.message_count("ru"))
	var prev := Loc.current
	Loc.apply("ru")
	var missing := []
	for id in Data.fish_order:
		if Data.fish_name(id) == String(Data.fish[id]["name"]):
			missing.append(id)
	for pid in Data.pond_order:
		if Data.pond_name(pid) == String(Data.ponds[pid]["name"]):
			missing.append(pid)
	for a in Data.achievements:
		if UIKit.T(a["name"]) == String(a["name"]) or UIKit.T(a["desc"]) == String(a["desc"]):
			missing.append(a["id"])
	for t in Data.talents.values():
		if UIKit.T(t["name"]) == String(t["name"]):
			missing.append(t["id"])
	check(missing.is_empty(), "every fish, pond, trophy and talent is translated %s" % str(missing))
	check(UIKit.T("PERFECT") == "ИДЕАЛЬНО" and UIKit.T("%.2f kg") % 1.5 == "1.50 кг", "UI strings and formats translate")
	var font := UIKit.font()
	var all_glyphs := true
	for ch in "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя":
		if not font.has_char(ch.unicode_at(0)):
			all_glyphs = false
	check(all_glyphs, "pixel font has every Cyrillic letter")
	Loc.apply(prev)
	check(UIKit.T("PERFECT") == "PERFECT" or prev == "ru", "switching back restores English")
