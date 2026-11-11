extends Node
## Tiny synthesiser: builds all sound effects in code at startup, so the project needs no audio files.
## Students can replace any of these with recorded .wav/.ogg files later (see play()).

const RATE := 22050
var streams: Dictionary = {}
var players: Array = []
var next_player: int = 0
var muted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)
	streams["steal"] = _seq([523.0, 659.0, 784.0, 1046.0], 0.09, "square", 0.25)
	streams["big"] = _seq([392.0, 523.0, 659.0, 784.0, 1046.0, 1318.0], 0.11, "square", 0.25)
	streams["bonk"] = _wav(_tone(140.0, 0.18, "saw", 0.5, -80.0))
	streams["honk"] = _wav(_mix(_tone(330.0, 0.3, "square", 0.25), _tone(415.0, 0.3, "square", 0.22)))
	streams["bell"] = _wav(_mix(_tone(1760.0, 0.55, "sine", 0.5), _tone(2637.0, 0.4, "sine", 0.2)))
	streams["squeak"] = _wav(_tone(2300.0, 0.07, "sine", 0.18, -800.0))
	streams["jump"] = _wav(_tone(300.0, 0.25, "tri", 0.4, 500.0))
	streams["land"] = _wav(_tone(90.0, 0.15, "tri", 0.6, -40.0))
	streams["busted"] = _seq([392.0, 370.0, 349.0, 330.0, 311.0], 0.2, "saw", 0.3)
	streams["siren_hi"] = _wav(_tone(880.0, 0.38, "tri", 0.12))
	streams["siren_lo"] = _wav(_tone(660.0, 0.38, "tri", 0.12))
	streams["boost"] = _wav(_tone(120.0, 0.3, "saw", 0.2, 240.0))
	streams["horn"] = _wav(_mix(_mix(_tone(233.0, 0.9, "saw", 0.35), _tone(277.0, 0.9, "saw", 0.3)), _tone(349.0, 0.9, "saw", 0.25)))
	streams["coo"] = _seq([900.0, 1100.0], 0.08, "sine", 0.2)
	streams["splash"] = _wav(_noise(0.5, 0.35))
	streams["crash"] = _wav(_mix(_noise(0.25, 0.5), _tone(110.0, 0.25, "saw", 0.4, -50.0)))
	# richer layered sounds (v2): landing thump = low sine drop + short crunchy noise + rattle
	streams["land"] = _wav(_mix(_mix(_tone(75.0, 0.22, "sine", 0.9, -35.0), _noise(0.09, 0.45)), _rattle(0.18, 0.12)))
	streams["shutter"] = _wav(_mix(_noise(0.05, 0.6), _tone(2400.0, 0.04, "square", 0.08)))
	streams["pickup"] = _seq([784.0, 1175.0, 1568.0], 0.06, "tri", 0.3)
	streams["throw"] = _wav(_tone(500.0, 0.2, "sine", 0.3, -300.0))
	streams["goal"] = _seq([523.0, 659.0, 784.0, 659.0, 784.0, 1046.0], 0.08, "square", 0.22)
	streams["nom"] = _seq([220.0, 196.0, 220.0, 196.0], 0.09, "saw", 0.18)
	# looping beds, started/stopped with set_loop(): wheel rumble on asphalt and the metal grind scrape
	_loops["roll"] = _make_loop(_rumble(1.0), -60.0)
	_loops["grind"] = _make_loop(_scrape(1.0), -60.0)
	_load_custom()

