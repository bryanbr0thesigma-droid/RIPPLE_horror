extends Node3D
## The title screen: a dark pool hall with the creature slowly wading round the shallow pool, the
## RIPPLE title, your character on a pedestal, and the menu. In VR you point at the menu with the
## right controller; on desktop the menu sits on the left of the screen.

const MenuPanel := preload("res://ui/menu_panel.tscn")
const Viewport2DIn3D := preload("res://addons/godot-xr-tools/objects/viewport_2d_in_3d.tscn")
const Pointer := preload("res://addons/godot-xr-tools/functions/function_pointer.tscn")
const LeftGlove := preload("res://addons/godot-xr-tools/hands/scenes/lowpoly/left_fullglove_low.tscn")
const RightGlove := preload("res://addons/godot-xr-tools/hands/scenes/lowpoly/right_fullglove_low.tscn")
const CreatureModel := preload("res://assets/creature/creature.glb")
const Music := preload("res://assets/audio/music_melted_piano.ogg")
const Ambience := preload("res://assets/audio/amb_halls.ogg")
const Voice := preload("res://assets/audio/creature_hunt.ogg")

var G: LevelGeometry
var preview: SuitRig
var preview_spot := Vector3(1.6, 0.0, -2.7)
var preview_yaw := 205.0
var creature: Node3D
var _wade: Node
var _voice: AudioStreamPlayer3D
var _click_t := 4.0
var _t := 0.0
var _ripples := PackedVector4Array()
var _ripple_i := 0
var _drip_timer := 0.0
var menu: Control
var gloves: Array[Node] = []


func _ready() -> void:
	if not Game.vr_mode:
		Game.start_xr()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ripples.resize(16)
	var lights := Node3D.new()
	lights.name = "Lights"
	add_child(lights)
	G = LevelGeometry.new(self)
	_room()
	_title_text()
	_creature()
	_audio()
	if Game.vr_mode:
		_vr_view()
	else:
		_desktop_view()
	_pedestal()
	menu.character_changed.connect(_refresh_preview)
	_refresh_preview()
	if Game.args.has("host"):
		Net.local_info.vr = Game.vr_mode
		Net.host()
	elif Game.args.has("join"):
		Net.local_info.vr = Game.vr_mode
		Net.join(str(Game.args.join))


func _room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.014)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.6, 0.65)
	env.ambient_light_energy = 0.03
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.07, 0.08)
	env.fog_density = 0.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Poolside where you stand, the pool in front, the far wall with the title.
	G.walls(-7, 7, -14, 3, 0.0, 5.0)
	G.ceiling(-7, 7, -14, 3, 5.0)
	G.floor_slab(-7, 7, -3, 3)
	G.floor_slab(-7, -5, -13, -3)
	G.floor_slab(5, 7, -13, -3)
	G.floor_slab(-7, 7, -14, -13)
	G.pool(-5, 5, -13, -3, -0.95, -0.3, {}, false)
	G.ladder(Vector3(-2.5, -1.6, -3), Vector3(0, 0, -1), 0.0)
	G.light(Vector3(0, 4.9, -1), 0.9, 9.0)
	G.light(Vector3(0, 4.9, -10), 0.7, 10.0, Color(0.8, 0.92, 1.0))


## A pedestal and spotlight for your character.
func _pedestal() -> void:
	G.block(preview_spot.x - 0.45, preview_spot.x + 0.45, 0.0, 0.12, preview_spot.z - 0.45, preview_spot.z + 0.45, G.mat_metal)
	var spot := SpotLight3D.new()
	spot.position = preview_spot + Vector3(0, 3.2, 0.6)
	spot.rotation_degrees = Vector3(-80, 0, 0)
	spot.light_energy = 2.5
	spot.spot_range = 5.0
	spot.spot_angle = 22.0
	spot.light_color = Color(1.0, 0.95, 0.85)
	add_child(spot)


func _title_text() -> void:
	var t := Label3D.new()
	t.text = "RIPPLE"
	t.font_size = 220
	t.pixel_size = 0.006
	t.outline_size = 0
	t.modulate = Color(0.55, 0.88, 0.95)
	t.position = Vector3(0, 3.2, -13.95)
	add_child(t)
	var sub := Label3D.new()
	sub.text = "THE SHALLOW HALLS  ·  DEMO"
	sub.font_size = 64
	sub.pixel_size = 0.005
	sub.modulate = Color(0.5, 0.6, 0.62)
	sub.position = Vector3(0, 2.15, -13.95)
	add_child(sub)


