extends Node
## Automatic smoke test. Run with:  godot --path . -- --autotest
## Plays through the main features, saves screenshots to res://tests/ and prints a report.

var w
var t := 0.0
var step := 0
var log_lines: Array = []

func _ready() -> void:
	w = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests"))

func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(ProjectSettings.globalize_path("res://tests/%s.png" % name))

func _log(s: String) -> void:
	log_lines.append(s)
	print("[autotest] ", s)

var style_test := "--styletest" in OS.get_cmdline_user_args()
var race_test := "--racetest" in OS.get_cmdline_user_args()

func _process(dt: float) -> void:
	t += dt
	if style_test:
		_style_test()
		return
	if race_test:
		_race_test()
		return
	if "--radiotest" in OS.get_cmdline_user_args():
		if t > 1.0 and step == 0:
			step = 1
			_log("playlists: %s" % [Radio.playlists.keys()])
			Radio.set_station(1)
			_log("station 1 stream: %s playing %s" % [Radio.player.stream.resource_path if Radio.player.stream else "none", Radio.player.playing])
			get_tree().quit()
		return
	if "--logictest" in OS.get_cmdline_user_args():
		if step == 0:
			step = 1
			_logic_test()
		return
	if "--featuretest" in OS.get_cmdline_user_args():
		if step == 0:
			step = 1
			_feature_test()
		return
	if "--looktest" in OS.get_cmdline_user_args():
		_look_test()
		return
	if "--tricktest" in OS.get_cmdline_user_args():
		_trick_test()
		return
	if "--storytest" in OS.get_cmdline_user_args():
		_story_test()
		return
	if "--hudtest" in OS.get_cmdline_user_args():
		if step == 0 and t > 1.0:
			w._start()
			step = 1
			t = 0
		elif step == 1 and t > 1.0:
			var h = w.hud
			for n in ["cred_label", "mission_label", "banner_label", "hint_label", "chair_label", "race_label"]:
				var l: Label = h.get(n)
				_log("%s rect=%s vis=%s text=%s alpha=%.2f" % [n, l.get_global_rect(), l.is_visible_in_tree(), l.text.substr(0, 25), l.modulate.a])
			_log("viewport %s" % get_viewport().get_visible_rect())
			_shot("14_hud")
			get_tree().quit()
		return
	match step:
		0:
			if t > 1.5:
				_shot("00_title")
				w._start()
				step = 1
				t = 0
		1:
			Input.action_press("forward")
			if t > 3.0:
				_shot("01_rolling")
				_log("speed after 3 s: %.2f m/s, pos %s" % [GameState.player.speed(), GameState.player.global_position])
				Input.action_release("forward")
				step = 2
				t = 0
		2:
			var npc = null
			for c in w.chairs:
				if c.mode == "npc" and c.is_on_floor():
					npc = c
					break
			if npc != null:
				GameState.player.global_position = npc.global_position + Vector3(1.2, 0.2, 0)
				GameState.player.velocity = Vector3.ZERO
			step = 3
			t = 0
		3:
			if t > 0.05:
				for c in w.chairs:
					if c.mode == "npc":
						GameState.player.global_position = c.global_position + Vector3(1.0, 0.1, 0)
						break
				w.try_steal()
				step = 4
				t = 0
		4:
			if t > 1.0:
				_shot("02_stolen")
				_log("after steal: chair=%s cred=%d wanted=%d dex=%s" % [GameState.player.type, GameState.cred, GameState.wanted, GameState.dex.keys()])
				GameState.add_wanted(3)
				step = 5
				t = 0
		5:
			Input.action_press("forward")
			if t > 6.0:
				Input.action_release("forward")
				var cops := 0
				for c in w.chairs:
					if c.mode == "cop" and c.chase:
						cops += 1
				_shot("03_police")
				_log("chasing cops: %d, wanted %d, bust_t %.2f, state %s" % [cops, GameState.wanted, GameState.bust_t, w.state])
				w.day_offset += 0.5
				step = 6
				t = 0
		6:
			if t > 1.5:
				_shot("04_night")
				w.day_offset -= 0.5
				GameState.wanted = 0
				if w.state != "play":
					w.state = "play"
				# throne mission
				if w.gold != null:
					GameState.player.global_position = w.gold.global_position + Vector3(1.0, 0.3, 0)
				step = 7
				t = 0
		7:
			if t > 0.4:
				w.try_steal()
				step = 8
				t = 0
		8:
			if t > 1.0:
				_log("riding gold: %s" % (GameState.player == w.gold))
				_shot("05_gold")
				GameState.player.global_position = w.city.points["chop"] + Vector3(0, 0.3, 0)
				step = 9
				t = 0
		9:
			if t > 1.0:
				_log("after delivery: cred=%d chair=%s gold=%s" % [GameState.cred, GameState.player.type, w.gold])
				GameState.player.global_position = w.city.points["pizza"] + Vector3(0, 0.3, 0)
				step = 10
				t = 0
		10:
			if t > 1.0:
				_log("pizza job active: %s" % (not w.pizza.is_empty()))
				w.rig.next_mode()
				_shot("06_pizza")
				step = 11
				t = 0
		11:
			Input.action_press("forward")
			Input.action_press("wheelie")
			if t > 2.0:
				_log("wheelie on: %s t=%.2f" % [GameState.player.wheelie, GameState.player.wheelie_t])
				Input.action_release("wheelie")
				Input.action_release("forward")
				w.rig.next_mode()
				step = 12
				t = 0
		12:
			if t > 1.0:
				_shot("07_topdown")
				_log("fps %d, chairs %d, cars %d, props %d" % [Engine.get_frames_per_second(), w.chairs.size(), w.cars.size(), w.props.size()])
				Radio.next_station()
				GameState.cred = 3000
				w.rig.mode = 0
				GameState.player.global_position = w.city.points["pimp"] + Vector3(0, 0.3, 0)
				step = 13
				t = 0
		13:
			if w.state == "shop":
				_log("shop opened")
				w.shop_buy(GameState.SHOP[0])
				w.shop_buy(GameState.SHOP[4])
				w.shop_buy(GameState.SHOP[5])
				w.shop_buy(GameState.SHOP[6])
				_shot("08_shop")
				w.close_shop()
				_log("style %s cred %d" % [GameState.style, GameState.cred])
				GameState.player.global_position += Vector3(0, 0.3, -8)
				step = 14
				t = 0
			elif t > 3.0:
				_log("shop did NOT open")
				step = 14
				t = 0
		14:
			if t > 1.5:
				_shot("09_styled")
				var f = w.flocks[0]
				GameState.player.global_position = f.pos + Vector3(3, 0.3, 0)
				GameState.player.velocity = Vector3(-3, 0, 0)
				step = 15
				t = 0
		15:
			Input.action_press("back")
			if t > 0.6:
				Input.action_release("back")
				_log("flock state: %s, radio station %d playing %s" % [w.flocks[0].state, Radio.station, Radio.player.playing])
				_log("DONE")
				get_tree().quit()

