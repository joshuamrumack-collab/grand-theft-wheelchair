class_name City
extends Node3D
## Builds Downtown Los Spokos: a 6 x 6 grid of blocks with roads, raised sidewalks,
## buildings, parks, special locations, street lamps, ramps and a road graph for police AI.
## All sizes are in metres.

const PITCH := 50.0          # distance between road centre lines
const ROAD := 10.0           # road width (two 5 m lanes)
const NB := 6                # blocks per side
const SIZE := NB * PITCH + ROAD
const CURB := 0.14           # sidewalk height
const BLOCK := PITCH - ROAD  # 40 m block incl. sidewalk
const WALK := 3.0            # sidewalk width
const FLOOR_H := 3.0

const LABELS := ["DONUTS", "WHEEL GOOD BANK", "SPOKES & CO", "TIRE-D GYM", "RAMP DEPOT", "ROLL-EX", "CHEESE",
	"24/7", "CASTOR OIL CO", "BURGERS", "AXLE ARCADE", "CUSHION KING", "RIM CITY", "BEARINGS BAR", "NOODLES"]
const STYLES := [Color("c07a55"), Color("8fa3b8"), Color("d8c48c"), Color("a7c4a0"), Color("c9a6cf"), Color("dadada"), Color("e8a87c"), Color("9ab7c9")]

var blocks: Array = []
var buildings: Array = []      # {rect: Rect2, color: Color, h: float}
var ramps: Array = []          # {pos: Vector3, yaw: float}
var lamp_lights: Array = []
var window_mats: Array = []
var lamp_mat: StandardMaterial3D
var astar := AStar2D.new()
var points: Dictionary = {}    # named locations
var parked_spots: Array = []   # {pos, yaw, type}
var prop_spots: Array = []     # {pos, yaw}
var rng := RandomNumberGenerator.new()
var _win_tex: ImageTexture
var _win_emit: ImageTexture
var _mat_cache: Dictionary = {}
var rails: Array = []          # grindable edges {a, b, d, len, kind}: curbs, ledges, handrails
var dumpsters: Array = []      # Vector3 positions (hiding spots)
var alley_spots: Array = []    # deep inside alleys (secret cassette)
var sign_spots: Array = []     # {pos, yaw} for STAIRS INC. signs
var donut_spots: Array = []    # Vector3 donut box pickups
var stunt_spots: Array = []    # {pos, label} marked on the minimap
var birds: Array = []
var steam: Array = []
const CUSTOM := preload("res://scripts/custom.gd")

func build() -> void:
	rng.seed = 90210
	_win_tex = _make_window_tex(false)
	_win_emit = _make_window_tex(true)
	lamp_mat = Models.unique_mat(Color("fff4c4"), Color("ffe2a0"), 0.4)
	_ground()
	for bz in NB:
		for bx in NB:
			_block(bx, bz)
	_markings()
	_ramps()
	_walls()
	_road_graph()
	_street_details()
	_birds()

# ------------------------------------------------------------------ materials
func _noise_tex(c1: Color, c2: Color, freq: float, normal: bool = false) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	if normal:
		t.as_normal_map = true
		t.bump_strength = 4.0
	else:
		var g := Gradient.new()
		g.set_color(0, c1)
		g.set_color(1, c2)
		t.color_ramp = g
	return t

func _surface_mat(c1: Color, c2: Color, scl: float, rough: float = 0.9, freq: float = 0.02) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(c1, c2, freq)
	m.normal_enabled = true
	m.normal_texture = _noise_tex(c1, c2, freq * 3.0, true)
	m.normal_scale = 0.4
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scl
	return m

func _make_window_tex(emit: bool) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK if emit else Color(0.93, 0.93, 0.93))
	if emit:
		img.fill_rect(Rect2i(10, 12, 44, 36), Color(1.0, 0.82, 0.5))
	else:
		img.fill_rect(Rect2i(0, 58, 64, 6), Color(0.8, 0.8, 0.8))
		img.fill_rect(Rect2i(9, 11, 46, 38), Color(0.72, 0.72, 0.72))
		img.fill_rect(Rect2i(10, 12, 44, 36), Color(0.16, 0.22, 0.31))
		img.fill_rect(Rect2i(10, 12, 12, 36), Color(0.36, 0.48, 0.62))
		img.fill_rect(Rect2i(31, 12, 2, 36), Color(0.75, 0.75, 0.75))
		img.fill_rect(Rect2i(8, 48, 48, 3), Color(0.68, 0.68, 0.68))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

var _building_shader: Shader = preload("res://shaders/building.gdshader")

func _wall_mat(color: Color, odd: bool) -> ShaderMaterial:
	var key := "%s%s" % [color.to_html(), odd]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = _building_shader
	m.set_shader_parameter("wall_color", color)
	m.set_shader_parameter("odd", 0.5 if odd else 0.0)
	m.set_shader_parameter("night", 0.0)
	var ft := "res://assets/textures/%s.png" % ("brick" if hash(key) % 3 != 0 else "stucco")
	if ResourceLoader.exists(ft):
		m.set_shader_parameter("facade_tex", load(ft))
		m.set_shader_parameter("use_tex", 1.0)
	_mat_cache[key] = m
	window_mats.append(m)
	return m

# ------------------------------------------------------------------ ground
func _ground() -> void:
	var asphalt := _tex_mat("asphalt", Color("c8cbd2"), 0.2, 0.85)
	if asphalt == null:
		asphalt = _surface_mat(Color("2f3237"), Color("45494f"), 0.25, 0.85, 0.05)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIZE, SIZE)
	plane.mesh = pm
	plane.material_override = asphalt
	plane.position = Vector3(SIZE / 2, 0, SIZE / 2)
	add_child(plane)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(SIZE + 400, 1, SIZE + 400)
	cs.shape = bs
	body.add_child(cs)
	body.position = Vector3(SIZE / 2, -0.5, SIZE / 2)
	add_child(body)
	var outer := MeshInstance3D.new()
	var om := PlaneMesh.new()
	om.size = Vector2(3000, 3000)
	outer.mesh = om
	outer.material_override = _surface_mat(Color("4a6b3a"), Color("6b8c4a"), 0.05, 1.0, 0.01)
	outer.position = Vector3(SIZE / 2, -0.03, SIZE / 2)
	add_child(outer)

