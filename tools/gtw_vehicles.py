# Grand Theft Wheelchair - cars with liveries, bushier trees and bushes (early-2000s style).
# Run inside Blender: exec(open(os.path.expanduser(r"E:\Godot\GrandTheftWheelchair\tools\gtw_vehicles.py")).read(), {"__name__": "gtw"})
import bpy, bmesh, math, os
exec(open(os.path.expanduser(r"E:\Godot\GrandTheftWheelchair\tools\gtw_blender_lib.py")).read(), globals())
out = []

def car(kind):
    """kind: sedan, taxi, van, hatch. Naming contract: Body, Taillights, WheelFL/FR/BL/BR, material Paint is recoloured."""
    clear()
    dims = {"sedan": (4.3, 1.8, 0.55, 2.05, 0.25), "taxi": (4.3, 1.8, 0.55, 2.05, 0.25),
            "hatch": (3.7, 1.75, 0.55, 1.9, 0.45), "van": (4.9, 1.95, 0.75, 3.6, 0.55)}[kind]
    L, W, lowh, cabl, cabz = dims
    paint_name = {"taxi": "TaxiPaint", "van": "VanPaint"}.get(kind, "Paint")
    paint_col = {"taxi": "ffcc00", "van": "f4efe6"}.get(kind, "ffffff")
    paint = tmat(paint_name, "car_panels", paint_col, 0.3, 0.35)
    glass = mat("Glass", "1c2836", 0.05, 0.6)
    dark = mat("Trim", "222222", 0.6)
    chrome = mat("Chrome", "d8dee4", 0.12, 1.0)
    hl = mat("Headlight", "fff7c2", 0.2, 0, "fff2b0", 3.0)
    parts = []
    parts.append(uvbox(box("lower", (W, lowh, L), (0, 0.33 + lowh / 2, 0), paint, 0.14), 1.2))
    if kind == "van":
        parts.append(uvbox(box("box", (W - 0.04, 1.15, cabl), (0, 0.33 + lowh + 0.575, 0.45), paint, 0.1), 1.2))
        parts.append(box("wind", (W - 0.14, 0.62, 0.06), (0, 0.33 + lowh + 0.5, 0.45 - cabl / 2 - 0.02), glass, 0.04, (0.3, 0, 0)))
        parts.append(uvbox(box("nose", (W - 0.06, 0.18, L - cabl - 0.2), (0, 0.33 + lowh + 0.09, -cabl / 2 - 0.25), paint, 0.06), 1.2))
        for s in (-1, 1):
            parts.append(box("sidewin%d" % s, (0.04, 0.42, 0.7), (s * (W / 2 - 0.01), 0.33 + lowh + 0.6, -0.85), glass, 0.02))
            liv = tmat("VanLivery", "van_livery", "ffffff", 0.5)
            u = (0, 0, 1, 1) if s > 0 else (1, 0, 0, 1)
            parts.append(panel("livery%d" % s, 2.6, 1.2, (s * (W / 2 + 0.012), 0.33 + lowh + 0.45, 0.85), liv, u, "+X" if s > 0 else "-X"))
        parts.append(box("pizza", (0.9, 0.35, 0.9), (0, 0.33 + lowh + 1.32, 0.6), mat("PizzaSign", "ff7a2b", 0.4, 0, "ff9a40", 1.2), 0.08))
    else:
        top = 0.33 + lowh
        parts.append(uvbox(box("hood", (W - 0.06, 0.12, 1.3), (0, top + 0.06, -L / 2 + 0.7), paint, 0.06), 1.2))
        if kind != "hatch":
            parts.append(uvbox(box("trunk", (W - 0.06, 0.12, 0.9), (0, top + 0.06, L / 2 - 0.5), paint, 0.06), 1.2))
        parts.append(box("cabin", (W - 0.18, 0.5, cabl), (0, top + 0.31, cabz), glass, 0.12))
        parts.append(uvbox(box("roof", (W - 0.2, 0.08, cabl - 0.4), (0, top + 0.58, cabz + 0.05), paint, 0.05), 1.2))
        for s in (-1, 1):
            parts.append(box("pillarA%d" % s, (0.07, 0.5, 0.12), (s * (W / 2 - 0.11), top + 0.31, cabz - cabl / 2 + 0.06), paint, 0.02, (0.3, 0, 0)))
            parts.append(box("pillarC%d" % s, (0.07, 0.5, 0.12), (s * (W / 2 - 0.11), top + 0.31, cabz + cabl / 2 - 0.06), paint, 0.02, (-0.35, 0, 0)))
        if kind == "taxi":
            parts.append(box("sign", (0.55, 0.16, 0.25), (0, top + 0.7, cabz + 0.1), mat("TaxiSign", "ffe680", 0.4, 0, "ffe680", 2.0), 0.03))
            liv = tmat("TaxiLivery", "taxi_livery", "ffffff", 0.5)
            for s in (-1, 1):
                u = (0, 0, 1, 1) if s > 0 else (1, 0, 0, 1)
                parts.append(panel("check%d" % s, 3.2, 0.28, (s * (W / 2 + 0.012), 0.72, 0.0), liv, u, "+X" if s > 0 else "-X"))
        if kind == "hatch":
            parts.append(box("spoiler", (W - 0.3, 0.05, 0.25), (0, top + 0.62, cabz + cabl / 2 - 0.05), dark, 0.02))
    for s in (-1, 1):
        parts.append(box("mirror%d" % s, (0.14, 0.09, 0.12), (s * (W / 2 + 0.06), 0.33 + lowh + 0.15, -L / 2 + 1.55), paint, 0.03))
        parts.append(box("hl%d" % s, (0.38, 0.13, 0.06), (s * (W / 2 - 0.32), 0.33 + lowh * 0.75, -L / 2), hl, 0.03))
        parts.append(box("handle%d" % s, (0.02, 0.03, 0.16), (s * (W / 2 + 0.005), 0.33 + lowh * 0.85, 0.0), chrome))
        for z in (-L / 2 + 0.9, L / 2 - 0.9):
            parts.append(box("arch%d%s" % (s, z), (0.06, 0.5, 0.86), (s * (W / 2 - 0.02), 0.45, z), mat("Arch", "141414", 0.9), 0.04))
    parts.append(box("bumperF", (W + 0.06, 0.22, 0.16), (0, 0.42, -L / 2 - 0.02), chrome if kind == "sedan" else dark, 0.06))
    parts.append(box("bumperB", (W + 0.06, 0.22, 0.16), (0, 0.42, L / 2 + 0.02), chrome if kind == "sedan" else dark, 0.06))
    parts.append(box("grille", (0.8, 0.14, 0.04), (0, 0.33 + lowh * 0.5, -L / 2 - 0.01), dark, 0.02))
    parts.append(box("plate", (0.4, 0.12, 0.02), (0, 0.55, L / 2 + 0.11), mat("Plate", "f0f0f0", 0.5)))
    join(parts, "Body")
    tl = mat("Taillight", "8a1010", 0.3, 0, "ff2020", 0.5)
    ty = 0.33 + lowh * 0.8
    join([box("tl1", (0.3, 0.14, 0.06), (-(W / 2 - 0.28), ty, L / 2), tl, 0.03), box("tl2", (0.3, 0.14, 0.06), ((W / 2 - 0.28), ty, L / 2), tl, 0.03)], "Taillights")
    wz = L / 2 - 0.9
    for n, p in [("WheelFL", (-(W / 2 - 0.04), 0.34, -wz)), ("WheelFR", ((W / 2 - 0.04), 0.34, -wz)), ("WheelBL", (-(W / 2 - 0.04), 0.34, wz)), ("WheelBR", ((W / 2 - 0.04), 0.34, wz))]:
        tyre = tmat("Tyre", "tread", "ffffff", 0.9)
        w = join([torus(n + "t", 0.25, 0.09, p, tyre, "X", 28, 10), cyl(n + "r", 0.22, 0.2, p, chrome, "X", 20, 0.02), cyl(n + "c", 0.08, 0.22, p, dark, "X", 12)], n)
        set_origin(w, g(*p))
    return export("car_" + kind)

