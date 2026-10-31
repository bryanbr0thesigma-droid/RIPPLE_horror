extends NetItem
## The staff room key. Bring it to the lock on the staff door. Drop it in the water and it sinks.

var _requested := false


func build() -> void:
	var gold := Color(0.85, 0.68, 0.22)
	add_box(Vector3(0.025, 0.01, 0.1), gold, Vector3(0, 0, 0.02), true, 0.9)
	add_cylinder(0.028, 0.01, gold, Vector3(0, 0, -0.05), true, 0.9)
	add_box(Vector3(0.012, 0.01, 0.03), gold, Vector3(0.016, 0, 0.055), false, 0.9)


func item_tick(_delta: float) -> void:
	if _requested or not is_held_by_me() or Game.level.state.staff_door:
		return
	if global_position.distance_to(Game.level.lock_point) < 0.3:
		try_unlock()


## Desktop: pressing interact on the door while holding the key.
func use_on(target: Node) -> bool:
	if target and (target.name == "StaffDoor" or target.name == "Lock"):
		return try_unlock()
	return false


func try_unlock() -> bool:
	if _requested or Game.level.state.staff_door:
		return false
	_requested = true
	Game.level.request("unlock")
	return true
