extends Node3D
## The multiplayer lobby: the visitor reception of a F.A.L.C.O.N. field station, built like a cozy
## old roadside lodge, where everyone waits before a game. Knotty pine walls, red carpet, a stucco
## ceiling with dark beams and a slow ceiling fan. Dusk through the venetian blinds, and a neon
## FIELD STATION sign glowing in the window (backwards from in here). A pine reception counter with a
## service bell (the host rings it to start the game), the visitors' sign-in book and a green
## banker's lamp; behind it the dormitory keys on their hooks, the staff mail cubbies and the
## station's carved sign with the F.A.L.C.O.N. seal. An orange cone fireplace in the corner, a coffee
## station, a rack of F.A.L.C.O.N. pamphlets and a glowing soda machine. By the TV: a couch, a leather
## armchair and a coffee table on a plaid rug, where the two F.A.L.C.O.N. tapes lie (07-W and 08-E).
## Put one in the VCR and it plays on the TV for everyone, with subtitles, and pops back out when it
## ends. The pamphlets, magazines, coffee cups and some of the keys can be picked up and thrown, and
## the soda machine's buttons drop Chlora-Cola cans. The furniture is solid.

const INTRO := preload("res://intro/intro.gd")
const LOBBY := "res://assets/lobby/"
const BRAND := "res://assets/branding/"         # the station's art (tools/branding)
const P := "res://assets/props/lobby/"
const X0 := -4.0
const X1 := 4.0
const Z0 := -3.5
const Z1 := 3.5
const H := 2.6
const DUSK := Color(1.0, 0.52, 0.28)
const BELL := Vector3(-1.2, 1.07, -1.76)
const DESTINATION := Vector3(-0.55, 1.12, -1.7)   # the flip sign on the desk: where the host is taking everyone
## The TV corner: the office's TV set, turned to stand against the east wall.
const TV_CORNER := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0.6, 0.0, -0.6))
const COFFEE_TABLE := Vector3(2.6, 0.0, -0.6)
const FIREPLACE := Vector3(3.3, 0.0, 2.85)         # the south-east corner, clear of the door
const SODA_TRAY := Vector3(-3.17, 0.335, -1.42)      # where a can from the machine lands
## The two tapes: their videos and subtitles.
const TAPES := {
	"Tape": ["res://assets/video/falcon_tape.ogv", "res://assets/video/falcon_tape.srt"],
	"Tape08": ["res://assets/video/falcon_tape_08.ogv", "res://assets/video/falcon_tape_08.srt"],
}
const SPAWNS: Array[Vector3] = [Vector3(0.0, 0.05, 1.8), Vector3(-1.0, 0.05, 1.2), Vector3(0.9, 0.05, 1.0), Vector3(-0.2, 0.05, 0.4)]

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
var _t := 0.0
var _fan: Node3D
var _fire_light: OmniLight3D
var _fire_mat: StandardMaterial3D
var _pine: StandardMaterial3D
var _wood: StandardMaterial3D
var _brass: StandardMaterial3D
var _clock_h: Node3D
var _clock_m: Node3D
var _countdown := 0          # seconds until the game starts (0: not starting)
var _dest_label: Label3D
var _leave_t := 0.0          # how long you've stood on the doormat by the way out
var _ips: Array[String] = []
var _ips_t := 0.0


func build(lv: Node3D) -> void:
	level = lv
	G = lv.G
	_environment(lv.world_env.environment)
	_pine = _tex_mat("pine", 0.8, Color(1, 0.96, 0.9), 0.35)
	_wood = _tex_mat("wood", 0.9, Color(0.75, 0.62, 0.55), 0.45)
	_brass = _flat(Color(0.82, 0.62, 0.3), 0.3, 1.0)
	_shell()
	_front()
	_counter()
	_behind_counter()
	_west_wall()
	_fireplace()
	_tv_nook()
	_letter_board()
	lv.spawn_points = SPAWNS
	lv.zones = []
	_update_info()


func _environment(env: Environment) -> void:
	env.background_color = Color(0, 0, 0)
	env.ambient_light_color = Color(0.9, 0.62, 0.42)
	env.ambient_light_energy = 0.12
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.04, 0.03)
	env.fog_density = 0.02
	# Bloom only on a monitor. On the Quest (Compatibility renderer) glow adds a full-screen pass that
	# fights the headset's dynamic foveation: once the GPU warms up, the lobby broke down into
	# flashing colours (the "cyberpsychosis" glitch). Not worth the risk, or the frame time.
	env.glow_enabled = not Game.vr_mode
	env.glow_intensity = 0.6
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.15      # only lamps, neon, the fire and the window bloom


# --- Helpers -------------------------------------------------------------------------------------

