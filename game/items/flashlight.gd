extends NetItem
## The squeeze flashlight (the diver's torch, from the approved diver model). A dynamo light: every
## pull of the trigger (desktop: every click) gives it a burst of charge, and the charge drains in
## moments, so it only stays lit while you keep pumping, pulsing brighter with each squeeze and
## sagging between them. It whirs while you squeeze. It makes no noise the creature can hear.

const KICK := 0.38          # charge per squeeze
const DRAIN := 1.0          # charge lost per second (one squeeze lasts about a third of a second)
const Whir := preload("res://assets/audio/flashlight_whir.ogg")
const Click := preload("res://assets/audio/flashlight_click.ogg")

var charge := 0.0
var _flash := 0.0           # the spike right after a squeeze
var _pressed := false       # trigger is down (with some give, so a half-pull doesn't flicker)
var _light: SpotLight3D
var _lens_mat: StandardMaterial3D
var _whir: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D


func build() -> void:
	mass = 0.4
	var m := add_model("res://assets/props/flashlight.glb")
	add_shape_box(Vector3(0.05, 0.05, 0.2))
	_lens_mat = StandardMaterial3D.new()
	_lens_mat.albedo_color = Color(0.9, 0.9, 0.8)
	_lens_mat.emission_enabled = true
	_lens_mat.emission = Color(1.0, 0.92, 0.75)
	_lens_mat.emission_energy_multiplier = 0.0
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).begins_with("Lens"):
			mi.material_override = _lens_mat
	_light = SpotLight3D.new()
	_light.light_color = Color(1.0, 0.93, 0.78)
	_light.spot_range = 14.0
	_light.spot_angle = 24.0
	_light.spot_attenuation = 1.2
	_light.shadow_enabled = false
	_light.light_energy = 0.0
	_light.visible = false
	_light.position = Vector3(0, 0, -0.11)
	add_child(_light)
	var ws: AudioStreamOggVorbis = Whir
	ws.loop = true
	_whir = AudioStreamPlayer3D.new()
	_whir.stream = ws
	_whir.unit_size = 1.5
	_whir.volume_db = -40.0
	add_child(_whir)
	_click = AudioStreamPlayer3D.new()
	_click.stream = Click
	_click.unit_size = 1.5
	_click.volume_db = -10.0
	add_child(_click)


## Desktop: each click of the left mouse is one squeeze.
func use(pressed: bool) -> void:
	if pressed and desktop_holder:
		_squeeze()


func _squeeze() -> void:
	charge = minf(charge + KICK, 1.0)
	_flash = 1.0
	_click.pitch_scale = randf_range(0.9, 1.1)
	_click.play()


func item_tick(delta: float) -> void:
	if is_mine() and is_picked_up():
		# A squeeze is the trigger going down past most of its travel, after being let back out.
		var v := 0.0
		for g in [_grab_driver.primary, _grab_driver.secondary]:
			if g and g.controller:
				v = maxf(v, (g.controller as XRController3D).get_float("trigger"))
		if not _pressed and v > 0.7:
			_pressed = true
			_squeeze()
		elif _pressed and v < 0.35:
			_pressed = false
	if is_mine():
		charge = maxf(charge - DRAIN * delta, 0.0)
	_flash = maxf(_flash - delta * 6.0, 0.0)
	# Bright right after each squeeze, sagging until the next one.
	var b := clampf(charge * 0.75 + _flash * charge * 0.6, 0.0, 1.2)
	_light.visible = b > 0.03
	_light.light_energy = b * 3.0
	_lens_mat.emission_energy_multiplier = b * 4.0
	if charge > 0.03:
		if not _whir.playing:
			_whir.play(randf() * 1.5)
		_whir.volume_db = lerpf(-24.0, -6.0, charge)
		_whir.pitch_scale = lerpf(0.8, 1.15, charge)
	elif _whir.playing:
		_whir.stop()


func extra_state() -> Array:
	return [charge, _flash]


func apply_extra(e: Array) -> void:
	if e.size() >= 2:
		charge = e[0]
		_flash = maxf(_flash, e[1])
