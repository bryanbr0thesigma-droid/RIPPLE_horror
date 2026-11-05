# Kitbash for the secret suit (code 34): an anime goth woman in a glossy black latex wetsuit with
# scuba gear.
#   Body: "Cat Girl - Anime Character Model" by VR_Avatars (CC BY), a VRoid character, keeping its
#         own skeleton and skin weights. Its skin from the neck down becomes black latex (the hands
#         too, as gloves); the face, hair, cat ears and black-and-pink top stay, the top made shiny.
#   Gear: the tank, vest and mask of "Scuba Diver" by turelljc (CC BY), taken from the
#         rigged game copy (game/assets/suits/scuba.glb) and fitted to her: the tank and harness
#         ride on her chest bone (pushed out of her where her fuller figure met it, and following
#         her bust's jiggle bones where it lies on it), the mask is pushed up onto her forehead.
# The VRoid bones are renamed to the Mixamo names the game looks for.
#   blender -b --python build_latex_diver.py -- catgirl.glb scuba.glb out.glb
import bpy, bmesh, sys, re, math
from mathutils import Vector, Matrix

a = sys.argv[sys.argv.index('--') + 1:]
src, gear_src, dst = a[0], a[1], a[2]
HEIGHT = 1.66                      # top of the cat ears

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.name.startswith('Icosphere'):
        bpy.data.objects.remove(o, do_unlink=True)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
body = [o for o in bpy.data.objects if o.type == 'MESH']

# 1. Stand her up (the download lies along +Y, face toward +Z), feet on the ground, facing -Y,
#    and bake every transform so the armature and meshes sit at the origin unscaled.
for o in body + [arm]:
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
for o in [o for o in bpy.data.objects if o.type == 'EMPTY']:
    bpy.data.objects.remove(o, do_unlink=True)
rot = Matrix.Rotation(math.radians(90), 4, 'X')
pts = [rot @ (o.matrix_world @ v.co) for o in body for v in o.data.vertices]
lo = Vector([min(p[i] for p in pts) for i in range(3)])
hi = Vector([max(p[i] for p in pts) for i in range(3)])
k = HEIGHT / (hi.z - lo.z)
fix = Matrix.Scale(k, 4) @ Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))) @ rot
for o in body + [arm]:
    o.matrix_world = fix @ o.matrix_world
    if o.type == 'MESH' and o.data.shape_keys:
        o.shape_key_clear()                     # the game doesn't use the face blend shapes
bpy.ops.object.select_all(action='DESELECT')
for o in body + [arm]:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# 2. Mixamo bone names (vertex groups follow the rename).
MAP = {'Hips': 'Hips', 'Spine': 'Spine', 'Chest': 'Spine1', 'UpperChest': 'Spine2', 'Neck': 'Neck',
       'Head': 'Head', 'Shoulder': 'Shoulder', 'UpperArm': 'Arm', 'LowerArm': 'ForeArm', 'Hand': 'Hand',
       'UpperLeg': 'UpLeg', 'LowerLeg': 'Leg', 'Foot': 'Foot', 'ToeBase': 'ToeBase'}
FINGERS = {'Thumb': 'Thumb', 'Index': 'Index', 'Middle': 'Middle', 'Ring': 'Ring', 'Little': 'Pinky'}
for b in arm.data.bones:
    n = re.sub(r'_\d+$', '', b.name)
    m = re.match(r'J_Bip_([CLR])_(\w+?)(\d?)$', n)
    if not m:
        continue
    side, part, num = m.groups()
    pre = {'C': '', 'L': 'Left', 'R': 'Right'}[side]
    if part in MAP:
        b.name = pre + MAP[part]
    elif part in FINGERS:
        b.name = pre + 'Hand' + FINGERS[part] + num
for o in body:
    for md in o.modifiers:
        if md.type == 'ARMATURE':
            md.object = arm
    o.parent = arm
    o.matrix_parent_inverse = arm.matrix_world.inverted()


def bone(name):
    return arm.matrix_world @ arm.data.bones[name].head_local


print('left hand', tuple(round(x, 2) for x in bone('LeftHand')), 'head', tuple(round(x, 2) for x in bone('Head')))

