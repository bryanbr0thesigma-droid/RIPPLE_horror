class_name SuitRig
extends Node3D
## A player in one of the three suits, in their color. Used for the character preview and for
## other players in the game. The suit models are posed from the player's head and hands
## (see suit_ik.gd); the player's color goes on the parts marked by each suit's mask.

const IK := preload("res://player/suit_ik.gd")
const EYE_FORWARD := 0.09        # the eyes are this far in front of the head bone
const TINT := preload("res://player/suit_tint.gdshader")

const SUITS := [
	{"name": "Anti-radiation suit", "about": "Baggy rubberized suit, hood and gas mask. Your color tints the camo.",
		"glove": Color(0.1, 0.11, 0.09), "file": "res://assets/suits/ozk.glb",
		"masks": {"kostum": "res://assets/suits/ozk_mask.png"}, "gain": 1.9, "flat": []},
	{"name": "Striker jumpsuit", "about": "Fitted work jumpsuit and helmet. Your color is the stripes.",
		"glove": Color(0.07, 0.07, 0.08), "file": "res://assets/suits/jumpsuit.glb",
		"masks": {"Jumpsuit": "res://assets/suits/jumpsuit_mask.png"}, "gain": 1.7, "flat": [], "hide": ["gloves"]},
	{"name": "Diver", "about": "Neoprene wetsuit, mask and snorkel. Your color is the panels.",
		"glove": Color(0.05, 0.05, 0.06), "file": "res://assets/suits/diver.glb",
		"masks": {}, "gain": 1.0, "flat": ["Buso_Stroke", "Lentes_Respirador"]},
]

# Bone roles -> base names to look for (after stripping "mixamorig_" and numeric suffixes).
const ROLES := {
	"Hips": ["Hips"], "Spine": ["Spine"], "Spine1": ["Spine1"], "Spine2": ["Spine2"], "Neck": ["Neck"], "Head": ["Head"],
	"LeftArm": ["LeftArm"], "LeftForeArm": ["LeftForeArm"], "LeftHand": ["LeftHand"],
	"RightArm": ["RightArm"], "RightForeArm": ["RightForeArm"], "RightHand": ["RightHand"],
	"LeftUpLeg": ["LeftUpLeg"], "LeftLeg": ["LeftLeg"], "LeftFoot": ["LeftFoot"],
	"RightUpLeg": ["RightUpLeg"], "RightLeg": ["RightLeg"], "RightFoot": ["RightFoot"],
	"LeftFinger": ["LeftHandMiddle1", "middle1.L"], "LeftSide": ["LeftHandIndex1", "pointer1.L"],
	"RightFinger": ["RightHandMiddle1", "middle1.R"], "RightSide": ["RightHandIndex1", "pointer1.R"],
}

var suit := 0
var color := Color.ORANGE
var idle := false
var model: Node3D
var skeleton: Skeleton3D
## Where the head (eyes) and hands should be, in this node's space. Read by the IK every frame.
var head_target := Transform3D()
var hand_targets: Array[Transform3D] = [Transform3D(), Transform3D()]
var eye_height := 1.6
## The suit split for the kills: "head" (head and neck), "upper" (chest and arms), "lower" (hips
## and legs). Each holds that part's meshes.
var parts := {"head": [], "upper": [], "lower": []}
var variant := ""
var bones := {}
var _sk_xf := Transform3D()       # skeleton space -> this node's space
var _stand_h := 0.0
var _t := 0.0


static func glove_color(index: int) -> Color:
	return SUITS[clampi(index, 0, SUITS.size() - 1)].glove


## variant "lr": the suit cut down the middle into "left" and "right" halves (for the vertical
## tear; built by tools/suits/split_lr.py), instead of "head", "upper" and "lower".
static func create(index: int, c: Color, variant := "") -> SuitRig:
	var r := SuitRig.new()
	r.suit = clampi(index, 0, SUITS.size() - 1)
	r.color = c
	r.variant = variant
	r._build()
	return r


## The full suit's materials by name. The halves files carry no textures of their own.
static var _materials := {}

static func _suit_materials(index: int) -> Dictionary:
	if _materials.has(index):
		return _materials[index]
	var out := {}
	var full: Node = (load(SUITS[index].file) as PackedScene).instantiate()
	for mi: MeshInstance3D in full.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m and not out.has(m.resource_name):
				out[m.resource_name] = m
	full.free()
	_materials[index] = out
	return out


