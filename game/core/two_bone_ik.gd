class_name TwoBoneIK
extends RefCounted
## Two-bone IK that works on any skeleton whatever its bone axes, by turning bones in skeleton
## space. Used by the player suits and the creature's legs.

## Turn bone A (and so its children) and then bone B so that C reaches the target, with the middle
## joint on the pole's side. bend_rest: the way B would fold toward when A..C is straight.
## stretch: when the target is out of reach, the limb may lengthen up to this much (the joints slide
## apart along the bones), so a hand still meets what it's holding.
static func solve(sk: Skeleton3D, ia: int, ib: int, ic: int, target: Vector3, pole: Vector3, bend_rest: Vector3, stretch := 1.0) -> void:
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
	var reach := (la + lb) * 0.999
	if stretch > 1.0 and to_t.length() > reach:
		var k := minf(to_t.length() / reach, stretch)
		B = sk.get_bone_global_pose(ib)
		B.origin = A.origin + (B.origin - A.origin) * k
		sk.set_bone_global_pose(ib, B)
		C = sk.get_bone_global_pose(ic)
		C.origin = B.origin + (C.origin - B.origin) * k
		sk.set_bone_global_pose(ic, C)
