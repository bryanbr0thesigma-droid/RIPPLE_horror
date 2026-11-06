extends Control
## The title screen menu, one page at a time: Main, Play, Join by address, Character, Settings,
## Connecting. Built for pointing in VR (big buttons, an on-screen keyboard) and works with a
## mouse and keyboard on desktop.

signal character_changed

const COLORS := [Color(0.95, 0.55, 0.15), Color(0.2, 0.6, 0.95), Color(0.3, 0.8, 0.35), Color(0.85, 0.25, 0.3),
	Color(0.85, 0.82, 0.2), Color(0.7, 0.4, 0.9), Color(0.9, 0.9, 0.92), Color(0.15, 0.75, 0.75)]
const INK := Color(0.85, 0.92, 0.93)
const DIM := Color(0.55, 0.64, 0.66)
const ACCENT := Color(0.45, 0.85, 0.9)

var _pages := {}
var _status: Label
var _hosts_box: VBoxContainer
var _ip := ""
var _ip_label: Label
var _code := ""
var _code_label: Label
var _room_text := ""
var _room_label: Label
var _code_msg: Label
var _name_label: Label
var _suit_label: Label
var _suit_about: Label
var _swatches: Array[Button] = []
var _turn_btn: Button
var _body_btn: Button
var _vol_label: Label
var _music_label: Label
var _connecting_label: Label
var _caps := true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.06, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	add_child(margin)
	var stack := Control.new()
	margin.add_child(stack)
	_build_main(stack)
	_build_play(stack)
	_build_address(stack)
	_build_room(stack)
	_build_character(stack)
	_build_code(stack)
	_build_settings(stack)
	_build_credits(stack)
	_build_connecting(stack)
	_status = _label("", 18, Color(1.0, 0.75, 0.5))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.position.y -= 70
	_status.size.y = 64
	stack.add_child(_status)
	_status.text = Game.menu_message
	Net.hosts_changed.connect(_refresh_hosts)
	Net.session_failed.connect(_on_failed)
	Net.session_started.connect(func(): Game.enter_session())
	show_page("main")


# --- Building pages ------------------------------------------------------------------------------

func _page(page_name: String, parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 12)
	parent.add_child(v)
	_pages[page_name] = v
	return v


