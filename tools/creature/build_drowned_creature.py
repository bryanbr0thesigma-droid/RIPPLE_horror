# The "drowned" creature: the crawler with its own near-human head, matte waterlogged skin, and eyes
# either sealed over with skin or left as empty holes. The unhinged jaw is posed in the game (and in
# the preview renderer) by opening and stretching the jaw bone. Run with:
#   blender -b --python build_drowned_creature.py -- <rake.gltf> <skin texture> <out.glb> <sealed|hollow> [normal map] [metallic-roughness map] [mouths]
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index('--') + 1:]
RAKE, SKIN_TEX, OUT, EYES = argv[:4]
NORMAL_TEX = argv[4] if len(argv) > 4 else None
MR_TEX = argv[5] if len(argv) > 5 else None
MOUTHS = argv[6] == 'mouths' if len(argv) > 6 else False

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
        elif n.type == 'TEX_IMAGE' and 'normal' in n.image.name and NORMAL_TEX:
            img = bpy.data.images.load(NORMAL_TEX)
            img.colorspace_settings.name = 'Non-Color'
            n.image = img
        elif n.type == 'TEX_IMAGE' and 'metallicRoughness' in n.image.name and MR_TEX:
            img = bpy.data.images.load(MR_TEX)
            img.colorspace_settings.name = 'Non-Color'
            n.image = img
    if not MR_TEX:
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

# ---- A few decorative mouths on the body: toothy slits sunk into the skin, each riding on one bone.
if MOUTHS:
    import math
    from mathutils import noise
    nm = rake_body.matrix_world.to_3x3()
    body_mw = rake_body.matrix_world
    groups = {g.index: g.name for g in rake_body.vertex_groups}
    head_pts = [body_mw @ v.co for v in rake_body.data.vertices if any(groups[g.group].startswith('head') and g.weight > 0.5 for g in v.groups)]
    scale = (max(p.y for p in head_pts) - min(p.y for p in head_pts))

    def spot(bone_prefix, want):
        # Some of this model's normals point inward, so judge "outward" from the middle of the bone's own vertices.
        want = Vector(want).normalized()
        cand = []
        for v in rake_body.data.vertices:
            w = sum(g.weight for g in v.groups if groups[g.group].startswith(bone_prefix))
            if w >= 0.6:
                cand.append(body_mw @ v.co)
        if not cand:
            return None
        mid = sum(cand, Vector()) / len(cand)
        best, best_score = None, -9
        for v in rake_body.data.vertices:
            w = sum(g.weight for g in v.groups if groups[g.group].startswith(bone_prefix))
            if w < 0.6:
                continue
            p = body_mw @ v.co
            out = (p - mid).normalized()
            n = (nm @ v.normal).normalized()
            if n.dot(out) < 0:
                n = -n                       # flip the inward-pointing normals
            # Prefer spots facing the wanted way where the skin itself faces outward (not edges or tips).
            score = out.dot(want) + n.dot(want) + 0.5 * n.dot(out)
            if score > best_score:
                best, best_score = (p, n), score
        return best

    def lip_mat(name, color, rough):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = m.node_tree.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = (*color, 1)
        b.inputs['Roughness'].default_value = rough
        return m

    mats = [lip_mat('MouthLips', (0.075, 0.035, 0.033), 0.3), lip_mat('MouthInside', (0.0, 0.0, 0.0), 1.0),
            lip_mat('MouthTeeth', (0.58, 0.5, 0.36), 0.45)]
    # (bone, outward direction, size relative to the head's height, tilt)
    places = [('spine.005', (0, -0.2, 1), 1.0, 0.25), ('spine.003', (1, 0, 0.35), 1.05, -0.6),
              ('upper_arm.R', (0, 1, 0.3), 0.8, 1.2), ('spine.002', (-0.4, 0.2, -1), 1.1, 0.15)]
    for bone_prefix, want, size, tilt in places:
        found = spot(bone_prefix, want)
        if not found:
            continue
        p, n = found
        w = scale * size
        bm = bmesh.new()
        frame = Matrix.Translation(p - n * w * 0.02) @ Vector((0, 0, 1)).rotation_difference(n).to_matrix().to_4x4() @ Matrix.Rotation(tilt, 4, 'Z')

        def part(fn, slot):
            before = set(bm.faces)
            fn()
            for f in bm.faces:
                if f not in before:
                    f.material_index = slot

        # No lips: just a black slit sunk into the skin with blunt rows of teeth, so it looks grown in, not stuck on.
        part(lambda: bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=1.0, matrix=frame @ Matrix.Translation((0, 0, -w * 0.035)) @ Matrix.Diagonal((w * 0.42, w * 0.1, w * 0.06, 1))), 1)
        for row, sign in ((0, 1), (1, -1)):
            for i in range(7):
                t = i / 6 * 2 - 1
                base = Vector((t * w * 0.3, sign * w * 0.075 * (1 - 0.35 * t * t), -w * 0.005))
                length = w * (0.05 + 0.02 * abs(noise.noise(Vector((t * 3, row, size)))))
                d = Vector((0, -sign, 0.2)).normalized()
                m = frame @ Matrix.Translation(base + d * length / 2) @ Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
                part(lambda m=m, length=length: bmesh.ops.create_cone(bm, segments=6, radius1=w * 0.022, radius2=w * 0.012, depth=length, matrix=m, cap_ends=True), 2)
        mesh = bpy.data.meshes.new('Mouth')
        bm.to_mesh(mesh)
        bm.free()
        for poly in mesh.polygons:
            poly.use_smooth = True
        mo = bpy.data.objects.new('Mouth_' + bone_prefix, mesh)
        bpy.context.collection.objects.link(mo)
        for m in mats:
            mo.data.materials.append(m)
        mo.data.transform(rake_body.matrix_world.inverted())
        mo.parent = rake_arm
        mo.matrix_parent_inverse = rake_body.matrix_parent_inverse.copy()
        mo.matrix_basis = rake_body.matrix_basis.copy()
        bone = next(b.name for b in rake_arm.data.bones if b.name.startswith(bone_prefix))
        vg = mo.vertex_groups.new(name=bone)
        vg.add(range(len(mo.data.vertices)), 1.0, 'REPLACE')
        mo.modifiers.new('Armature', 'ARMATURE').object = rake_arm
        print('MOUTH', bone_prefix, tuple(round(x, 3) for x in p))

rake_arm.data.pose_position = 'POSE'
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_skins=True, export_morph=False, export_yup=True)
print('DROWNEDDONE', EYES, [(tuple(round(x, 3) for x in c), round(r, 4)) for c, r in balls])