func _style_test() -> void:
	match step:
		0:
			if t > 1.0:
				w._start()
				GameState.cred = 5000
				for id in [0, 4, 5, 6]:
					w.shop_buy(GameState.SHOP[id])
				w.day_offset += 0.5
				var p = GameState.player
				p.global_position = Vector3(30, 0.3, 105)
				p.yaw = PI / 2
				w.rig.snap()
				step = 1
				t = 0
		1:
			if t > 2.5:
				_shot("10_style_night")
				w.open_shop()
				step = 2
				t = 0
		2:
			if t > 0.5:
				_shot("11_shop_menu")
				get_tree().quit()

func _race_test() -> void:
	match step:
		0:
			if t > 1.0:
				w._start()
				var s: Dictionary = w.acts.stunts[0]
				var f := Vector3(-sin(s.yaw), 0, -cos(s.yaw))
				var p = GameState.player
				p.global_position = s.pos - f * 9.0 + Vector3.UP * 0.2
				p.yaw = s.yaw
				p.velocity = f * 13.0
				w.rig.snap()
				step = 1
				t = 0
		1:
			Input.action_press("forward")
			Input.action_press("boost")
			if t > 0.45 and not GameState.player.is_on_floor():
				_shot("12_stunt_air")
				_log("stunt active %s slowmo %.2f" % [w.acts.stunt_active != null, GameState.slowmo])
				step = 2
				t = 0
			elif t > 3.0:
				_log("never left ground")
				step = 2
				t = 0
		2:
			if t > 3.0:
				Input.action_release("forward")
				Input.action_release("boost")
				_log("stunts done %s cred %d" % [GameState.stunts_done, GameState.cred])
				GameState.player.global_position = w.acts.race_start + Vector3.UP * 0.3
				GameState.player.velocity = Vector3.ZERO
				step = 3
				t = 0
		3:
			if t > 1.0:
				_log("race started %s" % (not w.acts.race.is_empty()))
				step = 4
				t = 0
		4:
			if t > 9.0:
				var info := []
				for r in w.acts.race.get("racers", []):
					info.append("%s cp%d" % [r.name, r.cp])
				_log("race after 5s: %s / %s" % [info, w.acts.race_text()])
				_shot("13_race")
				get_tree().quit()

