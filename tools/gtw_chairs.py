# Grand Theft Wheelchair - wheelchair models (Blender 5.x)
# Modelled on real chairs:
#  * active / rigid chairs (rusty, turbo, cop, gold): tapered rigid frame, 24" wheels with
#    laced spokes + push rims, camber, sling back, side guards, wheel locks, anti-tippers
#  * hospital: folding transport chair - X-brace, armrests, swing-away legrests, mag wheels, push handles
#  * power: mid-wheel-drive power chair - six wheels, power base, captain's seat, joystick
#  * monster: off-road active chair with fat knobby tyres and a roll cage (game silliness)
#  * cart: a shopping cart
# Naming contract (see scripts/models.gd): WheelL/WheelR (spin about local X, origin at hub),
# CasterL/CasterR(/CasterBL/CasterBR), Seat empty, LightRed/LightBlue on the cop chair.
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

_TOOLS = os.environ.get("GTW_TOOLS", r"E:\Godot\GrandTheftWheelchair\tools")
exec(open(os.path.join(_TOOLS, "gtw_blender_lib.py")).read(), globals())

COLORS = {"rusty": "9a6b4a", "hospital": "c9d1d8", "power": "2f7de1", "turbo": "e8343f", "monster": "3fb950",
          "cart": "b8c2cc", "cop": "1b2a4a", "gold": "f5c542"}

def shade(col, k):
    return "%02x%02x%02x" % tuple(max(0, min(255, int(int(col[i:i+2], 16) * k))) for i in (0, 2, 4))

def _bake(o):
    """apply rotation/scale into the mesh so the object only carries its position"""
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

def spin_part(objs, name, hub, camber=0.0):
    """join parts into a spinning wheel with its origin at the hub; camber tilts it inside a parent empty"""
    o = join(objs, name)
    _bake(o)
    set_origin(o, g(*hub))
    if camber != 0.0:
        e = bpy.data.objects.new("Camber" + name[-1], None)
        e.location = g(*hub)
        e.rotation_euler = (0, camber, 0)         # about the forward axis: tops lean in
        bpy.context.scene.collection.objects.link(e)
        o.parent = e
        o.matrix_parent_inverse = Matrix.Identity(4)
        o.location = (0, 0, 0)
        o.rotation_euler = (0, 0, 0)
    return o

