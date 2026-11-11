class_name CameraRig
extends Node3D
## GTA-style chase camera on a spring arm (never clips into buildings).
## Modes: chase, high, top-down. Shake via h/v offset.

const MODES := [
	{"name": "CHASE CAM", "len": 5.2, "pitch": 0.28, "fov": 68.0, "height": 1.2},
	{"name": "HIGH CAM", "len": 11.0, "pitch": 0.62, "fov": 62.0, "height": 1.0},
	{"name": "TOP-DOWN", "len": 30.0, "pitch": 1.3, "fov": 50.0, "height": 0.5},
]
var target: Node3D
var mode: int = 0
var cam_yaw: float = 0.0
var arm: SpringArm3D
var cam: Camera3D
var shake_amt: float = 0.0
var orbit: bool = false
var cur_pitch: float = 0.3

func _ready() -> void:
	arm = SpringArm3D.new()
	arm.collision_mask = 1
	arm.margin = 0.3
	arm.spring_length = MODES[0].len
	var sph := SphereShape3D.new()
	sph.radius = 0.3
	arm.shape = sph
	add_child(arm)
	cam = Camera3D.new()
	cam.current = true
	cam.far = 900.0
	cam.near = 0.08
	arm.add_child(cam)

func snap() -> void:
	if target == null:
		return
	global_position = target.global_position + Vector3.UP * MODES[mode].height
	cam_yaw = target.yaw if "yaw" in target else 0.0
	cur_pitch = MODES[mode].pitch

func next_mode() -> String:
	mode = (mode + 1) % MODES.size()
	return MODES[mode].name

func _process(dt: float) -> void:
	if target == null:
		return
	var m: Dictionary = MODES[mode]
	if orbit:
		cam_yaw += dt * 0.12
		arm.spring_length = lerpf(arm.spring_length, 26.0, dt)
		rotation = Vector3(-0.45, cam_yaw, 0)
		global_position = global_position.lerp(target.global_position + Vector3.UP * 3.0, dt * 2.0)
		return
	var tp: Vector3 = target.global_position + Vector3.UP * m.height
	global_position = global_position.lerp(tp, clampf(dt * 10.0, 0.0, 1.0))
	var ty: float = target.yaw if "yaw" in target else 0.0
	var fwd_speed := 0.0
	if target is CharacterBody3D:
		fwd_speed = target.velocity.dot(Vector3(-sin(ty), 0, -cos(ty)))
	var follow := 0.6 if fwd_speed < -0.5 else 3.2
	cam_yaw = lerp_angle(cam_yaw, ty, clampf(dt * follow, 0.0, 1.0))
	# in tight spots (backed against a wall) lift the camera and look down instead of squeezing in
	var free_len: float = arm.get_hit_length()
	var tight := clampf(1.0 - free_len / max(arm.spring_length, 0.01), 0.0, 1.0)
	var want_pitch: float = lerpf(m.pitch, 1.2, smoothstep(0.25, 0.7, tight))
	cur_pitch = lerpf(cur_pitch, want_pitch, clampf(dt * 2.5, 0.0, 1.0))
	rotation = Vector3(-cur_pitch, cam_yaw, 0)
	arm.spring_length = lerpf(arm.spring_length, m.len, dt * 4.0)
	var spd: float = target.velocity.length() if target is CharacterBody3D else 0.0
	cam.fov = lerpf(cam.fov, m.fov + min(spd, 14.0) * 1.1, dt * 3.0)
	if shake_amt > 0.01:
		cam.h_offset = randf_range(-1, 1) * shake_amt * 0.3
		cam.v_offset = randf_range(-1, 1) * shake_amt * 0.3
		shake_amt *= pow(0.02, dt)
	else:
		cam.h_offset = 0
		cam.v_offset = 0