# 2b. A fuller figure, the way VRChat body sliders do it: four regions (bust, waist, hips and rear,
#     thighs), each moved only through the bones that already hold it. A vertex moves by the
#     weighted sum of its bones' moves, so every change blends out along the artist's own skin
#     weights and nothing else (face, arms, hair) is touched.
BUST, WAIST, HIPS, REAR, THIGH = 1.45, 0.86, 1.25, 1.65, 1.4


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


hips_c = bone('Hips')


def thigh(side):
    a, b = bone(side + 'UpLeg'), bone(side + 'Leg')
    d = (b - a).normalized()
    L = (b - a).length

    def f(p):
        t = (p - a).dot(d) / L
        c = a + d * (p - a).dot(d)
        off = p - c
        s = 1 + (THIGH - 1) * (1 - 0.6 * max(0.0, min(1.0, t)))      # thickest at the top
        if off.y > 0:                                                  # behind (she faces -Y)
            s_back = s * (1 + (REAR - 1) * (1 - smooth(0.0, 0.45, t)))   # the rear, top of the thigh
            off = Vector((off.x * s, off.y * s_back, off.z * s))
        else:
            off = off * s
        return c + off
    return f


def hips(p):
    off = p - hips_c
    low = 1 - smooth(hips_c.z + 0.02, hips_c.z + 0.1, p.z)          # not up into the waist
    x = off.x * (1 + (HIPS - 1) * low)
    y = off.y * (1 + (REAR - 1) * low) if off.y > 0 else off.y
    return hips_c + Vector((x, y, off.z))


def waist(p):
    a, b = bone('Spine'), bone('Spine1')
    d = (b - a).normalized()
    c = a + d * (p - a).dot(d)
    return c + (p - c) * WAIST


MOVES = {'LeftUpLeg': thigh('Left'), 'RightUpLeg': thigh('Right'), 'Hips': hips, 'Spine': waist}
for bn in arm.data.bones:
    m = re.match(r'J_Sec_([LR])_Bust\d', bn.name)
    if m:
        root = next(b for b in arm.data.bones if re.match(r'J_Sec_%s_Bust1' % m.group(1), b.name))
        centre = arm.matrix_world @ root.head_local
        MOVES[bn.name] = (lambda c: (lambda p: c + (p - c) * BUST))(centre)
for o in body:
    names = {g.index: g.name for g in o.vertex_groups}
    moved = 0
    for v in o.data.vertices:
        tw = sum(g.weight for g in v.groups) or 1.0
        p = o.matrix_world @ v.co
        dp = Vector()
        for g in v.groups:
            f = MOVES.get(names.get(g.group))
            if f and g.weight > 0:
                dp += (f(p) - p) * (g.weight / tw)
        if dp.length > 1e-5:
            v.co = o.matrix_world.inverted() @ (p + dp)
            moved += 1
    if moved and o.data.has_custom_normals:          # let the normals follow the new shape
        bpy.context.view_layer.objects.active = o
        with bpy.context.temp_override(object=o, active_object=o):
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
    print('fuller', o.name, moved)

# 2c. Jiggle bones for the rear (the bust already has VRoid's own, J_Sec_*_Bust1/2): one per side,
#     parented to the hips, holding the round of each cheek with a soft falloff. The game springs
#     them and the bust bones (SpringBoneSimulator3D, see "jiggle" in suit_rig.gd).
rear = [o for o in body if any(m and ('Body_00_SKIN' in m.name or 'Onepiece' in m.name) for m in o.data.materials)]
rear_pts = [o.matrix_world @ v.co for o in rear for v in o.data.vertices]
behind = [p for p in rear_pts if hips_c.z - 0.15 < p.z < hips_c.z and 0.04 < abs(p.x) < 0.16 and p.y > hips_c.y]
rear_y = max(p.y for p in behind)
GLUTE = {}
for side, sgn in (('L', 1), ('R', -1)):
    GLUTE[side] = Vector((sgn * 0.09, (hips_c.y + rear_y) / 2, hips_c.z - 0.07))
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
for side, c in GLUTE.items():
    b = arm.data.edit_bones.new('J_Sec_%s_Glute1' % side)
    b.head = arm.matrix_world.inverted() @ c
    b.tail = arm.matrix_world.inverted() @ (c + Vector((0, 0.08, 0)))
    b.parent = arm.data.edit_bones['Hips']
    b.use_deform = True
