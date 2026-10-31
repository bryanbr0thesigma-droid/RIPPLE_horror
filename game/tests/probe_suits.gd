extends SceneTree
# Prints each suit's skeleton, size and materials: godot --headless --path game -s tests/probe_suits.gd

func _init() -> void:
	for n in ["ozk", "jumpsuit", "diver"]:
		var m: Node3D = load("res://assets/suits/%s.glb" % n).instantiate()
		root.add_child(m)
		await process_frame
		var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
		var ap = m.find_children("*", "AnimationPlayer", true, false)
		var anims: Array = ap[0].get_animation_list() if ap.size() > 0 else []
		print("== ", n, " bones=", sk.get_bone_count(), " anims=", anims, " sk_xform=", sk.global_transform)
		var lo := Vector3(1e9, 1e9, 1e9)
		var hi := -lo
		var keys := {}
		for i in sk.get_bone_count():
			var p := sk.global_transform * sk.get_bone_global_pose(i).origin
			lo = lo.min(p)
			hi = hi.max(p)
			var bn := sk.get_bone_name(i)
			for k in ["Head", "head", "LeftHand", "RightHand", "LeftArm", "LeftForeArm", "arm1.L", "arm2.L", "arm3.L", "arm1.R", "LeftFoot", "Hips"]:
				if bn.contains(k) and not keys.has(k) and not bn.contains("end") and not bn.contains("Top"):
					keys[k] = [bn, p]
		print("   rest bones min ", lo, " max ", hi)
		for k in keys:
			print("   ", k, " -> ", keys[k][0], " at ", keys[k][1])
		var mats := []
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var mat = mi.get_active_material(s)
				mats.append("%s:%s" % [mi.name, mat.resource_name if mat else "-"])
		print("   materials ", mats)
		m.queue_free()
	quit()
