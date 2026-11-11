# Grand Theft Wheelchair - skate pieces and extra street props.
# Origin on the ground; ramps rise towards -Z (you roll in from +Z heading -Z).
# Run inside Blender: exec(open(os.path.expanduser(r"E:\Godot\GrandTheftWheelchair\tools\gtw_skate.py")).read(), {"__name__": "gtw"})
import bpy, bmesh, math, os
exec(open(os.path.expanduser(r"E:\Godot\GrandTheftWheelchair\tools\gtw_blender_lib.py")).read(), globals())
out = []

def extrude_profile(name, prof, width, m, uv=1.5):
    """prof: list of (z, y) in Godot axes, closed polygon. Extruded across X (width)."""
    bm = bmesh.new()
    L = [bm.verts.new(g(-width / 2, y, z)) for z, y in prof]
    Rr = [bm.verts.new(g(width / 2, y, z)) for z, y in prof]
    n = len(prof)
    bm.faces.new(L[::-1])
    bm.faces.new(Rr)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((L[i], L[j], Rr[j], Rr[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = _mesh_obj(name, bm)
    o.data.materials.append(m)
    uvbox(o, uv)
    try:
        o.data.set_sharp_from_angle(angle=math.radians(25))
    except Exception:
        pass
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def quarter_pipe(name, R=3.0, deg=54.0, deck=1.3, width=6.0):
    clear()
    conc = tmat("Concrete", "concrete", "ffffff", 0.9)
    steel = mat("Coping", "c9d0d6", 0.2, 0.9)
    prof = [(0.0, 0.0)]
    steps = 14
    th = math.radians(deg)
    for i in range(1, steps + 1):
        a = th * i / steps
        prof.append((-R * math.sin(a), R * (1 - math.cos(a))))
    zt, h = prof[-1]
    prof += [(zt - deck, h), (zt - deck, 0.0)]
    parts = [extrude_profile("ramp", prof, width, conc)]
    # coping sits flush on the deck just behind the lip, so it can't act as a wall
    parts.append(tube("coping", (-width / 2, h - 0.005, zt - 0.05), (width / 2, h - 0.005, zt - 0.05), 0.04, steel, 12))
    join(parts, "QuarterPipe")
    return export(name)

out.append(quarter_pipe("quarterpipe"))

# kicker: small launch wedge
clear()
wood = tmat("RampWood", "wood", "ffffff", 0.85)
steel = mat("Steel", "8d949c", 0.35, 0.8)
k = extrude_profile("kick", [(0, 0), (-1.8, 0.55), (-1.8, 0.0)], 1.6, wood, 1.0)
join([k, box("lip", (1.62, 0.04, 0.06), (0, 0.56, -1.8), steel, 0.01)], "Kicker")
out.append(export("kicker"))

# funbox: platform with slopes front and back and a rail on top
clear()
conc = tmat("Concrete", "concrete", "ffffff", 0.9)
yel = mat("RailYellow", "ffcc22", 0.4, 0.6)
fb = extrude_profile("fun", [(2.6, 0), (1.2, 0.5), (-1.2, 0.5), (-2.6, 0)], 3.0, conc, 1.5)
parts = [fb, tube("rail", (0, 0.95, -1.0), (0, 0.95, 1.0), 0.03, yel, 12)]
for z in (-0.9, 0.9):
    parts.append(tube("rp", (0, 0.5, z), (0, 0.95, z), 0.028, yel, 10))
join(parts, "Funbox")
out.append(export("funbox"))

# ---------------- BUS STOP (open to -Z, the street side)
clear()
pole = mat("StopPole", "3a3f45", 0.4, 0.7)
glassm = mat("StopGlass", "9fc4d8", 0.05, 0.2, None, 0, 0.35)
roofm = mat("StopRoof", "2a5d8f", 0.4, 0.3)
ad = tmat("Ad", "ads", "ffffff", 0.4, 0.0, False, "ffffff", 0.35)
parts = [box("roof", (3.4, 0.08, 1.5), (0, 2.45, 0), roofm, 0.02),
         box("back", (3.2, 1.9, 0.03), (0, 1.35, 0.65), glassm, 0.0),
         box("bench", (2.2, 0.06, 0.4), (0, 0.46, 0.4), wood if False else tmat("Wood", "wood", "ffffff", 0.85), 0.01),
         box("benchleg1", (0.06, 0.44, 0.3), (-0.9, 0.22, 0.4), pole), box("benchleg2", (0.06, 0.44, 0.3), (0.9, 0.22, 0.4), pole)]
for x in (-1.65, 1.65):
    for z in (-0.65, 0.65):
        parts.append(cyl("post", 0.04, 2.45, (x, 1.22, z), pole, "Y", 10))
# side ad box (lit), shows quarter 0 of the 4-up ads atlas; the game shifts uv for variety
parts.append(box("adbox", (0.12, 1.9, 1.05), (1.65, 1.35, 0.0), pole, 0.01))
parts.append(panel("AdPanel", 0.95, 1.8, (1.585, 1.35, 0.0), ad, (0, 0, 0.25, 1), "-X"))
parts.append(panel("AdPanel2", 0.95, 1.8, (1.715, 1.35, 0.0), ad, (0, 0, 0.25, 1), "+X"))
parts.append(box("signpole", (0.06, 2.9, 0.06), (-2.1, 1.45, -0.6), pole))
parts.append(cyl("sign", 0.28, 0.04, (-2.1, 2.75, -0.6), mat("BusSign", "1e6fd0", 0.4), "Z", 20))
join(parts, "BusStop")
out.append(export("busstop"))

# ---------------- STAIRS INC. sign (smashable sandwich board)
clear()
st = tmat("StairsSign", "stairs_sign", "ffffff", 0.6)
wd = mat("SignWood", "8a6a4a", 0.8)
parts = [box("board", (1.2, 0.62, 0.04), (0, 1.0, 0), wd, 0.01),
         panel("front", 1.16, 0.58, (0, 1.0, -0.022), st, (0, 0, 1, 1), "-Z"),
         panel("backf", 1.16, 0.58, (0, 1.0, 0.022), st, (0, 0, 1, 1), "+Z"),
         box("leg1", (0.06, 0.75, 0.06), (-0.5, 0.37, 0), wd), box("leg2", (0.06, 0.75, 0.06), (0.5, 0.37, 0), wd),
         box("foot", (1.3, 0.05, 0.35), (0, 0.025, 0), wd)]
join(parts, "StairsSign")
out.append(export("stairs_sign"))

# ---------------- DONUT BOX pickup
clear()
pink = mat("DonutBox", "ff8fc8", 0.6)
dough = mat("Dough", "d9a066", 0.7)
icing = mat("Icing", "ff4fb0", 0.3)
parts = [box("box", (0.5, 0.14, 0.5), (0, 0.07, 0), pink, 0.01),
         torus("donut", 0.1, 0.055, (0, 0.2, 0), dough, "Y", 20, 10),
         torus("ice", 0.1, 0.05, (0, 0.215, 0), icing, "Y", 20, 8)]
for i in range(8):
    a = i * math.tau / 8
    parts.append(box("spr%d" % i, (0.02, 0.01, 0.006), (math.cos(a) * 0.1, 0.268, math.sin(a) * 0.1), mat("Spr%d" % (i % 3), ["ffd84a", "7ee0ff", "39ff14"][i % 3], 0.4)))
join(parts, "Donuts")
out.append(export("donuts"))

# ---------------- MANHOLE / steam vent
clear()
iron = mat("Iron", "3a3a3c", 0.6, 0.8)
parts = [cyl("lid", 0.45, 0.03, (0, 0.015, 0), iron, "Y", 24)]
for i in range(-3, 4):
    parts.append(box("slot%d" % i, (0.6 - abs(i) * 0.08, 0.012, 0.03), (0, 0.035, i * 0.1), mat("Slot", "111111", 0.9)))
join(parts, "Manhole")
out.append(export("manhole"))
result = {"exported": out}
