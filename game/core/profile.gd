extends Node
## The player's saved choices: name, suit, color and settings. Saved to user://profile.cfg.

signal changed

const PATH := "user://profile.cfg"
const NAMES := ["Lifeguard", "Snorkel", "Drip", "Echo", "Shallows", "Deep End", "Puddle",
	"Tidewalker", "Splash", "Lane Six", "Undertow", "Chlorine", "Floatie", "Drain", "Ripple"]

var player_name := ""
var suit := 0
var color := Color(0.95, 0.55, 0.15)
var snap_turn := true
var volume := 0.85
var music := 0.6
var codes: Array = []        # secret codes typed in (they unlock hidden suits)


func _ready() -> void:
	_setup_buses()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		player_name = cfg.get_value("player", "name", "")
		suit = int(cfg.get_value("player", "suit", 0))
		color = cfg.get_value("player", "color", color)
		snap_turn = cfg.get_value("settings", "snap_turn", true)
		volume = cfg.get_value("settings", "volume", 0.85)
		music = cfg.get_value("settings", "music", 0.6)
		codes = cfg.get_value("player", "codes", [])
	if not suit_unlocked(suit):
		suit = 0
	if player_name == "":
		player_name = random_name()
	if Game.args.has("name"):
		player_name = str(Game.args.name)
	apply_audio()
	_sync_net()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "suit", suit)
	cfg.set_value("player", "color", color)
	cfg.set_value("player", "codes", codes)
	cfg.set_value("settings", "snap_turn", snap_turn)
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "music", music)
	cfg.save(PATH)
	apply_audio()
	_sync_net()
	changed.emit()


func suit_unlocked(i: int) -> bool:
	if i < 0 or i >= SuitRig.SUITS.size():
		return false
	var code: String = SuitRig.SUITS[i].get("code", "")
	return code == "" or code in codes


## Tries a secret code. Returns the index of the suit it unlocks, or -1.
func enter_code(code: String) -> int:
	for i in SuitRig.SUITS.size():
		if SuitRig.SUITS[i].get("code", "") == code and code != "":
			if not code in codes:
				codes.append(code)
			return i
	return -1


static func random_name() -> String:
	return "%s %d" % [NAMES[randi() % NAMES.size()], randi_range(10, 99)]


func _sync_net() -> void:
	Net.local_info.name = player_name
	Net.local_info.color = color
	Net.local_info.suit = suit


func _setup_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Music")
		AudioServer.set_bus_send(i, "Master")


func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music, 0.0001)))
