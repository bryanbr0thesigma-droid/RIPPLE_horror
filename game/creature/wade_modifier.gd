extends SkeletonModifier3D
## Slow wading steps on top of the creature's standing idle. The model has no upright walk, so the
## feet step along the way it moves (lifting a little, mostly under water), the hips dip with each
## step and sway side to side, and the long arms swing loosely.

var creature: Node3D
var amount := 0.0       # 0 = standing still, 1 = full stride; set every frame
var phase := 0.0        # advanced by the distance walked
var stride := 1.0       # metres per step
var lift := 0.18        # metres
var _legs: Array = []   # [thigh, shin, foot] per side
var _arms: Array = []   # upper arm per side
var _arm_chains: Array = []   # [upper arm, forearm, hand] per side
var _hips := -1
var _upper_back := -1
var _head := -1
## The kill: both hands close on a point in front of it (world), and its head bends down to it.
var hold := 0.0
var hold_point := Vector3.ZERO
var bite := 0.0
## Optional separate targets (world) for the left and right hands; null means the shared hold.
var hand_goals: Array = [null, null]
var debug_hands: Array = [Vector3.ZERO, Vector3.ZERO]   # where the hands ended up (world), for tests


func setup(sk: Skeleton3D) -> void:
	for side in [".L", ".R"]:
		var t := _bone(sk, "thigh" + side)
		var s := _bone(sk, "shin" + side)
		var f := _bone(sk, "foot" + side)
		if t >= 0 and s >= 0 and f >= 0:
			_legs.append([t, s, f])
		var a := _bone(sk, "upper_arm" + side)
		if a >= 0:
			_arms.append(a)
		var fa := _bone(sk, "forearm" + side)
		var h := _bone(sk, "hand" + side)
		if a >= 0 and fa >= 0 and h >= 0:
			_arm_chains.append([a, fa, h])
	_hips = _bone(sk, "spine_01")
	_upper_back = _bone(sk, "spine.003")
	_head = _bone(sk, "head")


func _bone(sk: Skeleton3D, prefix: String) -> int:
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).begins_with(prefix):
			return i
	return -1


func _process_modification() -> void:
	var sk := get_skeleton()
	if not sk or not creature:
		return
	if hold > 0.01 or bite > 0.01:
		_hold(sk)
	if amount < 0.01 or _legs.size() < 2:
		return
	var to_sk: Transform3D = sk.global_transform.affine_inverse() * creature.global_transform
	var rot := to_sk.basis.orthonormalized()
	var u := to_sk.basis.get_scale().x                 # skeleton units per metre
	var fwd := (rot * Vector3.BACK).normalized()       # the creature faces +Z
	var up := (rot * Vector3.UP).normalized()
	var side := (rot * Vector3.RIGHT).normalized()
	# Where the feet stand in the idle, before the hips move them.
	var feet: Array = []
	for leg in _legs:
		feet.append(sk.get_bone_global_pose(leg[2]))
	if _hips >= 0:
		var h := sk.get_bone_global_pose(_hips)
		h.origin += (-up * 0.06 * (0.5 - 0.5 * cos(phase * 2.0)) + side * 0.05 * sin(phase)) * u * amount
		sk.set_bone_global_pose(_hips, h)
	for i in _legs.size():
		var leg: Array = _legs[i]
		var ph := fposmod(phase + PI * i, TAU)
		var off := stride * 0.5 * cos(ph)                # forward on the swing, back while planted
		var lf := sin(ph - PI) * lift if ph > PI else 0.0
		var f: Transform3D = feet[i]
		var target := f.origin + (fwd * off + up * lf) * u * amount
		var knee := sk.get_bone_global_pose(leg[1]).origin
		TwoBoneIK.solve(sk, leg[0], leg[1], leg[2], target, knee + fwd * u, -fwd)
		var nf := sk.get_bone_global_pose(leg[2])
		nf.basis = f.basis
		sk.set_bone_global_pose(leg[2], nf)
	for i in _arms.size():
		var a := sk.get_bone_global_pose(_arms[i])
		var swing := -sin(phase + PI * i) * 0.25 * amount   # opposite to the leg on that side
		a.basis = Basis(side, swing) * a.basis
		sk.set_bone_global_pose(_arms[i], a)


func _hold(sk: Skeleton3D) -> void:
	var inv := sk.global_transform.affine_inverse()
	var to_sk: Transform3D = inv * creature.global_transform
	var rot := to_sk.basis.orthonormalized()
	var u := to_sk.basis.get_scale().x
	var up := (rot * Vector3.UP).normalized()
	var side := (rot * Vector3.RIGHT).normalized()
	var target := inv * hold_point
	# Bend the upper back so the head comes down to the victim.
	if bite > 0.01 and _upper_back >= 0 and _head >= 0:
		var b := sk.get_bone_global_pose(_upper_back)
		var h := sk.get_bone_global_pose(_head).origin
		var want := target + up * 0.25 * u
		var d0 := (h - b.origin).normalized()
		var d1 := (want - b.origin).normalized()
		if d0.dot(d1) < 0.9999:
			var ang := minf(d0.angle_to(d1), deg_to_rad(70.0)) * bite
			b.basis = Basis(d0.cross(d1).normalized(), ang) * b.basis
			sk.set_bone_global_pose(_upper_back, b)
	# Both hands on the victim's sides.
	if hold > 0.01:
		for i in _arm_chains.size():
			var ch: Array = _arm_chains[i]
			var s := 1.0 if i == 0 else -1.0     # .L is the creature's left: +x in its own space
			var grip := target + side * s * 0.22 * u
			if hand_goals[i] != null:
				grip = inv * (hand_goals[i] as Vector3)
			var hand := sk.get_bone_global_pose(ch[2]).origin
			var goal := hand.lerp(grip, hold)
			var sh := sk.get_bone_global_pose(ch[0]).origin
			var pole := sh + side * s * 0.6 * u - up * 0.4 * u
			TwoBoneIK.solve(sk, ch[0], ch[1], ch[2], goal, pole, up)
			debug_hands[i] = sk.global_transform * sk.get_bone_global_pose(ch[2]).origin
