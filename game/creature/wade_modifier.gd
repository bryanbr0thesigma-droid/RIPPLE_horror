extends SkeletonModifier3D
## The creature's body in the shallow water, posed bone by bone on top of whatever animation plays
## (the model has no upright walk of its own):
## - stance and wading: tall and hunched, legs nearly straight, stepping with high knees through the
##   water (IK); the hips bob, sway and turn with the stride while the chest turns against them; the
##   long arms hang and swing behind the stride; the head scans slowly.
## - feeding: crouched low over the remains, reaching into the water, lifting a piece to its mouth,
##   biting and tearing at it (see creature.gd for the timing).
## - the kill holds: both hands on the victim, head bent down to bite.
## Everything is worked out in the creature's own space in metres (+Z ahead, +X its left, +Y up)
## and turned into skeleton space.

var creature: Node3D
## Walking: 0 = standing, 1 = full stride. phase advances by PI per step (see creature.gd).
var amount := 0.0
var phase := 0.0
var stride := 0.8                 # metres per step; set from the leg length in setup()
## 0 = leave the animation alone (crawling, running, searching), 1 = the upright stance and wade.
var stance := 1.0
## Head turn left/right (radians) and tilt down, for scanning and listening.
var look := 0.0
var look_down := 0.0
## Feeding (0..1 blend), and where the hand and mouth are in the feeding cycle:
##   feed_reach: 0 = hand up at the mouth, 1 = hand down in the water at the remains
##   feed_tear: a sharp head jerk back and to the side, tearing a mouthful off
var feed := 0.0
var feed_reach := 0.0
var feed_tear := 0.0
var feed_point := Vector3.ZERO    # world: the remains it's feeding on
## The kill: both hands close on a point in front of it (world), and its head bends down to it.
var hold := 0.0
var hold_point := Vector3.ZERO
var bite := 0.0
## Optional separate targets (world) for the left and right hands; null means the shared hold.
var hand_goals: Array = [null, null]
var debug_hands: Array = [Vector3.ZERO, Vector3.ZERO]   # where the hands ended up (world), for tests
var debug_top := 0.0              # height of the head above the feet (metres), for tests

const DUTY := 0.62                # share of a step cycle each foot is on the floor
const LIFT := 0.36                # how high the foot comes up through the water (metres)

var _hips := -1
var _spine: Array[int] = []       # spine.001 .. spine.005 (the last two are the neck)
var _head := -1
var _jaw := -1
var _legs: Array = []             # [thigh, shin, foot, toe] per side, left first
var _arms: Array = []             # [shoulder, upper arm, forearm, hand] per side, left first
var _arm_chains: Array = []       # [upper arm, forearm, hand] per side (for the kill holds)
var _upper_back := -1
var _t := 0.0
var _leg_m := 1.5                 # thigh + shin, metres (worked out on the first frame)
var _foot_m := 0.3


func setup(sk: Skeleton3D) -> void:
	_hips = _bone(sk, "spine_01")
	for n in ["spine.001", "spine.002", "spine.003", "spine.004", "spine.005"]:
		_spine.append(_bone(sk, n))
	_head = _bone(sk, "head")
	_jaw = _bone(sk, "jaw")
	_upper_back = _bone(sk, "spine.003")
	for side in [".L", ".R"]:
		_legs.append([_bone(sk, "thigh" + side), _bone(sk, "shin" + side), _bone(sk, "foot" + side), _bone(sk, "toe" + side)])
		_arms.append([_bone(sk, "shoulder" + side), _bone(sk, "upper_arm" + side), _bone(sk, "forearm" + side), _bone(sk, "hand" + side)])
		_arm_chains.append([_bone(sk, "upper_arm" + side), _bone(sk, "forearm" + side), _bone(sk, "hand" + side)])


func _bone(sk: Skeleton3D, prefix: String) -> int:
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).begins_with(prefix):
			return i
	return -1


## One foot's place relative to its hip (metres, creature space: forward, up) at a step phase.
func _foot(ph: float, reach: float) -> Vector2:
	var u := fposmod(ph, TAU) / TAU
	if u < DUTY:                                   # planted: slides back under the body
		return Vector2(reach * (1.0 - 2.0 * u / DUTY), 0.0)
	var s := (u - DUTY) / (1.0 - DUTY)             # swinging: knee up, out of the water, forward
	return Vector2(-reach + 2.0 * reach * smoothstep(0.0, 1.0, s), LIFT * pow(sin(PI * s), 0.8))


