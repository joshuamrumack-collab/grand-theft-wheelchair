# Grand Theft Wheelchair - riders in an early-2000s skate-game style (THPS3/4 era):
# one organic low-poly body (skin modifier), painted cloth textures, face + shirt-print decals,
# swappable hair styles and hats. Run inside Blender:
#   exec(open(os.path.expanduser(r"E:\Godot\GrandTheftWheelchair\tools\gtw_riders.py")).read())
import bpy, bmesh, math, os
from mathutils import Vector, Matrix
exec(open(os.path.expanduser(r"E:\Godot\GrandTheftWheelchair\tools\gtw_blender_lib.py")).read(), globals())
TEX = os.path.expanduser(r"E:\Godot\GrandTheftWheelchair\assets\textures")

def tmat(name, tex, color="ffffff", rough=0.8, alpha=False, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    c = hexc(color)
    if tex:
        img = bpy.data.images.load(os.path.join(TEX, tex + ".png"), check_existing=True)
        it = nt.nodes.new("ShaderNodeTexImage")
        it.image = img
        if color.lower() != "ffffff":
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1.0
            nt.links.new(it.outputs["Color"], mix.inputs[6])
            mix.inputs[7].default_value = (*c, 1)
            nt.links.new(mix.outputs[2], b.inputs["Base Color"])
        else:
            nt.links.new(it.outputs["Color"], b.inputs["Base Color"])
        if alpha:
            nt.links.new(it.outputs["Alpha"], b.inputs["Alpha"])
            try:
                m.surface_render_method = "DITHERED"
            except Exception:
                pass
    else:
        b.inputs["Base Color"].default_value = (*c, 1)
    m.diffuse_color = (*c, 1)
    return m

def G(v):  # blender -> godot
    return Vector((v.x, v.z, -v.y))

BONE_FOR_NODE = {}   # node index -> bone name (bone is named after the node at its tail)

def skin_mesh(name, nodes, edges, sub=1, names=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata([g(*p) for p, r in nodes], edges, [])
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    md = o.modifiers.new("Skin", "SKIN")
    md.use_smooth_shade = True
    md.branch_smoothing = 0.6
    sv = o.data.skin_vertices[0].data
    for i, (p, r) in enumerate(nodes):
        sv[i].radius = r if isinstance(r, tuple) else (r, r)
    sv[0].use_root = True
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    arm = None
    if names:
        # the skin modifier can grow a matching skeleton with vertex weights: one bone per edge
        bpy.ops.object.skin_armature_create(modifier="Skin")
        arm = [a for a in bpy.data.objects if a.type == "ARMATURE"][-1]
        arm.name = "Rig"
        arm.data.name = "Rig"
        bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
    s = o.modifiers.new("Sub", "SUBSURF")
    s.levels = sub
    s.render_levels = sub
    # keep the Armature modifier last, apply skin + subdivision
    for m in list(o.modifiers):
        if m.type == "ARMATURE":
            bpy.ops.object.modifier_move_to_index(modifier=m.name, index=len(o.modifiers) - 1)
    for m in list(o.modifiers):
        if m.type != "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=m.name)
    if arm is not None:
        # name bones after the node at their tail: Spine, Chest, ..., Forearm_L
        ren = {}
        for b in arm.data.bones:
            tail = arm.matrix_world @ b.tail_local
            best, bd = None, 1e9
            for i, (p, r) in enumerate(nodes):
                d = (g(*p) - tail).length
                if d < bd:
                    best, bd = i, d
            ren[b.name] = names[best]
        old_groups = {vg.name: vg for vg in o.vertex_groups}
        for old, new in ren.items():
            arm.data.bones[old].name = new
            if old in old_groups:
                old_groups[old].name = new
    return o, arm

def weight_all(o, bone):
    vg = o.vertex_groups.get(bone) or o.vertex_groups.new(name=bone)
    vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")

def bone_parent(o, arm, bone):
    b = arm.data.bones[bone]
    mw = o.matrix_world.copy()
    o.parent = arm
    o.parent_type = "BONE"
    o.parent_bone = bone
    o.matrix_world = mw

def uv_cube(o, scale=1.0):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=scale)
    bpy.ops.object.mode_set(mode="OBJECT")

def decal_shell(src, name, m, sel, uvf, push=0.004):
    """Copy the faces of src picked by sel(center_godot, normal_godot), push them out a hair,
    and give them a front-projected UV from uvf(godot_pos) -> (u, v)."""
    bm = bmesh.new()
    bm.from_mesh(src.data)
    bm.transform(src.matrix_world)
    keep = [f for f in bm.faces if sel(G(f.calc_center_median()), G(f.normal))]
    drop = [f for f in bm.faces if f not in set(keep)]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    for v in bm.verts:
        v.co += v.normal * push
    uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops:
            l[uvl].uv = uvf(G(l.vert.co))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.clear()
    me.materials.append(m)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    for vg in src.vertex_groups:
        o.vertex_groups.new(name=vg.name)
    return o

clear()
for im in list(bpy.data.images):
    if im.users == 0:
        bpy.data.images.remove(im)
M = {
    "Skin": tmat("Skin", "skin", "ffffff", 0.6),
    "Shirt": tmat("Shirt", "cloth_shirt", "ffffff", 0.9),
    "Pants": tmat("Pants", "cloth_denim", "ffffff", 0.9),
    "Hair": tmat("Hair", "hair", "ffffff", 0.7),
    "Shoes": tmat("Shoes", "shoes", "ffffff", 0.7),
    "Sole": tmat("Sole", None, "f0eee6", 0.6),
    "Belt": tmat("Belt", None, "1a1a1a", 0.4),
    "Face": tmat("Face", "faces", "ffffff", 0.6, True),
    "Print": tmat("Print", "prints", "ffffff", 0.8, True),
}
objs = []

# ---------------- BODY (seated, facing -Z in Godot)
nodes = [
    ((0, 0.63, 0.07), (0.16, 0.13)),     # 0 pelvis
    ((0, 0.80, 0.085), (0.15, 0.11)),    # 1 belly
    ((0, 0.97, 0.08), (0.2, 0.13)),      # 2 chest
    ((0, 1.11, 0.065), (0.12, 0.09)),    # 3 upper chest / collar
    ((0, 1.22, 0.05), (0.05, 0.05)),     # 4 neck
]
edges = [(0, 1), (1, 2), (2, 3), (3, 4)]
for s in (-1, 1):
    b = len(nodes)
    nodes += [
        ((s * 0.10, 0.62, 0.03), (0.095, 0.095)),   # hip
        ((s * 0.115, 0.61, -0.32), (0.085, 0.085)), # knee
        ((s * 0.115, 0.24, -0.39), (0.078, 0.078)), # ankle (baggy pants)
        ((s * 0.2, 1.07, 0.07), (0.075, 0.075)),    # shoulder
        ((s * 0.255, 0.86, 0.12), (0.058, 0.058)),  # elbow (sleeve)
        ((s * 0.30, 0.68, 0.0), (0.04, 0.04)),      # wrist
    ]
    edges += [(0, b), (b, b + 1), (b + 1, b + 2), (3, b + 3), (b + 3, b + 4), (b + 4, b + 5)]
NAMES = ["Root", "Spine", "Chest", "Collar", "Neck"]
for side in ("L", "R"):
    NAMES += [n + "_" + side for n in ("Hip", "Thigh", "Shin", "Clavicle", "UpperArm", "Forearm")]
body, rig = skin_mesh("Body", nodes, edges, 1, NAMES)
body.data.materials.append(M["Shirt"])
body.data.materials.append(M["Pants"])
body.data.materials.append(M["Skin"])
body.data.materials.append(M["Belt"])
for p in body.data.polygons:
    c = G(body.matrix_world @ p.center)
    idx = 0
    if c.y < 0.70:
        idx = 1
    if abs(c.x) > 0.2 and c.y < 0.84 and c.y > 0.62:
        idx = 2                      # forearms
    if c.y > 1.16:
        idx = 2                      # neck
    p.material_index = idx
uv_cube(body, 0.5)
objs.append(body)

# hands (mitt + thumb, gripping the push rims)
for s in (-1, 1):
    h = sph("hand%d" % s, 0.05, (s * 0.31, 0.64, -0.03), M["Skin"], (0.75, 1.05, 1.2), 12, 8)
    t = sph("thumb%d" % s, 0.022, (s * 0.285, 0.67, -0.07), M["Skin"], (1, 1, 1.4), 8, 6)
    for o in (h, t):
        weight_all(o, "Forearm_" + ("L" if s < 0 else "R"))
    objs += [h, t]

# skate shoes: chunky upper + white vulc sole + tongue
for s in (-1, 1):
    up = box("shoe%d" % s, (0.13, 0.11, 0.27), (s * 0.115, 0.165, -0.45), M["Shoes"], 0.04)
    uv_cube(up, 0.3)
    so = box("sole%d" % s, (0.142, 0.045, 0.29), (s * 0.115, 0.115, -0.452), M["Sole"], 0.015)
    tg = box("tongue%d" % s, (0.08, 0.06, 0.06), (s * 0.115, 0.235, -0.42), M["Shoes"], 0.02, (0.4, 0, 0))
    for o in (up, so, tg):
        bpy.context.view_layer.objects.active = o
        for md in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=md.name)
        weight_all(o, "Shin_" + ("L" if s < 0 else "R"))
    objs += [up, so, tg]

