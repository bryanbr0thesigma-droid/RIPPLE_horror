class_name SuitRig
extends Node3D
## A player in one of the three suits, in their color. Used for the character preview and for
## other players in the game. The suit models are posed from the player's head and hands
## (see suit_ik.gd); the player's color goes on the parts marked by each suit's mask.

const IK := preload("res://player/suit_ik.gd")
const TINT := preload("res://player/suit_tint.gdshader")
const XR_GLOVES := [preload("res://addons/godot-xr-tools/hands/model/Hand_low_L.gltf"),
	preload("res://addons/godot-xr-tools/hands/model/Hand_low_R.gltf")]
const GLOVE_MAT := preload("res://addons/godot-xr-tools/hands/materials/cleaning_glove.tres")

const SUITS := [
	{"name": "Anti-radiation suit", "about": "Baggy rubberized suit, hood and gas mask. Your color tints the camo.",
		"glove": Color(0.1, 0.11, 0.09), "file": "res://assets/suits/ozk.glb",
		"masks": {"kostum": "res://assets/suits/ozk_mask.png"}, "gain": 1.9, "flat": []},
	{"name": "Striker jumpsuit", "about": "Fitted work jumpsuit and helmet. Your color is the stripes.",
		"glove": Color(0.07, 0.07, 0.08), "file": "res://assets/suits/jumpsuit.glb",
		"masks": {"Jumpsuit": "res://assets/suits/jumpsuit_mask.png"}, "gain": 1.7, "flat": [], "hide": ["gloves"], "xr_gloves": true},
	{"name": "Diver", "about": "Neoprene wetsuit, mask and snorkel. Your color is the panels.",
		"glove": Color(0.05, 0.05, 0.06), "file": "res://assets/suits/diver.glb",
		"masks": {}, "gain": 1.0, "flat": ["Buso_Stroke", "Lentes_Respirador"]},
]

# Bone roles -> base names to look for (after stripping "mixamorig_" and numeric suffixes).
const ROLES := {
	"Hips": ["Hips"], "Spine": ["Spine"], "Neck": ["Neck"], "Head": ["Head"],
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
var gloves: Array[Node3D] = []    # the jumpsuit's own gloves are unusable; it wears the XR Tools ones
var _stand_h := 0.0
var _t := 0.0


static func glove_color(index: int) -> Color:
	return SUITS[clampi(index, 0, SUITS.size() - 1)].glove


static func create(index: int, c: Color) -> SuitRig:
	var r := SuitRig.new()
	r.suit = clampi(index, 0, SUITS.size() - 1)
	r.color = c
	r._build()
	return r


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
	model = (load(info.file) as PackedScene).instantiate()
	add_child(model)
	model.rotation.y = PI          # the models face +Z; players face -Z
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_warning("Suit has no skeleton: %s" % info.file)
		return
	skeleton = found[0]
	var names := {}
	for i in skeleton.get_bone_count():
		names[_base_name(skeleton.get_bone_name(i))] = i
	var bones := {}
	for role in ROLES:
		for n in ROLES[role]:
			if names.has(n):
				bones[role] = names[n]
				break
	# Eye height: a little above the head bone.
	if bones.has("Head"):
		var xf := Transform3D()
		var n: Node = skeleton
		while n != model:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var head_world := model.transform * xf * skeleton.get_bone_global_rest(bones.Head).origin
		eye_height = head_world.y + 0.11
	_recolor(info)
	if info.get("xr_gloves", false):
		var gm: BaseMaterial3D = GLOVE_MAT.duplicate()
		gm.albedo_texture = null
		gm.albedo_color = (info.glove as Color).lightened(0.15)
		for i in 2:
			var holder := Node3D.new()
			add_child(holder)
			var g: Node3D = XR_GLOVES[i].instantiate()
			holder.add_child(g)
			g.position = Vector3(-0.01 if i == 0 else 0.01, 0, 0.05)   # as XR Tools places them
			for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
				mi.material_override = gm
			gloves.append(holder)
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
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if not src:
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


# --- Posing --------------------------------------------------------------------------------------

## A neutral standing pose (feet at the origin), arms relaxed, for the preview.
func stand() -> void:
	head_target = Transform3D(Basis(), Vector3(0, eye_height, 0))
	var k := eye_height / 1.6
	var down := Basis(Vector3.RIGHT, -PI * 0.5)   # fingers down, thumbs forward
	hand_targets[0] = Transform3D(down, Vector3(-0.22, 0.84, 0.02) * Vector3(k, k, 1))
	hand_targets[1] = Transform3D(down, Vector3(0.22, 0.84, 0.02) * Vector3(k, k, 1))


## Follow a tracked head and hands (global transforms) with the feet on the ground.
func pose(head_xf: Transform3D, lh: Transform3D, rh: Transform3D, feet: Vector3) -> void:
	var yaw := atan2(head_xf.basis.z.x, head_xf.basis.z.z)   # facing where the head looks (-Z)
	global_transform = Transform3D(Basis(Vector3.UP, yaw), feet)
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
	for i in gloves.size():
		gloves[i].transform = hand_targets[i]
