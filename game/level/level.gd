class_name RippleLevel
extends Node3D
## The test level, "The Shallow Halls": built from rectangles at load time, identically on every peer.
##
## Route: start room -> Hall A (shallow pool; the key is on an island reached by stepping columns)
## -> staff room (locked; canteens, lidar, distiller) -> Hall B, the dark sector (deeper pool,
## narrow beams, the darker mineral water in the far corner, the generator) -> Hall C (deep pool;
## the lever extends a pool cover across once the generator runs) -> exit.
##
## The host owns the world state (doors, generator, pool cover) and the creature. Each peer owns
## its player and whatever items it is holding.

const PlayerScene := preload("res://player/player.gd")
const CreatureScript := preload("res://creature/creature.gd")
const ItemScripts := {
	"key": preload("res://items/key.gd"),
	"canteen": preload("res://items/canteen.gd"),
	"lidar": preload("res://items/lidar.gd"),
	"throwable": preload("res://items/throwable.gd"),
}
const SFX := {
	"splash_big": preload("res://assets/audio/splash_big.ogg"),
	"splash_small": preload("res://assets/audio/splash_small.ogg"),
	"plop": preload("res://assets/audio/plop.ogg"),
	"clank": preload("res://assets/audio/clank.ogg"),
	"door": preload("res://assets/audio/door.ogg"),
	"screech": preload("res://assets/audio/creature_charge.ogg"),
}
const AMBIENCE := {
	"halls": preload("res://assets/audio/amb_halls.ogg"),
	"dark": preload("res://assets/audio/amb_dark.ogg"),
	"pump": preload("res://assets/audio/amb_pumproom.ogg"),
}

const SURFACE := -0.3

var G: LevelGeometry
var players: Dictionary = {}      # peer id -> Player
var items: Dictionary = {}        # name -> NetItem
var creature: Node3D
var local_player: Node3D = null

## Host-owned world state, mirrored on every peer.
var state := {
	"staff_door": false,
	"key_used": false,
	"fuel": 0.0,
	"fuel_distilled": 0.0,
	"gen": 0,               # 0 off, 1 starting up, 2 running
	"cover": false,
	"all_escaped": false,
}
var escaped: Dictionary = {}      # host: peer id -> bool

# Things the state drives.
var hall_b_lights: Array[OmniLight3D] = []
var hall_b_fittings: Array[MeshInstance3D] = []
var staff_door: StaticBody3D
var exit_door: StaticBody3D
var cover_bridge: AnimatableBody3D
var cover_amount := 0.0
var generator_glass: MeshInstance3D
var generator_audio: AudioStreamPlayer3D
var distiller_audio: AudioStreamPlayer3D
var lever_arm: Node3D
var gen_timer := 0.0
var gen_noise_timer := 0.0

## Fixed places other scripts ask about.
var spawn_points: Array[Vector3] = [Vector3(2.5, 0.05, 4.5), Vector3(5.5, 0.05, 4.5), Vector3(2.5, 0.05, 6.5), Vector3(5.5, 0.05, 6.5)]
var lock_point := Vector3(15.95, 1.0, -5.55)
var funnel_point := Vector3(10.5, 1.15, -44.4)
var distiller_slot := Vector3(18.6, 0.98, -9.1)
var charger_point := Vector3(23.15, 1.0, -6.6)
var lever_point := Vector3(17.0, 1.0, -33.0)
var creature_spawn := Vector3(8.0, -1.05, -38.0)

## Rooms: ambience, checkpoints, exit. Rect2 is x, z, width, depth.
var zones := [
	{"name": "start", "rect": Rect2(0, 0, 8, 8), "amb": "halls", "checkpoint": Vector3(4, 0.05, 5)},
	{"name": "hall_a", "rect": Rect2(-8, -20, 24, 20), "amb": "halls"},
	{"name": "staff", "rect": Rect2(16, -10, 8, 10), "amb": "halls", "checkpoint": Vector3(19, 0.05, -3)},
	{"name": "corridor", "rect": Rect2(2, -22, 2.5, 2), "amb": "halls"},
	{"name": "hall_b_entry", "rect": Rect2(-8, -24, 24, 2), "amb": "dark", "checkpoint": Vector3(3, 0.05, -23)},
	{"name": "hall_b", "rect": Rect2(-8, -46, 24, 22), "amb": "dark"},
	{"name": "hall_c_ledge", "rect": Rect2(16, -40, 2, 8), "amb": "halls", "checkpoint": Vector3(17, 0.05, -36)},
	{"name": "hall_c", "rect": Rect2(16, -46, 22, 24), "amb": "halls"},
	{"name": "exit", "rect": Rect2(38, -40, 6, 8), "amb": "halls", "exit": true},
]

var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var _amb_current := ""
var _sync_timer := 0.0
var _ripples := PackedVector4Array()
var _ripple_i := 0
var lidar_dots: MultiMeshInstance3D
var _dot_i := 0
var hud: CanvasLayer


