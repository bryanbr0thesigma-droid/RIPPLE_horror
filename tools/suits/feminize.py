# A female version of a suit: the same approved model, reshaped. Every vertex of every mesh is moved
# by one smooth field worked out from the skeleton (so the garment, its trims and vest all move
# together and the skinning still works): a bigger chest, a narrower waist, wider hips, a fuller
# rear and thicker thighs, all deliberately exaggerated. Textures, materials and the
# head / upper / lower split are kept.
#   blender -b --python feminize.py -- in.glb out.glb [strength]
import bpy, sys, re, math
from mathutils import Vector

a = sys.argv[sys.argv.index('--') + 1:]
src, dst = a[0], a[1]
K = float(a[2]) if len(a) > 2 else 1.0
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.name.startswith('Icosphere'):
        bpy.data.objects.remove(o, do_unlink=True)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')


def bone(name):
    for b in arm.data.bones:
        n = re.sub(r'^mixamorig[:_]?', '', b.name)
        n = re.sub(r'_\d+$', '', n)
        if n == name:
            return arm.matrix_world @ b.head_local
    raise KeyError(name)


hips, spine, spine2, neck = bone('Hips'), bone('Spine'), bone('Spine2'), bone('Neck')
lu, ru, ll, rl = bone('LeftUpLeg'), bone('RightUpLeg'), bone('LeftLeg'), bone('RightLeg')
lf, lt = bone('LeftFoot'), bone('LeftToeBase')
up = (neck - hips).normalized()
right = (ru - lu)
right = (right - up * right.dot(up)).normalized()
fwd = up.cross(right)
toe = lt - lf
if (toe - up * toe.dot(up)).dot(fwd) < 0:       # the toes point forward
    fwd = -fwd
T = (neck - hips).length
k = T / 0.5                                      # sizes below are for a 0.5 m hips-to-neck torso


def gauss(d2, r):
    return math.exp(-d2 / (r * r))


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


h_chest = (spine2 - hips).dot(up) - 0.03 * k
h_waist = (spine - hips).dot(up) + 0.02 * k


def field(p):
    d = p - hips
    h, x, z = d.dot(up), d.dot(right), d.dot(fwd)
    out = Vector((0, 0, 0))
    # Chest: two rounded bulges on the front, lifted a little.
    front = smooth(-0.02 * k, 0.07 * k, z)
    for s in (-1, 1):
        w = gauss((x - s * 0.088 * k) ** 2 + (h - h_chest) ** 2, 0.095 * k) * front
        out += fwd * (0.085 * k * w) + up * (0.015 * k * w) + right * (s * 0.012 * k * w)
    # Waist: pulled in.
    w = gauss((h - h_waist) ** 2, 0.075 * k)
    out += -right * (x * 0.16 * w) - fwd * (z * 0.06 * w)
    # Hips: wider.
    w = gauss((h + 0.03 * k) ** 2, 0.1 * k)
    out += right * (x * 0.24 * w)
    # Rear: two rounded bulges on the back, below the hips.
    back = smooth(0.02 * k, -0.07 * k, z)
    for s in (-1, 1):
        w = gauss((x - s * 0.075 * k) ** 2 + (h + 0.1 * k) ** 2, 0.1 * k) * back
        out += -fwd * (0.075 * k * w) + right * (s * 0.012 * k * w)
    # Thighs: fuller, most at the top, tapering to the knee.
    for top, knee, s in ((lu, ll, -1), (ru, rl, 1)):
        axis = knee - top
        L = axis.length
        t = (p - top).dot(axis) / (L * L)
        if -0.15 < t < 1.05 and s * x > -0.02 * k:
            c = top + axis * t
            rv = p - c
            rv = rv - axis.normalized() * rv.dot(axis.normalized())
            f = gauss((t - 0.25) ** 2, 0.38) * smooth(-0.15, 0.05, t)
            out += rv * (0.3 * f)
    # Shoulders: a touch narrower.
    w = smooth(h_chest + 0.05 * k, h_chest + 0.15 * k, h) * (1 - smooth(T - 0.02 * k, T + 0.1 * k, h))
    out += -right * (x * 0.07 * w)
    return out * K


ARM = re.compile(r'(Shoulder|Arm|ForeArm|Hand|Thumb|Index|Middle|Ring|Pinky)', re.I)
# The arm bones: anything named like one, and everything below a shoulder (finger bones are not
# always named the Mixamo way, e.g. "pointer4.R").
arm_bones = set()
for b in arm.data.bones:
    chain = [b] + list(b.parent_recursive)
    if any(re.search(r'Shoulder', c.name, re.I) for c in chain) or ARM.search(re.sub(r'^mixamorig[:_]?', '', b.name)):
        arm_bones.add(b.name)
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
for o in meshes:
    mw = o.matrix_world
    inv = mw.inverted().to_3x3()
    arm_groups = {g.index for g in o.vertex_groups if g.name in arm_bones}
    for v in o.data.vertices:
        # The arms and hands keep their shape (in the rest pose they can hang beside the hips).
        aw = sum(g.weight for g in v.groups if g.group in arm_groups)
        tw = sum(g.weight for g in v.groups) or 1.0
        keep = 1.0 - min(1.0, max(0.0, (aw / tw - 0.03) / 0.12))   # any real arm weight: left alone
        if keep <= 0.0:
            continue
        pw = mw @ v.co
        v.co += inv @ (field(pw) * keep)
    # The imported normals were baked in; let them follow the new shape.
    if o.data.has_custom_normals:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
        o.select_set(False)
    for poly in o.data.polygons:
        poly.use_smooth = True

bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_skins=True, export_animations=False,
                          export_yup=True, use_selection=False)
print('feminized', src, '->', dst, 'torso', round(T, 3), 'strength', K)
