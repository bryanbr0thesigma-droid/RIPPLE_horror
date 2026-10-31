extends Node3D
## The creature. It lives in the water, hunts by sound, and is fast. The host runs its brain;
## everyone else follows its position and state.
##
## Patrol -> (small noise) Investigate -> (loud noise, or more noise nearby) Charge.
## When it arrives: if you're still moving, it has you. If you went still, it only knows the area,
## so it Searches by feel, sweeping its arm around: about a 30% chance it finds a perfectly still
## player, and any movement at all gives you away. Then it Lingers nearby for a while.

enum S { PATROL, INVESTIGATE, CHARGE, SEARCH, ATTACK, LINGER }

const SPEED := {S.PATROL: 1.3, S.INVESTIGATE: 3.2, S.CHARGE: 7.0, S.SEARCH: 0.6, S.ATTACK: 8.0, S.LINGER: 1.1}
const SEARCH_RADIUS := 4.5
const SEARCH_TIME := 7.0
const CATCH_CHANCE := 0.30
const NAV_Y := -1.3
const BODY_Y := -1.05
const MODEL := preload("res://assets/creature/creature.glb")
const VOICE_HUNT := preload("res://assets/audio/creature_hunt.ogg")
const VOICE_CLOSE := preload("res://assets/audio/creature_close.ogg")
const VOICE_CHARGE := preload("res://assets/audio/creature_charge.ogg")

## Model fitting: at scale 1 the model is about 0.65 m long and 0.3 m tall, facing +Z.
## At 3.4 it's about 2.2 m long and 1 m tall: crawling on the pool floor, its back at the surface.
const MODEL_SCALE := 3.4
const MODEL_YAW := 0.0
const MODEL_LIFT := -0.25

var state: int = S.PATROL
var target := Vector3.ZERO
var search_center := Vector3(0, -1000, 0)
var _path := PackedVector3Array()
var _path_i := 0
var _state_time := 0.0
var _clock := 0.0
var _idle := 0.0
var _search_rolls := {}
var _pending: Array = []
var _last_noise := {}          # peer -> time of their last water noise
var _attack_peer := 0
var _linger_center := Vector3.ZERO
var _yaw := 0.0
var _speed_now := 0.0
var _rng := RandomNumberGenerator.new()
var _sync_timer := 0.0
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _has_net := false

var model: Node3D
var anim: AnimationPlayer
var skeleton: Skeleton3D
var voice: AudioStreamPlayer3D
var oneshot: AudioStreamPlayer3D
var hitbox: Area3D
var wake: CPUParticles3D
var _anim_now := ""


func _ready() -> void:
	_rng.randomize()
	model = MODEL.instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	model.rotation.y = MODEL_YAW
	model.position.y = MODEL_LIFT
	add_child(model)
	anim = _find(model, "AnimationPlayer") as AnimationPlayer
	skeleton = _find(model, "Skeleton3D") as Skeleton3D
	_strip_root_offsets()
	if skeleton:
		var jaw := preload("res://creature/jaw_modifier.gd").new()
		skeleton.add_child(jaw)
	_play_anim("idle")   # the model's rest pose is metres off; never show it
	_setup_audio()
	_setup_hitbox()
	_setup_wake()
	if Net.is_host() or not Net.is_online():
		NoiseBus.heard.connect(_on_heard)
	_idle = 1.0


## The run animations leave the hip bone at the model's odd rest position (metres away). Pin the
## hip to where the idle animation holds it, so running plays in place.
func _strip_root_offsets() -> void:
	if not anim:
		return
	var idle_name := ""
	for n in anim.get_animation_list():
		if n.ends_with("|idle"):
			idle_name = n
	if idle_name == "":
		return
	var idle := anim.get_animation(idle_name)
	var hip_path := NodePath()
	var hip_pos := Vector3.ZERO
	for t in idle.get_track_count():
		if idle.track_get_type(t) == Animation.TYPE_POSITION_3D and str(idle.track_get_path(t).get_concatenated_subnames()).begins_with("spine_01"):
			hip_path = idle.track_get_path(t)
			hip_pos = idle.track_get_key_value(t, 0)
	if hip_path.is_empty():
		return
	for n in anim.get_animation_list():
		if not n.contains("run"):
			continue
		var a := anim.get_animation(n)
		var t := a.find_track(hip_path, Animation.TYPE_POSITION_3D)
		if t >= 0:
			a.remove_track(t)
		t = a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(t, hip_path)
		a.position_track_insert_key(t, 0.0, hip_pos)


