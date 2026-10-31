extends NetItem
## A bottle to throw. Where it lands in the water, it makes a loud noise: a decoy.


func build() -> void:
	mass = 0.4
	var glass := Color(0.25, 0.45, 0.3)
	add_cylinder(0.035, 0.18, glass, Vector3.ZERO, true, 0.1)
	add_cylinder(0.014, 0.07, glass, Vector3(0, 0.12, 0), false, 0.1)
	add_cylinder(0.016, 0.015, Color(0.6, 0.15, 0.1), Vector3(0, 0.16, 0), false)


## Desktop throws on release of the use button (handled by the desktop rig).
func is_throwable() -> bool:
	return true
