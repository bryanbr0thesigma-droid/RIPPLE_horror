extends Node3D
# Renders the three suits driven by the IK in a few poses (stand, reach, crouch, wave), front and
# side views.   xvfb-run godot --path game --rendering-driver opengl3 res://tests/suit_pose_shot.tscn -- --out=DIR

const COLORS := [Color(0.9, 0.45, 0.15), Color(0.2, 0.6, 0.95), Color(0.85, 0.15, 0.2), Color(0.3, 0.8, 0.3)]


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
	cam.fov = 60
	add_child(cam)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	floor_mi.mesh = pm
	add_child(floor_mi)
	var rigs: Array[SuitRig] = []
	for i in SuitRig.SUITS.size():
		var r := SuitRig.create(i, COLORS[i % COLORS.size()])
		add_child(r)
		rigs.append(r)
	for p in ["stand", "reach", "crouch", "wave"]:
		for view in ["front", "side", "close"]:
			if view == "front":
				cam.position = Vector3(0, 1.0, 6.2)
			elif view == "side":
				cam.position = Vector3(4.6, 1.1, 0.6)
			else:
				cam.position = Vector3(0.3, 1.2, 1.5)
			cam.look_at(Vector3(0, 1.0 if view == "close" else 0.9, 0))
			for k in 4:
				for i in rigs.size():
					var gap := 5.6 / maxf(rigs.size() - 1, 1)
					_pose(rigs[i], p, Transform3D(Basis(Vector3.UP, PI), Vector3(-2.8 + gap * i, 0, 0)))
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/pose_%s_%s.png" % [out, p, view])
	print("POSESHOT done")
	get_tree().quit()


func _pose(r: SuitRig, p: String, base: Transform3D) -> void:
	var fwd_hand := Basis()                                   # controller pointing forward
	var up_hand := Basis(Vector3.RIGHT, PI * 0.5)             # pointing up
	var down := Basis(Vector3.RIGHT, -PI * 0.5)
	match p:
		"stand":
			r.global_transform = base
			r.stand()
			r.head_target.basis = Basis(Vector3.UP, 0.4)
		"reach":
			r.pose(base * Transform3D(Basis(), Vector3(0, 1.62, 0)),
				base * Transform3D(fwd_hand, Vector3(-0.2, 1.3, -0.5)),
				base * Transform3D(fwd_hand, Vector3(0.25, 1.05, -0.45)), base.origin)
		"crouch":
			r.pose(base * Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 1.05, -0.15)),
				base * Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(-0.25, 0.35, -0.45)),
				base * Transform3D(fwd_hand, Vector3(0.3, 0.85, -0.25)), base.origin)
		"wave":
			r.pose(base * Transform3D(Basis(Vector3.UP, 0.6), Vector3(0, 1.62, 0)),
				base * Transform3D(down, Vector3(-0.24, 0.84, 0.02)),
				base * Transform3D(up_hand, Vector3(0.35, 1.85, -0.1)), base.origin)
