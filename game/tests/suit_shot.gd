extends Node3D
# Renders the three suits side by side (rest pose, then first animation frame), with a 1.8 m pole.
#   xvfb-run godot --path game --rendering-driver opengl3 res://tests/suit_shot.tscn -- --out=DIR

## Small red balls at the main joints, drawn on top, to check the skeleton sits inside the mesh.
func _markers(m: Node3D) -> void:
	await get_tree().process_frame
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		var keep := false
		for k in ["Hips", "Spine", "Neck", "Head", "Arm", "Hand", "Leg", "Foot", "Shoulder"]:
			if n.contains(k) and not n.contains("Thumb") and not n.contains("Index") and not n.contains("Middle") and not n.contains("Ring") and not n.contains("Pinky") and not n.contains("end") and not n.contains("End") and not n.contains("Top"):
				keep = true
		if not keep:
			continue
		var b := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.018
		sm.height = 0.036
		b.mesh = sm
		b.material_override = mat
		add_child(b)
		b.global_position = sk.global_transform * sk.get_bone_global_pose(i).origin


func _ready() -> void:
	var out := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.32, 0.35)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.1, 4.2)
	cam.fov = 60
	add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))
	var pole := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 1.8, 0.1)
	pole.mesh = bm
	pole.position = Vector3(-2.2, 0.9, 0)
	add_child(pole)
	var models := []
	var x := -1.2
	for n in ["ozk", "jumpsuit", "diver"]:
		var m: Node3D = load("res://assets/suits/%s.glb" % n).instantiate()
		add_child(m)
		m.position = Vector3(x, 0, 0)
		x += 1.2
		models.append(m)
		pass
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/suits_rest.png")
	for m in models:
		var ap = m.find_children("*", "AnimationPlayer", true, false)
		if ap.size() > 0 and ap[0].get_animation_list().size() > 0:
			ap[0].play(ap[0].get_animation_list()[0])
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/suits_anim.png")
	print("SUITSHOT done")
	get_tree().quit()
