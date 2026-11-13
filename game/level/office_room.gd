class_name OfficeRoom
extends RefCounted
## The office from the first-boot tape, shared by the cutscene and the multiplayer lobby: 6 m by
## 6.4 m with carpet, wallpaper and a drop ceiling (ambientCG, CC0), a frosted window in the east
## wall lit by the setting sun (beams, dust, warm light), office furniture (Poly Haven, CC0), and the
## TV set: a CRT on a cabinet with a VCR, a curved screen the tape plays on, and subtitles.

const TAPE := preload("res://assets/video/falcon_tape.ogv")
const OFFICE := "res://assets/intro/office/"
const LABEL_TEX := preload("res://assets/intro/tape_label.png")
const SPINE_TEX := preload("res://assets/intro/tape_spine.png")
const LABEL_TEX_08 := preload("res://assets/intro/tape_label_08.png")     # tape 08-E, "Going In, Coming Out"
const SPINE_TEX_08 := preload("res://assets/intro/tape_spine_08.png")

const ROOM := Rect2(-3.0, -3.4, 6.0, 6.4)             # x, z, width, depth
const DOOR_Z := 3.0
const CABINET := Vector3(0.0, 0.0, -3.10)
const TV := Vector3(-0.30, 0.83, -3.12)
const TV_SCALE := 1.2                                 # a 24-inch set
const VCR := Vector3(0.36, 0.83, -3.0)
const SCREEN := TV + Vector3(0.0, 0.32, 0.2167) * TV_SCALE    # the apex of the curved glass, just in front
const SCREEN_SIZE := Vector2(0.364, 0.272) * TV_SCALE
const SCREEN_CURVE := Vector2(0.80 / TV_SCALE, 6.0 / (TV_SCALE * TV_SCALE * TV_SCALE))   # depth = a*r^2 - b*x^2*y^2 (flatter at the corners)
# The window: frosted, in the east wall, lit warm by the low sun (no view out).
const WINDOW := Vector3(3.0, 1.45, -1.2)
const WINDOW_SIZE := Vector2(2.0, 1.3)                # along the wall (z), height
const SUN := Color(1.0, 0.48, 0.22)                   # sunset
const SLOT := VCR + Vector3(-0.026, 0.070, 0.1158)    # the tape door
const PLAY := VCR + Vector3(0.096, 0.032, 0.1441)     # the play button
const LED := VCR + Vector3(0.165, 0.074, 0.1635)
const SIDE_TABLE := Vector3(-1.25, 0.0, 2.45)
const TAPE_REST := Vector3(-1.23, 0.551, 2.45)
const CHAIR := Vector3(-0.30, 0.0, -1.95)


static func build_room(root: Node3D, G: LevelGeometry) -> OmniLight3D:
	# An office, 6 m by 6.4 m: carpet, wallpaper, a drop ceiling, dark wood skirting, a door in the
	# south wall to a short hallway, and a frosted window in the east wall lit by the setting sun.
	var carpet := office_mat("carpet", 1.0, Color(0.78, 0.8, 0.86), 0.95)
	var wall := office_mat("wall", 0.7, Color(0.86, 0.78, 0.62), 0.85)      # old beige
	var ceil := office_mat("ceiling", 0.83, Color(0.92, 0.9, 0.86), 0.9)
	G.mat_ceiling = ceil
	var x0 := ROOM.position.x
	var x1 := ROOM.end.x
	var z0 := ROOM.position.y
	var z1 := ROOM.end.y
	G.floor_slab(x0, x1, z0, z1, 0.0, carpet)
	G.walls(x0, x1, z0, z1, 0.0, 2.6, {"s": [[-0.5, 0.5, 2.1]]}, wall)
	G.ceiling(x0, x1, z0, z1, 2.6)
	G.floor_slab(-0.8, 0.8, z1, z1 + 2.4, 0.0, carpet)
	G.walls(-0.8, 0.8, z1 + 0.3, z1 + 2.4, 0.0, 2.6, {"n": [[-0.8, 0.8, 2.6]]}, wall)
	G.ceiling(-0.8, 0.8, z1, z1 + 2.4, 2.6)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.14, 0.09)
	wood.roughness = 0.6
	for sk in [[x0, x1, z0, z0 + 0.02], [x0, x0 + 0.02, z0, z1], [x1 - 0.02, x1, z0, z1], [x0, -0.5, z1 - 0.02, z1], [0.5, x1, z1 - 0.02, z1]]:
		G.block(sk[0], sk[1], 0.0, 0.09, sk[2], sk[3], wood)
	for f in [[-0.56, -0.5], [0.5, 0.56]]:
		G.block(f[0], f[1], 0.0, 2.16, z1 - 0.03, z1 + 0.03, wood)
	G.block(-0.56, 0.56, 2.1, 2.16, z1 - 0.03, z1 + 0.03, wood)
	_window(root, G, wood)
	# The tube light is off (just its fitting); a dim one out in the hallway.
	var room_light := G.light(Vector3(0.0, 2.45, -0.8), 0.0, 6.0, Color(0.85, 0.92, 1.0), false)
	var off := StandardMaterial3D.new()
	off.albedo_color = Color(0.7, 0.7, 0.68)
	G.block(-0.6, 0.6, 2.52, 2.58, -0.925, -0.675, off)
	G.light(Vector3(0.0, 2.45, z1 + 1.6), 0.16, 3.0, Color(0.85, 0.92, 1.0))
	return room_light


