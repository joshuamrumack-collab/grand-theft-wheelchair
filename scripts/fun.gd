extends Node3D
## Sillier police chases and street pickups:
##   * Donut boxes on the sidewalks. Press F (gamepad LB) to toss a donut behind you:
##     cops who see it stop to eat ("NOM NOM") and forget about you for a bit.
##   * Hide in a dumpster: stop next to one while wanted and press E. Press E again to pop out.
##   * Cops trip over traffic cones and barriers.
##   * STAIRS INC. signs to smash (goals + story).

const COP_DONUT := ["Is that... maple glaze?!", "Donut break!", "NOM NOM NOM", "We'll get you after this one.", "Sprinkles! My weakness!"]
const COP_LOST := ["Where'd they go?", "Has anyone seen a wheelchair?", "Smells like garbage... and freedom.", "They vanished!"]
const COP_TRIP := ["WHOA!", "Who put a cone there?!", "My dignity!", "I meant to do that.", "Cone 1, Cop 0."]

var w
var pickups: Array = []        # {node, pos, t}
var thrown: Array = []         # {body, t, eaten}
var signs: Array = []          # RigidBody3D
var hidden: bool = false
var hide_spot := Vector3.ZERO
var lost_t: float = 0.0

func setup(world) -> void:
	w = world
	for p in w.city.donut_spots:
		var m := Models.street("donuts")
		if m == null:
			break
		m.position = p + Vector3.UP * 0.35
		add_child(m)
		pickups.append({"node": m, "pos": p, "t": 0.0})
	for s in w.city.sign_spots:
		spawn_sign(s.pos, s.yaw)

func spawn_sign(pos: Vector3, yaw: float, story: bool = false) -> RigidBody3D:
	var m := Models.street("stairs_sign")
	if m == null:
		return null
	var b := RigidBody3D.new()
	b.collision_layer = 8
	b.collision_mask = 1 | 8
	b.mass = 4.0
	b.freeze = true
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.25, 1.35, 0.4)
	cs.shape = bs
	cs.position.y = 0.67
	b.add_child(cs)
	b.add_child(m)
	b.position = pos
	b.rotation.y = yaw
	b.set_meta("stairs_sign", true)
	b.set_meta("story", story)
	add_child(b)
	signs.append(b)
	return b

func sign_hit(b: RigidBody3D, c: Chair) -> void:
	if b.get_meta("smashed", false):
		return
	b.set_meta("smashed", true)
	Sfx.play("crash", 0.9)
	w.fx_dust(b.global_position + Vector3.UP * 0.6, 16)
	if c == GameState.player:
		GameState.add_cred(40, b.global_position + Vector3.UP * 2, ["STAIRS? NOT TODAY! +$40", "SIGN OFF! +$40", "RAMPS RULE! +$40"].pick_random())
		GameState.event.emit("stairs_sign", {"story": b.get_meta("story", false)})
		w.story.add_revolution(1)
	var wr: WeakRef = weakref(b)
	get_tree().create_timer(12.0).timeout.connect(func():
		var bb = wr.get_ref()
		if bb != null and not bb.get_meta("story", false):
			signs.erase(bb)
			bb.queue_free())

