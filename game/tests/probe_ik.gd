extends SceneTree
# Checks the IK puts every suit's wrists close to where they should be, in a few poses.

func _init() -> void:
	await process_frame
	var worst := 0.0
	for i in 3:
		var r := SuitRig.create(i, Color.ORANGE)
		root.add_child(r)
		var base := Transform3D(Basis(Vector3.UP, 0.7), Vector3(1, 0, 2))
		var cases := {
			"reach": [Transform3D(Basis(), Vector3(0, 1.62, 0)), Transform3D(Basis(), Vector3(-0.2, 1.3, -0.5)), Transform3D(Basis(), Vector3(0.25, 1.05, -0.45))],
			"crouch": [Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 1.05, -0.15)), Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(-0.25, 0.35, -0.45)), Transform3D(Basis(), Vector3(0.3, 0.85, -0.25))],
			"wave": [Transform3D(Basis(Vector3.UP, 0.6), Vector3(0, 1.62, 0)), Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(-0.24, 0.84, 0.02)), Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0.35, 1.85, -0.1))],
		}
		for c in cases:
			var t: Array = cases[c]
			for k in 4:
				r.pose(base * t[0], base * t[1], base * t[2], base.origin)
				await process_frame
			var ik = r.skeleton.get_node("SuitIK")
			for h in 2:
				var want: Vector3 = base * (t[h + 1] as Transform3D) * Vector3(0, 0, 0.06)
				var err: float = (ik.last_hands[h] as Vector3).distance_to(want)
				worst = maxf(worst, err)
				print("suit ", i, " ", c, " hand ", h, " error ", snappedf(err, 0.001), " got ", (ik.last_hands[h] as Vector3).snapped(Vector3.ONE * 0.01), " want ", want.snapped(Vector3.ONE * 0.01))
		r.queue_free()
	print("IK worst error ", snappedf(worst, 0.001))
	for i in 3:
		var r := SuitRig.create(i, Color.ORANGE)
		root.add_child(r)
		r.stand()
		for k in 4:
			await process_frame
		var ik = r.skeleton.get_node("SuitIK")
		var sk := r.skeleton
		var n: int = ik.bones.Neck
		var h: int = ik.bones.Head
		var s2: int = ik.bones.Spine2
		print("suit ", i, " stand head shift ", (ik.last_head_shift as Vector3).snapped(Vector3.ONE * 0.001), " neck rest->head rest ", (sk.global_transform.basis * (sk.get_bone_global_rest(h).origin - sk.get_bone_global_rest(n).origin)).snapped(Vector3.ONE * 0.001), " spine2->neck ", (sk.global_transform.basis * (sk.get_bone_global_rest(n).origin - sk.get_bone_global_rest(s2).origin)).snapped(Vector3.ONE * 0.001))
		r.queue_free()
	quit()
