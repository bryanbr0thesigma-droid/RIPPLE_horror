# PARTS 3 to 5 of the branding requests: the training annex (sign template, room titles, the noise
# meter), the Shallow Halls (warning signs, equipment plates, the exit sign, the level plaque) and
# the title screen (the RIPPLE logo and the menu header).
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops
from kit import *  # noqa: F401,F403

STATION = "PINEWATER FIELD STATION"


# ---------------------------------------------------------------- training annex
def training_sign(out):
    W, H = 1024, 640
    im, d = paper(W, H, 80, CREAM, 3, 0.8)
    rect(d, 0, 0, W, 176, fill=NAVY)
    rect(d, 0, 176, W, 190, fill=RED)
    rect(d, 0, 190, W, 197, fill=GOLD)
    paste(im, seal(140), 98, 88)
    tracked(d, 188, 30, "F.A.L.C.O.N.  ·  TRAINING DIVISION", F("sans", 17), GOLD, 4, "l")
    rect(d, 188, 46, W - 36, 48, fill=(60, 76, 140))
    # the body: a faint ruled margin and a footer strip
    rect(d, 28, 222, W - 28, H - 70, outline=(200, 192, 170), width=2)
    rect(d, 0, H - 48, W, H, fill=NAVY)
    tracked(d, 30, H - 24, "TRAINING ANNEX", F("sans", 17), WHITE, 4, "l")
    tracked(d, W - 30, H - 24, "AUTHORIZED PERSONNEL ONLY", F("sans", 17), GOLD, 4, "r")
    im = worn(im, 81, 0.35, chip_color=(190, 180, 160))
    return save(im, out, "training_sign.png")


ROOMS = ["CONTROLS", "WATER IS LOUD", "THROW / LIDAR", "THE DARK", "POWER", "THE POOL COVER",
         "IF YOU HEAR IT COMING, FREEZE"]


def room_title(out, n):
    W, H = 1024, 256
    im, d = new(W, H)
    cx, cy = 118, 128
    ellipse(d, cx, cy, 98, fill=GOLD)
    ellipse(d, cx, cy, 90, fill=NAVY)
    tracked(d, cx, cy + 4, str(n), F("black", 120), WHITE)
    title = ROOMS[n - 1]
    x0, x1 = 240, W - 24
    fnt = fit("black", title, x1 - x0, 104, 2)
    if fnt.size / SS >= 70:
        tracked(d, x0, 116, title, fnt, NAVY, 2, "l")
        tw = text_w(title, fnt, 2) / SS
        rect(d, x0 + 2, 186, x0 + tw, 198, fill=RED)
    else:
        a, b = title.split(", ")
        fa = fit("black", a + ",", x1 - x0, 64, 2)
        tracked(d, x0, 84, a + ",", fa, NAVY, 2, "l")
        fb = F("black", 96)
        tracked(d, x0, 168, b, fb, RED, 6, "l")
        tw = text_w(b, fb, 6) / SS
        rect(d, x0 + 2, 226, x0 + tw, 236, fill=NAVY)
    return save(im, out, f"room_title_{n}.png", opaque=False)


def noise_meter(out):
    W, H = 512, 256
    im, d = new(W, H)
    rect(d, 4, 4, W - 4, H - 4, fill=(40, 42, 48), r=22)
    rect(d, 14, 14, W - 14, H - 14, fill=CREAM, r=14)
    tracked(d, W / 2, 40, "NOISE LEVEL", F("sans", 26), NAVY, 6)
    cx, cy, R = W / 2, 222, 160
    zones = [(200, 248, (52, 150, 80)), (248, 300, (232, 176, 30)), (300, 340, RED)]
    for a0, a1, col in zones:
        d.arc([(cx - R) * SS, (cy - R) * SS, (cx + R) * SS, (cy + R) * SS], a0, a1, fill=col, width=int(26 * SS))
    for k in range(29):
        a = math.radians(200 + k * 5)
        big = k % 4 == 0
        r0 = R - 34 - (14 if big else 6)
        line(d, [(cx + math.cos(a) * r0, cy + math.sin(a) * r0), (cx + math.cos(a) * (R - 32), cy + math.sin(a) * (R - 32))],
             INK, 4 if big else 2, False)
    for label, ang, col in [("QUIET", 220, (30, 110, 60)), ("LOUD", 274, (150, 100, 0)), ("DANGER", 322, RED)]:
        a = math.radians(ang)
        r = R - 76
        tracked(d, cx + math.cos(a) * r, cy + math.sin(a) * r, label, F("sans", 17), col, 1.5)
    ellipse(d, cx, cy, 20, fill=(40, 42, 48))
    ellipse(d, cx, cy, 8, fill=(150, 150, 156))
    tracked(d, 34, H - 30, "F.A.L.C.O.N. TD-2", F("mono", 12), NAVY, 0, "l")
    tracked(d, W - 34, H - 30, "dB(A)", F("mono", 12), NAVY, 0, "r")
    for x, y in [(30, 30), (W - 30, 30)]:
        ellipse(d, x, y, 6, fill=(150, 150, 156))
    return save(im, out, "noise_meter.png", opaque=False)


