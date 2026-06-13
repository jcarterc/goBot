class_name SoundSynth
extends RefCounted
# Procedurally bakes every sound in the game into AudioStreamWAV buffers.
# No external audio assets — keeps the web export fully self-contained.
# Loops are baked once at a reference pitch and pitch-shifted per bot at runtime.

const RATE := 22050

static var _cache := {}

static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var s := clampf(samples[i], -1.0, 1.0)
		var v := int(s * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

# --- Movement loops (referenced pitch; runtime pitch_scale shifts them) ---

static func walker_loop() -> AudioStreamWAV:
	if _cache.has("walker"):
		return _cache["walker"]
	# Rhythmic square-wave footstep pulse at ~2 Hz.
	var n := RATE  # 1 second loop -> two steps
	var out := PackedFloat32Array()
	out.resize(n)
	var step_len := RATE / 2
	for i in n:
		var t := i % step_len
		var env := clampf(1.0 - float(t) / (step_len * 0.35), 0.0, 1.0)
		var phase := fmod(float(i) * 90.0 / RATE, 1.0)
		var sq := 1.0 if phase < 0.5 else -1.0
		out[i] = sq * env * 0.5
	_cache["walker"] = _wav(out, true)
	return _cache["walker"]

static func roller_loop() -> AudioStreamWAV:
	if _cache.has("roller"):
		return _cache["roller"]
	# Smooth sine hum.
	var n := RATE / 4
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var ph := TAU * 120.0 * float(i) / RATE
		out[i] = (sin(ph) * 0.7 + sin(ph * 2.0) * 0.2) * 0.4
	_cache["roller"] = _wav(out, true)
	return _cache["roller"]

static func flyer_loop() -> AudioStreamWAV:
	if _cache.has("flyer"):
		return _cache["flyer"]
	# High sawtooth with a slow tremolo.
	var n := RATE / 2
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var saw := fmod(float(i) * 320.0 / RATE, 1.0) * 2.0 - 1.0
		var trem := 0.7 + 0.3 * sin(TAU * 6.0 * float(i) / RATE)
		out[i] = saw * trem * 0.3
	_cache["flyer"] = _wav(out, true)
	return _cache["flyer"]

static func movement_loop(bot_type: String) -> AudioStreamWAV:
	match bot_type:
		"walker": return walker_loop()
		"flyer": return flyer_loop()
		_: return roller_loop()

# --- One-shot eat sounds ---

static func eat_sound(bot_type: String) -> AudioStreamWAV:
	match bot_type:
		"walker": return _walker_eat()
		"flyer": return _flyer_eat()
		_: return _roller_eat()

static func _walker_eat() -> AudioStreamWAV:
	if _cache.has("eat_walker"):
		return _cache["eat_walker"]
	# Metallic crunch: high noise burst, fast decay.
	var n := RATE / 6
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var env := exp(-float(i) / (n * 0.18))
		var noise := randf() * 2.0 - 1.0
		var ring := sin(TAU * 900.0 * float(i) / RATE)
		out[i] = (noise * 0.6 + ring * 0.4) * env * 0.7
	_cache["eat_walker"] = _wav(out, false)
	return _cache["eat_walker"]

static func _roller_eat() -> AudioStreamWAV:
	if _cache.has("eat_roller"):
		return _cache["eat_roller"]
	# Zap/pop: sine chirp up then down.
	var n := RATE / 5
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var f := float(i) / n
		var freq := 300.0 + sin(f * PI) * 900.0
		ph += TAU * freq / RATE
		var env := sin(f * PI)
		out[i] = sin(ph) * env * 0.6
	_cache["eat_roller"] = _wav(out, false)
	return _cache["eat_roller"]

static func _flyer_eat() -> AudioStreamWAV:
	if _cache.has("eat_flyer"):
		return _cache["eat_flyer"]
	# Vacuum whoosh: filtered noise swelling then cut.
	var n := RATE / 4
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var f := float(i) / n
		var env := sin(f * PI)
		var noise := randf() * 2.0 - 1.0
		prev = lerpf(prev, noise, 0.15)  # low-pass
		out[i] = prev * env * 0.7
	_cache["eat_flyer"] = _wav(out, false)
	return _cache["eat_flyer"]

static func death_sound() -> AudioStreamWAV:
	if _cache.has("death"):
		return _cache["death"]
	# Descending tone sweep then a short noise explosion.
	var n := RATE
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var f := float(i) / n
		var freq := 600.0 * (1.0 - f * 0.85)
		ph += TAU * freq / RATE
		var tone := sin(ph) * (1.0 - f) * 0.6
		var boom := 0.0
		if f > 0.6:
			boom = (randf() * 2.0 - 1.0) * (1.0 - f) * 1.5
		out[i] = clampf(tone + boom, -1.0, 1.0)
	_cache["death"] = _wav(out, false)
	return _cache["death"]
