# Makes the tape's own safety signs out of the public-domain ISO 7010 signs in assets/signs/:
# each sign is split into its layers (white disc, black figure, red ring and slash, yellow
# triangle) and new signs are put together from them, with water added, and one with the Wader
# in it. Writes assets/made/.
#   python3 build_signs.py      (needs node with playwright, for render_svgs.mjs)
import json, math, os, re, subprocess, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SIGNS = f"{HERE}/assets/signs"
OUT = f"{HERE}/assets/made"
PX = 800
os.makedirs(OUT, exist_ok=True)
tmp = tempfile.mkdtemp(dir=os.environ.get("TMP_DIR"))


def svg(code):
    return open(f"{SIGNS}/ISO_7010_{code}.svg").read()


def keep_paths(s, idx):
    """Keep only the <path> elements at these positions."""
    paths = list(re.finditer(r"<path\b.*?/>", s, re.S))
    for i, m in reversed(list(enumerate(paths))):
        if i not in idx:
            s = s[:m.start()] + s[m.end():]
    return s


def drop(s, ids):
    for i in ids:
        s = re.sub(r"<(path|polygon|rect)\b[^>]*?id=\"%s\".*?/>" % i, "", s, flags=re.S)
    return s


parts = {
    "disc": keep_paths(svg("P001"), {0}),
    "ring": keep_paths(svg("P001"), {1}),
    "walker": keep_paths(svg("P004"), {1}),
    "tri": keep_paths(svg("W001"), {0}),
    "faller": drop(svg("W008"), ["path4", "polygon6"]),
    "W008": svg("W008"), "W001": svg("W001"), "M001": svg("M001"),
}
args = []
for k, v in parts.items():
    open(f"{tmp}/{k}.svg", "w").write(v)
    args += [f"{tmp}/{k}.svg", f"{tmp}/{k}.png"]
# render_svgs.mjs has to sit next to a node_modules with playwright: NODE_DIR points at one.
node_dir = os.environ.get("NODE_DIR", HERE)
if node_dir != HERE:
    open(f"{node_dir}/render_svgs.mjs", "w").write(open(f"{HERE}/render_svgs.mjs").read())
subprocess.run(["node", f"{node_dir}/render_svgs.mjs", str(PX)] + args, check=True, cwd=node_dir)
L = {k: Image.open(f"{tmp}/{k}.png").convert("RGBA") for k in parts}


def alpha(im):
    return np.asarray(im)[..., 3] > 100


def pieces(mask):
    """Split a mask into its separate pieces (largest first)."""
    im = Image.fromarray((mask * 255).astype(np.uint8)).copy()
    out, lab = [], 1
    while True:
        ys, xs = np.nonzero(np.asarray(im) == 255)
        if not len(ys):
            break
        ImageDraw.floodfill(im, (int(xs[0]), int(ys[0])), lab)
        out.append(np.asarray(im) == lab)
        lab += 1
    return sorted(out, key=lambda m: -m.sum())


def crop_mask(m):
    ys, xs = np.nonzero(m)
    return m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def save_mask(name, m):
    Image.fromarray((crop_mask(m) * 255).astype(np.uint8)).save(f"{OUT}/{name}.png", optimize=True)


# ---------------------------------------------------------------- signs
def waves(d, x0, x1, y, amp, period, width, color, rows=2, gap=None):
    gap = gap or amp * 3.2
    for r in range(rows):
        pts = [(x, y + r * gap + math.sin((x - x0) / period * 2 * math.pi) * amp) for x in np.linspace(x0, x1, 120)]
        d.line(pts, fill=color, width=width, joint="curve")


