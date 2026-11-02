class_name RodRig
extends Node2D
## The fishing rod, reel, line and bobber - drawn every frame at native pixel resolution.
##
## The rod is a chain of segments whose curvature comes from a damped spring:
## taps add impulses (snappy), the spring settles smoothly (no jitter), tension
## and cast charge set the rest pose. All geometry is rounded to whole pixels.

signal landed(pos: Vector2)
signal reeled_in

enum Mode { HANGING, FLYING, FLOATING, FIGHT, REELING, SNAPPED }

const SEGMENTS := 20
const GUIDES := [0.42, 0.59, 0.73, 0.86, 0.96]
# grip colours per rod tier: [light, shade, ring dark, ring light]
const GRIPS := [
	[Color("#c8955a"), Color("#9c6a3a"), Color("#7a4f2a"), Color("#e2b57a")],
	[Color("#c8955a"), Color("#9c6a3a"), Color("#7a4f2a"), Color("#e2b57a")],
	[Color("#d6a96f"), Color("#a87a46"), Color("#7a4f2a"), Color("#f0d29a")],
	[Color("#4a2b17"), Color("#2a170c"), Color("#120c08"), Color("#6b4021")],
	[Color("#4a2b17"), Color("#2a170c"), Color("#c9973a"), Color("#6b4021")],
	[Color("#74492a"), Color("#56361f"), Color("#e2433a"), Color("#946036")],
	[Color("#74492a"), Color("#56361f"), Color("#a8e0e8"), Color("#946036")],
	[Color("#ecd2a0"), Color("#c7a670"), Color("#c9406a"), Color("#fff6dc")],
	[Color("#ecd2a0"), Color("#c7a670"), Color("#46c1ad"), Color("#fff6dc")],
	[Color("#ffd04a"), Color("#c07a1c"), Color("#7a4a12"), Color("#fff0a0")],
]
const SPRING_K := 150.0
const SPRING_DAMP := 13.0
const MAX_BEND_SPEED := 3.0

var base := Vector2(404, 396)
var length := 192.0
var rest_angle := -2.04
var aim_angle := -2.04
var aim_target := -2.04
var bend := 0.0
var bend_vel := 0.0
var charge := 0.0
var tension := 0.0
var crank := 0.0
var crank_speed := 0.0
var reel_held := false

var blank_color := Color("#8f5d32")
var accent_color := Color("#d4a46a")
var reel_color := Color("#8a8f96")
var line_color := Color("#e8e2d0")
var rod_tier := 0  # every tier gets its own look: grip, wraps, guides, butt gem, glowing tip, star shimmer
var _glow_t := 0.0

var mode := Mode.HANGING
var bobber := Vector2.ZERO
var _bob_vel := Vector2.ZERO
var _fly_from := Vector2.ZERO
var _fly_to := Vector2.ZERO
var _fly_t := 0.0
var _fly_dur := 0.5
var _reel_from := Vector2.ZERO
var _reel_t := 0.0
var float_point := Vector2.ZERO
var dip := 0.0
var _dip_target := 0.0
var _float_t := 0.0
var fish_point := Vector2.ZERO
var _snap_t := 0.0
var _tip := Vector2.ZERO
var _pts := PackedVector2Array()
var _bobber_tex: Texture2D
var _bob_sheet: Texture2D
var _bob_frames := 1
var _bob_w := 7
var _water_row := 7
var _reel_tex: Texture2D
var _shake := 0.0
var _idle_t := 0.0


func _ready() -> void:
	# SpriteCook-generated, hand-polished bobber with a 6-frame float loop (see spritecook-assets.json);
	# falls back to the procedural sprite if the files are missing
	if ResourceLoader.exists("res://assets/art/spritecook/bobber.png"):
		_bobber_tex = load("res://assets/art/spritecook/bobber.png")
		_bob_sheet = load("res://assets/art/spritecook/bobber_bob.png")
		_bob_w = _bobber_tex.get_width()
		_bob_frames = int(_bob_sheet.get_width() / _bob_w)
		_water_row = 11
	else:
		_bobber_tex = load("res://assets/art/fx/bobber.png")
	_reel_tex = load("res://assets/art/fx/reel.png")
	_compute_points()
	bobber = _tip + Vector2(0, 12)


