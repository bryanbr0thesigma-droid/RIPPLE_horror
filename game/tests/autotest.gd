extends Node
## Scripted checks that drive the real game without a person. Run, for example:
##   godot --headless --path game -- --desktop --host --autotest=mechanics
## Scenarios: smoke, mechanics, net_host, net_client. Each prints PASS/FAIL lines and quits.

var scenario := ""
var failures := 0


func _ready() -> void:
	scenario = str(Game.args.get("autotest", "smoke"))
	print("AUTOTEST start ", scenario)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures += 1


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func wait_for(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return false


func _run() -> void:
	if scenario == "intro":
		# The first-boot tape: it plays, skipping ends it, and the menu opens with it marked seen.
		Profile.intro_seen = false
		Profile.tutorial_done = false
		Game.play_intro()
		await wait(4.0)
		var intro = get_tree().current_scene
		check(intro != null and intro.name == "Intro", "the intro scene is running")
		check(intro.video != null and intro.video.stream != null, "the tape is loaded")
		check(intro._cues.size() > 10, "subtitles loaded (%d lines)" % intro._cues.size())
		# Run the walk-in at 4x: you pick the tape up, put it in, press play and end up in the chair.
		Engine.time_scale = 4.0
		var t0 := Time.get_ticks_msec()
		while not intro._playing and Time.get_ticks_msec() - t0 < 20000:
			await get_tree().process_frame
		check(intro._playing, "the tape got picked up, put in and played")
		check(not intro.tape.visible, "the tape went into the VCR")
		await wait(10.0)
		Engine.time_scale = 1.0
		check(intro.eye.distance_to(intro.SEATED) < 0.05, "you end up sitting in the armchair")
		check(intro._hand_mode == "rest" and intro._seated, "your hands rest on the armchair while you watch")
		check(intro.body != null and intro.body.visible, "you see your own body (full-body IK)")
		intro._finish()
		await wait(4.0)
		check(Profile.intro_seen, "after the tape it is marked as seen")
		var annex := await wait_for(func(): return Game.level != null and Game.level.mode == "tutorial", 10.0)
		check(annex, "on the first launch it fades into the training annex")
		check(not Game.intro_due(), "it won't play by itself again")
		_finish()
		return
	if scenario == "menu_shot":
		var out := str(Game.args.get("out", "user://"))
		await wait(2.0)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/title_main.png" % out)
		var title = get_tree().current_scene
		for page in ["character", "play", "room", "settings", "credits"]:
			title.menu.show_page(page)
			if page == "character":
				Profile.suit = 2
				Profile.color = Color(0.85, 0.82, 0.2)
				title.menu._refresh_character()
			await wait(1.0)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/title_%s.png" % [out, page])
		for i in 2:
			Profile.suit = i
			Profile.color = [Color(0.3, 0.8, 0.35), Color(0.85, 0.25, 0.3)][i]
			title.menu.show_page("character")
			title.menu._refresh_character()
			await wait(0.8)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/title_suit%d.png" % [out, i])
		_finish()
		return
	var ok := await wait_for(func(): return Game.level != null and Game.level.local_player != null, 20.0)
	check(ok, "level loaded and local player spawned")
	if not ok:
		_finish()
		return
	match scenario:
		"smoke":
			await _smoke()
		"mechanics":
			await _mechanics()
		"net_host":
			await _net_host()
		"net_client":
			await _net_client()
		"screens":
			await _screens()
		"creature_shot":
			await _creature_shot()
		"kill_shot":
			await _kill_shot()
		"props_shot":
			await _props_shot()
		"dummy":
			await _dummy_test()
		"kill_movie":
			await _kill_movie()
		"body":
			await _body_test()
		"tutorial":
			await _tutorial_test()
		"lobby":
			await _lobby_test()
		"lobby_host":
			await _lobby_host()
		"lobby_client":
			await _lobby_client()
		"tutorial_shot", "lobby_shot":
			await _room_shots()
		"body_shot":
			await _body_shot()
	_finish()


func _finish() -> void:
	print("AUTOTEST done ", scenario, " failures=", failures)
	get_tree().quit(1 if failures > 0 else 0)


## The training annex: everything works, nothing lives in the water, and the exit finishes it.
func _tutorial_test() -> void:
	var L = Game.level
	Profile.tutorial_done = false
	check(L.mode == "tutorial", "the training annex loaded")
	check(L.creature == null and get_tree().get_nodes_in_group("creature").is_empty(), "nothing lives in its water (no creature)")
	var all_items := true
	for n in ["Flashlight", "Bottle1", "Bottle3", "Lidar", "Key", "Canteen1", "Canteen2"]:
		all_items = all_items and L.items.has(n)
	check(all_items, "it has the flashlight, bottles, lidar, key and canteens")
	check(L.lock_point.x > 24.0 and L.charger_point.x > 17.0 and L.distiller_slot.x > 31.0 and L.funnel_point.x > 31.0 and L.lever_point.x > 41.0,
		"its door, charger, distiller, generator and lever are in the annex")
	var tut = L.get_node("Tutorial")
	NoiseBus.my_noise.emit(0.8)
	await wait(0.1)
	check(tut._noise > 0.5, "the noise meter lights up when you make noise")
	L.request("unlock")
	await wait(0.5)
	check(L.state.staff_door, "the key's door opens")
	L.request("fuel", [1.0, true])
	L.request("fuel", [1.0, true])
	check(L.state.gen == 1, "two canteens start the generator")
	var running := await wait_for(func(): return L.state.gen == 2, 15.0)
	check(running and L.hall_b_lights.size() > 0 and L.hall_b_lights[0].visible, "it runs, and the cover room's lights come on")
	L.request("lever")
	await wait(0.3)
	check(L.state.cover, "with power, the lever rolls the pool cover out")
	_rig().teleport(Vector3(56.5, 0.05, 0.0))
	var done := await wait_for(func(): return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == Game.MENU_SCENE, 20.0)
	check(done and Profile.tutorial_done, "walking out the exit finishes the training and goes to the title")


## The lobby: the tape plays in the VCR, and the host's START lever begins the game.
func _lobby_test() -> void:
	var L = Game.level
	check(L.mode == "lobby", "hosting from the menu opens the lobby")
	check(L.creature == null and get_tree().get_nodes_in_group("creature").is_empty(), "no creature in the lobby")
	var lobby = L.get_node("Lobby")
	check(L.items.has("Tape") and lobby.info.text.find("Here (1/") >= 0, "the tape is on the table and the sign lists who's here")
	var tape = L.items["Tape"]
	tape.global_position = lobby.SLOT + Vector3(0, 0.02, 0.05)     # dropped on the VCR
	var playing := await wait_for(func(): return L.state.vhs, 5.0)
	check(playing and lobby.playing and tape.stowed == L.IN_VCR, "the tape goes into the VCR and plays on the TV")
	await wait(1.0)
	check(lobby.video.is_playing(), "the video is running")
	L.request("lever")
	var started := await wait_for(func(): return Game.level != null and Game.level.mode == "game" and Game.level.local_player != null, 20.0)
	check(started, "the host pulls START and the game begins")
	check(started and Game.level.creature != null, "the game has the creature")


## Pictures of each tutorial room (or the lobby), from the desktop camera.
func _room_shots() -> void:
	var out := str(Game.args.get("out", "user://"))
	var r := _rig()
	var views := []
	if Game.level.mode == "tutorial":
		views = [[Vector3(3.5, 0.05, 2.6), 0.15], [Vector3(7.6, 0.05, 2.9), -0.55], [Vector3(17.6, 0.05, 2.9), -0.65],
			[Vector3(24.7, 0.05, 1.8), -1.25], [Vector3(31.8, 0.05, -1.2), -1.25], [Vector3(41.5, 0.05, 2.9), -1.0], [Vector3(53.8, 0.05, 2.6), -0.85]]
	else:
		views = [[Vector3(0.0, 0.05, 2.5), 0.0], [Vector3(-1.6, 0.05, -1.8), -2.4], [Vector3(2.4, 0.05, 2.5), 0.9]]
	for i in views.size():
		r.teleport(views[i][0])
		r.set("_yaw", views[i][1])
		r.set("_pitch", -0.12)
		await wait(1.0)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [out, Game.level.mode, i])


