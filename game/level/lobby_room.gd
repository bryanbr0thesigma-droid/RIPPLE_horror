extends Node3D
## The multiplayer lobby: the office from the first-boot tape, where everyone waits before a game.
## The F.A.L.C.O.N. tape lies on the side table; put it in the VCR and it plays on the TV for
## everyone (with subtitles) and pops back out at the end. A sign on the wall shows the room code
## and who's here. The host pulls the START lever by the door, and everyone goes into the game.

const SLOT := OfficeRoom.SLOT
const INTRO := preload("res://intro/intro.gd")
const LEVER_AT := Vector3(1.6, 0.0, 1.6)          # the start lever's post, in the room
const SPAWNS: Array[Vector3] = [Vector3(0.4, 0.05, 0.9), Vector3(-0.6, 0.05, 1.0), Vector3(1.0, 0.05, 0.2), Vector3(-1.3, 0.05, 0.3)]

var level: Node3D
var video: VideoStreamPlayer
var screen_mat: StandardMaterial3D
var tv_light: OmniLight3D
var led_mat: StandardMaterial3D
var subs: Label3D
var info: Label3D
var playing := false
var _cues: Array = []
var _info_t := 0.0


func build(lv: Node3D) -> void:
	level = lv
	_environment(lv.world_env.environment)
	OfficeRoom.build_room(lv, lv.G)
	OfficeRoom.furnish(lv)
	# A couple more seats in front of the TV.
	lv.G.chair(Vector3(0.75, 0.0, -1.7), 200.0)
	lv.G.chair(Vector3(-1.35, 0.0, -1.55), 160.0)
	var tvs := OfficeRoom.tv_set(self)
	video = tvs.video
	screen_mat = tvs.screen_mat
	tv_light = tvs.tv_light
	led_mat = tvs.led_mat
	subs = tvs.subs
	video.finished.connect(_on_tape_end)
	_cues = INTRO._load_srt("res://assets/video/falcon_tape.srt")
	# The VCR itself, so desktop players can press interact on it with the tape.
	var vcr_body := StaticBody3D.new()
	vcr_body.add_to_group("vcr")
	vcr_body.collision_layer = LevelGeometry.L_WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.43, 0.1, 0.34)
	cs.shape = box
	vcr_body.position = OfficeRoom.VCR + Vector3(0, 0.05, 0)
	vcr_body.add_child(cs)
	add_child(vcr_body)
	# The tape, on the side table.
	lv._spawn_item("tape", "Tape", OfficeRoom.TAPE_REST + Vector3(0, 0.03, 0))
	# The host's start lever, on a post by the door.
	lv._make_lever(LEVER_AT - Vector3(17.0, 0.0, -33.0), "START\nthe host pulls this\nwhen everyone's here")
	# The sign: room code and who's here.
	info = Label3D.new()
	info.position = Vector3(1.75, 1.85, OfficeRoom.ROOM.position.y + 0.03)
	info.pixel_size = 0.0021
	info.font_size = 40
	info.width = 700
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.modulate = Color(0.13, 0.12, 0.1)
	info.outline_size = 0
	add_child(info)
	var board := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(1.6, 1.1)
	board.mesh = bq
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.93, 0.91, 0.84)
	bm.roughness = 0.9
	board.material_override = bm
	board.position = info.position + Vector3(0, -0.05, -0.01)
	add_child(board)
	lv.spawn_points = SPAWNS
	lv.zones = []
	_update_info()


func _environment(env: Environment) -> void:
	# The late sun through the window, as in the tape.
	env.background_color = Color(0, 0, 0)
	env.ambient_light_color = Color(0.8, 0.5, 0.36)
	env.ambient_light_energy = 0.12
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.045, 0.035)
	env.fog_density = 0.03
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9


func _process(delta: float) -> void:
	_info_t -= delta
	if _info_t <= 0.0:
		_info_t = 0.5
		_update_info()
	if playing:
		var pos := video.stream_position
		var text := ""
		for c in _cues:
			if pos >= c[0] and pos <= c[1]:
				text = c[2]
				break
		subs.text = text
	else:
		subs.text = ""


func _update_info() -> void:
	var names := []
	for id in Net.players:
		names.append(str(Net.players[id].get("name", "Player")))
	if names.is_empty():
		names.append(Net.local_info.get("name", "Player"))
	var host_name := str(Net.players.get(1, {}).get("name", "the host"))
	var code := ""
	if Net.room_code != "":
		code = "Room code: %s\n" % Net.room_code
	elif Net.is_online() and Net.is_host():
		var ips := Net.local_addresses()
		if not ips.is_empty():
			code = "On this Wi-Fi: %s\n" % ips[0]
	var start := "Pull the START lever when everyone's here." if Net.is_host() or not Net.is_online() \
		else "Waiting for %s to start the game." % host_name
	info.text = "F.A.L.C.O.N. ORIENTATION ROOM\n\n%sHere (%d/%d): %s\n\n%s\nPut the tape in the VCR to watch it while you wait." % [
		code, names.size(), Net.MAX_PLAYERS, ", ".join(names), start]


## The tape went in (true) or came out (false): play it on everyone's TV.
func on_vhs(on: bool) -> void:
	if on == playing:
		return
	playing = on
	if on:
		led_mat.albedo_color = Color(0.2, 1.0, 0.3)
		led_mat.emission = Color(0.2, 1.0, 0.3)
		screen_mat.albedo_texture = null
		screen_mat.albedo_color = Color(0.9, 0.95, 1.0)
		var tw := create_tween()
		tw.tween_interval(0.12)
		tw.tween_callback(func():
			screen_mat.albedo_color = Color(1, 1, 1)
			screen_mat.albedo_texture = video.get_parent().get_texture()
			tv_light.light_color = Color(0.75, 0.85, 1.0)
			tv_light.light_energy = 0.55)
		video.play()
	else:
		video.stop()
		led_mat.albedo_color = Color(0.6, 0.05, 0.05)
		led_mat.emission = Color(0.8, 0.05, 0.0)
		screen_mat.albedo_texture = null
		screen_mat.albedo_color = Color(0.06, 0.13, 0.62)
		tv_light.light_color = Color(0.25, 0.4, 1.0)
		tv_light.light_energy = 0.35


## Host: the tape ended. It stops and pops back out of the VCR.
func _on_tape_end() -> void:
	if not (Net.is_host() or not Net.is_online()):
		return
	level.set_state("vhs", false)
	var out := SLOT + Vector3(0, -0.01, 0.2)
	level._set_item_stowed_at("Tape", 0, out)
	Net.send(level, &"_set_item_stowed_at", ["Tape", 0, out])
