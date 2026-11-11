extends Node3D
## Story mode (Act 1 + Act 2) + the Ramp Revolution.
## Missions are lists of simple steps, so students can write new missions without new code:
##   talk, steal, have_chair, goto, escape, set_wanted, spawn_crates, smash, baron, event, reward,
##   combo (bank a combo of n points, optionally near a place), grind (n metres), have_donut, donut,
##   signs (spawn + smash STAIRS INC. signs), collect (pick up glowing items).
## Mayor Baron Stairwell puts stairs on the sidewalks; smashing his STAIRS INC. crates and finishing
## missions raises the Ramp Revolution meter, and every 15% one of his staircases becomes a ramp.

const STORY_COL := Color("b388ff")
const SPOKE := ["SPOKE", Color("ffd84a")]
const BARON := ["MAYOR BARON STAIRWELL", Color("ff5c8a")]

var w
var city: City
var missions: Array = []
var active: int = -1
var step_i: int = 0
var step_t: float = 0.0
var line_i: int = 0
var smashed: int = 0
var stole: Dictionary = {}
var events: Array = []
var lock: bool = false
var ring: MeshInstance3D
var beam: MeshInstance3D
var target = null
var spoke: Chair
var baron: Chair
var story_crates: Array = []
var crates: Array = []
var stairs: Array = []
var plaza := Vector3.ZERO
var start_pos := Vector3.ZERO
var progress: float = 0.0
var story_signs: Array = []
var tokens: Array = []

func setup(world) -> void:
	w = world
	city = world.city
	plaza = city.points.get("hospital")
	for k in city.points.keys():
		if String(k).begins_with("park_"):
			plaza = city.points[k]
			break
	var chop: Vector3 = city.points["chop"]
	start_pos = chop + Vector3(5, 0, 0)
	ring = w._ring(start_pos, STORY_COL, 2.0)
	var lbl := Label3D.new()
	lbl.text = "STORY: SPOKE"
	lbl.font_size = 40
	lbl.pixel_size = 0.006
	lbl.outline_size = 12
	lbl.modulate = STORY_COL
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = start_pos + Vector3.UP * 2.3
	add_child(lbl)
	ring.set_meta("label", lbl)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.7, 0.5, 1.0, 0.22)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam = w._beam(1.6, bm)
	beam.visible = false
	spoke = w.spawn_chair("rusty", chop + Vector3(-5, 0, 0), 0.0)
	var r := Models.rider("npc", {"hat": "CapBack", "hair": "HairShort", "print": 1, "face": 1, "shirt": Color("ff8a1f")})
	spoke.set_rider(r, "npc")
	spoke.mode = "parked"
	spoke.set_meta("nosteal", true)
	var cap = r.find_child("Cap", true, false)
	if cap != null and r.find_child("CapBack", true, false) == null:
		cap.visible = true
	_build_missions()
	_build_stairs()
	_build_crates()
	GameState.event.connect(_on_event)
	_update_stairs(false)