# ---------------- HEAD
head = sph("Head", 0.125, (0, 1.335, 0.04), M["Skin"], (0.95, 1.1, 1.02), 20, 14)
bpy.context.view_layer.objects.active = head
for m in list(head.modifiers):
    bpy.ops.object.modifier_apply(modifier=m.name)
bpy.ops.object.select_all(action="DESELECT")
head.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# chin / jaw: pull the lower front a little forward and down
for v in head.data.vertices:
    gp = G(v.co)
    if gp.y < 1.29 and gp.z < 0.06:
        k = (1.29 - gp.y) / 0.1
        v.co.y += 0.012 * k          # forward (Godot -Z = Blender +Y)
uv_cube(head, 0.3)
weight_all(head, "Neck")
objs.append(head)
nose = sph("nose", 0.02, (0, 1.315, -0.088), M["Skin"], (0.9, 1.1, 1.2), 10, 6)
weight_all(nose, "Neck")
objs.append(nose)
for s in (-1, 1):
    ear = sph("ear%d" % s, 0.03, (s * 0.118, 1.33, 0.05), M["Skin"], (0.5, 1.1, 0.9), 10, 6)
    weight_all(ear, "Neck")
    objs.append(ear)

# face decal: quadrant 0 of the 2x2 atlas, the game shifts uv to pick a face
FT, FH = 1.447, 0.231
face = decal_shell(head, "FaceDecal", M["Face"],
    lambda c, n: n.z < -0.3 and FT - FH < c.y < FT and abs(c.x) < FH / 2,
    lambda p: ((FH / 2 - p.x) / FH * 0.5, 0.5 + (p.y - (FT - FH)) / FH * 0.5), 0.003)
