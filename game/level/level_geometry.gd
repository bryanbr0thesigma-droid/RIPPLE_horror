class_name LevelGeometry
extends RefCounted
## Helpers that build gray-box poolrooms geometry from rectangles: tiled boxes, walls with door
## gaps, pools with water, walkway slabs, ladders and grab rims.

const WALL_T := 0.3
## Pool walls stop just under walkway level, so where they run under a walkway slab the two tops
## aren't in the same plane (that flickered). Room walls start just under the floor for the same reason.
const RIM_TOP := -0.006
const WALL_SINK := 0.02
const CLIMBABLE := preload("res://addons/godot-xr-tools/objects/climbable.gd")
const WATER_SHADER := preload("res://core/water.gdshader")
const WALL_LAMP := preload("res://assets/props/wall_lamp.glb")
const CHAIR := preload("res://assets/props/chair.glb")
const WET_SIGN := preload("res://assets/props/wet_floor_sign.glb")
const PIPES := preload("res://assets/props/pipes_kit.glb")
const POOL_LADDER := preload("res://assets/props/pool_ladder.glb")

const L_WORLD := 1
const L_DYNAMIC := 1 << 1
const L_ITEMS := 1 << 2
const L_AVATARS := 1 << 5
const L_CREATURE := 1 << 6
const L_TRIGGERS := 1 << 8
const L_GRAB := 1 << 18
const L_PLAYER := 1 << 19

var root: Node3D
var geo: Node3D
var water_root: Node3D
var mat_white: StandardMaterial3D
var mat_blue: StandardMaterial3D
var mat_ceiling: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_rail: StandardMaterial3D
var water_mat: ShaderMaterial
var mineral_mat: ShaderMaterial
## Pool floors for the creature's navigation mesh, and obstacles standing in pools.
var nav_rects: Array[Rect2] = []
var nav_obstacles: Array[Rect2] = []
var _pipe_meshes := {}


func _init(level_root: Node3D) -> void:
	root = level_root
	geo = Node3D.new()
	geo.name = "Geometry"
	root.add_child(geo)
	water_root = Node3D.new()
	water_root.name = "Water"
	root.add_child(water_root)
	mat_white = _tiles("res://assets/textures/tiles_white_color.jpg", "res://assets/textures/tiles_white_normal.jpg", 0.5, Color(0.95, 0.96, 0.94))
	mat_blue = _tiles("res://assets/textures/tiles_blue_color.jpg", "res://assets/textures/tiles_blue_normal.jpg", 0.6, Color(1, 1, 1))
	mat_ceiling = StandardMaterial3D.new()
	mat_ceiling.albedo_color = Color(0.55, 0.58, 0.58)
	mat_ceiling.roughness = 0.9
	mat_metal = StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.45, 0.47, 0.48)
	mat_metal.metallic = 0.7
	mat_metal.roughness = 0.4
	mat_rail = StandardMaterial3D.new()
	mat_rail.albedo_color = Color(0.75, 0.77, 0.78)
	mat_rail.metallic = 0.9
	mat_rail.roughness = 0.25
	water_mat = ShaderMaterial.new()
	water_mat.shader = WATER_SHADER
	water_mat.set_shader_parameter("water_color", Color(0.32, 0.62, 0.68, 0.45))
	mineral_mat = ShaderMaterial.new()
	mineral_mat.shader = WATER_SHADER
	mineral_mat.set_shader_parameter("water_color", Color(0.05, 0.13, 0.15, 0.6))
	mineral_mat.set_shader_parameter("glow_color", Color(0.3, 0.95, 0.8))   # a soft teal glow
	mineral_mat.set_shader_parameter("glow", 0.35)
	mineral_mat.render_priority = 1   # always drawn over the pool's own surface


func _tiles(color_path: String, normal_path: String, scale: float, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(color_path)
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(normal_path)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = 0.3
	return m


## A solid box from min to max corner.
func block(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, mat: Material, layer := L_WORLD, parent: Node = null) -> StaticBody3D:
	var size := Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0))
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return null
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	(parent if parent else geo).add_child(body)
	return body


