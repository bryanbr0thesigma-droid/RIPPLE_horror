extends Node3D
## One player in the session. On its own peer it runs a rig (VR or desktop), makes noise and sends
## its pose to everyone. On other peers it shows an avatar that follows those updates.

const VRRig := preload("res://player/vr_rig.tscn")
const DesktopRig := preload("res://player/desktop_rig.gd")
const Avatar := preload("res://player/avatar.gd")
const WadeLoop := preload("res://assets/audio/wade_loop.ogg")

const CreatureScript := preload("res://creature/creature.gd")
var peer_id := 1
var info := {}
var is_local := false
var rig: Node3D = null
var avatar: Node3D = null

# Network pose (remote players, and what the host's creature reads).
var net_feet := Vector3.ZERO
var net_in_water := false
var net_alive := true

# Local noise state.
var _last_feet := Vector3.ZERO
var _fall_speed := 0.0
var _fall_window := 0.0
var _was_in_water := false
var _drip_timer := 0.0
var _wade_timer := 0.0
var _hand_timer := 0.0
var _last_hands_rel := [Vector3.ZERO, Vector3.ZERO]
var _hand_speed := [0.0, 0.0]
var _search_base := {}
var _search_cooldown := 0.0
var _send_timer := 0.0
var _zone_timer := 0.0
var _escaped_reported := false
var respawn_point := Vector3(4, 0.05, 5)
var alive := true
var in_water := false
var _wade_audio: AudioStreamPlayer3D


func setup() -> void:
	is_local = peer_id == Net.my_id()
	net_feet = global_position
	if is_local:
		if Game.vr_mode:
			rig = VRRig.instantiate()
		else:
			rig = DesktopRig.new()
		rig.name = "Rig"
		add_child(rig)
		rig.teleport(global_position)
		_last_feet = global_position
		respawn_point = global_position
		_wade_audio = AudioStreamPlayer3D.new()
		var wade: AudioStreamOggVorbis = WadeLoop
		wade.loop = true
		_wade_audio.stream = wade
		_wade_audio.volume_db = -80.0
		add_child(_wade_audio)
		_wade_audio.play()
		NoiseBus.my_noise.connect(_on_my_noise)
	else:
		avatar = Avatar.new()
		avatar.name = "Avatar"
		add_child(avatar)
		avatar.setup(info, peer_id)


func body_position() -> Vector3:
	if is_local and rig:
		return rig.feet_position()
	return net_feet


## What the host's creature needs to know about this player.
func is_in_water() -> bool:
	return in_water if is_local else net_in_water


func is_alive() -> bool:
	return alive if is_local else net_alive


