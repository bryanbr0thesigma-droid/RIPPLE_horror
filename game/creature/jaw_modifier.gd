extends SkeletonModifier3D
## The unhinged jaw: after the animation plays, open the jaw bone further than any animation does
## and stretch it longer.

const OPEN := 0.75
const STRETCH := 1.3

var _jaw := -1


func _ready() -> void:
	var sk := get_skeleton()
	if not sk:
		return
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).to_lower().begins_with("jaw"):
			_jaw = i
			break


func _process_modification() -> void:
	var sk := get_skeleton()
	if not sk or _jaw < 0:
		return
	var rot := sk.get_bone_pose_rotation(_jaw)
	sk.set_bone_pose_rotation(_jaw, rot * Quaternion(Vector3.RIGHT, OPEN))
	sk.set_bone_pose_scale(_jaw, Vector3(1.0, STRETCH, 1.0))
