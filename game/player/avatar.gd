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


func _process(delta: float) -> void:
	if not _has:
		return
	var k := clampf(delta * 15.0, 0.0, 1.0)
	_head = _head.interpolate_with(_t_head, k)
	for i in 2:
		_hands[i] = (_hands[i] as Transform3D).interpolate_with(_t_hands[i], k)
	_feet = _feet.lerp(_t_feet, k)
	suit.pose(_head, _hands[0], _hands[1], _feet)
	var yaw := atan2(-_head.basis.z.x, -_head.basis.z.z)
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw), _feet)
	label.global_position = _head.origin + Vector3.UP * 0.32
	visible = _alive or _flash > 0.0
	_flash = maxf(_flash - delta, 0.0)
