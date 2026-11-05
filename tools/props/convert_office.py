# The first-boot intro's office furniture (Poly Haven, CC0), kept at real size, simplified for the
# Quest, small textures. Floor pieces stand on their base, centred; wall pieces have their origin
# at the middle of their back, so they sit flush on a wall.
#   blender -b --python convert_office.py -- <poly haven dir> <game dir>
import bpy, sys, os
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
PH, GAME = sys.argv[sys.argv.index('--') + 1:][:2]
OUT = os.path.join(GAME, 'assets', 'props', 'office')

# id: (mode, max triangles)
ITEMS = {
    'metal_office_desk': ('floor', 7000), 'mid_century_lounge_chair': ('floor', 6200),
    'desk_lamp_arm_01': ('floor', 5000), 'office_notepads': ('floor', 700), 'vintage_stapler': ('floor', 1500),
    'clipboard': ('floor', 2000), 'standing_picture_frame_01': ('floor', 1700),
    'wooden_bookshelf_worn': ('floor', 8000), 'steel_frame_shelves_01': ('floor', 4400),
    'binder_notebook': ('floor', 3000), 'cardboard_box_01': ('floor', 3000), 'potted_plant_02': ('floor', 9000),
    'wall_clock': ('wall', 3700), 'hanging_picture_frame_01': ('wall', 2600), 'hanging_picture_frame_02': ('wall', 3700),
    'fire_alarm': ('wall', 2800),
}


def fresh(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    for o in meshes:
        mw = o.matrix_world.copy()
        o.data = o.data.copy()
        o.data.transform(mw)
        for m in list(o.modifiers):
            o.modifiers.remove(m)
        o.parent = None
        o.matrix_world = Matrix()
        for vg in list(o.vertex_groups):
            o.vertex_groups.remove(vg)
    for o in list(bpy.data.objects):
        if o.type != 'MESH':
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    return [o for o in bpy.data.objects]


for pid, (mode, tris) in ITEMS.items():
    src = os.path.join(PH, pid, pid + '_1k.gltf')
    objs = fresh(src)
    lo = Vector((1e9,) * 3); hi = -lo
    for o in objs:
        for v in o.data.vertices:
            lo = Vector(map(min, lo, v.co)); hi = Vector(map(max, hi, v.co))
    c = (lo + hi) / 2
    # Floor: base on the ground, centred. Wall: centred, its back (+Y, the models face -Y) at 0.
    anchor = Vector((c.x, c.y, lo.z)) if mode == 'floor' else Vector((c.x, hi.y, c.z))
    for o in objs:
        o.data.transform(Matrix.Translation(-anchor))
    total = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    if total > tris:
        for o in objs:
            bpy.context.view_layer.objects.active = o
            m = o.modifiers.new('dec', 'DECIMATE')
            m.ratio = tris / total
            with bpy.context.temp_override(object=o, active_object=o):
                bpy.ops.object.modifier_apply(modifier=m.name)
    for im in bpy.data.images:
        if im.size[0] > 512:
            k = 512 / max(im.size)
            im.scale(max(1, int(im.size[0] * k)), max(1, int(im.size[1] * k)))
            im.pack()
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, pid.lower() + '.glb')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True, export_image_format='JPEG',
                              export_jpeg_quality=86, export_animations=False)
    after = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
    print('OFFICE', pid.lower(), mode, 'tris', after, 'size', tuple(round(x, 3) for x in hi - lo))
