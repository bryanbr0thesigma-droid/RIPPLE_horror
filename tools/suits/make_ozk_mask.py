# Camo mask for the OZK suit: the camo cloth is saturated (greens/browns), the rubber parts are grey.
import sys
import numpy as np
from PIL import Image, ImageFilter
src, dst = sys.argv[1], sys.argv[2]
im = np.asarray(Image.open(src).convert('RGB').resize((512, 512), Image.LANCZOS)).astype(np.float32) / 255.0
mx, mn = im.max(2), im.min(2)
sat = (mx - mn) / np.maximum(mx, 1e-3)
# Local average of saturation, so the dark camo blotches inside the cloth stay masked.
s = Image.fromarray((sat * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))
s = np.asarray(s).astype(np.float32) / 255.0
m = np.clip((s - 0.12) / 0.12, 0, 1)
Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5)).save(dst)
print('mask mean', m.mean())
