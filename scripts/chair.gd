class_name Chair
extends CharacterBody3D
## One wheelchair. Driven by the player, an NPC, a police officer, or nobody (parked).
## Handling model: forward momentum + sideways grip (low grip = drift), spins on the spot,
## climbs curbs, launches off ramps.

const GRAV := 22.0
const LINES := ["HEY! That's MY chair!", "I just had that waxed!", "Ugh. Fine. I'll take yours.", "My mum bought me that!",
	"I'm telling the Kerb Patrol!", "Not AGAIN...", "Your chair smells like cheese.", "Rude. Very rude.",
	"I wasn't done rolling!", "At least leave the cupholder!", "My snacks were in there!"]
const COP_LINES := ["That's GOVERNMENT PROPERTY!", "Dispatch... he took my chair.", "This is SO going in my report."]
const COP_SHOUT := ["Pull over! ...Roll over?", "Stop in the name of the ramp!", "You have the right to remain seated!", "Freeze, wheel-thief!"]

var type: String = "rusty"
var stats: Dictionary = {}
var mode: String = "parked"          # player / npc / cop / parked
var rider: Node3D = null
var rider_kind: String = ""
var yaw: float = 0.0
var thr: float = 0.0
var steer: float = 0.0
var boost: bool = false
var visual: Node3D
var model: Node3D
var seat: Node3D
var wheels: Array = []
var lights: Array = []
var radius: float = 0.4
var wr: float = 0.0
var air_t: float = 0.0
var spin: float = 0.0
var wheelie: bool = false
var wheelie_t: float = 0.0
var bonk_time: float = -10.0
var boost_meter: float = 1.0
var prev_vel := Vector3.ZERO
var was_ramp: bool = false
var spawned_cop: bool = false
var bubble: Label3D
var bubble_t: float = 0.0
var squeak_t: float = 0.0
# skate-game trick pose (set by tricks.gd, added on top of the normal animation)
var trick_yaw: float = 0.0
var trick_pitch: float = 0.0
var trick_roll: float = 0.0
var blob: Decal
var hop_req: bool = false
var rig = null                       # rider_rig.gd when the rider has a skeleton
var grinding: bool = false           # tricks.gd drives the chair along a rail
var frozen: bool = false             # hiding in a dumpster / photo mode
var qp_dir := Vector3.ZERO           # up-ramp direction of the quarter pipe we are on
var qp_t: float = 0.0
var qp_ny: float = 1.0                # steepness where we last touched the quarter pipe
var vert: bool = false               # launched straight up out of a quarter pipe
var stunned: float = 0.0             # cops: tripped over a cone / eating a donut
const AIR_SPIN := 7.5
const HOP_V := 5.8
# AI state
var ai_block: Dictionary = {}
var ai_corner: int = 0
var ai_dir: int = 1
var angry_t: float = 0.0
var chase: bool = false
var stuck_t: float = 0.0
var reverse_t: float = 0.0
var reverse_dir: float = 1.0
var path := PackedVector2Array()
var path_i: int = 0
var path_t: float = 0.0
var los_t: float = 0.0
var los: bool = false
var shout_t: float = 0.0

func setup(t: String, y: float, kind: String = "") -> void:
	type = t
	stats = GameState.TYPES[t]
	yaw = y
	rotation.y = y
	radius = 0.5 if stats.get("big", false) else 0.4
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	cs.shape = sh
	cs.position = Vector3(0, radius, 0)
	add_child(cs)
	collision_layer = 2
	collision_mask = 1 | 2 | 8
	floor_max_angle = deg_to_rad(56)
	floor_snap_length = 0.3
	floor_stop_on_slope = false
	floor_block_on_wall = false
	wall_min_slide_angle = deg_to_rad(10)
	visual = Node3D.new()
	add_child(visual)
	model = Models.chair(t)
	visual.add_child(model)
	seat = model.find_child("Seat", true, false)
	Models.set_layers(model, 2)
	blob = Models.blob_shadow(1.25 if stats.get("big", false) else 1.0)
	add_child(blob)
	wheels = model.get_meta("wheels", [])
	lights = model.get_meta("lights", [])
	bubble = Label3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 44
	bubble.pixel_size = 0.006
	bubble.outline_size = 14
	bubble.modulate = Color.WHITE
	bubble.outline_modulate = Color(0, 0, 0, 0.9)
	bubble.position = Vector3(0, 2.05, 0)
	bubble.visible = false
	bubble.no_depth_test = true
	add_child(bubble)
	if kind != "":
		set_rider(Models.rider(kind), kind)

