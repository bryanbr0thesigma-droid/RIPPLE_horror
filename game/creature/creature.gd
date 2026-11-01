extends Node3D
## The creature. It lives in the water, hunts by sound, and is fast when it charges. A quarter
## taller than a person, gaunt and hunched, it wades slowly upright through the shallow pools,
## clicking now and then, and crawls through the deep channels between halls. The host runs its
## brain; everyone else follows its position and state, and everyone plays the kill and the feeding.
##
## Patrol -> (small noise) Investigate -> (loud noise, or more noise nearby) Charge.
## When it arrives: if you're still moving, it has you. If you went still, it only knows the area,
## so it Searches by feel, sweeping its arm around: about a 30% chance it finds a perfectly still
## player, and any movement at all gives you away. Then it Lingers nearby for a while.

enum S { PATROL, INVESTIGATE, CHARGE, SEARCH, ATTACK, LINGER, FEAST }

const SPEED := {S.PATROL: 0.7, S.INVESTIGATE: 1.5, S.CHARGE: 6.5, S.SEARCH: 0.5, S.ATTACK: 9.0, S.LINGER: 0.6, S.FEAST: 0.0}
## After a kill it feeds for up to ten seconds and hears nothing: the others' chance to get away.
const FEAST_MIN := 6.0
const FEAST_MAX := 10.0
const SEARCH_RADIUS := 4.5
const SEARCH_TIME := 7.0
const CATCH_CHANCE := 0.30
const NAV_Y := -1.3            # the navigation mesh is a flat plane; height comes from the water below
const DEEP := 1.2               # deeper than this it drops to all fours and crawls
const ATTACK_TIME := 4.8
const KILL_GRAB := 0.55         # the kill: seconds after the catch when it grabs them
const MODEL := preload("res://assets/creature/creature.glb")
const VOICE_HUNT := preload("res://assets/audio/creature_hunt.ogg")
const VOICE_CLOSE := preload("res://assets/audio/creature_close.ogg")
const CHARGE_ONSET := preload("res://assets/audio/charge_onset.ogg")
const CHARGE_HOLDS := [preload("res://assets/audio/charge_hold_a.ogg"), preload("res://assets/audio/charge_hold_b.ogg")]
const CHARGE_END := preload("res://assets/audio/charge_end.ogg")
# Approved screeches only. The trimmed 2, 4 and 7 are in review (Round 22) and join when approved.
const KILL_SCREECHES := [
	preload("res://assets/audio/kill_screech_1.ogg"), preload("res://assets/audio/kill_screech_3.ogg"),
	preload("res://assets/audio/kill_screech_5.ogg")]
const KILL_TEAR := preload("res://assets/audio/kill_tear.ogg")
const KILL_SPINE := preload("res://assets/audio/kill_spine.ogg")
const KILL_FEAST := preload("res://assets/audio/kill_feast.ogg")
const KILL_BITES := [preload("res://assets/audio/kill_bite_1.ogg"), preload("res://assets/audio/kill_bite_2.ogg")]
const KILL_STRAIN := preload("res://assets/audio/kill_strain.ogg")
const KILL_CRACKS := [preload("res://assets/audio/kill_crack_1.ogg"), preload("res://assets/audio/kill_crack_2.ogg"),
	preload("res://assets/audio/kill_crack_3.ogg")]
const KILL_NECK := preload("res://assets/audio/kill_neck.ogg")
const KILL_SPLIT := preload("res://assets/audio/kill_split.ogg")
const FEED_TEARS := [preload("res://assets/audio/feed_tear_1.ogg"), preload("res://assets/audio/feed_tear_2.ogg")]
const FEED_CRUNCH := [preload("res://assets/audio/feed_crunch_1.ogg"), preload("res://assets/audio/feed_crunch_2.ogg")]
const FEED_CHEW := [preload("res://assets/audio/feed_chew_1.ogg"), preload("res://assets/audio/feed_chew_2.ogg"),
	preload("res://assets/audio/kill_feast.ogg")]
const FEED_GULP := preload("res://assets/audio/feed_gulp.ogg")
const FEED_GROWL := preload("res://assets/audio/feed_growl.ogg")
const SPLASH := preload("res://assets/audio/splash_big.ogg")
const SPLASH_SMALL := preload("res://assets/audio/splash_small.ogg")
const WadeModifier := preload("res://creature/wade_modifier.gd")

## Model fitting: facing +Z, feet at its origin. Posed upright by the wade modifier, at 3.15 its head
## is about 2.2 m up: a quarter taller than a 1.75 m player.
const MODEL_SCALE := 3.15
const MODEL_YAW := 0.0
const MODEL_LIFT := 0.0

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
var wade: Node
var _anim_now := ""
var _y := -0.95
var _last_pos := Vector3.ZERO
var _burst_left := 0.0
var _click_t := 3.0
var _kill := {}
var _last_screech := -1
var _bite_player: AudioStreamPlayer3D
var _head_bone := -1
var _feast_for := 4.0
var _last_kill := -1
var _feast_spot := Vector3.ZERO
var _feed := {}
var _growl: AudioStreamPlayer3D
var _screams: Array[AudioStreamPlayer3D] = []
var _end_scream: AudioStreamPlayer3D
var _charge_t := -1.0
var _hold_on := false
var _hold_i := 0
var _clock_vis := 0.0


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
		wade = WadeModifier.new()
		wade.creature = self
		skeleton.add_child(wade)
		wade.setup(skeleton)
		for i in skeleton.get_bone_count():
			if skeleton.get_bone_name(i).begins_with("head"):
				_head_bone = i
	_play_anim("idle standing")   # the model's rest pose is metres off; never show it
	_setup_audio()
	_setup_hitbox()
	_setup_wake()
	if Net.is_host() or not Net.is_online():
		NoiseBus.heard.connect(_on_heard)
	_idle = 1.0


