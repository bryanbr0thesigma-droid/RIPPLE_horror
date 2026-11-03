# The tape's scenes. Each draw function gets the canvas, the time t in seconds since the scene
# started, and the scene (sc.m: when each narration line or mark starts, sc.e: when each line
# ends, sc.dur). Every diagram is a side cross-section of the poolrooms.
import math
from functools import lru_cache
import numpy as np
from PIL import Image
import gfx
from gfx import *

ENVS = {}  # loudness envelopes of the creature clips (100 per second), filled in by tape.py


def walk(t, rate=2.0, a="walk1", b="walk2"):
    return a if int(t * rate) % 2 == 0 else b


def tw(s, size, f="sans", track=0):
    return font(f, size).getlength(s) / S + track * (len(s) - 1)


def wading(x, t, rate=1.6, strength=0.5, life=1.6):
    """Ripple events from footsteps of someone wading at x."""
    ev = []
    k0 = int((t - life) * rate)
    for k in range(max(0, k0), int(t * rate) + 1):
        ev.append((x + (6 if k % 2 else -6), k / rate, strength))
    return ev


def section_base(c, dx=200, dy=290, fy=372, bg=NAVY, deck_left=True):
    c.rect(0, 0, W, H, fill=bg)
    back_wall(c, bg)
    hatch(c, dx if deck_left else 0, fy, W, H)
    if deck_left and dx > 0:
        deck(c, 0, dx, dy)


def wader_side(c, x, floor, h, t, flip=False, col=BLACK, alpha=1.0, name="side_idle"):
    hh = h if name == "side_idle" else h * gfx._sil_data()[name][1]["h"] / gfx._sil_data()["side_idle"][1]["h"]
    return sil(c, name, sil_frame(name, t), x, floor, hh, col, flip, alpha)


def bob(t, amt=2.0, rate=2.4):
    return abs(math.sin(t * rate * math.pi / 2)) * amt


# ---------------------------------------------------------------- cold open
def vcr(c, t, sc):
    blue = 0.6 <= t < sc.dur - 0.45
    c.rect(0, 0, W, H, fill=VCR_BLUE if blue else BLACK)


def osd(c, text, shape="play"):
    c.text(46, 44, text, 26, WHITE, "osd", "lm", 2)
    x = 46 + tw(text, 26, "osd") + 16
    if shape == "play":
        c.poly([(x, 32), (x + 20, 44), (x, 56)], fill=WHITE)
    else:
        c.rect(x, 34, x + 20, 54, fill=WHITE)


def warning(c, t, sc):
    c.rect(0, 0, W, H, fill=BLACK)
    m = sc.m
    if t < m["warn3"] - 0.4:
        c.line([(150, 84), (490, 84)], RED, 3, False)
        c.text(320, 112, "WARNING", 40, RED, "sans", "mm", 0, track=8)
        c.line([(150, 140), (490, 140)], RED, 3, False)
        if t >= m["warn1"]:
            c.paragraph(320, 196, ["THIS PROGRAM IS INTENDED FOR", "AUTHORIZED F.A.L.C.O.N.", "PERSONNEL ONLY."], 20, WHITE, "sans", 1.4, "mm", 0)
        if t >= m["warn2"]:
            c.paragraph(320, 306, ["IF YOU ARE NOT AUTHORIZED PERSONNEL,", "PLEASE STOP THE TAPE NOW."], 20, GOLD, "sans", 1.4, "mm", 0)
        c.text(320, 420, "UNAUTHORIZED VIEWING OR DUPLICATION OF THIS TAPE IS PROHIBITED", 10, GREY, "sans", "mm", 0)
    elif t >= m["warn3"]:
        c.text(320, 240, "THANK YOU.", 22, WHITE, "sans", "mm", 0)


def logo(c, t, sc):
    gradient_bg(c, (8, 14, 52), (30, 48, 136))
    seal(c, 320, 176, 112, progress=ramp(t, 0.3, 1.3))
    word = "F.A.L.C.O.N."
    n = int(max(0, t - 1.5) / 0.09)
    if n > 0:
        w = tw(word, 40, "sans", 10)
        c.text(320 - w / 2, 340, word[:n], 40, WHITE, "sans", "lm", 3, track=10)
    sw = 230 * ease(ramp(t, 2.0, 0.6))
    if sw > 1:
        c.rect(320 - sw, 368, 320 + sw, 371, fill=RED)
        c.rect(320 - sw, 374, 320 + sw, 376, fill=GOLD)
    if t > 2.5:
        c.text(320, 394, "FEDERAL AGENCY FOR LIMINAL CLASSIFICATION & OCCULT NATURE", 11,
               mix((26, 42, 120), WHITE, ramp(t, 2.5, 0.6)), "sans", "mm", 0, track=1.5)


def title(c, t, sc):
    gradient_bg(c, (10, 18, 64), (34, 56, 150))
    deck(c, 0, 190, 330)
    # something under the surface
    sil(c, "side_idle", sil_frame("side_idle", t), 470, 372 + 196, 196, (10, 22, 48))
    figure(c, 150, 330, 92, "stand", WHITE)
    water(c, 190, 640, 342, 480, t, alpha=0.78)
    c.text(24, 24, "ORIENTATION TAPE 07-W", 11, GREY, "sans", "lm", 0, track=1)
    c.text(616, 24, "© 1991 F.A.L.C.O.N. TRAINING DIVISION", 11, GREY, "sans", "rm", 0, track=1)
    m = sc.m
    if t >= m["title"]:
        c.text(320, 100, "WATER SAFETY", 52, GOLD, "sans", "mm", 4, track=2)
    if t >= m["title"] + 0.85:
        c.text(320, 160, "AND YOU", 52, WHITE, "sans", "mm", 4, track=2)
    if t >= m["sub"]:
        c.text(320, 222, "A FIELD GUIDE TO LIMINAL ENTITY L-7", 17, WHITE, "sans", "mm", 2, track=1)
    if t >= m["sub"] + 2.3:
        c.text(320, 256, "“THE WADER”", 26, GOLD, "sans", "mm", 3, track=3)


def section_card(n, name):
    def draw(c, t, sc):
        c.rect(0, 0, W, H, fill=NAVY)
        a = ease(ramp(t, 0.0, 0.3))
        c.circle(150, 240, 52 * a, fill=GOLD)
        if a > 0.85:
            c.text(150, 244, str(n), 60, NAVY, "sans", "mm", 0)
        if t > 0.15:
            c.text(222, 210, f"SECTION {n}", 18, GOLD, "sans", "lm", 0, track=3)
            c.text(222, 250, name, 34, WHITE, "sans", "lm", 2)
        w = tw(name, 34)
        c.rect(222, 276, 222 + w * ease(ramp(t, 0.25, 0.5)), 282, fill=RED)
    return draw


# ---------------------------------------------------------------- 1. the poolrooms
U = 300  # one hall bay