func configure(rod_base: Vector2, dock_tip: Vector2) -> void:
	base = rod_base
	var to := dock_tip + Vector2(-2, -6) - base
	rest_angle = to.angle()
	length = to.length()
	aim_angle = rest_angle
	aim_target = rest_angle
	_compute_points()
	bobber = _tip + Vector2(0, 12)
	mode = Mode.HANGING


func set_equipment(eq: Dictionary) -> void:
	var rod := Data.tier("rod", int(eq.get("rod", 0)))
	rod_tier = int(eq.get("rod", 0))
	blank_color = Color(rod["color"])
	accent_color = Color(rod["accent"])
	reel_color = Color(Data.tier("reel", int(eq.get("reel", 0)))["color"])
	line_color = Color(Data.tier("line", int(eq.get("line", 0)))["color"])


# ------------------------------------------------------------------ commands
func aim_at(world: Vector2, amount: float = 0.5) -> void:
	var a := (world - base).angle()
	var diff := wrapf(a - rest_angle, -PI, PI)
	aim_target = clampf(rest_angle + diff * amount, rest_angle - 0.5, rest_angle + 0.5)


func cast_to(target: Vector2) -> void:
	_fly_from = bobber
	_fly_to = target
	_fly_t = 0.0
	_fly_dur = 0.32 + _fly_from.distance_to(target) / 520.0
	mode = Mode.FLYING
	bend_vel += _down_sign() * 9.0  # forward whip
	crank_speed = 40.0


func reel_in() -> void:
	if mode == Mode.HANGING:
		return
	_reel_from = bobber if mode != Mode.FIGHT else fish_point
	_reel_t = 0.0
	mode = Mode.REELING
	crank_speed = 30.0
	dip = 0.0


func nibble() -> void:
	dip = 0.45
	bend_vel += _pull_sign() * 0.8


func bite() -> void:
	_dip_target = 1.0
	bend_vel += _pull_sign() * 2.8
	_shake = 0.3


func clear_bite() -> void:
	_dip_target = 0.0


func start_fight(pos: Vector2) -> void:
	fish_point = pos
	mode = Mode.FIGHT
	bend_vel -= _pull_sign() * 6.0  # hook set: the rod snaps back
	crank_speed = 25.0


func tap() -> void:
	## Instant visual response to every press, before the strike is judged.
	bend_vel -= _pull_sign() * 2.2
	crank += PI * 0.25
	crank_speed = maxf(crank_speed, 12.0)


func celebrate() -> void:
	bend_vel -= _down_sign() * 7.0


func strike(perfect: bool) -> void:
	bend_vel -= _pull_sign() * (5.5 if perfect else 3.8)
	crank += PI * 0.5
	crank_speed = maxf(crank_speed, 18.0)


func miss() -> void:
	bend_vel += _pull_sign() * 4.0
	_shake = 0.18


func snap_line() -> void:
	mode = Mode.SNAPPED
	_snap_t = 0.0
	bend_vel -= _pull_sign() * 10.0
	tension = 0.0


func reset_hanging() -> void:
	mode = Mode.HANGING
	bobber = _tip + Vector2(0, 12)
	_bob_vel = Vector2.ZERO
	dip = 0.0
	_dip_target = 0.0
	tension = 0.0


# ------------------------------------------------------------------ simulation
func _down_sign() -> float:
	var dir := Vector2.from_angle(aim_angle)
	return signf(dir.cross(Vector2.DOWN)) if absf(dir.cross(Vector2.DOWN)) > 0.01 else -1.0


func _pull_sign() -> float:
	var target := _line_end()
	var dir := Vector2.from_angle(aim_angle + bend * 0.5)
	var pull := (target - _tip)
	if pull.length() < 2.0:
		return _down_sign()
	var c := dir.cross(pull.normalized())
	return signf(c) if absf(c) > 0.02 else _down_sign()


func _line_end() -> Vector2:
	match mode:
		Mode.FIGHT:
			return fish_point
		Mode.SNAPPED:
			return _tip + Vector2(0, 10)
	return bobber + Vector2(0, -_water_row)


