extends Node3D
## First-boot cutscene. You walk into a small dim room, put the F.A.L.C.O.N. tape in the VCR, and
## the TV plays it ("Water Safety and You", with subtitles under the screen); then it fades to black
## and the title menu opens. It plays once, on the first launch (Profile.intro_seen); "Watch the
## tape" on the main menu plays it again. Hold A, X or a trigger (VR), or Space (desktop), to skip.
##
## The TV, VCR and tape are simple shapes until real models are picked on the review page.

const TAPE := preload("res://assets/video/falcon_tape.ogv")
const SUBTITLES := "res://assets/video/falcon_tape.srt"
const CLANK := preload("res://assets/audio/clank.ogg")
const AMBIENCE := preload("res://assets/audio/amb_halls.ogg")

const START := Vector3(0.0, 0.0, 3.5)       # in the corridor, outside the door
const STAND := Vector3(0.0, 0.0, 0.1)       # in front of the TV
const SCREEN := Vector3(0.0, 1.19, -1.655)  # centre of the TV screen
const SLOT := Vector3(0.0, 0.855, -1.735)   # the VCR's tape slot
const WALK_TIME := 6.0
const SKIP_HOLD := 1.2
const EYE := 1.65

var G: LevelGeometry
var rig: Node3D
var cam: Node3D
var controllers: Array[XRController3D] = []
var video: VideoStreamPlayer
var screen_mat: StandardMaterial3D
var tv_light: OmniLight3D
var room_light: OmniLight3D
var led_mat: StandardMaterial3D
var tape: Node3D
var subs: Label3D
var hint: Label3D
var ambience: AudioStreamPlayer
var _fade_vr: StandardMaterial3D
var _fade_2d: ColorRect
var _cues: Array = []          # [start, end, text]
var _look := SCREEN            # where the desktop camera looks
var _walking := false
var _skip_t := 0.0
var _t := 0.0
var _ending := false
var _playing := false


func _ready() -> void:
	if not Game.vr_mode:
		Game.start_xr()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if not Game.vr_mode else Input.MOUSE_MODE_VISIBLE
	var lights := Node3D.new()
	lights.name = "Lights"          # LevelGeometry puts its lights here
	add_child(lights)
	G = LevelGeometry.new(self)
	_environment()
	_room()
	_tv_and_vcr()
	_rig()
	_cues = _load_srt(SUBTITLES)
	_set_fade(1.0)
	_run()


# --- The sequence --------------------------------------------------------------------------------

func _run() -> void:
	ambience.play()
	await _wait(0.4)
	_fade_to(0.0, 1.6)
	await _wait(1.0)
	# Walk in.
	_walking = true
	var tw := create_tween()
	tw.tween_property(rig, "position", STAND, WALK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_walking = false
	if _ending:
		return
	# The tape, from your hand into the slot.
	await _insert_tape()
	if _ending:
		return
	# The TV comes on, and the tape plays.
	await _wait(0.6)
	_tv_on()
	video.play()
	_playing = true
	await video.finished
	_playing = false
	if not _ending:
		await _wait(1.2)
		_finish()


func _insert_tape() -> void:
	var c := cam.global_transform
	var hand := c.origin + (-c.basis.z) * 0.38 + Vector3.DOWN * 0.3 + c.basis.x * 0.06
	tape.global_position = hand
	tape.rotation = Vector3(0.0, 0.0, 0.0)
	tape.scale = Vector3.ONE * 0.01
	tape.visible = true
	_look = SLOT + Vector3(0, 0.05, 0)
	var tw := create_tween()
	tw.tween_property(tape, "scale", Vector3.ONE, 0.25)
	tw.tween_property(tape, "global_position", SLOT + Vector3(0, 0, 0.16), 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.15)
	tw.tween_property(tape, "global_position", SLOT + Vector3(0, 0, -0.14), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	tape.visible = false
	_sfx(CLANK, SLOT, -6.0)
	led_mat.albedo_color = Color(0.2, 1.0, 0.3)
	led_mat.emission = Color(0.2, 1.0, 0.3)
	_look = SCREEN


func _tv_on() -> void:
	# A white flash as the tube warms up, then the picture.
	screen_mat.albedo_texture = null
	screen_mat.albedo_color = Color(0.9, 0.95, 1.0)
	tv_light.light_energy = 1.2
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func():
		screen_mat.albedo_color = Color(1, 1, 1)
		screen_mat.albedo_texture = video.get_parent().get_texture()
		tv_light.light_energy = 0.55)


func _finish() -> void:
	if _ending:
		return
	_ending = true
	hint.visible = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(_set_fade, _current_fade(), 1.0, 2.0)
	tw.tween_property(ambience, "volume_db", -60.0, 2.0)
	tw.tween_property(video, "volume_db", -60.0, 2.0)
	await tw.finished
	await _wait(0.4)
	Profile.intro_seen = true
	Profile.save()
	Game.go_to_menu()


# --- Every frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	# The room's fluorescent tube flickers now and then.
	room_light.light_energy = 0.45 if fmod(_t, 7.3) > 0.12 else 0.12
	if not Game.vr_mode:
		var bob := sin(_t * 7.5) * 0.014 if _walking else 0.0
		cam.position = Vector3(0, EYE + bob, 0)
		var want := cam.global_transform.looking_at(_look, Vector3.UP).basis
		cam.global_transform.basis = cam.global_transform.basis.slerp(want, clampf(delta * 2.5, 0.0, 1.0))
	# Subtitles follow the tape.
	if _playing:
		var pos := video.stream_position
		var text := ""
		for c in _cues:
			if pos >= c[0] and pos <= c[1]:
				text = c[2]
				break
		subs.text = text
	else:
		subs.text = ""
	# Hold to skip.
	if not _ending:
		if _skip_held():
			_skip_t += delta
			hint.text = "Skipping..." if _skip_t > 0.2 else hint.text
			hint.modulate.a = 1.0
			if _skip_t >= SKIP_HOLD:
				_finish()
		else:
			_skip_t = 0.0
			hint.text = "Hold A to skip" if Game.vr_mode else "Hold Space to skip"
			hint.modulate.a = clampf(1.0 - (_t - 7.0) / 2.0, 0.0, 0.8)
		hint.outline_modulate.a = hint.modulate.a
		hint.visible = hint.modulate.a > 0.01


func _skip_held() -> bool:
	if Game.vr_mode:
		for c in controllers:
			if c.is_button_pressed("ax_button") or c.is_button_pressed("by_button") or c.is_button_pressed("trigger_click"):
				return true
		return false
	return Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_ESCAPE) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