func _skip_talk() -> void:
	var st = w.story
	if st.active >= 0 and st.cur().type == "talk":
		st.step_t = 999.0

func _story_test() -> void:
	var st = w.story
	var p = GameState.player
	if step > 0:
		_skip_talk()
	match step:
		0:
			if t > 1.0:
				GameState.reset_save()
				w._start()
				GameState.story = 2
				p.global_position = st.start_pos + Vector3.UP * 0.2
				step = 6
				t = 0
		1:
			if t > 1.0:
				_log("mission active %d step %d obj '%s'" % [st.active, st.step_i, st.objective()])
				for c in w.chairs:
					if c.mode == "npc" and not c.has_meta("nosteal"):
						p.global_position = c.global_position + Vector3(1.0, 0.1, 0)
						break
				w.try_steal()
				step = 2
				t = 0
		2:
			if t > 1.0:
				_log("after steal: step %d obj '%s' wanted %d" % [st.step_i, st.objective(), GameState.wanted])
				GameState.wanted = 0
				step = 3
				t = 0
		3:
			if t > 0.5:
				GameState.player.global_position = st.start_pos + Vector3.UP * 0.2
				step = 4
				t = 0
		4:
			if t > 1.5:
				_log("mission1 done: story=%d cred=%d rev=%d active=%d" % [GameState.story, GameState.cred, GameState.revolution, st.active])
				GameState.story = 2
				st.active = -1
				st.lock = false
				GameState.player.global_position = st.start_pos + Vector3(4, 0.2, 0)
				step = 5
				t = 0
		5:
			if t > 0.4:
				GameState.player.global_position = st.start_pos + Vector3.UP * 0.2
				step = 6
				t = 0
		6:
			if t > 1.0:
				_log("mission3 started: %d obj '%s'" % [st.active, st.objective()])
				GameState.player.global_position = st.plaza + Vector3(0, 0.3, 6)
				GameState.player.yaw = 0.0
				w.rig.snap()
				step = 7
				t = 0
		7:
			if st.baron != null and t > 1.0:
				st.step_t = 1.0 if st.cur().type == "talk" else st.step_t
				_shot("15_baron")
				step = 8
				t = 0
		8:
			if st.story_crates.size() > 0 and st.cur().type == "smash":
				var c = null
				for k in st.story_crates:
					if is_instance_valid(k) and not k.get_meta("smashed", false):
						c = k
						break
				if c != null and fmod(t, 1.2) < 0.03:
					GameState.player.global_position = Vector3(c.global_position.x, City.CURB + 0.05, c.global_position.z + 2.2)
					GameState.player.velocity = Vector3(0, 0, -7)
					GameState.player.yaw = 0.0
			if t > 30.0 or st.active < 0:
				_log("after smash: story=%d rev=%d cred=%d active=%d stairs_ramped=%s" % [GameState.story, GameState.revolution, GameState.cred, st.active, st.stairs.map(func(x): return x.ramp)])
				var s0 = st.stairs[0]
				GameState.player.global_position = s0.pos + Vector3(0, 0.3, 0) + Vector3(sin(s0.yaw), 0, cos(s0.yaw)) * 7.0
				GameState.player.yaw = s0.yaw
				w.rig.snap()
				step = 9
				t = 0
		9:
			if t > 1.5:
				_shot("16_stairs")
				get_tree().quit()


