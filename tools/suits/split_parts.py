# Split a suit into head, upper body and lower body, so the creature can tear it apart. Each face
# goes to the part whose bones hold its vertices most: the head (head and neck), the lower body
# (hips, lowest spine bone, legs) or the upper body (the rest). Meshes are renamed <name>__head,
# <name>__upper and <name>__lower; skinning is kept.
#   blender -b --python split_parts.py -- in.glb out.glb
import bpy, bmesh, sys, re
a = sys.argv[sys.argv.index('--') + 1:]
src, dst = a
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.name.startswith('Icosphere'):
        bpy.data.objects.remove(o, do_unlink=True)


def base(n):
    n = n.split(':')[-1]
    n = re.sub(r'^mixamorig_?', '', n)
    return re.sub(r'_\d+$', '', n)


def part_of(bone):
    b = base(bone)
    bl = b.lower()
    if 'head' in bl or 'neck' in bl:
        return 'head'
    if b == 'Hips' or b == 'Spine' or any(k in bl for k in ('upleg', 'leg', 'foot', 'toe')):
        return 'lower'
    return 'upper'


counts = {}
for o in [x for x in bpy.data.objects if x.type == 'MESH']:
    names = {g.index: g.name for g in o.vertex_groups}
    vpart = []
    for v in o.data.vertices:
        acc = {'head': 0.0, 'upper': 0.0, 'lower': 0.0}
        for g in v.groups:
            if g.group in names:
                acc[part_of(names[g.group])] += g.weight
        vpart.append(acc)
    fpart = []
    for f in o.data.polygons:
        acc = {'head': 0.0, 'upper': 0.0, 'lower': 0.0}
        for vi in f.vertices:
            for k, w in vpart[vi].items():
                acc[k] += w
        fpart.append(max(acc, key=acc.get) if sum(acc.values()) > 0 else 'upper')
    present = sorted(set(fpart))
    for part in present:
        c = o.copy()
        c.data = o.data.copy()
        for col in o.users_collection:
            col.objects.link(c)
        bm = bmesh.new()
        bm.from_mesh(c.data)
        bm.faces.ensure_lookup_table()
        kill = [bm.faces[i] for i, p in enumerate(fpart) if p != part]
        bmesh.ops.delete(bm, geom=kill, context='FACES')
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
        bm.to_mesh(c.data)
        bm.free()
        c.name = o.name + '__' + part
        counts[part] = counts.get(part, 0) + len(c.data.polygons)
    bpy.data.objects.remove(o, do_unlink=True)
print('PARTS', counts)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', use_selection=True, export_animations=False,
                          export_skins=True, export_image_format='AUTO')
print('DONE', dst)
