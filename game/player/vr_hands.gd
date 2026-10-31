class_name VRHands
extends RefCounted
## First-person hands match the gloves of the suit you picked.

const GLOVE := preload("res://addons/godot-xr-tools/hands/materials/cleaning_glove.tres")


static func tint(hand: Node, color: Color) -> void:
	if not hand or not ("hand_material_override" in hand):
		return
	var m: BaseMaterial3D = GLOVE.duplicate()
	m.albedo_texture = null
	m.albedo_color = color.lightened(0.15)
	hand.hand_material_override = m