# --- Building ------------------------------------------------------------------------------------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.55, 0.6)
	env.ambient_light_energy = 0.05
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.05, 0.06)
	env.fog_density = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	ambience = AudioStreamPlayer.new()
	ambience.stream = AMBIENCE
	ambience.volume_db = -20.0
	add_child(ambience)


func _room() -> void:
	# The room: 4 m by 4.4 m, door in the south wall; a short dark corridor outside.
	G.floor_slab(-2.0, 2.0, -2.4, 2.0, 0.0)
	G.walls(-2.0, 2.0, -2.4, 2.0, 0.0, 2.6, {"s": [[-0.5, 0.5, 2.1]]})
	G.ceiling(-2.0, 2.0, -2.4, 2.0, 2.6)
	G.floor_slab(-0.8, 0.8, 2.0, 4.4, 0.0, G.mat_blue)
	G.walls(-0.8, 0.8, 2.3, 4.4, 0.0, 2.6, {"n": [[-0.8, 0.8, 2.6]]}, G.mat_blue)
	G.ceiling(-0.8, 0.8, 2.0, 4.4, 2.6)
	room_light = G.light(Vector3(0.0, 2.45, -0.3), 0.45, 6.5)
	G.light(Vector3(0.0, 2.45, 3.6), 0.18, 3.0, Color(0.8, 0.9, 1.0))