func _build_main(parent: Control) -> void:
	var p := _page("main", parent)
	var header := TextureRect.new()          # the agency's terminal header (tools/branding)
	header.texture = load("res://assets/branding/menu_header.png")
	header.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.custom_minimum_size = Vector2(0, 112)
	p.add_child(header)
	p.add_child(_label("RIPPLE  ·  Demo: The Shallow Halls", 22, DIM))
	p.add_child(_spacer(18))
	p.add_child(_button("Play", func(): show_page("play"), 30))
	p.add_child(_button("Character", func(): show_page("character"), 30))
	p.add_child(_button("Settings", func(): show_page("settings"), 30))
	p.add_child(_button("Credits", func(): show_page("credits"), 30))
	p.add_child(_button("Watch the tape", func(): Game.play_intro(), 24))
	p.add_child(_button("Quit", func(): get_tree().quit(), 30))
	p.add_child(_spacer(10))
	var hint := _label("The Wader lives in the water. It hunts by sound. Escape together.", 18, DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(hint)


func _build_play(parent: Control) -> void:
	var p := _page("play", parent)
	p.add_child(_label("Play", 40, ACCENT))
	p.add_child(_button("Host online (room code)", _host_online))
	p.add_child(_button("Host a playtest (direct, UPnP)", _host_direct, 22))
	p.add_child(_button("Join online with a code", func():
		_room_text = ""
		_room_label.text = "_"
		show_page("room")))
	p.add_child(_button("Host on this Wi-Fi", _host))
	p.add_child(_button("Play solo", _solo))
	p.add_child(_button("Tutorial: the training annex", func(): Game.start_tutorial()))
	p.add_child(_label("Games on your Wi-Fi", 20, INK))
	_hosts_box = VBoxContainer.new()
	_hosts_box.add_theme_constant_override("separation", 8)
	p.add_child(_hosts_box)
	p.add_child(_button("Join by address", func(): show_page("address")))
	p.add_child(_button("Back", func(): show_page("main")))


func _build_room(parent: Control) -> void:
	var p := _page("room", parent)
	p.add_child(_label("Join online", 36, ACCENT))
	p.add_child(_label("Type the code the host sees (6 characters, or 8 for a playtest).", 18, DIM))
	_room_label = _label("_", 44, INK)
	p.add_child(_room_label)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var alphabet := OnlineRoom.ALPHABET
	for r in 4:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		for ch in alphabet.substr(r * 8, 8):
			var b := _button(ch, _room_key.bind(ch), 22)
			b.custom_minimum_size = Vector2(58, 52)
			h.add_child(b)
		v.add_child(h)
	p.add_child(v)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var del := _button("Delete", _room_key.bind("<"), 20)
	del.custom_minimum_size = Vector2(140, 56)
	row.add_child(del)
	var go := _button("Join", func(): _join_online(_room_text), 24)
	go.custom_minimum_size = Vector2(200, 56)
	row.add_child(go)
	p.add_child(row)
	p.add_child(_button("Back", func(): show_page("play")))


func _room_key(k: String) -> void:
	if k == "<":
		_room_text = _room_text.substr(0, maxi(_room_text.length() - 1, 0))
	elif _room_text.length() < 8:
		_room_text += k
	_room_label.text = _room_text if _room_text != "" else "_"


func _build_address(parent: Control) -> void:
	var p := _page("address", parent)
	p.add_child(_label("Join by address", 36, ACCENT))
	var addrs := Net.local_addresses()
	p.add_child(_label("Ask the host for the address on their screen. Yours: " + (", ".join(addrs) if addrs.size() > 0 else "no network"), 16, DIM))
	_ip_label = _label("_", 38, INK)
	p.add_child(_ip_label)
	var pad := GridContainer.new()
	pad.columns = 4
	pad.add_theme_constant_override("h_separation", 8)
	pad.add_theme_constant_override("v_separation", 8)
	for k in ["1", "2", "3", "<", "4", "5", "6", ".", "7", "8", "9", "0"]:
		var b := _button(k, _ip_key.bind(k), 30)
		b.custom_minimum_size = Vector2(110, 64)
		pad.add_child(b)
	p.add_child(pad)
	p.add_child(_button("Join", func(): _join(_ip)))
	p.add_child(_button("Back", func(): show_page("play")))


func _build_character(parent: Control) -> void:
	var p := _page("character", parent)
	p.add_child(_label("Character", 36, ACCENT))
	var name_row := HBoxContainer.new()
	name_row.add_child(_label("Name ", 22, DIM))
	_name_label = _label("", 28, INK)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_label)
	var rnd := _button("Random", _random_name, 18)
	rnd.custom_minimum_size = Vector2(110, 44)
	name_row.add_child(rnd)
	p.add_child(name_row)
	p.add_child(_keyboard())
	var suit_row := HBoxContainer.new()
	var prev := _button("<", func(): _cycle_suit(-1), 28)
	prev.custom_minimum_size = Vector2(64, 56)
	suit_row.add_child(prev)
	_suit_label = _label("", 24, INK)
	_suit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_suit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	suit_row.add_child(_suit_label)
	var nxt := _button(">", func(): _cycle_suit(1), 28)
	nxt.custom_minimum_size = Vector2(64, 56)
	suit_row.add_child(nxt)
	p.add_child(suit_row)
	var code_btn := _button("Enter a code", func():
		_code = ""
		_code_label.text = "_"
		_code_msg.text = ""
		show_page("code"), 16)
	code_btn.custom_minimum_size = Vector2(0, 40)
	p.add_child(code_btn)
	_suit_about = _label("", 16, DIM)
	_suit_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(_suit_about)
	var sw := HBoxContainer.new()
	sw.add_theme_constant_override("separation", 8)
	for c in COLORS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(50, 50)
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(25)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		var pressed: StyleBoxFlat = sb.duplicate()
		pressed.border_color = Color.WHITE
		pressed.set_border_width_all(4)
		b.add_theme_stylebox_override("pressed", pressed)
		b.toggle_mode = true
		b.pressed.connect(_pick_color.bind(c))
		sw.add_child(b)
		_swatches.append(b)
	p.add_child(sw)
	p.add_child(_button("Done", func():
		Profile.save()
		show_page("main")))
	_refresh_character()