def disc_sign(name, figure, fig_box, wave_y, wave_rows=2):
    """White disc, a black figure, water, and the red ring and slash on top."""
    im = L["disc"].copy()
    fig = Image.fromarray((crop_mask(alpha(figure)) * 255).astype(np.uint8))
    x0, y0, x1, y1 = [int(v * PX / 265) for v in fig_box]
    fig = fig.resize((x1 - x0, y1 - y0), Image.LANCZOS) if (x1 - x0) * fig.size[1] == (y1 - y0) * fig.size[0] else \
        fig.resize((int(fig.size[0] * (y1 - y0) / fig.size[1]), y1 - y0), Image.LANCZOS)
    im.paste((0, 0, 0, 255), (x0 + (x1 - x0 - fig.size[0]) // 2, y0), fig)
    if wave_y:
        lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        wy = int(wave_y * PX / 265)
        d.rectangle([0, wy + 6, PX, PX], fill=(255, 255, 255, 255))
        waves(d, 0, PX, wy, 14, 120, 22, (0, 0, 0, 255), wave_rows)
        clip = Image.new("L", im.size, 0)
        ImageDraw.Draw(clip).ellipse([PX * 0.06, PX * 0.06, PX * 0.94, PX * 0.94], fill=255)
        im.paste(lay, (0, 0), Image.composite(lay.getchannel("A"), Image.new("L", im.size, 0), clip))
    im.alpha_composite(L["ring"])
    im.save(f"{OUT}/sign_{name}.png", optimize=True)


def tri_mask():
    """Inside of the yellow triangle (W001's), for clipping."""
    a = np.asarray(L["tri"])
    yellow = (a[..., 0] > 200) & (a[..., 1] > 130) & (a[..., 2] < 80) & (a[..., 3] > 200)
    return Image.fromarray((yellow * 255).astype(np.uint8))


def tri_sign(name, base, draw):
    global YEL
    im = L[base].copy()
    YEL = im.getpixel((im.size[0] // 2, int(im.size[1] * 0.86)))  # the sign's own yellow
    lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    draw(lay, ImageDraw.Draw(lay))
    m = tri_mask() if base == "tri" else Image.fromarray(((np.asarray(L[base])[..., 1] > 130) & (np.asarray(L[base])[..., 2] < 80)).astype(np.uint8) * 255)
    im.paste(lay, (0, 0), Image.composite(lay.getchannel("A"), Image.new("L", im.size, 0), m))
    im.save(f"{OUT}/sign_{name}.png", optimize=True)


# Stop moving: the walker knee-deep, crossed out.
disc_sign("still", L["walker"], (70, 42, 195, 205), 170)
# Do not go in after them: the faller dropping into water, crossed out.
disc_sign("rescue", L["faller"], (52, 48, 213, 172), 178)

YEL = (246, 189, 22, 255)


def fall_water(lay, d):
    W, H = lay.size
    d.rectangle([W * 0.52, H * 0.80, W, H], fill=YEL)
    waves(d, W * 0.5, W, H * 0.80, 13, 110, 22, (0, 0, 0, 255), 2)


tri_sign("fall", "W008", fall_water)

idx = json.load(open(f"{HERE}/silhouettes/index.json"))["side_idle"]
strip = Image.open(f"{HERE}/silhouettes/side_idle.png").convert("L")
wader = strip.crop((0, 0, idx["w"], idx["h"]))


def wader_water(lay, d):
    W, H = lay.size
    h = int(H * 0.50)
    m = wader.resize((int(wader.size[0] * h / wader.size[1]), h), Image.LANCZOS)
    lay.paste((0, 0, 0, 255), (int(W / 2 - m.size[0] / 2), int(H * 0.36)), m)
    d.rectangle([0, H * 0.74, W, H], fill=YEL)
    waves(d, 0, W, H * 0.74, 11, 100, 20, (0, 0, 0, 255), 2)


tri_sign("wader", "tri", wader_water)

# The falling person from the fall sign, on its own (the ledge left out), for the falling-in diagram.
fall = pieces(alpha(L["faller"]))
ledge = min(fall, key=lambda p: np.nonzero(p)[1].mean())
os.makedirs(f"{HERE}/assets/people", exist_ok=True)
fm = crop_mask(np.any([p for p in fall if p is not ledge], axis=0))
Image.fromarray((fm * 255).astype(np.uint8)).save(f"{HERE}/assets/people/fall.png", optimize=True)

for k in ("W001", "M001"):
    L[k].save(f"{OUT}/sign_{k}.png", optimize=True)

print("made", sorted(os.listdir(OUT)))
