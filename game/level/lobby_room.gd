extends Node3D
## The multiplayer lobby: the ground-floor lobby of a 90s office building, where everyone waits
## before a game. Checkered marble floor, dark wood wainscoting under teal wallpaper, marble columns
## with brass bands, a drop ceiling with recessed lights. Frosted glass doors and tall windows on
## the south wall glow with the setting sun, light slanting in. A front desk with the F.A.L.C.O.N.
## seal behind it: the host rings its service bell to start the game. Two elevators. A felt letter
## board with the room code and who's here. A waiting area with a patterned sofa, armchairs, a rug,
## and a TV with a VCR; the F.A.L.C.O.N. tape is on the coffee table. Put it in the VCR and it plays
## on the TV for everyone, with subtitles, and pops back out when it ends.

const INTRO := preload("res://intro/intro.gd")
const LOBBY := "res://assets/lobby/"
const P := "res://assets/props/lobby/"
const X0 := -7.0
const X1 := 7.0
const Z0 := -6.0
const Z1 := 6.0
const H := 3.4
const SUN := Color(1.0, 0.5, 0.24)
const BELL := Vector3(-0.5, 1.13, -3.92)
## The TV corner: the office's TV set, turned to stand against the east wall of the waiting area.
const TV_CORNER := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(3.6, 0.0, 1.5))
const COFFEE_TABLE := Vector3(5.35, 0.0, 1.5)
const SPAWNS: Array[Vector3] = [Vector3(0.0, 0.05, 2.6), Vector3(-1.2, 0.05, 2.2), Vector3(1.2, 0.05, 2.2), Vector3(0.0, 0.05, 3.8)]

var level: Node3D
var G: LevelGeometry
var SLOT := Vector3.ZERO        # the VCR's tape door (world)
var video: VideoStreamPlayer
var screen_mat: StandardMaterial3D
var tv_light: OmniLight3D
var led_mat: StandardMaterial3D
var subs: Label3D
var info: Label3D
var playing := false
var _cues: Array = []
var _info_t := 0.0
var _wood: StandardMaterial3D
var _marble: StandardMaterial3D
var _brass: StandardMaterial3D
var _steel: StandardMaterial3D


func build(lv: Node3D) -> void:
	level = lv
	G = lv.G
	_environment(lv.world_env.environment)
	_materials()
	_shell()
	_entrance()
	_front_desk()
	_elevators()
	_columns()
	_waiting_area()
	_decor()
	_letter_board()
	lv.spawn_points = SPAWNS
	lv.zones = []
	_update_info()


func _environment(env: Environment) -> void:
	env.background_color = Color(0, 0, 0)
	env.ambient_light_color = Color(0.85, 0.62, 0.48)
	env.ambient_light_energy = 0.16
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.05, 0.04)
	env.fog_density = 0.02
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9


# --- Building ------------------------------------------------------------------------------------

