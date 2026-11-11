extends Node3D
## Grand Theft Wheelchair - main game controller.
## Builds the world, spawns everything and runs the rules: stealing, wanted level,
## police, missions, props, day/night and graphics quality.

const DAY_LENGTH := 360.0
const BUST_LINES := ["You have the right to remain seated.", "Sir, that chair is evidence.", "Nice wheels. Shame they're stolen.", "We've impounded your ride."]

var city: City
var rig: CameraRig
var hud: Hud
var chairs: Array = []
var cars: Array = []
var props: Array = []
var state: String = "title"
var hop = null
var prompt = null
var play_time: float = 0.0
var bust_line: String = ""
var busted_t: float = 0.0
var gold: Chair = null
var gold_delay: float = 0.0
var pizza: Dictionary = {}
var pizza_cd: float = 0.0
var player_rider: Node3D
var boost_toggled: bool = false
var wheelie_toggled: bool = false
var wheelie_limit: float = 0.0
var wheelie_bonk: float = 0.0
var wheelie_cool: float = 0.0
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var day_offset: float = 0.0
var night: float = 0.0
var cars_night: bool = false
var headlight: SpotLight3D
var siren_t: float = 0.0
var siren_hi: bool = false
var cop_cd: float = 0.0
var skid_mm: MultiMesh
var skid_i: int = 0
var beacon: MeshInstance3D
var chop_ring: MeshInstance3D
var pizza_ring: MeshInstance3D
var dest_ring: MeshInstance3D
var dest_beam: MeshInstance3D
var welcomed: bool = false
var shop_ring: MeshInstance3D
var shop_lock: bool = false
var neon_light: OmniLight3D
var neon_glow: MeshInstance3D
var flocks: Array = []
var acts
var tricks
var post: CanvasLayer
var post_rect: ColorRect
var story
var fun
var goals
var photo
var score
var editor
var autosave_t: float = 60.0
var ring_mats: Array = []      # [material, base colour] for colour-blind recolouring

func _ready() -> void:
	GameState.world = self
	randomize()
	_environment()
	city = City.new()
	add_child(city)
	city.build()
	if GameState.is_web or GameState.quality == 3:
		# small things (props, labels, birds, cars, chairs) stop drawing past 80 m; the fog hides the cut
		get_tree().node_added.connect(_cull_small)
		_cull_walk(self)
		var skip := {}
		for b in city.birds:
			skip[b.n] = true
		var t0 := Time.get_ticks_msec()
		var keep := {city.lamp_mat: true}
		for sm in city.shop_mats:
			keep[sm] = true
		if Models.rainbow_mat != null:
			keep[Models.rainbow_mat] = true
		var n: int = preload("res://scripts/batcher.gd").merge(city, skip, keep)
		print("[batch] city merged into %d meshes in %d ms" % [n, Time.get_ticks_msec() - t0])
	GameState.load_game()
	_spawn_world()
	rig = CameraRig.new()
	add_child(rig)
	rig.target = GameState.player
	rig.snap()
	rig.orbit = true
	hud = Hud.new()
	hud.world = self
	add_child(hud)
	_markers()
	_skids()
	acts = preload("res://scripts/activities.gd").new()
	add_child(acts)
	acts.setup(self)
	story = preload("res://scripts/story.gd").new()
	add_child(story)
	story.setup(self)
	fun = preload("res://scripts/fun.gd").new()
	add_child(fun)
	fun.setup(self)
	goals = preload("res://scripts/goals.gd").new()
	add_child(goals)
	goals.setup(self)
	photo = preload("res://scripts/photo.gd").new()
	add_child(photo)
	photo.setup(self)
	score = preload("res://scripts/score_attack.gd").new()
	add_child(score)
	score.setup(self)
	editor = preload("res://scripts/rider_editor.gd").new()
	add_child(editor)
	editor.setup(self)
	preload("res://scripts/custom.gd").ensure_folders()
	tricks = preload("res://scripts/tricks.gd").new()
	add_child(tricks)
	tricks.setup(self)
	_post_fx()
	restyle()
	GameState.float_text.connect(_float_text)
	apply_quality()
	apply_retro()
	apply_access()
	if GameState.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_menu_music()
	if "--autotest" in OS.get_cmdline_user_args():
		add_child(load("res://scripts/autotest.gd").new())

# ------------------------------------------------------------------ setup
func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3d8fe0")
	sky_mat.sky_horizon_color = Color("bfe3ff")
	sky_mat.ground_horizon_color = Color("bfe3ff")
	sky_mat.ground_bottom_color = Color("3b4a3a")
	sky_mat.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("cfe6ff")
	env.fog_density = 0.0022
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_blur = 1.2
	sun.shadow_normal_bias = 1.6
	sun.light_energy = 1.3
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	headlight = SpotLight3D.new()
	headlight.spot_range = 28.0
	headlight.spot_angle = 35.0
	headlight.light_color = Color("fff1c8")
	headlight.light_energy = 0.0
	headlight.shadow_enabled = true
	add_child(headlight)

func apply_quality() -> void:
	if GameState.retro:
		apply_retro()
		return
	if GameState.quality == 3:
		_apply_potato()
		return
	var q: int = GameState.quality
	headlight.visible = true
	if neon_light != null:
		neon_light.visible = true
	env.ssao_enabled = q >= 1
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssil_enabled = q >= 2
	env.sdfgi_enabled = q >= 2
	env.sdfgi_use_occlusion = true
	env.volumetric_fog_enabled = q >= 2
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_anisotropy = 0.5
	env.glow_enabled = true
	sun.directional_shadow_max_distance = [60.0, 140.0, 200.0][q]
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
	get_viewport().scaling_3d_scale = [0.75, 1.0, 1.0][q]
	for l in city.lamp_lights:
		l.visible = q >= 1 or night > 0.5

func _post_fx() -> void:
	post = CanvasLayer.new()
	post.layer = 0
	add_child(post)
	post_rect = ColorRect.new()
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/retro_post.gdshader")
	post_rect.material = sm
	post.add_child(post_rect)

## "RETRO 2001": flat bright lighting, blob shadows, distance fog, per-vertex shading,
## low-res point-sampled frame with dithered colour. Like a 2001 skate game on a CRT.
func apply_retro() -> void:
	var on := GameState.retro
	if post != null:
		post.visible = on
	city.set_retro(on)
	for b in get_tree().get_nodes_in_group("blob"):
		b.visible = on
	Models.vertex_light(self, on, {})
	if not on:
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_density = 0.0022
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.adjustment_saturation = 1.12
		get_viewport().scaling_3d_scale = [0.75, 1.0, 1.0, 0.5][GameState.quality]
		_apply_modern()
		return
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_depth_begin = 60.0
	env.fog_depth_end = 210.0
	env.fog_depth_curve = 1.4
	env.fog_aerial_perspective = 0.0
	env.fog_sky_affect = 0.0
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.08
	sun.shadow_enabled = false
	headlight.shadow_enabled = false
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().scaling_3d_scale = 0.5
	for l in city.lamp_lights:
		l.visible = night > 0.3
		l.shadow_enabled = false