func _ready() -> void:
	name = "Level"
	Game.level = self
	for n in ["Lights", "Props", "Items", "Players"]:
		var node := Node3D.new()
		node.name = n
		add_child(node)
	G = LevelGeometry.new(self)
	_environment()
	_build_start_room()
	_build_hall_a()
	_build_staff_room()
	_build_hall_b()
	_build_hall_c()
	_build_exit()
	_build_items()
	_build_navigation()
	_build_creature()
	_build_audio()
	_build_lidar_dots()
	_ripples.resize(16)
	NoiseBus.ripple.connect(_on_ripple)
	hud = preload("res://ui/hud.gd").new()
	add_child(hud)
	_apply_all_state()
	Net.level_loaded.call_deferred()


func _exit_tree() -> void:
	if Game.level == self:
		Game.level = null


# --- Layout --------------------------------------------------------------------------------------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.014)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.6, 0.65)
	env.ambient_light_energy = 0.015
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.08, 0.09)
	env.fog_density = 0.025
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_start_room() -> void:
	G.floor_slab(0, 8, 0, 8)
	G.walls(0, 8, 0, 8, 0.0, 3.4, {"n": [[3.0, 5.0, 2.4]]})
	G.ceiling(0, 8, 0, 8, 3.4)
	G.wall_lamp(Vector3(0, 2.5, 4), Vector3.RIGHT, 1.3, 9.5)
	G.chair(Vector3(7.2, 0, 7.0), -135)
	G.plaque("RIPPLE test level\n\nSomething lives in the water and hunts by sound. Falling in is loud. Wading fast is loud. Moving your hands in the water makes noise.\n\nIf you hear it coming, freeze. It knows roughly where you are and feels around with its arm. Don't move at all.\n\nFind the key, get into the staff room, power the generator with the darker mineral water (2 canteens), and get across the deep pool.", Vector3(4, 1.7, 7.95), 180, 0.0022)


func _build_hall_a() -> void:
	# Room: x -8..16, z -20..0. Pool: x -6..14, z -18..-2, floor -1.3.
	G.walls(-8, 16, -20, 0, 0.0, 4.2, {"s": [[3.0, 5.0, 2.4]], "n": [[2.0, 4.5, 2.4]], "e": [[-6.0, -4.0, 2.4]]})
	G.ceiling(-8, 16, -20, 0, 4.2)
	G.floor_slab(-8, 16, -2, 0)
	G.floor_slab(-8, 8, -20, -18)
	G.floor_slab(8, 10.5, -20, -18, 0.0, null, 0.2)   # bridge over the channel
	G.floor_slab(10.5, 16, -20, -18)
	G.floor_slab(-8, -6, -18, -2)
	G.floor_slab(14, 16, -18, -2)
	G.pool(-6, 14, -18, -2, -1.3, SURFACE, {"n": [[8.0, 10.5]]})
	# The island with the key, and stepping columns to it from both sides.
	G.pillar(3, 6, -11, -8, -1.3)
	for x in [-4.9, -3.2, -1.5, 0.2, 1.9, 7.0, 8.7, 10.4, 12.1, 13.6]:
		G.pillar(x - 0.4, x + 0.4, -9.9, -9.1, -1.3)
	# Steps down into the shallow end, and ladders.
	for i in range(4):
		var top := -0.3 - i * 0.25
		G.block(-6, -4.5, -1.3, top, -2.0 - (i + 1) * 0.5, -2.0 - i * 0.5, G.mat_white)
	G.ladder(Vector3(-6, -1.3, -14), Vector3(1, 0, 0), 0.0)
	G.ladder(Vector3(14, -1.3, -14), Vector3(-1, 0, 0), 0.0)
	G.ladder(Vector3(0, -1.3, -18), Vector3(0, 0, 1), 0.0)
	for p in [Vector3(-2, 4.1, -5), Vector3(10, 4.1, -5), Vector3(-2, 4.1, -15), Vector3(10, 4.1, -15)]:
		G.fitting(p)
	G.light(Vector3(4, 4.0, -5), 1.6, 15.0)
	G.light(Vector3(4, 4.0, -15), 1.6, 15.0)
	# Channel under the north wall to Hall B (water only, for the creature).
	G.pool(8, 10.5, -24, -18, -1.8, SURFACE, {"n": "open", "s": "open"}, false)
	# Corridor to Hall B.
	G.floor_slab(2, 4.5, -22, -20)
	G.walls(2, 4.5, -22, -20, 0.0, 2.6, {"n": [[2.0, 4.5, 3.0]], "s": [[2.0, 4.5, 3.0]]})
	G.ceiling(2, 4.5, -22, -20, 2.6)
	G.plaque("STAFF ONLY", Vector3(15.98, 2.6, -5.0), -90, 0.006)
	# Dressing: wet floor signs, poolside chairs, pipes along the walls.
	G.wet_sign(Vector3(-5.0, 0, -0.35), 30)
	G.wet_sign(Vector3(13.0, 0, -0.9), -20)
	G.chair(Vector3(-7.3, 0, -10.0), 90)
	G.chair(Vector3(-7.3, 0, -11.1), 80)
	G.pipe_run(Vector3(-8, 3.6, -20), Vector3(16, 3.6, -20), Vector3.BACK)
	G.pipe_run(Vector3(-8, 3.35, -20), Vector3(16, 3.35, -20), Vector3.BACK, true)
	G.pipe_run(Vector3(-8, 3.85, 0), Vector3(-8, 3.85, -20), Vector3.RIGHT)
	G.plaque("WET FLOOR", Vector3(3.25, 2.75, -20.01), 0, 0.005)