static func _aim(b: Basis, dir: Vector3) -> Basis:
	var cur := (b * Vector3.UP).normalized()
	var d := dir.normalized()
	if cur.dot(d) > 0.99999:
		return b
	if cur.dot(d) < -0.9999:
		return Basis(b.x.normalized(), PI) * b
	return Basis(Quaternion(cur, d)) * b


static func _lean(fwd: float, yaw := 0.0, roll := 0.0) -> Vector3:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, roll) * Vector3(0.0, cos(fwd), sin(fwd))


func _process_modification() -> void:
	var sk := get_skeleton()
	if not sk or not creature or _hips < 0 or _legs.size() < 2:
		return
	_t += 1.0 / maxf(Engine.get_frames_per_second(), 30.0)
	var to_sk: Transform3D = sk.global_transform.affine_inverse() * creature.global_transform
	var R := to_sk.basis.orthonormalized()
	var u := to_sk.basis.get_scale().x                 # skeleton units per metre
	var w := clampf(stance, 0.0, 1.0)
	if w > 0.001:
		_pose_body(sk, to_sk, R, u, w)
	if hold > 0.01 or bite > 0.01:
		_hold(sk)
	var top := sk.global_transform * sk.get_bone_global_pose(_head).origin
	debug_top = (creature.global_transform.affine_inverse() * top).y


func _put(sk: Skeleton3D, i: int, want: Transform3D, w: float) -> void:
	if w >= 0.999:
		sk.set_bone_global_pose(i, want)
	else:
		sk.set_bone_global_pose(i, sk.get_bone_global_pose(i).interpolate_with(want, w))


