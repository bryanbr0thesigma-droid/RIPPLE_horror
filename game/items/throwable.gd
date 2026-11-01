extends NetItem
## A bottle to throw. Where it lands in the water, it makes a loud noise: a decoy.


func build() -> void:
	mass = 0.4


## Each bottle is one of the four approved ones (picked by its name, so everyone sees the same).
func _ready() -> void:
	var files := ["bottle_beer", "bottle_glass_1", "bottle_glass_2", "bottle_glass_3"]
	var i := absi(hash(String(name))) % files.size()
	add_model("res://assets/props/%s.glb" % files[i])
	var tall := 0.24 if i == 0 else 0.3
	add_shape_cylinder(0.04 if i < 2 else 0.055, tall * 0.95)
	super._ready()


## Desktop throws on release of the use button (handled by the desktop rig).
func is_throwable() -> bool:
	return true
