# Drawing helpers for the tape: a 640x480 canvas drawn at 2x and shrunk (for smooth edges),
# broadcast-style text, safety-sign pictograms, the F.A.L.C.O.N. seal, pool diagrams and the
# Wader's silhouettes. Everything is flat 2D, the way a 1990s training video was made.
import json, math, os
from functools import lru_cache
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 640, 480
S = 2

# Palette
NAVY = (14, 26, 86)
NAVY2 = (28, 46, 128)
BLACK = (6, 6, 10)
WHITE = (236, 236, 226)
GOLD = (236, 196, 70)
RED = (200, 34, 40)
GREEN = (60, 190, 90)
ORANGE = (236, 128, 40)
YELLOW = (240, 220, 60)
CYAN = (70, 178, 210)
CYAN_L = (130, 214, 236)
WATER_D = (24, 92, 132)
TEAL = (40, 230, 190)
GREY = (150, 156, 170)
GREY_D = (78, 84, 100)
TILE = (198, 214, 222)
VCR_BLUE = (16, 24, 190)
PAPER = (206, 210, 196)

FONTS = {
    "sans": "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "sansr": "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    "mono": "/usr/share/fonts/truetype/freefont/FreeMonoBold.ttf",
    "osd": "/usr/share/fonts/opentype/unifont/unifont.otf",
    "serif": "/usr/share/fonts/truetype/freefont/FreeSerifBold.ttf",
}


@lru_cache(maxsize=None)
def font(name, size):
    return ImageFont.truetype(FONTS[name], int(size * S))


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def clamp01(x):
    return max(0.0, min(1.0, x))


def ease(x):
    x = clamp01(x)
    return x * x * (3 - 2 * x)


def ramp(t, t0, dur):
    return clamp01((t - t0) / dur) if dur > 0 else float(t >= t0)