## Solid spans of [lo, hi] once the gaps are cut out.
static func spans(lo: float, hi: float, gaps: Array) -> Array:
	var out := []
	var cur := lo
	var sorted := gaps.duplicate()
	sorted.sort_custom(func(a, b): return a[0] < b[0])
	for g in sorted:
		if g[0] > cur:
			out.append([cur, minf(g[0], hi)])
		cur = maxf(cur, g[1])
	if cur < hi:
		out.append([cur, hi])
	return out


## Walls around a rectangle (outside it), from y0 to y1, with door gaps.
## doors: {"n": [[a, b, top], ...], "s": ..., "w": ..., "e": ...}. n = the -z edge, s = +z, w = -x, e = +x.
func walls(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, doors := {}, mat: Material = null) -> void:
	var m := mat if mat else mat_white
	var t := WALL_T
	for side in ["n", "s", "w", "e"]:
		var d: Array = doors.get(side, [])
		var along_x: bool = side == "n" or side == "s"
		var lo := (x0 - t) if along_x else z0
		var hi := (x1 + t) if along_x else z1
		for sp in spans(lo, hi, d):
			_wall_piece(side, sp[0], sp[1], y0 - WALL_SINK, y1, x0, x1, z0, z1, m)
		for g in d:
			var top: float = g[2] if g.size() > 2 else 2.4
			if y0 + top < y1:
				_wall_piece(side, g[0], g[1], y0 + top, y1, x0, x1, z0, z1, m)


func _wall_piece(side: String, a: float, b: float, y0: float, y1: float, x0: float, x1: float, z0: float, z1: float, m: Material) -> void:
	var t := WALL_T
	match side:
		"n": block(a, b, y0, y1, z0 - t, z0, m)
		"s": block(a, b, y0, y1, z1, z1 + t, m)
		"w": block(x0 - t, x0, y0, y1, a, b, m)
		"e": block(x1, x1 + t, y0, y1, a, b, m)


## Floor and ceiling slabs over a rectangle.
## Floors are thick and solid, so nothing can slip through them. Use `thickness` 0.2 for a bridge
## over water.
func floor_slab(x0: float, x1: float, z0: float, z1: float, top := 0.0, mat: Material = null, thickness := 1.5) -> void:
	block(x0, x1, top - thickness, top, z0, z1, mat if mat else mat_white)


func ceiling(x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	block(x0 - WALL_T, x1 + WALL_T, y, y + 0.2, z0 - WALL_T, z1 + WALL_T, mat_ceiling)


## A pool: tiled floor, walls up to the walkway (y = 0) with gaps where water connects,
## grab rims along the top edge for VR climbing, a water volume and a water surface.
func pool(x0: float, x1: float, z0: float, z1: float, floor_y: float, surface_y: float, gaps := {}, rims := true) -> WaterVolume:
	block(x0, x1, floor_y - 1.5, floor_y, z0, z1, mat_blue)
	var t := WALL_T
	for side in ["n", "s", "w", "e"]:
		if gaps.get(side, null) is String:   # "open": no wall at all on this side
			continue
		var d: Array = gaps.get(side, [])
		var along_x: bool = side == "n" or side == "s"
		var lo := x0 if along_x else z0
		var hi := x1 if along_x else z1
		for sp in spans(lo, hi, d):
			match side:
				"n": block(sp[0], sp[1], floor_y - 0.3, RIM_TOP, z0 - t, z0, mat_blue)
				"s": block(sp[0], sp[1], floor_y - 0.3, RIM_TOP, z1, z1 + t, mat_blue)
				"w": block(x0 - t, x0, floor_y - 0.3, RIM_TOP, sp[0], sp[1], mat_blue)
				"e": block(x1, x1 + t, floor_y - 0.3, RIM_TOP, sp[0], sp[1], mat_blue)
			if rims:
				match side:
					"n": grab_rim(Vector3(sp[0], 0.0, z0), Vector3(sp[1], 0.0, z0))
					"s": grab_rim(Vector3(sp[0], 0.0, z1), Vector3(sp[1], 0.0, z1))
					"w": grab_rim(Vector3(x0, 0.0, sp[0]), Vector3(x0, 0.0, sp[1]))
					"e": grab_rim(Vector3(x1, 0.0, sp[0]), Vector3(x1, 0.0, sp[1]))
	var r := Rect2(x0, z0, x1 - x0, z1 - z0)
	nav_rects.append(r)
	return water(r, surface_y, floor_y, false)


func water(r: Rect2, surface_y: float, floor_y: float, is_mineral: bool) -> WaterVolume:
	var w := WaterVolume.make(r, surface_y, floor_y, is_mineral)
	w.name = ("Mineral" if is_mineral else "Pool") + str(water_root.get_child_count())
	water_root.add_child(w)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = r.size
	mi.mesh = pm
	mi.material_override = mineral_mat if is_mineral else water_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(r.position.x + r.size.x * 0.5, surface_y + (0.015 if is_mineral else 0.0), r.position.y + r.size.y * 0.5)
	if is_mineral:     # its glow lights the edges and whoever wades in it, faintly
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.35, 0.95, 0.8)
		glow.light_energy = 0.45
		glow.omni_range = maxf(r.size.x, r.size.y) * 0.75
		glow.omni_attenuation = 1.6
		glow.shadow_enabled = false
		glow.position = Vector3(mi.position.x, surface_y + 0.3, mi.position.z)
		water_root.add_child(glow)
	w.add_child(mi)
	return w