func _walls() -> void:
	var m := _tex_mat("brick", Color("b06a4f"), 0.25)
	if m == null:
		m = _surface_mat(Color("8a857b"), Color("a19b8f"), 0.5, 0.9)
	for a in [[Vector3(SIZE / 2, 1.5, -1), Vector3(SIZE + 4, 3, 2)], [Vector3(SIZE / 2, 1.5, SIZE + 1), Vector3(SIZE + 4, 3, 2)],
			[Vector3(-1, 1.5, SIZE / 2), Vector3(2, 3, SIZE + 4)], [Vector3(SIZE + 1, 1.5, SIZE / 2), Vector3(2, 3, SIZE + 4)]]:
		_static_box(a[0], a[1], m)

func _static_box(center: Vector3, size: Vector3, m: Material, parent: Node3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	if m != null:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = m
		body.add_child(mi)
	(parent if parent != null else self).add_child(body)
	return body

func _flat(center: Vector3, size: Vector2, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = m
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

# ------------------------------------------------------------------ blocks
var _sidewalk_mat: StandardMaterial3D
var _plaza_mat: StandardMaterial3D
var _grass_mat: StandardMaterial3D
var _lot_mat: StandardMaterial3D

## Hand-painted texture (assets/textures/*.png, made by tools/gtw_textures.py), world-triplanar.
func _tex_mat(tex: String, tint: Color, scl: float, rough: float = 0.9) -> StandardMaterial3D:
	var path := "res://assets/textures/%s.png" % tex
	if not ResourceLoader.exists(path):
		return null
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = tint
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scl
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _paver_mat() -> StandardMaterial3D:
	var tm := _tex_mat("sidewalk", Color("e6dac6"), 0.5)
	if tm != null:
		return tm
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color("bdb7ab"))
	for i in 128:
		for j in 128:
			var v := randf() * 0.06
			img.set_pixel(i, j, Color("bdb7ab").darkened(v))
	img.fill_rect(Rect2i(0, 0, 128, 3), Color("9a9488"))
	img.fill_rect(Rect2i(0, 0, 3, 128), Color("9a9488"))
	img.fill_rect(Rect2i(0, 64, 128, 2), Color("a9a397"))
	img.fill_rect(Rect2i(64, 0, 2, 128), Color("a9a397"))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.9
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _block(bx: int, bz: int) -> void:
	if _sidewalk_mat == null:
		_sidewalk_mat = _paver_mat()
		_plaza_mat = _tex_mat("concrete", Color("e0dbd2"), 0.25)
		if _plaza_mat == null:
			_plaza_mat = _surface_mat(Color("8e8a82"), Color("a29d94"), 0.3, 0.9, 0.03)
		_grass_mat = _surface_mat(Color("4f8f3c"), Color("6aa84f"), 0.15, 1.0, 0.02)
		_lot_mat = _tex_mat("asphalt", Color("b4b8c0"), 0.2, 0.85)
		if _lot_mat == null:
			_lot_mat = _surface_mat(Color("3d4047"), Color("4b4f57"), 0.25, 0.85, 0.05)
	var x0 := bx * PITCH + ROAD
	var z0 := bz * PITCH + ROAD
	var type := "city"
	if bx == 1 and bz == 1: type = "hospital"
	elif bx == 4 and bz == 4: type = "police"
	elif bx == 3 and bz == 2: type = "chop"
	elif bx == 1 and bz == 3: type = "pizza"
	elif bx == 2 and bz == 1: type = "pimp"
	elif bx == 4 and bz == 2: type = "skate"
	elif rng.randf() < 0.16: type = "park"
	var bl := {"bx": bx, "bz": bz, "x0": x0, "z0": z0, "type": type}
	blocks.append(bl)
	_static_box(Vector3(x0 + BLOCK / 2, CURB / 2, z0 + BLOCK / 2), Vector3(BLOCK, CURB, BLOCK), _sidewalk_mat)
	# every curb edge is grindable (trimmed short of the corner lamps)
	for e in [[Vector3(x0 + 2, CURB, z0), Vector3(x0 + BLOCK - 2, CURB, z0)], [Vector3(x0 + 2, CURB, z0 + BLOCK), Vector3(x0 + BLOCK - 2, CURB, z0 + BLOCK)],
			[Vector3(x0, CURB, z0 + 2), Vector3(x0, CURB, z0 + BLOCK - 2)], [Vector3(x0 + BLOCK, CURB, z0 + 2), Vector3(x0 + BLOCK, CURB, z0 + BLOCK - 2)]]:
		add_rail(e[0], e[1], "curb")
	var ix := x0 + WALK
	var iz := z0 + WALK
	var inner := BLOCK - WALK * 2
	var top := CURB + 0.004
	match type:
		"park":
			_flat(Vector3(x0 + BLOCK / 2, top, z0 + BLOCK / 2), Vector2(inner, inner), _grass_mat)
			_flat(Vector3(x0 + BLOCK / 2, top + 0.002, z0 + BLOCK / 2), Vector2(inner, 3), _plaza_mat)
			_flat(Vector3(x0 + BLOCK / 2, top + 0.002, z0 + BLOCK / 2), Vector2(3, inner), _plaza_mat)
			var pond := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 6.0
			cm.bottom_radius = 6.0
			cm.height = 0.05
			cm.radial_segments = 40
			pond.mesh = cm
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(0.25, 0.55, 0.8, 0.85)
			wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wm.roughness = 0.05
			wm.metallic = 0.3
			pond.material_override = wm
			var pc := Vector3(x0 + BLOCK / 2 + (8 if rng.randf() < 0.5 else -8), top + 0.02, z0 + BLOCK / 2 + (8 if rng.randf() < 0.5 else -8))
			var hpc := Vector3(2 * (x0 + BLOCK / 2) - pc.x - signf(pc.x - x0 - BLOCK / 2) * 1.5, CURB, 2 * (z0 + BLOCK / 2) - pc.z - signf(pc.z - z0 - BLOCK / 2) * 1.5)
			bl["hpc"] = hpc
			pond.position = pc
			bl["pond"] = pc
			pond.scale = Vector3(1, 1, 0.7)
			add_child(pond)
			for i in 10:
				var p := Vector3(ix + 2 + rng.randf() * (inner - 4), CURB, iz + 2 + rng.randf() * (inner - 4))
				if abs(p.x - (x0 + BLOCK / 2)) < 3 or abs(p.z - (z0 + BLOCK / 2)) < 3 or p.distance_to(pc) < 8 or Vector2(p.x - hpc.x, p.z - hpc.z).length() < 8.5:
					continue
				_tree(p, 0.8 + rng.randf() * 0.5)
			for k in 2:
				var b := Models.bench()
				b.position = Vector3(x0 + BLOCK / 2 + 3.2, CURB, z0 + BLOCK / 2 - 6 + k * 12)
				b.rotation.y = -PI / 2
				add_child(b)
			points["park_%d_%d" % [bx, bz]] = Vector3(x0 + BLOCK / 2, CURB, z0 + BLOCK / 2)
		"skate":
			_flat(Vector3(x0 + BLOCK / 2, top, z0 + BLOCK / 2), Vector2(inner, inner), _plaza_mat)
			_skate_plaza(x0, z0)
		"hospital":
			_flat(Vector3(x0 + BLOCK / 2, top, z0 + BLOCK / 2), Vector2(inner, inner), _plaza_mat)
			_building(Rect2(x0 + 4, z0 + 4, 32, 16), 4, Color("eef2f5"), "HOSPITAL", Color("e63946"))
			_flat(Vector3(x0 + BLOCK / 2, top + 0.002, z0 + 28.5), Vector2(32, 13), _lot_mat)
			for i in 6:
				var sx := x0 + 7 + i * 5.2
				_line(Vector3(sx - 2.6, top + 0.004, z0 + 26), Vector2(0.12, 5.0), Color.WHITE)
				parked_spots.append({"pos": Vector3(sx, CURB, z0 + 25.5), "yaw": 0.0, "type": ["rusty", "hospital", "power", "hospital", "turbo", "rusty"][i]})
			points["hospital"] = Vector3(x0 + BLOCK / 2, CURB, z0 + 31)
		"police":
			_flat(Vector3(x0 + BLOCK / 2, top, z0 + BLOCK / 2), Vector2(inner, inner), _plaza_mat)
			_building(Rect2(x0 + 4, z0 + 4, 32, 16), 5, Color("5b7bb5"), "KERB PATROL HQ", Color("ffd84a"))
			_flat(Vector3(x0 + BLOCK / 2, top + 0.002, z0 + 28.5), Vector2(32, 13), _lot_mat)
			for i in 3:
				parked_spots.append({"pos": Vector3(x0 + 12 + i * 8, CURB, z0 + 26), "yaw": 0.0, "type": "cop"})
			points["hq"] = Vector3(x0 + BLOCK / 2, CURB, z0 + BLOCK - 1.5)
		"chop":
			_flat(Vector3(x0 + BLOCK / 2, top, z0 + BLOCK / 2), Vector2(inner, inner), _plaza_mat)
			_building(Rect2(x0 + 4, z0 + 4, 32, 32), 2, Color("9b6b4b"), "SPOKE'S CHOP SHOP", Color("ffd84a"))
			points["chop"] = Vector3(x0 + BLOCK / 2, CURB, z0 + 1.5)
		_:
			_flat(Vector3(x0 + BLOCK / 2, top, z0 + BLOCK / 2), Vector2(inner, inner), _plaza_mat)
			var lot := 16.0
			for j in 2:
				for i in 2:
					var r := Rect2(x0 + WALK + 0.0 + i * (lot + 2), z0 + WALK + j * (lot + 2), lot, lot)
					var floors := 2 + rng.randi() % 7
					var label := ""
					var lc := Color.WHITE
					if type == "pizza" and i == 0 and j == 1:
						label = "ROLLING PIZZA"
						lc = Color("ff7a2b")
						floors = 3
					elif type == "pimp" and i == 1 and j == 1:
						label = "PIMP MY CHAIR"
						lc = Color("ff6fb5")
						floors = 3
					elif rng.randf() < 0.5:
						label = LABELS[rng.randi() % LABELS.size()]
					_building(r, floors, STYLES[rng.randi() % STYLES.size()], label, lc, j)
			if type == "pizza":
				points["pizza"] = Vector3(x0 + 11, CURB, z0 + BLOCK - 1.5)
			if type == "pimp":
				points["pimp"] = Vector3(x0 + 29, CURB, z0 + BLOCK - 1.5)
	_dress(bl, type)
	# street lamps on the four corners
	for c in [[x0 + 0.6, z0 + 0.6, -1, -1], [x0 + BLOCK - 0.6, z0 + 0.6, 1, -1], [x0 + BLOCK - 0.6, z0 + BLOCK - 0.6, 1, 1], [x0 + 0.6, z0 + BLOCK - 0.6, -1, 1]]:
		var l := Models.lamp()
		l.position = Vector3(c[0], CURB, c[1])
		l.rotation.y = atan2(-c[2], -c[3])
		add_child(l)
		var head = l.find_child("Head", true, false)
		if head is MeshInstance3D:
			head.material_override = lamp_mat
		var ol := OmniLight3D.new()
		ol.light_color = Color("ffd9a0")
		ol.omni_range = 11.0
		ol.light_energy = 0.0
		ol.shadow_enabled = false
		ol.position = l.position + Vector3(c[2] * 0.85, 4.9, c[3] * 0.85)
		add_child(ol)
		lamp_lights.append(ol)
	# spots for props: along the outer sidewalk edge
	for k in 3:
		var p := sidewalk_point(bl)
		var out := Vector3(-cos(p.yaw), 0, sin(p.yaw))
		prop_spots.append({"pos": p.pos + out * 0.9, "yaw": p.yaw})

# ------------------------------------------------------------------ street dressing
## Solid set dressing: dumpsters in alleys, vending machines against walls, and skate-spot
## ledges, rails, picnic tables and fences in the parks.
func _solid(prop: String, pos: Vector3, yaw: float, size: Vector3, yoff: float = -1.0) -> Node3D:
	var m := Models.street(prop)
	if m == null:
		return null
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position.y = size.y / 2 if yoff < 0.0 else yoff
	body.add_child(cs)
	body.add_child(m)
	add_child(body)
	match prop:
		"ledge": _rail_local(body, Vector3(-1.9, 0.53, 0), Vector3(1.9, 0.53, 0), "ledge")
		"handrail": _rail_local(body, Vector3(-1.75, 0.93, 0), Vector3(1.75, 0.93, 0), "rail")
		"funbox": _rail_local(body, Vector3(0, 0.98, -0.95), Vector3(0, 0.98, 0.95), "rail")
		"dumpster": dumpsters.append(pos)
	return body

func add_rail(a: Vector3, b: Vector3, kind: String) -> void:
	var d := b - a
	var L := d.length()
	if L < 1.0:
		return
	rails.append({"a": a, "b": b, "d": d / L, "len": L, "kind": kind})

func _rail_local(body: Node3D, la: Vector3, lb: Vector3, kind: String) -> void:
	var t := Transform3D(Basis(Vector3.UP, body.rotation.y), body.position)
	add_rail(t * la, t * lb, kind)

## Ramps with real curves (Blender quarter pipe / kicker / funbox). Quarter pipes launch you straight up.
func _skate_piece(prop: String, pos: Vector3, yaw: float) -> StaticBody3D:
	var m := Models.street(prop)
	if m == null:
		return null
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	body.add_child(m)
	add_child(body)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var cs := CollisionShape3D.new()
		var tri: ConcavePolygonShape3D = mi.mesh.create_trimesh_shape()
		tri.backface_collision = true
		cs.shape = tri
		cs.transform = body.global_transform.affine_inverse() * mi.global_transform
		body.add_child(cs)
	if prop == "quarterpipe":
		body.set_meta("qp", Basis(Vector3.UP, yaw) * Vector3.FORWARD)
	match prop:
		"funbox": _rail_local(body, Vector3(0, 0.98, -0.95), Vector3(0, 0.98, 0.95), "rail")
		"quarterpipe": _rail_local(body, Vector3(-2.8, 1.27, -2.48), Vector3(2.8, 1.27, -2.48), "rail")
	return body

func _half_pipe(c: Vector3, yaw: float, gap: float = 3.0) -> void:
	var f := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	_skate_piece("quarterpipe", c + f * gap, yaw)
	_skate_piece("quarterpipe", c - f * gap, yaw + PI)
	stunt_spots.append({"pos": c, "label": "HALF-PIPE"})

func _skate_plaza(x0: float, z0: float) -> void:
	var cx := x0 + BLOCK / 2
	var cz := z0 + BLOCK / 2
	var y := CURB
	_half_pipe(Vector3(cx, y, cz - 9.5), PI / 2, 3.0)
	_skate_piece("funbox", Vector3(cx, y, cz + 3.5), 0.0)
	_skate_piece("kicker", Vector3(cx - 11, y, cz + 9), 0.0)
	_skate_piece("kicker", Vector3(cx + 11, y, cz + 9), 0.0)
	_skate_piece("quarterpipe", Vector3(cx - 11.0, y, cz + 1.0), PI / 2)
	_skate_piece("quarterpipe", Vector3(cx + 11.0, y, cz + 1.0), -PI / 2)
	_solid("ledge", Vector3(cx - 7, y, cz + 13), 0.0, Vector3(4.0, 0.52, 1.0))
	_solid("ledge", Vector3(cx + 7, y, cz + 13), 0.0, Vector3(4.0, 0.52, 1.0))
	_solid("handrail", Vector3(cx, y, cz + 9.5), 0.0, Vector3(3.6, 0.95, 0.12))
	for k in 2:
		var b := Models.bench()
		b.position = Vector3(cx + (-15.0 if k == 0 else 15.0), y, cz + 13.5)
		add_child(b)
	var sign_l := Label3D.new()
	sign_l.text = "LOS SPOKOS\nSKATE PLAZA"
	sign_l.font = _graffiti_font()
	sign_l.font_size = 150
	sign_l.pixel_size = 0.012
	sign_l.outline_size = 30
	sign_l.modulate = Color("7ee0ff")
	sign_l.outline_modulate = Color("1a1030")
	sign_l.position = Vector3(cx, y + 6.5, cz - 15.5)
	add_child(sign_l)
	Models.box(self, Vector3(0.25, 6.2, 0.25), Vector3(cx - 4, y + 3.1, cz - 15.7), Models.mat(Color("3a3f45"), 0.5, 0.6))
	Models.box(self, Vector3(0.25, 6.2, 0.25), Vector3(cx + 4, y + 3.1, cz - 15.7), Models.mat(Color("3a3f45"), 0.5, 0.6))
	points["skate"] = Vector3(cx, y, cz + 6)
	stunt_spots.append({"pos": Vector3(cx, y, cz), "label": "SKATE PLAZA"})

func _near_point(p: Vector3, d: float) -> bool:
	for k in points:
		if points[k] is Vector3 and Vector2(points[k].x - p.x, points[k].z - p.z).length() < d:
			return true
	return false

func _dress(bl: Dictionary, type: String) -> void:
	var x0: float = bl.x0
	var z0: float = bl.z0
	if type in ["city", "pizza", "pimp"]:
		# dumpsters a few metres into the alleys (lots are 16 m with 2 m gaps)
		var ax := x0 + WALK + 17.0
		var az := z0 + WALK + 17.0
		alley_spots.append(Vector3(ax, CURB, z0 + WALK + 12.0))
		if rng.randf() < 0.7:
			_solid("dumpster", Vector3(ax, CURB, z0 + WALK + 3.0), PI / 2, Vector3(1.95, 1.3, 1.2))
		if rng.randf() < 0.7:
			_solid("dumpster", Vector3(x0 + WALK + 3.0, CURB, az), 0.0, Vector3(1.95, 1.3, 1.2))
		# vending machines against building fronts, facing the street
		for side in 4:
			if rng.randf() > 0.4:
				continue
			var u := WALK + 4.0 + rng.randf() * (BLOCK - WALK * 2 - 8.0)
			if abs(u - 20.0) < 3.0:
				continue
			var face := WALK - 0.45
			var p: Vector3
			var yaw := 0.0
			match side:
				0: p = Vector3(x0 + u, CURB, z0 + face); yaw = 0.0
				1: p = Vector3(x0 + BLOCK - face, CURB, z0 + u); yaw = -PI / 2
				2: p = Vector3(x0 + u, CURB, z0 + BLOCK - face); yaw = PI
				_: p = Vector3(x0 + face, CURB, z0 + u); yaw = PI / 2
			if _near_point(p, 5.0):
				continue
			# yaw turns the machine's -Z front to face the street
			_solid("vending", p, yaw, Vector3(1.0, 1.95, 0.8))
	elif type == "park":
		var cx := x0 + BLOCK / 2
		var cz := z0 + BLOCK / 2
		# grindable planter ledges and a handrail beside the cross paths
		_solid("ledge", Vector3(cx + 2.7, CURB, cz - 9.0), PI / 2, Vector3(4.0, 0.52, 1.0))
		_solid("ledge", Vector3(cx - 9.0, CURB, cz - 2.7), 0.0, Vector3(4.0, 0.52, 1.0))
		_solid("handrail", Vector3(cx + 9.0, CURB, cz + 2.3), 0.0, Vector3(3.6, 0.95, 0.12))
		var pond: Vector3 = bl.get("pond", Vector3(-999, 0, -999))
		var hpc: Vector3 = bl.get("hpc", Vector3(-999, 0, -999))
		if hpc.x > -900:
			_half_pipe(hpc, 0.0, 3.0)
		for k in 6:
			var bp := Vector3(cx + rng.randf_range(-15, 15), CURB, cz + rng.randf_range(-15, 15))
			if abs(bp.x - cx) > 3 and abs(bp.z - cz) > 3 and bp.distance_to(pond) > 8 and Vector2(bp.x - hpc.x, bp.z - hpc.z).length() > 8.5:
				var bush := Models.street("bush")
				if bush != null:
					bush.position = bp
					bush.rotation.y = rng.randf() * TAU
					add_child(bush)
		for c in [Vector2(-10, 10), Vector2(10, -10), Vector2(-10, -10), Vector2(10, 10)]:
			var p := Vector3(cx + c.x, CURB, cz + c.y)
			if Vector2(p.x - pond.x, p.z - pond.z).length() > 9.5 and Vector2(p.x - hpc.x, p.z - hpc.z).length() > 9.0:
				_solid("picnic", p, rng.randf() * TAU, Vector3(1.9, 0.8, 1.6))
		# chain-link along the north edge, with a gap at the path
		var fz := z0 + WALK + 0.3
		var fx := x0 + WALK + 2.0
		while fx < x0 + BLOCK - WALK - 1.0:
			if abs(fx - cx) > 3.5:
				_solid("fence", Vector3(fx, CURB, fz), 0.0, Vector3(4.0, 2.0, 0.1))
			fx += 4.0

var _interior_tex: Texture2D
var shop_mats: Array = []
func _shop_window(c: Vector3, wdt: float, outz: float) -> void:
	if _interior_tex == null and ResourceLoader.exists("res://assets/textures/interiors.png"):
		_interior_tex = load("res://assets/textures/interiors.png")
	if _interior_tex == null:
		Models.box(self, Vector3(wdt, 2.6, 0.1), c, Models.mat(Color("1d2b3a"), 0.1, 0.5))
		return
	# a painted shop interior behind glass: shelves, a counter and a shopkeeper. Lit up at night.
	var im := StandardMaterial3D.new()
	im.albedo_texture = _interior_tex
	im.uv1_scale = Vector3(0.5 * wdt / 14.0, 0.5, 1)
	var k := rng.randi() % 4
	im.uv1_offset = Vector3(0.5 * (k % 2), 0.5 * floorf(k / 2.0), 0)
	im.emission_enabled = true
	im.emission_texture = _interior_tex
	im.emission_energy_multiplier = 0.15
	im.texture_repeat = true
	shop_mats.append(im)
	var rot := Basis.IDENTITY if outz > 0 else Basis(Vector3.UP, PI)
	_wall_quad(Transform3D(rot, c + Vector3(0, 0, outz * 0.01)), Vector2(wdt, 2.6), im)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.7, 0.85, 0.28)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.04
	gm.metallic = 0.6
	_wall_quad(Transform3D(rot, c + Vector3(0, 0, outz * 0.05)), Vector2(wdt, 2.6), gm)
	Models.box(self, Vector3(wdt + 0.1, 0.1, 0.14), c + Vector3(0, -1.32, outz * 0.06), Models.mat(Color("2a2d31"), 0.5, 0.6))

