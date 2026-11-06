# PART 2 of the branding requests: the lobby of Pinewater Field Station (visitor reception).
# Pamphlets, posters, the station sign, the framed certificate and the small things.
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageOps
from kit import *  # noqa: F401,F403
from kit import TAPE

STATION = "PINEWATER FIELD STATION"
TEAL = (24, 118, 140)
WATER = (60, 150, 176)


# ---------------------------------------------------------------- pamphlets
PAPERS = [(198, 218, 236), (246, 238, 170), (226, 206, 232), (244, 204, 208), (206, 230, 200), (248, 214, 184)]


def tape_sign(name, height):
    im = Image.open(f"{TAPE}/assets/made/sign_{name}.png").convert("RGBA")
    h = int(height * SS)
    return im.resize((int(im.size[0] * h / im.size[1]), h), Image.LANCZOS)


def ripples(d, cx, cy, n, rx, ry, color, width):
    for i in range(n):
        k = (i + 1) / n
        ellipse(d, cx, cy, rx * k, ry * k, outline=color, width=width * (1.2 - k * 0.5))


def footprint(d, x, y, s, ang, color, left=True):
    """A bare footprint pointing along ang (radians): heel, arch, ball and five toes; s = length."""
    ca, sa = math.cos(ang), math.sin(ang)

    def at(u, v):
        return x + u * ca - v * sa, y + u * sa + v * ca
    m = -1 if left else 1
    pts = []
    for t in np.linspace(0, 2 * math.pi, 40):
        u = 0.32 + 0.32 * math.cos(t)                      # along the foot, 0 (heel) .. 0.64 (ball)
        wid = 0.13 + 0.07 * (u / 0.64) ** 1.5              # wider at the ball
        if math.sin(t) * m > 0:
            wid *= 0.55 + 0.45 * abs(u - 0.32) / 0.32      # the arch, on the inside
        pts.append(at(u * s, math.sin(t) * wid * s))
    poly(d, pts, fill=color)
    for v, r, du in [(-0.15, 0.075, 0.0), (-0.04, 0.055, 0.02), (0.05, 0.05, 0.0), (0.13, 0.045, -0.03), (0.2, 0.04, -0.07)]:
        cx, cy = at((0.78 + du) * s, m * v * s)
        ellipse(d, cx, cy, r * s, fill=color)


def icon_tooth(d, cx, cy, s, c):
    poly(d, [(cx - s * 0.5, cy - s * 0.35), (cx - s * 0.25, cy - s * 0.5), (cx, cy - s * 0.4), (cx + s * 0.25, cy - s * 0.5),
             (cx + s * 0.5, cy - s * 0.35), (cx + s * 0.42, cy + s * 0.05), (cx + s * 0.3, cy + s * 0.5),
             (cx + s * 0.14, cy + s * 0.5), (cx, cy + s * 0.12), (cx - s * 0.14, cy + s * 0.5), (cx - s * 0.3, cy + s * 0.5),
             (cx - s * 0.42, cy + s * 0.05)], fill=c)


def icon_coins(d, cx, cy, s, c, bg):
    for i in range(4):
        y = cy + s * 0.35 - i * s * 0.2
        rect(d, cx - s * 0.42, y - s * 0.06, cx + s * 0.42, y + s * 0.06, fill=c)
        ellipse(d, cx, y - s * 0.06, s * 0.42, s * 0.12, fill=c, outline=bg, width=2)


def icon_tissue(d, cx, cy, s, c, bg):
    rect(d, cx - s * 0.48, cy - s * 0.1, cx + s * 0.48, cy + s * 0.42, fill=c)
    ellipse(d, cx, cy - s * 0.02, s * 0.2, s * 0.06, fill=bg)
    poly(d, [(cx - s * 0.1, cy - s * 0.04), (cx - s * 0.2, cy - s * 0.5), (cx + s * 0.05, cy - s * 0.38),
             (cx + s * 0.22, cy - s * 0.55), (cx + s * 0.12, cy - s * 0.04)], fill=c)


