# Drawing helpers for the tape: a 640x480 canvas drawn at 2x and shrunk (for smooth edges),
# broadcast-style text, the simulated water of the side cross-sections, and the pasted-in assets:
# ISO safety signs, the road-sign people, the falcon seal and the Wader's silhouettes.
import json, math, os
from functools import lru_cache
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = f"{HERE}/assets"
W, H = 640, 480
S = 2

NAVY = (14, 26, 86)
NAVY2 = (28, 46, 128)
BLACK = (6, 6, 10)
WHITE = (236, 236, 226)
GOLD = (236, 196, 70)
RED = (200, 34, 40)
GREEN = (60, 190, 90)
CYAN = (70, 178, 210)
CYAN_L = (130, 214, 236)
WATER_D = (24, 92, 132)
GREY = (150, 156, 170)
GREY_D = (78, 84, 100)
TILE = (198, 214, 222)
VCR_BLUE = (16, 24, 190)
CREAM = (232, 226, 204)

FONTS = {
    "sans": "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "mono": "/usr/share/fonts/truetype/freefont/FreeMonoBold.ttf",
    "osd": "/usr/share/fonts/opentype/unifont/unifont.otf",
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


def typed(s, t, cps=22):
    return s[:int(max(0, t) * cps)]


class Canvas:
    def __init__(self, bg=NAVY):
        self.bg = bg
        self.im = Image.new("RGB", (W * S, H * S), bg)
        self.d = ImageDraw.Draw(self.im)

    def rect(self, x0, y0, x1, y1, fill=None, outline=None, width=1):
        if x1 * S - 1 < x0 * S or y1 * S - 1 < y0 * S:
            return
        self.d.rectangle([x0 * S, y0 * S, x1 * S - 1, y1 * S - 1], fill=fill, outline=outline, width=int(width * S))

    def line(self, pts, fill, width=2):
        self.d.line([(x * S, y * S) for x, y in pts], fill=fill, width=max(1, int(width * S)), joint="curve")

    def dashed(self, a, b, fill, width=2, dash=8, gap=6):
        (x0, y0), (x1, y1) = a, b
        L = math.hypot(x1 - x0, y1 - y0)
        ux, uy = (x1 - x0) / L, (y1 - y0) / L
        s = 0.0
        while s < L:
            e = min(s + dash, L)
            self.line([(x0 + ux * s, y0 + uy * s), (x0 + ux * e, y0 + uy * e)], fill, width)
            s += dash + gap

    def circle(self, cx, cy, r, fill=None, outline=None, width=1):
        self.d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=fill, outline=outline, width=int(width * S))

    def pie(self, cx, cy, r, a0, a1, fill):
        self.d.pieslice([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], a0, a1, fill=fill)

    def arc(self, cx, cy, r, a0, a1, fill, width=2):
        self.d.arc([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], a0, a1, fill=fill, width=int(width * S))

    def text(self, x, y, s, size=20, fill=WHITE, f="sans", anchor="la", shadow=2, track=0):
        fnt = font(f, size)
        if track:
            widths = [fnt.getlength(ch) + track * S for ch in s]
            total = sum(widths) - track * S
            cx = x * S - {"l": 0, "m": total / 2, "r": total}[anchor[0]]
            for ch, w in zip(s, widths):
                if shadow:
                    self.d.text((cx + shadow * S, y * S + shadow * S), ch, font=fnt, fill=(0, 0, 0), anchor="l" + anchor[1])
                self.d.text((cx, y * S), ch, font=fnt, fill=fill, anchor="l" + anchor[1])
                cx += w
            return
        if shadow:
            self.d.text((x * S + shadow * S, y * S + shadow * S), s, font=fnt, fill=(0, 0, 0), anchor=anchor)
        self.d.text((x * S, y * S), s, font=fnt, fill=fill, anchor=anchor)

    def lines(self, x, y, rows, size=20, fill=WHITE, lh=1.4, anchor="mm", shadow=2, f="sans"):
        for i, s in enumerate(rows):
            self.text(x, y + i * size * lh, s, size, fill, f, anchor, shadow)

    def paste_mask(self, mask, x, y, color, alpha=1.0):
        if alpha < 1:
            mask = mask.point(lambda v: int(v * alpha))
        self.im.paste(Image.new("RGB", mask.size, color), (int(x * S), int(y * S)), mask)

    def paste_rgba(self, im, x, y, alpha=1.0):
        a = im.getchannel("A")
        if alpha < 1:
            a = a.point(lambda v: int(v * alpha))
        self.im.paste(im.convert("RGB"), (int(x * S), int(y * S)), a)

    def overlay(self, rgba, at=(0, 0)):
        self.im.paste(rgba.convert("RGB"), at, rgba.getchannel("A"))
        self.d = ImageDraw.Draw(self.im)

    def layer(self):
        lay = Image.new("RGBA", self.im.size, (0, 0, 0, 0))
        return lay, ImageDraw.Draw(lay)

    def fade_to(self, color, a):
        if a > 0:
            self.im = Image.blend(self.im, Image.new("RGB", self.im.size, color), clamp01(a))
            self.d = ImageDraw.Draw(self.im)

    def finish(self):
        return np.asarray(self.im.resize((W, H), Image.LANCZOS))


