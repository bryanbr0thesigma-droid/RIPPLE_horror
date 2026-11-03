extends Node
## Test server only (--snapshot=PATH): when the file PATH.req appears, turns the server's player to
## face the nearest other player and saves what it sees to PATH as a JPEG.

var path := ""


func _ready() -> void:
	path = str(Game.args.snapshot)


func _process(_delta: float) -> void:
	if path != "" and FileAccess.file_exists(path + ".req"):
		DirAccess.remove_absolute(path + ".req")
		_snap()


func _snap() -> void:
	var L = Game.level
	if not L or not L.local_player:
		return
	var me = L.local_player
	var rig = me.rig
	var target = null
	var best := INF
	for id in L.players:
		var p = L.players[id]
		if p == me:
			continue
		var d: float = p.body_position().distance_to(me.body_position())
		if d < best:
			best = d
			target = p
	if target and rig and rig.get("cam"):
		var eye: Vector3 = rig.cam.global_position
		var dir: Vector3 = (target.body_position() + Vector3.UP * 1.1) - eye
		rig._yaw = atan2(-dir.x, -dir.z)
		rig._pitch = clampf(atan2(dir.y, Vector2(dir.x, dir.z).length()), -1.4, 1.4)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(path, 0.85)
	print("[SNAP] saved (nearest player %.1f m away)" % best)
