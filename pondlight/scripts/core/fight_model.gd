class_name FightModel
extends RefCounted
## Skill-based fish fight simulation (no rendering).
##
## Inputs each step: was the action pressed this frame, is it held.
##  * Tap while the marker is inside the target zone  -> progress burst, combo, small tension relief.
##  * Tap outside the zone                            -> tension spike, combo reset.
##  * Hold (after hold_threshold)                     -> continuous reeling; tension depends on fish state.
##  * Release                                         -> tension decays (faster with Control).
## Fish states: calm, struggle, surge (telegraphed), recovery, final_burst (Epic/Legendary).
##
## Gear vs fish: every fish has a power (species power x rarity power). Each stat is compared with it,
## edge = stat / fish power (clamped). Rod power scales strike gain, the reel scales hold progress,
## line strength scales how fast tension builds, and the overall gear rating scales the target zone.
## Under-geared fights against rare fish are genuinely hard; legendaries are easy only with strong gear.

const STATES: Array[String] = ["calm", "struggle", "surge", "recovery"]

var species: Dictionary
var rarity_idx := 0
var stats: PlayerStats
var cfg: Dictionary
var rng := RandomNumberGenerator.new()

var progress := 0.0
var tension := 0.0
var max_tension := 100.0
var time_left := 30.0
var time_limit := 30.0
var state := "calm"
var state_left := 1.5
var telegraph := 0.0
var final_burst_done := false
var marker := 0.0
var marker_dir := 1.0
var zone_center := 0.5
var zone_target := 0.5
var zone_half := 0.12
var combo := 0
var best_combo := 0
var strikes := 0
var perfects := 0
var misses := 0
var hold_time := 0.0
var held := false
var cooldown := 0.0
var _buffered := false
var easing := 1.0  # < 1 makes the fish gentler (first-session onboarding)
var result := ""
var events: Array[Dictionary] = []
var difficulty := 1.0
var strength := 1.0
var fish_power := 10.0
var gain_strike := 1.0
var gain_reel := 1.0
var tension_mult := 1.0
var zone_mult := 1.0


static func power_of(species_def: Dictionary, rarity: int) -> float:
	return float(species_def["fight"]["power"]) * float(Data.rarity(rarity).get("power", 1.0))


static func edge(stat: float, fpower: float) -> float:
	var g: Dictionary = Data.balance["gear"]
	return clampf(stat / maxf(1.0, fpower), float(g["edge_min"]), float(g["edge_max"]))


static func match_info(stats_: PlayerStats, species_def: Dictionary, rarity: int) -> Array:
	## [label, colour, edge] - how the whole kit compares with this fish.
	var e := edge(stats_.gear_rating(), power_of(species_def, rarity))
	for l in Data.balance["gear"]["labels"]:
		if e >= float(l[0]):
			return [String(l[1]), Color(String(l[2])), e]
	return ["Too strong", Color("#ff6f5a"), e]


func setup(species_def: Dictionary, rarity: int, player: PlayerStats, seed_value: int = 0) -> void:
	species = species_def
	rarity_idx = rarity
	stats = player
	cfg = Data.balance["fight"]
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var fight: Dictionary = species["fight"]
	var rar := Data.rarity(rarity)
	difficulty = float(fight["stamina"]) * float(rar["difficulty"])
	strength = float(fight["strength"]) * (1.0 + 0.1 * rarity)
	fish_power = power_of(species_def, rarity)
	var g: Dictionary = Data.balance["gear"]
	gain_strike = pow(edge(player.power, fish_power), float(g["gain_exp"]))
	gain_reel = pow(edge(player.reel, fish_power), float(g["gain_exp"]))
	tension_mult = pow(edge(player.line / 10.0, fish_power), -float(g["tension_exp"]))
	zone_mult = clampf(pow(edge(player.gear_rating(), fish_power), float(g["zone_exp"])), float(g["zone_min"]), float(g["zone_max"]))
	max_tension = 100.0
	time_limit = float(cfg["time_limit"])
	time_left = time_limit
	marker = rng.randf()
	zone_center = rng.randf_range(0.3, 0.7)
	zone_target = zone_center
	_enter("calm")


func _state_cfg() -> Dictionary:
	return cfg["states"][state]


func _enter(s: String) -> void:
	state = s
	var st: Array = species["fight"]["state_time"]
	state_left = rng.randf_range(float(st[0]), float(st[1]))
	if s == "final_burst":
		state_left = float(cfg["final_burst_time"])
	elif s == "surge":
		state_left *= 0.8
	events.append({"type": "state", "state": s})


func _next_state() -> void:
	if state == "surge" or state == "final_burst":
		_enter("recovery" if rng.randf() < 0.6 else "calm")
		return
	var weights: Dictionary = species["fight"]["states"]
	var total := 0.0
	for k in STATES:
		if k != state:
			total += float(weights.get(k, 0))
	var r := rng.randf() * total
	for k in STATES:
		if k == state:
			continue
		r -= float(weights.get(k, 0))
		if r <= 0.0:
			if k == "surge":
				telegraph = float(cfg["telegraph_time"])
				events.append({"type": "telegraph"})
				state = "struggle"
				state_left = telegraph + 0.01
			else:
				_enter(k)
			return
	_enter("calm")


