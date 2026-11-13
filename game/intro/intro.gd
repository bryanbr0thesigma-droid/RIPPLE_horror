extends Node3D
## First-boot cutscene. Late in the day you walk into a small office (carpet, drop ceiling, a frosted
## window glowing warm with the low sun) where an old TV glows blue, pick the F.A.L.C.O.N. tape up
## off the side table, push it into the VCR, press play and sit down in the armchair to watch it ("Water Safety and You", with subtitles under the TV); then it fades to black
## and the title menu opens. It plays once, on the first launch (Profile.intro_seen); "Watch the
## tape" on the main menu plays it again. Hold A, X or a trigger (VR), or Space (desktop), to skip.

const SUBTITLES := "res://assets/video/falcon_tape.srt"
const CLANK := preload("res://assets/audio/clank.ogg")
const CLICK := preload("res://assets/audio/flashlight_click.ogg")
const WHIR := preload("res://assets/audio/flashlight_whir.ogg")
const AMBIENCE := preload("res://assets/audio/amb_halls.ogg")
const GLOVE := preload("res://addons/godot-xr-tools/hands/scenes/lowpoly/right_fullglove_low.tscn")
const GLOVE_L := preload("res://addons/godot-xr-tools/hands/scenes/lowpoly/left_fullglove_low.tscn")

# Where things are. The models face +Z; the TV and VCR stand on the cabinet against the far wall.
const ROOM := OfficeRoom.ROOM
const DOOR_Z := OfficeRoom.DOOR_Z
const CABINET := OfficeRoom.CABINET
const TV := OfficeRoom.TV
const TV_SCALE := OfficeRoom.TV_SCALE
const VCR := OfficeRoom.VCR
const SCREEN := OfficeRoom.SCREEN
const SCREEN_SIZE := OfficeRoom.SCREEN_SIZE
const SCREEN_CURVE := OfficeRoom.SCREEN_CURVE
const WINDOW := OfficeRoom.WINDOW
const WINDOW_SIZE := OfficeRoom.WINDOW_SIZE
const SUN := OfficeRoom.SUN
const SLOT := OfficeRoom.SLOT
const PLAY := OfficeRoom.PLAY
const LED := OfficeRoom.LED
const SIDE_TABLE := OfficeRoom.SIDE_TABLE
const TAPE_REST := OfficeRoom.TAPE_REST
const CHAIR := OfficeRoom.CHAIR
# Your eyes along the way (standing 1.65 m, crouched at the VCR, seated in the chair).
const EYE := 1.65
const PATH_IN: Array[Vector3] = [Vector3(0.0, EYE, 4.9), Vector3(0.0, EYE, 3.3), Vector3(-0.35, EYE, 2.75),
	Vector3(-0.62, EYE, 2.45)]
const BEND := Vector3(-0.74, 1.30, 2.45)              # leaning down to the side table
const PATH_VCR: Array[Vector3] = [Vector3(-0.62, EYE, 2.45), Vector3(0.55, EYE, 1.2), Vector3(0.8, EYE, -0.6),
	Vector3(0.55, EYE, -2.05)]
const CROUCH := Vector3(0.40, 1.15, -2.27)
const BESIDE_CHAIR := Vector3(0.48, EYE, -1.85)
const SEATED := Vector3(-0.30, 1.22, -1.80)
# Seated, your hands rest on the armchair's arms (0.71 m up, 0.35 m either side).
const ARM_L := CHAIR + Vector3(-0.345, 0.75, -0.15)
const ARM_R := CHAIR + Vector3(0.345, 0.75, -0.15)
const SKIP_HOLD := 1.2
# The tape in the glove's hand space while held (palm down over it, fingers along it).
var GRIP := Transform3D(Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)), Vector3(-0.045, 0.0, -0.06))

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
var hand_mount: Node3D
var glove: Node3D
var lhand_mount: Node3D
var lglove: Node3D
var body: SuitRig               # your own suit, seen when you look down (full-body IK)
var _seated := false
var eye := PATH_IN[0]           # where your eyes are; the rig follows it every frame
var _head0 := Vector3(0, EYE, 0)   # VR: the headset's position at the start, kept as the reference
var _grip_v := 0.0
var _hand_mode := "rest"        # rest (at your side / on the armrest), free (tweened), hold (near your head)
var _fade_vr: StandardMaterial3D
var _fade_2d: ColorRect
var _cues: Array = []          # [start, end, text]
var _look := Vector3(0.0, 1.3, -2.4)   # where the desktop camera looks
var _last_eye := Vector3.ZERO
var _speed := 0.0
var _skip_t := 0.0
var _t := 0.0
var _ending := false
var _playing := false
var _first_boot := false        # the first launch: the training annex comes next