func _build_staff_room() -> void:
	# x 16..24, z -10..0. The door from Hall A is on the west wall (z -6..-4) and starts locked.
	G.floor_slab(16, 24, -10, 0)
	G.walls(16, 24, -10, 0, 0.0, 3.2, {"w": [[-6.0, -4.0, 2.4]]})
	G.ceiling(16, 24, -10, 0, 3.2)
	G.wall_lamp(Vector3(24, 2.4, -3.5), Vector3.LEFT, 1.3, 9.5)
	G.chair(Vector3(20.5, 0, -3.15), 0)
	G.chair(Vector3(21.6, 0, -3.2), 12)
	staff_door = G.block(15.85, 16.15, 0.0, 2.4, -6.0, -4.0, G.mat_metal, LevelGeometry.L_DYNAMIC, $Props)
	staff_door.name = "StaffDoor"
	var lock := G.block(15.75, 15.85, 0.9, 1.1, -5.65, -5.45, G.mat_rail, 0, $Props)
	lock.name = "Lock"
	# Table, shelf, distiller, charger.
	G.block(20.0, 22.0, 0.0, 0.85, -2.6, -1.4, G.mat_metal, LevelGeometry.L_WORLD, $Props)
	G.block(22.8, 23.6, 0.0, 0.9, -7.4, -5.8, G.mat_metal, LevelGeometry.L_WORLD, $Props)
	G.block(18.1, 19.1, 0.0, 0.9, -9.6, -8.6, G.mat_metal, LevelGeometry.L_WORLD, $Props)
	_add_prop_label("DISTILLER\nset a canteen here", Vector3(18.6, 1.35, -8.58))
	_add_prop_label("LIDAR CHARGER\nneeds power", Vector3(23.15, 1.35, -5.78))
	distiller_audio = _loop_audio(preload("res://assets/audio/distiller_loop.ogg"), Vector3(18.6, 1.0, -9.1), -10.0)


func _build_hall_b() -> void:
	# The dark sector: x -8..16, z -46..-22. The pool fills the room except the entrance strip.
	G.walls(-8, 16, -46, -22, 0.0, 4.5, {"s": [[2.0, 4.5, 2.4]], "e": [[-37.0, -35.0, 2.4]]})
	G.ceiling(-8, 16, -46, -22, 4.5)
	G.floor_slab(-8, 8, -24, -22)
	G.floor_slab(8, 10.5, -24, -22, 0.0, null, 0.2)   # bridge over the channel
	G.floor_slab(10.5, 16, -24, -22)
	G.pool(-8, 16, -46, -24, -1.8, SURFACE, {"s": [[8.0, 10.5]], "e": "open"})
	# Beams and platforms, all at walkway level.
	G.pillar(2.65, 3.35, -30, -24, -1.8)         # beam north from the entrance
	G.pillar(1.5, 4.5, -33, -30, -1.8)           # platform 1
	G.pillar(-4.5, 1.5, -31.85, -31.15, -1.8)    # beam west
	G.pillar(-8, -4.5, -34, -29, -1.8)           # platform by the mineral water
	G.pillar(2.65, 3.35, -38, -33, -1.8)         # beam north
	G.pillar(2.55, 3.45, -39.95, -39.05, -1.8)   # stepping columns
	G.pillar(2.55, 3.45, -41.45, -40.55, -1.8)
	G.pillar(3.45, 4.35, -43.05, -42.15, -1.8)
	G.pillar(5.2, 14, -46, -42, -1.8)            # generator platform
	G.pillar(14, 16, -46, -34, -1.8)             # ledge to the door to Hall C
	# The mineral water: slightly darker, in the north-west corner, next to the platform.
	G.water(Rect2(-8, -40, 3.5, 6), SURFACE, -1.8, true)
	G.ladder(Vector3(0, -1.8, -24), Vector3(0, 0, -1), 0.0)
	G.ladder(Vector3(12, -1.8, -24), Vector3(0, 0, -1), 0.0)
	G.ladder(Vector3(-6.25, -1.8, -29), Vector3(0, 0, -1), 0.0)
	G.ladder(Vector3(10, -1.8, -42), Vector3(0, 0, 1), 0.0)
	G.ladder(Vector3(4.5, -1.8, -31.5), Vector3(1, 0, 0), 0.0)
	for p in [Vector3(-2, 4.4, -28), Vector3(10, 4.4, -28), Vector3(-2, 4.4, -40), Vector3(10, 4.4, -40)]:
		hall_b_fittings.append(G.fitting(p, Color(0.85, 0.95, 1.0)))
	for p in [Vector3(4, 4.3, -29), Vector3(4, 4.3, -40)]:
		var l := G.light(p, 1.6, 15.0, Color(0.85, 0.95, 1.0))
		hall_b_lights.append(l)
	G.wet_sign(Vector3(6.5, 0, -23.0), 20)
	G.pipe_run(Vector3(-8, 3.8, -22), Vector3(-8, 3.8, -46), Vector3.RIGHT)
	G.pipe_run(Vector3(-8, 3.5, -46), Vector3(16, 3.5, -46), Vector3.BACK, true)
	G.pipe_riser(Vector3(12.3, 0, -46), 4.5, Vector3.BACK, 1.0)
	# A faint emergency light by the entrance, so the doorway isn't pitch black.
	var em := OmniLight3D.new()
	em.position = Vector3(3.25, 2.3, -22.6)
	em.light_color = Color(1.0, 0.25, 0.2)
	em.light_energy = 0.35
	em.omni_range = 4.0
	$Lights.add_child(em)
	_build_generator()


