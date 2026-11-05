class_name SuitRig
extends Node3D
## A player in one of the three suits, in their color. Used for the character preview and for
## other players in the game. The suit models are posed from the player's head and hands
## (see suit_ik.gd); the player's color goes on the parts marked by each suit's mask.

const IK := preload("res://player/suit_ik.gd")
const EYE_FORWARD := 0.09        # the eyes are this far in front of the head bone
const TINT := preload("res://player/suit_tint.gdshader")
const TINT_CUTOUT := preload("res://player/suit_tint_cutout.gdshader")

const SUITS := [
	{"name": "Anti-radiation suit", "about": "Baggy rubberized suit, hood and gas mask. Your color tints the camo.",
		"glove": Color(0.1, 0.11, 0.09), "file": "res://assets/suits/ozk.glb",
		"masks": {"kostum": "res://assets/suits/ozk_mask.png"}, "gain": 1.9, "flat": [],
		"fp_hide": ["balon_low", "filtr_low"]},   # the gas mask's canister on the chest fills your own view
	{"name": "Diver", "about": "Neoprene wetsuit, mask and snorkel. Your color is the panels.",
		"glove": Color(0.05, 0.05, 0.06), "file": "res://assets/suits/diver.glb",
		"masks": {}, "gain": 1.0, "flat": ["Buso_Stroke", "Lentes_Respirador"]},
	{"name": "Scuba diver", "about": "Black wetsuit, mask and air tank. Your color is the tank and gear.",
		"glove": Color(0.04, 0.04, 0.05), "file": "res://assets/suits/scuba.glb",
		"masks": {}, "gain": 1.0, "flat": ["Diver_Objects"]},
	{"name": "Brass-helmet diver", "about": "An old canvas diving suit, brass helmet and lead boots. Your color is the straps.",
		"glove": Color(0.12, 0.1, 0.08), "file": "res://assets/suits/brass.glb",
		"masks": {}, "gain": 1.0, "flat": ["straps_mat"]},
	# Secret: hidden until its code is typed in on the character page.
	{"name": "Latex diver", "about": "A goth in a glossy black latex wetsuit, with a tank and a mask pushed up on her head. Your color is the suit's trim, the tank and gear.",
		"glove": Color(0.02, 0.02, 0.025), "file": "res://assets/suits/latex.glb",
		"masks": {"N00_010_01_Onepiece_00_CLOTH_Instance": "res://assets/suits/latex_trim_mask.png"}, "gain": 1.7,
		"flat": ["Diver_Objects"], "code": "34",
		# Sprung soft-body bones: they bounce and sway with the wearer's movement.
		"jiggle": [
			{"root": "J_Sec_L_Bust1", "end": "J_Sec_L_Bust2", "dir": SkeletonModifier3D.BONE_DIRECTION_FROM_PARENT, "stiffness": 0.55, "drag": 0.22, "gravity": 0.05},
			{"root": "J_Sec_R_Bust1", "end": "J_Sec_R_Bust2", "dir": SkeletonModifier3D.BONE_DIRECTION_FROM_PARENT, "stiffness": 0.55, "drag": 0.22, "gravity": 0.05},
			{"root": "J_Sec_L_Glute1", "end": "J_Sec_L_Glute1", "dir": SkeletonModifier3D.BONE_DIRECTION_PLUS_Y, "stiffness": 0.8, "drag": 0.28, "gravity": 0.03},
			{"root": "J_Sec_R_Glute1", "end": "J_Sec_R_Glute1", "dir": SkeletonModifier3D.BONE_DIRECTION_PLUS_Y, "stiffness": 0.8, "drag": 0.28, "gravity": 0.03},
			{"root": "J_Sec_L_Thigh1", "end": "J_Sec_L_Thigh1", "dir": SkeletonModifier3D.BONE_DIRECTION_PLUS_Y, "stiffness": 0.9, "drag": 0.3, "gravity": 0.0},
			{"root": "J_Sec_R_Thigh1", "end": "J_Sec_R_Thigh1", "dir": SkeletonModifier3D.BONE_DIRECTION_PLUS_Y, "stiffness": 0.9, "drag": 0.3, "gravity": 0.0},
		]},
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
var jiggle: SpringBoneSimulator3D       # the soft-body springs, on suits that have them
var idle := false
var model: Node3D
var skeleton: Skeleton3D
## Where the head (eyes) and hands should be, in this node's space. Read by the IK every frame.
var head_target := Transform3D()
var hand_targets: Array[Transform3D] = [Transform3D(), Transform3D()]
var eye_height := 1.6
## Your own body in first person: the head shrinks to nothing (the camera is in it), and in VR the
## hands too (your gloves are there instead).
var first_person := false
var hide_hands := false
## Walking: how far each foot is off its planted spot (this node's space), from the step cycle.
var foot_offsets: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## Both feet moved this far (this node's space) on top of that: forward, to sit in a chair.
var foot_extra := Vector3.ZERO
var _gait_phase := 0.0
var _gait_amp := 0.0
var _gait_dir := Vector3.FORWARD
var _last_feet := Vector3.INF
var _last_pose_us := 0
var _body_yaw := INF
## Everyone's hands push the soft-body bones (bust, rear, thighs): key -> palm points (world).
static var touch_points := {}
const TOUCH_RADIUS := 0.045
var _touch_spheres: Array[SpringBoneCollisionSphere3D] = []
## The suit split for the kills: "head" (head and neck), "upper" (chest and arms), "lower" (hips
## and legs). Each holds that part's meshes.
var parts := {"head": [], "upper": [], "lower": []}
var variant := ""
var backpack_mesh: MeshInstance3D = null
var _ghost_saved := {}            # mesh -> its surface materials, while it's a ghost
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
	_add_jiggle(info)
	stand()


## Soft-body bones (bust, rear, thighs) on springs, after the IK so they react to how the body moves.
## Only on a whole suit (not the torn halves).
func _add_jiggle(info: Dictionary) -> void:
	var chains: Array = info.get("jiggle", [])
	if chains.is_empty() or variant != "":
		return
	var found := []
	for c: Dictionary in chains:
		var root := _bone_starting(c.root)
		var end := _bone_starting(c.end)
		if root >= 0 and end >= 0:
			found.append([root, end, c])
	if found.is_empty():
		return
	var sim := SpringBoneSimulator3D.new()
	sim.name = "Jiggle"
	sim.setting_count = found.size()
	for i in found.size():
		var c: Dictionary = found[i][2]
		sim.set_root_bone(i, found[i][0])
		sim.set_end_bone(i, found[i][1])
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_direction(i, c.dir)
		sim.set_end_bone_length(i, 0.07)
		sim.set_stiffness(i, c.stiffness)
		sim.set_drag(i, c.drag)
		sim.set_gravity(i, c.gravity)
	skeleton.add_child(sim)
	jiggle = sim
	add_to_group("jiggly")


## Your own body: no head piece (hood, mask, hair: the camera is inside it), and optionally no hands.
func set_first_person(no_hands: bool) -> void:
	first_person = true
	hide_hands = no_hands
	for mi: MeshInstance3D in parts.get("head", []):
		mi.visible = false
	for part in parts:                     # gear right under your eyes, hidden from your own view only
		for mi: MeshInstance3D in parts[part]:
			for n: String in SUITS[suit].get("fp_hide", []):
				if mi.name.begins_with(n):
					mi.visible = false
	# The raw cuts where the suit splits for the kills (the neck) would show without the head.
	var clear := StandardMaterial3D.new()
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.albedo_color = Color(0, 0, 0, 0)
	clear.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for part in parts:
		for mi: MeshInstance3D in parts[part]:
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i)
				if m and m.resource_name == "Flesh_cut":
					mi.set_surface_override_material(i, clear)


