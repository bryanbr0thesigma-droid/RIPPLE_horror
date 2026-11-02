extends Control
## In-game pause menu: resume or leave to the title screen.

signal resumed


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.06, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.custom_minimum_size = Vector2(420, 0)
	v.position = Vector2(-210, -170)
	v.add_theme_constant_override("separation", 16)
	add_child(v)
	var t := Label.new()
	t.text = "Paused"
	t.add_theme_font_size_override("font_size", 44)
	t.add_theme_color_override("font_color", Color(0.45, 0.85, 0.9))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var note := Label.new()
	note.text = "The game keeps running for everyone else."
	note.add_theme_font_size_override("font_size", 18)
	note.add_theme_color_override("font_color", Color(0.55, 0.64, 0.66))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	if Net.room_code != "":
		var code := Label.new()
		code.text = "Online room code: %s" % Net.room_code
		code.add_theme_font_size_override("font_size", 30)
		code.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
		code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(code)
	v.add_child(_button("Resume", func(): resumed.emit()))
	v.add_child(_button("Leave to title", func(): Game.go_to_menu("You left the game.")))


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 26)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.14, 0.16)
	normal.border_color = Color(0.25, 0.45, 0.5)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.12, 0.24, 0.27)
	hover.border_color = Color(0.45, 0.85, 0.9)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_color", Color(0.85, 0.92, 0.93))
	b.pressed.connect(cb)
	return b