func _build_generator() -> void:
	var g := G.block(9.5, 11.5, 0.0, 1.0, -45.6, -44.8, G.mat_metal, LevelGeometry.L_WORLD, $Props)
	g.name = "Generator"
	# Funnel on top: the canteen's stream has to land in it.
	var funnel := Area3D.new()
	funnel.name = "Funnel"
	funnel.add_to_group("generator_funnel")
	funnel.collision_layer = LevelGeometry.L_TRIGGERS
	funnel.collision_mask = 0
	funnel.position = funnel_point
	var fcs := CollisionShape3D.new()
	var fsh := CylinderShape3D.new()
	fsh.radius = 0.28
	fsh.height = 0.3
	fcs.shape = fsh
	funnel.add_child(fcs)
	$Props.add_child(funnel)
	var fm := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.1
	cm.height = 0.25
	fm.mesh = cm
	fm.material_override = G.mat_rail
	fm.position = funnel_point
	$Props.add_child(fm)
	# Sight glass showing how full the tank is.
	var frame := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.12, 0.7, 0.02)
	frame.mesh = fb
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.06, 0.06)
	frame.material_override = dark
	frame.position = Vector3(11.3, 0.5, -44.78)
	$Props.add_child(frame)
	generator_glass = MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(0.08, 0.66, 0.01)
	generator_glass.mesh = gb
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.1, 0.35, 0.4)
	gm.emission_enabled = true
	gm.emission = Color(0.1, 0.5, 0.55)
	gm.emission_energy_multiplier = 0.6
	generator_glass.material_override = gm
	generator_glass.position = Vector3(11.3, 0.5, -44.76)
	$Props.add_child(generator_glass)
	_add_prop_label("GENERATOR\npour mineral water in the funnel", Vector3(10.5, 1.55, -44.7))
	generator_audio = _loop_audio(preload("res://assets/audio/generator_hum.ogg"), Vector3(10.5, 0.8, -45.2), -4.0)