for k in ["sedan", "taxi", "hatch", "van"]:
    out.append(car(k))

# ---------------- TREES: trunk + several bumpy leaf clusters
def bumpy(name, r, pos, m, seed, scl=(1, 0.85, 1)):
    o = ico(name, r, pos, m, scl, 2)
    import random
    rnd = random.Random(seed)
    for v in o.data.vertices:
        v.co *= 1.0 + (rnd.random() - 0.5) * 0.28
    uvbox(o, 1.2)
    for p in o.data.polygons:
        p.use_smooth = True
    return o

for variant in (0, 1):
    clear()
    bark = tmat("Bark", "bark", "ffffff", 0.95)
    leaf1 = tmat("Leaves", "leaves", "ffffff", 0.85)
    leaf2 = tmat("LeavesLight", "leaves", "b8e08a", 0.85)
    parts = [uvbox(cyl("trunk", 0.2, 2.8, (0, 1.4, 0), bark, "Y", 10, 0.0, 0.12), 0.6)]
    parts.append(tube("branch1", (0, 2.2, 0), (0.6, 3.1, 0.2), 0.08, bark, 8))
    parts.append(tube("branch2", (0, 2.4, 0), (-0.6, 3.2, -0.3), 0.08, bark, 8))
    parts.append(tube("branch3", (0, 2.6, 0), (0.1, 3.4, 0.7), 0.07, bark, 8))
    clusters = [((0, 3.5, 0), 1.5, leaf1), ((-0.8, 3.9, -0.4), 1.1, leaf2), ((0.9, 3.8, 0.3), 1.05, leaf2),
                ((0.1, 4.5, 0.1), 1.0, leaf1), ((-0.3, 3.2, 0.9), 0.95, leaf1), ((0.5, 3.1, -0.8), 0.9, leaf2),
                ((-1.0, 3.2, 0.5), 0.8, leaf1)]
    if variant == 1:
        clusters = [((0, 3.9, 0), 1.2, leaf1), ((0, 4.9, 0), 0.95, leaf2), ((0, 5.7, 0), 0.65, leaf1), ((0.5, 3.6, 0.4), 0.8, leaf2), ((-0.5, 3.7, -0.4), 0.8, leaf2)]
    for i, (p, r, m) in enumerate(clusters):
        parts.append(bumpy("leaf%d" % i, r, p, m, i + variant * 10))
    join(parts, "Tree")
    out.append(export("tree" if variant == 0 else "tree_tall"))

clear()
leaf1 = tmat("Leaves", "leaves", "ffffff", 0.85)
parts = [bumpy("b%d" % i, r, p, leaf1, 40 + i, (1.2, 0.7, 1.0)) for i, (p, r) in enumerate([((0, 0.45, 0), 0.6), ((0.55, 0.4, 0.1), 0.45), ((-0.5, 0.38, -0.1), 0.45)])]
join(parts, "Bush")
out.append(export("bush"))
result = {"exported": out}
