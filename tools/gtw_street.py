# Grand Theft Wheelchair - textured street props, early-2000s skate-game style.
# Every prop: origin on the ground, front facing -Z in Godot (+Y in Blender).
# Run inside Blender: exec(open(os.path.expanduser(r"E:\Godot\GrandTheftWheelchair\tools\gtw_street.py")).read())
import bpy, bmesh, math, os
from mathutils import Vector
exec(open(os.path.expanduser(r"E:\Godot\GrandTheftWheelchair\tools\gtw_blender_lib.py")).read(), globals())
TEX = os.path.expanduser(r"E:\Godot\GrandTheftWheelchair\assets\textures")
_T = {}

def tmat(name, tex, rough=0.8, metal=0.0, alpha=False):
    if name in _T:
        return _T[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    it = nt.nodes.new("ShaderNodeTexImage")
    it.image = bpy.data.images.load(os.path.join(TEX, tex + ".png"), check_existing=True)
    nt.links.new(it.outputs["Color"], b.inputs["Base Color"])
    if alpha:
        nt.links.new(it.outputs["Alpha"], b.inputs["Alpha"])
        try:
            m.surface_render_method = "DITHERED"
        except Exception:
            pass
    _T[name] = m
    return m

def uvbox(o, size=1.0):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=size)
    bpy.ops.object.mode_set(mode="OBJECT")
    return o

def tbox(name, size, pos, m, bevel=0.0, rot=(0, 0, 0), uv=1.0):
    return uvbox(box(name, size, pos, m, bevel, rot), uv)

def panel(name, w, h, pos, m, uv=(0, 0, 1, 1), facing="-Z"):
    """Flat textured quad, front facing -Z (Godot) by default. uv = (u0, v0, u1, v1)."""
    bm = bmesh.new()
    if facing == "-Z":
        cs = [(-w / 2, -h / 2, 0), (w / 2, -h / 2, 0), (w / 2, h / 2, 0), (-w / 2, h / 2, 0)]
        vs = [bm.verts.new(g(pos[0] + c[0], pos[1] + c[1], pos[2])) for c in cs]
    else:  # +Y up-facing (Godot)
        cs = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
        vs = [bm.verts.new(g(pos[0] + c[0], pos[1], pos[2] - c[1])) for c in cs]
    f = bm.faces.new(vs)
    f.normal_update()
    uvl = bm.loops.layers.uv.verify()
    u0, v0, u1, v1 = uv
    for l, (u, v) in zip(f.loops, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]):
        l[uvl].uv = (u, v)
    o = _mesh_obj(name, bm)
    o.data.materials.append(m)
    return o

def done(objs, fname):
    root = join(objs, fname)
    return export(fname)

def C():
    global steel, dark, rubber, wd, blue
    clear(); _T.clear()
    steel = mat("Steel", "8d949c", 0.35, 0.8)
    dark = mat("DarkMetal", "2a2d31", 0.5, 0.6)
    rubber = mat("Rubber", "151515", 0.8)
    wd = tmat("Wood", "wood", 0.85)
    blue = tmat("NewsBlue", "metal_blue", 0.45, 0.4)
out = []

# ---------------- DUMPSTER
C()
dm = tmat("Dumpster", "dumpster", 0.6, 0.3)
lid = mat("Lid", "1e4d2b", 0.55)
o = [tbox("body", (1.9, 1.05, 1.15), (0, 0.67, 0), dm, 0.03, uv=1.9),
     tbox("rim", (1.98, 0.08, 1.22), (0, 1.2, 0), dm, 0.02, uv=1.9),
     box("lidL", (0.96, 0.05, 1.25), (-0.49, 1.27, 0.0), lid, 0.02, (0.08, 0, 0)),
     box("lidR", (0.96, 0.05, 1.25), (0.49, 1.27, 0.0), lid, 0.02, (0.08, 0, 0)),
     box("pocketL", (0.08, 0.18, 1.2), (-1.0, 0.85, 0), dark, 0.01),
     box("pocketR", (0.08, 0.18, 1.2), (1.0, 0.85, 0), dark, 0.01)]