def tw(s, size, f="sans", track=0):
    return font(f, size).getlength(s) / S + track * (len(s) - 1)


def caption(c, s, y=58, size=22, fill=WHITE, box=(8, 12, 40), border=None):
    w = tw(s, size)
    c.rect(320 - w / 2 - 12, y - size * 0.75, 320 + w / 2 + 12, y + size * 0.75, fill=box, outline=border, width=2)
    c.text(320, y, s, size, fill, "sans", "mm", 0)


def bug(c, title):
    """The small labels shown through the program: the section, lower left; the tape, lower right."""
    c.rect(0, 440, 40 + tw(title, 12), 462, fill=(10, 16, 50))
    c.rect(0, 440, 6, 462, fill=RED)
    c.text(16, 451, title, 12, WHITE, "sans", "lm", 0)
    c.text(624, 451, "F.A.L.C.O.N.  \u00b7  07-W", 11, (170, 176, 196), "sans", "rm", 0, track=1)


# ---------------------------------------------------------------- simulated water
def wave_y(x, ys, t, amp=1.5, bumps=()):
    yy = ys + math.sin(x * 0.05 + t * 2.0) * amp + math.sin(x * 0.11 - t * 1.3) * amp * 0.5
    for bx, bh, bw in bumps:
        d = (x - bx) / max(bw, 1)
        yy -= bh * math.exp(-d * d) * math.cos(d * 2.2)
    return yy