## Real recordings win: put land.wav, grind.ogg, roll.ogg, bell.wav ... into custom/sounds/
## (next to the project, next to the .exe, or in the user data folder) to replace the synth sounds.
func _load_custom() -> void:
	var dirs := preload("res://scripts/custom.gd").folders("sounds")
	for d in dirs:
		var da := DirAccess.open(d)
		if da == null:
			continue
		for f in da.get_files():
			var key := f.get_basename()
			var path := d.path_join(f)
			var st: AudioStream = null
			if f.to_lower().ends_with(".ogg"):
				st = AudioStreamOggVorbis.load_from_file(path)
			elif f.to_lower().ends_with(".wav"):
				st = AudioStreamWAV.load_from_file(path)
			if st == null:
				continue
			if _loops.has(key):
				if st is AudioStreamOggVorbis:
					st.loop = true
				elif st is AudioStreamWAV:
					st.loop_mode = AudioStreamWAV.LOOP_FORWARD
				_loops[key].stream = st
			else:
				streams[key] = st

var _loops: Dictionary = {}

func _make_loop(samples: PackedFloat32Array, vol_db: float) -> AudioStreamPlayer:
	var w := _wav(samples)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = samples.size()
	var p := AudioStreamPlayer.new()
	p.stream = w
	p.volume_db = vol_db
	add_child(p)
	return p

## Turn a looping sound on/off; volume 0..1 and pitch can be updated every frame.
func set_loop(loop_name: String, on: bool, volume: float = 1.0, pitch: float = 1.0) -> void:
	if not _loops.has(loop_name):
		return
	var p: AudioStreamPlayer = _loops[loop_name]
	if on and not muted and volume > 0.01:
		p.volume_db = linear_to_db(clampf(volume, 0.0, 1.0)) - 4.0
		p.pitch_scale = clampf(pitch, 0.3, 3.0)
		if not p.playing:
			p.play()
	elif p.playing:
		p.stop()

func _rattle(dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / n
		out[i] = (randf() * 2.0 - 1.0) * vol * (1.0 if floori(i / 180.0) % 3 == 0 else 0.2) * (1.0 - t)
	return out

func _rumble(dur: float) -> PackedFloat32Array:
	# brown noise + soft periodic clicks from the wheel joints; seamless because it is noise
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var b := 0.0
	for i in n:
		b = clampf(b + randf_range(-0.05, 0.05), -1.0, 1.0) * 0.995
		var click := 0.25 if i % 2756 < 40 else 0.0
		out[i] = b * 0.5 + click * randf_range(-1, 1)
	return out

func _scrape(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var last := 0.0
	for i in n:
		ph += (1900.0 + sin(float(i) / RATE * 37.0) * 300.0) / RATE
		last = lerpf(last, randf_range(-1.0, 1.0), 0.6)
		out[i] = (sin(TAU * ph) * 0.25 + last * 0.35) * (0.8 + 0.2 * sin(float(i) / RATE * 90.0))
	return out

func play(snd: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if muted or not streams.has(snd):
		return
	var p: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = streams[snd]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()

func _tone(freq: float, dur: float, wave: String, vol: float, slide: float = 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := freq + slide * t
		phase += f / RATE
		var x := fmod(phase, 1.0)
		var s := 0.0
		match wave:
			"sine": s = sin(TAU * x)
			"square": s = 1.0 if x < 0.5 else -1.0
			"saw": s = 2.0 * x - 1.0
			"tri": s = 4.0 * abs(x - 0.5) - 1.0
		var env: float = min(1.0, t * 60.0) * pow(1.0 - t, 2.0)
		out[i] = s * vol * env
	return out

func _noise(dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var last := 0.0
	for i in n:
		var t := float(i) / n
		last = lerp(last, randf_range(-1.0, 1.0), 0.35)
		out[i] = last * vol * pow(1.0 - t, 1.5)
	return out

func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n: int = max(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var v := 0.0
		if i < a.size(): v += a[i]
		if i < b.size(): v += b[i]
		out[i] = v
	return out

func _seq(freqs: Array, step: float, wave: String, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for f in freqs:
		out.append_array(_tone(f, step * 1.3, wave, vol).slice(0, int(step * RATE)))
	out.append_array(_tone(freqs[-1], step * 2.0, wave, vol))
	return _wav(out)

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clamp(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