# ------------------------------------------------------------------ mission data
func _build_missions() -> void:
	var chop: Vector3 = city.points["chop"]
	var skate: Vector3 = city.points.get("skate", plaza)
	missions = [
		{"title": "NEW WHEELS IN TOWN", "steps": [
			{"type": "talk", "lines": [[SPOKE, "So you're the new kid. Folks call me Spoke."], [SPOKE, "In Los Spokos, wheels are everything. Show me you can take some."]]},
			{"type": "steal", "victim": "npc", "text": "Steal a chair from someone who is sitting in it  (roll up and press E)"},
			{"type": "escape", "text": "Lose the Kerb Patrol!"},
			{"type": "goto", "pos": start_pos, "r": 3.0, "text": "Roll back to Spoke at the Chop Shop"},
			{"type": "talk", "lines": [[SPOKE, "Not bad. Not good either. But not bad."]]},
			{"type": "reward", "cred": 300, "rev": 5}]},
		{"title": "NEED FOR SPEED", "steps": [
			{"type": "talk", "lines": [[SPOKE, "A customer wants a Turbo Sprint X. Red, fast, rude."], [SPOKE, "There's usually one in the hospital car park. Don't ask why."]]},
			{"type": "have_chair", "chair": "turbo", "text": "Get a Turbo Sprint X  (try the Hospital car park)"},
			{"type": "goto", "pos": chop, "r": 3.5, "need": "turbo", "time": 90.0, "text": "Bring the Turbo Sprint X to the Chop Shop before the owner notices!"},
			{"type": "talk", "lines": [[SPOKE, "She's a beauty. Here's your cut. Now go get yourself something rusty again."]]},
			{"type": "reward", "cred": 500, "rev": 5}]},
		{"title": "OPERATION BIG STEP", "steps": [
			{"type": "talk", "lines": [[SPOKE, "Turn on the news, kid. Our new mayor is making a speech in the park."], [SPOKE, "I've got a bad feeling about this guy."]]},
			{"type": "goto", "pos": plaza, "r": 9.0, "text": "Go to the park and watch Mayor Baron Stairwell's speech"},
			{"type": "baron", "pos": plaza},
			{"type": "talk", "lines": [[BARON, "Citizens of Los Spokos! Ramps are a FAD."], [BARON, "Stairs are timeless. Stairs build CHARACTER."], [BARON, "Today I begin OPERATION BIG STEP: stairs on every corner!"], [BARON, "My crates of fresh stairs are arriving... right now!"]]},
			{"type": "spawn_crates", "pos": plaza, "n": 5},
			{"type": "smash", "n": 5, "time": 100.0, "text": "Smash the 5 STAIRS INC. crates before they get installed!"},
			{"type": "talk", "lines": [[BARON, "MY STAIRS! Who did this?! ...Was that a wheelchair?!"], [SPOKE, "Ha! Did you see his face? You're a natural, kid."]]},
			{"type": "reward", "cred": 600, "rev": 15}]},
		{"title": "IMPOUND JOB", "steps": [
			{"type": "talk", "lines": [[SPOKE, "The Kerb Patrol impounded my cousin's chair."], [SPOKE, "Get it back. Any police chair will do. He won't notice."]]},
			{"type": "have_chair", "chair": "cop", "text": "Steal a Kerb Patrol Cruiser  (the police HQ car park has some)"},
			{"type": "set_wanted", "n": 3},
			{"type": "escape", "text": "Lose the cops!  (Tip: a new paint job at Pimp My Chair makes them forget you)"},
			{"type": "goto", "pos": chop, "r": 3.5, "need": "cop", "text": "Deliver the Kerb Patrol Cruiser to the Chop Shop"},
			{"type": "talk", "lines": [[SPOKE, "My cousin will be thrilled. It's not his, but he'll be thrilled."]]},
			{"type": "reward", "cred": 800, "rev": 10}]},
		{"title": "THE GOLDEN THRONE", "steps": [
			{"type": "talk", "lines": [[SPOKE, "The Baron has a solid gold throne on wheels. He thinks he's royalty."], [SPOKE, "Steal it and bring it here. It'll pay for a LOT of ramps."]]},
			{"type": "event", "name": "delivered_gold", "text": "Steal the GOLDEN THRONE and deliver it to the Chop Shop  (follow the gold beam)"},
			{"type": "talk", "lines": [[BARON, "MY THRONE! You'll pay for this, you ramp-loving hooligan!"], [SPOKE, "That's Act 1, kid. The Ramp Revolution has begun."]]},
			{"type": "reward", "cred": 1000, "rev": 20, "final": true}]},
		# ------------------------------------------------------------ ACT 2: STAIRWAY TO NOWHERE
		{"title": "GRAND OPENING", "act": 2, "steps": [
			{"type": "talk", "lines": [[SPOKE, "Act 2, kid. We used the Throne money to build a skate plaza."], [SPOKE, "Nobody believes chairs can shred. Go show them."]]},
			{"type": "goto", "pos": skate, "r": 14.0, "text": "Roll to the new SKATE PLAZA"},
			{"type": "combo", "n": 2000, "near": skate, "r": 30.0, "time": 150.0, "text": "Land a 2,000 point combo at the plaza  (hop, spin, grab, grind, link with wheelies)"},
			{"type": "talk", "lines": [[SPOKE, "Did you see the crowd? Phones out, jaws on the floor."], [BARON, "A SKATE PLAZA?! In MY city?! This means war... on ramps!"]]},
			{"type": "reward", "cred": 700, "rev": 5}]},
		{"title": "DONUT DIPLOMACY", "act": 2, "steps": [
			{"type": "talk", "lines": [[SPOKE, "The Baron sent the whole Kerb Patrol after us."], [SPOKE, "Lucky for us, cops can't say no to donuts. Grab a box."]]},
			{"type": "have_donut", "text": "Grab a box of donuts  (pink boxes on the sidewalks)"},
			{"type": "set_wanted", "n": 2},
			{"type": "donut", "text": "Toss a donut at the cops chasing you  (press F)"},
			{"type": "escape", "text": "Lose the Kerb Patrol!  (Tip: hide in a dumpster with E)"},
			{"type": "talk", "lines": [[SPOKE, "Bribery by pastry. Classic."]]},
			{"type": "reward", "cred": 600, "rev": 5}]},
		{"title": "SIGN OF THE TIMES", "act": 2, "steps": [
			{"type": "talk", "lines": [[BARON, "Citizens! STAIRS INC. signs now mark every future staircase!"], [SPOKE, "Not if we flatten them first. Go!"]]},
			{"type": "signs", "pos": plaza, "n": 6},
			{"type": "smash_signs", "n": 6, "time": 120.0, "text": "Smash the 6 new STAIRS INC. signs around the park"},
			{"type": "talk", "lines": [[BARON, "My beautiful signage! Do you know how much laminating costs?!"]]},
			{"type": "reward", "cred": 800, "rev": 15}]},
		{"title": "RAIL BARON", "act": 2, "steps": [
			{"type": "talk", "lines": [[SPOKE, "Real chair-skaters grind. Curbs, ledges, rails, anything."], [SPOKE, "Get some metres under your wheels. Hop right next to an edge."]]},
			{"type": "grind", "n": 30.0, "time": 180.0, "text": "Grind 30 m on curbs, ledges and rails  (hop next to one, balance with left/right)"},
			{"type": "talk", "lines": [[SPOKE, "Sparks everywhere! The fire department is asking questions, but who cares."]]},
			{"type": "reward", "cred": 900, "rev": 10}]},
		{"title": "THE BARON'S LAST STEP", "act": 2, "steps": [
			{"type": "talk", "lines": [[BARON, "Tonight I pour concrete STAIRS over that skate plaza!"], [SPOKE, "We need ramp parts. Four of them are stashed around town. Move!"]]},
			{"type": "collect", "n": 4, "time": 200.0, "text": "Collect the 4 glowing RAMP PARTS around the city"},
			{"type": "goto", "pos": skate, "r": 10.0, "text": "Bring the ramp parts to the skate plaza"},
			{"type": "baron", "pos": skate},
			{"type": "talk", "lines": [[BARON, "Fine. FINE! Ramps everywhere. Ramps for everyone!"], [BARON, "...Could I maybe... try one?"], [SPOKE, "Everyone can roll, Baron. That's the whole point."]]},
			{"type": "reward", "cred": 2000, "rev": 25, "final2": true}]},
	]

