extends Control
## The main menu: pick a name and color, host a game, or join one (found on the LAN, or typed in
## with the keypad so it works in VR without a keyboard).

const COLORS := [Color(0.95, 0.55, 0.15), Color(0.2, 0.6, 0.95), Color(0.3, 0.8, 0.35), Color(0.85, 0.25, 0.3), Color(0.8, 0.8, 0.2), Color(0.7, 0.4, 0.9)]

var _status: Label
var _hosts_box: VBoxContainer
var _ip_label: Label
var _ip := ""
var _name_edit: LineEdit
var _swatches: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 36)
	margin.add_child(cols)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	cols.add_child(left)
	left.add_child(_label("RIPPLE", 54, Color(0.6, 0.9, 0.95)))
	left.add_child(_label("Co-op test level. Something in the water hunts by sound.", 20, Color(0.75, 0.82, 0.84)))
	left.add_child(_label("Your name", 18))
	_name_edit = LineEdit.new()
	_name_edit.text = str(Game.args.get("name", Net.local_info.name))
	_name_edit.custom_minimum_size = Vector2(0, 44)
	_name_edit.text_changed.connect(func(t): Net.local_info.name = t if t != "" else "Player")
	Net.local_info.name = _name_edit.text
	left.add_child(_name_edit)
	left.add_child(_label("Your color", 18))
	var sw := HBoxContainer.new()
	for c in COLORS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 52)
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(26)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		var pressed := sb.duplicate()
		pressed.border_color = Color.WHITE
		pressed.set_border_width_all(4)
		b.add_theme_stylebox_override("pressed", pressed)
		b.toggle_mode = true
		b.pressed.connect(_pick_color.bind(c, b))
		sw.add_child(b)
		_swatches.append(b)
	left.add_child(sw)
	_pick_color(Net.local_info.color, _swatches[0])
	var host := _button("Host a game", _on_host)
	left.add_child(host)
	var solo := _button("Play solo", _on_host)
	left.add_child(solo)
	_status = _label(Game.menu_message, 18, Color(1.0, 0.75, 0.5))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_status)
	var help := _label("Desktop: WASD, mouse, E pick up/use, left mouse use item, right mouse reach down, Space jump/climb out, Ctrl crouch, Shift run, Q drop, F shove.\nVR: left stick move, right stick turn, A/X jump, grip grab, trigger use.", 15, Color(0.6, 0.66, 0.68))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(help)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	cols.add_child(right)
	right.add_child(_label("Join a game on your network", 22))
	_hosts_box = VBoxContainer.new()
	right.add_child(_hosts_box)
	right.add_child(_label("Or type the host's address", 18))
	_ip_label = _label("_", 30, Color(0.9, 0.95, 0.95))
	right.add_child(_ip_label)
	var pad := GridContainer.new()
	pad.columns = 4
	for k in ["1", "2", "3", "<", "4", "5", "6", ".", "7", "8", "9", "0"]:
		var b := Button.new()
		b.text = k
		b.custom_minimum_size = Vector2(72, 56)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_key.bind(k))
		pad.add_child(b)
	right.add_child(pad)
	right.add_child(_button("Join this address", func(): _join(_ip)))
	var addrs := Net.local_addresses()
	right.add_child(_label("This computer: " + (", ".join(addrs) if addrs.size() > 0 else "no network found"), 15, Color(0.6, 0.66, 0.68)))

	Net.hosts_changed.connect(_refresh_hosts)
	Net.session_failed.connect(func(r): _status.text = r)
	Net.session_started.connect(_on_started)
	Net.start_listening()
	_refresh_hosts()


func _exit_tree() -> void:
	Net.stop_listening()


func _label(text: String, size: int, color := Color(0.85, 0.9, 0.9)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b


func _pick_color(c: Color, which: Button) -> void:
	Net.local_info.color = c
	for b in _swatches:
		b.button_pressed = b == which


func _key(k: String) -> void:
	if k == "<":
		_ip = _ip.substr(0, maxi(_ip.length() - 1, 0))
	elif _ip.length() < 15:
		_ip += k
	_ip_label.text = _ip if _ip != "" else "_"


func _refresh_hosts() -> void:
	for c in _hosts_box.get_children():
		c.queue_free()
	if Net.lan_hosts.is_empty():
		_hosts_box.add_child(_label("Looking for games...", 16, Color(0.6, 0.66, 0.68)))
	for ip in Net.lan_hosts:
		var h: Dictionary = Net.lan_hosts[ip]
		_hosts_box.add_child(_button("%s's game (%d/%d)  %s" % [h.name, h.players, Net.MAX_PLAYERS, ip], func(): _join(ip)))


func _on_host() -> void:
	Net.local_info.vr = Game.vr_mode
	if Net.host() == OK:
		_status.text = "Starting..."


func _join(ip: String) -> void:
	if ip.strip_edges() == "":
		_status.text = "Type the host's address first."
		return
	Net.local_info.vr = Game.vr_mode
	_status.text = "Connecting to %s..." % ip
	Net.join(ip)


func _on_started() -> void:
	Game.start_level()
