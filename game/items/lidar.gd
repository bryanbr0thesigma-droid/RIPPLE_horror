extends NetItem
## The lidar scanner. Hold the trigger (or left mouse) to spray dots onto everything in front of
## it, including the pool bottom and the creature. Only the holder sees the dots. Silent.
## The battery drains while scanning and recharges at the charger once the power is on.

const RAYS_PER_TICK := 40
const RANGE := 25.0
const CONE := 0.4

var battery := 100.0
var scanning := false
var _bar: MeshInstance3D
var _bar_mat: StandardMaterial3D
var _warned := false
var _rng := RandomNumberGenerator.new()


func build() -> void:
	mass = 0.6
	# The body is the approved digital Geiger counter: screen toward you, the emitter on its back.
	add_model("res://assets/props/scanner.glb")
	add_shape_box(Vector3(0.1, 0.19, 0.11))
	var lens := add_cylinder(0.018, 0.012, Color(0.2, 0.9, 0.85), Vector3(0, 0.05, -0.058), false)
	lens.rotation_degrees = Vector3(90, 0, 0)
	_bar = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.005, 0.12)
	_bar.mesh = bm
	_bar_mat = StandardMaterial3D.new()
	_bar_mat.emission_enabled = true
	_bar.material_override = _bar_mat
	_bar.position = Vector3(0, 0.1, 0.0)
	add_child(_bar)


func use(pressed: bool) -> void:
	scanning = pressed


func item_tick(delta: float) -> void:
	var b := clampf(battery / 100.0, 0.0, 1.0)
	_bar.scale = Vector3(1, 1, maxf(b, 0.02))
	var c := Color(0.2, 1.0, 0.6).lerp(Color(1.0, 0.2, 0.1), 1.0 - b)
	_bar_mat.albedo_color = c
	_bar_mat.emission = c
	if not is_mine():
		return
	if Game.level.state.gen == 2 and global_position.distance_to(Game.level.charger_point) < 0.8:
		battery = minf(100.0, battery + 25.0 * delta)
		_warned = false
	if holder != Net.my_id() or not scanning:
		return
	if battery <= 0.0:
		if not _warned:
			_warned = true
			Game.notify("The lidar battery is empty. Recharge it at the charger in the staff room (needs power).")
		return
	battery = maxf(0.0, battery - 5.0 * delta)
	var space := get_world_3d().direct_space_state
	var origin := global_transform * Vector3(0, 0.05, -0.065)
	var fwd := -global_transform.basis.z
	var right := global_transform.basis.x
	var up := global_transform.basis.y
	var mask := LevelGeometry.L_WORLD | LevelGeometry.L_DYNAMIC | LevelGeometry.L_ITEMS | LevelGeometry.L_AVATARS | LevelGeometry.L_CREATURE
	for i in RAYS_PER_TICK:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * CONE
		var dir := (fwd + right * cos(a) * r + up * sin(a) * r).normalized()
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * RANGE, mask)
		q.collide_with_areas = true
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if hit:
			var col := Color(0.35, 1.0, 0.9)
			if hit.collider.is_in_group("creature"):
				col = Color(1.0, 0.15, 0.1)
			elif hit.collider.is_in_group("avatar"):
				col = Color(1.0, 0.85, 0.3)
			Game.level.add_lidar_dot(hit.position, col)


func extra_state() -> Array:
	return [battery]


func apply_extra(e: Array) -> void:
	if e.size() >= 1:
		battery = e[0]