func set_rider(node: Node3D, kind: String) -> void:
	rider = node
	rider_kind = kind
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	seat.add_child(node)
	Models.set_layers(node, 2)
	rig = preload("res://scripts/rider_rig.gd").new()
	if not rig.setup(node):
		rig = null
	node.position = Vector3.ZERO
	node.rotation = Vector3.ZERO
	node.scale = Vector3.ONE
	var crown = node.find_child("Crown", true, false)
	if crown != null:
		crown.visible = type == "gold"
	mode = kind if kind in ["player", "npc", "cop"] else "parked"
	ai_block = {}

func take_rider() -> Array:
	var r := rider
	var k := rider_kind
	if r != null:
		seat.remove_child(r)
	rider = null
	rig = null
	rider_kind = ""
	mode = "parked"
	chase = false
	angry_t = 0.0
	return [r, k]

func say(text: String, dur: float = 2.6) -> void:
	bubble.text = text
	bubble.visible = true
	bubble_t = dur

func speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func hop() -> bool:
	if not is_on_floor() or spin != 0.0:
		return false
	hop_req = true
	Sfx.play("jump", 1.15)
	var w = GameState.world
	if w != null:
		w.fx_dust(global_position, 5)
	return true

func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

# ------------------------------------------------------------------ physics
func _physics_process(dt: float) -> void:
	var w = GameState.world
	if frozen or grinding:
		_animate(dt, false)
		return
	if stunned > 0.0:
		stunned -= dt
	match mode:
		"player": _player_input(w)
		"npc": _ai_npc(dt)
		"cop": _ai_cop(dt)
		"racer": _ai_racer(dt)
		_:
			thr = 0.0
			steer = 0.0
			boost = false
	var on_floor := is_on_floor()
	var maxs: float = stats["max"]
	var acc: float = stats["acc"]
	var grip: float = stats["grip"]
	var boosting := boost and thr > 0.0 and (mode != "player" or boost_meter > 0.02)
	if mode == "player":
		boost_meter = clampf(boost_meter + (-0.4 if boosting else 0.13) * dt, 0.0, 1.0)
	if spin != 0.0:
		yaw += spin * dt * 60.0
		spin *= pow(0.93, dt * 60.0)
		if abs(spin) < 0.01:
			spin = 0.0
	if on_floor:
		yaw += steer * float(stats["turn"]) * dt * (0.3 if spin != 0.0 else 1.0)
	var fwd := forward()
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var hv := Vector3(velocity.x, 0, velocity.z)
	var hv0 := hv.length()
	var f := hv.dot(fwd)
	var l := hv.dot(right)
	if on_floor:
		if was_ramp == false and air_t > 0.35:
			_landed()
		air_t = 0.0
		var mx := maxs * (1.45 if boosting else 1.0)
		if thr > 0.0:
			if f < mx:
				f += acc * thr * (1.7 if boosting else 1.0) * dt
		elif thr < 0.0:
			if f > 0.2:
				f -= acc * 2.2 * dt
			elif f > -mx * 0.45:
				f += acc * thr * 0.7 * dt
		else:
			f *= pow(0.965, dt * 60.0)
		if f > mx:
			f -= (f - mx) * 0.08 * dt * 60.0
		var drift: float = abs(l)
		l *= pow(1.0 - grip, dt * 60.0)
		if drift > 1.6 and w != null:
			w.add_skid(self)
		hv = fwd * f + right * l
		var n := get_floor_normal()
		var v := hv - n * hv.dot(n)
		if v.length() > 0.001:
			v = v.normalized() * hv.length()
		if n.y < 0.985 and v.length() > 0.05:
			# on a slope keep the real speed along the surface: gravity slows you going up and
			# speeds you up coming down (this is what makes quarter pipes and kickers work)
			var dir := v.normalized()
			var s3 := prev_vel.length() + (hv.length() - hv0) - GRAV * 0.5 * dir.y * dt
			v = dir * clampf(s3, -12.0, 24.0)
		velocity = v
		was_ramp = n.y < 0.985 and velocity.y > 0.4
		qp_t -= dt
		for i in get_slide_collision_count():
			var col := get_slide_collision(i).get_collider()
			if col != null and col.has_meta("qp"):
				qp_dir = col.get_meta("qp")
				qp_t = 0.15
				qp_ny = n.y
		if qp_t > 0.0 and n.y < 0.9:
			was_ramp = false
		vert = false
		if boosting and w != null and randf() < 0.5:
			w.fx_boost(self)
	else:
		if qp_t > 0.0 and velocity.y > 1.0 and air_t < 0.05 and qp_ny < 0.72:
			# vert: all the speed going up the quarter pipe becomes height, and we come back down into it
			var along := hv.dot(qp_dir)
			if along > 0.0:
				var h2 := hv - qp_dir * along
				velocity = Vector3(h2.x, 0, h2.z) - qp_dir * 0.6
				velocity.y = along * 0.85 + 2.2
				hv = Vector3(velocity.x, 0, velocity.z)
				vert = true
				was_ramp = false
				qp_t = 0.0
				if mode == "player":
					Sfx.play("jump", 0.9)
		if mode == "player" and air_t > 0.14:
			yaw += steer * AIR_SPIN * dt
		if was_ramp:
			velocity.y += hv.length() * 0.45
			was_ramp = false
			if mode == "player":
				Sfx.play("jump")
			elif rider != null and randf() < 0.5:
				say(["WHEEEE!", "YOLO!", "I regret nothing!"].pick_random(), 1.4)
		air_t += dt
		velocity.y -= GRAV * dt
	if hop_req:
		hop_req = false
		velocity.y = HOP_V + speed() * 0.04
		was_ramp = false
		air_t = 0.01
	prev_vel = velocity
	move_and_slide()
	_collisions()
	wr += f * dt
	rotation.y = yaw
	_animate(dt, on_floor)
	if mode == "player" and type == "rusty" and speed() > 1.5 and GameState.time > squeak_t:
		squeak_t = GameState.time + randf_range(0.35, 0.9)
		Sfx.play("squeak", randf_range(0.8, 1.3), -6.0)

