class_name NetItem
extends XRToolsPickable
## An item that can be carried in VR (XR Tools grab) or on desktop, and is synced over the network.
##
## Whoever holds an item simulates it and sends its position; everyone else follows. When it's
## dropped, the last holder keeps simulating it until it settles. Anyone can take an item, even
## from a teammate's hand: that's how items are given.

var holder := 0          # peer holding it (0 = nobody)
var auth := 1            # peer simulating it
var retired := false     # used up (the key, once it's in the lock)
var stowed := 0          # peer whose backpack it's in (0 = none)
var stow_t := 0          # when it went in (the last one in comes out first)
var home := Vector3.ZERO  # where it started
var returns_home := false  # needed to finish the level: goes home if it's lost (see level.gd)
var idle_time := 0.0
## No physics: let go and it drops straight down and stands upright where it lands (the canteen).
var steady := false
var _desk_trigger := false
var _falling := false
var _fall_v := 0.0

var desktop_holder: Node3D = null
var _target_pos := Vector3.ZERO
var _target_rot := Quaternion.IDENTITY
var _has_target := false
var _was_in_water := false
var _settle_timer := 0.0


func _init() -> void:
	collision_layer = LevelGeometry.L_ITEMS
	collision_mask = LevelGeometry.L_WORLD | LevelGeometry.L_DYNAMIC | LevelGeometry.L_ITEMS
	continuous_cd = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	ranged_grab_method = RangedMethod.LERP
	second_hand_grab = SecondHandGrab.SECOND   # hold it with both hands
	build()


## Subclasses add their meshes and collision shapes here.
func build() -> void:
	pass


func _ready() -> void:
	super._ready()
	picked_up.connect(_on_xr_picked_up)
	dropped.connect(_on_xr_dropped)
	action_pressed.connect(func(_p): use(true))
	action_released.connect(func(_p): use(false))
	_update_freeze()


func is_mine() -> bool:
	return auth == Net.my_id()


func is_held_by_me() -> bool:
	return desktop_holder != null or is_picked_up()


## Trigger (VR) or left mouse (desktop) while holding.
func use(_pressed: bool) -> void:
	pass


## Is the trigger held right now on a hand holding this (VR), or the left mouse (desktop)? Read
## straight from the controllers, so it doesn't depend on which hand or on button events arriving.
func trigger_down() -> bool:
	if desktop_holder:
		return _desk_trigger
	if not is_picked_up() or not _grab_driver:
		return false
	for g in [_grab_driver.primary, _grab_driver.secondary]:
		if g and g.controller and (g.controller as XRController3D).get_float("trigger") > 0.5:
			return true
	return false


func set_desktop_trigger(on: bool) -> void:
	_desk_trigger = on


func _update_freeze() -> void:
	if retired or stowed != 0 or steady:
		freeze = true
		return
	if is_picked_up():
		return   # XR Tools is moving it
	freeze = desktop_holder != null or not is_mine()


# --- Picking up and dropping ---------------------------------------------------------------------

func _on_xr_picked_up(_p) -> void:
	holder = Net.my_id()
	auth = holder
	Game.level.request_item(name, "pick")


func _on_xr_dropped(_p) -> void:
	var lv := linear_velocity
	var av := angular_velocity
	holder = 0
	auth = Net.my_id()
	# Let go over your shoulder: into your backpack.
	var me = Game.level.local_player if Game.level else null
	if me and me.rig and me.rig.has_method("in_backpack") and me.rig.in_backpack(global_position) \
			and Game.level.backpack_of(Net.my_id()).size() < Game.level.BACKPACK_SIZE:
		Game.level.stow_item(self)
		return
	_update_freeze()
	linear_velocity = lv
	angular_velocity = av
	_settle_timer = 3.0
	_start_fall()
	Game.level.request_item(name, "drop")


func grab_desktop(rig: Node3D) -> void:
	desktop_holder = rig
	holder = Net.my_id()
	auth = holder
	_update_freeze()
	Game.level.request_item(name, "pick")


func release_desktop(vel: Vector3) -> void:
	desktop_holder = null
	_desk_trigger = false
	holder = 0
	auth = Net.my_id()
	_update_freeze()
	linear_velocity = vel
	_settle_timer = 3.0
	_start_fall()
	Game.level.request_item(name, "drop")


## In or out of someone's backpack: hidden and out of reach while it's in.
func set_stowed(peer: int) -> void:
	if peer != 0 and is_held_by_me():
		_force_local_drop()
	stowed = peer
	if peer != 0:
		stow_t = Time.get_ticks_msec()
	_falling = false
	visible = peer == 0 and not retired
	enabled = peer == 0 and not retired
	collision_layer = LevelGeometry.L_ITEMS if peer == 0 and not retired else 0
	_update_freeze()


func _start_fall() -> void:
	if steady:
		linear_velocity = Vector3.ZERO          # a frozen body still drifts by its velocity in Jolt
		angular_velocity = Vector3.ZERO
		_falling = true
		_fall_v = 0.0
		_settle_timer = 3.0


## The host says who holds this now (and who simulates it).
func set_owner_state(h: int, a: int) -> void:
	var me := Net.my_id()
	if h != me and is_held_by_me():
		_force_local_drop()
	holder = h
	auth = a
	if a == me:
		_settle_timer = 3.0
	_update_freeze()


func _force_local_drop() -> void:
	if desktop_holder:
		var rig := desktop_holder
		desktop_holder = null
		if rig.has_method("forget_item"):
			rig.forget_item(self)
	if is_picked_up():
		drop()