func _act(a: String, on: bool) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = on
	Input.parse_input_event(e)
	if on:
		Input.action_press(a)
	else:
		Input.action_release(a)

func _tlog(tag: String) -> void:
	var tr = w.tricks
	var p: Chair = GameState.player
	_log("bail: " + tr.last_bail)
	_log("%s live=%s combo=%s pts=%d x%d flash='%s' special=%.2f cred=%d air=%s yaw=%.2f" % [tag, tr.live, tr.combo, tr.live_score(), tr.mult(), tr.flash_text, tr.special, GameState.cred, tr.in_air, p.yaw])

var _tt_seq := [
	[1.0, "start"], [1.5, "shot_street"], [0.1, "night"], [2.0, "shot_night"], [0.1, "modern"], [1.5, "shot_modern"], [0.1, "back"],
	[0.6, "fwd"], [1.6, "hop"], [0.12, "left_on"], [0.4, "left_off"], [0.5, "log"],
	[0.1, "wheelie_on"], [1.3, "wheelie_off"], [0.1, "hop"], [0.16, "flip"], [0.08, "shot_air"], [0.25, "grab_on"], [0.15, "grab_off"], [0.4, "log"],
	[1.4, "log_bank"], [0.4, "hop"], [0.33, "flip"], [0.6, "log_bail"], [0.1, "end"]]

func _trick_test() -> void:
	if step >= _tt_seq.size():
		return
	var it: Array = _tt_seq[step]
	if t < it[0]:
		return
	t = 0.0
	step += 1
	var p: Chair = GameState.player
	match it[1]:
		"start":
			w._start()
			GameState.retro = true
			w.apply_retro()
		"fwd": _act("forward", true)
		"hop": _act("hop", true); _act("hop", false)
		"flip": _act("hop", true); _act("hop", false)
		"left_on": _act("left", true)
		"left_off": _act("left", false)
		"wheelie_on": _act("wheelie", true)
		"wheelie_off": _act("wheelie", false)
		"grab_on": _act("wheelie", true)
		"grab_off": _act("wheelie", false)
		"log", "log_bank", "log_bail": _tlog(it[1])
		"shot_air": _tlog("air"); _shot("20_trick_air")
		"shot_street": _shot("21_retro_street")
		"night": w.day_offset += 0.5
		"shot_night":
			_shot("22_retro_night")
			w.post.visible = false
			await get_tree().process_frame
			await get_tree().process_frame
			_shot("22b_night_nopost")
			w.post.visible = true
		"modern":
			w.day_offset -= 0.5
			w.toggle_retro()
		"back": w.toggle_retro()
		"shot_modern": _shot("23_modern_compare")
		"end":
			_log("done")
			get_tree().quit()