bpy.ops.object.mode_set(mode='OBJECT')
for o in rear:
    vgs = {side: o.vertex_groups.new(name='J_Sec_%s_Glute1' % side) for side in GLUTE}
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        for side, c in GLUTE.items():
            d2 = ((p.x - c.x) / 0.08) ** 2 + ((p.z - c.z) / 0.1) ** 2
            w = 0.75 * math.exp(-d2) * smooth(hips_c.y, hips_c.y + 0.06, p.y)
            if w < 0.02:
                continue
            for g in v.groups:
                g.weight *= (1 - w)
            vgs[side].add([v.index], w, 'REPLACE')
# Thigh jiggle: a bone from the middle of each thigh pointing out and back, holding the flesh of the
# upper thigh (most on the outer and back side), so each step bounces it against the leg.
THIGHS = {}
for side, full in (('L', 'Left'), ('R', 'Right')):
    a, b = bone(full + 'UpLeg'), bone(full + 'Leg')
    THIGHS[side] = (a, b)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
for side, (a, b) in THIGHS.items():
    d = b - a
    eb = arm.data.edit_bones.new('J_Sec_%s_Thigh1' % side)
    out = Vector((1 if side == 'L' else -1, 0.5, 0)).normalized()     # outward and back, level
    eb.head = arm.matrix_world.inverted() @ (a + d * 0.4)
    eb.tail = arm.matrix_world.inverted() @ (a + d * 0.4 + out * 0.08)
    eb.parent = arm.data.edit_bones[('Left' if side == 'L' else 'Right') + 'UpLeg']
    eb.use_deform = True
bpy.ops.object.mode_set(mode='OBJECT')
for o in rear:
    vgs = {side: o.vertex_groups.new(name='J_Sec_%s_Thigh1' % side) for side in THIGHS}
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        for side, (a, b) in THIGHS.items():
            d = b - a
            L = d.length
            u = d.normalized()
            t = (p - a).dot(u) / L
            off = p - (a + u * (p - a).dot(u))
            if off.length > 0.2 or not (0.0 < t < 0.9) or (p.x > 0) != (side == 'L'):
                continue
            outer = 0.6 + 0.4 * max(0.0, off.normalized().dot(Vector((1 if side == 'L' else -1, 0.6, 0)).normalized()))
            w = 0.5 * math.exp(-((t - 0.42) / 0.2) ** 2) * outer
            if w < 0.02:
                continue
            for g in v.groups:
                g.weight *= (1 - w)
            vgs[side].add([v.index], w, 'REPLACE')
print('rear jiggle bones at', {k: tuple(round(x, 3) for x in c) for k, c in GLUTE.items()})

# 3. Materials: latex body, shiny top.
latex = bpy.data.materials.new('Latex_suit')
latex.use_nodes = True
p = latex.node_tree.nodes['Principled BSDF']
p.inputs['Base Color'].default_value = (0.012, 0.012, 0.016, 1)
p.inputs['Roughness'].default_value = 0.16
p.inputs['Metallic'].default_value = 0.0
for o in body:
    for i, m in enumerate(o.data.materials):
        if not m:
            continue
        if 'Body_00_SKIN' in m.name:
            o.data.materials[i] = latex
        elif 'Onepiece' in m.name or 'Shoes' in m.name or 'CatEar' in m.name:
            for n in m.node_tree.nodes:
                if n.type == 'BSDF_PRINCIPLED' and not n.inputs['Roughness'].is_linked:
                    n.inputs['Roughness'].default_value = 0.22 if 'Onepiece' in m.name else 0.4
# Lighter hair for the Quest.
for o in body:
    if len(o.data.polygons) > 15000:
        md = o.modifiers.new('dec', 'DECIMATE')
        md.ratio = 0.5
        bpy.context.view_layer.objects.active = o
        with bpy.context.temp_override(object=o, active_object=o):
            bpy.ops.object.modifier_move_to_index(modifier='dec', index=0)
            bpy.ops.object.modifier_apply(modifier='dec')

