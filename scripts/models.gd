class_name Models
extends RefCounted
## Builds every 3D model in the game.
## If a Blender export exists at res://assets/models/<name>.glb it is used,
## otherwise a code-built stand-in is made from primitives.
## Naming contract for Blender files: WheelL, WheelR (spinning wheels, pivot at hub, axle along X),
## Seat (empty where the rider sits), LightRed, LightBlue (cop lights), forward = -Z in Godot (+Y in Blender).

static var _mats: Dictionary = {}

static func mat(color: Color, rough: float = 0.75, metal: float = 0.0, emit: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s|%.2f" % [color.to_html(), rough, metal, emit.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = energy
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

static func unique_mat(color: Color, emit: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.5
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = energy
	return m

static func box(p: Node3D, size: Vector3, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi

static func cyl(p: Node3D, radius: float, height: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, seg: int = 16, top: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top < 0.0 else top
	cm.height = height
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi

static func sph(p: Node3D, radius: float, pos: Vector3, m: Material, scl: Vector3 = Vector3.ONE, seg: int = 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = seg
	sm.rings = max(4, int(seg * 0.5))
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	p.add_child(mi)
	return mi

static func torus(p: Node3D, inner: float, outer: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 24
	tm.ring_segments = 6
	mi.mesh = tm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi

static func limb(p: Node3D, a: Vector3, b: Vector3, radius: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = a.distance_to(b) + radius * 2.0
	cm.radial_segments = 10
	cm.rings = 2
	mi.mesh = cm
	mi.material_override = m
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	p.add_child(mi)
	return mi

static func try_glb(name: String) -> Node3D:
	var path := "res://assets/models/%s.glb" % name
	if ResourceLoader.exists(path):
		var ps = load(path)
		if ps is PackedScene:
			return ps.instantiate()
	return null

static func set_shadows(n: Node, on: bool = true) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		set_shadows(c, on)

# ------------------------------------------------------------------ CHAIRS
static func chair(type: String) -> Node3D:
	var t: Dictionary = GameState.TYPES[type]
	var root := try_glb("chair_" + type)
	var wheels: Array = []
	var lights: Array = []
	if root != null:
		for wn in ["WheelL", "WheelR", "CasterL", "CasterR", "CasterBL", "CasterBR"]:
			var w = root.find_child(wn, true, false)
			if w != null:
				var rad: float = 0.42 if t.get("big", false) else (0.3 if wn.begins_with("Wheel") else 0.075)
				if w is MeshInstance3D and w.mesh != null:
					rad = maxf(0.03, w.mesh.get_aabb().size.y * 0.5)     # real wheel size from the model
				wheels.append([w, rad])
		if root.find_child("Seat", true, false) == null:
			var s := Node3D.new()
			s.name = "Seat"
			root.add_child(s)
		for ln in ["LightRed", "LightBlue"]:
			var l = root.find_child(ln, true, false)
			if l is MeshInstance3D:
				var lm := unique_mat(Color.RED if ln == "LightRed" else Color.BLUE, Color.RED if ln == "LightRed" else Color(0.2, 0.4, 1.0), 4.0)
				l.material_override = lm
				lights.append(lm)
		root.set_meta("wheels", wheels)
		root.set_meta("lights", lights)
		return root
	root = Node3D.new()
	var paint: Material
	if type == "gold":
		paint = mat(Color("f5c542"), 0.25, 1.0, Color("6a4a00"), 0.3)
	else:
		paint = mat(t["color"], 0.45, 0.15)
	var dark: Material = mat(t["color"].darkened(0.35), 0.6) if type != "gold" else paint
	paint.resource_name = "Paint"
	if dark != paint:
		dark.resource_name = "PaintDark"
	var metal := mat(Color("b8c0c8"), 0.3, 0.9)
	var tire := mat(Color("161616"), 0.9)
	var black := mat(Color("111111"), 0.8)
	var seat := Node3D.new()
	seat.name = "Seat"
	root.add_child(seat)
	if type == "cart":
		var wire := mat(Color("d0d8e0"), 0.3, 0.9)
		box(root, Vector3(0.62, 0.02, 0.95), Vector3(0, 0.33, 0.0), wire)
		for i in 9:
			var z := -0.47 + i * 0.1175
			box(root, Vector3(0.015, 0.5, 0.015), Vector3(-0.31, 0.58, z), wire)
			box(root, Vector3(0.015, 0.5, 0.015), Vector3(0.31, 0.58, z), wire)
		for i in 6:
			var x := -0.31 + i * 0.124
			box(root, Vector3(0.015, 0.5, 0.015), Vector3(x, 0.58, -0.475), wire)
			box(root, Vector3(0.015, 0.5, 0.015), Vector3(x, 0.58, 0.475), wire)
		for y in [0.58, 0.83]:
			box(root, Vector3(0.64, 0.02, 0.02), Vector3(0, y, -0.475), wire)
			box(root, Vector3(0.64, 0.02, 0.02), Vector3(0, y, 0.475), wire)
			box(root, Vector3(0.02, 0.02, 0.97), Vector3(-0.31, y, 0), wire)
			box(root, Vector3(0.02, 0.02, 0.97), Vector3(0.31, y, 0), wire)
		box(root, Vector3(0.55, 0.03, 0.03), Vector3(0, 0.15, 0.0), wire)
		cyl(root, 0.025, 0.66, Vector3(0, 1.0, 0.6), mat(Color("e33333"), 0.5), Vector3(0, 0, PI / 2))
		box(root, Vector3(0.02, 0.25, 0.02), Vector3(-0.3, 0.9, 0.53), wire, Vector3(0.5, 0, 0))
		box(root, Vector3(0.02, 0.25, 0.02), Vector3(0.3, 0.9, 0.53), wire, Vector3(0.5, 0, 0))
		for p in [Vector3(-0.25, 0.06, -0.38), Vector3(0.25, 0.06, -0.38), Vector3(-0.25, 0.06, 0.38), Vector3(0.25, 0.06, 0.38)]:
			var w := Node3D.new()
			w.position = p
			root.add_child(w)
			cyl(w, 0.06, 0.04, Vector3.ZERO, tire, Vector3(0, 0, PI / 2), 12)
			wheels.append([w, 0.06])
			box(root, Vector3(0.02, 0.2, 0.02), p + Vector3(0, 0.12, 0), wire)
		seat.position = Vector3(0, -0.12, 0.05)
	else:
		var big: bool = t.get("big", false)
		var r := 0.42 if big else 0.3
		var w := 0.12 if big else 0.035
		var wx := 0.42 if big else 0.33
		var rim_col := Color("fff1a8") if type == "gold" else (Color("ff5a5a") if type == "turbo" else (Color("4f8bff") if type == "cop" else Color("b0b8c0")))
		for s in [-1.0, 1.0]:
			var wn := Node3D.new()
			wn.name = "WheelL" if s < 0 else "WheelR"
			wn.position = Vector3(s * wx, r, 0.06)
			root.add_child(wn)
			cyl(wn, r, w, Vector3.ZERO, tire, Vector3(0, 0, PI / 2), 28)
			cyl(wn, r * 0.82, w + 0.004, Vector3.ZERO, mat(Color("2a2a2a"), 0.6), Vector3(0, 0, PI / 2), 28)
			box(wn, Vector3(w * 0.5, r * 1.6, 0.018), Vector3.ZERO, metal)
			box(wn, Vector3(w * 0.5, 0.018, r * 1.6), Vector3.ZERO, metal)
			box(wn, Vector3(w * 0.5, r * 1.6, 0.018), Vector3.ZERO, metal, Vector3(PI / 4, 0, 0))
			box(wn, Vector3(w * 0.5, r * 1.6, 0.018), Vector3.ZERO, metal, Vector3(-PI / 4, 0, 0))
			cyl(wn, 0.035, w + 0.03, Vector3.ZERO, metal, Vector3(0, 0, PI / 2), 12)
			var rm := mat(rim_col, 0.3, 0.8)
			rm.resource_name = "Rim"
			torus(wn, r * 0.8, r * 0.85, Vector3(s * (w / 2 + 0.03), 0, 0), rm, Vector3(0, 0, PI / 2))
			wheels.append([wn, r])
		for s in [-1.0, 1.0]:
			var cn := Node3D.new()
			cn.position = Vector3(s * 0.24, 0.075, -0.38)
			root.add_child(cn)
			cyl(cn, 0.075, 0.03, Vector3.ZERO, tire, Vector3(0, 0, PI / 2), 14)
			wheels.append([cn, 0.075])
			box(root, Vector3(0.025, 0.32, 0.025), Vector3(s * 0.24, 0.28, -0.36), metal)
			box(root, Vector3(0.025, 0.025, 0.62), Vector3(s * 0.235, 0.46, -0.08), metal)
			cyl(root, 0.014, 0.62, Vector3(s * 0.24, 0.72, 0.24), metal)
			cyl(root, 0.02, 0.12, Vector3(s * 0.24, 1.0, 0.31), black, Vector3(PI / 2, 0, 0))
		box(root, Vector3(0.48, 0.06, 0.46), Vector3(0, 0.5, -0.02), paint)
		box(root, Vector3(0.48, 0.42, 0.05), Vector3(0, 0.76, 0.24), dark)
		box(root, Vector3(0.34, 0.025, 0.13), Vector3(0, 0.12, -0.44), mat(Color("333333"), 0.6))
		match type:
			"power":
				box(root, Vector3(0.42, 0.26, 0.32), Vector3(0, 0.27, 0.27), mat(Color("2b2b2b"), 0.6))
				box(root, Vector3(0.03, 0.02, 0.06), Vector3(0.12, 0.42, 0.43), mat(Color("33ff55"), 0.4, 0, Color("33ff55"), 3.0))
				box(root, Vector3(0.07, 0.05, 0.32), Vector3(0.28, 0.66, -0.12), mat(Color("333333"), 0.6))
				sph(root, 0.035, Vector3(0.28, 0.74, -0.24), black)
				cyl(root, 0.01, 0.06, Vector3(0.28, 0.7, -0.24), black)
			"hospital":
				cyl(root, 0.015, 1.4, Vector3(-0.26, 1.02, 0.28), metal)
				box(root, Vector3(0.14, 0.015, 0.015), Vector3(-0.26, 1.72, 0.28), metal)
				box(root, Vector3(0.1, 0.18, 0.04), Vector3(-0.2, 1.6, 0.28), mat(Color(0.65, 0.85, 1.0, 0.7), 0.1))
				box(root, Vector3(0.49, 0.1, 0.051), Vector3(0, 0.88, 0.245), mat(Color("e63946"), 0.6))
			"turbo":
				box(root, Vector3(0.62, 0.025, 0.14), Vector3(0, 1.08, 0.36), mat(Color("b01822"), 0.4))
				box(root, Vector3(0.02, 0.1, 0.02), Vector3(-0.2, 1.02, 0.34), black)
				box(root, Vector3(0.02, 0.1, 0.02), Vector3(0.2, 1.02, 0.34), black)
				box(root, Vector3(0.49, 0.012, 0.1), Vector3(0, 0.535, -0.15), mat(Color("ffb000"), 0.4))
			"monster":
				var cage := mat(Color("1d1d1d"), 0.5, 0.5)
				for s in [-1.0, 1.0]:
					cyl(root, 0.025, 1.0, Vector3(s * 0.48, 0.8, -0.3), cage)
					cyl(root, 0.025, 1.0, Vector3(s * 0.48, 0.8, 0.32), cage)
					cyl(root, 0.025, 0.62, Vector3(s * 0.48, 1.3, 0.01), cage, Vector3(PI / 2, 0, 0))
					sph(root, 0.05, Vector3(s * 0.3, 1.3, -0.32), mat(Color("fffbd0"), 0.2, 0, Color("fffbd0"), 3.0))
				cyl(root, 0.025, 0.96, Vector3(0, 1.3, -0.3), cage, Vector3(0, 0, PI / 2))
				cyl(root, 0.025, 0.96, Vector3(0, 1.3, 0.32), cage, Vector3(0, 0, PI / 2))
			"cop":
				box(root, Vector3(0.485, 0.012, 0.1), Vector3(0, 0.535, -0.02), mat(Color.WHITE, 0.5))
				box(root, Vector3(0.44, 0.05, 0.08), Vector3(0, 1.04, 0.28), black)
				var rm := unique_mat(Color("ff2020"), Color("ff2020"), 4.0)
				var bm := unique_mat(Color("2050ff"), Color("3060ff"), 4.0)
				box(root, Vector3(0.14, 0.07, 0.08), Vector3(-0.12, 1.1, 0.28), rm).name = "LightRed"
				box(root, Vector3(0.14, 0.07, 0.08), Vector3(0.12, 1.1, 0.28), bm).name = "LightBlue"
				lights.append(rm)
				lights.append(bm)
			"gold":
				sph(root, 0.045, Vector3(-0.24, 1.06, 0.24), paint)
				sph(root, 0.045, Vector3(0.24, 1.06, 0.24), paint)
				box(root, Vector3(0.08, 0.2, 0.05), Vector3(0, 1.06, 0.24), paint)
				sph(root, 0.06, Vector3(0, 1.2, 0.24), mat(Color("e63946"), 0.2, 0.3, Color("e63946"), 0.6))
				box(root, Vector3(0.06, 0.05, 0.36), Vector3(-0.27, 0.66, -0.05), paint)
				box(root, Vector3(0.06, 0.05, 0.36), Vector3(0.27, 0.66, -0.05), paint)
	root.set_meta("wheels", wheels)
	root.set_meta("lights", lights)
	set_shadows(root)
	return root

# ------------------------------------------------------------------ RIDERS
const SKINS := ["f6d0b1", "e8b48a", "c68642", "8d5524", "5c3a21", "ffdbac"]
const SHIRTS := ["e63946", "f4a261", "2a9d8f", "e9c46a", "8338ec", "ff006e", "3a86ff", "06d6a0", "ffbe0b", "fb5607"]
const HAIRS := ["2b1d0e", "6b4423", "d4a373", "111111", "b5651d", "e5e5e5", "ff6fb5", "33aadd", "7a1fa2"]
const PANTS := ["2b3a55", "3d3d3d", "5a4632", "24476b", "6b705c"]

const HAIR_STYLES := ["HairShort", "HairSpiky", "HairLong", "HairAfro", "HairMohawk"]
const HATS := ["", "", "", "Cap", "CapBack", "Beanie", "Headphones"]
const DECALS := ["Face", "Print"]

## look: optional overrides {"hair": "HairAfro", "hat": "Beanie", "print": 0..3 or -1, "face": 0..3,
##       "shirt": Color, "pants": Color, "skin": Color, "hair_color": Color}
static func rider(kind: String, look: Dictionary = {}) -> Node3D:
	look = look.duplicate()
	for k in ["skin", "shirt", "pants", "hair_color"]:
		if look.has(k) and look[k] is String:
			look[k] = Color(look[k])
	var root := try_glb("rider")
	var skin: Color = look.get("skin", Color(SKINS.pick_random()))
	var shirt: Color = look.get("shirt", Color("3c8d2f") if kind == "player" else (Color("1d3557") if kind == "cop" else Color(SHIRTS.pick_random())))
	var hair: Color = look.get("hair_color", Color("2b1d0e") if kind == "player" else Color(HAIRS.pick_random()))
	var pants: Color = look.get("pants", Color(PANTS.pick_random()))
	if root != null:
		var hat_col := Color(SHIRTS.pick_random())
		_recolor(root, {"Skin": skin, "Shirt": shirt, "Hair": hair, "Pants": pants, "CapCloth": hat_col, "Beanie": hat_col.darkened(0.2),
			"Shoes": Color(["ffffff", "e8e8ff", "ffd9d9", "d9ffe0"].pick_random())})
		_dress(root, kind, look)
		root.set_meta("rider", true)
		return root
	root = Node3D.new()
	var ms := mat(skin, 0.7)
	var mh := mat(hair, 0.8)
	var mt := mat(shirt, 0.8)
	var mp := mat(pants, 0.85)
	var shoe := mat(Color("1a1a1a"), 0.6)
	var black := mat(Color("0a0a0a"), 0.4)
	for s in [-1.0, 1.0]:
		box(root, Vector3(0.15, 0.13, 0.44), Vector3(s * 0.1, 0.6, -0.12), mp)
		box(root, Vector3(0.12, 0.44, 0.13), Vector3(s * 0.1, 0.37, -0.36), mp)
		box(root, Vector3(0.13, 0.09, 0.23), Vector3(s * 0.1, 0.15, -0.43), shoe)
		limb(root, Vector3(s * 0.21, 1.06, 0.08), Vector3(s * 0.27, 0.83, 0.12), 0.048, mt)
		limb(root, Vector3(s * 0.27, 0.83, 0.12), Vector3(s * 0.31, 0.64, -0.01), 0.042, mt)
		sph(root, 0.05, Vector3(s * 0.31, 0.62, -0.02), ms)
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.18
	cap.height = 0.62
	torso.mesh = cap
	torso.material_override = mt
	torso.position = Vector3(0, 0.88, 0.08)
	torso.scale = Vector3(1, 1, 0.78)
	root.add_child(torso)
	cyl(root, 0.05, 0.1, Vector3(0, 1.2, 0.06), ms)
	sph(root, 0.13, Vector3(0, 1.33, 0.04), ms, Vector3(1, 1.05, 1))
	sph(root, 0.138, Vector3(0, 1.36, 0.075), mh, Vector3(1, 0.92, 1))
	for s in [-1.0, 1.0]:
		sph(root, 0.018, Vector3(s * 0.045, 1.35, -0.086), black, Vector3.ONE, 8)
	box(root, Vector3(0.05, 0.012, 0.01), Vector3(0, 1.275, -0.124), mat(Color("7a2e2e"), 0.6))
	var shades := box(root, Vector3(0.2, 0.045, 0.02), Vector3(0, 1.35, -0.125), black)
	shades.name = "Shades"
	var cop_hat := Node3D.new()
	cop_hat.name = "CopHat"
	root.add_child(cop_hat)
	cyl(cop_hat, 0.145, 0.07, Vector3(0, 1.46, 0.04), mat(Color("14213d"), 0.6))
	box(cop_hat, Vector3(0.2, 0.015, 0.1), Vector3(0, 1.43, -0.1), mat(Color("0d1626"), 0.4))
	sph(cop_hat, 0.02, Vector3(0, 1.47, -0.105), mat(Color("ffd84a"), 0.3, 0.8), Vector3(1, 1, 0.5))
	var capn := Node3D.new()
	capn.name = "Cap"
	root.add_child(capn)
	var cc := mat(Color(SHIRTS.pick_random()), 0.8)
	sph(capn, 0.142, Vector3(0, 1.43, 0.05), cc, Vector3(1, 0.55, 1))
	box(capn, Vector3(0.17, 0.015, 0.13), Vector3(0, 1.41, -0.1), cc)
	var crown := cyl(root, 0.1, 0.09, Vector3(0, 1.52, 0.05), mat(Color("ffd700"), 0.2, 1.0, Color("6a4a00"), 0.6), Vector3.ZERO, 7, 0.12)
	crown.name = "Crown"
	var pizza := Node3D.new()
	pizza.name = "PizzaBox"
	root.add_child(pizza)
	box(pizza, Vector3(0.38, 0.06, 0.38), Vector3(0, 0.71, -0.2), mat(Color("c9a06a"), 0.9))
	box(pizza, Vector3(0.2, 0.005, 0.12), Vector3(0, 0.743, -0.2), mat(Color("d9452b"), 0.8))
	_extras(root, kind)
	set_shadows(root)
	return root

## Picks hair, hat, face and shirt print for the Blender rider.
static func _dress(root: Node3D, kind: String, look: Dictionary) -> void:
	var hair_style: String = look.get("hair", "HairSpiky" if kind == "player" else ("HairShort" if kind == "cop" else HAIR_STYLES.pick_random()))
	var hat: String = look.get("hat", "" if kind != "npc" else HATS.pick_random())
	if kind == "cop":
		hat = "CopHat"
	if hat in ["Cap", "CapBack", "Beanie", "CopHat"] and hair_style in ["HairSpiky", "HairAfro", "HairMohawk"]:
		hair_style = "HairShort"
	for h in HAIR_STYLES:
		var n = root.find_child(h, true, false)
		if n != null:
			n.visible = h == hair_style
	var shades: bool = look.get("shades", kind == "player")
	for n in ["Shades", "CopHat", "CopBadge", "Cap", "CapBack", "Beanie", "Headphones", "Crown", "PizzaBox"]:
		var c = root.find_child(n, true, false)
		if c != null:
			c.visible = n == hat or (n == "Shades" and shades) or (n == "CopBadge" and kind == "cop")
	var face: int = int(look.get("face", 0 if kind == "player" else randi() % 4))
	var custom: Array = preload("res://scripts/custom.gd").load_art("prints")
	var npc_print := -1 if kind == "cop" or randf() < 0.3 else randi() % 4
	if kind == "npc" and not custom.is_empty() and randf() < 0.3:
		npc_print = 100 + randi() % custom.size()
	var pr: int = int(look.get("print", 0 if kind == "player" else npc_print))
	var pn = root.find_child("Print", true, false)
	if pn != null:
		pn.visible = pr >= 0
	var ctex: Texture2D = null
	if pr >= 100 and pr - 100 < custom.size():
		ctex = custom[pr - 100].tex
	_decal_mats(root, face, clampi(pr, 0, 3), ctex)

static func _decal_mats(n: Node, face: int, pr: int, custom_print: Texture2D = null) -> void:
	if n is MeshInstance3D and n.mesh != null:
		for i in n.mesh.get_surface_count():
			var m = n.get_surface_override_material(i)
			if m == null:
				m = n.mesh.surface_get_material(i)
			if m is StandardMaterial3D and m.resource_name in DECALS:
				var nm: StandardMaterial3D = m.duplicate()
				nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				nm.alpha_scissor_threshold = 0.5
				var q := face if m.resource_name == "Face" else pr
				nm.uv1_offset = Vector3(0.5 * (q % 2), 0.5 * floorf(q / 2.0), 0)
				if m.resource_name == "Print" and custom_print != null:
					# a student's own PNG covers the whole print area
					nm.albedo_texture = custom_print
					nm.uv1_scale = Vector3(2, 2, 1)
					nm.uv1_offset = Vector3.ZERO
				nm.render_priority = 1
				n.set_surface_override_material(i, nm)
	for c in n.get_children():
		_decal_mats(c, face, pr, custom_print)

static func _extras(root: Node3D, kind: String) -> void:
	for n in ["Shades", "CopHat", "Cap", "Crown", "PizzaBox"]:
		var c = root.find_child(n, true, false)
		if c == null:
			continue
		match n:
			"Shades": c.visible = kind == "player"
			"CopHat": c.visible = kind == "cop"
			"Cap": c.visible = kind == "npc" and randf() < 0.3
			_: c.visible = false

static func _recolor(n: Node, colors: Dictionary) -> void:
	if n is MeshInstance3D and n.mesh != null:
		for i in n.mesh.get_surface_count():
			var m = n.mesh.surface_get_material(i)
			if m != null and colors.has(m.resource_name):
				var nm: StandardMaterial3D = m.duplicate()
				nm.albedo_color = colors[m.resource_name]
				n.set_surface_override_material(i, nm)
	for c in n.get_children():
		_recolor(c, colors)

# ------------------------------------------------------------------ CARS
const CAR_COLORS := ["e63946", "f1faee", "457b9d", "ffb703", "2a9d8f", "8d99ae", "222222", "ff7f50", "6a4c93", "b5172c"]

static func car(taxi: bool) -> Node3D:
	var kind: String = "taxi" if taxi else ["sedan", "sedan", "hatch", "hatch", "van"].pick_random()
	var root := try_glb("car_" + kind)
	if root == null and not taxi:
		root = try_glb("car_sedan")
	var wheels: Array = []
	var tail: StandardMaterial3D = unique_mat(Color("6a1010"), Color("ff2020"), 0.2)
	if root != null:
		for wn in ["WheelFL", "WheelFR", "WheelBL", "WheelBR"]:
			var w = root.find_child(wn, true, false)
			if w != null:
				wheels.append([w, 0.34])
		var tl = root.find_child("Taillights", true, false)
		if tl is MeshInstance3D:
			tl.material_override = tail
		if not taxi:
			_recolor(root, {"Paint": Color(CAR_COLORS.pick_random())})
		root.set_meta("wheels", wheels)
		root.set_meta("tail", tail)
		return root
	root = Node3D.new()
	var paint := mat(Color("ffcc00") if taxi else Color(CAR_COLORS.pick_random()), 0.28, 0.35)
	var glass := mat(Color("1c2836"), 0.08, 0.6)
	var dark := mat(Color("2a2a2a"), 0.7)
	box(root, Vector3(1.8, 0.6, 4.3), Vector3(0, 0.58, 0), paint)
	box(root, Vector3(1.78, 0.12, 4.0), Vector3(0, 0.94, 0.05), paint)
	box(root, Vector3(1.6, 0.5, 2.0), Vector3(0, 1.22, 0.3), glass)
	box(root, Vector3(1.62, 0.07, 1.75), Vector3(0, 1.5, 0.35), paint)
	box(root, Vector3(0.08, 0.5, 0.1), Vector3(-0.78, 1.22, -0.68), paint)
	box(root, Vector3(0.08, 0.5, 0.1), Vector3(0.78, 1.22, -0.68), paint)
	box(root, Vector3(1.84, 0.22, 0.14), Vector3(0, 0.42, -2.16), dark)
	box(root, Vector3(1.84, 0.22, 0.14), Vector3(0, 0.42, 2.16), dark)
	var hl := mat(Color("fff7c2"), 0.2, 0.0, Color("fff2b0"), 2.5)
	box(root, Vector3(0.36, 0.12, 0.05), Vector3(-0.6, 0.72, -2.16), hl)
	box(root, Vector3(0.36, 0.12, 0.05), Vector3(0.6, 0.72, -2.16), hl)
	box(root, Vector3(0.36, 0.12, 0.05), Vector3(-0.6, 0.76, 2.16), tail)
	box(root, Vector3(0.36, 0.12, 0.05), Vector3(0.6, 0.76, 2.16), tail)
	for p in [Vector3(-0.86, 0.34, -1.35), Vector3(0.86, 0.34, -1.35), Vector3(-0.86, 0.34, 1.35), Vector3(0.86, 0.34, 1.35)]:
		var w := Node3D.new()
		w.position = p
		root.add_child(w)
		cyl(w, 0.34, 0.24, Vector3.ZERO, mat(Color("141414"), 0.9), Vector3(0, 0, PI / 2), 20)
		cyl(w, 0.2, 0.25, Vector3.ZERO, mat(Color("c9ced3"), 0.3, 0.9), Vector3(0, 0, PI / 2), 12)
		wheels.append([w, 0.34])
	if taxi:
		box(root, Vector3(0.5, 0.16, 0.25), Vector3(0, 1.62, 0.35), mat(Color("ffe680"), 0.4, 0, Color("ffe680"), 1.5))
		box(root, Vector3(1.81, 0.1, 4.31), Vector3(0, 0.72, 0), mat(Color("222222"), 0.5))
	root.set_meta("wheels", wheels)
	root.set_meta("tail", tail)
	set_shadows(root)
	return root

# ------------------------------------------------------------------ PROPS
static func tree(size: float) -> Node3D:
	var root := try_glb("tree_tall" if randf() < 0.35 else "tree")
	if root != null:
		root.scale = Vector3.ONE * size
		return root
	root = Node3D.new()
	cyl(root, 0.18 * size, 2.6 * size, Vector3(0, 1.3 * size, 0), mat(Color("6b4a2f"), 0.9), Vector3.ZERO, 8, 0.12 * size)
	var g1 := mat(Color("3f7f34"), 0.85)
	var g2 := mat(Color("5fa449"), 0.85)
	sph(root, 1.6 * size, Vector3(0, 3.3 * size, 0), g1, Vector3(1, 0.85, 1), 8)
	sph(root, 1.1 * size, Vector3(-0.4 * size, 4.1 * size, -0.3 * size), g2, Vector3(1, 0.85, 1), 8)
	sph(root, 0.9 * size, Vector3(0.6 * size, 3.8 * size, 0.5 * size), g2, Vector3(1, 0.85, 1), 8)
	set_shadows(root)
	return root

static func lamp() -> Node3D:
	var root := try_glb("lamp")
	if root != null:
		return root
	root = Node3D.new()
	var pole := mat(Color("3a3f45"), 0.5, 0.6)
	cyl(root, 0.06, 5.2, Vector3(0, 2.6, 0), pole, Vector3.ZERO, 8, 0.045)
	box(root, Vector3(0.06, 0.06, 1.3), Vector3(0, 5.15, -0.6), pole)
	var head := box(root, Vector3(0.3, 0.1, 0.45), Vector3(0, 5.08, -1.2), mat(Color("fff4c4"), 0.3, 0, Color("ffe8a8"), 2.0))
	head.name = "Head"
	set_shadows(root)
	return root

static func bin_model() -> Node3D:
	var g := try_glb("bin")
	if g != null:
		return g
	var root := Node3D.new()
	cyl(root, 0.3, 0.85, Vector3(0, 0.425, 0), mat(Color("5b7a5a"), 0.6, 0.3), Vector3.ZERO, 14, 0.33)
	cyl(root, 0.35, 0.06, Vector3(0, 0.87, 0), mat(Color("3f5a3e"), 0.6, 0.3), Vector3.ZERO, 14)
	set_shadows(root)
	return root

static func hydrant_model() -> Node3D:
	var g := try_glb("hydrant")
	if g != null:
		return g
	var root := Node3D.new()
	var red := mat(Color("d62828"), 0.35, 0.2)
	cyl(root, 0.16, 0.6, Vector3(0, 0.3, 0), red, Vector3.ZERO, 12)
	sph(root, 0.17, Vector3(0, 0.62, 0), red, Vector3(1, 0.8, 1), 10)
	cyl(root, 0.07, 0.46, Vector3(0, 0.4, 0), red, Vector3(0, 0, PI / 2), 8)
	cyl(root, 0.06, 0.08, Vector3(0, 0.78, 0), mat(Color("ffd84a"), 0.4, 0.5), Vector3.ZERO, 8)
	set_shadows(root)
	return root

static func stand_model() -> Node3D:
	var root := Node3D.new()
	var wood := mat(Color("8a5a36"), 0.85)
	box(root, Vector3(1.8, 0.08, 1.0), Vector3(0, 0.85, 0), wood)
	for x in [-0.85, 0.85]:
		for z in [-0.45, 0.45]:
			box(root, Vector3(0.08, 0.85, 0.08), Vector3(x, 0.42, z), wood)
		box(root, Vector3(0.06, 1.2, 0.06), Vector3(x, 1.5, 0.48), wood)
	for i in 6:
		box(root, Vector3(1.9, 0.03, 0.22), Vector3(0, 2.1 - i * 0.03, 0.5 - i * 0.21), mat(Color.WHITE if i % 2 == 0 else Color("e63946"), 0.8), Vector3(-0.15, 0, 0))
	set_shadows(root)
	return root

static func bench() -> Node3D:
	var g := try_glb("bench")
	if g != null:
		set_shadows(g)
		return g
	var root := Node3D.new()
	var wood := mat(Color("9b6a3f"), 0.8)
	var iron := mat(Color("2b2b2b"), 0.5, 0.7)
	for i in 3:
		box(root, Vector3(1.8, 0.04, 0.12), Vector3(0, 0.45, -0.15 + i * 0.14), wood)
	box(root, Vector3(1.8, 0.3, 0.04), Vector3(0, 0.7, 0.22), wood, Vector3(-0.15, 0, 0))
	for x in [-0.8, 0.8]:
		box(root, Vector3(0.05, 0.45, 0.45), Vector3(x, 0.22, 0.03), iron)
	set_shadows(root)
	return root

# ------------------------------------------------------------------ PIMP MY CHAIR styling
static var rainbow_mat: StandardMaterial3D

static func paint_mat(id: String, dark: bool = false) -> StandardMaterial3D:
	if id == "rainbow":
		if rainbow_mat == null:
			rainbow_mat = StandardMaterial3D.new()
			rainbow_mat.roughness = 0.25
			rainbow_mat.metallic = 0.3
			rainbow_mat.emission_enabled = true
			rainbow_mat.emission_energy_multiplier = 0.4
		return rainbow_mat
	var c: Color = {"pink": Color("ff3fa4"), "chrome": Color("e8eef4"), "black": Color("1a1a22")}[id]
	if dark:
		c = c.darkened(0.3)
	var m := mat(c, 0.06 if id == "chrome" else 0.28, 1.0 if id == "chrome" else 0.25)
	if id == "black":
		m.clearcoat_enabled = true
		m.clearcoat = 1.0
	return m

static func apply_style(model: Node3D, style: Dictionary) -> void:
	var paint := ""
	var rims := false
	var dice := false
	if not style.is_empty():
		paint = style.paint
		rims = style.rims
		dice = style.dice
	_style_node(model, paint, rims)
	var d = model.find_child("Dice", false, false)
	if d != null:
		d.queue_free()
	if dice:
		var dn := Node3D.new()
		dn.name = "Dice"
		dn.position = Vector3(0.18, 0.95, 0.34)
		model.add_child(dn)
		box(dn, Vector3(0.006, 0.16, 0.006), Vector3(0, -0.08, 0), mat(Color("222222")))
		box(dn, Vector3(0.06, 0.06, 0.06), Vector3(-0.02, -0.18, 0), mat(Color("ff3fa4"), 1.0), Vector3(0.4, 0.3, 0.2))
		box(dn, Vector3(0.06, 0.06, 0.06), Vector3(0.03, -0.2, 0.02), mat(Color.WHITE, 1.0), Vector3(-0.3, 0.6, 0.1))

static func _style_node(n: Node, paint: String, rims: bool) -> void:
	if n.has_meta("rider"):
		return                     # never repaint the person sitting in the chair
	if n is MeshInstance3D and n.mesh != null:
		if n.material_override != null or n.has_meta("orig_override"):
			if not n.has_meta("orig_override"):
				n.set_meta("orig_override", n.material_override)
			var o: Material = n.get_meta("orig_override")
			n.material_override = _pick(o, paint, rims)
		else:
			for i in n.mesh.get_surface_count():
				var m = n.mesh.surface_get_material(i)
				if m == null:
					continue
				var p := _pick(m, paint, rims)
				n.set_surface_override_material(i, null if p == m else p)
	for c in n.get_children():
		_style_node(c, paint, rims)

static func _pick(m: Material, paint: String, rims: bool) -> Material:
	if m == null:
		return m
	var nm := m.resource_name
	if paint != "" and (nm == "Paint" or nm.begins_with("Paint.")):
		return paint_mat(paint)
	if paint != "" and nm.begins_with("PaintDark"):
		return paint_mat(paint, true)
	if rims and (nm == "Rim" or nm.begins_with("Rim.")):
		return mat(Color("ffd700"), 0.15, 1.0, Color("6a4a00"), 0.4)
	return m

static func pigeon() -> Node3D:
	var root := Node3D.new()
	var grey := mat(Color("8d929b"), 0.9)
	sph(root, 0.12, Vector3(0, 0.13, 0), grey, Vector3(0.8, 0.75, 1.15), 10)
	sph(root, 0.065, Vector3(0, 0.25, -0.12), mat(Color("5d6b7a"), 0.8), Vector3.ONE, 8)
	box(root, Vector3(0.025, 0.02, 0.06), Vector3(0, 0.24, -0.2), mat(Color("e0a030"), 0.6))
	box(root, Vector3(0.1, 0.02, 0.12), Vector3(0, 0.14, 0.16), grey)
	for s in [-1.0, 1.0]:
		var w := Node3D.new()
		w.name = "WingL" if s < 0 else "WingR"
		w.position = Vector3(s * 0.07, 0.17, 0.0)
		root.add_child(w)
		box(w, Vector3(0.2, 0.015, 0.14), Vector3(s * 0.1, 0, 0.02), mat(Color("7a808a"), 0.9))
	set_shadows(root)
	return root

# ------------------------------------------------------------------ retro helpers
static func set_layers(n: Node, layers: int) -> void:
	if n is VisualInstance3D and not n is Decal:
		n.layers = layers
	for c in n.get_children():
		set_layers(c, layers)

static var _blob_tex: GradientTexture2D
## Early-2000s style round "blob" shadow, projected down onto the ground.
## Only touches render layer 1, so it never darkens the chair or rider (layer 2).
static func blob_shadow(size: float) -> Decal:
	if _blob_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.78))
		g.set_color(1, Color(0, 0, 0, 0.0))
		g.add_point(0.55, Color(0, 0, 0, 0.6))
		_blob_tex = GradientTexture2D.new()
		_blob_tex.gradient = g
		_blob_tex.fill = GradientTexture2D.FILL_RADIAL
		_blob_tex.fill_from = Vector2(0.5, 0.5)
		_blob_tex.fill_to = Vector2(1.0, 0.5)
		_blob_tex.width = 64
		_blob_tex.height = 64
	var d := Decal.new()
	d.texture_albedo = _blob_tex
	d.size = Vector3(size, 3.2, size * 1.15)
	d.position = Vector3(0, -0.6, 0)
	d.cull_mask = 1
	d.normal_fade = 0.5
	d.upper_fade = 0.05
	d.lower_fade = 0.25
	d.distance_fade_enabled = true
	d.distance_fade_begin = 45.0
	d.modulate = Color(1, 1, 1, 0.9)
	d.distance_fade_length = 15.0
	d.visible = GameState.retro
	d.add_to_group("blob")
	return d

## Switch every standard material under n to per-vertex (Gouraud) lighting, PS2 style.
static func vertex_light(n: Node, on: bool, seen: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		if mi.material_override is BaseMaterial3D:
			_vl(mi.material_override, on, seen)
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(i)
				if m == null:
					m = mi.mesh.surface_get_material(i)
				if m is BaseMaterial3D:
					_vl(m, on, seen)
	for c in n.get_children():
		vertex_light(c, on, seen)

static func _vl(m: BaseMaterial3D, on: bool, seen: Dictionary) -> void:
	if seen.has(m):
		return
	seen[m] = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS if on else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# big textured ground/road surfaces stay per-pixel so street-lamp pools still show at night
	if m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or m.albedo_texture != null:
		return
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX if on else BaseMaterial3D.SHADING_MODE_PER_PIXEL

# ------------------------------------------------------------------ street dressing (Blender GLBs)
## name: dumpster, newsbox, vending, ledge, handrail, picnic, cone, barrier, fence.
## Returns null when the GLB is missing so the city can skip it.
static func street(name: String) -> Node3D:
	var g := try_glb(name)
	if g == null:
		return null
	_fix_alpha(g)
	set_shadows(g)
	return g

static func _fix_alpha(n: Node) -> void:
	if n is MeshInstance3D and n.mesh != null:
		for i in n.mesh.get_surface_count():
			var m = n.mesh.surface_get_material(i)
			if m is StandardMaterial3D and m.resource_name == "Chainlink":
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.4
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for c in n.get_children():
		_fix_alpha(c)