## The crawling run leaves the hip bone at the model's odd rest position (metres away). Pin the
## hip to where the crawling idle holds it, so it runs in place. (The standing run is fine.)
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
		if not n.ends_with("|run"):
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
	voice.position = Vector3(0, 1.9, 0)
	add_child(voice)
	oneshot = AudioStreamPlayer3D.new()
	oneshot.stream = CHARGE_ONSET
	oneshot.unit_size = 8.0
	oneshot.max_db = 6.0
	oneshot.position = Vector3(0, 1.7, 0)
	add_child(oneshot)
	_bite_player = AudioStreamPlayer3D.new()
	_bite_player.unit_size = 6.0
	_bite_player.position = Vector3(0, 1.5, 0.6)
	add_child(_bite_player)
	for i in 3:                       # the charge screech's held takes, and its ending
		var a := AudioStreamPlayer3D.new()
		a.unit_size = 8.0
		a.max_db = 6.0
		a.position = Vector3(0, 1.7, 0)
		add_child(a)
		if i < 2:
			_screams.append(a)
		else:
			_end_scream = a
	_growl = AudioStreamPlayer3D.new()
	_growl.stream = FEED_GROWL
	_growl.unit_size = 4.0
	_growl.position = Vector3(0, 1.0, 0.5)
	add_child(_growl)


func _setup_hitbox() -> void:
	hitbox = Area3D.new()
	hitbox.add_to_group("creature")
	hitbox.collision_layer = LevelGeometry.L_CREATURE
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 2.2
	cs.shape = cap
	cs.position = Vector3(0, 1.1, 0)
	hitbox.add_child(cs)
	add_child(hitbox)


func _setup_wake() -> void:
	wake = CPUParticles3D.new()
	wake.local_coords = false
	wake.amount = 40
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
	if state == S.ATTACK or state == S.FEAST:
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
			if _state_time > ATTACK_TIME:
				_set_state(S.FEAST)
				_path = PackedVector3Array()
				_path_i = 0
				_feast_for = _rng.randf_range(FEAST_MIN, FEAST_MAX)
		S.FEAST:
			if _state_time > _feast_for:
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
	_update_presentation(delta)


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
	_y = lerpf(_y, floor_at(pos), clampf(delta * 3.0, 0.0, 1.0))
	global_position = Vector3(pos.x, _y, pos.z)
	if _kill.is_empty():
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
	var away := Vector3(global_position.x - at.x, 0, global_position.z - at.z)
	away = away.normalized() if away.length() > 0.05 else Vector3.BACK
	target = _nav_point(at + away * 1.15)   # an arm's length away, face to face
	_path = PackedVector3Array([target])
	_path_i = 0
	_search_rolls.clear()
	Game.level.player_caught(id, next_screech(), next_kill())


func _go_linger(center: Vector3) -> void:
	_linger_center = center
	_set_state(S.LINGER)
	_path = _nav_path(_ring_point(center, 3.0))
	_path_i = 0


func _go(new_state: int, p: Vector3) -> void:
	_set_state(new_state)
	target = p
	_path = _nav_path(p)
	_path_i = 0


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


## The pool floor under a point (the creature stands on it).
static func floor_at(p: Vector3) -> float:
	var w := WaterVolume.below(Vector3(p.x, -0.35, p.z))
	return w.floor_y if w else -0.95


func _depth() -> float:
	var w := WaterVolume.below(Vector3(global_position.x, -0.35, global_position.z))
	return w.depth() if w else 0.65


func _update_presentation(delta: float) -> void:
	if state != _shown_state:
		var old := _shown_state
		_shown_state = state
		match state:
			S.PATROL, S.LINGER:
				_quiet()
				_click_t = _rng.randf_range(4.0, 10.0)
			S.INVESTIGATE:
				_quiet()
				_click_t = _rng.randf_range(0.5, 2.0)
			S.CHARGE:
				_set_voice(VOICE_HUNT, -2.0)
				if old != S.CHARGE:
					_charge_start()
			S.SEARCH:
				_set_voice(VOICE_CLOSE, -3.0)
			S.ATTACK, S.FEAST:
				_quiet()
		if old == S.CHARGE and state != S.CHARGE:
			_charge_stop(state == S.ATTACK)
	_charge_tick(delta)
	# Wading: only a short burst of clicks now and then.
	if state in [S.PATROL, S.LINGER, S.INVESTIGATE]:
		_click_t -= delta
		if _click_t <= 0.0:
			var busy := state == S.INVESTIGATE
			_click_burst(-5.0 if busy else -9.0)
			_click_t = _rng.randf_range(3.0, 7.0) if busy else _rng.randf_range(9.0, 20.0)
	if _burst_left > 0.0:
		_burst_left -= delta
		if _burst_left <= 0.0:
			var tw := create_tween()
			tw.tween_property(voice, "volume_db", -40.0, 0.25)
			tw.tween_callback(voice.stop)
	# Movement and animation.
	var moved := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length()
	_last_pos = global_position
	if moved > 2.0:
		moved = 0.0   # teleported
	# Upright (the wade modifier poses the whole body) unless it's running, searching with its own
	# animation, or crawling in the deep.
	var a := "idle standing"
	var upright := 1.0
	if not _kill.is_empty():
		_kill_tick(delta)
		a = _kill.get("anim", "standing run")
		upright = float(_kill.get("stance", 1.0))
	elif _depth() > DEEP:
		a = "run" if _speed_now > 2.5 else ("walk" if _speed_now > 0.2 else "idle")
		upright = 0.0
	elif state == S.SEARCH:
		a = "search"
		upright = 0.0
	elif _speed_now > 2.5:
		a = "standing run"
		upright = 0.0
	_play_anim(a)
	if anim:
		anim.speed_scale = clampf(_speed_now / 6.0, 0.7, 1.4) if a == "standing run" else 1.0
	if wade:
		wade.stance = move_toward(wade.stance, upright, delta * 3.0)
		var want: float = clampf(_speed_now / 0.6, 0.0, 1.0) if upright > 0.5 and _kill.is_empty() else 0.0
		wade.amount = lerpf(wade.amount, want, clampf(delta * 4.0, 0.0, 1.0))
		wade.phase += moved / wade.stride * PI
		# Scanning slowly as it wades; looking where it's going when it hunts.
		var scan := sin(_clock_vis * 0.37) * 0.45 + sin(_clock_vis * 0.13 + 1.0) * 0.25
		wade.look = lerpf(wade.look, scan if state in [S.PATROL, S.LINGER] else 0.0, clampf(delta * 2.0, 0.0, 1.0))
	_clock_vis += delta
	_feed_tick(delta)
	var wading := _depth() <= DEEP and _speed_now > 0.25
	wake.emitting = wading
	wake.amount = 40
	wake.global_position = Vector3(global_position.x, -0.28, global_position.z) + global_transform.basis.z * 0.3