func _landed() -> void:
	var imp := -prev_vel.y
	var w = GameState.world
	if w != null:
		w.fx_dust(global_position, 10)
	if mode == "player":
		Sfx.play("land")
		if w != null:
			w.shake(min(imp * 0.08, 0.6))
		if air_t > 0.45 and (w == null or w.get("tricks") == null):
			var g: int = mini(int(air_t * 180), 400)
			GameState.add_cred(g, global_position + Vector3.UP * 2, ["SICK AIR!", "AIRBORNE!", "TO THE MOON!", "RAMP LORD!"].pick_random() + " +$%d" % g)
		if w != null:
			w.on_player_landed(imp, air_t)

func _collisions() -> void:
	var w = GameState.world
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		var n := c.get_normal()
		var imp := -prev_vel.dot(n)
		if col is RigidBody3D:
			if col.freeze:
				col.freeze = false
			col.apply_central_impulse(-n * prev_vel.length() * col.mass * 0.6 + Vector3.UP * col.mass * 1.5)
			velocity = prev_vel * 0.8
			if w != null:
				w.on_prop_hit(col, self)
			continue
		if col is Chair:
			if imp > 0.0:
				col.velocity += -n * imp * 0.9
				velocity += n * imp * 0.4
				if imp > 3.0 and (mode == "player" or col.mode == "player") and GameState.time > bonk_time + 0.6:
					bonk_time = GameState.time
					Sfx.play("bonk")
					var other: Chair = col if mode == "player" else self
					other.spin = randf_range(-0.25, 0.25)
					GameState.pop(other.global_position + Vector3.UP * 2, "BUMP!")
					if other.rider_kind == "npc":
						other.say(["HEY!", "Watch where you roll!", "Bumper chairs?!", "My spine!"].pick_random(), 1.8)
			continue
		if abs(n.y) < 0.55 and imp > 0.5:
			velocity += Vector3(n.x, 0, n.z) * imp * 0.55
			if imp > 3.0 and GameState.time > bonk_time + 0.5:
				bonk_time = GameState.time
				if w != null:
					w.fx_sparks(c.get_position())
				if mode == "player":
					Sfx.play("bonk")
					if w != null:
						w.shake(min(imp * 0.06, 0.5))
					if imp > 5.0:
						GameState.pop(global_position + Vector3.UP * 2, ["CLONK!", "BONK!", "OOF!", "WALL: 1  YOU: 0"].pick_random())
				elif rider != null and randf() < 0.3:
					say(["Ow!", "Who put that wall there?!", "Totally meant to do that."].pick_random(), 1.5)