## A hand target for a glove: the suit's wrist goes where the glove's wrist is (its cuff then covers
## the sleeve's end), so the arm and the glove meet. `hand` is the glove's controller transform.
static func glove_hand(glove: Node, hand: Transform3D) -> Transform3D:
	var sk := glove.find_child("Skeleton3D", true, false) as Skeleton3D if glove else null
	if not sk:
		return hand
	var i := sk.find_bone("Wrist_R")
	if i < 0:
		i = sk.find_bone("Wrist_L")
	if i < 0:
		return hand
	var wrist := sk.global_transform * sk.get_bone_global_pose(i).origin
	return Transform3D(hand.basis, wrist - hand.basis.orthonormalized() * Vector3(0, 0, 0.06))


## Hands touching the soft-body bones, for every suit that has them.
static func set_touch(key, points: Array) -> void:
	touch_points[key] = points


static func clear_touch(key) -> void:
	touch_points.erase(key)


## Is this point (world) on one of the soft-body bones? For a buzz in the controller.
func touches_jiggle(p: Vector3) -> bool:
	if not jiggle or not visible:
		return false
	for i in jiggle.setting_count:
		for b in [jiggle.get_root_bone(i), jiggle.get_end_bone(i)]:
			var w := skeleton.global_transform * skeleton.get_bone_global_pose(b).origin
			if w.distance_to(p) < TOUCH_RADIUS + 0.06:
				return true
	return false


## A push sphere on the springs for every hand in the game (spares parked far away).
func _sync_touch() -> void:
	var n := 0
	for key in touch_points:
		for p: Vector3 in touch_points[key]:
			if n >= _touch_spheres.size():
				var s := SpringBoneCollisionSphere3D.new()
				s.radius = TOUCH_RADIUS
				jiggle.add_child(s)
				_touch_spheres.append(s)
			_touch_spheres[n].global_position = p
			n += 1
	for i in range(n, _touch_spheres.size()):
		_touch_spheres[i].global_position = Vector3(0, -1000, 0)


