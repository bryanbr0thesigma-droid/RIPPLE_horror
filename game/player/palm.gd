class_name Palm
extends RefCounted
## Where the palm is for a tracked hand (a controller's grip transform): a little behind and below
## the grip, where the glove's palm sits. Used for touching soft-body bones.

static func of(hand: Transform3D) -> Vector3:
	return hand * Vector3(0.0, -0.01, 0.05)
