# Make pale, drowned-skin versions of the base color textures (keeps the reds of mouths and gums).
import sys
import numpy as np
from PIL import Image
pairs = [(sys.argv[i], sys.argv[i + 1]) for i in range(1, len(sys.argv), 2)]
stops = np.array([[0.00, 0.13, 0.12, 0.12], [0.50, 0.60, 0.59, 0.56], [1.00, 0.93, 0.91, 0.86]])
for src, dst in pairs:
    im = np.asarray(Image.open(src).convert('RGB')).astype(np.float32) / 255.0
    lum = im @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    lo, hi = np.percentile(lum, 2), np.percentile(lum, 98)
    t = np.clip((lum - lo) / max(hi - lo, 1e-3), 0, 1) ** 0.85
    pale = np.stack([np.interp(t, stops[:, 0], stops[:, c]) for c in (1, 2, 3)], axis=-1)
    red = np.clip((im[..., 0] - np.maximum(im[..., 1], im[..., 2]) - 0.08) / 0.17, 0, 1)[..., None]
    out = pale * (1 - red) + np.clip(im * np.array([1.1, 0.75, 0.75]), 0, 1) * red
    Image.fromarray((out * 255).astype(np.uint8)).save(dst)
    print(dst, im.shape)
