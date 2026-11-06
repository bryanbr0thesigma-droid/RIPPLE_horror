# Draws the two cassette labels for a F.A.L.C.O.N. tape: the spine (side) label and the face (top)
# label, at real VHS label proportions (spine 146 x 19 mm, face 78 x 46 mm).
#   python3 labels.py <out_dir> [tape: 07-W (default) or 08-E]
import os, sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gfx

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
TAPES = {
    "07-W": dict(title=("WATER SAFETY", "AND YOU"), spine="WATER SAFETY AND YOU",
                 sub=("A FIELD GUIDE TO LIMINAL ENTITY L-7", "\u201cTHE WADER\u201d"), time="3 MIN 18 SEC", suffix=""),
    "08-E": dict(title=("GOING IN,", "COMING OUT"), spine="GOING IN, COMING OUT",
                 sub=("ENTRY AND EXIT PROCEDURES", "\u201cTHE POOLROOMS\u201d"), time="3 MIN 8 SEC", suffix="_08"),
}
TAPE = sys.argv[2] if len(sys.argv) > 2 else "07-W"
T = TAPES[TAPE]
CAT = "FAL-" + TAPE.replace("-", "") + "-91"
PAPER = (234, 229, 213)
NAVY = (18, 32, 92)
GOLD = (214, 172, 58)
RED = (178, 30, 36)
INK = (24, 26, 34)
SANS = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
SANSR = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
MONO = "/usr/share/fonts/truetype/freefont/FreeMonoBold.ttf"


def f(path, size):
    return ImageFont.truetype(path, size)


def tracked(d, xy, s, fnt, fill, track=0, anchor="l"):
    """Letter-spaced text; anchor l, m or r on the x axis, y is the vertical middle."""
    widths = [fnt.getlength(ch) + track for ch in s]
    total = sum(widths) - track
    x = xy[0] - {"l": 0, "m": total / 2, "r": total}[anchor]
    for ch, w in zip(s, widths):
        d.text((x, xy[1]), ch, font=fnt, fill=fill, anchor="lm")
        x += w
    return total


def paper(w, h, seed):
    """Printed label stock: a faint grain, and edges a little yellowed with age."""
    rng = np.random.default_rng(seed)
    base = np.ones((h, w, 3)) * np.array(PAPER, float)
    base += rng.normal(0, 3.5, (h, w, 1))
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy)) / (0.12 * min(w, h))
    base -= np.clip(1 - edge, 0, 1)[..., None] * np.array([6, 10, 22])
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8))


def seal(diameter):
    im = gfx.seal_image(diameter / 2 / gfx.S)
    return im.resize((diameter, diameter), Image.LANCZOS)