func _compute_points() -> void:
	_pts.resize(SEGMENTS + 1)
	var p := base
	_pts[0] = p
	var seg := length / SEGMENTS
	for i in range(1, SEGMENTS + 1):
		var s := float(i) / SEGMENTS
		var th := aim_angle + bend * s * s * 1.4
		p += Vector2.from_angle(th) * seg
		_pts[i] = p
	_tip = _pts[SEGMENTS]


func point_at(s: float) -> Vector2:
	var f := clampf(s, 0.0, 1.0) * SEGMENTS
	var i := mini(int(f), SEGMENTS - 1)
	return _pts[i].lerp(_pts[i + 1], f - i)


func dir_at(s: float) -> Vector2:
	var f := clampf(s, 0.0, 1.0) * SEGMENTS
	var i := mini(int(f), SEGMENTS - 1)
	return (_pts[i + 1] - _pts[i]).normalized()


func tip() -> Vector2:
	return _tip


func _process(delta: float) -> void:
	_glow_t += delta
	aim_angle = lerp_angle(aim_angle, aim_target, minf(1.0, delta * 7.0))
	# rest pose of the bend
	var pull := _pull_sign()
	_idle_t += delta
	var target := (0.06 + sin(_idle_t * 1.3) * 0.012) * _down_sign()
	if mode == Mode.FIGHT:
		target = pull * (0.12 + tension * 0.62)
	elif mode == Mode.FLOATING:
		target = pull * (0.06 + dip * 0.22)
	target -= _down_sign() * charge * 0.5
	bend_vel += (target - bend) * SPRING_K * delta
	bend_vel -= bend_vel * SPRING_DAMP * delta
	bend_vel = clampf(bend_vel, -MAX_BEND_SPEED, MAX_BEND_SPEED)  # snappy, but never a teleport
	bend += bend_vel * delta
	bend = clampf(bend, -1.2, 1.2)
	crank_speed = move_toward(crank_speed, 14.0 if reel_held else 0.0, delta * 40.0)
	crank += crank_speed * delta
	_shake = maxf(0.0, _shake - delta)
	_compute_points()
	dip = move_toward(dip, _dip_target, delta * (9.0 if _dip_target > dip else 2.5))
	match mode:
		Mode.HANGING:
			var want := _tip + Vector2(0, 12)
			_bob_vel += (want - bobber) * 60.0 * delta
			_bob_vel *= pow(0.02, delta)
			bobber += _bob_vel * delta
		Mode.FLYING:
			_fly_t += delta / _fly_dur
			var k := minf(_fly_t, 1.0)
			var arc := 26.0 + _fly_from.distance_to(_fly_to) * 0.18
			bobber = _fly_from.lerp(_fly_to, k) + Vector2(0, -arc * 4.0 * k * (1.0 - k))
			if _fly_t >= 1.0:
				bobber = _fly_to
				float_point = _fly_to
				mode = Mode.FLOATING
				_float_t = 0.0
				landed.emit(_fly_to)
		Mode.FLOATING:
			_float_t += delta
			bobber = float_point + Vector2(0, roundf(sin(_float_t * 2.3) * 0.7))
		Mode.REELING:
			_reel_t += delta / 0.38
			var k2 := ease(minf(_reel_t, 1.0), 0.5)
			var hang := _tip + Vector2(0, 12)
			bobber = _reel_from.lerp(hang, k2) + Vector2(0, -10.0 * sin(k2 * PI))
			if _reel_t >= 1.0:
				mode = Mode.HANGING
				_bob_vel = Vector2.ZERO
				reeled_in.emit()
		Mode.SNAPPED:
			_snap_t += delta
			if _snap_t > 0.9:
				reset_hanging()
				reeled_in.emit()
		Mode.FIGHT:
			bobber = fish_point
	queue_redraw()


# ------------------------------------------------------------------ drawing
func _half_width(s: float) -> float:
	if s < 0.2:
		return 3.5
	return lerpf(3.0, 1.0, (s - 0.2) / 0.8)


func _normal(i: int) -> Vector2:
	var a := _pts[maxi(0, i - 1)]
	var b := _pts[mini(SEGMENTS, i + 1)]
	var n := (b - a).normalized().orthogonal()
	if n.y > 0.0:
		n = -n  # always the upper (lit) side
	return n


