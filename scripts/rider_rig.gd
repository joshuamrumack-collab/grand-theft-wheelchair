extends RefCounted
## Procedural animation for the Blender rider (rider.glb has a 17-bone skeleton made from the skin modifier).
## No animation clips: every frame we nudge a few bones from their seated rest pose.
##   rolling  -> both arms push the rims in a cycle that follows the wheel speed
##   turning  -> the upper body leans into the turn and the head looks where you go
##   airborne -> arms fly up (and out to the sides while grinding, for balance)
##   bail     -> slump forward, arms dangle
##   cheer    -> both arms up for a moment after a big combo

const BONES := ["Spine", "Chest", "Collar", "Neck", "UpperArm_L", "UpperArm_R", "Forearm_L", "Forearm_R", "Clavicle_L", "Clavicle_R"]

var skel: Skeleton3D
var ids := {}
var rest := {}
var inv := {}
var phase: float = 0.0
var push: float = 0.0
var lean: float = 0.0
var air: float = 0.0
var slump: float = 0.0
var balance: float = 0.0
var cheer_t: float = 0.0
var look: float = 0.0

func setup(root: Node) -> bool:
	var found := root.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return false
	skel = found[0]
	for n in BONES:
		var i := skel.find_bone(n)
		if i >= 0:
			ids[n] = i
			rest[n] = skel.get_bone_rest(i).basis.get_rotation_quaternion()
			inv[n] = skel.get_bone_global_rest(i).basis.inverse()
	return ids.size() >= 6

func cheer() -> void:
	cheer_t = 1.4

func _q(bone: String, axis: Vector3, angle: float) -> Quaternion:
	# rotation about a model-space axis, expressed in the bone's own rest frame
	return Quaternion((inv[bone] * axis).normalized(), angle)

func _pose(bone: String, q: Quaternion) -> void:
	if ids.has(bone):
		skel.set_bone_pose_rotation(ids[bone], rest[bone] * q)

func update(c, dt: float) -> void:
	if skel == null or not is_instance_valid(skel):
		return
	var spd: float = c.speed()
	var on_floor: bool = c.is_on_floor()
	var grinding: bool = c.grinding
	var crashed: bool = c.spin != 0.0
	var k := clampf(dt * 10.0, 0.0, 1.0)
	var moving: bool = on_floor and spd > 0.5 and not crashed and not c.wheelie
	push = lerpf(push, 1.0 if moving and (c.thr > 0.05 or spd > 2.5) else 0.0, k * 0.6)
	if moving:
		phase += dt * (3.0 + spd * 0.9)
	var in_air: bool = (not on_floor and c.air_t > 0.15) or grinding
	air = lerpf(air, 1.0 if in_air and not grinding else 0.0, k)
	balance = lerpf(balance, 1.0 if grinding else 0.0, k)
	slump = lerpf(slump, 1.0 if crashed else 0.0, k * 0.8)
	lean = lerpf(lean, clampf(c.steer * clampf(spd / 5.0, 0.0, 1.0), -1.0, 1.0) if on_floor else 0.0, k * 0.5)
	look = lerpf(look, c.steer * 0.35, k * 0.5)
	cheer_t = maxf(0.0, cheer_t - dt)
	var cheer_k := clampf(cheer_t * 2.0, 0.0, 1.0)
	var arms_up := maxf(air, cheer_k)
	# push cycle: hands sweep from behind the hip forwards along the rim, then recover high
	var s := sin(phase)
	var swing := (s * 0.55 + 0.1) * push
	var bend := (0.35 + cos(phase) * 0.3) * push
	var X := Vector3.RIGHT
	var Z := Vector3.BACK
	var Y := Vector3.UP
	# torso
	var torso_pitch := -0.12 * push * (0.5 + 0.5 * s) - 0.55 * slump + 0.12 * air
	_pose("Spine", _q("Spine", Z, lean * 0.22) * _q("Spine", X, torso_pitch * 0.5))
	_pose("Chest", _q("Chest", Z, lean * 0.18) * _q("Chest", X, torso_pitch * 0.5))
	_pose("Neck", _q("Neck", Y, look) * _q("Neck", X, -0.45 * slump + 0.1 * air))
	for side in ["L", "R"]:
		var sg := -1.0 if side == "L" else 1.0
		var up_a: String = "UpperArm_" + side
		var fo: String = "Forearm_" + side
		if not ids.has(up_a):
			continue
		# arms: push swing (about X), raise for air/cheer, out to the side for grind balance, dangle on bail
		var raise := arms_up * 2.3
		var out := sg * (0.35 * arms_up + 1.25 * balance + 0.15 * slump)
		var wob := sin(phase * 0.7 + (0.0 if side == "L" else 1.5)) * 0.15 * balance
		var q := _q(up_a, X, swing * (1.0 - arms_up) * (1.0 - balance) + raise + 0.3 * balance + 0.25 * slump) * _q(up_a, Z, out + wob)
		_pose(up_a, q)
		_pose(fo, _q(fo, X, bend * (1.0 - arms_up) + 0.4 * arms_up * (1.0 - cheer_k)))