def water(c, x0, x1, ys, yb, t=0.0, col=CYAN, alpha=0.62, amp=1.5, bumps=()):
    """Side cross-section of water, drawn see-through over whatever stands in it.
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
    c.line(pts, CYAN_L, 2)


def surface_bumps(events, t, speed=60, life=2.0):
    """Ripples on the surface from noises: events are (x, t0, strength)."""
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


def sound_arcs(c, x, ys, age, strength=1.0, speed=90, life=3.5, col=WHITE, base=WATER_D):
    """Sound spreading through the water from a noise at the surface (half rings below it)."""
    if not 0 <= age <= life:
        return
    for k in range(3):
        a = age - k * 0.25
        if a > 0:
            c.arc(x, ys, a * speed, 0, 180, mix(base, col, (1 - age / life) * strength), max(1, 2.5 * strength * (1 - k * 0.25)))


@lru_cache(maxsize=16)
def _hatch_img(w, h):
    im = Image.new("RGB", (w, h), (96, 100, 112))
    d = ImageDraw.Draw(im)
    for k in range(-h, w, 10 * S):
        d.line([(k, h), (k + h, 0)], fill=(60, 62, 72), width=S)
    d.rectangle([0, 0, w - 1, h - 1], outline=(40, 42, 50), width=3)
    return im


def hatch(c, x0, y0, x1, y1):
    """Concrete in section."""
    w, h = int((x1 - x0) * S), int((y1 - y0) * S)
    if w > 0 and h > 0:
        c.im.paste(_hatch_img(w, h), (int(x0 * S), int(y0 * S)))


@lru_cache(maxsize=16)
def _deck_img(w, h):
    im = Image.new("RGB", (w, h), TILE)
    d = ImageDraw.Draw(im)
    g = mix(TILE, GREY_D, 0.35)
    for yy in range(16 * S, h, 16 * S):
        d.line([(0, yy), (w, yy)], fill=g, width=S)
    for xx in range(16 * S, w, 16 * S):
        d.line([(xx, 0), (xx, h)], fill=g, width=S)
    d.rectangle([0, 0, w - 1, h - 1], outline=(70, 80, 96), width=3)
    return im


def deck(c, x0, x1, y_top, y_bot=480):
    """A tiled poolside deck in section."""
    w, h = int((x1 - x0) * S), int((y_bot - y_top) * S)
    if w > 0 and h > 0:
        c.im.paste(_deck_img(w, h), (int(x0 * S), int(y_top * S)))


def back_wall(c, col=NAVY, step=24):
    line = mix(col, WHITE, 0.08)
    for x in range(0, W + 1, step):
        c.line([(x, 0), (x, H)], line, 1)
    for y in range(0, H + 1, step):
        c.line([(0, y), (W, y)], line, 1)


def pool(c, dx=200, dy=290, fy=372, bg=NAVY):
    """Background of a pool in section: far wall, deck on the left, concrete floor."""
    c.rect(0, 0, W, H, fill=bg)
    back_wall(c, bg)
    hatch(c, dx, fy, W, H)
    if dx > 0:
        deck(c, 0, dx, dy)


# ---------------------------------------------------------------- assets
@lru_cache(maxsize=None)
def _asset(path):
    im = Image.open(path)
    im = im.convert("RGBA") if im.mode != "L" else im
    bbox = (im.getchannel("A") if im.mode == "RGBA" else im).getbbox()
    return im.crop(bbox)


@lru_cache(maxsize=256)
def _scaled(path, hpx, flip=False, rot=0):
    im = _asset(path)
    w = max(1, round(im.size[0] * hpx / im.size[1]))
    im = im.resize((w, int(hpx)), Image.LANCZOS)
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    if rot:
        im = im.rotate(rot, resample=Image.BICUBIC, expand=True)
    return im


def sign(c, name, x, y, h, alpha=1.0):
    """One of the tape's safety signs (assets/made/, built from ISO 7010 signs) centred at (x, y)."""
    im = _scaled(f"{ASSETS}/made/sign_{name}.png", int(h * S))
    c.paste_rgba(im, x - im.size[0] / S / 2, y - im.size[1] / S / 2, alpha)


def person(c, kind, x, y, h, col=WHITE, flip=False, alpha=1.0, rot=0):
    """A road-sign person (stand, woman, walk, run) with feet at (x, y), h tall."""
    m = _scaled(f"{ASSETS}/people/{kind}.png", int(h * S), flip, rot)
    w, hh = m.size[0] / S, m.size[1] / S
    c.paste_mask(m, x - w / 2, y - hh, col, alpha)
    return (x - w / 2, y - hh, x + w / 2, y)


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
    m = m.resize((max(1, int(info["w"] * hpx / info["h"])), int(hpx)), Image.LANCZOS)
    return m.transpose(Image.FLIP_LEFT_RIGHT) if flip else m


def sil_frame(name, t):
    info = _sil_data()[name][1]
    return int(t * info["fps"]) % info["frames"]


