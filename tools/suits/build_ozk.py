# Rebuild the OZK suit from the author's source FBX: wire the hands and feet to the real arm and leg
# bones (in the source they hang off IK control bones), drop the control bones, give the bones
# Mixamo-style names, stand it 1.72 m tall with feet at 0, small textures, export GLB.
# blender -b --python build_ozk.py -- ozk_low.fbx textures_dir out.glb
import bpy, sys, os
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index('--') + 1:]
src, texdir, dst = a
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src, automatic_bone_orientation=True)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
meshes = [o for o in bpy.data.objects if o.type == 'MESH']

# 1. Reparent hands and feet, remove IK bones (move their weights to the nearest real bone first).
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
eb = arm.data.edit_bones
for s in ('L', 'R'):
    eb['wrist.' + s].parent = eb['arm3.' + s]
    eb['leg3.' + s].parent = eb['leg2.' + s]
ik = [b.name for b in eb if '_ik' in b.name or 'pole' in b.name.lower() or 'target' in b.name.lower()]
print('IK BONES', ik)
# Children of IK bones that aren't IK themselves: reparent to the IK bone's nearest real ancestor.
for b in eb:
    if b.name not in ik and b.parent and b.parent.name in ik:
        p = b.parent
        while p and p.name in ik:
            p = p.parent
        print('REPARENT', b.name, '->', p.name if p else None)
        b.parent = p
bpy.ops.object.mode_set(mode='OBJECT')
# Weights on IK bones?
for m in meshes:
    for g in m.vertex_groups:
        if g.name in ik:
            cnt = sum(1 for v in m.data.vertices for e in v.groups if e.group == g.index and e.weight > 0)
            print('WEIGHTED IK', m.name, g.name, cnt)
bpy.ops.object.mode_set(mode='EDIT')
for n in ik:
    eb.remove(eb[n])
bpy.ops.object.mode_set(mode='OBJECT')

# 2. Mixamo names.
names = {'Bone': 'Hips', 'spine1': 'Spine', 'spine2': 'Spine1', 'spine3': 'Spine2', 'neck': 'Neck', 'head': 'Head'}
side = {'L': 'Left', 'R': 'Right'}
limb = {'arm1': 'Shoulder', 'arm2': 'Arm', 'arm3': 'ForeArm', 'wrist': 'Hand',
        'leg1': 'UpLeg', 'leg2': 'Leg', 'leg3': 'Foot', 'leg4': 'ToeBase'}
for b in arm.data.bones:
    n = b.name
    if n in names:
        b.name = names[n]
    elif '.' in n and n.split('.')[0] in limb and n.split('.')[1] in side:
        b.name = side[n.split('.')[1]] + limb[n.split('.')[0]]
print('BONES', [b.name for b in arm.data.bones])

# 3. Height 1.72 m, feet at 0, centred on x/y.
dg = bpy.context.evaluated_depsgraph_get()
lo = Vector((1e9,) * 3); hi = -lo
for o in meshes:
    me = o.evaluated_get(dg).to_mesh()
    for v in me.vertices:
        p = o.matrix_world @ v.co
        lo = Vector(map(min, lo, p)); hi = Vector(map(max, hi, p))
k = 1.72 / (hi.z - lo.z)
off = Vector(((lo.x + hi.x) * -0.5, (lo.y + hi.y) * -0.5, -lo.z))
arm.location = (arm.location + off) * k
arm.scale = arm.scale * k
for o in [arm] + meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
print('SCALE', k, 'OFF', off)

# 4. Materials: base color + normal only, small textures. The suit itself keeps 1024.
def tex(name, kind):
    for ext in ('.jpg', '.jpeg'):
        p = os.path.join(texdir, '_%s_%s%s' % (name, kind, ext))
        if os.path.exists(p):
            return p
    return None
for m in bpy.data.materials:
    base = tex(m.name, 'BaseColor')
    if not base:
        print('NO TEX FOR', m.name)
        continue
    size = 1024 if m.name == 'kostum' else 512
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    bsdf.inputs['Metallic'].default_value = 0.0
    bsdf.inputs['Roughness'].default_value = 0.75
    img = bpy.data.images.load(base)
    img.scale(size, size)
    img.pack()
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = img
    nt.links.new(t.outputs[0], bsdf.inputs['Base Color'])
    nrm = tex(m.name, 'Normal')
    if nrm:
        ni = bpy.data.images.load(nrm)
        ni.scale(size, size)
        ni.pack()
        ni.colorspace_settings.name = 'Non-Color'
        tn = nt.nodes.new('ShaderNodeTexImage'); tn.image = ni
        nm = nt.nodes.new('ShaderNodeNormalMap')
        nt.links.new(tn.outputs[0], nm.inputs['Color'])
        nt.links.new(nm.outputs[0], bsdf.inputs['Normal'])
    if m.name == 'kostum':
        img.save(filepath=os.path.join(os.path.dirname(dst), 'ozk_albedo_1024.png'))
    print('MAT', m.name, size, bool(nrm))

bpy.ops.object.select_all(action='DESELECT')
for o in [arm] + meshes:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', use_selection=True, export_animations=False,
                          export_skins=True, export_image_format='JPEG', export_jpeg_quality=85, export_yup=True)
print('DONE', dst, 'bounds', tuple(lo), tuple(hi))