# ---------------------------------------------------------------- Shallow Halls
def plate(W, H, seed):
    """A white enamel sign plate."""
    im, d = paper(W, H, seed, (246, 244, 236), 2.0, 0.25)
    return im, d


def tap_and_glass(im, cx, cy, s):
    """A drinking-water tap over a glass, black (for the 'do not drink' sign)."""
    d = ImageDraw.Draw(im)
    K = (0, 0, 0, 255)
    rect(d, cx - s * 0.5, cy - s * 0.52, cx + s * 0.08, cy - s * 0.38, fill=K)        # pipe
    rect(d, cx - s * 0.06, cy - s * 0.52, cx + s * 0.1, cy - s * 0.24, fill=K)        # spout
    rect(d, cx - s * 0.32, cy - s * 0.64, cx - s * 0.2, cy - s * 0.52, fill=K)
    rect(d, cx - s * 0.42, cy - s * 0.7, cx - s * 0.1, cy - s * 0.63, fill=K)         # handle
    for i in range(2):
        put(im, drop(s * 0.1), cx + s * 0.02, cy - s * 0.12 + i * s * 0.12, (0, 0, 0))
    poly(d, [(cx - s * 0.2, cy + s * 0.08), (cx + s * 0.24, cy + s * 0.08), (cx + s * 0.18, cy + s * 0.56),
             (cx - s * 0.14, cy + s * 0.56)], fill=K)
    poly(d, [(cx - s * 0.15, cy + s * 0.13), (cx + s * 0.19, cy + s * 0.13), (cx + s * 0.17, cy + s * 0.26),
             (cx - s * 0.13, cy + s * 0.26)], fill=(255, 255, 255, 255))


