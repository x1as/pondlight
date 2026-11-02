extends Node
## In-game time of day and per-pond weather. Weather only biases odds, never gates fish.

signal phase_changed(phase: String)
signal weather_changed(pond_id: String, weather: String)

var running := false
var _last_phase := ""
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


func c() -> Dictionary:
	return Save.profile["clock"]


func time() -> float:
	return float(c()["time"])


func phase() -> String:
	return phase_at(time())


func phase_at(t: float) -> String:
	var ph: Dictionary = Data.balance["clock"]["phases"]
	for k in ["morning", "day", "evening"]:
		var r: Array = ph[k]
		if t >= float(r[0]) and t < float(r[1]):
			return k
	return "night"


func weather(pond_id: String) -> String:
	return String((c()["weather"] as Dictionary).get(pond_id, "clear"))


func clock_text() -> String:
	var mins := int(time() * 24.0 * 60.0)
	return UIKit.T("%02d:%02d") % [int(mins / 60.0) % 24, mins % 60]


func _process(delta: float) -> void:
	if not running or not Save.profile.has("clock"):
		return
	var cfg: Dictionary = Data.balance["clock"]
	c()["time"] = fmod(time() + delta / float(cfg["day_length"]), 1.0)
	var ph := phase()
	if ph != _last_phase:
		_last_phase = ph
		phase_changed.emit(ph)
	c()["weather_timer"] = float(c()["weather_timer"]) - delta
	if float(c()["weather_timer"]) <= 0.0:
		c()["weather_timer"] = rng.randf_range(float(cfg["weather_min"]), float(cfg["weather_max"]))
		for pid in Data.pond_order:
			var opts: Array = Data.ponds[pid]["weathers"]
			var w: String = opts[0]
			if opts.size() > 1 and rng.randf() < float(cfg["weather_bad_chance"]):
				w = opts[1]
			if w != weather(pid):
				c()["weather"][pid] = w
				weather_changed.emit(pid, w)


func set_weather(pond_id: String, w: String) -> void:
	c()["weather"][pond_id] = w
	weather_changed.emit(pond_id, w)


func daylight() -> Dictionary:
	## Colour grading keyframes over the day: modulate tint and night amount (0..1).
	var t := time()
	var keys := [
		[0.0, Color(0.36, 0.42, 0.68), 1.0],
		[0.18, Color(0.42, 0.45, 0.70), 0.9],
		[0.24, Color(1.0, 0.80, 0.72), 0.2],
		[0.32, Color(1.0, 0.97, 0.92), 0.0],
		[0.62, Color(1.0, 1.0, 0.98), 0.0],
		[0.71, Color(1.0, 0.78, 0.62), 0.15],
		[0.78, Color(0.72, 0.56, 0.72), 0.55],
		[0.84, Color(0.38, 0.43, 0.70), 0.95],
		[1.0, Color(0.36, 0.42, 0.68), 1.0],
	]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if t >= float(a[0]) and t <= float(b[0]):
			var k := (t - float(a[0])) / (float(b[0]) - float(a[0]))
			k = k * k * (3.0 - 2.0 * k)
			return {"tint": (a[1] as Color).lerp(b[1], k), "night": lerpf(float(a[2]), float(b[2]), k)}
	return {"tint": Color.WHITE, "night": 0.0}