func _normal_at(sv: float) -> Vector2:
	var f := clampf(sv, 0.0, 1.0) * SEGMENTS
	var i := mini(int(f), SEGMENTS - 1)
	var n := _normal(i).lerp(_normal(i + 1), f - i).normalized()
	return n


func _fill_strip(from_s: float, to_s: float, outer: float, inner: float, off: Vector2, col: Color, extra := 0.0) -> void:
	## Quads along the rod between two offsets (fractions of the half width; +1 = lit edge).
	var samples: Array[float] = [from_s]
	var k := int(floorf(from_s * SEGMENTS)) + 1
	while float(k) / SEGMENTS < to_s:
		samples.append(float(k) / SEGMENTS)
		k += 1
	samples.append(to_s)
	var cols := PackedColorArray([col, col, col, col])
	for j in samples.size() - 1:
		var s0 := samples[j]
		var s1 := samples[j + 1]
		var c0 := point_at(s0) + off
		var c1 := point_at(s1) + off
		var n0 := _normal_at(s0)
		var n1 := _normal_at(s1)
		var h0 := _half_width(s0)
		var h1 := _half_width(s1)
		var e0 := extra * signf(outer)
		var quad := PackedVector2Array([
			c0 + n0 * (h0 * outer + e0), c1 + n1 * (h1 * outer + e0),
			c1 + n1 * (h1 * inner - extra), c0 + n0 * (h0 * inner - extra)])
		draw_primitive(quad, cols, PackedVector2Array())


