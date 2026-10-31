extends NetItem
## The water canteen. Dip it in the darker mineral water to fill it, carry it without spilling,
## and pour it into the generator's funnel. Tip it and it spills; spilling into the pool splashes.
## Dipping it in ordinary pool water swaps the contents for ordinary water, which is useless.

const SPOUT := Vector3(0, 0.15, 0)
const PourLoop := preload("res://assets/audio/pour_loop.ogg")

var fill := 0.0
var mineral := false
var distilled := false
var pouring := false
var desktop_pour := false   # desktop: left mouse tips it over

var _level_mesh: MeshInstance3D
var _level_mat: StandardMaterial3D
var _stream: CPUParticles3D
var _audio: AudioStreamPlayer3D
var _distill := 0.0
var _spill_timer := 0.0
var _fuel_acc := 0.0
var _fuel_timer := 0.0
var _warned_plain := false
var _last_speed := 0.0


func build() -> void:
	mass = 0.8
	add_cylinder(0.055, 0.24, Color(0.28, 0.32, 0.22), Vector3.ZERO, true, 0.2)
	add_cylinder(0.022, 0.035, Color(0.15, 0.15, 0.15), Vector3(0, 0.135, 0), false, 0.5)
	# A window strip on the side shows how full it is and what's inside.
	add_box(Vector3(0.022, 0.2, 0.004), Color(0.05, 0.05, 0.05), Vector3(0, 0, 0.056), false)
	_level_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.016, 0.19, 0.004)
	_level_mesh.mesh = bm
	_level_mat = StandardMaterial3D.new()
	_level_mat.emission_enabled = true
	_level_mat.emission_energy_multiplier = 0.4
	_level_mesh.material_override = _level_mat
	_level_mesh.position = Vector3(0, 0, 0.0585)
	add_child(_level_mesh)
	_stream = CPUParticles3D.new()
	_stream.emitting = false
	_stream.amount = 40
	_stream.lifetime = 0.6
	_stream.direction = Vector3(0, 1, 0)
	_stream.spread = 8.0
	_stream.initial_velocity_min = 0.4
	_stream.initial_velocity_max = 0.6
	_stream.gravity = Vector3(0, -9.8, 0)
	_stream.scale_amount_min = 0.6
	var sm := SphereMesh.new()
	sm.radius = 0.008
	sm.height = 0.016
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.5, 0.7, 0.75, 0.7)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = wm
	_stream.mesh = sm
	_stream.position = SPOUT
	add_child(_stream)
	_audio = AudioStreamPlayer3D.new()
	var pour: AudioStreamOggVorbis = PourLoop
	pour.loop = true
	_audio.stream = pour
	_audio.volume_db = -8.0
	_audio.unit_size = 2.0
	add_child(_audio)


func use(pressed: bool) -> void:
	desktop_pour = pressed


func spout_global() -> Vector3:
	return global_transform * SPOUT


func tilt_deg() -> float:
	return rad_to_deg(global_transform.basis.y.angle_to(Vector3.UP))


func is_distilling() -> bool:
	return holder == 0 and not retired and mineral and not distilled and fill > 0.3 \
		and global_position.distance_to(Game.level.distiller_slot) < 0.3


func item_tick(delta: float) -> void:
	_update_visuals()
	if not is_mine():
		return
	var sp := spout_global()
	var pool := WaterVolume.at(sp)
	if pool and sp.y < pool.surface_y:
		# Dipped in the water: it fills with whatever water this is.
		if pool.mineral != mineral and fill > 0.0:
			fill = 0.0
		if not pool.mineral or not mineral:
			distilled = false
		mineral = pool.mineral
		fill = minf(1.0, fill + 0.4 * delta)
		pouring = false
	else:
		var tilt := tilt_deg()
		pouring = fill > 0.0 and tilt > 80.0
		if pouring:
			var rate := lerpf(0.12, 0.6, clampf((tilt - 80.0) / 70.0, 0.0, 1.0))
			var amount := minf(fill, rate * delta)
			fill -= amount
			_pour_land(sp, amount, delta)
	if fill <= 0.0:
		fill = 0.0
		mineral = false
		distilled = false
		pouring = false
	_fuel_timer -= delta
	if _fuel_timer <= 0.0 and _fuel_acc > 0.0:
		Game.level.request("fuel", [_fuel_acc, distilled])
		_fuel_acc = 0.0
		_fuel_timer = 0.2
	# Sitting in the distiller.
	if is_distilling():
		_distill += delta / 6.0
		if _distill >= 1.0:
			distilled = true
			_distill = 0.0
			Game.notify("The canteen's water is distilled. The generator will start faster with it.")
	else:
		_distill = 0.0
	# A hard knock spills some.
	var speed := linear_velocity.length()
	if holder == 0 and _last_speed > 3.5 and speed < 1.0 and fill > 0.0:
		fill *= 0.5
	_last_speed = speed


func _pour_land(sp: Vector3, amount: float, delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(sp, sp + Vector3.DOWN * 4.0, LevelGeometry.L_WORLD | LevelGeometry.L_DYNAMIC | LevelGeometry.L_TRIGGERS)
	q.collide_with_areas = true
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit and hit.collider and hit.collider.is_in_group("generator_funnel"):
		if mineral:
			_fuel_acc += amount
		elif not _warned_plain:
			_warned_plain = true
			Game.notify("That's ordinary pool water. The generator only runs on the darker mineral water.")
		return
	var pool := WaterVolume.below(sp)
	if pool:
		_spill_timer -= delta
		if _spill_timer <= 0.0:
			_spill_timer = 0.4
			NoiseBus.make(Vector3(sp.x, pool.surface_y, sp.z), 0.12, "spill")


func on_entered_water(pool: WaterVolume) -> void:
	mineral = pool.mineral
	distilled = false
	fill = 1.0


func _update_visuals() -> void:
	var f := clampf(fill, 0.0, 1.0)
	_level_mesh.visible = f > 0.01
	_level_mesh.scale = Vector3(1, maxf(f, 0.01), 1)
	_level_mesh.position.y = -0.095 * (1.0 - f)
	var c := Color(0.45, 0.7, 0.8)
	if mineral:
		c = Color(0.95, 0.95, 1.0) if distilled else Color(0.08, 0.22, 0.24)
	_level_mat.albedo_color = c
	_level_mat.emission = c
	_stream.emitting = pouring
	if pouring and not _audio.playing:
		_audio.play()
	elif not pouring and _audio.playing:
		_audio.stop()


func extra_state() -> Array:
	return [fill, mineral, distilled, pouring]


func apply_extra(e: Array) -> void:
	if e.size() >= 4:
		fill = e[0]
		mineral = e[1]
		distilled = e[2]
		pouring = e[3]
