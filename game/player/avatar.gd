extends Node3D
## How other players look: their chosen suit in their color, following their head and hand
## tracking (or desktop camera), with their name above them.

var peer_id := 0
var body: AnimatableBody3D
var suit: SuitRig
var label: Label3D
var _t_head := Transform3D()
var _t_hands := [Transform3D(), Transform3D()]
var _t_feet := Vector3.ZERO
var _head := Transform3D()
var _hands := [Transform3D(), Transform3D()]
var _feet := Vector3.ZERO
var _alive := true
var _has := false
var _flash := 0.0
var _seized: Node3D = null      # the creature holding this player during a kill
var _seize_t := 0.0
var _under := -1.0


func setup(info: Dictionary, id: int) -> void:
	peer_id = id
	set_as_top_level(true)
	var color: Color = info.get("color", Color(0.9, 0.5, 0.2))
	body = AnimatableBody3D.new()
	body.add_to_group("avatar")
	body.set_meta("peer_id", id)
	body.collision_layer = LevelGeometry.L_AVATARS
	body.collision_mask = 0
	body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	body.add_child(cs)
	add_child(body)
	suit = SuitRig.create(int(info.get("suit", 0)), color)
	add_child(suit)
	suit.add_backpack()
	label = Label3D.new()
	label.text = str(info.get("name", "Player"))
	label.pixel_size = 0.003
	label.font_size = 40
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color.lightened(0.35)
	add_child(label)


func set_target(h: Transform3D, lh: Transform3D, rh: Transform3D, feet: Vector3, alive: bool) -> void:
	_t_head = h
	_t_hands = [lh, rh]
	_t_feet = feet
	_alive = alive
	if not _has:
		_has = true
		_head = h
		_hands = [lh, rh]
		_feet = feet


func flash_caught() -> void:
	_flash = 1.0


## The creature has them: they hang from its jaws, thrashing, until it drags them under.
func seize(creature: Node3D) -> void:
	_seized = creature
	_seize_t = 0.0
	_under = -1.0
	visible = true


func drag_under() -> void:
	_under = 0.0


## The creature tore them apart: torn-off pieces take over, this body hides until they respawn.
## (Dead until their own game says they're alive again; without this the whole body popped back up
## where it stood on the next frame, next to the pieces.)
func release() -> void:
	_seized = null
	_alive = false
	_flash = 0.0
	visible = false


func _held(delta: float) -> void:
	_seize_t += delta
	var c := _seized
	var fwd: Vector3 = c.global_transform.basis.z           # the creature faces the victim
	fwd = Vector3(fwd.x, 0, fwd.z).normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	var t := _seize_t
	var shake := Vector3(sin(t * 31.0), sin(t * 27.0 + 1.0) * 0.6, sin(t * 23.0 + 2.0)) * 0.05
	var chest: Vector3 = c.victim_chest() + shake
	if _under >= 0.0:
		_under += delta
		chest += Vector3.DOWN * clampf(_under / 0.4, 0.0, 1.0) * 1.6
		if _under > 0.5:
			_seized = null
			visible = false
			return
	var look := -fwd                                          # facing the creature, head thrown back
	var head_basis := Basis.looking_at(look, Vector3.UP).rotated(side, 0.7 + sin(t * 9.0) * 0.2)
	var head := Transform3D(head_basis, chest + Vector3.UP * 0.45)
	var flail := func(k: float) -> Vector3:
		return Vector3(sin(t * 13.0 + k), sin(t * 17.0 + k * 2.0), cos(t * 11.0 + k)) * 0.18
	var lh := Transform3D(Basis(), chest - side * 0.38 + Vector3.UP * 0.25 + fwd * 0.1 + flail.call(0.0))
	var rh := Transform3D(Basis(), chest + side * 0.38 + Vector3.UP * 0.2 + fwd * 0.1 + flail.call(3.0))
	var feet := chest + Vector3.DOWN * 1.25 + look * 0.15
	suit.pose(head, lh, rh, feet)
	body.global_transform = Transform3D(Basis(), feet)
	label.global_position = head.origin + Vector3.UP * 0.32


func _process(delta: float) -> void:
	if _seized:
		if is_instance_valid(_seized):
			_held(delta)
			return
		_seized = null
	if not _has:
		return
	var k := clampf(delta * 15.0, 0.0, 1.0)
	_head = _head.interpolate_with(_t_head, k)
	for i in 2:
		_hands[i] = (_hands[i] as Transform3D).interpolate_with(_t_hands[i], k)
	_feet = _feet.lerp(_t_feet, k)
	suit.pose(_head, _hands[0], _hands[1], _feet)
	var yaw := atan2(_head.basis.z.x, _head.basis.z.z)
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw), _feet)
	label.global_position = _head.origin + Vector3.UP * 0.32
	visible = _alive or _flash > 0.0
	_flash = maxf(_flash - delta, 0.0)