def pamphlet(out, n):
    W, H = 256, 512
    im, d = new(W, H, (255, 255, 255))
    K = (24, 24, 28)
    # header: the seal and the agency
    paste(im, seal(78), W / 2, 52)
    tracked(d, W / 2, 106, "F.A.L.C.O.N.", F("sans", 17), K, 5)
    tracked(d, W / 2, 124, "TRAINING DIVISION", F("sansr", 10), K, 3)
    rect(d, 24, 136, W - 24, 138, fill=K)
    titles = {1: ("WATER", "SAFETY"), 2: ("YOUR", "FIRST DAY"), 3: ("LIMINAL", "ENTITIES"),
              4: ("IF YOU ARE", "TAKEN"), 5: ("STAFF", "BENEFITS"), 6: ("WET", "FOOTPRINTS?")}
    t1, t2 = titles[n]
    f1 = fit("sans", t1, W - 30, 40)
    f2 = fit("sans", t2, W - 30, 44)
    tracked(d, W / 2, 168, t1, f1, K)
    tracked(d, W / 2, 210, t2, f2, K)
    cy = 322
    if n == 1:
        paste(im, tape_sign("fall", 120), W / 2, cy)
        sub = ["Stay dry. Stay quiet.", "Stay still."]
    elif n == 2:
        put(im, person("stand", 112), W / 2 - 34, cy, K)
        put(im, person("woman", 112), W / 2 + 34, cy, K)
        ellipse(d, W / 2 + 74, cy - 70, 16, outline=K, width=3)
        line(d, [(W / 2 + 66, cy - 70), (W / 2 + 72, cy - 63), (W / 2 + 84, cy - 78)], K, 3, False)
        sub = ["Welcome to the Agency!", "Sign in. Watch Tape 07-W."]
    elif n == 3:
        put(im, wader(124), W / 2 - 6, cy + 2, K)
        rect(d, W / 2 + 44, cy - 66, W / 2 + 94, cy - 42, outline=K, width=2.5)
        tracked(d, W / 2 + 69, cy - 54, "L-7", F("sans", 14), K)
        sub = ["A field guide.", "Vol. 1: L-1 to L-9"]
    elif n == 4:
        waves(d, 20, W - 20, cy - 6, 3, 34, 3, K, 1)
        ripples(d, W / 2, cy + 26, 4, 96, 26, K, 3)
        ellipse(d, W / 2, cy + 26, 6, 2, fill=K)
        sub = ["Don't panic. Your desk will", "be cleared within 48 hours."]
    elif n == 5:
        for i, (fn, lab) in enumerate([(icon_tooth, "DENTAL"), (icon_coins, "PENSION"), (icon_tissue, "GRIEF")]):
            x = 52 + i * 76
            if fn is icon_tooth:
                fn(d, x, cy - 14, 50, K)
            else:
                fn(d, x, cy - 14, 50, K, (255, 255, 255))
            tracked(d, x, cy + 34, lab, F("sans", 11), K, 1)
        sub = ["Dental. Pension.", "Grief counselling."]
    else:
        for i in range(4):
            footprint(d, W / 2 - 40 + (i % 2) * 40, cy + 70 - i * 42, 44, -math.pi / 2 - 0.06, K, i % 2 == 0)
        put(im, drop(30), W / 2 + 70, cy - 40, K)
        sub = ["Report them to your supervisor.", "Do not follow them."]
    for i, s_ in enumerate(sub):
        tracked(d, W / 2, 418 + i * 19, s_, fit("sans", s_, W - 28, 15), K)
    rect(d, 24, 466, W - 24, 467, fill=K)
    tracked(d, W / 2, 482, f"FORM TD-{10 + n:02d}  ·  REV. 3/91", F("mono", 10), K, 1)
    tracked(d, W / 2, 497, "TAKE ONE", F("sans", 9), K, 3)
    # print it: grey ink, multiplied onto coloured copier paper, with copier speckle
    g = ImageOps.grayscale(im.convert("RGB"))
    g = g.point(lambda v: int(30 + v * 225 / 255))
    pap, _ = paper(W, H, 40 + n, PAPERS[n - 1], 2.5, 0.6)
    ink = Image.merge("RGB", [g, g, g])
    out_im = ImageChops.multiply(pap.convert("RGB"), ink).convert("RGBA")
    out_im = photocopy(out_im, 50 + n, 1.0)
    return save(out_im, out, f"pamphlet_{n}.png")