func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f:
			return f
	return null


func _setup_audio() -> void:
	for s: AudioStreamOggVorbis in [VOICE_HUNT, VOICE_CLOSE]:
		s.loop = true
	voice = AudioStreamPlayer3D.new()
	voice.stream = VOICE_HUNT
	voice.unit_size = 5.0
	voice.max_db = 3.0
	voice.position = Vector3(0, 0.6, 0)
	add_child(voice)
	voice.play()
	oneshot = AudioStreamPlayer3D.new()
	oneshot.stream = VOICE_CHARGE
	oneshot.unit_size = 8.0
	oneshot.position = Vector3(0, 0.6, 0)
	add_child(oneshot)


func _setup_hitbox() -> void:
	hitbox = Area3D.new()
	hitbox.add_to_group("creature")
	hitbox.collision_layer = LevelGeometry.L_CREATURE
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 2.4
	cs.shape = cap
	cs.rotation_degrees = Vector3(90, 0, 0)
	cs.position = Vector3(0, 0.3, 0)
	hitbox.add_child(cs)
	add_child(hitbox)


func _setup_wake() -> void:
	wake = CPUParticles3D.new()
	wake.local_coords = false
	wake.amount = 60
	wake.lifetime = 2.0
	wake.emitting = false
	wake.direction = Vector3(0, 1, 0)
	wake.spread = 70.0
	wake.initial_velocity_min = 0.2
	wake.initial_velocity_max = 0.6
	wake.gravity = Vector3(0, -0.6, 0)
	wake.scale_amount_min = 0.5
	wake.scale_amount_max = 1.2
	var m := QuadMesh.new()
	m.size = Vector2(0.12, 0.12)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.85, 0.95, 1.0, 0.5)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = wm
	wake.mesh = m
	add_child(wake)


func is_searching() -> bool:
	return state == S.SEARCH


# --- Hearing (host) ------------------------------------------------------------------------------

func _on_heard(pos: Vector3, loudness: float, kind: String, peer: int) -> void:
	if Game.level == null or Game.level.state.all_escaped:
		return
	if kind in ["wade", "hands", "fall", "enter", "spill", "search_move"]:
		_last_noise[peer] = _clock
	if kind == "search_move":
		if state == S.SEARCH and _in_search_area(peer):
			_catch(peer)
			return
		loudness = maxf(loudness, 0.5)
	var d := Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
	var falloff := 1.0 if d < 10.0 else lerpf(1.0, 0.3, clampf((d - 10.0) / 40.0, 0.0, 1.0))
	var level := loudness * falloff
	if level < 0.035:
		return
	var delay := clampf((d - 15.0) / 35.0, 0.0, 1.0) * 3.0
	_pending.append({"t": _clock + delay, "pos": pos, "level": level, "peer": peer})


func _react(n: Dictionary) -> void:
	if state == S.ATTACK:
		return
	var p := _nav_point(n.pos)
	var escalate: bool = state in [S.INVESTIGATE, S.SEARCH, S.LINGER] and p.distance_to(target) < 6.0 and n.level >= 0.05
	if state == S.CHARGE or n.level >= 0.45 or escalate:
		_go(S.CHARGE, p)
	else:
		_go(S.INVESTIGATE, p)


# --- Brain (host) --------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not (Net.is_host() or not Net.is_online()):
		_follow_net(delta)
		return
	if NavigationServer3D.map_get_iteration_id(_map()) == 0:
		return   # the navigation map isn't ready yet
	_clock += delta
	_state_time += delta
	for n in _pending.duplicate():
		if _clock >= n.t:
			_pending.erase(n)
			_react(n)
	match state:
		S.SEARCH:
			_search_tick()
		S.ATTACK:
			if _state_time > 2.5:
				_go_linger(global_position)
		S.LINGER:
			if _state_time > 8.0:
				_go(S.PATROL, _patrol_point())
		S.PATROL:
			if _path_i >= _path.size():
				_idle -= delta
				if _idle <= 0.0:
					_go(S.PATROL, _patrol_point())
	_move(delta)
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 0.05
		Net.send(self, &"_net_state", [global_position, _yaw, state, search_center, _speed_now])
	_update_presentation()