# ------------------------------------------------------------------ runner
func _on_event(ev: String, data: Dictionary) -> void:
	events.append([ev, data])
	if ev == "busted" and active >= 0:
		_fail("You got busted.")

func _physics_process(dt: float) -> void:
	if w == null or w.state == "title":
		return
	var p: Chair = GameState.player
	var done: bool = GameState.story >= missions.size()
	ring.visible = active < 0 and not done
	ring.get_meta("label").visible = ring.visible
	if active < 0:
		target = null
		beam.visible = false
		events.clear()
		if done:
			return
		var d := p.global_position.distance_to(start_pos)
		if d > 5.0:
			lock = false
		elif not lock and d < 2.2 and w.hop == null and w.state == "play" and w.acts.race.is_empty() and w.pizza.is_empty():
			_start(GameState.story)
		return
	_run_step(dt)
	beam.visible = target != null
	if target != null:
		beam.global_position = target + Vector3.UP * 80.0
	events.clear()

func _start(i: int) -> void:
	active = i
	step_i = 0
	_begin_step()
	var act: int = missions[i].get("act", 1)
	var in_act := missions.filter(func(m): return m.get("act", 1) == act)
	GameState.say_banner(missions[i].title, "Act %d  •  Mission %d of %d" % [act, in_act.find(missions[i]) + 1, in_act.size()], STORY_COL)
	Sfx.play("big")

