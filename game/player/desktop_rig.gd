extends CharacterBody3D
## Keyboard and mouse player, for testing without a headset.
## WASD move, Shift run (loud in water), Space jump / climb out, Ctrl crouch, E pick up / use,
## left mouse use the held item (scan, pour, throw), right mouse reach down (to dip the canteen),
## Q drop, F shove a teammate, Esc free the mouse (Esc twice to leave).

const WALK := 2.3
const RUN := 4.2
const JUMP := 4.3
const GRAVITY := 9.8
const EYE := 1.65
const EYE_CROUCH := 1.0

var cam: Camera3D
var hold_point: Node3D
var held: Node3D = null
var controls := true
var crouching := false
var reaching := false
var swimming := false
var _yaw := 0.0
var _pitch := 0.0
var _push := Vector3.ZERO
var _fade_rect: ColorRect
var _pause: Control = null
var _eye := EYE
var _shape: CollisionShape3D


func _init() -> void:
	collision_layer = LevelGeometry.L_PLAYER
	collision_mask = LevelGeometry.L_WORLD | LevelGeometry.L_DYNAMIC | LevelGeometry.L_AVATARS
	floor_snap_length = 0.3
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	_shape.shape = cap
	_shape.position = Vector3(0, 0.9, 0)
	add_child(_shape)
	cam = Camera3D.new()
	cam.position = Vector3(0, EYE, 0)
	cam.near = 0.05
	cam.fov = 75.0
	add_child(cam)
	hold_point = Node3D.new()
	hold_point.position = Vector3(0.22, -0.22, -0.5)
	cam.add_child(hold_point)


func _ready() -> void:
	set_as_top_level(true)
	cam.current = true
	var layer := CanvasLayer.new()
	layer.layer = 10
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade_rect)
	add_child(layer)
	if not Game.args.has("autotest"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_pause() -> void:
	if _pause:
		_pause.queue_free()
		_pause = null
		controls = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	_pause = preload("res://ui/pause_panel.tscn").instantiate()
	_fade_rect.get_parent().add_child(_pause)
	_pause.resumed.connect(toggle_pause)
	controls = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Rig interface used by player.gd -------------------------------------------------------------

func feet_position() -> Vector3:
	return global_position


func head_transform() -> Transform3D:
	return cam.global_transform


func hand_positions() -> Array:
	return [global_transform * Vector3(-0.25, 1.0, -0.2), hold_point.global_position]


func hand_transforms() -> Array:
	return [Transform3D(global_transform.basis, hand_positions()[0]), hold_point.global_transform]


## Hand positions relative to the body, so walking doesn't count as hand movement.
func hands_relative() -> Array:
	return [to_local(hand_positions()[0]), to_local(hold_point.global_position)]


func teleport(p: Vector3) -> void:
	global_position = p
	velocity = Vector3.ZERO
	_push = Vector3.ZERO


func add_push(impulse: Vector3) -> void:
	_push += Vector3(impulse.x, 0, impulse.z)
	velocity.y += impulse.y


func set_controls_enabled(on: bool) -> void:
	controls = on


func set_fade(a: float) -> void:
	_fade_rect.color.a = a


func drop_all() -> void:
	if held:
		_release(Vector3.ZERO)


func forget_item(item: Node3D) -> void:
	if held == item:
		held = null


## Where a held item sits. Canteens tip over while pouring.
func hold_transform_for(item: Node3D) -> Transform3D:
	var xf := hold_point.global_transform
	if reaching:
		xf.origin = cam.global_position + (-cam.global_transform.basis.z * 0.8) + Vector3.DOWN * 1.15
	if item.get("desktop_pour"):
		xf.basis = xf.basis * Basis(Vector3.RIGHT, deg_to_rad(-130))
	return xf


# --- Input and movement --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.0025
		_pitch = clampf(_pitch - event.relative.y * 0.0025, -1.45, 1.45)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _pause:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		toggle_pause()
	if not controls:
		return
	if event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("drop") and held:
		_release(-cam.global_transform.basis.z * 1.5)
	elif event.is_action_pressed("push"):
		_shove()
	elif event.is_action_pressed("use_item") and held:
		held.use(true)
	elif event.is_action_released("use_item") and held:
		held.use(false)
		if held.has_method("is_throwable"):
			_release(-cam.global_transform.basis.z * 9.0 + Vector3.UP * 1.5)


func _physics_process(delta: float) -> void:
	rotation = Vector3(0, _yaw, 0)
	cam.rotation = Vector3(_pitch, 0, 0)
	crouching = controls and Input.is_action_pressed("crouch")
	reaching = controls and Input.is_action_pressed("reach")
	_eye = move_toward(_eye, EYE_CROUCH if crouching else EYE, delta * 4.0)
	cam.position.y = _eye
	(_shape.shape as CapsuleShape3D).height = maxf(_eye + 0.15, 0.7)
	_shape.position.y = (_shape.shape as CapsuleShape3D).height * 0.5

	var dir := Vector3.ZERO
	if controls:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (global_transform.basis * Vector3(iv.x, 0, iv.y)).normalized() * iv.length()
	var speed := RUN if (controls and Input.is_action_pressed("run")) else WALK
	if crouching:
		speed = 1.1

	var pool := WaterVolume.below(global_position + Vector3.UP * 0.05)
	var in_water := pool != null and global_position.y < pool.surface_y - 0.05
	swimming = in_water and pool.depth() > 1.55 and global_position.y < pool.surface_y - 1.35
	if in_water:
		speed *= 0.5 if swimming else 0.6

	var ladder := _ladder_here()
	if ladder and controls and Input.is_action_pressed("move_forward"):
		velocity.y = 2.0
		var out: Vector3 = ladder.get_meta("out")
		dir = -out * 0.6
	elif swimming:
		var target_y := pool.surface_y - 1.45
		velocity.y = clampf((target_y - global_position.y) * 3.0, -1.5, 1.5)
	else:
		velocity.y -= GRAVITY * delta

	if controls and Input.is_action_just_pressed("jump"):
		if in_water and _edge_ahead(pool):
			velocity.y = 6.2
			_push += -global_transform.basis.z * 2.5
		elif is_on_floor():
			velocity.y = JUMP * (0.7 if in_water else 1.0)

	_push = _push.move_toward(Vector3.ZERO, delta * 6.0)
	velocity.x = dir.x * speed + _push.x
	velocity.z = dir.z * speed + _push.z
	move_and_slide()
	_update_hint()


func _ladder_here() -> Area3D:
	for a in get_tree().get_nodes_in_group("ladder"):
		var sh: BoxShape3D = a.get_child(0).shape
		var local: Vector3 = a.to_local(global_position + Vector3.UP * 0.5)
		if absf(local.x) < sh.size.x * 0.5 and absf(local.y) < sh.size.y * 0.5 and absf(local.z) < sh.size.z * 0.5:
			return a
	return null


## Standing in the water facing a pool edge we can pull ourselves up onto.
func _edge_ahead(pool: WaterVolume) -> bool:
	var space := get_world_3d().direct_space_state
	var fwd := -global_transform.basis.z
	var low := global_position + Vector3.UP * 0.6
	var q := PhysicsRayQueryParameters3D.create(low, low + fwd * 0.8, LevelGeometry.L_WORLD | LevelGeometry.L_DYNAMIC)
	var hit := space.intersect_ray(q)
	if not hit:
		return false
	var top := Vector3(hit.position.x, pool.surface_y + 0.6, hit.position.z) + fwd * 0.3
	var q2 := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 0.7, LevelGeometry.L_WORLD | LevelGeometry.L_DYNAMIC)
	var hit2 := space.intersect_ray(q2)
	return hit2 and hit2.position.y - global_position.y < 2.1