func _tex_mat(name: String, scale: float, tint: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(LOBBY + name + "_color.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(LOBBY + name + "_normal.jpg")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = rough
	m.metallic = metal
	return m


func _flat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _materials() -> void:
	_wood = _tex_mat("wood", 0.9, Color(0.85, 0.75, 0.7), 0.45)
	_marble = _tex_mat("marble", 0.6, Color(1, 1, 1), 0.15)
	_brass = _flat(Color(0.82, 0.62, 0.3), 0.28, 1.0)
	_steel = _flat(Color(0.62, 0.63, 0.64), 0.32, 0.9)


func _prop(path: String, pos: Vector3, yaw: float, parent: Node3D = null) -> Node3D:
	return OfficeRoom.prop(parent if parent else level, path, pos, yaw)


func _shell() -> void:
	var floor_mat := _tex_mat("tiles", 1.0, Color(1, 1, 1), 0.2)
	var wall := OfficeRoom.office_mat("wall", 0.6, Color(0.42, 0.62, 0.6), 0.85)       # dusty teal
	G.mat_ceiling = OfficeRoom.office_mat("ceiling", 0.83, Color(0.93, 0.91, 0.87), 0.9)
	G.floor_slab(X0, X1, Z0, Z1, 0.0, floor_mat)
	G.walls(X0, X1, Z0, Z1, 0.0, H, {}, wall)
	G.ceiling(X0, X1, Z0, Z1, H)
	# Wood wainscoting to 1.05 m, a chair rail, and crown moulding at the top.
	var t := 0.03
	for w in [[X0, X1, Z0, Z0 + t], [X0, X1, Z1 - t, Z1], [X0, X0 + t, Z0, Z1], [X1 - t, X1, Z0, Z1]]:
		G.block(w[0], w[1], 0.0, 1.05, w[2], w[3], _wood)
	for w in [[X0, X1, Z0, Z0 + 0.06], [X0, X1, Z1 - 0.06, Z1], [X0, X0 + 0.06, Z0, Z1], [X1 - 0.06, X1, Z0, Z1]]:
		G.block(w[0], w[1], 1.05, 1.1, w[2], w[3], _wood)
		G.block(w[0], w[1], H - 0.14, H, w[2], w[3], _wood)
	# Recessed light panels in the drop ceiling; three of them actually light the room.
	var panel := StandardMaterial3D.new()
	panel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	panel.albedo_color = Color(1.25, 1.12, 0.92)
	for x in [-4.5, -0.5, 3.5]:
		for z in [-3.0, 2.5]:
			var m := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.6, 0.6)
			m.mesh = q
			m.material_override = panel
			m.rotation_degrees.x = 90.0
			m.position = Vector3(x, H - 0.005, z)
			level.add_child(m)
	for p in [Vector3(-4.5, H - 0.3, -0.2), Vector3(-0.5, H - 0.3, -1.6), Vector3(3.5, H - 0.3, 1.2)]:
		G.light(p, 0.75, 8.0, Color(1.0, 0.86, 0.68), false)


## The south wall: frosted glass doors and tall windows with vertical blinds, glowing with the low
## sun, beams of light slanting in with dust in them.
func _entrance() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.3, 0.26))
	grad.add_point(0.5, Color(1.0, 0.55, 0.22))
	grad.set_color(grad.get_point_count() - 1, Color(1.0, 0.85, 0.52))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_texture = gt
	glass.albedo_color = Color(1.7, 1.55, 1.45)
	var zg := Z1 - 0.035
	var panes := [[-1.2, 0.0, 0.02, 2.35], [0.0, 1.2, 0.02, 2.35], [-1.2, 1.2, 2.45, 3.05],      # doors, transom
		[-5.3, -2.5, 1.2, 3.0], [2.5, 5.3, 1.2, 3.0]]                                          # windows
	for p in panes:
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(p[1] - p[0], p[3] - p[2])
		m.mesh = q
		m.material_override = glass
		m.rotation_degrees.y = 180.0
		m.position = Vector3((p[0] + p[1]) * 0.5, (p[2] + p[3]) * 0.5, zg)
		level.add_child(m)
	# Brass door frame and push bars; dark wood window frames and mullions.
	var zf0 := Z1 - 0.08
	var zf1 := Z1 - 0.03
	G.block(-1.3, -1.2, 0.0, 3.15, zf0, zf1, _brass)
	G.block(1.2, 1.3, 0.0, 3.15, zf0, zf1, _brass)
	G.block(-0.03, 0.03, 0.0, 2.4, zf0, zf1, _brass)
	G.block(-1.3, 1.3, 2.36, 2.44, zf0, zf1, _brass)
	G.block(-1.3, 1.3, 3.05, 3.15, zf0, zf1, _brass)
	G.block(-0.9, -0.15, 1.0, 1.05, zf0 - 0.05, zf0, _brass)
	G.block(0.15, 0.9, 1.0, 1.05, zf0 - 0.05, zf0, _brass)
	for wx in [[-5.3, -2.5], [2.5, 5.3]]:
		G.block(wx[0] - 0.08, wx[1] + 0.08, 1.12, 1.2, zf0 - 0.06, zf1, _wood)          # sill
		G.block(wx[0] - 0.08, wx[1] + 0.08, 3.0, 3.08, zf0, zf1, _wood)
		for x in [wx[0] - 0.08, (wx[0] + wx[1]) * 0.5 - 0.03, wx[1]]:
			G.block(x, x + 0.08, 1.2, 3.0, zf0, zf1, _wood)
		# Vertical blinds, half drawn, turned to the light.
		var slat_mat := _flat(Color(0.88, 0.84, 0.74), 0.8)
		var slat := BoxMesh.new()
		slat.size = Vector3(0.09, 1.75, 0.005)
		var n := 9
		for i in n:
			var m := MeshInstance3D.new()
			m.mesh = slat
			m.material_override = slat_mat
			m.position = Vector3(wx[0] + 0.12 + i * 0.13, 2.1, Z1 - 0.16)
			m.rotation_degrees.y = 62.0
			level.add_child(m)
	# The light: beams slanting in from the windows and doors, a hot patch across the floor.
	var dir := Vector3(0.12, -0.3, -1.0).normalized()
	var beam_grad := Gradient.new()
	beam_grad.set_color(0, Color(1.0, 0.62, 0.3, 0.26))
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
	bm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	bm.albedo_texture = bt
	var length := 6.0
	var starts := [Vector3(-4.6, 2.4, Z1), Vector3(-3.3, 1.8, Z1), Vector3(-0.6, 2.0, Z1), Vector3(0.6, 1.4, Z1),
		Vector3(3.2, 2.5, Z1), Vector3(4.5, 1.7, Z1)]
	for st in starts:
		for twist in [0.0, 90.0]:
			var beam := MeshInstance3D.new()
			var bq := QuadMesh.new()
			bq.size = Vector2(length, 0.35)
			beam.mesh = bq
			beam.material_override = bm
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			beam.basis = Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, deg_to_rad(twist))
			beam.position = st + dir * (length * 0.5)
			level.add_child(beam)
	var dust := CPUParticles3D.new()
	dust.amount = 120
	dust.lifetime = 10.0
	dust.preprocess = 10.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(5.0, 0.8, 1.6)
	dust.position = Vector3(0.0, 1.5, 3.4)
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
	level.add_child(dust)
	var sun := SpotLight3D.new()
	sun.light_color = SUN
	sun.light_energy = 4.0
	sun.spot_range = 13.0
	sun.spot_angle = 38.0
	sun.spot_attenuation = 0.5
	sun.position = Vector3(0.0, 2.6, Z1 + 0.6)
	sun.basis = Basis.looking_at(dir, Vector3.UP)
	level.add_child(sun)
	var wash := OmniLight3D.new()
	wash.light_color = SUN
	wash.light_energy = 1.0
	wash.omni_range = 6.0
	wash.position = Vector3(0.0, 1.8, Z1 - 0.8)
	level.add_child(wash)


