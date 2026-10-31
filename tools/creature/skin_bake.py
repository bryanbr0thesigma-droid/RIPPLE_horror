# Realistic skin for the crawler: its own texture for the big shapes, photographed leather (real animal
# skin, Poly Haven CC0) for pores and wrinkles, plus color blotches, veins, and wet creases.
#   python3 skin_bake.py <rake textures dir> <leather dir> <out dir> <dark|pale> [tiles]
import sys

import numpy as np
from PIL import Image, ImageFilter

RAKE, LEATHER, OUT, TONE = sys.argv[1:5]
TILES = int(sys.argv[5]) if len(sys.argv) > 5 else 9
rng = np.random.default_rng(11)


def load(path, size, mode='RGB'):
    return np.asarray(Image.open(path).convert(mode).resize((size, size), Image.LANCZOS)).astype(np.float32) / 255


def tiled(path, size, mode='RGB'):
    tile = Image.open(path).convert(mode).resize((size // TILES, size // TILES), Image.LANCZOS)
    a = np.asarray(tile).astype(np.float32) / 255
    reps = (TILES + 1, TILES + 1) + ((1,) if a.ndim == 3 else ())
    return np.tile(a, reps)[:size, :size]


def blur(a, radius):
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(radius))).astype(np.float32) / 255


def noise_field(size, cells, seed):
    g = np.random.default_rng(seed).random((cells, cells))
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
    # Blur away the blocky cell edges that bicubic upscaling leaves.
    return np.asarray(img.filter(ImageFilter.GaussianBlur(size / cells / 2.5))).astype(np.float32) / 255


S = 2048
base = load(f'{RAKE}/lambert1_baseColor.jpeg', S)
lum = base @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
lo, hi = np.percentile(lum, 2), np.percentile(lum, 98)
shape = np.clip((lum - lo) / (hi - lo), 0, 1)                     # big forms and creases from the original paint

leather = tiled(f'{LEATHER}/brown_leather_albedo_2k.jpg', S)
ll = leather @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
detail = np.clip(ll / np.maximum(blur(ll, 6), 1e-3), 0.4, 1.8)     # pores and wrinkles only, no leather color
ao = tiled(f'{LEATHER}/brown_leather_ao_2k.jpg', S, 'L')

# Low-frequency blotches (bruised purple, grey-green, red) and a vein network.
b1, b2, b3 = noise_field(S, 10, 1), noise_field(S, 22, 2), noise_field(S, 40, 3)
veins = np.zeros((S, S), np.float32)
for cells, seed, width in ((14, 4, 0.02), (30, 5, 0.014)):
    f = noise_field(S, cells, seed) - 0.5
    veins = np.maximum(veins, np.clip(1 - np.abs(f) / width, 0, 1) ** 3 * (noise_field(S, cells // 2, seed + 10) > 0.45))
veins = blur(veins, 1.2)

if TONE == 'pale':
    crease, mid, high = np.array([0.30, 0.28, 0.29]), np.array([0.60, 0.58, 0.56]), np.array([0.80, 0.77, 0.73])
    vein_col, bruise, green, red = np.array([0.33, 0.32, 0.46]), np.array([0.50, 0.42, 0.52]), np.array([0.55, 0.58, 0.52]), np.array([0.66, 0.50, 0.48])
    vein_amt = 0.2
else:
    crease, mid, high = np.array([0.045, 0.040, 0.040]), np.array([0.19, 0.17, 0.16]), np.array([0.34, 0.31, 0.28])
    vein_col, bruise, green, red = np.array([0.09, 0.08, 0.12]), np.array([0.20, 0.15, 0.20]), np.array([0.17, 0.19, 0.16]), np.array([0.26, 0.15, 0.13])
    vein_amt = 0.15
t = shape[..., None]
col = np.where(t < 0.5, crease + (mid - crease) * (t * 2), mid + (high - mid) * ((t - 0.5) * 2))
col = col * (1 - 0.35 * np.clip(b1 - 0.5, 0, 1)[..., None] * 2) + bruise * 0.35 * np.clip(b1 - 0.5, 0, 1)[..., None] * 2
col = col * (1 - 0.3 * np.clip(b2 - 0.55, 0, 1)[..., None] * 2) + green * 0.3 * np.clip(b2 - 0.55, 0, 1)[..., None] * 2
col = col * (1 - 0.25 * np.clip(b3 - 0.6, 0, 1)[..., None] * 2.5) + red * 0.25 * np.clip(b3 - 0.6, 0, 1)[..., None] * 2.5
col = col * (1 - vein_amt * veins[..., None]) + vein_col * vein_amt * veins[..., None]
col = col * (0.55 + 0.45 * detail[..., None]) * (0.8 + 0.2 * ao[..., None])
Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save(f'{OUT}/skin_{TONE}_color.png')

# Roughness (glTF metallic-roughness: G = roughness, B = metallic): damp and shinier in creases, drier on top.
rough = tiled(f'{LEATHER}/brown_leather_rough_2k.jpg', S, 'L')
r = 0.5 + 0.35 * (rough - rough.mean()) - 0.18 * (1 - shape) + 0.08 * (b2 - 0.5)
r = np.clip(r, 0.22, 0.85)
mr = np.stack([np.zeros_like(r), r, np.zeros_like(r)], axis=-1)
Image.fromarray((mr * 255).astype(np.uint8)).save(f'{OUT}/skin_{TONE}_mr.png')

# Normals: the crawler's own normal map with the leather's pores and wrinkles blended on top.
NS = 4096
n1 = load(f'{RAKE}/lambert1_normal.png', NS) * 2 - 1
n2 = tiled(f'{LEATHER}/brown_leather_nor_gl_2k.jpg', NS) * 2 - 1
xy = n1[..., :2] + n2[..., :2] * 0.9
z = n1[..., 2:3] * n2[..., 2:3]
n = np.concatenate([xy, z], axis=-1)
n /= np.linalg.norm(n, axis=-1, keepdims=True)
Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save(f'{OUT}/skin_normal.png')
print('baked', TONE)
