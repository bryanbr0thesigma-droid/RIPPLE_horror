extends XRToolsPickable
## The pool cover lever's handle. Grab it (VR) or press interact on it (desktop) to pull it.

var _cooldown := 0.0


func _init() -> void:
	collision_layer = LevelGeometry.L_ITEMS
	collision_mask = 0
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	ranged_grab_method = RangedMethod.NONE
	release_mode = ReleaseMode.FROZEN
	add_to_group("lever")
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.12
	cs.shape = sh
	add_child(cs)


func _ready() -> void:
	super._ready()
	picked_up.connect(func(_p):
		pull()
		drop.call_deferred())


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func pull() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = 1.5
	Game.level.request("lever")