func current_zone_half() -> float:
	var base := float(cfg["base_zone_half"]) + stats.control * float(cfg["zone_per_control"])
	return clampf(base * zone_mult * float(Data.rarity(rarity_idx)["zone_mult"]) * float(_state_cfg()["zone"]), 0.035, 0.3)


func perfect_half() -> float:
	return zone_half * (1.0 - float(cfg["perfect_threshold"]))


func step(delta: float, pressed: bool, is_held: bool) -> void:
	if result != "":
		return
	time_left -= delta
	cooldown = maxf(0.0, cooldown - delta)
	# --- behaviour state machine
	if telegraph > 0.0:
		telegraph -= delta
		if telegraph <= 0.0:
			_enter("surge")
	else:
		state_left -= delta
		if state_left <= 0.0:
			_next_state()
	var fb_allowed := bool(Data.rarity(rarity_idx)["final_burst"])
	if fb_allowed and not final_burst_done and progress >= float(cfg["final_burst_at"]):
		final_burst_done = true
		telegraph = 0.0
		_enter("final_burst")
	var sc := _state_cfg()
	# --- timing marker & target zone
	var fight: Dictionary = species["fight"]
	var speed := float(cfg["marker_base_speed"]) * float(fight["marker_speed"]) * float(sc["marker"]) * (1.0 + 0.08 * rarity_idx)
	marker += marker_dir * speed * delta
	if marker > 1.0:
		marker = 2.0 - marker
		marker_dir = -1.0
	elif marker < 0.0:
		marker = -marker
		marker_dir = 1.0
	zone_half = current_zone_half()
	var drift := float(fight["zone_drift"])
	if absf(zone_center - zone_target) < 0.01:
		zone_target = clampf(zone_center + rng.randf_range(-0.35, 0.35) * drift, zone_half, 1.0 - zone_half)
	zone_center = move_toward(zone_center, zone_target, delta * (0.08 + 0.25 * drift) * float(sc["marker"]))
	zone_center = clampf(zone_center, zone_half, 1.0 - zone_half)
	# --- strike: a press during the short cooldown is buffered, never dropped
	if pressed and cooldown > 0.0:
		_buffered = true
	if (pressed or _buffered) and cooldown <= 0.0:
		_buffered = false
		cooldown = float(cfg["strike_cooldown"])
		var d := absf(marker - zone_center)
		if d <= zone_half:
			var q := 1.0 - d / zone_half
			var perfect := q >= float(cfg["perfect_threshold"])
			strikes += 1
			if perfect:
				perfects += 1
			var gain := float(cfg["strike_gain"]) * gain_strike * (1.0 + stats.strike_bonus) * (1.0 + (float(cfg["perfect_bonus"]) if perfect else 0.0))
			gain *= 1.0 + combo * float(cfg["combo_step"])
			progress += gain / difficulty
			tension = maxf(0.0, tension - float(cfg["strike_relief"]))
			combo = mini(combo + 1, int(cfg["combo_max"]))
			best_combo = maxi(best_combo, combo)
			events.append({"type": "strike", "perfect": perfect, "combo": combo, "gain": gain / difficulty})
		else:
			misses += 1
			combo = 0
			tension += float(cfg["miss_tension"]) * strength * tension_mult * easing
			events.append({"type": "miss"})
	# --- hold to reel
	if is_held:
		hold_time += delta
	else:
		hold_time = 0.0
	held = is_held and hold_time >= float(cfg["hold_threshold"])
	var control_mitigation := clampf((stats.control - 10.0) * 0.008, 0.0, 0.3)
	if held:
		progress += float(cfg["reel_rate"]) * gain_reel * (1.0 + stats.reel_bonus) * float(sc["reel"]) * delta / difficulty
		tension += float(sc["hold_tension"]) * strength * tension_mult * delta * (1.0 - control_mitigation) * easing
	else:
		var decay := (float(cfg["tension_decay"]) + stats.control * float(cfg["tension_decay_per_control"])) * (1.0 + stats.decay_bonus)
		tension = maxf(0.0, tension - decay * delta)
	tension += float(sc["idle_tension"]) * strength * tension_mult * delta * easing
	var pull := float(sc["pull"])
	if state == "surge" or state == "final_burst":
		pull *= float(fight["surge_power"])
	progress = maxf(0.0, progress - pull * delta)
	# --- outcome
	if tension >= max_tension:
		tension = max_tension
		result = "snapped"
	elif progress >= 100.0:
		progress = 100.0
		result = "caught"
	elif time_left <= 0.0:
		time_left = 0.0
		result = "escaped"


func apply_onboarding(time_bonus: float, tension_mult: float) -> void:
	time_limit += time_bonus
	time_left += time_bonus
	easing = tension_mult


func precision() -> float:
	var total := strikes + misses
	if total == 0:
		return 0.5
	return (float(strikes) + float(perfects) * 0.5) / (float(total) * 1.5)


func tension_ratio() -> float:
	return tension / max_tension


func pop_events() -> Array[Dictionary]:
	var e := events
	events = []
	return e
