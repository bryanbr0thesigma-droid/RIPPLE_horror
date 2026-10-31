class_name SuitRig
extends Node3D
## A player in one of the three suits, in their color. Used for the character preview and for
## other players in the game. Stand-ins until the approved suit models are added: the anti-radiation
## suit (color tints the camo), the Striker jumpsuit (color is the stripes) and the diver (color is
## the panels and tank).

const SUITS := [
	{"name": "Anti-radiation suit", "about": "Baggy rubberized suit, hood and gas mask. Your color tints the camo.", "glove": Color(0.12, 0.14, 0.1)},
	{"name": "Striker jumpsuit", "about": "Fitted work jumpsuit and goggles. Your color is the stripes.", "glove": Color(0.07, 0.07, 0.08)},
	{"name": "Diver", "about": "Neoprene suit, diving helmet and air tank. Your color is the panels.", "glove": Color(0.05, 0.05, 0.06)},
]

var suit := 0
var color := Color.ORANGE
var hips: Node3D
var torso: Node3D
var head: Node3D
var arms: Array[Node3D] = []      # shoulder pivots; each holds a segment mesh along -Z
var arm_len: Array[float] = [0.6, 0.6]
var hands: Array[MeshInstance3D] = []
var legs: Array[Node3D] = []
var _base: StandardMaterial3D
var _accent: Material
var _dark: StandardMaterial3D
var _glass: StandardMaterial3D
var _t := 0.0
var idle := false


static func glove_color(index: int) -> Color:
	return SUITS[clampi(index, 0, SUITS.size() - 1)].glove


static func create(index: int, c: Color) -> SuitRig:
	var r := SuitRig.new()
	r.suit = clampi(index, 0, SUITS.size() - 1)
	r.color = c
	r._build()
	return r


func _build() -> void:
	_dark = _mat(SUITS[suit].glove, 0.75)
	_glass = _mat(Color(0.05, 0.07, 0.08), 0.08, 0.6)
	match suit:
		0:
			_base = null
			_accent = _camo(color)
		1:
			_base = _mat(Color(0.2, 0.21, 0.23), 0.85)
			_accent = _mat(color, 0.5)
		2:
			_base = _mat(Color(0.05, 0.05, 0.06), 0.5)
			_accent = _mat(color, 0.35)
	var body: Material = _accent if suit == 0 else _base
	hips = Node3D.new()
	add_child(hips)
	torso = Node3D.new()
	add_child(torso)
	head = Node3D.new()
	add_child(head)
	var chest_r := 0.2 if suit == 0 else 0.17
	_capsule(torso, chest_r, 0.62, body, Vector3(0, 0.0, 0))
	match suit:
		0:
			_box(torso, Vector3(0.3, 0.05, 0.25), _dark, Vector3(0, -0.28, 0))     # belt
			_capsule(head, 0.15, 0.36, _accent, Vector3(0, 0.02, 0.01))              # hood
			_sphere(head, 0.12, _dark, Vector3(0, -0.01, -0.06))                    # gas mask
			for s in [-1.0, 1.0]:
				_cyl(head, 0.038, 0.02, _glass, Vector3(0.05 * s, 0.03, -0.165), Vector3(90, 0, 0))
			_cyl(head, 0.045, 0.08, _dark, Vector3(0, -0.07, -0.17), Vector3(90, 0, 0))   # filter
		1:
			_box(torso, Vector3(0.36, 0.06, 0.02), _accent, Vector3(0, 0.12, -0.17))  # chest stripe
			_box(torso, Vector3(0.3, 0.05, 0.24), _dark, Vector3(0, -0.28, 0))
			_sphere(head, 0.12, _mat(Color(0.75, 0.6, 0.5), 0.8), Vector3.ZERO)
			_capsule(head, 0.125, 0.26, _base, Vector3(0, 0.03, 0.01))               # balaclava
			_box(head, Vector3(0.2, 0.06, 0.05), _glass, Vector3(0, 0.02, -0.11))   # goggles
			_box(head, Vector3(0.22, 0.02, 0.05), _accent, Vector3(0, 0.06, -0.1))
		2:
			_box(torso, Vector3(0.3, 0.3, 0.02), _accent, Vector3(0, 0.05, -0.16))   # chest panel
			_cyl(torso, 0.09, 0.5, _accent, Vector3(0, 0.02, 0.2))                   # air tank
			_cyl(torso, 0.02, 0.06, _dark, Vector3(0, 0.3, 0.2))
			_sphere(head, 0.16, _accent, Vector3.ZERO)                               # helmet
			_cyl(head, 0.11, 0.04, _glass, Vector3(0, 0.0, -0.14), Vector3(90, 0, 0))   # faceplate
			_cyl(head, 0.125, 0.02, _dark, Vector3(0, 0.0, -0.125), Vector3(90, 0, 0))
	for s in [-1.0, 1.0]:
		var leg := Node3D.new()
		hips.add_child(leg)
		leg.position = Vector3(0.1 * s, 0, 0)
		_capsule(leg, 0.075 if suit != 0 else 0.09, 0.8, body, Vector3(0, -0.4, 0))
		_box(leg, Vector3(0.12, 0.09, 0.22), _dark, Vector3(0, -0.8, -0.04))       # boot
		if suit == 1:
			_box(leg, Vector3(0.02, 0.6, 0.02), _accent, Vector3(0.075 * s, -0.4, 0))
		legs.append(leg)
		var arm := Node3D.new()
		torso.add_child(arm)
		arm.position = Vector3((chest_r + 0.05) * s, 0.22, 0)
		var seg := _capsule(arm, 0.06 if suit != 0 else 0.075, 0.6, body, Vector3(0, 0, -0.3), Vector3(90, 0, 0))
		seg.name = "Segment"
		if suit == 1:
			_box(arm, Vector3(0.02, 0.02, 0.5), _accent, Vector3(0.06 * s, 0, -0.3)).name = "Stripe"
		var hand := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.055
		hm.height = 0.11
		hand.mesh = hm
		hand.material_override = _dark
		arm.add_child(hand)
		hand.position = Vector3(0, 0, -0.6)
		hands.append(hand)
		arms.append(arm)


