# PART 1 of the branding requests: the F.A.L.C.O.N. logo files, and the knock-off brands with
# their packaging: CHLORA-COLA (the vending machine), FLOATER'S coffee, LIMINAL GEOGRAPHIC magazine
# and SORNY electronics. They are parodies: the names and colours nod at the real thing, but the
# lettering and artwork are drawn here and no real logo is copied.
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops
from kit import *  # noqa: F401,F403

PURE = (255, 255, 255)
# Soda colours
COLA_RED = (200, 20, 32)
COLA_RED_D = (132, 8, 20)
LANE_BLUE = (24, 96, 190)
# Coffee colours
CAN_RED = (188, 26, 30)
CAN_RED_D = (112, 10, 14)
BRASS = (226, 182, 72)
# Magazine
FRAME_Y = (250, 204, 20)


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


# ---------------------------------------------------------------- CHLORA-COLA (a cola knock-off)
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


def bubbles(im, box, n, seed, color=(255, 255, 255), rmin=4, rmax=16):
    rng = np.random.default_rng(seed)
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = box
    for _ in range(n):
        x, y, r = rng.uniform(x0, x1), rng.uniform(y0, y1), rng.uniform(rmin, rmax)
        ellipse(d, x, y, r, outline=color + (200,), width=max(1.5, r * 0.18))
        ellipse(d, x - r * 0.35, y - r * 0.35, r * 0.22, fill=color + (230,))


def lane_rope(lay, x0, x1, y, s, color):
    """A pool lane rope: a cord threaded with floats, alternating white and blue (canvas scale)."""
    d = ImageDraw.Draw(lay)
    d.line([(x0, y), (x1, y)], fill=color + (255,), width=max(2, int(s * 0.05)))
    n = max(3, int((x1 - x0) / (s * 0.36)))
    for i in range(n):
        cx = x0 + (i + 0.5) * (x1 - x0) / n
        rx, ry = s * 0.15, s * 0.1
        if i % 2 == 0:
            d.ellipse([cx - rx, y - ry, cx + rx, y + ry], fill=color + (255,))
        else:
            d.ellipse([cx - rx, y - ry, cx + rx, y + ry], fill=LANE_BLUE + (255,), outline=color + (255,),
                      width=max(1, int(s * 0.025)))


def chlora_logo(max_w, color=PURE, angle=5, size=150):
    """The Chlora-Cola script, a lane rope under it, tilted up to the right."""
    fnt = fit("script", "Chlora-Cola", max_w * 0.92, size)
    m = text_mask("Chlora-Cola", fnt)
    s = fnt.size
    lay = Image.new("RGBA", (int(m.size[0] + s * 0.3), int(m.size[1] + s * 0.42)), (0, 0, 0, 0))
    lay.alpha_composite(tint(m, color), (int(s * 0.15), 0))
    lane_rope(lay, s * 0.3, lay.size[0] - s * 0.05, m.size[1] + s * 0.2, s * 0.62, color)
    return lay.rotate(angle, resample=Image.BICUBIC, expand=True)


def tile_grid(d, x0, y0, x1, y1, step, color):
    """Faint pool tiles."""
    y = y0
    while y < y1:
        line(d, [(x0, y), (x1, y)], color, 1.5, False)
        y += step
    x = x0
    while x < x1:
        line(d, [(x, y0), (x, y1)], color, 1.5, False)
        x += step


def can(im, cx, cy, w, h):
    """A Chlora-Cola can, flat-shaded, beaded with condensation."""
    d = ImageDraw.Draw(im)
    lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    top, bot = cy - h / 2, cy + h / 2
    ry = w * 0.13
    body = Image.new("L", im.size, 0)
    bd = ImageDraw.Draw(body)
    rect(bd, cx - w / 2, top + ry, cx + w / 2, bot - ry, fill=255)
    ellipse(bd, cx, bot - ry, w / 2, ry, fill=255)
    lay.paste(COLA_RED + (255,), (0, 0), body)
    for t0, t1, col in [(0.0, 0.12, COLA_RED_D), (0.88, 1.0, COLA_RED_D), (0.6, 0.72, (236, 70, 76))]:
        band = Image.new("L", im.size, 0)
        rect(ImageDraw.Draw(band), cx - w / 2 + w * t0, top, cx - w / 2 + w * t1, bot, fill=255)
        lay.paste(col + (255,), (0, 0), ImageChops.multiply(band, body))
    im.alpha_composite(lay)
    paste(im, chlora_logo(w * 0.86, PURE, 90, 60), cx, cy + h * 0.02)
    ellipse(d, cx, top + ry, w / 2 * 0.98, ry, fill=(196, 204, 210))
    ellipse(d, cx, top + ry, w / 2 * 0.86, ry * 0.8, fill=(150, 160, 170))
    ellipse(d, cx, top + ry * 1.05, w / 2 * 0.8, ry * 0.68, fill=(214, 220, 226))
    ellipse(d, cx + w * 0.06, top + ry, w * 0.13, ry * 0.32, fill=(120, 128, 138))
    rect(d, cx - w / 2, bot - ry - 4, cx + w / 2, bot - ry + 1, fill=(0, 0, 0, 50))
    rng = np.random.default_rng(5)
    for _ in range(26):                                   # condensation
        x, y = rng.uniform(cx - w * 0.44, cx + w * 0.44), rng.uniform(top + ry * 2, bot - ry * 1.5)
        r = rng.uniform(1.5, 4)
        ellipse(d, x, y, r, r * 1.3, fill=(255, 255, 255, 120))