func _lobby_host() -> void:
	var L = Game.level
	check(L.mode == "lobby", "host: in the lobby")
	var ok := await wait_for(func(): return L.players.size() >= 2, 30.0)
	check(ok, "host: the other player arrives in the lobby")
	await wait(2.0)
	L.request("lever")
	var started := await wait_for(func(): return Game.level != null and Game.level.mode == "game" and Game.level.players.size() >= 2, 30.0)
	check(started, "host: the game starts with both players")
	await wait(4.0)


func _lobby_client() -> void:
	var ok := await wait_for(func(): return Game.level != null and Game.level.mode == "lobby" and Game.level.players.size() >= 2, 30.0)
	check(ok, "client: joined into the lobby and sees the host")
	var started := await wait_for(func(): return Game.level != null and Game.level.mode == "game" and Game.level.players.size() >= 2, 40.0)
	check(started, "client: moved into the game along with the host")
	await wait(2.0)


## Your own body (full-body IK), its walking feet, and hands pushing the soft-body springs.
func _body_test() -> void:
	var L = Game.level
	var me = L.local_player
	await wait(1.0)
	var body: SuitRig = me.self_body
	check(body != null and body.visible, "you have your own suit body")
	var head_scale := [1.0]
	var hb: int = body.bones.get("Head", -1)
	body.skeleton.skeleton_updated.connect(func(): head_scale[0] = body.skeleton.get_bone_global_pose(hb).basis.get_scale().x)
	await wait(0.3)
	check(head_scale[0] < 0.01, "its head is hidden from your own view (scale %.3f)" % head_scale[0])
	check(SuitRig.touch_points.has("local") and SuitRig.touch_points["local"].size() == 2, "your two hands can touch soft-body bones")
	# Walk: the feet take steps.
	var r := _rig()
	var start: Vector3 = r.global_position
	var stepped := 0.0
	for i in 60:
		r.global_position = start + Vector3(0, 0, -1.0 * i / 60.0)
		await get_tree().process_frame
		stepped = maxf(stepped, body.foot_offsets[0].length())
	check(stepped > 0.08, "walking moves the feet in steps (%.2f m)" % stepped)
	await wait(1.5)
	check(body.foot_offsets[0].length() < 0.03, "standing still, the feet settle")
	# Hands push the springs: a soft-body suit, with a hand pressed against her chest.
	var other := SuitRig.create(4, Color.RED)
	L.add_child(other)
	other.global_position = start + Vector3(2.5, 0, 0)
	var tip := [Vector3.ZERO]
	var end_bone: int = other.jiggle.get_end_bone(0)
	other.skeleton.skeleton_updated.connect(func(): tip[0] = other.skeleton.global_transform * other.skeleton.get_bone_global_pose(end_bone).origin)
	await wait(0.8)
	var rest: Vector3 = tip[0]
	SuitRig.set_touch("test", [rest + Vector3(0, 0, -0.02)])
	await wait(0.4)
	var pushed: float = (tip[0] - rest).length()
	check(pushed > 0.02, "a hand pressed on it pushes it in (%.3f m)" % pushed)
	SuitRig.clear_touch("test")
	await wait(1.0)
	check((tip[0] - rest).length() < 0.01, "let go, it springs back")
	check(other.touches_jiggle(rest), "touching it counts (for the controller buzz)")
	other.queue_free()
	Profile.show_body = false
	await wait(0.2)
	check(not body.visible, "your body can be hidden in the settings")
	Profile.show_body = true


