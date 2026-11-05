extends Node3D
## The F.A.L.C.O.N. Training Annex: the tutorial after the first-boot tape (also on the Play page).
## A row of small tiled rooms going east, each teaching one thing with a sign on the wall, built
## from the same mechanics as the Shallow Halls but with nothing in the water:
##   1 controls and the flashlight     2 wading quietly (a noise meter on the wall)
##   3 throwing, the backpack, the lidar     4 a dark room: find the key with the lidar
##   5 the locked door, mineral water, canteens, the distiller and the generator
##   6 the pool cover and its lever (lights and lever need the power)     7 freezing, teammates, exit

const SURFACE := -0.3
const FLOOR := -0.95
const H := 3.2                 # ceiling height
const Z0 := -3.5               # every room runs z -3.5..3.5
const Z1 := 3.5
const DOOR := [[-1.0, 1.0, 2.4]]
const LOCKED := [[-0.64, 0.64, 2.15]]

var level: Node3D
var G: LevelGeometry
var meter: Array[MeshInstance3D] = []
var _noise := 0.0


func build(lv: Node3D) -> void:
	level = lv
	G = lv.G
	var env: Environment = lv.world_env.environment
	env.ambient_light_energy = 0.05
	_room_controls()
	_room_water()
	_room_throw()
	_room_dark()
	_room_power()
	_room_cover()
	_room_final()
	var spawns: Array[Vector3] = [Vector3(1.5, 0.05, 0.0), Vector3(1.5, 0.05, 1.5), Vector3(1.5, 0.05, -1.5), Vector3(2.8, 0.05, 0.8)]
	lv.spawn_points = spawns
	lv.zones = [
		{"name": "controls", "rect": Rect2(0, Z0, 7, 7), "amb": "halls", "checkpoint": Vector3(1.5, 0.05, 0.0)},
		{"name": "water", "rect": Rect2(7, Z0, 10, 7), "amb": "halls"},
		{"name": "throw", "rect": Rect2(17, Z0, 7, 7), "amb": "halls", "checkpoint": Vector3(18.0, 0.05, 0.0)},
		{"name": "dark", "rect": Rect2(24, Z0, 7, 7), "amb": "dark"},
		{"name": "power", "rect": Rect2(31, Z0, 10, 7), "amb": "halls", "checkpoint": Vector3(32.0, 0.05, -1.0)},
		{"name": "cover", "rect": Rect2(41, Z0, 12, 7), "amb": "dark"},
		{"name": "final", "rect": Rect2(53, Z0, 6, 7), "amb": "halls", "exit": true},
	]
	NoiseBus.my_noise.connect(_on_my_noise)


# --- The rooms -----------------------------------------------------------------------------------

func _shell(x0: float, x1: float, doors: Dictionary) -> void:
	G.walls(x0, x1, Z0, Z1, 0.0, H, doors)
	G.ceiling(x0, x1, Z0, Z1, H)


func _sign(text: String, pos: Vector3, facing: float, size := 0.0024) -> void:
	G.plaque(text, pos, facing, size)


func _table(at: Vector3) -> void:
	level._hidden_block(at.x - 0.94, at.x + 0.94, 0.0, 0.85, at.z - 0.47, at.z + 0.47)
	level._prop("res://assets/props/staff_desk.glb", at, 90.0)


func _room_controls() -> void:
	G.floor_slab(0, 7, Z0, Z1)
	_shell(0, 7, {"e": DOOR})
	G.light(Vector3(3.5, H - 0.15, 0.0), 1.2, 9.0)
	_sign("F.A.L.C.O.N. TRAINING ANNEX\n\nPractice only: nothing lives in this water.\n\nMOVE: left stick (VR) or W A S D.\nTURN: right stick, or the mouse.\nGRAB: grip (VR) or E.\nUSE what you're holding: trigger, or left mouse.\nDROP: let go, or Q.", Vector3(3.5, 1.75, Z0 + 0.03), 0.0)
	_sign("Pick up the FLASHLIGHT on the table. It only lights while you squeeze the trigger (or hold left mouse).\n\nBACKPACK: reach over your shoulder and let go (VR), or press B. It holds 3 things. Reach back there (or press B with empty hands) to take one out.", Vector3(0.03, 1.7, 0.0), 90.0, 0.0019)
	_table(Vector3(3.5, 0.0, -2.6))
	level._spawn_item("flashlight", "Flashlight", Vector3(3.5, 0.92, -2.6))


