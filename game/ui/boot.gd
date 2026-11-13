extends Node3D
## The first scene: only a camera in the dark (an XR one on the headset). The loading sign shows in
## front of you, head-tracked, while the title screen or the first-boot tape loads in the
## background, instead of a frozen view (the OS splash covers the engine starting; Meta asks for
## something that follows your head within 4 seconds of launch).


func _ready() -> void:
	Game.start_xr()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0, 0, 0)
	add_child(env)
	if Game.vr_mode and not Game.args.has("fakevr"):
		var origin := XROrigin3D.new()
		add_child(origin)
		var cam := XRCamera3D.new()
		origin.add_child(cam)
		cam.current = true
	else:
		var cam := Camera3D.new()
		cam.position = Vector3(0, 1.6, 0)
		add_child(cam)
		cam.current = true
	for i in 5:                    # a few frames, so head tracking has started before the sign goes up
		await get_tree().process_frame
	if Game.fader.busy or get_tree().current_scene != self:
		return                     # something else already asked for a scene (a test, a quick start)
	Game.fader.go(Game.INTRO_SCENE if Game.intro_due() else Game.MENU_SCENE)