func _ready() -> void:
	_first_boot = not Profile.intro_seen and not Profile.tutorial_done
	if not Game.vr_mode:
		Game.start_xr()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if not Game.vr_mode else Input.MOUSE_MODE_VISIBLE
	var lights := Node3D.new()
	lights.name = "Lights"          # LevelGeometry puts its lights here
	add_child(lights)
	G = LevelGeometry.new(self)
	_environment()
	room_light = OfficeRoom.build_room(self, G)
	OfficeRoom.furnish(self)
	var tvs := OfficeRoom.tv_set(self)
	video = tvs.video
	screen_mat = tvs.screen_mat
	tv_light = tvs.tv_light
	led_mat = tvs.led_mat
	subs = tvs.subs
	tape = OfficeRoom.tape_model()
	add_child(tape)
	tape.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(98.0)), TAPE_REST)
	_hand()
	_rig()
	_body()
	_cues = _load_srt(SUBTITLES)
	_set_fade(1.0)
	_last_eye = eye
	_run()


# --- The sequence --------------------------------------------------------------------------------

func _run() -> void:
	ambience.play()
	await _wait(0.4)
	if Game.vr_mode:
		_head0 = cam.position
	_fade_to(0.0, 1.6)
	await _wait(0.8)
	# Walk in, past the glowing TV, to the side table.
	get_tree().create_timer(2.6).timeout.connect(func(): _look = TAPE_REST)
	await _walk(PATH_IN, 4.4)
	if _ending:
		return
	await _pick_up_tape()
	if _ending:
		return
	# Over to the VCR, and crouch in front of it.
	_look = VCR + Vector3(0, 0.1, 0)
	await _walk(PATH_VCR, 3.8)
	_look = SLOT
	await _move_eye(CROUCH, 0.9)
	if _ending:
		return
	await _insert_tape()
	if _ending:
		return
	await _press_play()
	if _ending:
		return
	# Stand, step over to the armchair and sit down.
	_look = SCREEN
	await _move_eye(Vector3(CROUCH.x + 0.04, EYE, CROUCH.z + 0.25), 1.0)
	await _walk([eye, BESIDE_CHAIR], 1.6)
	if cam is Camera3D:
		create_tween().tween_property(cam, "fov", 52.0, 2.5).set_trans(Tween.TRANS_SINE)   # desktop: settle in
	_seated = true
	create_tween().tween_property(body, "foot_extra", Vector3(0, 0, -0.5), 1.5).set_trans(Tween.TRANS_SINE)
	await _move_eye(SEATED, 1.7)
	if _ending:
		return
	await video.finished
	_playing = false
	if not _ending:
		await _wait(1.2)
		_finish()


func _pick_up_tape() -> void:
	# The glove comes up from below and closes over the tape.
	glove.force_grip_trigger(0.0, 0.0)
	_grip_v = 0.0
	_move_eye(BEND, 0.9)                         # lean down to the table
	await _hand_to(tape.global_transform * GRIP.affine_inverse() * Transform3D(Basis(), Vector3(0, 0.06, 0)), 0.75)
	await _hand_to(tape.global_transform * GRIP.affine_inverse(), 0.3)
	await _grip(0.45, 0.25)
	_sfx(CLICK, TAPE_REST, -16.0, 0.6)
	# Into your hand: from here on it moves with the glove.
	tape.reparent(hand_mount)
	tape.transform = GRIP
	_move_eye(PATH_VCR[0], 0.8)
	await _hand_to_hold(0.8)


func _insert_tape() -> void:
	# Line the tape up with the door, push it in, and let the VCR pull it the rest of the way.
	var mid := SLOT + Vector3(0, -0.0133, 0)       # the tape's origin is its bottom face
	await _hand_to(Transform3D(Basis(), mid + Vector3(0, 0, 0.16)) * GRIP.affine_inverse(), 1.0)
	await _wait(0.15)
	await _hand_to(Transform3D(Basis(), mid + Vector3(0, 0, 0.045)) * GRIP.affine_inverse(), 0.45, Tween.TRANS_QUAD)
	tape.reparent(self)
	await _grip(0.0, 0.15)
	_sfx(CLANK, SLOT, -8.0, 1.0)
	_sfx(WHIR, SLOT, -14.0, 0.55)
	var tw := create_tween()
	tw.tween_property(tape, "global_position", mid + Vector3(0, 0, -0.07), 0.6).set_trans(Tween.TRANS_SINE)
	_hand_to(hand_mount.global_transform.translated(Vector3(0.04, 0.03, 0.12)), 0.6)
	await tw.finished
	tape.visible = false
	led_mat.albedo_color = Color(0.2, 1.0, 0.3)
	led_mat.emission = Color(0.2, 1.0, 0.3)


