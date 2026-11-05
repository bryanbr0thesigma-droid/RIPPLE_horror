# PART 1 of the branding requests: the F.A.L.C.O.N. logo files, and the made-up brands with their
# packaging: DEEP END soda (the vending machine), HIGH & DRY coffee, VACANCY magazine and the
# TELLURIC electronics logo.
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops
from kit import *  # noqa: F401,F403
import kit

# Soda colours
TEAL = (14, 132, 156)
TEAL_D = (8, 74, 104)
TEAL_L = (96, 214, 222)
MAGENTA = (226, 36, 126)
SODA_Y = (255, 214, 40)
SODA_NAVY = (16, 22, 64)
# Coffee colours
MUSTARD = (226, 160, 40)
BROWN = (74, 38, 22)
BROWN_L = (140, 74, 40)
CHAR = (40, 38, 42)


# ---------------------------------------------------------------- F.A.L.C.O.N.
def falcon_logo_full(out):
    W, H = 2048, 1024
    im, d = new(W, H)
    paste(im, seal(860), 470, 512)
    x0, x1 = 980, 1990
    fnt = fit("sans", "F.A.L.C.O.N.", x1 - x0, 230, 0)
    tw = text_w("F.A.L.C.O.N.", fnt) / SS
    tr = (x1 - x0 - tw) / 11
    tracked(d, x0, 395, "F.A.L.C.O.N.", fnt, NAVY, tr, "l")
    rect(d, x0, 522, x1, 536, fill=GOLD)
    rect(d, x0, 544, x1, 550, fill=RED)
    f2 = fit("sans", "CLASSIFICATION & OCCULT NATURE", x1 - x0, 70, 6)
    tracked(d, x0, 618, "FEDERAL AGENCY FOR LIMINAL", f2, NAVY, 6, "l")
    tracked(d, x0, 702, "CLASSIFICATION & OCCULT NATURE", f2, NAVY, 6, "l")
    return save(im, out, "falcon_logo_full.png", opaque=False)


def falcon_logo_onecolor(out):
    W, H = 1024, 1024
    im, d = new(W, H)
    paste(im, seal_mono(700, (255, 255, 255)), 512, 395)
    fnt = F("sans", 104)
    tracked(d, 512, 836, "F.A.L.C.O.N.", fnt, (255, 255, 255), 26)
    rect(d, 150, 903, 874, 910, fill=(255, 255, 255))
    f2 = fit("sans", "FEDERAL AGENCY FOR LIMINAL CLASSIFICATION & OCCULT NATURE", 760, 30, 2)
    tracked(d, 512, 948, "FEDERAL AGENCY FOR LIMINAL CLASSIFICATION & OCCULT NATURE", f2, (255, 255, 255), 2)
    return save(im, out, "falcon_logo_onecolor.png", opaque=False)


# ---------------------------------------------------------------- DEEP END soda
def outlined(s, fnt, fill, outline, ow, shadow=None, sh_off=(0, 0), track=0):
    """Text with a thick outline and an offset shadow, as RGBA (canvas scale)."""
    m = text_mask(s, fnt, track)
    g, pad = grow(m, ow * SS)
    sp = int(max(abs(sh_off[0]), abs(sh_off[1])) * SS) + 2
    out = Image.new("RGBA", (g.size[0] + 2 * sp, g.size[1] + 2 * sp), (0, 0, 0, 0))
    if shadow:
        out.alpha_composite(tint(g, shadow), (int(sp + sh_off[0] * SS), int(sp + sh_off[1] * SS)))
    out.alpha_composite(tint(g, outline), (sp, sp))
    out.alpha_composite(tint(m, fill), (sp + pad, sp + pad))
    return out