## A tiled pillar standing on a pool floor, with its top at walkway level. Platforms and beams.
func pillar(x0: float, x1: float, z0: float, z1: float, floor_y: float, top := 0.0, rims := true) -> void:
	block(x0, x1, floor_y - 0.3, top, z0, z1, mat_white)
	nav_obstacles.append(Rect2(x0, z0, x1 - x0, z1 - z0))
	if rims:
		grab_rim(Vector3(x0, top, z0), Vector3(x1, top, z0))
		grab_rim(Vector3(x0, top, z1), Vector3(x1, top, z1))
		grab_rim(Vector3(x0, top, z0), Vector3(x0, top, z1))
		grab_rim(Vector3(x1, top, z0), Vector3(x1, top, z1))


## A grab-only edge (VR hands can grab it to climb; it doesn't block walking).
func grab_rim(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var body := StaticBody3D.new()
	body.set_script(CLIMBABLE)
	body.collision_layer = L_GRAB
	body.collision_mask = 0
	body.position = (a + b) * 0.5
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(length + 0.1, 0.14, 0.14) if absf(a.z - b.z) < 0.01 else Vector3(0.14, 0.14, length + 0.1)
	cs.shape = sh
	body.add_child(cs)
	geo.add_child(body)


## A pool ladder against a wall: rails (solid) and rungs (grab only for VR; desktop climbs inside its trigger).
## `out` points from the wall toward the open water.
func ladder(base: Vector3, out: Vector3, y_top: float) -> Area3D:
	var side := Vector3(out.z, 0, -out.x).normalized()
	var height := y_top - base.y
	# The approved pool ladder (CC0, plaggy), sized so its rails rise half a metre over the edge.
	var model: Node3D = POOL_LADDER.instantiate()
	var k := (height + 0.5) / 1.13
	# Facing the pool, its handrails curving back over the edge onto the deck.
	model.transform = Transform3D(Basis.looking_at(-out, Vector3.UP).scaled(Vector3.ONE * k), base + out * 0.16)
	geo.add_child(model)
	var climb := StaticBody3D.new()
	climb.set_script(CLIMBABLE)
	climb.collision_layer = L_GRAB
	climb.collision_mask = 0
	climb.position = base + out * 0.12 + Vector3(0, height * 0.5 + 0.3, 0)
	var ccs := CollisionShape3D.new()
	var csh := BoxShape3D.new()
	csh.size = (side.abs() * 0.5 + out.abs() * 0.08 + Vector3(0, height + 0.6, 0))
	ccs.shape = csh
	climb.add_child(ccs)
	geo.add_child(climb)
	var area := Area3D.new()
	area.add_to_group("ladder")
	area.collision_layer = L_TRIGGERS
	area.collision_mask = 0
	area.position = base + out * 0.35 + Vector3(0, height * 0.5 + 0.4, 0)
	var acs := CollisionShape3D.new()
	var ash := BoxShape3D.new()
	ash.size = side.abs() * 0.8 + out.abs() * 0.7 + Vector3(0, height + 1.2, 0)
	acs.shape = ash
	area.add_child(acs)
	area.set_meta("out", out)
	geo.add_child(area)
	return area


## A ceiling light fitting with a real light. Returns the light so it can be switched with power.
## A glowing ceiling fitting with no light of its own (real lights are kept few, for the Quest).
func fitting(pos: Vector3, color := Color(1.0, 0.95, 0.85)) -> MeshInstance3D:
	var f := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.06, 0.25)
	f.mesh = bm
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.9, 0.9, 0.85)
	em.emission_enabled = true
	em.emission = color
	em.emission_energy_multiplier = 1.5
	f.material_override = em
	f.position = pos + Vector3(0, 0.1, 0)
	geo.add_child(f)
	return f


