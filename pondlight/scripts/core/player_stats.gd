class_name PlayerStats
extends RefCounted
## The gameplay statistics derived from equipment tiers and talents.
##
## Power, Reel and Line are measured on the same scale as a fish's power (see FightModel):
## a stat equal to the fish's power is a fair fight, half of it is brutal, double is easy.

var power := 10.0
var reel := 10.0
var control := 10.0
var line := 100.0
var luck := 0.0
var reach := 4
# talent bonuses (fractions unless noted)
var perfect_widen := 0.0
var charge_slow := 0.0
var wait_cut := 0.0
var bite_bonus := 0.0
var reel_bonus := 0.0
var strike_bonus := 0.0
var decay_bonus := 0.0
var sell_bonus := 0.0
var xp_bonus := 0.0
var rare_bite := 0.0
var might := 0.0
var gamble_bonus := 0.0
var chest_bonus := 0.0


static func from_equipment(eq: Dictionary) -> PlayerStats:
	var s := PlayerStats.new()
	var rod := Data.tier("rod", int(eq.get("rod", 0)))
	var reel_t := Data.tier("reel", int(eq.get("reel", 0)))
	var line_t := Data.tier("line", int(eq.get("line", 0)))
	var charm := Data.tier("charm", int(eq.get("charm", 0)))
	s.power = float(rod["power"])
	s.control = float(rod["control"]) + float(line_t.get("control", 0))
	s.reach = int(rod["reach"])
	s.reel = float(reel_t["reel"])
	s.line = float(line_t["line"])
	s.luck = float(charm["luck"])
	return s


func apply_talents(levels: Dictionary) -> PlayerStats:
	for id in levels.keys():
		if not Data.talents.has(id):
			continue
		var t: Dictionary = Data.talents[id]
		var v := float(t["per"]) * clampi(int(levels[id]), 0, int(t["max"]))
		match String(t["effect"]):
			"perfect_zone":
				perfect_widen += v
			"charge_slow":
				charge_slow += v
			"wait":
				wait_cut += v
			"bite_window":
				bite_bonus += v
			"reel":
				reel_bonus += v
			"strike":
				strike_bonus += v
			"decay":
				decay_bonus += v
			"sell":
				sell_bonus += v
			"xp":
				xp_bonus += v
			"reach":
				reach += int(v)
			"rare_bite":
				rare_bite += v
			"might":
				might += v
			"luck":
				luck += v
			"gamble":
				gamble_bonus += v
			"chest":
				chest_bonus += v
	if might > 0.0:
		power *= 1.0 + might
		reel *= 1.0 + might
		line *= 1.0 + might
	return self


func gear_rating() -> float:
	## One number for the whole kit: compared with a fish's power to judge a fight.
	return (power + reel + line / 10.0) / 3.0


func to_dict() -> Dictionary:
	return {"power": power, "reel": reel, "control": control, "line": line, "luck": luck, "reach": reach, "gear": gear_rating()}