class Canvas:
    def __init__(self, bg=NAVY):
        self.bg = bg
        self.im = Image.new("RGB", (W * S, H * S), bg)
        self.d = ImageDraw.Draw(self.im)
        self.fx = {}

    # --- primitives (coordinates in 640x480 units) ---
    def rect(self, x0, y0, x1, y1, fill=None, outline=None, width=1):
        self.d.rectangle([x0 * S, y0 * S, x1 * S - 1, y1 * S - 1], fill=fill, outline=outline, width=int(width * S))

    def line(self, pts, fill, width=2, round_caps=True):
        p = [(x * S, y * S) for x, y in pts]
        self.d.line(p, fill=fill, width=max(1, int(width * S)), joint="curve")
        if round_caps and width >= 2:
            r = width * S / 2
            for x, y in (p[0], p[-1]):
                self.d.ellipse([x - r, y - r, x + r, y + r], fill=fill)

    def dashed(self, a, b, fill, width=2, dash=8, gap=6, phase=0.0):
        (x0, y0), (x1, y1) = a, b
        L = math.hypot(x1 - x0, y1 - y0)
        if L < 1e-6:
            return
        ux, uy = (x1 - x0) / L, (y1 - y0) / L
        s = -(phase % (dash + gap))
        while s < L:
            s0, s1 = max(s, 0), min(s + dash, L)
            if s1 > s0:
                self.line([(x0 + ux * s0, y0 + uy * s0), (x0 + ux * s1, y0 + uy * s1)], fill, width, False)
            s += dash + gap

    def poly(self, pts, fill=None, outline=None, width=1):
        self.d.polygon([(x * S, y * S) for x, y in pts], fill=fill, outline=outline, width=int(width * S))

    def circle(self, cx, cy, r, fill=None, outline=None, width=1):
        self.d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=fill, outline=outline, width=int(width * S))

    def ellipse(self, cx, cy, rx, ry, fill=None, outline=None, width=1):
        self.d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=fill, outline=outline, width=int(width * S))

    def arc(self, cx, cy, r, a0, a1, fill, width=2):
        self.d.arc([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], a0, a1, fill=fill, width=int(width * S))

    def pie(self, cx, cy, r, a0, a1, fill):
        self.d.pieslice([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], a0, a1, fill=fill)

    def text(self, x, y, s, size=20, fill=WHITE, f="sans", anchor="la", shadow=2, track=0, shadow_col=(0, 0, 0)):
        fnt = font(f, size)
        if track:
            # Letter-spaced text, drawn one character at a time.
            widths = [fnt.getlength(ch) + track * S for ch in s]
            total = sum(widths) - track * S
            ox = {"l": 0, "m": total / 2, "r": total}[anchor[0]]
            cx = x * S - ox
            for ch, w in zip(s, widths):
                if shadow:
                    self.d.text((cx + shadow * S, y * S + shadow * S), ch, font=fnt, fill=shadow_col, anchor="l" + anchor[1])
                self.d.text((cx, y * S), ch, font=fnt, fill=fill, anchor="l" + anchor[1])
                cx += w
            return total / S
        if shadow:
            self.d.text((x * S + shadow * S, y * S + shadow * S), s, font=fnt, fill=shadow_col, anchor=anchor)
        self.d.text((x * S, y * S), s, font=fnt, fill=fill, anchor=anchor)
        return fnt.getlength(s) / S

    def paragraph(self, x, y, lines, size=20, fill=WHITE, f="sans", lh=1.3, anchor="la", shadow=2):
        for i, s in enumerate(lines):
            self.text(x, y + i * size * lh, s, size, fill, f, anchor, shadow)

    def paste_mask(self, mask, x, y, color, alpha=1.0):
        """Paste a solid colour through an L mask whose top-left is at (x, y) in canvas units."""
        if alpha < 1:
            mask = mask.point(lambda v: int(v * alpha))
        self.im.paste(Image.new("RGB", mask.size, color), (int(x * S), int(y * S)), mask)

    def overlay(self, rgba, alpha=1.0, at=(0, 0)):
        """Alpha-blend an RGBA image onto the canvas; at is its top-left in pixels."""
        a = rgba.getchannel("A")
        if alpha < 1:
            a = a.point(lambda v: int(v * alpha))
        self.im.paste(rgba.convert("RGB"), at, a)
        self.d = ImageDraw.Draw(self.im)

    def layer(self):
        """A transparent full-canvas layer and a draw handle for it (use with overlay())."""
        lay = Image.new("RGBA", self.im.size, (0, 0, 0, 0))
        return lay, ImageDraw.Draw(lay)

    def fade_to(self, color, a):
        if a <= 0:
            return
        self.im = Image.blend(self.im, Image.new("RGB", self.im.size, color), clamp01(a))
        self.d = ImageDraw.Draw(self.im)

    def finish(self):
        return np.asarray(self.im.resize((W, H), Image.LANCZOS))


def typed(s, t, cps=22):
    n = int(max(0, t) * cps)
    return s[:n]


# ---------------------------------------------------------------- pictogram figure
POSES = {
    #        lean  armR1 armR2 armL1 armL2 legR1 legR2 legL1 legL2  (degrees from straight down,
    #                                                               positive = toward the facing side)
    "stand": (0, 24, 14, -24, -14, 10, 0, -10, 0),
    "walk1": (4, 30, 50, -28, -10, 22, 5, -20, -40),
    "walk2": (4, -28, -10, 30, 50, -20, -40, 22, 5),
    "run1": (14, 60, 110, -50, -20, 45, 10, -35, -80),
    "run2": (14, -50, -20, 60, 110, -35, -80, 45, 10),
    "still": (0, 20, 30, -20, -30, 6, 0, -6, 0),
    "fall": (-30, 150, 170, 120, 150, 30, -20, -10, -50),
    "flail": (20, 160, 200, 200, 230, 50, 90, -30, 20),
    "climb1": (0, 170, 180, 150, 120, 60, -20, 0, 0),
    "climb2": (0, 150, 120, 170, 180, 0, 0, 60, -20),
    "hang": (0, 172, 178, 168, 176, 4, -6, -4, -12),
    "throw": (-6, 150, 175, -30, -20, 20, 0, -18, 0),
    "reach": (25, 80, 85, 20, 30, 10, 0, -10, 0),
    "crouch": (30, 40, 70, 30, 60, 80, -10, 70, -20),
    "seized": (-20, 170, 200, 150, 190, 25, 40, -15, -35),
    "hands": (28, 70, 20, 55, 10, 14, 0, -12, 0),
}