func _build_hall_c() -> void:
	# x 16..38, z -46..-22. Deep pool with a ledge on each side; the pool cover bridges them.
	G.walls(16, 38, -46, -22, 0.0, 4.8, {"w": [[-37.0, -35.0, 2.4]], "e": [[-37.0, -35.0, 2.4]]})
	G.ceiling(16, 38, -46, -22, 4.8)
	G.pool(16, 38, -46, -22, -2.6, SURFACE, {"w": [[-30.0, -27.0]]})
	G.pillar(16, 18, -40, -32, -2.6)
	G.pillar(36, 38, -40, -32, -2.6)
	G.ladder(Vector3(18, -2.6, -38.5), Vector3(1, 0, 0), 0.0)
	G.ladder(Vector3(36, -2.6, -33.5), Vector3(-1, 0, 0), 0.0)
	for p in [Vector3(22, 4.7, -30), Vector3(32, 4.7, -30), Vector3(22, 4.7, -40), Vector3(32, 4.7, -40)]:
		G.fitting(p, Color(0.9, 0.95, 1.0))
	G.light(Vector3(27, 4.6, -30), 1.3, 15.0, Color(0.9, 0.95, 1.0))
	G.light(Vector3(27, 4.6, -40), 1.3, 15.0, Color(0.9, 0.95, 1.0))
	G.pipe_run(Vector3(38, 4.0, -22), Vector3(38, 4.0, -46), Vector3.LEFT)
	G.wet_sign(Vector3(17.4, 0, -39.4), 45)
	# The retractable pool cover, retracted against the west ledge.
	cover_bridge = AnimatableBody3D.new()
	cover_bridge.name = "PoolCover"
	cover_bridge.collision_layer = LevelGeometry.L_DYNAMIC
	cover_bridge.collision_mask = 0
	cover_bridge.sync_to_physics = false
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(18, 0.12, 2.4)
	mi.mesh = bm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.2, 0.32, 0.5)
	cm.roughness = 0.7
	mi.material_override = cm
	cover_bridge.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = bm.size
	cs.shape = sh
	cover_bridge.add_child(cs)
	$Props.add_child(cover_bridge)
	# The lever on the west ledge.
	G.block(16.6, 17.4, 0.0, 0.9, -33.3, -32.7, G.mat_metal, LevelGeometry.L_WORLD, $Props)
	lever_arm = Node3D.new()
	lever_arm.position = Vector3(17.0, 0.9, -33.0)
	var arm := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.03
	am.bottom_radius = 0.03
	am.height = 0.55
	arm.mesh = am
	arm.material_override = G.mat_rail
	arm.position = Vector3(0, 0.27, 0)
	lever_arm.add_child(arm)
	var knob := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.06
	km.height = 0.12
	knob.mesh = km
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.7, 0.08, 0.06)
	knob.material_override = red
	knob.position = Vector3(0, 0.55, 0)
	lever_arm.add_child(knob)
	lever_arm.rotation_degrees = Vector3(-35, 0, 0)
	$Props.add_child(lever_arm)
	var handle := preload("res://items/lever_handle.gd").new()
	handle.name = "LeverHandle"
	$Props.add_child(handle)
	handle.global_position = lever_point
	_add_prop_label("POOL COVER\npull the lever (needs power)", Vector3(17.0, 1.75, -33.0), 90)


func _build_exit() -> void:
	G.floor_slab(38, 44, -40, -32)
	G.walls(38, 44, -40, -32, 0.0, 3.2, {"w": [[-37.0, -35.0, 2.4]]})
	G.ceiling(38, 44, -40, -32, 3.2)
	G.wall_lamp(Vector3(41, 2.4, -40), Vector3.BACK, 1.6, 9.5, Color(0.85, 1.0, 0.85))
	G.chair(Vector3(43.2, 0, -32.8), -135)
	G.plaque("EXIT\nYou made it. Wait here for the others.", Vector3(43.95, 1.7, -36), -90, 0.006)


func _add_prop_label(text: String, pos: Vector3, yaw := 0.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = 0.0025
	l.font_size = 40
	l.position = pos
	l.rotation_degrees = Vector3(0, yaw, 0)
	l.modulate = Color(0.85, 0.9, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	$Props.add_child(l)


func _loop_audio(stream: AudioStream, pos: Vector3, db: float) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	a.stream = stream
	a.volume_db = db
	a.unit_size = 4.0
	a.position = pos
	$Props.add_child(a)
	return a


# --- Items, navigation, creature, audio ----------------------------------------------------------

func _build_items() -> void:
	_spawn_item("key", "Key", Vector3(4.5, 0.08, -9.5))
	_spawn_item("canteen", "Canteen1", Vector3(20.6, 0.95, -2.0))
	_spawn_item("canteen", "Canteen2", Vector3(21.4, 0.95, -2.0))
	_spawn_item("lidar", "Lidar", Vector3(23.15, 1.0, -6.6))
	_spawn_item("throwable", "Bottle1", Vector3(1.0, 0.1, -1.0))
	_spawn_item("throwable", "Bottle2", Vector3(21.0, 0.95, -1.7))
	_spawn_item("throwable", "Bottle3", Vector3(15.0, 0.1, -36.5))
	_spawn_item("throwable", "Bottle4", Vector3(3.0, 0.1, -23.0))


func _spawn_item(kind: String, item_name: String, pos: Vector3) -> void:
	var it: RigidBody3D = ItemScripts[kind].new()
	it.name = item_name
	$Items.add_child(it)
	it.global_position = pos
	items[item_name] = it


func _build_navigation() -> void:
	var nm := NavigationMesh.new()
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_radius = 0.5
	nm.agent_height = 0.5
	nm.agent_max_climb = 0.25
	nm.region_min_size = 1.0
	var src := NavigationMeshSourceGeometryData3D.new()
	var y := -1.3
	for r: Rect2 in G.nav_rects:
		var a := Vector3(r.position.x, y, r.position.y)
		var b := Vector3(r.end.x, y, r.position.y)
		var c := Vector3(r.end.x, y, r.end.y)
		var d := Vector3(r.position.x, y, r.end.y)
		src.add_faces(PackedVector3Array([a, b, c, a, c, d, a, c, b, a, d, c]), Transform3D.IDENTITY)
	for o: Rect2 in G.nav_obstacles:
		var outline := PackedVector3Array([
			Vector3(o.position.x, y, o.position.y), Vector3(o.end.x, y, o.position.y),
			Vector3(o.end.x, y, o.end.y), Vector3(o.position.x, y, o.end.y)])
		src.add_projected_obstruction(outline, y - 1.0, 3.0, true)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	var region := NavigationRegion3D.new()
	region.name = "CreatureNav"
	region.navigation_mesh = nm
	add_child(region)


func _build_creature() -> void:
	creature = CreatureScript.new()
	creature.name = "Creature"
	add_child(creature)
	creature.global_position = creature_spawn


func _build_audio() -> void:
	_amb_a = AudioStreamPlayer.new()
	_amb_b = AudioStreamPlayer.new()
	for a in [_amb_a, _amb_b]:
		a.volume_db = -80.0
		add_child(a)
	for k in AMBIENCE:
		var amb: AudioStreamOggVorbis = AMBIENCE[k]
		amb.loop = true
	var music := AudioStreamPlayer.new()
	var ms: AudioStreamOggVorbis = preload("res://assets/audio/music_under_surface.ogg")
	ms.loop = true
	music.stream = ms
	music.bus = "Music"
	music.volume_db = -8.0
	add_child(music)
	music.play()


func _build_lidar_dots() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	mm.mesh = q
	mm.instance_count = 6000
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -100, 0)))
		mm.set_instance_custom_data(i, Color(-1000, 0, 0, 0))
		mm.set_instance_color(i, Color(0.4, 1.0, 0.9))
	lidar_dots = MultiMeshInstance3D.new()
	lidar_dots.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://core/lidar_dots.gdshader")
	lidar_dots.material_override = mat
	lidar_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lidar_dots.custom_aabb = AABB(Vector3(-100, -50, -100), Vector3(200, 100, 200))
	add_child(lidar_dots)


