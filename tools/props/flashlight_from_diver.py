# The squeeze flashlight: the torch the approved diver model holds ("Nanando diver" by Marco Lopez,
# CC BY), cut out of the suit, freed from its skeleton, lens pointing forward (Godot -Z), 20 cm long,
# origin at its middle. The lens glass is kept as its own mesh ("Lens") so the game can light it.
#   blender -b --python flashlight_from_diver.py -- diver.glb flashlight.glb
import bpy, sys
from mathutils import Vector, Matrix

a = sys.argv[sys.argv.index('--') + 1:]
src, dst = a
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

parts = []
for o in [o for o in bpy.data.objects if o.type == 'MESH']:
    names = [m.name for m in o.data.materials if m]
    if any(n.startswith('Linterna') for n in names):
        parts.append(o)
for o in list(bpy.data.objects):
    if o not in parts:
        bpy.data.objects.remove(o, do_unlink=True)
for o in parts:                                   # bake the bind pose, drop the skinning
    for m in list(o.modifiers):
        o.modifiers.remove(m)
    mw = o.matrix_world.copy()
    o.parent = None
    o.data = o.data.copy()
    o.data.transform(mw)
    o.matrix_world = Matrix.Identity(4)
    o.vertex_groups.clear()

body = [o for o in parts if not any(m and m.name == 'Linterna_Light' for m in o.data.materials)]
lens = [o for o in parts if o not in body]
allv = [v.co for o in parts for v in o.data.vertices]
lo = Vector([min(v[i] for v in allv) for i in range(3)])
hi = Vector([max(v[i] for v in allv) for i in range(3)])
mid = (lo + hi) * 0.5
size = hi - lo
axis = max(range(3), key=lambda i: size[i])        # the torch's long axis
lv = [v.co for o in lens for v in o.data.vertices] or allv
lens_c = sum(lv, Vector()) / len(lv)
d = Vector((0, 0, 0))
d[axis] = 1.0 if lens_c[axis] > mid[axis] else -1.0
rot = d.rotation_difference(Vector((0, 1, 0))).to_matrix().to_4x4()   # Blender +Y = Godot -Z
k = 0.2 / size[axis]
m = Matrix.Scale(k, 4) @ rot @ Matrix.Translation(-mid)
for o in parts:
    o.data.transform(m)
for o in body:
    o.name = 'Body'
for o in lens:
    o.name = 'Lens'
for img in bpy.data.images:                        # small textures for the Quest
    if img.size[0] > 512:
        img.scale(512, max(1, int(img.size[1] * 512 / img.size[0])))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', use_selection=True, export_skins=False, export_animations=False)
print('torch axis', axis, 'scale', round(k, 4), 'parts', [o.name for o in parts])
