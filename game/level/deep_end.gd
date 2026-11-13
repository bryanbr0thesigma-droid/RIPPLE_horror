extends Node3D
## Level 2, The Deep End (gray-box, first pass). A tall natatorium over one deep diving pool: you
## can't wade here, only swim, and the Wader crawls along the bottom. Falls are huge.
##
##   Start room (south) -> the south deck -> a ladder up to the west gallery (4 m up, with gaps to
##   jump) -> a long narrow beam out to the diving tower -> ladders up its platforms (4, 7.5 and
##   10 m) -> the key on the top platform. Then back the careful way (ladders, beam, gallery), or
##   dive from 10 m (fast, and the loudest thing you can do) and swim for the north ladder -> the
##   north deck -> a ladder up to the north gallery -> the locked door on the north-east gallery ->
##   the exit.
##
## Built from the same pieces as the Shallow Halls; more gets added to it step by step.

const SURFACE := -0.3
const DEEP := -2.7                  # the pool floor: 2.4 m of water
const X0 := -14.0                   # the natatorium
const X1 := 22.0
const Z0 := -44.0
const Z1 := 0.0
const H := 12.0
const GALLERY := 4.0                # the galleries' walking height
const TOWER := Rect2(2.0, -30.0, 3.0, 3.0)   # the diving tower's core (x, z, w, d)

var level: Node3D
var G: LevelGeometry


func build(lv: Node3D) -> void:
	level = lv
	G = lv.G
	var env: Environment = lv.world_env.environment
	env.ambient_light_energy = 0.06
	_start_room()
	_hall()
	_galleries()
	_tower()
	_exit()
	_items()
	var spawns: Array[Vector3] = [Vector3(2.5, 0.05, 4.5), Vector3(5.5, 0.05, 4.5), Vector3(2.5, 0.05, 6.5), Vector3(5.5, 0.05, 6.5)]
	lv.spawn_points = spawns
	lv.creature_spawn = Vector3(4.0, DEEP, -16.0)
	lv.zones = [
		{"name": "start", "rect": Rect2(0, 0, 8, 8), "amb": "halls", "checkpoint": Vector3(4, 0.05, 5)},
		{"name": "south_deck", "rect": Rect2(X0, -4, X1 - X0, 4), "amb": "halls", "checkpoint": Vector3(4, 0.05, -2)},
		{"name": "hall", "rect": Rect2(X0, Z0, X1 - X0, Z1 - Z0 - 4), "amb": "halls"},
		{"name": "exit", "rect": Rect2(22, -43, 6, 6), "amb": "halls", "exit": true},
	]


# --- Rooms ---------------------------------------------------------------------------------------

func _start_room() -> void:
	G.floor_slab(0, 8, 0, 8)
	G.walls(0, 8, 0, 8, 0.0, 3.2, {"n": [[3.0, 5.0, 2.4]]})
	G.ceiling(0, 8, 0, 8, 3.2)
	G.light(Vector3(4, 3.0, 4), 1.2, 9.0)
	G.plaque("THE DEEP END\n\nThe water here is deep: you can't wade, only swim, and it hears every stroke. Falling in from up high is the loudest thing you can do.\n\nThe key is at the top of the diving tower. The way out is the locked door on the north-east gallery.\n\nIf you hear it coming, freeze.", Vector3(4, 1.7, 7.95), 180, 0.0021)


