# Rig an unrigged character with the diver's skeleton (Mixamo bone names, which the game's suit
# code knows), so it can be worn as a suit.
#  1. The model is turned to face -Y, scaled to 1.72 m, feet on the ground, simplified for Quest.
#  2. The diver's skeleton is fitted to it: arms along the model's own arms (T-pose or A-pose),
#     legs from the hips to its feet.
#  3. The model is skinned to it with automatic weights; any vertex left without a weight (small or
#     open pieces like straps and glass) goes to its nearest bone.
#   blender -b --python rig_like_diver.py -- target.glb diver.glb out.glb [max_faces] [turn_degrees]
import bpy, bmesh, sys, re, math
from mathutils import Vector, Matrix

a = sys.argv[sys.argv.index('--') + 1:]
src, ref, dst = a[0], a[1], a[2]
MAX_FACES = int(a[3]) if len(a) > 3 else 25000
TURN = float(a[4]) if len(a) > 4 else 0.0
MAX_TEX = int(a[5]) if len(a) > 5 else 1024
H = 1.72

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
for o in list(bpy.data.objects):
    if o.type != 'MESH':
        bpy.data.objects.remove(o, do_unlink=True)
# Bake transforms into the meshes.
for o in meshes:
    mw = o.matrix_world.copy()
    o.parent = None
    o.data = o.data.copy()
    o.data.transform(mw)
    o.matrix_world = Matrix.Identity(4)
    if TURN:
        o.data.transform(Matrix.Rotation(math.radians(TURN), 4, 'Z'))


def bounds(objs):
    pts = [v.co for o in objs for v in o.data.vertices]
    return (Vector([min(p[i] for p in pts) for i in range(3)]), Vector([max(p[i] for p in pts) for i in range(3)]))


lo, hi = bounds(meshes)
k = H / (hi.z - lo.z)
m = Matrix.Scale(k, 4) @ Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)))
for o in meshes:
    o.data.transform(m)
# Simplify for the Quest, in proportion to each piece's size.
total = sum(len(o.data.polygons) for o in meshes)
if total > MAX_FACES:
    r = MAX_FACES / total
    for o in meshes:
        if len(o.data.polygons) > 300:
            mod = o.modifiers.new('dec', 'DECIMATE')
            mod.ratio = max(r, 0.08)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=mod.name)
print('faces', total, '->', sum(len(o.data.polygons) for o in meshes))
for img in bpy.data.images:
    if img.size[0] > MAX_TEX:
        img.scale(MAX_TEX, max(1, int(img.size[1] * MAX_TEX / img.size[0])))

# The diver's skeleton.
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=ref)
new = [o for o in bpy.data.objects if o not in before]
arm = next(o for o in new if o.type == 'ARMATURE')
for o in new:
    if o is not arm and o.type == 'MESH':
        bpy.data.objects.remove(o, do_unlink=True)
mw = arm.matrix_world.copy()          # keep it where it is when it leaves its parent node
arm.parent = None
arm.matrix_world = mw
for o in [o for o in bpy.data.objects if o not in before and o is not arm]:
    try:
        bpy.data.objects.remove(o, do_unlink=True)
    except ReferenceError:
        pass
bpy.context.view_layer.update()
# Print where the diver's hips and hands are, to check it lines up with the model.
for bn in arm.data.bones:
    if re.sub(r'_\d+$', '', re.sub(r'^mixamorig[:_]?', '', bn.name)) in ('Hips', 'Head', 'LeftHand', 'RightHand', 'LeftFoot'):
        print('ref bone', bn.name, tuple(round(x, 3) for x in (arm.matrix_world @ bn.head_local)))


def base(n):
    n = re.sub(r'^mixamorig[:_]?', '', n)
    return re.sub(r'_\d+$', '', n)


pts = [v.co for o in meshes for v in o.data.vertices]
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
eb = {base(b.name): b for b in arm.data.edit_bones}
AW = arm.matrix_world
AI = AW.inverted()


def W(p):          # armature space -> world
    return AW @ p


def A(p):          # world -> armature space
    return AI @ p


def set_chain(names, start, direction, total):
    """Lay bones `names` (each the parent of the next) along `direction` from `start`, keeping their
    length ratios, over `total` metres."""
    lens = [(W(eb[n].tail) - W(eb[n].head)).length for n in names]
    s = total / sum(lens)
    p = start
    for n, L in zip(names, lens):
        q = p + direction * L * s
        eb[n].head = A(p)
        eb[n].tail = A(q)
        p = q
    return p


