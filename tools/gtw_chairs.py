# Grand Theft Wheelchair Blender export script
import bpy, bmesh, math, os

exec(open(os.path.expanduser(r"E:\Godot\GrandTheftWheelchair\tools\gtw_blender_lib.py")).read(), globals())

COLORS = {"rusty": "8a8f98", "hospital": "cfd8e0", "power": "2f7de1", "turbo": "e8343f", "monster": "3fb950", "cart": "b8c2cc", "cop": "1b2a4a", "gold": "f5c542"}

def wheel(name, r, w, pos, side, rim_col, big=False):
    tire = tmat("Tire", "tread", "ffffff", 0.85)
    metal = mat("Chrome", "dfe5ea", 0.12, 1.0)
    rimm = mat("Rim", rim_col, 0.3, 0.8)
    parts = []
    minor = 0.06 if big else 0.022
    parts.append(torus(name + "_t", r - minor, minor, pos, tire, "X", 40, 12))
    parts.append(torus(name + "_r", r - minor * 2 - 0.005, 0.012, pos, metal, "X", 36, 6))
    for i in range(12 if not big else 6):
        a = 2 * math.pi * i / (12 if not big else 6)
        rr = r - minor * 2 - 0.01
        tip = (pos[0] + (0.0 if not big else 0.0), pos[1] + math.cos(a) * rr, pos[2] + math.sin(a) * rr)
        hub_off = 0.025 * (1 if i % 2 == 0 else -1)
        parts.append(tube(name + "_s%d" % i, (pos[0] + hub_off, pos[1], pos[2]), tip, 0.005 if not big else 0.025, metal if not big else rimm, 6))
    parts.append(cyl(name + "_h", 0.04, w + 0.04, pos, metal, "X", 16))
    if big:
        parts.append(cyl(name + "_d", r - minor * 2, 0.02, pos, rimm, "X", 32))
    else:
        hx = pos[0] + side * (w / 2 + 0.035)
        parts.append(torus(name + "_hr", r * 0.8, 0.011, (hx, pos[1], pos[2]), rimm, "X", 36, 6))
        for k in range(4):
            a = k * math.pi / 2 + 0.4
            q = (pos[1] + math.cos(a) * r * 0.8, pos[2] + math.sin(a) * r * 0.8)
            parts.append(tube(name + "_c%d" % k, (pos[0], q[0], q[1]), (hx, q[0], q[1]), 0.006, metal, 6))
    o = join(parts, name)
    set_origin(o, g(*pos))
    return o

def caster(name, pos):
    tire = tmat("Tire", "tread", "ffffff", 0.85)
    metal = mat("Chrome", "dfe5ea", 0.12, 1.0)
    o = join([torus(name + "_t", 0.055, 0.02, pos, tire, "X", 20, 8), cyl(name + "_h", 0.03, 0.035, pos, metal, "X", 12)], name)
    set_origin(o, g(*pos))
    return o