# 4. Scuba gear from the rigged scuba suit.
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=gear_src)
new = [o for o in bpy.data.objects if o not in before]
g_arm = next(o for o in new if o.type == 'ARMATURE')


def g_bone(name):
    for b in g_arm.data.bones:
        if re.sub(r'_\d+$', '', re.sub(r'^mixamorig[:_]?', '', b.name)) == name:
            return g_arm.matrix_world @ b.head_local


g_sp2, g_head = g_bone('Spine2'), g_bone('Head')
g_neck, g_hips, g_larm = g_bone('Neck'), g_bone('Hips'), g_bone('LeftArm')
g_sw = (g_bone('LeftArm') - g_bone('RightArm')).length
sw = (bone('LeftArm') - bone('RightArm')).length
GEAR = {'Object_5': 'Spine2', 'Object_6': 'Spine2', 'Object_7': 'Head'}   # not Object_9, the white hoses (they'd cross her face)
gear = []
others = [o for o in new if o.type != 'MESH']
# The scuba diver's own body, to measure his chest before it goes.
g_body_pts = [o.matrix_world @ v.co for o in new if o.type == 'MESH' and o.name.split('__')[0] == 'Object_2'
              for v in o.data.vertices]
for o in [o for o in new if o.type == 'MESH']:
    base = o.name.split('__')[0]
    if base not in GEAR:
        bpy.data.objects.remove(o, do_unlink=True)
        continue
    mw = o.matrix_world.copy()
    o.parent = None
    o.data = o.data.copy()
    o.data.transform(mw)
    o.matrix_world = Matrix.Identity(4)
    for md in list(o.modifiers):
        o.modifiers.remove(md)
    for vg in list(o.vertex_groups):
        o.vertex_groups.remove(vg)
    if GEAR[base] == 'Spine2':
        # Drop anything well away from the torso (the dive computer on his wrist).
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if abs(v.co.x - g_sp2.x) > 0.3], context='VERTS')
        bm.to_mesh(o.data)
        bm.free()
    gear.append((o, GEAR[base], base))
for o in others:
    bpy.data.objects.remove(o, do_unlink=True)


def section(pts, z, dz=0.03):
    """Width centre, half width, front and back of a body's cross-section at height z."""
    ring = [p for p in pts if abs(p.z - z) < dz]
    xs = [p.x for p in ring]
    ys = [p.y for p in ring]
    return Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, z)), (max(xs) - min(xs)) / 2, min(ys), max(ys)


skin_pts = [o.matrix_world @ v.co for o in body if any(m and m.name == 'Latex_suit' for m in o.data.materials)
            for v in o.data.vertices]
sp2 = bone('Spine2')
h_c, h_w, h_front, h_back = section(skin_pts, sp2.z)
g_c, g_w, g_front, g_back = section(g_body_pts, g_sp2.z)
sz = (bone('Neck').z - bone('Hips').z) / (g_neck.z - g_hips.z)
sx = h_w / g_w
sy = (h_back - h_front) / (g_back - g_front)
vest_top = max(v.co.z for o, bn, base in gear if base == 'Object_5' for v in o.data.vertices)
shoulder_top = max(p.z for p in skin_pts if 0.08 < abs(p.x - h_c.x) < 0.16 and abs(p.y - h_c.y) < 0.08
                   and p.z < bone('Neck').z)
print('fit', round(sx, 2), round(sy, 2), round(sz, 2), 'vest top', round(vest_top, 3), 'her shoulders', round(shoulder_top, 3))
for o, bn, base in gear:
    if base == 'Object_5':
        # The harness wraps her chest: fitted to its width and depth (bust included).
        # Its height runs from the chest bone up to the top of her shoulders, so the straps rest on them.
        sz_vest = (shoulder_top + 0.01 - sp2.z) / (vest_top - g_sp2.z)
        t = Matrix.Translation(h_c) @ Matrix.Diagonal((sx * 1.04, sy * 1.06, sz_vest, 1)) @ Matrix.Translation(-g_c)
        o.data.transform(t)
    elif bn == 'Spine2':
        # The tank and hoses keep their shape and sit on her back where they sat on his.
        k = (sx + sz) / 2
        t = (Matrix.Translation(Vector((h_c.x, h_back, sp2.z))) @ Matrix.Scale(k, 4)
             @ Matrix.Translation(-Vector((g_c.x, g_back, g_sp2.z))))
        o.data.transform(t)