var _lcam: Camera3D
func _look_test() -> void:
	if step == 0 and t > 1.0:
		step = 1
		t = 0.0
		w._start()
		var p: Chair = GameState.player
		var f := p.forward()
		var r := Vector3(cos(p.yaw), 0, -sin(p.yaw))
		var types := ["hospital", "power", "turbo", "rusty", "monster"]
		for i in 5:
			var pos: Vector3 = p.global_position + f * 3.2 + r * (i - 2) * 1.3
			var c: Chair = w.spawn_chair(types[i], pos, p.yaw, "npc")
			c.mode = "parked"
		_lcam = Camera3D.new()
		w.add_child(_lcam)
		_lcam.global_position = p.global_position + f * 7.2 + Vector3.UP * 1.5
		_lcam.look_at(p.global_position + f * 3.2 + Vector3.UP * 0.9)
		_lcam.fov = 50
		_lcam.current = true
	elif step == 1 and t > 1.5:
		step = 2
		t = 0.0
		_shot("30_lineup")
		var p: Chair = GameState.player
		var f := p.forward()
		_lcam.global_position = p.global_position + f * 1.6 + Vector3.UP * 1.25
		_lcam.look_at(p.global_position + Vector3.UP * 1.0)
	elif step == 2 and t > 0.6:
		step = 3
		t = 0.0
		_shot("31_player_close")
		# a park and a city street with the new dressing
		var park: Vector3 = Vector3.ZERO
		for k in w.city.points:
			if str(k).begins_with("park_"):
				park = w.city.points[k]
				break
		_lcam.global_position = park + Vector3(14, 4.0, 14)
		_lcam.look_at(park + Vector3(2, 0.5, 0))
	elif step == 3 and t > 0.8:
		step = 4
		t = 0.0
		_shot("32_park")
		var bl: Dictionary = {}
		for b in w.city.blocks:
			if b.type == "city":
				bl = b
				break
		var x0: float = bl.x0
		var z0: float = bl.z0
		_lcam.global_position = Vector3(x0 - 3.0, 2.2, z0 + 1.0)
		_lcam.look_at(Vector3(x0 + 18.0, 1.2, z0 + 1.5))
	elif step == 4 and t > 0.8:
		step = 5
		_shot("33_street")
		get_tree().quit()


# ------------------------------------------------------------------ feature test (v3 systems)
var dbg_qp := false
var dbg_hp := Vector3.ZERO
func _physics_process(_dt: float) -> void:
	if dbg_qp:
		var p: Chair = GameState.player
		var n := p.get_floor_normal() if p.is_on_floor() else Vector3.ZERO
		var cols := []
		for i in p.get_slide_collision_count():
			var c := p.get_slide_collision(i)
			cols.append("%s n=%s" % [c.get_collider().name if c.get_collider() else "?", c.get_normal().snapped(Vector3.ONE * 0.01)])
		print("[qp] x=%.2f y=%.2f v=%s floor=%s n=%s qp_t=%.2f vert=%s cols=%s" % [p.global_position.x - dbg_hp.x, p.global_position.y, p.velocity.snapped(Vector3.ONE * 0.01), p.is_on_floor(), n.snapped(Vector3.ONE * 0.01), p.qp_t, p.vert, cols])

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

func _side_cam(target: Vector3, from_offset: Vector3) -> Camera3D:
	if _lcam == null:
		_lcam = Camera3D.new()
		w.add_child(_lcam)
	_lcam.fov = 55
	_lcam.global_position = target + from_offset
	_lcam.look_at(target, Vector3.UP)
	_lcam.current = true
	return _lcam

