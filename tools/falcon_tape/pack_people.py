# Cuts single figures out of "Template of road signs (stickmen)" (Openclipart 241042, public domain)
# rendered to PNG with render_svgs.mjs, and saves them as tight white-on-transparent masks in
# assets/people/.   python3 pack_people.py <stickmen.png>
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
im = Image.open(sys.argv[1]).convert("RGBA")
alpha = np.asarray(im)[..., 3] > 40
cols = alpha.any(0)
segs, start = [], None
for x, v in enumerate(cols):
    if v and start is None:
        start = x
    if not v and start is not None:
        segs.append((start, x)); start = None
# 0 pointing, 1 standing man, 2 woman, 3 litter, 4 walking, 5 two running, 6 ball, 7 child, 8 digging
want = {"stand": 1, "woman": 2, "walk": 4, "run": 5}


def round_head(m):
    """Swap the figure's head (its topmost separate piece) for a circle of the same size, so
    the moving figures' heads match the standing ones."""
    sub = Image.fromarray((m * 255).astype(np.uint8)).copy()
    pieces, label = [], 1
    while True:
        ys, xs = np.nonzero(np.asarray(sub) == 255)
        if not len(ys):
            break
        ImageDraw.floodfill(sub, (int(xs[0]), int(ys[0])), label)
        pieces.append(np.asarray(sub) == label)
        label += 1
    head = min((p for p in pieces if p.sum() > 200), key=lambda p: np.nonzero(p)[0].mean())
    ys, xs = np.nonzero(head)
    r = math.sqrt(head.sum() / math.pi)
    out = Image.fromarray(((m & ~head) * 255).astype(np.uint8))
    ImageDraw.Draw(out).ellipse([xs.mean() - r, ys.mean() - r, xs.mean() + r, ys.mean() + r], fill=255)
    return np.asarray(out) > 127


def save(name, m):
    ys, xs = np.nonzero(m)
    m = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    Image.fromarray((m * 255).astype(np.uint8)).save(f"{HERE}/assets/people/{name}.png", optimize=True)
    print(name, m.shape)


for name, k in want.items():
    a, b = segs[k]
    m = alpha[:, a:b]
    if name == "run":
        # two runners overlap; label the separate pieces and keep the grown-up's (right side)
        sub = Image.fromarray((m * 255).astype(np.uint8)).copy()
        pieces, label = [], 1
        while True:
            ys, xs = np.nonzero(np.asarray(sub) == 255)
            if not len(ys):
                break
            ImageDraw.floodfill(sub, (int(xs[0]), int(ys[0])), label)
            pm = np.asarray(sub) == label
            pieces.append(pm)
            label += 1
        keep = [pm for pm in pieces if np.nonzero(pm)[1].mean() > m.shape[1] * 0.48]
        print("run pieces", [(int(np.nonzero(pm)[1].mean()), int(pm.sum())) for pm in pieces])
        m = np.any(keep, axis=0)
    if name in ("walk", "run"):
        m = round_head(m)
    save(name, m)
