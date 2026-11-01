extends Node
## Noise events. Anyone can make a noise; the host decides what the creature hears.
##
## Loudness guide (before distance): very quiet 0.03, quiet 0.08, medium 0.25, loud 0.5, a fall 0.8+.
## Noises in the water also draw ripple rings on the water for everyone.

## Host only: the creature listens to this.
signal heard(pos: Vector3, loudness: float, kind: String, peer: int)
## Everyone: a ripple ring to draw on the water.
signal ripple(pos: Vector3, strength: float)
## Local only: noise my own player made, for controller rumble.
signal my_noise(loudness: float)

## Machinery that masks noise near it: {pos: Vector3, radius: float, mask: float (0-1)}
var cover_zones: Array[Dictionary] = []


func make(pos: Vector3, loudness: float, kind: String, in_water := true) -> void:
	if loudness <= 0.0:
		return
	my_noise.emit(loudness)
	if Game.args.has("netdebug"):
		print("MAKE noise %s %.2f host=%s online=%s" % [kind, loudness, Net.is_host(), Net.is_online()])
	if Net.is_host() or not Net.is_online():
		_receive(pos, loudness, kind, in_water, Net.my_id())
	else:
		rpc_id(1, "_srv_noise", pos, loudness, kind, in_water)


## Host only: a noise made by someone who isn't a real peer (the test dummy).
func make_for(peer: int, pos: Vector3, loudness: float, kind: String, in_water := true) -> void:
	if Net.is_host() or not Net.is_online():
		_receive(pos, loudness, kind, in_water, peer)


@rpc("any_peer", "call_remote", "reliable")
func _srv_noise(pos: Vector3, loudness: float, kind: String, in_water: bool) -> void:
	if not Net.is_host():
		return
	_receive(pos, loudness, kind, in_water, multiplayer.get_remote_sender_id())


func _receive(pos: Vector3, loudness: float, kind: String, in_water: bool, peer: int) -> void:
	if Game.args.has("netdebug"):
		print("NOISE from %d: %s %.2f at %s" % [peer, kind, loudness, pos])
	var masked := loudness
	for z in cover_zones:
		if z.get("active", true) and pos.distance_to(z.pos) < z.radius:
			masked *= 1.0 - z.mask
	if in_water:
		var strength := clampf(loudness * 1.5, 0.15, 1.0)
		_show_ripple(pos, strength)
		Net.send(self, &"_show_ripple", [pos, strength])
	heard.emit(pos, masked, kind, peer)


@rpc("authority", "call_remote", "unreliable")
func _show_ripple(pos: Vector3, strength: float) -> void:
	ripple.emit(pos, strength)
