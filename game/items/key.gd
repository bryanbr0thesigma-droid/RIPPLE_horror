extends NetItem
## The staff room key: an old ornate key, in gold. Bring it to the lock on the staff door. Drop it
## in the water and it sinks.

var _requested := false


func build() -> void:
	add_model("res://assets/props/key.glb")
	add_shape_box(Vector3(0.1, 0.1, 0.08))


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
