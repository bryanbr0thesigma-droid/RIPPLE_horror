extends Node
## Game-wide state: VR or desktop mode, scene changes, messages, and the desktop controls.

signal message(text: String)
signal recentered   # after the Meta-button recenter
signal focus_changed(has_focus: bool)   # the Quest's menu opened over the game (false) or closed

const LEVEL_SCENE := "res://level/level.tscn"
const MENU_SCENE := "res://ui/main.tscn"
const INTRO_SCENE := "res://intro/intro.tscn"

var vr_mode := false
var xr_interface: XRInterface
var level: Node = null          # the running level (level.gd)
var level_mode := "game"        # what the next level scene builds: "game", "lobby" or "tutorial"
var level_map := "halls"        # which level a game is: "halls" (the Shallow Halls) or "deep_end"
const MAPS := {"halls": "THE SHALLOW HALLS", "deep_end": "THE DEEP END"}
var use_lobby := false          # hosting from the menu: everyone waits in the lobby first
var menu_message := ""          # shown on the menu after leaving a game
var fader: Node3D               # scene changes fade through a loading void (core/scene_fader.gd)
var has_focus := true           # false while the headset's own menu is open over the game

## Command-line options after "--": --desktop, --host, --join=IP, --name=NAME, --autotest=NAME
var args: Dictionary = {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := str(a).trim_prefix("--")
		var kv := s.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else true
	if args.has("map") and MAPS.has(str(args.map)):
		level_map = str(args.map)
	_setup_desktop_input()
	fader = preload("res://core/scene_fader.gd").new()
	fader.name = "Fader"
	add_child(fader)
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
		# Focus: the Meta button's menu takes input away from the game (Meta's VRC.Quest.Input.4).
		if xr_interface.has_signal("session_visible") and not xr_interface.session_visible.is_connected(_on_focus):
			xr_interface.session_visible.connect(_on_focus.bind(false))
			xr_interface.session_focussed.connect(_on_focus.bind(true))
		var rate := 72.0
		if xr_interface.has_method("get_display_refresh_rate"):
			rate = maxf(xr_interface.get_display_refresh_rate(), 72.0)
		Engine.physics_ticks_per_second = int(rate)
	return vr_mode


## The headset's menu opened (false) or closed (true). Hands and controllers hide while it's open,
## and on your own (solo, the tutorial) the game pauses (VRC.Quest.Functional.2); with others in
## the session it carries on, as it has to for them.
func _on_focus(focussed: bool) -> void:
	if focussed == has_focus:
		return
	has_focus = focussed
	var alone: bool = Net.is_offline_session() or (Net.players.size() <= 1 and level != null and level.get("mode") != "lobby")
	get_tree().paused = not focussed and alone and level != null
	focus_changed.emit(focussed)


## Recenter the view: the headset's current spot and facing become the play area's centre and
## forward, keeping your real height. Called when the Meta button is held.
func recenter() -> void:
	XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
	recentered.emit()


## The first-boot tape (also "Watch the tape" on the main menu).
func play_intro() -> void:
	fader.go(INTRO_SCENE)


## Whether to play the tape now: on the first launch only, and never in tests or quick starts.
func intro_due() -> bool:
	for a in ["autotest", "no-intro", "host", "join", "host-online", "join-code"]:
		if args.has(a):
			return false
	return not Profile.intro_seen


func start_level(mode := "game") -> void:
	level_mode = mode
	if mode != "tutorial":
		Net.phase = mode
	fader.go(LEVEL_SCENE)


## The training annex, on your own (no one can join).
func start_tutorial() -> void:
	Net.local_info.vr = vr_mode
	Net.host_offline()
	start_level("tutorial")


## After hosting or joining: the host goes to the lobby (or straight into the game when playing
## solo); a joining player waits for the host to say which (Net._welcome).
func enter_session() -> void:
	if Net.is_host():
		start_level("lobby" if use_lobby else "game")


func go_to_menu(reason := "") -> void:
	menu_message = reason
	fader.go(MENU_SCENE, func():
		Net.leave(true)
		level = null)


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