# ------------------------------------------------------------------ rear wheels
def rear_wheel(name, hub, side, r, style, rim_col, tyre="tread", camber=0.0):
    """style: laced (36 crossed spokes), sport (6 flat bladed spokes), mag (5 cast spokes), knobby (fat off-road)"""
    x, y, z = hub
    chrome = mat("Chrome", "dfe5ea", 0.12, 1.0)
    alu = mat("Alu", "b9c0c8", 0.3, 0.9)
    rim = mat("Rim_" + rim_col, rim_col, 0.3, 0.8)
    parts = []
    if style == "knobby":
        tw = 0.065
        tire = tmat("TireFat", tyre, "707070", 0.9)
        parts.append(torus(name + "_t", r - tw, tw, hub, tire, "X", 48, 14))
        for k in range(28):                              # knobs
            a = 2 * math.pi * k / 28
            for s in (-1, 1):
                p = (x + s * 0.035, y + math.cos(a) * (r - 0.012), z + math.sin(a) * (r - 0.012))
                kb = box(name + "_k%d%d" % (k, s), (0.04, 0.026, 0.03), p, tire, 0.004, rot=(a, 0, 0))
                parts.append(kb)
    elif style == "mag":
        tw = 0.022
        tire = tmat("TireGrey", tyre, "5a5f66", 0.9)
        parts.append(torus(name + "_t", r - tw, tw, hub, tire, "X", 44, 12))
    else:
        tw = 0.015
        tire = tmat("Tire", tyre, "ffffff", 0.85)
        parts.append(torus(name + "_t", r - tw, tw, hub, tire, "X", 48, 10))
    rr = r - tw * 2                                       # rim radius
    parts.append(torus(name + "_rim", rr - 0.006, 0.009, hub, rim if style != "laced" else alu, "X", 44, 6))
    parts.append(cyl(name + "_hub", 0.028, 0.075, hub, alu, "X", 16))
    parts.append(cyl(name + "_qr", 0.012, 0.11, (x - side * 0.01, y, z), chrome, "X", 10))   # quick-release axle
    if style == "laced" or style == "knobby":
        n = 36 if style == "laced" else 24
        for i in range(n):
            a0 = 2 * math.pi * i / n
            fl = 1 if i % 2 == 0 else -1                  # left / right hub flange
            cross = 0.45 * (1 if (i // 2) % 2 == 0 else -1)
            hx = x + fl * 0.026
            ha = a0 + cross
            p0 = (hx, y + math.cos(ha) * 0.026, z + math.sin(ha) * 0.026)
            p1 = (x, y + math.cos(a0) * (rr - 0.01), z + math.sin(a0) * (rr - 0.01))
            parts.append(tube(name + "_s%d" % i, p0, p1, 0.0022 if style == "laced" else 0.003, chrome, 4))
    elif style == "sport":
        for i in range(6):                                # bladed spokes in pairs, Spinergy-ish
            for d in (-0.06, 0.06):
                a0 = 2 * math.pi * i / 6 + d
                p0 = (x + (0.02 if d > 0 else -0.02), y + math.cos(a0) * 0.03, z + math.sin(a0) * 0.03)
                p1 = (x, y + math.cos(a0 + d) * (rr - 0.01), z + math.sin(a0 + d) * (rr - 0.01))
                parts.append(tube(name + "_s%d%s" % (i, d), p0, p1, 0.0045, rim, 6))
    elif style == "mag":
        for i in range(5):
            a0 = 2 * math.pi * i / 5
            mid = (x, y + math.cos(a0) * rr * 0.52, z + math.sin(a0) * rr * 0.52)
            parts.append(box(name + "_m%d" % i, (0.03, rr * 0.92, 0.035), mid, rim, 0.008, rot=(a0, 0, 0)))
        parts.append(cyl(name + "_disc", 0.06, 0.05, hub, rim, "X", 20))
    # push rim (hand rim): outside the wheel on 6 tabs - what you actually push
    hrx = x + side * 0.036
    hr = rr - 0.03
    parts.append(torus(name + "_hr", hr, 0.0095, (hrx, y, z), chrome, "X", 48, 8))
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.25
        q = (y + math.cos(a) * hr, z + math.sin(a) * hr)
        parts.append(tube(name + "_tab%d" % k, (x + side * 0.008, q[0], q[1]), (hrx, q[0], q[1]), 0.005, chrome, 6))
    return spin_part(parts, name, hub, camber * (-side))

def caster(name, pos, r=0.065, wide=0.028, col="2a2a2a", soft=False):
    tire = tmat("CasterTire", "tread", col, 0.85) if not soft else mat("CasterPU", col, 0.7)
    alu = mat("Alu", "b9c0c8", 0.3, 0.9)
    parts = [torus(name + "_t", r - wide / 2, wide / 2, pos, tire, "X", 24, 8),
             cyl(name + "_d", r * 0.62, wide * 0.8, pos, alu, "X", 16),
             cyl(name + "_h", 0.012, wide + 0.02, pos, alu, "X", 8)]
    return spin_part(parts, name, pos)

def caster_assembly(objs, name, x, frame_y, stem_z, r=0.065, trail=0.035, col="2a2a2a", housing="c0c7cf"):
    """caster housing (vertical stem) on the frame + fork + wheel trailing behind it"""
    metal = mat("Housing_" + housing, housing, 0.3, 0.8)
    alu = mat("Alu", "b9c0c8", 0.3, 0.9)
    axle = (x, r, stem_z + trail)
    caster(name, axle, r, col=col)
    top = frame_y
    objs.append(cyl(name + "Stem", 0.02, 0.07, (x, top - 0.035, stem_z), metal, "Y", 12))
    objs.append(cyl(name + "Cap", 0.022, 0.01, (x, top + 0.003, stem_z), mat("Black", "151515", 0.7), "Y", 12))
    fy = top - 0.075
    for s in (-1, 1):
        objs.append(tube(name + "Fork%d" % s, (x + s * 0.022, fy, stem_z), (x + s * 0.022, r, stem_z + trail), 0.006, alu, 6))
    objs.append(box(name + "Crown", (0.06, 0.014, 0.03), (x, fy, stem_z), alu, 0.004))

# ------------------------------------------------------------------ the chairs
def side_guard(objs, s, x, hub, r, m):
    """clothing guard: flat plate between seat and wheel, its top following the tyre"""
    bm = bmesh.new()
    pts = []
    y0 = 0.45
    for k in range(9):
        a = math.radians(40 + k * 12.5)                   # front-top to back-top of the wheel
        pts.append((hub[2] - math.cos(a) * (r + 0.02), hub[1] + math.sin(a) * (r + 0.02)))
    poly = [(pts[0][0], y0)] + pts + [(pts[-1][0], y0)]
    vs = [bm.verts.new(g(x, py, pz)) for (pz, py) in poly]
    f = bm.faces.new(vs)
    ret = bmesh.ops.extrude_face_region(bm, geom=[f])
    ev = [e for e in ret["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=Vector((0.006 * s, 0, 0)), verts=ev)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("guard%d" % s)
    bm.to_mesh(me)
    o = bpy.data.objects.new("guard%d" % s, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(m)
    objs.append(o)

def active_chair(t, objs, paint, dark, cushion):
    """rigid ultralight 'active' chair"""
    metal = mat("Metal", "c0c7cf", 0.22, 0.95)
    black = mat("Black", "151515", 0.7)
    sling = cushion
    r = 0.3
    hub = (0.0, r, 0.07)
    camber = {"turbo": math.radians(12), "cop": math.radians(4), "gold": math.radians(5), "rusty": 0.0, "monster": math.radians(3)}.get(t, math.radians(3))
    wx = 0.31 if t != "turbo" else 0.33
    style = {"turbo": "sport", "gold": "sport", "rusty": "laced", "monster": "knobby"}.get(t, "laced")
    rim_col = {"turbo": "ff5a5a", "gold": "fff1a8", "cop": "4f8bff", "rusty": "a8a8a0", "monster": "2a2a2a"}.get(t, "b0b8c0")
    if t == "monster":
        r = 0.42
        hub = (0.0, r, 0.1)
        wx = 0.44
    for s, nm in ((-1, "WheelL"), (1, "WheelR")):
        rear_wheel(nm, (s * wx, hub[1], hub[2]), s, r, style, rim_col, camber=camber)
    fw = 0.205                     # half frame width at the seat
    ff = 0.15                      # half width at the footrest (tapered front)
    seat_f, seat_b = 0.505, 0.47   # front higher than back ("dump")
    zf, zb = -0.30, 0.13           # seat front / back
    back_top = 0.83 if t != "turbo" else 0.72
    if t == "monster":
        seat_f, seat_b = 0.62, 0.59
        back_top = 0.95
    for s in (-1, 1):
        x = s * fw
        xf = s * ff
        # one bent side tube: back cane -> seat rail -> knee bend -> down to the footrest
        objs.append(tube("rail%d" % s, (x, seat_b - 0.04, zb), (x, seat_f - 0.04, zf), 0.013, paint, 10))
        objs.append(sph("bend%d" % s, 0.013, (x, seat_f - 0.04, zf), paint, segs=10, rings=6))
        objs.append(tube("front%d" % s, (x, seat_f - 0.04, zf), (xf, 0.14 if t != "monster" else 0.22, -0.50), 0.013, paint, 10))
        # back cane, slightly reclined, with a folding hinge
        objs.append(tube("cane%d" % s, (x, seat_b - 0.04, zb), (x, back_top, zb + 0.05), 0.012, paint, 10))
        objs.append(cyl("hinge%d" % s, 0.017, 0.03, (x, seat_b + 0.06, zb + 0.01), black, "X", 10))
        # rear down tube to the axle plate and the camber/axle tube
        objs.append(tube("down%d" % s, (x, seat_b - 0.04, zb - 0.02), (x, hub[1] - 0.03, hub[2]), 0.012, paint, 10))
        objs.append(box("plate%d" % s, (0.008, 0.07, 0.11), (x + s * 0.012, hub[1] - 0.01, hub[2]), metal, 0.003))
        # wheel lock: lever at the front of the tyre
        lz = hub[2] - r * 0.72
        objs.append(box("lock%d" % s, (0.02, 0.025, 0.06), (s * (wx - 0.045), seat_f - 0.09, lz), black, 0.005))
        objs.append(tube("lockh%d" % s, (s * (wx - 0.045), seat_f - 0.08, lz), (s * (wx - 0.05), seat_f + 0.02, lz - 0.06), 0.006, black, 6))
        objs.append(sph("lockk%d" % s, 0.012, (s * (wx - 0.05), seat_f + 0.02, lz - 0.06), mat("Red", "e63946", 0.5), segs=8, rings=6))
        # anti-tipper with a small roller
        objs.append(tube("tip%d" % s, (x, hub[1] - 0.06, hub[2] + 0.04), (x * 0.85, 0.07, hub[2] + 0.24), 0.01, metal, 8))
        objs.append(cyl("tipw%d" % s, 0.028, 0.025, (x * 0.85, 0.05, hub[2] + 0.24), black, "X", 12))
        lean = (r + 0.02) * math.tan(camber)          # cambered tyre top sits further in
        side_guard(objs, s, s * (wx - 0.035 - lean), hub, r, dark)
        # caster housing clamped to the outside of the front tube
        fy0 = 0.14 if t != "monster" else 0.22
        zc = -0.36
        k = (zc - zf) / (-0.50 - zf)
        ty = (seat_f - 0.04) + k * (fy0 - (seat_f - 0.04))
        tx = fw + k * (ff - fw)
        cx = s * (tx + 0.035)
        objs.append(box("clamp%d" % s, (0.05, 0.03, 0.03), (s * (tx + 0.018), ty - 0.02, zc), black, 0.006))
        caster_assembly(objs, "Caster" + ("L" if s < 0 else "R"), cx, ty - 0.01, zc,
                        r=0.065 if t != "monster" else 0.1, col="2a2a2a")
        objs.append(tube("lockarm%d" % s, (x, seat_f - 0.05 - (seat_f - seat_b) * ((lz - zf) / (zb - zf)), lz), (s * (wx - 0.045), seat_f - 0.09, lz), 0.008, metal, 6))
    objs.append(tube("axle", (-wx + 0.04, hub[1] - 0.02, hub[2]), (wx - 0.04, hub[1] - 0.02, hub[2]), 0.016, paint, 12))
    objs.append(tube("brace", (-fw, seat_b - 0.04, zb - 0.01), (fw, seat_b - 0.04, zb - 0.01), 0.011, paint, 10))
    # footrest: flip-up angled plate between the tapered front tubes
    fy = 0.14 if t != "monster" else 0.22
    objs.append(tube("footbar", (-ff, fy, -0.50), (ff, fy, -0.50), 0.013, paint, 10))
    objs.append(box("Foot", (ff * 2 + 0.02, 0.012, 0.13), (0, fy + 0.01, -0.45), black, 0.004, rot=(0.12, 0, 0)))
    # sling seat + cushion, sling back with straps
    sy = (seat_f + seat_b) / 2
    tilt = math.atan2(seat_f - seat_b, zb - zf)
    objs.append(uvbox(box("SeatPad", (fw * 2 + 0.01, 0.06, zb - zf - 0.02), (0, sy + 0.005, (zf + zb) / 2), sling, 0.02, rot=(-tilt, 0, 0)), 0.5))
    bh = back_top - seat_b - 0.06
    objs.append(uvbox(box("BackPad", (fw * 2 - 0.01, bh, 0.025), (0, seat_b + 0.06 + bh / 2, zb + 0.035), sling, 0.008, rot=(-0.1, 0, 0)), 0.5))
    for k in range(3):
        yk = seat_b + 0.1 + k * bh / 3
        objs.append(box("strap%d" % k, (fw * 2 + 0.01, 0.025, 0.012), (0, yk, zb + 0.055 - k * 0.006), black, 0.003, rot=(-0.1, 0, 0)))
    if t in ("rusty", "cop"):        # short push handles on the canes
        for s in (-1, 1):
            objs.append(tube("grip%d" % s, (s * fw, back_top, zb + 0.05), (s * fw, back_top + 0.03, zb + 0.16), 0.016, black, 10))
    return hub, wx

def hospital_chair(objs, paint, dark, cushion):
    """standard folding chair: steel frame, X-brace, full armrests, swing-away legrests, mag wheels, push handles"""
    metal = mat("Metal", "c0c7cf", 0.22, 0.95)
    black = mat("Black", "151515", 0.7)
    r = 0.3
    hub = (0.0, r, 0.12)
    wx = 0.34
    for s, nm in ((-1, "WheelL"), (1, "WheelR")):
        rear_wheel(nm, (s * wx, r, hub[2]), s, r, "mag", "8a9099")
    fw = 0.24
    sy = 0.49
    zf, zb = -0.26, 0.2
    for s in (-1, 1):
        x = s * fw
        objs.append(tube("rail%d" % s, (x, sy - 0.03, zf), (x, sy - 0.03, zb), 0.013, metal, 10))
        objs.append(tube("low%d" % s, (x, 0.27, zf), (x, 0.27, zb), 0.012, metal, 10))
        objs.append(tube("fpost%d" % s, (x, 0.2, zf), (x, 0.7, zf), 0.013, metal, 10))
        objs.append(tube("cane%d" % s, (x, 0.2, zb), (x, 0.95, zb + 0.02), 0.013, metal, 10))
        objs.append(tube("grip%d" % s, (x, 0.95, zb + 0.02), (x, 0.95, zb + 0.15), 0.018, black, 10))
        # armrest: support + pad over the full seat length
        objs.append(tube("arm%d" % s, (x, 0.7, zf), (x, 0.7, zb - 0.02), 0.012, metal, 10))
        objs.append(tube("armb%d" % s, (x, 0.7, zb - 0.02), (x, sy - 0.03, zb - 0.02), 0.012, metal, 10))
        objs.append(box("pad%d" % s, (0.06, 0.04, 0.34), (x, 0.725, zf + 0.19), black, 0.015))
        # swing-away legrest + flip-up footplate with heel loop
        fx = s * 0.15
        objs.append(tube("leg%d" % s, (x, 0.48, zf + 0.01), (fx, 0.16, -0.48), 0.012, metal, 10))
        objs.append(box("Foot%d" % s, (0.15, 0.012, 0.12), (fx - s * 0.06, 0.15, -0.45), black, 0.004, rot=(0.1, 0, 0)))
        objs.append(tube("heel%d" % s, (fx - s * 0.13, 0.17, -0.40), (fx, 0.17, -0.40), 0.004, black, 6))
        # wheel lock (push-to-lock lever)
        objs.append(box("lock%d" % s, (0.025, 0.03, 0.07), (s * (wx - 0.05), 0.47, hub[2] - 0.22), black, 0.006))
        objs.append(tube("lockh%d" % s, (s * (wx - 0.05), 0.48, hub[2] - 0.22), (s * (wx - 0.05), 0.58, hub[2] - 0.3), 0.007, black, 6))
        objs.append(box("plate%d" % s, (0.008, 0.12, 0.12), (x + s * 0.012, r, hub[2]), metal, 0.004))
        objs.append(tube("down%d" % s, (x, sy - 0.03, hub[2]), (x, r, hub[2]), 0.012, metal, 8))
        objs.append(box("guard%d" % s, (0.006, 0.15, 0.36), (s * (fw + 0.02), 0.6, zf + 0.22), dark, 0.004))
        caster_assembly(objs, "Caster" + ("L" if s < 0 else "R"), x, 0.27, zf, r=0.09, trail=0.04, col="3a3f46")
        objs.append(tube("tip%d" % s, (x, 0.27, zb), (x * 0.9, 0.08, zb + 0.24), 0.01, metal, 8))
        objs.append(cyl("tipw%d" % s, 0.025, 0.025, (x * 0.9, 0.06, zb + 0.24), black, "X", 12))
    # the folding X-brace under the seat
    objs.append(tube("x1", (-fw, 0.27, 0.0), (fw, sy - 0.03, 0.0), 0.011, metal, 8))
    objs.append(tube("x2", (fw, 0.27, 0.0), (-fw, sy - 0.03, 0.0), 0.011, metal, 8))
    objs.append(uvbox(box("SeatPad", (fw * 2 + 0.02, 0.055, zb - zf), (0, sy + 0.01, (zf + zb) / 2), cushion, 0.015), 0.5))
    objs.append(uvbox(box("BackPad", (fw * 2 + 0.01, 0.36, 0.02), (0, 0.76, zb + 0.01), cushion, 0.006), 0.5))
    return hub, wx

def power_chair(objs, paint, dark, cushion):
    """mid-wheel-drive power chair: big drive wheels under the seat, casters front and back"""
    black = mat("Black", "151515", 0.7)
    shroud = mat("Shroud", "2b2e33", 0.55, 0.1)
    r = 0.17
    hub = (0.0, r, 0.0)
    wx = 0.28
    tire = tmat("TireP", "tread", "ffffff", 0.85)
    alu = mat("Alu", "b9c0c8", 0.3, 0.9)
    for s, nm in ((-1, "WheelL"), (1, "WheelR")):
        p = (s * wx, r, 0.0)
        parts = [torus(nm + "_t", r - 0.035, 0.035, p, tire, "X", 36, 12),
                 cyl(nm + "_d", r - 0.06, 0.05, p, mat("Rim_p", "3a3f46", 0.4, 0.6), "X", 24),
                 cyl(nm + "_c", 0.045, 0.07, p, paint, "X", 16)]
        for k in range(5):
            a = 2 * math.pi * k / 5
            parts.append(cyl(nm + "_b%d" % k, 0.01, 0.075, (p[0], r + math.cos(a) * 0.07, math.sin(a) * 0.07), alu, "X", 8))
        spin_part(parts, nm, p)
    # power base: shrouded box with bumpers, batteries inside
    objs.append(box("Base", (0.42, 0.2, 0.7), (0, 0.22, 0.0), shroud, 0.03))
    objs.append(box("BaseTop", (0.44, 0.03, 0.72), (0, 0.33, 0.0), paint, 0.012))
    for z in (-0.37, 0.37):
        objs.append(box("bump%s" % z, (0.46, 0.06, 0.04), (0, 0.18, z), black, 0.015))
    objs.append(box("Led", (0.03, 0.02, 0.01), (0.12, 0.3, 0.355), mat("Led", "33ff55", 0.4, 0, "33ff55", 5.0)))
    for nm, x, z in (("CasterL", -0.18, -0.42), ("CasterR", 0.18, -0.42), ("CasterBL", -0.18, 0.42), ("CasterBR", 0.18, 0.42)):
        caster_assembly(objs, nm, x, 0.22, z - (0.03 if z < 0 else -0.03), r=0.075, trail=0.03 if z < 0 else -0.03)
        objs.append(tube(nm + "Arm", (x, 0.22, z - (0.03 if z < 0 else -0.03)), (x, 0.22, z * 0.6), 0.018, shroud, 8))
    # seat post + captain's seat with high back, headrest and armrests
    objs.append(cyl("Post", 0.05, 0.12, (0, 0.4, 0.0), mat("Metal", "c0c7cf", 0.22, 0.95), "Y", 16))
    objs.append(uvbox(box("SeatPad", (0.48, 0.1, 0.46), (0, 0.51, -0.02), cushion, 0.035), 0.5))
    objs.append(uvbox(box("BackPad", (0.46, 0.5, 0.09), (0, 0.85, 0.22), cushion, 0.035, rot=(-0.12, 0, 0)), 0.5))
    objs.append(uvbox(box("Head", (0.26, 0.14, 0.08), (0, 1.2, 0.28), cushion, 0.03, rot=(-0.12, 0, 0)), 0.5))
    objs.append(tube("headpost", (0, 1.1, 0.27), (0, 1.14, 0.28), 0.012, black))
    for s in (-1, 1):
        objs.append(box("arm%d" % s, (0.07, 0.05, 0.36), (s * 0.27, 0.7, -0.06), black, 0.02))
        objs.append(tube("armp%d" % s, (s * 0.27, 0.56, 0.08), (s * 0.27, 0.68, 0.08), 0.014, black))
        objs.append(tube("leg%d" % s, (s * 0.12, 0.46, -0.24), (s * 0.12, 0.14, -0.46), 0.015, black))
    objs.append(box("Foot", (0.36, 0.015, 0.16), (0, 0.13, -0.47), black, 0.005, rot=(0.1, 0, 0)))
    # joystick on the right armrest
    objs.append(box("JoyBox", (0.075, 0.05, 0.13), (0.29, 0.75, -0.25), black, 0.012))
    objs.append(box("JoyScreen", (0.05, 0.003, 0.04), (0.29, 0.776, -0.27), mat("Screen", "7ee0ff", 0.3, 0, "7ee0ff", 1.5)))
    objs.append(tube("Stick", (0.29, 0.77, -0.22), (0.29, 0.83, -0.22), 0.007, black))
    objs.append(sph("Knob", 0.02, (0.29, 0.84, -0.22), mat("Knob", "f5c542", 0.5)))
    return hub, wx

def chair(t):
    clear()
    col = COLORS[t]
    gold = t == "gold"
    paint = mat("Paint", col, 0.22 if gold else 0.35, 1.0 if gold else 0.35)
    dark = paint if gold else mat("PaintDark", shade(col, 0.62), 0.6)
    cushion = tmat("Cushion", "fabric", "3a3d44" if not gold else "8a1c2b", 0.9)
    objs = []
    empty("Seat", (0, -0.12, 0.05) if t == "cart" else (0, 0, 0))
    if t == "cart":
        return cart(objs)
    if t == "hospital":
        hospital_chair(objs, paint, dark, cushion)
    elif t == "power":
        power_chair(objs, paint, dark, cushion)
    else:
        active_chair(t, objs, paint, dark, cushion)
    metal = mat("Metal", "c0c7cf", 0.22, 0.95)
    black = mat("Black", "151515", 0.7)
    if t == "hospital":
        objs.append(tube("IV", (-0.26, 0.3, 0.3), (-0.26, 1.75, 0.3), 0.012, metal))
        objs.append(tube("IVt", (-0.34, 1.72, 0.3), (-0.18, 1.72, 0.3), 0.008, metal))
        objs.append(box("Bag", (0.1, 0.18, 0.04), (-0.2, 1.58, 0.3), mat("Bag", "a8dcff", 0.1, 0, None, 0, 0.6), 0.02))
        objs.append(box("Cross", (0.16, 0.05, 0.03), (0, 0.8, 0.225), mat("Red", "e63946", 0.5)))
        objs.append(box("Cross2", (0.05, 0.16, 0.03), (0, 0.8, 0.225), mat("Red", "e63946", 0.5)))
    if t == "turbo":
        objs.append(box("Spoiler", (0.6, 0.022, 0.13), (0, 0.84, 0.3), mat("Spoiler", "b01822", 0.3, 0.3), 0.01))
        for s in (-1, 1):
            objs.append(tube("sp%d" % s, (s * 0.2, 0.7, 0.19), (s * 0.2, 0.83, 0.29), 0.01, black))
        objs.append(box("Stripe", (0.06, 0.004, 0.4), (0, 0.523, -0.085), mat("Stripe", "ffb000", 0.4), rot=(-0.08, 0, 0)))
    if t == "monster":
        cage = mat("Cage", "1d1d1d", 0.4, 0.6)
        for s in (-1, 1):
            objs.append(tube("cf%d" % s, (s * 0.3, 0.55, -0.3), (s * 0.3, 1.35, -0.3), 0.025, cage))
            objs.append(tube("cb%d" % s, (s * 0.3, 0.55, 0.2), (s * 0.3, 1.35, 0.2), 0.025, cage))
            objs.append(tube("ct%d" % s, (s * 0.3, 1.35, -0.3), (s * 0.3, 1.35, 0.2), 0.025, cage))
            objs.append(sph("Lamp%d" % s, 0.055, (s * 0.22, 1.35, -0.34), mat("Lamp", "fffbd0", 0.2, 0, "fffbd0", 6.0)))
        objs.append(tube("cx1", (-0.3, 1.35, -0.3), (0.3, 1.35, -0.3), 0.025, cage))
        objs.append(tube("cx2", (-0.3, 1.35, 0.2), (0.3, 1.35, 0.2), 0.025, cage))
    if t == "cop":
        objs.append(box("Stripe", (0.42, 0.004, 0.08), (0, 0.525, -0.085), mat("White", "ffffff", 0.5), rot=(-0.08, 0, 0)))
        objs.append(tube("LightPost", (-0.205, 0.86, 0.18), (0.205, 0.86, 0.18), 0.012, black))
        objs.append(box("Bar", (0.4, 0.045, 0.07), (0, 0.9, 0.18), black, 0.01))
        lr = box("LightRed", (0.14, 0.06, 0.07), (-0.11, 0.95, 0.18), mat("LightRedM", "ff2020", 0.3, 0, "ff2020", 4.0), 0.01)
        lb = box("LightBlue", (0.14, 0.06, 0.07), (0.11, 0.95, 0.18), mat("LightBlueM", "2050ff", 0.3, 0, "3060ff", 4.0), 0.01)
        for o in (lr, lb):
            bpy.context.view_layer.objects.active = o
            for md in list(o.modifiers):
                bpy.ops.object.modifier_apply(modifier=md.name)
    if t == "gold":
        gem = mat("Gem", "e63946", 0.15, 0.3, "e63946", 0.8)
        for s in (-1, 1):
            objs.append(sph("fin%d" % s, 0.035, (s * 0.205, 0.85, 0.18), paint))
        objs.append(box("Crest", (0.12, 0.2, 0.03), (0, 0.9, 0.17), paint, 0.012))
        objs.append(sph("Gem", 0.045, (0, 0.95, 0.15), gem))
    join(objs, "Frame")
    return export("chair_" + t)

def cart(objs):
    wire = mat("Wire", "d0d8e0", 0.25, 0.95)
    red = mat("Handle", "e33333", 0.4)
    objs.append(box("Floor", (0.62, 0.02, 0.95), (0, 0.33, 0), wire, 0.004))
    for i in range(9):
        z = -0.47 + i * 0.1175
        for x in (-0.31, 0.31):
            objs.append(tube("vz%d%s" % (i, x), (x, 0.33, z), (x, 0.84, z), 0.006, wire, 6))
    for i in range(6):
        x = -0.31 + i * 0.124
        for z in (-0.475, 0.475):
            objs.append(tube("vx%d%s" % (i, z), (x, 0.33, z), (x, 0.84, z), 0.006, wire, 6))
    for y in (0.58, 0.84):
        for z in (-0.475, 0.475):
            objs.append(tube("hz%s%s" % (y, z), (-0.31, y, z), (0.31, y, z), 0.008, wire, 6))
        for x in (-0.31, 0.31):
            objs.append(tube("hx%s%s" % (y, x), (x, y, -0.475), (x, y, 0.475), 0.008, wire, 6))
    objs.append(tube("Bar", (-0.33, 1.0, 0.6), (0.33, 1.0, 0.6), 0.028, red, 12))
    for x in (-0.3, 0.3):
        objs.append(tube("hs%s" % x, (x, 0.84, 0.475), (x, 1.0, 0.6), 0.012, wire, 6))
    for i, p in enumerate([(-0.25, 0.06, -0.38), (0.25, 0.06, -0.38), (-0.25, 0.06, 0.38), (0.25, 0.06, 0.38)]):
        caster(["CasterL", "CasterR", "CasterBL", "CasterBR"][i], p, 0.06, soft=True, col="2a2a2a")
        objs.append(tube("leg%d" % i, (p[0], 0.08, p[2]), (p[0], 0.33, p[2]), 0.012, wire, 6))
    join(objs, "Frame")
    return export("chair_cart")

ONLY = os.environ.get("GTW_ONLY", "")
out = []
for t in ["rusty", "hospital", "power", "turbo", "monster", "cart", "cop", "gold"]:
    if ONLY and t not in ONLY.split(","):
        continue
    out.append(chair(t))
result = {"exported": out}