# ------------------------------------------------------------------ street details
func _street_details() -> void:
	var city_blocks := blocks.filter(func(b): return b.type in ["city", "pizza", "pimp"])
	# bus stops facing the street
	for bl in city_blocks:
		if rng.randf() > 0.45:
			continue
		var side := rng.randi() % 4
		var u := rng.randf_range(8.0, BLOCK - 8.0)
		var x0: float = bl.x0
		var z0: float = bl.z0
		var p: Vector3
		var yaw := 0.0
		match side:
			0: p = Vector3(x0 + u, CURB, z0 + 1.45); yaw = 0.0
			1: p = Vector3(x0 + BLOCK - 1.45, CURB, z0 + u); yaw = -PI / 2
			2: p = Vector3(x0 + u, CURB, z0 + BLOCK - 1.45); yaw = PI
			_: p = Vector3(x0 + 1.45, CURB, z0 + u); yaw = PI / 2
		if _near_point(p, 5.0):
			continue
		var stop := _solid("busstop", p, yaw, Vector3(3.4, 2.5, 0.2), 1.25)
		if stop != null:
			(stop.get_child(0) as CollisionShape3D).position = Vector3(0, 1.25, 0.65)
			_ad_variant(stop)
	# STAIRS INC. signs to smash, donut boxes, steam vents and puddles
	for bl in blocks:
		var sp := sidewalk_point(bl)
		sign_spots.append({"pos": sp.pos + Vector3(-cos(sp.yaw), 0, sin(sp.yaw)) * 0.6, "yaw": sp.yaw + PI / 2})
		if rng.randf() < 0.35:
			var dp := sidewalk_point(bl)
			donut_spots.append(dp.pos)
	var vent_mat := StandardMaterial3D.new()
	vent_mat.albedo_color = Color(1, 1, 1, 0.22)
	vent_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vent_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vent_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	vent_mat.vertex_color_use_as_albedo = true
	for i in 16:
		var rp := random_road_point()
		var mh := Models.street("manhole")
		if mh == null:
			break
		mh.position = Vector3(rp.x, 0.005, rp.z)
		add_child(mh)
		if i % 3 == 0:
			var pt := CPUParticles3D.new()
			pt.amount = 24
			pt.lifetime = 2.6
			pt.direction = Vector3.UP
			pt.spread = 12.0
			pt.gravity = Vector3(0.3, 0.6, 0)
			pt.initial_velocity_min = 0.6
			pt.initial_velocity_max = 1.2
			pt.scale_amount_min = 0.6
			pt.scale_amount_max = 1.6
			var sc := Curve.new()
			sc.add_point(Vector2(0, 0.3))
			sc.add_point(Vector2(1, 1.6))
			pt.scale_amount_curve = sc
			var gr := Gradient.new()
			gr.set_color(0, Color(1, 1, 1, 0.5))
			gr.set_color(1, Color(1, 1, 1, 0.0))
			pt.color_ramp = gr
			var qm := QuadMesh.new()
			qm.size = Vector2(0.8, 0.8)
			qm.material = vent_mat
			pt.mesh = qm
			pt.position = mh.position + Vector3.UP * 0.1
			add_child(pt)
			steam.append(pt)
	if ResourceLoader.exists("res://assets/textures/puddle.png"):
		var pm := StandardMaterial3D.new()
		pm.albedo_texture = load("res://assets/textures/puddle.png")
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.roughness = 0.03
		pm.metallic = 0.4
		pm.albedo_color = Color(0.5, 0.55, 0.6, 0.9)
		for i in 26:
			var rp := random_road_point()
			var q := MeshInstance3D.new()
			var pl := PlaneMesh.new()
			pl.size = Vector2(rng.randf_range(1.5, 3.5), rng.randf_range(1.2, 2.5))
			q.mesh = pl
			q.material_override = pm
			q.position = Vector3(rp.x, 0.012, rp.z)
			q.rotation.y = rng.randf() * TAU
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(q)
	for r in ramps:
		stunt_spots.append({"pos": r.pos, "label": "RAMP"})