def figure(c, x, y, h, pose="stand", col=WHITE, facing=1, head_gap=True, outline=None):
    """A safety-sign person standing with feet at (x, y), h tall."""
    p = POSES[pose] if isinstance(pose, str) else pose
    lean, ar1, ar2, al1, al2, lr1, lr2, ll1, ll2 = [math.radians(v) for v in p]
    th = h * 0.105
    hip = (x, y - h * 0.47)
    sh = (hip[0] + math.sin(lean) * facing * h * 0.29, hip[1] - math.cos(lean) * h * 0.29)

    def seg(a, ang, L):
        return (a[0] + math.sin(ang) * facing * L, a[1] + math.cos(ang) * L)

    def limb(a, a1, a2, l1, l2, w):
        b = seg(a, a1, l1)
        e = seg(b, a2, l2)
        c.line([a, b, e], col, w)

    limb(sh, al1, al2, h * 0.17, h * 0.16, th * 0.9)
    limb(hip, ll1, ll2, h * 0.24, h * 0.24, th)
    c.line([hip, sh], col, th * 1.45)
    limb(hip, lr1, lr2, h * 0.24, h * 0.24, th)
    limb(sh, ar1, ar2, h * 0.17, h * 0.16, th * 0.9)
    hr = h * 0.08
    hc = (sh[0] + math.sin(lean) * facing * (hr + (h * 0.05 if head_gap else h * 0.03)),
          sh[1] - math.cos(lean) * (hr + (h * 0.05 if head_gap else h * 0.03)))
    c.circle(hc[0], hc[1], hr, fill=col)
    return hc


# ---------------------------------------------------------------- icons
def arrow(c, a, b, col=WHITE, w=2.5, head=9):
    c.line([a, b], col, w)
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    p1 = (b[0] - math.cos(ang - 0.45) * head, b[1] - math.sin(ang - 0.45) * head)
    p2 = (b[0] - math.cos(ang + 0.45) * head, b[1] - math.sin(ang + 0.45) * head)
    c.poly([b, p1, p2], fill=col)


def label(c, x, y, s, size=13, fill=WHITE, box=(6, 10, 32), anchor="mm", pad=5):
    """Small boxed label for diagrams."""
    fnt = font("sans", size)
    w = fnt.getlength(s) / S
    ox = {"l": 0, "m": w / 2, "r": w}[anchor[0]]
    c.rect(x - ox - pad, y - size * 0.7, x - ox + w + pad, y + size * 0.7, fill=box)
    c.text(x - ox, y, s, size, fill, "sans", "lm", 0)


def check(c, x, y, s, col=GREEN, w=None):
    c.line([(x - s * 0.5, y), (x - s * 0.15, y + s * 0.35), (x + s * 0.55, y - s * 0.45)], col, w or s * 0.18)


def cross(c, x, y, s, col=RED, w=None):
    c.line([(x - s / 2, y - s / 2), (x + s / 2, y + s / 2)], col, w or s * 0.16)
    c.line([(x + s / 2, y - s / 2), (x - s / 2, y + s / 2)], col, w or s * 0.16)


def no_sign(c, x, y, r, col=RED):
    c.circle(x, y, r, outline=col, width=r * 0.16)
    a = math.radians(45)
    c.line([(x - math.cos(a) * r * 0.92, y - math.sin(a) * r * 0.92), (x + math.cos(a) * r * 0.92, y + math.sin(a) * r * 0.92)], col, r * 0.16, False)


