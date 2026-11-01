class_name Gore
extends RefCounted
## The mess the creature leaves: blood spraying from a bite, a red mist, a blood cloud spreading
## through the water, chunks of flesh and bone floating on the surface, the victim's torn-off glove,
## torn-off pieces and organs. All made in code (shapes, noise and shaders), apart from the approved
## spine and organ models.

const GLOVE_L := preload("res://addons/godot-xr-tools/hands/model/Hand_low_L.gltf")
const GLOVE_R := preload("res://addons/godot-xr-tools/hands/model/Hand_low_R.gltf")
const GLOVE_MAT := preload("res://addons/godot-xr-tools/hands/materials/cleaning_glove.tres")

static var _blood_mat: StandardMaterial3D
static var _flesh_mat: ShaderMaterial
static var _bone_mat: StandardMaterial3D
static var _noise: NoiseTexture2D
static var _mist_tex: GradientTexture2D
static var _mist_mat: StandardMaterial3D
## Kept loaded for the whole level, so a kill never waits on the disk (the organs took a third of
## a second to load on a desktop, longer on a headset).
static var _spine_scene: PackedScene
static var _organ_scenes: Array[PackedScene] = []
## One of each shader, shared: a new Shader per blood pool or gut meant a fresh compile each time.
static var _pool_shader: Shader
static var _gut_shader: Shader
static var _blur_shader: Shader

const POOL_SHADER := """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D noise_tex : repeat_enable;
uniform float age = 0.0;
uniform float spread_time = 7.0;
uniform float life = 120.0;
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float g = clamp(age / spread_time, 0.0, 1.0);
	g = 1.0 - pow(1.0 - g, 3.0);
	vec2 drift = vec2(age * 0.004, -age * 0.003) + seed;
	float n = texture(noise_tex, UV * 1.2 + drift).r;
	float n2 = texture(noise_tex, UV * 3.3 - drift * 0.5 + 0.37).r;
	float edge = g * (0.5 + 0.5 * n);
	float a = 1.0 - smoothstep(edge - 0.3, edge, r);
	a *= 0.45 + 0.55 * n2;
	a *= 1.0 - smoothstep(life * 0.6, life, age);
	ALBEDO = vec3(0.30, 0.0, 0.012) * (0.55 + 0.7 * n2);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
	ALPHA = clamp(a, 0.0, 0.92);
}
"""

const FLESH_SHADER := """shader_type spatial;
uniform sampler2D noise_tex : repeat_enable;
varying vec3 lp;
void vertex() { lp = VERTEX * length(MODEL_MATRIX[0].xyz); }   // in metres, whatever the mesh's units
void fragment() {
	float n = texture(noise_tex, lp.xy * 6.0 + lp.zx * 4.0).r;
	float f = texture(noise_tex, lp.yz * 9.0 + 0.5).r;
	vec3 meat = mix(vec3(0.22, 0.0, 0.01), vec3(0.55, 0.08, 0.08), n);
	vec3 fat = vec3(0.78, 0.62, 0.48);
	ALBEDO = mix(meat, fat, smoothstep(0.68, 0.78, f) * 0.7);
	ROUGHNESS = 0.18;
	SPECULAR = 0.7;
}
"""

static func _setup() -> void:
	if _blood_mat:
		return
	_noise = NoiseTexture2D.new()
	_noise.width = 256
	_noise.height = 256
	_noise.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	fn.fractal_octaves = 4
	_noise.noise = fn
	_blood_mat = StandardMaterial3D.new()
	_blood_mat.albedo_color = Color(0.32, 0.0, 0.015)
	_blood_mat.roughness = 0.12
	_blood_mat.metallic_specular = 0.7
	_flesh_mat = ShaderMaterial.new()
	var fs := Shader.new()
	fs.code = FLESH_SHADER
	_flesh_mat.shader = fs
	_flesh_mat.set_shader_parameter("noise_tex", _noise)
	_bone_mat = StandardMaterial3D.new()
	_bone_mat.albedo_color = Color(0.86, 0.82, 0.72)
	_bone_mat.roughness = 0.45
	var g := Gradient.new()
	g.set_color(0, Color(0.4, 0.0, 0.0, 0.7))
	g.set_color(1, Color(0.2, 0.0, 0.0, 0.0))
	_mist_tex = GradientTexture2D.new()
	_mist_tex.gradient = g
	_mist_tex.fill = GradientTexture2D.FILL_RADIAL
	_mist_tex.fill_from = Vector2(0.5, 0.5)
	_mist_tex.fill_to = Vector2(1.0, 0.5)
	_mist_tex.width = 64
	_mist_tex.height = 64
	_mist_mat = StandardMaterial3D.new()
	_mist_mat.albedo_texture = _mist_tex
	_mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mist_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mist_mat.vertex_color_use_as_albedo = true
	_pool_shader = Shader.new()
	_pool_shader.code = POOL_SHADER
	_gut_shader = Shader.new()
	_gut_shader.code = GUT_SHADER
	_blur_shader = Shader.new()
	_blur_shader.code = BLUR_SHADER
	if ResourceLoader.exists(SPINE_MODEL):
		_spine_scene = load(SPINE_MODEL)
	for path in ORGAN_MODELS:
		if ResourceLoader.exists(path):
			_organ_scenes.append(load(path))


