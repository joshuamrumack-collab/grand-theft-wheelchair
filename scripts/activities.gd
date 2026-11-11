class_name Activities
extends Node3D
## Side activities: unique stunt jumps (with slow motion) and street races against the Rim Reapers crew.

const LAPS := 2
const RIVALS := ["Vex", "Chrome-Jo", "Spinz"]
const TAUNTS := ["Eat my dust!", "You call that a chair?", "Rim Reapers rule!", "See you at the finish. Much later."]

var w                                  # main game node
var city: City
var stunts: Array = []                 # {id, pos, yaw, label, done, area}
var stunt_active = null
var stunt_t: float = 0.0
# race
var race_start := Vector3.ZERO
var race_points: Array = []
var race: Dictionary = {}              # empty when no race is running
var race_ring: MeshInstance3D
var cp_ring: MeshInstance3D
var cp_next: MeshInstance3D
var race_lock: bool = false

func setup(world) -> void:
	w = world
	city = world.city
	_build_stunts()
	_build_race()

# ------------------------------------------------------------------ STUNT JUMPS
func _build_stunts() -> void:
	var spots := [[0, 1, 1], [2, 0, -1], [1, 4, 1], [5, 2, -1], [3, 5, 1], [4, 3, 1], [6, 4, -1], [2, 6, -1]]
	var id := 0
	for s in spots:
		var horizontal: bool = id % 2 == 0
		var line: int = s[0]
		var b: int = s[1]
		var c := line * City.PITCH + City.ROAD / 2.0
		var along := b * City.PITCH + City.ROAD + 20.0
		if b >= City.NB:
			along = (City.NB - 1) * City.PITCH + City.ROAD + 20.0
		var pos := Vector3(along, 0, c) if horizontal else Vector3(c, 0, along)
		var dir: int = s[2]
		var yaw: float
		if horizontal:
			yaw = -PI / 2 if dir > 0 else PI / 2
		else:
			yaw = PI if dir > 0 else 0.0
		var clash := false
		for r in city.ramps:
			if r.pos.distance_to(pos) < 9.0:
				clash = true
		if clash:
			pos += (Vector3(1, 0, 0) if horizontal else Vector3(0, 0, 1)) * 12.0
		_stunt_ramp(id, pos, yaw)
		id += 1

func _stunt_ramp(id: int, pos: Vector3, yaw: float) -> void:
	var L := 2.6
	var W := 2.1
	var H := 1.7
	var v := [Vector3(-W, 0, L), Vector3(W, 0, L), Vector3(W, 0, -L), Vector3(-W, 0, -L), Vector3(W, H, -L), Vector3(-W, H, -L)]
	var tris := [[0, 1, 4], [0, 4, 5], [3, 5, 4], [3, 4, 2], [1, 2, 4], [0, 5, 3], [0, 3, 2], [0, 2, 1]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector3(0, H / 3, -L / 3)
	for t in tris:
		var a: Vector3 = v[t[0]]
		var b: Vector3 = v[t[1]]
		var c: Vector3 = v[t[2]]
		var n := (c - a).cross(b - a).normalized()
		if n.dot((a + b + c) / 3.0 - centre) < 0:
			n = -n
		for p in [a, c, b]:
			st.set_normal(n)
			st.add_vertex(p)
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array(v)
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ff9f1c")
	m.roughness = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	body.add_child(mi)
	# chevrons on the slope and a striped back
	var black := Models.mat(Color("111111"), 0.6)
	var ang := atan2(H, 2 * L)
	for k in 3:
		var z := 1.5 - k * 1.5
		var y := H * (L - z) / (2 * L) + 0.02
		Models.box(body, Vector3(1.6, 0.02, 0.35), Vector3(-0.6, y, z), black, Vector3(ang, 0.5, 0))
		Models.box(body, Vector3(1.6, 0.02, 0.35), Vector3(0.6, y, z), black, Vector3(ang, -0.5, 0))
	for k in 5:
		Models.box(body, Vector3(0.8, H - 0.02, 0.05), Vector3(-1.7 + k * 0.85, (H - 0.02) / 2, -L - 0.02), black if k % 2 == 0 else Models.mat(Color("ffd84a"), 0.5))
	# flag poles
	for sx in [-1.0, 1.0]:
		Models.cyl(body, 0.05, 3.2, Vector3(sx * (W + 0.3), 1.6, -L), Models.mat(Color("dddddd"), 0.3, 0.8))
		Models.box(body, Vector3(0.02, 0.5, 0.8), Vector3(sx * (W + 0.3), 2.9, -L + 0.42), Models.mat(Color("e63946"), 0.6))
	Models.set_shadows(body)
	w.add_child(body)
	city.ramps.append({"pos": pos, "yaw": yaw})
	var lbl := Label3D.new()
	lbl.text = "STUNT JUMP"
	lbl.font_size = 64
	lbl.pixel_size = 0.008
	lbl.outline_size = 14
	lbl.modulate = Color("ffd84a")
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 4.0, -L)
	body.add_child(lbl)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var acs := CollisionShape3D.new()
	var ab := BoxShape3D.new()
	ab.size = Vector3(W * 2, 2.5, 1.2)
	acs.shape = ab
	acs.position = Vector3(0, H + 0.6, -L + 0.3)
	area.add_child(acs)
	body.add_child(area)
	var sdat := {"id": id, "pos": pos, "yaw": yaw, "label": lbl, "done": GameState.stunts_done.has(id), "mat": m}
	area.body_entered.connect(func(b): _stunt_enter(sdat, b))
	stunts.append(sdat)
	if sdat.done:
		_mark_done(sdat)

