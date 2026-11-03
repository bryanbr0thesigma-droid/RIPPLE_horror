# Convert the approved Round 20/21 downloads into game files: real-world size, sensible origin,
# simplified for the Quest, small textures.  blender -b --python convert_approved.py -- <dl dir> <ph dir> <game dir>
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix
DL, PH, GAME = sys.argv[sys.argv.index('--') + 1:][:3]
# Optional 4th argument: convert only these (comma separated names), e.g. Distiller.
ONLY = set(sys.argv[sys.argv.index('--') + 1:][3].split(',')) if len(sys.argv[sys.argv.index('--') + 1:]) > 3 else None


def fresh(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    for o in list(bpy.data.objects):
        if o.name.startswith('Icosphere') or o.type not in ('MESH',):
            if o.type == 'MESH':
                bpy.data.objects.remove(o, do_unlink=True)
    # Bake every mesh's world transform, drop empties and armatures (these props aren't rigged).
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    for o in meshes:
        mw = o.matrix_world.copy()
        o.data = o.data.copy()
        o.data.transform(mw)
        for m in list(o.modifiers):
            o.modifiers.remove(m)
        o.parent = None
        o.matrix_world = Matrix()
    for o in list(bpy.data.objects):
        if o.type != 'MESH':
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    return [o for o in bpy.data.objects]


def bounds(objs):
    lo = Vector((1e9,) * 3); hi = -lo
    for o in objs:
        for v in o.data.vertices:
            lo = Vector(map(min, lo, v.co)); hi = Vector(map(max, hi, v.co))
    return lo, hi


def transform_all(objs, m):
    for o in objs:
        o.data.transform(m)


def normalize(objs, size, dim='z', origin='bottom'):
    lo, hi = bounds(objs)
    ext = hi - lo
    cur = max(ext) if dim == 'max' else ext['xyz'.index(dim)]
    k = size / cur
    c = (lo + hi) * 0.5
    anchor = Vector((c.x, c.y, lo.z if origin == 'bottom' else (hi.z if origin == 'top' else c.z)))
    transform_all(objs, Matrix.Scale(k, 4) @ Matrix.Translation(-anchor))
    return k


def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    return o


def decimate(objs, target):
    total = sum(len(o.data.polygons) for o in objs)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    if tris <= target:
        return
    r = target / tris
    for o in objs:
        bpy.context.view_layer.objects.active = o
        m = o.modifiers.new('dec', 'DECIMATE')
        m.ratio = r
        bpy.ops.object.modifier_apply(modifier=m.name)


def shrink_textures(size):
    for im in bpy.data.images:
        if im.size[0] > size or im.size[1] > size:
            w, h = im.size
            k = size / max(w, h)
            im.scale(max(1, int(w * k)), max(1, int(h * k)))
            im.pack()


def export(path, objs=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in (objs or bpy.data.objects):
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_image_format='JPEG',
                              export_jpeg_quality=88, export_animations=False)
    lo, hi = bounds(objs or list(bpy.data.objects))
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in (objs or bpy.data.objects))
    print('EXPORTED', os.path.basename(path), 'tris', tris, 'size', tuple(round(x, 3) for x in (hi - lo)))


def simple(name, src, out, size, dim='z', origin='bottom', tris=None, tex=512, after=None):
    objs = fresh(src)
    normalize(objs, size, dim, origin)
    o = join(objs, name)
    if tris:
        decimate([o], tris)
    if after:
        after(o)
    shrink_textures(tex)
    export(out, [o])


def gold(o):
    for m in o.data.materials:
        if m and m.use_nodes:
            b = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if not b:
                continue
            nt = m.node_tree
            mix = nt.nodes.new('ShaderNodeMix')
            mix.data_type = 'RGBA'
            mix.blend_type = 'MULTIPLY'
            mix.inputs['Factor'].default_value = 1.0
            mix.inputs[7].default_value = (1.0, 0.72, 0.28, 1.0)
            if b.inputs['Base Color'].is_linked:
                src = b.inputs['Base Color'].links[0].from_socket
                nt.links.new(src, mix.inputs[6])
            else:
                mix.inputs[6].default_value = b.inputs['Base Color'].default_value
            nt.links.new(mix.outputs[2], b.inputs['Base Color'])
            for l in list(b.inputs['Metallic'].links):
                nt.links.remove(l)
            b.inputs['Metallic'].default_value = 1.0
            for l in list(b.inputs['Roughness'].links):
                nt.links.remove(l)
            b.inputs['Roughness'].default_value = 0.32


P = os.path.join(GAME, 'assets', 'props')
G = os.path.join(GAME, 'assets', 'gore')

# --- Round 20 ---------------------------------------------------------------------------------
# --- Round 22 ------------------------------------------------------------------------------------
LATER = [
    ('Distiller', f'{DL}/distiller/model.glb', f'{P}/distiller.glb', 1.25, 'z', 'bottom', 8000),   # rusted tanks
    # --- Round 24: staff room table and the lidar charger's stand (the table height is kept, so
    # the items on it don't move) ---
    ('Desk', f'{DL}/desk_metal/model.glb', f'{P}/staff_desk.glb', 0.85, 'z', 'bottom'),            # old metal desk
    ('ToolCart', f'{PH}/tool_cart/tool_cart_1k.gltf', f'{P}/tool_cart.glb', 0.9, 'z', 'bottom', 8000),
    # Round 24: the distiller machine the canteen goes on, in front of the tanks
    ('Machinery', f'{DL}/machinery/model.glb', f'{P}/distiller_machine.glb', 1.7, 'max', 'bottom', 12000),
]
if ONLY:                       # just these, then stop
    for args in LATER:
        if args[0] in ONLY:
            simple(*args)
    raise SystemExit(0)