objs.append(face)
# shirt print: centred on the chest
PB, PS = 0.86, 0.21
pr = decal_shell(body, "Print", M["Print"],
    lambda c, n: n.z < -0.45 and PB + 0.01 < c.y < PB + PS - 0.01 and abs(c.x) < PS / 2 - 0.01,
    lambda p: ((PS / 2 - p.x) / PS * 0.5, 0.5 + (p.y - PB) / PS * 0.5), 0.004)

# join everything onto the body without applying its Armature modifier
for m in list(body.modifiers):
    body.modifiers.remove(m)
for o in objs:
    if o is not body:
        bpy.context.view_layer.objects.active = o
        for md in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=md.name)
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body_all = bpy.context.active_object
body_all.name = "Body"
am = body_all.modifiers.new("Rig", "ARMATURE")
am.object = rig
body_all.parent = rig
pr.parent = rig
am2 = pr.modifiers.new("Rig", "ARMATURE")
am2.object = rig

# ---------------- HAIR STYLES (each its own object, the game shows one)
def hair_cap(name, cut, scl=1.07, extra=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=14, radius=0.125)
    bmesh.ops.scale(bm, vec=Vector((0.95 * scl, 1.02 * scl, 1.1 * scl)), verts=bm.verts)
    bmesh.ops.translate(bm, vec=g(0, 1.335, 0.04), verts=bm.verts)
    drop = [f for f in bm.faces if not cut(G(f.calc_center_median()))]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    o = _mesh_obj(name, bm)
    o.data.materials.append(M["Hair"])
    for p in o.data.polygons:
        p.use_smooth = True
    sd = o.modifiers.new("Solid", "SOLIDIFY")
    sd.thickness = 0.012
    uv_cube(o, 0.3)
    parts = [o]
    if extra:
        parts += extra()
    return join(parts, name)

def short_cut(c):
    front = c.z < -0.04
    return c.y > (1.40 if front else 1.27) and not (abs(c.x) > 0.09 and c.y < 1.34 and c.z > -0.03 and c.z < 0.06)

hair_cap("HairShort", short_cut)
def spikes():
    out = []
    for i in range(9):
        a = i / 9 * math.tau
        x = math.cos(a) * 0.07; z = 0.04 + math.sin(a) * 0.07
        out.append(cyl("spk%d" % i, 0.035, 0.09, (x, 1.47, z), M["Hair"], "Y", 6, 0.0, 0.002))
    out.append(cyl("spkc", 0.04, 0.11, (0, 1.49, 0.04), M["Hair"], "Y", 6, 0.0, 0.002))
    return out
hair_cap("HairSpiky", short_cut, 1.06, spikes)
def pony():
    return [sph("pony", 0.05, (0, 1.3, 0.17), M["Hair"], (0.9, 2.0, 0.9), 10, 8),
            sph("ptie", 0.03, (0, 1.37, 0.155), mat("Tie", "ff4fb0", 0.5), (1, 0.6, 1), 8, 6)]
hair_cap("HairLong", lambda c: c.y > (1.40 if c.z < -0.04 else 1.18), 1.08, pony)
def fro():
    return [ico("fro", 0.19, (0, 1.42, 0.08), M["Hair"], (1.0, 0.92, 1.0), 2)]