func retire() -> void:
	if is_held_by_me():
		_force_local_drop()
	retired = true
	visible = false
	enabled = false
	collision_layer = 0
	collision_mask = 0
	freeze = true


# --- Network sync --------------------------------------------------------------------------------

func needs_sync() -> bool:
	return not retired and stowed == 0 and (holder != 0 or _settle_timer > 0.0)


func extra_state() -> Array:
	return []


func apply_extra(_extra: Array) -> void:
	pass


func net_target(pos: Vector3, rot: Quaternion, extra: Array) -> void:
	_target_pos = pos
	_target_rot = rot
	if not _has_target:
		global_position = pos
		quaternion = rot
	_has_target = true
	apply_extra(extra)


func snapshot() -> Array:
	return [name, holder, auth, global_position, global_transform.basis.get_rotation_quaternion(), extra_state(), retired, stowed]


func apply_snapshot(e: Array) -> void:
	holder = e[1]
	auth = e[2]
	global_position = e[3]
	quaternion = e[4]
	_target_pos = e[3]
	_target_rot = e[4]
	_has_target = true
	apply_extra(e[5])
	if e[6]:
		retire()
	if e.size() > 7 and int(e[7]) != stowed:
		set_stowed(int(e[7]))
	_update_freeze()


# --- Every frame ---------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if retired or stowed != 0:
		return
	if _falling and is_mine() and holder == 0:
		_fall(delta)
	if desktop_holder:
		global_transform = desktop_holder.hold_transform_for(self)
	elif not is_mine() and _has_target and not is_picked_up():
		global_position = global_position.lerp(_target_pos, clampf(delta * 15.0, 0.0, 1.0))
		quaternion = quaternion.slerp(_target_rot, clampf(delta * 15.0, 0.0, 1.0))
	if is_mine():
		_settle_timer = maxf(_settle_timer - delta, 0.0)
		if holder == 0 and not freeze:
			if linear_velocity.length() > 0.05:
				_settle_timer = maxf(_settle_timer, 0.5)
			_water_tick()
	item_tick(delta)


## Dropped or thrown into the water: noise where it lands, then it sinks slowly.
func _water_tick() -> void:
	var pool := WaterVolume.below(global_position)
	var wet := pool != null and global_position.y < pool.surface_y
	if wet and not _was_in_water:
		var speed := linear_velocity.length()
		var surface := Vector3(global_position.x, pool.surface_y, global_position.z)
		NoiseBus.make(surface, clampf(0.2 + speed * 0.07, 0.2, 0.8), "item")
		Game.level.play_sfx("plop" if speed < 4.0 else "splash_small", surface)
		on_entered_water(pool)
	if wet:
		linear_damp = 4.0
		angular_damp = 4.0
		gravity_scale = 0.35
	else:
		linear_damp = 0.05
		angular_damp = 0.05
		gravity_scale = 1.0
	_was_in_water = wet


func on_entered_water(_pool: WaterVolume) -> void:
	pass


## A steady item, let go: straight down, upright, onto the floor or floating at the water's surface.
func _fall(delta: float) -> void:
	_fall_v = minf(_fall_v + 9.8 * delta, 8.0)
	var from := global_position
	var to := from + Vector3.DOWN * _fall_v * delta
	var pool := WaterVolume.below(from)
	var rest_y := -INF
	var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.05, to + Vector3.DOWN * 0.15, LevelGeometry.L_WORLD | LevelGeometry.L_DYNAMIC)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		rest_y = (hit.position as Vector3).y + 0.13
	if pool and pool.surface_y - 0.05 > rest_y:
		rest_y = pool.surface_y - 0.05          # floats upright at the surface (even dropped under it)
	var yaw := global_transform.basis.get_euler().y
	global_transform.basis = global_transform.basis.slerp(Basis(Vector3.UP, yaw), clampf(delta * 10.0, 0.0, 1.0))
	if to.y <= rest_y:
		global_position = Vector3(from.x, rest_y, from.z)
		global_transform.basis = Basis(Vector3.UP, yaw)
		_falling = false
		_settle_timer = 0.5
		if pool and rest_y >= pool.surface_y - 0.06:
			var surface := Vector3(from.x, pool.surface_y, from.z)
			NoiseBus.make(surface, clampf(0.15 + _fall_v * 0.06, 0.15, 0.6), "item")
			Game.level.play_sfx("plop", surface)
		return
	global_position = to


func item_tick(_delta: float) -> void:
	pass


## Helpers for building item meshes.
## A model (from assets/props) as this item's look. Collision is added separately.
func add_model(path: String, xf := Transform3D()) -> Node3D:
	var m: Node3D = (load(path) as PackedScene).instantiate()
	m.transform = xf
	add_child(m)
	return m


## A collision box with no mesh.
func add_shape_box(size: Vector3, offset := Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = offset
	add_child(cs)


func add_shape_cylinder(radius: float, height: float, offset := Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	cs.position = offset
	add_child(cs)


func add_box(size: Vector3, color: Color, offset := Vector3.ZERO, collide := true, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.5
	mi.material_override = m
	mi.position = offset
	add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.position = offset
		add_child(cs)
	return mi


func add_cylinder(radius: float, height: float, color: Color, offset := Vector3.ZERO, collide := true, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.45
	mi.material_override = m
	mi.position = offset
	add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = height
		cs.shape = sh
		cs.position = offset
		add_child(cs)
	return mi