def bottle(c, x, y, s, ang=0, col=(110, 170, 90)):
    pts = [(-0.18, 0.5), (0.18, 0.5), (0.18, -0.1), (0.07, -0.25), (0.07, -0.5), (-0.07, -0.5), (-0.07, -0.25), (-0.18, -0.1)]
    ca, sa = math.cos(ang), math.sin(ang)
    c.poly([(x + (px * ca - py * sa) * s, y + (px * sa + py * ca) * s) for px, py in pts], fill=col, outline=BLACK, width=1)


def canteen(c, x, y, s, fill=0.0, glow=TEAL, body=(200, 200, 200)):
    c.rect(x - s * 0.22, y - s * 0.45, x + s * 0.22, y + s * 0.5, fill=body, outline=BLACK, width=1.5)
    if fill > 0:
        c.rect(x - s * 0.17, y + s * 0.45 - s * 0.85 * fill, x + s * 0.17, y + s * 0.45, fill=glow)
    c.rect(x - s * 0.14, y - s * 0.6, x + s * 0.14, y - s * 0.45, fill=GREY_D, outline=BLACK, width=1)


def generator(c, x, y, s, on=False, t=0.0):
    c.rect(x - s * 0.6, y - s * 0.45, x + s * 0.6, y + s * 0.45, fill=(196, 160, 40) if on else GREY_D, outline=BLACK, width=2)
    c.rect(x - s * 0.5, y - s * 0.35, x - s * 0.05, y + s * 0.35, fill=(40, 40, 46))
    for i in range(4):
        yy = y - s * 0.25 + i * s * 0.16
        c.line([(x - s * 0.45, yy), (x - s * 0.1, yy)], GREY, s * 0.04, False)
    bolt = [(0.25, -0.35), (0.08, 0.02), (0.22, 0.02), (0.12, 0.35), (0.42, -0.06), (0.27, -0.06), (0.38, -0.35)]
    c.poly([(x + px * s, y + py * s) for px, py in bolt], fill=YELLOW if on else (120, 120, 90), outline=BLACK)
    c.rect(x + s * 0.3, y - s * 0.62, x + s * 0.45, y - s * 0.45, fill=GREY, outline=BLACK, width=1)


def scanner(c, x, y, s, beam=0.0, t=0.0):
    c.rect(x - s * 0.5, y - s * 0.25, x + s * 0.3, y + s * 0.25, fill=(196, 170, 60), outline=BLACK, width=2)
    c.rect(x - s * 0.38, y - s * 0.15, x - s * 0.02, y + s * 0.1, fill=(30, 50, 30))
    c.line([(x - s * 0.35, y), (x - s * 0.25, y - s * 0.06), (x - s * 0.15, y + s * 0.05), (x - s * 0.05, y - s * 0.03)], GREEN, 1.5)
    c.rect(x + s * 0.3, y - s * 0.12, x + s * 0.55, y + s * 0.12, fill=GREY_D, outline=BLACK, width=1)
    c.rect(x - s * 0.25, y + s * 0.25, x - s * 0.05, y + s * 0.65, fill=(60, 60, 60), outline=BLACK, width=1)


def bag(c, x, y, s, glow=0.0):
    if glow > 0:
        lay, d = c.layer()
        for i in range(6, 0, -1):
            r = s * (0.45 + i * 0.12) * S
            d.ellipse([x * S - r, y * S - r, x * S + r, y * S + r], fill=(250, 240, 170, int(22 * glow)))
        c.overlay(lay)
    c.ellipse(x, y + s * 0.05, s * 0.42, s * 0.35, fill=(150, 110, 60), outline=BLACK, width=2)
    c.poly([(x - s * 0.15, y - s * 0.25), (x + s * 0.15, y - s * 0.25), (x + s * 0.08, y - s * 0.4), (x - s * 0.08, y - s * 0.4)], fill=(150, 110, 60), outline=BLACK)
    c.line([(x - s * 0.12, y - s * 0.4), (x + s * 0.12, y - s * 0.4)], (90, 60, 30), s * 0.08, False)


