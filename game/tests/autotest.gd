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
	if scenario == "menu_shot":
		await wait(1.5)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/menu.png" % str(Game.args.get("out", "user://")))
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
	_finish()


func _finish() -> void:
	print("AUTOTEST done ", scenario, " failures=", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _rig() -> Node3D:
	return Game.level.local_player.rig


func _smoke() -> void:
	var L = Game.level
	check(WaterVolume.all.size() >= 5, "water volumes built (%d)" % WaterVolume.all.size())
	check(L.items.size() == 8, "items spawned (%d)" % L.items.size())
	await wait(0.5)   # let the navigation map pick up the level's region
	var nav := NavigationServer3D.map_get_closest_point(L.get_world_3d().navigation_map, Vector3(4, -1.3, -10))
	check(nav.distance_to(Vector3(4, -1.3, -10)) < 3.0, "creature navigation covers Hall A's pool")
	var path := NavigationServer3D.map_get_path(L.get_world_3d().navigation_map, Vector3(0, -1.3, -6), Vector3(25, -1.3, -42), true)
	check(path.size() > 1 and path[path.size() - 1].distance_to(Vector3(25, -1.3, -42)) < 1.5, "creature can swim from Hall A to Hall C (%d points)" % path.size())
	await wait(1.0)
	var rig := _rig()
	if Game.vr_mode:
		check(rig.body.on_ground, "VR player stands on the start room floor (y=%.2f)" % rig.feet_position().y)
		rig.teleport(Vector3(2, 0.5, -14))
		await wait(1.5)
		check(L.local_player.in_water, "VR player wades in Hall A's pool")
		rig.teleport(Vector3(26, 0.5, -28))
		await wait(3.0)
		var cam_y: float = rig.camera.global_position.y
		check(absf(cam_y - (-0.3 + 0.15)) < 0.35, "VR player floats in the deep pool with the head at the surface (camera y=%.2f)" % cam_y)
	else:
		check(rig.is_on_floor(), "desktop player stands on the start room floor")


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
	var given := await wait_for(func(): return bottle.holder == 1, 5.0)
	check(given, "the host can take the bottle from the client's hand")
	await wait(2.0)
	# Shoving: push the client sideways.
	L.push_player(other_id, Vector3(4, 0.5, 0))
	await wait(4.0)


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
	rig.held = bottle
	bottle.grab_desktop(rig)
	var owned := await wait_for(func(): return bottle.holder == Net.my_id(), 5.0)
	check(owned, "client holds the bottle")
	var taken := await wait_for(func(): return bottle.holder == 1, 10.0)
	check(taken and rig.held == null, "the host took the bottle out of the client's hand")
	rig.teleport(Vector3(2, 0.05, -1))
	await wait(0.5)
	var before: Vector3 = rig.feet_position()
	var shoved := await wait_for(func(): return rig.feet_position().distance_to(before) > 0.3, 8.0)
	check(shoved, "the host's shove moves the client")
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
		["staff", Vector3(17, 0.05, -1), 135.0, -15.0],
		["hall_b_dark", Vector3(3, 0.05, -23), 0.0, -8.0],
		["hall_c", Vector3(17, 0.05, -38.5), 270.0, -6.0],
	]
	L.creature.set_physics_process(false)
	L.creature._play_anim("search")
	L.creature.global_position = Vector3(4, -1.05, -12)
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
	L.creature.global_position = Vector3(4, -1.05, -5.5)
	await wait(0.6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/creature.png" % out)
	# The dark sector through the lidar.
	var lidar = L.items["Lidar"]
	rig.teleport(Vector3(3, 0.05, -23.2))
	rig._yaw = deg_to_rad(0)
	rig._pitch = deg_to_rad(-12)
	L.creature.global_position = Vector3(3, -1.05, -31)
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