func _move(delta: float) -> void:
	var speed: float = SPEED[state]
	var pos := Vector3(global_position.x, NAV_Y, global_position.z)
	_speed_now = 0.0
	if _path_i < _path.size():
		var wp := _path[_path_i]
		var to := Vector3(wp.x - pos.x, 0, wp.z - pos.z)
		if to.length() < 0.3:
			_path_i += 1
			if _path_i >= _path.size():
				_arrived()
		else:
			var step := minf(speed * delta, to.length())
			pos += to.normalized() * step
			_speed_now = step / maxf(delta, 0.0001)
			var want := atan2(to.x, to.z)
			_yaw = lerp_angle(_yaw, want, clampf(delta * (10.0 if state == S.CHARGE else 4.0), 0.0, 1.0))
	global_position = Vector3(pos.x, BODY_Y, pos.z)
	rotation.y = _yaw


func _arrived() -> void:
	match state:
		S.CHARGE, S.INVESTIGATE:
			var victim := _moving_player_near(target, 2.2, 0.8)
			if victim != 0:
				_catch(victim)
			elif _players_in_water_near(target, SEARCH_RADIUS).size() > 0:
				_start_search(target)
			else:
				_go_linger(target)
		S.PATROL:
			_idle = _rng.randf_range(1.5, 4.0)
		S.LINGER:
			_path = _nav_path(_ring_point(_linger_center, 3.0))
			_path_i = 0
		S.SEARCH:
			_path = _nav_path(_ring_point(search_center, 1.6))
			_path_i = 0


func _start_search(center: Vector3) -> void:
	var off := Vector3(_rng.randf_range(-1.2, 1.2), 0, _rng.randf_range(-1.2, 1.2))
	search_center = _nav_point(center + off)
	_search_rolls.clear()
	for id in _players_in_water_near(search_center, SEARCH_RADIUS):
		_roll(id)
	_set_state(S.SEARCH)
	_path = _nav_path(_ring_point(search_center, 1.6))
	_path_i = 0


func _roll(id: int) -> void:
	_search_rolls[id] = (_clock + _rng.randf_range(1.5, SEARCH_TIME - 0.5)) if _rng.randf() < CATCH_CHANCE else -1.0


func _search_tick() -> void:
	for id in _players_in_water_near(search_center, SEARCH_RADIUS):
		if not _search_rolls.has(id):
			_roll(id)
		var t: float = _search_rolls[id]
		if t > 0.0 and _clock >= t:
			_catch(id)
			return
	if _state_time > SEARCH_TIME:
		_go_linger(search_center)


func _in_search_area(id: int) -> bool:
	return id in _players_in_water_near(search_center, SEARCH_RADIUS + 0.5)


func _catch(id: int) -> void:
	var p = Game.level.players.get(id)
	if not p or not p.is_alive():
		return
	_attack_peer = id
	var at: Vector3 = p.body_position()
	_set_state(S.ATTACK)
	target = _nav_point(at)
	_path = PackedVector3Array([target])
	_path_i = 0
	_search_rolls.clear()
	Game.level.player_caught(id)


func _go_linger(center: Vector3) -> void:
	_linger_center = center
	_set_state(S.LINGER)
	_path = _nav_path(_ring_point(center, 3.0))
	_path_i = 0


func _go(new_state: int, p: Vector3) -> void:
	var was := state
	_set_state(new_state)
	target = p
	_path = _nav_path(p)
	_path_i = 0
	if new_state == S.CHARGE and was != S.CHARGE:
		_play_charge()


func _set_state(s: int) -> void:
	if s != state:
		_state_time = 0.0
	state = s
	if s != S.SEARCH:
		search_center = Vector3(0, -1000, 0)


# --- Helpers -------------------------------------------------------------------------------------

func _map() -> RID:
	return get_world_3d().navigation_map