static func _base_name(n: String) -> String:
	for p in ["mixamorig_", "mixamorig:", "mixamorig"]:
		if n.begins_with(p):
			n = n.substr(p.length())
			break
	var i := n.rfind("_")
	if i > 0 and n.substr(i + 1).is_valid_int():
		n = n.substr(0, i)
	return n


func _build() -> void:
	var info: Dictionary = SUITS[suit]
	var file: String = info.file
	if variant == "lr":
		file = file.replace(".glb", "_lr.glb")
		parts = {"left": [], "right": []}
	model = (load(file) as PackedScene).instantiate()
	add_child(model)
	if variant == "lr":
		var mats := _suit_materials(suit)
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh.has_meta("borrowed"):
				continue
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i)
				if m and mats.has(m.resource_name):
					mi.mesh.surface_set_material(i, mats[m.resource_name])
			mi.mesh.set_meta("borrowed", true)
	model.rotation.y = PI          # the models face +Z; players face -Z
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_warning("Suit has no skeleton: %s" % info.file)
		return
	skeleton = found[0]
	var names := {}
	for i in skeleton.get_bone_count():
		names[_base_name(skeleton.get_bone_name(i))] = i
	bones = {}
	for role in ROLES:
		for n in ROLES[role]:
			if names.has(n):
				bones[role] = names[n]
				break
	# Eye height: a little above the head bone.
	var xf := Transform3D()
	var n: Node = skeleton
	while n != model:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	_sk_xf = model.transform * xf
	if bones.has("Head"):
		eye_height = (_sk_xf * skeleton.get_bone_global_rest(bones.Head).origin).y + 0.11
	_recolor(info)
	var ik := IK.new()
	ik.name = "SuitIK"
	skeleton.add_child(ik)
	ik.rig = self
	ik.setup(skeleton, bones)
	stand()


func _recolor(info: Dictionary) -> void:
	var masks: Dictionary = info.masks
	var flat: Array = info.flat
	var hide: Array = info.get("hide", [])
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # cheap on Quest
		var first := mi.mesh.surface_get_material(0)
		if first and first.resource_name in hide:
			mi.visible = false
			continue
		for part in parts:
			if String(mi.name).ends_with("__" + part):
				parts[part].append(mi)
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if not src:
				continue
			if src.resource_name == "Flesh_cut":            # where a half was cut off
				mi.set_surface_override_material(s, Gore.flesh_material())
				continue
			if masks.has(src.resource_name):
				mi.set_surface_override_material(s, _tinted(src, load(masks[src.resource_name]), info.gain))
			elif src.resource_name in flat:
				var m := src.duplicate() as BaseMaterial3D
				m.albedo_color = color
				mi.set_surface_override_material(s, m)


func _tinted(src: BaseMaterial3D, mask: Texture2D, gain: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TINT
	m.set_shader_parameter("albedo_tex", src.albedo_texture)
	m.set_shader_parameter("base_color", src.albedo_color)
	if src.normal_enabled and src.normal_texture:
		m.set_shader_parameter("normal_tex", src.normal_texture)
		m.set_shader_parameter("has_normal", true)
	m.set_shader_parameter("mask_tex", mask)
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("gain", gain)
	m.set_shader_parameter("roughness", src.roughness)
	m.set_shader_parameter("metallic", src.metallic)
	return m


## Plain grey all over: the test dummy.
func make_featureless() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.6, 0.58)
	m.roughness = 0.85
	for part in parts:   # the suit itself only, not the raw flesh where it was torn
		for mi: MeshInstance3D in parts[part]:
			for s in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(s)
				if not (src and src.resource_name == "Flesh_cut"):
					mi.set_surface_override_material(s, m)


# --- Tearing apart -------------------------------------------------------------------------------

## Show only some parts ("head", "upper", "lower"), with raw flesh where they were torn off.
func show_only(keep: Array) -> void:
	for part in parts:
		for mi: MeshInstance3D in parts[part]:
			mi.visible = part in keep
	var neck_cut := ("head" in keep) != ("upper" in keep)
	var waist_cut := ("upper" in keep) != ("lower" in keep)
	if neck_cut and bones.has("Neck") and bones.has("Head"):
		_add_cap("Neck", "Head", 0.065, not ("head" in keep))
	if waist_cut and bones.has("Spine1"):
		_add_cap("Spine1", "Spine2" if bones.has("Spine2") else "Neck", 0.15, "lower" in keep)