func _mark_done(s: Dictionary) -> void:
	s.label.text = "STUNT DONE"
	s.label.modulate = Color("8cff6a")
	s.mat.albedo_color = Color("6ab04c")

func _stunt_enter(s: Dictionary, body) -> void:
	if body != GameState.player or w.state != "play":
		return
	var p: Chair = body
	var f := Vector3(-sin(s.yaw), 0, -cos(s.yaw))
	if p.velocity.dot(f) < 5.0:
		return
	stunt_active = s
	stunt_t = 0.0

func _stunts(dt: float) -> void:
	if stunt_active == null:
		GameState.slowmo = 1.0
		return
	stunt_t += dt
	var p: Chair = GameState.player
	GameState.slowmo = 0.35 if not p.is_on_floor() else 1.0
	if stunt_t > 2.5 and p.is_on_floor():
		stunt_active = null

func on_land(air_t: float) -> void:
	if stunt_active == null:
		return
	var s: Dictionary = stunt_active
	stunt_active = null
	GameState.slowmo = 1.0
	if air_t < 0.6:
		GameState.say_banner("STUNT FAILED", "Not enough air. More speed! More turbo!", Color("ff5c8a"))
		return
	if s.done:
		GameState.add_cred(100, GameState.player.global_position + Vector3.UP * 2.5, "STUNT AGAIN +$100")
		return
	s.done = true
	GameState.stunts_done.append(s.id)
	_mark_done(s)
	GameState.cred += 500
	GameState.say_banner("UNIQUE STUNT BONUS!", "+$500   •   Stunt jumps %d / %d" % [GameState.stunts_done.size(), stunts.size()], Color("ffd84a"))
	w.fx_confetti(GameState.player.global_position, 90)
	Sfx.play("big")
	GameState.save_game()

# ------------------------------------------------------------------ STREET RACE
func _build_race() -> void:
	var loop := [Vector2i(3, 0), Vector2i(6, 0), Vector2i(6, 3), Vector2i(3, 3)]
	for k in loop.size():
		var a: Vector2i = loop[k]
		var b: Vector2i = loop[(k + 1) % loop.size()]
		var pa := Vector3(a.x * City.PITCH + City.ROAD / 2.0, 0, a.y * City.PITCH + City.ROAD / 2.0)
		var pb := Vector3(b.x * City.PITCH + City.ROAD / 2.0, 0, b.y * City.PITCH + City.ROAD / 2.0)
		var n := int(pa.distance_to(pb) / 25.0)
		for i in n:
			race_points.append(pa.lerp(pb, float(i + 1) / n))
	race_start = Vector3(3 * City.PITCH + City.ROAD + 8, City.CURB, City.ROAD + City.WALK / 2)
	race_ring = w._ring(race_start, Color("39ff14"), 2.0)
	var lbl := Label3D.new()
	lbl.text = "STREET RACE\nvs RIM REAPERS"
	lbl.font_size = 40
	lbl.pixel_size = 0.006
	lbl.outline_size = 12
	lbl.modulate = Color("39ff14")
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = race_start + Vector3.UP * 2.3
	w.add_child(lbl)
	cp_ring = w._ring(Vector3.ZERO, Color("39ff14"), 5.0)
	cp_ring.scale = Vector3(1, 6, 1)
	cp_next = w._ring(Vector3.ZERO, Color("39ff14"), 3.0)
	cp_ring.visible = false
	cp_next.visible = false

func _start_race() -> void:
	race_lock = true
	var p: Chair = GameState.player
	var grid := [Vector3(150, 0.1, 7.5), Vector3(150, 0.1, 2.5), Vector3(144, 0.1, 7.5), Vector3(144, 0.1, 2.5)]
	p.global_position = grid[0]
	p.yaw = -PI / 2
	p.velocity = Vector3.ZERO
	w.rig.snap()
	var racers: Array = [{"chair": p, "cp": 0, "lap": 0, "done": false, "name": "YOU"}]
	for i in 3:
		var c: Chair = w.spawn_chair("turbo", grid[i + 1], -PI / 2, "npc")
		c.mode = "racer"
		c.say(TAUNTS.pick_random(), 3.0)
		racers.append({"chair": c, "cp": 0, "lap": 0, "done": false, "name": RIVALS[i]})
	race = {"racers": racers, "count": 3.99, "t": 0.0, "finished": 0, "last_count": 4}
	GameState.say_sub("VEX (Rim Reapers)", "Two laps. No rules. Hope you brought a fast chair.", Color("ff3b3b"))