def stopwatch(c, x, y, r, frac, col=WHITE, face=BLACK):
    c.rect(x - r * 0.15, y - r * 1.32, x + r * 0.15, y - r * 1.05, fill=col)
    c.circle(x, y, r, fill=face, outline=col, width=r * 0.1)
    for i in range(12):
        a = i / 12 * 2 * math.pi
        c.line([(x + math.sin(a) * r * 0.78, y - math.cos(a) * r * 0.78), (x + math.sin(a) * r * 0.9, y - math.cos(a) * r * 0.9)], col, r * 0.05, False)
    c.pie(x, y, r * 0.72, -90, -90 + 360 * frac, (150, 30, 34))
    a = frac * 2 * math.pi
    c.line([(x, y), (x + math.sin(a) * r * 0.75, y - math.cos(a) * r * 0.75)], col, r * 0.07)
    c.circle(x, y, r * 0.08, fill=col)


def speaker(c, x, y, s, waves=3, col=WHITE, slashed=False):
    c.poly([(x - s * 0.5, y - s * 0.18), (x - s * 0.25, y - s * 0.18), (x, y - s * 0.45), (x, y + s * 0.45), (x - s * 0.25, y + s * 0.18), (x - s * 0.5, y + s * 0.18)], fill=col)
    for i in range(waves):
        r = s * (0.25 + 0.18 * i)
        c.arc(x + s * 0.05, y, r, -45, 45, col, s * 0.07)
    if slashed:
        no_sign(c, x, y, s * 0.7)


def ladder(c, x, y_top, y_bot, w=26, col=(190, 196, 206)):
    c.line([(x - w / 2, y_top), (x - w / 2, y_bot)], col, 4)
    c.line([(x + w / 2, y_top), (x + w / 2, y_bot)], col, 4)
    yy = y_top + 10
    while yy < y_bot:
        c.line([(x - w / 2, yy), (x + w / 2, yy)], col, 3, False)
        yy += 18
    c.arc(x - w / 2 - 10, y_top, 10, 180, 360, col, 4)
    c.arc(x + w / 2 + 10, y_top, 10, 180, 360, col, 4)


def exit_sign(c, x, y, s=1.0):
    c.rect(x - 34 * s, y - 12 * s, x + 34 * s, y + 12 * s, fill=(20, 140, 60), outline=WHITE, width=1.5)
    c.text(x, y + 1 * s, "EXIT", 16 * s, WHITE, "sans", "mm", 0)


# ---------------------------------------------------------------- water
def wave_y(x, ys, t, amp=1.5, bumps=()):
    yy = ys + math.sin(x * 0.05 + t * 2.0) * amp + math.sin(x * 0.11 - t * 1.3) * amp * 0.5
    for bx, bh, bw in bumps:
        d = (x - bx) / max(bw, 1)
        yy -= bh * math.exp(-d * d) * math.cos(d * 2.2)
    return yy