func _draw() -> void:
	var off := Vector2.ZERO
	if _shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round()
	var ink := Color("#120c08")
	var hi := blank_color.lightened(0.38)
	var dark := blank_color.darkened(0.42)
	# soft shadow cast onto the ground / water
	var shadow := PackedVector2Array()
	for i in range(0, SEGMENTS + 1):
		shadow.append((_pts[i] + Vector2(12, 8)).round())
	draw_polyline(shadow, Color(0.02, 0.06, 0.05, 0.25), 4.0)
	_draw_line_and_bobber(off)
	# outline: full-length polygon one pixel wider than the blank
	_fill_strip(0.0, 1.0, 1.0, -1.0, off, ink, 1.0)
	# blank (tier colour) with shaded underside and a highlight streak
	_fill_strip(0.2, 1.0, 1.0, -1.0, off, blank_color)
	_fill_strip(0.2, 1.0, -0.25, -1.0, off, dark)
	var streak := PackedVector2Array()
	for i in range(int(0.22 * SEGMENTS), int(0.9 * SEGMENTS)):
		var sv := float(i) / SEGMENTS
		streak.append((_pts[i] + off + _normal(i) * _half_width(sv) * 0.5).round())
	draw_polyline(streak, hi, 1.0)
	# grip: cork -> dark leather -> walnut -> ivory -> gold, with rings
	var g: Array = GRIPS[mini(rod_tier, GRIPS.size() - 1)]
	_fill_strip(0.0, 0.2, 1.0, -1.0, off, g[0])
	_fill_strip(0.0, 0.2, -0.3, -1.0, off, g[1])
	for k in range(1, 12):
		var sv := 0.2 * k / 12.0
		var c := point_at(sv) + off
		var n := _normal(int(sv * SEGMENTS))
		var col: Color = g[2] if k % 2 == 0 else g[3]
		draw_line((c + n * 3.0).round(), (c - n * 3.0).round(), col, 1.0)
	# butt cap
	var c2 := point_at(0.01) + off
	var n2 := _normal(0)
	draw_line((c2 + n2 * 4.0).round(), (c2 - n2 * 4.0).round(), Color("#2a1a10"), 2.0)
	# reel seat: steel, then brass from tier 5, gold from tier 8
	var seat := Color("#b0b7bd") if rod_tier < 4 else (Color("#c9973a") if rod_tier < 7 else Color("#ffd04a"))
	_band(0.2, 0.235, seat, seat.darkened(0.45), off)
	# thread wraps in the accent colour: more and doubled on better rods
	for sv in [0.25, 0.42, 0.59, 0.73, 0.86]:
		_band(sv - 0.008, sv + 0.008, accent_color, accent_color.darkened(0.35), off)
		if rod_tier >= 2:
			_band(sv + 0.014, sv + 0.022, accent_color.lightened(0.3), accent_color.darkened(0.2), off)
	# a spiral pinstripe along the blank from tier 4
	if rod_tier >= 3:
		for i in range(int(0.26 * SEGMENTS), int(0.95 * SEGMENTS), 3):
			var sv := float(i) / SEGMENTS
			var side := 0.5 if (i / 3) % 2 == 0 else -0.5
			draw_rect(Rect2((_pts[i] + off + _normal(i) * _half_width(sv) * side).round(), Vector2.ONE), accent_color)
	# guides on the underside (gold rings on the top rods)
	var ring := Color("#d6dbde") if rod_tier < 6 else Color("#ffd04a")
	for sv in GUIDES:
		var gp := (point_at(sv) - _normal(int(sv * SEGMENTS)) * (_half_width(sv) + 2.5) + off).round()
		draw_rect(Rect2(gp - Vector2(1, 1), Vector2(3, 3)), ink)
		draw_rect(Rect2(gp, Vector2(1, 1)), ring)
	# butt gem from tier 6
	if rod_tier >= 5:
		var bc := (point_at(0.02) + off).round()
		draw_rect(Rect2(bc - Vector2(2, 2), Vector2(4, 4)), ink)
		draw_rect(Rect2(bc - Vector2(1, 1), Vector2(2, 2)), accent_color)
		draw_rect(Rect2(bc - Vector2(1, 1), Vector2(1, 1)), accent_color.lightened(0.6))
	var tp := (_tip + off).round()
	draw_rect(Rect2(tp - Vector2(1, 1), Vector2(3, 3)), ink)
	draw_rect(Rect2(tp, Vector2(1, 1)), accent_color)
	# glowing tip from tier 8, star shimmer running along the blank on the last two tiers
	if rod_tier >= 7:
		var pulse := 0.5 + 0.5 * sin(_glow_t * 5.0)
		for o: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_rect(Rect2(tp + o * 2.0, Vector2.ONE), Color(accent_color, 0.35 + pulse * 0.5))
	if rod_tier >= 8:
		for k in 3:
			var sv := fmod(_glow_t * 0.25 + k / 3.0, 1.0) * 0.75 + 0.22
			var sp := (point_at(sv) + off).round()
			var a := sin(fmod(_glow_t * 0.25 + k / 3.0, 1.0) * PI)
			draw_rect(Rect2(sp, Vector2.ONE), Color(1, 1, 1, a))
			draw_rect(Rect2(sp + Vector2(1, 0), Vector2.ONE), Color(accent_color, a * 0.6))
			draw_rect(Rect2(sp - Vector2(1, 0), Vector2.ONE), Color(accent_color, a * 0.6))
	_draw_reel(off)


func _band(a: float, b: float, c: Color, shade: Color, off: Vector2) -> void:
	_fill_strip(a, b, 1.15, -1.15, off, c)
	_fill_strip(a, b, -0.3, -1.15, off, shade)


func _draw_reel(off: Vector2) -> void:
	var ink := Color("#120c08")
	var rp := (_reel_center() + off).round()
	var foot := (point_at(0.215) + off).round()
	draw_line(foot, rp, ink, 4.0)
	draw_line(foot, rp, reel_color.darkened(0.25), 2.0)
	var body := reel_color
	draw_circle(rp, 7.5, ink)
	draw_circle(rp, 6.5, body.darkened(0.35))
	draw_circle(rp + Vector2(-0.5, -0.5), 5.5, body)
	draw_circle(rp, 3.5, body.darkened(0.2))
	draw_arc(rp, 2.5, 0.0, TAU, 12, line_color.darkened(0.1), 1.0)
	draw_rect(Rect2(rp + Vector2(-3, -5), Vector2(2, 1)), body.lightened(0.5))
	draw_rect(Rect2(rp + Vector2(-5, -3), Vector2(1, 2)), body.lightened(0.5))
	draw_rect(Rect2(rp - Vector2(1, 1), Vector2(2, 2)), Color("#d6dbde"))
	var arm := Vector2(cos(crank), sin(crank) * 0.8) * 8.0
	var knob := (rp + arm).round()
	draw_line(rp, knob, ink, 3.0)
	draw_line(rp, knob, body.lightened(0.35), 1.0)
	draw_rect(Rect2(knob - Vector2(2, 2), Vector2(4, 4)), ink)
	draw_rect(Rect2(knob - Vector2(1, 1), Vector2(2, 2)), Color("#d6a96f"))