## Build the materials and the splatter textures ahead of time (at level load), so the first kill
## doesn't hitch.
static func warm_up() -> void:
	_setup()


## Blood bursting out of a bite, in droplets that fall into the water.
static func spray(parent: Node, pos: Vector3, dir: Vector3, amount := 90, mist := true) -> void:
	_setup()
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = amount
	p.lifetime = 1.4
	p.local_coords = false
	p.direction = dir.normalized()
	p.spread = 40.0
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.8
	var m := SphereMesh.new()
	m.radius = 0.014
	m.height = 0.028
	m.radial_segments = 6
	m.rings = 3
	m.material = _blood_mat
	p.mesh = m
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	if mist:
		_mist(parent, pos)
	parent.get_tree().create_timer(2.5).timeout.connect(p.queue_free)


static func _mist(parent: Node, pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.7
	p.amount = 12
	p.lifetime = 1.6
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0, -0.3, 0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	q.material = _mist_mat
	p.mesh = q
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(2.5).timeout.connect(p.queue_free)


## Blood pouring from someone being held: keep it where they are, then stop it.
static func bleed(parent: Node) -> CPUParticles3D:
	_setup()
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 0.9
	p.local_coords = false
	p.direction = Vector3.DOWN
	p.spread = 25.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, -9.8, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	var m := SphereMesh.new()
	m.radius = 0.012
	m.height = 0.03
	m.radial_segments = 6
	m.rings = 3
	m.material = _blood_mat
	p.mesh = m
	parent.add_child(p)
	p.emitting = true
	return p


## A blood cloud spreading through the water from where someone was dragged under. Stays a while.
static func blood_pool(parent: Node, pos: Vector3, surface_y: float, size := 6.0) -> void:
	_setup()
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = _pool_shader
	mat.set_shader_parameter("noise_tex", _noise)
	mat.set_shader_parameter("seed", randf())
	mat.render_priority = 2
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.y = randf() * TAU
	var aging := _Ager.new()
	aging.mat = mat
	aging.life = 120.0
	mi.add_child(aging)
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, surface_y + 0.02, pos.z)