func _pose_body(sk: Skeleton3D, to_sk: Transform3D, R: Basis, u: float, w: float) -> void:
	# Proportions, from the skeleton itself.
	var th0: Transform3D = sk.get_bone_global_pose(_legs[0][0])
	var sh0: Transform3D = sk.get_bone_global_pose(_legs[0][1])
	var ft0: Transform3D = sk.get_bone_global_pose(_legs[0][2])
	var to0: Transform3D = sk.get_bone_global_pose(_legs[0][3])
	_leg_m = (th0.origin.distance_to(sh0.origin) + sh0.origin.distance_to(ft0.origin)) / u
	_foot_m = ft0.origin.distance_to(to0.origin) / u
	stride = _leg_m * 0.55
	var walk := clampf(amount, 0.0, 1.0)
	var crouch := clampf(feed, 0.0, 1.0)
	var reach := DUTY * stride * walk
	var ankle_h := _foot_m * 0.28
	var breathe := sin(_t * 1.3)
	# The feet (relative to their hips) and how lifted each one is.
	var f0 := _foot(phase, reach)
	var f1 := _foot(phase + PI, reach)
	var f: Array[Vector2] = [f0, f1]
	var lift_n: Array[float] = [f0.y / LIFT, f1.y / LIFT]
	var fwd_n: Array[float] = [0.0, 0.0]
	if walk > 0.01:
		fwd_n = [f0.x / maxf(reach, 1e-3), f1.x / maxf(reach, 1e-3)]
	# Hips: nearly straight legs (low and bent right over when feeding), bobbing with the steps,
	# swaying over the planted foot, turning with the swinging leg, dropping on its side.
	var still := 1.0 - walk
	var hip_h := ankle_h + _leg_m * lerpf(lerpf(0.9, 0.86, still), 0.5, crouch)
	var bob := -0.03 * cos(2.0 * phase) * walk + 0.006 * breathe
	var sway := 0.045 * (lift_n[1] - lift_n[0]) * walk + 0.035 * sin(_t * 0.45) * still
	var p_yaw := -deg_to_rad(7.0) * fwd_n[0] * walk
	var p_roll := deg_to_rad(4.0) * (lift_n[1] - lift_n[0]) * walk
	var p_tilt := deg_to_rad(lerpf(12.0, 40.0, crouch))
	var H := sk.get_bone_global_pose(_hips)
	var want := Transform3D(Basis(R * Vector3.UP, p_yaw) * Basis(R * Vector3.BACK, p_roll) * _aim(H.basis, R * _lean(p_tilt)), H.origin)
	want.origin = to_sk * Vector3(sway, hip_h + bob, lerpf(0.0, -0.25, crouch))
	# Put the hip joints (where the thighs start), not the pelvis bone, at that height.
	sk.set_bone_global_pose(_hips, want)
	var thigh_y := ((to_sk.affine_inverse() * sk.get_bone_global_pose(_legs[0][0]).origin).y + (to_sk.affine_inverse() * sk.get_bone_global_pose(_legs[1][0]).origin).y) * 0.5
	want.origin += R * Vector3.UP * (hip_h + bob - thigh_y) * u
	sk.set_bone_global_pose(_hips, H)
	_put(sk, _hips, want, w)
	# The spine curls forward into a hunch (much further when feeding); the chest turns against
	# the hips. The last two are the neck, curving back up so the face looks ahead.
	var leans: Array[float] = [30.0, 46.0, 64.0, 74.0, 44.0]
	var feed_leans: Array[float] = [44.0, 56.0, 68.0, 70.0, 30.0]
	var yaws: Array[float] = [-0.3, -0.6, -0.7, -0.3, 0.0]
	for k in _spine.size():
		var i: int = _spine[k]
		if i < 0:
			continue
		var g := sk.get_bone_global_pose(i)
		var lean := deg_to_rad(lerpf(leans[k], feed_leans[k], crouch)) + 0.012 * breathe * (k - 1)
		if k >= 3:
			lean += deg_to_rad(look_down) * 0.5
		var yaw: float = p_yaw * yaws[k] + (look * 0.25 if k >= 3 else 0.0)
		if crouch > 0.01 and k >= 3:                     # tearing at a mouthful
			lean -= feed_tear * deg_to_rad(25.0)
			yaw += feed_tear * 0.35
		g.basis = _aim(Basis(R * Vector3.UP, yaw - (p_yaw * yaws[k - 1] if k > 0 else p_yaw)) * g.basis, R * _lean(lean, yaw))
		_put(sk, i, g, w)
	if _head >= 0:
		var g := sk.get_bone_global_pose(_head)
		var nod := deg_to_rad(10.0 + look_down) + 0.02 * breathe
		g.basis = _aim(g.basis, R * _lean(nod + crouch * deg_to_rad(30.0) - feed_tear * deg_to_rad(20.0), look * 0.6 + feed_tear * 0.3))
		_put(sk, _head, g, w)
	# Legs: each foot planted under its hip or swinging forward with the knee raised.
	for i in 2:
		var leg: Array = _legs[i]
		var s := 1.0 if i == 0 else -1.0
		var hip_c := to_sk.affine_inverse() * sk.get_bone_global_pose(leg[0]).origin
		var fp: Vector2 = f[i]
		var stand_off := 0.08 * s if walk < 0.01 else 0.0     # standing: one foot a little ahead
		var foot_c := Vector3(hip_c.x * lerpf(lerpf(0.85, 1.25, still), 1.3, crouch), ankle_h + fp.y, hip_c.z + fp.x + stand_off * (1.0 - crouch))
		if crouch > 0.01:
			foot_c.z = lerpf(foot_c.z, hip_c.z + 0.15 + 0.1 * s, crouch)
		var knee_c := Vector3(hip_c.x * 1.1, hip_c.y, hip_c.z) + Vector3(0, 0, 1.0)
		var target := to_sk * foot_c
		var anim_foot := sk.get_bone_global_pose(leg[2]).origin
		TwoBoneIK.solve(sk, leg[0], leg[1], leg[2], anim_foot.lerp(target, w), to_sk * knee_c, R * Vector3.BACK)
		# The foot: flat on the floor while planted, toes pointing down as it lifts.
		var g := sk.get_bone_global_pose(leg[2])
		var pitch := asin(clampf(ankle_h / maxf(_foot_m, 0.01), 0.0, 1.0)) + deg_to_rad(55.0) * float(lift_n[i])
		_put(sk, leg[2], Transform3D(_aim(g.basis, R * Vector3(0.0, -sin(pitch), cos(pitch))), g.origin), w)
	# Arms: hanging long, swinging opposite the legs and lagging behind them, elbows a little bent.
	for i in 2:
		var arm: Array = _arms[i]
		if arm[1] < 0 or arm[2] < 0:
			continue
		var s := 1.0 if i == 0 else -1.0
		var lag := _foot(phase + PI * (1 - i) - 0.7, reach)        # the opposite leg, a moment ago
		var swing := deg_to_rad(11.0) * (lag.x / maxf(reach, 1e-3)) * walk if walk > 0.01 else 0.0
		var idle := deg_to_rad(3.0) * sin(_t * 0.9 + i * 1.7)
		if arm[0] >= 0:                                     # shoulders roll with the stride
			var g := sk.get_bone_global_pose(arm[0])
			g.basis = Basis(R * Vector3.BACK, deg_to_rad(4.0) * s * float(lift_n[1 - i]) * walk) * g.basis
			_put(sk, arm[0], g, w)
		var fwd_up := deg_to_rad(2.0 + 30.0 * crouch) + swing + idle
		var out := deg_to_rad(16.0)
		var g1 := sk.get_bone_global_pose(arm[1])
		g1.basis = _aim(g1.basis, R * _hang(fwd_up, out, s))
		_put(sk, arm[1], g1, w)
		var bend := deg_to_rad(16.0) + swing * 0.5 + idle * 1.5
		var g2 := sk.get_bone_global_pose(arm[2])
		g2.basis = _aim(g2.basis, R * _hang(fwd_up + bend, out * 0.4, s))
		_put(sk, arm[2], g2, w)
		if arm[3] >= 0:
			var g3 := sk.get_bone_global_pose(arm[3])
			g3.basis = _aim(g3.basis, R * _hang(fwd_up + bend + deg_to_rad(12.0), out * 0.2, s))
			_put(sk, arm[3], g3, w)
	# Feeding: the left hand braced in the water in front; the right hand goes down into the water at
	# the remains and comes back up to the mouth.
	if crouch > 0.01 and _arm_chains.size() > 1:
		var lc: Array = _arm_chains[0]
		var brace := to_sk * Vector3(0.42, 0.5, 0.62 + 0.03 * sin(_t * 2.0))
		var lsh := sk.get_bone_global_pose(lc[0]).origin
		TwoBoneIK.solve(sk, lc[0], lc[1], lc[2], sk.get_bone_global_pose(lc[2]).origin.lerp(brace, crouch * w), lsh + R * Vector3(0.7, -0.2, -0.2) * u, R * Vector3.DOWN)
		var ch: Array = _arm_chains[1]
		var inv := sk.global_transform.affine_inverse()
		var mouth := sk.get_bone_global_pose(_jaw if _jaw >= 0 else _head).origin + R * Vector3(-0.04, -0.1, 0.1) * u
		var down := inv * feed_point
		var goal := mouth.lerp(down, clampf(feed_reach, 0.0, 1.0))
		var hand := sk.get_bone_global_pose(ch[2]).origin
		var sh := sk.get_bone_global_pose(ch[0]).origin
		TwoBoneIK.solve(sk, ch[0], ch[1], ch[2], hand.lerp(goal, crouch * w), sh + R * Vector3(-0.6, -0.7, 0.1) * u, R * Vector3.DOWN)
		debug_hands[1] = sk.global_transform * sk.get_bone_global_pose(ch[2]).origin