func _dark(c: Color, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _tv_and_vcr() -> void:
	# Stand, VCR, CRT television (placeholders until models are picked).
	G.block(-0.55, 0.55, 0.0, 0.8, -2.25, -1.75, _dark(Color(0.22, 0.16, 0.11), 0.8))
	G.block(-0.22, 0.22, 0.8, 0.89, -2.1, -1.74, _dark(Color(0.06, 0.06, 0.07), 0.4))
	G.block(-0.36, 0.36, 0.89, 1.49, -2.2, -1.66, _dark(Color(0.09, 0.085, 0.08), 0.5))
	var slot := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(0.2, 0.02)
	slot.mesh = sq
	slot.material_override = _dark(Color(0, 0, 0))
	slot.position = SLOT + Vector3(0, 0, -0.004)
	add_child(slot)
	var led := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.012, 0.006, 0.004)
	led.mesh = lb
	led_mat = _dark(Color(0.25, 0.05, 0.05), 0.3)
	led_mat.emission_enabled = true
	led_mat.emission = Color(0.4, 0.0, 0.0)
	led.material_override = led_mat
	led.position = Vector3(0.16, 0.835, -1.737)
	add_child(led)
	# The screen shows the tape through a 640x480 viewport.
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 480)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	video = VideoStreamPlayer.new()
	video.stream = TAPE
	video.expand = true
	video.size = Vector2(640, 480)
	video.volume_db = -1.0
	vp.add_child(video)
	var screen := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.56, 0.42)
	screen.mesh = qm
	screen_mat = StandardMaterial3D.new()
	screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_mat.albedo_color = Color(0.03, 0.035, 0.035)
	screen.material_override = screen_mat
	screen.position = SCREEN
	add_child(screen)
	tv_light = OmniLight3D.new()
	tv_light.light_color = Color(0.75, 0.85, 1.0)
	tv_light.light_energy = 0.0
	tv_light.omni_range = 4.0
	tv_light.position = SCREEN + Vector3(0, 0, 0.5)
	add_child(tv_light)
	# Subtitles on the stand, under the TV.
	subs = Label3D.new()
	subs.position = Vector3(0, 0.72, -1.735)
	subs.pixel_size = 0.0019
	subs.font_size = 32
	subs.outline_size = 10
	subs.width = 600
	subs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subs.modulate = Color(1, 1, 0.92)
	subs.no_depth_test = true
	add_child(subs)
	# The tape (black shell, white label), hidden until you hold it.
	tape = Node3D.new()
	var shell := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.19, 0.025, 0.105)
	shell.mesh = tb
	shell.material_override = _dark(Color(0.03, 0.03, 0.03), 0.35)
	tape.add_child(shell)
	var label := MeshInstance3D.new()
	var lq := QuadMesh.new()
	lq.size = Vector2(0.15, 0.06)
	label.mesh = lq
	label.material_override = _dark(Color(0.92, 0.9, 0.82), 0.8)
	label.rotation_degrees = Vector3(-90, 0, 0)
	label.position = Vector3(0, 0.0131, 0.0)
	tape.add_child(label)
	tape.visible = false
	add_child(tape)


func _rig() -> void:
	if Game.vr_mode:
		var origin := XROrigin3D.new()
		origin.current = true
		add_child(origin)
		var xc := XRCamera3D.new()
		xc.current = true
		origin.add_child(xc)
		for tracker in ["left_hand", "right_hand"]:
			var c := XRController3D.new()
			c.tracker = tracker
			origin.add_child(c)
			controllers.append(c)
		rig = origin
		cam = xc
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
	else:
		rig = Node3D.new()
		add_child(rig)
		var c := Camera3D.new()
		c.fov = 70.0
		c.current = true
		rig.add_child(c)
		cam = c
	rig.position = START
	cam.position = Vector3(0, EYE, 0) if not Game.vr_mode else cam.position
	# Fades: a black sphere around the head (VR), a black screen (desktop).
	var sphere := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	sm.flip_faces = true
	sphere.mesh = sm
	_fade_vr = StandardMaterial3D.new()
	_fade_vr.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fade_vr.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fade_vr.no_depth_test = true
	_fade_vr.render_priority = 100
	sphere.material_override = _fade_vr
	cam.add_child(sphere)
	var layer := CanvasLayer.new()
	add_child(layer)
	_fade_2d = ColorRect.new()
	_fade_2d.color = Color.BLACK
	_fade_2d.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_2d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade_2d)
	# The skip hint, low in your view.
	hint = Label3D.new()
	hint.pixel_size = 0.0009
	hint.font_size = 28
	hint.outline_size = 8
	hint.no_depth_test = true
	hint.render_priority = 101
	hint.position = Vector3(0, -0.22, -0.75)
	hint.modulate = Color(1, 1, 1, 0.8)
	cam.add_child(hint)


# --- Helpers -------------------------------------------------------------------------------------

func _set_fade(a: float) -> void:
	_fade_vr.albedo_color = Color(0, 0, 0, a)
	_fade_2d.color = Color(0, 0, 0, a)


func _current_fade() -> float:
	return _fade_2d.color.a


func _fade_to(a: float, time: float) -> void:
	create_tween().tween_method(_set_fade, _current_fade(), a, time)


func _wait(t: float) -> Signal:
	return get_tree().create_timer(t).timeout


func _sfx(stream: AudioStream, pos: Vector3, db: float) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.position = pos
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Subtitle cues from an .srt file: [[start seconds, end seconds, text], ...].
static func _load_srt(path: String) -> Array:
	var out := []
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return out
	var blocks := f.get_as_text().replace("\r", "").split("\n\n", false)
	for b in blocks:
		var lines := b.strip_edges().split("\n")
		if lines.size() < 3 or not lines[1].contains("-->"):
			continue
		var times := lines[1].split("-->")
		out.append([_srt_time(times[0]), _srt_time(times[1]), "\n".join(lines.slice(2))])
	return out


static func _srt_time(s: String) -> float:
	var p := s.strip_edges().replace(",", ".").split(":")
	if p.size() < 3:
		return 0.0
	return float(p[0]) * 3600.0 + float(p[1]) * 60.0 + float(p[2])