func _begin_step() -> void:
	step_t = 0.0
	line_i = -1
	smashed = 0
	progress = 0.0
	target = null

func cur() -> Dictionary:
	return missions[active].steps[step_i]

func _next() -> void:
	step_i += 1
	_begin_step()
	if step_i >= missions[active].steps.size():
		active = -1

func _run_step(dt: float) -> void:
	var s := cur()
	var p: Chair = GameState.player
	step_t += dt
	if s.has("time") and step_t > s.time:
		_fail("Out of time!")
		return
	match s.type:
		"talk":
			var idx := int(step_t / 3.6)
			if idx != line_i and idx < s.lines.size():
				line_i = idx
				var ln: Array = s.lines[idx]
				GameState.say_sub(ln[0][0], ln[1], ln[0][1])
				if ln[0] == BARON and baron != null:
					baron.say(ln[1], 3.4)
				elif ln[0] == SPOKE and p.global_position.distance_to(spoke.global_position) < 15.0:
					spoke.say(ln[1], 3.4)
			if step_t > s.lines.size() * 3.6:
				_next()
		"steal":
			for e in events:
				if e[0] == "steal" and (s.victim == "any" or e[1].victim == s.victim):
					_next()
					return
		"have_chair":
			if p.type == s.chair and w.hop == null:
				_next()
		"goto":
			target = s.pos
			var ok: bool = not s.has("need") or p.type == s.need
			if ok and p.global_position.distance_to(s.pos) < s.r and w.hop == null:
				_next()
		"escape":
			if GameState.wanted == 0 and step_t > 0.5:
				_next()
		"set_wanted":
			GameState.wanted = max(GameState.wanted, s.n)
			GameState.wanted_cool = 0.0
			_next()
		"baron":
			_spawn_baron(s.pos)
			_next()
		"spawn_crates":
			var offs := [Vector3(7, 0, 0), Vector3(-7, 0, 0), Vector3(0, 0, 7), Vector3(0, 0, -7), Vector3(12, 0, 0), Vector3(-12, 0, 0), Vector3(0, 0, 12), Vector3(0, 0, -12)]
			for i in s.n:
				story_crates.append(_crate(s.pos + offs[i % offs.size()] + Vector3(0, 0.5, 0), true))
			_next()
		"smash":
			for e in events:
				if e[0] == "crate" and e[1].story:
					smashed += 1
			var left: Array = []
			for c in story_crates:
				if is_instance_valid(c) and not c.get_meta("smashed", false):
					left.append(c)
			if not left.is_empty():
				target = left[0].global_position
			if smashed >= s.n or left.is_empty():
				_next()
		"event":
			if s.name == "delivered_gold" and w.gold != null:
				target = w.gold.global_position if p != w.gold else city.points["chop"]
			for e in events:
				if e[0] == s.name:
					_next()
					return
		"combo":
			if s.has("near"):
				target = s.near
			for e in events:
				if e[0] == "combo" and e[1].total >= s.n and (not s.has("near") or p.global_position.distance_to(s.near) < s.r):
					_next()
					return
		"grind":
			for e in events:
				if e[0] == "grind":
					progress += e[1].m
			if progress >= s.n:
				_next()
		"have_donut":
			if GameState.donuts > 0:
				_next()
			elif not w.fun.pickups.is_empty():
				var best = null
				var bd := 1e9
				for pk in w.fun.pickups:
					if pk.node.visible and pk.pos.distance_to(p.global_position) < bd:
						bd = pk.pos.distance_to(p.global_position)
						best = pk.pos
				target = best
		"donut":
			for e in events:
				if e[0] == "donut_bribe":
					_next()
					return
			if GameState.donuts <= 0 and step_t > 1.0:
				GameState.donuts = 1
				GameState.pop(p.global_position + Vector3.UP * 2, "Spoke tossed you a donut!", Color("ff8fc8"))
		"signs":
			for i in s.n:
				var a: float = TAU * i / s.n
				var sp: Vector3 = s.pos + Vector3(cos(a) * 11.0, 0, sin(a) * 11.0)
				var b = w.fun.spawn_sign(sp, a, true)
				if b != null:
					story_signs.append(b)
			_next()
		"smash_signs":
			var left: Array = story_signs.filter(func(b): return is_instance_valid(b) and not b.get_meta("smashed", false))
			if not left.is_empty():
				target = left[0].global_position
			if left.is_empty():
				_next()
		"collect":
			if tokens.is_empty() and progress == 0.0:
				progress = 0.01
				for i in s.n:
					var bl: Dictionary = city.blocks[(i * 9 + 4) % city.blocks.size()]
					var tp: Vector3 = city.sidewalk_point(bl).pos + Vector3.UP * 0.9
					var t := Label3D.new()
					t.text = "RAMP\nPART"
					t.font_size = 64
					t.pixel_size = 0.008
					t.outline_size = 16
					t.modulate = Color("39ff14")
					t.billboard = BaseMaterial3D.BILLBOARD_ENABLED
					t.position = tp
					add_child(t)
					tokens.append(t)
			var best = null
			var bd := 1e9
			for t in tokens.duplicate():
				var d := p.global_position.distance_to(t.position)
				if d < 2.0:
					tokens.erase(t)
					t.queue_free()
					Sfx.play("pickup")
					GameState.pop(p.global_position + Vector3.UP * 2, "RAMP PART %d/%d" % [s.n - tokens.size(), s.n], Color("39ff14"))
				elif d < bd:
					bd = d
					best = t.position
			target = best
			if tokens.is_empty():
				_next()
		"reward":
			GameState.cred += s.cred
			add_revolution(s.rev)
			GameState.story = active + 1
			if s.get("final", false):
				GameState.say_banner("ACT 1 COMPLETE!", "+$%d  •  The Ramp Revolution has begun. Spoke has a new job for you..." % s.cred, STORY_COL)
				w.fx_confetti(p.global_position, 200)
			elif s.get("final2", false):
				GameState.say_banner("ACT 2 COMPLETE!", "+$%d  •  Los Spokos is a ramp city now. You did that." % s.cred, STORY_COL)
				w.fx_confetti(p.global_position, 300)
			else:
				GameState.say_banner("MISSION PASSED", "+$%d  •  RESPECT +" % s.cred, Color("8cff6a"))
			Sfx.play("big")
			_cleanup()
			lock = true
			GameState.save_game()
			_next()