for side, sgn in (('Left', 1), ('Right', -1)):
    # Which way is this side? The diver's own left hand tells us.
    ref_hand = W(eb[side + 'Hand'].head)
    s = 1 if ref_hand.x > 0 else -1
    shoulder = W(eb[side + 'Arm'].head)
    # The model's arm: everything well out from the body above the waist, on this side.
    arm_pts = [p for p in pts if p.x * s > abs(shoulder.x) + 0.08 and p.z > 0.55 * H]
    if len(arm_pts) > 30:
        far = max(arm_pts, key=lambda p: (p - shoulder).length)
        d = (far - shoulder).normalized()
        reach = (far - shoulder).length * 0.92
        end = set_chain([side + 'Arm', side + 'ForeArm', side + 'Hand'], shoulder, d, reach)
        # The fingers follow the hand.
        for b in arm.data.edit_bones:
            if base(b.name).startswith(side + 'Hand') and base(b.name) != side + 'Hand':
                off = b.tail - b.head
                b.head = A(end)
                b.tail = A(end) + off.normalized() * 0.03 + d * 0.0
    # The leg: from the hip to the lowest point of this side (the foot).
    hip = W(eb[side + 'UpLeg'].head)
    foot_pts = [p for p in pts if p.x * s > 0.02 and p.z < 0.12]
    if foot_pts:
        ankle = sum(foot_pts, Vector()) / len(foot_pts)
        ankle = Vector((ankle.x, ankle.y + 0.03, 0.08))
        set_chain([side + 'UpLeg', side + 'Leg'], hip, (ankle - hip).normalized(), (ankle - hip).length)
        eb[side + 'Foot'].head = A(ankle)
        toe = W(eb[side + 'Foot'].tail)
        eb[side + 'Foot'].tail = A(Vector((ankle.x, ankle.y - 0.12, 0.03)))
bpy.ops.object.mode_set(mode='OBJECT')

# Skin it: each vertex follows its nearest bone, blended between the two nearest near a joint.
# (Blender's automatic weights fail on models made of many separate pieces.) Fingers count as part
# of the hand.
deform = [b for b in arm.data.bones if b.use_deform]
segs = []
for b in deform:
    n = base(b.name)
    if re.search(r'Hand(Thumb|Index|Middle|Ring|Pinky)', n) or n.endswith('_end') or n.startswith('HeadTop'):
        continue
    h, t = W(b.head_local), W(b.tail_local)
    if n.endswith('Hand'):        # reach out over the fingers
        tips = [W(c.tail_local) for c in b.children_recursive]
        if tips:
            t = max(tips, key=lambda q: (q - h).length)
    segs.append((b.name, h, t))


def dists(p):
    out = []
    for n, h, t in segs:
        ht = t - h
        L2 = ht.length_squared or 1e-9
        u = max(0.0, min(1.0, (p - h).dot(ht) / L2))
        out.append(((p - (h + ht * u)).length, n))
    out.sort()
    return out


BLEND = 0.05
for o in meshes:
    for vg in list(o.vertex_groups):
        o.vertex_groups.remove(vg)
    for md in list(o.modifiers):
        if md.type == 'ARMATURE':
            o.modifiers.remove(md)
    groups = {}
    for v in o.data.vertices:
        ds = dists(o.matrix_world @ v.co)
        (d1, n1), (d2, n2) = ds[0], ds[1]
        t = max(0.0, min(1.0, (d2 - d1) / BLEND))
        w1 = 0.5 + 0.5 * t
        groups.setdefault(n1, []).append((v.index, w1))
        if w1 < 0.999:
            groups.setdefault(n2, []).append((v.index, 1.0 - w1))
    for n, items in groups.items():
        vg = o.vertex_groups.new(name=n)
        for idx, w in items:
            vg.add([idx], w, 'REPLACE')
    md = o.modifiers.new('Armature', 'ARMATURE')
    md.object = arm
    o.parent = arm
    o.matrix_parent_inverse = arm.matrix_world.inverted()
print('skinned', sum(len(o.data.vertices) for o in meshes), 'vertices to', len(segs), 'bones')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_skins=True, export_animations=False,
                          export_yup=True, use_selection=False)
print('rigged', src, '->', dst)