## Chunks of flesh (some with bone sticking out) thrown up and left floating, and the victim's
## torn-off glove in their suit's glove color.
static func remains(parent: Node, pos: Vector3, surface_y: float, glove_color: Color, count := 6, with_glove := true) -> void:
	_setup()
	for i in count:
		var chunk := Node3D.new()
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r := randf_range(0.04, 0.09)
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 7
		sm.rings = 4
		mi.mesh = sm
		mi.material_override = _flesh_mat
		mi.scale = Vector3(randf_range(0.9, 1.7), randf_range(0.45, 0.8), randf_range(0.8, 1.4))
		chunk.add_child(mi)
		if randf() < 0.5:
			var bone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.007
			cm.bottom_radius = 0.012
			cm.height = randf_range(0.08, 0.16)
			cm.radial_segments = 6
			bone.mesh = cm
			bone.material_override = _bone_mat
			bone.rotation = Vector3(randf_range(0.6, 1.4), randf() * TAU, 0)
			bone.position = bone.transform.basis.y * cm.height * 0.3
			chunk.add_child(bone)
		_float(parent, chunk, pos, surface_y)
	if not with_glove:
		return
	# The glove, torn off at the wrist.
	var glove := Node3D.new()
	var hand: Node3D = (GLOVE_L if randf() < 0.5 else GLOVE_R).instantiate()
	glove.add_child(hand)
	var gm: BaseMaterial3D = GLOVE_MAT.duplicate()
	gm.albedo_texture = null
	gm.albedo_color = glove_color.lightened(0.15)
	for m: MeshInstance3D in hand.find_children("*", "MeshInstance3D", true, false):
		m.material_override = gm
	var stump := MeshInstance3D.new()
	var st := CylinderMesh.new()
	st.top_radius = 0.034
	st.bottom_radius = 0.03
	st.height = 0.03
	stump.mesh = st
	stump.material_override = _flesh_mat
	stump.rotation_degrees = Vector3(90, 0, 0)
	stump.position = Vector3(0, 0, 0.075)
	glove.add_child(stump)
	var wrist_bone := MeshInstance3D.new()
	var wb := CylinderMesh.new()
	wb.top_radius = 0.008
	wb.bottom_radius = 0.011
	wb.height = 0.07
	wrist_bone.mesh = wb
	wrist_bone.material_override = _bone_mat
	wrist_bone.rotation_degrees = Vector3(90, 0, 0)
	wrist_bone.position = Vector3(0.008, 0, 0.1)
	glove.add_child(wrist_bone)
	_float(parent, glove, pos, surface_y)


## One torn-off chunk of flesh, maybe with bone sticking out (what it chews on after a kill that
## didn't open the body).
static func chunk() -> Node3D:
	_setup()
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	var r := randf_range(0.05, 0.08)
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 7
	sm.rings = 4
	mi.mesh = sm
	mi.material_override = _flesh_mat
	mi.scale = Vector3(randf_range(1.0, 1.6), randf_range(0.5, 0.8), randf_range(0.8, 1.3))
	n.add_child(mi)
	var bone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.012
	cm.height = 0.14
	cm.radial_segments = 6
	bone.mesh = cm
	bone.material_override = _bone_mat
	bone.rotation = Vector3(1.1, randf() * TAU, 0)
	n.add_child(bone)
	return n


static func _float(parent: Node, n: Node3D, pos: Vector3, surface_y: float) -> void:
	var f := _Floater.new()
	f.surface_y = surface_y
	f.velocity = Vector3(randf_range(-1.2, 1.2), randf_range(1.5, 3.5), randf_range(-1.2, 1.2))
	f.spin = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	f.add_child(n)
	parent.add_child(f)
	f.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
	f.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)


## Something tossed up by the kill: flies, lands in the water and floats there, bobbing and drifting.
class _Floater extends Node3D:
	var surface_y := 0.0
	var velocity := Vector3.ZERO
	var spin := Vector3.ZERO
	var _t := 0.0
	var _floating := false
	var _resting := false
	var _seed := randf() * 10.0

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t > 120.0:
			queue_free()
		if _resting:
			return
		var old := global_position
		var p := old
		if not _floating:
			velocity.y -= 9.8 * delta
			p += velocity * delta
			rotation += spin * delta
			if p.y <= surface_y and velocity.y < 0.0 and Gore.water_below(p):
				_floating = true
				velocity = Vector3(velocity.x, 0, velocity.z) * 0.15
		else:
			velocity *= 1.0 - delta * 0.2
			p += velocity * delta
			p.y = surface_y + sin(_t * 1.4 + _seed) * 0.008
			rotation.y += delta * 0.05
		# Walls and floors stop it (it lands on dry floor if it was thrown out of the water).
		var hit := Gore.sweep(self, old, p, 0.05)
		if not hit.is_empty():
			var n: Vector3 = hit.normal
			p = hit.position + n * 0.05
			velocity = (velocity - n * velocity.dot(n) * 1.3) * 0.4
			spin *= 0.5
			if n.y > 0.6 and velocity.length() < 0.6 and not _floating:
				_resting = true
		global_position = p


## Ages a blood cloud's shader and removes it when it has faded.
class _Ager extends Node:
	var mat: ShaderMaterial
	var life := 120.0
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		mat.set_shader_parameter("age", _age)
		if _age > life:
			get_parent().queue_free()


# --- Dismemberment ------------------------------------------------------------------------------

