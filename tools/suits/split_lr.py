# Split a suit into left and right halves down the middle, for the creature's vertical tear.
# Each mesh is joined back together (the head / upper / lower pieces from split_parts.py), cut on
# the body's mid plane (through the hips bone), and the cut is filled with a face that gets a
# "Flesh_cut" material (the game shows raw flesh there). Meshes are renamed <name>__left and
# <name>__right; skinning is kept (the new vertices on the cut get blended weights).
# Textures are not exported: the game borrows the materials, by name, from the full suit file.
#   blender -b --python split_lr.py -- in.glb out.glb
import bpy, bmesh, sys, re
from mathutils import Vector

a = sys.argv[sys.argv.index('--') + 1:]
src, dst = a
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.name.startswith('Icosphere'):
        bpy.data.objects.remove(o, do_unlink=True)

arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
hips = next((b for b in arm.data.bones if re.sub(r'^mixamorig[:_]?', '', b.name).split('_0')[0] in ('Hips',)), None)
if hips is None:
    hips = next(b for b in arm.data.bones if 'hips' in b.name.lower())
mid_x = (arm.matrix_world @ hips.head_local).x
print('mid plane x =', round(mid_x, 4), 'from bone', hips.name)

flesh = bpy.data.materials.new('Flesh_cut')
flesh.diffuse_color = (0.5, 0.05, 0.05, 1.0)

# Join the head / upper / lower pieces of each mesh back into one, closing their seams.
groups = {}
for o in [o for o in bpy.data.objects if o.type == 'MESH']:
    base = re.sub(r'__(head|upper|lower)$', '', o.name)
    groups.setdefault(base, []).append(o)
meshes = []
for base, objs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = base
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(o.data)
    bm.free()
    meshes.append(o)


def half(o, keep_left):
    """Copy o, cut it on the mid plane, keep one side and fill the cut."""
    c = o.copy()
    c.data = o.data.copy()
    bpy.context.scene.collection.objects.link(c)
    for col in o.users_collection:
        if c.name not in col.objects:
            col.objects.link(c)
    c.name = o.name + ('__left' if keep_left else '__right')
    inv = c.matrix_world.inverted()
    co = inv @ Vector((mid_x, 0, 0))
    no = (c.matrix_world.to_3x3().transposed() @ Vector((1, 0, 0))).normalized()
    bm = bmesh.new()
    bm.from_mesh(c.data)
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, dist=1e-6,
                           clear_inner=keep_left, clear_outer=not keep_left)
    # The cut: boundary edges lying on the plane. Fill the closed loops with flesh.
    eps = 1e-4
    on_plane = [e for e in bm.edges if e.is_boundary and all(abs((v.co - co).dot(no)) < eps for v in e.verts)]
    if c.data.materials.find('Flesh_cut') < 0:
        c.data.materials.append(flesh)
    fi = c.data.materials.find('Flesh_cut')
    filled = 0
    if on_plane:
        # Where the cut runs into an opening (the neck, say), its chain is open: close it across.
        deg = {}
        for e in on_plane:
            for v in e.verts:
                deg[v] = deg.get(v, 0) + 1
        ends = [v for v, d in deg.items() if d == 1]
        edges = list(on_plane)
        while len(ends) >= 2:
            v = ends.pop(0)
            j = min(range(len(ends)), key=lambda k: (ends[k].co - v.co).length)
            w = ends.pop(j)
            if bm.edges.get((v, w)) is None:
                edges.append(bm.edges.new((v, w)))
        res = bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=edges, normal=no)
        faces = [g for g in res['geom'] if isinstance(g, bmesh.types.BMFace)]
        out = -no if keep_left else no          # the cap faces away from the half it closes
        for f in faces:
            f.material_index = fi
            f.normal_update()
            if f.normal.dot(out) < 0:
                f.normal_flip()
            filled += 1
    bm.to_mesh(c.data)
    bm.free()
    print('  ', c.name, 'faces', len(c.data.polygons), 'cut faces', filled)
    return c


def rigid(o):
    """Gear that moves mostly with one bone (a tank, straps, a mask, a torch) stays whole instead of
    being cut; garments spread over many bones (the suit itself) are cut."""
    top = {}
    for v in o.data.vertices:
        if v.groups:
            g = max(v.groups, key=lambda g: g.weight)
            top[g.group] = top.get(g.group, 0) + 1
    return bool(top) and max(top.values()) >= 0.55 * len(o.data.vertices)


for o in meshes:
    if rigid(o):
        cx = sum(((o.matrix_world @ v.co).x for v in o.data.vertices), 0.0) / max(len(o.data.vertices), 1)
        o.name = o.name + ('__left' if cx > mid_x else '__right')   # with the half it sits on
        print('  ', o.name, 'kept whole (rigid gear)')
        continue
    half(o, True)
    half(o, False)
    bpy.data.objects.remove(o, do_unlink=True)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_skins=True, export_animations=False,
                          export_image_format='NONE', export_yup=True, use_selection=False)
print('wrote', dst)
