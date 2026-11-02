class_name TideModel
extends RefCounted
## Tide of Fortune: push-your-luck on a fresh catch's sale value (in-game coins only).
##
## Each wave the bar is reshuffled into segments (x0, x1, x1.5, x2, x3 by default). A bobber sweeps
## back and forth, faster every wave; the player stops it. x0 means the tide takes the fish.
## After every winning wave the player may cash out or ride the next wave (up to `rounds`).

var segments: Array[Dictionary] = []  # {"mult", "from", "to"} covering 0..1
var pot := 0
var base := 0
var wave := 0
var pos := 0.0
var dir := 1.0
var done := false
var lost := false
var cfg: Dictionary
var widen := 0.0
var rng := RandomNumberGenerator.new()


func setup(value: int, gamble_bonus: float, seed_value: int = 0) -> TideModel:
	cfg = Data.balance["tide"]
	base = value
	pot = value
	widen = gamble_bonus
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_shuffle()
	return self


func rounds() -> int:
	return int(cfg["rounds"])


func speed() -> float:
	var sp: Array = cfg["speeds"]
	return float(sp[mini(wave, sp.size() - 1)])


func _shuffle() -> void:
	## Winning segments get wider with Gambler's Nerve; widths are then normalised to the bar.
	var segs: Array = (cfg["segments"] as Array).duplicate()
	for i in range(segs.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = segs[i]
		segs[i] = segs[j]
		segs[j] = tmp
	var total := 0.0
	var widths: Array[float] = []
	for s in segs:
		var w := float(s["w"]) * (1.0 + (widen if float(s["mult"]) > 0.0 else 0.0))
		widths.append(w)
		total += w
	segments.clear()
	var x := 0.0
	for i in segs.size():
		var w := widths[i] / total
		segments.append({"mult": float(segs[i]["mult"]), "from": x, "to": x + w})
		x += w
	segments[-1]["to"] = 1.0


func step(delta: float) -> void:
	if done:
		return
	pos += dir * speed() * delta
	if pos > 1.0:
		pos = 2.0 - pos
		dir = -1.0
	elif pos < 0.0:
		pos = -pos
		dir = 1.0


func mult_at(x: float) -> float:
	for s in segments:
		if x >= float(s["from"]) and x <= float(s["to"]):
			return float(s["mult"])
	return float(segments[-1]["mult"])


func stop() -> float:
	## Stops the bobber; returns the multiplier hit. The pot is updated.
	var m := mult_at(pos)
	pot = int(round(pot * m))
	wave += 1
	if m <= 0.0:
		lost = true
		done = true
	elif wave >= rounds():
		done = true
	else:
		_shuffle()
	return m


func can_ride() -> bool:
	return not done and wave < rounds()


func total_mult() -> float:
	return float(pot) / maxf(1.0, float(base))


func expected_mult() -> float:
	## Average multiplier of one blind stop (used by tests and the panel's odds line).
	var ev := 0.0
	for s in segments:
		ev += float(s["mult"]) * (float(s["to"]) - float(s["from"]))
	return ev