static func office_mat(name: String, scale: float, tint: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(OFFICE + name + "_color.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(OFFICE + name + "_normal.jpg")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = rough
	return m


## The frosted window: a sunset glow (deep red-orange at the top, gold where the low sun is), a
## wooden frame and half-open blinds, beams of light slanting through the blinds into the room with
## dust drifting in them, and the light it throws: a warm wash and a hot patch across the far side.
static func _window(root: Node3D, G: LevelGeometry, wood: StandardMaterial3D) -> void:
	var glass := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = WINDOW_SIZE
	glass.mesh = q
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.28, 0.25))                # top: red, the sky above the sun
	grad.add_point(0.55, Color(1.0, 0.52, 0.2))               # orange
	grad.set_color(grad.get_point_count() - 1, Color(1.0, 0.84, 0.5))   # bottom: gold, the sun
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_texture = gt
	gm.albedo_color = Color(1.8, 1.6, 1.5)                    # bright enough to bloom
	glass.material_override = gm
	glass.position = WINDOW - Vector3(0.012, 0, 0)
	glass.rotation_degrees.y = -90.0                          # faces into the room (-X)
	root.add_child(glass)
	var hw := WINDOW_SIZE.x * 0.5
	var hh := WINDOW_SIZE.y * 0.5
	var fx0 := WINDOW.x - 0.05
	var fx1 := WINDOW.x - 0.005
	G.block(fx0, fx1, WINDOW.y - hh - 0.05, WINDOW.y - hh, WINDOW.z - hw - 0.05, WINDOW.z + hw + 0.05, wood)
	G.block(fx0, fx1, WINDOW.y + hh, WINDOW.y + hh + 0.05, WINDOW.z - hw - 0.05, WINDOW.z + hw + 0.05, wood)
	G.block(fx0, fx1, WINDOW.y - hh, WINDOW.y + hh, WINDOW.z - hw - 0.05, WINDOW.z - hw, wood)
	G.block(fx0, fx1, WINDOW.y - hh, WINDOW.y + hh, WINDOW.z + hw, WINDOW.z + hw + 0.05, wood)
	G.block(fx0, fx1, WINDOW.y - hh, WINDOW.y + hh, WINDOW.z - 0.02, WINDOW.z + 0.02, wood)
	G.block(WINDOW.x - 0.18, WINDOW.x - 0.005, WINDOW.y - hh - 0.08, WINDOW.y - hh - 0.05, WINDOW.z - hw - 0.1, WINDOW.z + hw + 0.1, wood)
	# Venetian blinds over the top half, slats tilted, dark against the glow.
	var slat_mat := StandardMaterial3D.new()
	slat_mat.albedo_color = Color(0.75, 0.7, 0.6)
	slat_mat.roughness = 0.7
	var slat := BoxMesh.new()
	slat.size = Vector3(0.05, 0.003, WINDOW_SIZE.x)
	for i in 17:
		var m := MeshInstance3D.new()
		m.mesh = slat
		m.material_override = slat_mat
		m.position = Vector3(WINDOW.x - 0.08, WINDOW.y + hh - 0.02 - i * 0.04, WINDOW.z)
		m.rotation_degrees.z = 35.0
		root.add_child(m)
	G.block(WINDOW.x - 0.11, WINDOW.x - 0.05, WINDOW.y + hh + 0.01, WINDOW.y + hh + 0.05, WINDOW.z - hw, WINDOW.z + hw, slat_mat)
	# Beams of light slanting down through the window into the room (the sun is low: nearly level).
	var beam_grad := Gradient.new()
	beam_grad.set_color(0, Color(1.0, 0.62, 0.3, 0.32))
	beam_grad.set_color(1, Color(1.0, 0.45, 0.2, 0.0))
	var bt := GradientTexture2D.new()
	bt.gradient = beam_grad
	bt.fill_from = Vector2(0.0, 0.5)
	bt.fill_to = Vector2(1.0, 0.5)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.no_depth_test = false
	bm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	bm.albedo_texture = bt
	var dir := Vector3(-1.0, -0.28, 0.12).normalized()       # into the room, down, a little south
	var length := 4.6
	for k in 7:
		var start := WINDOW + Vector3(-0.03, -hh + 0.15 + k * 0.17, -hw + 0.2 + fmod(k * 0.53, 1.0) * (WINDOW_SIZE.x - 0.4))
		for twist in [0.0, 90.0]:
			var beam := MeshInstance3D.new()
			var bq := QuadMesh.new()
			bq.size = Vector2(length, 0.16 + 0.05 * (k % 3))
			beam.mesh = bq
			beam.material_override = bm
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var basis := Basis.looking_at(dir, Vector3.UP)
			# The quad's long side (x) along the beam; turned about it so the two quads cross.
			beam.basis = basis * Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, deg_to_rad(twist))
			beam.position = start + dir * (length * 0.5)
			root.add_child(beam)
	# Dust drifting in the light.
	var dust := CPUParticles3D.new()
	dust.amount = 80
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.6, 0.6, 0.9)
	dust.position = WINDOW + dir * 1.8
	dust.gravity = Vector3(0, -0.004, 0)
	dust.initial_velocity_min = 0.005
	dust.initial_velocity_max = 0.03
	dust.direction = Vector3(0, 1, 0)
	dust.spread = 180.0
	var dq := QuadMesh.new()
	dq.size = Vector2(0.006, 0.006)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.albedo_color = Color(1.0, 0.75, 0.45, 0.7)
	dq.material = dm
	dust.mesh = dq
	root.add_child(dust)
	# The light: a warm wash from the window, and the low sun itself throwing a hot band across
	# the room onto the far wall and the desk.
	var wash := OmniLight3D.new()
	wash.light_color = SUN
	wash.light_energy = 1.4
	wash.omni_range = 5.0
	wash.omni_attenuation = 1.1
	wash.position = WINDOW + Vector3(-0.5, -0.2, 0.0)
	root.add_child(wash)
	var sun := SpotLight3D.new()
	sun.light_color = Color(1.0, 0.55, 0.25)
	sun.light_energy = 5.0
	sun.spot_range = 9.0
	sun.spot_angle = 30.0
	sun.spot_attenuation = 0.6
	sun.position = WINDOW + Vector3(0.6, 0.15, 0.0)
	sun.basis = Basis.looking_at(dir, Vector3.UP)
	root.add_child(sun)