## Approved models replace these stand-ins when present (the spine and organs from Round 21).
const SPINE_MODEL := "res://assets/gore/spine.glb"
const ORGAN_MODELS := ["res://assets/gore/heart.glb", "res://assets/gore/lungs.glb", "res://assets/gore/liver.glb",
	"res://assets/gore/stomach.glb", "res://assets/gore/kidney.glb"]

const GUT_SHADER := """shader_type spatial;
uniform sampler2D noise_tex : repeat_enable;
varying vec2 uv2;
void vertex() { uv2 = UV; }
void fragment() {
	float ring = 0.5 + 0.5 * sin(uv2.y * 70.0);
	float n = texture(noise_tex, uv2 * vec2(2.0, 9.0)).r;
	vec3 c = mix(vec3(0.62, 0.22, 0.2), vec3(0.85, 0.45, 0.4), n);
	c = mix(c * 0.55, c, smoothstep(0.1, 0.6, ring));
	ALBEDO = c;
	ROUGHNESS = 0.12;
	SPECULAR = 0.8;
}
"""


static func flesh_material() -> ShaderMaterial:
	_setup()
	return _flesh_mat


static func bone_material() -> StandardMaterial3D:
	_setup()
	return _bone_mat


## A cut surface: raw flesh with a ring of skin and a bone in the middle. Its normal is +Y.
static func cap(radius: float, with_bone := true) -> Node3D:
	_setup()
	var n := Node3D.new()
	var d := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius * 0.92
	cm.height = 0.025
	cm.radial_segments = 12
	cm.rings = 1
	d.mesh = cm
	d.material_override = _flesh_mat
	n.add_child(d)
	if with_bone:
		var b := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = radius * 0.22
		bm.bottom_radius = radius * 0.25
		bm.height = 0.06
		bm.radial_segments = 8
		b.mesh = bm
		b.material_override = _bone_mat
		b.position = Vector3(0, 0.02, -radius * 0.25)
		n.add_child(b)
	return n


## The spine torn out with the head: hangs down (-Y) from its top. The approved model if present,
## otherwise a column of vertebrae with their spines and a trailing cord.
static func spine() -> Node3D:
	_setup()
	if _spine_scene:
		return _spine_scene.instantiate()
	var root := Node3D.new()
	var y := 0.0
	for i in 24:
		var t := float(i) / 23.0
		var w := lerpf(0.018, 0.034, t)            # vertebrae grow toward the lower back
		var h := lerpf(0.018, 0.03, t)
		var v := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = w
		cm.bottom_radius = w * 1.05
		cm.height = h
		cm.radial_segments = 8
		v.mesh = cm
		v.material_override = _bone_mat
		var curve := sin(t * TAU) * 0.025          # the S curve of a spine
		v.position = Vector3(0, y - h * 0.5, curve)
		root.add_child(v)
		var proc := MeshInstance3D.new()           # the spinous process sticking out the back
		var pm := BoxMesh.new()
		pm.size = Vector3(w * 0.35, h * 0.6, w * 1.4)
		proc.mesh = pm
		proc.material_override = _bone_mat
		proc.position = Vector3(0, y - h * 0.6, curve + w * 1.1)
		proc.rotation.x = 0.5
		root.add_child(proc)
		if i % 2 == 0:
			var meat := MeshInstance3D.new()       # shreds of flesh still on it
			var sm := SphereMesh.new()
			sm.radius = w * 0.9
			sm.height = w * 1.2
			sm.radial_segments = 6
			sm.rings = 3
			meat.mesh = sm
			meat.material_override = _flesh_mat
			meat.position = Vector3(randf_range(-1, 1) * w * 0.8, y - h * 0.3, curve - w * 0.4)
			root.add_child(meat)
		y -= h + 0.006
	return root


## Organs spilling from a torn torso. The approved models if present, otherwise rough stand-ins.
static func organs() -> Array[Node3D]:
	_setup()
	var out: Array[Node3D] = []
	for sc in _organ_scenes:
		out.append(sc.instantiate())
	if not out.is_empty():
		return out
	# Stand-ins: liver, stomach, heart, two kidneys, a lung.
	for spec in [[Vector3(0.11, 0.05, 0.08), 0.0], [Vector3(0.07, 0.05, 0.06), 0.3], [Vector3(0.05, 0.06, 0.045), -0.2],
			[Vector3(0.035, 0.05, 0.025), 0.1], [Vector3(0.035, 0.05, 0.025), 0.1], [Vector3(0.06, 0.11, 0.05), 0.4]]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 10
		sm.rings = 6
		mi.mesh = sm
		mi.material_override = _flesh_mat
		mi.scale = spec[0]
		var n := Node3D.new()
		n.add_child(mi)
		out.append(n)
	return out