hair_cap("HairAfro", lambda c: c.y > 1.41 and c.z > -0.02, 1.0, fro)
def hawk():
    return [box("hawk", (0.04, 0.09, 0.26), (0, 1.47, 0.05), M["Hair"], 0.015)]
hair_cap("HairMohawk", lambda c: c.y > 1.43 and abs(c.x) < 0.035, 1.07, hawk)

# ---------------- HATS / ACCESSORIES
black = mat("Black", "0a0a0a", 0.2, 0.3)
join([box("lens", (0.215, 0.045, 0.02), (0, 1.355, -0.105), black, 0.012), box("lensh", (0.2, 0.006, 0.005), (0, 1.372, -0.117), mat("Shine", "8fd7ff", 0.1, 0.5, "4fb0ff", 0.4), 0.0),
      box("arm1", (0.01, 0.012, 0.15), (-0.11, 1.36, -0.03), black), box("arm2", (0.01, 0.012, 0.15), (0.11, 1.36, -0.03), black)], "Shades")
capm = tmat("CapCloth", "cloth_shirt", "ffffff", 0.8)
def cap_obj(name, back):
    zb = 1 if back else -1
    parts = [hair_cap(name + "Dome", lambda c: c.y > 1.385, 1.1)]
    parts[0].data.materials[0] = capm
    parts.append(box(name + "Bill", (0.17, 0.016, 0.13), (0, 1.40, 0.04 + zb * 0.15), capm, 0.012, (zb * -0.12, 0, 0)))
    parts.append(sph(name + "Btn", 0.014, (0, 1.485, 0.04), capm, (1, 0.6, 1), 8, 6))
    return join(parts, name)
cap_obj("Cap", False)
cap_obj("CapBack", True)
beanie = tmat("Beanie", "cloth_shirt", "ffffff", 0.95)
b1 = hair_cap("BeanieDome", lambda c: c.y > 1.37, 1.12)
b1.data.materials[0] = beanie
join([b1, torus("fold", 0.123, 0.022, (0, 1.385, 0.04), beanie, "Y", 20, 8), sph("pom", 0.035, (0, 1.505, 0.04), beanie, (1, 1, 1), 10, 8)], "Beanie")
hp = mat("Phones", "222222", 0.3, 0.4)
join([torus("band", 0.13, 0.012, (0, 1.36, 0.04), hp, "Z", 24, 6)] + [cyl("cup%d" % s, 0.045, 0.04, (s * 0.13, 1.33, 0.04), mat("Cup", "ff3d7f", 0.4), "X", 14, 0.01) for s in (-1, 1)], "Headphones")
navy = mat("Navy", "14213d", 0.6)
join([cyl("hat", 0.15, 0.075, (0, 1.47, 0.04), navy, "Y", 20, 0.01), box("brim", (0.2, 0.015, 0.1), (0, 1.44, -0.1), mat("Brim", "0d1626", 0.3), 0.005),
      sph("badge", 0.02, (0, 1.475, -0.11), mat("Badge", "ffd84a", 0.3, 0.9), (1, 1, 0.4))], "CopHat")
join([sph("cbadge", 0.03, (-0.09, 1.02, -0.045), mat("Badge2", "ffd84a", 0.25, 0.9), (1, 1.2, 0.35), 10, 6)], "CopBadge")
goldm = mat("Gold", "ffd700", 0.2, 1.0, "6a4a00", 0.5)
cr = [cyl("band", 0.12, 0.06, (0, 1.5, 0.05), goldm, "Y", 20, 0.0, 0.11)]
for i in range(6):
    a = i * math.pi / 3
    cr.append(sph("pt%d" % i, 0.022, (math.cos(a) * 0.11, 1.55, 0.05 + math.sin(a) * 0.11), goldm, (1, 1.6, 1), 10, 6))
join(cr, "Crown")
join([box("pbox", (0.38, 0.06, 0.38), (0, 0.71, -0.2), mat("Cardboard", "c9a06a", 0.9), 0.005), box("plogo", (0.2, 0.005, 0.12), (0, 0.743, -0.2), mat("Logo", "d9452b", 0.8))], "PizzaBox")

for n in ["HairShort", "HairSpiky", "HairLong", "HairAfro", "HairMohawk", "Shades", "Cap", "CapBack", "Beanie", "Headphones", "CopHat", "Crown"]:
    bone_parent(bpy.data.objects[n], rig, "Neck")
bone_parent(bpy.data.objects["CopBadge"], rig, "Chest")
out = export("rider")
result = {"export": out, "objects": sorted(o.name for o in bpy.data.objects), "tris": sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH"),
          "bones": [b.name for b in rig.data.bones], "groups": [vg.name for vg in body_all.vertex_groups]}