for x in (-0.8, 0.8):
    for z in (-0.45, 0.45):
        o.append(cyl("w", 0.07, 0.05, (x, 0.07, z), rubber, "X", 10))
        o.append(box("fork", (0.06, 0.08, 0.06), (x, 0.17, z), dark))
out.append(done(o, "dumpster"))

# ---------------- NEWSPAPER BOX
C()
o = [tbox("box", (0.52, 0.62, 0.46), (0, 0.72, 0), blue, 0.02, uv=0.6),
     tbox("cap", (0.56, 0.05, 0.5), (0, 1.055, 0), blue, 0.015, uv=0.6),
     panel("front", 0.5, 0.6, (0, 0.72, -0.232), tmat("Newsbox", "newsbox", 0.4)),
     box("leg", (0.08, 0.42, 0.08), (0, 0.21, 0), dark),
     box("foot", (0.42, 0.04, 0.36), (0, 0.02, 0), dark)]
out.append(done(o, "newsbox"))

# ---------------- VENDING MACHINE
C()
red = mat("VendRed", "c81e28", 0.4, 0.2)
o = [box("cab", (1.0, 1.9, 0.8), (0, 0.95, 0), red, 0.03),
     panel("front", 0.94, 1.84, (0, 0.95, -0.402), tmat("Vending", "vending", 0.3)),
     box("top", (1.04, 0.06, 0.84), (0, 1.92, 0), dark, 0.01)]
glow = mat("VendGlow", "ffffff", 0.2, 0.0, "fff6d8", 1.5)
o.append(panel("glow", 0.6, 1.5, (-0.11, 1.12, -0.403), glow, (0.06, 0.2, 0.67, 0.97)))
out.append(done(o, "vending"))

# ---------------- PLANTER LEDGE (grindable, with steel coping)
C()
conc = tmat("Concrete", "concrete", 0.9)
dirt = mat("Dirt", "4a3424", 1.0)
bush = mat("Bush", "3f7d34", 0.9)
o = [tbox("ledge", (4.0, 0.5, 1.0), (0, 0.25, 0), conc, 0.02, uv=2.0),
     box("copeF", (4.04, 0.05, 0.06), (0, 0.5, -0.5), steel, 0.01),
     box("copeB", (4.04, 0.05, 0.06), (0, 0.5, 0.5), steel, 0.01),
     box("dirt", (3.8, 0.02, 0.8), (0, 0.49, 0), dirt)]
for i in range(5):
    o.append(ico("bush%d" % i, 0.32, (-1.5 + i * 0.75, 0.68, 0), bush, (1.1, 0.75, 0.9), 1))
out.append(done(o, "ledge"))

# ---------------- HANDRAIL
C()
yel = mat("RailYellow", "ffcc22", 0.4, 0.6)
o = [tube("rail", (-1.8, 0.9, 0), (1.8, 0.9, 0), 0.03, yel, 12)]
for x in (-1.6, 0, 1.6):
    o.append(tube("post", (x, 0, 0), (x, 0.9, 0), 0.028, yel, 10))
    o.append(cyl("base", 0.07, 0.02, (x, 0.01, 0), dark, "Y", 10))
out.append(done(o, "handrail"))

# ---------------- PICNIC TABLE
C()
o = []
for i in range(4):
    o.append(tbox("top%d" % i, (1.9, 0.05, 0.19), (0, 0.76, -0.3 + i * 0.2), wd, 0.01, uv=1.0))
for z in (-0.65, 0.65):
    for i in range(2):
        o.append(tbox("seat", (1.9, 0.05, 0.16), (0, 0.45, z + (i - 0.5) * 0.18), wd, 0.01, uv=1.0))
for x in (-0.75, 0.75):
    for s in (-1, 1):
        o.append(tbox("leg", (0.08, 0.95, 0.09), (x, 0.4, s * 0.32), wd, 0.0, (s * 0.55, 0, 0), 1.0))
    o.append(tbox("brace", (0.08, 0.07, 1.6), (x, 0.4, 0), wd, 0.0, uv=1.0))
out.append(done(o, "picnic"))

# ---------------- BENCH (wood slats on cast iron)
C()
o = []
for i in range(3):
    o.append(tbox("slat%d" % i, (1.8, 0.04, 0.12), (0, 0.45, -0.15 + i * 0.14), wd, 0.008, uv=1.0))