# ---------------------------------------------------------------- posters
def poster_freeze(out):
    W, H = 768, 1024
    im, d = new(W, H, NAVY)
    # the pool in cross-section
    wy = 700
    rect(d, 0, wy, W, H, fill=TEAL)
    for k in range(4):
        rect(d, 0, wy + 60 + k * 70, W, wy + 62 + k * 70, fill=(34, 132, 156))
    # the Wader, crawling along under the surface towards them
    wm = wader(200, "search", 14)
    lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    put(lay, wm, 230, 822, (8, 26, 44))
    im.alpha_composite(lay)
    # the person standing still, knee-deep
    put(im, person("stand", 300), 560, 780, WHITE)
    rect(d, 0, wy + 3, W, H, fill=TEAL + (120,))
    waves(d, 0, W, wy, 4, 120, 6, (130, 214, 236), 1)
    # its clicking, coming up out of the water at them
    for i in range(4):
        r = 120 + i * 50
        d.arc([(250 - r) * SS, (760 - r) * SS, (250 + r) * SS, (760 + r) * SS], 285, 330, fill=GOLD, width=int(9 * SS))
    tracked(d, W / 2, 112, "IF YOU HEAR IT COMING,", fit("sans", "IF YOU HEAR IT COMING,", W - 80, 58, 2), GOLD, 2)
    tracked(d, W / 2, 232, "FREEZE.", fit("black", "FREEZE.", W - 90, 190, 6), WHITE, 6)
    tracked(d, W / 2, 350, "It hunts by sound. Don't move at all.", fit("sans", "It hunts by sound. Don't move at all.", W - 120, 30), (210, 220, 240))
    rect(d, 0, H - 96, W, H, fill=(10, 16, 46))
    paste(im, seal(70), 60, H - 48)
    tracked(d, 110, H - 58, "F.A.L.C.O.N. SAFETY NOTICE NO. 4", F("sans", 22), WHITE, 3, "l")
    tracked(d, 110, H - 30, "FEDERAL AGENCY FOR LIMINAL CLASSIFICATION & OCCULT NATURE", F("sansr", 13), GOLD, 1.5, "l")
    im = worn(im, 61, 0.6)
    return save(im, out, "poster_1.png")


def poster_recruit(out):
    W, H = 768, 1024
    im, d = new(W, H, NAVY)
    cx, cy = W / 2, 520
    for k in range(24):
        a0 = math.radians(k * 15)
        poly(d, [(cx, cy), (cx + math.cos(a0) * 1200, cy + math.sin(a0) * 1200),
                 (cx + math.cos(a0 + math.radians(7.5)) * 1200, cy + math.sin(a0 + math.radians(7.5)) * 1200)],
             fill=(30, 50, 128))
    ellipse(d, cx, cy, 250, fill=GOLD)
    paste(im, seal(460), cx, cy)
    rect(d, 0, 0, W, 190, fill=CREAM)
    rect(d, 0, 190, W, 200, fill=RED)
    tracked(d, W / 2, 70, "SEE WHAT", F("black", 84), NAVY, 6)
    tracked(d, W / 2, 148, "OTHERS CAN'T", F("black", 72), RED, 4)
    rect(d, 0, H - 230, W, H - 220, fill=RED)
    rect(d, 0, H - 220, W, H, fill=CREAM)
    tracked(d, W / 2, H - 160, "F.A.L.C.O.N. NEEDS YOU", fit("black", "F.A.L.C.O.N. NEEDS YOU", W - 70, 64, 2), NAVY, 2)
    tracked(d, W / 2, H - 92, "Steady work. Federal pension. Field training provided.", fit("sans", "Steady work. Federal pension. Field training provided.", W - 90, 24), INK)
    tracked(d, W / 2, H - 52, "INQUIRE AT ANY FIELD STATION", F("sans", 22), RED, 5)
    im = worn(im, 62, 0.6)
    return save(im, out, "poster_2.png")


