# Move each joint to where the mesh actually bends: the centroid of vertices shared between a bone
# and its parent. Bones without a clear blend region follow a similarity fit of the rest.
# The mesh doesn't move (rest pose stays identity), so the bind becomes consistent.
# blender -b --python refit_joints.py -- in.glb out.glb
import bpy, sys
import numpy as np
from mathutils import Vector
a = sys.argv[sys.argv.index('--') + 1:]
src, dst = a
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.name.startswith('Icosphere'):
        bpy.data.objects.remove(o, do_unlink=True)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
inv = arm.matrix_world.inverted()
# Per-vertex weights by bone name, positions in armature space.
acc = {}   # bone -> [sum pos*w, sum w]
bones = arm.data.bones
skip_for_hand = {o.name for o in meshes if o.data.materials and o.data.materials[0] and 'glove' in o.data.materials[0].name.lower()}
for m in meshes:
    names = {g.index: g.name for g in m.vertex_groups}
    for v in m.data.vertices:
        w = {names[g.group]: g.weight for g in v.groups if g.weight > 0.02 and names[g.group] in bones}
        if len(w) < 2:
            continue
        p = inv @ (m.matrix_world @ v.co)
        for bn, wb in w.items():
            if m.name in skip_for_hand and bn.split(':')[-1].startswith(('LeftHand_', 'RightHand_')):
                continue
            par = bones[bn].parent
            if par and par.name in w:
                k = min(wb, w[par.name])
                s = acc.setdefault(bn, [Vector(), 0.0])
                s[0] += p * k
                s[1] += k
est = {bn: s[0] / s[1] for bn, s in acc.items() if s[1] > 1.5}
hips = next(b.name for b in bones if b.parent is None or 'Hips' in b.name and b.parent.name not in acc)
hips = next(b.name for b in bones if 'Hips' in b.name)
legs = [bn for bn in est if 'UpLeg' in bn]
spine = next(bn for bn in est if bn.endswith(('Spine_015',)) or bn.split(':')[-1].split('_')[0] == 'Spine')
if len(legs) == 2:
    mid = (est[legs[0]] + est[legs[1]]) * 0.5
    est[hips] = mid.lerp(est[spine], 0.5)
    print('HIPS', hips, tuple(round(x, 3) for x in est[hips]))
# Similarity fit (uniform scale + translation) from the confident joints.
B = np.array([list(bones[bn].head_local) for bn in est])
J = np.array([list(est[bn]) for bn in est])
bc, jc = B.mean(0), J.mean(0)
scale = np.sqrt(((J - jc) ** 2).sum() / ((B - bc) ** 2).sum())
print('FIT scale', round(float(scale), 3), 'from', len(est), 'joints')
def fit(p):
    return Vector(list((np.array(list(p)) - bc) * scale + jc))
for bn in sorted(est):
    if any(k in bn for k in ('Hips', 'Spine', 'Neck', 'Head', 'Arm', 'Hand_', 'Leg', 'Foot', 'Toe', 'Shoulder')):
        print('  J', bn, 'bone', tuple(round(x, 3) for x in bones[bn].head_local), '-> mesh', tuple(round(x, 3) for x in est[bn]), 'fit', tuple(round(x, 3) for x in fit(bones[bn].head_local)))
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
eb = arm.data.edit_bones
old = {b.name: (b.head.copy(), b.tail.copy()) for b in eb}
# Joints we trust: the main chain. Fingers and ends follow their parent hand rigidly (scaled).
trusted = {bn for bn in est if not any(k in bn for k in ('Thumb', 'Index', 'Middle', 'Ring', 'Pinky', '_end', 'End', 'Top'))}
new_head = {}
for b in eb:
    new_head[b.name] = est[b.name] if b.name in trusted else None
def resolve(b):
    if new_head[b.name] is not None:
        return new_head[b.name]
    if b.parent is None:
        new_head[b.name] = fit(old[b.name][0])
    else:
        ph = resolve(b.parent)
        new_head[b.name] = ph + (old[b.name][0] - old[b.parent.name][0]) * scale
    return new_head[b.name]
for b in eb:
    resolve(b)
for b in eb:
    h, t = old[b.name]
    b.use_connect = False
for b in eb:
    h, t = old[b.name]
    nh = new_head[b.name]
    kids = [c for c in b.children if c.name in trusted]
    if len(kids) == 1:
        nt = new_head[kids[0].name]
    else:
        nt = nh + (t - h) * scale
    if (nt - nh).length < 1e-4:
        nt = nh + (t - h) * scale
    b.head = nh
    b.tail = nt
bpy.ops.object.mode_set(mode='OBJECT')
# Fingers don't move in the game: fold their weights into the hand, so broken finger bones
# (some sit at the origin in this model) can't pull vertices away.
FINGERS = ('Thumb', 'Index', 'Middle', 'Ring', 'Pinky')
for m in meshes:
    for side in ('Left', 'Right'):
        hand = next((g for g in m.vertex_groups if g.name.split(':')[-1].startswith(side + 'Hand_')), None)
        fingers = [g for g in m.vertex_groups if g.name.split(':')[-1].startswith(side + 'Hand') and any(f in g.name for f in FINGERS)]
        if not fingers:
            continue
        if hand is None:
            hb = next(b.name for b in bones if b.name.split(':')[-1].startswith(side + 'Hand_'))
            hand = m.vertex_groups.new(name=hb)
        fidx = {g.index for g in fingers}
        moved = 0
        for v in m.data.vertices:
            w = sum(e.weight for e in v.groups if e.group in fidx)
            if w > 0:
                hand.add([v.index], w, 'ADD')
                moved += 1
        for g in fingers:
            m.vertex_groups.remove(g)
        print('FOLDED', m.name, side, moved)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', use_selection=True, export_animations=False,
                          export_skins=True, export_image_format='AUTO')
print('DONE')