def soda_front(out):
    W, H = 512, 1024
    work = W * 5 / 6
    im, d = new(W, H, COLA_RED)
    vgrad(d, 0, 0, work, H, COLA_RED, COLA_RED_D)
    tile_grid(d, 0, 640, work, H, 34, (150, 14, 26))
    tracked(d, work / 2, 56, "ENJOY", F("sans", 30), PURE, 12)
    paste(im, chlora_logo(work - 30), work / 2, 176)
    tracked(d, work / 2, 304, "It's the wet thing!", F("serifi", 32), PURE)
    can(im, work / 2, 552, 184, 330)
    rect(d, 64, 768, work - 64, 836, fill=PURE, r=10)
    tracked(d, work / 2, 803, "ICE COLD", F("black", 46), COLA_RED, 6)
    bubbles(im, (24, 852, work - 24, 906), 8, 7, PURE, 4, 10)
    rect(d, 0, H - 104, work, H, fill=(70, 4, 12))
    tracked(d, work / 2, H - 70, "CHLORA-COLA CLASSIC", F("sans", 24), PURE, 4)
    tracked(d, work / 2, H - 34, "12 FL OZ  \u00b7  ONLY 75\u00a2", F("sans", 22), BRASS, 3)
    rect(d, work, 0, W, H, fill=(34, 34, 38))
    rect(d, work, 0, work + 4, H, fill=(20, 20, 24))
    return save(im, out, "soda_front.png")


def soda_side(out):
    W, H = 512, 1024
    im, d = new(W, H, COLA_RED)
    vgrad(d, 0, 0, W, H, COLA_RED, COLA_RED_D)
    tile_grid(d, 0, 0, W, H, 40, (170, 16, 28))
    logo = chlora_logo(880, PURE, 0, 200).rotate(90, expand=True, resample=Image.BICUBIC)
    paste(im, logo, W / 2, H / 2 - 40)
    rect(d, 0, H - 90, W, H, fill=(70, 4, 12))
    tracked(d, W / 2, H - 45, "DRINK CHLORA-COLA", F("sans", 32), PURE, 5)
    return save(im, out, "soda_side.png")


# ---------------------------------------------------------------- FLOATER'S coffee (a knock-off of the red can)
def riband(d, cx, cy, w, h, fill, fold):
    """A banner with folded, notched ends."""
    e = h * 0.9
    for side in (-1, 1):
        x = cx + side * w / 2
        poly(d, [(x - side * e * 0.3, cy - h * 0.25), (x + side * e, cy - h * 0.25), (x + side * e * 0.6, cy + h * 0.25),
                 (x + side * e, cy + h * 0.75), (x - side * e * 0.3, cy + h * 0.75)], fill=fold)
    rect(d, cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2, fill=fill)


def coffee_label(out):
    W, H = 512, 256
    im, d = new(W, H, CAN_RED)
    vgrad(d, 0, 0, W, H, (206, 34, 36), CAN_RED_D)
    rect(d, 0, 0, W, 22, fill=CAN_RED_D)
    rect(d, 0, 22, W, 26, fill=BRASS)
    rect(d, 0, H - 26, W, H - 22, fill=BRASS)
    rect(d, 0, H - 22, W, H, fill=CAN_RED_D)
    for x in (100, W - 100):
        rect(d, x - 1, 36, x + 1, H - 36, fill=(232, 120, 100))
    rect(d, 150, 50, 196, 51.5, fill=BRASS)
    rect(d, W - 196, 50, W - 150, 51.5, fill=BRASS)
    tracked(d, W / 2, 51, "POOL GROWN", F("sans", 11), BRASS, 3)
    word = outlined("Floater's", fit("fat", "Floater's", 290, 70), PURE, (40, 4, 8), 3.2, (40, 4, 8, 140), (2.2, 2.6))
    paste(im, word, W / 2, 104)
    riband(d, W / 2, 162, 170, 30, BRASS, (160, 120, 40))
    tracked(d, W / 2, 162, "CLASSIC SOAK", F("serif", 17), CAN_RED_D, 3)
    tracked(d, W / 2, 202, "100% PURE COFFEE  \u00b7  MEDIUM ROAST", F("sans", 9.5), PURE, 1.5)
    sm = F("sansr", 8.6)
    para(d, 12, 40, "\u201cThe best part of wakin' up is Floater's in your cup.\u201d", F("serifi", 10.5), PURE, 80, 1.25)
    para(d, 12, 118, "BREWING: One tablespoon for each cup of fresh cold water.", sm, PURE, 80, 1.25)
    tracked(d, 50, 208, "NET WT 2 LB", F("sans", 10), BRASS, 1)
    tracked(d, 50, 221, "(907 g)", F("sansr", 9), PURE)
    para(d, W - 90, 40, "PACKED FOR THE F.A.L.C.O.N. COMMISSARY. GOVERNMENT ISSUE. NOT FOR RESALE.", sm, PURE, 80, 1.25)
    barcode(d, W - 86, 190, 70, 18, 5, INK)
    im = worn(im, 21, 0.3, chip_color=(110, 20, 20), scratches=True)
    return save(im, out, "coffee_label.png")


