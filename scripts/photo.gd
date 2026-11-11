extends Node
## Photo mode (P / gamepad Back) and Instant Replay (T / D-pad down).
## Photo mode freezes the game and gives you a free camera:
##   WASD / left stick move, arrow keys or right-mouse-drag look, Q/E down/up, mouse wheel zoom,
##   ENTER or SPACE takes the picture, P or ESC goes back to the game.
## Pictures are saved to Pictures/GrandTheftWheelchair (and the user data folder).
## Instant replay plays back your last 8 seconds with a slow orbiting camera; ENTER snaps a photo.

const BUFFER := 480                 # 8 s at 60 physics frames per second

var w
var active: bool = false
var replaying: bool = false
var cam: Camera3D
var yaw: float = 0.0
var pitch: float = -0.2
var rec: Array = []                 # [chair, global_transform, visual transform, rider pose basis...]
var rep_i: int = 0
var rep_t: float = 0.0
var rep_chair: Chair
var rep_end: Transform3D
var layer: CanvasLayer
var label: Label
var toast: Label
var toast_t: float = 0.0
var dragging: bool = false

func setup(world) -> void:
	w = world
	process_mode = Node.PROCESS_MODE_ALWAYS
	cam = Camera3D.new()
	cam.fov = 60.0
	w.add_child.call_deferred(cam)
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	label = Label.new()
	var ls := LabelSettings.new()
	ls.font_size = 18
	ls.outline_size = 6
	ls.outline_color = Color.BLACK
	label.label_settings = ls
	label.position = Vector2(20, 20)
	label.visible = false
	layer.add_child(label)
	toast = Label.new()
	var ts := LabelSettings.new()
	ts.font_size = 26
	ts.outline_size = 8
	ts.outline_color = Color.BLACK
	ts.font_color = Color("ffd84a")
	toast.label_settings = ts
	toast.anchor_top = 1.0
	toast.anchor_bottom = 1.0
	toast.offset_left = 20
	toast.offset_top = -60
	layer.add_child(toast)

func _physics_process(_dt: float) -> void:
	# keep recording while playing normally
	if w == null or active or replaying or get_tree().paused or w.state != "play":
		return
	var p: Chair = GameState.player
	if p == null:
		return
	rec.append([p, p.global_transform, p.visual.transform])
	if rec.size() > BUFFER:
		rec.pop_front()

func toggle_photo() -> void:
	if replaying:
		return
	if active:
		_exit()
		return
	if w.state != "play" or get_tree().paused:
		return
	active = true
	get_tree().paused = true
	var src: Camera3D = w.rig.cam
	cam.global_transform = src.global_transform
	var e := src.global_transform.basis.get_euler()
	pitch = e.x
	yaw = e.y
	cam.fov = src.fov
	cam.current = true
	w.hud.visible = false
	label.visible = true
	label.text = "PHOTO MODE   WASD move  •  arrows / right-drag look  •  Q/E down/up  •  wheel zoom  •  ENTER snap  •  P exit"

func start_replay() -> void:
	if active or replaying or rec.size() < 30 or w.state != "play" or get_tree().paused:
		return
	replaying = true
	get_tree().paused = true
	rep_chair = rec[-1][0]
	rep_end = rep_chair.global_transform
	rep_i = 0
	rep_t = 0.0
	cam.fov = 55.0
	cam.current = true
	w.hud.visible = false
	label.visible = true
	label.text = "● INSTANT REPLAY   ENTER snap a photo  •  T skip"

func _exit() -> void:
	active = false
	replaying = false
	label.visible = false
	w.hud.visible = true
	w.rig.cam.current = true
	get_tree().paused = false

func _end_replay() -> void:
	if is_instance_valid(rep_chair):
		rep_chair.global_transform = rep_end
		rep_chair.visual.transform = Transform3D.IDENTITY
	_exit()

func _unhandled_input(event: InputEvent) -> void:
	if not active and not replaying:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_SPACE):
		snap()
		get_viewport().set_input_as_handled()
	elif active and (event.is_action_pressed("photo") or event.is_action_pressed("pause")):
		_exit()
		get_viewport().set_input_as_handled()
	elif replaying and (event.is_action_pressed("replay") or event.is_action_pressed("pause")):
		_end_replay()
		get_viewport().set_input_as_handled()
	elif active and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.fov = maxf(15.0, cam.fov - 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.fov = minf(100.0, cam.fov + 3.0)
	elif active and event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch - event.relative.y * 0.005, -1.5, 1.5)

func _process(dt: float) -> void:
	if toast_t > 0.0:
		toast_t -= dt
		toast.modulate.a = clampf(toast_t, 0.0, 1.0)
	if active:
		var mv := Vector3(Input.get_axis("left", "right"), 0, -Input.get_axis("back", "forward"))
		if Input.is_key_pressed(KEY_E):
			mv.y += 1.0
		if Input.is_key_pressed(KEY_Q):
			mv.y -= 1.0
		yaw += (float(Input.is_key_pressed(KEY_LEFT)) - float(Input.is_key_pressed(KEY_RIGHT))) * dt * 1.5
		pitch = clampf(pitch + (float(Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_DOWN))) * dt * 1.2, -1.5, 1.5)
		var b := Basis.from_euler(Vector3(pitch, yaw, 0))
		var spd := 12.0 if Input.is_action_pressed("boost") else 5.0
		cam.global_transform = Transform3D(b, cam.global_position + b * Vector3(mv.x, 0, mv.z) * spd * dt + Vector3.UP * mv.y * spd * dt)
	elif replaying:
		rep_t += dt * 60.0
		rep_i = int(rep_t)
		if rep_i >= rec.size():
			_end_replay()
			return
		var fr: Array = rec[rep_i]
		var c: Chair = fr[0]
		if not is_instance_valid(c):
			_end_replay()
			return
		c.global_transform = fr[1]
		c.visual.transform = fr[2]
		# slow orbit around the action
		var ang := rep_t / 60.0 * 0.6
		var target: Vector3 = fr[1].origin + Vector3.UP * 1.0
		var off := Vector3(sin(ang) * 4.5, 1.6 + sin(ang * 0.7) * 0.6, cos(ang) * 4.5)
		cam.global_position = target + off
		cam.look_at(target, Vector3.UP)

func snap() -> void:
	var was := label.visible
	label.visible = false
	toast.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	label.visible = was
	toast.visible = true
	if img == null:
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var fname := "gtw_%s.png" % stamp
	var dirs: Array = [OS.get_user_data_dir().path_join("screenshots")]
	var pics := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pics != "":
		dirs.push_front(pics.path_join("GrandTheftWheelchair"))
	var saved := ""
	for d in dirs:
		DirAccess.make_dir_recursive_absolute(d)
		if img.save_png(d.path_join(fname)) == OK and saved == "":
			saved = d.path_join(fname)
	Sfx.play("shutter")
	toast.text = "SAVED: " + saved
	toast_t = 3.0
