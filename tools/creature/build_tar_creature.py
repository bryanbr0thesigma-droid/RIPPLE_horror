# The "tar" creature: the crawler's starved body in wet, glossy black, with a smooth eyeless head,
# a crooked slit of human teeth and sound pits. Run with:
#   blender -b --python build_tar.py -- <rake.gltf> <dark body texture> <out.glb> [head size] [mouth tilt deg]
import math
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index('--') + 1:]
RAKE, DARK_TEX, OUT = argv[:3]
HEAD_K = float(argv[3]) if len(argv) > 3 else 1.05
TILT = math.radians(float(argv[4]) if len(argv) > 4 else 14)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=RAKE)
rake_arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
rake_arm.data.pose_position = 'REST'
bpy.context.view_layer.update()
rake_body = next(o for o in bpy.data.objects if o.type == 'MESH' and o.data.name.startswith('body'))
bone_name = lambda prefix: next(b.name for b in rake_arm.data.bones if b.name.startswith(prefix))

# ---- Measure the crawler's head, then remove it.
grp = {g.index for g in rake_body.vertex_groups if g.name.startswith('head') or g.name.startswith('jaw')}
mw = rake_body.matrix_world
head_w = np.array([sum(g.weight for g in v.groups if g.group in grp) for v in rake_body.data.vertices])
pts = np.array([tuple(mw @ v.co) for v in rake_body.data.vertices])[head_w > 0.5]
head_min, head_max = Vector(pts.min(0)), Vector(pts.max(0))
head_h = head_max.y - head_min.y
neck_r = rake_arm.matrix_world @ rake_arm.data.bones[bone_name('head')].head_local
up, fwd, side = Vector((0, 1, 0)), Vector((0, 0, 1)), Vector((1, 0, 0))
bm = bmesh.new()
bm.from_mesh(rake_body.data)
bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[v for v in bm.verts if head_w[v.index] > 0.5], context='VERTS')
bm.to_mesh(rake_body.data)
bm.free()

# ---- The new head, built in world space.
r = 0.5 * head_h * HEAD_K
center = neck_r + up * r * 0.95 + fwd * r * 0.12
hb = bmesh.new()
slots = {'Skin': 0, 'Teeth': 1, 'Mouth': 2, 'Pit': 3}


def add(fn, slot):
    before = set(hb.faces)
    fn()
    for f in hb.faces:
        if f not in before:
            f.material_index = slot


def rot_to(z_dir):
    return Vector((0, 0, 1)).rotation_difference(Vector(z_dir)).to_matrix().to_4x4()


# A smooth skull, a little taller than wide, slightly flattened at the face. No eyes, no nose.
skull = Matrix.Translation(center) @ Matrix.Diagonal((0.86, 1.12, 0.98, 1.0))
add(lambda: bmesh.ops.create_uvsphere(hb, u_segments=40, v_segments=28, radius=r, matrix=skull), slots['Skin'])

# The mouth: a dark slit low on the face, tilted, with two rows of blunt human teeth along its edges.
mouth_c = center + fwd * r * 0.74 - up * r * 0.4
tilt = Matrix.Rotation(TILT, 4, fwd)
slit = Matrix.Translation(mouth_c) @ tilt @ Matrix.Diagonal((r * 0.52, r * 0.18, r * 0.3, 1.0))
add(lambda: bmesh.ops.create_uvsphere(hb, u_segments=24, v_segments=12, radius=1.0, matrix=slit), slots['Mouth'])
n_teeth = 12
for row, sign in (('upper', 1), ('lower', -1)):
    for i in range(n_teeth):
        t = (i / (n_teeth - 1)) * 2 - 1
        x = t * r * 0.48
        y = sign * r * 0.14 * (1 - 0.4 * t * t)
        length = r * (0.14 if abs(t) < 0.5 else 0.1)
        local = Vector((x, y, r * 0.2))
        base = mouth_c + (tilt @ local)
        point = tilt @ Vector((0, -sign, 0.15)).normalized()
        m = Matrix.Translation(base + point * length / 2) @ rot_to(point)
        add(lambda m=m, length=length: bmesh.ops.create_cone(hb, segments=8, radius1=r * 0.028, radius2=r * 0.012, depth=length, matrix=m, cap_ends=True), slots['Teeth'])