func _press_play() -> void:
	_look = PLAY + Vector3(0, 0.02, 0)
	glove.force_grip_trigger(1.0, 0.0)          # pointing
	_grip_v = 1.0
	await _wait(0.35)
	var basis := Basis.looking_at(Vector3(-0.55, -0.3, -0.75).normalized(), Vector3.UP)
	var tip := _fingertip_local()
	var at := func(gap: float) -> Transform3D:
		return Transform3D(basis, PLAY + Vector3(0, 0, gap) - basis * tip)
	await _hand_to(at.call(0.03), 0.7)
	await _hand_to(at.call(-0.004), 0.15, Tween.TRANS_QUAD)
	_sfx(CLICK, PLAY, -6.0, 1.0)
	await _hand_to(at.call(0.04), 0.25)
	# The tape starts: a flicker of static, then the picture.
	_tv_on()
	video.play()
	_playing = true
	_look = SCREEN
	glove.force_grip_trigger(0.15, 0.15)
	_grip_v = 0.15
	await _hand_to_rest(0.8)


func _tv_on() -> void:
	screen_mat.albedo_texture = null
	screen_mat.albedo_color = Color(0.9, 0.95, 1.0)
	tv_light.light_energy = 1.2
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func():
		screen_mat.albedo_color = Color(1, 1, 1)
		screen_mat.albedo_texture = video.get_parent().get_texture()
		tv_light.light_color = Color(0.75, 0.85, 1.0)
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
	if _first_boot:
		Game.start_tutorial()
	else:
		Game.go_to_menu()


# --- Moving you and the hand ---------------------------------------------------------------------