func _physics_process(delta: float) -> void:
	if not is_local or not rig:
		return
	var feet: Vector3 = rig.feet_position()
	var vel := (feet - _last_feet) / maxf(delta, 0.0001)
	if (feet - _last_feet).length() > 3.0:   # teleported
		vel = Vector3.ZERO
	_last_feet = feet

	# Safety net: if anything ever drops you out of the map, back to the last checkpoint.
	if alive and feet.y < -8.0:
		rig.teleport(respawn_point)
		_last_feet = respawn_point
		Game.notify("You fell out of the map. Back to the last checkpoint.")
		return

	var pool := WaterVolume.below(feet + Vector3.UP * 0.05)
	in_water = alive and pool != null and feet.y < pool.surface_y - 0.05
	var surface := Vector3(feet.x, pool.surface_y if pool else feet.y, feet.z)

	# Falling in: how fast were we going down just before we hit the water?
	_fall_window -= delta
	if -vel.y > _fall_speed or _fall_window <= 0.0:
		_fall_speed = maxf(-vel.y, 0.0)
		_fall_window = 0.25
	if in_water and not _was_in_water:
		var loud := 0.04
		var kind := "enter"
		if _fall_speed > 3.0:
			loud = clampf(0.55 + (_fall_speed - 3.0) * 0.12, 0.55, 1.5)
			kind = "fall"
			Game.level.play_sfx("splash_big", surface)
		elif _fall_speed > 1.3:
			loud = 0.25
			Game.level.play_sfx("splash_small", surface)
		if _drip_timer > 0.0:
			loud += 0.2
		NoiseBus.make(surface, loud, kind)
	if _was_in_water and not in_water and alive:
		_drip_timer = 20.0
	_was_in_water = in_water
	_drip_timer = maxf(_drip_timer - delta, 0.0)

	# Wading.
	var hspeed := Vector2(vel.x, vel.z).length()
	_wade_timer -= delta
	if in_water and _wade_timer <= 0.0:
		_wade_timer = 0.25
		var loud := 0.0
		if hspeed > 1.6:
			loud = 0.35
		elif hspeed > 0.9:
			loud = 0.12
		elif hspeed > 0.35:
			loud = 0.04
		elif hspeed > 0.12:
			loud = 0.015
		if loud > 0.0:
			NoiseBus.make(surface, loud, "wade")
	_wade_audio.global_position = surface
	_wade_audio.volume_db = linear_to_db(clampf(hspeed / 2.0, 0.0001, 1.0)) - 4.0 if in_water else -80.0

	# Hands moving in the water. Only movement relative to the body counts, so walking doesn't.
	var hands_rel: Array = rig.hands_relative()
	var hands_world: Array = rig.hand_positions()
	var hands_in_water := [false, false]
	for i in 2:
		var hw: Vector3 = hands_world[i]
		var hp := WaterVolume.below(hw)
		hands_in_water[i] = hp != null and hw.y < hp.surface_y
		var v: float = (hands_rel[i] - _last_hands_rel[i]).length() / maxf(delta, 0.0001)
		_hand_speed[i] = lerpf(_hand_speed[i], v, 0.3)
		_last_hands_rel[i] = hands_rel[i]
	_hand_timer -= delta
	if _hand_timer <= 0.0:
		_hand_timer = 0.25
		for i in 2:
			if hands_in_water[i]:
				var loud := clampf((_hand_speed[i] - 0.15) * 0.22, 0.0, 0.3)
				if loud > 0.01:
					var hw: Vector3 = hands_world[i]
					NoiseBus.make(Vector3(hw.x, surface.y, hw.z), loud, "hands")

	# While the creature searches nearby, any movement at all gives you away.
	_search_cooldown -= delta
	var c = Game.level.creature
	var searching: bool = c and c.is_searching() and in_water and Vector2(feet.x - c.search_center.x, feet.z - c.search_center.z).length() < c.SEARCH_RADIUS
	if searching:
		var head: Vector3 = rig.head_transform().origin
		if _search_base.is_empty():
			_search_base = {"head": head, "feet": feet, "hands": hands_rel.duplicate()}
		else:
			var moved: bool = head.distance_to(_search_base.head) > 0.07 or Vector2(feet.x - _search_base.feet.x, feet.z - _search_base.feet.z).length() > 0.07
			for i in 2:
				if hands_in_water[i] and (hands_rel[i] as Vector3).distance_to(_search_base.hands[i]) > 0.07:
					moved = true
			if moved and _search_cooldown <= 0.0:
				_search_cooldown = 1.0
				NoiseBus.make(surface, 1.0, "search_move")
	else:
		_search_base = {}

	# Checkpoints and the exit.
	_zone_timer -= delta
	if _zone_timer <= 0.0:
		_zone_timer = 0.4
		var z: Dictionary = Game.level.zone_at(feet)
		if z.has("checkpoint") and alive:
			respawn_point = z.checkpoint
		var at_exit: bool = z.get("exit", false)
		if at_exit != _escaped_reported:
			_escaped_reported = at_exit
			Game.level.request("escaped", [at_exit])
			if at_exit:
				Game.notify("You reached the exit. Waiting for everyone else.")

	# Send my pose.
	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer = 1.0 / 30.0
		var hands_xf: Array = rig.hand_transforms()
		var flags := (1 if in_water else 0) | (2 if alive else 0)
		Net.send(self, &"_state", [rig.head_transform(), hands_xf[0], hands_xf[1], feet, flags])


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(head: Transform3D, lh: Transform3D, rh: Transform3D, feet: Vector3, flags: int) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	net_feet = feet
	net_in_water = (flags & 1) != 0
	net_alive = (flags & 2) != 0
	if avatar:
		avatar.set_target(head, lh, rh, feet, net_alive)


func _on_my_noise(loudness: float) -> void:
	if rig and rig.has_method("rumble"):
		rig.rumble(clampf(loudness, 0.0, 1.0))


## The creature got me. (Teammates see it on my avatar; the creature plays that part.)
## In my own view: when it pulls my head off, my vision blurs and then cuts to black; when it tears
## me in half, it cuts straight to black. Then back at the last checkpoint.
func on_caught(kind := 0) -> void:
	if not is_local or not alive:
		return
	alive = false
	in_water = false
	Game.notify("It got you.")
	rig.drop_all()
	rig.set_controls_enabled(false)
	var cam: Camera3D = rig.get("camera") if rig.get("camera") else rig.get("cam")
	var grab: float = 0.55
	var cut: float = CreatureScript.cut_time(kind)    # head and spine: blurs until the neck tears
	var tw := create_tween()
	if kind == 0:
		var blur := Gore.blur_overlay(cam)
		tw.tween_interval(grab)
		tw.tween_callback(func(): _on_my_noise(1.0))
		tw.tween_method(func(v: float): blur.material_override.set_shader_parameter("amount", v), 0.0, 1.0, cut - grab)
		tw.tween_callback(func():
			rig.set_fade(1.0)
			blur.queue_free())
	else:
		tw.tween_interval(grab)
		tw.tween_callback(func(): _on_my_noise(1.0))
		tw.tween_interval(cut - grab)
		tw.tween_callback(func(): rig.set_fade(1.0))
	tw.tween_interval(2.4)
	tw.tween_callback(func():
		rig.teleport(respawn_point)
		_last_feet = respawn_point
		_was_in_water = false
		_drip_timer = 0.0
		alive = true
		rig.set_controls_enabled(true))
	tw.tween_method(rig.set_fade, 1.0, 0.0, 0.8)


func receive_push(impulse: Vector3) -> void:
	if is_local and rig:
		rig.add_push(impulse)


@rpc("any_peer", "call_remote", "reliable")
func _pushed(impulse: Vector3) -> void:
	receive_push(impulse.limit_length(5.0))