def chair(t):
    clear()
    col = COLORS[t]
    gold = t == "gold"
    paint = mat("Paint", col, 0.22 if gold else 0.4, 1.0 if gold else 0.2)
    dark = paint if gold else mat("PaintDark", "%02x%02x%02x" % tuple(int(int(col[i:i+2], 16) * 0.62) for i in (0, 2, 4)), 0.6)
    metal = mat("Metal", "c0c7cf", 0.22, 0.95)
    black = mat("Black", "151515", 0.7)
    cushion = tmat("Cushion", "fabric", "3a3d44" if not gold else "8a1c2b", 0.9)
    objs = []
    empty("Seat", (0, -0.12, 0.05) if t == "cart" else (0, 0, 0))
    if t == "cart":
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
            caster(["CasterL", "CasterR", "CasterBL", "CasterBR"][i], p)
            objs.append(tube("leg%d" % i, (p[0], 0.08, p[2]), (p[0], 0.33, p[2]), 0.012, wire, 6))
        join(objs, "Frame")
        return export("chair_cart")
    big = t == "monster"
    r = 0.42 if big else 0.3
    w = 0.12 if big else 0.035
    wx = 0.42 if big else 0.33
    rim = {"gold": "fff1a8", "turbo": "ff5a5a", "cop": "4f8bff"}.get(t, "b0b8c0")
    wheel("WheelL", r, w, (-wx, r, 0.06), -1, rim, big)
    wheel("WheelR", r, w, (wx, r, 0.06), 1, rim, big)
    caster("CasterL", (-0.24, 0.075, -0.38))
    caster("CasterR", (0.24, 0.075, -0.38))
    for s in (-1, 1):
        x = s * 0.235
        objs.append(tube("fork%d" % s, (s * 0.24, 0.1, -0.38), (s * 0.24, 0.46, -0.36), 0.012, metal))
        objs.append(tube("rail%d" % s, (x, 0.46, -0.38), (x, 0.46, 0.24), 0.013, metal))
        objs.append(tube("up%d" % s, (s * 0.24, 0.46, 0.24), (s * 0.24, 1.0, 0.27), 0.013, metal))
        objs.append(tube("grip%d" % s, (s * 0.24, 1.0, 0.27), (s * 0.24, 1.0, 0.4), 0.02, black))
        objs.append(tube("leg%d" % s, (x, 0.46, -0.36), (s * 0.17, 0.14, -0.44), 0.012, metal))
        objs.append(tube("arm%d" % s, (s * 0.25, 0.66, -0.2), (s * 0.25, 0.66, 0.2), 0.016, black))
        objs.append(tube("armp%d" % s, (s * 0.25, 0.46, -0.15), (s * 0.25, 0.66, -0.15), 0.012, metal))
    objs.append(tube("axle", (-wx, r, 0.06), (wx, r, 0.06), 0.012, metal))
    objs.append(uvbox(box("SeatPad", (0.46, 0.07, 0.45), (0, 0.5, -0.02), cushion, 0.025), 0.5))
    objs.append(uvbox(box("BackPad", (0.42, 0.34, 0.04), (0, 0.77, 0.21), cushion, 0.018), 0.5))
    for s in (-1, 1):
        # clothing guards over the wheels, arm pads, brakes and anti-tip bars: the bits real chairs have
        objs.append(box("guard%d" % s, (0.012, 0.16, 0.3), (s * 0.27, 0.6, 0.02), paint, 0.004))
        objs.append(box("pad%d" % s, (0.06, 0.035, 0.3), (s * 0.25, 0.685, -0.02), black, 0.012))
        objs.append(box("brake%d" % s, (0.03, 0.04, 0.09), (s * 0.29, 0.47, -0.16), black, 0.008))
        objs.append(tube("tip%d" % s, (s * 0.2, 0.3, 0.27), (s * 0.2, 0.1, 0.5), 0.011, metal, 6))
        objs.append(cyl("tipw%d" % s, 0.025, 0.02, (s * 0.2, 0.1, 0.5), black, "X", 10))
    objs.append(box("SeatPan", (0.48, 0.025, 0.46), (0, 0.46, -0.02), paint, 0.008))
    objs.append(box("Back", (0.46, 0.4, 0.05), (0, 0.76, 0.24), dark, 0.02))
    objs.append(box("Foot", (0.34, 0.02, 0.13), (0, 0.13, -0.45), black, 0.006))
    if t == "power":
        objs.append(box("Battery", (0.42, 0.26, 0.32), (0, 0.27, 0.27), mat("Battery", "2b2b2b", 0.6), 0.02))
        objs.append(box("Led", (0.03, 0.02, 0.01), (0.12, 0.38, 0.435), mat("Led", "33ff55", 0.4, 0, "33ff55", 5.0)))
        objs.append(box("JoyBox", (0.07, 0.05, 0.14), (0.27, 0.7, -0.22), black, 0.01))
        objs.append(tube("Stick", (0.27, 0.72, -0.24), (0.27, 0.79, -0.24), 0.008, black))
        objs.append(sph("Knob", 0.022, (0.27, 0.8, -0.24), black))
    if t == "hospital":
        objs.append(tube("IV", (-0.26, 0.4, 0.28), (-0.26, 1.75, 0.28), 0.012, metal))
        objs.append(tube("IVt", (-0.34, 1.72, 0.28), (-0.18, 1.72, 0.28), 0.008, metal))
        objs.append(box("Bag", (0.1, 0.18, 0.04), (-0.2, 1.58, 0.28), mat("Bag", "a8dcff", 0.1, 0, None, 0, 0.6), 0.02))
        objs.append(box("Cross", (0.2, 0.06, 0.052), (0, 0.86, 0.24), mat("Red", "e63946", 0.5)))
        objs.append(box("Cross2", (0.06, 0.2, 0.052), (0, 0.86, 0.24), mat("Red", "e63946", 0.5)))
    if t == "turbo":
        objs.append(box("Spoiler", (0.62, 0.025, 0.14), (0, 1.08, 0.38), mat("Spoiler", "b01822", 0.3, 0.3), 0.01))
        for s in (-1, 1):
            objs.append(tube("sp%d" % s, (s * 0.2, 0.98, 0.3), (s * 0.2, 1.07, 0.37), 0.01, black))
        objs.append(box("Stripe", (0.08, 0.004, 0.44), (0, 0.537, -0.02), mat("Stripe", "ffb000", 0.4)))
    if t == "monster":
        cage = mat("Cage", "1d1d1d", 0.4, 0.6)
        for s in (-1, 1):
            objs.append(tube("cf%d" % s, (s * 0.5, 0.3, -0.3), (s * 0.5, 1.32, -0.3), 0.025, cage))
            objs.append(tube("cb%d" % s, (s * 0.5, 0.3, 0.32), (s * 0.5, 1.32, 0.32), 0.025, cage))
            objs.append(tube("ct%d" % s, (s * 0.5, 1.32, -0.3), (s * 0.5, 1.32, 0.32), 0.025, cage))
            objs.append(sph("Lamp%d" % s, 0.055, (s * 0.3, 1.32, -0.34), mat("Lamp", "fffbd0", 0.2, 0, "fffbd0", 6.0)))
        objs.append(tube("cx1", (-0.5, 1.32, -0.3), (0.5, 1.32, -0.3), 0.025, cage))
        objs.append(tube("cx2", (-0.5, 1.32, 0.32), (0.5, 1.32, 0.32), 0.025, cage))
    if t == "cop":
        objs.append(box("Stripe", (0.48, 0.004, 0.1), (0, 0.537, -0.02), mat("White", "ffffff", 0.5)))
        objs.append(box("Bar", (0.44, 0.05, 0.08), (0, 1.04, 0.28), black, 0.01))
        lr = box("LightRed", (0.14, 0.07, 0.08), (-0.12, 1.1, 0.28), mat("LightRedM", "ff2020", 0.3, 0, "ff2020", 4.0), 0.01)
        lb = box("LightBlue", (0.14, 0.07, 0.08), (0.12, 1.1, 0.28), mat("LightBlueM", "2050ff", 0.3, 0, "3060ff", 4.0), 0.01)
        for o in (lr, lb):
            bpy.context.view_layer.objects.active = o
            for md in list(o.modifiers):
                bpy.ops.object.modifier_apply(modifier=md.name)
    if t == "gold":
        gem = mat("Gem", "e63946", 0.15, 0.3, "e63946", 0.8)
        for s in (-1, 1):
            objs.append(sph("fin%d" % s, 0.045, (s * 0.24, 1.06, 0.27), paint))
            objs.append(box("garm%d" % s, (0.07, 0.06, 0.4), (s * 0.26, 0.68, -0.02), paint, 0.02))
        objs.append(box("Crest", (0.12, 0.22, 0.05), (0, 1.06, 0.25), paint, 0.02))
        objs.append(sph("Gem", 0.055, (0, 1.12, 0.22), gem))
    join(objs, "Frame")
    return export("chair_" + t)

out = []
for t in ["rusty", "hospital", "power", "turbo", "monster", "cart", "cop", "gold"]:
    out.append(chair(t))
result = {"exported": out}