func _ad_variant(stop: Node) -> void:
	for mi in stop.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m = mi.mesh.surface_get_material(i)
			if m is StandardMaterial3D and m.resource_name == "Ad":
				var nm: StandardMaterial3D = m.duplicate()
				nm.uv1_offset = Vector3(0.25 * (rng.randi() % 4), 0, 0)
				mi.set_surface_override_material(i, nm)

# ------------------------------------------------------------------ birds
func _birds() -> void:
	var body_m := Models.mat(Color("3a3a40"), 0.8)
	for f in 5:
		var c := Vector3(rng.randf_range(40, SIZE - 40), rng.randf_range(22, 38), rng.randf_range(40, SIZE - 40))
		for i in 7:
			var b := Node3D.new()
			Models.box(b, Vector3(0.12, 0.1, 0.38), Vector3.ZERO, body_m)
			var wl := Models.box(b, Vector3(0.45, 0.02, 0.16), Vector3(-0.25, 0, 0), body_m)
			var wr := Models.box(b, Vector3(0.45, 0.02, 0.16), Vector3(0.25, 0, 0), body_m)
			add_child(b)
			birds.append({"n": b, "c": c, "r": rng.randf_range(8, 18), "a": rng.randf() * TAU, "sp": rng.randf_range(0.25, 0.45), "h": rng.randf_range(-3, 3), "wl": wl, "wr": wr, "ph": rng.randf() * TAU})

