class_name CastModel
extends RefCounted
## Cast charge meter. The marker ping-pongs 0 -> 1 -> 0 while the button is held.

enum Zone { WEAK, NORMAL, PERFECT, OVER }

var charge := 0.0
var _phase := 0.0
var control := 10.0
var widen_bonus := 0.0
var tempo_slow := 0.0


func reset() -> void:
	charge = 0.0
	_phase = 0.0


func update(delta: float) -> void:
	var period := float(Data.balance["cast"]["charge_time"]) * (1.0 + tempo_slow)
	_phase = fmod(_phase + delta / period, 2.0)
	charge = _phase if _phase <= 1.0 else 2.0 - _phase


func zone_bounds() -> Dictionary:
	var z: Dictionary = Data.balance["cast"]["zones"]
	var widen := (control - 10.0) * 0.0015 + widen_bonus * 0.5
	return {
		"weak": float(z["weak"]),
		"perfect_lo": float(z["normal"]) - widen,
		"perfect_hi": float(z["perfect"]) + widen,
	}


func zone_of(v: float) -> Zone:
	var b := zone_bounds()
	if v < b["weak"]:
		return Zone.WEAK
	if v < b["perfect_lo"]:
		return Zone.NORMAL
	if v <= b["perfect_hi"]:
		return Zone.PERFECT
	if v < 0.94:
		return Zone.NORMAL
	return Zone.OVER


func wait_mult(z: Zone) -> float:
	var c: Dictionary = Data.balance["cast"]
	match z:
		Zone.PERFECT:
			return float(c["perfect_wait_mult"])
		Zone.WEAK:
			return float(c["weak_wait_mult"])
		Zone.OVER:
			return float(c["over_wait_mult"])
	return 1.0
