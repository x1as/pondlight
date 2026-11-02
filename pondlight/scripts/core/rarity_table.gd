class_name RarityTable
extends RefCounted
## Per-catch rarity roll driven by the species' own mastery level (1..20).
##
## Anchor rows (levels 1/5/10/15/20) come from balance.json and are hit exactly.
## Between anchors each tier is interpolated with a monotone cubic (Fritsch-Carlson),
## which is smooth (no kinks at 5/10/15) and never overshoots, then normalised.
## Luck is a small capped modifier: it moves at most `luck_shift_max` of probability
## from Common/Uncommon to the higher tiers. At level 20 Common/Uncommon are 0,
## so Luck can never lift Legendary above the published 50%.

const COUNT := 5


static func _anchors() -> Array:
	## [[level, [c, u, r, e, l]], ...] sorted by level.
	var raw: Dictionary = Data.balance["rarity_table"]["anchors"]
	var out: Array = []
	for k in raw.keys():
		out.append([int(k), raw[k]])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return out


static func _pchip(xs: Array[float], ys: Array[float], x: float) -> float:
	var n := xs.size()
	if x <= xs[0]:
		return ys[0]
	if x >= xs[n - 1]:
		return ys[n - 1]
	var d: Array[float] = []
	for i in n - 1:
		d.append((ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]))
	var m: Array[float] = []
	m.resize(n)
	m[0] = d[0]
	m[n - 1] = d[n - 2]
	for i in range(1, n - 1):
		if d[i - 1] * d[i] <= 0.0:
			m[i] = 0.0
		else:
			var w1 := 2.0 * (xs[i + 1] - xs[i]) + (xs[i] - xs[i - 1])
			var w2 := (xs[i + 1] - xs[i]) + 2.0 * (xs[i] - xs[i - 1])
			m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])
	for i in [0, n - 1]:
		var k: int = 0 if i == 0 else n - 2
		if d[k] == 0.0 or signf(m[i]) != signf(d[k]):
			m[i] = 0.0
	var seg := 0
	while seg < n - 2 and x > xs[seg + 1]:
		seg += 1
	var h := xs[seg + 1] - xs[seg]
	var t := (x - xs[seg]) / h
	var t2 := t * t
	var t3 := t2 * t
	return (2 * t3 - 3 * t2 + 1) * ys[seg] + (t3 - 2 * t2 + t) * h * m[seg] \
		+ (-2 * t3 + 3 * t2) * ys[seg + 1] + (t3 - t2) * h * m[seg + 1]


static func base_weights(level: float) -> Array[float]:
	var anchors := _anchors()
	var xs: Array[float] = []
	for a in anchors:
		xs.append(float(a[0]))
	var w: Array[float] = []
	var total := 0.0
	for tier in COUNT:
		var ys: Array[float] = []
		for a in anchors:
			ys.append(float(a[1][tier]))
		var v := maxf(0.0, _pchip(xs, ys, clampf(level, xs[0], xs[xs.size() - 1])))
		w.append(v)
		total += v
	for i in COUNT:
		w[i] /= total
	return w


static func weights(level: float, luck: float = 0.0) -> Array[float]:
	var w := base_weights(level)
	var cfg: Dictionary = Data.balance["rarity_table"]
	var shift := minf(maxf(luck, 0.0) * float(cfg["luck_shift_per_point"]), float(cfg["luck_shift_max"]))
	var low := w[0] + w[1]
	if shift > 0.0 and low > 0.0:
		var take := minf(shift, low)
		var high := w[2] + w[3] + w[4]
		w[0] -= take * w[0] / low
		w[1] -= take * w[1] / low
		for i in [2, 3, 4]:
			w[i] += take * (w[i] / high if high > 0.0 else 1.0 / 3.0)
	return w


static func roll(rng: RandomNumberGenerator, level: float, luck: float = 0.0) -> int:
	var w := weights(level, luck)
	var r := rng.randf()
	var acc := 0.0
	for i in COUNT:
		acc += w[i]
		if r < acc:
			return i
	for i in range(COUNT - 1, -1, -1):
		if w[i] > 0.0:
			return i
	return 0
