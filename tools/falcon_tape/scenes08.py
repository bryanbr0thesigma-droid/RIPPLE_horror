# The scenes of "Going In, Coming Out" (tape 08-E). Same conventions as scenes.py: each draw
# function gets the canvas, the time t since the scene started, and the scene (sc.m / sc.e: when
# each line or mark starts / ends). Side cross-sections, road-sign people, simulated water.
import math, os
import numpy as np
from PIL import Image, ImageDraw
import gfx
from gfx import *
from scenes import pool_ladder, drop, osd, bob, steps

gfx.FONTS["hand"] = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "branding", "fonts", "Kalam-Regular.ttf")
SIGN_RED = (200, 16, 30)
WOOD = (128, 84, 52)
WOOD_L = (156, 104, 66)
DOT = (90, 255, 150)
WENT_IN = 4


# ---------------------------------------------------------------- small drawings
def poly(c, pts, fill):
    c.d.polygon([(x * S, y * S) for x, y in pts], fill=fill)


def rrect(c, x0, y0, x1, y1, r, fill=None, outline=None, width=1):
    c.d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], r * S, fill=fill, outline=outline, width=int(width * S))


def no_sign(c, x, y, r, kind=None, h=None, dy=0, inner=None):
    """A prohibition sign: white disc, a black figure, red ring and slash."""
    c.circle(x, y, r, fill=(250, 250, 248))
    if kind:
        person(c, kind, x, y + (h or r * 1.2) / 2 + dy, h or r * 1.2, (10, 10, 10))
    if inner:
        inner(c)
    c.circle(x, y, r, outline=SIGN_RED, width=r * 0.2)
    k = r * 0.57
    c.line([(x - k, y - k), (x + k, y + k)], SIGN_RED, r * 0.16)


def ok_mark(c, x, y, r=16):
    c.circle(x, y, r, fill=(40, 160, 80))
    c.line([(x - r * 0.45, y + r * 0.02), (x - r * 0.12, y + r * 0.35), (x + r * 0.48, y - r * 0.38)], WHITE, r * 0.24)


def x_mark(c, x, y, r=16):
    c.circle(x, y, r, fill=SIGN_RED)
    k = r * 0.4
    c.line([(x - k, y - k), (x + k, y + k)], WHITE, r * 0.24)
    c.line([(x - k, y + k), (x + k, y - k)], WHITE, r * 0.24)


def clock(c, x, y, r, minutes):
    c.circle(x, y, r, fill=(244, 240, 228), outline=(20, 24, 40), width=3)
    for k in range(12):
        a = math.radians(k * 30)
        c.line([(x + math.sin(a) * r * 0.78, y - math.cos(a) * r * 0.78), (x + math.sin(a) * r * 0.9, y - math.cos(a) * r * 0.9)],
               (20, 24, 40), 2)
    ah = math.radians(minutes / 2)
    am = math.radians(minutes * 6)
    c.line([(x, y), (x + math.sin(ah) * r * 0.5, y - math.cos(ah) * r * 0.5)], (20, 24, 40), 3.5)
    c.line([(x, y), (x + math.sin(am) * r * 0.75, y - math.cos(am) * r * 0.75)], (20, 24, 40), 2.2)
    c.circle(x, y, 3, fill=RED)


def counter(c, x0, x1, top, floor):
    """The reception counter in section, with the sign-in book open on it."""
    c.rect(x0, top, x1, floor, fill=WOOD)
    c.rect(x0 - 8, top - 10, x1 + 8, top, fill=WOOD_L)
    for k in range(1, 4):
        xx = x0 + (x1 - x0) * k / 4
        c.line([(xx, top + 12), (xx, floor - 8)], (100, 64, 40), 2)
    bx = x0 + 34
    poly(c, [(bx, top - 10), (bx + 30, top - 16), (bx + 30, top - 10)], (244, 240, 228))
    poly(c, [(bx + 30, top - 16), (bx + 60, top - 10), (bx + 30, top - 10)], (230, 226, 212))