## "Potato": for old school PCs. Half resolution, no shadows, no post effects, short view distance.
func _apply_potato() -> void:
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	env.glow_enabled = false
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_depth_begin = 50.0
	env.fog_depth_end = 140.0
	sun.shadow_enabled = false
	headlight.shadow_enabled = false
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().scaling_3d_scale = 0.5
	if rig != null and rig.cam != null:
		rig.cam.far = 150.0
	for l in city.lamp_lights:
		l.visible = false
	for st in city.steam:
		st.emitting = false
	if neon_light != null:
		neon_light.visible = false
	headlight.visible = false
	for c in cars:
		if is_instance_valid(c) and c.headlight != null:
			c.headlight.visible = false

func _apply_modern() -> void:
	if GameState.quality == 3:
		_apply_potato()
		return
	headlight.shadow_enabled = true
	if rig != null and rig.cam != null:
		rig.cam.far = 500.0
	for st in city.steam:
		st.emitting = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0022
	env.glow_enabled = true
	var q: int = GameState.quality
	headlight.visible = true
	if neon_light != null:
		neon_light.visible = true
	env.ssao_enabled = q >= 1
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssil_enabled = q >= 2
	env.sdfgi_enabled = q >= 2
	env.sdfgi_use_occlusion = true
	env.volumetric_fog_enabled = q >= 2
	env.glow_intensity = 0.55
	env.adjustment_contrast = 1.05
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.25
	sun.directional_shadow_max_distance = [60.0, 140.0, 200.0][q]
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
	get_viewport().scaling_3d_scale = [0.75, 1.0, 1.0][q]
	for l in city.lamp_lights:
		l.visible = q >= 1 or night > 0.5

func toggle_retro() -> void:
	GameState.retro = not GameState.retro
	apply_retro()
	GameState.say_banner("LOOK: " + ("RETRO 2001" if GameState.retro else "MODERN"), "F3 to switch", Color("ffd84a"))

func cycle_quality() -> void:
	GameState.quality = (GameState.quality + 1) % 4
	_apply_modern()
	apply_quality()
	GameState.say_banner("GRAPHICS: " + GameState.QUALITY_NAMES[GameState.quality].to_upper(), "Fewer cars and people in Potato mode after a restart" if GameState.quality == 3 else "", Color("7ee0ff"))
	GameState.save_game()

func toggle_fullscreen() -> void:
	GameState.fullscreen = not GameState.fullscreen
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if GameState.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	GameState.save_game()

## Accessibility: HUD size and colour-blind palette (rings and minimap; minimap reads it every frame).
func apply_access() -> void:
	get_tree().root.content_scale_factor = GameState.hud_scale
	for rm in ring_mats:
		var c: Color = GameState.cb(rm[1])
		rm[0].albedo_color = Color(c.r, c.g, c.b, rm[0].albedo_color.a)
		if rm[0].emission_enabled:
			rm[0].emission = c

## Rebuild the player's rider after Create-a-Rider.
func rebuild_player_rider() -> void:
	if hop != null:
		return
	var c: Chair = GameState.player
	c.take_rider()
	player_rider.queue_free()
	player_rider = Models.rider("player", GameState.look)
	c.set_rider(player_rider, "player")
	restyle()

func spawn_chair(type: String, pos: Vector3, yaw: float, kind: String = "") -> Chair:
	var c := Chair.new()
	c.position = pos
	add_child(c)
	c.setup(type, yaw, kind)
	chairs.append(c)
	return c

func remove_chair(c: Chair) -> void:
	chairs.erase(c)
	if c == gold:
		gold = null
	c.queue_free()

func _spawn_world() -> void:
	player_rider = Models.rider("player", GameState.look)
	var start: Vector3 = city.points.get("hospital", Vector3(30, City.CURB, 30))
	var pc := spawn_chair("rusty", start, PI)
	pc.set_rider(player_rider, "player")
	GameState.player = pc
	GameState.dex["rusty"] = true
	for s in city.parked_spots:
		spawn_chair(s.type, s.pos, s.yaw)
	var potato: bool = GameState.quality == 3
	var web: bool = GameState.is_web and potato       # the browser version runs on one CPU thread: keep the crowd small
	for i in (5 if web else (7 if potato else 14)):
		var p := city.sidewalk_point()
		spawn_chair(GameState.CIVILIAN_TYPES.pick_random(), p.pos, p.yaw + PI / 2)
	for i in (7 if web else (11 if potato else 22)):
		var bl: Dictionary = city.blocks.pick_random()
		var k := randi() % 4
		var cn: Vector3 = city.corners(bl)[k]
		var c := spawn_chair(GameState.CIVILIAN_TYPES.pick_random(), cn, randf() * TAU, "npc")
		c.ai_block = bl
		c.ai_corner = (k + 1) % 4
	_spawn_gold()
	var n := 0
	for i in City.NB + 1:
		var c := i * City.PITCH + City.ROAD / 2
		for k in 2:
			for j in (1 if potato else 2):
				var sp := randf_range(7.0, 11.0)
				var car := Car.new()
				add_child(car)
				var along := randf() * City.SIZE
				if k == 0:
					car.setup(Vector3(along, 0, c + 2.5), Vector3.RIGHT, sp, randf() < 0.12, n)
				else:
					car.setup(Vector3(along, 0, c - 2.5), Vector3.LEFT, sp, randf() < 0.12, n + 1)
				cars.append(car)
				var car2 := Car.new()
				add_child(car2)
				along = randf() * City.SIZE
				if k == 0:
					car2.setup(Vector3(c + 2.5, 0, along), Vector3.FORWARD, sp, randf() < 0.12, n + 2)
				else:
					car2.setup(Vector3(c - 2.5, 0, along), Vector3.BACK, sp, randf() < 0.12, n + 3)
				cars.append(car2)
				n += 4
	for s in city.prop_spots:
		var kind: String = ["bin", "bin", "hydrant", "stand", "cone", "cone", "barrier", "newsbox"].pick_random()
		if kind in ["cone", "barrier", "newsbox"] and not ResourceLoader.exists("res://assets/models/%s.glb" % kind):
			kind = "bin"
		_spawn_prop(kind, s.pos, s.yaw)

func _spawn_gold() -> void:
	var p: Dictionary
	for i in 60:
		p = city.sidewalk_point()
		if p.pos.distance_to(GameState.player.global_position) > 130.0 and p.pos.distance_to(city.points["chop"]) > 110.0:
			break
	gold = spawn_chair("gold", p.pos, p.yaw + PI / 2)