# --- Interacting ---------------------------------------------------------------------------------

func _look_hit(dist := 2.4) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * dist,
		LevelGeometry.L_WORLD | LevelGeometry.L_DYNAMIC | LevelGeometry.L_ITEMS | LevelGeometry.L_AVATARS | LevelGeometry.L_TRIGGERS)
	q.collide_with_areas = true
	if held:
		q.exclude = [held.get_rid()]
	return space.intersect_ray(q)


func _interact() -> void:
	var hit := _look_hit()
	var c: Object = hit.get("collider") if hit else null
	if c and c.is_in_group("lever"):
		c.pull()
		return
	if held:
		if held.has_method("use_on") and held.use_on(c):
			return
		# Set a canteen into the distiller.
		if held.get("fill") != null and hit and (hit.position as Vector3).distance_to(Game.level.distiller_slot) < 0.9:
			var item := held
			_release(Vector3.ZERO)
			item.global_position = Game.level.distiller_slot
			item.rotation = Vector3.ZERO
			return
		# Put the lidar back on its charger.
		if held.get("battery") != null and hit and (hit.position as Vector3).distance_to(Game.level.charger_point) < 0.9:
			var item := held
			_release(Vector3.ZERO)
			item.global_position = Game.level.charger_point
			item.rotation = Vector3.ZERO
			return
		return
	if c is NetItem and not c.retired:
		held = c
		c.grab_desktop(self)


func _release(vel: Vector3) -> void:
	var item := held
	held = null
	if item:
		item.use(false)
		item.release_desktop(vel)


func _shove() -> void:
	var hit := _look_hit(1.8)
	if hit and hit.collider.is_in_group("avatar"):
		var id: int = hit.collider.get_meta("peer_id")
		Game.level.push_player(id, -cam.global_transform.basis.z * 3.5 + Vector3.UP * 0.5)


func _update_hint() -> void:
	if not Game.level or not Game.level.hud:
		return
	var text := ""
	var hit := _look_hit()
	var c: Object = hit.get("collider") if hit else null
	if c and c.is_in_group("lever"):
		text = "E: pull the lever"
	elif c is NetItem and not held and not c.retired:
		text = "E: pick up the %s" % c.name.rstrip("0123456789").to_lower()
	elif c and c.is_in_group("avatar"):
		text = "F: shove"
	if held:
		var item_name: String = held.name.rstrip("0123456789").to_lower()
		var tips := "Holding the %s. Q: drop" % item_name
		if held.get("fill") != null:
			var what := "empty"
			if held.fill > 0.0:
				what = ("distilled mineral water" if held.distilled else "mineral water") if held.mineral else "ordinary water"
			tips += ". Left mouse: pour. Right mouse: reach down to dip it. Contents: %s, %d%%" % [what, int(held.fill * 100)]
		elif held.get("battery") != null:
			tips += ". Left mouse: scan. Battery %d%%" % int(held.battery)
		elif held.has_method("is_throwable"):
			tips += ". Left mouse: throw"
		elif held.has_method("use_on"):
			tips += ". E on the staff door: unlock"
		text = tips + ("\n" + text if text != "" else "")
	Game.level.hud.set_hint(text)
