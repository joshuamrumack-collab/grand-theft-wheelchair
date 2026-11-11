"""Paints the hand-made, early-2000s-skate-game style textures for Grand Theft Wheelchair.
Run with plain Python 3 + Pillow + numpy:  python tools/gtw_textures.py
Writes PNGs to assets/textures/. Tintable textures (cloth, hair) are painted in light grey so the
game can recolour them; decals (faces, prints, signs) carry their own colour.
"""
import os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures")
os.makedirs(OUT, exist_ok=True)
R = random.Random(7)
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
for cand in ["C:/Windows/Fonts/impact.ttf", "C:/Windows/Fonts/ariblk.ttf"]:
    if os.path.exists(cand):
        BOLD = cand
        break

def font(size):
    return ImageFont.truetype(BOLD, size)

def noise(w, h, scale, octaves=4, seed=0):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        s = max(1, int(scale / (2 ** o)))
        g = rng.random((h // s + 2, w // s + 2))
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((w + 2 * s, h + 2 * s), Image.BICUBIC)
        out += np.asarray(img, dtype=float)[s:s + h, s:s + w] / 255.0 * amp
        tot += amp
        amp *= 0.5
    return out / tot

def save(img, name):
    img.save(os.path.join(OUT, name + ".png"))
    print("wrote", name)

def grey_from(arr, lo, hi):
    a = np.clip(lo + (hi - lo) * arr, 0, 1)
    return Image.fromarray((a * 255).astype(np.uint8)).convert("RGB")

# ------------------------------------------------------------------ CLOTH (tintable)
def cloth_shirt():
    w = h = 256
    n = noise(w, h, 32, 4, 1)
    fine = noise(w, h, 2, 1, 2)
    a = 0.80 + (n - 0.5) * 0.18 + (fine - 0.5) * 0.06
    img = grey_from(a, 0, 1)
    d = ImageDraw.Draw(img)
    # folds / wrinkles
    for i in range(7):
        x = R.randint(0, w); y = R.randint(0, h)
        pts = [(x + k * 7, y + int(math.sin(k * 0.8 + i) * 4) + k * 2) for k in range(4)]
        d.line(pts, fill=(176, 176, 176), width=4)
        d.line([(p[0] + 2, p[1] - 3) for p in pts], fill=(225, 225, 225), width=2)
    # hem stitching
    for y in (6, 250):
        for x in range(0, w, 8):
            d.line([(x, y), (x + 4, y)], fill=(120, 120, 120), width=2)
    img = img.filter(ImageFilter.GaussianBlur(1.4))
    save(img, "cloth_shirt")

def cloth_denim():
    w = h = 256
    base = noise(w, h, 48, 4, 3)
    yy, xx = np.mgrid[0:h, 0:w]
    twill = ((xx + yy) % 4 < 2).astype(float)
    a = 0.70 + (base - 0.5) * 0.3 + twill * 0.06
    # faded knees / thighs
    fade = np.exp(-(((xx - 128) / 70.0) ** 2 + ((yy - 128) / 50.0) ** 2))
    a += fade * 0.12
    img = grey_from(a, 0, 1)
    d = ImageDraw.Draw(img)
    for x in (4, 250):  # side seams
        d.line([(x, 0), (x, h)], fill=(110, 110, 110), width=3)
        for y in range(0, h, 9):
            d.line([(x + 4, y), (x + 4, y + 4)], fill=(230, 230, 230), width=1)
    for i in range(10):
        y = R.randint(20, 236)
        d.arc([R.randint(0, 120), y, R.randint(140, 256), y + 14], 200, 340, fill=(120, 120, 120), width=2)
    save(img.filter(ImageFilter.GaussianBlur(0.5)), "cloth_denim")

def hair():
    w = h = 128
    rng = np.random.default_rng(5)
    a = np.zeros((h, w))
    for x in range(w):
        a[:, x] = rng.random() * 0.5
    a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)), float) / 255
    a = 0.6 + a * 0.5 + (noise(w, h, 16, 2, 6) - 0.5) * 0.2
    save(grey_from(a, 0, 1), "hair")

