class_name OnlineRoom
extends RefCounted
## Online co-op with a room code, over the internet.
##
## The players' games connect straight to each other with WebRTC (the technology video calls use,
## which gets through most home routers with the help of public STUN servers). To find each other
## they pass the WebRTC offers and answers through a free public MQTT broker, on topics named
## after the room code. Game traffic never goes through the broker.
##
## The code is 5 characters for the room plus 1 digit naming which broker the host reached
## (several public brokers are tried in turn in case one is down).

signal code_ready(code: String)
signal failed(reason: String)

const BROKERS := [
	"wss://broker.hivemq.com:8884/mqtt",
	"wss://broker.emqx.io:8084/mqtt",
	"wss://test.mosquitto.org:8081/mqtt",
]
const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   # no I, O, 0 or 1: easy to read out
const TOPIC := "rippledemo/v1/"
const ICE := {"iceServers": [
	{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]},
	{"urls": ["stun:stun.cloudflare.com:3478"]},
]}
const BROKER_WAIT := 8.0        # seconds to reach a broker before trying the next
const JOIN_WAIT := 30.0         # seconds for a joiner to get connected

var rtc := WebRTCMultiplayerPeer.new()
var code := ""
var is_host := false
var brokers: Array = BROKERS
var max_players := 4

var _link: MqttLink
var _broker := -1
var _broker_t := 0.0
var _room := ""
var _my_id := 1
var _conns := {}           # peer id -> WebRTCPeerConnection
var _remote_set := {}      # peer id -> remote description applied
var _early_ice := {}       # peer id -> candidates that came before the description
var _offers := {}          # peer id -> the offer sent (re-sent if the joiner asks again)
var _hello_t := 0.0
var _age := 0.0
var _connected_t := -1.0
var _closed := false


## Host a room. `forced_room` (5 characters) is for tests.
func host(players_max: int, forced_room := "") -> void:
	is_host = true
	max_players = players_max
	rtc.create_server()
	_room = forced_room if forced_room != "" else random_room()
	_next_broker()


## Join a room by its code.
func join(room_code: String) -> void:
	is_host = false
	code = clean(room_code)
	if code.length() != 6 or not code[5].is_valid_int() or int(code[5]) < 2 or int(code[5]) - 2 >= brokers.size():
		_fail("That room code doesn't look right. It's 6 characters, ending in a number.")
		return
	_my_id = randi_range(2, 2147483646)
	rtc.create_client(_my_id)
	_open_broker(int(code[5]) - 2)


static func random_room() -> String:
	var s := ""
	for i in 5:
		s += ALPHABET[randi() % ALPHABET.length()]
	return s


## Upper case, with anything that isn't a code character (spaces, dashes) dropped.
static func clean(s: String) -> String:
	var out := ""
	for ch in s.to_upper():
		if ch in ALPHABET:
			out += ch
	return out


func close() -> void:
	_closed = true
	if _link:
		_link.close()
		_link = null


func poll(delta: float) -> void:
	if _closed:
		return
	_age += delta
	if _link:
		_link.poll(delta)            # may fail and drop the link (or the whole room) right here
		if _closed:
			return
		if _link and not _link.is_open():
			_broker_t += delta
			if _broker_t > BROKER_WAIT:
				_on_link_failed()
				if _closed:
					return
	if is_host:
		# Drop joiners whose direct connection failed, so they can try again.
		for id in _conns.keys():
			var st: int = _conns[id].get_connection_state()
			if st == WebRTCPeerConnection.STATE_FAILED or st == WebRTCPeerConnection.STATE_CLOSED:
				if rtc.has_peer(id):
					rtc.remove_peer(id)
				_conns.erase(id)
				_remote_set.erase(id)
				_offers.erase(id)
	else:
		if rtc.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			if _connected_t < 0.0:
				_connected_t = _age
			elif _age - _connected_t > 5.0 and _link:
				_link.close()            # found each other; the broker isn't needed any more
				_link = null
			return
		if _conns.has(1) and _conns[1].get_connection_state() == WebRTCPeerConnection.STATE_FAILED:
			_fail("Found the room, but couldn't connect to the host directly. One of your networks may block it (some mobile hotspots and school or work Wi-Fi do).")
			return
		if _link and _link.is_open() and not _conns.has(1):
			_hello_t -= delta
			if _hello_t <= 0.0:
				_hello_t = 2.0
				_send_to_host({"t": "hello", "id": _my_id})
		if _age > JOIN_WAIT:
			_fail("No game found with room code %s. Check the code, and that the host is in the game." % code
				if not _conns.has(1) else "Found the room, but the connection didn't finish. Try again.")


