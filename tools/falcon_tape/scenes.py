# The tape's scenes. Each draw function gets the canvas, the time t in seconds since the scene
# started, and the scene (sc.m: when each narration line or mark starts, sc.e: when each line
# ends, sc.dur). Diagrams are side cross-sections with simulated water.
import math
from PIL import Image
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
        sign(c, "wader", 560, 120, 96)
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
        late = t >= sc.dur - 1.2
        c.text(500, 130, "!" if late else "?", 40, RED if late else GOLD, "sans", "mm", 3)
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
    if True:
        tf = m["drop"] + 0.2
        tl = tf + 0.8
        if t < tf:
            person(c, "stand", 142, 116, 100)
        elif t < tl:
            u = (t - tf) / 0.8
            person(c, "stand", 142 + 80 * u, 116 + (fy - 116) * u * u, 100, rot=-100 * u)
        else:
            person(c, "stand", 222, fy, 100)
        tc = e["fall"] + 0.1
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
        if t < m["out"]:
            sign(c, "fall", 560, 96, 100)
        else:
            caption(c, "GET OUT OF THE WATER", 58, 22)
    bug(c, "FALLING IN")


# ---------------------------------------------------------------- stillness
def stillness(c, t, sc):
    """Before the demonstration: stop moving. After it: most are not found; the stutter."""
    m, e = sc.m, sc.e
    if "st1" in m:
        dx, sy, fy = 60, 296, 370
        pool(c, dx, 286, fy)
        person(c, "stand", 260, fy, 175)
        water(c, dx, W, sy, fy, t)
        sign(c, "still", 560, 110, 96)
        caption(c, "STOP MOVING.", 58, 28, WHITE, border=RED)
        bug(c, "STILLNESS")
    elif t < m["st5"]:
        c.rect(0, 0, W, H, fill=NAVY)
        if t >= m["found"] + 0.3:
            c.text(320, 240, "MOST ARE NOT FOUND.", 40, WHITE, "sans", "mm", 3, track=3)
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
        head, col, todo, clip, t0 = "IF IT SCREECHES", RED, "MOVE", "charge", m["snd_charge"]
    else:
        head, col, todo, clip, t0 = "LISTEN", WHITE, "", "hunt", m["snd_hunt"]
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
    out0 = m["ca1"] + 0.5                       # the lights go out for a moment
    out1 = out0 + 0.7
    gone = t >= out1
    if out0 <= t < out1:
        c.rect(0, 0, W, H, fill=BLACK)
        if out0 + 0.3 <= t < out0 + 0.37:
            kill_scene(c, 2, 0.15)
        return
    pool(c, dx, dy, fy, bg=DARK)
    if not gone:
        person(c, "woman", 420, fy, 150)
    else:
        wader(c, 440, fy, 200, 0.0, name="search")
    ev = [(420, out1 - 0.1, 0.8)] if gone else []
    water(c, dx, W, sy, fy, t, bumps=surface_bumps(ev, t))
    if t < m["busy"] + 1.6:
        person(c, "stand", 130, dy, 120)
    else:
        u = ramp(t - m["busy"], 1.6, 1.4)
        if u < 1:
            person(c, "run", 130 - 150 * u, dy, 110)
    if out1 + 0.3 <= t < m["busy"]:
        sign(c, "rescue", 560, 110, 90)
        caption(c, "DO NOT ATTEMPT A RESCUE", 58, 20)
    elif t >= m["busy"] + 1.4:
        caption(c, "USE THIS TIME.", 58, 26)
    c.fade_to(BLACK, 0.5 if (not gone and int(t * 9) % 4 == 0 and t > m["ca1"]) else 0)
    bug(c, "MISSING PERSONNEL")


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


# ---------------------------------------------------------------- the demonstration (section 4)
AX, SY, FY = 300, 300, 372        # where the agent stands; water surface; pool floor
AGENT_H, WADER_H = 175, 219


