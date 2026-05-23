extends Node
# Autoload singleton. Synthesizes short, chill PCM sounds at startup and plays
# them via a small AudioStreamPlayer pool. If an .ogg with the matching name
# is dropped into res://assets/sfx/, it overrides the synth at load time.

const MIX_RATE: int = 44100
const POOL_SIZE: int = 8
const DEFAULT_VOLUME_DB: float = -8.0
const SFX_DIR: String = "res://assets/sfx/"

var _streams: Dictionary = {}            # name -> AudioStream
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = DEFAULT_VOLUME_DB
		add_child(p)
		_pool.append(p)
	_build_library()

func play(sfx_name: StringName, pitch_var: float = 0.05, volume_db: float = DEFAULT_VOLUME_DB) -> void:
	var stream: AudioStream = _streams.get(sfx_name, null)
	if stream == null:
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = volume_db
	p.play()

# ----- library --------------------------------------------------------------

func _build_library() -> void:
	_streams[&"jump"]      = _load_or_synth("jump",      func(): return _synth_blip(480.0, 620.0, 0.10))
	_streams[&"double_jump"] = _load_or_synth("double_jump", func(): return _synth_blip(620.0, 880.0, 0.11))
	_streams[&"attack"]    = _load_or_synth("attack",    func(): return _synth_whoosh(240.0, 90.0, 0.13))
	_streams[&"attack2"]   = _load_or_synth("attack2",   func(): return _synth_whoosh(280.0, 110.0, 0.15))
	_streams[&"attack3"]   = _load_or_synth("attack3",   func(): return _synth_thump_whoosh(0.20))
	_streams[&"shoot"]     = _load_or_synth("shoot",     func(): return _synth_shot(0.06, 80.0))
	_streams[&"shotgun"]   = _load_or_synth("shotgun",   func(): return _synth_shot(0.14, 55.0))
	_streams[&"hurt"]      = _load_or_synth("hurt",      func(): return _synth_blip(320.0, 160.0, 0.18))
	_streams[&"die"]       = _load_or_synth("die",       func(): return _synth_blip(260.0, 70.0, 0.55))
	_streams[&"pickup"]    = _load_or_synth("pickup",    func(): return _synth_chime())

func _load_or_synth(sfx_name: String, synth: Callable) -> AudioStream:
	var path := SFX_DIR + sfx_name + ".ogg"
	if ResourceLoader.exists(path):
		var s: AudioStream = load(path) as AudioStream
		if s != null:
			return s
	return synth.call() as AudioStream

# ----- synth primitives -----------------------------------------------------

# Build an AudioStreamWAV from an array of floats in [-1, 1].
func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: float = clampf(samples[i], -1.0, 1.0)
		var s16: int = int(round(v * 32767.0))
		if s16 < 0:
			s16 += 65536
		bytes[i * 2]     = s16 & 0xFF
		bytes[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream

# Soft sine sweep with exponential decay envelope. "Chill" = sine, not square.
func _synth_blip(f_start: float, f_end: float, duration: float) -> AudioStreamWAV:
	var n: int = int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var f: float = lerpf(f_start, f_end, t)
		phase += TAU * f / MIX_RATE
		var env: float = exp(-3.5 * t) * (1.0 - exp(-60.0 * t))  # quick attack + decay
		out[i] = sin(phase) * env * 0.6
	return _to_stream(out)

# Low filtered noise + low sine — feels like a swing through air.
func _synth_whoosh(f_start: float, f_end: float, duration: float) -> AudioStreamWAV:
	var n: int = int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var f: float = lerpf(f_start, f_end, t)
		phase += TAU * f / MIX_RATE
		var noise: float = randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.08)  # lowpass — kills the harsh hiss
		var env: float = exp(-4.0 * t) * (1.0 - exp(-50.0 * t))
		out[i] = (sin(phase) * 0.55 + lp * 0.45) * env * 0.55
	return _to_stream(out)

# Heavier slow swing for the combo finisher.
func _synth_thump_whoosh(duration: float) -> AudioStreamWAV:
	var n: int = int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var f: float = lerpf(180.0, 60.0, t)
		phase += TAU * f / MIX_RATE
		var noise: float = randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.05)
		var env: float = exp(-3.2 * t) * (1.0 - exp(-40.0 * t))
		out[i] = (sin(phase) * 0.65 + lp * 0.35) * env * 0.65
	return _to_stream(out)

# Soft muffled "pop" — low thump + filtered noise. Not a sharp click.
func _synth_shot(duration: float, thump_hz: float) -> AudioStreamWAV:
	var n: int = int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var f: float = lerpf(thump_hz * 2.0, thump_hz, t)
		phase += TAU * f / MIX_RATE
		var noise: float = randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.18)  # softer lowpass than whoosh — slight body
		var env: float = exp(-9.0 * t) * (1.0 - exp(-200.0 * t))
		out[i] = (sin(phase) * 0.7 + lp * 0.55) * env * 0.7
	return _to_stream(out)

# Two-tone bell (major third) for pickups — pleasant, not jingle-y.
func _synth_chime() -> AudioStreamWAV:
	var duration: float = 0.30
	var n: int = int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var p1: float = 0.0
	var p2: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		p1 += TAU * 660.0 / MIX_RATE
		p2 += TAU * 830.0 / MIX_RATE
		var env: float = exp(-3.0 * t) * (1.0 - exp(-80.0 * t))
		out[i] = (sin(p1) + sin(p2) * 0.7) * env * 0.35
	return _to_stream(out)