func _creature() -> void:
	creature = Node3D.new()            # unscaled body, the model inside it (as in the game)
	add_child(creature)
	var model: Node3D = CreatureModel.instantiate()
	model.scale = Vector3.ONE * preload("res://creature/creature.gd").MODEL_SCALE
	creature.add_child(model)
	var ap := creature.find_children("*", "AnimationPlayer", true, false)
	if ap.size() > 0:
		var anim: AnimationPlayer = ap[0]
		for n in anim.get_animation_list():
			if n.ends_with("|idle standing"):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
				anim.play(n)
	var sk := creature.find_children("*", "Skeleton3D", true, false)
	if sk.size() > 0:
		_wade = preload("res://creature/wade_modifier.gd").new()
		_wade.creature = creature
		sk[0].add_child(_wade)
		_wade.setup(sk[0])
		_wade.amount = 1.0
	_voice = AudioStreamPlayer3D.new()
	var vs: AudioStreamOggVorbis = Voice
	vs.loop = true
	_voice.stream = vs
	_voice.volume_db = -10.0
	_voice.unit_size = 3.0
	_voice.position = Vector3(0, 2.2, 0)
	creature.add_child(_voice)


func _audio() -> void:
	var m := AudioStreamPlayer.new()
	var ms: AudioStreamOggVorbis = Music
	ms.loop = true
	m.stream = ms
	m.bus = "Music"
	add_child(m)
	m.play()
	var a := AudioStreamPlayer.new()
	var am: AudioStreamOggVorbis = Ambience
	am.loop = true
	a.stream = am
	a.volume_db = -12.0
	add_child(a)
	a.play()


func _desktop_view() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(-1.5, 1.7, 1.5)
	cam.fov = 70.0
	add_child(cam)
	cam.look_at(Vector3(-2.5, 1.8, -8.0))
	cam.current = true
	preview_spot = Vector3(-0.2, 0.0, -3.2)
	preview_yaw = 195.0
	var layer := CanvasLayer.new()
	add_child(layer)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	holder.custom_minimum_size = Vector2(620, 0)
	holder.size = Vector2(620, 720)
	layer.add_child(holder)
	menu = MenuPanel.instantiate()
	holder.add_child(menu)


func _vr_view() -> void:
	var origin := XROrigin3D.new()
	origin.position = Vector3(0, 0, 0.6)
	add_child(origin)
	var cam := XRCamera3D.new()
	cam.position = Vector3(0, 1.7, 0)
	origin.add_child(cam)
	for side in ["left_hand", "right_hand"]:
		var c := XRController3D.new()
		c.tracker = side
		origin.add_child(c)
		var glove := LeftGlove.instantiate() if side == "left_hand" else RightGlove.instantiate()
		c.add_child(glove)
		gloves.append(glove)
		var p := Pointer.instantiate()
		p.enabled = side == "right_hand"
		c.add_child(p)
	var screen := Viewport2DIn3D.instantiate()
	add_child(screen)
	screen.position = Vector3(-0.75, 1.45, -1.0)
	screen.rotation_degrees = Vector3(0, 28, 0)
	screen.unshaded = true
	screen.screen_size = Vector2(0.93, 1.2)
	screen.viewport_size = Vector2(620, 800)
	screen.scene = MenuPanel
	menu = screen.get_scene_instance()
	preview_spot = Vector3(0.95, 0.0, -1.7)
	preview_yaw = 215.0


func _refresh_preview() -> void:
	if preview:
		preview.queue_free()
	preview = SuitRig.create(Profile.suit, Profile.color)
	preview.idle = true
	add_child(preview)
	preview.position = preview_spot + Vector3(0, 0.12, 0)
	preview.rotation_degrees = Vector3(0, preview_yaw, 0)
	for g in gloves:
		VRHands.tint(g, SuitRig.glove_color(Profile.suit))


func _process(delta: float) -> void:
	_t += delta
	# The creature wades slowly round the shallow pool, clicking now and then.
	var a := _t * 0.2
	var p := Vector3(cos(a) * 2.6, -0.95, -8.0 + sin(a) * 2.6)
	creature.position = p
	creature.rotation.y = atan2(-sin(a), cos(a))
	if _wade:
		_wade.phase += 0.2 * 2.6 * delta / _wade.stride * PI
	_click_t -= delta
	if _click_t <= 0.0:
		_click_t = randf_range(8.0, 16.0)
		_voice.play(randf() * maxf(_voice.stream.get_length() - 3.0, 0.0))
		get_tree().create_timer(randf_range(1.0, 2.2)).timeout.connect(_voice.stop)
	# Drips land on the water now and then, and the creature leaves ripples.
	_drip_timer -= delta
	if _drip_timer <= 0.0:
		_drip_timer = randf_range(0.6, 2.0)
		_ripple(Vector3(randf_range(-4.5, 4.5), 0, randf_range(-12.5, -3.5)), randf_range(0.2, 0.5))
		if randf() < 0.5:
			_ripple(p, 0.6)
	var t := RippleLevel.now()
	G.water_mat.set_shader_parameter("time_now", t)


func _ripple(pos: Vector3, strength: float) -> void:
	_ripples[_ripple_i] = Vector4(pos.x, pos.z, RippleLevel.now(), strength)
	_ripple_i = (_ripple_i + 1) % 16
	G.water_mat.set_shader_parameter("ripples", _ripples)