def skin():
    w = h = 128
    a = 0.93 + (noise(w, h, 24, 3, 9) - 0.5) * 0.08
    save(grey_from(a, 0, 1), "skin")

# ------------------------------------------------------------------ FACES (2x2 atlas, alpha decal)
def faces():
    S = 256
    atlas = Image.new("RGBA", (S * 2, S * 2), (0, 0, 0, 0))
    eye_cols = [(70, 45, 25), (40, 90, 150), (40, 110, 60), (20, 20, 20)]
    for idx in range(4):
        f = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        d = ImageDraw.Draw(f)
        cx = S // 2
        ey = 108
        for s in (-1, 1):
            ex = cx + s * 46
            # eye white with slight almond shape
            d.ellipse([ex - 22, ey - 12, ex + 22, ey + 12], fill=(250, 248, 240, 255))
            d.ellipse([ex - 11 + s * 2, ey - 11, ex + 11 + s * 2, ey + 11], fill=(*eye_cols[idx], 255))
            d.ellipse([ex - 5 + s * 2, ey - 5, ex + 5 + s * 2, ey + 5], fill=(10, 10, 10, 255))
            d.ellipse([ex - 4, ey - 8, ex + 1, ey - 3], fill=(255, 255, 255, 255))
            # upper lid line + lashes
            d.arc([ex - 23, ey - 14, ex + 23, ey + 12], 190, 350, fill=(30, 20, 15, 255), width=5)
            # brows: each face a different attitude
            tilt = [0, -8, 6, -14][idx] * s
            d.line([(ex - 24, ey - 30 + (tilt if s < 0 else 0)), (ex + 24, ey - 30 + (0 if s < 0 else -tilt))], fill=(40, 25, 15, 255), width=9)
        # nose shadow
        d.line([(cx - 6, ey + 18), (cx - 10, ey + 52), (cx + 4, ey + 56)], fill=(120, 70, 50, 110), width=4)
        # mouth: grin / smirk / determined / big smile
        my = 196
        if idx == 0:
            d.arc([cx - 40, my - 30, cx + 40, my + 14], 20, 160, fill=(110, 40, 40, 255), width=7)
        elif idx == 1:
            d.line([(cx - 30, my), (cx + 10, my + 2), (cx + 32, my - 10)], fill=(110, 40, 40, 255), width=7)
        elif idx == 2:
            d.line([(cx - 28, my), (cx + 28, my)], fill=(110, 40, 40, 255), width=7)
        else:
            d.chord([cx - 38, my - 26, cx + 38, my + 20], 0, 180, fill=(120, 30, 40, 255))
            d.rectangle([cx - 30, my - 4, cx + 30, my + 4], fill=(250, 250, 250, 255))
        # cheek blush
        for s in (-1, 1):
            d.ellipse([cx + s * 62 - 18, 150, cx + s * 62 + 18, 172], fill=(220, 90, 80, 40))
        f = f.filter(ImageFilter.GaussianBlur(0.8))
        atlas.paste(f, ((idx % 2) * S, (idx // 2) * S))
    save(atlas, "faces")

# ------------------------------------------------------------------ SHIRT PRINTS (2x2 atlas)
def prints():
    S = 256
    atlas = Image.new("RGBA", (S * 2, S * 2), (0, 0, 0, 0))
    # 0: GTW logo
    p = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(p)
    d.ellipse([28, 28, 228, 228], outline=(255, 255, 255, 255), width=14)
    d.text((128, 128), "GTW", font=font(84), fill=(255, 216, 74, 255), anchor="mm", stroke_width=6, stroke_fill=(20, 20, 20, 255))
    atlas.paste(p, (0, 0))
    # 1: flaming wheel
    p = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(p)
    for i in range(7):
        x = 40 + i * 28
        d.polygon([(x - 14, 170), (x + 14, 170), (x + R.randint(-10, 10), 40 + R.randint(0, 50))], fill=(255, 120 + i * 15, 30, 255))
    d.ellipse([70, 110, 186, 226], outline=(20, 20, 20, 255), width=16)
    d.ellipse([82, 122, 174, 214], outline=(230, 230, 230, 255), width=6)
    for k in range(8):
        a = k * math.pi / 4
        d.line([(128, 168), (128 + math.cos(a) * 46, 168 + math.sin(a) * 46)], fill=(230, 230, 230, 255), width=4)
    atlas.paste(p, (S, 0))
    # 2: RAMP OR DIE text tee
    p = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(p)
    d.text((128, 92), "RAMP", font=font(70), fill=(255, 61, 127, 255), anchor="mm", stroke_width=5, stroke_fill=(255, 255, 255, 255))
    d.text((128, 168), "OR DIE", font=font(56), fill=(255, 255, 255, 255), anchor="mm", stroke_width=5, stroke_fill=(20, 20, 20, 255))
    atlas.paste(p, (0, S))
    # 3: lightning star
    p = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(p)
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = 110 if k % 2 == 0 else 46
        pts.append((128 + math.cos(a) * r, 128 + math.sin(a) * r))
    d.polygon(pts, fill=(126, 224, 255, 255), outline=(20, 20, 20, 255))
    d.polygon([(140, 50), (96, 140), (128, 140), (110, 210), (164, 110), (132, 110)], fill=(255, 216, 74, 255), outline=(20, 20, 20, 255))
    atlas.paste(p, (S, S))
    save(atlas, "prints")

# ------------------------------------------------------------------ SHOES
def shoes():
    w = h = 128
    a = 0.30 + (noise(w, h, 12, 3, 11) - 0.5) * 0.12
    img = grey_from(a, 0, 1)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 96, w, h], fill=(238, 236, 228))          # vulcanised sole
    d.line([(0, 100), (w, 100)], fill=(30, 30, 30), width=3)   # foxing stripe
    for y in range(20, 80, 12):                               # laces
        d.line([(40, y), (88, y + 6)], fill=(245, 245, 245), width=4)
        d.line([(88, y), (40, y + 6)], fill=(245, 245, 245), width=4)
    d.arc([10, 30, 118, 120], 200, 330, fill=(240, 240, 240), width=6)  # side swoosh-ish stripe (generic)
    save(img, "shoes")

# ------------------------------------------------------------------ PROPS / WORLD
def metal_paint(name, rgb, label=None, seed=0):
    w = h = 256
    n = noise(w, h, 40, 4, seed)
    rust = noise(w, h, 18, 3, seed + 1)
    img = Image.new("RGB", (w, h), rgb)
    arr = np.asarray(img, float)
    arr *= (0.85 + n[..., None] * 0.25)
    rm = np.clip((rust - 0.62) * 5, 0, 1)[..., None]
    arr = arr * (1 - rm) + np.array([120, 62, 30]) * rm
    # vertical drips and dents
    for i in range(20):
        x = R.randint(0, w - 1)
        arr[R.randint(0, 60):, x:x + 2] *= 0.86
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    if label:
        d.text((w // 2, h // 2), label, font=font(42), fill=(240, 240, 230), anchor="mm")
    save(img, name)

def concrete(name, seed, tone=170, cracks=6, tiles=0, spots=30):
    w = h = 256
    n = noise(w, h, 60, 5, seed)
    sp = noise(w, h, 2, 1, seed + 3)
    a = (tone / 255) + (n - 0.5) * 0.22 + (sp - 0.5) * 0.08
    img = grey_from(a, 0, 1)
    d = ImageDraw.Draw(img)
    if tiles:
        step = w // tiles
        for k in range(0, w + 1, step):
            d.line([(k, 0), (k, h)], fill=(110, 110, 110), width=3)
            d.line([(0, k), (w, k)], fill=(110, 110, 110), width=3)
    for i in range(cracks):
        x, y = R.randint(0, w), R.randint(0, h)
        pts = [(x, y)]
        for k in range(R.randint(4, 9)):
            x += R.randint(-14, 14); y += R.randint(-14, 14)
            pts.append((x, y))
        d.line(pts, fill=(max(0, tone - 60),) * 3, width=1)
    # gum spots and stains
    for i in range(spots):
        x, y = R.randint(0, w), R.randint(0, h)
        r = R.randint(1, 3)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(max(0, tone - 45),) * 3)
    save(img, name)

def asphalt():
    w = h = 256
    n = noise(w, h, 80, 5, 21)
    grit = np.random.default_rng(2).random((h, w))
    a = 0.30 + (n - 0.5) * 0.12 + (grit - 0.5) * 0.12
    img = grey_from(a, 0, 1)
    d = ImageDraw.Draw(img)
    for i in range(5):  # tar snakes
        x, y = R.randint(0, w), R.randint(0, h)
        pts = [(x, y)]
        for k in range(8):
            x += R.randint(-20, 20); y += R.randint(4, 24)
            pts.append((x, y))
        d.line(pts, fill=(48, 48, 48), width=3)
    for i in range(3):  # oil stains
        x, y = R.randint(30, 220), R.randint(30, 220)
        d.ellipse([x - 26, y - 14, x + 26, y + 14], fill=(45, 45, 50))
    save(img.filter(ImageFilter.GaussianBlur(0.4)), "asphalt")

def brick():
    w = h = 256
    img = Image.new("RGB", (w, h), (205, 205, 200))
    d = ImageDraw.Draw(img)
    bh, bw = 16, 42
    for row in range(h // bh + 1):
        off = (row % 2) * bw // 2
        for col in range(-1, w // bw + 2):
            x = col * bw + off
            v = R.randint(-20, 14)
            c = (210 + v, 210 + v, 205 + v)
            d.rectangle([x + 2, row * bh + 2, x + bw - 2, row * bh + bh - 2], fill=c)
    arr = np.asarray(img, float) * (0.9 + noise(w, h, 30, 3, 31)[..., None] * 0.18)
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)), "brick")

def wood():
    w = h = 256
    yy, xx = np.mgrid[0:h, 0:w]
    n = noise(w, h, 24, 3, 41)
    grain = np.sin(yy * 0.35 + n * 9) * 0.5 + 0.5
    base = np.array([150, 98, 55], float)
    arr = base * (0.75 + grain[..., None] * 0.3)
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    for y in range(0, h, 64):
        d.line([(0, y), (w, y)], fill=(70, 40, 20), width=4)
    save(img, "wood")

def newsbox():
    w, h = 256, 256
    img = Image.new("RGB", (w, h), (30, 90, 170))
    d = ImageDraw.Draw(img)
    d.rectangle([20, 20, 236, 70], fill=(240, 240, 235))
    d.text((128, 45), "DAILY SPOKE", font=font(30), fill=(20, 20, 20), anchor="mm")
    d.rectangle([30, 90, 226, 200], fill=(170, 200, 210), outline=(20, 20, 20), width=5)
    d.text((128, 120), "BARON BUYS", font=font(20), fill=(20, 20, 20), anchor="mm")
    d.text((128, 150), "MORE STAIRS", font=font(24), fill=(200, 20, 20), anchor="mm")
    d.rectangle([100, 215, 156, 230], fill=(200, 200, 200))
    save(img, "newsbox")

def vending():
    w, h = 256, 512
    img = Image.new("RGB", (w, h), (200, 30, 40))
    d = ImageDraw.Draw(img)
    d.rectangle([16, 16, 170, 400], fill=(40, 40, 50))
    for row in range(6):
        for col in range(4):
            x = 26 + col * 36; y = 28 + row * 60
            c = [(255, 216, 74), (57, 255, 20), (126, 224, 255), (255, 79, 176)][(row + col) % 4]
            d.rounded_rectangle([x, y, x + 24, y + 48], 6, fill=c)
    d.text((95, 440), "RUSH", font=font(54), fill=(255, 255, 255), anchor="mm", stroke_width=3, stroke_fill=(20, 20, 20))
    d.rectangle([186, 60, 236, 200], fill=(30, 30, 30))
    d.rectangle([190, 220, 232, 260], fill=(200, 200, 200))
    save(img, "vending")

def posters():
    S = 256
    atlas = Image.new("RGB", (S * 2, S * 2))
    specs = [
        ((255, 216, 74), "SKATE\nOR ROLL", (20, 20, 20)),
        ((40, 30, 70), "RIM\nREAPERS\nLIVE!", (255, 79, 176)),
        ((57, 200, 120), "RAMPS\nNOT\nSTAIRS", (255, 255, 255)),
        ((230, 230, 225), "LOST:\nONE\nSTAIR-\nCASE", (200, 20, 20)),
    ]
    for i, (bg, txt, fg) in enumerate(specs):
        p = Image.new("RGB", (S, S), bg)
        d = ImageDraw.Draw(p)
        d.multiline_text((S // 2, S // 2), txt, font=font(46), fill=fg, anchor="mm", align="center", spacing=6)
        arr = np.asarray(p, float) * (0.85 + noise(S, S, 40, 3, 50 + i)[..., None] * 0.2)
        atlas.paste(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)), ((i % 2) * S, (i // 2) * S))
    save(atlas, "posters")

def chainlink():
    w = h = 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    step = 16
    for k in range(-h, w + h, step):
        d.line([(k, 0), (k + h, h)], fill=(190, 195, 200, 255), width=2)
        d.line([(k, h), (k + h, 0)], fill=(160, 165, 170, 255), width=2)
    save(img, "chainlink")

def hazard():
    w = h = 128
    img = Image.new("RGB", (w, h), (255, 200, 0))
    d = ImageDraw.Draw(img)
    for k in range(-w, w * 2, 32):
        d.polygon([(k, 0), (k + 16, 0), (k + 16 + h, h), (k + h, h)], fill=(25, 25, 25))
    save(img, "hazard")

# ------------------------------------------------------------------ CHAIRS / CARS / TREES (pass 2)
def tread():
    w, h = 64, 256
    img = Image.new("RGB", (w, h), (30, 30, 30))
    d = ImageDraw.Draw(img)
    for y in range(0, h, 10):
        d.polygon([(6, y), (28, y + 5), (6, y + 8)], fill=(18, 18, 18))
        d.polygon([(58, y + 4), (36, y + 9), (58, y + 12)], fill=(18, 18, 18))
    d.line([(32, 0), (32, h)], fill=(12, 12, 12), width=3)
    arr = np.asarray(img, float) * (0.85 + noise(w, h, 8, 2, 80)[..., None] * 0.3)
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)), "tread")

def fabric():
    w = h = 128
    yy, xx = np.mgrid[0:h, 0:w]
    weave = (((xx // 2) + (yy // 2)) % 2) * 0.08
    a = 0.75 + weave + (noise(w, h, 16, 3, 81) - 0.5) * 0.15
    img = grey_from(a, 0, 1)
    d = ImageDraw.Draw(img)
    for y in (8, 120):  # piping / stitching
        for x in range(0, w, 6):
            d.line([(x, y), (x + 3, y)], fill=(250, 250, 250), width=1)
    save(img, "fabric")

def bark():
    w, h = 128, 256
    n = noise(w, h, 10, 3, 82)
    yy, xx = np.mgrid[0:h, 0:w]
    ridges = np.abs(np.sin(xx * 0.25 + n * 6)) ** 0.5
    arr = np.array([96, 68, 44], float) * (0.6 + ridges[..., None] * 0.55)
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)), "bark")

def leaves():
    w = h = 256
    img = Image.new("RGB", (w, h), (52, 105, 44))
    d = ImageDraw.Draw(img)
    for i in range(900):
        x, y = R.randint(0, w), R.randint(0, h)
        g = R.randint(80, 170)
        c = (int(g * 0.45), g, int(g * 0.35))
        a = R.random() * math.tau
        L = R.randint(5, 11)
        d.ellipse([x - L, y - L // 2, x + L, y + L // 2], fill=c)
        d.line([(x - math.cos(a) * L, y - math.sin(a) * L), (x + math.cos(a) * L, y + math.sin(a) * L)], fill=(int(g * 0.3), int(g * 0.7), int(g * 0.25)), width=1)
    save(img.filter(ImageFilter.GaussianBlur(0.5)), "leaves")

def car_panels():
    # light grey so the game can tint the paint; door seams, grime near the sills
    w = h = 256
    a = 0.88 + (noise(w, h, 40, 3, 83) - 0.5) * 0.06
    yy = np.mgrid[0:h, 0:w][0]
    a = a - np.clip((yy - 200) / 56.0, 0, 1) * 0.18
    img = grey_from(a, 0, 1)
    d = ImageDraw.Draw(img)
    for x in (70, 150):
        d.line([(x, 40), (x, 210)], fill=(120, 120, 120), width=2)
    d.line([(0, 120), (w, 120)], fill=(200, 200, 200), width=2)
    save(img, "car_panels")

def van_livery():
    w, h = 512, 256
    img = Image.new("RGB", (w, h), (245, 240, 230))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 180, w, h], fill=(255, 122, 43))
    d.ellipse([20, 30, 170, 180], fill=(240, 190, 90), outline=(150, 60, 20), width=8)
    for k in range(6):
        a = k * math.pi / 3
        d.line([(95, 105), (95 + math.cos(a) * 70, 105 + math.sin(a) * 70)], fill=(150, 60, 20), width=4)
    for i in range(9):
        x, y = R.randint(50, 140), R.randint(60, 150)
        d.ellipse([x - 9, y - 9, x + 9, y + 9], fill=(200, 40, 40))
    d.text((340, 80), "ROLLING", font=font(56), fill=(220, 50, 30), anchor="mm", stroke_width=4, stroke_fill=(255, 255, 255))
    d.text((340, 140), "PIZZA", font=font(64), fill=(220, 50, 30), anchor="mm", stroke_width=4, stroke_fill=(255, 255, 255))
    d.text((340, 212), "WE DELIVER ON WHEELS", font=font(24), fill=(255, 255, 255), anchor="mm")
    save(img, "van_livery")

def taxi_livery():
    w, h = 256, 64
    img = Image.new("RGB", (w, h), (255, 204, 0))
    d = ImageDraw.Draw(img)
    for i in range(0, w, 16):
        for j in range(2):
            if (i // 16 + j) % 2 == 0:
                d.rectangle([i, 8 + j * 12, i + 15, 19 + j * 12], fill=(20, 20, 20))
    d.text((w // 2, 48), "SPOKOS CAB", font=font(18), fill=(20, 20, 20), anchor="mm")
    save(img, "taxi_livery")

# ------------------------------------------------------------------ STREET pass 2
def ads():
    S = 256
    atlas = Image.new("RGB", (S * 2, S * 4))
    specs = [((255, 79, 176), "RUSH\nENERGY", (255, 255, 255), "now with 30% more ramp"),
             ((30, 30, 40), "WHEEL FM\n101.7", (255, 216, 74), "the wheel deal"),
             ((57, 200, 120), "VOTE\nRAMPS", (255, 255, 255), "not stairs"),
             ((126, 224, 255), "SKATE\nPLAZA", (20, 20, 20), "opening soon"),
             ((255, 216, 74), "ROLLING\nPIZZA", (200, 30, 30), "hot in 30 min"),
             ((120, 40, 160), "RIM\nREAPERS", (255, 255, 255), "street racing is a lifestyle"),
             ((240, 240, 235), "STAIRS\nINC.", (60, 60, 60), "a step above (we insist)"),
             ((255, 120, 40), "PIMP MY\nCHAIR", (255, 255, 255), "rims rims rims")]
    for i, (bg, txt, fg, small) in enumerate(specs):
        p = Image.new("RGB", (S, S * 2), bg)
        d = ImageDraw.Draw(p)
        d.multiline_text((S // 2, S - 30), txt, font=font(60), fill=fg, anchor="mm", align="center", spacing=8)
        d.text((S // 2, S * 2 - 50), small, font=font(18), fill=fg, anchor="mm")
        d.rectangle([6, 6, S - 7, S * 2 - 7], outline=fg, width=4)
        atlas.paste(p.resize((S, S * 2)), ((i % 2) * S, (i // 2) * S if False else 0))
    # 4 tall ads (256x512 each) laid out 4x1 -> 1024x512 atlas
    atlas = Image.new("RGB", (S * 4, S * 2))
    for i, (bg, txt, fg, small) in enumerate(specs[:4]):
        p = Image.new("RGB", (S, S * 2), bg)
        d = ImageDraw.Draw(p)
        d.multiline_text((S // 2, S - 30), txt, font=font(60), fill=fg, anchor="mm", align="center", spacing=8)
        d.text((S // 2, S * 2 - 50), small, font=font(18), fill=fg, anchor="mm")
        d.rectangle([6, 6, S - 7, S * 2 - 7], outline=fg, width=4)
        atlas.paste(p, (i * S, 0))
    save(atlas, "ads")

def interiors():
    """4 shop interiors seen through glass (shelves, counter, posters), 256x128 each in a 2x2 atlas."""
    W, H = 256, 128
    atlas = Image.new("RGB", (W * 2, H * 2))
    palettes = [(200, 180, 150), (170, 200, 210), (220, 190, 200), (190, 210, 170)]
    for i in range(4):
        p = Image.new("RGB", (W, H), palettes[i])
        d = ImageDraw.Draw(p)
        d.rectangle([0, 92, W, H], fill=(90, 70, 60))                    # floor
        for sx in (12, 140):                                             # shelves full of stuff
            for row in range(3):
                y = 18 + row * 24
                d.rectangle([sx, y + 18, sx + 100, y + 21], fill=(110, 80, 55))
                for k in range(8):
                    c = (R.randint(60, 255), R.randint(60, 255), R.randint(60, 255))
                    d.rectangle([sx + 4 + k * 12, y + 4, sx + 12 + k * 12, y + 18], fill=c)
        d.rectangle([90, 70, 170, 98], fill=(70, 50, 40))                 # counter
        d.ellipse([118, 40, 142, 64], fill=(230, 180, 140))               # shopkeeper
        d.rectangle([116, 62, 144, 74], fill=[(230, 60, 70), (60, 120, 220), (60, 180, 90), (240, 180, 40)][i])
        atlas.paste(p, ((i % 2) * W, (i // 2) * H))
    save(atlas, "interiors")

def puddle():
    w = h = 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    n = noise(w, h, 20, 3, 90)
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.sqrt(((xx - 64) / 60.0) ** 2 + ((yy - 64) / 44.0) ** 2) + (n - 0.5) * 0.5
    a = np.clip((1.0 - r) * 4.0, 0, 1)
    arr = np.zeros((h, w, 4), np.uint8)
    arr[..., 0:3] = 40
    arr[..., 3] = (a * 220).astype(np.uint8)
    save(Image.fromarray(arr, "RGBA"), "puddle")

def stairs_sign():
    w, h = 256, 128
    img = Image.new("RGB", (w, h), (240, 240, 235))
    d = ImageDraw.Draw(img)
    for i in range(5):  # little staircase logo
        d.rectangle([14 + i * 14, 92 - i * 14, 28 + i * 14, 106], fill=(60, 60, 60))
    d.text((165, 50), "STAIRS", font=font(40), fill=(40, 40, 40), anchor="mm")
    d.text((165, 92), "INC.", font=font(34), fill=(200, 30, 30), anchor="mm")
    d.rectangle([3, 3, w - 4, h - 4], outline=(40, 40, 40), width=5)
    save(img, "stairs_sign")

if __name__ == "__main__":
    cloth_shirt(); cloth_denim(); hair(); skin(); faces(); prints(); shoes()
    metal_paint("dumpster", (40, 110, 60), "NO STAIRS", 60)
    metal_paint("metal_blue", (40, 70, 140), None, 61)
    concrete("concrete", 70, 175, 8)
    concrete("stucco", 72, 205, 2, spots=0)
    concrete("sidewalk", 71, 200, 4, tiles=2)
    asphalt(); brick(); wood(); newsbox(); vending(); posters(); chainlink(); hazard()
    tread(); fabric(); bark(); leaves(); car_panels(); van_livery(); taxi_livery()
    ads(); interiors(); puddle(); stairs_sign()
