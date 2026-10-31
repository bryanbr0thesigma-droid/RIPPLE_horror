# Turn a Poly Haven glTF (1k) into a GLB for the game, optionally keeping only some pieces and
# moving each piece so a chosen point sits at its origin (for kits like modular_pipes).
#   blender -b --python ph_to_glb.py -- in.gltf out.glb max_tex [piece=x,y,z ...]
# Coordinates for pieces are Blender (Z-up) world positions.
import bpy, sys
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index('--') + 1:]
src, dst, max_tex = a[0], a[1], int(a[2])
pieces = {}
for p in a[3:]:
    n, c = p.split('=')
    pieces[n] = Vector([float(x) for x in c.split(',')])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.type != 'MESH' or (pieces and o.name not in pieces):
        bpy.data.objects.remove(o, do_unlink=True)
for o in bpy.data.objects:
    o.data = o.data.copy()
    o.data.transform(o.matrix_world)
    o.matrix_world = Matrix()
    o.parent = None
    if o.name in pieces:
        o.data.transform(Matrix.Translation(-pieces[o.name]))
for im in bpy.data.images:
    if max(im.size) > max_tex:
        im.scale(max_tex, max_tex)
        im.pack()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', use_selection=True, export_image_format='JPEG',
                          export_jpeg_quality=88)
print('DONE', dst, [o.name for o in bpy.data.objects])
