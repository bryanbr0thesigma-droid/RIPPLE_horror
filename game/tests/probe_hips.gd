extends SceneTree

func _init() -> void:
	var m: Node3D = load("res://assets/creature/creature.glb").instantiate()
	root.add_child(m)
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	for n in ap.get_animation_list():
		var a := ap.get_animation(n)
		for t in a.track_get_count() if false else a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D and str(a.track_get_path(t).get_concatenated_subnames()).begins_with("spine_01"):
				var k := a.track_get_key_count(t)
				var lo := Vector3(1e9, 1e9, 1e9)
				var hi := -lo
				for i in k:
					var v: Vector3 = a.track_get_key_value(t, i)
					lo = lo.min(v)
					hi = hi.max(v)
				print(n, " len ", snappedf(a.length, 0.01), " hip keys ", k, " min ", lo.snapped(Vector3.ONE * 0.001), " max ", hi.snapped(Vector3.ONE * 0.001))
	quit()