def warning_sign(out, key):
    W, H = 512, 512
    im, d = plate(W, H, 90 + len(key))
    cx, cy = W / 2, 178
    if key == "no_diving":
        prohibition(im, cx, cy, 150, person("stand", 168, rot=-128), 0, -22, 62)
        texts, band = ["NO DIVING"], RED
    elif key == "no_running":
        prohibition(im, cx, cy, 150, person("run", 168), 0, 6)
        texts, band = ["NO RUNNING"], RED
    elif key == "staff_only":
        prohibition(im, cx, cy, 150, person("stand", 190), 0, 4)
        texts, band = ["AUTHORISED", "STAFF ONLY"], RED
    elif key == "deep_water":
        def swimmer(lay, ld):
            ellipse(ld, cx + 6, cy + 18, 24, fill=(0, 0, 0, 255))
            line(ld, [(cx - 22, cy + 50), (cx - 48, cy - 10), (cx - 40, cy - 46)], (0, 0, 0, 255), 15)
            ellipse(ld, cx - 40, cy - 48, 9, fill=(0, 0, 0, 255))
            rect(ld, cx - 200, cy + 54, cx + 200, cy + 200, fill=YELLOW + (255,))
            waves(ld, cx - 200, cx + 200, cy + 52, 7, 52, 11, (0, 0, 0, 255), 3, 24)
        warning(im, cx, cy + 14, 330, draw=swimmer)
        texts, band = ["DEEP WATER"], (20, 20, 22)
    else:  # do not drink
        lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
        prohibition(im, cx, cy, 150)
        tap_and_glass(lay, cx, cy + 6, 190)
        clip = Image.new("L", im.size, 0)
        ellipse(ImageDraw.Draw(clip), cx, cy, 120, fill=255)
        lay.putalpha(ImageChops.multiply(lay.getchannel("A"), clip))
        im.alpha_composite(lay)
        prohibition_ring_only(im, cx, cy, 150)
        texts, band = ["DO NOT DRINK", "THE WATER"], RED
    y0 = 350
    rect(d, 22, y0, W - 22, H - 46, fill=band)
    if len(texts) == 1:
        tracked(d, W / 2, (y0 + H - 46) / 2, texts[0], fit("black", texts[0], W - 80, 66, 3), YELLOW if band == (20, 20, 22) else WHITE, 3)
    else:
        f2 = fit("black", max(texts, key=len), W - 80, 52, 2)
        for i, t in enumerate(texts):
            tracked(d, W / 2, y0 + 36 + i * 50, t, f2, WHITE, 2)
    tracked(d, W / 2, H - 24, "F.A.L.C.O.N.  ·  " + STATION, F("sans", 13), (60, 60, 64), 2)
    rect(d, 8, 8, W - 8, H - 8, outline=(170, 168, 160), width=2, r=14)
    for x, y in [(26, 26), (W - 26, 26), (26, H - 26), (W - 26, H - 26)]:
        ellipse(d, x, y, 6, fill=(170, 170, 176))
        ellipse(d, x, y, 2.5, fill=(110, 110, 116))
    im = worn(im, 95 + len(key), 0.8, chip_color=(80, 74, 66))
    return save(im, out, f"sign_{key}.png")


def prohibition_ring_only(im, cx, cy, r):
    ring = Image.new("L", im.size, 0)
    rd = ImageDraw.Draw(ring)
    ellipse(rd, cx, cy, r, fill=255)
    ellipse(rd, cx, cy, r * 0.8, fill=0)
    ang = math.radians(45)
    w = r * 0.08
    dx, dy = math.cos(ang) * r * 0.82, math.sin(ang) * r * 0.82
    nx, ny = -math.sin(ang) * w, math.cos(ang) * w
    poly(rd, [(cx - dx + nx, cy - dy + ny), (cx + dx + nx, cy + dy + ny), (cx + dx - nx, cy + dy - ny),
              (cx - dx - nx, cy - dy - ny)], fill=255)
    im.alpha_composite(tint(ring, (200, 16, 30)))