func _bone_starting(prefix: String) -> int:
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i).begins_with(prefix):
			return i
	return -1


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
	# Cut-out outfits (see-through windows) keep their cut-out; otherwise the empty pixels show.
	if src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		m.shader = TINT_CUTOUT
		m.set_shader_parameter("alpha_cut", src.alpha_scissor_threshold)
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


## A ghost: the suit faint, pale and see-through (or back to normal).
static var _ghost_mat: StandardMaterial3D

func set_ghost(on: bool) -> void:
	if not _ghost_mat:
		_ghost_mat = StandardMaterial3D.new()
		_ghost_mat.albedo_color = Color(0.7, 0.85, 1.0, 0.18)
		_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost_mat.cull_mode = BaseMaterial3D.CULL_BACK
	for part in parts:
		for mi: MeshInstance3D in parts[part]:
			if on and not _ghost_saved.has(mi):
				var saved := []
				for i in mi.mesh.get_surface_count():
					saved.append(mi.get_surface_override_material(i))
					mi.set_surface_override_material(i, _ghost_mat)
				_ghost_saved[mi] = saved
			elif not on and _ghost_saved.has(mi):
				var saved: Array = _ghost_saved[mi]
				for i in saved.size():
					mi.set_surface_override_material(i, saved[i])
	if not on:
		_ghost_saved.clear()
	if backpack_mesh:
		backpack_mesh.visible = not on


## The backpack everyone carries (see level.gd): a canvas pack on the upper back, further out on the
## suits with an air tank so it sits over the tank.
func add_backpack() -> void:
	if not bones.has("Spine2"):
		return
	var rest := skeleton.get_bone_global_rest(bones["Spine2"])
	var att := BoneAttachment3D.new()
	att.bone_name = skeleton.get_bone_name(bones["Spine2"])
	skeleton.add_child(att)
	var pack := MeshInstance3D.new()
	backpack_mesh = pack
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.38, 0.14)
	pack.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.22, 0.17)
	mat.roughness = 0.9
	pack.material_override = mat
	pack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	att.add_child(pack)
	# Upright and behind the back in this node's space (players face -Z), whatever the bone's axes.
	var back := 0.3                                     # all the suits carry a tank or a filter pack
	var want := Transform3D(Basis(), bone_rest("Spine2") + Vector3(0, -0.05, back))
	var bone_xf := _sk_xf * rest                        # the bone in this node's space, at rest
	pack.transform = bone_xf.affine_inverse() * want


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
	var now := Time.get_ticks_usec()
	var dt := clampf((now - _last_pose_us) / 1000000.0, 0.0, 0.1) if _last_pose_us > 0 else 0.0
	_last_pose_us = now
	var yaw := atan2(head_xf.basis.z.x, head_xf.basis.z.z)   # facing where the head looks (-Z)
	if first_person:
		# Your body doesn't spin with every glance: the head turns up to 35 degrees on its own,
		# then the body follows (and slowly settles behind the head).
		if _body_yaw == INF:
			_body_yaw = yaw
		var d := wrapf(yaw - _body_yaw, -PI, PI)
		var limit := deg_to_rad(35.0)
		if absf(d) > limit:
			_body_yaw += d - signf(d) * limit
		_body_yaw = lerp_angle(_body_yaw, yaw, clampf(dt * 0.8, 0.0, 1.0))
		yaw = _body_yaw
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
	_step(feet, dt)


## The step cycle: while the body moves, the feet take turns stepping along the way it goes.
func _step(feet: Vector3, dt: float) -> void:
	if _last_feet == Vector3.INF or dt <= 0.0 or feet.distance_to(_last_feet) > 1.0:
		_last_feet = feet
		return
	var v := (feet - _last_feet) / dt
	_last_feet = feet
	v.y = 0.0
	var speed := v.length()
	var k := model.scale.x
	var stride := 0.6 * k
	_gait_amp = move_toward(_gait_amp, clampf(speed / 1.1, 0.0, 1.0), dt * 3.0)
	if speed > 0.05:
		_gait_phase = fmod(_gait_phase + speed * dt / stride * PI, TAU)
		_gait_dir = (global_transform.basis.inverse() * v).normalized()
	for i in 2:
		var ph := _gait_phase + PI * i
		foot_offsets[i] = (_gait_dir * sin(ph) * stride * 0.5 + Vector3.UP * maxf(0.0, cos(ph)) * 0.09 * k) * _gait_amp


func _process(delta: float) -> void:
	if jiggle:
		_sync_touch()
	if idle:
		_t += delta
		stand()
		head_target.basis = Basis(Vector3.UP, sin(_t * 0.5) * 0.35) * Basis(Vector3.RIGHT, sin(_t * 0.31) * 0.08)
		head_target.origin.y += sin(_t * 1.6) * 0.006