static func prop(root: Node3D, path: String, pos: Vector3, yaw: float) -> Node3D:
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.rotation_degrees.y = yaw
	root.add_child(n)
	return n


static func furnish(root: Node3D) -> void:
	prop(root, "res://assets/props/intro_cabinet.glb", CABINET, 0.0)
	prop(root, "res://assets/props/intro_tv.glb", TV, 0.0).scale = Vector3.ONE * TV_SCALE
	prop(root, "res://assets/props/intro_vcr.glb", VCR, 0.0)
	prop(root, "res://assets/props/intro_side_table.glb", SIDE_TABLE, 90.0)
	prop(root, "res://assets/props/intro_armchair.glb", CHAIR, 180.0)
	# The office: a desk against the west wall with its chair, lamp and papers; shelves, a bookcase,
	# a plant by the window, a clock over the TV, pictures and a fire alarm.
	var o := "res://assets/props/office/"
	prop(root, o + "metal_office_desk.glb", Vector3(-2.52, 0.0, -0.6), 90.0)
	prop(root, o + "mid_century_lounge_chair.glb", Vector3(-1.6, 0.0, -0.75), -70.0)
	prop(root, o + "desk_lamp_arm_01.glb", Vector3(-2.78, 0.788, -1.35), 130.0)
	prop(root, o + "office_notepads.glb", Vector3(-2.55, 0.788, -0.45), 95.0).scale = Vector3.ONE * 0.45
	prop(root, o + "vintage_stapler.glb", Vector3(-2.3, 0.788, -1.0), 70.0)
	prop(root, o + "clipboard.glb", Vector3(-2.45, 0.788, 0.05), 80.0)
	prop(root, o + "standing_picture_frame_01.glb", Vector3(-2.82, 0.788, -0.05), 120.0)
	prop(root, o + "binder_notebook.glb", Vector3(-2.7, 0.788, 0.25), 90.0)
	prop(root, o + "wooden_bookshelf_worn.glb", Vector3(-2.25, 0.0, -3.1), 0.0)
	prop(root, o + "steel_frame_shelves_01.glb", Vector3(-2.74, 0.0, 1.0), 90.0).scale = Vector3.ONE * (1.9 / 21.405)
	prop(root, o + "cardboard_box_01.glb", Vector3(-2.65, 0.0, 1.95), 12.0)
	prop(root, o + "cardboard_box_01.glb", Vector3(-2.62, 0.342, 1.93), -8.0)
	prop(root, o + "cardboard_box_01.glb", Vector3(2.55, 0.0, 2.4), 30.0)
	prop(root, o + "potted_plant_02.glb", Vector3(2.55, 0.0, 0.35), 0.0)
	prop(root, o + "potted_plant_02.glb", Vector3(-2.55, 0.0, -2.0), 70.0).scale = Vector3.ONE * 0.85
	prop(root, o + "wall_clock.glb", Vector3(-0.3, 2.0, ROOM.position.y), 0.0)
	prop(root, o + "hanging_picture_frame_02.glb", Vector3(ROOM.end.x, 1.6, 1.5), -90.0)
	prop(root, o + "hanging_picture_frame_01.glb", Vector3(-1.9, 1.55, DOOR_Z), 180.0).scale = Vector3.ONE * 0.8
	prop(root, o + "fire_alarm.glb", Vector3(0.85, 1.45, DOOR_Z), 180.0)