func _quiet() -> void:
	_burst_left = 0.0
	voice.stop()


func _click_burst(db: float) -> void:
	voice.stream = VOICE_HUNT
	voice.volume_db = db
	var length: float = (VOICE_HUNT as AudioStream).get_length()
	voice.play(_rng.randf() * maxf(length - 3.0, 0.0))
	_burst_left = _rng.randf_range(0.9, 2.2)


func _set_voice(stream: AudioStream, db: float) -> void:
	_burst_left = 0.0
	if voice.stream != stream or not voice.playing:
		voice.stream = stream
		voice.play()
	voice.volume_db = db


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


# --- The kill (everyone plays it) ----------------------------------------------------------------

## A different death screech each time: never the same one twice in a row. The host picks it so
## everyone hears the same.
func next_screech() -> int:
	var v := _rng.randi() % KILL_SCREECHES.size()
	if v == _last_screech:
		v = (v + 1 + _rng.randi() % (KILL_SCREECHES.size() - 1)) % KILL_SCREECHES.size()
	_last_screech = v
	return v


## The three kills (the host picks one; everyone plays it):
##   HEAD_RIP: one hand on the shoulder, the other on the head. The neck tears and the head comes
##             away, but the spine is stuck in the body: it tugs, three times, bones cracking, until
##             the spine rips out with the head. It lifts the head to its face, bites it, throws it.
##   HALVES:   it lifts them with both hands and tears them apart at the waist; the gut stretches
##             between the halves and the organs spill; it drops the legs and throws the rest.
##   SPLIT:    it lifts them by the shoulders and pulls them apart down the middle: the head splits
##             first and the tear runs down to the crotch in jerks, then the halves come apart with
##             the organs spilling between them.
## The torn pieces are built while it closes in (hidden, one per frame) and take the victim's exact
## pose when they swap in, so the tear itself costs nothing and nothing jumps.
enum K { HEAD_RIP, HALVES, SPLIT }
const NECK_AT := 1.25        # head and spine: the neck tears (the victim's view goes black here)
const SPINE_OUT := 2.35      # ...and the stuck spine finally rips out
const TUGS := [0.3, 0.62, 0.92]          # after the neck tears: tugs on the stuck spine
const TEAR_AT := 1.4         # torn in half at the waist (the victim's view cuts to black)
const SPLIT_AT := 1.15       # split down the middle: the head splits (the victim's view cuts to black)
const SPLIT_OPEN := 2.2      # ...and the halves come apart
const SPLIT_TUGS := [0.12, 0.45, 0.78]   # after the head splits: the tear running down, in jerks
const HOLD_AHEAD := 1.0      # how far in front of it the victim is held (its arms reach about this far)
## Which suit parts make each piece: [variant, parts shown].
const PIECES := {"head": ["", ["head"]], "body": ["", ["upper", "lower"]], "upper": ["", ["head", "upper"]],
	"lower": ["", ["lower"]], "left": ["lr", ["left"]], "right": ["lr", ["right"]]}
const PLAN := {K.HEAD_RIP: ["head", "body"], K.HALVES: ["upper", "lower"], K.SPLIT: ["left", "right"]}


## When the victim's own view goes black, for player.gd.
static func cut_time(kind: int) -> float:
	match kind:
		K.HEAD_RIP:
			return NECK_AT
		K.SPLIT:
			return SPLIT_AT
	return TEAR_AT


func next_kill() -> int:
	var k := _rng.randi() % 3
	if k == _last_kill:
		k = (k + 1 + _rng.randi() % 2) % 3
	_last_kill = k
	return k


func play_kill(victim: Node, screech: int, kind := 0) -> void:
	_last_screech = screech
	_quiet()
	_end_feed()
	if not _kill.is_empty():
		_end_kill()
	_kill = {"p": victim, "t": 0.0, "v": screech, "kind": kind, "stage": 0, "pos": victim.body_position(),
		"anim": "standing run", "stance": 0.0, "held": [], "pull": 0.0, "pieces": {}, "token": _rng.randi()}
	_prepare_pieces(_kill)


## Build the torn pieces ahead of time, hidden and asleep, one per frame.
func _prepare_pieces(k: Dictionary) -> void:
	for nm in PLAN[int(k.kind)]:
		await get_tree().process_frame
		if _kill.get("token") != k.token:
			return          # that kill is over
		k.pieces[nm] = _new_piece(nm)
	if int(k.kind) != K.HEAD_RIP:
		await get_tree().process_frame
		if _kill.get("token") == k.token:
			k.organs = Gore.organs()


func _new_piece(nm: String) -> SuitRig:
	var p = _kill.get("p")
	var info: Dictionary = p.info if is_instance_valid(p) else {}
	var spec: Array = PIECES[nm]
	var piece := SuitRig.create(int(info.get("suit", 0)), info.get("color", Color(0.9, 0.5, 0.2)), spec[0])
	piece.visible = false
	piece.process_mode = Node.PROCESS_MODE_DISABLED
	Game.level.add_child(piece)
	piece.show_only(spec[1])
	if info.get("dummy", false):
		piece.make_featureless()
	if nm == "head" or nm == "right":         # the spine: torn out with the head, or showing in the cut
		var spine := Gore.spine()
		piece.add_child(spine)
		spine.position = piece.bone_rest("Neck") + Vector3(0, -0.02, 0.02 if nm == "head" else 0.0)
	return piece


## Swap the victim's body for the torn pieces, in exactly the pose it's in now.
func _reveal(names: Array) -> Array[SuitRig]:
	var p = _kill.p
	var src: SuitRig = p.avatar.suit if is_instance_valid(p) and p.avatar else null
	var out: Array[SuitRig] = []
	for nm in names:
		var piece: SuitRig = _kill.pieces.get(nm)
		if not is_instance_valid(piece):
			piece = _new_piece(nm)
			_kill.pieces[nm] = piece
		if src:
			piece.global_transform = src.global_transform
			piece.head_target = src.head_target
			piece.hand_targets = src.hand_targets.duplicate()
		piece.process_mode = Node.PROCESS_MODE_INHERIT
		piece.visible = true
		out.append(piece)
	if is_instance_valid(p) and p.avatar:
		p.avatar.release()
	return out


