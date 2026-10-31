# Draws the top-down map of the test level (docs/level1_map.png) from the same rectangles the
# game builds it from (game/level/level.gd).  python3 draw_map.py <out.png>
import sys
from PIL import Image, ImageDraw, ImageFont

S = 17                      # pixels per metre
X0, X1, Z0, Z1 = -10, 46, -48, 10
W, H = (X1 - X0) * S, (Z1 - Z0) * S + 200
img = Image.new('RGB', (W, H), (247, 247, 244))
d = ImageDraw.Draw(img)
try:
    F = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
    FB = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 17)
except OSError:
    F = FB = ImageFont.load_default()


def px(x, z):
    return ((x - X0) * S, (z - Z0) * S)


def rect(x0, x1, z0, z1, fill, outline=None, width=1):
    a, b = px(x0, z0), px(x1, z1)
    d.rectangle([a, b], fill=fill, outline=outline, width=width)


FLOOR, WALL = (226, 228, 224), (70, 76, 80)
POOL, DEEP, MINERAL = (150, 205, 220), (95, 160, 190), (40, 85, 95)
PLAT, DARK = (252, 252, 250), (60, 64, 72)

rooms = [(0, 8, 0, 8), (-8, 16, -20, 0), (16, 24, -10, 0), (2, 4.5, -22, -20), (-8, 16, -46, -22), (16, 38, -46, -22), (38, 44, -40, -32)]
for r in rooms:
    rect(*r, FLOOR, WALL, 3)
rect(-8, 16, -46, -22, (205, 207, 212), WALL, 3)   # the dark sector, shaded
# Pools
rect(-6, 14, -18, -2, POOL)
rect(8, 10.5, -24, -18, POOL)
rect(-8, 16, -46, -24, (125, 175, 195))
rect(16, 38, -46, -22, DEEP)
rect(-8, -4.5, -40, -34, MINERAL)
# Platforms, beams, columns, ledges
plats = [(3, 6, -11, -8), (-6, -4.5, -4, -2),
         (2.65, 3.35, -30, -24), (1.5, 4.5, -33, -30), (-4.5, 1.5, -31.85, -31.15), (-8, -4.5, -34, -29),
         (2.65, 3.35, -38, -33), (2.55, 3.45, -39.95, -39.05), (2.55, 3.45, -41.45, -40.55), (3.45, 4.35, -43.05, -42.15),
         (5.2, 14, -46, -42), (14, 16, -46, -34), (16, 18, -40, -32), (36, 38, -40, -32)]
for x in [-4.9, -3.2, -1.5, 0.2, 1.9, 7.0, 8.7, 10.4, 12.1, 13.6]:
    plats.append((x - 0.4, x + 0.4, -9.9, -9.1))
for p in plats:
    rect(*p, PLAT, (120, 125, 128))
# Walkways in Hall A and the Hall B entrance strip
for w in [(-8, 16, -2, 0), (-8, 16, -20, -18), (-8, -6, -18, -2), (14, 16, -18, -2), (-8, 16, -24, -22)]:
    rect(*w, (236, 237, 233), (150, 155, 158))
# Pool cover (retracted until the lever is pulled)
a, b = px(18, -37.2), px(36, -34.8)
d.rectangle([a, b], outline=(40, 70, 130), width=2)
for i in range(18):
    q0, q1 = px(18 + i, -37.2), px(18.5 + i, -34.8)
    d.line([q0, q1], fill=(40, 70, 130), width=1)
# Doors
def door(x0, x1, z0, z1, color=(200, 120, 40)):
    rect(x0, x1, z0, z1, color)
door(3, 5, -0.15, 0.15); door(2, 4.5, -20.15, -19.85); door(2, 4.5, -22.15, -21.85)
door(15.85, 16.15, -6, -4, (190, 40, 40))           # locked staff door
door(15.85, 16.15, -37, -35); door(37.85, 38.15, -37, -35)
# Things
def dot(x, z, color, label, dx=8, dz=-8, r=6):
    c = px(x, z)
    d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=color, outline=(20, 20, 20))
    if label:
        d.text((c[0] + dx, c[1] + dz), label, fill=(20, 20, 20), font=F)
dot(4.5, -9.5, (230, 190, 50), 'Key')
dot(21, -2, (90, 110, 70), 'Canteens x2', -40, 10)
dot(23.15, -6.6, (40, 200, 190), 'Lidar', -50, -6)
dot(18.6, -9.1, (160, 160, 170), 'Distiller', 10, -2)
dot(10.5, -44.8, (200, 60, 40), 'Generator', -30, 10)
dot(17.0, -33.0, (200, 40, 40), 'Lever', 8, -20)
dot(8.0, -38.0, (120, 20, 20), 'Creature starts', 8, -6, 7)
for (x, z) in [(1, -1), (21, -1.7), (15, -36.5), (3, -23)]:
    dot(x, z, (60, 120, 70), '', r=4)
d.text(px(-6.2, -38.6), 'Mineral\nwater', fill=(240, 245, 245), font=F)
for (x, z) in [(-6, -14), (14, -14), (0, -18), (0, -24), (12, -24), (-6.25, -29), (10, -42), (4.5, -31.5), (18, -38.5), (36, -33.5)]:
    c = px(x, z)
    d.rectangle([c[0] - 4, c[1] - 4, c[0] + 4, c[1] + 4], fill=(30, 30, 30))
# Room names and route numbers
names = [(4, 6.6, '1  Start'), (-7.4, -1.6, '2  Hall A  (shallow, 1 m)'), (16.6, -4.6, '3  Staff'),
         (-7.4, -27.4, '4  Hall B, dark (1.5 m)'), (18.6, -45.4, '5  Hall C  (deep, 2.3 m)'), (38.4, -39.4, '6  Exit')]
for x, z, t in names:
    d.text(px(x, z), t, fill=(15, 15, 15), font=FB)
# Legend
ly = (Z1 - Z0) * S + 10
items = [(POOL, 'Shallow water'), ((125, 175, 195), 'Water (dark sector)'), (DEEP, 'Deep water'), (MINERAL, 'Mineral water'),
         (PLAT, 'Platforms and beams'), ((190, 40, 40), 'Locked door'), ((30, 30, 30), 'Ladder')]
for i, (c, t) in enumerate(items):
    x = 12 + (i % 3) * 310
    y = ly + (i // 3) * 26
    d.rectangle([x, y, x + 18, y + 18], fill=c, outline=(90, 90, 90))
    d.text((x + 26, y), t, fill=(20, 20, 20), font=F)
notes = ['Small green dots: bottles to throw as decoys.',
         'Striped: the pool cover. It extends from Hall C\'s west ledge to the exit ledge once the',
         'generator runs and the lever is pulled. Water channels under the walls let the creature',
         'swim everywhere. Scale: 17 px = 1 m. North is up.']
for i, t in enumerate(notes):
    d.text((12, ly + 84 + i * 22), t, fill=(40, 40, 40), font=F)
img.save(sys.argv[1])
print(img.size)