static func tv_set(root: Node3D) -> Dictionary:
	# The VCR's power light: red until the tape is in.
	var led := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.008, 0.004, 0.002)
	led.mesh = lb
	var led_mat := StandardMaterial3D.new()
	led_mat.albedo_color = Color(0.6, 0.05, 0.05)
	led_mat.emission_enabled = true
	led_mat.emission = Color(0.8, 0.05, 0.0)
	led.material_override = led_mat
	led.position = LED
	root.add_child(led)
	# The tape plays through a 640x480 viewport onto a screen curved like the TV's glass.
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 480)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var video := VideoStreamPlayer.new()
	video.stream = TAPE
	video.expand = true
	video.size = Vector2(640, 480)
	video.volume_db = -1.0
	vp.add_child(video)
	var screen := MeshInstance3D.new()
	screen.mesh = curved_screen(SCREEN_SIZE, SCREEN_CURVE)
	var screen_mat := StandardMaterial3D.new()
	screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_mat.albedo_color = Color(0.06, 0.13, 0.62)       # the blue of an empty video channel
	screen.material_override = screen_mat
	screen.position = SCREEN
	root.add_child(screen)
	var tv_light := OmniLight3D.new()
	tv_light.light_color = Color(0.25, 0.4, 1.0)
	tv_light.light_energy = 0.35
	tv_light.omni_range = 4.0
	tv_light.position = SCREEN + Vector3(0, 0, 0.45)
	root.add_child(tv_light)
	# Subtitles on the cabinet, under the TV.
	var subs := Label3D.new()
	subs.position = Vector3(TV.x, 0.76, CABINET.z + 0.30)
	subs.pixel_size = 0.0013
	subs.font_size = 32
	subs.outline_size = 10
	subs.width = 640
	subs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subs.modulate = Color(1, 1, 0.92)
	subs.no_depth_test = true
	root.add_child(subs)
	return {"video": video, "screen_mat": screen_mat, "tv_light": tv_light, "led_mat": led_mat, "subs": subs}


## A rectangle bulging towards +Z like a CRT's glass (its apex at the origin).
static func curved_screen(size: Vector2, curve: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 16
	var ny := 12
	for j in ny + 1:
		for i in nx + 1:
			var u := float(i) / nx
			var v := float(j) / ny
			var x := (u - 0.5) * size.x
			var y := (0.5 - v) * size.y
			st.set_uv(Vector2(u, v))
			st.set_normal(Vector3(2.0 * curve.x * x, 2.0 * curve.x * y, 1.0).normalized())
			st.add_vertex(Vector3(x, y, -curve.x * (x * x + y * y) + curve.y * x * x * y * y))
	for j in ny:
		for i in nx:
			var k := j * (nx + 1) + i
			st.add_index(k)
			st.add_index(k + 1)
			st.add_index(k + nx + 1)
			st.add_index(k + 1)
			st.add_index(k + nx + 2)
			st.add_index(k + nx + 1)
	return st.commit()


static func tape_model(tape_08 := false) -> Node3D:
	# The tape lies on the side table, spine towards the door, with the F.A.L.C.O.N. labels
	# (07-W's, or the second tape's).
	var tape := Node3D.new()
	tape.add_child(load("res://assets/props/intro_tape.glb").instantiate())
	for l in [[LABEL_TEX_08 if tape_08 else LABEL_TEX, Vector2(0.0790, 0.0466), Vector3(0.0005, 0.0268, 0.004), Vector3(-90, 0, 0)],
			[SPINE_TEX_08 if tape_08 else SPINE_TEX, Vector2(0.1448, 0.0188), Vector3(0.0, 0.0133, 0.0528), Vector3.ZERO]]:
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = l[1]
		m.mesh = q
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = l[0]
		mat.roughness = 0.85
		m.material_override = mat
		m.position = l[2]
		m.rotation_degrees = l[3]
		tape.add_child(m)
	return tape
