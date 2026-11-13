extends XROrigin3D
## The VR player: XR Tools hands, grabbing, climbing, smooth movement, turning and jumping.
## Left stick moves, right stick turns, A/X jumps, grip grabs, trigger uses the held item.

@onready var camera: XRCamera3D = $XRCamera3D
@onready var left: XRController3D = $LeftHand
@onready var right: XRController3D = $RightHand
@onready var body: XRToolsPlayerBody = $PlayerBody
var _body_placed := false

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
var _in_pack := [false, false]


func _ready() -> void:
	set_as_top_level(true)
	current = true
	$MovementWater.rig = self
	for p in [$LeftHand/CollisionHandLeft/FunctionPickup, $RightHand/CollisionHandRight/FunctionPickup]:
		# An item in one hand sits on XR Tools' "held" layer; the other hand must see that layer too,
		# or it can't take hold of it as well.
		p.grab_collision_mask = LevelGeometry.L_ITEMS | LevelGeometry.L_GRAB | XRToolsPickable.DEFAULT_LAYER
		p.ranged_collision_mask = LevelGeometry.L_ITEMS
	body.collision_mask = LevelGeometry.L_WORLD | LevelGeometry.L_DYNAMIC | LevelGeometry.L_AVATARS
	# Your real height, 1:1 (no calibrating everyone to one height, which can start shorter or
	# seated players below the floor), and walking into a wall in real life pushes you back
	# instead of letting your head through.
	body.player_calibrate_height = false
	body.player_height_offset = 0.0
	body.head_behavior_mode = 0
	# Hands stop at walls, floors and tables instead of passing through them.
	for hand in [$LeftHand/CollisionHandLeft, $RightHand/CollisionHandRight]:
		hand.collision_mask = LevelGeometry.L_WORLD | LevelGeometry.L_DYNAMIC | LevelGeometry.L_ITEMS
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
	Game.recentered.connect(_on_recentered)
	# Hands match the suit's gloves; turning follows the player's setting.
	VRHands.tint($LeftHand/CollisionHandLeft/LeftGlove, SuitRig.glove_color(Profile.suit))
	VRHands.tint($RightHand/CollisionHandRight/RightGlove, SuitRig.glove_color(Profile.suit))
	$RightHand/MovementTurn.turn_mode = 1 if Profile.snap_turn else 2
	# Pause menu on the left controller's menu button.
	_pointer = POINTER.instantiate()
	_pointer.enabled = false
	_pointer.visible = false
	right.add_child(_pointer)
	left.button_pressed.connect(func(b):
		if b == "menu_button":
			toggle_pause())
	# Both thumbsticks clicked together: drop a test dummy in the water ahead.
	for pair in [[left, right], [right, left]]:
		pair[0].button_pressed.connect(func(b):
			if b == "primary_click" and pair[1].is_button_pressed("primary_click") and Game.level:
				Game.level.spawn_dummy(camera.global_transform))
	# The backpack, over your shoulder: grip there with an empty hand to take the last item out.
	for pair in [[left, $LeftHand/CollisionHandLeft/FunctionPickup], [right, $RightHand/CollisionHandRight/FunctionPickup]]:
		pair[0].button_pressed.connect(func(b):
			if b == "grip_click":
				_take_from_backpack(pair[0], pair[1]))
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
	# A buzz when a hand holding something reaches into the backpack, so you know you can let go.
	for i in 2:
		var c: XRController3D = left if i == 0 else right
		var p = ($LeftHand/CollisionHandLeft/FunctionPickup if i == 0 else $RightHand/CollisionHandRight/FunctionPickup)
		var inside := in_backpack(c.global_position)
		if inside and not _in_pack[i] and Game.level and (is_instance_valid(p.picked_up_object) or not Game.level.backpack_of(Net.my_id()).is_empty()):
			c.trigger_haptic_pulse("haptic", 0.0, 0.35, 0.08, 0.0)
		_in_pack[i] = inside
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