def agent(c, x, floor, h, frame=0, col=WHITE, rot=0, part=None):
    """The ending's agent (a silhouette of the game's anti-radiation suit). part: 'top' or 'bottom'
    half, cut at the waist. Returns the box it was drawn in."""
    import gfx
    m = gfx.sil_mask("agent", frame, int(h * S))
    if part:
        cut = int(m.size[1] * 0.5)
        m = m.crop((0, 0, m.size[0], cut)) if part == "top" else m.crop((0, cut, m.size[0], m.size[1]))
    if rot:
        m = m.rotate(rot, resample=Image.BICUBIC, expand=True)
    w, hh = m.size[0] / S, m.size[1] / S
    if part or rot:
        c.paste_mask(m, x - w / 2, floor - hh / 2, col)          # (x, floor) is the centre
        return (x - w / 2, floor - hh / 2, x + w / 2, floor + hh / 2)
    c.paste_mask(m, x - w / 2, floor - hh, col)
    return (x - w / 2, floor - hh, x + w / 2, floor)


def claw_point(box):
    """Where the screeching Wader's claws are (they reach forward, to the left)."""
    return box[0] + (box[2] - box[0]) * 0.14, box[1] + (box[3] - box[1]) * 0.36


STANDBY_FLASHES = [(0.6, 1), (1.45, 2), (2.3, 3)]   # (seconds into the stand-by card, picture)
FLASH = 0.23                                        # long enough to see what it is, then gone


def demo(c, t, sc):
    """The stillness protocol demonstrated: the agent flinches, the lights die, and the tape cuts
    to a stand-by card while it happens. Only single frames get through."""
    m = sc.m
    flinch, dark, standby, after = m["flinch"], m["dark"], m["standby"], m["after"]
    if dark <= t < standby:
        c.rect(0, 0, W, H, fill=BLACK)
        return
    if standby <= t < after:
        u = t - standby
        for at, pic in STANDBY_FLASHES:
            if at <= u < at + FLASH:
                kill_frame(c, pic, 0.1 + (u - at))
                return
        stand_by(c, u)
        return
    gone = t >= after
    pool(c, 120, 290, FY)
    ev = []
    if not gone:
        agent(c, AX, FY, AGENT_H, 1 if t >= flinch else 0)
        a = t - m["walk"]
        if 0 <= a < 3.0:
            x = 720 - 265 * ease(ramp(a, 0, 3.0))
            wader(c, x, FY + bob(a), WADER_H, t)
            ev += steps(x - 20, a, 1.6, 0.45)
        elif a >= 3.0:
            frozen = t >= flinch
            wader(c, 455, FY, WADER_H, flinch if frozen else t, name="search")
            if not frozen:
                ev.append((380 + 25 * math.sin(t * 2.4), t - 0.05, 0.35))
        if t >= flinch:
            ev.append((AX - 18, flinch, 0.6))
    else:
        wader(c, 430, FY, WADER_H, 0.0)
        ev.append((AX, after - 0.4, 0.5))
    water(c, 120, W, SY, FY, t, bumps=surface_bumps(ev, t, 50, 1.4))
    caption(c, "END OF DEMONSTRATION" if gone else "DEMONSTRATION: STILLNESS PROTOCOL", 58, 20)
    if not gone:
        if t < flinch:
            c.rect(424, 96, 620, 124, fill=(10, 40, 20), outline=GREEN, width=2)
            c.text(522, 110, "SUBJECT: STILL", 13, GREEN, "sans", "mm", 0, track=1)
        elif int(t * 6) % 2 == 0:
            c.rect(424, 96, 620, 124, fill=(60, 8, 10), outline=RED, width=2)
            c.text(522, 110, "MOVEMENT DETECTED", 13, RED, "sans", "mm", 0, track=1)
    bug(c, "STILLNESS")