func _feature_test() -> void:
	await _wait(1.0)
	w._start()
	await _wait(0.5)
	var p: Chair = GameState.player
	_log("rider rig: %s" % (p.rig != null))
	# 1. pushing animation on a straight road
	var rp: Vector3 = Vector3(City.ROAD / 2.0 + City.PITCH * 2, 0.2, City.PITCH * 2 + 25)
	p.global_position = rp
	p.yaw = PI
	_act("forward", true)
	await _wait(1.6)
	_side_cam(p.global_position + Vector3.UP * 0.8, Vector3(3.0, 0.6, 0.6))
	await _wait(0.25)
	_shot("40_push")
	_act("forward", false)
	w.rig.cam.current = true
	# 2. curb grind
	var curb: Dictionary = {}
	for r in w.city.rails:
		if r.kind == "curb" and r.len > 20:
			curb = r
			break
	p = GameState.player
	var out := Vector3(-curb.d.z, 0, curb.d.x)
	p.global_position = curb.a + curb.d * 4.0 + out * 0.6 + Vector3(0, 0.3, 0)
	p.yaw = atan2(-curb.d.x, -curb.d.z)
	p.rotation.y = p.yaw
	await _wait(0.2)
	p.velocity = curb.d * 6.5
	p.hop()
	await _wait(0.45)
	_log("grinding after hop: %s kind=%s" % [not w.tricks.grind.is_empty(), w.tricks.grind.get("rail", {}).get("kind", "-")])
	_side_cam(p.global_position + Vector3.UP * 0.7, out * 3.0 + Vector3.UP * 0.8 + curb.d * 1.5)
	await _wait(0.1)
	_shot("41_grind")
	w.rig.cam.current = true
	await _wait(0.8)
	_act("hop", true)
	_act("hop", false)
	await _wait(1.5)
	_log("after grind: m=%.1f combo=%s live=%s" % [w.tricks.grind_m, w.tricks.combo, w.tricks.live])
	await _wait(1.5)
	# 3. half-pipe vert in the skate plaza
	var sk: Vector3 = w.city.points["skate"]
	var hp: Vector3 = Vector3.INF
	for sp in w.city.stunt_spots:
		if sp.label == "HALF-PIPE" and sp.pos.distance_to(sk) < 25.0:
			hp = sp.pos
	p.global_position = hp + Vector3(2.0, 0.3, 0)
	p.yaw = PI / 2
	p.rotation.y = p.yaw
	p.velocity = Vector3.ZERO
	await _wait(0.3)
	p.velocity = Vector3(-10.0, 0, 0)
	_act("forward", true)
	var max_y := 0.0
	var vert_seen := false
	for i in 40:
		await _wait(0.05)
		max_y = maxf(max_y, p.global_position.y)
		vert_seen = vert_seen or p.vert
		if i == 14:
			_side_cam(hp + Vector3(0, 2.0, 0), Vector3(0, 2.5, 9.0))
			await _wait(0.02)
			_shot("42_halfpipe")
			w.rig.cam.current = true
	_act("forward", false)
	_log("half-pipe: vert=%s max_y=%.2f combo=%s goals=%s" % [vert_seen, max_y, w.tricks.combo, GameState.goals.keys()])
	await _wait(1.5)
	_side_cam(sk + Vector3(0, 1, 0), Vector3(-14, 9, 16))
	await _wait(0.2)
	_shot("43_plaza")
	w.rig.cam.current = true
	# 4. donuts and cops
	GameState.donuts = 0
	var pk: Dictionary = w.fun.pickups[0]
	p.global_position = pk.pos + Vector3(0, 0.2, 0)
	await _wait(0.4)
	_log("donuts after pickup: %d" % GameState.donuts)
	GameState.wanted = 2
	var cop: Chair = w.spawn_chair("cop", p.global_position - p.forward() * 4.0, p.yaw, "cop")
	cop.chase = true
	w.fun.throw_donut()
	await _wait(1.6)
	_log("cop stunned=%.1f chase=%s donut goal=%s" % [cop.stunned, cop.chase, GameState.goals.has("donut")])
	# 5. dumpster hiding
	var dm: Vector3 = w.city.dumpsters[0]
	p.global_position = dm + Vector3(1.6, 0.2, 0)
	p.velocity = Vector3.ZERO
	await _wait(0.5)
	var hid: bool = w.fun.toggle_hide()
	_log("hide: %s hidden=%s visible=%s" % [hid, w.fun.hidden, p.visible])
	await _wait(1.0)
	w.fun.toggle_hide()
	_log("unhide: hidden=%s visible=%s" % [w.fun.hidden, p.visible])
	GameState.wanted = 0
	# 6. signs + cone trip
	for b in w.fun.signs.slice(0, 5):
		w.on_prop_hit(b, p)
	w.fun.cop_tripped(cop)
	_log("goals now %d: %s" % [w.goals.count(), GameState.goals.keys()])
	# 7. create-a-rider
	w.editor.open_editor()
	await _wait(0.3)
	w.editor._step("hair", 2)
	w.editor._step("hat", 3)
	w.editor._step("print", 2)
	w.editor._step("shirt", 4)
	await _wait(0.4)
	_shot("44_editor")
	_log("look: %s" % [GameState.look])
	w.editor.close()
	# 8. pause menu and goals screen
	w.toggle_pause()
	await _wait(0.3)
	_shot("45_pause")
	w.hud._show_goals(true)
	await _wait(0.2)
	_shot("46_goals")
	w.hud._show_goals(false)
	w.toggle_pause()
	await _wait(0.3)
	# 9. photo + replay
	w.photo.toggle_photo()
	await _wait(0.3)
	w.photo.snap()
	await _wait(0.4)
	w.photo.toggle_photo()
	_log("photo toast: %s" % w.photo.toast.text)
	_act("forward", true)
	await _wait(3.0)
	_act("forward", false)
	w.photo.start_replay()
	await _wait(1.2)
	_shot("47_replay")
	_log("replaying=%s frames=%d" % [w.photo.replaying, w.photo.rec.size()])
	w.photo._end_replay()
	await _wait(0.3)
	# 10. score attack (1 player, short run)
	w.score.open_setup()
	w.score.count_spin.value = 2
	w.score.class_edit.text = "TestClass"
	w.score.name_edits[0].text = "Alva"
	w.score.name_edits[1].text = "Bo"
	w.score._begin()
	w.score.run_len = 4.0
	await _wait(4.0)
	w.score.scores[0] += 1234
	await _wait(12.5)
	w.score.scores[1] += 999
	await _wait(9.0)
	_log("score attack: active=%s results=%s" % [w.score.active, w.score.result_panel.visible])
	_shot("48_results")
	w.score.result_panel.visible = false
	get_tree().paused = false
	await _wait(0.3)
	# 11. story: Act 1 missions 2, 4, 5 and all of Act 2 via a cheat runner
	for mi in [1, 3, 4, 5, 6, 7, 8, 9]:
		await _cheat_mission(mi)
	_log("story=%d revolution=%d" % [GameState.story, GameState.revolution])
	_log("FEATURES DONE")
	get_tree().quit()