## The front desk: dark wood with a marble top and a brass rail; behind it, the F.A.L.C.O.N. seal
## and its name in brass, and a back counter with a monitor. The host rings the bell to start.
func _front_desk() -> void:
	G.block(-3.0, 2.0, 0.0, 1.08, -4.4, -3.75, _wood)                  # the counter
	G.block(-3.06, 2.06, 1.08, 1.13, -4.46, -3.68, _marble)             # its marble top
	G.block(-3.0, 2.0, 0.1, 0.14, -3.75, -3.72, _brass)                 # brass kick rail
	G.block(-3.0, 2.0, 0.0, 0.76, -5.05, -4.4, _wood)                   # the clerks' work surface
	G.block(-3.4, 2.4, 0.0, 0.92, Z0, -5.45, _wood)                     # back counter
	G.block(-3.42, 2.42, 0.92, 0.96, Z0, -5.42, _marble)
	var seal := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(1.25, 1.25)
	seal.mesh = sq
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = load(LOBBY + "seal.png")
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	sm.roughness = 0.6
	seal.material_override = sm
	seal.position = Vector3(-0.5, 2.3, Z0 + 0.035)
	level.add_child(seal)
	var name_l := Label3D.new()
	name_l.text = "F . A . L . C . O . N ."
	name_l.font_size = 96
	name_l.pixel_size = 0.0042
	name_l.modulate = Color(0.85, 0.65, 0.3)
	name_l.outline_size = 0
	name_l.position = Vector3(-0.5, 1.45, Z0 + 0.04)
	level.add_child(name_l)
	var sub := Label3D.new()
	sub.text = "FACILITIES  &  ORIENTATION"
	sub.font_size = 48
	sub.pixel_size = 0.0035
	sub.modulate = Color(0.8, 0.62, 0.3)
	sub.outline_size = 0
	sub.position = Vector3(-0.5, 1.18, Z0 + 0.04)
	level.add_child(sub)
	# On the desk: a lamp, papers, a stapler; on the back counter, the front desk's monitor.
	var o := "res://assets/props/office/"
	_prop(o + "desk_lamp_arm_01.glb", Vector3(1.55, 1.13, -4.15), 200.0)
	_prop(o + "clipboard.glb", Vector3(0.4, 1.13, -4.05), 10.0)
	_prop(o + "vintage_stapler.glb", Vector3(-1.4, 1.13, -4.1), -20.0)
	_prop(o + "office_notepads.glb", Vector3(1.0, 1.13, -4.15), 0.0).scale = Vector3.ONE * 0.35
	_prop("res://assets/props/intro_tv.glb", Vector3(-2.4, 0.96, -5.75), 20.0).scale = Vector3.ONE * 0.8
	_prop(P + "potted_plant_04.glb", Vector3(-2.9, 1.13, -4.05), 0.0)
	_prop(o + "binder_notebook.glb", Vector3(1.6, 0.96, -5.7), 0.0)
	# The service bell: brass dome on a dark base. Ringing it (grab, or interact) starts the game.
	var base := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.055
	bc.bottom_radius = 0.06
	bc.height = 0.022
	base.mesh = bc
	base.material_override = _flat(Color(0.08, 0.06, 0.05), 0.4)
	base.position = BELL + Vector3(0, 0.011, 0)
	level.add_child(base)
	var dome := MeshInstance3D.new()
	var ds := SphereMesh.new()
	ds.radius = 0.05
	ds.height = 0.1
	ds.is_hemisphere = true
	dome.mesh = ds
	dome.material_override = _brass
	dome.position = BELL + Vector3(0, 0.022, 0)
	dome.scale = Vector3(1, 0.75, 1)
	level.add_child(dome)
	var knob := MeshInstance3D.new()
	var kc := CylinderMesh.new()
	kc.top_radius = 0.008
	kc.bottom_radius = 0.006
	kc.height = 0.025
	knob.mesh = kc
	knob.material_override = _brass
	knob.position = BELL + Vector3(0, 0.07, 0)
	level.add_child(knob)
	level.lever_point = BELL + Vector3(0, 0.05, 0)
	var ring := preload("res://items/lever_handle.gd").new()
	ring.name = "Bell"
	level.get_node("Props").add_child(ring)
	ring.global_position = level.lever_point
	var tag := Label3D.new()
	tag.text = "RING FOR SERVICE\nthe host rings to start"
	tag.font_size = 32
	tag.pixel_size = 0.0018
	tag.modulate = Color(0.12, 0.1, 0.08)
	tag.outline_size = 0
	tag.position = BELL + Vector3(0, -0.2, 0.2)
	level.add_child(tag)