func _process(dt: float) -> void:
	var t := GameState.time
	for b in birds:
		b.a += b.sp * dt
		var pos: Vector3 = b.c + Vector3(cos(b.a) * b.r, b.h + sin(t * 0.7 + b.ph) * 1.5, sin(b.a) * b.r)
		var n: Node3D = b.n
		n.position = pos
		n.rotation.y = -b.a
		var flap := sin(t * 11.0 + b.ph) * 0.7
		b.wl.rotation.z = flap
		b.wr.rotation.z = -flap

func _tree(p: Vector3, s: float) -> void:
	var t := Models.tree(s)
	t.position = p
	t.rotation.y = rng.randf() * TAU
	add_child(t)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3 * s
	cyl.height = 3.0
	cs.shape = cyl
	body.add_child(cs)
	body.position = p + Vector3(0, 1.5, 0)
	add_child(body)

func _line(center: Vector3, size: Vector2, color: Color) -> void:
	var m := Models.mat(color, 0.8)
	_flat(center, size, m)

func _building(r: Rect2, floors: int, color: Color, label: String, label_col: Color, face: int = 1) -> void:
	var h := floors * FLOOR_H
	var cx := r.position.x + r.size.x / 2
	var cz := r.position.y + r.size.y / 2
	var body := StaticBody3D.new()
	body.position = Vector3(cx, CURB + h / 2, cz)
	add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(r.size.x, h, r.size.y)
	cs.shape = bs
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(r.size.x, h, r.size.y)
	mi.mesh = bm
	mi.material_override = _wall_mat(color, floors % 2 == 1)
	body.add_child(mi)
	buildings.append({"rect": r, "color": color, "h": h})
	# roof: parapet, deck, rooftop units
	var top := CURB + h
	var par := Models.mat(color.darkened(0.3), 0.85)
	var deck := Models.mat(Color("6e6a66"), 0.95)
	Models.box(self, Vector3(r.size.x - 0.4, 0.1, r.size.y - 0.4), Vector3(cx, top + 0.05, cz), deck)
	Models.box(self, Vector3(r.size.x + 0.3, 0.9, 0.3), Vector3(cx, top + 0.45, r.position.y), par)
	Models.box(self, Vector3(r.size.x + 0.3, 0.9, 0.3), Vector3(cx, top + 0.45, r.end.y), par)
	Models.box(self, Vector3(0.3, 0.9, r.size.y), Vector3(r.position.x, top + 0.45, cz), par)
	Models.box(self, Vector3(0.3, 0.9, r.size.y), Vector3(r.end.x, top + 0.45, cz), par)
	var acm := Models.mat(Color("c9ced3"), 0.5, 0.4)
	for i in rng.randi() % 4:
		Models.box(self, Vector3(1.5 + rng.randf(), 1.0, 1.2 + rng.randf()), Vector3(cx - r.size.x / 3 + rng.randf() * r.size.x / 1.5, top + 0.6, cz - r.size.y / 3 + rng.randf() * r.size.y / 1.5), acm)
	if rng.randf() < 0.2 and r.size.x <= 16:
		Models.cyl(self, 1.2, 2.2, Vector3(cx + 3, top + 2.6, cz + 3), Models.mat(Color("8a5a36"), 0.9), Vector3.ZERO, 12)
		for k in 4:
			Models.box(self, Vector3(0.1, 1.5, 0.1), Vector3(cx + 3 + (0.8 if k % 2 else -0.8), top + 0.75, cz + 3 + (0.8 if k < 2 else -0.8)), par)
	if rng.randf() < 0.55:
		_graffiti(r, (0 if face == 1 else 1) if label != "" else -1)
	if rng.randf() < 0.45:
		_posters(r, (0 if face == 1 else 1) if label != "" else -1)
	if label != "":
		var fz := r.end.y if face == 1 else r.position.y
		var outz := 1.0 if face == 1 else -1.0
		# shop front: dark glass band and awning
		_shop_window(Vector3(cx, CURB + 1.3, fz + outz * 0.05), r.size.x - 2, outz)
		var aw := Models.box(self, Vector3(r.size.x - 1, 0.12, 1.6), Vector3(cx, CURB + 3.0, fz + outz * 0.8), Models.mat(label_col.darkened(0.15), 0.7), Vector3(outz * 0.18, 0, 0))
		aw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var sign_label := Label3D.new()
		sign_label.text = label
		sign_label.font_size = 160
		sign_label.pixel_size = 0.006
		sign_label.outline_size = 24
		sign_label.modulate = label_col
		sign_label.outline_modulate = Color(0, 0, 0, 0.85)
		sign_label.position = Vector3(cx, CURB + 3.75, fz + outz * 0.12)
		sign_label.rotation.y = 0.0 if face == 1 else PI
		sign_label.double_sided = false
		add_child(sign_label)
		if label == "HOSPITAL":
			var red := Models.mat(Color("e63946"), 0.6)
			Models.box(self, Vector3(2, 0.12, 6), Vector3(cx, top + 0.16, cz), red)
			Models.box(self, Vector3(6, 0.12, 2), Vector3(cx, top + 0.16, cz), red)