## Walk along the points (a smooth curve through them) in `time` seconds.
func _walk(points: Array[Vector3], time: float) -> Signal:
	var curve := Curve3D.new()
	for i in points.size():
		var p := points[i]
		var tangent := Vector3.ZERO
		if i > 0 and i < points.size() - 1:
			tangent = (points[i + 1] - points[i - 1]) * 0.25
		curve.add_point(p, -tangent, tangent)
	var length := curve.get_baked_length()
	var tw := create_tween()
	tw.tween_method(func(k: float): eye = curve.sample_baked(k * length), 0.0, 1.0, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw.finished


func _move_eye(to: Vector3, time: float) -> Signal:
	var tw := create_tween()
	tw.tween_property(self, "eye", to, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw.finished


func _yaw_basis() -> Basis:
	var f := -cam.global_transform.basis.z
	f.y = 0.0
	if f.length() < 0.01:
		f = Vector3.FORWARD
	return Basis.looking_at(f.normalized(), Vector3.UP)


## Where the glove holds the tape while you walk: low and to the right, label tilted towards you.
func _hold_xf() -> Transform3D:
	var yb := _yaw_basis()
	var tape_xf := Transform3D(yb * Basis(Vector3.RIGHT, deg_to_rad(35.0)), cam.global_position + yb * Vector3(0.12, -0.38, -0.36))
	return tape_xf * GRIP.affine_inverse()


func _hand_to(target: Transform3D, time: float, trans := Tween.TRANS_SINE) -> Signal:
	_hand_mode = "free"
	var a := hand_mount.global_transform
	var tw := create_tween()
	tw.tween_method(func(k: float): hand_mount.global_transform = a.interpolate_with(target, k), 0.0, 1.0, time) \
		.set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	return tw.finished


func _hand_to_hold(time: float) -> void:
	_hand_mode = "free"
	var a := hand_mount.global_transform
	var tw := create_tween()
	tw.tween_method(func(k: float): hand_mount.global_transform = a.interpolate_with(_hold_xf(), k), 0.0, 1.0, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_hand_mode = "hold"


## Where a hand rests (0 left, 1 right): hanging at your side, swinging a little as you walk; seated,
## on the armchair's arm.
func _rest_xf(i: int) -> Transform3D:
	if _seated:
		var at := ARM_L if i == 0 else ARM_R
		var side := Vector3.RIGHT if i == 0 else Vector3.LEFT       # index finger towards your middle
		return Transform3D(Basis(side.cross(Vector3.BACK), side, Vector3.BACK), at)
	var b := Basis(Vector3.UP, body.global_transform.basis.get_euler().y) if body else _yaw_basis()
	var swing := sin(_t * 3.75 + (PI if i == 0 else 0.0)) * 0.09 * clampf(_speed / 0.7, 0.0, 1.0)
	var off := Vector3(-0.23 if i == 0 else 0.23, 0.87, 0.02 - swing)
	var base := Transform3D(b, Vector3(cam.global_position.x, 0.0, cam.global_position.z))
	return Transform3D(b * Basis(Vector3.RIGHT, -PI * 0.5), base * off)      # fingers down


func _hand_to_rest(time: float) -> void:
	_hand_mode = "free"
	var a := hand_mount.global_transform
	var tw := create_tween()
	tw.tween_method(func(k: float): hand_mount.global_transform = a.interpolate_with(_rest_xf(1), k), 0.0, 1.0, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_hand_mode = "rest"


func _grip(amount: float, time: float) -> Signal:
	var tw := create_tween()
	tw.tween_method(func(v: float):
		_grip_v = v
		glove.force_grip_trigger(v, v), _grip_v, amount, time)
	return tw.finished


## The index fingertip in the hand mount's space (for pressing the button with it).
func _fingertip_local() -> Vector3:
	var sk := glove.find_child("Skeleton3D", true, false) as Skeleton3D
	if not sk:
		return Vector3(0, 0, -0.15)
	var i := sk.find_bone("Index_Tip_R")
	if i < 0:
		return Vector3(0, 0, -0.15)
	var tip := sk.global_transform * sk.get_bone_global_pose(i).origin
	return glove.global_transform.affine_inverse() * tip


# --- Every frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	# Follow the eye point: desktop moves the camera there; VR moves the play area so your head is
	# there (your own head movement still counts).
	_speed = lerpf(_speed, Vector2(eye.x - _last_eye.x, eye.z - _last_eye.z).length() / maxf(delta, 0.001), clampf(delta * 6.0, 0.0, 1.0))
	_last_eye = eye
	if Game.vr_mode:
		rig.position = eye - _head0
	else:
		var bob := sin(_t * 7.5) * 0.016 * clampf(_speed / 0.7, 0.0, 1.0)
		rig.position = Vector3(eye.x, 0.0, eye.z)
		cam.position = Vector3(0, eye.y + bob, 0)
		var want := cam.global_transform.looking_at(_look, Vector3.UP).basis
		cam.global_transform.basis = cam.global_transform.basis.slerp(want, clampf(delta * 2.5, 0.0, 1.0))
	if _hand_mode == "hold":
		hand_mount.global_transform = hand_mount.global_transform.interpolate_with(_hold_xf(), clampf(delta * 10.0, 0.0, 1.0))
	elif _hand_mode == "rest":
		hand_mount.global_transform = hand_mount.global_transform.interpolate_with(_rest_xf(1), clampf(delta * 8.0, 0.0, 1.0))
	lhand_mount.global_transform = lhand_mount.global_transform.interpolate_with(_rest_xf(0), clampf(delta * 8.0, 0.0, 1.0))
	# Your body: head where the camera is, hands on the gloves, feet on the floor under you.
	var head: Transform3D = cam.global_transform
	body.pose(head, SuitRig.glove_hand(lglove, lhand_mount.global_transform), SuitRig.glove_hand(glove, hand_mount.global_transform),
		Vector3(head.origin.x, 0.0, head.origin.z))
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
	env.ambient_light_color = Color(0.8, 0.5, 0.36)         # warm: the setting sun through the window
	env.ambient_light_energy = 0.08
	env.glow_enabled = not Game.vr_mode                      # the window bloom (not on the Quest: see lobby_room.gd)
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.045, 0.035)
	env.fog_density = 0.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	ambience = AudioStreamPlayer.new()
	ambience.stream = AMBIENCE
	ambience.volume_db = -20.0
	add_child(ambience)


func _hand() -> void:
	# A gloved right hand (your suit's glove colour) for picking up the tape and pressing play.
	hand_mount = Node3D.new()
	add_child(hand_mount)
	glove = GLOVE.instantiate()
	hand_mount.add_child(glove)
	VRHands.tint(glove, SuitRig.glove_color(Profile.suit))
	lhand_mount = Node3D.new()
	add_child(lhand_mount)
	lglove = GLOVE_L.instantiate()
	lhand_mount.add_child(lglove)
	VRHands.tint(lglove, SuitRig.glove_color(Profile.suit))


## Your own suit (full-body IK): no head (the camera is in it) and no hands (the gloves are).
func _body() -> void:
	body = SuitRig.create(Profile.suit, Profile.color)
	body.set_first_person(true)
	add_child(body)
	var feet := Vector3(cam.global_position.x, 0.0, cam.global_position.z)
	hand_mount.global_transform = _rest_xf(1)
	lhand_mount.global_transform = _rest_xf(0)
	body.pose(cam.global_transform, lhand_mount.global_transform, hand_mount.global_transform, feet)


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
	rig.position = Vector3(eye.x, 0.0, eye.z)
	if not Game.vr_mode:
		cam.position = Vector3(0, eye.y, 0)
		cam.look_at(_look, Vector3.UP)
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
	# A faint light by your head, so the glove and the tape read in the dim room.
	var near := OmniLight3D.new()
	near.light_color = Color(1.0, 0.95, 0.88)
	near.light_energy = 0.35
	near.omni_range = 1.4
	near.position = Vector3(0.1, 0.05, 0.0)
	cam.add_child(near)
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


func _sfx(stream: AudioStream, pos: Vector3, db: float, pitch := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
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