func _ready() -> void:
	stand()


# --- Posing --------------------------------------------------------------------------------------

## A neutral standing pose (feet at the origin), for the preview.
func stand() -> void:
	hips.position = Vector3(0, 0.88, 0)
	torso.position = Vector3(0, 1.22, 0)
	torso.rotation = Vector3.ZERO
	head.position = Vector3(0, 1.66, 0)
	head.rotation = Vector3.ZERO
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_aim_arm(i, to_global(Vector3(0.28 * s, 0.82, -0.05)))


## Follow a tracked head and hands (global transforms) with the feet on the ground.
func pose(head_xf: Transform3D, lh: Transform3D, rh: Transform3D, feet: Vector3) -> void:
	global_position = feet
	var yaw := atan2(-head_xf.basis.z.x, -head_xf.basis.z.z)
	global_rotation = Vector3(0, yaw, 0)
	var head_local := to_local(head_xf.origin)
	var h := clampf(head_local.y, 0.8, 1.9)
	var crouch := h / 1.66
	hips.position = Vector3(0, 0.88 * crouch, 0)
	torso.position = Vector3(head_local.x * 0.5, 1.22 * crouch, head_local.z * 0.5)
	head.global_transform = head_xf
	for leg in legs:
		leg.scale = Vector3(1, crouch, 1)
	_aim_arm(0, lh.origin)
	_aim_arm(1, rh.origin)


func _aim_arm(i: int, target: Vector3) -> void:
	var arm := arms[i]
	var from := arm.global_position
	var d := target - from
	var length := clampf(d.length(), 0.15, 0.75)
	if d.length() > 0.01:
		arm.look_at(from + d, Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.FORWARD)
	var seg := arm.get_node("Segment") as MeshInstance3D
	seg.scale = Vector3(1, length / 0.6, 1)
	seg.position = Vector3(0, 0, -length * 0.5)
	if arm.has_node("Stripe"):
		var st := arm.get_node("Stripe") as MeshInstance3D
		st.scale = Vector3(1, 1, length / 0.6)
		st.position.z = -length * 0.5
	hands[i].position = Vector3(0, 0, -length)


func _process(delta: float) -> void:
	if not idle:
		return
	_t += delta
	stand()
	torso.position.y += sin(_t * 1.6) * 0.008
	head.rotation.y = sin(_t * 0.5) * 0.35
	head.position.y += sin(_t * 1.6) * 0.008


# --- Mesh helpers --------------------------------------------------------------------------------

func _mat(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _camo(c: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
uniform vec4 tint : source_color;
uniform sampler2D blotches;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float n = texture(blotches, lp.xy * 1.7 + lp.zx * 0.9).r;
	float n2 = texture(blotches, lp.zy * 2.3 + vec2(0.3)).r;
	vec3 dark = tint.rgb * 0.35;
	vec3 mid = tint.rgb * 0.7;
	vec3 col = n > 0.55 ? dark : (n2 > 0.5 ? mid : tint.rgb);
	ALBEDO = col;
	ROUGHNESS = 0.8;
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", c)
	var tex := NoiseTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_CELLULAR
	fn.frequency = 0.04
	tex.noise = fn
	m.set_shader_parameter("blotches", tex)
	return m


func _capsule(parent: Node3D, r: float, h: float, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(h, r * 2.0)
	cm.radial_segments = 12
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, r: float, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r: float, h: float, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 14
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi
