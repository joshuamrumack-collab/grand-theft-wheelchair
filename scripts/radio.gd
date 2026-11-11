extends Node
## In-game radio. Three stations whose music is composed and rendered in code
## (rendered once in a background thread, then looped), plus DJ chatter and fake ads.
## Students can replace a station's music with their own track: put an .ogg in
## res://assets/audio/radio_<station id>.ogg and it is used instead.

const RATE := 22050
const STATIONS := [
	{"id": "off", "name": "RADIO OFF"},
	{"id": "wheelfm", "name": "WHEEL FM", "color": Color("ff6fb5"), "bpm": 118.0, "style": "pop",
		"dj": ["Wheel FM! Number one in Los Spokos, number zero in stairs!", "Next up: a song about rolling. They're ALL about rolling.",
			"Traffic report: everything is a ramp if you're brave enough.", "Shout-out to whoever keeps parking cars on the ramps. Not cool."]},
	{"id": "ramp", "name": "RAMP RADIO", "color": Color("ff5a2b"), "bpm": 160.0, "style": "metal",
		"dj": ["RAMP RADIOOOO! TURN IT UP TO ELEVEN KILOMETRES PER HOUR!", "This next track was recorded at the top of a really steep hill.",
			"Metal fact: castor wheels are the drummers of the chair world.", "If your spokes aren't vibrating, it's not loud enough!"]},
	{"id": "smooth", "name": "SMOOTH SPOKES", "color": Color("7ee0ff"), "bpm": 84.0, "style": "jazz",
		"dj": ["Smooth Spokes... for when you want to roll... slowly... with feeling.", "That was 'Cushion of Love' by the Velvet Brakes.",
			"Remember to oil your axles, darling.", "Ooh. That bassline rolls like a fresh set of bearings."]},
	{"id": "bearings808", "name": "BEARINGS 808", "color": Color("ffd84a"), "bpm": 90.0, "style": "pop",
		"dj": ["Bearings 808! The heaviest beats on the lightest wheels!", "Big up everybody chair-jacking responsibly tonight.",
			"That track was so hard the Kerb Patrol filed a noise complaint.", "Seated but not settled - that's the 808 way."]},
	{"id": "kerbcountry", "name": "KERB COUNTRY", "color": Color("e8a87c"), "bpm": 100.0, "style": "pop",
		"dj": ["Kerb Country! Where the music's sad but the ramps are happy.", "Howdy, Los Spokos. Remember: a porch without a ramp is just a fence.",
			"That one goes out to the angry rooster on Route 9.", "Saddle up, partners. Or, you know, sit down. You're already sitting."]},
	{"id": "rueda", "name": "RADIO RUEDA", "color": Color("39ff14"), "bpm": 95.0, "style": "pop",
		"dj": ["Radio Rueda! Que la rueda no para!", "Buenas noches, Los Spokos. Nobody stays on the sidewalk tonight!",
			"That was La Cumbia del Carrito. Yes, it's about a shopping cart.", "Arriba las ruedas! Wheels up, everybody!"]},
	{"id": "neon", "name": "NEON UNDERGLOW FM", "color": Color("00e5ff"), "bpm": 108.0, "style": "pop",
		"dj": ["Neon Underglow FM. Night drive mode: engaged.", "If your chair isn't glowing right now, Pimp My Chair is open late.",
			"Synth fact: every arpeggio is just a staircase that learned to dance.", "Keep it neon, keep it rolling."]},
	{"id": "p4rullstol", "name": "P4 RULLSTOL", "color": Color("ffd000"), "bpm": 128.0, "style": "pop",
		"dj": ["P4 Rullstol - hela Sveriges rullande radio!", "Nästa låt är för alla som har tröttnat på trappor.",
			"Hej Los Spokos! Glöm inte att fika mellan rånen.", "Vi spelar schlager tills borgmästaren bygger en ramp."]},
	{"id": "lofi", "name": "LO-FI CASTOR", "color": Color("b388ff"), "bpm": 75.0, "style": "jazz",
		"dj": ["Lo-fi Castor... beats to roll and relax to.", "It's raining in the hospital car park. Perfect.",
			"Take a deep breath. Unclench your push rims.", "No DJ chatter here. Except this. Sorry."]},
]
const ADS := ["Tired of stairs? So are we. Call 1-800-RAMP-NOW.", "Spoke's Chop Shop. We don't ask questions. We don't even ask your name.",
	"Cushion King's new Memory Foam 9000. It remembers everything. Everything.", "Rolling Pizza! If it's cold, it's free. It's usually cold.",
	"Pimp My Chair: because beige is a crime too.", "The Kerb Patrol is hiring! Must own a chair. Must not steal chairs.",
	"Baron Stairwell for Mayor: 'Stairs build character.' Paid for by Stairs Inc.", "Lost your castor wheel? So did we. Castor Oil Co."]
const MUSIC_DIR := "res://assets/audio/radio/"

var station: int = 0
var player: AudioStreamPlayer
var streams: Dictionary = {}     # station index -> generated loop
var playlists: Dictionary = {}   # station index -> {"songs": [...], "jingles": [...], "order": [...], "pos": 0}
var pending: Dictionary = {}
var buffers: Dictionary = {}
var chatter_t: float = 0.0
var since_jingle: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.volume_db = -7.0
	add_child(player)
	player.finished.connect(_on_song_finished)
	for i in range(1, STATIONS.size()):
		var id: String = STATIONS[i].id
		var songs := _list_audio(MUSIC_DIR + id)
		var jingles := _list_audio(MUSIC_DIR + id + "/jingles")
		if not songs.is_empty():
			var order := range(songs.size())
			order.shuffle()
			playlists[i] = {"songs": songs, "jingles": jingles, "order": order, "pos": 0}

static func _list_audio(dir: String) -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var files: PackedStringArray
	if ResourceLoader.has_method("list_directory"):
		files = ResourceLoader.call("list_directory", dir)
	else:
		files = DirAccess.get_files_at(dir)
	for f in files:
		var fname := f.trim_suffix(".import").trim_suffix(".remap")
		if fname.get_extension().to_lower() in ["mp3", "ogg", "wav"] and not out.has(dir + "/" + fname):
			out.append(dir + "/" + fname)
	return out

func next_station() -> String:
	set_station((station + 1) % STATIONS.size())
	return STATIONS[station].name

func set_station(i: int) -> void:
	station = i
	player.stop()
	if i == 0:
		return
	if playlists.has(i):
		_play_next_song(false)
	elif streams.has(i):
		_play(i)
	elif not pending.has(i):
		var s: Dictionary = STATIONS[i]
		var style: String = s["style"]
		var bpm: float = s["bpm"]
		pending[i] = WorkerThreadPool.add_task(func(): buffers[i] = _render(style, bpm))
	_dj(true)

func _play_next_song(allow_jingle: bool) -> void:
	if Sfx.muted or station == 0 or not playlists.has(station):
		return
	var pl: Dictionary = playlists[station]
	var path: String
	if allow_jingle and not pl.jingles.is_empty() and since_jingle >= 1 and randf() < 0.6:
		path = pl.jingles.pick_random()
		since_jingle = 0
	else:
		path = pl.songs[pl.order[pl.pos]]
		pl.pos = (pl.pos + 1) % pl.songs.size()
		if pl.pos == 0:
			pl.order.shuffle()
		since_jingle += 1
	var st = load(path)
	if st is AudioStream:
		if "loop" in st:
			st.loop = false
		player.stream = st
		player.play()

func _on_song_finished() -> void:
	if playlists.has(station):
		_play_next_song(true)

func _play(i: int) -> void:
	if Sfx.muted:
		return
	player.stream = streams[i]
	player.play()

func _process(delta: float) -> void:
	for i in pending.keys():
		if WorkerThreadPool.is_task_completed(pending[i]):
			WorkerThreadPool.wait_for_task_completion(pending[i])
			pending.erase(i)
			streams[i] = _to_stream(buffers[i])
			buffers.erase(i)
			if station == i:
				_play(i)
	if Sfx.muted and player.playing:
		player.stop()
	elif not Sfx.muted and station > 0 and not player.playing:
		if playlists.has(station):
			_play_next_song(false)
		elif streams.has(station):
			_play(station)
	if station > 0 and GameState.world != null and GameState.world.state == "play" and not get_tree().paused:
		chatter_t -= delta
		if chatter_t <= 0.0:
			_dj(false)

func _dj(first: bool) -> void:
	var s: Dictionary = STATIONS[station]
	chatter_t = randf_range(30.0, 50.0)
	var line: String = s.dj.pick_random() if (first or randf() < 0.55) else ("AD: " + ADS.pick_random())
	GameState.say_sub("RADIO  " + s.name, line, s.color)

# ------------------------------------------------------------------ synthesis
static func _note(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)

static func _tone(buf: PackedFloat32Array, t0: float, dur: float, freq: float, wave: String, vol: float, dist: float = 0.0) -> void:
	var i0 := int(t0 * RATE)
	var n := int(dur * RATE)
	var ph := 0.0
	var inc := freq / RATE
	var lp := 0.0
	for k in n:
		var i := i0 + k
		if i >= buf.size():
			break
		ph += inc
		var x := ph - floorf(ph)
		var s := 0.0
		match wave:
			"sine": s = sin(TAU * x)
			"tri": s = 4.0 * abs(x - 0.5) - 1.0
			"square": s = 1.0 if x < 0.5 else -1.0
			_: s = 2.0 * x - 1.0
		if dist > 0.0:
			s = tanh(s * dist)
			lp += (s - lp) * 0.35
			s = lp
		var t := float(k) / n
		var env: float = min(1.0, k / (RATE * 0.004)) * pow(1.0 - t, 1.6)
		buf[i] += s * vol * env

