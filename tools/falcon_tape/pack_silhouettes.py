# Crops each rendered silhouette sequence to the area it moves in and packs it into one
# grayscale strip: silhouettes/<name>.png (frames side by side) and silhouettes/index.json.
#   python3 pack_silhouettes.py <rendered_frames_dir>
import glob, json, os, sys
import numpy as np
from PIL import Image

SRC = sys.argv[1]
SEQS = {"side_idle": 12, "search": 12, "screech": 12}
SCALE = 0.5
index = {}
for name, fps in SEQS.items():
    frames = [np.asarray(Image.open(p).convert("L")) for p in sorted(glob.glob(f"{SRC}/{name}_[0-9]*.png"))]
    m = np.max(frames, axis=0) > 0
    ys, xs = np.nonzero(m)
    y0, y1, x0, x1 = max(ys.min() - 4, 0), ys.max() + 5, max(xs.min() - 4, 0), xs.max() + 5
    w, h = int((x1 - x0) * SCALE), int((y1 - y0) * SCALE)
    strip = Image.new("L", (w * len(frames), h))
    for i, f in enumerate(frames):
        strip.paste(Image.fromarray(f[y0:y1, x0:x1]).resize((w, h), Image.LANCZOS), (i * w, 0))
    strip.save(f"silhouettes/{name}.png", optimize=True)
    index[name] = {"frames": len(frames), "w": w, "h": h, "fps": fps}
    print(name, len(frames), w, h)
json.dump(index, open("silhouettes/index.json", "w"), indent=1)
