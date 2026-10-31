# Bake an animation frame into the rest pose (for models whose rest skeleton doesn't match the mesh).
# blender -b --python rest_from_anim.py -- in.glb out.glb frame
import bpy, sys
from mathutils import Vector
a = sys.argv[sys.argv.index('--') + 1:]
src, dst, frame = a[0], a[1], int(a[2])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.name.startswith('Icosphere'):
        bpy.data.objects.remove(o, do_unlink=True)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
print('ACTION', arm.animation_data.action.name if arm.animation_data and arm.animation_data.action else None, 'range', arm.animation_data.action.frame_range if arm.animation_data and arm.animation_data.action else None)
bpy.context.scene.frame_set(frame)
bpy.context.view_layer.update()
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
for m in meshes:
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = m
    m.select_set(True)
    mod = next(md for md in m.modifiers if md.type == 'ARMATURE')
    name = mod.name
    bpy.ops.object.modifier_apply(modifier=name)
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.pose.select_all(action='SELECT')
bpy.ops.pose.armature_apply(selected=False)
bpy.ops.object.mode_set(mode='OBJECT')
arm.animation_data_clear()
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)
for m in meshes:
    md = m.modifiers.new('Armature', 'ARMATURE')
    md.object = arm
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
lo = Vector((1e9,) * 3); hi = -lo
for o in meshes:
    me = o.evaluated_get(dg).to_mesh()
    for v in me.vertices:
        p = o.matrix_world @ v.co
        lo = Vector(map(min, lo, p)); hi = Vector(map(max, hi, p))
print('BOUNDS', tuple(round(x, 3) for x in lo), tuple(round(x, 3) for x in hi))
for b in arm.data.bones:
    if any(k in b.name for k in ('Head_', 'Hips_', 'LeftHand_', 'LeftFoot_')):
        print('  B', b.name, tuple(round(x, 3) for x in arm.matrix_world @ b.head_local))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', use_selection=True, export_animations=False,
                          export_skins=True, export_image_format='AUTO')
print('DONE')