## Two elevators in the west wall: brushed steel doors, brass frames, call buttons and floor dials.
func _elevators() -> void:
	var amber := StandardMaterial3D.new()
	amber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	amber.albedo_color = Color(1.0, 0.6, 0.15)
	var dark := _flat(Color(0.05, 0.05, 0.05), 0.5)
	for c in [-2.6, 0.6]:
		G.block(X0, X0 + 0.1, 0.0, 2.55, c - 0.78, c + 0.78, _brass)        # frame
		G.block(X0, X0 + 0.12, 0.02, 2.4, c - 0.62, c + 0.62, _steel)      # the doors
		G.block(X0 + 0.12, X0 + 0.125, 0.02, 2.4, c - 0.005, c + 0.005, dark)
		G.block(X0, X0 + 0.11, 2.6, 2.86, c - 0.35, c + 0.35, dark)         # the floor dial
		var dial := Label3D.new()
		dial.text = "L   2   3   4"
		dial.font_size = 40
		dial.pixel_size = 0.0035
		dial.modulate = Color(1.0, 0.62, 0.18)
		dial.outline_size = 0
		dial.position = Vector3(X0 + 0.115, 2.73, c)
		dial.rotation_degrees.y = 90.0
		level.add_child(dial)
		G.block(X0, X0 + 0.04, 1.0, 1.35, c + 0.92, c + 1.08, _brass)       # call buttons
		for y in [1.24, 1.11]:
			var b := MeshInstance3D.new()
			var bc := CylinderMesh.new()
			bc.top_radius = 0.022
			bc.bottom_radius = 0.022
			bc.height = 0.012
			b.mesh = bc
			b.material_override = amber
			b.rotation_degrees.z = 90.0
			b.position = Vector3(X0 + 0.045, y, c + 1.0)
			level.add_child(b)