func _fail(reason: String) -> void:
	GameState.say_banner("MISSION FAILED", reason + "  Roll back to Spoke to try again.", Color("ff5c8a"))
	Sfx.play("busted")
	active = -1
	lock = true
	_cleanup()

func _cleanup() -> void:
	for t in tokens:
		if is_instance_valid(t):
			t.queue_free()
	tokens.clear()
	for b in story_signs:
		if is_instance_valid(b):
			b.queue_free()
	story_signs.clear()
	for c in story_crates:
		if is_instance_valid(c):
			c.queue_free()
	story_crates.clear()
	if baron != null and is_instance_valid(baron):
		w.remove_chair(baron)
	baron = null
	target = null
	beam.visible = false

func _spawn_baron(pos: Vector3) -> void:
	if baron != null:
		return
	baron = w.spawn_chair("power", pos + Vector3(0, 0.2, -2), PI)
	var r := Models.rider("npc", {"hat": "", "hair": "HairShort", "print": -1, "face": 2, "shirt": Color("2a2a2a"), "pants": Color("1a1a1a"), "hair_color": Color("dddddd")})
	baron.set_rider(r, "npc")
	baron.mode = "parked"
	baron.set_meta("nosteal", true)
	Models.apply_style(baron.model, {"paint": "black", "rims": true, "dice": false})
	var hat := Node3D.new()
	hat.name = "TopHat"
	r.add_child(hat)
	var black := Models.mat(Color("111111"), 0.4)
	Models.cyl(hat, 0.12, 0.26, Vector3(0, 1.6, 0.04), black, Vector3.ZERO, 16)
	Models.cyl(hat, 0.2, 0.02, Vector3(0, 1.47, 0.04), black, Vector3.ZERO, 16)
	Models.cyl(hat, 0.123, 0.04, Vector3(0, 1.5, 0.04), Models.mat(Color("e63946"), 0.5), Vector3.ZERO, 16)
	Models.torus(r, 0.025, 0.033, Vector3(0.05, 1.35, -0.125), Models.mat(Color("ffd700"), 0.2, 1.0), Vector3(PI / 2, 0, 0))
	for k in 2:
		var cop: Chair = w.spawn_chair("cop", pos + Vector3(-2.5 + k * 5.0, 0.2, -1), PI, "cop")
		cop.spawned_cop = true