func light(pos: Vector3, energy := 1.4, rng := 11.0, color := Color(1.0, 0.95, 0.85), with_fitting := true) -> OmniLight3D:
	if not with_fitting:
		var bare := OmniLight3D.new()
		bare.position = pos
		bare.light_color = color
		bare.light_energy = energy
		bare.omni_range = rng
		bare.omni_attenuation = 1.2
		bare.shadow_enabled = false
		root.get_node("Lights").add_child(bare)
		return bare
	var fitting := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.06, 0.25)
	fitting.mesh = bm
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.9, 0.9, 0.85)
	em.emission_enabled = true
	em.emission = color
	em.emission_energy_multiplier = 1.5
	fitting.material_override = em
	fitting.position = pos + Vector3(0, 0.1, 0)
	geo.add_child(fitting)
	var l := OmniLight3D.new()
	l.position = pos - Vector3(0, 0.2, 0)
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	l.set_meta("fitting", fitting)
	root.get_node("Lights").add_child(l)
	return l


func plaque(text: String, pos: Vector3, facing_y_deg: float, size := 0.006) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = size
	l.position = pos
	l.rotation_degrees = Vector3(0, facing_y_deg, 0)
	l.modulate = Color(0.12, 0.13, 0.14)
	l.outline_size = 0
	l.font_size = 48
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.width = 900
	root.add_child(l)
	return l


# --- Props (Poly Haven, CC0) ---------------------------------------------------------------------

## A caged industrial lamp on a wall, with its light just in front. normal points into the room.
func wall_lamp(pos: Vector3, normal: Vector3, energy := 1.2, rng := 9.0, color := Color(1.0, 0.9, 0.75)) -> OmniLight3D:
	var lamp: Node3D = WALL_LAMP.instantiate()
	geo.add_child(lamp)
	lamp.transform = Transform3D(_facing(normal), pos)
	return light(pos + normal * 0.35 + Vector3.DOWN * 0.1, energy, rng, color, false)


## A plastic chair standing on the floor, turned to face yaw (degrees).
func chair(pos: Vector3, yaw_deg: float) -> void:
	_solid_prop(CHAIR, pos, yaw_deg, Vector3(0.6, 0.85, 0.6))


## A yellow wet floor sign.
func wet_sign(pos: Vector3, yaw_deg: float) -> void:
	_solid_prop(WET_SIGN, pos, yaw_deg, Vector3(0.3, 0.63, 0.34))


func _solid_prop(scene: PackedScene, pos: Vector3, yaw_deg: float, box: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = L_WORLD
	body.collision_mask = 0
	geo.add_child(body)
	body.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)
	body.add_child(scene.instantiate())
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box
	cs.shape = sh
	cs.position = Vector3(0, box.y * 0.5, 0)
	body.add_child(cs)