def canteen(c, x, y, s):
    c.arc(x, y - s * 0.2, s * 0.62, 200, 340, (150, 120, 70), 4)         # strap
    c.circle(x, y, s * 0.42, fill=(170, 180, 150))
    c.circle(x, y, s * 0.34, outline=(130, 140, 110), width=2)
    c.rect(x - s * 0.1, y - s * 0.62, x + s * 0.1, y - s * 0.4, fill=(150, 160, 130))
    c.rect(x - s * 0.14, y - s * 0.72, x + s * 0.14, y - s * 0.6, fill=(60, 60, 60))


def lidar(c, x, y, s):
    rrect(c, x - s * 0.55, y - s * 0.28, x + s * 0.4, y + s * 0.12, s * 0.06, fill=(200, 202, 196))
    poly(c, [(x - s * 0.2, y + s * 0.1), (x + s * 0.05, y + s * 0.1), (x - s * 0.05, y + s * 0.6), (x - s * 0.3, y + s * 0.6)],
         (90, 92, 98))
    c.circle(x + s * 0.4, y - s * 0.08, s * 0.16, fill=(40, 44, 52))
    c.circle(x + s * 0.4, y - s * 0.08, s * 0.08, fill=DOT)
    c.rect(x - s * 0.45, y - s * 0.2, x - s * 0.05, y - s * 0.02, fill=(20, 60, 36))


def flashlight(c, x, y, s):
    lay, d = c.layer()
    d.polygon([((x + s * 0.4) * S, (y - s * 0.12) * S), ((x + s * 1.1) * S, (y - s * 0.42) * S),
               ((x + s * 1.1) * S, (y + s * 0.42) * S), ((x + s * 0.4) * S, (y + s * 0.12) * S)], fill=(255, 240, 150, 70))
    c.overlay(lay)
    rrect(c, x - s * 0.6, y - s * 0.1, x + s * 0.2, y + s * 0.1, s * 0.05, fill=(60, 64, 72))
    poly(c, [(x + s * 0.2, y - s * 0.1), (x + s * 0.42, y - s * 0.18), (x + s * 0.42, y + s * 0.18), (x + s * 0.2, y + s * 0.1)],
         (80, 84, 94))
    c.rect(x + s * 0.4, y - s * 0.17, x + s * 0.44, y + s * 0.17, fill=(250, 240, 180))


def lidar_dot(c, x, y, age=1.0):
    a = clamp01(age * 4)
    lay, d = c.layer()
    d.ellipse([(x - 10) * S, (y - 10) * S, (x + 10) * S, (y + 10) * S], fill=DOT + (int(60 * a),))
    c.overlay(lay)
    c.circle(x, y, 3.5 * a + 0.5, fill=DOT)


def puddle(c, x, y, w):
    c.d.ellipse([(x - w) * S, (y - 2) * S, (x + w) * S, (y + 2) * S], fill=CYAN_L)


def footprint(c, x, y, left):
    dy = -2 if left else 2
    c.d.ellipse([(x - 9) * S, (y - 3 + dy * 0.3) * S, (x + 9) * S, (y + 3 + dy * 0.3) * S], fill=(70, 160, 206))


def floor_line(c, y):
    deck(c, 0, W, y)


def number(c, x, y, n, col=GOLD, size=30):
    c.text(x, y, str(n), size, col, "sans", "mm", 3)


