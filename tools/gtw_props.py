# Grand Theft Wheelchair Blender export script
import bpy, bmesh, math, os

exec(open(os.path.expanduser(r"E:\Godot\GrandTheftWheelchair\tools\gtw_blender_lib.py")).read())
out = []
# ---------------- RIDER (seated, facing -Z in Godot / +Y in Blender)
clear()
skin = mat("Skin", "e8b48a", 0.65)
shirt = mat("Shirt", "3c8d2f", 0.85)
pants = mat("Pants", "2b3a55", 0.9)
hair = mat("Hair", "2b1d0e", 0.8)
shoe = mat("Shoes", "1a1a1a", 0.5)
black = mat("Black", "0a0a0a", 0.3)
white = mat("EyeWhite", "ffffff", 0.3)
lip = mat("Mouth", "7a2e2e", 0.6)
body = []
for s in (-1, 1):
    body.append(box("thigh%d" % s, (0.15, 0.14, 0.46), (s * 0.1, 0.6, -0.12), pants, 0.05))
    body.append(box("shin%d" % s, (0.13, 0.46, 0.14), (s * 0.1, 0.37, -0.37), pants, 0.05))
    body.append(box("shoe%d" % s, (0.13, 0.1, 0.25), (s * 0.1, 0.14, -0.44), shoe, 0.045))
    body.append(tube("upper%d" % s, (s * 0.2, 1.07, 0.08), (s * 0.27, 0.83, 0.13), 0.052, shirt, 14))
    body.append(sph("elbow%d" % s, 0.05, (s * 0.27, 0.83, 0.13), shirt, (1, 1, 1), 14, 8))
    body.append(tube("fore%d" % s, (s * 0.27, 0.83, 0.13), (s * 0.31, 0.65, 0.0), 0.044, skin, 14))
    body.append(sph("hand%d" % s, 0.052, (s * 0.31, 0.62, -0.02), skin, (0.9, 1.1, 1.1), 14, 8))
    body.append(sph("shoulder%d" % s, 0.065, (s * 0.2, 1.07, 0.08), shirt, (1, 1, 1), 16, 10))
    body.append(sph("ear%d" % s, 0.03, (s * 0.128, 1.33, 0.05), skin, (0.6, 1, 1), 12, 8))
    body.append(sph("eyew%d" % s, 0.024, (s * 0.046, 1.35, -0.072), white, (1, 1, 0.6), 12, 8))
    body.append(sph("eye%d" % s, 0.014, (s * 0.046, 1.35, -0.087), black, (1, 1, 0.6), 10, 6))
body.append(box("torso", (0.38, 0.6, 0.27), (0, 0.88, 0.08), shirt, 0.0, (0, 0, 0), 2))
body.append(box("hips", (0.34, 0.18, 0.3), (0, 0.6, 0.06), pants, 0.06))
body.append(tube("neck", (0, 1.15, 0.06), (0, 1.25, 0.05), 0.05, skin, 12))
body.append(sph("head", 0.13, (0, 1.33, 0.04), skin, (1, 1.05, 1), 28, 16))
body.append(sph("hair", 0.138, (0, 1.365, 0.075), hair, (1.02, 0.92, 1.0), 28, 16))
body.append(sph("nose", 0.022, (0, 1.31, -0.093), skin, (1, 1, 1), 12, 8))
body.append(box("mouth", (0.055, 0.012, 0.012), (0, 1.27, -0.1), lip))
join(body, "Body")
sh = join([box("lens", (0.21, 0.05, 0.02), (0, 1.35, -0.1), black, 0.008), box("arm1", (0.01, 0.01, 0.14), (-0.105, 1.355, -0.03), black), box("arm2", (0.01, 0.01, 0.14), (0.105, 1.355, -0.03), black)], "Shades")
navy = mat("Navy", "14213d", 0.6)
join([cyl("hat", 0.148, 0.075, (0, 1.465, 0.04), navy, "Y", 24, 0.01), box("brim", (0.2, 0.015, 0.1), (0, 1.435, -0.1), mat("Brim", "0d1626", 0.3), 0.005), sph("badge", 0.02, (0, 1.47, -0.105), mat("Badge", "ffd84a", 0.3, 0.9), (1, 1, 0.4))], "CopHat")
capm = mat("CapCloth", "e63946", 0.8)
join([sph("cap", 0.145, (0, 1.425, 0.05), capm, (1, 0.55, 1), 24, 12), box("bill", (0.17, 0.016, 0.13), (0, 1.41, -0.1), capm, 0.01)], "Cap")
goldm = mat("Gold", "ffd700", 0.2, 1.0, "6a4a00", 0.5)
cr = [cyl("band", 0.12, 0.06, (0, 1.5, 0.05), goldm, "Y", 20, 0.0, 0.11)]
for i in range(6):
    a = i * math.pi / 3
    cr.append(sph("pt%d" % i, 0.022, (math.cos(a) * 0.11, 1.55, 0.05 + math.sin(a) * 0.11), goldm, (1, 1.6, 1), 10, 6))
