extends Node3D
## How other players look: a simple suited body in their color, a head with a visor, two gloves,
## and their name. Follows their head and hand tracking (or desktop camera).

var peer_id := 0
var body: AnimatableBody3D
var torso: MeshInstance3D
var head: MeshInstance3D
var hands: Array[MeshInstance3D] = []
var label: Label3D
var _t_head := Transform3D()
var _t_hands := [Transform3D(), Transform3D()]
var _t_feet := Vector3.ZERO
var _alive := true
var _has := false
var _flash := 0.0


func setup(info: Dictionary, id: int) -> void:
	peer_id = id
	set_as_top_level(true)
	var color: Color = info.get("color", Color(0.9, 0.5, 0.2))
	var suit := StandardMaterial3D.new()
	suit.albedo_color = color
	suit.roughness = 0.6
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.09, 0.1)
	dark.metallic = 0.6
	dark.roughness = 0.2
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
	torso = MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.24
	cm.height = 1.35
	torso.mesh = cm
	torso.material_override = suit
	torso.position = Vector3(0, 0.72, 0)
	body.add_child(torso)
	head = MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.14
	hm.height = 0.3
	head.mesh = hm
	head.material_override = suit
	add_child(head)
	var visor := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.2, 0.09, 0.06)
	visor.mesh = vm
	visor.material_override = dark
	visor.position = Vector3(0, 0.01, -0.12)
	head.add_child(visor)
	for i in 2:
		var h := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.04, 0.16)
		h.mesh = bm
		h.material_override = suit
		add_child(h)
		hands.append(h)
	label = Label3D.new()
	label.text = str(info.get("name", "Player"))
	label.pixel_size = 0.003
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color.lightened(0.3)
	add_child(label)


func set_target(h: Transform3D, lh: Transform3D, rh: Transform3D, feet: Vector3, alive: bool) -> void:
	_t_head = h
	_t_hands = [lh, rh]
	_t_feet = feet
	_alive = alive
	if not _has:
		_has = true
		_apply(1.0)


func flash_caught() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	if not _has:
		return
	_apply(clampf(delta * 15.0, 0.0, 1.0))
	visible = _alive or _flash > 0.0
	_flash = maxf(_flash - delta, 0.0)


func _apply(k: float) -> void:
	head.global_transform = head.global_transform.interpolate_with(_t_head, k)
	for i in 2:
		hands[i].global_transform = hands[i].global_transform.interpolate_with(_t_hands[i], k)
	var head_pos := head.global_position
	var yaw := atan2(-_t_head.basis.z.x, -_t_head.basis.z.z)
	var feet := body.global_position.lerp(_t_feet, k)
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw + PI), feet)
	var height := clampf(head_pos.y - feet.y, 0.6, 2.0)
	torso.scale = Vector3(1, height / 1.6, 1)
	torso.position.y = height * 0.45
	label.global_position = head_pos + Vector3.UP * 0.3