# Sound pits: a few small dimples along each side of the skull.
for sx in (-1, 1):
    for j, (a, b) in enumerate(((0.15, 0.35), (-0.1, 0.45), (-0.35, 0.3), (0.0, 0.1), (-0.25, 0.05))):
        n = (side * sx * 0.9 + fwd * a + up * b).normalized()
        p = center + Vector((n.x * 0.86, n.y * 1.12, n.z * 0.98)) * r
        m = Matrix.Translation(p) @ rot_to(n) @ Matrix.Diagonal((1.0, 1.25, 0.35, 1.0))
        add(lambda m=m: bmesh.ops.create_uvsphere(hb, u_segments=10, v_segments=6, radius=r * 0.055, matrix=m), slots['Pit'])

from mathutils import noise
for v in hb.verts:
    f = hb.faces[0] if False else None
skin_verts = {v for f in hb.faces if f.material_index == slots['Skin'] for v in f.verts}
for v in skin_verts:
    d = v.co - center
    n = Vector((d.x / 0.86, d.y / 1.12, d.z / 0.98)).normalized()
    lump = noise.noise(n * 2.2) * 0.07 + noise.noise(n * 6.0) * 0.025
    sag = max(0.0, -n.y) ** 2 * 0.35            # the lower half narrows into the neck
    back = max(0.0, -n.z) * 0.12                 # a slightly longer back of the skull
    v.co = center + Vector((d.x * (1 - sag), d.y, d.z * (1 - sag * 0.6))) * (1 + lump) - fwd * back * r * max(0.0, n.y + 0.3)
head_mesh = bpy.data.meshes.new('TarHead')
hb.to_mesh(head_mesh)
hb.free()
for poly in head_mesh.polygons:
    poly.use_smooth = True
head = bpy.data.objects.new('TarHead', head_mesh)
bpy.context.collection.objects.link(head)


def mat(name, color, rough, spec=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Specular IOR Level'].default_value = spec
    if name == 'TarSkin':
        b.inputs['Coat Weight'].default_value = 1.0
        b.inputs['Coat Roughness'].default_value = 0.05
    return m


for m in (mat('TarSkin', (0.008, 0.009, 0.010), 0.12, 0.8), mat('Teeth', (0.72, 0.66, 0.54), 0.4),
          mat('Mouth', (0.0, 0.0, 0.0), 1.0, 0.0), mat('Pit', (0.0, 0.0, 0.0), 0.9)):
    head.data.materials.append(m)

# ---- Bind the head to the head bone, the way the body is bound.
head.data.transform(rake_body.matrix_world.inverted())
head.parent = rake_arm
head.matrix_parent_inverse = rake_body.matrix_parent_inverse.copy()
head.matrix_basis = rake_body.matrix_basis.copy()
vg = head.vertex_groups.new(name=bone_name('head'))
vg.add(range(len(head.data.vertices)), 1.0, 'REPLACE')
head.modifiers.new('Armature', 'ARMATURE').object = rake_arm

# ---- Wet, glossy black skin on the body: a darkened texture keeps its detail, and low roughness makes it shine.
for m in rake_body.data.materials:
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    for n in nt.nodes:
        if n.type == 'TEX_IMAGE' and 'baseColor' in n.image.name:
            n.image = bpy.data.images.load(DARK_TEX)
    for link in list(nt.links):
        if link.to_node == bsdf and link.to_socket.name in ('Roughness', 'Metallic'):
            nt.links.remove(link)
    bsdf.inputs['Roughness'].default_value = 0.14
    bsdf.inputs['Metallic'].default_value = 0.0
    bsdf.inputs['Specular IOR Level'].default_value = 0.8
    bsdf.inputs['Coat Weight'].default_value = 1.0
    bsdf.inputs['Coat Roughness'].default_value = 0.05

# ---- Clean up and export.
for o in list(bpy.data.objects):
    if o not in (rake_arm, rake_body, head) and o.type == 'MESH':
        bpy.data.objects.remove(o, do_unlink=True)
rake_arm.data.pose_position = 'POSE'
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_skins=True, export_morph=False, export_yup=True)
print('TARDONE head radius', round(r, 4))