join(cr, "Crown")
join([box("pbox", (0.38, 0.06, 0.38), (0, 0.71, -0.2), mat("Cardboard", "c9a06a", 0.9), 0.005), box("plogo", (0.2, 0.005, 0.12), (0, 0.743, -0.2), mat("Logo", "d9452b", 0.8))], "PizzaBox")
out.append(export("rider"))

# ---------------- CARS
def car(taxi):
    clear()
    paint = mat("TaxiPaint" if taxi else "Paint", "ffcc00" if taxi else "457b9d", 0.25, 0.4)
    glass = mat("Glass", "1c2836", 0.05, 0.6)
    dark = mat("Trim", "222222", 0.6)
    chrome = mat("Chrome", "d0d6dc", 0.15, 1.0)
    hl = mat("Headlight", "fff7c2", 0.2, 0, "fff2b0", 3.0)
    parts = []
    parts.append(box("lower", (1.8, 0.55, 4.3), (0, 0.6, 0), paint, 0.14, (0, 0, 0)))
    parts.append(box("hood", (1.74, 0.12, 1.3), (0, 0.9, -1.45), paint, 0.06))
    parts.append(box("trunk", (1.74, 0.12, 0.9), (0, 0.9, 1.65), paint, 0.06))
    parts.append(box("cabin", (1.62, 0.5, 2.05), (0, 1.17, 0.25), glass, 0.12))
    parts.append(box("roof", (1.6, 0.08, 1.65), (0, 1.44, 0.3), paint, 0.05))
    for s in (-1, 1):
        parts.append(box("pillarA%d" % s, (0.07, 0.5, 0.12), (s * 0.79, 1.17, -0.72), paint, 0.02, (0.3, 0, 0)))
        parts.append(box("pillarB%d" % s, (0.07, 0.5, 0.1), (s * 0.8, 1.17, 0.3), paint, 0.02))
        parts.append(box("pillarC%d" % s, (0.07, 0.5, 0.12), (s * 0.79, 1.17, 1.22), paint, 0.02, (-0.35, 0, 0)))
        parts.append(box("mirror%d" % s, (0.14, 0.09, 0.12), (s * 0.96, 1.02, -0.62), paint, 0.03))
        parts.append(box("hl%d" % s, (0.38, 0.13, 0.06), (s * 0.58, 0.74, -2.15), hl, 0.03))
        parts.append(box("handle%d" % s, (0.02, 0.03, 0.16), (s * 0.905, 0.86, 0.0), chrome))
        parts.append(box("handle2%d" % s, (0.02, 0.03, 0.16), (s * 0.905, 0.86, 0.85), chrome))
    parts.append(box("bumperF", (1.86, 0.22, 0.16), (0, 0.42, -2.17), dark, 0.06))
    parts.append(box("bumperB", (1.86, 0.22, 0.16), (0, 0.42, 2.17), dark, 0.06))
    parts.append(box("grille", (0.8, 0.14, 0.04), (0, 0.6, -2.16), dark, 0.02))
    parts.append(box("plate", (0.4, 0.12, 0.02), (0, 0.55, 2.26), mat("Plate", "f0f0f0", 0.5)))
    for s in (-1, 1):
        for z in (-1.35, 1.35):
            parts.append(box("arch%d%s" % (s, z), (0.06, 0.5, 0.86), (s * 0.88, 0.45, z), mat("Arch", "141414", 0.9), 0.04))
    if taxi:
        parts.append(box("sign", (0.55, 0.16, 0.25), (0, 1.56, 0.35), mat("TaxiSign", "ffe680", 0.4, 0, "ffe680", 2.0), 0.03))
        parts.append(box("check", (1.82, 0.08, 4.0), (0, 0.78, 0), mat("Checker", "1a1a1a", 0.5)))
    join(parts, "Body")
    tl = mat("Taillight", "8a1010", 0.3, 0, "ff2020", 0.5)
    join([box("tl1", (0.38, 0.13, 0.06), (-0.58, 0.78, 2.15), tl, 0.03), box("tl2", (0.38, 0.13, 0.06), (0.58, 0.78, 2.15), tl, 0.03)], "Taillights")
    for n, p in [("WheelFL", (-0.86, 0.34, -1.35)), ("WheelFR", (0.86, 0.34, -1.35)), ("WheelBL", (-0.86, 0.34, 1.35)), ("WheelBR", (0.86, 0.34, 1.35))]:
        w = join([cyl(n + "t", 0.34, 0.24, p, mat("Tyre", "141414", 0.9), "X", 28, 0.05), cyl(n + "r", 0.22, 0.25, p, chrome, "X", 20, 0.02), cyl(n + "c", 0.08, 0.27, p, dark, "X", 12)], n)
        set_origin(w, g(*p))
    return export("car_taxi" if taxi else "car_sedan")