def poster_quiet(out):
    W, H = 768, 1024
    im, d = paper(W, H, 63, CREAM, 3, 0.8)
    fq = fit("black", "QUIET HANDS", W - 90, 104, 3)
    tracked(d, W / 2, 96, "QUIET HANDS", fq, NAVY, 3)
    tracked(d, W / 2, 210, "SAVE LIVES", fq, RED, 3)
    # two panels, the right way and the wrong way
    for i, (kind, ok) in enumerate([("walk", True), ("run", False)]):
        x0 = 40 + i * 354
        rect(d, x0, 300, x0 + 334, 700, fill=NAVY)
        wy = 560
        rect(d, x0, wy, x0 + 334, 700, fill=TEAL)
        put(im, person(kind, 230), x0 + 167, 640, WHITE)
        rect(d, x0, wy + 2, x0 + 334, 700, fill=TEAL + (190,))
        if ok:
            waves(d, x0 + 6, x0 + 328, wy, 2, 60, 4, (150, 220, 236), 1)
            ripples(d, x0 + 167, wy + 4, 2, 70, 8, (150, 220, 236), 3)
        else:
            waves(d, x0 + 6, x0 + 328, wy, 9, 40, 5, (150, 220, 236), 1)
            rng = np.random.default_rng(3)
            for k in range(14):
                a = math.radians(rng.uniform(200, 340))
                r = rng.uniform(60, 130)
                ellipse(d, x0 + 167 + math.cos(a) * r, wy + math.sin(a) * r * 0.8, rng.uniform(5, 10), fill=(190, 236, 246))
        # verdict badge
        bx, by = x0 + 290, 344
        ellipse(d, bx, by, 32, fill=(40, 150, 80) if ok else RED)
        if ok:
            line(d, [(bx - 15, by + 1), (bx - 4, by + 12), (bx + 16, by - 12)], WHITE, 8, False)
        else:
            line(d, [(bx - 13, by - 13), (bx + 13, by + 13)], WHITE, 8, False)
            line(d, [(bx - 13, by + 13), (bx + 13, by - 13)], WHITE, 8, False)
        tracked(d, x0 + 167, 740, "SLOW AND STILL" if ok else "SPLASHING", F("sans", 30), NAVY if ok else RED, 3)
    para(d, W / 2, 800, "Keep your hands out of the water. Wade slowly. Everything you do in the water can be heard.",
         F("sans", 27), INK, W - 140, 1.35, "m")
    rect(d, 40, H - 96, W - 40, H - 94, fill=NAVY)
    paste(im, seal(56), 76, H - 52)
    tracked(d, 116, H - 52, "F.A.L.C.O.N. SAFETY NOTICE NO. 7", F("sans", 20), NAVY, 3, "l")
    im = worn(im, 64, 0.4, chip_color=(200, 190, 170))
    return save(im, out, "poster_3.png")


def poster_rules(out):
    W, H = 768, 1024
    im, d = paper(W, H, 65, CREAM, 3, 0.8)
    rect(d, 0, 0, W, 200, fill=NAVY)
    rect(d, 0, 200, W, 212, fill=RED)
    rect(d, 0, 212, W, 218, fill=GOLD)
    paste(im, seal(150), 110, 100)
    tracked(d, 200, 82, "VISITOR RULES", fit("black", "VISITOR RULES", W - 230, 76), WHITE, 2, "l")
    tracked(d, 202, 146, STATION, F("sans", 24), GOLD, 4, "l")
    rules = ["Sign in at reception.", "Stay with your escort at all times.", "Do not enter the pools.",
             "Report wet footprints to staff.", "If you hear clicking, stand still.", "Sign out before you leave."]
    for i, r in enumerate(rules):
        y = 290 + i * 104
        ellipse(d, 92, y, 36, fill=RED)
        tracked(d, 92, y + 1, str(i + 1), F("black", 44), WHITE)
        tracked(d, 150, y, r, fit("sans", r, W - 190, 38), INK, 0, "l")
        if i < len(rules) - 1:
            rect(d, 150, y + 52, W - 50, y + 53, fill=(180, 172, 150))
    rect(d, 0, H - 86, W, H, fill=NAVY)
    tracked(d, W / 2, H - 43, "THANK YOU FOR YOUR COOPERATION", F("sans", 26), WHITE, 5)
    im = worn(im, 66, 0.4, chip_color=(200, 190, 170))
    return save(im, out, "poster_4.png")


