extends Node
## Game-wide state: VR or desktop mode, scene changes, messages, and the desktop controls.

signal message(text: String)
signal recentered   # after the Meta-button recenter

const LEVEL_SCENE := "res://level/level.tscn"
const MENU_SCENE := "res://ui/main.tscn"

var vr_mode := false
var xr_interface: XRInterface
var level: Node = null          # the running level (level.gd)
var menu_message := ""          # shown on the menu after leaving a game

## Command-line options after "--": --desktop, --host, --join=IP, --name=NAME, --autotest=NAME
var args: Dictionary = {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := str(a).trim_prefix("--")
		var kv := s.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else true
	_setup_desktop_input()
	Net.session_ended.connect(_on_session_ended)
	# A kill stacks a screech, tearing, cracks and bites at once: a limiter on the master bus keeps
	# that from clipping into noise.
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, lim)
	if args.has("autotest"):
		var t: Node = load("res://tests/autotest.gd").new()
		t.name = "AutoTest"
		get_tree().root.add_child.call_deferred(t)


## Try to start VR. Returns true if a headset is running.
func start_xr() -> bool:
	if args.has("fakevr"):   # test only: build the VR rig without a headset
		vr_mode = true
		return true
	if args.has("desktop"):
		return false
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		vr_mode = true
	elif xr_interface and xr_interface.initialize():
		vr_mode = true
	if vr_mode:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		# Holding the Meta button asks to recenter. In the stage space (real floor height) the
		# headset leaves that to the game, so face forward where the player is looking.
		if not xr_interface.pose_recentered.is_connected(recenter):
			xr_interface.pose_recentered.connect(recenter)
		var rate := 72.0
		if xr_interface.has_method("get_display_refresh_rate"):
			rate = maxf(xr_interface.get_display_refresh_rate(), 72.0)
		Engine.physics_ticks_per_second = int(rate)
	return vr_mode


## Recenter the view: the headset's current spot and facing become the play area's centre and
## forward, keeping your real height. Called when the Meta button is held.
func recenter() -> void:
	XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
	recentered.emit()


func start_level() -> void:
	get_tree().change_scene_to_file.call_deferred(LEVEL_SCENE)


func go_to_menu(reason := "") -> void:
	menu_message = reason
	Net.leave(true)
	level = null
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)


func notify(text: String) -> void:
	message.emit(text)
	print("[RIPPLE] ", text)


func _on_session_ended(reason: String) -> void:
	if level:
		go_to_menu(reason)


func _setup_desktop_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "run": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_C],
		"interact": [KEY_E], "drop": [KEY_Q], "push": [KEY_F], "pause": [KEY_ESCAPE], "backpack": [KEY_B],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for pair in [["use_item", MOUSE_BUTTON_LEFT], ["reach", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
		var mb := InputEventMouseButton.new()
		mb.button_index = pair[1]
		InputMap.action_add_event(pair[0], mb)