# ---------------------------------------------------------------- opening
def title(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    back_wall(c)
    dx, dy, sy, fy = 330, 350, 362, 430
    deck(c, 0, dx, dy)
    hatch(c, dx, fy, W, H)
    c.rect(70, 238, 140, dy, fill=(6, 10, 30))                       # the doorway out of the station
    c.rect(64, 232, 146, 238, fill=WOOD_L)
    c.rect(64, 232, 70, dy, fill=WOOD_L)
    c.rect(140, 232, 146, dy, fill=WOOD_L)
    x = 120 + 150 * ease(ramp(t, 0.2, 4.0))
    person(c, "walk", x, dy + bob(t, 2, 3.0) * (t < 4.2), 92, flip=True)
    water(c, dx, W, sy, fy, t, alpha=0.75)
    c.text(24, 24, f"ORIENTATION TAPE {gfx.TAPE_ID}", 11, GREY, "sans", "lm", 0, track=1)
    c.text(616, 24, "© 1991 F.A.L.C.O.N. TRAINING DIVISION", 11, GREY, "sans", "rm", 0, track=1)
    if t >= m["title8"]:
        c.text(320, 110, "GOING IN,", 52, GOLD, "sans", "mm", 4, track=2)
    if t >= m["title8"] + 0.7:
        c.text(320, 170, "COMING OUT", 52, WHITE, "sans", "mm", 4, track=2)


# ---------------------------------------------------------------- 1. before entry
def reception(c, t, sc, out=False):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    back_wall(c)
    fy = 380
    floor_line(c, fy)
    counter(c, 330, 560, 300, fy)
    clock(c, 560, 200, 30, 9 * 60 + 14 + (t * 2 if not out else 300 + t * 2))
    person(c, "stand", 280, fy, 150)
    k1, k2 = ("signout", "inside") if out else ("signin", "timein")
    if t >= m[k1]:
        caption(c, "SIGN OUT AT RECEPTION" if out else "SIGN IN AT RECEPTION", 58, 22)
    if out and t >= m["inside"]:
        c.rect(40, 96, 600, 150, fill=(8, 12, 40), outline=RED, width=2)
        c.text(320, 112, "PERSONNEL WHO DO NOT SIGN OUT", 17, WHITE, "sans", "mm", 0, track=1)
        c.text(320, 134, "ARE CONSIDERED STILL INSIDE.", 17, RED, "sans", "mm", 0, track=1)
    elif t >= m["timein" if not out else "signout"] + (0 if not out else 1.2):
        # the book, close up: the time written in
        c.rect(70, 110, 250, 230, fill=(244, 240, 228), outline=(20, 24, 40), width=2)
        c.text(160, 126, "TIME OUT" if out else "TIME IN", 12, NAVY, "sans", "mm", 0, track=2)
        c.line([(84, 140), (236, 140)], (150, 170, 200), 1.5)
        c.text(160, 182, typed("4:52" if out else "9:14", t - m["timein" if not out else "signout"] - (0 if not out else 1.2), 5),
               40, (24, 30, 110), "hand", "mm", 0)
    bug(c, "SIGN OUT" if out else "BEFORE ENTRY")


def sign_out(c, t, sc):
    reception(c, t, sc, out=True)


def kit(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    caption(c, "COLLECT YOUR FIELD KIT", 58, 22)
    items = [(170, "CANTEEN", canteen), (320, "LIDAR", lidar), (470, "FLASHLIGHT", flashlight)]
    for i, (x, name, fn) in enumerate(items):
        a = m["kit"] + i * 0.45
        if t >= a:
            fn(c, x if fn is not flashlight else x - 20, 230, 96)
            c.text(x, 320, name, 18, WHITE, "sans", "mm", 2, track=2)
        if t >= a + 0.3:
            ok_mark(c, x, 368, 15)
    bug(c, "BEFORE ENTRY")


def alone(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    fy = 360
    c.rect(40, 120, 300, fy + 20, fill=(10, 18, 56), outline=GREY_D, width=2)
    c.rect(340, 120, 600, fy + 20, fill=(10, 18, 56), outline=GREY_D, width=2)
    person(c, "stand", 135, fy, 150)
    person(c, "stand", 205, fy, 150)
    if t < m["alone"]:
        person(c, "stand", 470, fy, 150)
    else:
        no_sign(c, 470, 262, 92, "stand", 130)
        ok_mark(c, 170, 400, 18)
        x_mark(c, 470, 400, 18)
        caption(c, "NEVER ENTER ALONE", 58, 24)
    bug(c, "BEFORE ENTRY")


# ---------------------------------------------------------------- 2. going in
def have_to(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    if t >= m["haveto"]:
        c.text(320, 210, "DO NOT ENTER THE WATER", 34, WHITE, "sans", "mm", 3, track=2)
    if t >= m["haveto"] + 1.2:
        c.text(320, 262, "UNLESS YOU ABSOLUTELY HAVE TO.", 22, GOLD, "sans", "mm", 2, track=2)
    bug(c, "GOING IN")


def range_check(c, t, sc):
    """Check a kilometre of water before going in. (Not to scale.)"""
    m = sc.m
    dx, dy, sy, fy = 90, 300, 312, 380
    pool(c, dx, dy, fy)
    person(c, "stand", 52, dy, 110)
    x0, x1 = dx + 6, 618
    scan0, scan1 = m["scan"], m["clear"]
    u = ramp(t, scan0, scan1 - scan0)
    if t >= scan0:
        sx = x0 + (x1 - x0) * u
        lay, d = c.layer()
        d.rectangle([x0 * S, (sy - 4) * S, sx * S, fy * S], fill=(60, 200, 110, 40))
        c.overlay(lay)
    water(c, dx, W, sy, fy, t)
    if t >= scan0 and u < 1:
        sx = x0 + (x1 - x0) * u
        c.line([(sx, sy - 70), (sx, fy)], DOT, 2.5)
        for k in range(3):
            c.arc(sx, (sy + fy) / 2, 14 + k * 10, -40, 40, mix(NAVY, DOT, 1 - k * 0.3), 2)
    # the scale
    c.line([(x0, 412), (x1, 412)], WHITE, 2)
    for i, lab in enumerate(["0", "250 M", "500 M", "750 M", "1 KM"]):
        xx = x0 + (x1 - x0) * i / 4
        c.line([(xx, 406), (xx, 418)], WHITE, 2)
        c.text(xx, 432, lab, 12, WHITE, "sans", "mm", 0)
    c.text(x1, 396, "(NOT TO SCALE)", 9, GREY, "sans", "rm", 0, track=1)
    if t >= scan1:
        caption(c, "NO ENTITIES WITHIN 1 KM", 58, 22, GREEN)
        ok_mark(c, 560, 150, 24)
        c.text(560, 190, "CLEAR", 16, GREEN, "sans", "mm", 2, track=3)
    elif t >= m["km"]:
        caption(c, "CHECK 1 KM IN EVERY DIRECTION", 58, 20)
    bug(c, "GOING IN")


def walk_wet(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    back_wall(c)
    fy = 330
    floor_line(c, fy)
    for x, w in [(120, 22), (250, 14), (330, 30), (470, 18), (590, 12)]:
        puddle(c, x, fy + 1, w)
    for k in range(3):
        ph = (t * 0.9 + k * 0.37) % 1.0
        drop(c, 200 + k * 160, 90 + ph * (fy - 100), 14, CYAN_L)
    x = 90 + 46 * t
    person(c, "walk", x, fy + bob(t, 2, 2.4), 150, flip=True)
    if t >= m["walk"] + 0.6:
        no_sign(c, 540, 180, 54, "run", 66)
    caption(c, "WALK. THE FLOORS ARE ALWAYS WET.", 58, 20)
    bug(c, "GOING IN")


def ladder(c, t, sc):
    """Down the ladder, slowly. Then: never jump in."""
    m, e = sc.m, sc.e
    dx, dy, sy, fy = 150, 300, 312, 392
    lx = 170
    c.rect(0, 0, W, H, fill=NAVY)
    back_wall(c)
    deck(c, 0, dx, dy)
    hatch(c, dx, fy, W, H)
    pool_ladder(c, lx, dy, fy)
    c0, c1 = m["ladder"] + 0.3, e["slowly"] + 0.8           # the climb down
    ev = []
    if t < c0:
        person(c, "walk", 60 + (lx - 76) * ease(ramp(t, 0, c0)), dy, 100, flip=True)
    elif t < c1:
        u = (t - c0) / (c1 - c0)
        rung = int(u * 6)
        y = dy + (fy - dy) * min(1.0, (rung + ease(u * 6 - rung)) / 6)
        person(c, "walk" if rung % 2 == 0 else "stand", lx + 14, y, 100)
        if y > sy - 40:
            ev.append((lx + 14, c0 + 0.1 + rung / 6 * (c1 - c0), 0.25))
    else:
        person(c, "stand", lx + 30, fy, 100)
    water(c, dx, W, sy, fy, t, bumps=surface_bumps(ev, t, 40, 1.4))
    if t >= m["jump"]:
        no_sign(c, 500, 200, 70, "fall", 78, -6)
        for k in range(3):
            c.arc(500, 236, 30 + k * 12, 200, 340, (10, 10, 10), 3)
        caption(c, "NEVER JUMP IN", 58, 24, WHITE, border=RED)
    elif t >= m["ladder"]:
        caption(c, "USE THE LADDER. SLOWLY.", 58, 22)
    bug(c, "GOING IN")


DOTS = [140, 190, 240, 290, 340, 390, 440]


def mark(c, t, sc, back=False):
    m = sc.m
    dx, sy, fy = 60, 300, 380
    pool(c, dx, 290, fy)
    if not back:
        lead = 110 + 40 * t
        dots = [x for x in DOTS if x < lead - 10]
    else:
        lead = 470 - 44 * t
        dots = DOTS
    xs = [lead, lead - 70] if not back else [lead, lead + 70]
    for x in xs:
        person(c, "walk", x, fy + bob(t, 2, 2.6), 160, flip=not back)
    for i, x in enumerate(dots):
        age = (t - (x + 10 - 110) / 40) if not back else 2.0
        lidar_dot(c, x, 186 + (i % 2) * 18, age)
    ev = []
    for x in xs:
        ev += steps(x, t, 1.4, 0.3)
    water(c, dx, W, sy, fy, t, bumps=surface_bumps(ev, t, 50, 1.4))
    if not back:
        if t >= m["partner"]:
            c.dashed((xs[1] + 8, 236), (xs[0] - 8, 236), GOLD, 2.5)
            caption(c, "STAY IN SIGHT OF YOUR PARTNER", 58, 20)
        elif t >= m["mark"]:
            caption(c, "MARK YOUR WAY", 58, 22)
        bug(c, "GOING IN")


# ---------------------------------------------------------------- 3. coming out
DOOR_X = 52                     # the middle of the doorway to the station (come_out)


def through_door(t, x0, start, dur):
    """Walking left from x0 into the doorway, then gone into the dark beyond it: (x, alpha)."""
    x = x0 - (x0 - DOOR_X) * ease(ramp(t, start, dur))
    return x, 1 - ramp(t, start + dur, 0.35)


def come_out(c, t, sc):
    """Back along the marks, up the ladder, and dry off at the threshold before crossing it."""
    m, e = sc.m, sc.e
    dx, dy, sy, fy = 300, 300, 312, 392
    lx, th = 320, 90                                        # the ladder; the threshold
    c.rect(0, 0, W, H, fill=NAVY)
    back_wall(c)
    deck(c, 0, dx, dy)
    hatch(c, dx, fy, W, H)
    c.rect(20, 190, th - 6, dy, fill=(6, 10, 30))           # the doorway to the station
    c.rect(14, 184, th, 190, fill=WOOD_L)
    c.rect(th - 6, 184, th, dy, fill=WOOD_L)
    pool_ladder(c, lx, dy, fy)
    for i, x in enumerate(DOTS[:4]):
        lidar_dot(c, x + 220, 186 + (i % 2) * 18)
    w0, w1 = m["way"], m["climb"] + 0.1                     # wade back
    c0, c1 = w1, m["dryoff"] - 1.1                          # climb, slowly
    s0 = c1                                                 # walk to the threshold
    dry0, dry1 = m["dryoff"] + 0.4, e["dryoff"] + 0.3       # drying off
    x_out = e["dryoff"] + 0.5                               # cross it
    partner_x = 210
    ev = []
    if t < w1:
        x = 560 - (560 - (lx + 18)) * ease(ramp(t, w0, w1 - w0))
        person(c, "walk", x, fy + bob(t, 2, 2.6), 100)
        ev += steps(x, t, 1.5, 0.3)
    elif t < c1:
        u = (t - c0) / (c1 - c0)
        rung = int(u * 6)
        y = fy - (fy - dy) * min(1.0, (rung + ease(u * 6 - rung)) / 6)
        person(c, "walk" if rung % 2 == 0 else "stand", lx + 14, y, 100)
    elif t < x_out:
        x = lx - (lx - (th + 44)) * ease(ramp(t, s0, 1.0))
        person(c, "walk" if t < s0 + 1.0 else "stand", x, dy, 100)
        wet = 1 - ramp(t, dry0, dry1 - dry0)
        if wet > 0.05:
            for k in range(3):
                ph = (t * 1.4 + k * 0.33) % 1.0
                drop(c, x - 14 + k * 14, dy - 60 + ph * 58, 9 * wet + 3, CYAN_L)
            puddle(c, x, dy + 1, 12 * wet + 4)
        if t >= dry1:
            ok_mark(c, x, dy - 120, 13)
    else:                                                   # through the door, after the partner
        x, a = through_door(t, th + 44, x_out + 0.7, 0.8)
        if a > 0.02:
            person(c, "walk" if a > 0.99 and x > DOOR_X + 1 else "stand", x, dy, 100, alpha=a)
    if t < x_out:
        person(c, "stand", partner_x, dy, 100)
    else:
        px, a = through_door(t, partner_x, x_out, 1.3)
        if a > 0.02:
            person(c, "walk" if a > 0.99 and px > DOOR_X + 1 else "stand", px, dy, 100, alpha=a)
    water(c, dx, W, sy, fy, t, bumps=surface_bumps(ev, t, 50, 1.4))
    c.dashed((th + 8, dy - 120), (th + 8, dy), RED, 2.5, 7, 5)
    c.text(th + 8, dy - 130, "THRESHOLD", 11, RED, "sans", "mm", 0, track=1)
    if t >= m["noleave"]:
        no_sign(c, 470, 170, 58, inner=lambda c: drop(c, 470, 172, 64, (10, 10, 10)))
        caption(c, "WATER MUST NOT LEAVE THE POOLROOMS", 58, 18, WHITE, border=RED)
    elif t >= m["dryoff"]:
        caption(c, "DRY OFF BEFORE YOU CROSS THE THRESHOLD", 58, 18)
    elif t >= m["climb"]:
        caption(c, "CLIMB OUT SLOWLY", 58, 22)
    elif t >= m["way"]:
        caption(c, "LEAVE THE WAY YOU CAME IN", 58, 22)
    bug(c, "COMING OUT")


# ---------------------------------------------------------------- 4. the headcount
XS = [150, 250, 350, 450, 550]
FY = 380


def team(c, n, alphas=None, wet=None, t=0.0):
    for i in range(n):
        a = 1.0 if alphas is None else alphas[i]
        if a > 0.02:
            person(c, "stand", XS[i], FY, 150, WHITE, alpha=a)
    if wet is not None:
        x = XS[wet]
        for k in range(3):
            ph = (t * 1.1 + k * 0.33) % 1.0
            drop(c, x - 16 + k * 16, FY - 110 + ph * 104, 10, CYAN_L)
        puddle(c, x, FY + 1, 20)


def tally(c, t, start, n, col, step=0.5, last_col=None):
    """Numbers over their heads, one every `step` seconds from `start`."""
    k = 0 if t < start else (n if step <= 0 else min(n, int((t - start) / step) + 1))
    for i in range(k):
        number(c, XS[i], 196, i + 1, last_col if (last_col and i == n - 1) else col)
    return k


def headcount(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    back_wall(c)
    floor_line(c, FY)
    lower = t >= m["lower"]
    fade = ramp(t, m["lower"] + 0.2, 0.8)
    team(c, 4, [1, 1, 1, 1 - fade] if lower else None)
    c.rect(452, 94, 620, 122, fill=(8, 12, 40), outline=GREY_D, width=2)
    c.text(536, 108, f"WENT IN: {WENT_IN}", 14, WHITE, "sans", "mm", 0, track=2)
    if lower:
        tally(c, t, m["lower"] + 1.0, 3, RED, 0.25)
        if t >= m["lower"] + 1.2:
            caption(c, "LOWER: DO NOT GO BACK", 58, 22, WHITE, border=RED)
            sign(c, "rescue", 560, 300, 80)
    elif t >= m["same"]:
        tally(c, t, m["same"], 4, GREEN, 0.0)
        if t >= m["ok"]:
            caption(c, "THE SAME: SIGN OUT", 58, 22, GREEN)
            ok_mark(c, 536, 150, 18)
    elif t >= m["c2"]:
        tally(c, t, m["c2"], 4, WHITE)
        caption(c, "THEN COUNT THEM AGAIN", 58, 22)
    elif t >= m["c1"]:
        tally(c, t, m["c1"], 4, GOLD)
        caption(c, "COUNT YOUR TEAM", 58, 22)
    bug(c, "THE HEADCOUNT")


def higher(c, t, sc):
    """The count comes out higher. The fifth looks like everyone else, but it is wet."""
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    back_wall(c)
    floor_line(c, FY)
    c3 = m["c3"]
    k = tally(c, t, c3, 5, WHITE, 0.6, RED)
    fifth = clamp01((t - (c3 + 4 * 0.6)) / 0.15) if t >= c3 + 4 * 0.6 else 0.0
    team(c, 5, [1, 1, 1, 1, fifth], wet=4 if fifth > 0.5 else None, t=t)
    c.rect(452, 94, 620, 122, fill=(8, 12, 40), outline=GREY_D, width=2)
    c.text(536, 108, f"WENT IN: {WENT_IN}", 14, WHITE, "sans", "mm", 0, track=2)
    if k >= 5:
        c.rect(452, 128, 620, 156, fill=(40, 6, 8), outline=RED, width=2)
        c.text(536, 142, "COUNTED: 5", 14, RED, "sans", "mm", 0, track=2)
    if t >= m["donttell"]:
        caption(c, "DO NOT TELL THEM.", 58, 26, WHITE, border=RED)
    elif t >= m["higher"]:
        caption(c, "IF IT IS HIGHER…", 58, 22)
    bug(c, "THE HEADCOUNT")


def walk_on(c, t, sc):
    """Back to the station, normally. Only one of them leaves wet footprints."""
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    back_wall(c)
    floor_line(c, FY)
    v = 40
    lead = 250 + v * t
    xs = [lead - i * 90 for i in range(5)]
    last = xs[4]
    x = 40.0
    i = 0
    while x < last - 14:
        footprint(c, x, FY + 5 + (i % 2) * 4, i % 2 == 0)
        x += 30
        i += 1
    for i, x in enumerate(xs):
        if -40 < x < W + 40:
            person(c, "walk", x, FY + bob(t + i * 0.3, 2, 2.4), 150, flip=True)
    for k in range(2):
        ph = (t * 1.1 + k * 0.5) % 1.0
        drop(c, last - 8 + k * 16, FY - 100 + ph * 96, 9, CYAN_L)
    if t >= m["super"]:
        caption(c, "INFORM YOUR SUPERVISOR", 58, 22)
    elif t >= m["normal"]:
        caption(c, "WALK TO THE STATION NORMALLY", 58, 20)
    bug(c, "THE HEADCOUNT")


# ---------------------------------------------------------------- summary and ending
def summary(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    if t >= m["rm0"]:
        sign(c, "M001", 320, 70, 60)
        c.text(320, 124, "REMEMBER:", 24, GOLD, "sans", "mm", 3, track=4)
    for i, (k, s) in enumerate((("rm1", "SIGN IN."), ("rm2", "STAY TOGETHER."), ("rm3", "STAY DRY."),
                                ("rm4", "COUNT TWICE."), ("rm5", "SIGN OUT."))):
        if t >= m[k]:
            c.text(320, 176 + i * 54, s, 34, WHITE, "sans", "mm", 3, track=2)


def outro(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    seal(c, 320, 168, 96)
    if t >= m["end"]:
        c.text(320, 298, "THIS CONCLUDES YOUR ORIENTATION.", 17, WHITE, "sans", "mm", 2, track=1)
    if t >= m["end"] + 2.1:
        c.text(320, 332, "THANK YOU FOR YOUR SERVICE.", 23, GOLD, "sans", "mm", 3, track=1)
    c.text(320, 404, f"F.A.L.C.O.N. TRAINING DIVISION  ·  TAPE {gfx.TAPE_ID}  ·  END OF PROGRAM", 10, GREY, "sans", "mm", 0,
           track=1)
    c.fade_to(BLACK, ramp(t, sc.dur - 1.3, 1.2))


def tape_end(c, t, sc):
    """After the program: black, a burst of static, and the tape stops."""
    m = sc.m
    c.rect(0, 0, W, H, fill=BLACK)
    if m["stop"] <= t < m["stop"] + 1.6:
        c.rect(0, 0, W, H, fill=VCR_BLUE)
        osd(c, "STOP \u25a0")