## The two gloves you see (for your own body's arms to meet them).
func gloves() -> Array:
	return [get_node_or_null("LeftHand/CollisionHandLeft/LeftGlove"), get_node_or_null("RightHand/CollisionHandRight/RightGlove")]


func hand_transforms() -> Array:
	return [left.global_transform, right.global_transform]


## Hands in play-space coordinates: stick movement and turning move the whole play space, so they
## don't count as hand movement. Only actually moving your hands does.
func hands_relative() -> Array:
	return [left.position, right.position]


## Is this point in the backpack: behind your head, over either shoulder?
func in_backpack(p: Vector3) -> bool:
	var local := camera.global_transform.affine_inverse() * p
	return local.z > 0.08 and local.y > -0.7 and local.y < 0.3 and absf(local.x) < 0.5


func _take_from_backpack(c: XRController3D, pickup: Node) -> void:
	if is_instance_valid(pickup.picked_up_object) or not in_backpack(c.global_position) or not Game.level:
		return
	var it = Game.level.take_from_backpack(c.global_transform)
	if it:
		pickup._pick_up_object(it)
		c.trigger_haptic_pulse("haptic", 0.0, 0.6, 0.1, 0.0)


## After the Meta-button recenter, the view faces forward again; keep the player standing where
## they were instead of jumping to the middle of their play area (maybe into a wall).
func _on_recentered() -> void:
	var feet := body.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(body):
		teleport(feet)


func teleport(p: Vector3) -> void:
	# The player body is top-level: until it first moves it still sits at the world origin, and
	# teleporting from there put the rig the spawn point's distance away twice over (outside the
	# lobby's wall, falling out of the map). Bring it under the rig first.
	if not _body_placed:
		_body_placed = true
		body.global_position = global_position
	body.teleport(Transform3D(body.global_transform.basis, p))


func add_push(impulse: Vector3) -> void:
	pending_push += impulse


func set_controls_enabled(on: bool) -> void:
	for path in ["LeftHand/MovementDirect", "RightHand/MovementTurn", "RightHand/MovementJump", "MovementClimb", "LeftHand/CollisionHandLeft/FunctionPickup", "RightHand/CollisionHandRight/FunctionPickup"]:
		var n := get_node_or_null(path)
		if n:
			n.enabled = on


## A ghost sees the world through a cold, pale tint, and can't take hold of anything.
var _ghost_view := false

func set_ghost_view(on: bool) -> void:
	_ghost_view = on
	set_fade(0.0)


func set_pickups_enabled(on: bool) -> void:
	for path in ["LeftHand/CollisionHandLeft/FunctionPickup", "RightHand/CollisionHandRight/FunctionPickup"]:
		var n := get_node_or_null(path)
		if n:
			n.enabled = on


func set_fade(a: float) -> void:
	# Black for fades; the ghost tint underneath when it's clear.
	if _ghost_view and a < 0.2:
		_fade_mat.albedo_color = Color(0.35, 0.5, 0.65, 0.25)
		_fade.visible = true
		return
	_fade_mat.albedo_color = Color(0, 0, 0, a)
	_fade.visible = a > 0.01


func drop_all() -> void:
	$LeftHand/CollisionHandLeft/FunctionPickup.drop_object()
	$RightHand/CollisionHandRight/FunctionPickup.drop_object()


func rumble_hand(i: int, amount: float) -> void:
	var c: XRController3D = left if i == 0 else right
	if c.get_is_active():
		c.trigger_haptic_pulse("haptic", 0.0, clampf(amount, 0.05, 1.0), 0.08, 0.0)


func rumble(amount: float) -> void:
	for c in [left, right]:
		if c.get_is_active():
			c.trigger_haptic_pulse("haptic", 0.0, clampf(amount, 0.05, 1.0), 0.12, 0.0)
