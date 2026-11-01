extends SceneTree
# Prints the creature model's size, bones and animations: godot --headless --path game -s tests/probe_creature.gd

func _init() -> void:
	var m: Node3D = load("res://assets/creature/creature.glb").instantiate()
	root.add_child(m)
	await process_frame
	var aabb := AABB()
	var first := true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = mi.global_transform * mi.get_aabb()
		print("mesh ", mi.name, " aabb ", a)
		aabb = a if first else aabb.merge(a)
		first = false
	print("TOTAL ", aabb)
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	var c = load("res://creature/creature.gd").new()
	c.anim = ap
	c._strip_root_offsets()
	print("ANIMS ", ap.get_animation_list())
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	var names := []
	for i in sk.get_bone_count():
		names.append(sk.get_bone_name(i))
	print("BONES ", names)
	print("SK xform ", sk.global_transform)
	for anim_name in ["metarig|idle standing", "metarig|standing run", "metarig|getup1", "metarig|screech", "metarig|search"]:
		ap.play(anim_name)
		ap.seek(0.3, true)
		ap.advance(0.0)
		await process_frame
		var pts := {}
		for i in sk.get_bone_count():
			var bn := sk.get_bone_name(i)
			for key in ["head_", "hand.L", "hand.R", "foot.L", "foot.R", "spine_01"]:
				if bn.begins_with(key):
					pts[key] = sk.global_transform * sk.get_bone_global_pose(i).origin
		var lo := Vector3(1e9, 1e9, 1e9)
		var hi := -lo
		for i in sk.get_bone_count():
			var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(i).origin
			lo = lo.min(p)
			hi = hi.max(p)
		print("POSE ", anim_name, " bones_min ", lo, " bones_max ", hi)
		for k in pts:
			print("   ", k, " ", pts[k])
	quit()