## Spill organs from a point: they tumble out, fall into the water and float there.
static func spill(parent: Node, pos: Vector3, surface_y: float, push: Vector3, ready_made: Array = []) -> void:
	for o in (ready_made if not ready_made.is_empty() else organs()):
		var f := _Floater.new()
		f.surface_y = surface_y
		f.velocity = push + Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 1.2), randf_range(-0.6, 0.6))
		f.spin = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
		f.add_child(o)
		parent.add_child(f)
		f.global_position = pos + Vector3(randf_range(-0.08, 0.08), randf_range(-0.05, 0.05), randf_range(-0.08, 0.08))


## Intestines hanging out: a soft rope between two points that swings and drapes into the water.
## a and b are nodes it hangs from; it lets go of b when stretched too far.
static func gut(parent: Node, a: Node3D, b: Node3D, length := 1.8, floor_y := -0.95) -> Node3D:
	_setup()
	var g := _Gut.new()
	g.a = a
	g.b = b
	g.length = length
	g.floor_y = floor_y
	var mat := ShaderMaterial.new()
	mat.shader = _gut_shader
	mat.set_shader_parameter("noise_tex", _noise)
	g.material_override = mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(g)
	return g


## Blood pumping out of a stump, in spurts. Keep it where the stump is; it stops by itself.
static func fountain(parent: Node, seconds := 3.0) -> CPUParticles3D:
	var p := bleed(parent)
	p.direction = Vector3.UP
	p.spread = 18.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.6
	p.amount = 90
	p.emission_sphere_radius = 0.03
	var tw := p.create_tween().set_loops(int(seconds / 0.5))
	tw.tween_property(p, "initial_velocity_max", 3.2, 0.12)
	tw.tween_property(p, "initial_velocity_max", 1.4, 0.38)
	parent.get_tree().create_timer(seconds).timeout.connect(func(): if is_instance_valid(p): p.emitting = false)
	parent.get_tree().create_timer(seconds + 1.5).timeout.connect(p.queue_free)
	return p


class _Gut extends MeshInstance3D:
	var a: Node3D
	var b: Node3D
	var length := 1.8
	var floor_y := -0.95
	var radius := 0.022
	var _pts: PackedVector3Array = []
	var _old: PackedVector3Array = []
	var _attached_b := true
	var _t := 0.0
	const N := 22

	func _ready() -> void:
		var p0: Vector3 = a.global_position if is_instance_valid(a) else global_position
		var p1: Vector3 = b.global_position if is_instance_valid(b) else p0 + Vector3.DOWN * length
		for i in N:
			var p := p0.lerp(p1, float(i) / (N - 1)) + Vector3(0, -sin(PI * i / (N - 1)) * 0.2, 0)
			_pts.append(p)
			_old.append(p)
		top_level = true
		global_transform = Transform3D.IDENTITY

	func _process(delta: float) -> void:
		_t += delta
		var dt := minf(delta, 1.0 / 30.0)
		var seg := length / (N - 1)
		for i in N:
			var v := (_pts[i] - _old[i]) * 0.985
			_old[i] = _pts[i]
			_pts[i] += v + Vector3(0, -9.8, 0) * dt * dt
			if _pts[i].y < floor_y + radius:
				_pts[i].y = floor_y + radius
		for k in 6:
			if is_instance_valid(a):
				_pts[0] = a.global_position
			if _attached_b and is_instance_valid(b):
				_pts[N - 1] = b.global_position
			for i in N - 1:
				var d := _pts[i + 1] - _pts[i]
				var l := d.length()
				if l < 1e-5:
					continue
				var diff := d * (1.0 - seg / l)
				var pin0 := i == 0
				var pin1 := i + 1 == N - 1 and _attached_b
				if pin0 and pin1:
					continue
				elif pin0:
					_pts[i + 1] -= diff
				elif pin1:
					_pts[i] += diff
				else:
					_pts[i] += diff * 0.5
					_pts[i + 1] -= diff * 0.5
		if _attached_b and is_instance_valid(a) and is_instance_valid(b) and a.global_position.distance_to(b.global_position) > length * 1.15:
			_attached_b = false            # it tears loose from the lower half and dangles
		_rebuild()
		if _t > 120.0:
			queue_free()

	func _rebuild() -> void:
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		var sides := 6
		for i in N:
			var fwd := (_pts[mini(i + 1, N - 1)] - _pts[maxi(i - 1, 0)]).normalized()
			var side := fwd.cross(Vector3.UP)
			if side.length() < 0.01:
				side = fwd.cross(Vector3.RIGHT)
			side = side.normalized()
			var up := side.cross(fwd).normalized()
			var r := radius * (1.0 + 0.25 * sin(i * 1.7))
			for k in sides:
				var ang := TAU * k / sides
				var nrm := side * cos(ang) + up * sin(ang)
				verts.append(_pts[i] + nrm * r)
				norms.append(nrm)
				uvs.append(Vector2(float(k) / sides, float(i) / (N - 1)))
		for i in N - 1:
			for k in sides:
				var a0 := i * sides + k
				var a1 := i * sides + (k + 1) % sides
				var b0 := a0 + sides
				var b1 := a1 + sides
				idx.append_array([a0, b0, a1, a1, b0, b1])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh = am