func _columns() -> void:
	var dark := _flat(Color(0.12, 0.1, 0.09), 0.25)
	for p in [Vector2(-4.0, -1.4), Vector2(-4.0, 2.6), Vector2(2.4, -1.4), Vector2(2.4, 2.6)]:
		G.block(p.x - 0.36, p.x + 0.36, 0.0, 0.14, p.y - 0.36, p.y + 0.36, dark)
		G.block(p.x - 0.3, p.x + 0.3, 0.14, H, p.y - 0.3, p.y + 0.3, _marble)
		G.block(p.x - 0.32, p.x + 0.32, 1.05, 1.1, p.y - 0.32, p.y + 0.32, _brass)
		G.block(p.x - 0.33, p.x + 0.33, H - 0.24, H - 0.18, p.y - 0.33, p.y + 0.33, _brass)


## The waiting area by the east wall: a patterned sofa facing the TV, two armchairs, a marble coffee
## table on a rug, with the tape and a few magazines on it.
func _waiting_area() -> void:
	var rug := MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(3.4, 4.25)
	rug.mesh = rq
	var rm := StandardMaterial3D.new()
	rm.albedo_texture = load(LOBBY + "rug.jpg")
	rm.roughness = 0.95
	rug.material_override = rm
	rug.rotation_degrees.x = -90.0
	rug.position = Vector3(5.25, 0.006, 1.5)
	level.add_child(rug)
	_prop(P + "sofa_03.glb", Vector3(4.05, 0.0, 1.5), 90.0)
	_prop(P + "greenchair_01.glb", Vector3(5.5, 0.0, -0.45), 25.0)
	_prop(P + "greenchair_01.glb", Vector3(5.5, 0.0, 3.45), 155.0)
	_prop(P + "coffee_table_round_01.glb", COFFEE_TABLE, 0.0)
	level._hidden_block(COFFEE_TABLE.x - 0.45, COFFEE_TABLE.x + 0.45, 0.0, 0.49, COFFEE_TABLE.z - 0.45, COFFEE_TABLE.z + 0.45)
	_prop(P + "side_table_tall_01.glb", Vector3(3.95, 0.0, 3.45), 0.0)
	_prop(P + "antique_ceramic_vase_01.glb", Vector3(3.95, 0.76, 3.45), 0.0)
	_prop(P + "potted_plant_01.glb", Vector3(6.45, 0.0, -0.5), 0.0)
	_prop(P + "potted_plant_01.glb", Vector3(6.45, 0.0, 3.6), 120.0)
	# Magazines on the coffee table.
	for m in [[Vector3(5.6, 0.495, 1.85), 20.0, Color(0.75, 0.2, 0.18)], [Vector3(5.66, 0.502, 1.8), -8.0, Color(0.2, 0.42, 0.62)],
			[Vector3(5.0, 0.495, 1.05), 70.0, Color(0.85, 0.75, 0.3)]]:
		var mag := MeshInstance3D.new()
		var mb := BoxMesh.new()
		mb.size = Vector3(0.21, 0.006, 0.28)
		mag.mesh = mb
		mag.material_override = _flat(m[2], 0.4)
		mag.position = m[0]
		mag.rotation_degrees.y = m[1]
		level.add_child(mag)
	# The TV set, turned to face the room from the east wall.
	var corner := Node3D.new()
	corner.name = "TVCorner"
	corner.transform = TV_CORNER
	level.add_child(corner)
	_prop("res://assets/props/intro_cabinet.glb", OfficeRoom.CABINET, 0.0, corner)
	_prop("res://assets/props/intro_tv.glb", OfficeRoom.TV, 0.0, corner).scale = Vector3.ONE * OfficeRoom.TV_SCALE
	_prop("res://assets/props/intro_vcr.glb", OfficeRoom.VCR, 0.0, corner)
	var tvs := OfficeRoom.tv_set(corner)
	video = tvs.video
	screen_mat = tvs.screen_mat
	tv_light = tvs.tv_light
	led_mat = tvs.led_mat
	subs = tvs.subs
	video.finished.connect(_on_tape_end)
	_cues = INTRO._load_srt("res://assets/video/falcon_tape.srt")
	SLOT = TV_CORNER * OfficeRoom.SLOT
	var vcr_body := StaticBody3D.new()
	vcr_body.add_to_group("vcr")
	vcr_body.collision_layer = LevelGeometry.L_WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.43, 0.1, 0.34)
	cs.shape = box
	vcr_body.position = OfficeRoom.VCR + Vector3(0, 0.05, 0)
	vcr_body.add_child(cs)
	corner.add_child(vcr_body)
	level._hidden_block(X1 - 0.6, X1, 0.0, 0.83, 0.84, 2.16)        # the cabinet, to stand things on
	level._spawn_item("tape", "Tape", COFFEE_TABLE + Vector3(-0.15, 0.51, -0.25))


