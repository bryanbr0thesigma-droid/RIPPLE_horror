extends XROrigin3D
## The VR player: XR Tools hands, grabbing, climbing, smooth movement, turning and jumping.
## Left stick moves, right stick turns, A/X jumps, grip grabs, trigger uses the held item.

@onready var camera: XRCamera3D = $XRCamera3D
@onready var left: XRController3D = $LeftHand
@onready var right: XRController3D = $RightHand
@onready var body: XRToolsPlayerBody = $PlayerBody

const POINTER := preload("res://addons/godot-xr-tools/functions/function_pointer.tscn")
const VIEWPORT_3D := preload("res://addons/godot-xr-tools/objects/viewport_2d_in_3d.tscn")
const PAUSE := preload("res://ui/pause_panel.tscn")

var pending_push := Vector3.ZERO
var _pointer: Node3D
var _pause_screen: Node3D
var _fade: MeshInstance3D
var _fade_mat: StandardMaterial3D
var _msg: Label3D
var _msg_time := 0.0
var _hand_areas: Array[Area3D] = []
var _last_hand_pos := [Vector3.ZERO, Vector3.ZERO]


func _ready() -> void:
	set_as_top_level(true)
	current = true
	$MovementWater.rig = self
	for p in [$LeftHand/FunctionPickup, $RightHand/FunctionPickup]:
		p.grab_collision_mask = LevelGeometry.L_ITEMS | LevelGeometry.L_GRAB
		p.ranged_collision_mask = LevelGeometry.L_ITEMS
	body.collision_mask = LevelGeometry.L_WORLD | LevelGeometry.L_DYNAMIC | LevelGeometry.L_AVATARS
	# A black sphere around the head for fading out when caught.
	_fade = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	sm.flip_faces = true
	_fade.mesh = sm
	_fade_mat = StandardMaterial3D.new()
	_fade_mat.albedo_color = Color(0, 0, 0, 0)
	_fade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fade_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fade_mat.no_depth_test = true
	_fade_mat.render_priority = 100
	_fade.material_override = _fade_mat
	_fade.visible = false
	camera.add_child(_fade)
	# Messages float in front of you for a few seconds.
	_msg = Label3D.new()
	_msg.pixel_size = 0.0012
	_msg.font_size = 32
	_msg.outline_size = 8
	_msg.width = 700
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.no_depth_test = true
	_msg.render_priority = 50
	_msg.position = Vector3(0, -0.15, -0.9)
	_msg.visible = false
	camera.add_child(_msg)
	Game.message.connect(_show_message)
	# Hands match the suit's gloves; turning follows the player's setting.
	VRHands.tint($LeftHand/LeftGlove, SuitRig.glove_color(Profile.suit))
	VRHands.tint($RightHand/RightGlove, SuitRig.glove_color(Profile.suit))
	$RightHand/MovementTurn.turn_mode = 1 if Profile.snap_turn else 2
	# Pause menu on the left controller's menu button.
	_pointer = POINTER.instantiate()
	_pointer.enabled = false
	_pointer.visible = false
	right.add_child(_pointer)
	left.button_pressed.connect(func(b):
		if b == "menu_button":
			toggle_pause())
	# Hands that can shove teammates.
	for c in [left, right]:
		var a := Area3D.new()
		a.collision_layer = 0
		a.collision_mask = LevelGeometry.L_AVATARS
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.08
		cs.shape = sh
		a.add_child(cs)
		c.add_child(a)
		a.body_entered.connect(_on_hand_hit.bind(_hand_areas.size()))
		_hand_areas.append(a)


func _process(delta: float) -> void:
	if _msg_time > 0.0:
		_msg_time -= delta
		_msg.modulate.a = clampf(_msg_time, 0.0, 1.0)
		_msg.visible = _msg_time > 0.0


func _physics_process(_delta: float) -> void:
	_last_hand_pos = [left.global_position, right.global_position]


func _show_message(text: String) -> void:
	_msg.text = text
	_msg_time = 6.0
	_msg.visible = true


func _on_hand_hit(other: Node3D, i: int) -> void:
	if not other.is_in_group("avatar"):
		return
	var hand: XRController3D = left if i == 0 else right
	var v: Vector3 = (hand.global_position - _last_hand_pos[i]) * Engine.physics_ticks_per_second
	if v.length() > 1.2:
		Game.level.push_player(other.get_meta("peer_id"), v.limit_length(4.0) * 0.9)


func toggle_pause() -> void:
	if _pause_screen:
		_pause_screen.queue_free()
		_pause_screen = null
		_pointer.enabled = false
		_pointer.visible = false
		return
	_pause_screen = VIEWPORT_3D.instantiate()
	get_parent().add_child(_pause_screen)
	var fwd := -camera.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	_pause_screen.global_position = camera.global_position + fwd * 1.0
	_pause_screen.look_at(camera.global_position, Vector3.UP)
	_pause_screen.rotate_object_local(Vector3.UP, PI)
	_pause_screen.unshaded = true
	_pause_screen.screen_size = Vector2(0.9, 0.6)
	_pause_screen.viewport_size = Vector2(720, 480)
	_pause_screen.scene = PAUSE
	_pause_screen.get_scene_instance().resumed.connect(toggle_pause)
	_pointer.enabled = true
	_pointer.visible = true


# --- Rig interface used by player.gd -------------------------------------------------------------

func feet_position() -> Vector3:
	return body.global_position


func head_transform() -> Transform3D:
	return camera.global_transform


func hand_positions() -> Array:
	return [left.global_position, right.global_position]


func hand_transforms() -> Array:
	return [left.global_transform, right.global_transform]


## Hands in play-space coordinates: stick movement and turning move the whole play space, so they
## don't count as hand movement. Only actually moving your hands does.
func hands_relative() -> Array:
	return [left.position, right.position]


func teleport(p: Vector3) -> void:
	body.teleport(Transform3D(body.global_transform.basis, p))


func add_push(impulse: Vector3) -> void:
	pending_push += impulse


func set_controls_enabled(on: bool) -> void:
	for path in ["LeftHand/MovementDirect", "RightHand/MovementTurn", "RightHand/MovementJump", "MovementClimb", "LeftHand/FunctionPickup", "RightHand/FunctionPickup"]:
		var n := get_node_or_null(path)
		if n:
			n.enabled = on


func set_fade(a: float) -> void:
	_fade_mat.albedo_color.a = a
	_fade.visible = a > 0.01


func drop_all() -> void:
	$LeftHand/FunctionPickup.drop_object()
	$RightHand/FunctionPickup.drop_object()


func rumble(amount: float) -> void:
	for c in [left, right]:
		if c.get_is_active():
			c.trigger_haptic_pulse("haptic", 0.0, clampf(amount, 0.05, 1.0), 0.12, 0.0)