def poolrooms(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    off = t * 16
    sy, fy = 330, 400
    # far wall with dark openings to other halls (moves slower: further away)
    back_wall(c, NAVY)
    po = off * 0.6
    for k in range(-1, 5):
        x = k * 230 - (po % 230) + 60
        c.rect(x, 170, x + 70, sy, fill=(6, 10, 34))
        c.arc(x + 35, 170, 35, 180, 360, (6, 10, 34), 36)
    c.rect(0, 30, W, 64, fill=(96, 100, 112))
    c.rect(0, 30, W, 64, outline=(40, 42, 50), width=1.5)
    c.rect(0, fy, W, H, fill=(96, 100, 112))
    # lights: which are on
    n_lights = []
    k0 = int(off // U) - 1
    off_start = m["pr4"] + 0.4
    for k in range(k0, k0 + 5):
        for j, frac in enumerate((0.3, 0.75)):
            wx = k * U + frac * U
            x = wx - off
            if -60 < x < W + 60:
                n_lights.append((wx, x))
    n_lights.sort()
    lit = []
    for idx, (wx, x) in enumerate(n_lights):
        # lights go out one after another, right to left, flickering first
        order = len(n_lights) - 1 - idx
        t_off = off_start + order * 0.35
        on = t < t_off
        if t_off - 0.4 <= t < t_off:
            on = (int(t * 17 + wx) % 3) != 0
        lit.append((x, on))
    for x, on in lit:
        if on:
            lay, d = c.layer()
            d.polygon([((x - 14) * S, 70 * S), ((x + 14) * S, 70 * S), ((x + 70) * S, sy * S), ((x - 70) * S, sy * S)], fill=(255, 250, 200, 34))
            c.overlay(lay)
        c.rect(x - 16, 64, x + 16, 70, fill=(250, 250, 230) if on else (60, 60, 64))
    # columns standing in the water
    for k in range(k0, k0 + 5):
        x = k * U - off
        deck(c, x - 13, x + 13, 64, fy)
        if k % 2 == 0:
            deck(c, x + 110, x + 170, sy - 14, fy)
    reveal = m["pr5"] + 0.85 <= t < m["pr5"] + 0.93 or m["pr5"] + 1.02 <= t < m["pr5"] + 1.24
    if reveal:
        x = min(lit, key=lambda p: abs(p[0] - 360))[0]
        lay, d = c.layer()
        d.polygon([((x - 14) * S, 70 * S), ((x + 14) * S, 70 * S), ((x + 80) * S, sy * S), ((x - 80) * S, sy * S)], fill=(255, 250, 200, 60))
        c.overlay(lay)
        c.rect(x - 16, 64, x + 16, 70, fill=(250, 250, 230))
        wader_side(c, x + 34, fy, 220, t)
    water(c, 0, W, sy, fy, t, alpha=0.6)
    # site card
    if t >= m["pr2"]:
        c.rect(24, 86, 276, 170, fill=(8, 14, 46), outline=GOLD, width=1.5)
        rows = ["SITE:     THE POOLROOMS", "EXTENT:   UNKNOWN", "WATER:    0.65 M, WARM", "LIGHTING: CONTINUOUS*"]
        txt = typed("\n".join(rows), t - m["pr2"], 34).split("\n")
        for i, r in enumerate(txt):
            c.text(36, 102 + i * 18, r, 13, WHITE, "mono", "lm", 0)
        if t >= m["pr4"]:
            c.text(36, 182, "*NOT ALL SECTORS", 13, RED, "mono", "lm", 0)
    # darkness as the lights go out
    out = sum(1 for _, on in lit if not on) / max(1, len(lit))
    if not reveal:
        c.fade_to(BLACK, out * 0.93)
    else:
        c.fade_to(BLACK, 0.35)
    bug(c, 1, "THE POOLROOMS")


# ---------------------------------------------------------------- 2. identification
@lru_cache(maxsize=4)
def sil_points(name):
    """Where the face, eye socket and claws are on the silhouette (fractions of its box)."""
    strip, info = gfx._sil_data()[name]
    m = np.asarray(strip.crop((0, 0, info["w"], info["h"]))) > 128
    h, w = m.shape

    def leftmost(r0, r1):
        best = None
        for y in range(int(r0 * h), int(r1 * h)):
            xs = np.nonzero(m[y])[0]
            if len(xs) and (best is None or xs[0] < best[0]):
                best = (xs[0], y)
        return best[0] / w, best[1] / h

    face = leftmost(0.03, 0.2)
    claw = leftmost(0.45, 0.85)
    return {"face": face, "eye": (face[0] + 0.07, face[1] - 0.035), "claw": claw}


def ident(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=PAPER)
    g = mix(PAPER, NAVY, 0.12)
    for x in range(0, W, 20):
        c.line([(x, 0), (x, H)], g, 1, False)
    for y in range(0, H, 20):
        c.line([(0, y), (W, y)], g, 1, False)
    c.line([(30, 400), (356, 400)], NAVY, 2, False)
    figure(c, 82, 400, 180, "stand", NAVY)
    c.text(82, 416, "AGENT", 11, NAVY, "sans", "mm", 0)
    box = None
    if t >= m["id1"]:
        box = wader_side(c, 222, 400, 225, t)
        c.text(222, 416, "L-7", 11, BLACK, "sans", "mm", 0)
    # ruler
    p = ease(ramp(t, m["id2"], 1.0))
    if p > 0:
        top = 400 - 250 * p
        c.line([(340, 400), (340, top)], NAVY, 2, False)
        for k in range(0, 14):
            y = 400 - k * 18
            if y >= top:
                c.line([(334 if k % 5 else 328, y), (340, y)], NAVY, 1.5, False)
        if p > 0.75:
            c.dashed((40, 220), (340, 220), NAVY, 1.5, 6, 5)
            c.text(346, 220, "1.00", 11, NAVY, "sans", "lm", 0)
        if p > 0.95:
            c.dashed((140, 175), (340, 175), RED, 1.5, 6, 5)
            c.text(346, 175, "1.25", 11, RED, "sans", "lm", 0)
    # numbered features
    if box and t >= m["id3"]:
        d3 = sc.e["id3"] - m["id3"]
        pts = sil_points("side_idle")
        bx0, by0, bx1, by1 = box
        for i, key in enumerate(("claw", "face", "eye")):
            if t >= m["id3"] + i * d3 / 3:
                fx, fy_ = pts[key]
                x, y = bx0 + fx * (bx1 - bx0), by0 + fy_ * (by1 - by0)
                x -= 10 if key != "eye" else -4
                blink = key == "eye" and t >= m["id4"] and int(t * 4) % 2 == 0
                c.circle(x, y, 9, fill=WHITE if blink else RED, outline=BLACK, width=1)
                c.text(x, y + 1, str(i + 1), 11, RED if blink else WHITE, "sans", "mm", 0)
    # profile panel
    c.rect(372, 50, 620, 424, fill=(10, 18, 60), outline=NAVY2, width=2)
    c.text(386, 72, "SUBJECT PROFILE", 15, GOLD, "sans", "lm", 0, track=2)
    c.line([(386, 86), (606, 86)], GOLD, 1.5, False)
    y = 108
    rows = []
    if t >= m["id1"]:
        rows += [("DESIGNATION", "L-7", m["id1"]), ("COMMON NAME", "THE WADER", m["id1"] + 0.6)]
    if t >= m["id2"]:
        rows += [("HEIGHT", "1.25 x AGENT", m["id2"])]
    for k, v, t0 in rows:
        c.text(386, y, k, 12, GREY, "mono", "lm", 0)
        c.text(386, y + 16, typed(v, t - t0, 20), 15, WHITE, "mono", "lm", 0)
        y += 40
    if t >= m["id3"]:
        d3 = sc.e["id3"] - m["id3"]
        c.text(386, y, "FEATURES", 12, GREY, "mono", "lm", 0)
        for i, s in enumerate(("LONG ARMS", "WIDE JAW", "NO EYES")):
            if t >= m["id3"] + i * d3 / 3:
                col = RED if (i == 2 and t >= m["id4"]) else WHITE
                c.circle(394, y + 22 + i * 22, 8, fill=RED)
                c.text(394, y + 23 + i * 22, str(i + 1), 10, WHITE, "sans", "mm", 0)
                c.text(410, y + 22 + i * 22, s, 15, col, "mono", "lm", 0)
        y += 96
    if t >= m["id4"] + 1.0:
        c.text(386, y + 4, "THREAT LEVEL", 12, GREY, "mono", "lm", 0)
        c.text(386, y + 22, "SEVERE", 18, RED, "mono", "lm", 0)
    bug(c, 2, "IDENTIFICATION")
    # a frame of something else
    fl = sc.e["id4"] + 0.25
    if fl <= t < fl + 0.07:
        flash(c, t)


def flash(c, t):
    c.rect(0, 0, W, H, fill=(120, 0, 0))
    sil(c, "screech", 14, 320, 470, 460, BLACK)


def dry(c, t, sc):
    section_base(c, 240, 300, 372)
    figure(c, 150, 300, 130, "stand", WHITE)
    x = 560 - 230 * ease(ramp(t, 0.2, 3.4))
    moving = 0.2 < t < 3.6
    wader_side(c, x, 372 + bob(t) * moving, 162, t)
    ev = wading(x - 20, t, 1.4, 0.5) if moving else []
    water(c, 240, W, 312, 372, t, bumps=surface_bumps(ev, t))
    if t > 3.0:
        c.dashed((246, 150), (246, 372), RED, 2.5, 8, 6)
        label(c, 330, 140, "CANNOT LEAVE THE WATER", 12, RED)
    if t > 1.0:
        check(c, 150, 128, 34)
        caption_box(c, "DRY GROUND IS SAFE", 60, 22, GREEN)
    bug(c, 2, "IDENTIFICATION")


# ---------------------------------------------------------------- 3. how it hears
def hear(c, t, sc):
    m = sc.m
    dx, sy, fy = 70, 306, 372
    section_base(c, dx, 296, fy)
    ax = 150 + t * 7
    figure(c, ax, fy, 170, walk(t, 1.6), WHITE)
    wader_side(c, 520, fy, 212, t)
    ev = wading(ax, t, 1.6, 0.6, life=4.2)
    water(c, dx, W, sy, fy, t, bumps=surface_bumps([e for e in ev if t - e[1] < 2], t))
    for x, t0, st in ev:
        sound_arcs(c, x, sy, t - t0, 0.9, speed=95, life=4.2)
    hatch(c, dx, fy, W, H)
    deck(c, 0, dx, 296)
    first_hit = 0.0 + (520 - 150) / 95
    if t > first_hit:
        q = "!" if t >= m["hr3"] else "?"
        c.text(498, 128, q, 40, RED if q == "!" else GOLD, "sans", "mm", 3)
    if t >= m["hr3"]:
        c.dashed((480, 150), (ax + 20, 200), RED, 2, 8, 6, phase=-t * 30)
    if t >= m["hr2"] + 0.3:
        label(c, ax + 120, 262, "RIPPLES", 13, CYAN_L)
        arrow(c, (ax + 92, 272), (ax + 40, sy - 6), CYAN_L, 2, 8)
        label(c, 330, 430, "SOUND TRAVELS THROUGH THE WATER", 13, WHITE)
    bug(c, 3, "HOW IT HEARS")


def noise_chart(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    c.text(320, 46, "NOISE IN THE WATER", 24, GOLD, "sans", "mm", 2, track=2)
    c.line([(176, 66), (464, 66)], GOLD, 2, False)
    rows = [("hr4", "STANDING STILL", "still", 0.0, "SILENT", GREEN),
            ("hr5", "WADING SLOWLY", "walk", 0.22, "VERY QUIET", GREEN),
            ("hr6", "WADING QUICKLY", "run", 0.92, "LOUD", RED),
            ("hr7", "MOVING YOUR HANDS", "hands", 0.78, "LOUD", RED)]
    for i, (key, name, pose, level, verdict, vcol) in enumerate(rows):
        if t < m[key]:
            continue
        y = 116 + i * 80
        a = t - m[key]
        c.rect(40, y - 36, 190, y + 34, fill=(20, 34, 104))
        if pose == "still":
            p, ev = "still", []
        elif pose == "walk":
            p, ev = walk(a, 1.2), wading(115, a, 1.2, 0.35)
        elif pose == "run":
            p, ev = walk(a, 4.0, "run1", "run2"), wading(115, a, 4.0, 1.0)
        else:
            p, ev = "hands", [(150, k / 3.0, 0.9) for k in range(int(a * 3) + 1)]
        figure(c, 112, y + 30, 64, p, WHITE)
        water(c, 40, 190, y + 8, y + 34, a, alpha=0.65, bumps=surface_bumps(ev, a, 40, 1.2))
        c.text(214, y - 14, name, 18, WHITE, "sans", "lm", 2)
        lev = level * ease(ramp(a, 0.2, 0.6))
        if level > 0.5:
            lev += 0.06 * math.sin(a * 13)
        meter(c, 214, y + 6, 240, 14, lev)
        if a > 0.8:
            c.text(470, y + 13, verdict, 17, vcol, "sans", "lm", 2)
    bug(c, 3, "HOW IT HEARS")


def investigate(c, t, sc):
    dx, sy, fy = 70, 306, 372
    section_base(c, dx, 296, fy)
    tp = 0.8
    x = 560 - 200 * ease(ramp(t, 1.4, 3.0))
    moving = 1.4 < t < 4.4
    wader_side(c, x, fy + bob(t) * moving, 212, t)
    if t < tp:
        u = ramp(t, 0.3, tp - 0.3)
        bottle(c, 300, 60 + (sy - 60) * u * u, 26, ang=t * 6)
    ev = [(300, tp, 0.8)] + (wading(x - 20, t, 1.8, 0.5) if moving else [])
    water(c, dx, W, sy, fy, t, bumps=surface_bumps(ev, t))
    sound_arcs(c, 300, sy, t - tp, 0.9, speed=95, life=3.5)
    hatch(c, dx, fy, W, H)
    deck(c, 0, dx, 296)
    if moving or t >= 4.4:
        label(c, x + 10, 130, "INVESTIGATE", 15, YELLOW)
        if moving:
            arrow(c, (x - 40, 150), (x - 100, 150), YELLOW, 2.5)
    bug(c, 3, "HOW IT HEARS")


# ---------------------------------------------------------------- 4. falling in
_drops = np.random.default_rng(4).random((30, 3))


def droplets(c, x, y, age, n=30, power=1.0):
    if not 0 <= age < 0.9:
        return
    for i in range(n):
        vx = (_drops[i, 0] - 0.5) * 200 * power
        vy = -(120 + _drops[i, 1] * 200) * power
        px, py = x + vx * age, y + vy * age + 520 * age * age
        if py < y + 4:
            c.circle(px, py, 2 + _drops[i, 2] * 2.5, fill=CYAN_L)


def fall(c, t, sc):
    m, e = sc.m, sc.e
    sy, fy = 320, 400
    c.rect(0, 0, W, H, fill=NAVY)
    back_wall(c, NAVY)
    hatch(c, 40, 120, 110, H)
    c.rect(110, 116, 156, 122, fill=(220, 220, 210))
    hatch(c, 110, fy, W, H)
    ladder(c, 30, 120, fy, 18)
    tf = m["fa1"] + 1.2
    tl = tf + 0.8
    if t < tf:
        figure(c, 142, 116, 100, "stand", WHITE)
    elif t < tl:
        u = (t - tf) / 0.8
        figure(c, 142 + 70 * u, 116 + (fy - 116) * u * u, 100, "flail" if u < 0.5 else "fall", WHITE)
    else:
        figure(c, 212, fy, 100, "flail" if t < tl + 1.2 else "still", WHITE)
    tc = e["fa2"] - 1.3
    if t >= tc:
        u = ease(ramp(t, tc, 0.7))
        x = 720 - 420 * u
        wader_side(c, x, fy, 125, t)
        if u < 1:
            for k in range(6):
                yy = fy - 20 - k * 17
                c.line([(x + 40, yy), (x + 40 + 140 * (1 - u) * (0.5 + 0.1 * k), yy)], WHITE, 2, False)
        elif t < tc + 3:
            label(c, x, fy - 145, "CHARGE", 15, RED)
    ev = [(212, tl, 1.6)] if t >= tl else []
    bumps = surface_bumps(ev, t)
    if tl <= t < tl + 0.5:
        bumps.append((212, 22 * (1 - (t - tl) * 2), 14))
    water(c, 110, W, sy, fy, t, bumps=bumps)
    droplets(c, 212, sy, t - tl)
    if t >= m["fa2"]:
        c.rect(330, 40, 620, 250, fill=(8, 14, 46), outline=NAVY2, width=1.5)
        c.text(475, 58, "SPLASH VOLUME", 14, GOLD, "sans", "mm", 0, track=2)
        for i, (nm, hgt) in enumerate((("LEDGE", 34), ("PLATFORM", 72), ("TOWER", 112))):
            h = hgt * ease(ramp(t, m["fa2"] + 0.3 + 0.35 * i, 0.5))
            x0 = 360 + i * 85
            c.rect(x0, 196 - h, x0 + 56, 196, fill=[YELLOW, ORANGE, RED][i])
            c.text(x0 + 28, 208, nm, 10, WHITE, "sans", "mm", 0)
        if t >= m["fa2"] + 2.6:
            c.text(475, 232, "HEARD: ALMOST ALWAYS", 13, RED, "sans", "mm", 0)
    bug(c, 4, "FALLING IN")


def speed(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    back_wall(c, NAVY)
    c.text(320, 52, "TOP SPEED", 22, GOLD, "sans", "mm", 2, track=3)
    c.text(40, 118, "AGENT, WADING", 16, WHITE, "sans", "lm", 2)
    figure(c, 84, 216, 80, walk(t, 4, "run1", "run2"), WHITE)
    c.rect(140, 180, 140 + 110 * ease(ramp(t, 0.3, 1.0)), 198, fill=WHITE)
    c.text(40, 262, "L-7, CHARGING", 16, RED, "sans", "lm", 2)
    wader_side(c, 84, 372, 100, t, flip=True)
    L = 470 * ease(ramp(t, 0.6, 0.9))
    if L > 10:
        arrow(c, (140, 330), (140 + L, 330), RED, 18, 26)
        for k in range(4):
            c.line([(40 - k * 6, 300 + k * 14), (8 - k * 6, 300 + k * 14)], WHITE, 2, False)
    if t >= m["fa3"] + 1.9:
        cross(c, 150, 190, 120)
        caption_box(c, "DO NOT TRY TO OUTRUN IT", 410, 22, WHITE, border=RED)
    bug(c, 4, "FALLING IN")


def climb_out(c, t, sc):
    m = sc.m
    dx, dy, sy, fy = 260, 280, 292, 380
    section_base(c, dx, dy, fy)
    ladder(c, 282, 250, fy, 22)
    a = t - m["fa4"]
    b = t - m["fa5"]
    pose, x, y, facing = "still", 470, fy, -1
    if b >= 0:
        pose, x, y = "hang", 290, 336
    elif a < 0.6:
        pass
    elif a < 2.0:
        x = 470 - 165 * (a - 0.6) / 1.4
        pose = walk(a, 3)
    elif a < 3.8:
        x, y = 302, fy - (fy - dy) * (a - 2.0) / 1.8
        pose = walk(a, 3, "climb1", "climb2")
    elif a < 4.6:
        x, y = 302 - 110 * (a - 3.8) / 0.8, dy
        pose = walk(a, 3)
    else:
        x, y = 192, dy
        pose = "stand"
    figure(c, x, y, 120, pose, WHITE, facing=facing)
    ev = wading(x, a, 3, 0.6) if 0.6 < a < 2.0 else []
    if b > 1.2:
        wx = 700 - 230 * ease(ramp(b, 1.2, 3.0))
        wader_side(c, wx, fy, 150, t)
    water(c, dx, W, sy, fy, t, bumps=surface_bumps(ev, a))
    if a < 2.0:
        c.dashed((440, sy - 30), (500, sy - 30), RED, 2, 5, 4)
        cross(c, 470, sy - 46, 18)
        label(c, 470, sy - 74, "WHERE YOU LANDED", 12, RED)
        caption_box(c, "DO NOT STAY WHERE YOU LANDED", 56, 20)
    elif b < 0:
        caption_box(c, "CLIMB ALL THE WAY OUT", 56, 20)
        if a >= 4.6:
            check(c, 192, 130, 30)
            label(c, 120, 300 - 190, "DRY GROUND", 12, GREEN)
    else:
        cross(c, 350, 200, 40)
        caption_box(c, "FEET OVER WATER = IN THE WATER", 56, 20, WHITE, border=RED)
    bug(c, 4, "FALLING IN")


# ---------------------------------------------------------------- 5. stillness protocol
def still_search(c, t, sc):
    m = sc.m
    dx, sy, fy = 60, 296, 370
    section_base(c, dx, 286, fy)
    ax = 270
    figure(c, ax, fy, 175, "still", WHITE)
    a = t - m["st2"]
    ev = []
    claw = None
    if a >= 0:
        if a < 2.6:
            x = 700 - 250 * ease(ramp(a, 0, 2.6))
            wader_side(c, x, fy + bob(a), 219, t)
            ev = wading(x - 20, a, 1.6, 0.4)
        else:
            box = wader_side(c, 450, fy, 219, t, name="search")
            # one long arm sweeping under the surface toward the agent and back
            sw = (a - 2.6) * 0.9
            reach = 0.5 - 0.5 * math.cos(sw * math.pi)
            cx = 400 - (400 - (ax + 26)) * reach
            cy = sy + 34
            shx, shy = box[0] + (box[2] - box[0]) * 0.45, box[1] + (box[3] - box[1]) * 0.25
            c.line([(shx, shy), ((shx + cx) / 2, cy - 18), (cx, cy)], BLACK, 5)
            for k in (-1, 0, 1):
                c.line([(cx, cy), (cx - 12, cy + k * 5)], BLACK, 2, False)
            claw = (cx, cy)
            if abs(math.sin(sw * math.pi)) > 0.3:
                ev = [(cx, a - 0.05, 0.4)]
    water(c, dx, W, sy, fy, t, bumps=surface_bumps(ev, a, 40, 0.6))
    c.rect(ax - 26, 150, ax - 18, 176, fill=WHITE)
    c.rect(ax - 10, 150, ax - 2, 176, fill=WHITE)
    if t >= m["st1"] and t < m["st2"] + 0.3:
        caption_box(c, "STOP MOVING.", 60, 30, WHITE, border=RED)
    if a >= 0.2:
        c.dashed((204, sy - 52), (360, sy - 52), GOLD, 2, 6, 5)
        c.line([(204, sy - 60), (204, sy - 44)], GOLD, 2, False)
        c.line([(360, sy - 60), (360, sy - 44)], GOLD, 2, False)
        c.text(194, sy - 52, "LAST HEARD HERE", 13, GOLD, "sans", "rm", 2)
    if claw:
        c.dashed((ax + 26, sy + 34), (400, sy + 34), WHITE, 1.5, 5, 5)
        label(c, 360, sy + 58, "ARM SWEEP", 12, WHITE)
    bug(c, 5, "STILLNESS PROTOCOL")


def dont_move(c, t, sc):
    m, e = sc.m, sc.e
    c.rect(0, 0, W, H, fill=NAVY)
    c.text(320, 66, "DO NOT MOVE", 32, RED, "sans", "mm", 3, track=4)
    D = e["st3"] - m["st3"]
    for i, name in enumerate(("YOUR HEAD", "YOUR BODY", "YOUR HANDS")):
        t0 = m["st3"] + i * D / 3
        if t < t0:
            continue
        cx = 120 + i * 200
        c.rect(cx - 85, 110, cx + 85, 316, fill=(22, 38, 108))
        if i == 0:
            c.circle(cx, 220, 40, fill=WHITE)
            c.arc(cx, 220, 62, 200, 340, GOLD, 4)
            arrow(c, (cx + 50, 175), (cx + 60, 187), GOLD, 4, 12)
            arrow(c, (cx - 50, 175), (cx - 60, 187), GOLD, 4, 12)
        elif i == 1:
            figure(c, cx, 296, 160, "stand", WHITE)
            arrow(c, (cx + 30, 210), (cx + 70, 210), GOLD, 4, 12)
            arrow(c, (cx - 30, 210), (cx - 70, 210), GOLD, 4, 12)
        else:
            water(c, cx - 85, cx + 85, 250, 316, t, alpha=0.7)
            pts = [(-14, 30), (-16, -10), (-26, -26), (-20, -30), (-8, -18), (-8, -48), (0, -50), (2, -22), (6, -52), (14, -50), (12, -20), (20, -44), (27, -40), (16, 0), (16, 30)]
            c.poly([(cx + px * 1.3, 240 + py * 1.3) for px, py in pts], fill=WHITE, outline=BLACK)
            arrow(c, (cx + 40, 200), (cx + 70, 200), GOLD, 4, 12)
        if t >= t0 + 0.35:
            no_sign(c, cx, 214, 74)
        c.text(cx, 340, name, 17, WHITE, "sans", "mm", 2)
    bug(c, 5, "STILLNESS PROTOCOL")


def odds(c, t, sc):
    m, e = sc.m, sc.e
    if t < m["st5"]:
        c.rect(0, 0, W, H, fill=NAVY)
        p = ease(ramp(t, m["st4"] + 0.2, 1.4))
        c.circle(200, 236, 124, fill=(10, 16, 50))
        if p > 0:
            c.pie(200, 236, 120, -90, -90 + 252 * min(1, p / 0.7), GREEN)
        if p > 0.7:
            c.pie(200, 236, 120, 162, 162 + 108 * (p - 0.7) / 0.3, RED)
        if p >= 1:
            c.text(370, 190, "70%", 44, GREEN, "sans", "lm", 3)
            c.text(372, 224, "SURVIVE THE SEARCH", 15, WHITE, "sans", "lm", 2)
            c.text(370, 290, "30%", 44, RED, "sans", "lm", 3)
            c.text(372, 324, "ARE FOUND ANYWAY", 15, WHITE, "sans", "lm", 2)
        bug(c, 5, "STILLNESS PROTOCOL")
    else:
        c.rect(0, 0, W, H, fill=BLACK)
        c.text(320, 240, "REMAIN PERFECTLY STILL.", 28, WHITE, "sans", "mm", 0, track=2)
        if t > e["st5"] + 0.15:
            j = int(t * 20) % 5 - 2
            c.text(320 + j * 3, 240 + j, "REMAIN PERFECTLY STILL.", 28, RED, "sans", "mm", 0, track=2)
            c.text(320, 240, "REMAIN PERFECTLY STILL.", 28, WHITE, "sans", "mm", 0, track=2)
        fl = e["st5"] + 1.35
        if fl <= t < fl + 0.07:
            flash(c, t)


# ---------------------------------------------------------------- 6. warning signs
def wake(c, t, sc):
    m = sc.m
    sy, fy = 220, 430
    c.rect(0, 0, W, H, fill=NAVY)
    back_wall(c, NAVY)
    hatch(c, 0, fy, W, H)
    a = t - m["ws1"]
    x = 640 - 46 * max(0, t)
    hs = 230 * gfx._sil_data()["search"][1]["h"] / gfx._sil_data()["side_idle"][1]["h"]
    box = wader_side(c, x, sy - 14 + hs, 230, t, name="search", col=(0, 0, 0))
    front = box[0]
    bumps = [(front - 6, 9, 14), (front + 40, -4, 16), (front + 90, 3, 18), (front + 150, 2, 22)]
    water(c, 0, W, sy, fy, t, bumps=bumps, alpha=0.42)
    for k in range(10):
        ph = (t * 0.7 + k * 0.137) % 1.0
        bx = box[0] + (box[2] - box[0]) * (0.3 + 0.5 * ((k * 0.61) % 1)) + math.sin(t * 3 + k) * 4
        by = box[1] + 60 - ph * 60
        if by > sy + 4:
            c.circle(bx, by, 2 + (k % 3), outline=CYAN_L, width=1.2)
    if a >= 1.6:
        label(c, front - 40, sy - 64, "WAKE", 14, CYAN_L)
        arrow(c, (front - 40, sy - 50), (front - 8, sy - 12), CYAN_L, 2, 8)
    if a >= 3.4:
        label(c, (box[0] + box[2]) / 2 + 70, sy - 104, "ITS BACK BREAKING THE SURFACE", 13, WHITE)
        arrow(c, ((box[0] + box[2]) / 2 + 40, sy - 90), ((box[0] + box[2]) / 2 + 10, sy - 14), WHITE, 2, 8)
    if a >= 3.4:
        label(c, (box[0] + box[2]) / 2 + 40, sy + 120, "BUBBLES", 13, CYAN_L)
    if t >= sc.e["ws1"] - 1.6:
        speaker(c, 560, 70, 40, 3, GOLD)
        c.text(560, 112, "CLICKING", 14, GOLD, "sans", "mm", 2)
    bug(c, 6, "WARNING SIGNS")


SIGNS = [("ws2", "WANDERING", GREEN, "STAY QUIET", "snd_wander", "wander"),
         ("ws3", "HUNTING", YELLOW, "FREEZE", "snd_hunt", "hunt"),
         ("ws4", "VERY CLOSE", ORANGE, "DO NOT MOVE", "snd_close", "close"),
         ("ws5", "CHARGING", RED, "GET OFF THAT SPOT", "snd_charge", "charge")]


def signs(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    c.text(320, 36, "WHAT ITS CLICKING MEANS", 20, GOLD, "sans", "mm", 2, track=2)
    keys = [s[0] for s in SIGNS]
    for i, (key, name, col, todo, mk, clip) in enumerate(SIGNS):
        if t < m[key]:
            continue
        x0, y0 = (30, 60) if i % 2 == 0 else (330, 60)
        if i >= 2:
            y0 = 252
        nxt = m[keys[i + 1]] if i + 1 < len(keys) else 1e9
        active = m[key] <= t < nxt
        dim = 0 if active else 0.55
        hc = col
        if clip == "charge" and active and t >= m[mk] and int(t * 6) % 2 == 0:
            hc = WHITE
        c.rect(x0, y0, x0 + 280, y0 + 184, fill=mix((20, 34, 104), NAVY, dim))
        c.rect(x0, y0, x0 + 280, y0 + 26, fill=mix(hc, NAVY, dim))
        c.text(x0 + 12, y0 + 14, name, 15, mix(BLACK, NAVY, dim), "sans", "lm", 0, track=2)
        # chart recorder of the sound
        bx0, by0, bx1, by1 = x0 + 12, y0 + 36, x0 + 268, y0 + 134
        c.rect(bx0, by0, bx1, by1, fill=(4, 10, 6))
        mid = (by0 + by1) / 2
        env = ENVS.get(clip)
        ts = t - m[mk]
        tr = mix((70, 230, 110), NAVY, dim)
        c.line([(bx0 + 2, mid), (bx1 - 2, mid)], mix(tr, BLACK, 0.6), 1, False)
        if env is not None and ts > 0:
            n = len(env)
            k1 = min(int(ts * 100), n)
            k0 = max(0, k1 - 200)
            for k in range(k0, k1, 2):
                xx = bx1 - 4 - (k1 - k) * (bx1 - bx0 - 8) / 200
                hh = min(46, env[k] * 46)
                c.line([(xx, mid - hh), (xx, mid + hh)], tr, 1.5, False)
        c.text(x0 + 140, y0 + 160, todo, 18, mix(WHITE, NAVY, dim), "sans", "mm", 2)
    bug(c, 6, "WARNING SIGNS")


def waits(c, t, sc):
    m, e = sc.m, sc.e
    dx, dy, sy, fy = 250, 286, 298, 372
    section_base(c, dx, dy, fy)
    figure(c, 170, dy, 130, "still", WHITE)
    for k in range(4):
        ph = (t * 1.3 + k * 0.29) % 1.0
        x = 150 + k * 13
        y = 200 + ph * (dy - 200)
        c.ellipse(x, y, 2, 3, fill=CYAN_L)
    x = 450 + 110 * math.sin(t * 0.55)
    flip = math.cos(t * 0.55) > 0
    wader_side(c, x, fy + bob(t), 162, t, flip=flip)
    water(c, dx, W, sy, fy, t, bumps=surface_bumps(wading(x, t, 1.4, 0.35), t))
    label(c, 450, 110, "IT WAITS NEARBY", 14, RED)
    label(c, 100, 150, "DRIPPING", 13, CYAN_L)
    if t >= m["ws6"] + (e["ws6"] - m["ws6"]) * 0.5:
        caption_box(c, "DO NOT GO BACK IN RIGHT AWAY", 56, 20)
    bug(c, 6, "WARNING SIGNS")


# ---------------------------------------------------------------- 7. equipment
def decoy(c, t, sc):
    m = sc.m
    dx, dy, sy, fy = 190, 290, 302, 372
    section_base(c, dx, dy, fy)
    a = t - m["eq1"]
    tt, tl = 0.8, 1.9
    figure(c, 120, dy, 125, "throw" if tt <= a < tt + 0.5 else "stand", WHITE)
    figure(c, 300, fy, 150, "still", WHITE)
    turn = a >= 2.3
    wx = 420 + 140 * ease(ramp(a, 2.3, 1.7))
    moving = 2.3 < a < 4.0
    wader_side(c, wx, fy + bob(a) * moving, 188, t, flip=turn)
    ev = []
    if tt <= a < tl:
        u = (a - tt) / (tl - tt)
        bx = 150 + 450 * u
        by = 190 + (sy - 190) * u - 260 * u * (1 - u)
        bottle(c, bx, by, 22, ang=a * 9)
        label(c, bx, by - 26, "DECOY", 12, GOLD)
    if a >= tl:
        ev.append((600, tl, 1.0))
    if moving:
        ev += wading(wx + 20, a, 1.8, 0.4)
    water(c, dx, W, sy, fy, t, bumps=surface_bumps(ev, a))
    if a >= tl:
        sound_arcs(c, 600, sy, a - tl, 1.0, 95, 3.0)
        hatch(c, dx, fy, W, H)
    if a >= 2.3:
        c.dashed((wx + 40, 150), (590, 270), GOLD, 2, 7, 5, phase=-a * 30)
        label(c, 520, 130, "NEAREST SOUND", 13, GOLD)
    bug(c, 7, "EQUIPMENT")


@lru_cache(maxsize=None)
def lidar_sets():
    """Dot positions for the two lidar scans: (x, y, colour, angle, delay) arrays."""
    rng = np.random.default_rng(21)
    sx, sy0 = 146, 214
    env = []
    for x in np.arange(0, 200, 5):
        env.append((x, 290))
    for y in np.arange(290, 380, 5):
        env.append((200, y))
    for x in np.arange(200, 640, 5):
        env.append((x, 380))
    for x in np.arange(0, 640, 6):
        env.append((x, 52))
    for _ in range(700):
        env.append((rng.uniform(0, 640), rng.uniform(56, 376)))
    env = np.array(env, float) + rng.normal(0, 1.2, (len(env), 2))

    def from_mask(draw, n):
        cv = Canvas(BLACK)
        draw(cv)
        a = np.asarray(cv.im.convert("L")) > 128
        ys, xs = np.nonzero(a)
        idx = rng.choice(len(xs), size=min(n, len(xs)), replace=False)
        return np.stack([xs[idx] / S, ys[idx] / S], 1)

    team = from_mask(lambda cv: figure(cv, 330, 380, 150, "still", WHITE), 170)
    w1 = from_mask(lambda cv: wader_side(cv, 540, 380, 188, 0.0, col=WHITE), 300)
    w2 = from_mask(lambda cv: wader_side(cv, 430, 380, 188, 0.4, col=WHITE), 300)
    envc = (190, 220, 235)

    def pack(parts):
        pts = np.concatenate([p for p, _ in parts])
        cols = np.concatenate([np.tile(np.array(cl, float), (len(p), 1)) for p, cl in parts])
        ang = np.degrees(np.arctan2(pts[:, 1] - sy0, pts[:, 0] - sx))
        delay = rng.uniform(0, 0.25, len(pts))
        return pts, cols, ang, delay

    return pack([(env, envc), (team, YELLOW), (w1, (240, 40, 40))]), pack([(env, envc), (team, YELLOW), (w2, (240, 40, 40))]), (sx, sy0)


def lidar(c, t, sc):
    m, e = sc.m, sc.e
    c.rect(0, 0, W, H, fill=BLACK)
    (s1, s2, (sx, sy0)) = lidar_sets()
    figure(c, 110, 290, 125, "reach", (34, 36, 46))
    scanner(c, sx - 6, sy0, 26)
    scans = [(s1, m["eq2"] + 0.8), (s2, m["eq4"] + 0.2)]
    sweep = 1.6
    for (pts, cols, ang, delay), t0 in scans:
        if t < t0:
            continue
        lo, hi = ang.min(), ang.max()
        appear = t0 + (ang - lo) / (hi - lo) * sweep + delay
        age = t - appear
        vis = age >= 0
        fade = np.clip(1 - age / 9.0, 0, 1)
        for (x, y), cl, f in zip(pts[vis], cols[vis], fade[vis]):
            if f > 0.02:
                col = tuple(int(v * (0.25 + 0.75 * f)) for v in cl)
                c.d.rectangle([x * S - 2, y * S - 2, x * S + 2, y * S + 2], fill=col)
        if t < t0 + sweep:
            u = (t - t0) / sweep
            a = math.radians(lo + (hi - lo) * u)
            lay, d = c.layer()
            d.polygon([(sx * S, sy0 * S), ((sx + math.cos(a - 0.08) * 700) * S, (sy0 + math.sin(a - 0.08) * 700) * S),
                       ((sx + math.cos(a + 0.08) * 700) * S, (sy0 + math.sin(a + 0.08) * 700) * S)], fill=(160, 255, 200, 40))
            c.overlay(lay)
    if t >= m["eq2"] + 2.6:
        c.dashed((200, 302), (640, 302), (60, 80, 90), 1.5, 4, 6)
        label(c, 520, 316, "WATER SURFACE: SEEN THROUGH", 11, (150, 170, 180), box=(0, 0, 0))
    if t >= m["eq3"]:
        label(c, 560, 150, "L-7", 15, (240, 60, 60), box=(0, 0, 0))
        c.line([(560, 162), (548, 200)], (240, 60, 60), 1.5, False)
    if t >= m["eq3"] + 1.4:
        label(c, 300, 200, "TEAM", 15, YELLOW, box=(0, 0, 0))
        c.line([(306, 212), (322, 236)], YELLOW, 1.5, False)
    if t >= m["eq4"] + 2.0:
        label(c, 560, 136, "WHERE IT WAS", 12, GREY, box=(0, 0, 0))
    fl = e["eq4"] - 0.9
    if fl <= t < fl + 0.13:
        c.fade_to((70, 74, 80), 0.6)
        wader_side(c, 372, 380, 188, t)
    caption = None
    if t >= m["eq4"]:
        caption = "EACH SCAN IS A SNAPSHOT"
    if caption:
        caption_box(c, caption, 56, 18, WHITE, box=(0, 0, 0))
    bug(c, 7, "EQUIPMENT")


def generator_scene(c, t, sc):
    m, e = sc.m, sc.e
    dx, dy, sy, fy = 300, 290, 302, 372
    section_base(c, dx, dy, fy)
    a = t - m["eq5"]
    t_gen = min(m["eq5"] + 5.9, m["eq6"] - 0.1)
    on = t >= t_gen
    generator(c, 200, dy - 32, 70, on, t)
    # glowing mineral water patch
    lay, d = c.layer()
    g = 0.75 + 0.25 * math.sin(t * 2.5)
    for k in range(5, 0, -1):
        d.ellipse([(560 - 60 - k * 8) * S, (sy + 2 - k * 3) * S, (560 + 60 + k * 8) * S, (fy + k * 3) * S], fill=(40, 230, 190, int(38 * g)))
    c.overlay(lay)
    wx = None
    if t >= m["eq6"]:
        wx = 420 + 20 * math.sin(t * 0.8)
        figure(c, wx, fy, 140, walk(t, 1.6), WHITE)
    water(c, dx, W, sy, fy, t, bumps=surface_bumps(wading(wx, t, 1.6, 0.6) if wx else [], t))
    label(c, 560, sy + 52, "MINERAL WATER", 13, TEAL)
    for i in range(2):
        t0 = 0.8 + i * 2.5
        u = a - t0
        if 0 <= u < 2.4:
            if u < 0.8:
                x, y, f = 560, sy - 6, u / 0.8
            elif u < 1.6:
                v = (u - 0.8) / 0.8
                x, y, f = 560 - 330 * v, sy - 6 - 120 * math.sin(v * math.pi) - 30 * v, 1.0
            else:
                x, y, f = 230, sy - 36, 1 - (u - 1.6) / 0.8
                c.line([(220, y - 10), (212, dy - 70)], TEAL, 3, False)
            canteen(c, x, y - 26, 48, f)
        if a >= t0 + 2.4:
            canteen(c, 120 + i * 28, dy - 22, 30, 0.0)
    c.text(200, 196, "2 CANTEENS", 13, TEAL, "sans", "mm", 2)
    if on:
        for k in range(4):
            r = ((t - t_gen) * 60 + k * 60) % 240
            c.arc(200, dy - 32, r + 30, 180, 360, mix(GOLD, NAVY, r / 240), 2)
            c.arc(200, dy - 32, r + 30, 0, 180, mix(GOLD, NAVY, r / 240), 2)
        label(c, 200, 120, "RUNNING", 13, YELLOW)
    if t >= m["eq6"]:
        c.dashed((470, 230), (470, 290), GREY, 1.5, 4, 4)
        label(c, 470, 220, "YOUR NOISE: COVERED", 12, GREY)
        caption_box(c, "THE HUM COVERS YOUR NOISE", 56, 20)
    bug(c, 7, "EQUIPMENT")


# ---------------------------------------------------------------- 8. casualty procedure
DARK = (8, 12, 40)


def taken(c, t, sc):
    m = sc.m
    dx, dy, sy, fy = 200, 290, 302, 372
    section_base(c, dx, dy, fy, bg=DARK)
    c.rect(18, 198, 72, dy, fill=(4, 6, 20), outline=GREY_D, width=2)
    exit_sign(c, 45, 182, 0.8)
    a1, a2, a3 = t - m["ca1"], t - m["ca2"], t - m["ca3"]
    ts = m["ca1"] + 0.4
    # the colleague in the water
    if t < ts:
        figure(c, 420, fy, 150, "still", WHITE)
    elif t < ts + 0.45:
        figure(c, 420, fy + (t - ts) * 60, 150, "seized", RED)
    feeding = t >= ts + 0.3
    if feeding:
        wader_side(c, 450, fy, 200, t, name="search")
    ev = [(420, ts + 0.3, 1.4)] if t >= ts + 0.3 else []
    if feeding:
        ev += [(400, ts + 0.5 + k * 0.7, 0.3) for k in range(int((t - ts) / 0.7))]
    water(c, dx, W, sy, fy, t, bumps=surface_bumps(ev, t))
    # the one left on the deck
    if a3 < 0:
        figure(c, 150, dy, 125, "reach" if a1 > 0.9 else "stand", WHITE)
        if a1 > 1.2 and t < m["ca2"]:
            no_sign(c, 160, dy - 62, 60)
            caption_box(c, "DO NOT ATTEMPT A RESCUE", 56, 20, WHITE, border=RED)
    else:
        u = ramp(a3, 0.4, 1.3)
        if u < 1:
            figure(c, 150 - 105 * u, dy, 125, walk(a3, 4, "run1", "run2"), WHITE, facing=-1)
        caption_box(c, "USE THIS TIME.", 56, 26)
    if t >= m["ca2"]:
        stopwatch(c, 560, 110, 40, min(1, a2 / 10.0) * 10 / 12)
        c.text(560, 168, "FEEDS 6–10 SEC", 13, WHITE, "sans", "mm", 2)
        if a2 > 1.5:
            speaker(c, 412, 108, 34, 2, WHITE, slashed=True)
            c.text(412, 156, "IGNORES ALL SOUND", 12, WHITE, "sans", "mm", 2)
    bug(c, 8, "CASUALTY PROCEDURE")


def bag_scene(c, t, sc):
    m, e = sc.m, sc.e
    dx, sy, fy = 120, 302, 372
    section_base(c, dx, 290, fy, bg=DARK)
    wader_side(c, 640, fy, 200, t, alpha=0.9)
    water(c, dx, W, sy, fy, t)
    by = wave_y(420, sy, t) - 6
    bag(c, 420, by, 46, glow=0.6 + 0.4 * math.sin(t * 3))
    label(c, 420, 220, "EQUIPMENT BAG", 13, (240, 230, 170))
    arrow(c, (420, 232), (420, by - 26), (240, 230, 170), 2, 8)
    if t >= m["ca4"] + (e["ca4"] - m["ca4"]) * 0.5:
        caption_box(c, "RECOVER IT WHEN IT IS SAFE", 56, 20)
    bug(c, 8, "CASUALTY PROCEDURE")


def returning(c, t, sc):
    m, e = sc.m, sc.e
    c.rect(0, 0, W, H, fill=DARK)
    back_wall(c, DARK)
    hatch(c, 0, 360, W, H)
    hatch(c, 0, 40, W, 62)
    hatch(c, 0, 62, 26, 360)
    hatch(c, 610, 62, 640, 360)
    c.rect(470, 210, 540, 360, fill=(2, 4, 14))
    c.rect(466, 206, 544, 360, outline=GREY_D, width=3)
    label(c, 92, 86, "DRY ROOM", 13, GREEN)
    figure(c, 180, 360, 130, "stand", WHITE)
    figure(c, 240, 360, 126, "stand", (190, 190, 180))
    a = t - m["ca5"]
    if a > 1.2:
        on = (int(t * 13) % 4) != 0 or a > 3.0
        if on:
            lay, d = c.layer()
            sub = Canvas((0, 0, 0))
            figure(sub, 505, 360, 128, "stand", (210, 220, 230))
            msk = sub.im.convert("L").point(lambda v: 90 if v > 40 else 0)
            lay.paste((200, 214, 226, 255), (0, 0), msk)
            c.overlay(lay)
            for k in range(3):
                ph = (t * 1.1 + k * 0.33) % 1.0
                c.ellipse(492 + k * 12, 290 + ph * 66, 1.6, 2.6, fill=CYAN_L)
    if t >= m["ca5"] + (e["ca5"] - m["ca5"]) * 0.58:
        s = "F.A.L.C.O.N. HAS NO EXPLANATION FOR THIS."
        c.text(320, 412, typed(s, t - (m["ca5"] + (e["ca5"] - m["ca5"]) * 0.58), 26), 14, WHITE, "mono", "mm", 0)
    bug(c, 8, "CASUALTY PROCEDURE")


def ask(c, t, sc):
    c.rect(0, 0, W, H, fill=BLACK)
    if t >= sc.m["ca6"]:
        c.text(320, 220, "DO NOT ASK THEM", 30, WHITE, "sans", "mm", 0, track=3)
        c.text(320, 262, "ABOUT THE WATER.", 30, WHITE, "sans", "mm", 0, track=3)


# ---------------------------------------------------------------- summary and ending
def summary(c, t, sc):
    m = sc.m
    gradient_bg(c, (10, 18, 64), (30, 50, 140))
    if t >= m["rm0"]:
        c.text(320, 80, "REMEMBER:", 30, GOLD, "sans", "mm", 3, track=4)
    rows = [("rm1", "STAY DRY."), ("rm2", "STAY QUIET."), ("rm3", "STAY STILL.")]
    for i, (k, s) in enumerate(rows):
        if t < m[k]:
            continue
        y = 172 + i * 82
        c.rect(150, y - 34, 224, y + 34, fill=(16, 28, 90), outline=GOLD, width=2)
        if i == 0:
            deck(c, 158, 216, y + 16, y + 30)
            figure(c, 187, y + 16, 44, "stand", WHITE)
        elif i == 1:
            speaker(c, 190, y, 40, 0, WHITE, slashed=True)
        else:
            figure(c, 187, y + 28, 54, "still", WHITE)
        c.text(250, y, s, 38, WHITE, "sans", "lm", 3, track=2)
    if t >= m["rm4"]:
        c.text(320, 414, "AND ABOVE ALL…", 18, GOLD, "sans", "mm", 2, track=3)


def fall_in(c, t, sc):
    c.rect(0, 0, W, H, fill=BLACK)
    if t >= sc.m["rm5"]:
        c.text(320, 240, "DO NOT FALL IN.", 48, RED, "sans", "mm", 0, track=4)


def outro(c, t, sc):
    m, e = sc.m, sc.e
    gradient_bg(c, (8, 14, 52), (30, 48, 136))
    seal(c, 320, 168, 96)
    if t >= m["end"]:
        c.text(320, 298, "THIS CONCLUDES YOUR ORIENTATION.", 17, WHITE, "sans", "mm", 2, track=1)
    if t >= m["end"] + 2.1:
        c.text(320, 332, "THANK YOU FOR YOUR SERVICE.", 23, GOLD, "sans", "mm", 3, track=1)
    c.text(320, 404, "F.A.L.C.O.N. TRAINING DIVISION  ·  TAPE 07-W  ·  END OF PROGRAM", 10, GREY, "sans", "mm", 0, track=1)
    c.fade_to(BLACK, ramp(t, sc.dur - 1.3, 1.2))


def blank(c, t, sc):
    c.rect(0, 0, W, H, fill=BLACK)


def stinger(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=BLACK)
    if t < m["scare"]:
        s = "THE HUMAN BODY IS ABOUT 60% WATER."
        col = RED if t >= m["hear"] + 0.3 else WHITE
        c.text(320, 240, typed(s, t - 0.5, 15), 20, col, "mono", "mm", 0)
    elif t < m["static"]:
        if int(t * 15) % 2 == 0:
            c.rect(0, 0, W, H, fill=(150, 0, 0))
        f = 8 + int((t - m["scare"]) * 12)
        sil(c, "screech", f, 330, 478, 470, BLACK)
    elif t >= m["stop"]:
        if t < m["stop"] + 1.6:
            c.rect(0, 0, W, H, fill=VCR_BLUE)
            osd(c, "STOP", "stop")