func _spawn_prop(kind: String, pos: Vector3, yaw: float) -> void:
	var b := RigidBody3D.new()
	b.collision_layer = 8
	b.collision_mask = 1 | 8
	var cs := CollisionShape3D.new()
	var model: Node3D
	match kind:
		"bin":
			var s := CylinderShape3D.new()
			s.radius = 0.32
			s.height = 0.9
			cs.shape = s
			cs.position.y = 0.45
			b.mass = 6.0
			model = Models.bin_model()
		"hydrant":
			var s := CylinderShape3D.new()
			s.radius = 0.2
			s.height = 0.8
			cs.shape = s
			cs.position.y = 0.4
			b.mass = 35.0
			b.freeze = true
			model = Models.hydrant_model()
		"cone":
			var s := CylinderShape3D.new()
			s.radius = 0.18
			s.height = 0.72
			cs.shape = s
			cs.position.y = 0.36
			b.mass = 2.0
			model = Models.street("cone")
		"barrier":
			var s := BoxShape3D.new()
			s.size = Vector3(1.6, 1.0, 0.5)
			cs.shape = s
			cs.position.y = 0.5
			b.mass = 8.0
			model = Models.street("barrier")
		"newsbox":
			var s := BoxShape3D.new()
			s.size = Vector3(0.55, 1.08, 0.5)
			cs.shape = s
			cs.position.y = 0.54
			b.mass = 25.0
			model = Models.street("newsbox")
		_:
			var s := BoxShape3D.new()
			s.size = Vector3(1.8, 1.0, 1.0)
			cs.shape = s
			cs.position.y = 0.5
			b.mass = 30.0
			b.freeze = true
			model = Models.stand_model()
			if true:
				var fruit := Node3D.new()
				var fc := [Color("e63946"), Color("ffb703"), Color("7cb518"), Color("fb8500")]
				for i in 12:
					Models.sph(fruit, 0.09, Vector3(-0.7 + (i % 6) * 0.28, 0.98, -0.2 + floori(i / 6.0) * 0.3), Models.mat(fc[i % 4], 0.5))
				model.add_child(fruit)
	b.add_child(cs)
	b.add_child(model)
	b.position = pos
	b.rotation.y = yaw
	add_child(b)
	props.append({"body": b, "home": b.transform, "kind": kind, "hit": false, "t": 0.0, "gush": 0.0})

func _markers() -> void:
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.albedo_color = Color(1.0, 0.85, 0.3, 0.22)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beacon = _beam(0.7, beam_mat)
	var blue := beam_mat.duplicate()
	blue.albedo_color = Color(0.2, 0.6, 1.0, 0.22)
	dest_beam = _beam(1.5, blue)
	chop_ring = _ring(city.points["chop"], Color("ffd84a"), 2.6)
	pizza_ring = _ring(city.points["pizza"], Color("ff7a2b"), 2.0)
	dest_ring = _ring(Vector3.ZERO, Color("2a9dff"), 2.6)
	shop_ring = _ring(city.points["pimp"], Color("ff3fa4"), 2.0)
	var pimp := Label3D.new()
	pimp.text = "PIMP MY CHAIR\nroll in!"
	pimp.font_size = 40
	pimp.pixel_size = 0.006
	pimp.outline_size = 12
	pimp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pimp.modulate = Color("ff6fb5")
	pimp.position = city.points["pimp"] + Vector3.UP * 2.2
	add_child(pimp)
	neon_light = OmniLight3D.new()
	neon_light.omni_range = 3.0
	neon_light.light_energy = 0.0
	neon_light.shadow_enabled = false
	add_child(neon_light)
	neon_glow = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.9, 1.9)
	neon_glow.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.9))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gm.albedo_texture = gt
	neon_glow.material_override = gm
	neon_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	neon_glow.visible = false
	add_child(neon_glow)
	_spawn_pigeons()

func _beam(r: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 160.0
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _ring(pos: Vector3, color: Color, r: float) -> MeshInstance3D:
	var base := color
	color = GameState.cb(color)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.5
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 40
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3.UP * 0.25
	add_child(mi)
	ring_mats.append([m, base])
	return mi

func _skids() -> void:
	skid_mm = MultiMesh.new()
	skid_mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.09, 0.32)
	skid_mm.mesh = pm
	skid_mm.instance_count = 800
	for i in 800:
		skid_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -50, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = skid_mm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.05, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

# ------------------------------------------------------------------ effects
func add_skid(c: Chair) -> void:
	if GameState.player == null or c.global_position.distance_to(GameState.player.global_position) > 60.0:
		return
	if Engine.get_physics_frames() % 2 == 1:
		return
	var right := Vector3(cos(c.yaw), 0, -sin(c.yaw))
	var off: float = 0.42 if c.stats.get("big", false) else 0.33
	for s in [-1.0, 1.0]:
		var p: Vector3 = c.global_position + right * off * s + Vector3.UP * 0.02
		skid_mm.set_instance_transform(skid_i, Transform3D(Basis(Vector3.UP, c.yaw), p))
		skid_i = (skid_i + 1) % skid_mm.instance_count

func _particles(pos: Vector3, color: Color, amount: int, spd: float, size: float, life: float, grav: float, spread: float = 180.0, hue: float = 0.0) -> void:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = spread
	pm.initial_velocity_min = spd * 0.4
	pm.initial_velocity_max = spd
	pm.gravity = Vector3(0, grav, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.5
	pm.scale_min = size * 0.6
	pm.scale_max = size
	pm.color = color
	if hue > 0.0:
		pm.hue_variation_min = -hue
		pm.hue_variation_max = hue
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.2, 0.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = m
	p.draw_pass_1 = qm
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.92
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.6).timeout.connect(p.queue_free)

func fx_dust(pos: Vector3, n: int = 8) -> void:
	_particles(pos + Vector3.UP * 0.1, Color(0.8, 0.76, 0.68, 0.7), n, 1.5, 2.0, 0.8, 0.6, 80.0)

func fx_sparks(pos: Vector3) -> void:
	_particles(pos, Color(1.0, 0.85, 0.4), 14, 5.0, 0.5, 0.35, -9.0)

func fx_confetti(pos: Vector3, n: int = 60) -> void:
	_particles(pos + Vector3.UP, Color(1, 0.2, 0.3), n, 7.0, 0.8, 2.2, -6.0, 60.0, 1.0)

func fx_boost(c: Chair) -> void:
	if c.global_position.distance_to(GameState.player.global_position) > 50.0:
		return
	var fl: bool = c.type in ["turbo", "gold", "cop"] or (c == GameState.player and GameState.style.flames)
	var col := Color(1.0, 0.55, 0.15) if fl else Color(0.85, 0.85, 0.85, 0.6)
	_particles(c.global_position - c.forward() * 0.6 + Vector3.UP * 0.4, col, 3, 1.5, 1.4, 0.35, 1.0, 25.0)

func shake(a: float) -> void:
	rig.shake_amt = max(rig.shake_amt, a)

func _float_text(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.pixel_size = 0.007
	l.outline_size = 18
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", pos + Vector3.UP * 1.8, 1.4)
	tw.tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)

# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if state == "title":
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
			_start()
		return
	if state != "play":
		return
	if event.is_action_pressed("fullscreen"):
		toggle_fullscreen()
		return
	if event.is_action_pressed("photo"):
		photo.toggle_photo()
		return
	if event.is_action_pressed("replay"):
		photo.start_replay()
		return
	if event.is_action_pressed("steal"):
		if fun.hidden:
			fun.toggle_hide()
		elif not try_steal() and GameState.wanted > 0:
			fun.toggle_hide()
	elif event.is_action_pressed("donut"):
		fun.throw_donut()
	elif event.is_action_pressed("bell"):
		ring_bell()
	elif event.is_action_pressed("camera"):
		hud.show_cam(rig.next_mode())
	elif event.is_action_pressed("daynight"):
		day_offset += 0.5
	elif event.is_action_pressed("quality"):
		cycle_quality()
	elif event.is_action_pressed("retro"):
		toggle_retro()
	elif event.is_action_pressed("radio"):
		hud.show_cam("RADIO: " + Radio.next_station())
	elif event.is_action_pressed("boost") and GameState.settings_toggle_boost:
		boost_toggled = not boost_toggled
	elif event.is_action_pressed("wheelie") and GameState.settings_toggle_wheelie:
		wheelie_toggled = not wheelie_toggled

var _perf_t: float = 0.0
func _cull_walk(n: Node) -> void:
	_cull_small(n)
	for c in n.get_children():
		_cull_walk(c)

func _cull_small(n: Node) -> void:
	if not n is GeometryInstance3D or str(n.name).begins_with("Batch"):
		return
	var gi: GeometryInstance3D = n
	if gi.visibility_range_end > 0.0:
		return
	if not gi.is_inside_tree():
		gi.ready.connect(_cull_small.bind(gi), CONNECT_ONE_SHOT)
		return
	var size := gi.get_aabb().size * gi.global_basis.get_scale()
	if maxf(size.x, maxf(size.y, size.z)) > 12.0:
		return          # ground, big buildings, mission beams stay visible from far away
	gi.visibility_range_end = 45.0 if gi is Label3D else 80.0

var menu_player: AudioStreamPlayer
## Title-screen theme: any mp3/ogg/wav in assets/audio/menu/ (see the Suno prompts doc). Fades out on PLAY.
func _menu_music() -> void:
	var songs: Array = preload("res://scripts/radio.gd")._list_audio("res://assets/audio/menu")
	if songs.is_empty():
		return
	var st = load(songs.pick_random())
	if st == null:
		return
	if st is AudioStreamOggVorbis or st is AudioStreamMP3:
		st.loop = true
	elif st is AudioStreamWAV:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	menu_player = AudioStreamPlayer.new()
	menu_player.stream = st
	menu_player.volume_db = -6.0
	menu_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu_player)
	menu_player.play()

func _start() -> void:
	if state != "title":
		return
	if menu_player != null:
		var tw := create_tween()
		tw.tween_property(menu_player, "volume_db", -60.0, 2.0)
		tw.tween_callback(menu_player.stop)
	state = "play"
	rig.orbit = false
	rig.target = GameState.player
	rig.snap()
	Sfx.play("big")
	GameState.say_banner("LOS SPOKOS", "Find and steal the GOLDEN THRONE", Color("ffd84a"))

func toggle_pause() -> void:
	var p: bool = not get_tree().paused
	get_tree().paused = p
	hud.set_paused(p)

# ------------------------------------------------------------------ main loop
func _physics_process(dt: float) -> void:
	Engine.time_scale = GameState.game_speed * GameState.slowmo
	if state == "title":
		return
	play_time += dt
	if not welcomed and play_time > 3.0:
		welcomed = true
		GameState.say_sub("SPOKE (on the phone)", "Kid! Bring me the Golden Throne. Need cash? Rolling Pizza is hiring.", Color("ffd84a"))
	if state == "busted":
		busted_t -= dt
		if busted_t <= 0.0:
			_respawn()
		return
	autosave_t -= dt
	if autosave_t <= 0.0:
		autosave_t = 60.0
		GameState.save_game()
	_wheelie(dt)
	_wanted(dt)
	_missions(dt)
	_props(dt)
	_pigeons(dt)
	prompt = null
	if hop == null and GameState.player.is_on_floor():
		prompt = _nearest_stealable()