## The natatorium: a deck at each end, the deep pool between them filling the hall wall to wall.
func _hall() -> void:
	G.floor_slab(X0, X1, -4, Z1)                 # the south deck (you come in here)
	G.floor_slab(X0, X1, Z0, -38)                # the north deck
	G.pool(X0, X1, -38, -4, DEEP, SURFACE)
	# Walls in two bands: the ground floor (the start room's door) and the galleries (the exit door).
	G.walls(X0, X1, Z0, Z1, 0.0, GALLERY, {"s": [[3.0, 5.0, 2.4]]})
	G.walls(X0, X1, Z0, Z1, GALLERY, H, {"e": [[-40.64, -39.36, 2.15]]})
	G.ceiling(X0, X1, Z0, Z1, H)
	# Out of the water: a ladder at each end of the pool, and one up the tower from the water.
	G.ladder(Vector3(-6, DEEP, -4), Vector3(0, 0, -1), 0.0)
	G.ladder(Vector3(12, DEEP, -4), Vector3(0, 0, -1), 0.0)
	G.ladder(Vector3(-2, DEEP, -38), Vector3(0, 0, 1), 0.0)
	G.ladder(Vector3(14, DEEP, -38), Vector3(0, 0, 1), 0.0)
	# High, cold light: a few big fittings under the roof, a lamp on each deck.
	for p in [Vector3(-4, H - 0.3, -12), Vector3(12, H - 0.3, -12), Vector3(-4, H - 0.3, -30), Vector3(12, H - 0.3, -30)]:
		G.fitting(p, Color(0.85, 0.95, 1.0))
	G.light(Vector3(4, H - 0.6, -12), 1.6, 18.0, Color(0.85, 0.95, 1.0))
	G.light(Vector3(4, H - 0.6, -30), 1.6, 18.0, Color(0.85, 0.95, 1.0))
	G.wall_lamp(Vector3(4, 2.6, Z1), Vector3.FORWARD, 1.0, 8.0)
	G.wall_lamp(Vector3(4, 2.6, Z0), Vector3.BACK, 1.0, 8.0)
	G.wet_sign(Vector3(1.5, 0, -1.2), 20)
	G.plaque("DEEP WATER\nNO DIVING\nEXCEPT FROM THE TOWER", Vector3(9, 2.2, -0.03), 180, 0.004)


## The galleries, 4 m up: along the west wall (gaps to jump, one with only a plank across) and
## along the north wall to the locked door on the east side.
func _galleries() -> void:
	var y0 := GALLERY - 0.3
	var y1 := GALLERY
	# Up from the south deck: a ladder against the gallery's edge (you climb onto what's behind it).
	G.ladder(Vector3(X0 + 2.0, 0.0, -6.0), Vector3(1, 0, 0), GALLERY)
	# The west gallery, z -40..-4, in pieces.
	for seg in [[-4.0, -12.8], [-14.0, -22.4], [-24.0, -42.0]]:
		_slab(X0, X0 + 2.0, seg[1], seg[0], y0, y1)
	# The second gap only has a plank across it, along the wall.
	G.block(X0 + 0.15, X0 + 0.45, y1 - 0.08, y1, -24.0, -22.4, G.mat_metal)
	# The north gallery, from the west gallery to the door, with a gap to jump; a ladder up to it
	# from the north deck (for whoever came the wet way).
	_slab(X0, 6.0, Z0, -42.0, y0, y1)
	_slab(7.2, X1, Z0, -42.0, y0, y1)
	G.ladder(Vector3(12.0, 0.0, -42.0), Vector3(0, 0, 1), GALLERY)
	# The east stub up to the door.
	_slab(X1 - 2.0, X1, -42.0, -37.0, y0, y1)
	level._make_staff_door(Vector3(X1 - 16.0, GALLERY, -40.0 + 5.0))
	G.wall_lamp(Vector3(X1, GALLERY + 2.4, -38.0), Vector3.LEFT, 1.0, 7.0)
	G.wall_lamp(Vector3(X0, GALLERY + 2.4, -8.0), Vector3.RIGHT, 0.9, 7.0)
	G.wall_lamp(Vector3(X0, GALLERY + 2.4, -30.0), Vector3.RIGHT, 0.9, 7.0)