func _room_water() -> void:
	G.floor_slab(7, 8, Z0, Z1)
	G.floor_slab(16, 17, Z0, Z1)
	G.pool(8, 16, Z0, Z1, FLOOR, SURFACE)
	_shell(7, 17, {"w": DOOR, "e": DOOR})
	G.ladder(Vector3(8, FLOOR, 1.6), Vector3(1, 0, 0), 0.0)
	G.ladder(Vector3(16, FLOOR, -1.6), Vector3(-1, 0, 0), 0.0)
	G.light(Vector3(10.0, H - 0.15, 0.0), 1.1, 9.0)
	G.light(Vector3(14.0, H - 0.15, 0.0), 1.1, 9.0)
	G.wet_sign(Vector3(7.5, 0.0, -2.8), 30.0)
	_sign("WATER IS LOUD\n\nThe Wader hunts by sound. Climb down a ladder: dropping in is loud. Wade slowly. Rushing, splashing, and moving your hands through the water all make noise.\n\nWatch the meter. Try to cross without lighting it up.", Vector3(9.6, 1.95, Z0 + 0.03), 0.0)
	# The noise meter: twelve lamps, green to red, lit by the noise you make.
	var label := Label3D.new()
	label.text = "NOISE"
	label.pixel_size = 0.004
	label.font_size = 48
	label.modulate = Color(0.12, 0.13, 0.14)
	label.outline_size = 0
	label.position = Vector3(14.0, 2.55, Z0 + 0.03)
	level.add_child(label)
	for i in 12:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.12, 0.3, 0.03)
		m.mesh = b
		var mat := StandardMaterial3D.new()
		var c := Color(0.2, 0.9, 0.3).lerp(Color(1.0, 0.85, 0.2), clampf(i / 7.0, 0.0, 1.0))
		if i >= 8:
			c = Color(1.0, 0.85, 0.2).lerp(Color(1.0, 0.15, 0.1), (i - 8) / 3.0)
		mat.albedo_color = c * 0.25
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 0.0
		m.material_override = mat
		m.position = Vector3(13.1 + i * 0.165, 2.15, Z0 + 0.03)
		level.add_child(m)
		meter.append(m)


func _room_throw() -> void:
	G.floor_slab(17, 24, Z0, 1.0)
	G.floor_slab(17, 18, 1.0, Z1)
	G.floor_slab(23, 24, 1.0, Z1)
	G.pool(18, 23, 1.0, Z1, FLOOR, SURFACE)
	_shell(17, 24, {"w": DOOR, "e": DOOR})
	G.light(Vector3(20.5, H - 0.15, -0.5), 1.2, 9.0)
	_sign("THROW\n\nA splash somewhere else draws it there. Throw a bottle into the water: swing and let go (VR), or hold left mouse and release (desktop).", Vector3(18.6, 1.9, Z0 + 0.03), 0.0, 0.0021)
	_sign("LIDAR\n\nTake the lidar off its charger. Point it and squeeze: it paints dots on whatever is in front of you, even in the dark. Only you see them. The battery runs down; it recharges here once there's power.", Vector3(23.97, 1.85, -1.0), -90.0, 0.0021)
	_table(Vector3(19.6, 0.0, -2.6))
	for i in 3:
		level._spawn_item("throwable", "Bottle%d" % (i + 1), Vector3(19.0 + i * 0.55, 0.95, -2.6))
	level._make_charger(Vector3(22.45 - 23.15, 0.0, -2.85 + 6.6))
	level._spawn_item("lidar", "Lidar", level.charger_point)


func _room_dark() -> void:
	G.floor_slab(24, 31, Z0, Z1)
	_shell(24, 31, {"w": DOOR, "e": LOCKED})
	# No lights: just a faint emergency light by the way in, so the sign can be read.
	var em := OmniLight3D.new()
	em.position = Vector3(24.7, 2.3, -1.6)
	em.light_color = Color(1.0, 0.3, 0.22)
	em.light_energy = 0.45
	em.omni_range = 3.5
	level.get_node("Lights").add_child(em)
	_sign("THE DARK\n\nThe key to the next door is somewhere in here. Use the lidar to find it, then hold the key up to the lock on the door.", Vector3(24.03, 1.8, -1.6), 90.0, 0.0021)
	var crate := StandardMaterial3D.new()
	crate.albedo_color = Color(0.32, 0.26, 0.18)
	crate.roughness = 0.9
	for c in [[25.6, 26.6, 1.6, 2.6, 0.9], [27.4, 28.2, -2.9, -2.1, 1.2], [28.0, 29.0, 1.7, 2.7, 0.8], [29.6, 30.4, -0.9, 0.1, 0.6], [26.4, 27.0, -0.6, 0.2, 1.5]]:
		G.block(c[0], c[1], 0.0, c[4], c[2], c[3], crate)
	level._spawn_item("key", "Key", Vector3(28.5, 0.86, 2.2))