func _animate(dt: float, on_floor: bool) -> void:
	for w in wheels:
		w[0].rotation.x = -wr / float(w[1])
	var pitch := 0.0
	if on_floor:
		var n := get_floor_normal()
		pitch = -asin(clampf(n.dot(forward()), -1.0, 1.0))
	else:
		pitch = clampf(velocity.y * 0.05, -0.35, 0.35)
	var wob := sin(GameState.time * 30.0) * 0.06 if spin != 0.0 else 0.0
	var wh := 0.0
	if wheelie:
		wh = 0.38 + sin(GameState.time * (8.0 + wheelie_t * 3.0)) * 0.04 * (1.0 + wheelie_t * 0.6)
	if rig != null:
		rig.update(self, dt)
	if grinding or frozen:
		return
	var b := Basis(Vector3.UP, trick_yaw) * Basis(Vector3.RIGHT, pitch + wh + trick_pitch) * Basis(Vector3.FORWARD, wob + trick_roll)
	var piv := Vector3(0, 0.3 + clampf(abs(trick_roll) + abs(trick_pitch), 0.0, 1.0) * 0.35, 0.06)
	visual.transform = Transform3D(b, piv - b * piv)
	if lights.size() == 2:
		var on := int(GameState.time * 6.0) % 2 == 0
		lights[0].emission_energy_multiplier = 5.0 if on else 0.3
		lights[1].emission_energy_multiplier = 0.3 if on else 5.0
	if bubble_t > 0.0:
		bubble_t -= dt
		if bubble_t <= 0.0:
			bubble.visible = false

# ------------------------------------------------------------------ control
func _player_input(w) -> void:
	if w == null or w.state != "play" or w.hop != null:
		thr = 0.0
		steer = 0.0
		boost = false
		return
	thr = Input.get_axis("back", "forward")
	steer = Input.get_axis("right", "left")
	boost = Input.is_action_pressed("boost")
	if GameState.settings_toggle_boost:
		boost = w.boost_toggled
	if GameState.one_switch:
		# one-switch play: the chair rolls and steers itself; the single button does hop / tricks
		thr = 0.75
		boost = false
		steer = _assist_steer(1.0)
	elif GameState.assist_steer and absf(steer) < 0.1 and thr > 0.0:
		steer = _assist_steer(0.6)

## Steering help: look ahead with three rays and turn away from walls, buildings and props;
## on an open road, gently line up with the street grid.
func _assist_steer(strength: float) -> float:
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * 0.45
	var look := 5.0 + speed() * 0.6
	var hits := []
	for a in [-0.45, 0.0, 0.45]:
		var dir := Vector3(-sin(yaw + a), 0, -cos(yaw + a))
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * look, 1 | 8)
		q.exclude = [get_rid()]
		var r := space.intersect_ray(q)
		hits.append(1.0 if r.is_empty() else origin.distance_to(r.position) / look)
	if hits[1] < 0.95 or hits[0] < 0.6 or hits[2] < 0.6:
		# turn towards the more open side
		return clampf((hits[0] - hits[2]) * 3.0 + (0.8 if hits[0] >= hits[2] else -0.8) * (1.0 - hits[1]), -1.0, 1.0) * strength
	var grid := roundf(yaw / (PI / 2)) * (PI / 2)
	return clampf(wrapf(grid - yaw, -PI, PI) * 2.0, -0.5, 0.5) * strength

func _steer_to(target: Vector3, thr_max: float) -> float:
	var d := target - global_position
	d.y = 0
	var desired := atan2(-d.x, -d.z)
	var da := wrapf(desired - yaw, -PI, PI)
	steer = clampf(da * 2.5, -1.0, 1.0)
	thr = thr_max if abs(da) < 1.1 else 0.12
	return d.length()

