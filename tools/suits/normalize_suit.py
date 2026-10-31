# Stand a suit upright, 1.72 m tall, feet at 0, centred; no animations.
# blender -b --python normalize_suit.py -- in.glb out.glb rot_x_degrees
import bpy, sys, math
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index('--') + 1:]
src, dst, rotx = a[0], a[1], a[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.name.startswith('Icosphere'):
        bpy.data.objects.remove(o, do_unlink=True)
for o in bpy.data.objects:
    if o.animation_data:
        o.animation_data_clear()
    if o.type == 'ARMATURE':
        o.data.pose_position = 'REST'
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)
top = [o for o in bpy.data.objects if o.parent is None]
assert len(top) == 1, [o.name for o in top]
top = top[0]
print("TOP", top.name, top.rotation_mode, tuple(top.rotation_quaternion))
if rotx != 'keep':
    top.rotation_mode = 'XYZ'
    top.rotation_euler = (math.radians(float(rotx)), 0, 0)
bpy.context.view_layer.update()
print("TOPMW", top.matrix_world)
def bounds():
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9,) * 3); hi = -lo
    for o in bpy.data.objects:
        if o.type == 'MESH':
            me = o.evaluated_get(dg).to_mesh()
            for v in me.vertices:
                p = o.matrix_world @ v.co
                lo = Vector(map(min, lo, p)); hi = Vector(map(max, hi, p))
    return lo, hi
lo, hi = bounds()
k = 1.72 / (hi.z - lo.z)
top.scale = top.scale * k
lo, hi = bounds()
top.location = Vector(((lo.x + hi.x) * -0.5, (lo.y + hi.y) * -0.5, -lo.z)) + top.location
lo, hi = bounds()
print('BOUNDS', tuple(round(x, 3) for x in lo), tuple(round(x, 3) for x in hi))
for o in bpy.data.objects:
    if o.type == 'ARMATURE':
        o.data.pose_position = 'POSE'
        for b in o.data.bones:
            if b.name.endswith(('Head_1', 'LeftArm_25', 'LeftFoot_56', 'LeftToeBase_55', 'Head_019', 'LeftFoot_059', 'LeftToeBase_060', 'Hips_014')) or b.name in ('Head', 'LeftArm', 'LeftFoot', 'LeftToeBase'):
                print('  B', b.name, tuple(round(x, 3) for x in (o.matrix_world @ b.head_local)))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', use_selection=True, export_animations=False,
                          export_skins=True, export_image_format='AUTO')
print('DONE', dst)
