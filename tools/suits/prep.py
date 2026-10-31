# Prepare a suit for the Quest: drop Blender's bone-shape spheres and anything listed to remove,
# shrink textures that aren't on the main suit material, save the main albedo for mask-making,
# and export a GLB.   blender -b --python prep.py -- in.glb out.glb out_dir keep_material [remove,...]
import bpy, sys, os
a = sys.argv[sys.argv.index('--') + 1:]
src, dst, outdir, keep_mat = a[0], a[1], a[2], a[3]
remove = a[4].split(',') if len(a) > 4 and a[4] else []
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    mats = [m.name for m in o.data.materials if m] if o.type == 'MESH' else []
    if o.name.startswith('Icosphere') or any(m in remove for m in mats):
        bpy.data.objects.remove(o, do_unlink=True)
keep_images = set()
for m in bpy.data.materials:
    if m.name == keep_mat and m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image:
                keep_images.add(n.image.name)
                bsdf = next((x for x in m.node_tree.nodes if x.type == 'BSDF_PRINCIPLED'), None)
                if bsdf and bsdf.inputs['Base Color'].is_linked and bsdf.inputs['Base Color'].links[0].from_node == n:
                    n.image.filepath_raw = os.path.join(outdir, 'albedo.png')
                    n.image.file_format = 'PNG'
                    n.image.save()
                    print('SAVED albedo', n.image.name, tuple(n.image.size))
for im in bpy.data.images:
    if im.name not in keep_images and max(im.size) > 512:
        im.scale(512, 512)
        im.pack()
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', use_selection=True, export_animations=True,
                          export_skins=True, export_image_format='AUTO')
print('PREPDONE', dst, 'kept', sorted(keep_images))