## Pictures of looking down at your own body, in each suit (desktop camera).
func _body_shot() -> void:
	var out := str(Game.args.get("out", "user://"))
	var me = Game.level.local_player
	var r := _rig()
	for s in [0, 2, 4]:
		Profile.suit = s
		me.rebuild_self_body()
		r.set("_pitch", -1.0)
		await wait(1.2)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/body_down_%d.png" % [out, s])


func _rig() -> Node3D:
	return Game.level.local_player.rig


func _smoke() -> void:
	var L = Game.level
	check(WaterVolume.all.size() >= 5, "water volumes built (%d)" % WaterVolume.all.size())
	# The secret suit: locked until its code is typed in.
	var codes_before: Array = Profile.codes.duplicate()
	Profile.codes = []
	var secret := SuitRig.SUITS.size() - 1
	check(not Profile.suit_unlocked(secret) and Profile.enter_code("12") == -1, "the secret suit is locked and a wrong code does nothing")
	check(Profile.enter_code("34") == secret and Profile.suit_unlocked(secret), "code 34 unlocks the latex diver")
	Profile.codes = codes_before
	check(L.items.keys().filter(func(n): return not n.begins_with("Bag_")).size() == 9, "items spawned (%d)" % L.items.size())
	await wait(0.5)   # let the navigation map pick up the level's region
	var nav := NavigationServer3D.map_get_closest_point(L.get_world_3d().navigation_map, Vector3(4, -1.3, -10))
	check(nav.distance_to(Vector3(4, -1.3, -10)) < 3.0, "creature navigation covers Hall A's pool")
	var path := NavigationServer3D.map_get_path(L.get_world_3d().navigation_map, Vector3(0, -1.3, -6), Vector3(25, -1.3, -42), true)
	check(path.size() > 1 and path[path.size() - 1].distance_to(Vector3(25, -1.3, -42)) < 1.5, "creature can swim from Hall A to Hall C (%d points)" % path.size())
	await wait(1.0)
	var rig := _rig()
	if Game.vr_mode:
		check(rig.body.on_ground, "VR player stands on the start room floor (y=%.2f)" % rig.feet_position().y)
		# A shorter (or seated) player: eyes at 1.2 m. They must stay on the floor, not sink through it.
		rig.camera.position.y = 1.2
		rig.teleport(Vector3(4, 0.05, 3))
		await wait(2.0)
		check(absf(rig.feet_position().y) < 0.1, "a seated or short VR player stays on the floor (feet y=%.2f)" % rig.feet_position().y)
		rig.camera.position.y = 1.7
		# On a headset the first frame can come before tracking starts (head reported at the floor).
		rig.camera.position.y = 0.0
		await get_tree().physics_frame
		await get_tree().physics_frame
		rig.camera.position.y = 1.6
		rig.teleport(Vector3(4, 0.05, 3))
		await wait(2.0)
		check(absf(rig.feet_position().y) < 0.1, "VR player stays on the floor even if tracking starts late (feet y=%.2f)" % rig.feet_position().y)
		rig.camera.position.y = 1.7
		check(not rig.body.player_calibrate_height and rig.body.head_behavior_mode == 0, "VR player uses real height and is pushed back from walls")
		check(rig.get_node("LeftHand/CollisionHandLeft").collision_mask & LevelGeometry.L_WORLD != 0, "VR hands collide with the level")
		check(rig.get_node("RightHand/CollisionHandRight/FunctionPickup").grab_collision_mask & XRToolsPickable.DEFAULT_LAYER != 0, "a hand can take hold of an item the other hand already holds")
		rig.teleport(Vector3(4, -20, 4))
		await wait(1.0)
		check(rig.feet_position().y > -1.0, "falling out of the map returns you to a checkpoint (y=%.2f)" % rig.feet_position().y)
		rig.teleport(Vector3(2, 0.5, -14))
		await wait(1.5)
		check(L.local_player.in_water, "VR player wades in Hall A's pool")
		rig.teleport(Vector3(26, 0.5, -28))
		await wait(3.0)
		var cam_y: float = rig.camera.global_position.y
		var feet_y: float = rig.feet_position().y
		check(absf(feet_y - (-0.95)) < 0.15 and cam_y > 0.4, "the pools are shallow: VR player stands on the bottom, head well above the water (feet y=%.2f, camera y=%.2f)" % [feet_y, cam_y])
		var before: Vector3 = rig.feet_position()
		rig.camera.position = Vector3(0.6, 1.7, 0.4)   # standing off-centre in the play area
		Game.recenter()
		await wait(0.5)
		var moved: float = Vector2(rig.feet_position().x - before.x, rig.feet_position().z - before.z).length()
		check(Game.recentered.is_connected(rig._on_recentered) and moved < 0.15, "holding the Meta button recenters without moving you (moved %.2f m)" % moved)
	else:
		check(rig.is_on_floor(), "desktop player stands on the start room floor")
		# The backpack: B puts what you hold in, B takes it back out.
		var fl = L.items["Flashlight"]
		rig.held = fl
		fl.grab_desktop(rig)
		await wait(0.1)
		rig._backpack()
		check(fl.stowed == Net.my_id() and not fl.visible and rig.held == null, "B puts the flashlight in the backpack")
		rig._backpack()
		check(fl.stowed == 0 and rig.held == fl and fl.visible, "B takes it back out")
		# The squeeze flashlight: each squeeze lights it, it fades unless you keep pumping.
		fl.use(true)
		fl.use(false)
		await wait(0.05)
		check(fl._light.visible, "a squeeze lights the flashlight")
		await wait(1.0)
		check(not fl._light.visible, "it goes dark unless you keep squeezing")
		var lit_all := true
		for i in 6:
			fl.use(true)
			fl.use(false)
			await wait(0.3)
			lit_all = lit_all and fl._light.visible
		check(lit_all, "pumping the trigger keeps it lit")
		rig._release(Vector3.ZERO)
		# The canteen has no physics: let go and it drops straight down, upright.
		var can = L.items["Canteen1"]
		rig.held = can
		can.grab_desktop(rig)
		await wait(0.1)
		rig.held = null
		can.desktop_holder = null
		can.global_transform = Transform3D(Basis(Vector3.RIGHT, 1.2), Vector3(3.0, 1.3, 1.0))
		await get_tree().physics_frame
		await get_tree().physics_frame
		can.release_desktop(Vector3(3, 0, 0))
		await wait(1.2)
		check(absf(can.global_position.x - 3.0) < 0.01 and can.global_position.y < 0.3 and can.global_transform.basis.y.dot(Vector3.UP) > 0.99,
			"a dropped canteen falls straight down and stands upright (at %s, up %.3f)" % [can.global_position, can.global_transform.basis.y.dot(Vector3.UP)])
		# Dying alone: back at the checkpoint, and my bag floats where I died with what I carried.
		rig._release(Vector3.ZERO)
		var fl2 = L.items["Flashlight"]
		rig.teleport(Vector3(2.0, 0.5, -6.0))          # in Hall A's pool
		await wait(1.0)
		rig.held = fl2
		fl2.grab_desktop(rig)
		await wait(0.2)
		L.player_caught(Net.my_id(), 0, L.creature.K.HALVES)
		var respawned := await wait_for(func(): return L.local_player.alive, 10.0)
		check(respawned and not L.local_player.ghost, "dying alone: straight back at the checkpoint, not a ghost")
		var my_bag = L.items["Bag_%d" % Net.my_id()]
		await wait(1.0)
		check(my_bag.visible and fl2.stowed == -Net.my_id() and my_bag.global_position.distance_to(Vector3(2.0, -0.35, -6.0)) < 0.6,
			"my bag floats where I died, with the flashlight in it (bag at %s)" % my_bag.global_position)
		rig.teleport(my_bag.global_position + Vector3(0, 0.3, 0.6))
		await wait(0.3)
		rig.held = my_bag
		my_bag.grab_desktop(rig)
		var got_back := await wait_for(func(): return fl2.stowed == Net.my_id() and not my_bag.visible, 5.0)
		check(got_back, "grabbing my bag puts the flashlight back in my backpack")
		rig.held = null