## Hold a piece in a hand from where it is now (so it doesn't jump into the hand).
func _grip(piece: Node3D, hand: int) -> void:
	_kill.held.append({"node": piece, "hand": hand, "basis": piece.global_basis,
		"attach": piece.global_transform.affine_inverse() * _hand(hand)})


func mouth_position() -> Vector3:
	if skeleton and _head_bone >= 0:
		var h := skeleton.global_transform * skeleton.get_bone_global_pose(_head_bone).origin
		return h + global_transform.basis.z * 0.25
	return global_position + Vector3.UP * 1.9 + global_transform.basis.z * 0.5


## Where the victim's chest is held during the kill: up in front of its face (lifted), or standing
## and stretched upward as it pulls their head.
func hold_point() -> Vector3:
	return global_position + global_transform.basis.z * HOLD_AHEAD + Vector3.UP * float(_kill.get("hold_h", 1.3))


func victim_chest() -> Vector3:
	if int(_kill.get("kind", 0)) == K.HEAD_RIP:
		var v: Vector3 = _kill.pos
		return Vector3(v.x, floor_at(v), v.z) + Vector3.UP * (1.25 + float(_kill.get("pull", 0.0)))
	return hold_point()


func _victim_head() -> Vector3:
	var p = _kill.p
	if is_instance_valid(p) and p.is_local and p.rig:
		return p.rig.head_transform().origin
	return victim_chest() + Vector3.UP * 0.45


func _hand(i: int) -> Vector3:
	return wade.debug_hands[i] if wade else hold_point()


func _kill_tick(delta: float) -> void:
	_kill.t += delta
	var t: float = _kill.t
	var vpos: Vector3 = _kill.pos
	var to := Vector3(vpos.x - global_position.x, 0, vpos.z - global_position.z)
	if to.length() > 0.1 and int(_kill.stage) < 2:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), clampf(delta * 10.0, 0.0, 1.0))
		_yaw = rotation.y
	if int(_kill.stage) == 0 and t >= KILL_GRAB and (to.length() < 2.2 or t > 1.0):
		_grab()
	if int(_kill.stage) >= 1:
		match int(_kill.kind):
			K.HEAD_RIP:
				_head_rip_tick(t, delta)
			K.SPLIT:
				_split_tick(t, delta)
			_:
				_halves_tick(t, delta)
	var bleed = _kill.get("bleed")
	if bleed and is_instance_valid(bleed) and _kill.get("bleed_at") is Callable:
		bleed.global_position = (_kill.bleed_at as Callable).call()
	for h in _kill.held:
		_carry(h)
	if wade:
		var holding: bool = _kill.get("holding", false)
		wade.hold = lerpf(wade.hold, 1.0 if holding else 0.0, clampf(delta * 8.0, 0.0, 1.0))
		wade.hold_point = hold_point()
	if t >= ATTACK_TIME:
		_end_kill()


func _grab() -> void:
	var p = _kill.p
	_kill.stage = 1
	_kill.grab_t = _kill.t
	_kill.anim = "idle standing"
	_kill.stance = 1.0
	_kill.holding = true
	oneshot.stream = KILL_SCREECHES[int(_kill.v) % KILL_SCREECHES.size()]
	oneshot.play()
	if is_instance_valid(p) and p.avatar:
		p.avatar.seize(self)


## Plays once when the kill clock passes `at` (each name only once).
func _once(name: String, at: float) -> bool:
	if float(_kill.t) >= at and not _kill.has("did_" + name):
		_kill["did_" + name] = true
		return true
	return false


func _head_rip_tick(t: float, delta: float) -> void:
	var level: Node = Game.level
	var stage: int = _kill.stage
	var since: float = t - float(_kill.grab_t)
	var side := global_transform.basis.x.normalized()
	if stage == 1:
		# Pulling: the head goes up, the body stretches onto its toes, the neck strains.
		_kill.pull = clampf(since / (NECK_AT - KILL_GRAB), 0.0, 1.0) * 0.3
		wade.hand_goals = [victim_chest() + side * 0.18 + Vector3.UP * 0.1, _victim_head() + Vector3.UP * 0.08]
		wade.bite = lerpf(wade.bite, 0.1, clampf(delta * 4.0, 0.0, 1.0))
		if _once("strain", 0.75):
			_tear_sound(KILL_STRAIN)
		if since > 0.4 and not _kill.has("bleed"):
			_kill.bleed = Gore.bleed(level)
			_kill.bleed_at = func(): return victim_chest() + Vector3.UP * 0.32
		if t >= NECK_AT:
			_neck_tear()
	elif stage == 2:
		# The head is off but the spine is stuck in the body: it tugs, the body jerks with it.
		var body: SuitRig = _kill.body
		var head: SuitRig = _kill.head
		var since_neck := t - NECK_AT
		# The gap opens to a hand's width at once, then each tug drags a little more spine out.
		var gap := 0.16 * smoothstep(0.0, 0.15, since_neck)
		var jolt := 0.0
		for i in TUGS.size():
			gap += 0.06 * smoothstep(TUGS[i], TUGS[i] + 0.1, since_neck)
			var k: float = (since_neck - TUGS[i]) / 0.22
			if k > 0.0 and k < 1.0:
				gap += sin(PI * k) * 0.06
				jolt = sin(PI * k)
			if _once("tug%d" % i, NECK_AT + TUGS[i]):
				_tear_sound(KILL_CRACKS[i % KILL_CRACKS.size()])
				Gore.spray(level, body.bone_world("Neck") + body.global_basis.y * gap * 0.5, Vector3.UP, 40, false)
		if _once("strain2", NECK_AT + 0.15):
			_tear_sound(KILL_STRAIN)
		var shake := Vector3(sin(t * 47.0), 0, cos(t * 41.0)) * 0.01
		if is_instance_valid(body) and is_instance_valid(head):
			var up := body.global_basis.y
			body.global_position = (_kill.body_at as Vector3) + up * jolt * 0.05
			head.global_transform = Transform3D(body.global_basis, body.global_position + up * gap + shake)
			wade.hand_goals = [body.bone_world("RightArm") + Vector3.UP * jolt * 0.05, head.bone_world("Head")]
		if t >= SPINE_OUT:
			_spine_out()
	elif stage == 3:
		# The head, spine dangling, up to its face; bite it; throw it.
		var head: SuitRig = _kill.head
		var k := clampf((t - SPINE_OUT) / 0.25, 0.0, 1.0)
		var face := mouth_position() + global_transform.basis.z * 0.25 + Vector3.DOWN * 0.1
		var start: Vector3 = _kill.rip_from
		var flung := start + Vector3.UP * 0.7 + global_transform.basis.z * -0.1
		var goal := start.lerp(flung, sin(k * PI * 0.5))
		if t > SPINE_OUT + 0.25:
			goal = flung.lerp(face, clampf((t - SPINE_OUT - 0.25) / 0.5, 0.0, 1.0))
		wade.hand_goals = [global_position + global_transform.basis.z * 0.5 + side * 0.4 + Vector3.UP * 1.0, goal]
		if is_instance_valid(head) and not _kill.get("head_held", false):
			head.global_transform = Transform3D(head.global_basis, goal - head.global_basis * head.bone_rest("Head"))
			if t > SPINE_OUT + 0.25:
				_kill.head_held = true
				_grip(head, 1)
		wade.bite = lerpf(wade.bite, 1.0 if t > SPINE_OUT + 0.85 else 0.3, clampf(delta * 5.0, 0.0, 1.0))
		if _once("bite", SPINE_OUT + 1.0):
			_bite(1)
			Gore.spray(level, _hand(1), Vector3.UP, 120)
		if t > SPINE_OUT + 1.5:
			_throw(head, global_transform.basis.z * 2.2 + side * 1.2 + Vector3.UP * 2.0)
			_kill.stage = 4
			_kill.holding = false
			wade.hand_goals = [null, null]


