import bpy, sys
from mathutils import Vector
src = sys.argv[sys.argv.index('--') + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
dg = bpy.context.evaluated_depsgraph_get()
for o in bpy.data.objects:
    print('OBJ', o.type, o.name, 'parent', o.parent.name if o.parent else None, 'loc', tuple(round(x,3) for x in o.location), 'rot', tuple(round(x,3) for x in o.rotation_euler), 'scale', tuple(round(x,4) for x in o.scale))
for o in bpy.data.objects:
    if o.type == 'ARMATURE':
        o.data.pose_position = 'REST'
dg.update()
lo = Vector((1e9,)*3); hi = -lo
for o in bpy.data.objects:
    if o.type == 'MESH':
        me = o.evaluated_get(dg).to_mesh()
        for v in me.vertices:
            p = o.matrix_world @ v.co
            lo = Vector(map(min, lo, p)); hi = Vector(map(max, hi, p))
print('REST BOUNDS', tuple(round(x, 3) for x in lo), tuple(round(x, 3) for x in hi))
for o in bpy.data.objects:
    if o.type == 'ARMATURE':
        for b in o.data.bones:
            if any(k in b.name for k in ['Hips', 'Head', 'LeftHand', 'LeftFoot', 'LeftArm']) and 'End' not in b.name and 'Top' not in b.name:
                print('  B', b.name, tuple(round(x, 3) for x in (o.matrix_world @ b.head_local)))
print('ACTIONS', [a.name for a in bpy.data.actions])