def stand_by(c, u):
    c.rect(0, 0, W, H, fill=NAVY)
    seal(c, 320, 150, 78)
    c.text(320, 286, "PLEASE STAND BY", 40, WHITE, "sans", "mm", 3, track=4)
    c.text(320, 330, "A PORTION OF THIS DEMONSTRATION HAS BEEN REMOVED.", 13, GREY, "sans", "mm", 0, track=1)
    sw = 230
    c.rect(320 - sw, 356, 320 + sw, 359, fill=RED)
    c.rect(320 - sw, 362, 320 + sw, 364, fill=GOLD)


KILL_CUTS = [  # (start, length, picture) after the "kill" mark; None is black
    (0.00, 0.26, 0), (0.26, 0.07, None), (0.33, 0.30, 1), (0.63, 0.06, None), (0.69, 0.55, 2),
    (1.24, 0.08, None), (1.32, 0.50, 3), (1.82, 0.10, None), (1.92, 1.00, 4)]

_blood = None


def kill_frame(c, phase, u):
    """The demonstration going wrong, in red light: 0 it's behind them, 1 lifted, 2 torn apart,
    3 falling into the water, 4 after."""
    global _blood
    import numpy as np
    if _blood is None:
        _blood = np.random.default_rng(13).random((70, 4))
    red = (120, 14, 16)
    c.rect(0, 0, W, H, fill=red)
    back_wall(c, red)
    c.rect(0, 290, 120, H, fill=(70, 36, 40))
    c.rect(120, FY, W, H, fill=(34, 8, 10))
    pale = (238, 224, 208)
    blood = (110, 0, 4)
    wx = AX + 70
    bumps, cloud = [], 0
    if phase == 0:
        agent(c, AX, FY, AGENT_H, 1, pale)
        sil(c, "screech", 12, wx, FY, WADER_H * 1.22, BLACK)
    else:
        box = sil(c, "screech" if phase < 4 else "search", {1: 13, 2: 14, 3: 15, 4: 22}[phase], wx if phase < 4 else wx - 20,
                  FY, WADER_H * (1.22 if phase < 4 else 0.73), BLACK)
        cx, cy = claw_point(box)
        if phase == 1:
            agent(c, cx - 10, cy + 6, AGENT_H, 0, pale, rot=-82)
        elif phase in (2, 3):
            if phase == 2:
                d, fall = 14 + u * 70, 0
            else:
                d, fall = 14 + 0.55 * 70 + u * 40, u
            ty = cy - d * 0.45 + 900 * (fall ** 2) * 0.45
            by = cy + d * 0.35 + 900 * (fall ** 2) * 0.45
            ty, by = min(ty, SY - 4), min(by, SY - 4)
            agent(c, cx - d, ty, AGENT_H, 0, pale, rot=-82 - 50 * u, part="top")
            agent(c, cx + d * 0.7, by, AGENT_H, 0, pale, rot=-82 + 70 * u, part="bottom")
            tt = u if phase == 2 else 0.55 + u
            for i in range(70):
                vx = (_blood[i, 0] - 0.5) * 360
                vy = -(40 + _blood[i, 1] * 300)
                px, py = cx + vx * tt, cy + vy * tt + 640 * tt * tt
                if py < SY + 4:
                    r = 1.5 + _blood[i, 2] * 4
                    c.circle(px, py, r, fill=blood)
                    if _blood[i, 3] > 0.6:
                        c.line([(px, py), (px - vx * 0.03, py - (vy + 1280 * tt) * 0.03)], blood, r * 1.2)
            cloud = 0.4 + tt * 0.8
            if phase == 3 and fall > 0.3:
                bumps = [(cx - d, 10, 14), (cx + d * 0.7, 10, 14)]
        else:
            cloud = 1.6
            bumps = [(wx - 60, 4, 12)]
    water(c, 120, W, SY, FY, u, col=(30, 8, 12), alpha=0.82, bumps=bumps)
    if cloud:
        lay, dr = c.layer()
        r = 50 + cloud * 110
        dr.ellipse([(wx - 10 - r) * S, (SY + 6) * S, (wx - 10 + r) * S, (FY + 24) * S], fill=(130, 0, 4, 170))
        lay.paste((0, 0, 0, 0), (0, 0, W * S, int((SY + 4) * S)))
        c.overlay(lay)
    if int(u * 30) % 6 == 0:
        c.fade_to(BLACK, 0.4)                    # the light stutters