# The mask: pushed up onto the forehead, a little bigger to suit her anime head.
head = bone('Head')
face_top = max((o.matrix_world @ v.co).z for o in body for v in o.data.vertices
               if any(m and 'Face_00_SKIN' in m.name for m in o.data.materials))
face_front = min((o.matrix_world @ v.co).y for o in body for v in o.data.vertices
                 if any(m and 'Face_00_SKIN' in m.name for m in o.data.materials))
for o, bn, base in gear:
    if base == 'Object_7':
        c = sum((v.co for v in o.data.vertices), Vector()) / len(o.data.vertices)
        t = (Matrix.Translation(Vector((0, face_front + 0.03, face_top - 0.05)))
             @ Matrix.Rotation(math.radians(-65), 4, 'X') @ Matrix.Scale(1.35, 4) @ Matrix.Translation(-c))
        o.data.transform(t)

# Rigid skinning: each piece follows one bone.
for o, bn, base in gear:
    vg = o.vertex_groups.new(name=bn)
    vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    md = o.modifiers.new('Armature', 'ARMATURE')
    md.object = arm
    o.parent = arm
    o.matrix_parent_inverse = arm.matrix_world.inverted()
    o.name = 'Gear_' + base

# 4b. The vest sits on her, not in her. It was sized from her skin, but her top stands further out
#     over the (fuller) bust, so the vest's sides and straps sank into it. Every vest point inside
#     her (skin or top) is pushed out to just above her surface, its neighbours within a centimetre
#     (the other face of the same panel) going with it so the panels keep their thickness; and where
#     the vest lies on her bust it takes the bust's jiggle bones, so the straps bounce with it.
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
S_VERTS, S_POLYS, S_W = [], [], []        # her surface (skin and top), with each point's bust weights
for o in body:
    mats = [m.name if m else '' for m in o.data.materials]
    names = {g.index: g.name for g in o.vertex_groups}
    seen = {}
    for poly in o.data.polygons:
        mn = mats[poly.material_index] if poly.material_index < len(mats) else ''
        if not (mn == 'Latex_suit' or 'Onepiece' in mn):
            continue
        ids = []
        for vi in poly.vertices:
            if vi not in seen:
                seen[vi] = len(S_VERTS)
                v = o.data.vertices[vi]
                S_VERTS.append(o.matrix_world @ v.co)
                tw = sum(g.weight for g in v.groups) or 1.0
                S_W.append({names[g.group]: g.weight / tw for g in v.groups
                            if 'Bust' in names.get(g.group, '') and g.weight > 0.0})
            ids.append(seen[vi])
        S_POLYS.append(ids)
surface = BVHTree.FromPolygons(S_VERTS, S_POLYS)
s_kd = KDTree(len(S_VERTS))
for i, q in enumerate(S_VERTS):
    s_kd.insert(q, i)
s_kd.balance()
# Which way is out: her chest's normal should point forward (-Y).
_l, _n, _i, _d = surface.find_nearest(bone('Spine2') + Vector((0, -0.4, 0)))
OUT = 1.0 if _n.y < 0 else -1.0
GAP, KEEP, FADE = 0.006, 0.012, 0.03


def signed(p):
    loc, n, _, _ = surface.find_nearest(p, 0.15)
    if loc is None:
        return None, None, 1.0
    n = n * OUT
    return loc, n, (p - loc).dot(n)


