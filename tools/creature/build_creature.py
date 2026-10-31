# Build the RIPPLE creature: the crawler's body and limbs with the predator's head and tail.
# The predator parts (head with blind eyes, needle teeth and sound pits, and the tail) come ready-made as
# parts.obj + parts.json, cut from the predator's rest pose. Run with:
#   blender -b --python mix_build.py -- <rake.gltf> <parts.obj> <parts.json> <tex dir> <out.glb> [head scale] [tail scale]
import json
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index('--') + 1:]
RAKE, PARTS, META, TEX, OUT = argv[:5]
HEAD_K = float(argv[5]) if len(argv) > 5 else 1.6
TAIL_K = float(argv[6]) if len(argv) > 6 else 0.9
TRIM = float(argv[7]) if len(argv) > 7 else 0.2
meta = json.load(open(META))

bpy.ops.wm.read_factory_settings(use_empty=True)
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=RAKE)
rake = [o for o in bpy.data.objects if o not in before]
rake_arm = next(o for o in rake if o.type == 'ARMATURE')
rake_arm.data.pose_position = 'REST'
bpy.context.view_layer.update()
rake_body = next(o for o in rake if o.type == 'MESH' and o.data.name.startswith('body'))

# The parts are in the same axes as the crawler here (up +Y, front +Z), so import them without converting axes.
before = set(bpy.data.objects)
bpy.ops.wm.obj_import(filepath=PARTS, forward_axis='Y', up_axis='Z')
parts = [o for o in bpy.data.objects if o not in before]


def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


head_parts = [o for o in parts if not o.name.startswith('PredTail')]
tail_parts = [o for o in parts if o.name.startswith('PredTail')]
head_obj = join(head_parts, 'CreatureHead')
tail_obj = join(tail_parts, 'CreatureTail')
for o in (head_obj, tail_obj):
    o.data.transform(o.matrix_world)
    o.matrix_world = Matrix.Identity(4)

# Trim the thick base off the tail so it suits the crawler's narrow hips, then close the cut and use its center as the attach point.
tz = max(v.co.z for v in tail_obj.data.vertices)
tlen = tz - min(v.co.z for v in tail_obj.data.vertices)
bm = bmesh.new()
bm.from_mesh(tail_obj.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=tlen * 0.002)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > tz - TRIM * tlen], context='VERTS')
cut_z = tz - TRIM * tlen
open_edges = [e for e in bm.edges if e.is_boundary and all(v.co.z > cut_z - 0.12 * tlen for v in e.verts)]
rim = {v for e in open_edges for v in e.verts}
tail_base = sum((v.co for v in rim), Vector()) / max(1, len(rim))
bmesh.ops.holes_fill(bm, edges=open_edges, sides=0)
bm.to_mesh(tail_obj.data)
bm.free()

# ---- The crawler's head: measure it, then remove it.
bone_name = lambda prefix: next(b.name for b in rake_arm.data.bones if b.name.startswith(prefix))
grp = {g.index for g in rake_body.vertex_groups if g.name.startswith('head') or g.name.startswith('jaw')}
mw = rake_body.matrix_world
head_w = np.array([sum(g.weight for g in v.groups if g.group in grp) for v in rake_body.data.vertices])
pts = np.array([tuple(mw @ v.co) for v in rake_body.data.vertices])[head_w > 0.5]
rake_head_size = float(np.linalg.norm(pts.max(0) - pts.min(0)))
neck_r = rake_arm.matrix_world @ rake_arm.data.bones[bone_name('head')].head_local
hips_r = rake_arm.matrix_world @ rake_arm.data.bones[bone_name('spine_')].head_local
up_r, fwd_r = Vector((0, 1, 0)), Vector((0, 0, 1))
bm = bmesh.new()
bm.from_mesh(rake_body.data)
bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[v for v in bm.verts if head_w[v.index] > 0.5], context='VERTS')
bm.to_mesh(rake_body.data)
bm.free()

# ---- Head onto the neck.
s_head = HEAD_K * rake_head_size / meta['headSize']
head_obj.data.transform(Matrix.Translation(neck_r - fwd_r * rake_head_size * 0.08) @ Matrix.Scale(s_head, 4) @ Matrix.Translation(-Vector(meta['back'])))

# ---- Tail onto the hips. The crawler stands in its rest pose and pitches forward to crawl,
# so a tail hanging down and slightly back here trails behind it when it crawls.
base, tip = tail_base, Vector(meta['tailTip'])
rot = (tip - base).normalized().rotation_difference((-up_r - fwd_r * 1.0).normalized()).to_matrix().to_4x4()
tail_obj.data.transform(Matrix.Translation(hips_r - fwd_r * rake_head_size * 0.12) @ rot @ Matrix.Scale(TAIL_K * s_head, 4) @ Matrix.Translation(-base))

# ---- Bind both to the crawler's skeleton, the same way its body is bound.
for obj, bone in ((head_obj, bone_name('head')), (tail_obj, bone_name('spine_'))):
    obj.data.transform(rake_body.matrix_world.inverted())
    obj.parent = rake_arm
    obj.matrix_parent_inverse = rake_body.matrix_parent_inverse.copy()
    obj.matrix_basis = rake_body.matrix_basis.copy()
    vg = obj.vertex_groups.new(name=bone)
    vg.add(range(len(obj.data.vertices)), 1.0, 'REPLACE')
    obj.modifiers.new('Armature', 'ARMATURE').object = rake_arm

# ---- Pale skin on the crawler's body too.
for m in rake_body.data.materials:
    for n in m.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and 'baseColor' in n.image.name:
            n.image = bpy.data.images.load(f'{TEX}/rake_body_pale.png')

# ---- Clean up and export.
for o in list(bpy.data.objects):
    if o not in (rake_arm, rake_body, head_obj, tail_obj) and (o.type == 'MESH' or o not in rake):
        bpy.data.objects.remove(o, do_unlink=True)
rake_arm.data.pose_position = 'POSE'
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_skins=True, export_morph=False, export_yup=True)
print('MIXDONE head scale', round(s_head, 6), 'rake head size', round(rake_head_size, 4))