for i in range(2):
    o.append(tbox("back%d" % i, (1.8, 0.11, 0.035), (0, 0.62 + i * 0.15, 0.24 + i * 0.03), wd, 0.008, (-0.18, 0, 0), 1.0))
for x in (-0.8, 0.8):
    o.append(box("legF", (0.05, 0.45, 0.06), (x, 0.22, -0.2), dark, 0.01))
    o.append(box("legB", (0.05, 0.85, 0.06), (x, 0.42, 0.24), dark, 0.01, (-0.12, 0, 0)))
    o.append(box("arm", (0.05, 0.05, 0.5), (x, 0.66, 0.0), dark, 0.015))
out.append(done(o, "bench"))

# ---------------- TRASH CAN
C()
o = [uvbox(cyl("can", 0.3, 0.85, (0, 0.43, 0), blue, "Y", 16, 0.01, 0.33), 0.7),
     cyl("lid", 0.35, 0.07, (0, 0.89, 0), dark, "Y", 16, 0.01),
     cyl("knob", 0.06, 0.06, (0, 0.95, 0), dark, "Y", 8),
     torus("band", 0.315, 0.015, (0, 0.2, 0), dark, "Y", 24, 6)]
out.append(done(o, "bin"))

# ---------------- HYDRANT
C()
hr = mat("HydRed", "d62828", 0.35, 0.2)
hy = mat("HydYel", "ffd84a", 0.4, 0.5)
o = [cyl("base", 0.2, 0.08, (0, 0.04, 0), hr, "Y", 12, 0.01),
     cyl("barrel", 0.15, 0.55, (0, 0.34, 0), hr, "Y", 14, 0.01),
     sph("dome", 0.16, (0, 0.62, 0), hr, (1, 0.75, 1), 14, 8),
     cyl("nut", 0.05, 0.07, (0, 0.75, 0), hy, "Y", 6),
     cyl("outL", 0.065, 0.12, (-0.18, 0.42, 0), hy, "X", 10),
     cyl("outR", 0.065, 0.12, (0.18, 0.42, 0), hy, "X", 10),
     cyl("outF", 0.08, 0.1, (0, 0.38, -0.17), hy, "Z", 10)]
out.append(done(o, "hydrant"))

# ---------------- TRAFFIC CONE
C()
orng = mat("Cone", "ff6a00", 0.5)
wht = mat("ConeStripe", "f2f2f2", 0.4)
o = [box("cbase", (0.42, 0.04, 0.42), (0, 0.02, 0), orng, 0.01),
     cyl("cone", 0.17, 0.66, (0, 0.37, 0), orng, "Y", 14, 0.0, 0.03),
     cyl("stripe", 0.118, 0.1, (0, 0.42, 0), wht, "Y", 14, 0.0, 0.1)]
out.append(done(o, "cone"))

# ---------------- STRIPED BARRIER
C()
hz = tmat("Hazard", "hazard", 0.5)
o = [tbox("plank", (1.6, 0.25, 0.05), (0, 0.85, 0), hz, 0.0, uv=0.8),
     tbox("plank2", (1.6, 0.18, 0.05), (0, 0.45, 0), hz, 0.0, uv=0.8)]
for x in (-0.7, 0.7):
    for s in (-1, 1):
        o.append(box("leg", (0.06, 1.0, 0.05), (x, 0.47, s * 0.12), mat("BarLeg", "e0e0e0", 0.6), 0.0, (s * 0.25, 0, 0)))
out.append(done(o, "barrier"))

# ---------------- CHAIN-LINK FENCE PANEL (4 m)
C()
cl = tmat("Chainlink", "chainlink", 0.4, 0.6, True)
o = [panel("mesh", 4.0, 2.0, (0, 1.0, 0), cl, (0, 0, 8, 4)),
     tube("top", (-2, 2.0, 0), (2, 2.0, 0), 0.025, steel, 8)]
for x in (-2, 0, 2):
    o.append(tube("post", (x, 0, 0), (x, 2.05, 0), 0.035, steel, 8))
out.append(done(o, "fence"))

result = {"exported": out}