def stinger(c, t, sc):
    """After the end of the program: the card, the line, then what the stand-by card covered."""
    m = sc.m
    c.rect(0, 0, W, H, fill=BLACK)
    if t < m["kill"]:
        s = "THE HUMAN BODY IS ABOUT 60% WATER."
        c.text(320, 240, typed(s, t - 0.5, 15), 20, RED if t >= m["hear"] + 0.3 else WHITE, "mono", "mm", 0)
    elif t < m["static"]:
        u = t - m["kill"]
        for a, d, pic in KILL_CUTS:
            if a <= u < a + d and pic is not None:
                kill_frame(c, pic, u - a)
    elif m["stop"] <= t < m["stop"] + 1.6:
        c.rect(0, 0, W, H, fill=VCR_BLUE)
        osd(c, "STOP \u25a0")


def kill_scene(c, phase, u):
    """The single-frame flash in the program (the tear)."""
    kill_frame(c, 2, u)


# ---------------------------------------------------------------- tape furniture
def bars(c, t, sc):
    cols = [(191, 191, 191), (191, 191, 0), (0, 191, 191), (0, 191, 0), (191, 0, 191), (191, 0, 0), (0, 0, 191)]
    w = W / 7
    for i, col in enumerate(cols):
        c.rect(i * w, 0, (i + 1) * w + 1, 320, fill=col)
    for i, col in enumerate([(0, 0, 191), (19, 19, 19), (191, 0, 191), (19, 19, 19), (0, 191, 191), (19, 19, 19), (191, 191, 191)]):
        c.rect(i * w, 320, (i + 1) * w + 1, 360, fill=col)
    for x0, x1, col in ((0, 114, (0, 33, 76)), (114, 228, (255, 255, 255)), (228, 342, (50, 0, 106)), (342, 640, (19, 19, 19))):
        c.rect(x0, 360, x1, 480, fill=col)
    c.rect(220, 140, 420, 180, fill=(10, 10, 10))
    c.text(320, 160, "F.A.L.C.O.N.  07-W", 16, WHITE, "sans", "mm", 0, track=2)


def leader(c, t, sc):
    """The countdown: 3, 2, 1, then the program."""
    c.rect(0, 0, W, H, fill=(120, 120, 116))
    n = max(1, 3 - int(t))
    f = t % 1.0
    c.pie(320, 240, 330, -90, -90 + 360 * f, (150, 150, 146))
    c.line([(0, 240), (W, 240)], (40, 40, 40), 2)
    c.line([(320, 0), (320, H)], (40, 40, 40), 2)
    c.circle(320, 240, 150, outline=WHITE, width=5)
    c.circle(320, 240, 130, outline=WHITE, width=3)
    c.text(320, 248, str(n), 170, (20, 20, 20), "sans", "mm", 0)


def section_card(n, name, label=None):
    def draw(c, t, sc):
        c.rect(0, 0, W, H, fill=NAVY)
        a = ease(ramp(t, 0.0, 0.3))
        c.circle(150, 240, 52 * a, fill=GOLD)
        if a > 0.85:
            c.text(150, 244, str(n), 60, NAVY, "sans", "mm", 0)
        if t > 0.15:
            c.text(222, 210, label or f"SECTION {n}", 18, GOLD, "sans", "lm", 0, track=3)
            c.text(222, 250, name, 34, WHITE, "sans", "lm", 2)
        c.rect(222, 276, 222 + tw(name, 34) * ease(ramp(t, 0.25, 0.5)), 282, fill=RED)
    return draw