func _neck_tear() -> void:
	var level: Node = Game.level
	_kill.stage = 2
	var got := _reveal(["head", "body"])
	_kill.head = got[0]
	_kill.body = got[1]
	_kill.body_at = got[1].global_position
	_tear_sound(KILL_NECK)
	Gore.spray(level, got[1].bone_world("Neck"), Vector3.UP, 140, false)
	var bleed = _kill.get("bleed")
	if bleed and is_instance_valid(bleed):
		_kill.bleed_at = func(): return (_kill.body as SuitRig).bone_world("Neck") if is_instance_valid(_kill.get("body")) else hold_point()


func _spine_out() -> void:
	var level: Node = Game.level
	_kill.stage = 3
	var body: SuitRig = _kill.body
	var head: SuitRig = _kill.head
	_kill.rip_from = head.bone_world("Head") if is_instance_valid(head) else _hand(1)
	_tear_sound(KILL_SPINE)
	if is_instance_valid(body):
		var neck := body.bone_world("Neck")
		var fountain := Gore.fountain(level, 3.5)
		fountain.global_position = neck
		var follow := _Follow.new()
		follow.target = body
		follow.role = "Neck"
		fountain.add_child(follow)
		Gore.spray(level, neck + Vector3.UP * 0.2, Vector3.UP, 160)
		Gore.drop(body, -0.3, -global_transform.basis.z * 0.8)
		Gore.blood_pool(level, neck, -0.3, 5.0)
	var bleed = _kill.get("bleed")
	if bleed and is_instance_valid(bleed):
		_kill.bleed_at = func(): return _hand(1) + Vector3.DOWN * 0.3


func _halves_tick(t: float, delta: float) -> void:
	var level: Node = Game.level
	var stage: int = _kill.stage
	var since: float = t - float(_kill.grab_t)
	var side := global_transform.basis.x.normalized()
	_kill.hold_h = lerpf(1.3, 1.75, clampf(since / 0.3, 0.0, 1.0))
	if stage == 1:
		wade.hand_goals = [null, null]
		wade.bite = lerpf(wade.bite, 0.15, clampf(delta * 4.0, 0.0, 1.0))
		if _once("strain", 0.85):
			_tear_sound(KILL_STRAIN)
		if not _kill.has("bleed"):
			_kill.bleed = Gore.bleed(level)
			_kill.bleed_at = func(): return hold_point() + Vector3.DOWN * 0.2
		if t >= TEAR_AT:
			_tear()
	elif stage >= 2:
		var k := clampf((t - TEAR_AT) / 0.3, 0.0, 1.0)
		var hp := hold_point()
		var up_goal := hp + (Vector3.UP * 0.35 + side * 0.25) * k + side * 0.2
		var low_goal := hp + (Vector3.DOWN * 0.5 - side * 0.25) * k - side * 0.2
		if stage >= 3:   # legs dropped; hold the rest up to its face
			up_goal = up_goal.lerp(mouth_position() + global_transform.basis.z * 0.45 + Vector3.DOWN * 0.3, clampf((t - TEAR_AT - 0.6) / 0.6, 0.0, 1.0))
			low_goal = global_position + global_transform.basis.z * 0.4 - side * 0.4 + Vector3.UP * 1.0
		wade.hand_goals = [up_goal, low_goal]
		if stage == 2 and t > TEAR_AT + 0.6:
			_kill.stage = 3
			_release_held(_kill.lower, Vector3.DOWN * 0.5)
		if stage == 3 and t > TEAR_AT + 1.9:
			_kill.stage = 4
			_throw(_kill.upper, global_transform.basis.z * 2.0 - side * 1.0 + Vector3.UP * 1.6)
			_kill.holding = false
			wade.hand_goals = [null, null]


func _tear() -> void:
	var level: Node = Game.level
	_kill.stage = 2
	_tear_sound(KILL_TEAR)
	var got := _reveal(["upper", "lower"])
	var upper: SuitRig = got[0]
	var lower: SuitRig = got[1]
	_kill.upper = upper
	_kill.lower = lower
	_grip(upper, 0)
	_grip(lower, 1)
	# The gut between the two halves, and everything else falling out.
	var top := Node3D.new()
	upper.add_child(top)
	top.position = upper.bone_rest("Spine1")
	var bottom := Node3D.new()
	lower.add_child(bottom)
	bottom.position = lower.bone_rest("Spine1")
	var surface := -0.3
	Gore.gut(level, top, bottom, 1.9)
	Gore.gut(level, top, bottom, 1.4)
	Gore.spill(level, top.global_position, surface, Vector3.DOWN * 0.5 + global_transform.basis.z * 0.4, _kill.get("organs", []))
	Gore.spray(level, top.global_position, Vector3.UP + global_transform.basis.z * 0.5, 180)
	Gore.spray(level, bottom.global_position, Vector3.DOWN, 120)
	Gore.blood_pool(level, hold_point(), -0.3, 6.0)
	var f1 := Gore.fountain(level, 3.0)
	var fl := _Follow.new()
	fl.target = upper
	fl.role = "Spine1"
	f1.add_child(fl)
	f1.direction = Vector3.DOWN
	var bleed = _kill.get("bleed")
	if bleed and is_instance_valid(bleed):
		_kill.bleed_at = func(): return top.global_position + Vector3.DOWN * 0.1