# --- Broker --------------------------------------------------------------------------------------

func _next_broker() -> void:
	_open_broker(_broker + 1)


func _open_broker(i: int) -> void:
	if _link:
		_link.close()
		_link = null
	if i >= brokers.size():
		_fail("Couldn't reach the online matchmaking service. Check the headset's internet connection.")
		return
	_broker = i
	_broker_t = 0.0
	_link = MqttLink.new()
	_link.opened.connect(_on_link_open)
	_link.failed.connect(_on_link_failed)
	_link.message.connect(_on_message)
	if _link.open(brokers[i]) != OK:
		_on_link_failed()


func _on_link_failed() -> void:
	if _closed:
		return
	if is_host and code == "":
		_next_broker()           # try the next broker before giving out a code
	elif is_host:
		_open_broker(_broker)    # lost the broker mid-game: reconnect to the same one
	else:
		_fail("Couldn't reach the online matchmaking service. Check the headset's internet connection.")


func _on_link_open() -> void:
	if is_host:
		if code == "":
			code = _room + str(_broker + 2)
			code_ready.emit(code)
		_link.subscribe(TOPIC + code + "/host")
	else:
		_link.subscribe(TOPIC + code + "/p%d" % _my_id)
		_hello_t = 0.3


func _send_to_host(msg: Dictionary) -> void:
	if _link:
		_link.publish(TOPIC + code + "/host", JSON.stringify(msg))


func _send_to_peer(id: int, msg: Dictionary) -> void:
	if _link:
		_link.publish(TOPIC + code + "/p%d" % id, JSON.stringify(msg))


func _on_message(_topic: String, payload: String) -> void:
	var m = JSON.parse_string(payload)
	if not m is Dictionary:
		return
	var t := str(m.get("t", ""))
	if is_host:
		var id := int(m.get("id", 0))
		if id < 2:
			return
		match t:
			"hello":
				if _conns.has(id):
					if _offers.has(id):
						_send_to_peer(id, {"t": "offer", "sdp": _offers[id]})
				elif _conns.size() + 1 >= max_players:
					_send_to_peer(id, {"t": "full"})
				else:
					_new_conn(id).create_offer()
			"answer":
				if _conns.has(id):
					_conns[id].set_remote_description("answer", str(m.sdp))
					_remote_set[id] = true
					_flush_ice(id)
			"ice":
				_add_ice(id, m)
	else:
		match t:
			"offer":
				if not _conns.has(1):
					_new_conn(1).set_remote_description("offer", str(m.sdp))
					_remote_set[1] = true
					_flush_ice(1)
			"ice":
				_add_ice(1, m)
			"full":
				_fail("That game is full (%d players)." % max_players)


# --- WebRTC --------------------------------------------------------------------------------------

func _new_conn(id: int) -> WebRTCPeerConnection:
	var pc := WebRTCPeerConnection.new()
	pc.initialize(ICE)
	pc.session_description_created.connect(func(type: String, sdp: String):
		pc.set_local_description(type, sdp)
		if is_host:
			_offers[id] = sdp
			_send_to_peer(id, {"t": type, "sdp": sdp})
		else:
			_send_to_host({"t": type, "id": _my_id, "sdp": sdp}))
	pc.ice_candidate_created.connect(func(mid: String, index: int, cand: String):
		var msg := {"t": "ice", "mid": mid, "index": index, "cand": cand}
		if is_host:
			_send_to_peer(id, msg)
		else:
			msg.id = _my_id
			_send_to_host(msg))
	rtc.add_peer(pc, id)
	_conns[id] = pc
	return pc


func _add_ice(id: int, m: Dictionary) -> void:
	if not _conns.has(id):
		return
	if not _remote_set.get(id, false):
		if not _early_ice.has(id):
			_early_ice[id] = []
		_early_ice[id].append(m)
		return
	_conns[id].add_ice_candidate(str(m.mid), int(m.index), str(m.cand))


func _flush_ice(id: int) -> void:
	for m in _early_ice.get(id, []):
		_conns[id].add_ice_candidate(str(m.mid), int(m.index), str(m.cand))
	_early_ice.erase(id)


func _fail(reason: String) -> void:
	if _closed:
		return
	close()
	failed.emit(reason)