func _cheat_mission(mi: int) -> void:
	var st = w.story
	GameState.story = mi
	GameState.wanted = 0
	var p: Chair = GameState.player
	if w.fun.hidden:
		w.fun.toggle_hide()
	if st.active >= 0:
		st._fail("test")
	await _wait(0.2)
	st._start(mi)
	var guard := 0
	var last := -1
	while st.active == mi and guard < 400:
		guard += 1
		var s: Dictionary = st.cur()
		if st.step_i != last:
			last = st.step_i
		match s.type:
			"talk": st.step_t = 999.0
			"goto":
				if s.has("need") and GameState.player.type != s.need:
					await _get_chair(s.need)
				GameState.player.global_position = s.pos + Vector3(0, 0.3, 0)
			"have_chair": await _get_chair(s.chair)
			"steal": GameState.event.emit("steal", {"victim": s.victim})
			"escape": GameState.wanted = 0
			"event": GameState.event.emit(s.name, {})
			"combo": GameState.event.emit("combo", {"total": s.n + 10, "tricks": 3}); GameState.player.global_position = s.get("near", GameState.player.global_position) + Vector3(0, 0.3, 0)
			"grind": GameState.event.emit("grind", {"m": s.n + 1.0, "kind": "curb"})
			"have_donut": GameState.donuts = 1
			"donut": GameState.event.emit("donut_bribe", {})
			"smash_signs":
				for b in st.story_signs:
					if is_instance_valid(b) and not b.get_meta("smashed", false):
						w.fun.sign_hit(b, GameState.player)
			"collect":
				for t in st.tokens.duplicate():
					if is_instance_valid(t):
						GameState.player.global_position = t.position - Vector3(0, 0.6, 0)
						await _wait(0.05)
		await _wait(0.05)
	_log("mission %d '%s' finished: story=%d active=%d guard=%d step=%s" % [mi, st.missions[mi].title, GameState.story, st.active, guard, st.cur().type if st.active >= 0 else "-"])

func _get_chair(t: String) -> void:
	var p: Chair = GameState.player
	var c: Chair = w.spawn_chair(t, p.global_position + p.forward() * 1.2, p.yaw)
	await _wait(0.3)
	w.try_steal()
	await _wait(0.7)


