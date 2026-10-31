class_name WaterVolume
extends Node3D
## A box of pool water: an XZ rectangle between the pool floor and the surface.
## Mineral patches are water volumes too, inside a pool, and win over the pool they sit in.

static var all: Array[WaterVolume] = []

var rect := Rect2()          # x, z, width, depth in world space
var surface_y := -0.3
var floor_y := -1.3
var mineral := false


static func make(r: Rect2, surface: float, floor_level: float, is_mineral := false) -> WaterVolume:
	var w := WaterVolume.new()
	w.rect = r
	w.surface_y = surface
	w.floor_y = floor_level
	w.mineral = is_mineral
	return w


func _enter_tree() -> void:
	if self not in all:
		all.append(self)


func _exit_tree() -> void:
	all.erase(self)


func contains_xz(p: Vector3) -> bool:
	return rect.has_point(Vector2(p.x, p.z))


func depth() -> float:
	return surface_y - floor_y


## The water volume at a point (below the surface and above the floor), or null.
static func at(p: Vector3) -> WaterVolume:
	var best: WaterVolume = null
	for w in all:
		if w.contains_xz(p) and p.y < w.surface_y and p.y > w.floor_y - 0.3:
			if best == null or w.mineral:
				best = w
	return best


## The pool under a point in XZ, whatever the height (for "is there water below me?").
static func below(p: Vector3) -> WaterVolume:
	var best: WaterVolume = null
	for w in all:
		if w.contains_xz(p) and p.y > w.floor_y - 0.3:
			if best == null or w.mineral:
				best = w
	return best


## The main pool (not a mineral patch) under a point.
static func pool_below(p: Vector3) -> WaterVolume:
	for w in all:
		if not w.mineral and w.contains_xz(p) and p.y > w.floor_y - 0.3:
			return w
	return null