simple('Key', f'{DL}/key/model.glb', f'{P}/key.glb', 0.13, 'max', 'center', after=gold)
simple('Scanner', f'{DL}/scanner/model.glb', f'{P}/scanner.glb', 0.19, 'max', 'center')
simple('Bottle', f'{DL}/bottle_beer/model.glb', f'{P}/bottle_beer.glb', 0.24, 'z', 'center')
simple('Ladder', f'{DL}/ladder/model.glb', f'{P}/pool_ladder.glb', 1.13, 'z', 'bottom')
simple('ExitDoors', f'{DL}/door_exit/model.glb', f'{P}/exit_doors.glb', 2.3, 'z', 'bottom')
simple('BunkerDoor', f'{DL}/door_bunker/model.glb', f'{P}/bunker_door.glb', 2.4, 'z', 'bottom', tris=6000)
simple('PowerLever', f'{DL}/lever_yellow/model.glb', f'{P}/power_lever.glb', 0.55, 'max', 'bottom', tris=3000)
simple('Canteen', f'{PH}/plastic_thermos/plastic_thermos_1k.gltf', f'{P}/canteen.glb', 0.26, 'z', 'center')
# Whiskey and wine: one file per bottle.
objs = fresh(f'{DL}/bottles_wine/model.glb')
for i, o in enumerate(sorted(objs, key=lambda x: x.name)):
    others = [x for x in bpy.data.objects if x != o]
    bpy.ops.object.select_all(action='DESELECT')
for i, keep in enumerate(sorted([o.name for o in objs])):
    objs = fresh(f'{DL}/bottles_wine/model.glb')
    o = bpy.data.objects[keep]
    for x in list(bpy.data.objects):
        if x != o:
            bpy.data.objects.remove(x, do_unlink=True)
    normalize([o], 0.3, 'z', 'center')
    shrink_textures(512)
    export(f'{P}/bottle_glass_{i + 1}.glb', [o])
# Metal staff door: the frame, and the leaf with its handle and lock hinged on the right edge.
objs = fresh(f'{DL}/door_metal/model.glb')
k = normalize(objs, 2.15, 'z', 'bottom')
frame = next(o for o in objs if o.name == 'defaultMaterial')
leaf = join([o for o in objs if o != frame], 'Leaf')
frame.name = 'Frame'
lo, hi = bounds([leaf])
hinge = Vector((hi.x, (lo.y + hi.y) * 0.5, 0))
leaf.data.transform(Matrix.Translation(-hinge))
leaf.location = hinge
shrink_textures(512)
export(f'{P}/staff_door.glb', [frame, leaf])
print('HINGE', tuple(round(x, 3) for x in hinge))
# The red lever: panel and a handle that turns about its own origin.
objs = fresh(f'{DL}/lever_red/model.glb')
normalize(objs, 0.42, 'z', 'bottom')
handle = next(o for o in objs if o.name.startswith('Lever'))
panel = next(o for o in objs if o.name.startswith('Panel'))
handle.name = 'Handle'
panel.name = 'Panel'
lo, hi = bounds([handle])
pivot = Vector(((lo.x + hi.x) * 0.5, lo.y, lo.z + (hi.z - lo.z) * 0.08))
handle.data.transform(Matrix.Translation(-pivot))
handle.location = pivot
shrink_textures(512)
export(f'{P}/cover_lever.glb', [panel, handle])
print('LEVER PIVOT', tuple(round(x, 3) for x in pivot), 'handle size', tuple(round(x, 3) for x in hi - lo))

# --- Round 21 (anatomy) -------------------------------------------------------------------------
simple('Heart', f'{DL}/heart/model.glb', f'{G}/heart.glb', 0.13, 'max', 'center', tris=4000)
simple('Lungs', f'{DL}/lungs/model.glb', f'{G}/lungs.glb', 0.26, 'max', 'center', tris=6000)
simple('Liver', f'{DL}/liver/model.glb', f'{G}/liver.glb', 0.22, 'max', 'center', tris=5000)
simple('Kidney', f'{DL}/kidney/model.glb', f'{G}/kidney.glb', 0.11, 'max', 'center', tris=2500)
simple('Gut', f'{DL}/digestive/model.glb', f'{G}/stomach.glb', 0.36, 'max', 'center', tris=6000)
# The spine hangs from its neck end: origin at the top (the narrow, cervical end), pointing down.
objs = fresh(f'{DL}/spine/model.glb')
o = join(objs, 'Spine')
lo, hi = bounds([o])
zs = sorted(v.co.z for v in o.data.vertices)
def width_at(z0, z1):
    xs = [v.co.x for v in o.data.vertices if z0 <= v.co.z <= z1]
    return (max(xs) - min(xs)) if xs else 0
h = hi.z - lo.z
top_w, bot_w = width_at(hi.z - h * 0.1, hi.z), width_at(lo.z, lo.z + h * 0.1)
if top_w > bot_w:       # lumbar end is up: flip so the neck end is up
    o.data.transform(Matrix.Rotation(math.pi, 4, 'X'))
normalize([o], 0.62, 'z', 'top')
decimate([o], 5000)
mat = bpy.data.materials.new('Bone')
mat.use_nodes = True
b = mat.node_tree.nodes['Principled BSDF']
b.inputs['Base Color'].default_value = (0.82, 0.76, 0.64, 1)
b.inputs['Roughness'].default_value = 0.5
o.data.materials.clear()
o.data.materials.append(mat)
export(f'{G}/spine.glb', [o])
print('SPINE widths top/bottom', round(top_w, 2), round(bot_w, 2))
for args in LATER:
    simple(*args)