def deep_end_logo(size, angle=8):
    """DEEP over END, yellow with a navy outline and a magenta shadow, tilted up."""
    a = outlined("DEEP", F("soda", size), SODA_Y, SODA_NAVY, size * 0.07, MAGENTA, (size * 0.06, size * 0.07))
    b = outlined("END", F("soda", size * 1.18), SODA_Y, SODA_NAVY, size * 0.07, MAGENTA, (size * 0.06, size * 0.07))
    w = max(a.size[0], b.size[0]) + int(size * 0.24 * SS)
    ov = int(size * 0.3 * SS)
    lay = Image.new("RGBA", (w, a.size[1] + b.size[1] - ov), (0, 0, 0, 0))
    lay.alpha_composite(b, ((w - b.size[0]) // 2 + int(size * 0.12 * SS), a.size[1] - ov))
    lay.alpha_composite(a, ((w - a.size[0]) // 2 - int(size * 0.12 * SS), 0))
    return lay.rotate(angle, resample=Image.BICUBIC, expand=True)


def bubbles(im, box, n, seed, color=(255, 255, 255), rmin=4, rmax=16):
    rng = np.random.default_rng(seed)
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = box
    for _ in range(n):
        x, y, r = rng.uniform(x0, x1), rng.uniform(y0, y1), rng.uniform(rmin, rmax)
        ellipse(d, x, y, r, outline=color + (200,), width=max(1.5, r * 0.18))
        ellipse(d, x - r * 0.35, y - r * 0.35, r * 0.22, fill=color + (230,))


def memphis(im, box, seed, cols):
    """90s confetti: zigzags, triangles and squiggles."""
    rng = np.random.default_rng(seed)
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = box
    for i in range(16):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        c = cols[i % len(cols)]
        k = i % 3
        s = rng.uniform(14, 26)
        if k == 0:
            pts = [(x + j * s * 0.5, y + (s * 0.35 if j % 2 else 0)) for j in range(5)]
            line(d, pts, c, s * 0.16, False)
        elif k == 1:
            a = rng.uniform(0, 6.28)
            poly(d, [(x + math.cos(a + t) * s * 0.6, y + math.sin(a + t) * s * 0.6) for t in (0, 2.09, 4.19)], fill=c)
        else:
            pts = [(x + t * s * 1.6, y + math.sin(t * 6.28) * s * 0.25) for t in np.linspace(0, 1, 30)]
            line(d, pts, c, s * 0.14)


def splash(im, cx, cy, w, h, color, seed=2):
    """A flat, rounded splash: a pool of liquid with tongues and drops thrown up, merged smooth."""
    rng = np.random.default_rng(seed)
    m = Image.new("L", im.size, 0)
    md = ImageDraw.Draw(m)
    ellipse(md, cx, cy + h * 0.1, w / 2, h * 0.16, fill=255)
    n = 7
    for i in range(n):
        t = (i + 0.5) / n
        x = cx - w * 0.42 + t * w * 0.84
        lean = (t - 0.5) * 1.1
        tall = h * (0.55 + 0.4 * math.sin(math.pi * t)) * rng.uniform(0.8, 1.05)
        tongue = Image.new("L", (int(w * 0.2 * SS), int(tall * 2 * SS)), 0)
        ImageDraw.Draw(tongue).ellipse([0, 0, tongue.size[0] - 1, tongue.size[1] - 1], fill=255)
        tongue = tongue.rotate(-math.degrees(lean) * 0.6, expand=True, resample=Image.BICUBIC)
        m.paste(255, (int(x * SS - tongue.size[0] / 2), int((cy + h * 0.1) * SS - tongue.size[1] / 2)), tongue)
        tx = x + lean * tall * 0.55
        ty = cy + h * 0.1 - tall * 1.08
        ellipse(md, tx, ty, w * 0.035, w * 0.042, fill=255)
    for i in range(8):
        a = math.radians(rng.uniform(205, 335))
        r = rng.uniform(0.62, 0.8) * w * 0.62
        ellipse(md, cx + math.cos(a) * r, cy + math.sin(a) * r * 0.95 - h * 0.25, w * 0.022, w * 0.026, fill=255)
    m = m.filter(ImageFilter.GaussianBlur(4 * SS)).point(lambda v: 0 if v < 110 else min(255, (v - 110) * 6))
    im.alpha_composite(tint(m, color))
    hi = m.filter(ImageFilter.MinFilter(9)).filter(ImageFilter.GaussianBlur(2))
    hi = ImageChops.subtract(m, hi.transform(hi.size, Image.AFFINE, (1, 0, -6, 0, 1, -8)))
    im.alpha_composite(tint(hi, (255, 255, 255), 0.7))


def can(im, cx, cy, w, h, seed=1):
    """A DEEP END can, flat-shaded."""
    d = ImageDraw.Draw(im)
    lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    top, bot = cy - h / 2, cy + h / 2
    ry = w * 0.13
    # body with cylinder shading in bands
    body = Image.new("L", im.size, 0)
    bd = ImageDraw.Draw(body)
    rect(bd, cx - w / 2, top + ry, cx + w / 2, bot - ry, fill=255)
    ellipse(bd, cx, bot - ry, w / 2, ry, fill=255)
    lay.paste(TEAL + (255,), (0, 0), body)
    for i, (t0, t1, col) in enumerate([(0.0, 0.12, TEAL_D), (0.88, 1.0, TEAL_D), (0.62, 0.74, TEAL_L)]):
        band = Image.new("L", im.size, 0)
        rect(ImageDraw.Draw(band), cx - w / 2 + w * t0, top, cx - w / 2 + w * t1, bot, fill=255)
        lay.paste(col + (255,), (0, 0), ImageChops.multiply(band, body))
    # magenta wave band
    wave = Image.new("L", im.size, 0)
    wd = ImageDraw.Draw(wave)
    pts = [(x, cy + h * 0.22 + math.sin((x - cx) / w * 6) * h * 0.03) for x in np.linspace(cx - w / 2, cx + w / 2, 60)]
    poly(wd, pts + [(cx + w / 2, bot), (cx - w / 2, bot)], fill=255)
    lay.paste(MAGENTA + (255,), (0, 0), ImageChops.multiply(wave, body))
    im.alpha_composite(lay)
    # logo on the can
    logo = deep_end_logo(w * 0.27, 8)
    paste(im, logo, cx, cy - h * 0.06)
    # lid
    ellipse(d, cx, top + ry, w / 2 * 0.98, ry, fill=(196, 204, 210))
    ellipse(d, cx, top + ry, w / 2 * 0.86, ry * 0.8, fill=(150, 160, 170))
    ellipse(d, cx, top + ry * 1.05, w / 2 * 0.8, ry * 0.68, fill=(214, 220, 226))
    ellipse(d, cx + w * 0.06, top + ry * 1.0, w * 0.13, ry * 0.32, fill=(120, 128, 138))   # tab
    rect(d, cx - w / 2, top + ry, cx + w / 2, top + ry + 5, fill=(180, 188, 196))
    rect(d, cx - w / 2, bot - ry - 4, cx + w / 2, bot - ry + 1, fill=(0, 0, 0, 40))


def soda_front(out):
    W, H = 512, 1024
    im, d = new(W, H, TEAL_D)
    work = W * 5 / 6
    # background: deep teal, getting lighter upwards, with wave bands
    for i in range(40):
        t = i / 39
        col = tuple(int(TEAL_D[k] + (TEAL[k] - TEAL_D[k]) * (1 - t)) for k in range(3))
        rect(d, 0, H * t, work, H * (t + 1 / 39) + 1, fill=col)
    for j, (yy, col) in enumerate([(300, (255, 255, 255, 34)), (330, (255, 255, 255, 22))]):
        pts = [(x, yy + math.sin(x / 60 + j) * 12) for x in np.linspace(0, work, 60)]
        line(d, pts, col, 10)
    memphis(im, (10, 360, work - 20, 980), 4, [SODA_Y, MAGENTA, (255, 255, 255)])
    # top strip
    rect(d, 0, 0, work, 70, fill=MAGENTA)
    tracked(d, work / 2, 36, "ICE COLD", F("soda", 40), (255, 255, 255), 8)
    rect(d, 0, 70, work, 78, fill=SODA_Y)
    # logo
    paste(im, deep_end_logo(118, 8), work / 2, 228)
    paste(im, outlined("Take the plunge!", F("script", 40), (255, 255, 255), SODA_NAVY, 3.2), work / 2, 392)
    # splash and can
    splash(im, work / 2, 812, 330, 150, (176, 236, 244), 3)
    can(im, work / 2, 690, 150, 270)
    bubbles(im, (20, 420, work - 20, 960), 24, 7)
    # bottom
    rect(d, 0, H - 112, work, H - 104, fill=SODA_Y)
    rect(d, 0, H - 104, work, H, fill=SODA_NAVY)
    tracked(d, work / 2, H - 70, "REFRESHINGLY BOTTOMLESS", fit("sans", "REFRESHINGLY BOTTOMLESS", work - 40, 26, 2), SODA_Y, 2)
    tracked(d, work / 2, H - 34, "12 FL OZ  ·  ONLY 75¢", F("sans", 22), (255, 255, 255), 3)
    # the button column: plain
    rect(d, work, 0, W, H, fill=(34, 38, 46))
    rect(d, work, 0, work + 4, H, fill=(20, 22, 28))
    return save(im, out, "soda_front.png")


def soda_side(out):
    W, H = 512, 1024
    im, d = new(W, H, MAGENTA)
    # diagonal teal stripes
    for i in range(-6, 14):
        y0 = i * 120
        poly(d, [(0, y0), (W, y0 - 300), (W, y0 - 240), (0, y0 + 60)], fill=TEAL if i % 2 else (206, 26, 112))
    logo = deep_end_logo(150, 0).rotate(90, expand=True, resample=Image.BICUBIC)
    paste(im, logo, W / 2, H / 2 - 30)
    bubbles(im, (20, 20, W - 20, H - 20), 30, 11, rmin=6, rmax=22)
    rect(d, 0, H - 90, W, H, fill=SODA_NAVY)
    tracked(d, W / 2, H - 45, "TAKE THE PLUNGE", F("soda", 40), SODA_Y, 4)
    return save(im, out, "soda_side.png")


# ---------------------------------------------------------------- HIGH & DRY coffee
def mesa(d, x0, x1, base, top, color):
    """A flat desert mesa silhouette."""
    w = x1 - x0
    pts = [(x0, base), (x0 + w * 0.12, top + (base - top) * 0.3), (x0 + w * 0.2, top), (x0 + w * 0.62, top),
           (x0 + w * 0.68, top + (base - top) * 0.25), (x0 + w * 0.74, top + (base - top) * 0.2),
           (x0 + w * 0.86, base - (base - top) * 0.35), (x1, base)]
    poly(d, pts, fill=color)


def high_and_dry_badge(size):
    """The coffee's emblem: a sun over a mesa in a circle, with the script name across it."""
    S_ = size
    lay = Image.new("RGBA", (int(S_ * 1.5 * SS), int(S_ * 1.05 * SS)), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    cx, cy = S_ * 0.75, S_ * 0.45
    ellipse(d, cx, cy, S_ * 0.42, fill=CREAM)
    clip = Image.new("L", lay.size, 0)
    ellipse(ImageDraw.Draw(clip), cx, cy, S_ * 0.38, fill=255)
    inner = Image.new("RGBA", lay.size, (0, 0, 0, 0))
    idr = ImageDraw.Draw(inner)
    ellipse(idr, cx, cy, S_ * 0.38, fill=MUSTARD)
    for k in range(18):  # sun rays
        a0 = math.radians(k * 20 - 90)
        poly(idr, [(cx, cy + S_ * 0.05), (cx + math.cos(a0 - 0.08) * S_, cy + S_ * 0.05 + math.sin(a0 - 0.08) * S_),
                   (cx + math.cos(a0 + 0.08) * S_, cy + S_ * 0.05 + math.sin(a0 + 0.08) * S_)], fill=(238, 184, 70))
    ellipse(idr, cx, cy + S_ * 0.05, S_ * 0.16, fill=(250, 226, 150))
    mesa(idr, cx - S_ * 0.42, cx + S_ * 0.42, cy + S_ * 0.42, cy + S_ * 0.08, BROWN_L)
    rect(idr, cx - S_ * 0.5, cy + S_ * 0.25, cx + S_ * 0.5, cy + S_ * 0.5, fill=BROWN)
    inner.putalpha(ImageChops.multiply(inner.getchannel("A"), clip))
    lay.alpha_composite(inner)
    name = outlined("High & Dry", F("script", S_ * 0.3), CREAM, BROWN, S_ * 0.025, (0, 0, 0, 90), (S_ * 0.012, S_ * 0.016))
    lay.alpha_composite(name, (int(cx * SS - name.size[0] / 2), int((cy + S_ * 0.3) * SS - name.size[1] / 2)))
    return lay


def coffee_label(out):
    W, H = 512, 256
    im, d = new(W, H, BROWN)
    rect(d, 0, 0, W, 22, fill=RED)
    rect(d, 0, 22, W, 28, fill=MUSTARD)
    rect(d, 0, H - 28, W, H - 22, fill=MUSTARD)
    rect(d, 0, H - 22, W, H, fill=RED)
    for x in (96, W - 96):
        rect(d, x - 1, 40, x + 1, H - 40, fill=(120, 72, 44))
    badge = high_and_dry_badge(150)
    paste(im, badge, W / 2, 110)
    tracked(d, W / 2, 196, "COFFEE", F("slab", 34), CREAM, 6)
    tracked(d, W / 2, 220, "FINE GROUND  ·  ALL-METHOD GRIND", F("sans", 9.5), MUSTARD, 1.5)
    # back of the can
    sm = F("sansr", 8.6)
    para(d, 12, 40, "BREWING: Use one level tablespoon for each cup of fresh cold water. "
         "Brew as usual. Serve hot.", sm, CREAM, 76, 1.25)
    para(d, 12, 120, "Store in a cool, dry place. Keep the lid on tight.", sm, CREAM, 76, 1.25)
    tracked(d, 48, 205, "NET WT 2 LB", F("sans", 10), MUSTARD, 1)
    tracked(d, 48, 218, "(907 g)", F("sansr", 9), CREAM)
    para(d, W - 88, 40, "PACKED FOR THE F.A.L.C.O.N. COMMISSARY. GOVERNMENT ISSUE. NOT FOR RESALE.", sm, CREAM, 76, 1.25)
    tracked(d, W - 50, 168, "\"Always on", F("serifi", 11), MUSTARD)
    tracked(d, W - 50, 182, "dry ground.\"", F("serifi", 11), MUSTARD)
    barcode(d, W - 86, 196, 70, 18, 5, INK)
    im = worn(im, 21, 0.25, chip_color=(96, 58, 36), scratches=True)
    return save(im, out, "coffee_label.png")


# ---------------------------------------------------------------- VACANCY magazine
def vgrad(d, x0, y0, x1, y1, c0, c1, steps=64):
    for i in range(steps):
        t = i / (steps - 1)
        col = tuple(int(c0[k] + (c1[k] - c0[k]) * t) for k in range(3))
        rect(d, x0, y0 + (y1 - y0) * i / steps, x1, y0 + (y1 - y0) * (i + 1) / steps + 1, fill=col)


def cover_motel(im, d, W, H):
    vgrad(d, 0, 0, W, 470, (34, 24, 74), (236, 116, 70))
    ellipse(d, 150, 420, 60, fill=(252, 196, 96))
    rect(d, 0, 400, W, 470, fill=(60, 40, 70))
    # motel block
    rect(d, 40, 330, 470, 470, fill=(232, 220, 196))
    rect(d, 30, 318, 480, 334, fill=(176, 52, 46))
    for i in range(7):
        x = 60 + i * 58
        rect(d, x, 370, x + 26, 450, fill=(46, 92, 110))
        rect(d, x + 32, 380, x + 50, 404, fill=(250, 214, 120))
        tracked(d, x + 13, 360, str(i + 1), F("sans", 11), (90, 60, 50))
    # sign
    rect(d, 412, 190, 420, 330, fill=(70, 70, 80))
    rect(d, 356, 196, 476, 286, fill=(28, 120, 120), r=10)
    tracked(d, 416, 226, "MOTEL", F("sans", 26), (250, 240, 220), 3)
    rect(d, 368, 252, 464, 276, fill=(240, 80, 70), r=4)
    tracked(d, 416, 264, "VACANCY", F("sans", 13), (255, 250, 230), 2)
    # empty pool in front
    rect(d, 0, 470, W, H, fill=(214, 206, 192))
    poly(d, [(120, 520), (430, 520), (470, 640), (80, 640)], fill=(150, 196, 210))
    poly(d, [(132, 528), (418, 528), (452, 632), (98, 632)], fill=(196, 222, 228))
    for i in range(8):
        x = 140 + i * 38
        line(d, [(x, 528), (x - 10 + i * 2.5, 632)], (176, 206, 216), 2)
    rect(d, 400, 500, 406, 540, fill=(170, 174, 180))
    rect(d, 420, 500, 426, 540, fill=(170, 174, 180))


def cover_hall(im, d, W, H):
    d.rectangle([0, 0, W * SS, H * SS], fill=(214, 196, 120))
    vx, vy = W / 2, 340
    # floor and ceiling
    poly(d, [(0, H), (W, H), (vx + 30, vy + 22), (vx - 30, vy + 22)], fill=(150, 130, 90))
    poly(d, [(0, 0), (W, 0), (vx + 30, vy - 22), (vx - 30, vy - 22)], fill=(232, 226, 196))
    poly(d, [(0, 0), (vx - 30, vy - 22), (vx - 30, vy + 22), (0, H)], fill=(222, 202, 124))
    poly(d, [(W, 0), (vx + 30, vy - 22), (vx + 30, vy + 22), (W, H)], fill=(204, 184, 108))
    rect(d, vx - 30, vy - 22, vx + 30, vy + 22, fill=(120, 104, 70))
    # ceiling lights receding
    for i in range(9):
        t = 0.82 ** i
        y = vy - (vy - 30) * t
        w = 60 * t
        ln = 26 * t
        rect(d, vx - w, y - ln / 2, vx + w, y + ln / 2, fill=(255, 252, 232))
    # doors receding on both walls
    for i in range(7):
        t0, t1 = 0.78 ** (i + 0.15), 0.78 ** (i + 0.55)
        for side in (-1, 1):
            xa, xb = vx + side * (vx * t0 + 30 * (1 - t0)), vx + side * (vx * t1 + 30 * (1 - t1))
            ya0, ya1 = vy - (vy - 120) * t0, vy + (H - vy) * t0 * 0.92
            yb0, yb1 = vy - (vy - 120) * t1, vy + (H - vy) * t1 * 0.92
            poly(d, [(xa, ya0), (xb, yb0), (xb, yb1), (xa, ya1)], fill=(126, 92, 60))
    # a figure at the far end
    put(im, person("stand", 22), vx, vy + 9, (40, 34, 26))


def cover_pool(im, d, W, H):
    d.rectangle([0, 0, W * SS, H * SS], fill=(226, 236, 236))
    for y in range(0, H, 22):  # tiles
        line(d, [(0, y), (W, y)], (200, 214, 216), 1.5, False)
    for x in range(0, W, 22):
        line(d, [(x, 0), (x, 400)], (200, 214, 216), 1.5, False)
    rect(d, 320, 220, 440, 400, fill=(40, 52, 58))                # doorway
    rect(d, 0, 400, W, H, fill=(76, 182, 206))                    # water
    rng = np.random.default_rng(4)
    for i in range(40):
        x, y = rng.uniform(0, W), rng.uniform(420, H)
        ww = rng.uniform(20, 70)
        line(d, [(x, y), (x + ww * 0.5, y - 4), (x + ww, y)], (150, 222, 236), 2.5)
    rect(d, 0, 396, W, 404, fill=(196, 214, 216))
    # reflection of the doorway
    rect(d, 326, 404, 434, 520, fill=(46, 120, 140))
    # a ladder
    for x in (70, 96):
        line(d, [(x, 330), (x, 404), (x + 6, 460)], (190, 196, 204), 5)
    for y in (350, 376, 402):
        line(d, [(70, y), (96, y)], (190, 196, 204), 4)


def headline(d, x, y, big, small, col_big, col_small, w, anchor="l", size=32, edge=(0, 0, 0)):
    fb = fit("sans", big, w, size, 0)
    tracked(d, x, y, big, fb, col_big, 0, anchor, stroke=2.2, stroke_fill=edge)
    if small:
        fs = F("sans", 17)
        tracked(d, x, y + fb.size / SS * 0.9, small, fs, col_small, 0, anchor, stroke=1.6, stroke_fill=edge)


def magazine(out, n):
    W, H = 512, 680
    im, d = new(W, H, (0, 0, 0))
    issues = [
        (cover_motel, (255, 236, 200), "JULY 1993",
         [("10 POOLS", "you should never swim in", 206), ("MOTELS THAT", "aren't there anymore", 276)],
         "ROAD TRIP: NOWHERE, NEVADA"),
        (cover_hall, (176, 30, 36), "OCTOBER 1993",
         [("IS YOUR HALLWAY", "too long? A checklist", 520), ("NEW ROOMS:", "how to tell", 590)],
         "EXIT SIGNS: A FIELD GUIDE"),
        (cover_pool, (14, 40, 90), "FEBRUARY 1994",
         [("THE QUIET SEASON", "indoor pools, off-peak", 214), ("WHY IS THE WATER", "always warm?", 560)],
         "READERS' PHOTOS: ROOMS WE CAN'T FIND AGAIN"),
    ]
    draw, mast_col, date, heads, kicker = issues[n - 1]
    draw(im, d, W, H)
    dark_bg = n == 1
    # masthead
    top_col = (255, 255, 255) if n == 1 else INK
    tracked(d, W / 2, 22, "AMERICA'S ROADSIDE TRAVEL MONTHLY", F("sans", 13), top_col, 3)
    fm = fit("fat", "VACANCY", W - 30, 140)
    tracked(d, W / 2 + 3, 92, "VACANCY", fm, (0, 0, 0, 90))
    tracked(d, W / 2, 89, "VACANCY", fm, mast_col)
    tracked(d, W - 16, 156, f"{date}  ·  $2.95", F("sans", 13), top_col, 1, "r")
    for big, small, y in heads:
        if n == 3:
            headline(d, 22, y, big, small, (176, 30, 36), INK, 300, edge=(255, 255, 255))
        else:
            headline(d, 22, y, big, small, (255, 226, 80), (255, 255, 255), 300)
    # kicker strip
    rect(d, 0, H - 44, W, H, fill=(176, 30, 36) if n != 2 else (14, 40, 90))
    tracked(d, 20, H - 22, kicker, fit("sans", kicker, 360, 17, 1), (255, 255, 255), 1, "l")
    barcode(d, W - 96, H - 108, 72, 34, 10 + n, INK)
    return save(im, out, f"magazine_{n}.png")


# ---------------------------------------------------------------- TELLURIC electronics
def electronics_logo(out):
    W, H = 512, 128
    im, d = new(W, H)
    col = (222, 224, 228)
    # emblem: three stacked bars inside a ring, like a stylised signal
    ellipse(d, 64, 64, 40, outline=col, width=7)
    for i, w in enumerate((44, 32, 20)):
        rect(d, 64 - w / 2, 44 + i * 15, 64 + w / 2, 52 + i * 15, fill=col)
    m = text_mask("TELLURIC", F("sans", 60), 6)
    m = m.resize((int(m.size[0] * 1.25), m.size[1]), Image.LANCZOS)          # extended, like 80s TV badges
    pad = int(m.size[1] * 0.2)
    wide = Image.new("L", (m.size[0] + pad, m.size[1]), 0)
    wide.paste(m, (pad, 0))
    m = wide.transform(wide.size, Image.AFFINE, (1, 0.2, 0, 0, 1, 0), Image.BICUBIC)   # italic slant
    sc = min(356 * SS / m.size[0], 62 * SS / m.size[1])
    m = m.resize((int(m.size[0] * sc), int(m.size[1] * sc)), Image.LANCZOS)
    paste(im, tint(m, col), 306, 60)
    rect(d, 124, 98, 486, 101, fill=col)
    return save(im, out, "electronics_logo.png", opaque=False)


def run(out):
    return [falcon_logo_full(out), falcon_logo_onecolor(out), soda_front(out), soda_side(out), coffee_label(out),
            magazine(out, 1), magazine(out, 2), magazine(out, 3), electronics_logo(out)]


if __name__ == "__main__":
    import sys, os
    o = sys.argv[1]
    os.makedirs(o, exist_ok=True)
    run(o)
