class_name Car
extends Node3D
## Traffic car: drives straight along its lane, brakes for chairs and cars ahead,
## honks, rides over ramps, knocks chairs around, wraps at the edge of the map.

const HONKS := ["HONK!", "BEEEP!", "Watch it, wheels!", "*angry honking*", "Move it, speedy!"]
var dir := Vector3.RIGHT
var base_speed: float = 9.0
var v: float = 9.0
var model: Node3D
var wheels: Array = []
var tail: StandardMaterial3D
var headlight: SpotLight3D
var honk_t: float = 0.0
var stop_t: float = 0.0
var braking: bool = false
var wrot: float = 0.0
var y_off: float = 0.0
var vy: float = 0.0
var id: int = 0
const HL := 2.2   # half length
const HW := 0.95  # half width

func setup(pos: Vector3, d: Vector3, spd: float, taxi: bool, n: int) -> void:
	position = pos
	dir = d
	base_speed = spd
	v = spd
	id = n
	rotation.y = atan2(-d.x, -d.z)
	model = Models.car(taxi)
	add_child(model)
	Models.set_layers(model, 2)
	var bl := Models.blob_shadow(2.3)
	bl.size = Vector3(2.3, 3.2, 4.8)
	add_child(bl)
	wheels = model.get_meta("wheels", [])
	tail = model.get_meta("tail")
	headlight = SpotLight3D.new()
	headlight.position = Vector3(0, 0.8, -2.3)
	headlight.rotation = Vector3(-0.12, 0, 0)
	headlight.spot_range = 22.0
	headlight.spot_angle = 32.0
	headlight.light_color = Color("fff1c8")
	headlight.light_energy = 0.0
	headlight.shadow_enabled = false
	headlight.visible = false
	add_child(headlight)

func _physics_process(dt: float) -> void:
	var w = GameState.world
	if w == null:
		return
	var blocked := false
	var by_player := false
	if stop_t < 3.0:
		for c in w.chairs:
			if c.global_position.y - position.y > 1.2:
				continue
			if _ahead(c.global_position, 1.6):
				blocked = true
				by_player = c == GameState.player
				break
		if not blocked:
			for o in w.cars:
				if o == self or abs(o.position.x - position.x) > 14.0 or abs(o.position.z - position.z) > 14.0:
					continue
				var same: bool = o.dir.is_equal_approx(dir)
				if (same or o.id < id) and _ahead(o.position, 0.7 if same else 2.0):
					blocked = true
					break
	var tv := 0.0 if blocked else base_speed
	braking = tv < v - 0.05
	v = lerpf(v, tv, (10.0 if blocked else 1.6) * dt)
	if v < 0.3:
		stop_t += dt
	else:
		stop_t = 0.0
	if stop_t > 4.0:
		stop_t = 0.0
	honk_t -= dt
	if by_player and v < 1.0 and honk_t <= 0.0 and w.state == "play":
		honk_t = randf_range(3.0, 5.0)
		Sfx.play("honk", randf_range(0.9, 1.1), -4.0)
		GameState.pop(position + Vector3.UP * 2.2, HONKS.pick_random(), Color("ffd84a"))
	position += dir * v * dt
	# ride over ramps
	var q := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 3.0, position + Vector3.DOWN * 0.5, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var ground := 0.0
	if hit:
		ground = hit.position.y
	if ground > y_off:
		y_off = ground
		vy = max(vy, 0.0)
	else:
		vy -= 22.0 * dt
		y_off = max(ground, y_off + vy * dt)
	position.y = y_off
	var S := City.SIZE
	if position.x > S + 10: position.x = -10
	if position.x < -10: position.x = S + 10
	if position.z > S + 10: position.z = -10
	if position.z < -10: position.z = S + 10
	wrot += v * dt / 0.34
	for wh in wheels:
		wh[0].rotation.x = -wrot
	if tail != null:
		tail.emission_energy_multiplier = 3.0 if (braking or v < 0.3) else (1.0 if headlight.visible else 0.2)
	_hit_chairs(w)

func _ahead(p: Vector3, lat: float) -> bool:
	var r := p - position
	var ax := r.dot(dir)
	var ay := r.dot(Vector3(dir.z, 0, -dir.x))
	return ax > HL - 0.3 and ax < HL + 7.0 and abs(ay) < lat

func _hit_chairs(w) -> void:
	if v < 0.5:
		return
	var side := Vector3(dir.z, 0, -dir.x)
	for c in w.chairs:
		var r: Vector3 = c.global_position - position
		if r.y > 1.0:
			continue
		var ax := r.dot(dir)
		var ay := r.dot(side)
		var cr: float = c.radius
		if abs(ax) < HL + cr and abs(ay) < HW + cr:
			var ox: float = HL + cr - abs(ax)
			var oy: float = HW + cr - abs(ay)
			var push: Vector3 = dir * sign(ax) * ox if ox < oy else side * sign(ay) * oy
			c.global_position += push
			var big: bool = c.stats.get("big", false)
			var k := 0.6 if big else 1.3
			c.velocity += dir * v * k + push.normalized() * 2.5 + Vector3.UP * 2.0
			if v > 3.0:
				c.spin = randf_range(-0.35, 0.35) * (0.4 if big else 1.0)
				if c == GameState.player:
					w.shake(0.6)
					Sfx.play("crash")
					GameState.pop(c.global_position + Vector3.UP * 2, ["WHAM!", "FENDER BENDER!", "NOT INSURED!"].pick_random())
				elif c.rider != null and randf() < 0.5:
					c.say(["WAAAH!", "My chair insurance!", "Not again!"].pick_random(), 1.6)
			if big and c == GameState.player:
				v = -2.0
				GameState.pop(position + Vector3.UP * 2, "MONSTER BONK!", Color("3fb950"))
			else:
				v *= 0.3

func set_night(on: bool) -> void:
	headlight.visible = on
	headlight.light_energy = 2.0 if on else 0.0