func _logic_test() -> void:
	await _wait(0.5)
	w._start()
	await _wait(0.5)
	var p: Chair = GameState.player
	var curb: Dictionary = {}
	for r in w.city.rails:
		if r.kind == "curb" and r.len > 20:
			curb = r
			break
	var out := Vector3(-curb.d.z, 0, curb.d.x)
	p.global_position = curb.a + curb.d * 4.0 + out * 0.6 + Vector3(0, 0.3, 0)
	p.yaw = atan2(-curb.d.x, -curb.d.z)
	p.rotation.y = p.yaw
	await _wait(0.4)
	_log("curb a=%s d=%s pos=%s floor=%s" % [curb.a, curb.d, p.global_position, p.is_on_floor()])
	p.velocity = curb.d * 6.5
	p.hop()
	await _wait(0.6)
	_log("plain hop near curb grinds (should be false): %s" % (not w.tricks.grind.is_empty()))
	if not w.tricks.grind.is_empty():
		w.tricks._end_grind(p, false)
	await _wait(0.8)
	p.global_position = curb.a + curb.d * 4.0 + out * 0.6 + Vector3(0, 0.3, 0)
	p.velocity = Vector3.ZERO
	await _wait(0.4)
	p.velocity = curb.d * 6.5
	await _wait(0.1)
	_act("wheelie", true)
	await _wait(0.1)
	_act("wheelie", false)
	_log("X on ground by curb grinds (should be true): %s" % (not w.tricks.grind.is_empty()))
	for i in 12:
		await _wait(0.05)
		var rel: Vector3 = p.global_position - curb.a
		var t: float = rel.dot(curb.d)
		var perp: Vector3 = Vector3(rel.x, 0, rel.z) - curb.d * t
		_log("t=%.2f y=%.2f air=%.2f vy=%.2f perp=%.2f grind=%s" % [t, p.global_position.y, p.air_t, p.velocity.y, perp.length(), not w.tricks.grind.is_empty()])
	await _wait(0.6)
	_act("hop", true)
	_act("hop", false)
	await _wait(1.6)
	_log("grind m=%.1f combo=%s flash=%s cred=%d" % [w.tricks.grind_m, w.tricks.combo, w.tricks.flash_text, GameState.cred])
	await _wait(1.0)
	if not w.tricks.grind.is_empty():
		w.tricks._end_grind(p, false)
	await _wait(0.5)
	var sk: Vector3 = w.city.points["skate"]
	var hp: Vector3 = Vector3.INF
	for sp in w.city.stunt_spots:
		if sp.label == "HALF-PIPE" and sp.pos.distance_to(sk) < 25.0:
			hp = sp.pos
	p.global_position = hp + Vector3(1.0, 0.3, 0)
	p.yaw = PI / 2
	p.rotation.y = p.yaw
	p.velocity = Vector3.ZERO
	await _wait(0.4)
	p.global_position = hp + Vector3(2.6, 0.3, 0)
	await _wait(0.3)
	p.velocity = Vector3(-9.0, 0, 0)
	_act("forward", true)
	_act("boost", true)
	dbg_hp = hp
	dbg_qp = true
	var max_y := 0.0
	var vert_seen := false
	for i in 60:
		await _wait(0.05)
		max_y = maxf(max_y, p.global_position.y)
		vert_seen = vert_seen or p.vert
		if i % 6 == 0:
			_log("hp x=%.2f y=%.2f v=%s vert=%s floor=%s" % [p.global_position.x - hp.x, p.global_position.y, p.velocity, p.vert, p.is_on_floor()])
	dbg_qp = false
	_act("forward", false)
	_act("boost", false)
	_log("half-pipe: vert=%s max_y=%.2f combo=%s flash=%s" % [vert_seen, max_y - hp.y, w.tricks.combo, w.tricks.flash_text])
	for mi in [1, 3, 4, 5, 6, 7, 8, 9]:
		await _cheat_mission(mi)
	_log("story=%d revolution=%d" % [GameState.story, GameState.revolution])
	w.score.open_setup()
	w.score.count_spin.value = 1
	w.score._begin()
	w.score.run_len = 3.0
	for i in 14:
		await _wait(1.0)
		_log("score phase=%s t=%.1f paused=%s ts=%.2f" % [w.score.phase, w.score.t, get_tree().paused, Engine.time_scale])
	_log("results=%s" % w.score.result_panel.visible)
	get_tree().quit()