func _ramps() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 1.6
	var L := 1.6
	var H := 0.85
	var v := [Vector3(-w, 0, L), Vector3(w, 0, L), Vector3(w, 0, -L), Vector3(-w, 0, -L), Vector3(w, H, -L), Vector3(-w, H, -L)]
	var tris := [[0, 1, 4], [0, 4, 5], [3, 5, 4], [3, 4, 2], [1, 2, 4], [0, 5, 3], [0, 3, 2], [0, 2, 1]]
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
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("f3cd52")
	m.roughness = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var stripe := Models.mat(Color("1a1a1a"), 0.7)
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array(v)
	for i in 16:
		var line := rng.randi() % (NB + 1)
		var along := (rng.randi() % NB) * PITCH + ROAD + 10 + rng.randf() * 20
		var lane := 1 if rng.randf() < 0.5 else -1
		var pos: Vector3
		var yaw: float
		if rng.randf() < 0.5:
			pos = Vector3(along, 0, line * PITCH + ROAD / 2 + lane * 2.5)
			yaw = -PI / 2 if lane > 0 else PI / 2
		else:
			pos = Vector3(line * PITCH + ROAD / 2 + lane * 2.5, 0, along)
			yaw = PI if lane < 0 else 0.0
		var body := StaticBody3D.new()
		body.position = pos
		body.rotation.y = yaw
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		body.add_child(mi)
		for k in 4:
			Models.box(body, Vector3(0.7, H - 0.02, 0.06), Vector3(-1.2 + k * 0.8, (H - 0.02) / 2, -L - 0.01), stripe if k % 2 == 0 else m)
		Models.set_shadows(body)
		add_child(body)
		ramps.append({"pos": pos, "yaw": yaw})