# ---------------------------------------------------------------- LIMINAL GEOGRAPHIC (a knock-off of the yellow border)
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
    art, ad = new(W, H, (0, 0, 0))
    issues = [
        (cover_motel, "JULY 1993",
         [("10 POOLS", "you should never swim in", 206), ("MOTELS THAT", "aren't there anymore", 276)],
         "ROAD TRIP: NOWHERE, NEVADA"),
        (cover_hall, "OCTOBER 1993",
         [("IS YOUR HALLWAY", "too long? A checklist", 500), ("NEW ROOMS:", "how to tell", 566)],
         "EXIT SIGNS: A FIELD GUIDE"),
        (cover_pool, "FEBRUARY 1994",
         [("THE QUIET SEASON", "indoor pools, off-peak", 214), ("WHY IS THE WATER", "always warm?", 540)],
         "READERS' PHOTOS: ROOMS WE CAN'T FIND AGAIN"),
    ]
    draw, date, heads, kicker = issues[n - 1]
    draw(art, ad, W, H)
    # white cover, the art in a window, a thick yellow frame round the edge
    im, d = new(W, H, (250, 250, 246))
    box = (34, 112, W - 34, H - 34)
    crop = art.crop(tuple(int(v * SS) for v in box))
    im.alpha_composite(crop, (int(box[0] * SS), int(box[1] * SS)))
    rect(d, 12, 12, W - 12, H - 12, outline=FRAME_Y, width=22)
    tracked(d, W / 2, 62, "LIMINAL GEOGRAPHIC", fit("serif", "LIMINAL GEOGRAPHIC", W - 90, 44, 3), INK, 3)
    tracked(d, W / 2, 96, f"{date}  \u00b7  VOL. 184, NO. {n + 2}  \u00b7  $2.95", F("sans", 11), INK, 2)
    d2 = ImageDraw.Draw(im)
    for big, small, y in heads:
        if n == 3:
            headline(d2, 48, y, big, small, (176, 30, 36), INK, 300, edge=PURE)
        else:
            headline(d2, 48, y, big, small, FRAME_Y, PURE, 300)
    tracked(d2, 48, H - 56, kicker, fit("sans", kicker, 300, 15, 1), PURE if n != 3 else INK, 1, "l",
            stroke=1.4, stroke_fill=(0, 0, 0) if n != 3 else PURE)
    barcode(d2, W - 116, H - 100, 64, 30, 10 + n, INK)
    return save(im, out, f"magazine_{n}.png")


# ---------------------------------------------------------------- SORNY electronics
def electronics_logo(out):
    W, H = 512, 128
    im, d = new(W, H)
    col = (222, 224, 228)
    m = text_mask("SORNY", F("serif", 80), 14)
    m = m.resize((int(m.size[0] * 1.3), m.size[1]), Image.LANCZOS)          # extended, like 80s TV badges
    sc = min(400 * SS / m.size[0], 76 * SS / m.size[1])
    m = m.resize((int(m.size[0] * sc), int(m.size[1] * sc)), Image.LANCZOS)
    paste(im, tint(m, col), W / 2, 58)
    tracked(d, W / 2, 112, "SOLID STATE  \u00b7  HI-FI STEREO", F("sans", 11), col, 4)
    return save(im, out, "electronics_logo.png", opaque=False)


def run(out):
    return [falcon_logo_full(out), falcon_logo_onecolor(out), soda_front(out), soda_side(out), coffee_label(out),
            magazine(out, 1), magazine(out, 2), magazine(out, 3), electronics_logo(out)]


if __name__ == "__main__":
    import sys, os
    o = sys.argv[1]
    os.makedirs(o, exist_ok=True)
    run(o)