func _split_tick(t: float, delta: float) -> void:
	var level: Node = Game.level
	var stage: int = _kill.stage
	var since: float = t - float(_kill.grab_t)
	var side := global_transform.basis.x.normalized()
	_kill.hold_h = lerpf(1.3, 1.7, clampf(since / 0.35, 0.0, 1.0))
	if stage == 1:
		# Lifted by the shoulders (its left hand on their right shoulder, and the other way round).
		var hp := hold_point()
		wade.hand_goals = [hp + side * 0.2 + Vector3.UP * 0.15, hp - side * 0.2 + Vector3.UP * 0.15]
		wade.bite = lerpf(wade.bite, 0.1, clampf(delta * 4.0, 0.0, 1.0))
		if _once("strain", 0.7):
			_tear_sound(KILL_STRAIN)
		if t >= SPLIT_AT:
			_split_start()
	elif stage == 2:
		# Tearing down the middle in jerks: each half hinges outward at the crotch.
		var since_split := t - SPLIT_AT
		var ang := 0.04
		for i in SPLIT_TUGS.size():
			ang += 0.075 * smoothstep(SPLIT_TUGS[i], SPLIT_TUGS[i] + 0.12, since_split)
			if _once("stug%d" % i, SPLIT_AT + SPLIT_TUGS[i]):
				_tear_sound(KILL_CRACKS[i % KILL_CRACKS.size()])
				var mid := _split_mid(0.55 - 0.25 * i)
				Gore.spray(level, mid, -global_transform.basis.z + Vector3.UP * 0.5, 70, false)
		_pose_split(ang, 0.0)
		if t >= SPLIT_OPEN:
			_split_open()
	elif stage >= 3:
		# Apart: one half in each hand, held up; then it drops one and brings the other to its face.
		var k := clampf((t - SPLIT_OPEN) / 0.3, 0.0, 1.0)
		var hp := hold_point()
		var lgoal := hp + side * (0.25 + 0.35 * k) + Vector3.UP * 0.2 * k
		var rgoal := hp - side * (0.25 + 0.35 * k) + Vector3.UP * 0.2 * k
		if stage >= 4:
			rgoal = rgoal.lerp(mouth_position() + global_transform.basis.z * 0.45 + Vector3.DOWN * 0.25, clampf((t - SPLIT_OPEN - 0.7) / 0.6, 0.0, 1.0))
			lgoal = global_position + global_transform.basis.z * 0.4 + side * 0.4 + Vector3.UP * 1.0
		wade.hand_goals = [lgoal, rgoal]
		if stage == 3 and t > SPLIT_OPEN + 0.7:
			_kill.stage = 4
			_release_held(_kill.right, Vector3.DOWN * 0.4 + side * 0.3)
		if stage == 4 and _once("sbite", SPLIT_OPEN + 1.4):
			_bite(0)
			Gore.spray(level, _hand(1), Vector3.UP, 100)
		if stage == 4 and t > SPLIT_OPEN + 2.0:
			_kill.stage = 5
			_throw(_kill.left, global_transform.basis.z * 2.0 + side * 0.8 + Vector3.UP * 1.6)
			_kill.holding = false
			wade.hand_goals = [null, null]


## A point on the tear between the halves, `k` of the way from the crotch (0) to the head (1).
func _split_mid(k: float) -> Vector3:
	var l: SuitRig = _kill.left
	var r: SuitRig = _kill.right
	if not (is_instance_valid(l) and is_instance_valid(r)):
		return hold_point()
	var lo := (l.bone_world("Hips") + r.bone_world("Hips")) * 0.5
	var hi := (l.bone_world("Head") + r.bone_world("Head")) * 0.5
	return lo.lerp(hi, clampf(k, 0.0, 1.0))


func _split_start() -> void:
	var level: Node = Game.level
	_kill.stage = 2
	var got := _reveal(["left", "right"])
	_kill.left = got[0]
	_kill.right = got[1]
	_kill.split_base = got[0].global_transform
	_kill.split_pivot = got[0].bone_rest("Hips")
	_kill.split_hp = hold_point()
	_tear_sound(KILL_SPLIT)
	Gore.spray(level, got[0].bone_world("Head") + Vector3.UP * 0.05, Vector3.UP, 120, false)
	_kill.bleed = Gore.bleed(level)
	_kill.bleed_at = func(): return _split_mid(0.4)


## Both halves where they were taken over, following the hold, each turned outward by `ang` about
## the crotch (the victim's forward axis) and pushed apart by `apart` metres.
func _pose_split(ang: float, apart: float) -> void:
	var base: Transform3D = _kill.split_base
	base.origin += hold_point() - (_kill.split_hp as Vector3)
	var pivot: Vector3 = _kill.split_pivot
	for i in 2:
		var half: SuitRig = _kill.left if i == 0 else _kill.right
		if not is_instance_valid(half):
			continue
		var s := 1.0 if i == 0 else -1.0        # left half: its own -X is outward
		var hinge := Transform3D(Basis(Vector3.BACK, s * ang), Vector3.ZERO)
		var local := Transform3D(Basis(), pivot) * hinge * Transform3D(Basis(), -pivot)
		local.origin += Vector3(-s * apart, 0, 0)
		half.global_transform = base * local
	var l: SuitRig = _kill.left
	var r: SuitRig = _kill.right
	if is_instance_valid(l) and is_instance_valid(r):
		wade.hand_goals = [r.bone_world("RightArm"), l.bone_world("LeftArm")]