func _room_power() -> void:
	# The mineral water basin is in the south-west corner (step in by the ladder).
	G.floor_slab(31, 41, Z0, 0.6)
	G.floor_slab(31, 32, 0.6, Z1)
	G.floor_slab(35.5, 41, 0.6, Z1)
	G.pool(32, 35.5, 0.6, Z1, FLOOR, SURFACE)
	G.water(Rect2(32, 0.6, 3.5, Z1 - 0.6), SURFACE, FLOOR, true)
	G.ladder(Vector3(33.75, FLOOR, 0.6), Vector3(0, 0, 1), 0.0)
	_shell(31, 41, {"w": LOCKED, "e": DOOR})
	level._make_staff_door(Vector3(31.0 - 16.0, 0.0, 5.0))
	G.light(Vector3(34.0, H - 0.15, -1.0), 1.1, 9.0)
	G.light(Vector3(38.5, H - 0.15, 0.5), 1.1, 9.0)
	level._make_distiller(Vector3(33.0 - 18.5, 0.0, -2.6 + 9.1))
	level._build_generator(Vector3(39.6 - 10.5, 0.0, -3.4 + 45.6))
	_table(Vector3(38.2, 0.0, 2.4))
	level._spawn_item("canteen", "Canteen1", Vector3(37.8, 0.95, 2.4))
	level._spawn_item("canteen", "Canteen2", Vector3(38.6, 0.95, 2.4))
	_sign("POWER\n\nFill a canteen in the darker mineral water (dip it in, by the ladder), then tip it into the generator's funnel. It takes two canteens.\n\nStand a canteen on the distiller for a while first and the generator starts faster. A generator is loud while it starts up.", Vector3(36.6, 1.95, Z1 - 0.03), 180.0, 0.0021)


func _room_cover() -> void:
	G.floor_slab(41, 42, Z0, Z1)
	G.floor_slab(52, 53, Z0, Z1)
	G.pool(42, 52, Z0, Z1, FLOOR, SURFACE)
	_shell(41, 53, {"w": DOOR, "e": DOOR})
	G.ladder(Vector3(42, FLOOR, 2.6), Vector3(1, 0, 0), 0.0)
	G.ladder(Vector3(52, FLOOR, -2.6), Vector3(-1, 0, 0), 0.0)
	level._make_pool_cover(Vector3(42.0 - 18.0, 0.0, 36.0), 10.0)
	level._make_lever(Vector3(41.5 - 17.0, 0.0, -2.2 + 33.0), "POOL COVER\npull the lever (needs power)")
	# The lights here run off the generator.
	for p in [Vector3(44.5, H - 0.1, -1.8), Vector3(49.5, H - 0.1, 1.8)]:
		level.hall_b_fittings.append(G.fitting(p, Color(0.85, 0.95, 1.0)))
	for p in [Vector3(45.0, H - 0.2, 0.0), Vector3(49.0, H - 0.2, 0.0)]:
		level.hall_b_lights.append(G.light(p, 1.4, 11.0, Color(0.85, 0.95, 1.0)))
	var em := OmniLight3D.new()
	em.position = Vector3(41.6, 2.3, 1.2)
	em.light_color = Color(1.0, 0.3, 0.22)
	em.light_energy = 0.45
	em.omni_range = 3.5
	level.get_node("Lights").add_child(em)
	_sign("THE POOL COVER\n\nThe lights and this lever run off the generator. With the power on, pull the lever and the cover rolls out across the pool: cross without touching the water.", Vector3(41.03, 1.85, 1.6), 90.0, 0.0021)


func _room_final() -> void:
	G.floor_slab(53, 59, Z0, Z1)
	_shell(53, 59, {"w": DOOR})
	G.light(Vector3(56.0, H - 0.15, 0.0), 1.2, 9.0, Color(0.85, 1.0, 0.85))
	_sign("IF YOU HEAR IT COMING, FREEZE\n\nIt knows roughly where you are and feels around with its arm. Don't move at all, not even your hands, until it's gone.", Vector3(55.0, 1.95, Z0 + 0.03), 0.0, 0.0021)
	_sign("WITH FRIENDS\n\nGive things by taking them from each other's hands. Shove a teammate with F (desktop). If it gets you, you're a ghost until a teammate reaches a dry room, or carries your bag into one.\n\nWalk to the exit doors to finish.", Vector3(55.0, 1.95, Z1 - 0.03), 180.0, 0.0021)
	var doors: Node3D = preload("res://assets/props/exit_doors.glb").instantiate()
	doors.position = Vector3(58.92, 0.0, 0.0)
	level.get_node("Props").add_child(doors)


# --- The noise meter -----------------------------------------------------------------------------

func _on_my_noise(loudness: float) -> void:
	_noise = maxf(_noise, clampf(loudness, 0.0, 1.0))


func _process(delta: float) -> void:
	_noise = maxf(_noise - delta * 0.5, 0.0)
	var lit := int(round(_noise * meter.size()))
	for i in meter.size():
		(meter[i].material_override as StandardMaterial3D).emission_energy_multiplier = 1.6 if i < lit else 0.0