func _reel_center() -> Vector2:
	return point_at(0.215) - _normal(int(0.215 * SEGMENTS)) * 10.0


func _draw_line_and_bobber(off: Vector2) -> void:
	var lc := line_color
	lc.a = 0.9
	if tension > 0.72:
		lc = line_color.lerp(Color("#ff5a4a"), clampf((tension - 0.72) / 0.28, 0.0, 1.0))
	# reel -> guides -> tip
	var run := PackedVector2Array([(_reel_center() + off).round()])
	for sv in GUIDES:
		run.append((point_at(sv) - _normal(int(sv * SEGMENTS)) * (_half_width(sv) + 2.5) + off).round())
	run.append((_tip + off).round())
	draw_polyline(run, Color(lc, 0.55), 1.0)
	if mode == Mode.SNAPPED:
		# whipping loose end
		var k := clampf(_snap_t / 0.9, 0.0, 1.0)
		var pts := PackedVector2Array()
		for i in 10:
			var t := float(i) / 9.0
			pts.append((_tip + Vector2(sin(t * 6.0 + _snap_t * 18.0) * 6.0 * (1.0 - k), t * 22.0 * (0.4 + k)) + off).round())
		draw_polyline(pts, lc, 1.0)
		return
	var end := _line_end()
	var start := _tip
	var dist := start.distance_to(end)
	var slack := 0.15
	match mode:
		Mode.FLOATING:
			slack = 0.55 - dip * 0.4
		Mode.FIGHT:
			slack = clampf(0.5 - tension * 0.6, 0.0, 0.5)
		Mode.HANGING:
			slack = 0.0
	var sag := clampf(dist * 0.22, 2.0, 34.0) * slack
	var ctrl := start.lerp(end, 0.5) + Vector2(0, sag)
	var vib := Vector2.ZERO
	if mode == Mode.FIGHT and tension > 0.8:
		vib = Vector2(0, 1) * (1.0 if Engine.get_process_frames() % 2 == 0 else -1.0)
	var pts2 := PackedVector2Array()
	var n := int(clampf(dist / 4.0, 6.0, 40.0))
	for i in n + 1:
		var t := float(i) / n
		var p := start.lerp(ctrl, t).lerp(ctrl.lerp(end, t), t)
		if i > 0 and i < n:
			p += vib * sin(t * PI)
		pts2.append((p + off).round())
	draw_polyline(pts2, lc, 1.0)
	if mode == Mode.FIGHT:
		return
	# bobber
	var bp := (bobber + off).round()
	if mode == Mode.FLOATING:
		var half := floorf(_bob_w / 2.0)
		var above := _water_row + 1
		var rows := int(round(above - dip * (above - 2)))
		if rows > 0:
			var tex := _bobber_tex
			var src := Rect2(0, 0, _bob_w, rows)
			if _bob_sheet != null and dip < 0.2:
				# gentle float loop while idle on the water
				tex = _bob_sheet
				src.position.x = (int(_float_t * 8.0) % _bob_frames) * _bob_w
			draw_texture_rect_region(tex, Rect2(bp - Vector2(half, _water_row - (above - rows)), Vector2(_bob_w, rows)), src)
		# waterline glint
		draw_rect(Rect2(bp + Vector2(-half, 1), Vector2(_bob_w, 1)), Color(0.85, 1.0, 0.95, 0.75))
		draw_rect(Rect2(bp + Vector2(-half + 1, 2), Vector2(_bob_w - 2, 1)), Color(0.05, 0.2, 0.22, 0.35))
	else:
		draw_texture(_bobber_tex, bp - Vector2(floorf(_bob_w / 2.0), _water_row))
