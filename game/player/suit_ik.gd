extends SkeletonModifier3D
## Poses a suit from a head and two hands: the hips drop and lean so the head can get where the
## player's head is, the spine bends toward it, the legs bend to keep the feet planted, the arms
## reach for the hands with the elbows down and out, and the head and hands take the tracked turn.
## Works on any humanoid skeleton whatever its bone axes, by turning bones in skeleton space.

var rig: Node3D          # the SuitRig; targets are read from it in its local space
var bones := {}          # role -> bone index
var _rest := {}          # role -> rest global pose (skeleton space)
var _ready_ok := false
var last_hands := [Vector3.ZERO, Vector3.ZERO]   # where the hands ended up (world), for tests


func setup(sk: Skeleton3D, found: Dictionary) -> void:
	bones = found
	for role in bones:
		_rest[role] = sk.get_bone_global_rest(bones[role])
	_ready_ok = bones.has("Hips") and bones.has("Head") and bones.has("LeftArm") and bones.has("RightArm")


func _process_modification() -> void:
	var sk := get_skeleton()
	if not sk or not _ready_ok or not rig:
		return
	# Rig space -> skeleton space.
	var to_sk: Transform3D = sk.global_transform.affine_inverse() * rig.global_transform
	var rot_sk := to_sk.basis.orthonormalized()          # directions only
	var up := (rot_sk * Vector3.UP).normalized()
	var fwd := (rot_sk * Vector3.FORWARD).normalized()   # the rig faces -Z
	var right := (rot_sk * Vector3.RIGHT).normalized()
	var u := to_sk.basis.get_scale().x                   # skeleton units per metre

	var head_xf: Transform3D = rig.head_target
	# The head bone sits below and behind the eyes.
	var head_goal := to_sk * (head_xf * Vector3(0, -0.11, 0.09))
	var head_rest: Vector3 = _rest.Head.origin

	# 1. Hips: drop for crouching, shift a little toward a leaning head.
	var off := head_goal - head_rest
	var drop := clampf(-off.dot(up), 0.0, 0.85 * u)
	var lean := off - up * off.dot(up)
	var lean_len := lean.length()
	var max_lean := 0.3 * u
	if lean_len > max_lean:
		lean = lean * (max_lean / lean_len)
	var hips: Transform3D = sk.get_bone_global_pose(bones.Hips)
	hips.origin += -up * drop * 0.92 + lean * 0.35
	sk.set_bone_global_pose(bones.Hips, hips)

	# 2. Spine: bend toward the head.
	if bones.has("Spine"):
		var sp: Transform3D = sk.get_bone_global_pose(bones.Spine)
		var hc: Vector3 = sk.get_bone_global_pose(bones.Head).origin
		var a := (hc - sp.origin).normalized()
		var b := (head_goal - sp.origin).normalized()
		if a.dot(b) < 0.9999:
			var ang := minf(a.angle_to(b), deg_to_rad(50.0))
			var axis := a.cross(b).normalized()
			sp.basis = Basis(axis, ang) * sp.basis
			sk.set_bone_global_pose(bones.Spine, sp)

	# 3. Legs: feet stay where they stand, knees go forward.
	for s in ["Left", "Right"]:
		if bones.has(s + "UpLeg") and bones.has(s + "Leg") and bones.has(s + "Foot"):
			var foot_rest: Transform3D = _rest[s + "Foot"]
			var knee: Vector3 = sk.get_bone_global_pose(bones[s + "Leg"]).origin
			_two_bone(sk, bones[s + "UpLeg"], bones[s + "Leg"], bones[s + "Foot"], foot_rest.origin, knee + fwd * u, -fwd)
			var f: Transform3D = sk.get_bone_global_pose(bones[s + "Foot"])
			f.basis = foot_rest.basis
			sk.set_bone_global_pose(bones[s + "Foot"], f)

	# 4. Head turn: the tracked head's rotation relative to the rig, applied to the rest head.
	var hm: Basis = head_xf.basis.orthonormalized()
	var delta: Basis = rot_sk * hm * rot_sk.inverse()
	if bones.has("Neck"):
		var nk: Transform3D = sk.get_bone_global_pose(bones.Neck)
		nk.basis = delta.slerp(Basis(), 0.6) * _rest.Neck.basis
		sk.set_bone_global_pose(bones.Neck, nk)
	var hd: Transform3D = sk.get_bone_global_pose(bones.Head)
	hd.basis = delta * _rest.Head.basis
	sk.set_bone_global_pose(bones.Head, hd)

	# 5. Arms: elbows down, back and out.
	for i in 2:
		var s: String = ["Left", "Right"][i]
		if not (bones.has(s + "Arm") and bones.has(s + "ForeArm") and bones.has(s + "Hand")):
			continue
		var hand_xf: Transform3D = rig.hand_targets[i]
		var goal := to_sk * (hand_xf * Vector3(0, 0, 0.06))   # the wrist is behind the grip
		var sh: Vector3 = sk.get_bone_global_pose(bones[s + "Arm"]).origin
		var side := -right if i == 0 else right
		var pole := sh + (side * 0.25 - up * 0.6 - fwd * 0.3) * u
		_two_bone(sk, bones[s + "Arm"], bones[s + "ForeArm"], bones[s + "Hand"], goal, pole, fwd)
		_aim_hand(sk, s, rot_sk * hand_xf.basis.orthonormalized())
		last_hands[i] = sk.global_transform * sk.get_bone_global_pose(bones[s + "Hand"]).origin