## Single-player run through every mechanic, moving the player and items directly.
func _mechanics() -> void:
	var L = Game.level
	var rig := _rig()
	var C = L.creature
	await wait(0.5)

	# Falling into Hall A's pool is loud: the creature charges.
	rig.teleport(Vector3(2, 2.5, -14))
	var charged := await wait_for(func(): return C.state == C.S.CHARGE, 6.0)
	check(charged, "falling in makes the creature charge")
	# Stand perfectly still: when it arrives it searches by feel.
	var searched := await wait_for(func(): return C.state == C.S.SEARCH or C.state == C.S.ATTACK, 20.0)
	check(searched, "standing still makes it search (or the 30% catch)")
	# Moving during a search gives you away.
	if C.state == C.S.SEARCH:
		await wait(0.3)
		rig.teleport(rig.feet_position() + Vector3(0.3, 0, 0))
		var caught := await wait_for(func(): return not L.local_player.alive, 3.0)
		check(caught, "moving during the search gets you caught")
	await wait_for(func(): return L.local_player.alive, 8.0)
	check(L.local_player.alive, "respawned after being caught")

	# Key to the lock opens the staff door.
	var key = L.items["Key"]
	rig.teleport(Vector3(15.0, 0.05, -5.5))
	await wait(0.3)
	rig.held = key
	key.grab_desktop(rig)
	await wait(0.2)
	key.global_position = L.lock_point
	key.try_unlock()
	var opened := await wait_for(func(): return L.state.staff_door, 3.0)
	check(opened, "the key opens the staff door")
	check(key.retired, "the key is used up")
	rig.held = null

	# Fill a canteen in the mineral water, then pour it into the generator, twice.
	for cname in ["Canteen1", "Canteen2"]:
		var can = L.items[cname]
		rig.teleport(Vector3(-6.2, 0.05, -33.0))
		await wait(0.2)
		rig.held = can
		can.grab_desktop(rig)
		can.desktop_holder = null   # hold it in place by hand for the test
		can.freeze = true
		can.global_transform = Transform3D(Basis(), Vector3(-6.0, -0.6, -36.0))
		await wait(0.5)
		check(can.fill < 0.01, "%s doesn't fill until you click" % cname)
		can.use(true)
		can.use(false)
		var filled := await wait_for(func(): return can.fill >= 0.999 and can.mineral, 6.0)
		check(filled, "%s fills with mineral water" % cname)
		can.global_transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(150)), L.funnel_point + Vector3(0, 0.4, 0))
		var poured := await wait_for(func(): return can.fill <= 0.0, 8.0)
		check(poured, "%s pours out" % cname)
		can.global_transform = Transform3D(Basis(), Vector3(11.5, 0.6, -43.0))
		can.release_desktop(Vector3.ZERO)
		rig.held = null
		await wait(0.5)
	check(L.state.fuel >= 1.99, "two canteens fill the generator (fuel %.2f)" % L.state.fuel)
	var running := await wait_for(func(): return L.state.gen == 2, 15.0)
	check(running, "the generator starts and runs")
	check(L.hall_b_lights[0].visible, "the dark sector's lights come on")

	# Pull the lever: the pool cover extends.
	rig.teleport(Vector3(17.0, 0.05, -34.5))
	await wait(0.3)
	L.get_node("Props/LeverHandle").pull()
	var cover := await wait_for(func(): return L.state.cover and L.cover_amount > 0.99, 10.0)
	check(cover, "the lever extends the pool cover")
	# Walk across it to the exit.
	rig.teleport(Vector3(30.0, 0.4, -36.0))
	await wait(1.0)
	check(rig.feet_position().y > -0.2, "you can stand on the pool cover (y=%.2f)" % rig.feet_position().y)
	rig.teleport(Vector3(41.0, 0.05, -36.0))
	var escaped := await wait_for(func(): return L.state.all_escaped, 3.0)
	check(escaped, "reaching the exit ends the level")