func race_target(c: Chair) -> Vector3:
	if race.is_empty():
		return c.global_position
	for r in race.racers:
		if r.chair == c:
			return race_points[r.cp]
	return c.global_position

func race_counting() -> bool:
	return not race.is_empty() and race.count > 0.0

func _race(dt: float) -> void:
	var p: Chair = GameState.player
	if race.is_empty():
		race_ring.visible = true
		var d := p.global_position.distance_to(race_start)
		if d > 5.0:
			race_lock = false
		elif not race_lock and d < 2.2 and w.hop == null and w.state == "play":
			_start_race()
		return
	race_ring.visible = false
	if w.state == "busted":
		_end_race("RACE OVER", "The Kerb Patrol doesn't do street racing.")
		return
	if race.count > 0.0:
		race.count -= dt
		var n := int(ceil(race.count))
		if n != race.last_count:
			race.last_count = n
			GameState.say_banner(str(n) if n > 0 else "GO!", "", Color("39ff14") if n == 0 else Color.WHITE)
			Sfx.play("steal" if n == 0 else "bonk", 1.5 if n == 0 else 2.0)
		for r in race.racers:
			r.chair.velocity = Vector3(0, r.chair.velocity.y, 0)
		if race.count <= 0.0:
			GameState.say_banner("GO!", "", Color("39ff14"))
		return
	race.t += dt
	var player_entry = null
	for r in race.racers:
		if r.done:
			continue
		var c: Chair = r.chair
		if r.name == "YOU":
			c = p
			r.chair = p
			player_entry = r
		elif c == p or not is_instance_valid(c) or c.mode != "racer":
			r.done = true
			r.dnf = true
			continue
		var target: Vector3 = race_points[r.cp]
		if Vector2(c.global_position.x - target.x, c.global_position.z - target.z).length() < 7.0:
			r.cp += 1
			if r.name == "YOU":
				Sfx.play("coo", 1.6, -8.0)
			if r.cp >= race_points.size():
				r.cp = 0
				r.lap += 1
				if r.lap >= LAPS:
					r.done = true
					race.finished += 1
					r.rank = race.finished
					if r.name == "YOU":
						_player_finished(r.rank)
						return
					else:
						c.say(["WINNER!", "Too easy.", "Rim Reapers forever!"].pick_random(), 3.0)
				elif r.name == "YOU":
					GameState.say_banner("FINAL LAP!", "", Color("39ff14"))
	# checkpoint markers for the player
	if player_entry != null:
		cp_ring.visible = true
		cp_next.visible = true
		cp_ring.global_position = race_points[player_entry.cp] + Vector3.UP * 1.5
		cp_next.global_position = race_points[(player_entry.cp + 1) % race_points.size()] + Vector3.UP * 0.25

func positions() -> Array:
	var arr: Array = race.racers.duplicate()
	arr.sort_custom(func(a, b):
		var sa: float = (100000.0 - a.get("rank", 0) * 1000.0) if a.done and not a.get("dnf", false) else (a.lap * 100.0 + a.cp)
		var sb: float = (100000.0 - b.get("rank", 0) * 1000.0) if b.done and not b.get("dnf", false) else (b.lap * 100.0 + b.cp)
		return sa > sb)
	return arr

func race_text() -> String:
	if race.is_empty():
		return ""
	var me = race.racers[0]
	var pos := positions().find(me) + 1
	return "RACE   LAP %d/%d   •   CHECKPOINT %d/%d   •   POSITION %d/4   •   %d:%02d" % [min(me.lap + 1, LAPS), LAPS, me.cp + 1, race_points.size(), pos, floori(race.t / 60.0), int(race.t) % 60]

func _player_finished(rank: int) -> void:
	var pay: int = [1500, 500, 200, 0][clampi(rank - 1, 0, 3)]
	GameState.cred += pay
	if rank == 1:
		GameState.races_won += 1
		GameState.say_banner("YOU WIN!", "+$%d  •  The Rim Reapers respect you now. A bit." % pay, Color("39ff14"))
		w.fx_confetti(GameState.player.global_position, 120)
		Sfx.play("big")
	else:
		GameState.say_banner("FINISHED #%d" % rank, ("+$%d" % pay) if pay > 0 else "The Rim Reapers are laughing at you.", Color("ffd84a"))
	_end_race("", "")
	GameState.save_game()

func _end_race(title: String, sub: String) -> void:
	if title != "":
		GameState.say_banner(title, sub, Color("ff5c8a"))
	for r in race.racers:
		var c = r.chair
		if r.name != "YOU" and is_instance_valid(c) and c.mode == "racer":
			c.mode = "npc"
			c.ai_block = {}
	race = {}
	cp_ring.visible = false
	cp_next.visible = false
	race_lock = true

func _physics_process(dt: float) -> void:
	if w == null or w.state == "title":
		return
	_stunts(dt)
	_race(dt)
