# The "drowned" creature: the crawler with its own near-human head, matte waterlogged skin, and eyes
# either sealed over with skin or left as empty holes. The unhinged jaw is posed in the game (and in
# the preview renderer) by opening and stretching the jaw bone. Run with:
#   blender -b --python build_drowned.py -- <rake.gltf> <skin texture> <out.glb> <sealed|hollow>
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index('--') + 1:]
RAKE, SKIN_TEX, OUT, EYES = argv[:4]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=RAKE)
rake_arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
rake_arm.data.pose_position = 'REST'
bpy.context.view_layer.update()
rake_body = next(o for o in bpy.data.objects if o.type == 'MESH' and o.data.name.startswith('body'))
eyes = next(o for o in bpy.data.objects if o.type == 'MESH' and o.data.name.startswith('eyes'))
head_bone = next(b.name for b in rake_arm.data.bones if b.name.startswith('head'))

# ---- Find the two eyeballs, then remove them.
pts = np.array([tuple(eyes.matrix_world @ v.co) for v in eyes.data.vertices])
balls = []
for side in (pts[:, 0] > 0, pts[:, 0] <= 0):
    p = pts[side]
    balls.append((Vector(p.mean(0)), float((p.max(0) - p.min(0)).max()) / 2))
bpy.data.objects.remove(eyes, do_unlink=True)

# ---- Fill the sockets: skin stretched over them, or empty black holes sunk a little deeper.
mesh = bpy.data.meshes.new('Sockets')
import bmesh
bm = bmesh.new()
fwd = Vector((0, 0, 1))
for c, rad in balls:
    if EYES == 'sealed':
        m = Matrix.Translation(c - fwd * rad * 0.55) @ Matrix.Diagonal((1.15, 0.85, 0.45, 1.0))
        bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=14, radius=rad * 1.1, matrix=m)
    else:
        m = Matrix.Translation(c - fwd * rad * 0.35)
        bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=14, radius=rad * 1.2, matrix=m)
bm.to_mesh(mesh)
bm.free()
for poly in mesh.polygons:
    poly.use_smooth = True
sockets = bpy.data.objects.new('Sockets', mesh)
bpy.context.collection.objects.link(sockets)
sm = bpy.data.materials.new('Socket')
sm.use_nodes = True
b = sm.node_tree.nodes['Principled BSDF']
b.inputs['Base Color'].default_value = (0.055, 0.05, 0.045, 1) if EYES == 'sealed' else (0.0, 0.0, 0.0, 1)
b.inputs['Roughness'].default_value = 0.5 if EYES == 'sealed' else 1.0
b.inputs['Specular IOR Level'].default_value = 0.4 if EYES == 'sealed' else 0.0
sockets.data.materials.append(sm)
sockets.data.transform(rake_body.matrix_world.inverted())
sockets.parent = rake_arm
sockets.matrix_parent_inverse = rake_body.matrix_parent_inverse.copy()
sockets.matrix_basis = rake_body.matrix_basis.copy()
vg = sockets.vertex_groups.new(name=head_bone)
vg.add(range(len(sockets.data.vertices)), 1.0, 'REPLACE')
sockets.modifiers.new('Armature', 'ARMATURE').object = rake_arm

# ---- Matte, waterlogged skin.
for m in rake_body.data.materials:
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    for n in nt.nodes:
        if n.type == 'TEX_IMAGE' and 'baseColor' in n.image.name:
            n.image = bpy.data.images.load(SKIN_TEX)
    for link in list(nt.links):
        if link.to_node == bsdf and link.to_socket.name in ('Roughness', 'Metallic'):
            nt.links.remove(link)
    bsdf.inputs['Roughness'].default_value = 0.55
    bsdf.inputs['Metallic'].default_value = 0.0
    bsdf.inputs['Specular IOR Level'].default_value = 0.35

# Yellowed teeth.
for o in bpy.data.objects:
    if o.type == 'MESH' and 'teeth' in o.data.name:
        for m in o.data.materials:
            bsdf = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if bsdf:
                for link in list(m.node_tree.links):
                    if link.to_node == bsdf and link.to_socket.name == 'Base Color':
                        m.node_tree.links.remove(link)
                bsdf.inputs['Base Color'].default_value = (0.55, 0.48, 0.34, 1)
                bsdf.inputs['Roughness'].default_value = 0.45

rake_arm.data.pose_position = 'POSE'
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_skins=True, export_morph=False, export_yup=True)
print('DROWNEDDONE', EYES, [(tuple(round(x, 3) for x in c), round(r, 4)) for c, r in balls])