func _decor() -> void:
	_prop(P + "sofa_02.glb", Vector3(-6.45, 0.0, 3.6), 90.0)                       # by the elevators
	_prop(P + "potted_plant_01.glb", Vector3(-6.45, 0.0, -1.0), 40.0)
	_prop(P + "potted_plant_01.glb", Vector3(-6.4, 0.0, 5.35), 200.0)
	_prop(P + "potted_plant_01.glb", Vector3(6.4, 0.0, -5.35), 300.0)
	_prop(P + "side_table_tall_01.glb", Vector3(-6.6, 0.0, 5.0), 0.0)
	var o := "res://assets/props/office/"
	_prop(o + "wall_clock.glb", Vector3(-4.6, 2.45, Z0), 0.0)
	_prop(o + "hanging_picture_frame_02.glb", Vector3(X0, 1.85, 3.6), 90.0)
	_prop(o + "hanging_picture_frame_01.glb", Vector3(X1, 1.8, -3.8), -90.0).scale = Vector3.ONE * 0.9
	_prop(o + "fire_alarm.glb", Vector3(1.9, 1.45, Z1), 180.0)
	# Brass sconces by the desk and either side of the TV; the ones by the TV glow.
	_prop(P + "industrial_wall_sconce.glb", Vector3(-2.6, 2.05, Z0), 0.0)
	_prop(P + "industrial_wall_sconce.glb", Vector3(1.6, 2.05, Z0), 0.0)
	_prop(P + "industrial_wall_sconce.glb", Vector3(X1, 1.95, -0.25), -90.0)
	_prop(P + "industrial_wall_sconce.glb", Vector3(X1, 1.95, 3.25), -90.0)
	for z in [-0.25, 3.25]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.75, 0.45)
		l.light_energy = 0.5
		l.omni_range = 3.2
		l.position = Vector3(X1 - 0.35, 1.8, z)
		level.add_child(l)