## Lidar scanner hits, only drawn for the person holding it.
func add_lidar_dot(pos: Vector3, color: Color) -> void:
	var mm := lidar_dots.multimesh
	mm.set_instance_transform(_dot_i, Transform3D(Basis(), pos))
	mm.set_instance_custom_data(_dot_i, Color(now(), 0, 0, 0))
	mm.set_instance_color(_dot_i, color)
	_dot_i = (_dot_i + 1) % mm.instance_count


static func now() -> float:
	return fmod(Time.get_ticks_msec() / 1000.0, 3600.0)


func _on_ripple(pos: Vector3, strength: float) -> void:
	_ripples[_ripple_i] = Vector4(pos.x, pos.z, now(), strength)
	_ripple_i = (_ripple_i + 1) % 16
	G.water_mat.set_shader_parameter("ripples", _ripples)
	G.mineral_mat.set_shader_parameter("ripples", _ripples)


# --- Per frame -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var t := now()
	G.water_mat.set_shader_parameter("time_now", t)
	G.mineral_mat.set_shader_parameter("time_now", t)
	(lidar_dots.material_override as ShaderMaterial).set_shader_parameter("time_now", t)
	_update_ambience(delta)
	# Pool cover slides out once extended.
	var target := 1.0 if state.cover else 0.0
	cover_amount = move_toward(cover_amount, target, delta / 6.0)
	_place_cover()
	if lever_arm:
		lever_arm.rotation_degrees.x = lerpf(lever_arm.rotation_degrees.x, 35.0 if state.cover else -35.0, delta * 6.0)
	if staff_door:
		var open_y := 2.35 if state.staff_door else 0.0
		staff_door.position.y = move_toward(staff_door.position.y, 1.2 + open_y, delta * 1.5)
	var distilling := false
	for it in items.values():
		if it.has_method("is_distilling") and it.is_distilling():
			distilling = true
	if distilling and not distiller_audio.playing:
		distiller_audio.play()
	elif not distilling and distiller_audio.playing:
		distiller_audio.stop()


func _physics_process(delta: float) -> void:
	if Net.is_host() or not Net.is_online():
		_host_tick(delta)
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 0.05
		_send_item_sync()


func _place_cover() -> void:
	if not cover_bridge:
		return
	var a := maxf(cover_amount, 0.001)
	var mesh: MeshInstance3D = cover_bridge.get_child(0)
	var cs: CollisionShape3D = cover_bridge.get_child(1)
	mesh.scale = Vector3(a, 1, 1)
	(cs.shape as BoxShape3D).size = Vector3(maxf(18.0 * a, 0.05), 0.12, 2.4)
	cover_bridge.position = Vector3(18.0 + 9.0 * a, -0.06, -36.0)
	cover_bridge.visible = cover_amount > 0.002
	cs.disabled = cover_amount < 0.05


func _update_ambience(delta: float) -> void:
	if not local_player:
		return
	var p: Vector3 = local_player.body_position()
	var want := "halls"
	for z in zones:
		if z.rect.has_point(Vector2(p.x, p.z)):
			want = z.amb
	if want == "dark" and state.gen == 2:
		want = "pump"
	if want != _amb_current:
		_amb_current = want
		var tmp := _amb_a
		_amb_a = _amb_b
		_amb_b = tmp
		_amb_a.stream = AMBIENCE[want]
		_amb_a.play()
	_amb_a.volume_db = move_toward(_amb_a.volume_db, -6.0, delta * 30.0)
	_amb_b.volume_db = move_toward(_amb_b.volume_db, -80.0, delta * 30.0)
	if _amb_b.volume_db <= -79.0 and _amb_b.playing:
		_amb_b.stop()