func _process(_dt: float) -> void:
	if GameState.is_web:
		_perf_t += _dt
		if _perf_t > 3.0:
			_perf_t = 0.0
			print("[perf] fps=%d proc=%.1fms phys=%.1fms draws=%d objs=%d prims=%dk nodes=%d" % [Engine.get_frames_per_second(),
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	_day_night()
	var p: Chair = GameState.player
	if p != null:
		var f := p.forward()
		headlight.global_position = p.global_position + Vector3.UP * 1.0 + f * 0.3
		headlight.look_at(p.global_position + f * 12.0, Vector3.UP)
	_style_fx()
	if p != null and state == "play" and not get_tree().paused:
		var spd := p.speed()
		Sfx.set_loop("roll", p.is_on_floor() and spd > 0.6 and not p.frozen, clampf(spd / 9.0, 0.0, 0.8), 0.6 + spd * 0.07)
	else:
		Sfx.set_loop("roll", false)
	var carrying := gold != null and p == gold
	beacon.visible = gold != null and not carrying
	if beacon.visible:
		beacon.global_position = gold.global_position + Vector3.UP * 80.0
	chop_ring.visible = carrying
	var pulse := 1.0 + sin(GameState.time * 5.0) * 0.06
	chop_ring.scale = Vector3(pulse, 1, pulse)
	pizza_ring.visible = pizza.is_empty()
	dest_ring.visible = not pizza.is_empty()
	dest_beam.visible = not pizza.is_empty()
	if not pizza.is_empty():
		dest_ring.global_position = pizza.pos + Vector3.UP * 0.25
		dest_beam.global_position = pizza.pos + Vector3.UP * 80.0

func _day_night() -> void:
	var d := fposmod(0.12 + GameState.time / DAY_LENGTH + day_offset, 1.0)
	var e := sin(d * TAU)
	var day := clampf(e * 2.2 + 0.25, 0.0, 1.0)
	night = 1.0 - day
	var dusk := clampf(1.0 - abs(e) * 4.0, 0.0, 1.0)
	sun.rotation_degrees = Vector3(-lerpf(10.0, 68.0, clampf(e, 0.0, 1.0)) if e > 0.0 else -35.0, 20.0 + d * 160.0, 0)
	sun.light_energy = 0.12 + 1.2 * day
	sun.shadow_enabled = day > 0.2 and not GameState.retro
	sun.light_color = Color("9fb4ff").lerp(Color("ffb070"), clampf(day * 2.0, 0, 1)).lerp(Color("fff3e0"), clampf((day - 0.5) * 2.0, 0, 1))
	sky_mat.sky_top_color = Color("070d24").lerp(Color("3d8fe0"), day).lerp(Color("5b3a8a"), dusk * 0.5)
	sky_mat.sky_horizon_color = Color("16224a").lerp(Color("cde9ff"), day).lerp(Color("ff9a5a"), dusk * 0.7)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.sky_energy_multiplier = 0.35 + 0.65 * day
	env.ambient_light_sky_contribution = lerpf(0.25, 0.55, day)
	env.ambient_light_color = Color("5a6aa8").lerp(Color("c9c2b4"), day)
	env.ambient_light_energy = lerpf(0.9, 1.0, day)
	env.fog_light_color = Color("0d1430").lerp(Color("cfe6ff"), day).lerp(Color("e8a07a"), dusk * 0.4)
	city.set_night(night)
	headlight.light_energy = night * 4.0
	var n := night > 0.5
	if n != cars_night:
		cars_night = n
		for c in cars:
			c.set_night(n)
		for l in city.lamp_lights:
			l.visible = GameState.quality >= 1 or n or (GameState.retro and night > 0.3)

# ------------------------------------------------------------------ stealing
func _nearest_stealable() -> Chair:
	var best: Chair = null
	var bd := 2.3
	var pp: Vector3 = GameState.player.global_position
	for c in chairs:
		if c == GameState.player or not c.is_on_floor() or c.has_meta("nosteal"):
			continue
		var d := Vector2(c.global_position.x - pp.x, c.global_position.z - pp.z).length()
		if d < bd and abs(c.global_position.y - pp.y) < 1.0:
			bd = d
			best = c
	return best

func try_steal() -> bool:
	if hop != null or not GameState.player.is_on_floor() or fun.hidden:
		return false
	var tgt := _nearest_stealable()
	if tgt == null:
		return false
	var old: Chair = GameState.player
	old.wheelie = false
	var taken := tgt.take_rider()
	var victim: Node3D = taken[0]
	var vkind: String = taken[1]
	var from := player_rider.global_transform
	old.take_rider()
	add_child(player_rider)
	player_rider.global_transform = from
	if victim != null:
		old.set_rider(victim, vkind)
		if vkind == "cop":
			old.chase = true
			old.say(Chair.COP_LINES.pick_random(), 3.0)
		else:
			old.angry_t = 3.5
			old.say(Chair.LINES.pick_random(), 3.0)
	tgt.mode = "player"
	tgt.velocity *= 0.2
	GameState.player = tgt
	rig.target = tgt
	hop = {"from": from.origin, "yaw0": old.yaw, "to": tgt, "victim": vkind, "type": tgt.type}
	Sfx.play("jump")
	var tw := create_tween()
	tw.tween_method(_hop_step, 0.0, 1.0, 0.38)
	tw.tween_callback(_hop_done)
	return true

func _hop_step(t: float) -> void:
	if hop == null:
		return
	var tgt: Chair = hop.to
	var e := t * t * (3.0 - 2.0 * t)
	var to: Vector3 = tgt.seat.global_position
	player_rider.global_position = hop.from.lerp(to, e) + Vector3.UP * sin(PI * t) * 1.1
	player_rider.rotation = Vector3(0, lerp_angle(hop.yaw0, tgt.yaw, e) + t * TAU, 0)

func _hop_done() -> void:
	var h: Dictionary = hop
	hop = null
	var tgt: Chair = h.to
	tgt.set_rider(player_rider, "player")
	restyle()
	var t: String = h.type
	var gain := 100
	var w := 0
	var msg := "+$100"
	if h.victim == "cop":
		gain = 500
		w = 2
		msg = "COP CHAIR JACKED!"
	elif h.victim == "npc":
		gain = 250
		w = 1
		msg = "CHAIR JACKED!"
	elif t == "cop":
		gain = 300
		w = 2
		msg = "STOLE FROM THE IMPOUND!"
	if t == "gold":
		gain = 1000
		w = max(w, 1)
		GameState.say_banner("THE GOLDEN THRONE", "Now deliver it to Spoke's Chop Shop!", Color("f5c542"))
		fx_confetti(tgt.global_position, 120)
		Sfx.play("big")
	else:
		Sfx.play("steal")
	GameState.event.emit("steal", {"victim": h.victim, "type": t})
	if not GameState.dex.has(t):
		GameState.dex[t] = true
		gain += 200
		if t != "gold":
			GameState.say_banner("NEW RIDE!", GameState.TYPES[t].name + " - " + GameState.TYPES[t].desc, Color("7ee0ff"))
	GameState.cred += gain
	if w > 0:
		GameState.add_wanted(w)
	GameState.pop(tgt.global_position + Vector3.UP * 2.4, msg, Color("ff5c8a") if w > 0 else Color("8cff6a"))
	GameState.pop(tgt.global_position + Vector3.UP * 1.8, "+$%d" % gain, Color("8cff6a"))
	fx_confetti(tgt.global_position, 30)

func ring_bell() -> void:
	var p: Chair = GameState.player
	if GameState.style.horn:
		_air_horn(p)
		return
	Sfx.play("bell")
	GameState.pop(p.global_position + Vector3.UP * 2, "*ding ding*", Color("7ee0ff"))
	for c in chairs:
		if c != p and c.rider_kind == "npc" and c.global_position.distance_to(p.global_position) < 10.0 and randf() < 0.6:
			c.say(["Rude.", "Ooh, fancy bell!", "Ding ding to you too!", "WHAT?!", "My ears!"].pick_random(), 1.8)

func line_of_sight(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a + Vector3.UP * 1.2, b + Vector3.UP * 1.2, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# ------------------------------------------------------------------ wheelie
func _wheelie(dt: float) -> void:
	var p: Chair = GameState.player
	wheelie_cool -= dt
	var held := wheelie_toggled if GameState.settings_toggle_wheelie else Input.is_action_pressed("wheelie")
	if tricks != null and tricks.one_switch_held():
		held = true
	var can := hop == null and p.is_on_floor() and p.spin == 0.0
	if held and can and not p.wheelie and p.speed() > 1.0 and wheelie_cool <= 0.0:
		p.wheelie = true
		p.wheelie_t = 0.0
		wheelie_limit = randf_range(2.8, 7.5)
		wheelie_bonk = p.bonk_time
		GameState.pop(p.global_position + Vector3.UP * 2, "WHEELIE!", Color("ffd84a"))
		Sfx.play("jump", 1.4, -6.0)
	if not p.wheelie:
		return
	if p.bonk_time != wheelie_bonk or not p.is_on_floor():
		if p.is_on_floor():
			tricks.bail(p, false)
		else:
			tricks.end_manual(p)
		p.wheelie = false
		wheelie_toggled = false
		return
	p.wheelie_t += dt
	if p.wheelie_t > wheelie_limit:
		tricks.bail(p, false)
		p.wheelie = false
		wheelie_toggled = false
		wheelie_cool = 1.5
		p.spin = randf_range(-0.4, 0.4)
		p.velocity *= 0.3
		shake(0.6)
		Sfx.play("bonk")
		fx_dust(p.global_position, 14)
		GameState.pop(p.global_position + Vector3.UP * 2, ["FACEPLANT!", "TIMBERRR!", "GRAVITY WINS!"].pick_random(), Color("ff5c8a"))
	elif not held:
		tricks.end_manual(p)
		p.wheelie = false

# ------------------------------------------------------------------ wanted level & police
func _wanted(dt: float) -> void:
	var p: Chair = GameState.player
	var seen := false
	var nearest := 1e9
	var chasing := 0
	if score.active:
		GameState.wanted = 0
	for c in chairs.duplicate():
		if c.mode != "cop" or c == p:
			continue
		var d: float = c.global_position.distance_to(p.global_position)
		if GameState.wanted == 0:
			c.chase = false
		elif c.stunned > 0.0 or fun.hidden:
			c.chase = false
			continue
		elif d < 90.0:
			c.chase = true
		if c.chase:
			chasing += 1
			nearest = min(nearest, d)
			if d < 60.0:
				seen = true
			if d < c.radius + p.radius + 0.5 and p.speed() < 3.5 and hop == null:
				GameState.bust_t += dt * 1.6
		elif c.spawned_cop and d > 150.0:
			remove_chair(c)
	GameState.bust_t = max(0.0, GameState.bust_t - dt * 0.6)
	if GameState.bust_t > 1.2:
		_busted()
		return
	if GameState.wanted > 0:
		if seen:
			GameState.wanted_cool = 0.0
		else:
			GameState.wanted_cool += dt
			if GameState.wanted_cool > 8.0:
				GameState.wanted -= 1
				GameState.wanted_cool = 0.0
				GameState.pop(p.global_position + Vector3.UP * 2.5, "-1 STAR" if GameState.wanted > 0 else "LOST THEM!", Color("7ee0ff"))
	var want: int = 0 if GameState.wanted == 0 else min(7, int(ceil(GameState.wanted * 1.4)))
	cop_cd -= dt
	if chasing < want and cop_cd <= 0.0:
		cop_cd = 2.5
		_spawn_cop()
	siren_t -= dt
	if GameState.wanted > 0 and nearest < 80.0 and siren_t <= 0.0:
		siren_t = 0.42
		siren_hi = not siren_hi
		Sfx.play("siren_hi" if siren_hi else "siren_lo", 1.0, -10.0)

func _spawn_cop() -> void:
	var pp: Vector3 = GameState.player.global_position
	for i in 30:
		var p := city.random_road_point()
		var d := p.distance_to(pp)
		if d > 60.0 and d < 120.0:
			var c := spawn_chair("cop", p, atan2(-(pp.x - p.x), -(pp.z - p.z)), "cop")
			c.chase = true
			c.spawned_cop = true
			c.shout_t = GameState.time + randf_range(1.0, 3.0)
			return

func _busted() -> void:
	state = "busted"
	busted_t = 3.5
	bust_line = BUST_LINES.pick_random()
	GameState.bust_t = 0.0
	Sfx.play("busted")
	GameState.event.emit("busted", {})
	if not pizza.is_empty():
		pizza = {}

func _respawn() -> void:
	var old: Chair = GameState.player
	old.wheelie = false
	old.take_rider()
	if old == gold:
		remove_chair(old)
		gold_delay = 3.0
	var hq: Vector3 = city.points["hq"]
	var c := spawn_chair("rusty", hq, PI / 2)
	c.set_rider(player_rider, "player")
	GameState.player = c
	restyle()
	rig.target = c
	rig.snap()
	GameState.cred = int(GameState.cred * 0.9)
	GameState.wanted = 0
	GameState.wanted_cool = 0.0
	for k in chairs:
		if k.mode == "cop":
			k.chase = false
	state = "play"
	GameState.say_banner("RELEASED", "The Kerb Patrol kept your chair. Here's a rusty one.", Color("ff5c8a"))

# ------------------------------------------------------------------ missions
func _missions(dt: float) -> void:
	var p: Chair = GameState.player
	if gold == null:
		gold_delay -= dt
		if gold_delay <= 0.0:
			_spawn_gold()
	elif p == gold and hop == null and p.global_position.distance_to(city.points["chop"]) < 3.5:
		GameState.cred += 2000
		GameState.event.emit("delivered_gold", {})
		GameState.say_banner("THRONE DELIVERED!", "+$2000  -  Spoke says: \"Pleasure doing business.\"", Color("8cff6a"))
		Sfx.play("big")
		fx_confetti(p.global_position, 160)
		var pos := p.global_position
		var y := p.yaw
		p.take_rider()
		remove_chair(p)
		gold_delay = 3.0
		var nc := spawn_chair(["turbo", "monster", "power", "cart"].pick_random(), pos, y)
		nc.set_rider(player_rider, "player")
		GameState.dex[nc.type] = true
		GameState.player = nc
		restyle()
		rig.target = nc
		GameState.wanted = max(0, GameState.wanted - 1)
		GameState.save_game()
	# Pimp My Chair
	var dshop: float = p.global_position.distance_to(city.points["pimp"])
	if dshop > 5.0:
		shop_lock = false
	elif not shop_lock and dshop < 2.2 and hop == null:
		open_shop()
		return
	# pizza delivery job
	pizza_cd -= dt
	var pz: Node = player_rider.find_child("PizzaBox", true, false)
	if pz != null:
		pz.visible = not pizza.is_empty()
	if pizza.is_empty():
		if pizza_cd <= 0.0 and hop == null and p.global_position.distance_to(city.points["pizza"]) < 2.5:
			var dest: Dictionary
			for i in 40:
				dest = city.sidewalk_point()
				var dd: float = dest.pos.distance_to(city.points["pizza"])
				if dd > 120.0 and dd < 260.0:
					break
			var dist: float = dest.pos.distance_to(city.points["pizza"])
			pizza = {"pos": dest.pos, "t": dist / 6.0 + 12.0, "integ": 100.0, "bonk": p.bonk_time}
			GameState.say_banner("ROLLING PIZZA", "Deliver it before it gets cold! Bumps and hard landings ruin it.", Color("ff7a2b"))
			GameState.say_sub("PIZZA BOSS", ["Go go GO! The customer is HANGRY!", "Don't do any jumps. ...You're going to do jumps, aren't you."].pick_random(), Color("ff7a2b"))
			Sfx.play("steal")
		return
	pizza.t -= dt
	if p.bonk_time != pizza.bonk:
		pizza.bonk = p.bonk_time
		pizza.integ = max(0.0, pizza.integ - 6.0)
		GameState.pop(p.global_position + Vector3.UP * 1.6, "-6% pizza", Color("ff7a2b"))
	if hop == null and p.global_position.distance_to(pizza.pos) < 3.0:
		var pay := 150 + int(pizza.t * 15.0) + int(pizza.integ * 2.0)
		GameState.cred += pay
		GameState.say_banner("DELIVERED!", "+$%d  (pizza %d%% intact)" % [pay, int(pizza.integ)], Color("8cff6a"))
		GameState.say_sub("CUSTOMER", "Wow, still hot! Here's a tip!" if pizza.integ >= 60.0 else "Is this... a pancake now?", Color("ffd84a"))
		Sfx.play("big")
		fx_confetti(p.global_position, 50)
		pizza = {}
		pizza_cd = 3.0
	elif pizza.t <= 0.0:
		GameState.say_banner("PIZZA'S COLD!", "The customer is eating cereal instead. Sad.", Color("ff5c8a"))
		Sfx.play("busted")
		pizza = {}
		pizza_cd = 3.0

func on_player_landed(impact: float, air_t: float = 0.0) -> void:
	acts.on_land(air_t)
	if not pizza.is_empty() and impact > 4.0:
		var loss := int(impact * 2.0)
		pizza.integ = max(0.0, pizza.integ - loss)
		GameState.pop(GameState.player.global_position + Vector3.UP * 1.6, "-%d%% pizza" % loss, Color("ff7a2b"))

func mission_text() -> String:
	var so: String = story.objective() if story != null else ""
	if so != "":
		return so
	if not acts.race.is_empty():
		return "Race the Rim Reapers! Follow the green rings."
	if not pizza.is_empty():
		return "Deliver the pizza to the blue marker!"
	if gold == null:
		return "Spoke is polishing a new throne..."
	if GameState.player == gold:
		return "Deliver the GOLDEN THRONE to Spoke's Chop Shop"
	if gold.rider != null:
		return "Someone took the throne! Steal it back!"
	return "Find and steal the GOLDEN THRONE  (or grab a pizza job at Rolling Pizza)"

func mission_target():
	if story != null and story.target != null:
		return story.target
	if not acts.race.is_empty() and not acts.race_counting():
		return acts.race_points[acts.race.racers[0].cp]
	if not pizza.is_empty():
		return pizza.pos
	if gold == null:
		return null
	if GameState.player == gold:
		return city.points["chop"]
	return gold.global_position

func map_icons() -> Array:
	var out: Array = []
	out.append({"pos": city.points["hospital"], "color": Color("eef2f5"), "letter": "H"})
	out.append({"pos": city.points["hq"], "color": Color("4f8bff"), "letter": "K"})
	out.append({"pos": city.points["chop"], "color": Color("ffd84a"), "letter": "$"})
	out.append({"pos": city.points["pimp"], "color": Color("ff3fa4"), "letter": "M"})
	out.append({"pos": acts.race_start, "color": Color("39ff14"), "letter": "R"})
	if story.active < 0 and GameState.story < story.missions.size():
		out.append({"pos": story.start_pos, "color": Color("b388ff"), "letter": "S"})
	if story.target != null:
		out.append({"pos": story.target, "color": Color("b388ff"), "letter": "!"})
	for s in acts.stunts:
		if not s.done:
			out.append({"pos": s.pos, "color": Color("ff9f1c"), "letter": "J"})
	if city.points.has("skate"):
		out.append({"pos": city.points["skate"], "color": Color("7ee0ff"), "letter": "X"})
	for sp in city.stunt_spots:
		if sp.label == "HALF-PIPE" and sp.pos.distance_to(city.points.get("skate", Vector3.INF)) > 25.0:
			out.append({"pos": sp.pos, "color": Color("7ee0ff"), "letter": "U"})
	if pizza.is_empty():
		out.append({"pos": city.points["pizza"], "color": Color("ff7a2b"), "letter": "P"})
	else:
		out.append({"pos": pizza.pos, "color": Color("2a9dff"), "letter": "!"})
	if gold != null and GameState.player != gold:
		out.append({"pos": gold.global_position, "color": Color("f5c542"), "letter": "G"})
	return out

# ------------------------------------------------------------------ props
func on_prop_hit(body: RigidBody3D, c: Chair) -> void:
	if body.has_meta("crate"):
		story.crate_hit(body, c)
		return
	if body.has_meta("stairs_sign"):
		fun.sign_hit(body, c)
		return
	for pr in props:
		if pr.body != body or pr.hit:
			continue
		pr.hit = true
		pr.t = 0.0
		var isp := c == GameState.player
		if c.mode == "cop" and pr.kind in ["cone", "barrier", "bin"]:
			fun.cop_tripped(c)
		match pr.kind:
			"cone", "barrier":
				Sfx.play("bonk", 1.6, -6.0)
				if isp:
					GameState.add_cred(5, body.global_position + Vector3.UP * 1.2, ["CONED! +$5", "BOOP +$5"].pick_random())
			"newsbox":
				Sfx.play("crash", 1.1, -4.0)
				_particles(body.global_position + Vector3.UP * 0.8, Color(0.95, 0.95, 0.9), 22, 4.0, 1.0, 1.8, -3.0, 80.0)
				if isp:
					GameState.add_cred(20, body.global_position + Vector3.UP * 1.5, "EXTRA! EXTRA! +$20")
			"bin":
				_particles(body.global_position + Vector3.UP * 0.6, Color(0.75, 0.68, 0.5), 18, 4.0, 1.0, 1.4, -9.0, 70.0, 0.15)
				Sfx.play("crash", 1.3, -6.0)
				if isp:
					GameState.add_cred(10, body.global_position + Vector3.UP * 1.5, ["TRASHED! +$10", "BIN THERE, DONE THAT +$10"].pick_random())
			"hydrant":
				pr.gush = 6.0
				Sfx.play("splash")
				if isp:
					GameState.add_cred(25, body.global_position + Vector3.UP * 1.5, "SPLASH! +$25")
			"stand":
				Sfx.play("crash")
				var fruit = body.get_child(1).get_child(body.get_child(1).get_child_count() - 1)
				if fruit != null:
					fruit.visible = false
				_spill_fruit(body.global_position + Vector3.UP * 1.0, c.velocity)
				if isp:
					GameState.add_cred(50, body.global_position + Vector3.UP * 2, "FRUIT SALAD! +$50")
					GameState.say_sub("FRUIT VENDOR", ["MY APPLES!!", "That stand was my FATHER'S!", "I'm sending you the bill!"].pick_random(), Color("ffb703"))
		return

func _spill_fruit(pos: Vector3, vel: Vector3) -> void:
	var fc := [Color("e63946"), Color("ffb703"), Color("7cb518"), Color("fb8500")]
	var sh := SphereShape3D.new()
	sh.radius = 0.1
	for i in 14:
		var b := RigidBody3D.new()
		b.collision_layer = 16
		b.collision_mask = 1 | 8 | 16
		b.mass = 0.3
		var cs := CollisionShape3D.new()
		cs.shape = sh
		b.add_child(cs)
		Models.sph(b, 0.1, Vector3.ZERO, Models.mat(fc[i % 4], 0.5))
		b.position = pos + Vector3(randf_range(-0.6, 0.6), randf() * 0.3, randf_range(-0.3, 0.3))
		add_child(b)
		b.linear_velocity = vel * 0.5 + Vector3(randf_range(-3, 3), randf_range(2, 5), randf_range(-3, 3))
		get_tree().create_timer(15.0).timeout.connect(b.queue_free)

func _props(dt: float) -> void:
	var pp: Vector3 = GameState.player.global_position
	for pr in props:
		if not pr.hit:
			continue
		pr.t += dt
		var b: RigidBody3D = pr.body
		if pr.gush > 0.0:
			pr.gush -= dt
			if Engine.get_physics_frames() % 4 == 0:
				_particles(b.get_meta("home_pos", pr.home.origin) + Vector3.UP * 0.5, Color(0.6, 0.85, 1.0, 0.8), 10, 9.0, 1.2, 1.2, -9.8, 12.0)
			for c in chairs:
				if c.is_on_floor() and c.global_position.distance_to(pr.home.origin) < 1.6:
					c.velocity.y = 9.0
					if c == GameState.player:
						GameState.pop(c.global_position + Vector3.UP * 2, "GEYSER JUMP!", Color("7ee0ff"))
						Sfx.play("jump")
					elif c.rider != null:
						c.say("WHOAAA!", 1.5)
		if pr.t > 40.0 and pp.distance_to(pr.home.origin) > 60.0:
			pr.hit = false
			pr.gush = 0.0
			b.linear_velocity = Vector3.ZERO
			b.angular_velocity = Vector3.ZERO
			b.transform = pr.home
			if pr.kind != "bin":
				b.freeze = true
			var m = b.get_child(1)
			if m != null and m.get_child_count() > 0:
				m.get_child(m.get_child_count() - 1).visible = true

# ------------------------------------------------------------------ Pimp My Chair
func restyle() -> void:
	for c in chairs:
		if c == GameState.player:
			Models.apply_style(c.model, GameState.style)
			c.set_meta("styled", true)
			if GameState.retro:
				Models.vertex_light(c, true, {})
		elif c.has_meta("styled"):
			Models.apply_style(c.model, {})
			c.remove_meta("styled")

func open_shop() -> void:
	shop_lock = true
	state = "shop"
	GameState.player.velocity = Vector3.ZERO
	get_tree().paused = true
	hud.open_shop()
	Sfx.play("steal")

func close_shop() -> void:
	get_tree().paused = false
	state = "play"
	hud.close_shop()

func shop_buy(item: Dictionary) -> String:
	var id: String = item.id
	var st: Dictionary = GameState.style
	var msg := ""
	if not GameState.owned.has(id):
		if GameState.cred < item.price:
			Sfx.play("bonk")
			return "Not enough cred! Go steal something. Responsibly."
		GameState.cred -= item.price
		GameState.owned[id] = true
		msg = "Bought: " + item.label + "!"
		Sfx.play("big")
	match item.kind:
		"paint":
			st.paint = "" if (st.paint == id and msg == "") else id
			if st.paint != "" and GameState.wanted > 0:
				GameState.wanted = 0
				GameState.wanted_cool = 0.0
				msg += "  New look - the cops don't recognise you!"
		"neon":
			if msg != "":
				st.neon = GameState.NEONS[0]
			else:
				var k := GameState.NEONS.find(st.neon)
				st.neon = "" if k == GameState.NEONS.size() - 1 else GameState.NEONS[k + 1]
		_:
			st[id] = true if msg != "" else not st[id]
	restyle()
	GameState.save_game()
	return msg

func _style_fx() -> void:
	var p: Chair = GameState.player
	var st: Dictionary = GameState.style
	if Models.rainbow_mat != null:
		var c := Color.from_hsv(fposmod(GameState.time * 0.2, 1.0), 0.85, 1.0)
		Models.rainbow_mat.albedo_color = c
		Models.rainbow_mat.emission = c
	var on: bool = st.neon != "" and hop == null and p != null
	neon_glow.visible = on
	neon_light.light_energy = (2.5 + night * 3.0) if on else 0.0
	if on:
		var c := Color(st.neon)
		neon_light.light_color = c
		neon_glow.material_override.albedo_color = c
		neon_glow.global_position = p.global_position + Vector3.UP * 0.03
		neon_light.global_position = p.global_position + Vector3.UP * 0.25
		var s := 1.0 + sin(GameState.time * 4.0) * 0.06
		neon_glow.scale = Vector3(s, 1, s)

func _air_horn(p: Chair) -> void:
	Sfx.play("horn")
	shake(0.3)
	GameState.pop(p.global_position + Vector3.UP * 2.2, "BWAAAAAMP!", Color("ffd84a"))
	for c in chairs:
		if c == p or c.global_position.distance_to(p.global_position) > 14.0:
			continue
		var away: Vector3 = (c.global_position - p.global_position).normalized()
		c.velocity += Vector3(away.x, 0.0, away.z) * 4.0
		if c.rider != null:
			c.spin = randf_range(-0.3, 0.3)
			c.say(["AAAAH!", "MY EARS!", "WHO DOES THAT?!", "*jumps out of skin*"].pick_random(), 2.0)

# ------------------------------------------------------------------ pigeons
func _spawn_pigeons() -> void:
	for i in 16:
		var c: Vector3
		var bl: Dictionary = city.blocks.pick_random()
		if bl.type == "park":
			c = Vector3(bl.x0 + randf_range(6, 34), City.CURB, bl.z0 + randf_range(6, 34))
		else:
			c = city.sidewalk_point(bl).pos
		var f := {"pos": c, "birds": [], "state": "idle", "t": 0.0}
		for k in 6:
			var b := Models.pigeon()
			var off := Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.6, 1.6))
			b.position = c + off
			b.rotation.y = randf() * TAU
			add_child(b)
			f.birds.append({"node": b, "off": off, "vel": Vector3.ZERO, "peck": randf() * 5.0})
		flocks.append(f)

func _pigeons(dt: float) -> void:
	var p: Chair = GameState.player
	for f in flocks:
		var d: float = p.global_position.distance_to(f.pos)
		if f.state == "idle":
			if d > 60.0:
				continue
			if d < 5.0 and p.speed() > 0.8:
				f.state = "fly"
				f.t = 0.0
				for b in f.birds:
					var away: Vector3 = (b.node.global_position - p.global_position)
					away.y = 0
					away = away.normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6))
					b.vel = away * randf_range(3.0, 5.0) + Vector3.UP * randf_range(2.0, 3.5)
					b.node.rotation.y = atan2(-b.vel.x, -b.vel.z)
				GameState.add_cred(5, f.pos + Vector3.UP * 1.5, ["COO! +$5", "*flap flap* +$5", "PIGEON PANIC! +$5"].pick_random())
				Sfx.play("coo")
			else:
				for b in f.birds:
					b.peck += dt * 3.0
					b.node.rotation.x = max(0.0, sin(b.peck)) * 0.4
		else:
			f.t += dt
			for b in f.birds:
				var n: Node3D = b.node
				b.vel.y += dt * 1.5
				n.position += b.vel * dt
				n.visible = f.t < 6.0
				var flap := sin(GameState.time * 40.0 + b.peck) * 0.9
				n.get_node("WingL").rotation.z = flap
				n.get_node("WingR").rotation.z = -flap
			if f.t > 25.0 and d > 40.0:
				f.state = "idle"
				for b in f.birds:
					b.node.position = f.pos + b.off
					b.node.rotation = Vector3(0, randf() * TAU, 0)
					b.node.visible = true
					b.node.get_node("WingL").rotation.z = 0.0
					b.node.get_node("WingR").rotation.z = 0.0