def pieces(o):
    """The vest's separate hard pieces: vertices joined by an edge or lying on top of each other
    (the import splits a buckle into loose triangles)."""
    vs = o.data.vertices
    parent = list(range(len(vs)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def union(i, j):
        ri, rj = find(i), find(j)
        if ri != rj:
            parent[ri] = rj
    for e in o.data.edges:
        union(e.vertices[0], e.vertices[1])
    kd = KDTree(len(vs))
    for i, v in enumerate(vs):
        kd.insert(v.co, i)
    kd.balance()
    for i, v in enumerate(vs):
        for _co, j, _d in kd.find_range(v.co, 0.002):
            union(i, j)
    out = {}
    for i in range(len(vs)):
        out.setdefault(find(i), []).append(i)
    return list(out.values()), kd


def mid_fade(x):
    """Nothing near her middle follows one side of the bust (the buckle over the cleavage)."""
    t = min(max((abs(x) - 0.04) / 0.07, 0.0), 1.0)
    return t * t * (3 - 2 * t)


SMALL = 0.06          # pieces smaller than this (buckles, clips, rings) move as one
STRAP = 0.85          # straps pulled tight over the bust swing a little less than it does
for o, bn, base in gear:
    if base not in ('Object_5', 'Object_6'):
        continue
    vs = o.data.vertices
    parts, kd = pieces(o)
    small = {}
    for pc in parts:
        pts = [vs[i].co for i in pc]
        lo = Vector(map(min, *pts)) if len(pts) > 1 else pts[0]
        hi = Vector(map(max, *pts)) if len(pts) > 1 else pts[0]
        if (hi - lo).length < SMALL:
            for i in pc:
                small[i] = pc
    push = []
    for v in vs:
        loc, n, d = signed(v.co)
        push.append(n * (GAP - d) if loc is not None and d < GAP else Vector())
    new = []
    for i, v in enumerate(vs):
        best = Vector()
        if i in small:                       # a hard piece: one push for all of it
            for j in small[i]:
                if push[j].length > best.length:
                    best = push[j]
        else:
            for co, j, dist in kd.find_range(v.co, KEEP + FADE):
                f = 1.0 if dist <= KEEP else 1.0 - (dist - KEEP) / FADE
                cand = push[j] * f
                if cand.length > best.length:
                    best = cand
        new.append(v.co + best)
    moved = sum(1 for i, v in enumerate(vs) if (new[i] - v.co).length > 1e-4)
    for i, v in enumerate(vs):
        v.co = new[i]
    # Anything of the soft panels still inside (where the fade fell short) goes straight out.
    left = 0
    for i, v in enumerate(vs):
        if i in small:
            continue
        loc, n, d = signed(v.co)
        if loc is not None and d < GAP * 0.5:
            v.co = loc + n * GAP
            left += 1
    # Weights: where the vest lies on her bust, the bust's jiggle bones (not near her middle);
    # a hard piece takes the average of its points, so it moves as one.
    want = []
    for i, v in enumerate(vs):
        loc, n, d = signed(v.co)
        if loc is None or d > KEEP + FADE:
            want.append({})
            continue
        f = (1.0 if d <= KEEP else 1.0 - (d - KEEP) / FADE) * mid_fade(v.co.x) * STRAP
        _co, j, _dist = s_kd.find(loc)
        want.append({k: w * f for k, w in S_W[j].items()})
    done = set()
    for i in range(len(vs)):
        if i in small and i not in done:
            pc = small[i]
            avg = {}
            for j in pc:
                for k, w in want[j].items():
                    avg[k] = avg.get(k, 0.0) + w / len(pc)
            for j in pc:
                want[j] = avg
                done.add(j)
    groups = {g.name: g for g in o.vertex_groups}
    rigid = groups[bn]
    sprung = 0
    for i, ws in enumerate(want):
        tot = sum(ws.values())
        if tot < 0.02:
            continue
        for k, w in ws.items():
            if k not in groups:
                groups[k] = o.vertex_groups.new(name=k)
            groups[k].add([i], w, 'REPLACE')
        rigid.add([i], max(0.0, 1.0 - tot), 'REPLACE')
        sprung += 1
    print('vest fit', base, 'pieces', len(parts), 'hard', len({id(p) for p in small.values()}), 'pushed out', moved,
          'still inside after', left, 'on the bust springs', sprung)

for img in bpy.data.images:
    if img.size[0] > 1024:
        img.scale(1024, max(1, int(img.size[1] * 1024 / img.size[0])))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_skins=True, export_animations=False,
                          export_morph=False, export_yup=True, use_selection=False)
print('built', dst, 'faces', sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH'))
