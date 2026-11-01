extends NetItem
## A player's backpack once they've died: it floats where they died with a faint glow, holding
## everything they carried (in their hands and in their backpack). Anyone alive can carry it.
## Carried into a dry room by a teammate, it brings its owner back from being a ghost. Its owner
## grabbing it, or coming back, empties it back into their backpack. Hidden the rest of the time
## (it's "on their back").

var owner_peer := 0
var _home_timer := 0.0
var _glow: OmniLight3D


func build() -> void:
	steady = true
	mass = 1.0
	add_box(Vector3(0.3, 0.38, 0.14), Color(0.2, 0.22, 0.17))
	var strap := add_box(Vector3(0.31, 0.03, 0.15), Color(0.4, 0.9, 0.8), Vector3(0, 0.1, 0), false)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.4, 0.9, 0.8)
	sm.emission_enabled = true
	sm.emission = Color(0.4, 0.95, 0.85)
	sm.emission_energy_multiplier = 1.5
	strap.material_override = sm
	_glow = OmniLight3D.new()                 # so it can be found in the dark
	_glow.light_color = Color(0.45, 0.95, 0.85)
	_glow.light_energy = 0.35
	_glow.omni_range = 2.0
	_glow.shadow_enabled = false
	_glow.position = Vector3(0, 0.3, 0)
	add_child(_glow)


func _ready() -> void:
	super._ready()
	set_stowed(owner_peer)                    # on its owner's back until they die


func _on_xr_picked_up(p) -> void:
	super._on_xr_picked_up(p)
	_owner_took_it()


func grab_desktop(rig: Node3D) -> void:
	super.grab_desktop(rig)
	_owner_took_it()


## Its owner, alive, picking it up: everything goes back in their backpack.
func _owner_took_it() -> void:
	if owner_peer == Net.my_id() and Game.level:
		var me = Game.level.local_player
		if me and me.alive:
			if desktop_holder and desktop_holder.has_method("forget_item"):
				desktop_holder.forget_item(self)
			Game.level.request("bag_return", [])


func item_tick(delta: float) -> void:
	# A teammate carries it into a dry room: its owner comes back there.
	_home_timer -= delta
	if is_mine() and holder != 0 and holder != owner_peer and _home_timer <= 0.0 and Game.level:
		_home_timer = 0.5
		var z: Dictionary = Game.level.zone_at(global_position)
		if z.has("checkpoint"):
			Game.level.request("bag_home", [owner_peer, z.checkpoint])