func _net_host() -> void:
	var L = Game.level
	var ok := await wait_for(func(): return L.players.size() >= 2, 30.0)
	check(ok, "host sees the client's player")
	if not ok:
		return
	var other_id := 0
	for id in L.players:
		if id != 1:
			other_id = id
	var moved := await wait_for(func(): return L.players[other_id].body_position().distance_to(Vector3(2, 0, -14)) < 3.0, 10.0)
	check(moved, "host sees the client walk into Hall A")
	var charged := await wait_for(func(): return L.creature.state == L.creature.S.CHARGE, 12.0)
	check(charged, "the client's fall makes the host's creature charge")
	var bottle = L.items["Bottle1"]
	var picked := await wait_for(func(): return bottle.holder == other_id, 10.0)
	check(picked, "host sees the client pick up a bottle")
	await wait(1.0)
	# Giving: the host takes the bottle out of the client's hand.
	var rig := _rig()
	rig.teleport(bottle.global_position + Vector3(0, -0.5, 0.6))
	if rig.has_method("hold_transform_for"):
		rig.held = bottle
		bottle.grab_desktop(rig)
	else:
		bottle._on_xr_picked_up(null)   # what an XR Tools grab does
	var given := await wait_for(func(): return bottle.holder == 1, 5.0)
	check(given, "the host can take the bottle from the client's hand")
	await wait(2.0)
	# Shoving: push the client sideways.
	L.push_player(other_id, Vector3(4, 0.5, 0))
	await wait(4.0)
	# Death in co-op: the client dies with me alive, so it's a ghost and its things float in its bag.
	rig.teleport(Vector3(4, 0.05, 5))
	var flash = L.items["Flashlight"]
	var has_fl := await wait_for(func(): return flash.holder == other_id, 15.0)
	check(has_fl, "host sees the client pick up the flashlight")
	await wait(1.5)     # the client steps out into Hall A first: deaths happen out there, not in dry rooms
	L.player_caught(other_id, 0, L.creature.K.HALVES)
	var ghosted := await wait_for(func(): return L.players[other_id].net_ghost, 10.0)
	check(ghosted, "the dead client comes back as a ghost (a teammate is still alive)")
	var bag = L.items["Bag_%d" % other_id]
	check(bag.visible and flash.stowed == -other_id, "its flashlight is in its bag, floating where it died (flash stowed %d holder %d, bag visible %s stowed %d)" % [flash.stowed, flash.holder, bag.visible, bag.stowed])
	# I walk out of the start room and back in: the ghost comes back to life here.
	rig.teleport(Vector3(4, 0.05, -1.0))
	await wait(1.0)
	rig.teleport(Vector3(4, 0.05, 5))
	var back := await wait_for(func(): return not L.players[other_id].net_ghost and L.players[other_id].net_alive, 8.0)
	check(back, "a living teammate reaching a dry room brings the ghost back")
	var returned := await wait_for(func(): return flash.stowed == other_id and not bag.visible, 5.0)
	check(returned, "the ghost's things go back into its backpack")
	await wait(2.0)


func _net_client() -> void:
	var L = Game.level
	var ok := await wait_for(func(): return L.players.size() >= 2, 20.0)
	check(ok, "client sees the host's player")
	var rig := _rig()
	rig.teleport(Vector3(2, 0.05, -1))
	await wait(1.0)
	rig.teleport(Vector3(2, 2.5, -14))
	var heard := await wait_for(func(): return L.creature.state == L.creature.S.CHARGE, 12.0)
	check(heard, "client sees the creature charge after its own fall")
	var bottle = L.items["Bottle1"]
	if rig.has_method("hold_transform_for"):
		rig.held = bottle
		bottle.grab_desktop(rig)
	else:
		bottle._on_xr_picked_up(null)   # what an XR Tools grab does
	var owned := await wait_for(func(): return bottle.holder == Net.my_id(), 5.0)
	check(owned, "client holds the bottle")
	var taken := await wait_for(func(): return bottle.holder == 1, 10.0)
	check(taken and (not rig.has_method("hold_transform_for") or rig.held == null), "the host took the bottle out of the client's hand")
	rig.teleport(Vector3(2, 0.05, -1))
	await wait(0.5)
	var before: Vector3 = rig.feet_position()
	var shoved := await wait_for(func(): return rig.feet_position().distance_to(before) > 0.3, 8.0)
	check(shoved, "the host's shove moves the client")
	await wait(1.0)
	# Pick up the flashlight; the host has me killed while it's alive.
	var fl = L.items["Flashlight"]
	rig.teleport(Vector3(3.2, 0.05, 2.4))
	await wait(0.3)
	if rig.has_method("hold_transform_for"):
		rig.held = fl
		fl.grab_desktop(rig)
	else:
		fl._on_xr_picked_up(null)
	await wait(0.3)
	rig.teleport(Vector3(2, 0.05, -1))      # out of the dry room, into Hall A
	var dead := await wait_for(func(): return L.local_player.ghost, 25.0)
	check(dead, "killed with the host alive, I'm a ghost")
	check(fl.stowed == -Net.my_id(), "what I carried is in my bag")
	var alive_again := await wait_for(func(): return L.local_player.alive and not L.local_player.ghost, 20.0)
	check(alive_again, "the host reaching a dry room brings me back")
	var mine := await wait_for(func(): return fl.stowed == Net.my_id(), 5.0)
	check(mine, "my things came back to my backpack")
	await wait(1.0)