const BLUR_SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, skip_vertex_transform;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
void vertex() { POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0); }
void fragment() {
	vec3 c = vec3(0.0);
	for (int i = 0; i < 16; i++) {
		float a = float(i) * 2.399963;
		float r = sqrt((float(i) + 0.5) / 16.0) * amount * 0.035;
		c += texture(screen_tex, SCREEN_UV + vec2(cos(a), sin(a)) * r).rgb;
	}
	c /= 16.0;
	float v = length(SCREEN_UV - 0.5) * 1.6;
	ALBEDO = c * (1.0 - amount * 0.45 * v * v);
	ALPHA = clamp(amount * 4.0, 0.0, 1.0);
}
"""


## The victim's vision going blurry (set "amount" from 0 to 1).
static func blur_overlay(cam: Camera3D) -> MeshInstance3D:
	_setup()
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = _blur_shader
	mat.render_priority = 99
	mi.material_override = mat
	mi.extra_cull_margin = 16384.0
	mi.position = Vector3(0, 0, -0.3)
	cam.add_child(mi)
	return mi


## Let go of a torn-off piece: it falls, tips over to lie in the water and floats there a while.
static func drop(piece: Node3D, surface_y: float, velocity := Vector3.ZERO, lie := true) -> void:
	var s := _Sinker.new()
	s.piece = piece
	s.surface_y = surface_y
	s.velocity = velocity
	s.lie = lie
	piece.add_child(s)


class _Sinker extends Node:
	var piece: Node3D
	var surface_y := -0.3
	var velocity := Vector3.ZERO
	var lie := true
	var _t := 0.0
	var _start := Basis()
	var _target := Basis()
	var _floating := false
	var _resting := false
	var _probes: Array[Vector3] = []      # points at the piece's extremities, in its own space

	func _ready() -> void:
		_start = piece.global_basis.orthonormalized()
		var yaw := randf() * TAU
		_target = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5) if lie else _start
		var inv := piece.global_transform.affine_inverse()
		if piece.has_method("extent_points"):
			for w in piece.extent_points():
				_probes.append(inv * w)
		if _probes.is_empty():
			_probes.append(Vector3.ZERO)

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t > 100.0:
			piece.queue_free()
			return
		var k := clampf(_t / 0.9, 0.0, 1.0)
		var b := _start.slerp(_target, k * k)
		var old := piece.global_transform
		var p := old.origin
		if _resting:
			piece.global_transform = Transform3D(b, p)
			return
		if not _floating:
			velocity.y -= 9.8 * delta
			p += velocity * delta
			if p.y <= surface_y - 0.12 and velocity.y < 0.0 and Gore.water_below(p):
				_floating = true
				velocity = Vector3(velocity.x, 0, velocity.z) * 0.1
		else:
			velocity *= 1.0 - delta * 0.5
			p += velocity * delta
			p.y = surface_y - 0.12 + sin(_t * 1.2) * 0.01
		# Every extremity is swept against the walls and floors: a hit pushes the whole piece back,
		# so a torn half never passes through a wall, and one thrown out of the water lies on the floor.
		var want := Transform3D(b, p)
		var push := Vector3.ZERO
		var normal := Vector3.ZERO
		for q in _probes:
			var hit := Gore.sweep(piece, old * q, want * q, 0.06)
			if not hit.is_empty():
				var corr: Vector3 = (hit.position as Vector3) + (hit.normal as Vector3) * 0.06 - want * q
				if corr.length() > push.length():
					push = corr
					normal = hit.normal
		if push != Vector3.ZERO:
			want.origin += push
			velocity = (velocity - normal * velocity.dot(normal) * 1.3) * 0.35
			if normal.y > 0.6 and velocity.length() < 0.5 and not _floating:
				_resting = true
		piece.global_transform = want


## Is there pool water under this point? (Dry floor isn't.)
static func water_below(p: Vector3) -> bool:
	return WaterVolume.below(Vector3(p.x, p.y + 0.5, p.z)) != null


## A ray from a to b (extended by margin) against the level's walls and floors.
static func sweep(n: Node3D, a: Vector3, b: Vector3, margin: float) -> Dictionary:
	if not n.is_inside_tree() or a.distance_squared_to(b) < 1e-10:
		return {}
	var d := b - a
	var q := PhysicsRayQueryParameters3D.create(a, b + d.normalized() * margin, LevelGeometry.L_WORLD)
	return n.get_world_3d().direct_space_state.intersect_ray(q)


## Keep a held piece out of walls: if a wall stands between `from` (the creature's chest) and any of
## the piece's extremities, slide the piece back to this side of it.
static func keep_out(piece: Node3D, from: Vector3) -> void:
	if not piece.has_method("extent_points") or not piece.is_inside_tree():
		return
	var push := Vector3.ZERO
	for w: Vector3 in piece.extent_points():
		var hit := sweep(piece, from, w, 0.08)
		if not hit.is_empty():
			var corr: Vector3 = (hit.position as Vector3) + (hit.normal as Vector3) * 0.08 - w
			if corr.length() > push.length():
				push = corr
	if push != Vector3.ZERO:
		piece.global_position += push


## Draw one of everything the kills use, once, in front of the camera while the screen is black at
## the start of the level: the headset compiles each shader the first time it draws it, and doing
## that mid-kill was a big part of the stutter. Also loads the torn-suit files.
static func warm_draw(parent: Node, cam: Camera3D) -> void:
	_setup()
	var rack := Node3D.new()
	parent.add_child(rack)
	rack.global_transform = cam.global_transform * Transform3D(Basis(), Vector3(0, -0.15, -1.4))
	var things: Array[Node3D] = [spine(), cap(0.08)]
	things.append_array(organs())
	for i in SuitRig.SUITS.size():
		var full := SuitRig.create(i, Color(0.8, 0.4, 0.1))
		full.show_only(["head", "upper"])
		things.append(full)
		var half := SuitRig.create(i, Color(0.8, 0.4, 0.1), "lr")
		half.show_only(["left"])
		things.append(half)
	var grey := SuitRig.create(1, Color.GRAY)
	grey.make_featureless()
	things.append(grey)
	for i in things.size():
		var t := things[i]
		rack.add_child(t)
		t.position = Vector3((i % 6 - 2.5) * 0.25, (i / 6) * 0.25 - 0.3, 0)
		t.scale = Vector3.ONE * 0.2
	var pool := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.4, 0.4)
	pool.mesh = pm
	var pmat := ShaderMaterial.new()
	pmat.shader = _pool_shader
	pmat.set_shader_parameter("noise_tex", _noise)
	pmat.set_shader_parameter("age", 3.0)
	pool.material_override = pmat
	rack.add_child(pool)
	pool.rotation.x = PI * 0.5
	var a := Node3D.new()
	var b := Node3D.new()
	rack.add_child(a)
	rack.add_child(b)
	a.position = Vector3(-0.3, 0.2, 0)
	b.position = Vector3(0.3, 0.2, 0)
	gut(rack, a, b, 0.8)
	spray(rack, rack.global_position, Vector3.UP, 6)
	fountain(rack, 0.4)
	for f in 4:
		await parent.get_tree().process_frame
	if is_instance_valid(rack):
		rack.queue_free()