def brushed(W, H, seed, base):
    """Painted steel: a fine horizontal brush grain."""
    rng = np.random.default_rng(seed)
    a = np.ones((H * SS, W * SS, 3)) * np.array(base, float)
    streak = rng.normal(0, 1, (H * SS, 1)) * 3 + rng.normal(0, 1.5, (H * SS, W * SS))
    a += streak[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA")


def equipment_label(out, key):
    W, H = 512, 256
    spec = {
        "generator": ("GENERATOR", "MINERAL WATER ONLY", (232, 184, 36), (20, 20, 20), True, "07-1142"),
        "distiller": ("DISTILLER", "SET CANTEEN HERE", (150, 158, 164), (20, 22, 26), False, "07-0387"),
        "charger": ("LIDAR CHARGER", "REQUIRES POWER", (40, 70, 110), (240, 236, 220), False, "07-2210"),
        "cover": ("POOL COVER", "PULL LEVER  ·  REQUIRES POWER", (176, 40, 36), (246, 240, 226), False, "07-0954"),
    }
    title, sub, paint, ink, hazard, num = spec[key]
    im = brushed(W, H, 100 + len(key), paint)
    d = ImageDraw.Draw(im)
    if hazard:
        for i in range(-2, 20):
            x = i * 40
            poly(d, [(x, H - 44), (x + 20, H - 44), (x + 40, H), (x + 20, H)], fill=(20, 20, 20))
        rect(d, 0, H - 48, W, H - 44, fill=(20, 20, 20))
    ft = fit("stencil", title, W - 60, 92, 3)
    tracked(d, W / 2, 98, title, ft, ink, 3)
    rect(d, 40, 152, W - 40, 156, fill=ink)
    tracked(d, W / 2, 182, sub, fit("stencil", sub, W - 70, 34, 2), ink, 2)
    if not hazard:
        tracked(d, W / 2, 228, f"F.A.L.C.O.N. PROPERTY  ·  NO. {num}", F("mono", 14), ink, 1)
    else:
        tracked(d, W / 2, 30, f"F.A.L.C.O.N. PROPERTY  ·  NO. {num}", F("mono", 14), ink, 1)
    for x, y in [(16, 16), (W - 16, 16), (16, H - 16), (W - 16, H - 16)]:
        ellipse(d, x, y, 7, fill=tuple(int(c * 0.7) for c in paint))
        ellipse(d, x - 1.5, y - 1.5, 3, fill=tuple(min(255, int(c * 1.2) + 30) for c in paint))
    im = worn(im, 110 + len(key), 0.8, chip_color=(90, 88, 84))
    return save(im, out, f"label_{key}.png")


def exit_sign(out):
    W, H = 512, 256
    im, d = new(W, H, (242, 240, 232))
    rect(d, 6, 6, W - 6, H - 6, outline=(200, 30, 30), width=5, r=10)
    tracked(d, W / 2, 128, "EXIT", F("sans", 150), (210, 26, 30), 16)
    for side in (-1, 1):
        x = W / 2 + side * 205
        poly(d, [(x + side * 20, 128), (x - side * 4, 98), (x - side * 4, 158)], fill=(210, 26, 30))
    tracked(d, W / 2, 222, "FIRE EXIT  ·  KEEP CLEAR", F("sans", 15), (170, 30, 30), 4)
    im = worn(im, 120, 0.5, chip_color=(120, 116, 110))
    return save(im, out, "exit_sign.png")


def halls_plaque(out):
    W, H = 1024, 640
    # brushed brass
    rng = np.random.default_rng(130)
    a = np.ones((H * SS, W * SS, 3)) * np.array((196, 158, 86), float)
    a += (rng.normal(0, 1, (H * SS, 1)) * 5 + rng.normal(0, 2, (H * SS, W * SS)))[..., None]
    yy, xx = np.mgrid[0:H * SS, 0:W * SS].astype(float)
    a *= (0.9 + 0.12 * np.cos((xx / (W * SS) - 0.35) * 3.0))[..., None]
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(im)
    ENG = (64, 42, 18)
    LIT = (244, 220, 160)

    def eng(x, y, s, fnt, track=0, anchor="m", fill=ENG):
        tracked(d, x + 0.9, y + 1.2, s, fnt, LIT, track, anchor)
        tracked(d, x, y, s, fnt, fill, track, anchor)
    rect(d, 18, 18, W - 18, H - 18, outline=ENG, width=4, r=12)
    rect(d, 28, 28, W - 28, H - 28, outline=ENG, width=1.5, r=8)
    for x, y in [(44, 44), (W - 44, 44), (44, H - 44), (W - 44, H - 44)]:
        ellipse(d, x, y, 9, fill=(150, 116, 56))
        line(d, [(x - 6, y - 6), (x + 6, y + 6)], ENG, 2, False)
    eng(W / 2, 90, "THE SHALLOW HALLS", fit("serif", "THE SHALLOW HALLS", W - 160, 84, 6), 6)
    eng(W / 2, 146, "F.A.L.C.O.N.  \u00b7  " + STATION + "  \u00b7  OBSERVATION LEVEL", F("sans", 18), 3)
    rect(d, 120, 170, W - 120, 172, fill=ENG)
    eng(W / 2, 212, "Something lives in the water. It hunts by sound.", fit("serifi", "Something lives in the water. It hunts by sound.", W - 200, 36))
    rules = ["Falling in is loud.", "Wading fast is loud.", "Hands in the water make noise.",
             "If you hear it coming, FREEZE."]
    for i, r in enumerate(rules):
        y = 284 + i * 68
        ellipse(d, 176, y, 25, outline=ENG, width=3.5)
        eng(176, y + 1, str(i + 1), F("serif", 30))
        eng(222, y, r, F("serif" if i == 3 else "serifr", 44), 0, "l")
    rect(d, 120, 548, W - 120, 550, fill=ENG)
    eng(W / 2, 586, "IT FEELS AROUND WITH ITS ARM. DON'T MOVE AT ALL.", fit("sans", "IT FEELS AROUND WITH ITS ARM. DON'T MOVE AT ALL.", W - 200, 26, 3), 3)
    im = worn(im, 131, 0.5, chip_color=(120, 92, 40))
    return save(im, out, "halls_plaque.png")


# ---------------------------------------------------------------- title screen and menu
def ripple_logo(out):
    W, H = 2048, 1024
    im, d = new(W, H)
    pale = (232, 240, 238)
    cyan = (120, 210, 226)
    wl = 640
    # rings spreading out on the water
    rings = Image.new("RGBA", im.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rings)
    for i in range(7):
        rx = 220 + i * 150
        a = int(200 * (1 - i / 7) ** 1.3)
        ellipse(rd, W / 2, wl + 40, rx, rx * 0.13, outline=cyan + (a,), width=6 - i * 0.6)
    im.alpha_composite(rings)
    fnt = fit("black", "RIPPLE", W - 420, 480, 40)
    m = text_mask("RIPPLE", fnt, 40)
    tw, th = m.size
    x0 = int(W / 2 * SS - tw / 2)
    y0 = int(wl * SS - th - 8 * SS)
    letters = tint(m, pale)
    im.alpha_composite(letters, (x0, y0))
    # the reflection: flipped, rippled sideways more the deeper it goes, fading out
    ref = m.transpose(Image.FLIP_TOP_BOTTOM)
    arr = np.asarray(ref, float)
    out_a = np.zeros_like(arr)
    for y in range(arr.shape[0]):
        k = y / arr.shape[0]
        shift = int(math.sin(y / (9 * SS) + 1.3) * (2 + 22 * k) * SS / 2)
        out_a[y] = np.roll(arr[y], shift)
        out_a[y] *= 0.55 * (1 - k) ** 1.6
    # gaps between the ripples' bands
    bands = (np.sin(np.arange(arr.shape[0]) / (5.5 * SS)) > -0.55).astype(float)[:, None]
    out_a *= bands
    refl = tint(Image.fromarray(out_a.clip(0, 255).astype(np.uint8)), cyan)
    im.alpha_composite(refl, (x0, int(wl * SS + 14 * SS)))
    # the waterline
    line(d, [(W / 2 - tw / SS / 2 - 80, wl + 6), (W / 2 + tw / SS / 2 + 80, wl + 6)], cyan + (180,), 4, False)
    return save(im, out, "ripple_logo.png", opaque=False)


def menu_header(out):
    W, H = 1024, 256
    im, d = new(W, H)
    rect(d, 8, 24, W - 8, H - 24, fill=NAVY, r=18)
    rect(d, 8, H - 58, W - 8, H - 50, fill=GOLD)
    rect(d, 8, H - 50, W - 8, H - 44, fill=RED)
    paste(im, seal(170), 108, 112)
    tracked(d, 214, 78, "F.A.L.C.O.N.", F("sans", 58), WHITE, 14, "l")
    tracked(d, 216, 138, "FIELD TERMINAL  ·  AUTHORIZED PERSONNEL ONLY", fit("mono", "FIELD TERMINAL  ·  AUTHORIZED PERSONNEL ONLY", 620, 22), GOLD, 0, "l")
    tracked(d, W - 32, 52, "SYS 07-W  v1.91", F("mono", 15), (150, 164, 210), 0, "r")
    ellipse(d, W - 40, 80, 6, fill=(80, 220, 120))
    tracked(d, W - 54, 80, "ONLINE", F("mono", 15), (150, 164, 210), 0, "r")
    return save(im, out, "menu_header.png", opaque=False)


def run(out):
    res = [training_sign(out)] + [room_title(out, n) for n in range(1, 8)] + [noise_meter(out)]
    res += [warning_sign(out, k) for k in ("no_diving", "no_running", "staff_only", "deep_water", "no_drinking")]
    res += [equipment_label(out, k) for k in ("generator", "distiller", "charger", "cover")]
    res += [exit_sign(out), halls_plaque(out), ripple_logo(out), menu_header(out)]
    return res


if __name__ == "__main__":
    import sys, os
    o = sys.argv[1]
    os.makedirs(o, exist_ok=True)
    run(o)
