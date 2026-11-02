extends CanvasLayer
## Desktop on-screen text: a crosshair, what you're looking at or holding, and messages.
## In VR, messages float in front of the headset instead (see vr_rig.gd).

var _msg: Label
var _hint: Label
var _info: Label
var _msg_time := 0.0


func _ready() -> void:
	visible = not Game.vr_mode
	var cross := Label.new()
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 22)
	cross.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position -= Vector2(6, 14)
	add_child(cross)
	_msg = _make_label(22, Control.PRESET_CENTER_BOTTOM, Vector2(-450, -150), Color(1.0, 0.92, 0.8))
	_hint = _make_label(17, Control.PRESET_CENTER_BOTTOM, Vector2(-450, -80), Color(0.8, 0.9, 0.9))
	_info = _make_label(15, Control.PRESET_TOP_LEFT, Vector2(16, 12), Color(0.7, 0.78, 0.8))
	Game.message.connect(show_message)


func _make_label(size: int, preset: int, offset: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.set_anchors_preset(preset)
	l.position += offset
	l.size = Vector2(900, 70)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if preset != Control.PRESET_TOP_LEFT else HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(l)
	return l


func show_message(text: String) -> void:
	_msg.text = text
	_msg_time = 6.0


func set_hint(text: String) -> void:
	_hint.text = text


func _process(delta: float) -> void:
	_msg_time -= delta
	_msg.modulate.a = clampf(_msg_time, 0.0, 1.0)
	var lines := []
	if Net.is_host() and Net.is_online_room():
		lines.append("Online room code: %s" % Net.room_code if Net.room_code != "" else "Getting a room code...")
	elif Net.is_host():
		var addrs := Net.local_addresses()
		lines.append("Hosting. Friends join at: %s" % (", ".join(addrs) if addrs.size() > 0 else "?"))
	lines.append("Players: %d" % Net.players.size())
	_info.text = "\n".join(lines)
