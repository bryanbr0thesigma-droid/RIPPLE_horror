extends Node3D
## Scene changes the way VR games do them: never a hard cut. Fade to black, load the next scene in
## the background while a loading sign hangs in the dark in front of you (it stays put in the world
## as you look around, so your head keeps tracking), switch, and fade back in once the new place has
## drawn a few frames. On the Quest the OS splash screen covers the boot itself (Meta asks for
## something head-tracked within 4 seconds of launch).

const SEAL := "res://assets/branding/falcon_logo_onecolor.png"
const FADE_OUT := 0.35
const FADE_IN := 0.6

var busy := false
var _pending: Array = []           # a change asked for in the middle of another: [path, then]
var _veil: MeshInstance3D          # a black sphere around the camera
var _veil_mat: StandardMaterial3D
var _sign: Node3D                  # LOADING and the turning seal
var _seal: MeshInstance3D
var _alpha := 0.0
var _flat: ColorRect               # the same black over the flat screen (desktop: menus, HUD)


func _ready() -> void:
	process_priority = 1000        # follow the camera after everything else has moved it
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.3
	s.height = 0.6
	s.flip_faces = true
	_veil.mesh = s
	_veil_mat = StandardMaterial3D.new()
	_veil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_veil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_veil_mat.no_depth_test = true
	_veil_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_veil_mat.render_priority = 120
	_veil_mat.albedo_color = Color(0, 0, 0, 0)
	_veil.material_override = _veil_mat
	_veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_veil.visible = false
	add_child(_veil)
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_flat = ColorRect.new()
	_flat.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flat.color = Color(0, 0, 0, 0)
	_flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flat.visible = false
	layer.add_child(_flat)
	_sign = Node3D.new()
	_sign.visible = false
	add_child(_sign)
	_seal = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.32, 0.32)
	_seal.mesh = q
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.no_depth_test = true
	sm.render_priority = 125
	sm.albedo_texture = load(SEAL)
	sm.albedo_color = Color(0.85, 0.8, 0.6)
	_seal.material_override = sm
	_seal.position = Vector3(0, 0.12, 0)
	_sign.add_child(_seal)
	var l := Label3D.new()
	l.text = "LOADING"
	l.font_size = 40
	l.pixel_size = 0.0016
	l.modulate = Color(0.75, 0.72, 0.62)
	l.outline_size = 0
	l.no_depth_test = true
	l.render_priority = 125
	l.position = Vector3(0, -0.12, 0)
	_sign.add_child(l)


## Go to another scene (a file path) with a fade and a background load. `then` runs once it's dark,
## just before the old scene goes (leaving the session, say).
func go(path: String, then := Callable()) -> void:
	if busy:
		_pending = [path, then]
		return
	busy = true
	await _fade(1.0, FADE_OUT)
	if then.is_valid():
		then.call()
	# The old scene is behind black now: stop it (nothing to see, and it leaves the CPU to the loading).
	var old := get_tree().current_scene
	if old:
		old.process_mode = Node.PROCESS_MODE_DISABLED
	_place_sign()
	var err := ResourceLoader.load_threaded_request(path)
	var packed: PackedScene = null
	if err == OK:
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		packed = ResourceLoader.load_threaded_get(path) as PackedScene
	if packed:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(path)
	# The new scene builds in its _ready; wait for a camera (a player's rig can take a moment) and a
	# few drawn frames before lifting the veil.
	var t := 0.0
	while t < 10.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if get_viewport().get_camera_3d() and t > 0.15:
			break
	for i in 3:
		await get_tree().process_frame
	_sign.visible = false
	busy = false
	if not _pending.is_empty():
		var p: Array = _pending
		_pending = []
		go(p[0], p[1])
		return
	await _fade(0.0, FADE_IN)


func _fade(to: float, time: float) -> void:
	var from := _alpha
	var t := 0.0
	while t < time:
		await get_tree().process_frame
		t += get_process_delta_time()
		_set_alpha(lerpf(from, to, clampf(t / time, 0.0, 1.0)))
	_set_alpha(to)


func _set_alpha(a: float) -> void:
	_alpha = a
	_veil_mat.albedo_color = Color(0, 0, 0, a)
	_veil.visible = a > 0.005
	_flat.color = Color(0, 0, 0, a)
	_flat.visible = a > 0.005 and not Game.vr_mode


## In the dark, 1.6 m ahead of where you're looking, level with your eyes.
func _place_sign() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	_sign.global_position = cam.global_position + fwd * 1.6
	_sign.look_at(cam.global_position, Vector3.UP, true)
	_sign.visible = true


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and _veil.visible:
		_veil.global_position = cam.global_position
	if _sign.visible:
		_seal.rotate_object_local(Vector3.FORWARD, delta * 1.2)
		# After the switch the camera is somewhere new: bring the sign along, once.
		if cam and cam.global_position.distance_to(_sign.global_position) > 4.0:
			_place_sign()
