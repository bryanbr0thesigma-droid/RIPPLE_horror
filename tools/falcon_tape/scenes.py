# The tape's scenes. Each draw function gets the canvas, the time t in seconds since the scene
# started, and the scene (sc.m: when each narration line or mark starts, sc.e: when each line
# ends, sc.dur). Diagrams are side cross-sections with simulated water.
import math
from gfx import *

ENVS = {}  # loudness envelopes of the creature clips (100 per second), filled in by tape.py


def bob(t, amt=2.0, rate=2.4):
    return abs(math.sin(t * rate * math.pi / 2)) * amt


def steps(x, t, rate=1.6, strength=0.5, life=1.6):
    """Ripple events from someone wading at x."""
    return [(x + (6 if k % 2 else -6), k / rate, strength) for k in range(max(0, int((t - life) * rate)), int(t * rate) + 1)]


def wader(c, x, floor, h, t, flip=False, name="side_idle", col=BLACK):
    hh = h if name == "side_idle" else h * gfx_h(name) / gfx_h("side_idle")
    return sil(c, name, sil_frame(name, t), x, floor, hh, col, flip)


def gfx_h(name):
    import gfx
    return gfx._sil_data()[name][1]["h"]


def osd(c, text):
    c.text(46, 44, text, 26, WHITE, "osd", "lm", 2)


def flash(c):
    c.rect(0, 0, W, H, fill=(120, 0, 0))
    sil(c, "screech", 14, 320, 470, 460, BLACK)


# ---------------------------------------------------------------- opening
def vcr(c, t, sc):
    c.rect(0, 0, W, H, fill=VCR_BLUE if 0.6 <= t < sc.dur - 0.45 else BLACK)


def warning(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=BLACK)
    if t < m["warn3"] - 0.4:
        sign(c, "W001", 320, 96, 96)
        if t >= m["warn1"]:
            c.lines(320, 196, ["THIS PROGRAM IS INTENDED FOR", "AUTHORIZED F.A.L.C.O.N.", "PERSONNEL ONLY."], 20, WHITE, shadow=0)
        if t >= m["warn2"]:
            c.lines(320, 306, ["IF YOU ARE NOT AUTHORIZED PERSONNEL,", "PLEASE STOP THE TAPE NOW."], 20, GOLD, shadow=0)
    elif t >= m["warn3"]:
        c.text(320, 240, "THANK YOU.", 22, WHITE, "sans", "mm", 0)


def logo(c, t, sc):
    c.rect(0, 0, W, H, fill=NAVY)
    seal(c, 320, 176, 112, ramp(t, 0.3, 1.3))
    word = "F.A.L.C.O.N."
    n = int(max(0, t - 1.5) / 0.09)
    if n:
        c.text(320 - tw(word, 40, "sans", 10) / 2, 340, word[:n], 40, WHITE, "sans", "lm", 3, track=10)
    sw = 230 * ease(ramp(t, 2.0, 0.6))
    if sw > 1:
        c.rect(320 - sw, 368, 320 + sw, 371, fill=RED)
        c.rect(320 - sw, 374, 320 + sw, 376, fill=GOLD)
    if t > 2.5:
        c.text(320, 394, "FEDERAL AGENCY FOR LIMINAL CLASSIFICATION & OCCULT NATURE", 11, WHITE, "sans", "mm", 0, track=1.5)