func objective() -> String:
	if active < 0:
		return ""
	var s := cur()
	var txt: String = s.get("text", "")
	if txt == "":
		return ""
	if s.has("time"):
		var left: float = max(0.0, s.time - step_t)
		txt += "   (%d:%02d)" % [floori(left / 60.0), int(left) % 60]
	if s.type == "smash":
		txt += "   %d/%d" % [smashed, s.n]
	return missions[active].title + ":  " + txt

# ------------------------------------------------------------------ Ramp Revolution
func add_revolution(n: int) -> void:
	var before: int = GameState.revolution
	GameState.revolution = clampi(GameState.revolution + n, 0, 100)
	if GameState.revolution != before:
		_update_stairs(true)

func _build_crates() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var placed := 0
	var tries := 0
	while placed < 24 and tries < 400:
		tries += 1
		var bl: Dictionary = city.blocks[rng.randi() % city.blocks.size()]
		var p := city.sidewalk_point(bl)
		var pos: Vector3 = p.pos + Vector3(rng.randf_range(-1, 1), 0.45, rng.randf_range(-1, 1))
		var bad := false
		for k in city.points.values():
			if k.distance_to(pos) < 8.0:
				bad = true
		for s in stairs:
			if s.pos.distance_to(pos) < 6.0:
				bad = true
		if bad:
			continue
		var id := placed
		placed += 1
		if GameState.crates_smashed.has(id):
			continue
		var c := _crate(pos, false)
		c.set_meta("crate_id", id)
		crates.append(c)