## Which checkpoint (if any) contains a point, and whether it's the exit.
func zone_at(p: Vector3) -> Dictionary:
	var found := {}
	for z in zones:
		if z.rect.has_point(Vector2(p.x, p.z)):
			found = z
	return found


# --- Host: generator, escapes --------------------------------------------------------------------

func _host_tick(delta: float) -> void:
	if state.gen == 1:
		gen_timer -= delta
		gen_noise_timer -= delta
		if gen_noise_timer <= 0.0:
			gen_noise_timer = 1.0
			NoiseBus.make(Vector3(10.5, SURFACE, -42.0), 0.3, "generator", false)
		if gen_timer <= 0.0:
			set_state("gen", 2)
			broadcast_message("The generator is running. The lights are on in the dark sector.")


func set_state(key: String, value) -> void:
	state[key] = value
	_apply_state(key)
	Net.send(self, &"_set_state", [key, value])


@rpc("authority", "call_remote", "reliable")
func _set_state(key: String, value) -> void:
	state[key] = value
	_apply_state(key)


func _apply_all_state() -> void:
	for k in state:
		_apply_state(k)


func _apply_state(key: String) -> void:
	match key:
		"gen":
			var on: bool = state.gen == 2
			var fittings: Array = hall_b_fittings.duplicate()
			for l in hall_b_lights:
				l.visible = on
				fittings.append(l.get_meta("fitting"))
			for f: MeshInstance3D in fittings:
				(f.material_override as StandardMaterial3D).emission_energy_multiplier = 1.5 if on else 0.0
			if state.gen == 1:
				generator_audio.stream = preload("res://assets/audio/generator_start.ogg")
				generator_audio.play()
			elif on:
				generator_audio.stream = preload("res://assets/audio/generator_hum.ogg")
				generator_audio.stream.loop = true
				generator_audio.play()
			NoiseBus.cover_zones = [{"pos": Vector3(10.5, SURFACE, -44.0), "radius": 8.0, "mask": 0.6, "active": on}]
		"fuel":
			if generator_glass:
				var f: float = clampf(state.fuel / 2.0, 0.0, 1.0)
				generator_glass.scale = Vector3(1, maxf(f, 0.01), 1)
				generator_glass.position.y = 0.5 - 0.33 * (1.0 - f)
		"key_used":
			if state.key_used and items.has("Key"):
				items["Key"].retire()
		"all_escaped":
			if state.all_escaped:
				Game.notify("Everyone escaped! Back to the title in a few seconds.")
				get_tree().create_timer(8.0).timeout.connect(func():
					if Game.level == self:
						Game.go_to_menu("You escaped the Shallow Halls. Thanks for playing the RIPPLE demo."))


## Ask the host to do something to the world.
func request(action: String, args: Array = []) -> void:
	Net.to_host(self, &"_srv_request", [action, args])


@rpc("any_peer", "call_remote", "reliable")
func _srv_request(action: String, args: Array) -> void:
	if not (Net.is_host() or not Net.is_online()):
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = Net.my_id()
	match action:
		"unlock":
			if not state.staff_door:
				set_state("staff_door", true)
				set_state("key_used", true)
				play_sfx("door", lock_point)
				NoiseBus.make(lock_point, 0.05, "door", false)
		"fuel":
			if state.gen == 0:
				var amount: float = args[0]
				set_state("fuel", minf(2.0, state.fuel + amount))
				if args[1]:
					set_state("fuel_distilled", minf(2.0, state.fuel_distilled + amount))
				if state.fuel >= 1.9:   # two canteens, give or take a splash
					var distilled_part: float = clampf(state.fuel_distilled / 2.0, 0.0, 1.0)
					gen_timer = 9.0 * (1.0 - 0.7 * distilled_part)
					gen_noise_timer = 0.0
					set_state("gen", 1)
					broadcast_message("The generator is starting up%s." % (" fast (distilled water)" if distilled_part > 0.5 else ""))
		"lever":
			play_sfx("clank", lever_point)
			if state.gen == 2 and not state.cover:
				set_state("cover", true)
				NoiseBus.make(lever_point, 0.7, "lever", false)
				broadcast_message("The pool cover is extending.")
			elif state.gen != 2:
				NoiseBus.make(lever_point, 0.2, "lever", false)
				broadcast_message("The lever clanks. Nothing happens. There's no power.")
		"escaped":
			escaped[sender] = args[0]
			var all := true
			for id in players:
				if not escaped.get(id, false):
					all = false
			if all and players.size() > 0 and not state.all_escaped:
				set_state("all_escaped", true)


