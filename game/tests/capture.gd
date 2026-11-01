extends Node3D
## Records short clips of the creature for review, with Godot's movie writer (fixed frame rate, so
## a slow software renderer doesn't matter):
##   godot --path game --write-movie out.avi --fixed-fps 30 --quit-after 240 res://tests/capture.tscn -- --cap=wade
## Modes: wade (walks past the camera), wade_front (walks toward it), feed (feeds on remains).

const MODEL := preload("res://assets/creature/creature.glb")
const SURFACE := -0.3
const FLOOR := -0.95

var mode := "wade"
var scale_k := 4.1
var creature: Node3D
var anim: AnimationPlayer
var gait: Node
var cam: Camera3D
var _t := 0.0
var _last := Vector3.ZERO


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cap="):
			mode = a.substr(6)
		if a.begins_with("--scale="):
			scale_k = float(a.substr(8))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.025, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.4, 0.42)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	sun.light_energy = 0.9
	add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(1, 3.5, 2)
	lamp.omni_range = 12
	lamp.light_energy = 1.6
	lamp.light_color = Color(0.9, 0.95, 1.0)
	add_child(lamp)
	_plane(Vector3(0, FLOOR, 0), Vector2(30, 30), _mat(Color(0.55, 0.7, 0.75), 0.6))
	var water := _mat(Color(0.25, 0.45, 0.5, 0.55), 0.05)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_plane(Vector3(0, SURFACE, 0), Vector2(30, 30), water)
	for x in range(-14, 15, 2):       # tile lines on the floor, for a sense of speed
		var l := _plane(Vector3(x, FLOOR + 0.002, 0), Vector2(0.03, 30), _mat(Color(0.3, 0.4, 0.45), 0.6))
		l.name = "line"
	creature = Node3D.new()                        # like the game: an unscaled body, model inside
	add_child(creature)
	var model: Node3D = MODEL.instantiate()
	model.scale = Vector3.ONE * scale_k
	creature.add_child(model)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var jaw = preload("res://creature/jaw_modifier.gd").new()
	sk.add_child(jaw)
	gait = load("res://creature/wade_modifier.gd").new()
	gait.creature = creature
	sk.add_child(gait)
	gait.setup(sk)
	_play("idle standing")
	cam = Camera3D.new()
	cam.fov = 55
	add_child(cam)
	cam.current = true


func _play(want: String) -> void:
	for n in anim.get_animation_list():
		if n.ends_with("|" + want):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
			anim.play(n, 0.3)


func _plane(pos: Vector3, size: Vector2, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _process(delta: float) -> void:
	_t += delta
	if int(_t * 30.0) % 30 == 0 and "debug_top" in gait:
		print("CAP head height %.2f m" % gait.debug_top)
	var speed := 0.7                              # patrol speed in the game
	match mode:
		"wade":                                   # side view, following it
			creature.position = Vector3(-4.0 + _t * speed, FLOOR, 0)
			creature.rotation.y = PI * 0.5
			cam.position = creature.position + Vector3(0.3, 1.9, 4.2)
			cam.look_at(creature.position + Vector3(0.3, 1.25, 0))
		"wade_front":                             # three-quarter front view, following it
			creature.position = Vector3(0, FLOOR, -7.0 + _t * speed)
			creature.rotation.y = 0.0
			cam.position = creature.position + Vector3(2.2, 1.8, 3.4)
			cam.look_at(creature.position + Vector3(0, 1.2, 0.3))
		"feed", "feed_side":                      # crouched over remains, feeding
			creature.position = Vector3(0, FLOOR, 0)
			creature.rotation.y = 0.5 if mode == "feed" else -PI * 0.5
			cam.position = Vector3(2.2, 0.9, 2.0) if mode == "feed" else Vector3(-0.6, 0.6, 3.0)
			cam.look_at(Vector3(0, 0.55, 0.4) if mode == "feed" else Vector3(-0.6, 0.45, 0))
			var c := fposmod(_t, 3.6)            # reach down, grab, lift, tear twice, chew
			gait.feed = clampf(_t / 0.8, 0.0, 1.0)
			gait.feed_point = creature.global_transform * Vector3(-0.15, -0.5 - FLOOR, 0.75)
			if c < 0.7:
				gait.feed_reach = smoothstep(0.0, 0.7, c)
			elif c < 0.95:
				gait.feed_reach = 1.0
			elif c < 1.6:
				gait.feed_reach = 1.0 - smoothstep(0.95, 1.6, c)
			else:
				gait.feed_reach = 0.0
			var tear := 0.0
			for at in [1.7, 2.15]:
				var k: float = (c - at) / 0.32
				if k > 0.0 and k < 1.0:
					tear = sin(PI * k)
			if c > 2.5:
				tear = 0.15 * sin((c - 2.5) * 14.0)    # chewing
			gait.feed_tear = tear
		"stand":
			creature.position = Vector3(0, FLOOR, 0)
			creature.rotation.y = 0.6
			cam.position = Vector3(1.0, 0.9, 3.6)
			cam.look_at(Vector3(0, 1.0, 0))
			gait.look = sin(_t * 0.7) * 0.6
	var moved := (creature.position - _last).length()
	_last = creature.position
	if moved > 1.0:
		moved = 0.0
	if "amount" in gait:
		gait.amount = 1.0 if mode.begins_with("wade") else 0.0
	if "phase" in gait:
		gait.phase += moved / gait.stride * PI
