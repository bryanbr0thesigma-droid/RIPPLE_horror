extends Node3D
## Start-up: decide VR or desktop, then show the menu. In VR the menu floats in front of you and
## you point at it with the right controller.

const MenuPanel := preload("res://ui/menu_panel.tscn")
const Viewport2DIn3D := preload("res://addons/godot-xr-tools/objects/viewport_2d_in_3d.tscn")
const Pointer := preload("res://addons/godot-xr-tools/functions/function_pointer.tscn")
const LeftGlove := preload("res://addons/godot-xr-tools/hands/scenes/lowpoly/left_fullglove_low.tscn")
const RightGlove := preload("res://addons/godot-xr-tools/hands/scenes/lowpoly/right_fullglove_low.tscn")


func _ready() -> void:
	if not Game.vr_mode:
		Game.start_xr()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.vr_mode:
		_build_vr_menu()
	else:
		var layer := CanvasLayer.new()
		layer.add_child(MenuPanel.instantiate())
		add_child(layer)
	# Shortcuts for quick testing: --host, --join=IP
	if Game.args.has("host"):
		Net.local_info.vr = Game.vr_mode
		Net.host()
	elif Game.args.has("join"):
		Net.local_info.vr = Game.vr_mode
		Net.join(str(Game.args.join))


func _build_vr_menu() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.03, 0.05, 0.06)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.7, 0.75)
	add_child(env)
	var origin := XROrigin3D.new()
	add_child(origin)
	var cam := XRCamera3D.new()
	cam.position = Vector3(0, 1.7, 0)
	origin.add_child(cam)
	for side in ["left_hand", "right_hand"]:
		var c := XRController3D.new()
		c.tracker = side
		origin.add_child(c)
		c.add_child(LeftGlove.instantiate() if side == "left_hand" else RightGlove.instantiate())
		if side == "right_hand":
			c.add_child(Pointer.instantiate())
	var screen := Viewport2DIn3D.instantiate()
	screen.position = Vector3(0, 1.5, -1.6)
	add_child(screen)
	screen.screen_size = Vector2(2.4, 1.35)
	screen.viewport_size = Vector2(1280, 720)
	screen.scene = MenuPanel
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.2, 0.45, 0.5)
	floor_mesh.material_override = fm
	add_child(floor_mesh)
