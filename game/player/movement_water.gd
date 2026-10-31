extends XRToolsMovementProvider
## Water for the VR player: wading is slower, deep water is swimming (you float with your head
## just above the surface and paddle with the left stick), and shoves from teammates land here.

@export var order : int = 12

var rig: Node3D


func physics_movement(delta: float, player_body: XRToolsPlayerBody, disabled: bool):
	if disabled or not rig:
		return false
	if rig.pending_push != Vector3.ZERO:
		player_body.velocity += rig.pending_push
		rig.pending_push = Vector3.ZERO
	var climb := rig.get_node_or_null("MovementClimb")
	if climb and climb.is_active:
		return false
	var feet: Vector3 = player_body.global_position
	var pool := WaterVolume.below(feet + Vector3.UP * 0.05)
	if not pool or feet.y > pool.surface_y - 0.05:
		return false
	player_body.ground_control_velocity *= 0.6
	var cam: XRCamera3D = rig.camera
	if pool.depth() > 1.55 and cam.global_position.y < pool.surface_y + 0.25:
		var stick := Vector2.ZERO
		if rig.left and rig.left.get_is_active():
			stick = rig.left.get_vector2("primary")
		var yaw := Basis(Vector3.UP, cam.global_rotation.y)
		var hv := yaw * Vector3(stick.x, 0, -stick.y) * 1.3
		var vy := clampf(((pool.surface_y + 0.15) - cam.global_position.y) * 3.0, -1.5, 1.5)
		player_body.velocity = player_body.move_player(Vector3(hv.x, vy, hv.z))
		return true
	return false
