class_name Valuation
extends RefCounted
## Specimen weight roll and sale value.
##
## value = base_value x weight_mult x rarity_mult x quality


static func roll_weight(rng: RandomNumberGenerator, species: Dictionary, rarity_idx: int, luck: float) -> float:
	var v: Dictionary = Data.balance["valuation"]
	var exp_ := float(Data.rarity(rarity_idx)["weight_exp"]) * maxf(0.5, 1.0 - luck * float(v["luck_weight_exp_reduction"]))
	var u := pow(rng.randf(), exp_)
	var w := lerpf(float(species["min_weight"]), float(species["max_weight"]), u)
	return snappedf(w, 0.01)


static func weight_mult(species: Dictionary, weight: float) -> float:
	var v: Dictionary = Data.balance["valuation"]
	var m := pow(weight / float(species["base_weight"]), float(v["weight_exponent"]))
	return clampf(m, float(v["weight_mult_min"]), float(v["weight_mult_max"]))


static func quality(perfect_cast: bool, precision: float) -> float:
	var v: Dictionary = Data.balance["valuation"]
	var q := 1.0 + clampf(precision, 0.0, 1.0) * float(v["quality_per_precision"])
	if perfect_cast:
		q += float(v["quality_perfect_cast"])
	return q


static func value(species: Dictionary, rarity_idx: int, weight: float, quality_mod: float) -> int:
	var raw := float(species["base_value"]) * weight_mult(species, weight) * float(Data.rarity(rarity_idx)["value_mult"]) * quality_mod
	return maxi(1, roundi(raw))