func _split_open() -> void:
	var level: Node = Game.level
	_kill.stage = 3
	_pose_split(0.3, 0.05)
	var l: SuitRig = _kill.left
	var r: SuitRig = _kill.right
	_tear_sound(KILL_TEAR)
	_grip(r, 0)
	_grip(l, 1)
	var mid := _split_mid(0.5)
	var a := Node3D.new()
	l.add_child(a)
	a.position = l.bone_rest("Spine1")
	var b := Node3D.new()
	r.add_child(b)
	b.position = r.bone_rest("Spine1")
	Gore.gut(level, a, b, 1.2)
	var a2 := Node3D.new()
	l.add_child(a2)
	a2.position = l.bone_rest("Spine2")
	var b2 := Node3D.new()
	r.add_child(b2)
	b2.position = r.bone_rest("Spine")
	Gore.gut(level, a2, b2, 1.6)
	Gore.spill(level, mid, -0.3, Vector3.DOWN * 0.6 - global_transform.basis.z * 0.3, _kill.get("organs", []))
	Gore.spray(level, mid, Vector3.UP, 180)
	Gore.spray(level, mid, -global_transform.basis.z, 120)
	Gore.blood_pool(level, mid, -0.3, 6.0)
	for half in [l, r]:
		var f := Gore.fountain(level, 3.0)
		var fl := _Follow.new()
		fl.target = half
		fl.role = "Spine1"
		f.add_child(fl)
		f.direction = Vector3.DOWN
	_kill.bleed_at = func(): return _hand(1) + Vector3.DOWN * 0.3


func _tear_sound(stream: AudioStream) -> void:
	var a := AudioStreamPlayer3D.new()
	a.stream = stream
	a.unit_size = 7.0
	a.max_db = 6.0
	add_child(a)
	a.global_position = hold_point()
	a.play()
	a.finished.connect(a.queue_free)


## Keep a torn-off piece in a hand, held by one of its bones, and out of the walls.
func _carry(h: Dictionary) -> void:
	var n: Node3D = h.node
	if not is_instance_valid(n):
		return
	var b: Basis = h.basis
	var wobble := Basis(global_transform.basis.x.normalized(), sin(_kill.t * 9.0) * 0.12)
	b = wobble * b
	n.global_transform = Transform3D(b, _hand(int(h.hand)) - b * (h.attach as Vector3))
	Gore.keep_out(n, global_position + Vector3.UP * 1.5)


func _release_held(n: Node3D, vel: Vector3) -> void:
	for h in _kill.held.duplicate():
		if h.node == n:
			_kill.held.erase(h)
	if is_instance_valid(n):
		Gore.drop(n, -0.3, vel)


func _throw(n: Node3D, vel: Vector3) -> void:
	_bite_player.stream = SPLASH
	_bite_player.pitch_scale = 1.0
	get_tree().create_timer(0.6).timeout.connect(_bite_player.play)
	var level: Node = Game.level
	_release_held(n, vel)
	var bleed = _kill.get("bleed")
	if bleed and is_instance_valid(bleed):
		bleed.emitting = false
	if is_instance_valid(n):
		get_tree().create_timer(0.7).timeout.connect(func():
			if is_instance_valid(n):
				Gore.blood_pool(level, n.global_position, -0.3)
				Gore.remains(level, n.global_position + Vector3.UP * 0.2, -0.3, SuitRig.glove_color(n.suit), 4))


func _end_kill() -> void:
	for h in _kill.get("held", []):
		if is_instance_valid(h.node):
			Gore.drop(h.node, -0.3)
	for piece in _kill.get("pieces", {}).values():   # pieces built but never used
		if is_instance_valid(piece) and not piece.visible:
			piece.queue_free()
	var bleed = _kill.get("bleed")
	if bleed and is_instance_valid(bleed):
		bleed.queue_free()
	if _kill.has("pos"):
		_feast_spot = _kill.pos
	_kill = {}
	if wade:
		wade.hold = 0.0
		wade.bite = 0.0
		wade.hand_goals = [null, null]


## Keeps a particle emitter on a bone of a torn-off piece.
class _Follow extends Node:
	var target: SuitRig
	var role := "Neck"

	func _process(_delta: float) -> void:
		if is_instance_valid(target) and get_parent() is Node3D:
			(get_parent() as Node3D).global_position = target.bone_world(role)


# --- Feeding (everyone) --------------------------------------------------------------------------
# Crouched over the remains: it reaches into the water, comes up with a piece, tears at it twice,
# chews and swallows, and goes back for more, growling low the whole time.