## A direction hanging down, swung forward by fwd and out to the side (s = 1 left, -1 right).
static func _hang(fwd: float, out: float, s: float) -> Vector3:
	return Vector3(sin(out) * s, -cos(out) * cos(fwd), cos(out) * sin(fwd)).normalized()


func _hold(sk: Skeleton3D) -> void:
	var inv := sk.global_transform.affine_inverse()
	var to_sk: Transform3D = inv * creature.global_transform
	var rot := to_sk.basis.orthonormalized()
	var u := to_sk.basis.get_scale().x
	var up := (rot * Vector3.UP).normalized()
	var side := (rot * Vector3.RIGHT).normalized()
	var target := inv * hold_point
	# Bend the upper back so the head comes down to the victim.
	if bite > 0.01 and _upper_back >= 0 and _head >= 0:
		var b := sk.get_bone_global_pose(_upper_back)
		var h := sk.get_bone_global_pose(_head).origin
		var want := target + up * 0.25 * u
		var d0 := (h - b.origin).normalized()
		var d1 := (want - b.origin).normalized()
		if d0.dot(d1) < 0.9999:
			var ang := minf(d0.angle_to(d1), deg_to_rad(70.0)) * bite
			b.basis = Basis(d0.cross(d1).normalized(), ang) * b.basis
			sk.set_bone_global_pose(_upper_back, b)
	# Both hands on the victim's sides.
	if hold > 0.01:
		for i in _arm_chains.size():
			var ch: Array = _arm_chains[i]
			var s := 1.0 if i == 0 else -1.0     # .L is the creature's left: +x in its own space
			var grip := target + side * s * 0.22 * u
			if hand_goals[i] != null:
				grip = inv * (hand_goals[i] as Vector3)
			var hand := sk.get_bone_global_pose(ch[2]).origin
			var goal := hand.lerp(grip, hold)
			var sh := sk.get_bone_global_pose(ch[0]).origin
			var pole := sh + side * s * 0.6 * u - up * 0.4 * u
			TwoBoneIK.solve(sk, ch[0], ch[1], ch[2], goal, pole, up)
			debug_hands[i] = sk.global_transform * sk.get_bone_global_pose(ch[2]).origin