def title(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    deck(c, 0, 190, 330)
    sil(c, "side_idle", sil_frame("side_idle", t), 470, 568, 196, (10, 22, 48))
    person(c, "stand", 140, 330, 96)
    water(c, 190, W, 342, H, t, alpha=0.78)
    c.text(24, 24, "ORIENTATION TAPE 07-W", 11, GREY, "sans", "lm", 0, track=1)
    c.text(616, 24, "© 1991 F.A.L.C.O.N. TRAINING DIVISION", 11, GREY, "sans", "rm", 0, track=1)
    if t >= m["title"]:
        c.text(320, 110, "WATER SAFETY", 52, GOLD, "sans", "mm", 4, track=2)
    if t >= m["title"] + 0.85:
        c.text(320, 170, "AND YOU", 52, WHITE, "sans", "mm", 4, track=2)


# ---------------------------------------------------------------- the poolrooms
def poolrooms(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    back_wall(c)
    off = t * 16
    sy, fy, U = 330, 400, 300
    c.rect(0, 30, W, 64, fill=(96, 100, 112))
    c.rect(0, fy, W, H, fill=(96, 100, 112))
    k0 = int(off // U) - 1
    lights = sorted((k * U + f * U - off) for k in range(k0, k0 + 5) for f in (0.3, 0.75))
    lights = [x for x in lights if -60 < x < W + 60]
    lit = []
    for i, x in enumerate(lights):
        t_off = m["pr4"] + 0.4 + (len(lights) - 1 - i) * 0.35
        on = t < t_off if not (t_off - 0.4 <= t < t_off) else int(t * 17 + i) % 3 != 0
        lit.append((x, on))
        if on:
            lay, d = c.layer()
            d.polygon([((x - 14) * S, 70 * S), ((x + 14) * S, 70 * S), ((x + 70) * S, sy * S), ((x - 70) * S, sy * S)], fill=(255, 250, 200, 34))
            c.overlay(lay)
        c.rect(x - 16, 64, x + 16, 70, fill=(250, 250, 230) if on else (60, 60, 64))
    for k in range(k0, k0 + 5):
        x = k * U - off
        deck(c, x - 13, x + 13, 64, fy)
    reveal = m["pr5"] + 0.85 <= t < m["pr5"] + 0.93 or m["pr5"] + 1.02 <= t < m["pr5"] + 1.24
    if reveal:
        x = min(lit, key=lambda p: abs(p[0] - 360))[0]
        lay, d = c.layer()
        d.polygon([((x - 14) * S, 70 * S), ((x + 14) * S, 70 * S), ((x + 80) * S, sy * S), ((x - 80) * S, sy * S)], fill=(255, 250, 200, 60))
        c.overlay(lay)
        c.rect(x - 16, 64, x + 16, 70, fill=(250, 250, 230))
        wader(c, x + 34, fy, 220, t)
    water(c, 0, W, sy, fy, t, alpha=0.6)
    if m["pr1"] <= t < m["pr4"]:
        caption(c, "LIMINAL SITE: THE POOLROOMS", 110, 18, GOLD)
    out = sum(1 for _, on in lit if not on) / max(1, len(lit))
    c.fade_to(BLACK, 0.35 if reveal else out * 0.93)
    bug(c, "THE POOLROOMS")


# ---------------------------------------------------------------- the Wader
def the_wader(c, t, sc):
    m, e = sc.m, sc.e
    pool(c, 190, 286, 372)
    person(c, "stand", 110, 286, 120)
    wader(c, 430, 372, 190, t)
    water(c, 190, W, 300, 372, t)
    if t >= m["id1"]:
        caption(c, "L-7  “THE WADER”", 58, 22, GOLD)
    if t >= m["eyes"]:
        c.text(430, 160, "NO EYES", 18, RED, "sans", "mm", 2, track=2)
    bug(c, "THE WADER")
    if e["eyes"] + 0.25 <= t < e["eyes"] + 0.32:
        flash(c)


def hearing(c, t, sc):
    m = sc.m
    dx, sy, fy = 70, 306, 372
    pool(c, dx, 296, fy)
    ax = 160 + t * 6
    person(c, "walk", ax, fy + bob(t, 2, 3.2), 160, flip=True)
    wader(c, 520, fy, 210, t)
    ev = steps(ax, t, 1.6, 0.6, life=4.0)
    water(c, dx, W, sy, fy, t, bumps=surface_bumps([v for v in ev if t - v[1] < 2], t))
    for x, t0, st in ev:
        sound_arcs(c, x, sy, t - t0, 0.9, 95, 4.0)
    hatch(c, dx, fy, W, H)
    deck(c, 0, dx, 296)
    if t > (520 - 160) / 95:
        q = "!" if t >= m["hr1"] + 3.0 else "?"
        c.text(500, 130, q, 40, RED if q == "!" else GOLD, "sans", "mm", 3)
    if t >= m["slow"]:
        sign(c, "P010", 90, 130, 84)
        caption(c, "WADE SLOWLY.  KEEP YOUR HANDS STILL.", 58, 20)
    bug(c, "THE WADER")


def dry_ground(c, t, sc):
    pool(c, 240, 300, 372)
    person(c, "stand", 150, 300, 130)
    x = 560 - 230 * ease(ramp(t, 0.2, 3.0))
    moving = 0.2 < t < 3.2
    wader(c, x, 372 + bob(t) * moving, 162, t)
    water(c, 240, W, 312, 372, t, bumps=surface_bumps(steps(x - 20, t, 1.4) if moving else [], t))
    if t > 2.6:
        c.dashed((246, 150), (246, 372), RED, 2.5)
    if t > 0.8:
        caption(c, "DRY GROUND IS SAFE", 58, 22, GREEN)
    bug(c, "THE WADER")


# ---------------------------------------------------------------- falling in
def falling(c, t, sc):
    m, e = sc.m, sc.e
    sy, fy = 320, 400
    c.rect(0, 0, W, H, fill=NAVY)
    back_wall(c)
    hatch(c, 40, 120, 110, H)
    c.rect(110, 116, 156, 122, fill=(220, 220, 210))
    hatch(c, 110, fy, W, H)
    if t < m["out"]:
        tf = m["fa2"] + 0.5
        tl = tf + 0.8
        if t < tf:
            person(c, "stand", 142, 116, 100)
        elif t < tl:
            u = (t - tf) / 0.8
            person(c, "stand", 142 + 80 * u, 116 + (fy - 116) * u * u, 100, rot=-100 * u)
        else:
            person(c, "stand", 222, fy, 100)
        tc = e["fa2"] - 1.3
        if t >= tc:
            u = ease(ramp(t, tc, 0.7))
            x = 720 - 400 * u
            wader(c, x, fy, 125, t)
            if u < 1:
                for k in range(6):
                    yy = fy - 20 - k * 17
                    c.line([(x + 40, yy), (x + 40 + 140 * (1 - u) * (0.5 + 0.1 * k), yy)], WHITE, 2)
        bumps = surface_bumps([(222, tl, 1.6)] if t >= tl else [], t)
        if tl <= t < tl + 0.5:
            bumps.append((222, 22 * (1 - (t - tl) * 2), 14))
        water(c, 110, W, sy, fy, t, bumps=bumps)
        sign(c, "W008", 560, 96, 100)
        if t >= m["fa2"] + 1.6:
            c.text(560, 168, "FALLS ARE LOUD", 14, GOLD, "sans", "mm", 2)
    else:
        c.rect(0, 0, W, H, fill=NAVY)
        sign(c, "E001", 320, 210, 170)
        caption(c, "GET OUT OF THE WATER", 370, 24)
    bug(c, "FALLING IN")


# ---------------------------------------------------------------- stillness
def stillness(c, t, sc):
    m, e = sc.m, sc.e
    if t < m["st4"]:
        dx, sy, fy = 60, 296, 370
        pool(c, dx, 286, fy)
        person(c, "stand", 260, fy, 175)
        a = t - m["feel"]
        ev = []
        if a >= 0:
            if a < 2.4:
                x = 700 - 260 * ease(ramp(a, 0, 2.4))
                wader(c, x, fy + bob(a), 219, t)
                ev = steps(x - 20, a, 1.6, 0.4)
            else:
                wader(c, 430, fy, 219, t, name="search")
                ev = [(330 + 30 * math.sin(a * 2.2), a - 0.05, 0.35)]
        water(c, dx, W, sy, fy, t, bumps=surface_bumps(ev, a, 40, 0.6))
        sign(c, "P004", 560, 110, 96)
        caption(c, "STOP MOVING.", 58, 28, WHITE, border=RED)
        bug(c, "STILLNESS")
    elif t < m["st5"]:
        c.rect(0, 0, W, H, fill=NAVY)
        if t >= m["st4"] + 1.0:
            c.text(320, 190, "70%", 60, GREEN, "sans", "mm", 3)
            c.text(320, 236, "SURVIVE THE SEARCH", 17, WHITE, "sans", "mm", 2, track=2)
        if t >= m["st4"] + 2.6:
            c.text(320, 310, "30%", 60, RED, "sans", "mm", 3)
            c.text(320, 356, "ARE FOUND ANYWAY", 17, WHITE, "sans", "mm", 2, track=2)
        bug(c, "STILLNESS")
    else:
        c.rect(0, 0, W, H, fill=BLACK)
        if t > e["st5"] + 0.15:
            j = int(t * 20) % 5 - 2
            c.text(320 + j * 3, 240 + j, "REMAIN PERFECTLY STILL.", 28, RED, "sans", "mm", 0, track=2)
        c.text(320, 240, "REMAIN PERFECTLY STILL.", 28, WHITE, "sans", "mm", 0, track=2)
        if e["st5"] + 1.35 <= t < e["st5"] + 1.42:
            flash(c)


# ---------------------------------------------------------------- its clicking
def clicking(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    if t >= m["scr"]:
        head, col, todo, clip, t0 = "SCREECH", RED, "MOVE", "charge", m["snd_charge"]
    elif t >= m["ws3"]:
        head, col, todo, clip, t0 = "STEADY CLICKING", GOLD, "FREEZE", "hunt", m["snd_hunt"]
    else:
        head, col, todo, clip, t0 = "LISTEN FOR CLICKING", WHITE, "", None, 0
    c.text(320, 96, head, 30, col, "sans", "mm", 3, track=3)
    bx0, by0, bx1, by1 = 70, 140, 570, 330
    c.rect(bx0, by0, bx1, by1, fill=(4, 10, 6), outline=GREY_D, width=2)
    mid = (by0 + by1) / 2
    c.line([(bx0 + 4, mid), (bx1 - 4, mid)], (30, 80, 40), 1)
    env = ENVS.get(clip)
    if env is not None and t > t0:
        k1 = min(int((t - t0) * 100), len(env))
        for k in range(max(0, k1 - 250), k1, 2):
            xx = bx1 - 6 - (k1 - k) * (bx1 - bx0 - 12) / 250
            hh = min(88, env[k] * 88)
            c.line([(xx, mid - hh), (xx, mid + hh)], (70, 230, 110), 1.5)
    if todo and t >= t0 + 0.4:
        flick = clip == "charge" and int(t * 6) % 2 == 0
        c.text(320, 380, todo, 40, WHITE if flick else col, "sans", "mm", 3, track=4)
    bug(c, "WARNING SIGNS")


# ---------------------------------------------------------------- losing someone
DARK = (8, 12, 40)


def taken(c, t, sc):
    m = sc.m
    dx, dy, sy, fy = 200, 290, 302, 372
    pool(c, dx, dy, fy, bg=DARK)
    ts = m["ca1"] + 0.4
    if t < ts:
        person(c, "woman", 420, fy, 150)
    elif t < ts + 0.45:
        person(c, "woman", 420, fy + (t - ts) * 80, 150, RED)
    if t >= ts + 0.3:
        wader(c, 450, fy, 200, t, name="search")
    ev = [(420, ts + 0.3, 1.4)] if t >= ts + 0.3 else []
    ev += [(400, ts + 0.5 + k * 0.7, 0.3) for k in range(int(max(0, t - ts) / 0.7))]
    water(c, dx, W, sy, fy, t, bumps=surface_bumps(ev, t))
    if t < m["ca3"]:
        person(c, "stand", 130, dy, 120)
    else:
        u = ramp(t - m["ca3"], 0.3, 1.4)
        if u < 1:
            person(c, "run", 130 - 120 * u, dy, 110)
        sign(c, "E001", 60, 150, 64)
    if m["ca1"] + 1.0 <= t < m["ca2"]:
        sign(c, "P001", 560, 110, 90)
        caption(c, "DO NOT ATTEMPT A RESCUE", 58, 20)
    elif m["ca2"] <= t < m["ca3"]:
        caption(c, "IT FEEDS FOR 6–10 SECONDS", 58, 22)
    elif t >= m["ca3"]:
        caption(c, "USE THIS TIME.", 58, 26)
    bug(c, "CASUALTIES")


def coming_back(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=BLACK)
    if t >= m["ret"] + 0.8 and (int(t * 13) % 5 != 0 or t > m["ret"] + 2.5):
        person(c, "stand", 320, 330, 170, (200, 214, 226), alpha=0.3)
        for k in range(3):
            ph = (t * 1.1 + k * 0.33) % 1.0
            c.circle(306 + k * 14, 270 + ph * 60, 2, fill=CYAN_L)
    if t >= m["ret"]:
        c.text(320, 380, "TAKEN PERSONNEL SOMETIMES COME BACK.", 17, WHITE, "sans", "mm", 0, track=1)
    if t >= m["ca6"]:
        c.text(320, 412, "DO NOT ASK THEM ABOUT THE WATER.", 17, RED, "sans", "mm", 0, track=1)


# ---------------------------------------------------------------- summary and ending
def summary(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
    if t >= m["rm0"]:
        sign(c, "M001", 320, 84, 72)
        c.text(320, 150, "REMEMBER:", 26, GOLD, "sans", "mm", 3, track=4)
    for i, (k, s) in enumerate((("rm1", "STAY DRY."), ("rm2", "STAY QUIET."), ("rm3", "STAY STILL."))):
        if t >= m[k]:
            c.text(320, 214 + i * 60, s, 38, WHITE, "sans", "mm", 3, track=2)
    if t >= m["rm4"]:
        c.text(320, 414, "AND ABOVE ALL…", 18, GOLD, "sans", "mm", 2, track=3)


def fall_in(c, t, sc):
    c.rect(0, 0, W, H, fill=BLACK)
    if t >= sc.m["rm5"]:
        c.text(320, 240, "DO NOT FALL IN.", 48, RED, "sans", "mm", 0, track=4)


def outro(c, t, sc):
    m = sc.m
    c.rect(0, 0, W, H, fill=NAVY)
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
        c.text(320, 240, typed(s, t - 0.5, 15), 20, RED if t >= m["hear"] + 0.3 else WHITE, "mono", "mm", 0)
    elif t < m["static"]:
        if int(t * 15) % 2 == 0:
            c.rect(0, 0, W, H, fill=(150, 0, 0))
        sil(c, "screech", 8 + int((t - m["scare"]) * 12), 330, 478, 470, BLACK)
    elif m["stop"] <= t < m["stop"] + 1.6:
        c.rect(0, 0, W, H, fill=VCR_BLUE)
        osd(c, "STOP ■")