## Turn bone A (and so its children) and then bone B so that C reaches the target, with the middle
## joint on the pole's side. bend_rest: the way B would fold toward when A..C is straight.
func _two_bone(sk: Skeleton3D, ia: int, ib: int, ic: int, target: Vector3, pole: Vector3, bend_rest: Vector3) -> void:
	var A: Transform3D = sk.get_bone_global_pose(ia)
	var B: Transform3D = sk.get_bone_global_pose(ib)
	var C: Transform3D = sk.get_bone_global_pose(ic)
	var la := A.origin.distance_to(B.origin)
	var lb := B.origin.distance_to(C.origin)
	if la < 1e-5 or lb < 1e-5:
		return
	var to_t := target - A.origin
	var d := clampf(to_t.length(), absf(la - lb) + (la + lb) * 0.01, (la + lb) * 0.999)
	var dir := to_t.normalized() if to_t.length() > 1e-6 else (B.origin - A.origin).normalized()
	var pd := pole - A.origin
	var bend := pd - dir * pd.dot(dir)
	if bend.length() < 1e-6:
		bend = bend_rest - dir * bend_rest.dot(dir)
	bend = bend.normalized()
	var cos_a := clampf((la * la + d * d - lb * lb) / (2.0 * la * d), -1.0, 1.0)
	var elbow := A.origin + dir * (la * cos_a) + bend * (la * sqrt(1.0 - cos_a * cos_a))
	# Turn A by matching frames: (upper dir, fold dir) before -> after, so the hinge stays a hinge.
	var u0 := (B.origin - A.origin).normalized()
	var f0 := (C.origin - B.origin)
	f0 = f0 - u0 * f0.dot(u0)
	if f0.length() < 1e-4 * lb:
		f0 = bend_rest - u0 * bend_rest.dot(u0)
	f0 = f0.normalized()
	var u1 := (elbow - A.origin).normalized()
	var f1 := (A.origin + dir * d) - elbow
	f1 = f1 - u1 * f1.dot(u1)
	if f1.length() < 1e-6:
		f1 = -bend - u1 * (-bend).dot(u1)
	f1 = f1.normalized()
	var r := Basis(u1, f1, u1.cross(f1)) * Basis(u0, f0, u0.cross(f0)).inverse()
	A.basis = r.orthonormalized() * A.basis
	sk.set_bone_global_pose(ia, A)
	B = sk.get_bone_global_pose(ib)
	C = sk.get_bone_global_pose(ic)
	var c_dir := (C.origin - B.origin).normalized()
	var t_dir := (A.origin + dir * d - B.origin).normalized()
	if c_dir.dot(t_dir) < 0.99999:
		B.basis = Basis(Quaternion(c_dir, t_dir)) * B.basis
		sk.set_bone_global_pose(ib, B)


## Point the hand's fingers along the controller and its palm toward the controller's middle.
func _aim_hand(sk: Skeleton3D, s: String, ctrl: Basis) -> void:
	var ih: int = bones[s + "Hand"]
	if not (bones.has(s + "Finger") and bones.has(s + "Side")):
		return
	var rest_h: Transform3D = _rest[s + "Hand"]
	var f0: Vector3 = (_rest[s + "Finger"].origin - rest_h.origin).normalized()
	var side0: Vector3 = (_rest[s + "Side"].origin - rest_h.origin)
	side0 = (side0 - f0 * side0.dot(f0)).normalized()
	var f1 := (ctrl * Vector3.FORWARD).normalized()
	var side1 := ctrl * Vector3.UP   # the index-finger side is on top of a gripped controller
	side1 = (side1 - f1 * side1.dot(f1)).normalized()
	var r := Basis(f1, side1, f1.cross(side1)) * Basis(f0, side0, f0.cross(side0)).inverse()
	var h: Transform3D = sk.get_bone_global_pose(ih)
	h.basis = r.orthonormalized() * rest_h.basis
	sk.set_bone_global_pose(ih, h)