func _markings() -> void:
	var yellow := Models.mat(Color("e9c94a"), 0.7)
	var white := Models.mat(Color(0.95, 0.95, 0.95), 0.7)
	var dashes: Array = []
	var zebra: Array = []
	for i in NB + 1:
		var c := i * PITCH + ROAD / 2
		for b in NB:
			var a := b * PITCH + ROAD + 2
			var e := (b + 1) * PITCH - 2
			var s := a
			while s + 3 <= e:
				dashes.append(Transform3D(Basis().scaled(Vector3(3, 1, 0.15)), Vector3(s + 1.5, 0.012, c)))
				dashes.append(Transform3D(Basis().scaled(Vector3(0.15, 1, 3)), Vector3(c, 0.012, s + 1.5)))
				s += 6
	for i in NB + 1:
		for j in NB + 1:
			var X := i * PITCH
			var Z := j * PITCH
			for k in 7:
				var o := 1.0 + k * 1.35
				zebra.append(Transform3D(Basis().scaled(Vector3(0.6, 1, 2.2)), Vector3(X + o + 0.3, 0.012, Z - 1.4)))
				zebra.append(Transform3D(Basis().scaled(Vector3(0.6, 1, 2.2)), Vector3(X + o + 0.3, 0.012, Z + ROAD + 1.4)))
				zebra.append(Transform3D(Basis().scaled(Vector3(2.2, 1, 0.6)), Vector3(X - 1.4, 0.012, Z + o + 0.3)))
				zebra.append(Transform3D(Basis().scaled(Vector3(2.2, 1, 0.6)), Vector3(X + ROAD + 1.4, 0.012, Z + o + 0.3)))
	_multimesh(dashes, yellow)
	_multimesh(zebra, white)

func _multimesh(xforms: Array, m: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	mm.mesh = pm
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

# ------------------------------------------------------------------ navigation helpers
func _road_graph() -> void:
	for j in NB + 1:
		for i in NB + 1:
			astar.add_point(j * (NB + 1) + i, Vector2(i * PITCH + ROAD / 2, j * PITCH + ROAD / 2))
	for j in NB + 1:
		for i in NB + 1:
			var id := j * (NB + 1) + i
			if i < NB: astar.connect_points(id, id + 1)
			if j < NB: astar.connect_points(id, id + NB + 1)

func road_path(from: Vector3, to: Vector3) -> PackedVector2Array:
	var a := astar.get_closest_point(Vector2(from.x, from.z))
	var b := astar.get_closest_point(Vector2(to.x, to.z))
	return astar.get_point_path(a, b)

func corners(bl: Dictionary) -> Array:
	var x0: float = bl.x0
	var z0: float = bl.z0
	var a := WALK / 2
	var b := BLOCK - WALK / 2
	return [Vector3(x0 + a, CURB, z0 + a), Vector3(x0 + b, CURB, z0 + a), Vector3(x0 + b, CURB, z0 + b), Vector3(x0 + a, CURB, z0 + b)]

func block_at(p: Vector3) -> Dictionary:
	var bx := clampi(int(floor((p.x - ROAD) / PITCH)), 0, NB - 1)
	var bz := clampi(int(floor((p.z - ROAD) / PITCH)), 0, NB - 1)
	return blocks[bz * NB + bx]

func sidewalk_point(bl: Dictionary = {}) -> Dictionary:
	if bl.is_empty():
		bl = blocks[randi() % blocks.size()]
	var u := WALK / 2 + randf() * (BLOCK - WALK)
	var s := randi() % 4
	var x0: float = bl.x0
	var z0: float = bl.z0
	var a := WALK / 2
	var b := BLOCK - WALK / 2
	match s:
		0: return {"pos": Vector3(x0 + u, CURB, z0 + a), "yaw": -PI / 2}
		1: return {"pos": Vector3(x0 + b, CURB, z0 + u), "yaw": PI}
		2: return {"pos": Vector3(x0 + u, CURB, z0 + b), "yaw": PI / 2}
		_: return {"pos": Vector3(x0 + a, CURB, z0 + u), "yaw": 0.0}

func random_road_point() -> Vector3:
	var line := randi() % (NB + 1)
	var along := randf() * SIZE
	var lane := 2.5 if randf() < 0.5 else -2.5
	if randf() < 0.5:
		return Vector3(along, 0.0, line * PITCH + ROAD / 2 + lane)
	return Vector3(line * PITCH + ROAD / 2 + lane, 0.0, along)

func is_on_road(p: Vector3) -> bool:
	var fx := fposmod(p.x, PITCH)
	var fz := fposmod(p.z, PITCH)
	return fx < ROAD or fz < ROAD

func set_retro(on: bool) -> void:
	for m in window_mats:
		m.set_shader_parameter("retro", 1.0 if on else 0.0)

# ------------------------------------------------------------------ graffiti
const TAGS := ["RAMP OR DIE", "DEATH TO STAIRS", "SPOKE WAS HERE", "FREE THE RAMPS", "STAIRS INC. SUX",
	"ROLL HARD", "WHEELS > HEELS", "GRIP & RIP", "NO STEP IS SAFE", "PUSH IT", "SIT DOWN. GO FAST.",
	"RIM REAPERS", "CURBS FEAR US", "BARON = SQUARE", "LOS SPOKOS", "ACCESS 4 ALL", "SKATE OR ROLL",
	"KERB KINGS", "2 WHEELS 2 FURIOUS", "LIFT? WE FLY.", "CASTER FLIP CREW", "STAY SEATED STAY SICK"]
const TAG_COLORS := ["ff3d7f", "39ff14", "ffd84a", "7ee0ff", "ff8a1f", "b388ff", "ffffff", "ff4fb0"]
var graffiti_font: SystemFont
var graffiti: Array = []

func _graffiti_font() -> SystemFont:
	if graffiti_font == null:
		graffiti_font = SystemFont.new()
		graffiti_font.font_names = PackedStringArray(["Impact", "Arial Black", "Comic Sans MS", "DejaVu Sans"])
		graffiti_font.font_weight = 900
		graffiti_font.font_italic = true
	return graffiti_font

func _face_xf(r: Rect2, face: int, along: float, y: float) -> Transform3D:
	var cx := r.position.x + r.size.x / 2
	var cz := r.position.y + r.size.y / 2
	match face:
		0: return Transform3D(Basis.IDENTITY, Vector3(cx + along * r.size.x, y, r.end.y + 0.04))
		1: return Transform3D(Basis(Vector3.UP, PI), Vector3(cx + along * r.size.x, y, r.position.y - 0.04))
		2: return Transform3D(Basis(Vector3.UP, PI / 2), Vector3(r.end.x + 0.04, y, cz + along * r.size.y))
		_: return Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(r.position.x - 0.04, y, cz + along * r.size.y))

