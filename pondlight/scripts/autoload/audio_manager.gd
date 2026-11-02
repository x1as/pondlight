extends Node
## Sound effects pool, music and two ambient layers (base + weather) with cross-fades.

const SFX: Array[String] = [
	"ui_hover", "ui_click", "ui_open", "ui_close", "cast_charge", "cast_release", "splash", "plop", "bite",
	"reel", "strike_good", "strike_perfect", "strike_miss", "tension", "surge", "escape", "line_snap",
	"catch", "catch_rare", "catch_legendary", "sell", "purchase", "unlock", "discovery", "levelup",
]

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _amb: Array[AudioStreamPlayer] = []
var _current_music := ""
var _current_amb := ["", ""]
var _loops: Dictionary = {}
var _last_play: Dictionary = {}
var _fades: Array[Tween] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in SFX:
		_streams[n] = load(UIKit.T("res://assets/audio/sfx/%s.wav") % n)
	for i in 12:
		var pl := AudioStreamPlayer.new()
		pl.bus = "SFX"
		add_child(pl)
		_pool.append(pl)
	_music = _make_loop_player("Music")
	_amb = [_make_loop_player("Ambient"), _make_loop_player("Ambient")]


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	# stop and release every stream so the engine shuts down without leaked playbacks
	for tw in _fades:
		if tw.is_valid():
			tw.kill()
	_fades.clear()
	var all: Array[AudioStreamPlayer] = []
	all.append_array(_pool)
	all.append_array(_amb)
	all.append(_music)
	for pl in all:
		if pl != null:
			pl.stop()
			pl.stream = null
	_loops.clear()
	_streams.clear()


func _make_loop_player(bus: String) -> AudioStreamPlayer:
	var pl := AudioStreamPlayer.new()
	pl.bus = bus
	pl.volume_db = -80.0
	add_child(pl)
	pl.finished.connect(func() -> void:
		if pl.stream != null and pl.volume_db > -70.0:
			pl.play())
	return pl


func _loop_stream(path: String) -> AudioStream:
	if _loops.has(path):
		return _loops[path]
	var s: AudioStream = load(path)
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	_loops[path] = s
	return s


func play(name: String, pitch_var := 0.06, volume_db := 0.0) -> void:
	if not _streams.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(name, -1000)) < 35:
		return  # prevents stacking when spamming
	_last_play[name] = now
	for pl in _pool:
		if not pl.playing:
			pl.stream = _streams[name]
			pl.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			pl.volume_db = volume_db
			pl.play()
			return


func play_pitched(name: String, pitch: float, volume_db := 0.0) -> void:
	## Exact pitch (rising tallies, combo ladders). Not throttled.
	if not _streams.has(name):
		return
	for pl in _pool:
		if not pl.playing:
			pl.stream = _streams[name]
			pl.pitch_scale = pitch
			pl.volume_db = volume_db
			pl.play()
			return


func music_pitch(p: float) -> void:
	create_tween().tween_property(_music, "pitch_scale", p, 0.6)


func stop(name: String) -> void:
	for pl in _pool:
		if pl.playing and pl.stream == _streams.get(name):
			pl.stop()


func music(name: String) -> void:
	if name == _current_music:
		return
	_current_music = name
	_fade_to(_music, "res://assets/audio/music/%s.wav" % name if name != "" else "", -6.0)


func ambient(base: String, weather_layer: String = "") -> void:
	if base != _current_amb[0]:
		_current_amb[0] = base
		_fade_to(_amb[0], "res://assets/audio/ambient/%s.wav" % base if base != "" else "", -4.0)
	if weather_layer != _current_amb[1]:
		_current_amb[1] = weather_layer
		_fade_to(_amb[1], "res://assets/audio/ambient/%s.wav" % weather_layer if weather_layer != "" else "", -3.0)


func _fade_to(pl: AudioStreamPlayer, path: String, target_db: float) -> void:
	var tw := create_tween()
	_fades = _fades.filter(func(t: Tween) -> bool: return t.is_valid())
	_fades.append(tw)
	tw.tween_property(pl, "volume_db", -80.0, 0.8 if pl.playing else 0.0)
	tw.tween_callback(func() -> void:
		pl.stop()
		if path != "":
			pl.stream = _loop_stream(path)
			pl.play())
	if path != "":
		tw.tween_property(pl, "volume_db", target_db, 1.6).from(-40.0)