func _stuck(dt: float) -> bool:
	if reverse_t > 0.0:
		reverse_t -= dt
		thr = -1.0
		steer = reverse_dir
		return true
	if thr > 0.3 and speed() < 0.6:
		stuck_t += dt
		if stuck_t > 0.8:
			stuck_t = 0.0
			reverse_t = 0.6
			reverse_dir = 1.0 if randf() < 0.5 else -1.0
	else:
		stuck_t = max(0.0, stuck_t - dt)
	return false

func _reset_ring() -> void:
	var city: City = GameState.world.city
	ai_block = city.block_at(global_position)
	var cs: Array = city.corners(ai_block)
	var best := 0
	var bd := 1e9
	for i in cs.size():
		var d: float = global_position.distance_to(cs[i])
		if d < bd:
			bd = d
			best = i
	ai_corner = best
	ai_dir = 1 if randf() < 0.5 else -1

func _ai_npc(dt: float) -> void:
	boost = false
	var w = GameState.world
	if w == null:
		return
	if _stuck(dt):
		return
	var p: Chair = GameState.player
	if angry_t > 0.0 and p != null and w.state == "play":
		angry_t -= dt
		var d := _steer_to(p.global_position, 0.85)
		if d < 2.0:
			thr = 0.0
		if angry_t <= 0.0:
			_reset_ring()
		return
	_wander(0.55)

func _wander(thr_max: float) -> void:
	var city: City = GameState.world.city
	if ai_block.is_empty():
		_reset_ring()
	var c: Vector3 = city.corners(ai_block)[ai_corner]
	var d := _steer_to(c, thr_max)
	if d < 1.3:
		if randf() < 0.3:
			var opts: Array = [[[-1, 0, 1], [0, -1, 3]], [[1, 0, 0], [0, -1, 2]], [[1, 0, 3], [0, 1, 1]], [[-1, 0, 2], [0, 1, 0]]][ai_corner]
			var o: Array = opts.pick_random()
			var nx: int = ai_block.bx + o[0]
			var nz: int = ai_block.bz + o[1]
			if nx >= 0 and nz >= 0 and nx < City.NB and nz < City.NB:
				ai_block = city.blocks[nz * City.NB + nx]
				ai_corner = o[2]
				return
		ai_corner = (ai_corner + ai_dir + 4) % 4

func _ai_racer(dt: float) -> void:
	var w = GameState.world
	if w == null or w.acts == null:
		return
	if w.acts.race_counting():
		thr = 0.0
		steer = 0.0
		boost = false
		return
	if _stuck(dt):
		return
	_steer_to(w.acts.race_target(self), 1.0)
	boost = abs(steer) < 0.3

func _ai_cop(dt: float) -> void:
	var w = GameState.world
	var p: Chair = GameState.player
	if w == null:
		return
	if stunned > 0.0:
		thr = 0.0
		steer = 0.0
		boost = false
		return
	if not chase or p == null or w.state != "play":
		boost = false
		if _stuck(dt):
			return
		_wander(0.6)
		return
	if _stuck(dt):
		return
	var to_p := p.global_position - global_position
	var dist := Vector2(to_p.x, to_p.z).length()
	los_t -= dt
	if los_t <= 0.0:
		los_t = 0.25
		los = w.line_of_sight(global_position, p.global_position)
	if los or dist < 8.0:
		var lead := clampf(dist / 12.0, 0.0, 1.2)
		_steer_to(p.global_position + p.velocity * lead, 1.0)
	else:
		path_t -= dt
		if path_t <= 0.0 or path.is_empty():
			path = w.city.road_path(global_position, p.global_position)
			path_i = 0
			path_t = 1.2
		while path_i < path.size() and Vector2(global_position.x, global_position.z).distance_to(path[path_i]) < 5.0:
			path_i += 1
		if path_i < path.size():
			_steer_to(Vector3(path[path_i].x, 0, path[path_i].y), 1.0)
		else:
			_steer_to(p.global_position, 1.0)
	boost = dist > 25.0 and GameState.wanted >= 3
	if GameState.time > shout_t and dist < 25.0:
		shout_t = GameState.time + randf_range(5.0, 10.0)
		say(COP_SHOUT.pick_random(), 2.2)
