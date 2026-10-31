import bpy, sys
from mathutils import Vector
src = sys.argv[sys.argv.index('--') + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
dg = bpy.context.evaluated_depsgraph_get()
for o in bpy.data.objects:
    if o.type == 'MESH':
        me = o.evaluated_get(dg).to_mesh()
        lo = Vector((1e9,)*3); hi = -lo
        for v in me.vertices:
            p = o.matrix_world @ v.co
            lo = Vector(map(min, lo, p)); hi = Vector(map(max, hi, p))
        groups = sorted(set(o.vertex_groups[g.group].name for v in o.data.vertices for g in v.groups if g.weight > 0.01))
        print('MESH', o.name, [m.name for m in o.data.materials if m], 'parent', o.parent.name if o.parent else None, o.parent_type, o.parent_bone, 'mods', [m.type for m in o.modifiers], 'n', len(me.vertices), 'lo', tuple(round(x,2) for x in lo), 'hi', tuple(round(x,2) for x in hi), 'groups', groups[:8], len(groups))