## A flesh cap at bone `at`, facing toward bone `toward` (or away from it when flip).
func _add_cap(at: String, toward: String, radius: float, flip: bool) -> void:
	var rest_a := skeleton.get_bone_global_rest(bones[at])
	var rest_b := skeleton.get_bone_global_rest(bones[toward])
	var n_sk := (rest_b.origin - rest_a.origin).normalized() * (-1.0 if flip else 1.0)
	var local_n := (rest_a.basis.inverse() * n_sk).normalized()
	var att := BoneAttachment3D.new()
	att.bone_name = skeleton.get_bone_name(bones[at])
	skeleton.add_child(att)
	var c := Gore.cap(radius)
	att.add_child(c)
	var sc := _sk_xf.basis.get_scale().x * rest_a.basis.get_scale().x
	c.transform = Transform3D(Basis(Quaternion(Vector3.UP, local_n)).scaled(Vector3.ONE / maxf(sc, 1e-4)), Vector3.ZERO)


## Where a bone sits in this node's space at rest (for holding a torn-off piece by it).
func bone_rest(role: String) -> Vector3:
	if not bones.has(role):
		return Vector3(0, eye_height, 0)
	return _sk_xf * skeleton.get_bone_global_rest(bones[role]).origin


## The far ends of whatever part of the suit is showing (world space), for keeping torn pieces out
## of walls and floors.
func extent_points() -> Array[Vector3]:
	var roles: Array[String] = []
	var shown := func(part: String) -> bool:
		return parts.has(part) and parts[part].any(func(mi): return (mi as MeshInstance3D).visible)
	if shown.call("head"):
		roles.append("Head")
	if shown.call("upper"):
		roles.append_array(["Spine2", "LeftHand", "RightHand"])
	if shown.call("lower"):
		roles.append_array(["Hips", "LeftFoot", "RightFoot"])
	if shown.call("left"):
		roles.append_array(["Head", "Hips", "LeftHand", "LeftFoot"])
	if shown.call("right"):
		roles.append_array(["Head", "Hips", "RightHand", "RightFoot"])
	var out: Array[Vector3] = []
	for r in roles:
		if bones.has(r):
			out.append(bone_world(r))
	return out


## Where a bone is right now, in world space (after the IK).
func bone_world(role: String) -> Vector3:
	if not bones.has(role):
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(bones[role]).origin


# --- Posing --------------------------------------------------------------------------------------

## A neutral standing pose (feet at the origin), arms relaxed, for the preview.
func stand() -> void:
	head_target = Transform3D(Basis(), Vector3(0, eye_height, -EYE_FORWARD))
	var k := eye_height / 1.6
	var down := Basis(Vector3.RIGHT, -PI * 0.5)   # fingers down, thumbs forward
	hand_targets[0] = Transform3D(down, Vector3(-0.22, 0.84, 0.02) * Vector3(k, k, 1))
	hand_targets[1] = Transform3D(down, Vector3(0.22, 0.84, 0.02) * Vector3(k, k, 1))


## Follow a tracked head and hands (global transforms) with the feet on the ground.
func pose(head_xf: Transform3D, lh: Transform3D, rh: Transform3D, feet: Vector3) -> void:
	var yaw := atan2(head_xf.basis.z.x, head_xf.basis.z.z)   # facing where the head looks (-Z)
	# The body stands under the middle of the head, which is a little behind the eyes.
	var b := Basis(Vector3.UP, yaw)
	global_transform = Transform3D(b, feet + b * Vector3(0, 0, EYE_FORWARD))
	var inv := global_transform.affine_inverse()
	head_target = inv * head_xf
	hand_targets[0] = inv * lh
	hand_targets[1] = inv * rh
	# Scale the suit to the player: their standing eye height, learned slowly so jumps don't count.
	var h := head_target.origin.y
	if _stand_h == 0.0:
		_stand_h = maxf(h, 1.3)
	elif h > _stand_h:
		_stand_h += (h - _stand_h) * 0.02
	model.scale = Vector3.ONE * clampf(_stand_h / eye_height, 0.85, 1.2)


func _process(delta: float) -> void:
	if idle:
		_t += delta
		stand()
		head_target.basis = Basis(Vector3.UP, sin(_t * 0.5) * 0.35) * Basis(Vector3.RIGHT, sin(_t * 0.31) * 0.08)
		head_target.origin.y += sin(_t * 1.6) * 0.006