## A flat textured quad on a building face (posters, student graffiti, shop interiors).
func _wall_quad(xf: Transform3D, size: Vector2, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = m
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

var _poster_tex: Texture2D
func _posters(r: Rect2, skip_face: int) -> void:
	if _poster_tex == null:
		if not ResourceLoader.exists("res://assets/textures/posters.png"):
			return
		_poster_tex = load("res://assets/textures/posters.png")
	var face := rng.randi() % 4
	if face == skip_face:
		face = (face + 1) % 4
	var n := 1 + rng.randi() % 3
	var start := rng.randf_range(-0.35, 0.2)
	for i in n:
		var m := StandardMaterial3D.new()
		m.albedo_texture = _poster_tex
		m.uv1_scale = Vector3(0.5, 0.5, 1)
		var k := rng.randi() % 4
		m.uv1_offset = Vector3(0.5 * (k % 2), 0.5 * floorf(k / 2.0), 0)
		m.roughness = 0.8
		var xf := _face_xf(r, face, start + i * 0.09, CURB + 1.5 + rng.randf() * 0.3)
		xf.origin += xf.basis.z * 0.01
		xf.basis = xf.basis * Basis(Vector3.FORWARD, rng.randf_range(-0.06, 0.06))
		_wall_quad(xf, Vector2(1.2, 1.2), m)

func _graffiti(r: Rect2, skip_face: int) -> void:
	_graffiti_font()
	var faces := [0, 1, 2, 3]
	faces.shuffle()
	var n := 1 + int(rng.randf() < 0.35)
	for face in faces:
		if n <= 0:
			break
		if face == skip_face:
			continue
		n -= 1
		var art: Array = CUSTOM.load_art("graffiti")
		if not art.is_empty() and rng.randf() < 0.5:
			var a: Dictionary = art[rng.randi() % art.size()]
			var gm := StandardMaterial3D.new()
			gm.albedo_texture = a.tex
			gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			gm.alpha_scissor_threshold = 0.3
			var hgt := rng.randf_range(1.4, 2.2)
			var gxf := _face_xf(r, face, (rng.randf() - 0.5) * 0.5, CURB + 1.4 + hgt / 2)
			_wall_quad(gxf, Vector2(hgt * clampf(a.aspect, 0.3, 4.0), hgt), gm)
			continue
		var t := Label3D.new()
		t.text = TAGS[rng.randi() % TAGS.size()]
		if t.text.length() > 11 and rng.randf() < 0.6:
			var sp := t.text.find(" ", 5)
			if sp > 0:
				t.text = t.text.substr(0, sp) + "\n" + t.text.substr(sp + 1)
		t.font = graffiti_font
		t.font_size = 110
		t.pixel_size = 0.011 + rng.randf() * 0.006
		t.outline_size = 22
		var col := Color(TAG_COLORS[rng.randi() % TAG_COLORS.size()])
		t.modulate = col
		t.outline_modulate = Color(TAG_COLORS[rng.randi() % TAG_COLORS.size()]).darkened(0.55)
		t.shaded = true
		t.double_sided = false
		t.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		var cx := r.position.x + r.size.x / 2
		var cz := r.position.y + r.size.y / 2
		var y := CURB + 1.5 + rng.randf() * 1.6
		var along := (rng.randf() - 0.5) * 0.5
		match face:
			0:
				t.position = Vector3(cx + along * r.size.x, y, r.end.y + 0.04)
				t.rotation.y = 0.0
			1:
				t.position = Vector3(cx + along * r.size.x, y, r.position.y - 0.04)
				t.rotation.y = PI
			2:
				t.position = Vector3(r.end.x + 0.04, y, cz + along * r.size.y)
				t.rotation.y = PI / 2
			3:
				t.position = Vector3(r.position.x - 0.04, y, cz + along * r.size.y)
				t.rotation.y = -PI / 2
		t.rotation.z = (rng.randf() - 0.5) * 0.25
		add_child(t)
		graffiti.append(t)

func set_night(f: float) -> void:
	for m in shop_mats:
		m.emission_energy_multiplier = 0.15 + f * 1.3
	for m in window_mats:
		m.set_shader_parameter("night", f)
	for l in lamp_lights:
		l.light_energy = f * 2.2
	lamp_mat.emission_energy_multiplier = 0.3 + f * 4.0