# ---------------------------------------------------------------- station sign
def wood(w, h, seed, base=(118, 74, 42)):
    """Stained pine boards (canvas scale), grain running along x."""
    W, H = w * SS, h * SS
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    n = noise(W, H, seed, 0, 48)
    g = np.sin((yy + n * 26 + np.sin(xx / (W * 0.21)) * 18) / (5.5 * SS)) * 0.5 + 0.5
    g2 = np.sin((yy + n * 60) / (1.7 * SS)) * 0.5 + 0.5
    shade = 0.82 + 0.12 * g + 0.06 * g2
    rng = np.random.default_rng(seed)
    a = np.ones((H, W, 3)) * np.array(base, float) * shade[..., None]
    a += rng.normal(0, 2.5, (H, W, 1))
    # knots
    for _ in range(3):
        kx, ky, kr = rng.uniform(0, W), rng.uniform(0, H), rng.uniform(6, 12) * SS
        dd = np.hypot((xx - kx) / 1.6, yy - ky)
        a *= (1 - 0.35 * np.exp(-(dd / kr) ** 2))[..., None]
        a *= (1 - 0.08 * (np.sin(dd / (2 * SS)) * 0.5 + 0.5) * np.exp(-(dd / (kr * 3)) ** 2))[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA")


def carved(im, mask, x, y, paint=(238, 222, 176), depth=2.0):
    """Routed lettering: a dark recess, painted, with a lit lower edge and shadowed upper edge."""
    sh = tint(mask, (20, 10, 4), 0.85)
    hi = tint(mask, (255, 236, 196), 0.6)
    paste(im, hi, x + depth * 0.5, y + depth)
    paste(im, sh, x - depth * 0.3, y - depth * 0.8)
    m2 = mask.filter(ImageFilter.MinFilter(3))
    paste(im, tint(m2, paint), x, y)


def station_sign(out):
    W, H = 1024, 256
    im = wood(W, H, 70)
    d = ImageDraw.Draw(im)
    # routed border groove
    for inset, col in [(12, (40, 22, 10)), (14, (150, 100, 60))]:
        rect(d, inset, inset, W - inset, H - inset, outline=col, width=3, r=10)
    for x in (110, W - 110):
        ellipse(d, x, H / 2, 94, fill=(30, 16, 8))
        paste(im, seal(178), x, H / 2)
    title = text_mask("PINEWATER", fit("slab", "PINEWATER", 560, 84, 4), 4)
    carved(im, title, W / 2, 98, depth=3)
    sub = text_mask("FIELD STATION", F("slab", 40), 8)
    carved(im, sub, W / 2, 168)
    rect(d, 300, 196, W - 300, 199, fill=(232, 210, 160))
    vr = text_mask("VISITOR RECEPTION", F("sans", 22), 9)
    carved(im, vr, W / 2, 221, (236, 196, 70), 1.5)
    im = worn(im, 71, 0.5, chip_color=(60, 36, 18), scratches=True)
    return save(im, out, "station_sign.png")


# ---------------------------------------------------------------- framed certificate
def notice(out):
    W, H = 512, 512
    im, d = paper(W, H, 72, (240, 234, 216), 2.5, 0.9)
    rect(d, 16, 16, W - 16, H - 16, outline=NAVY, width=4)
    rect(d, 26, 26, W - 26, H - 26, outline=GOLD, width=2)
    for cx, cy in [(26, 26), (W - 26, 26), (26, H - 26), (W - 26, H - 26)]:
        poly(d, [(cx, cy - 12), (cx + 12, cy), (cx, cy + 12), (cx - 12, cy)], fill=NAVY)
    tracked(d, W / 2, 62, "FEDERAL AGENCY FOR LIMINAL CLASSIFICATION & OCCULT NATURE", fit("sans", "FEDERAL AGENCY FOR LIMINAL CLASSIFICATION & OCCULT NATURE", W - 90, 12, 1), NAVY, 1)
    tracked(d, W / 2, 100, "Certificate", F("fat", 46), NAVY)
    tracked(d, W / 2, 140, "OF CONTAINMENT", F("serif", 22), RED, 6)
    para(d, W / 2, 168, "This is to certify that", F("serifi", 15), INK, W - 100, 1.3, "m")
    tracked(d, W / 2, 205, STATION, fit("serif", STATION, W - 90, 26), NAVY)
    para(d, W / 2, 226, "has been inspected and found fit for the observation of Liminal Entity L-7 (“The Wader”) "
         "under Class II containment procedures.", F("serifr", 15), INK, W - 110, 1.35, "m")
    tracked(d, W / 2, 318, "Inspected 14 March 1991. Valid until revoked.", F("serifi", 13), INK)
    # gold foil seal, lower left
    cx, cy = 116, 410
    pts = []
    for k in range(48):
        r = 62 if k % 2 == 0 else 54
        a = math.radians(k * 7.5)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    poly(d, pts, fill=(214, 168, 52))
    ellipse(d, cx, cy, 50, fill=(238, 196, 80))
    paste(im, seal_mono(86, (150, 108, 24), True), cx, cy)
    poly(d, [(cx - 30, cy + 46), (cx - 44, cy + 92), (cx - 24, cy + 82), (cx - 12, cy + 96), (cx - 4, cy + 50)], fill=RED)
    poly(d, [(cx + 30, cy + 46), (cx + 44, cy + 92), (cx + 24, cy + 82), (cx + 12, cy + 96), (cx + 4, cy + 50)], fill=RED)
    # signature
    tracked(d, 350, 400, "R. Albrecht", F("hand3", 40), (20, 30, 90))
    rect(d, 250, 422, 450, 423.5, fill=INK)
    tracked(d, 350, 436, "R. ALBRECHT", F("sans", 11), INK, 2)
    tracked(d, 350, 452, "Director, Field Operations", F("serifi", 12), INK)
    return save(im, out, "notice.png")


# ---------------------------------------------------------------- small things
def keyfob(out):
    W, H = 128, 256
    im, d = new(W, H, (238, 238, 234))
    # the diamond's raised rim
    dia = [(W / 2, 6), (W - 8, H / 2), (W / 2, H - 6), (8, H / 2)]
    poly(d, dia, outline=(196, 196, 192), width=4)
    poly(d, [(W / 2, 14), (W - 16, H / 2), (W / 2, H - 14), (16, H / 2)], outline=(218, 218, 214), width=2)
    # the key ring's hole
    ellipse(d, W / 2, 34, 10, fill=(150, 150, 150))
    ellipse(d, W / 2, 34, 6, fill=(60, 60, 60))
    tracked(d, W / 2, 74, "F.A.L.C.O.N.", F("sans", 10.5), (120, 120, 120), 1.5)
    tracked(d, W / 2, 132, "D-", F("black", 46), (90, 90, 90))
    rect(d, 34, 166, W - 34, 168, fill=(150, 150, 150))
    for i, s_ in enumerate(["DROP IN ANY", "MAILBOX.", "POSTAGE", "GUARANTEED."]):
        tracked(d, W / 2, 182 + i * 9, s_, F("sans", 6.4), (140, 140, 140), 0.3)
    return save(im, out, "keyfob.png")


def signin_page(out):
    W, H = 512, 512
    im, d = paper(W, H, 74, (244, 240, 226), 2.0, 0.7)
    BL = (120, 160, 200)
    tracked(d, W / 2, 26, "VISITORS' REGISTER  ·  " + STATION, fit("sans", "VISITORS' REGISTER  ·  " + STATION, W - 40, 14, 1), NAVY, 1)
    cols = [16, 196, 336, 420, 496]
    heads = ["NAME", "VISITING", "TIME IN", "TIME OUT"]
    top, row = 46, 40
    rect(d, cols[0], top, cols[-1], top + 26, fill=(214, 222, 232))
    for i, h_ in enumerate(heads):
        tracked(d, (cols[i] + cols[i + 1]) / 2, top + 13, h_, F("sans", 11), NAVY, 1.5)
    for k in range(12):
        y = top + 26 + k * row
        rect(d, cols[0], y, cols[-1], y + 1, fill=BL)
    for x in cols:
        rect(d, x, top, x + 1, top + 26 + 11 * row, fill=(200, 110, 110) if x == cols[1] else BL)
    entries = [
        ("hand4", (24, 30, 80), ["Margaret Okafor", "Payroll", "8:40", "9:15"]),
        ("hand1", (30, 30, 34), ["T. Brennan", "Dr. Hale", "10:05", "11:30"]),
        ("hand3", (24, 40, 120), ["Gary Pruitt (plumbing)", "Pool 2 drain", "1:20", "4:45"]),
        ("hand4", (30, 30, 34), ["R. Delgado", "Survey, Pool 4", "2:10", ""]),
        ("hand2", (24, 30, 80), ["Linda + Sam Voss", "Open day", "3:00", "3:40"]),
        ("hand1", (40, 40, 60), ["Ed Kowalczyk", "Vending machine", "4:15", "4:30"]),
    ]
    sizes = {"hand1": 30, "hand2": 21, "hand3": 24, "hand4": 21}
    for i, (fn, col, cells) in enumerate(entries):
        y = top + 26 + i * row + row * 0.55
        for c, txt in enumerate(cells):
            if txt:
                fnt = fit(fn, txt, cols[c + 1] - cols[c] - 10, sizes[fn])
                tracked(d, cols[c] + 6, y, txt, fnt, col, 0, "l")
    # a later entry, shaky, and the page wet around it
    y = top + 26 + 7 * row + row * 0.55
    stain = Image.new("L", im.size, 0)
    sd = ImageDraw.Draw(stain)
    rng = np.random.default_rng(9)
    for k in range(9):
        ellipse(sd, 210 + rng.uniform(-110, 110), y + rng.uniform(-14, 18), rng.uniform(30, 60), rng.uniform(16, 30), fill=255)
    stain = stain.filter(ImageFilter.GaussianBlur(10 * SS))
    edge = ImageChops.subtract(stain.point(lambda v: 255 if v > 90 else 0).filter(ImageFilter.GaussianBlur(2 * SS)),
                               stain.point(lambda v: 255 if v > 120 else 0).filter(ImageFilter.GaussianBlur(3 * SS)))
    im.alpha_composite(tint(stain.point(lambda v: 255 if v > 90 else 0).filter(ImageFilter.GaussianBlur(3)),
                            (200, 186, 140), 0.22))
    im.alpha_composite(tint(edge, (140, 116, 70), 0.75))
    shaky = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sk = ImageDraw.Draw(shaky)
    for c, txt in enumerate(["R. Delgado", "home", "3:33 AM"]):
        fnt = fit("hand1", txt, cols[c + 1] - cols[c] - 10, 30)
        tracked(sk, cols[c] + 6, y, txt, fnt, (30, 30, 50), 0, "l")
    shaky = shaky.transform(shaky.size, Image.MESH, [((0, 0, shaky.size[0], shaky.size[1]),
                                                     (0, 0, 0, shaky.size[1], shaky.size[0], shaky.size[1] + 6, shaky.size[0], 4))])
    blurred = shaky.filter(ImageFilter.GaussianBlur(1.6 * SS))
    im.alpha_composite(blurred)
    im.alpha_composite(shaky)
    return save(im, out, "signin_page.png")


def mail_note(out):
    W, H = 256, 256
    im, d = paper(W, H, 75, (246, 242, 214), 2.0, 0.5)
    rect(d, 0, 0, W, 38, fill=NAVY)
    paste(im, seal(30), 22, 19)
    tracked(d, 44, 14, "F.A.L.C.O.N.", F("sans", 12), WHITE, 3, "l")
    tracked(d, 44, 28, "INTER-OFFICE MEMO", F("sansr", 9), GOLD, 2, "l")
    for k in range(7):
        rect(d, 10, 66 + k * 26, W - 10, 66.6 + k * 26, fill=(170, 190, 214))
    hand = F("hand4", 17)
    lines_ = ["Dave -", "your waders are still in", "the drying room.", "They're still wet.", "It's been 3 weeks.",
              "               - M."]
    for i, s_ in enumerate(lines_):
        tracked(d, 16, 56 + i * 26, s_, hand, (28, 36, 110), 0, "l")
    return save(im, out, "mail_note.png")


def door_decal(out):
    W, H = 512, 512
    im, d = new(W, H)
    wcol = (255, 255, 255)
    paste(im, seal_mono(220, wcol), W / 2, 130)
    tracked(d, W / 2, 284, "F.A.L.C.O.N.", F("sans", 50), wcol, 12)
    tracked(d, W / 2, 330, STATION, fit("sans", STATION, 420, 24, 4), wcol, 4)
    rect(d, 96, 352, W - 96, 354, fill=wcol)
    tracked(d, W / 2, 386, "VISITOR ENTRANCE", F("sans", 34), wcol, 4)
    tracked(d, W / 2, 428, "PLEASE SIGN IN AT RECEPTION", F("sansr", 17), wcol, 3)
    tracked(d, W / 2, 456, "OPEN 24 HOURS", F("sansr", 15), wcol, 4)
    return save(im, out, "door_decal.png", opaque=False)


def neon_design(out):
    W, H = 1024, 512
    im, d = new(W, H)
    wcol = (255, 255, 255)
    lw = 9
    # a pine tree, drawn as one tube
    tx, base = 170, 400
    outline_pts = [(tx, 90), (tx - 58, 175), (tx - 26, 175), (tx - 90, 265), (tx - 40, 265), (tx - 122, 355),
                   (tx - 18, 355), (tx - 18, 410), (tx + 18, 410), (tx + 18, 355), (tx + 122, 355), (tx + 40, 265),
                   (tx + 90, 265), (tx + 26, 175), (tx + 58, 175), (tx, 90)]
    line(d, outline_pts, wcol, lw, True)
    for x, y in outline_pts:
        ellipse(d, x, y, lw / 2, fill=wcol)
    # the name in a monoline script, thickened to an even tube
    m = text_mask("Pinewater", F("neon", 230))
    g, pad = grow(m, 2.2 * SS)
    paste(im, tint(g, wcol), 620, 236)
    # water under it
    pts = [(330 + t * 600, 392 + math.sin(t * math.pi * 6) * 12) for t in np.linspace(0, 1, 200)]
    line(d, pts, wcol, lw)
    pts = [(420 + t * 420, 432 + math.sin(t * math.pi * 4 + 1) * 9) for t in np.linspace(0, 1, 160)]
    line(d, pts, wcol, lw)
    for (x, y) in [(330, 392), (930, 392), (420, 432 + math.sin(1) * 9), (840, 432 + math.sin(4 * math.pi + 1) * 9)]:
        ellipse(d, x, y, lw / 2, fill=wcol)
    return save(im, out, "neon_design.png", opaque=False)


def clock_face(out):
    W, H = 512, 512
    im, d = new(W, H)
    c = W / 2
    ellipse(d, c, c, 252, fill=NAVY)
    ellipse(d, c, c, 238, fill=CREAM)
    ellipse(d, c, c, 232, outline=GOLD, width=3)
    for k in range(60):
        a = math.radians(k * 6 - 90)
        r0 = 222 if k % 5 else 206
        w = 2.4 if k % 5 else 6
        line(d, [(c + math.cos(a) * r0, c + math.sin(a) * r0), (c + math.cos(a) * 226, c + math.sin(a) * 226)], NAVY, w, False)
    fn = F("sans", 40)
    for h in range(1, 13):
        a = math.radians(h * 30 - 90)
        tracked(d, c + math.cos(a) * 176, c + math.sin(a) * 176 + 1, str(h), fn, NAVY)
    paste(im, seal(140), c, c + 6)
    tracked(d, c, 146, "F.A.L.C.O.N.", F("sans", 15), NAVY, 4)
    tracked(d, c, 376, "STANDARD ISSUE", F("sans", 11), RED, 3)
    return save(im, out, "clock_face.png", opaque=False)


def rug_logo(out):
    W, H = 512, 512
    # the seal, simplified to a few yarn colours on a coarse stitch grid
    cells = 104
    s = seal(W).resize((cells, cells), Image.LANCZOS)
    a = np.asarray(s).astype(float)
    pal = np.array([NAVY, GOLD, CREAM, (250, 248, 240), (40, 36, 34), (128, 116, 100)], float)
    rgb = a[..., :3]
    idx = np.argmin(((rgb[:, :, None, :] - pal[None, None]) ** 2).sum(-1), axis=2)
    q = pal[idx]
    alpha = (a[..., 3] > 128).astype(float)
    big = np.repeat(np.repeat(q, W * SS // cells + 1, 0), W * SS // cells + 1, 1)[:W * SS, :W * SS]
    al = np.repeat(np.repeat(alpha, W * SS // cells + 1, 0), W * SS // cells + 1, 1)[:W * SS, :W * SS]
    # a knit "V" in every cell
    cs = W * SS / cells
    yy, xx = np.mgrid[0:W * SS, 0:W * SS].astype(float)
    u = (xx % cs) / cs
    v = (yy % cs) / cs
    vee = np.abs(u - 0.5) * 2
    shade = 0.78 + 0.32 * np.clip(1 - np.abs(v - vee * 0.8 - 0.1) * 2.2, 0, 1)
    rng = np.random.default_rng(76)
    big = big * shade[..., None] * (1 + rng.normal(0, 0.03, (W * SS, W * SS, 1)))
    img = np.dstack([np.clip(big, 0, 255), al * 255]).astype(np.uint8)
    im = Image.fromarray(img, "RGBA")
    # a binding round the edge
    edge = Image.new("L", im.size, 0)
    ed = ImageDraw.Draw(edge)
    ellipse(ed, W / 2, W / 2, W / 2 - 1, fill=255)
    ellipse(ed, W / 2, W / 2, W / 2 - 9, fill=0)
    im.alpha_composite(tint(edge, (30, 26, 40)))
    return save(im, out, "rug_logo.png", opaque=False)


def run(out):
    res = [pamphlet(out, n) for n in range(1, 7)]
    res += [poster_freeze(out), poster_recruit(out), poster_quiet(out), poster_rules(out), station_sign(out), notice(out),
            keyfob(out), signin_page(out), mail_note(out), door_decal(out), neon_design(out), clock_face(out), rug_logo(out)]
    return res


if __name__ == "__main__":
    import sys, os
    o = sys.argv[1]
    os.makedirs(o, exist_ok=True)
    run(o)
