extends NetItem
## A F.A.L.C.O.N. tape in the lobby: "Tape" is 07-W (the Wader), "Tape08" is 08-E ("Going In,
## Coming Out"). Bring it to the VCR (or drop it on it) and it goes in and plays on the TV for
## everyone; it pops back out when the tape ends.

var _asked := 0.0


func build() -> void:
	add_shape_box(Vector3(0.19, 0.03, 0.105), Vector3(0, 0.0133, 0))


func _ready() -> void:
	add_child(OfficeRoom.tape_model(String(name) == "Tape08"))     # which labels: by its name
	super._ready()


func item_tick(delta: float) -> void:
	_asked = maxf(_asked - delta, 0.0)
	var L = Game.level
	if _asked > 0.0 or not L or L.mode != "lobby" or L.state.vhs != "" or stowed != 0:
		return
	# Held up to the slot, or let go on top of the VCR (by whoever is simulating it).
	if (is_held_by_me() or (holder == 0 and is_mine())) and global_position.distance_to(L.get_node("Lobby").SLOT) < 0.3:
		insert()


## Desktop: pressing interact on the VCR while holding the tape.
func use_on(target: Node) -> bool:
	if target and target.is_in_group("vcr"):
		insert()
		return true
	return false


func insert() -> void:
	_asked = 2.0
	Game.level.request("vhs_in", [String(name)])