func broadcast_message(text: String) -> void:
	Game.notify(text)
	Net.send(self, &"_message", [text])


@rpc("authority", "call_remote", "reliable")
func _message(text: String) -> void:
	Game.notify(text)


func play_sfx(sfx_name: String, pos: Vector3) -> void:
	_sfx(sfx_name, pos)
	Net.send(self, &"_sfx", [sfx_name, pos])


@rpc("any_peer", "call_remote", "reliable")
func _sfx(sfx_name: String, pos: Vector3) -> void:
	if not SFX.has(sfx_name):
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = SFX[sfx_name]
	a.unit_size = 6.0
	add_child(a)
	a.global_position = pos
	a.play()
	a.finished.connect(a.queue_free)


# --- Players -------------------------------------------------------------------------------------

## Host: a peer finished loading. Send them the world, then spawn their player everywhere.
func on_peer_ready(id: int) -> void:
	if not Net.is_host():
		return
	if id != 1:
		var item_list := []
		for it in items.values():
			item_list.append(it.snapshot())
		rpc_id(id, "_snapshot", state, item_list, creature.snapshot())
		for pid in players:
			var p = players[pid]
			rpc_id(id, "_spawn_player", pid, Net.players.get(pid, {}), p.global_position)
	var spawn := spawn_points[mini(players.size(), spawn_points.size() - 1)]
	var info: Dictionary = Net.players.get(id, Net.local_info)
	_spawn_player(id, info, spawn)
	Net.send(self, &"_spawn_player", [id, info, spawn])


@rpc("authority", "call_remote", "reliable")
func _snapshot(world: Dictionary, item_list: Array, creature_state: Array) -> void:
	for k in world:
		state[k] = world[k]
	_apply_all_state()
	cover_amount = 1.0 if state.cover else 0.0
	for entry in item_list:
		var it = items.get(entry[0])
		if it:
			it.apply_snapshot(entry)
	creature.apply_snapshot(creature_state)


@rpc("authority", "call_remote", "reliable")
func _spawn_player(id: int, info: Dictionary, pos: Vector3) -> void:
	if players.has(id):
		return
	var p: Node3D = PlayerScene.new()
	p.name = str(id)
	p.peer_id = id
	p.info = info
	$Players.add_child(p)
	p.global_position = pos
	players[id] = p
	if id == Net.my_id():
		local_player = p
	p.setup()


func on_peer_left(id: int) -> void:
	if players.has(id):
		players[id].queue_free()
		players.erase(id)
	escaped.erase(id)
	if Net.is_host():
		for it in items.values():
			if it.holder == id or it.auth == id:
				_set_item_owner(it.name, 0, 1)
				Net.send(self, &"_set_item_owner", [it.name, 0, 1])


## The creature caught someone (host decides; everyone shows it).
func player_caught(id: int) -> void:
	_caught(id)
	Net.send(self, &"_caught", [id])


@rpc("authority", "call_remote", "reliable")
func _caught(id: int) -> void:
	var p = players.get(id)
	if p:
		_sfx("screech", p.body_position())
		p.on_caught()


## Push another player (or myself).
func push_player(id: int, impulse: Vector3) -> void:
	var p = players.get(id)
	if not p:
		return
	if id == Net.my_id():
		p.receive_push(impulse)
	else:
		p.rpc_id(id, "_pushed", impulse)


# --- Items ---------------------------------------------------------------------------------------

func request_item(item_name: String, action: String) -> void:
	Net.to_host(self, &"_srv_item", [item_name, action])


@rpc("any_peer", "call_remote", "reliable")
func _srv_item(item_name: String, action: String) -> void:
	var it = items.get(item_name)
	if not it:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = Net.my_id()
	if action == "pick":
		# Anyone can take an item, even out of a teammate's hand: that's how items are given.
		_set_item_owner(item_name, sender, sender)
		Net.send(self, &"_set_item_owner", [item_name, sender, sender])
	elif action == "drop" and it.holder == sender:
		_set_item_owner(item_name, 0, sender)
		Net.send(self, &"_set_item_owner", [item_name, 0, sender])


@rpc("authority", "call_remote", "reliable")
func _set_item_owner(item_name: String, holder: int, auth: int) -> void:
	var it = items.get(item_name)
	if it:
		it.set_owner_state(holder, auth)


func _send_item_sync() -> void:
	if Net.other_ready_peers().is_empty():
		return
	var me := Net.my_id()
	var batch := []
	for it in items.values():
		if it.auth == me and it.needs_sync():
			batch.append([it.name, it.global_position, it.global_transform.basis.get_rotation_quaternion(), it.extra_state()])
	if not batch.is_empty():
		Net.send(self, &"_items_sync", [batch])


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _items_sync(batch: Array) -> void:
	var sender := multiplayer.get_remote_sender_id()
	for e in batch:
		var it = items.get(e[0])
		if it and it.auth == sender:
			it.net_target(e[1], e[2], e[3])