func _crate(pos: Vector3, story: bool) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.collision_layer = 8
	b.collision_mask = 1 | 8
	b.mass = 12.0
	b.freeze = true
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.9, 0.9, 0.9)
	cs.shape = bs
	b.add_child(cs)
	var wood := Models.mat(Color("a0703f"), 0.9)
	var dark := Models.mat(Color("6b4423"), 0.9)
	Models.box(b, Vector3(0.9, 0.9, 0.9), Vector3.ZERO, wood)
	for e in [Vector3(0, 0.44, 0), Vector3(0, -0.44, 0)]:
		Models.box(b, Vector3(0.94, 0.06, 0.94), e, dark)
	Models.box(b, Vector3(0.06, 0.94, 0.94), Vector3(0.44, 0, 0), dark)
	Models.box(b, Vector3(0.06, 0.94, 0.94), Vector3(-0.44, 0, 0), dark)
	for side in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = "STAIRS\nINC."
		l.font_size = 48
		l.pixel_size = 0.005
		l.outline_size = 8
		l.modulate = Color("ff5c8a")
		l.position = Vector3(0, 0, side * 0.465)
		l.rotation.y = 0.0 if side > 0 else PI
		b.add_child(l)
	Models.set_shadows(b)
	b.position = pos
	b.rotation.y = randf() * TAU
	b.set_meta("crate", true)
	b.set_meta("story", story)
	w.add_child(b)
	return b

func crate_hit(b: RigidBody3D, c: Chair) -> void:
	if b.get_meta("smashed", false) or c != GameState.player:
		return
	b.set_meta("smashed", true)
	b.freeze = false
	w._particles(b.global_position + Vector3.UP * 0.3, Color(0.65, 0.45, 0.25), 24, 5.0, 1.2, 1.2, -9.0, 80.0)
	Sfx.play("crash")
	var story: bool = b.get_meta("story", false)
	if not story and b.has_meta("crate_id"):
		GameState.crates_smashed.append(b.get_meta("crate_id"))
		add_revolution(2)
		GameState.add_cred(20, b.global_position + Vector3.UP * 1.5, "STAIRS SMASHED! +$20  •  REVOLUTION %d%%" % GameState.revolution)
	else:
		GameState.add_cred(20, b.global_position + Vector3.UP * 1.5, "STAIRS SMASHED! +$20")
	GameState.event.emit("crate", {"story": story})
	get_tree().create_timer(6.0).timeout.connect(b.queue_free)

func _build_stairs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var tries := 0
	while stairs.size() < 6 and tries < 300:
		tries += 1
		var bl: Dictionary = city.blocks[rng.randi() % city.blocks.size()]
		if bl.type in ["hospital", "police", "chop", "pimp", "pizza"]:
			continue
		var side := rng.randi() % 4
		var x0: float = bl.x0
		var z0: float = bl.z0
		var a := City.WALK / 2.0
		var b := City.BLOCK - City.WALK / 2.0
		var mid := City.BLOCK / 2.0 + 6.0
		var pos: Vector3
		var yaw: float
		match side:
			0:
				pos = Vector3(x0 + mid, City.CURB, z0 + a)
				yaw = -PI / 2
			1:
				pos = Vector3(x0 + b, City.CURB, z0 + mid)
				yaw = PI
			2:
				pos = Vector3(x0 + mid, City.CURB, z0 + b)
				yaw = PI / 2
			_:
				pos = Vector3(x0 + a, City.CURB, z0 + mid)
				yaw = 0.0
		var bad := false
		for s in stairs:
			if s.pos.distance_to(pos) < 40.0:
				bad = true
		if bad:
			continue
		stairs.append({"pos": pos, "yaw": yaw, "node": null, "ramp": false})

func _update_stairs(announce: bool) -> void:
	for i in stairs.size():
		var s: Dictionary = stairs[i]
		var should_ramp: bool = GameState.revolution >= (i + 1) * 15
		if s.node != null and s.ramp == should_ramp:
			continue
		if s.node != null:
			s.node.queue_free()
		s.ramp = should_ramp
		s.node = _ramp_hump(s.pos, s.yaw) if should_ramp else _staircase(s.pos, s.yaw)
		if should_ramp and announce:
			GameState.say_banner("REVOLUTION %d%%" % GameState.revolution, "One of the Baron's staircases is now a RAMP!", STORY_COL)
			w.fx_confetti(s.pos, 80)