def water(c, x0, x1, ys, yb, t=0.0, col=CYAN, alpha=0.62, amp=1.5, bumps=(), surface=CYAN_L):
    """Side cross-section of water, drawn see-through over whatever is standing in it.
    bumps: (x, height, width) for splashes and ripples travelling along the surface."""
    n = max(2, int((x1 - x0) / 4))
    pts = [(x0 + (x1 - x0) * i / n, wave_y(x0 + (x1 - x0) * i / n, ys, t, amp, bumps)) for i in range(n + 1)]
    top = min(y for _, y in pts) - 2
    ox, oy = int(x0 * S), int(top * S)
    lay = Image.new("RGBA", (int((x1 - x0) * S) + 2, int((yb - top) * S) + 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    d.polygon([(x * S - ox, y * S - oy) for x, y in pts + [(x1, yb), (x0, yb)]], fill=col + (int(255 * alpha),))
    for k in range(3):
        yy = ys + 14 + k * 16
        if yy < yb - 4:
            for j in range(int((x1 - x0) / 60) + 2):
                xx = x0 + ((j * 60 + t * 10 * (k + 1)) % (x1 - x0 + 60)) - 30
                if x0 < xx < x1 - 26:
                    d.line([(xx * S - ox, yy * S - oy), ((xx + 22) * S - ox, yy * S - oy)], fill=CYAN_L + (90,), width=2)
    c.overlay(lay, at=(ox, oy))
    if surface:
        c.line(pts, surface, 2, False)
    return pts


@lru_cache(maxsize=64)
def _hatch_img(w, h, col, line, step):
    im = Image.new("RGB", (w, h), col)
    d = ImageDraw.Draw(im)
    for k in range(-h, w, step * S):
        d.line([(k, h), (k + h, 0)], fill=line, width=S)
    d.rectangle([0, 0, w - 1, h - 1], outline=(40, 42, 50), width=int(1.5 * S))
    return im


def hatch(c, x0, y0, x1, y1, col=(96, 100, 112), line=(60, 62, 72), step=10):
    """Concrete in section: a filled block with diagonal hatching, like an architect's drawing."""
    w, h = int((x1 - x0) * S), int((y1 - y0) * S)
    if w > 0 and h > 0:
        c.im.paste(_hatch_img(w, h, col, line, step), (int(x0 * S), int(y0 * S)))


@lru_cache(maxsize=64)
def _deck_img(w, h, tile):
    im = Image.new("RGB", (w, h), TILE)
    d = ImageDraw.Draw(im)
    g = mix(TILE, GREY_D, 0.35)
    for yy in range(tile * S, h, tile * S):
        d.line([(0, yy), (w, yy)], fill=g, width=S)
    for xx in range(tile * S, w, tile * S):
        d.line([(xx, 0), (xx, h)], fill=g, width=S)
    d.rectangle([0, 0, w - 1, h - 1], outline=(70, 80, 96), width=int(1.5 * S))
    return im


def deck(c, x0, x1, y_top, y_bot=480, tile=16):
    """A tiled poolside deck (or a tiled column) in section."""
    w, h = int((x1 - x0) * S), int((y_bot - y_top) * S)
    if w > 0 and h > 0:
        c.im.paste(_deck_img(w, h, tile), (int(x0 * S), int(y_top * S)))


def back_wall(c, col=NAVY, line=None, step=24, y1=480):
    """Faint tiles on the far wall behind a cross-section."""
    line = line or mix(col, WHITE, 0.08)
    for x in range(0, W + 1, step):
        c.line([(x, 0), (x, y1)], line, 1, False)
    for y in range(0, y1 + 1, step):
        c.line([(0, y), (W, y)], line, 1, False)


def sound_arcs(c, x, ys, age, strength=1.0, speed=70, life=2.4, col=WHITE, base=WATER_D, rings=3):
    """Sound spreading through the water from a noise at the surface (half rings below it)."""
    if age < 0 or age > life:
        return
    for k in range(rings):
        a = age - k * 0.25
        if a <= 0:
            continue
        r = a * speed
        fade = (1 - age / life) * strength
        c.arc(x, ys, r, 0, 180, mix(base, col, fade), max(1, 2.5 * strength * (1 - k * 0.25)))


def surface_bumps(events, t, speed=60, life=2.0):
    """Ripples on the surface from noises: events are (x, t0, strength). Returns bumps for water()."""
    out = []
    for x, t0, st in events:
        a = t - t0
        if 0 <= a < life:
            h = 6 * st * math.exp(-a * 2.2)
            if a < 0.25:
                out.append((x, h * 1.6 * (1 - a * 4), 10))
            out.append((x - a * speed, h, 9))
            out.append((x + a * speed, h, 9))
    return out


# ---------------------------------------------------------------- silhouettes
_SIL = None


def _sil_data():
    global _SIL
    if _SIL is None:
        idx = json.load(open(f"{HERE}/silhouettes/index.json"))
        _SIL = {k: (Image.open(f"{HERE}/silhouettes/{k}.png").convert("L"), v) for k, v in idx.items()}
    return _SIL


@lru_cache(maxsize=512)
def sil_mask(name, frame, hpx, flip=False):
    strip, info = _sil_data()[name]
    f = frame % info["frames"]
    m = strip.crop((f * info["w"], 0, (f + 1) * info["w"], info["h"]))
    w = max(1, int(info["w"] * hpx / info["h"]))
    m = m.resize((w, int(hpx)), Image.LANCZOS)
    if flip:
        m = m.transpose(Image.FLIP_LEFT_RIGHT)
    return m


def sil_frame(name, t):
    info = _sil_data()[name][1]
    return int(t * info["fps"]) % info["frames"]


def sil(c, name, frame, x, y, h, col=BLACK, flip=False, alpha=1.0, anchor="b"):
    """Draw a silhouette frame with its bottom-centre (anchor b) or centre (anchor c) at (x, y), h tall.
    The Wader faces left unless flipped."""
    m = sil_mask(name, frame, int(h * S), flip)
    w = m.size[0] / S
    top = y - h if anchor == "b" else y - h / 2
    c.paste_mask(m, x - w / 2, top, col, alpha)
    return (x - w / 2, top, x + w / 2, top + h)


# ---------------------------------------------------------------- the seal
FALCON = [(-0.80, -0.02), (-0.70, -0.20), (-0.50, -0.36), (-0.20, -0.56), (0.15, -0.62), (0.45, -0.50),
          (0.62, -0.20), (0.58, 0.20), (0.70, 0.62), (0.30, 0.55), (0.35, 0.78), (-0.05, 0.60),
          (-0.10, 0.80), (-0.30, 0.45), (-0.45, 0.18), (-0.56, 0.10), (-0.68, 0.04), (-0.74, 0.06)]


def falcon_head(d, cx, cy, r, col, dark):
    """Draw on a raw ImageDraw in pixels."""
    d.polygon([(cx + x * r, cy + y * r) for x, y in FALCON], fill=col)
    d.polygon([(cx + x * r, cy + y * r) for x, y in [(-0.33, -0.10), (-0.17, -0.08), (-0.22, 0.32), (-0.34, 0.26)]], fill=dark)
    d.line([(cx - 0.56 * r, cy + 0.10 * r), (cx - 0.42 * r, cy - 0.04 * r)], fill=dark, width=max(1, int(r * 0.05)))
    e = (cx - 0.24 * r, cy - 0.24 * r)
    d.ellipse([e[0] - 0.11 * r, e[1] - 0.11 * r, e[0] + 0.11 * r, e[1] + 0.11 * r], fill=dark)
    d.ellipse([e[0] - 0.05 * r, e[1] - 0.06 * r, e[0] + 0.03 * r, e[1] + 0.02 * r], fill=col)


@lru_cache(maxsize=8)
def seal_image(r, ring=GOLD, inner=NAVY2, text_col=WHITE):
    """The F.A.L.C.O.N. seal as an RGBA image, 2r x 2r canvas units."""
    R = int(r * S)
    im = Image.new("RGBA", (2 * R + 4, 2 * R + 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = R + 2
    d.ellipse([c - R, c - R, c + R, c + R], fill=ring)
    d.ellipse([c - R * 0.93, c - R * 0.93, c + R * 0.93, c + R * 0.93], fill=(18, 30, 92))
    d.ellipse([c - R * 0.66, c - R * 0.66, c + R * 0.66, c + R * 0.66], fill=ring)
    d.ellipse([c - R * 0.62, c - R * 0.62, c + R * 0.62, c + R * 0.62], fill=inner)
    falcon_head(d, c + R * 0.04, c - R * 0.02, R * 0.5, ring, inner)
    # three stars under the falcon
    for k in (-1, 0, 1):
        sx, sy = c + k * R * 0.17, c + R * 0.5
        pts = []
        for i in range(10):
            a = -math.pi / 2 + i * math.pi / 5
            rr = R * (0.05 if i % 2 == 0 else 0.02)
            pts.append((sx + math.cos(a) * rr, sy + math.sin(a) * rr))
        d.polygon(pts, fill=text_col)
    # ring text
    fnt = ImageFont.truetype(FONTS["sans"], int(R * 0.115))

    def ring_text(s, center_deg, radius, inward=True):
        widths = [fnt.getlength(ch) * 1.08 for ch in s]
        total = sum(widths)
        ang = center_deg - math.degrees(total / 2 / radius) * (1 if inward else -1)
        for ch, w in zip(s, widths):
            step = math.degrees(w / radius)
            mid = ang + (step / 2 if inward else -step / 2)
            a = math.radians(mid)
            px, py = c + math.cos(a) * radius, c + math.sin(a) * radius
            g = Image.new("RGBA", (int(R * 0.3), int(R * 0.3)), (0, 0, 0, 0))
            ImageDraw.Draw(g).text((g.size[0] / 2, g.size[1] / 2), ch, font=fnt, fill=text_col, anchor="mm")
            rot = -(mid + 90) if inward else -(mid - 90)
            g = g.rotate(rot, resample=Image.BICUBIC)
            im.alpha_composite(g, (int(px - g.size[0] / 2), int(py - g.size[1] / 2)))
            ang += step if inward else -step

    ring_text("FEDERAL AGENCY FOR LIMINAL CLASSIFICATION", -90, R * 0.795, True)
    ring_text("& OCCULT NATURE", 90, R * 0.795, False)
    for a in (180 - 32, 32):
        aa = math.radians(a)
        px, py = c + math.cos(aa) * R * 0.795, c + math.sin(aa) * R * 0.795
        d.ellipse([px - R * 0.025, py - R * 0.025, px + R * 0.025, py + R * 0.025], fill=text_col)
    return im


def seal(c, cx, cy, r, progress=1.0, alpha=1.0):
    im = seal_image(r)
    if progress < 1:
        m = Image.new("L", im.size, 0)
        ImageDraw.Draw(m).pieslice([0, 0, im.size[0], im.size[1]], -90, -90 + 360 * ease(progress), fill=255)
        a = Image.composite(im.getchannel("A"), Image.new("L", im.size, 0), m)
        im = im.copy()
        im.putalpha(a)
    if alpha < 1:
        im = im.copy()
        im.putalpha(im.getchannel("A").point(lambda v: int(v * alpha)))
    lay = Image.new("RGBA", c.im.size, (0, 0, 0, 0))
    lay.alpha_composite(im, (int(cx * S - im.size[0] / 2), int(cy * S - im.size[1] / 2)))
    c.overlay(lay)


# ---------------------------------------------------------------- frame furniture
def gradient_bg(c, top, bottom):
    arr = np.linspace(0, 1, H * S)[:, None]
    col = (np.array(top)[None, :] * (1 - arr) + np.array(bottom)[None, :] * arr).astype(np.uint8)
    c.im = Image.fromarray(np.repeat(col[:, None, :], W * S, axis=1))
    c.d = ImageDraw.Draw(c.im)


def bug(c, section, title):
    """The small lower-left label shown through each section."""
    c.rect(0, 440, 236, 462, fill=(10, 16, 50))
    c.rect(0, 440, 6, 462, fill=RED)
    c.text(14, 451, f"SEC. {section}", 12, GOLD, "sans", "lm", 0)
    c.text(70, 451, title, 12, WHITE, "sans", "lm", 0)


def caption_box(c, s, y=398, size=22, fill=WHITE, box=(8, 12, 40), border=None, alpha=1.0, x=320):
    fnt = font("sans", size)
    w = fnt.getlength(s) / S
    pad = 12
    col = mix(c.bg, fill, alpha) if alpha < 1 else fill
    c.rect(x - w / 2 - pad, y - size * 0.75, x + w / 2 + pad, y + size * 0.75, fill=box, outline=border, width=2 if border else 1)
    c.text(x, y, s, size, col, "sans", "mm", 0)


def meter(c, x, y, w, h, level, segs=12):
    """A segmented noise meter, green to red, lit up to level (0..1)."""
    gap = 2
    sw = (w - gap * (segs - 1)) / segs
    for i in range(segs):
        f = i / (segs - 1)
        col = GREEN if f < 0.5 else (YELLOW if f < 0.75 else RED)
        lit = (i + 0.5) / segs <= level
        c.rect(x + i * (sw + gap), y, x + i * (sw + gap) + sw, y + h, fill=col if lit else mix(col, BLACK, 0.78))