func _feed_tick(delta: float) -> void:
	var feeding := state == S.FEAST and _kill.is_empty()
	if not feeding:
		if wade:
			wade.feed = move_toward(wade.feed, 0.0, delta / 0.6)
			wade.feed_reach = move_toward(wade.feed_reach, 0.0, delta * 2.0)
			wade.feed_tear = 0.0
		if not _feed.is_empty():
			_end_feed()
		return
	if _feed.is_empty():
		_feed = {"t": 0.0, "c": 0.0, "len": _rng.randf_range(3.3, 4.2), "step": 0}
		_growl.volume_db = -40.0
		_growl.play(_rng.randf() * 2.0)
		create_tween().tween_property(_growl, "volume_db", -8.0, 1.0)
		var drip := Gore.bleed(Game.level)
		drip.amount = 20
		_feed.drip = drip
	_feed.t += delta
	if _feast_spot != Vector3.ZERO:
		var to := Vector3(_feast_spot.x - global_position.x, 0, _feast_spot.z - global_position.z)
		if to.length() > 0.2:
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), clampf(delta * 3.0, 0.0, 1.0))
			_yaw = rotation.y
	var fwd := global_transform.basis.z
	wade.feed = move_toward(wade.feed, 1.0, delta / 0.8)
	wade.feed_point = Vector3(global_position.x, -0.5, global_position.z) + fwd * 0.75 - global_transform.basis.x * 0.15
	if is_instance_valid(_feed.get("drip")):
		(_feed.drip as Node3D).global_position = mouth_position() + Vector3.DOWN * 0.1
	var piece: Node3D = _feed.get("piece")
	if is_instance_valid(piece):
		piece.global_position = _hand(1) + global_transform.basis.z * 0.05
	if _feed.t < 0.8:
		wade.feed_reach = 0.0
		return
	_feed.c += delta
	var c: float = _feed.c
	var cycle: float = _feed.len
	if c < 0.7:
		wade.feed_reach = smoothstep(0.0, 0.7, c)
	elif c < 0.95:
		wade.feed_reach = 1.0
	elif c < 1.6:
		wade.feed_reach = 1.0 - smoothstep(0.95, 1.6, c)
	else:
		wade.feed_reach = 0.0
	var tear := 0.0
	for at in [1.7, 2.15]:
		var k: float = (c - at) / 0.32
		if k > 0.0 and k < 1.0:
			tear = sin(PI * k)
	if c > 2.5 and c < cycle - 0.4:
		tear = 0.15 * sin((c - 2.5) * 14.0)            # chewing
	wade.feed_tear = tear
	var step: int = _feed.step
	if step == 0 and c >= 0.5:
		_feed_sound(SPLASH_SMALL, -6.0)
		_feed.step = 1
	elif step == 1 and c >= 0.75:
		var bits := Gore.organs()                        # comes up with a piece of them
		var keep: Node3D = bits[_rng.randi() % bits.size()]
		for o in bits:
			if o != keep:
				o.queue_free()
		Game.level.add_child(keep)
		keep.scale = Vector3.ONE * 0.8
		_feed.piece = keep
		_feed.step = 2
	elif step == 2 and c >= 1.7:
		_feed_sound(FEED_TEARS[_rng.randi() % FEED_TEARS.size()], 0.0)
		Gore.spray(Game.level, mouth_position(), Vector3.UP + fwd, 40)
		_feed.step = 3
	elif step == 3 and c >= 2.15:
		_feed_sound(FEED_CRUNCH[_rng.randi() % FEED_CRUNCH.size()], 0.0)
		if is_instance_valid(piece):
			piece.scale *= 0.6
		_feed.step = 4
	elif step == 4 and c >= 2.5:
		_feed_sound(FEED_CHEW[_rng.randi() % FEED_CHEW.size()], -2.0)
		_feed.step = 5
	elif step == 5 and c >= cycle - 0.4:
		_feed_sound(FEED_GULP, -3.0)
		if is_instance_valid(piece):
			piece.queue_free()
		_feed.piece = null
		_feed.step = 6
	if c >= cycle:
		_feed.c = 0.0
		_feed.len = _rng.randf_range(3.3, 4.2)
		_feed.step = 0


func _feed_sound(stream: AudioStream, db: float) -> void:
	var a := AudioStreamPlayer3D.new()
	a.stream = stream
	a.unit_size = 6.0
	a.volume_db = db
	a.pitch_scale = _rng.randf_range(0.9, 1.08)
	add_child(a)
	a.global_position = mouth_position()
	a.play()
	a.finished.connect(a.queue_free)


func _end_feed() -> void:
	if _feed.is_empty():
		return
	if is_instance_valid(_feed.get("piece")):
		(_feed.piece as Node).queue_free()
	if is_instance_valid(_feed.get("drip")):
		(_feed.drip as Node).queue_free()
	if _growl and _growl.playing:
		var tw := create_tween()
		tw.tween_property(_growl, "volume_db", -40.0, 0.6)
		tw.tween_callback(_growl.stop)
	_feed = {}


# --- The charge screech --------------------------------------------------------------------------
# It screeches until it gets where it's going: the onset (clicks speeding into the scream), then the
# scream carried on (a long take that keeps changing, never a loop; a second take crossfades in if
# a charge ever runs that long), and the scream's own ending the moment it arrives.
const ONSET_HOLD_AT := 1.3     # where the onset's scream hands over to the held scream
const HOLD_LEN := 10.0

func _charge_start() -> void:
	_charge_t = 0.0
	_hold_on = false
	_hold_i = 0
	oneshot.stream = CHARGE_ONSET
	oneshot.volume_db = 0.0
	oneshot.play()


func _charge_tick(delta: float) -> void:
	if _charge_t < 0.0:
		return
	_charge_t += delta
	if not _hold_on and _charge_t >= ONSET_HOLD_AT:
		_hold_on = true
		_start_hold(_screams[0], CHARGE_HOLDS[0], 0.0, 0.04)
	elif _hold_on:
		var cur: AudioStreamPlayer3D = _screams[_hold_i]
		if cur.playing and cur.get_playback_position() > HOLD_LEN - 0.5:
			var nxt: AudioStreamPlayer3D = _screams[1 - _hold_i]
			_start_hold(nxt, CHARGE_HOLDS[1 - _hold_i], 0.4, 0.3)
			_fade_out(cur, 0.3)
			_hold_i = 1 - _hold_i


func _start_hold(p: AudioStreamPlayer3D, stream: AudioStream, from: float, fade: float) -> void:
	p.stream = stream
	p.volume_db = -40.0
	p.play(from)
	create_tween().tween_property(p, "volume_db", 0.0, fade)


func _fade_out(p: AudioStreamPlayer3D, secs: float) -> void:
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -40.0, secs)
	tw.tween_callback(p.stop)


## It got there. If it caught someone, the kill screech follows instead of the scream's ending.
func _charge_stop(caught: bool) -> void:
	if _charge_t < 0.0:
		return
	var early := not _hold_on
	var wait := maxf(ONSET_HOLD_AT - _charge_t, 0.0)
	_charge_t = -1.0
	for p in _screams:
		if p.playing:
			_fade_out(p, 0.1)
	if caught:
		return
	if early:       # still in the onset: let it reach the scream, then end it
		get_tree().create_timer(wait).timeout.connect(func():
			_end_scream.stream = CHARGE_END
			_end_scream.play())
	else:
		_end_scream.stream = CHARGE_END
		_end_scream.play()


func _bite(i: int) -> void:
	_bite_player.pitch_scale = 1.0
	_bite_player.stream = KILL_BITES[i % KILL_BITES.size()]
	_bite_player.play()


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
		if _kill.is_empty():
			_yaw = lerp_angle(_yaw, _net_yaw, clampf(delta * 12.0, 0.0, 1.0))
			rotation.y = _yaw
	_update_presentation(delta)


func snapshot() -> Array:
	return [global_position, _yaw, state, search_center]


func apply_snapshot(e: Array) -> void:
	_net_state(e[0], e[1], e[2], e[3], 0.0)
