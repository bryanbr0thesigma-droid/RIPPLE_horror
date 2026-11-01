# The jumpsuit's own gloves can't be used (stored half a metre from its hands). Give it the
# diver's black neoprene hands instead: cut them off the diver by skin weight, move each onto the
# jumpsuit's hand bone (matching the two rigs' hand bones), and skin them rigidly to it.
#   blender -b --python transplant_hands.py -- jumpsuit.glb diver.glb out.glb
import bpy, bmesh, sys, re
from mathutils import Matrix
a = sys.argv[sys.argv.index('--') + 1:]
jump_path, diver_path, dst = a


def base(n):
    n = n.split(':')[-1]
    n = re.sub(r'^mixamorig_?', '', n)
    return re.sub(r'_\d+$', '', n)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=jump_path)
jump_objs = set(bpy.data.objects)
jarm = next(o for o in jump_objs if o.type == 'ARMATURE')
bpy.ops.import_scene.gltf(filepath=diver_path)
diver_objs = [o for o in bpy.data.objects if o not in jump_objs]
darm = next(o for o in diver_objs if o.type == 'ARMATURE')


def bone(arm, name):
    return next(b for b in arm.data.bones if base(b.name) == name)


made = []
for side in ('Left', 'Right'):
    dhand = bone(darm, side + 'Hand')
    jhand = bone(jarm, side + 'Hand')
    def unscaled(m):
        return Matrix.LocRotScale(m.translation, m.to_quaternion(), (1, 1, 1))
    D = unscaled(darm.matrix_world @ dhand.matrix_local)    # the rigs are scaled differently;
    J = unscaled(jarm.matrix_world @ jhand.matrix_local)    # both suits are already 1.72 m tall
    M = J @ D.inverted()
    body = [x for x in diver_objs if x.type == 'MESH' and x.vertex_groups and x.data.materials
            and x.data.materials[0] and x.data.materials[0].name == 'Buso']   # the wetsuit only
    for o in body:
        names = {g.index: g.name for g in o.vertex_groups}
        hand_v = set()
        for v in o.data.vertices:
            h = sum(g.weight for g in v.groups if g.group in names and base(names[g.group]).startswith(side + 'Hand'))
            tot = sum(g.weight for g in v.groups)
            if tot > 0 and h / tot > 0.5:
                hand_v.add(v.index)
        faces = [f.index for f in o.data.polygons if all(vi in hand_v for vi in f.vertices)]
        if len(faces) < 20:
            continue
        me = o.data.copy()
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        keep = set(faces)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context='FACES')
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
        bm.to_mesh(me)
        bm.free()
        me.transform(M @ o.matrix_world)
        h = bpy.data.objects.new(f'{side}Hand__upper', me)
        bpy.context.collection.objects.link(h)
        h.vertex_groups.clear()
        g = h.vertex_groups.new(name=jhand.name)
        g.add([v.index for v in me.vertices], 1.0, 'REPLACE')
        h.parent = jarm
        h.matrix_parent_inverse = jarm.matrix_world.inverted()
        mod = h.modifiers.new('Armature', 'ARMATURE')
        mod.object = jarm
        made.append((h.name, len(me.polygons)))
for o in diver_objs:
    bpy.data.objects.remove(o, do_unlink=True)
for o in list(bpy.data.objects):
    if o.name.startswith('Icosphere'):
        bpy.data.objects.remove(o, do_unlink=True)
print('HANDS', made)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', use_selection=True, export_animations=False,
                          export_skins=True, export_image_format='AUTO')
print('DONE', dst)