static func _kick(buf: PackedFloat32Array, t0: float, vol: float) -> void:
	var i0 := int(t0 * RATE)
	var n := int(0.2 * RATE)
	var ph := 0.0
	for k in n:
		var i := i0 + k
		if i >= buf.size():
			break
		var t := float(k) / RATE
		ph += (40.0 + 110.0 * exp(-t * 30.0)) / RATE
		buf[i] += sin(TAU * ph) * vol * exp(-t * 14.0)

static func _noise(buf: PackedFloat32Array, t0: float, dur: float, vol: float, hat: bool, rng: RandomNumberGenerator) -> void:
	var i0 := int(t0 * RATE)
	var n := int(dur * RATE)
	var lp := 0.0
	for k in n:
		var i := i0 + k
		if i >= buf.size():
			break
		var r := rng.randf_range(-1.0, 1.0)
		lp += (r - lp) * (0.15 if hat else 0.5)
		var s := (r - lp) if hat else lp
		buf[i] += s * vol * pow(1.0 - float(k) / n, 2.0)

static func _render(style: String, bpm: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(style)
	var sd := 60.0 / bpm / 4.0
	var bars := 8
	var buf := PackedFloat32Array()
	buf.resize(int(bars * 16 * sd * RATE) + 1)
	var prog: Array
	match style:
		"pop": prog = [[60, 64, 67], [55, 59, 62], [57, 60, 64], [53, 57, 60]]
		"metal": prog = [[40], [36], [38], [35]]
		_: prog = [[62, 65, 69, 72], [55, 59, 62, 65], [60, 64, 67, 71], [57, 61, 64, 67]]
	var mel := [0, 2, 4, 7, 9, 12]
	var melody: Array = []
	for i in 32:
		melody.append(mel[rng.randi() % mel.size()] if rng.randf() < 0.6 else -1)
	for step in bars * 16:
		var st := step % 16
		var bar := floori(step / 16.0) % 4
		var t := step * sd
		var ch: Array = prog[bar]
		match style:
			"pop":
				if st % 4 == 0: _kick(buf, t, 0.55)
				if st == 4 or st == 12: _noise(buf, t, 0.16, 0.35, false, rng)
				if st % 2 == 0: _noise(buf, t, 0.05, 0.15, true, rng)
				if st in [0, 3, 6, 8, 11, 14]: _tone(buf, t, sd * 1.8, _note(ch[0] - 24), "tri", 0.4)
				if st in [2, 6, 10, 14]:
					for n in ch: _tone(buf, t, sd * 1.2, _note(n), "square", 0.045)
				var m: int = melody[floori(step / 2.0) % 32]
				if st % 2 == 0 and m >= 0 and step >= 32: _tone(buf, t, sd * 1.8, _note(72 + m), "square", 0.06)
			"metal":
				if st % 2 == 0 or st == 7 or st == 15: _kick(buf, t, 0.5)
				if st == 4 or st == 12: _noise(buf, t, 0.18, 0.45, false, rng)
				if st % 2 == 1: _noise(buf, t, 0.03, 0.12, true, rng)
				if [1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1][st] == 1:
					_tone(buf, t, sd * 0.9, _note(ch[0]), "saw", 0.12, 6.0)
					_tone(buf, t, sd * 0.9, _note(ch[0] + 7), "saw", 0.08, 6.0)
				if st == 0 and bar == 3: _tone(buf, t, sd * 12.0, _note(ch[0] + 19), "saw", 0.06, 4.0)
			_:
				var sw := sd * 0.35 if st % 2 == 1 else 0.0
				if st % 4 == 0: _tone(buf, t, sd * 3.5, _note(ch[0] - 24 + [0, 3, 5, 7][floori(st / 4.0)]), "sine", 0.45)
				if st == 0 or st == 7 or st == 10:
					for n in ch: _tone(buf, t + sw, sd * 5.0, _note(n), "tri", 0.04)
				if st % 2 == 0 or st % 4 == 3: _noise(buf, t + sw, 0.06, 0.06, true, rng)
				if st == 4 or st == 12: _noise(buf, t, 0.2, 0.08, false, rng)
				if st == 14 and bar % 2 == 1: _tone(buf, t, sd * 4.0, _note(ch[2] + 12), "sine", 0.07)
	var peak := 0.001
	for v in buf:
		peak = max(peak, abs(v))
	var g := 0.85 / peak
	for i in buf.size():
		buf[i] *= g
	return buf

static func _to_stream(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clamp(buf[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = buf.size()
	return s