def sil(c, name, frame, x, y, h, col=BLACK, flip=False, alpha=1.0):
    """A Wader silhouette with its feet at (x, y), h tall. It faces left unless flipped."""
    m = sil_mask(name, frame, int(h * S), flip)
    w = m.size[0] / S
    c.paste_mask(m, x - w / 2, y - h, col, alpha)
    return (x - w / 2, y - h, x + w / 2, y)


@lru_cache(maxsize=4)
def seal_image(r):
    """The F.A.L.C.O.N. seal: the falcon in a ring of lettering, as RGBA, 2r across."""
    R = int(r * S)
    im = Image.new("RGBA", (2 * R + 4, 2 * R + 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = R + 2
    d.ellipse([c - R, c - R, c + R, c + R], fill=GOLD)
    d.ellipse([c - R * 0.93, c - R * 0.93, c + R * 0.93, c + R * 0.93], fill=(18, 30, 92))
    d.ellipse([c - R * 0.66, c - R * 0.66, c + R * 0.66, c + R * 0.66], fill=GOLD)
    d.ellipse([c - R * 0.62, c - R * 0.62, c + R * 0.62, c + R * 0.62], fill=CREAM)
    bird = _asset(f"{ASSETS}/falcon_121135.png")
    bh = int(R * 0.98)
    bird = bird.resize((int(bird.size[0] * bh / bird.size[1]), bh), Image.LANCZOS)
    inner = Image.new("L", im.size, 0)
    ImageDraw.Draw(inner).ellipse([c - R * 0.6, c - R * 0.6, c + R * 0.6, c + R * 0.6], fill=255)
    lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    lay.alpha_composite(bird, (int(c - bird.size[0] / 2), int(c - bh / 2 + R * 0.04)))
    lay.putalpha(Image.composite(lay.getchannel("A"), Image.new("L", im.size, 0), inner))
    im.alpha_composite(lay)
    fnt = ImageFont.truetype(FONTS["sans"], int(R * 0.115))

    def ring_text(s, center_deg, radius, inward):
        widths = [fnt.getlength(ch) * 1.08 for ch in s]
        ang = center_deg - math.degrees(sum(widths) / 2 / radius) * (1 if inward else -1)
        for ch, w in zip(s, widths):
            step = math.degrees(w / radius)
            mid = ang + (step / 2 if inward else -step / 2)
            a = math.radians(mid)
            g = Image.new("RGBA", (int(R * 0.3), int(R * 0.3)), (0, 0, 0, 0))
            ImageDraw.Draw(g).text((g.size[0] / 2, g.size[1] / 2), ch, font=fnt, fill=WHITE, anchor="mm")
            g = g.rotate(-(mid + 90) if inward else -(mid - 90), resample=Image.BICUBIC)
            im.alpha_composite(g, (int(c + math.cos(a) * radius - g.size[0] / 2), int(c + math.sin(a) * radius - g.size[1] / 2)))
            ang += step if inward else -step

    ring_text("FEDERAL AGENCY FOR LIMINAL CLASSIFICATION", -90, R * 0.795, True)
    ring_text("& OCCULT NATURE", 90, R * 0.795, False)
    for a in (180 - 32, 32):
        aa = math.radians(a)
        px, py = c + math.cos(aa) * R * 0.795, c + math.sin(aa) * R * 0.795
        d.ellipse([px - R * 0.025, py - R * 0.025, px + R * 0.025, py + R * 0.025], fill=WHITE)
    return im


def seal(c, cx, cy, r, progress=1.0):
    im = seal_image(r)
    if progress < 1:
        m = Image.new("L", im.size, 0)
        ImageDraw.Draw(m).pieslice([0, 0, im.size[0], im.size[1]], -90, -90 + 360 * ease(progress), fill=255)
        im = im.copy()
        im.putalpha(Image.composite(im.getchannel("A"), Image.new("L", im.size, 0), m))
    c.overlay(im, at=(int(cx * S - im.size[0] / 2), int(cy * S - im.size[1] / 2)))