func _tex_mat(name: String, scale: float, tint: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(LOBBY + name + "_color.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(LOBBY + name + "_normal.jpg")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = rough
	return m


func _flat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _glow(c: Color, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c * energy
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees.y = yaw
	level.add_child(mi)
	return mi


func _cyl(r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	level.add_child(mi)
	return mi


func _text(t: String, pos: Vector3, yaw: float, size: float, col: Color, font := 48) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font_size = font
	l.pixel_size = size
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees.y = yaw
	level.add_child(l)
	return l


## A flat picture from the station's art: a quad facing +z, turned by rot (degrees). glow > 0 makes
## it self-lit (unshaded, that bright); cut keeps only its opaque pixels (for transparent art).
func _pic(file: String, size: Vector2, pos: Vector3, rot := Vector3.ZERO, glow := 0.0, cut := false, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(BRAND + file)
	m.roughness = 0.85
	if glow > 0.0:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(glow, glow, glow)
	if cut:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation_degrees = rot
	(parent if parent else level).add_child(mi)
	return mi


## A can with a paper label all the way round (u runs round it, the middle of the label faces +x),
## and a tin lid.
func _label_can(r: float, h: float, pos: Vector3, file: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 24
	for i in n:
		for k in [[i, 0.0], [i + 1, 0.0], [i + 1, 1.0], [i, 0.0], [i + 1, 1.0], [i, 1.0]]:
			var u: float = float(k[0]) / n
			var a := u * TAU
			var d := Vector3(-cos(a), 0.0, sin(a))      # u = 0.5 faces +x; reading on goes to -z
			st.set_normal(d)
			st.set_uv(Vector2(u, 1.0 - k[1]))
			st.add_vertex(d * r + Vector3(0, h * k[1], 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(BRAND + file)
	m.roughness = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = pos - Vector3(0, h * 0.5, 0)
	level.add_child(mi)
	_cyl(r * 0.99, r * 0.99, 0.006, pos + Vector3(0, h * 0.5, 0), _flat(Color(0.75, 0.75, 0.72), 0.3, 1.0))


func _light(pos: Vector3, c: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	level.add_child(l)
	return l


func _prop(path: String, pos: Vector3, yaw: float, parent: Node3D = null) -> Node3D:
	return OfficeRoom.prop(parent if parent else level, path, pos, yaw)


## An invisible solid box so you can't walk through a piece of furniture: size, its bottom centre
## at `at`, turned by yaw (degrees); `local` moves it within the furniture's own frame.
func _solid(at: Vector3, size: Vector3, yaw := 0.0, local := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = LevelGeometry.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = local + Vector3(0, size.y * 0.5, 0)
	body.add_child(cs)
	body.position = at
	body.rotation_degrees.y = yaw
	level.add_child(body)


## A small thing to pick up (items/prop.gd), turned by rot (degrees).
func _thing(item_name: String, pos: Vector3, rot := Vector3.ZERO) -> void:
	level._spawn_item("prop", item_name, pos)
	level.items[item_name].rotation_degrees = rot


# --- The room ------------------------------------------------------------------------------------

func _shell() -> void:
	var carpet := _tex_mat("carpet", 1.3, Color(0.8, 0.62, 0.6), 0.95)
	G.mat_ceiling = _tex_mat("stucco", 1.0, Color(0.95, 0.92, 0.86), 0.95)
	G.floor_slab(X0, X1, Z0, Z1, 0.0, carpet)
	G.walls(X0, X1, Z0, Z1, 0.0, H, {}, _pine)
	G.ceiling(X0, X1, Z0, Z1, H)
	# Dark skirting and crown moulding; beams across the ceiling.
	for w in [[X0, X1, Z0, Z0 + 0.03], [X0, X1, Z1 - 0.03, Z1], [X0, X0 + 0.03, Z0, Z1], [X1 - 0.03, X1, Z0, Z1]]:
		G.block(w[0], w[1], 0.0, 0.11, w[2], w[3], _wood)
		G.block(w[0], w[1], H - 0.08, H, w[2], w[3], _wood)
	for z in [-2.4, -0.9, 0.6, 2.1]:
		G.block(X0, X1, H - 0.16, H, z - 0.09, z + 0.09, _wood)
	# The ceiling fan turns slowly; a dim light in its middle.
	_fan = _prop(P + "ceiling_fan.glb", Vector3(1.0, H - 0.516, -0.2), 0.0)
	if not Game.vr_mode:        # on the headset every light is another pass over the walls: only the ones that matter
		_light(Vector3(1.0, H - 0.6, -0.2), Color(1.0, 0.8, 0.55), 0.35, 5.0)


## The front wall: the glass door and the big window, venetian blinds, dusk outside, the station's
## neon sign hanging in the window.
func _front() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.45, 0.25, 0.45))            # dusk sky
	grad.add_point(0.55, Color(1.0, 0.45, 0.25))
	grad.set_color(grad.get_point_count() - 1, Color(1.0, 0.75, 0.45))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_texture = gt
	glass.albedo_color = Color(1.5, 1.4, 1.35)
	var zg := Z1 - 0.025
	for p in [[-3.25, -2.35, 0.05, 2.05], [-1.6, 2.8, 0.85, 2.15]]:
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(p[1] - p[0], p[3] - p[2])
		m.mesh = q
		m.material_override = glass
		m.rotation_degrees.y = 180.0
		m.position = Vector3((p[0] + p[1]) * 0.5, (p[2] + p[3]) * 0.5, zg)
		level.add_child(m)
	var zf0 := Z1 - 0.08
	var zf1 := Z1 - 0.02
	# The door: wood frame, a brass handle, the visitor entrance lettered on the glass (from outside).
	G.block(-3.33, -3.25, 0.0, 2.13, zf0, zf1, _wood)
	G.block(-2.35, -2.27, 0.0, 2.13, zf0, zf1, _wood)
	G.block(-3.33, -2.27, 2.05, 2.13, zf0, zf1, _wood)
	G.block(-3.25, -2.35, 0.0, 0.3, zf0 + 0.02, zf1, _wood)
	_cyl(0.015, 0.015, 0.16, Vector3(-2.47, 1.0, zf0 - 0.03), _brass)
	_pic("door_decal.png", Vector2(0.6, 0.6), Vector3(-2.8, 1.2, Z1 - 0.03), Vector3.ZERO, 0.0, true)
	# A coir doormat inside the door, with the seal woven into it.
	_box(Vector3(0.95, 0.012, 0.62), Vector3(-2.8, 0.006, 3.05), _flat(Color(0.28, 0.2, 0.12), 0.95))
	# The way out: stand on the mat by the door for a moment to leave the station (and the session).
	_pic("exit_sign.png", Vector2(0.44, 0.22), Vector3(-2.8, 2.33, Z1 - 0.012), Vector3(0, 180, 0), 1.2)
	_text("STAND HERE TO LEAVE", Vector3(-2.8, 0.02, 2.7), 0.0, 0.0014, Color(0.85, 0.75, 0.5), 32).rotation_degrees = Vector3(-90, 180, 0)
	_pic("rug_logo.png", Vector2(0.5, 0.5), Vector3(-2.8, 0.0125, 3.05), Vector3(-90, 0, 0), 0.0, true)
	# The window: frame, mullion, sill.
	G.block(-1.68, 2.88, 0.77, 0.85, zf0 - 0.08, zf1, _wood)
	G.block(-1.68, 2.88, 2.15, 2.23, zf0, zf1, _wood)
	for x in [-1.68, 0.56, 2.8]:
		G.block(x, x + 0.08, 0.85, 2.15, zf0, zf1, _wood)
	# Venetian blinds over door and window, slats tilted: stripes of dusk between them.
	var slat_mat := _flat(Color(0.9, 0.86, 0.76), 0.75)
	for b in [[-3.25, -2.35, 1.58, 2.0], [-1.6, 2.8, 1.2, 2.12]]:      # the door's are half up
		var slat := BoxMesh.new()
		slat.size = Vector3(b[1] - b[0], 0.003, 0.045)
		var y: float = b[3]
		while y > b[2]:
			var m := MeshInstance3D.new()
			m.mesh = slat
			m.material_override = slat_mat
			m.position = Vector3((b[0] + b[1]) * 0.5, y, Z1 - 0.09)
			m.rotation_degrees.x = -40.0
			level.add_child(m)
			y -= 0.038
	# The station's neon sign, hanging in the window and facing the road: backwards from here.
	_box(Vector3(1.5, 0.78, 0.02), Vector3(1.4, 1.68, Z1 - 0.16), _flat(Color(0.05, 0.05, 0.05), 0.6))
	var neon := _pic("neon_design.png", Vector2(1.4, 0.7), Vector3(1.4, 1.68, Z1 - 0.172), Vector3.ZERO, 1.0, true)
	neon.material_override.albedo_color = Color(0.35, 0.85, 2.2)
	var open := _text("OPEN 24 HRS", Vector3(1.4, 1.15, Z1 - 0.17), 0.0, 0.0018, Color(2.2, 0.3, 0.2), 64)
	open.shaded = false
	open.double_sided = true
	if not Game.vr_mode:
		_light(Vector3(1.4, 1.6, Z1 - 0.5), Color(0.3, 0.55, 1.0), 0.7, 3.0)
	# Dusk light slanting in through the blinds.
	var dir := Vector3(0.12, -0.22, -1.0).normalized()
	var beam_grad := Gradient.new()
	beam_grad.set_color(0, Color(1.0, 0.6, 0.32, 0.2))
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
	var length := 4.5
	for i in 7:
		var st := Vector3(-1.3 + i * 0.62, 1.25 + fmod(i * 0.37, 0.8), Z1)
		for twist in [0.0, 90.0]:
			var beam := MeshInstance3D.new()
			var bq := QuadMesh.new()
			bq.size = Vector2(length, 0.12)
			beam.mesh = bq
			beam.material_override = bm
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			beam.basis = Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, deg_to_rad(twist))
			beam.position = st + dir * (length * 0.5)
			level.add_child(beam)
	var sun := SpotLight3D.new()
	sun.light_color = DUSK
	sun.light_energy = 3.0
	sun.spot_range = 9.0
	sun.spot_angle = 35.0
	sun.spot_attenuation = 0.6
	sun.position = Vector3(0.6, 1.9, Z1 + 0.5)
	sun.basis = Basis.looking_at(dir, Vector3.UP)
	level.add_child(sun)


## The reception counter: pine front, dark wood top. The bell (the host rings it to start), the
## visitors' sign-in book, a green banker's lamp, a little plant, a card.
func _counter() -> void:
	G.block(-2.9, 0.6, 0.0, 1.03, -2.2, -1.62, _pine)
	G.block(-2.95, 0.65, 1.03, 1.07, -2.25, -1.55, _wood)
	G.block(-2.9, 0.6, 0.0, 0.1, -1.64, -1.6, _wood)
	G.block(-2.9, 0.6, 0.0, 0.78, -2.6, -2.2, _wood)                # the clerk's shelf
	# The visitors' sign-in book, open.
	_box(Vector3(0.37, 0.012, 0.35), Vector3(-2.0, 1.076, -1.86), _flat(Color(0.3, 0.12, 0.08), 0.7), 8.0)
	_pic("signin_page.png", Vector2(0.33, 0.33), Vector3(-2.0, 1.0835, -1.86), Vector3(-90, 8, 0))
	_cyl(0.004, 0.004, 0.14, Vector3(-1.85, 1.09, -1.75), _flat(Color(0.1, 0.1, 0.2), 0.4)).rotation_degrees = Vector3(90, 30, 0)
	# Banker's lamp: brass base and stem, green glass shade, a warm pool of light.
	_cyl(0.07, 0.08, 0.025, Vector3(-2.6, 1.083, -1.95), _brass)
	_cyl(0.008, 0.008, 0.3, Vector3(-2.6, 1.23, -1.95), _brass)
	var shade := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.07
	sc.bottom_radius = 0.07
	sc.height = 0.3
	sc.radial_segments = 16
	shade.mesh = sc
	var green := _flat(Color(0.05, 0.4, 0.2), 0.15)
	green.emission_enabled = true
	green.emission = Color(0.1, 0.5, 0.25)
	green.emission_energy_multiplier = 0.5
	shade.material_override = green
	shade.rotation_degrees.z = 90.0
	shade.scale = Vector3(1, 1, 0.55)
	shade.position = Vector3(-2.6, 1.37, -1.92)
	level.add_child(shade)
	_light(Vector3(-2.6, 1.28, -1.85), Color(1.0, 0.82, 0.55), 0.6, 2.6)
	_prop(P + "potted_plant_04.glb", Vector3(0.38, 1.07, -1.92), 0.0)
	_text("PLEASE RING\nFOR SERVICE", BELL + Vector3(0.25, 0.06, 0.04), 0.0, 0.0012, Color(0.15, 0.1, 0.06), 32)
	_box(Vector3(0.16, 0.1, 0.003), BELL + Vector3(0.25, 0.06, 0.035), _flat(Color(0.95, 0.92, 0.84), 0.9))
	# The service bell: brass dome on a dark base. Ringing it (grab, or interact) starts the game.
	_cyl(0.055, 0.06, 0.022, BELL + Vector3(0, 0.011, 0), _flat(Color(0.08, 0.06, 0.05), 0.4))
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
	_cyl(0.008, 0.006, 0.025, BELL + Vector3(0, 0.07, 0), _brass)
	# The destination sign: the host flips it (grab, or interact) to choose the level.
	_box(Vector3(0.44, 0.2, 0.02), DESTINATION + Vector3(0, 0.08, -0.12), _flat(Color(0.07, 0.125, 0.36), 0.6))
	_dest_label = _text("", DESTINATION + Vector3(0, 0.08, -0.108), 0.0, 0.0011, Color(0.93, 0.85, 0.5), 32)
	_text("FLIP TO CHOOSE (HOST)", DESTINATION + Vector3(0, -0.035, -0.1), 0.0, 0.0006, Color(0.15, 0.1, 0.06), 32)
	var flip := preload("res://items/lever_handle.gd").new("destination", 0.12)
	flip.name = "Destination"
	level.get_node("Props").add_child(flip)
	flip.global_position = DESTINATION
	on_map(Game.level_map)
	level.lever_point = BELL + Vector3(0, 0.05, 0)
	var ring := preload("res://items/lever_handle.gd").new()
	ring.name = "Bell"
	level.get_node("Props").add_child(ring)
	ring.global_position = level.lever_point


## Behind the counter: the dormitory keys on their board, the staff mail cubbies, the station's
## carved sign with the seal, the clock, a framed safety notice, and the sign-in rule.
func _behind_counter() -> void:
	var zw := Z0 + 0.03
	# Key board: three rows of six hooks, each with a key on a coloured plastic fob.
	G.block(-2.75, -1.15, 1.25, 1.95, Z0, zw, _wood)
	_text("DORMITORY KEYS", Vector3(-1.95, 1.89, zw + 0.005), 0.0, 0.0018, Color(0.9, 0.8, 0.55), 40)
	var fob_cols := [Color(0.75, 0.15, 0.12), Color(0.15, 0.35, 0.65), Color(0.15, 0.5, 0.3), Color(0.85, 0.55, 0.15)]
	var gone := [3, 8, 13, 16]          # rooms checked out right now: empty hooks
	for row in 3:
		for col in 6:
			var n := row * 6 + col
			var hx := -2.6 + col * 0.25
			var hy := 1.75 - row * 0.2
			_cyl(0.005, 0.005, 0.04, Vector3(hx, hy, zw + 0.02), _brass).rotation_degrees.x = 90.0
			if n in gone:
				continue
			if n in [1, 6, 10, 17]:           # these keys come off their hooks
				_thing("Fob%d" % (101 + n), Vector3(hx, hy - 0.11, zw + 0.035))
				continue
			_box(Vector3(0.012, 0.06, 0.004), Vector3(hx, hy - 0.04, zw + 0.035), _brass)
			_box(Vector3(0.035, 0.07, 0.008), Vector3(hx, hy - 0.11, zw + 0.035), _flat(fob_cols[n % 4], 0.35))
			var tag := _pic("keyfob.png", Vector2(0.035, 0.07), Vector3(hx, hy - 0.11, zw + 0.0395))
			tag.material_override.albedo_color = fob_cols[n % 4].lightened(0.2)
	# Staff mail: a pine box of pigeonholes, a few with notes in them.
	var cx0 := -0.95
	var cx1 := 0.35
	G.block(cx0, cx1, 1.2, 2.0, Z0, Z0 + 0.28, _wood)
	var hole := _flat(Color(0.12, 0.08, 0.05), 0.9)
	var note := _flat(Color(0.95, 0.93, 0.86), 0.9)
	for r in 3:
		for c in 4:
			var x := cx0 + 0.06 + c * 0.31 + 0.13
			var y := 1.29 + r * 0.25 + 0.1
			_box(Vector3(0.26, 0.2, 0.01), Vector3(x, y, Z0 + 0.282), hole)
			if r == 1 and c == 2:            # a memo for Dave, sticking out
				_pic("mail_note.png", Vector2(0.15, 0.15), Vector3(x, y - 0.01, Z0 + 0.29), Vector3(0, 0, -5))
			elif (r * 4 + c) % 3 == 0:
				_box(Vector3(0.18, 0.12, 0.004), Vector3(x, y - 0.03, Z0 + 0.29), note).rotation_degrees.z = 6.0
	_text("STAFF MAIL", Vector3(-0.3, 2.04, Z0 + 0.285), 0.0, 0.0014, Color(0.9, 0.8, 0.55), 40)
	# The station's carved sign over the key board.
	G.block(-2.86, -1.04, 1.99, 2.45, Z0, zw - 0.01, _wood)
	_pic("station_sign.png", Vector2(1.8, 0.45), Vector3(-1.95, 2.22, zw - 0.008))
	_wall_clock(Vector3(1.25, 2.05, Z0))
	_text("ALL VISITORS\nMUST SIGN IN", Vector3(1.25, 1.7, zw + 0.005), 0.0, 0.0015, Color(0.2, 0.12, 0.06), 40)
	# The station's framed L-7 containment certificate.
	G.block(0.79, 1.35, 1.06, 1.62, Z0, zw + 0.02, _wood)
	_pic("notice.png", Vector2(0.5, 0.5), Vector3(1.07, 1.34, zw + 0.021))


## A wall clock with the agency's face, telling the real time.
func _wall_clock(at: Vector3) -> void:
	var rim := _cyl(0.17, 0.17, 0.045, at + Vector3(0, 0, 0.0225), _flat(Color(0.12, 0.08, 0.05), 0.4))
	rim.rotation_degrees.x = 90.0
	_pic("clock_face.png", Vector2(0.31, 0.31), at + Vector3(0, 0, 0.0455), Vector3.ZERO, 0.0, true)
	var black := _flat(Color(0.05, 0.05, 0.06), 0.4)
	var hands: Array[Node3D] = []
	for h in [[0.085, 0.012, 0.047], [0.125, 0.007, 0.049]]:
		var pivot := Node3D.new()
		pivot.position = at + Vector3(0, 0, h[2])
		level.add_child(pivot)
		var hand := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(h[1], h[0], 0.002)
		hand.mesh = b
		hand.material_override = black
		hand.position = Vector3(0, h[0] * 0.5 - 0.012, 0)
		pivot.add_child(hand)
		hands.append(pivot)
	_clock_h = hands[0]
	_clock_m = hands[1]


## Along the west wall: the soda machine, the coffee station and the rack of F.A.L.C.O.N. pamphlets.
func _west_wall() -> void:
	var xw := X0 + 0.03
	# The soda machine: red cabinet, a lit front panel, a column of buttons.
	G.block(xw, xw + 0.72, 0.0, 1.8, -1.75, -0.95, _flat(Color(0.7, 0.08, 0.06), 0.35, 0.2))
	# Its lit Chlora-Cola front; the selection buttons sit on the plain strip down its right side.
	_pic("soda_front.png", Vector2(0.48, 0.96), Vector3(xw + 0.722, 1.15, -1.42), Vector3(0, 90, 0), 1.15)
	for i in 6:
		_box(Vector3(0.02, 0.06, 0.055), Vector3(xw + 0.73, 1.45 - i * 0.12, -1.62), _glow(Color(0.95, 0.85, 0.6), 0.9))
	_box(Vector3(0.02, 0.12, 0.3), Vector3(xw + 0.73, 0.35, -1.42), _flat(Color(0.05, 0.05, 0.05), 0.5))
	# Press a button (grab it, or interact) and a can drops into the tray: six in the machine.
	G.block(xw + 0.72, xw + 0.88, 0.24, 0.27, -1.58, -1.26, _flat(Color(0.12, 0.12, 0.12), 0.4, 0.6))
	var buttons := preload("res://items/lever_handle.gd").new("soda", 0.22)
	buttons.name = "SodaButtons"
	level.get_node("Props").add_child(buttons)
	buttons.global_position = Vector3(xw + 0.76, 1.15, -1.62)
	for i in 6:
		var can := "Soda%d" % (i + 1)
		level._spawn_item("prop", can, SODA_TRAY)
		level.items[can].set_stowed(level.IN_MACHINE)
	_pic("soda_side.png", Vector2(0.7, 1.4), Vector3(xw + 0.36, 0.95, -0.947))
	_pic("soda_side.png", Vector2(0.7, 1.4), Vector3(xw + 0.36, 0.95, -1.753), Vector3(0, 180, 0))
	# Free coffee: a little cabinet with a coffee maker, its pot, cups and sugar.
	G.block(xw, xw + 0.5, 0.0, 0.88, -0.25, 0.75, _wood)
	_box(Vector3(0.24, 0.34, 0.22), Vector3(xw + 0.17, 1.05, 0.0), _flat(Color(0.06, 0.06, 0.06), 0.4))
	var pot := _flat(Color(0.25, 0.12, 0.05), 0.1)
	pot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pot.albedo_color = Color(0.3, 0.14, 0.06, 0.85)
	_cyl(0.06, 0.07, 0.14, Vector3(xw + 0.3, 0.95, 0.0), pot)
	_box(Vector3(0.01, 0.01, 0.01), Vector3(xw + 0.29, 0.89, 0.1), _glow(Color(1.0, 0.1, 0.05), 1.5))
	var cup := _flat(Color(0.97, 0.96, 0.93), 0.8)
	for i in 4:
		_cyl(0.035, 0.03, 0.09, Vector3(xw + 0.3, 0.925 + i * 0.03, 0.42), cup)
	_label_can(0.05, 0.15, Vector3(xw + 0.24, 0.955, 0.6), "coffee_label.png")      # Floater's
	_thing("Cup1", Vector3(xw + 0.38, 0.925, 0.17))
	_thing("Cup2", Vector3(xw + 0.38, 0.925, 0.27))
	_text("COFFEE\nSTAFF & VISITORS", Vector3(X0 + 0.035, 1.55, 0.25), 90.0, 0.0018, Color(0.35, 0.15, 0.05), 48)
	# F.A.L.C.O.N. pamphlets for visitors and new staff.
	G.block(xw, xw + 0.04, 0.95, 1.75, 1.05, 1.85, _wood)
	_text("TAKE ONE", Vector3(xw + 0.045, 1.81, 1.45), 90.0, 0.0016, Color(0.25, 0.12, 0.05), 40)
	# WATER SAFETY, YOUR FIRST DAY, LIMINAL ENTITIES, IF YOU ARE TAKEN, STAFF BENEFITS, WET FOOTPRINTS?
	for r in 3:
		G.block(xw + 0.04, xw + 0.1, 1.0 + r * 0.25, 1.03 + r * 0.25, 1.05, 1.85, _wood)
		for c in 3:
			var i := (r * 3 + c) % 6
			_thing("Pamphlet%d_%d" % [i + 1, r * 3 + c], Vector3(xw + 0.07, 1.13 + r * 0.25, 1.18 + c * 0.25), Vector3(-8, 90, 0))
	# Visitor rules, by the end of the counter; no splashing, by the door.
	_pic("poster_4.png", Vector2(0.6, 0.8), Vector3(X0 + 0.006, 1.55, -2.75), Vector3(0, 90, 0))
	_pic("poster_3.png", Vector2(0.6, 0.8), Vector3(X0 + 0.006, 1.55, 2.55), Vector3(0, 90, 0))
	_prop(P + "potted_plant_01.glb", Vector3(-3.62, 0.0, 3.1), 0.0)
	_solid(Vector3(-3.62, 0.0, 3.1), Vector3(0.5, 1.3, 0.5))


## An orange cone fireplace in the corner, on a stone hearth, with a fire flickering in it.
func _fireplace() -> void:
	var f := FIREPLACE
	_box(Vector3(1.15, 0.06, 1.15), f + Vector3(0, 0.03, 0), _flat(Color(0.32, 0.3, 0.28), 0.9))
	var enamel := _flat(Color(0.92, 0.36, 0.08), 0.22, 0.15)
	_cyl(0.42, 0.42, 0.36, f + Vector3(0, 0.24, 0), enamel)                     # the bowl
	_cyl(0.11, 0.42, 0.72, f + Vector3(0, 0.78, 0), enamel)                     # the cone
	_cyl(0.1, 0.1, H - 1.14, f + Vector3(0, 1.14 + (H - 1.14) * 0.5, 0), _flat(Color(0.1, 0.1, 0.1), 0.5, 0.6))
	for leg in [Vector3(0.28, 0, 0.18), Vector3(-0.28, 0, 0.18), Vector3(0, 0, -0.32)]:
		_cyl(0.02, 0.02, 0.06, f + leg + Vector3(0, 0.09, 0), _flat(Color(0.1, 0.1, 0.1), 0.5, 0.6))
	_solid(f, Vector3(0.95, 1.2, 0.95))
	_solid(f + Vector3(0, 1.2, 0), Vector3(0.22, H - 1.2, 0.22))
	# The opening faces into the room (north-west), towards the armchair, with the fire inside.
	var face := Vector3(-0.72, 0, -0.69).normalized()
	var mouth := MeshInstance3D.new()
	var mq := QuadMesh.new()
	mq.size = Vector2(0.42, 0.32)
	mouth.mesh = mq
	_fire_mat = _glow(Color(1.0, 0.45, 0.12), 1.4)
	mouth.material_override = _fire_mat
	mouth.basis = Basis.looking_at(-face, Vector3.UP)
	mouth.position = f + face * 0.43 + Vector3(0, 0.36, 0)
	level.add_child(mouth)
	_fire_light = _light(f + face * 0.7 + Vector3(0, 0.45, 0), Color(1.0, 0.5, 0.18), 1.1, 4.0)


## The TV nook by the east wall: a couch facing the TV, a leather armchair, a coffee table on a plaid
## rug with the tape and some magazines, a lamp on a tall side table, plants.
func _tv_nook() -> void:
	var rug := MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(2.6, 3.3)
	rug.mesh = rq
	var rm := StandardMaterial3D.new()
	rm.albedo_texture = load(LOBBY + "plaid_color.jpg")
	rm.normal_enabled = true
	rm.normal_texture = load(LOBBY + "plaid_normal.jpg")
	rm.uv1_scale = Vector3(3.0, 3.8, 1.0)
	rm.roughness = 0.95
	rug.material_override = rm
	rug.rotation_degrees.x = -90.0
	rug.position = Vector3(2.55, 0.006, -0.6)
	level.add_child(rug)
	_prop(P + "sofa_03.glb", Vector3(1.5, 0.0, -0.6), 90.0)
	_solid(Vector3(1.5, 0.0, -0.6), Vector3(2.73, 0.48, 0.92), 90.0)                              # the seat
	_solid(Vector3(1.5, 0.0, -0.6), Vector3(2.73, 1.0, 0.3), 90.0, Vector3(0, 0, -0.31))          # its back
	_prop("res://assets/props/intro_armchair.glb", Vector3(2.75, 0.0, 1.55), 149.0)
	_solid(Vector3(2.75, 0.0, 1.55), Vector3(0.82, 0.5, 0.98), 149.0)
	_solid(Vector3(2.75, 0.0, 1.55), Vector3(0.82, 1.0, 0.26), 149.0, Vector3(0, 0, -0.36))
	_prop(P + "coffeetable_01.glb", COFFEE_TABLE, 90.0)
	level._hidden_block(COFFEE_TABLE.x - 0.45, COFFEE_TABLE.x + 0.45, 0.0, 0.52, COFFEE_TABLE.z - 0.7, COFFEE_TABLE.z + 0.7)
	# Three old issues of Liminal Geographic, the right way up for whoever's on the couch.
	for m in [[3, Vector3(2.75, 0.527, -1.05), 15.0], [1, Vector3(2.82, 0.534, -0.97), -10.0], [2, Vector3(2.7, 0.527, -0.05), 4.0]]:
		_thing("Magazine%d" % m[0], m[1], Vector3(-90, -90.0 + m[2], 0))
	# A table lamp on a tall side table at the end of the couch: the vase is its base.
	_prop(P + "side_table_tall_01.glb", Vector3(1.45, 0.0, 1.15), 0.0)
	_solid(Vector3(1.45, 0.0, 1.15), Vector3(0.4, 1.4, 0.4))
	_prop(P + "antique_ceramic_vase_01.glb", Vector3(1.45, 0.76, 1.15), 0.0).scale = Vector3.ONE * 0.8
	var shade := _cyl(0.12, 0.2, 0.24, Vector3(1.45, 1.27, 1.15), _glow(Color(1.0, 0.86, 0.62), 1.1))
	shade.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	_light(Vector3(1.45, 1.2, 1.15), Color(1.0, 0.78, 0.5), 0.8, 3.5)
	_prop(P + "potted_plant_01.glb", Vector3(3.55, 0.0, -3.0), 120.0)
	_solid(Vector3(3.55, 0.0, -3.0), Vector3(0.5, 1.3, 0.5))
	# Agency posters: the safety rule over the TV corner, recruiting over the armchair.
	_pic("poster_1.png", Vector2(0.6, 0.8), Vector3(X1 - 0.006, 1.55, -2.3), Vector3(0, -90, 0))
	_pic("poster_2.png", Vector2(0.6, 0.8), Vector3(X1 - 0.006, 1.6, 1.6), Vector3(0, -90, 0))
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
	tv_light.visible = not Game.vr_mode
	led_mat = tvs.led_mat
	subs = tvs.subs
	video.finished.connect(_on_tape_end)
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
	level._hidden_block(X1 - 0.6, X1, 0.0, 0.83, -1.26, 0.06)        # the cabinet, to stand things on
	level._spawn_item("tape", "Tape", COFFEE_TABLE + Vector3(-0.1, 0.53, 0.25))
	level._spawn_item("tape", "Tape08", COFFEE_TABLE + Vector3(-0.15, 0.53, -0.05))     # 08-E, the second tape


## The felt letter board: the room code and who's here.
func _letter_board() -> void:
	var at := Vector3(2.9, 1.55, Z0 + 0.04)
	G.block(at.x - 0.75, at.x + 0.75, at.y - 0.52, at.y + 0.52, Z0, Z0 + 0.03, _wood)
	var felt := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(1.4, 0.94)
	felt.mesh = fq
	felt.material_override = _flat(Color(0.03, 0.03, 0.035), 0.95)
	felt.position = at
	level.add_child(felt)
	info = Label3D.new()
	info.position = at + Vector3(0, 0, 0.005)
	info.pixel_size = 0.0017
	info.font_size = 40
	info.width = 780
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.modulate = Color(0.95, 0.94, 0.9)
	info.outline_size = 0
	level.add_child(info)


# --- Every frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if _fan:
		_fan.rotation.y += delta * 1.6
	if _clock_m:
		var now := Time.get_time_dict_from_system()
		var mins: float = now.minute + now.second / 60.0
		_clock_m.rotation.z = -TAU * mins / 60.0
		_clock_h.rotation.z = -TAU * (fmod(now.hour, 12.0) + mins / 60.0) / 12.0
	if _fire_light:
		# A slow, gentle glow: nothing that flickers 3-30 times a second (that can set off seizures).
		var f := 1.0 + 0.06 * sin(_t * 1.7) + 0.04 * sin(_t * 2.9 + 1.3)
		_fire_light.light_energy = 1.0 * f
		_fire_mat.albedo_color = Color(1.0, 0.45, 0.12) * (1.3 + 0.05 * f)
	_check_leaving(delta)
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


## Standing on the doormat by the front door for two seconds leaves the station: back to the title
## (for the host that ends the session for everyone, so the board says so).
func _check_leaving(delta: float) -> void:
	var me = level.local_player
	if not me or Game.fader.busy or _countdown > 0:
		_leave_t = 0.0
		return
	var p: Vector3 = me.body_position()
	if p.x > -3.3 and p.x < -2.3 and p.z > 2.85:
		if _leave_t == 0.0:
			Game.notify("Leaving the field station... step back to stay." if not (Net.is_host() and Net.players.size() > 1)
				else "Leaving ends the game for everyone... step back to stay.")
		_leave_t += delta
		if _leave_t >= 2.0:
			_leave_t = -1000.0
			Game.go_to_menu("You left the field station.")
	elif _leave_t > 0.0:
		_leave_t = 0.0


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
		_ips_t -= 0.5
		if _ips_t <= 0.0:
			_ips_t = 5.0
			_ips = Net.local_addresses()
		if not _ips.is_empty():
			code = "ON THIS WI-FI  %s\n" % _ips[0]
	var start := "RING THE BELL AT THE DESK TO START" if Net.is_host() or not Net.is_online() \
		else "WAITING FOR %s TO RING THE BELL" % host_name
	start = "TO: %s\n%s" % [Game.MAPS.get(Game.level_map, "?"), start]
	if _countdown > 0:
		start = "GOING IN IN %d . . ." % _countdown
	info.text = "WELCOME TO THE FIELD STATION\n\n%sHERE (%d/%d): %s\n\n%s\n\nTHE TAPES ARE ON THE COFFEE TABLE" % [
		code, names.size(), Net.MAX_PLAYERS, ", ".join(names), start]


## Where the host is taking everyone (the sign on the desk and the letter board).
func on_map(map: String) -> void:
	if _dest_label:
		_dest_label.text = "DESTINATION\n%s" % Game.MAPS.get(map, "?")
	if info:
		_update_info()


## The host rang the bell: n seconds to go (a tick each second on everyone's headset).
func on_countdown(n: int) -> void:
	_countdown = n
	if n > 0:
		level._sfx("ding", BELL)
		Game.notify("Going in in %d..." % n)
	_update_info()


## The tape in the VCR changed: which ("" when it's empty).
func on_vhs(which: String) -> void:
	var on := which != ""
	if on == playing:
		return
	playing = on
	if on:
		var t: Array = TAPES.get(which, TAPES["Tape"])
		video.stream = load(t[0])
		_cues = INTRO._load_srt(t[1])
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
		video.get_parent().render_target_update_mode = SubViewport.UPDATE_ALWAYS
		tv_light.visible = true
		video.play()
	else:
		video.stop()
		video.get_parent().render_target_update_mode = SubViewport.UPDATE_DISABLED
		tv_light.visible = not Game.vr_mode           # an empty blue screen doesn't need a light on the headset
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
	var which: String = level.state.vhs
	level.set_state("vhs", "")
	if which == "":
		return
	var out := SLOT + (TV_CORNER.basis * Vector3(0, -0.01, 0.2))
	level._set_item_stowed_at(which, 0, out)
	Net.send(level, &"_set_item_stowed_at", [which, 0, out])