## A pipe along a wall from a to b (same height), held by brackets every 2 m. normal points into
## the room; the pipe's axis is 10 cm off the wall. One draw call per run.
func pipe_run(a: Vector3, b: Vector3, normal: Vector3, thin := false) -> void:
	var d := (b - a)
	var length := d.length()
	if length < 0.05:
		return
	d = d / length
	var n := normal.normalized()
	var axis := a + n * 0.1
	var pipe_basis: Basis
	if thin:
		pipe_basis = Basis(d, n.cross(d), n)          # the thin piece runs along its X, centred
	else:
		pipe_basis = Basis(d.cross(n), d, n)          # the big piece runs along its Y from 0 to 2
	var count := int(ceil(length / 2.0))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _pipe_mesh("pipe_thin_200cm_metal" if thin else "pipe_200cm_metal")
	mm.instance_count = count
	for i in count:
		var seg := minf(2.0, length - i * 2.0)
		var k := seg / 2.0
		var start := axis + d * (i * 2.0)
		var sb := pipe_basis
		if thin:
			sb = Basis(pipe_basis.x * k, pipe_basis.y, pipe_basis.z)
			mm.set_instance_transform(i, Transform3D(sb, start + d * seg * 0.5))
		else:
			sb = Basis(pipe_basis.x, pipe_basis.y * k, pipe_basis.z)
			mm.set_instance_transform(i, Transform3D(sb, start))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geo.add_child(mmi)
	var brackets := MultiMesh.new()
	brackets.transform_format = MultiMesh.TRANSFORM_3D
	brackets.mesh = _pipe_mesh("pipe_thin_support_metal" if thin else "pipe_support_metal")
	var nb := int(floor(length / 2.0)) + 1
	brackets.instance_count = nb
	for i in nb:
		var t := minf(0.3 + i * 2.0, length - 0.3)
		brackets.set_instance_transform(i, Transform3D(pipe_basis, axis + d * t))
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = brackets
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geo.add_child(bmi)


## A vertical pipe from the floor to the ceiling against a wall, with a hand valve at valve_y.
func pipe_riser(base: Vector3, top_y: float, normal: Vector3, valve_y := -1.0) -> void:
	var n := normal.normalized()
	var side := Vector3.UP.cross(n)
	var b := Basis(side, Vector3.UP, n)
	var axis := base + n * 0.1
	var parts: Array = []   # [from, to]
	if valve_y > base.y:
		parts = [[base.y, valve_y], [valve_y + 0.4, top_y]]
		var valve := MeshInstance3D.new()
		valve.mesh = _pipe_mesh("pipe_valve_small_1_metal")
		valve.transform = Transform3D(b, Vector3(axis.x, valve_y, axis.z))
		geo.add_child(valve)
	else:
		parts = [[base.y, top_y]]
	for pr in parts:
		var y := float(pr[0])
		while y < float(pr[1]) - 0.01:
			var seg := minf(2.0, float(pr[1]) - y)
			var mi := MeshInstance3D.new()
			mi.mesh = _pipe_mesh("pipe_200cm_metal")
			mi.transform = Transform3D(Basis(b.x, b.y * (seg / 2.0), b.z), Vector3(axis.x, y, axis.z))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			geo.add_child(mi)
			y += seg
	for y in [base.y + 0.6, top_y - 0.4]:
		var br := MeshInstance3D.new()
		br.mesh = _pipe_mesh("pipe_support_metal")
		br.transform = Transform3D(b, Vector3(axis.x, y, axis.z))
		geo.add_child(br)


func _pipe_mesh(piece: String) -> Mesh:
	if _pipe_meshes.is_empty():
		var kit: Node3D = PIPES.instantiate()
		for mi: MeshInstance3D in kit.find_children("*", "MeshInstance3D", true, false):
			_pipe_meshes[String(mi.name)] = mi.mesh
		kit.free()
	return _pipe_meshes.get(piece)


## A basis whose +Z points along normal (props are modelled sticking out along +Z).
func _facing(normal: Vector3) -> Basis:
	var z := normal.normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Basis(x, z.cross(x), z)