out.append(car(False))
out.append(car(True))

# ---------------- TREE
clear()
bark = mat("Bark", "6b4a2f", 0.9)
leaf1 = mat("Leaves", "3f7f34", 0.85)
leaf2 = mat("LeavesLight", "5fa449", 0.85)
parts = [cyl("trunk", 0.2, 2.8, (0, 1.4, 0), bark, "Y", 10, 0.0, 0.12)]
parts.append(tube("branch1", (0, 2.2, 0), (0.5, 3.0, 0.2), 0.07, bark, 8))
parts.append(tube("branch2", (0, 2.4, 0), (-0.5, 3.1, -0.3), 0.07, bark, 8))
for i, (p, r, m) in enumerate([((0, 3.4, 0), 1.6, leaf1), ((-0.6, 3.9, -0.4), 1.1, leaf2), ((0.7, 3.7, 0.4), 1.0, leaf2), ((0.1, 4.4, 0.1), 0.9, leaf1), ((-0.2, 3.1, 0.8), 0.9, leaf1)]):
    parts.append(ico("leaf%d" % i, r, p, m, (1, 0.85, 1), 1))
join(parts, "Tree")
out.append(export("tree"))

# ---------------- LAMP
clear()
pole = mat("Pole", "3a3f45", 0.45, 0.7)
parts = [cyl("base", 0.13, 0.4, (0, 0.2, 0), pole, "Y", 12, 0.02), cyl("pole", 0.06, 5.0, (0, 2.6, 0), pole, "Y", 12, 0.0, 0.045)]
parts.append(tube("arm", (0, 5.0, 0), (0, 5.25, -0.6), 0.04, pole, 8))
parts.append(tube("arm2", (0, 5.25, -0.6), (0, 5.2, -1.15), 0.04, pole, 8))
join(parts, "Pole")
join([box("hood", (0.34, 0.1, 0.5), (0, 5.17, -1.2), pole, 0.03)], "Hood")
box("Head", (0.28, 0.04, 0.42), (0, 5.11, -1.2), mat("LampGlow", "fff4c4", 0.3, 0, "ffe8a8", 2.0))
out.append(export("lamp"))
result = {"exported": out}