## The felt letter board on the north wall: the room code and who's here.
func _letter_board() -> void:
	var at := Vector3(4.6, 1.75, Z0 + 0.04)
	G.block(at.x - 0.95, at.x + 0.95, at.y - 0.68, at.y + 0.68, Z0, Z0 + 0.03, _steel)
	var felt := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(1.8, 1.26)
	felt.mesh = fq
	felt.material_override = _flat(Color(0.03, 0.03, 0.035), 0.95)
	felt.position = at
	level.add_child(felt)
	info = Label3D.new()
	info.position = at + Vector3(0, 0, 0.005)
	info.pixel_size = 0.0021
	info.font_size = 40
	info.width = 800
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.modulate = Color(0.95, 0.94, 0.9)
	info.outline_size = 0
	level.add_child(info)


# --- Every frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_info_t -= delta
	if _info_t <= 0.0:
		_info_t = 0.5
		_update_info()
	if playing:
		var pos := video.stream_position
		var text := ""
		for c in _cues:
			if pos >= c[0] and pos <= c[1]:
				text = c[2]
				break
		subs.text = text
	else:
		subs.text = ""


func _update_info() -> void:
	var names := []
	for id in Net.players:
		names.append(str(Net.players[id].get("name", "Player")).to_upper())
	if names.is_empty():
		names.append(str(Net.local_info.get("name", "Player")).to_upper())
	var host_name := str(Net.players.get(1, {}).get("name", "the host")).to_upper()
	var code := ""
	if Net.room_code != "":
		code = "ROOM CODE  %s\n" % Net.room_code
	elif Net.is_online() and Net.is_host():
		var ips := Net.local_addresses()
		if not ips.is_empty():
			code = "ON THIS WI-FI  %s\n" % ips[0]
	var start := "THE HOST RINGS THE BELL AT THE FRONT DESK TO START" if Net.is_host() or not Net.is_online() \
		else "WAITING FOR %s TO RING THE BELL" % host_name
	info.text = "WELCOME TO F.A.L.C.O.N.\n\n%sHERE (%d/%d): %s\n\n%s\n\nTHE TAPE IS ON THE COFFEE TABLE" % [
		code, names.size(), Net.MAX_PLAYERS, ", ".join(names), start]


## The tape went in (true) or came out (false): play it on everyone's TV.
func on_vhs(on: bool) -> void:
	if on == playing:
		return
	playing = on
	if on:
		led_mat.albedo_color = Color(0.2, 1.0, 0.3)
		led_mat.emission = Color(0.2, 1.0, 0.3)
		screen_mat.albedo_texture = null
		screen_mat.albedo_color = Color(0.9, 0.95, 1.0)
		var tw := create_tween()
		tw.tween_interval(0.12)
		tw.tween_callback(func():
			screen_mat.albedo_color = Color(1, 1, 1)
			screen_mat.albedo_texture = video.get_parent().get_texture()
			tv_light.light_color = Color(0.75, 0.85, 1.0)
			tv_light.light_energy = 0.55)
		video.play()
	else:
		video.stop()
		led_mat.albedo_color = Color(0.6, 0.05, 0.05)
		led_mat.emission = Color(0.8, 0.05, 0.0)
		screen_mat.albedo_texture = null
		screen_mat.albedo_color = Color(0.06, 0.13, 0.62)
		tv_light.light_color = Color(0.25, 0.4, 1.0)
		tv_light.light_energy = 0.35


## Host: the tape ended. It stops and pops back out of the VCR.
func _on_tape_end() -> void:
	if not (Net.is_host() or not Net.is_online()):
		return
	level.set_state("vhs", false)
	var out := SLOT + (TV_CORNER.basis * Vector3(0, -0.01, 0.2))
	level._set_item_stowed_at("Tape", 0, out)
	Net.send(level, &"_set_item_stowed_at", ["Tape", 0, out])