func _nav_point(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(_map(), Vector3(p.x, NAV_Y, p.z))


func _nav_path(to: Vector3) -> PackedVector3Array:
	var from := Vector3(global_position.x, NAV_Y, global_position.z)
	return NavigationServer3D.map_get_path(_map(), from, to, true)


func _ring_point(center: Vector3, radius: float) -> Vector3:
	var a := _rng.randf() * TAU
	return _nav_point(center + Vector3(cos(a), 0, sin(a)) * radius)


func _patrol_point() -> Vector3:
	# Usually drift toward a player who is near the water, so it's never far away for long.
	var near := []
	for p in Game.level.players.values():
		var pos: Vector3 = p.body_position()
		if WaterVolume.below(pos + Vector3.UP * 0.1) or _nav_point(pos).distance_to(Vector3(pos.x, NAV_Y, pos.z)) < 6.0:
			near.append(pos)
	if not near.is_empty() and _rng.randf() < 0.6:
		var pos: Vector3 = near[_rng.randi() % near.size()]
		return _nav_point(pos + Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8)))
	return NavigationServer3D.map_get_random_point(_map(), 1, false)


func _players_in_water_near(center: Vector3, radius: float) -> Array:
	var out := []
	for id in Game.level.players:
		var p = Game.level.players[id]
		if p.is_alive() and p.is_in_water():
			var pos: Vector3 = p.body_position()
			if Vector2(pos.x - center.x, pos.z - center.z).length() < radius:
				out.append(id)
	return out


func _moving_player_near(center: Vector3, radius: float, within: float) -> int:
	for id in _players_in_water_near(center, radius):
		if _clock - float(_last_noise.get(id, -100.0)) < within:
			return id
	return 0


# --- Presentation (everyone) ---------------------------------------------------------------------

var _shown_state := -1


func _update_presentation() -> void:
	if state != _shown_state:
		var old := _shown_state
		_shown_state = state
		match state:
			S.PATROL:
				_set_voice(VOICE_HUNT, -14.0)
			S.INVESTIGATE:
				_set_voice(VOICE_HUNT, -6.0)
			S.CHARGE:
				_set_voice(VOICE_HUNT, -2.0)
				if old != S.CHARGE and not (Net.is_host() or not Net.is_online()):
					_play_charge()
			S.SEARCH, S.LINGER:
				_set_voice(VOICE_CLOSE, -3.0)
			S.ATTACK:
				oneshot.play()
	var a := "idle"
	match state:
		S.PATROL, S.LINGER:
			a = "walk" if _speed_now > 0.2 else "idle"
		S.INVESTIGATE:
			a = "walk"
		S.CHARGE, S.ATTACK:
			a = "run"
		S.SEARCH:
			a = "search"
	_play_anim(a)
	wake.emitting = _speed_now > 2.5
	wake.global_position = Vector3(global_position.x, -0.28, global_position.z)


func _set_voice(stream: AudioStream, db: float) -> void:
	if voice.stream != stream:
		voice.stream = stream
		voice.play()
	voice.volume_db = db


func _play_charge() -> void:
	oneshot.play()


func _play_anim(want: String) -> void:
	if not anim or want == _anim_now:
		return
	var pick := ""
	for n in anim.get_animation_list():
		if n == want or n.ends_with("|" + want) or n.to_lower() == want:
			pick = n
			break
	if pick == "":
		for n in anim.get_animation_list():
			if n.to_lower().begins_with(want):
				pick = n
				break
	if pick != "":
		var a := anim.get_animation(pick)
		a.loop_mode = Animation.LOOP_LINEAR
		anim.play(pick, 0.3)
		_anim_now = want


# --- Network (clients follow the host) -----------------------------------------------------------

@rpc("authority", "call_remote", "unreliable_ordered")
func _net_state(pos: Vector3, yaw: float, s: int, center: Vector3, speed: float) -> void:
	_net_pos = pos
	_net_yaw = yaw
	if not _has_net:
		global_position = pos
		_yaw = yaw
	_has_net = true
	state = s
	search_center = center
	_speed_now = speed


func _follow_net(delta: float) -> void:
	if _has_net:
		global_position = global_position.lerp(_net_pos, clampf(delta * 12.0, 0.0, 1.0))
		_yaw = lerp_angle(_yaw, _net_yaw, clampf(delta * 12.0, 0.0, 1.0))
		rotation.y = _yaw
	_update_presentation()


func snapshot() -> Array:
	return [global_position, _yaw, state, search_center]


func apply_snapshot(e: Array) -> void:
	_net_state(e[0], e[1], e[2], e[3], 0.0)