## The diving tower in the middle of the pool: a core from the pool floor to 10 m, a platform on
## its west side at 4 m (where the beam from the west gallery lands), one on its south side at
## 7.5 m, the top at 10 m with a diving board. Ladders between them, and one up from the water.
func _tower() -> void:
	var t := TOWER
	var tx0 := t.position.x
	var tx1 := t.end.x
	var tz0 := t.position.y
	var tz1 := t.end.y
	G.pillar(tx0, tx1, tz0, tz1, DEEP, 10.0)
	# The beam: 40 cm wide, 13 m long, nothing to hold on to.
	G.block(X0 + 2.0, tx0 - 3.0, GALLERY - 0.25, GALLERY, -28.7, -28.3, G.mat_metal)
	G.grab_rim(Vector3(X0 + 2.0, GALLERY, -28.7), Vector3(tx0 - 3.0, GALLERY, -28.7))
	G.grab_rim(Vector3(X0 + 2.0, GALLERY, -28.3), Vector3(tx0 - 3.0, GALLERY, -28.3))
	# 4 m: west of the core. A ladder from its south edge up to the 7.5 m platform behind it.
	_slab(tx0 - 3.0, tx0, tz0, tz1, GALLERY - 0.3, GALLERY)
	G.ladder(Vector3(tx0 - 0.75, GALLERY, tz1), Vector3(0, 0, -1), 7.5)
	# 7.5 m: south of the core (reaching back over the 4 m one); a ladder up the core to the top.
	_slab(tx0 - 1.5, tx1, tz1, tz1 + 1.6, 7.2, 7.5)
	G.ladder(Vector3(tx1 - 0.8, 7.5, tz1), Vector3(0, 0, 1), 10.0)
	# 10 m: the top, and the board over the water.
	G.block(tx1, tx1 + 2.2, 9.9, 10.0, -28.8, -28.2, G.mat_blue)
	G.grab_rim(Vector3(tx1, 10.0, -28.8), Vector3(tx1 + 2.2, 10.0, -28.8))
	G.grab_rim(Vector3(tx1, 10.0, -28.2), Vector3(tx1 + 2.2, 10.0, -28.2))
	# From the water up the east face to the 4 m platform? No: up to a small landing at 1 m, so a
	# swimmer can get out of the water there, but not up the tower.
	_slab(tx1, tx1 + 1.2, tz0 + 0.8, tz1 - 0.8, 0.7, 1.0)
	G.ladder(Vector3(tx1 + 1.2, DEEP, tz0 + 1.5), Vector3(1, 0, 0), 1.0)
	G.light(Vector3(3.5, 11.3, -28.5), 0.8, 6.0, Color(0.9, 0.95, 1.0), false)


## Through the locked door: a dry room at gallery height. Everyone inside ends the level.
func _exit() -> void:
	G.floor_slab(22, 28, -43, -37, GALLERY)
	G.walls(22, 28, -43, -37, GALLERY, GALLERY + 3.2, {"w": [[-40.64, -39.36, 2.15]]})
	G.ceiling(22, 28, -43, -37, GALLERY + 3.2)
	G.wall_lamp(Vector3(25, GALLERY + 2.4, -43), Vector3.BACK, 1.4, 8.0, Color(0.85, 1.0, 0.85))
	var doors: Node3D = preload("res://assets/props/exit_doors.glb").instantiate()
	doors.position = Vector3(27.92, GALLERY, -40.0)
	level.get_node("Props").add_child(doors)
	G.plaque("You made it. Wait here for the others.", Vector3(25, GALLERY + 1.8, -37.03), 180, 0.003)


func _items() -> void:
	level._spawn_item("key", "Key", Vector3(3.5, 10.08, -28.5))
	level._spawn_item("flashlight", "Flashlight", Vector3(3.2, 0.06, 1.6))
	level._spawn_item("lidar", "Lidar", Vector3(5.0, 0.06, 1.6))
	level._spawn_item("throwable", "Bottle1", Vector3(-2.0, 0.1, -1.5))
	level._spawn_item("throwable", "Bottle2", Vector3(X0 + 1.0, GALLERY + 0.1, -8.0))
	level._spawn_item("throwable", "Bottle3", Vector3(TOWER.position.x - 1.5, GALLERY + 0.1, -28.5))
	level._spawn_item("throwable", "Bottle4", Vector3(0.0, 0.1, -40.5))


## A walkway slab with grab rims along its edges (VR hands can catch it if a jump falls short).
func _slab(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
	G.block(x0, x1, y0, y1, z0, z1, G.mat_white)
	G.grab_rim(Vector3(x0, y1, z0), Vector3(x1, y1, z0))
	G.grab_rim(Vector3(x0, y1, z1), Vector3(x1, y1, z1))
	G.grab_rim(Vector3(x0, y1, z0), Vector3(x0, y1, z1))
	G.grab_rim(Vector3(x1, y1, z0), Vector3(x1, y1, z1))