def stamp(text, w, h, angle, size):
    """A red rubber stamp: a ruled box with the word in it, a little uneven, rotated."""
    lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    fnt = f(SANS, size)
    tw = fnt.getlength(text) + 0.18 * size * (len(text) - 1)
    bx0, by0 = (w - tw) / 2 - size * 0.35, h / 2 - size * 0.75
    bx1, by1 = (w + tw) / 2 + size * 0.35, h / 2 + size * 0.75
    d.rectangle([bx0, by0, bx1, by1], outline=RED + (255,), width=max(3, size // 9))
    tracked(d, (w / 2, h / 2 + size * 0.02), text, fnt, RED + (255,), 0.18 * size, "m")
    a = np.asarray(lay).copy()
    rng = np.random.default_rng(7)
    a[..., 3] = (a[..., 3] * np.clip(rng.normal(0.82, 0.18, a.shape[:2]), 0, 1)).astype(np.uint8)
    return Image.fromarray(a).rotate(angle, resample=Image.BICUBIC, expand=False)


# ---------------------------------------------------------------- face (top) label, 78 x 46 mm
W, H = 1404, 828
face = paper(W, H, 1)
d = ImageDraw.Draw(face)
band = 168
d.rectangle([0, 0, W, band], fill=NAVY)
d.rectangle([0, band, W, band + 10], fill=RED)
d.rectangle([0, band + 10, W, band + 16], fill=GOLD)
tracked(d, (W / 2, 70), "F.A.L.C.O.N.", f(SANS, 76), (240, 238, 228), 22, "m")
tracked(d, (W / 2, 132), "FEDERAL AGENCY FOR LIMINAL CLASSIFICATION & OCCULT NATURE", f(SANS, 25), GOLD, 4, "m")
sd = 340
face.paste(s := seal(sd), (60, band + 52), s)
x0 = 60 + sd + 56
tracked(d, (x0, band + 82), f"ORIENTATION TAPE {TAPE}", f(MONO, 40), RED, 2)
d.text((x0, band + 128), T["title"][0], font=f(SANS, 92), fill=NAVY, anchor="la")
d.text((x0, band + 228), T["title"][1], font=f(SANS, 92), fill=NAVY, anchor="la")
tracked(d, (x0 + 2, band + 352), T["sub"][0], f(SANS, 30), INK, 2)
tracked(d, (x0 + 2, band + 392), T["sub"][1], f(SANS, 30), RED, 3)
# the warning strip and the small print
yb = H - 178
d.rectangle([40, yb, W - 40, yb + 54], fill=RED)
tracked(d, (W / 2, yb + 28), "FOR AUTHORIZED PERSONNEL ONLY", f(SANS, 36), (246, 240, 230), 8, "m")
small = f(MONO, 32)
d.text((44, H - 92), f"RUNNING TIME {T['time']} · VHS SP · COLOR", font=small, fill=INK, anchor="lm")
d.text((W - 44, H - 92), f"CAT. NO. {CAT}", font=small, fill=INK, anchor="rm")
d.text((W / 2, H - 46), "© 1991 F.A.L.C.O.N. TRAINING DIVISION  ·  DUPLICATION PROHIBITED",
       font=f(SANS, 28), fill=INK, anchor="mm")
d.rectangle([14, 14, W - 15, H - 15], outline=NAVY, width=3)
st = stamp("RESTRICTED", 520, 140, 3, 52)
face.paste(st, (W - 540, band + 348), st)
face.save(f"{OUT}/label_top{T['suffix']}.png")

# ---------------------------------------------------------------- spine (side) label, 146 x 19 mm
W2, H2 = 2048, 266
sp = paper(W2, H2, 2)
d = ImageDraw.Draw(sp)
d.rectangle([0, 0, 300, H2], fill=NAVY)
sp.paste(s := seal(228), (36, 19), s)
d.rectangle([300, 0, 312, H2], fill=RED)
d.rectangle([312, 0, 318, H2], fill=GOLD)
d.text((356, H2 / 2 - 4), T["spine"], font=f(SANS, 82), fill=NAVY, anchor="lm")
tw = f(SANS, 82).getlength(T["spine"]) - 4
tracked(d, (356 + tw + 34, H2 / 2 - 32), "ORIENTATION", f(MONO, 34), RED, 1)
tracked(d, (356 + tw + 34, H2 / 2 + 20), f"TAPE {TAPE}", f(MONO, 34), RED, 1)
d.rectangle([W2 - 330, 0, W2, H2], fill=NAVY)
d.rectangle([W2 - 342, 0, W2 - 330, H2], fill=RED)
tracked(d, (W2 - 165, H2 / 2 - 30), "F.A.L.C.O.N.", f(SANS, 38), (240, 238, 228), 5, "m")
tracked(d, (W2 - 165, H2 / 2 + 34), "VHS · SP", f(SANS, 30), GOLD, 6, "m")
d.rectangle([0, H2 - 10, W2 - 342, H2], fill=RED)
sp.save(f"{OUT}/label_spine{T['suffix']}.png")

# a side-by-side preview for approval
pv = Image.new("RGB", (W2 + 80, H + H2 + 160), (40, 42, 48))
pd = ImageDraw.Draw(pv)
pd.text((40, 30), "TOP LABEL (78 x 46 mm)", font=f(SANS, 30), fill=(220, 220, 220), anchor="lm")
pv.paste(face, (40, 60))
pd.text((40, H + 100), "SIDE / SPINE LABEL (146 x 19 mm)", font=f(SANS, 30), fill=(220, 220, 220), anchor="lm")
pv.paste(sp, (40, H + 130))
pv.save(f"{OUT}/labels_preview{T['suffix']}.png")
print("ok")