func _physics_process(dt: float) -> void:
	if w == null or w.state == "title":
		return
	var p: Chair = GameState.player
	# pickups bob and spin; respawn after a minute
	for pk in pickups:
		var n: Node3D = pk.node
		if not n.visible:
			pk.t -= dt
			if pk.t <= 0.0:
				n.visible = true
			continue
		n.rotation.y += dt * 2.0
		n.position.y = pk.pos.y + 0.35 + sin(GameState.time * 3.0) * 0.08
		if p.global_position.distance_to(n.global_position) < 1.4 and GameState.donuts < 5:
			n.visible = false
			pk.t = 60.0
			GameState.donuts += 1
			Sfx.play("pickup")
			GameState.pop(n.global_position + Vector3.UP, "DONUTS x%d  (F to throw)" % GameState.donuts, Color("ff8fc8"))
	# thrown donuts: when they settle, nearby cops stop to eat them
	for d in thrown.duplicate():
		d.t += dt
		var b: RigidBody3D = d.body
		if not is_instance_valid(b):
			thrown.erase(d)
			continue
		if not d.eaten and d.t > 0.5:
			for c in w.chairs:
				if c.mode == "cop" and c.stunned <= 0.0 and c.global_position.distance_to(b.global_position) < 11.0:
					c.stunned = 7.0
					c.chase = false
					c.say(COP_DONUT.pick_random(), 2.5)
					d.eaten = true
					Sfx.play("nom", randf_range(0.9, 1.2), -4.0)
					GameState.event.emit("donut_bribe", {})
					GameState.wanted_cool += 3.0
		if d.t > 9.0:
			b.queue_free()
			thrown.erase(d)
	# hiding: wanted level cools down 3x faster and cops lose track
	if hidden:
		p.global_position = hide_spot
		lost_t -= dt
		if GameState.wanted > 0:
			GameState.wanted_cool += dt * 2.0
			if lost_t <= 0.0:
				lost_t = 3.0
				for c in w.chairs:
					if c.mode == "cop" and c.global_position.distance_to(p.global_position) < 30.0:
						c.chase = false
						c.say(COP_LOST.pick_random(), 2.2)
						break

func throw_donut() -> void:
	var p: Chair = GameState.player
	if GameState.donuts <= 0:
		GameState.pop(p.global_position + Vector3.UP * 2, "No donuts! Find a pink box.", Color("ff8fc8"))
		return
	GameState.donuts -= 1
	var b := RigidBody3D.new()
	b.collision_layer = 16
	b.collision_mask = 1 | 8 | 16
	b.mass = 0.4
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.15
	sh.height = 0.08
	cs.shape = sh
	b.add_child(cs)
	Models.torus(b, 0.05, 0.14, Vector3.ZERO, Models.mat(Color("d9a066"), 0.7), Vector3.ZERO)
	Models.torus(b, 0.06, 0.13, Vector3(0, 0.03, 0), Models.mat(Color("ff4fb0"), 0.3), Vector3.ZERO)
	add_child(b)
	b.global_position = p.global_position + Vector3.UP * 1.2 - p.forward() * 0.6
	b.linear_velocity = p.velocity * 0.3 - p.forward() * 6.0 + Vector3.UP * 4.0
	b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), 0)
	thrown.append({"body": b, "t": 0.0, "eaten": false})
	Sfx.play("throw")

func near_dumpster() -> Vector3:
	var p: Chair = GameState.player
	for d in w.city.dumpsters:
		if Vector2(d.x - p.global_position.x, d.z - p.global_position.z).length() < 2.4:
			return d
	return Vector3.INF

func toggle_hide() -> bool:
	var p: Chair = GameState.player
	if hidden:
		hidden = false
		p.frozen = false
		p.visible = true
		p.velocity = Vector3.ZERO
		p.global_position = hide_spot + Vector3(0, 0.3, 0)
		Sfx.play("bonk", 1.3)
		GameState.pop(p.global_position + Vector3.UP * 2, "SURPRISE!", Color("8cff6a"))
		return true
	var d := near_dumpster()
	if d == Vector3.INF or not p.is_on_floor() or p.speed() > 2.0:
		return false
	hidden = true
	p.frozen = true
	p.visible = false
	p.wheelie = false
	hide_spot = p.global_position
	lost_t = 1.0
	Sfx.play("bonk", 0.7)
	GameState.say_banner("HIDING IN A DUMPSTER", "Smells great. Press E to pop out.", Color("8cff6a"))
	return true

func cop_tripped(c: Chair) -> void:
	if c.stunned > 0.0:
		return
	c.stunned = 2.5
	c.spin = randf_range(-0.5, 0.5)
	c.velocity *= 0.3
	c.say(COP_TRIP.pick_random(), 2.0)
	Sfx.play("bonk", 0.8)
	GameState.event.emit("cop_trip", {})