func _build_code(parent: Control) -> void:
	var p := _page("code", parent)
	p.add_child(_label("Enter a code", 36, ACCENT))
	_code_label = _label("_", 38, INK)
	p.add_child(_code_label)
	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 8)
	pad.add_theme_constant_override("v_separation", 8)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "OK"]:
		var b := _button(k, _code_key.bind(k), 30)
		b.custom_minimum_size = Vector2(110, 64)
		pad.add_child(b)
	p.add_child(pad)
	_code_msg = _label("", 20, DIM)
	p.add_child(_code_msg)
	p.add_child(_button("Back", func(): show_page("character")))


func _code_key(k: String) -> void:
	if k == "<":
		_code = _code.substr(0, maxi(_code.length() - 1, 0))
	elif k == "OK":
		var i := Profile.enter_code(_code)
		if i >= 0:
			Profile.suit = i
			Profile.save()
			_refresh_character()
			_code_msg.text = "Unlocked: " + SuitRig.SUITS[i].name
		else:
			_code_msg.text = "Nothing happens."
		_code = ""
	elif _code.length() < 8:
		_code += k
	_code_label.text = _code if _code != "" else "_"


func _keyboard() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	for row in ["1234567890", "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 5)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		for ch in row:
			var b := _button(ch, _type.bind(ch), 18)
			b.custom_minimum_size = Vector2(44, 42)
			h.add_child(b)
		v.add_child(h)
	var last := HBoxContainer.new()
	last.alignment = BoxContainer.ALIGNMENT_CENTER
	last.add_theme_constant_override("separation", 5)
	var caps := _button("Aa", func(): _caps = not _caps, 18)
	caps.custom_minimum_size = Vector2(70, 42)
	last.add_child(caps)
	var space := _button("Space", _type.bind(" "), 18)
	space.custom_minimum_size = Vector2(220, 42)
	last.add_child(space)
	var back := _button("Delete", _type.bind("<"), 18)
	back.custom_minimum_size = Vector2(110, 42)
	last.add_child(back)
	v.add_child(last)
	return v


func _build_settings(parent: Control) -> void:
	var p := _page("settings", parent)
	p.add_child(_label("Settings", 36, ACCENT))
	_turn_btn = _button("", func():
		Profile.snap_turn = not Profile.snap_turn
		_refresh_settings())
	p.add_child(_turn_btn)
	_body_btn = _button("", func():
		Profile.show_body = not Profile.show_body
		_refresh_settings())
	p.add_child(_body_btn)
	p.add_child(_stepper("Volume", func(d): Profile.volume = clampf(Profile.volume + d, 0.0, 1.0)))
	_vol_label = p.get_child(p.get_child_count() - 1).get_child(1)
	p.add_child(_stepper("Music", func(d): Profile.music = clampf(Profile.music + d, 0.0, 1.0)))
	_music_label = p.get_child(p.get_child_count() - 1).get_child(1)
	var tips := _label("VR: left stick moves, right stick turns, A or X jumps, grip grabs, trigger uses what you hold. Grab pool edges and ladders to climb out.\nDesktop: WASD, mouse, E pick up and use, left mouse use item, right mouse reach down, Space jump, Ctrl crouch, Q drop, F shove.", 15, DIM)
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(tips)
	p.add_child(_button("Back", func():
		Profile.save()
		show_page("main")))
	_refresh_settings()


const CREDITS := """[b]Models[/b] (CC BY 4.0, changed for the game)
The Wader (the creature): "The Rake" by Sealife Fan 3
Anti-radiation suit: "Antiradiation suit - OZK" by sanyaork
Diver: "Nanando diver" by Marco Lopez (its torch is the flashlight)
Scuba diver: "Scuba Diver" by turelljc
Brass-helmet diver: "The Diver" by amt16
Latex diver (secret): "Cat Girl - Anime Character Model" by VR_Avatars, wearing the scuba diver's gear
Key: "Old Key" by TheFalkonett
Staff door: "Metal Door 2" by tboiston
Exit doors: "Fire Escape / Exit Doors" by bloobloo
Bunker door: "Old metal bunker door" by rakutin
Generator lever: "Industrial Electricity's Lever" by Amine.Elouneg
Cover lever: "Old lever" by gunnarcorrea
Scanner: "Geiger counter" by DenisKorablyov
Bottles: "Dusty Beer Bottle" by GameDevNick, "Whiskey and Wine Low-Poly Bottles" by Helyeouka
Pool ladder: "CC0 - Pool Ladder 3" by plaggy
Distiller: "Rusted liquid storages" and "Machinery device" by maxpsr
Staff room desk: "Old Metal Table (Low Poly)" by berkgedik
Spine: "Human Spine" by b_bear
Heart and lungs: "Realistic Human Heart", "Realistic Human Lungs" by neshallads
Liver: "Human liver and gallbladder" by ElliotSS
Kidney: "Human kidney (Lowpoly example 9k)" by linejung
Stomach: "digestive system" by 7D_Production
All on sketchfab.com. creativecommons.org/licenses/by/4.0

[b]CC0[/b] (free to use, credited anyway)
Props and textures: Poly Haven (Wet Floor Sign, Industrial Wall Lamp, Modular Pipes, Plastic Monobloc Chair, Plastic Thermos by PierreB3D, Tool Cart by Savva Zakharov, Brown Leather) and ambientCG (tiles)
Hands: Godot XR Tools, by DigitalN8m4r3
Sounds: Freesound users Fupicat, Moss___6, Zrte, DatBloxyBirb, DangAdv64, batchku, Kinoton, kyles, craigsmith, courter, nomadas, Sclolex
Intro tape "Water Safety and You": signs after ISO 7010 (public domain), the falcon by papapishu and stick figures by rones (Openclipart, CC0), static by xhunterko (OpenGameArt, CC0); narrated by Microsoft Sam\nIntro room: TV "Television 02" by Benny Weimer, armchair by Vibrant Nordic, cabinet by Gabriel Radić, side table by James Ray Cock (Poly Haven, CC0); "VCR Player" by twunnyphaiv and "VHS" tape by Terizmeh (Sketchfab, CC BY 4.0); office carpet, wallpaper and ceiling from ambientCG (CC0); office furniture from Poly Haven (CC0)\nLobby (the field station reception): pine by Charlotte Baglioni and Rico Cilliers, plaid by Rob Tuytel, stucco by Amal Kumar (Poly Haven, CC0), carpet and wood from ambientCG (CC0); couch, coffee table, ceiling fan, plants, lamp table and vase from Poly Haven (CC0) by Fran Calvente, Fernando Quinn, Ulan Cabanilla, Rico Cilliers and James Ray Cock
Music made from "At the End of Hope" by Emma_MA and "Underwater Ambient Pad" by isaiah658 (OpenGameArt)

[b]Code[/b]
Godot Engine and Godot XR Tools (MIT)
Online play: relay by ExpressTURN; webrtc-native (MIT), with libdatachannel and libjuice by Paul-Louis Ageneau (MPL 2.0, source at github.com/paullouisageneau), usrsctp and libsrtp (BSD), Mbed TLS (Apache 2.0)"""


func _build_credits(parent: Control) -> void:
	var p := _page("credits", parent)
	p.add_child(_label("Credits", 36, ACCENT))
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.text = CREDITS
	t.fit_content = false
	t.scroll_active = true
	t.custom_minimum_size = Vector2(0, 470)
	t.add_theme_font_size_override("normal_font_size", 15)
	t.add_theme_font_size_override("bold_font_size", 17)
	t.add_theme_color_override("default_color", INK)
	p.add_child(t)
	p.add_child(_button("Back", func(): show_page("main")))


func _stepper(title: String, change: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_child(_label(title, 22, INK))
	var value := _label("", 22, ACCENT)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(value)
	for pair in [["-", -0.1], ["+", 0.1]]:
		var b := _button(pair[0], func():
			change.call(pair[1])
			Profile.apply_audio()
			_refresh_settings(), 26)
		b.custom_minimum_size = Vector2(70, 56)
		h.add_child(b)
	return h


func _build_connecting(parent: Control) -> void:
	var p := _page("connecting", parent)
	p.add_child(_label("Connecting", 36, ACCENT))
	_connecting_label = _label("", 22, INK)
	_connecting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(_connecting_label)
	p.add_child(_button("Cancel", func():
		Net.leave(true)
		show_page("play")))


# --- Behaviour -----------------------------------------------------------------------------------

func show_page(page_name: String) -> void:
	for k in _pages:
		_pages[k].visible = k == page_name
	if page_name == "play":
		Net.start_listening()
		_refresh_hosts()
	elif page_name != "address" and page_name != "connecting":
		Net.stop_listening()
	if page_name != "connecting" and page_name != "main":
		_status.text = ""


func _solo() -> void:
	Game.use_lobby = false
	Profile.save()
	Net.local_info.vr = Game.vr_mode
	if Net.host() == OK:
		_connecting_label.text = "Starting your game..."
		show_page("connecting")


func _host() -> void:
	Game.use_lobby = true
	Profile.save()
	Net.local_info.vr = Game.vr_mode
	if Net.host() == OK:
		_connecting_label.text = "Starting your game..."
		show_page("connecting")


func _host_online() -> void:
	Game.use_lobby = true
	Profile.save()
	Net.local_info.vr = Game.vr_mode
	if Net.host_online() == OK:
		_connecting_label.text = "Starting your game. Your room code will show up in a moment..."
		show_page("connecting")


func _host_direct() -> void:
	Game.use_lobby = true
	Profile.save()
	Net.local_info.vr = Game.vr_mode
	if Net.host_direct() == OK:
		_connecting_label.text = "Starting your game. Opening a port on your router for friends..."
		show_page("connecting")


func _join_online(code: String) -> void:
	var n := OnlineRoom.clean(code).length()
	if n != 6 and n != 8:
		_status.text = "The code is 6 characters (or 8 for a playtest)."
		show_page("play")
		return
	if n == 8 and DirectLink.decode(code).is_empty():
		_status.text = "That playtest code doesn't look right. Check it with the host."
		show_page("play")
		return
	Profile.save()
	Net.local_info.vr = Game.vr_mode
	_connecting_label.text = "Joining room %s..." % OnlineRoom.clean(code)
	show_page("connecting")
	Net.join_online(code)


func _join(ip: String) -> void:
	if ip.strip_edges() == "":
		_status.text = "Type the host's address first."
		return
	Profile.save()
	Net.local_info.vr = Game.vr_mode
	_connecting_label.text = "Connecting to %s..." % ip
	show_page("connecting")
	Net.join(ip)


func _on_failed(reason: String) -> void:
	show_page("play")
	_status.text = reason


func _refresh_hosts() -> void:
	if not _hosts_box:
		return
	for c in _hosts_box.get_children():
		c.queue_free()
	if Net.lan_hosts.is_empty():
		_hosts_box.add_child(_label("Looking for games...", 18, DIM))
	for ip in Net.lan_hosts:
		var h: Dictionary = Net.lan_hosts[ip]
		_hosts_box.add_child(_button("%s's game  (%d/%d)" % [h.name, h.players, Net.MAX_PLAYERS], func(): _join(ip), 22))


func _ip_key(k: String) -> void:
	if k == "<":
		_ip = _ip.substr(0, maxi(_ip.length() - 1, 0))
	elif _ip.length() < 15:
		_ip += k
	_ip_label.text = _ip if _ip != "" else "_"


func _type(ch: String) -> void:
	var n := Profile.player_name
	if ch == "<":
		n = n.substr(0, maxi(n.length() - 1, 0))
	elif n.length() < 16:
		n += ch if _caps or ch == " " else ch.to_lower()
		_caps = false
	Profile.player_name = n
	_refresh_character()


func _unhandled_key_input(event: InputEvent) -> void:
	# Desktop: type the name on the real keyboard while the character page is open (or a code on
	# the code page).
	if _pages.get("room") and _pages.room.visible and event.pressed:
		var rk := event as InputEventKey
		if rk.keycode == KEY_BACKSPACE:
			_room_key("<")
		elif rk.keycode == KEY_ENTER or rk.keycode == KEY_KP_ENTER:
			_join_online(_room_text)
		elif rk.unicode > 0 and char(rk.unicode).to_upper() in OnlineRoom.ALPHABET:
			_room_key(char(rk.unicode).to_upper())
		get_viewport().set_input_as_handled()
		return
	if _pages.get("code") and _pages.code.visible and event.pressed:
		var ck := event as InputEventKey
		if ck.keycode == KEY_BACKSPACE:
			_code_key("<")
		elif ck.keycode == KEY_ENTER or ck.keycode == KEY_KP_ENTER:
			_code_key("OK")
		elif ck.unicode >= 48 and ck.unicode <= 57:
			_code_key(char(ck.unicode))
		get_viewport().set_input_as_handled()
		return
	if not _pages.get("character") or not _pages.character.visible or not event.pressed:
		return
	var k := event as InputEventKey
	if k.keycode == KEY_BACKSPACE:
		_type("<")
	elif k.unicode >= 32 and k.unicode < 127:
		_caps = true
		var ch := char(k.unicode)
		Profile.player_name = (Profile.player_name + ch).substr(0, 16)
		_refresh_character()
	get_viewport().set_input_as_handled()


func _random_name() -> void:
	Profile.player_name = Profile.random_name()
	_refresh_character()


func _cycle_suit(d: int) -> void:
	for n in SuitRig.SUITS.size():             # skip suits still locked by a code
		Profile.suit = posmod(Profile.suit + d, SuitRig.SUITS.size())
		if Profile.suit_unlocked(Profile.suit):
			break
	_refresh_character()


func _pick_color(c: Color) -> void:
	Profile.color = c
	_refresh_character()


func _refresh_character() -> void:
	_name_label.text = (Profile.player_name if Profile.player_name != "" else "...") + "_"
	_suit_label.text = SuitRig.SUITS[Profile.suit].name
	_suit_about.text = SuitRig.SUITS[Profile.suit].about
	for i in _swatches.size():
		_swatches[i].button_pressed = COLORS[i].is_equal_approx(Profile.color)
	Net.local_info.name = Profile.player_name
	character_changed.emit()


func _refresh_settings() -> void:
	_turn_btn.text = "Turning: " + ("snap" if Profile.snap_turn else "smooth")
	_body_btn.text = "Your body: " + ("shown" if Profile.show_body else "hidden")
	if _vol_label:
		_vol_label.text = "%d%%" % roundi(Profile.volume * 100)
		_music_label.text = "%d%%" % roundi(Profile.music * 100)


func _label(text: String, size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _button(text: String, cb: Callable, size := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", size)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.14, 0.16)
	normal.border_color = Color(0.25, 0.45, 0.5)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.12, 0.24, 0.27)
	hover.border_color = ACCENT
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", INK)
	b.pressed.connect(cb)
	return b