## Screenshots from fixed viewpoints (needs a display: run under xvfb-run without --headless).
func _screens() -> void:
	var L = Game.level
	var rig := _rig()
	var out := str(Game.args.get("out", "user://"))
	var shots := [
		["start", Vector3(4, 0.05, 4.0), 180.0, -5.0],
		["hall_a", Vector3(-7, 0.05, -1), -40.0, -12.0],
		["hall_a_island", Vector3(-5.5, 0.05, -9.5), 270.0, -10.0],
		["staff", Vector3(17, 0.05, -1), 307.0, -12.0],
		["generator", Vector3(7.5, 0.05, -43.0), 300.0, -10.0],
		["exit", Vector3(39, 0.05, -33), 344.0, -5.0],
		["hall_b_dark", Vector3(3, 0.05, -23), 0.0, -8.0],
		["hall_c", Vector3(17, 0.05, -38.5), 270.0, -6.0],
	]
	L.creature.set_physics_process(false)
	L.creature._play_anim("search")
	L.creature.global_position = Vector3(4, -0.95, -12)
	for s in shots:
		rig.teleport(s[1])
		rig._yaw = deg_to_rad(s[2])
		rig._pitch = deg_to_rad(s[3])
		await wait(0.6)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, s[0]])
		print("SHOT ", s[0])
	# The creature up close, from the walkway.
	rig.teleport(Vector3(4, 0.05, -1.2))
	rig._yaw = deg_to_rad(0)
	rig._pitch = deg_to_rad(-30)
	L.creature.global_position = Vector3(4, -0.95, -5.5)
	await wait(0.6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/creature.png" % out)
	# The dark sector through the lidar.
	var lidar = L.items["Lidar"]
	rig.teleport(Vector3(3, 0.05, -23.2))
	rig._yaw = deg_to_rad(0)
	rig._pitch = deg_to_rad(-12)
	L.creature.global_position = Vector3(3, -0.95, -31)
	rig.held = lidar
	lidar.grab_desktop(rig)
	await wait(0.3)
	lidar.use(true)
	for i in 60:
		lidar.global_transform = Transform3D(rig.cam.global_transform.basis, rig.cam.global_position + Vector3(0, -0.15, 0))
		lidar.basis = rig.cam.global_transform.basis.rotated(Vector3.UP, randf_range(-0.5, 0.5))
		await get_tree().physics_frame
	lidar.use(false)
	await wait(0.2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/lidar.png" % out)
	# Hall B with the lights on.
	L.set_state("gen", 2)
	rig.teleport(Vector3(3, 0.05, -23))
	await wait(0.6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/hall_b_lit.png" % out)
	# Hall C with the cover out.
	L.set_state("cover", true)
	L.cover_amount = 1.0
	rig.teleport(Vector3(17, 0.05, -36))
	rig._yaw = deg_to_rad(270)
	rig._pitch = deg_to_rad(-8)
	await wait(0.6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/hall_c_cover.png" % out)
	print("SHOTS done")


func _creature_shot() -> void:
	var L = Game.level
	var rig := _rig()
	var out := str(Game.args.get("out", "user://"))
	var C = L.creature
	C.set_physics_process(false)
	C._play_anim("walk")
	C.global_position = Vector3(4, 0.3, -6.0)
	rig.teleport(Vector3(4, 0.05, -1.5))
	rig._yaw = 0.0
	rig._pitch = deg_to_rad(-10)
	await wait(0.8)
	var vis := 0
	for mi in C.model.find_children("*", "MeshInstance3D", true, false):
		vis += 1
		print("CMESH ", mi.name, " visible=", mi.is_visible_in_tree(), " aabb=", mi.global_transform * mi.get_aabb(), " skel=", mi.skeleton)
	print("CREATURE pos ", C.global_position, " model scale ", C.model.scale, " meshes ", vis)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/creature_dry.png" % out)


## Renders the creature wading beside a player (for scale), both kills seen by a teammate, and
## both from the victim's own eyes.
func _kill_shot() -> void:
	var L = Game.level
	var rig := _rig()
	var out := str(Game.args.get("out", "user://"))
	var C = L.creature
	C.set_physics_process(false)
	var shoot := func(file: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, file])
		print("SHOT ", file)
	# Steps the creature's kill a fixed 1/30 s per frame (this renderer is slow), shooting at kill times.
	var run := func(marks: Dictionary, until: float, extra: Callable) -> void:
		var done := {}
		var t := 0.0
		while t < until:
			C._update_presentation(1.0 / 30.0)
			extra.call(t)
			await get_tree().process_frame
			t += 1.0 / 30.0
			for m in marks.keys():
				if t >= m and not done.has(m):
					done[m] = true
					await shoot.call(marks[m])
	var mate_at := func(id: int, suit: int, col: Color, at: Vector3) -> Node:
		L._spawn_player(id, {"name": "Teammate", "suit": suit, "color": col}, at)
		var m = L.players[id]
		var down := Basis(Vector3.RIGHT, -PI * 0.5)
		for k in 3:
			m.avatar.set_target(Transform3D(Basis(Vector3.UP, PI * 0.5), at + Vector3.UP * 1.62),
				Transform3D(down, at + Vector3(0, 0.85, 0.25)), Transform3D(down, at + Vector3(0, 0.85, -0.25)), at, k < 2)
			await get_tree().process_frame
		return m
	# 1. Wading past a teammate, slowly.
	var mate = await mate_at.call(99, 1, Color(0.2, 0.6, 0.95), Vector3(5, -0.95, -6))
	rig.teleport(Vector3(5.5, 0.05, -1.0))
	rig._yaw = deg_to_rad(10)
	rig._pitch = deg_to_rad(-2)
	C.global_position = Vector3(8.5, -0.95, -6.8)
	C.rotation.y = -PI * 0.5
	C._last_pos = C.global_position
	C.state = C.S.PATROL
	await run.call({1.6: "wade_scale"}, 1.7, func(_t):
		C._speed_now = 0.7
		C.global_position += Vector3(-0.7 * get_process_delta_time(), 0, 0))
	C._speed_now = 0.0
	# 2. The head rip, from the walkway.
	C.global_position = Vector3(6.6, -0.95, -6.0)
	C.rotation.y = -PI * 0.5
	rig.teleport(Vector3(5.8, 0.05, -2.3))
	rig._yaw = deg_to_rad(0)
	rig._pitch = deg_to_rad(4)
	C.play_kill(mate, 3, C.K.HEAD_RIP)
	await run.call({0.9: "rip_1_grab", 1.25: "rip_2_pull", 1.6: "rip_3_off", 2.2: "rip_4_lift", 2.6: "rip_5_bite", 3.4: "rip_6_thrown", 6.5: "rip_7_after"}, 6.6, func(t):
		if t > 5.5:
			rig.teleport(Vector3(5.2, 0.05, -2.4))
			rig._pitch = deg_to_rad(-38))
	# 3. Torn in half, elsewhere.
	var mate2 = await mate_at.call(98, 0, Color(0.9, 0.45, 0.15), Vector3(10.0, -0.95, -5.0))
	C.global_position = Vector3(11.6, -0.95, -5.0)
	C.rotation.y = -PI * 0.5
	rig.teleport(Vector3(10.6, 0.05, -1.0))
	rig._yaw = deg_to_rad(0)
	rig._pitch = deg_to_rad(-14)
	C.play_kill(mate2, 5, C.K.HALVES)
	await run.call({0.9: "half_1_grab", 1.55: "half_2_tear", 1.85: "half_3_apart", 2.4: "half_4_drop", 3.0: "half_5_hold", 3.8: "half_6_thrown", 6.5: "half_7_after"}, 6.6, func(t):
		if t > 5.5:
			rig.teleport(Vector3(10.4, 0.05, -1.4))
			rig._pitch = deg_to_rad(-40))
	# 4. The victim's own eyes during the spine kill: its hand on your head, vision blurring.
	rig.teleport(Vector3(2.0, -0.9, -15.0))
	rig._yaw = deg_to_rad(0)
	rig._pitch = deg_to_rad(8)
	await wait(0.5)
	C.global_position = Vector3(2.0, -0.95, -16.4)
	C.rotation.y = 0.0
	C._last_pos = C.global_position
	C.play_kill(L.local_player, 0, C.K.HEAD_RIP)
	var blur: MeshInstance3D = Gore.blur_overlay(rig.cam)
	await run.call({1.0: "victim_rip_clear"}, 1.05, func(_t2): pass)
	blur.material_override.set_shader_parameter("amount", 0.5)
	await run.call({0.05: "victim_rip_blur"}, 0.1, func(_t2): pass)
	blur.material_override.set_shader_parameter("amount", 1.0)
	await run.call({0.05: "victim_rip_blur2"}, 0.1, func(_t2): pass)
	blur.queue_free()
	C._end_kill()
	print("KILLSHOTS done")


## Renders the approved props where they stand, and the items up close.
func _props_shot() -> void:
	var L = Game.level
	var rig := _rig()
	var out := str(Game.args.get("out", "user://"))
	L.creature.set_physics_process(false)
	L.creature.global_position = Vector3(30, -0.95, -44)
	var views := [
		["p_staff_door", Vector3(13.5, 0.05, -5.0), -90.0, 0.0],
		["p_ladder", Vector3(-4.6, 0.05, -14.0), 90.0, -35.0],
		["p_ladder_side", Vector3(-4.2, 0.05, -11.6), 37.0, -22.0],
		["p_lever", Vector3(17.9, 0.05, -32.2), 60.0, -25.0],
		["p_exit", Vector3(40.0, 0.05, -36.0), -90.0, 0.0],
		["p_bunker", Vector3(4.0, 0.05, 3.0), -90.0, -5.0],
		["p_generator", Vector3(7.0, 0.05, -43.0), -60.0, -15.0],
		["p_distiller", Vector3(20.2, 0.05, -5.0), 8.0, -14.0],
		["p_staff_table", Vector3(19.0, 0.05, -4.8), -144.0, -18.0],
		["p_charger", Vector3(21.0, 0.05, -5.0), -54.0, -18.0],
		["p_mineral", Vector3(-6.2, 0.05, -31.0), 0.0, -32.0],
	]
	for v in views:
		rig.teleport(v[1])
		rig._yaw = deg_to_rad(v[2])
		rig._pitch = deg_to_rad(v[3])
		await wait(0.5)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, v[0]])
	# Items lined up on the start room floor.
	rig.teleport(Vector3(4, 0.05, 6.5))
	rig._yaw = 0.0
	rig._pitch = deg_to_rad(-38)
	var x := 3.3
	for n in ["Key", "Canteen1", "Lidar", "Bottle1", "Bottle2", "Bottle3", "Bottle4"]:
		var it = L.items[n]
		it.freeze = true
		it.global_transform = Transform3D(Basis(), Vector3(x, 0.15, 5.6))
		x += 0.24
	await wait(0.6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/p_items.png" % out)
	# The test dummy, dropped into Hall A.
	rig.teleport(Vector3(4, 0.05, -1.0))
	rig._yaw = 0.0
	rig._pitch = deg_to_rad(-10)
	await wait(0.3)
	L.spawn_dummy(rig.cam.global_transform)
	await wait(1.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/p_dummy.png" % out)
	print("PROPSHOTS done")


## The test dummy: dropped in, the creature comes for it and kills it, and it's cleaned up after.
func _dummy_test() -> void:
	var L = Game.level
	var rig := _rig()
	rig.teleport(Vector3(4, 0.05, -1.0))
	rig._yaw = 0.0
	await wait(0.3)
	L.spawn_dummy(rig.cam.global_transform)
	var spawned := await wait_for(func(): return L.players.size() == 2, 3.0)
	check(spawned, "Ctrl+Shift+P drops a test dummy")
	var dummy_id := 0
	for id in L.players:
		if id >= 900:
			dummy_id = id
	check(dummy_id > 0 and L.players[dummy_id].is_in_water(), "the dummy is in the water ahead")
	var killed := await wait_for(func(): return L.creature.state == L.creature.S.ATTACK and L.creature._attack_peer == dummy_id, 40.0)
	check(killed, "the creature finds the fidgeting dummy and kills it")
	var feasting := await wait_for(func(): return L.creature.state == L.creature.S.FEAST, 8.0)
	check(feasting, "then it feasts on the remains")
	NoiseBus.make(Vector3(6, -0.3, -8), 0.9, "fall")
	await wait(1.0)
	check(L.creature.state == L.creature.S.FEAST, "while feasting it ignores even a loud splash")
	var gone := await wait_for(func(): return not L.players.has(dummy_id), 6.0)
	check(gone, "the dummy is removed after")
	var done := await wait_for(func(): return L.creature.state != L.creature.S.FEAST, 12.0)
	check(done, "the feeding lasts at most 10 seconds")


## For review clips, run with Godot's movie writer (fixed 30 fps, sound included):
##   godot --path game --write-movie out.avi --fixed-fps 30 -- --desktop --host --autotest=kill_movie
## Prints "CLIP name start end" (seconds into the movie) for cutting it up.
func _kill_movie() -> void:
	var L = Game.level
	var rig := _rig()
	var C = L.creature
	C.set_physics_process(false)
	await wait(1.2)                                   # past the start-of-level warm-up
	var clock := [0.0]
	var step := func(n: int, extra: Callable) -> void:
		for i in n:
			C._update_presentation(1.0 / 30.0)
			extra.call(i / 30.0)
			await get_tree().process_frame
			clock[0] += 1.0 / 30.0
	var clip := func(name: String, n: int, extra: Callable) -> void:
		var t0: float = clock[0] + 1.2
		await step.call(n, extra)
		print("CLIP %s %.2f %.2f" % [name, t0, clock[0] + 1.2])
	var mate_at := func(id: int, suit: int, col: Color, at: Vector3, face: float) -> Node:
		L._spawn_player(id, {"name": "Teammate", "suit": suit, "color": col}, at)
		var m = L.players[id]
		var b := Basis(Vector3.UP, face)
		var down := Basis(Vector3.RIGHT, -PI * 0.5)
		for k in 3:
			m.avatar.set_target(Transform3D(b, at + Vector3.UP * 1.62), Transform3D(b * down, at + Vector3.UP * 0.85 - b.x * 0.25),
				Transform3D(b * down, at + Vector3.UP * 0.85 + b.x * 0.25), at, true)
			await get_tree().process_frame
		return m
	var noop := func(_t): pass
	# Stand on the walkway at `feet` and look at `at`.
	var cam: Camera3D = rig.get("cam") if rig.get("cam") else rig.get("camera")
	var aim := func(feet: Vector3, at: Vector3) -> void:
		cam.fov = 42.0                                 # zoomed in a little, for the clips
		rig.teleport(feet)
		var d: Vector3 = at - (feet + Vector3.UP * 1.62)
		rig._yaw = atan2(-d.x, -d.z)
		rig._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	# 1. Wading past, from the walkway.
	aim.call(Vector3(5.0, 0.05, -0.6), Vector3(7.2, 0.6, -4.6))
	C.global_position = Vector3(10.5, -0.95, -4.6)
	C.rotation.y = -PI * 0.5
	C._yaw = C.rotation.y
	C._last_pos = C.global_position
	C.state = C.S.PATROL
	C._speed_now = 0.7
	await clip.call("wade", 210, func(_t): C.global_position += Vector3(-0.7 / 30.0, 0, 0))
	C._speed_now = 0.0
	# 2. Head and spine.
	var m1 = await mate_at.call(99, 1, Color(0.2, 0.6, 0.95), Vector3(5.0, -0.95, -4.4), PI * 0.5)
	C.global_position = Vector3(6.15, -0.95, -4.4)
	C.rotation.y = -PI * 0.5
	C._last_pos = C.global_position
	aim.call(Vector3(5.2, 0.05, -1.9), Vector3(5.6, 0.75, -4.4))
	C.play_kill(m1, 1, C.K.HEAD_RIP)
	await clip.call("kill_spine", 160, noop)
	# 3. Split down the middle.
	var m2 = await mate_at.call(98, 0, Color(0.9, 0.45, 0.15), Vector3(10.0, -0.95, -4.5), 0.0)
	C.global_position = Vector3(10.0, -0.95, -3.35)     # between us and them, so we see their front
	C.rotation.y = PI
	C._last_pos = C.global_position
	aim.call(Vector3(12.7, 0.05, -1.9), Vector3(10.0, 0.75, -4.4))
	C.play_kill(m2, 0, C.K.SPLIT)
	await clip.call("kill_split", 150, noop)
	# 4. Torn in half at the waist, then it feeds.
	var m3 = await mate_at.call(97, 2, Color(0.6, 0.6, 0.6), Vector3(1.5, -0.95, -4.4), PI * 0.5)
	C.global_position = Vector3(2.65, -0.95, -4.4)
	C.rotation.y = -PI * 0.5
	C._last_pos = C.global_position
	aim.call(Vector3(2.0, 0.05, -1.9), Vector3(2.1, 0.75, -4.4))
	C.play_kill(m3, 2, C.K.HALVES)
	await clip.call("kill_halves", 150, noop)
	await step.call(10, noop)                         # the kill ends
	C.state = C.S.FEAST
	aim.call(Vector3(3.6, 0.05, -1.9), Vector3(2.4, -0.2, -4.4))
	await clip.call("feed", 240, noop)
	C.state = C.S.LINGER
	await step.call(20, noop)
	# 5. A charge across the pool and the screech lasting all the way.
	C.global_position = Vector3(12.0, -0.95, -14.0)
	C.rotation.y = -PI * 0.75
	C._yaw = C.rotation.y
	C._last_pos = C.global_position
	aim.call(Vector3(2.0, 0.05, -0.8), Vector3(5.0, 0.4, -9.0))
	cam.fov = 60.0
	C.state = C.S.CHARGE
	C._speed_now = 6.5
	var dir := (Vector3(-2.0, 0, -4.0) - Vector3(12.0, 0, -14.0)).normalized()
	C.rotation.y = atan2(dir.x, dir.z)
	await clip.call("charge", 150, func(t):
		if t < 3.0:
			C.global_position += dir * 4.5 / 30.0
		elif C.state == C.S.CHARGE:
			C._speed_now = 0.0
			C.state = C.S.LINGER)