func _staircase(pos: Vector3, yaw: float) -> Node3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	var grey := Models.mat(Color("b3aca0"), 0.85)
	var edge := Models.mat(Color("e63946"), 0.6)
	var step_h := 0.2
	var step_d := 0.4
	var W := 3.0
	for k in 4:
		for sgn in [1.0, -1.0]:
			var z: float = sgn * (0.5 + 1.6 - k * step_d - step_d / 2)
			var h := (k + 1) * step_h
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(W, h, step_d)
			cs.shape = bs
			cs.position = Vector3(0, h / 2, z)
			body.add_child(cs)
			Models.box(body, Vector3(W, h, step_d), Vector3(0, h / 2, z), grey)
			Models.box(body, Vector3(W, 0.03, 0.06), Vector3(0, h + 0.015, z + sgn * (step_d / 2 - 0.03)), edge)
	var top := CollisionShape3D.new()
	var tb := BoxShape3D.new()
	tb.size = Vector3(W, 0.8, 1.0)
	top.shape = tb
	top.position = Vector3(0, 0.4, 0)
	body.add_child(top)
	Models.box(body, Vector3(W, 0.8, 1.0), Vector3(0, 0.4, 0), grey)
	var rail := Models.mat(Color("ffd700"), 0.3, 0.9)
	for x in [-W / 2 + 0.05, W / 2 - 0.05]:
		Models.cyl(body, 0.03, 4.4, Vector3(x, 1.4, 0), rail, Vector3(PI / 2, 0, 0), 8)
	var sign_l := Label3D.new()
	sign_l.text = "BARON STAIRWELL'S\nOFFICIAL STAIRS\n(no ramps allowed)"
	sign_l.font_size = 40
	sign_l.pixel_size = 0.006
	sign_l.outline_size = 10
	sign_l.modulate = Color("ff5c8a")
	sign_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_l.position = Vector3(0, 2.4, 0)
	body.add_child(sign_l)
	Models.set_shadows(body)
	w.add_child(body)
	return body

func _ramp_hump(pos: Vector3, yaw: float) -> Node3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	var W := 1.5
	var H := 0.8
	var L := 1.6
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("b388ff")
	m.roughness = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for sgn in [1.0, -1.0]:
		var pts := PackedVector3Array([Vector3(-W, 0, sgn * (0.5 + L)), Vector3(W, 0, sgn * (0.5 + L)), Vector3(W, H, sgn * 0.5), Vector3(-W, H, sgn * 0.5), Vector3(W, 0, sgn * 0.5), Vector3(-W, 0, sgn * 0.5)])
		var cs := CollisionShape3D.new()
		var sh := ConvexPolygonShape3D.new()
		sh.points = pts
		cs.shape = sh
		body.add_child(cs)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for tri in [[0, 1, 2], [0, 2, 3], [0, 3, 5], [1, 4, 2]]:
			for k in tri:
				st.add_vertex(pts[k])
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = m
		body.add_child(mi)
	var top := CollisionShape3D.new()
	var tb := BoxShape3D.new()
	tb.size = Vector3(W * 2, H, 1.0)
	top.shape = tb
	top.position = Vector3(0, H / 2, 0)
	body.add_child(top)
	Models.box(body, Vector3(W * 2, H, 1.0), Vector3(0, H / 2, 0), m)
	var l := Label3D.new()
	l.text = "REVOLUTION RAMP"
	l.font_size = 40
	l.pixel_size = 0.006
	l.outline_size = 10
	l.modulate = STORY_COL
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, 2.0, 0)
	body.add_child(l)
	Models.set_shadows(body)
	w.add_child(body)
	return body
