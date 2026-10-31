extends Node
## Co-op session: hosting, joining, LAN discovery, and who has the level loaded.
##
## The host is authoritative for the creature and the world state. Every peer simulates its own
## player and the items it holds. Messages only go to peers that have finished loading the level
## ("ready peers"), so nobody receives updates for nodes they don't have yet.

signal session_started
signal session_failed(reason: String)
signal session_ended(reason: String)
signal players_changed
signal ready_peers_changed
signal hosts_changed

const PORT := 7777
const DISCOVERY_PORT := 7778
const MAX_PLAYERS := 4
const GAME_TAG := "RIPPLE-demo-1"

## peer id -> {"name": String, "color": Color, "vr": bool}
var players: Dictionary = {}
## Peers (including the host) that have the level loaded.
var ready_peers: Array[int] = []
## Discovered LAN hosts: ip -> {"name": String, "players": int, "seen": float}
var lan_hosts: Dictionary = {}

var local_info := {"name": "Player", "color": Color(0.9, 0.55, 0.15), "vr": false}

var _peer: ENetMultiplayerPeer
var _broadcaster: PacketPeerUDP
var _listener: PacketPeerUDP
var _broadcast_timer := 0.0
var _expected_disconnect := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online() -> bool:
	return _peer != null


func is_host() -> bool:
	return _peer != null and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if _peer else 1


func is_ready_peer(id: int) -> bool:
	return id in ready_peers


## Peers other than me that have the level loaded.
func other_ready_peers() -> Array[int]:
	var out: Array[int] = []
	var me := my_id()
	for id in ready_peers:
		if id != me:
			out.append(id)
	return out


## Call an RPC on `node` for every other ready peer.
func send(node: Node, method: StringName, args: Array = []) -> void:
	for id in other_ready_peers():
		node.callv("rpc_id", [id, method] + args)


## Call an RPC on the host (or run it directly if we are the host).
func to_host(node: Node, method: StringName, args: Array = []) -> void:
	if is_host():
		node.callv(method, args)
	else:
		node.callv("rpc_id", [1, method] + args)


# --- Hosting and joining -------------------------------------------------------------------------

func host() -> Error:
	leave(true)
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		_peer = null
		session_failed.emit("Could not host on port %d (is another copy already hosting?)" % PORT)
		return err
	multiplayer.multiplayer_peer = _peer
	players = {1: local_info.duplicate()}
	ready_peers = []
	_start_broadcasting()
	players_changed.emit()
	session_started.emit()
	return OK


func join(address: String) -> Error:
	leave(true)
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address.strip_edges(), PORT)
	if err != OK:
		_peer = null
		session_failed.emit("Could not start connecting to %s" % address)
		return err
	multiplayer.multiplayer_peer = _peer
	return OK


func leave(quiet := false) -> void:
	_stop_broadcasting()
	if _peer:
		_expected_disconnect = true
		_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_peer = null
		_expected_disconnect = false
	players = {}
	ready_peers = []
	if not quiet:
		session_ended.emit("You left the game.")


## Called by the level once it has finished building on this peer.
func level_loaded() -> void:
	if is_host():
		_mark_ready(1)
	else:
		rpc_id(1, "_client_level_ready")


func _mark_ready(id: int) -> void:
	if id not in ready_peers:
		ready_peers.append(id)
	_broadcast_ready()
	ready_peers_changed.emit()
	if Game.level:
		Game.level.on_peer_ready(id)


func _broadcast_ready() -> void:
	for id in ready_peers:
		if id != 1:
			rpc_id(id, "_set_ready_peers", ready_peers)


@rpc("any_peer", "call_remote", "reliable")
func _client_level_ready() -> void:
	if not is_host():
		return
	_mark_ready(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func _set_ready_peers(ids: Array) -> void:
	ready_peers.clear()
	for id in ids:
		ready_peers.append(int(id))
	ready_peers_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _register(info: Dictionary) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	players[id] = info
	for pid in players:
		if pid != 1:
			rpc_id(pid, "_set_players", players)
	players_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _set_players(p: Dictionary) -> void:
	players = p
	players_changed.emit()


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	ready_peers.erase(id)
	if is_host():
		for pid in players:
			if pid != 1:
				rpc_id(pid, "_set_players", players)
		_broadcast_ready()
	if Game.level:
		Game.level.on_peer_left(id)
	players_changed.emit()
	ready_peers_changed.emit()


func _on_connected_to_server() -> void:
	rpc_id(1, "_register", local_info)
	session_started.emit()


func _on_connection_failed() -> void:
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	session_failed.emit("Couldn't connect. Check the address, that the host is in a game, and that port %d is allowed through the firewall." % PORT)


func _on_server_disconnected() -> void:
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {}
	ready_peers = []
	if not _expected_disconnect:
		session_ended.emit("The host left the game.")


# --- LAN discovery -------------------------------------------------------------------------------

func _start_broadcasting() -> void:
	_broadcaster = PacketPeerUDP.new()
	_broadcaster.set_broadcast_enabled(true)
	_broadcaster.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_broadcast_timer = 0.0


func _stop_broadcasting() -> void:
	if _broadcaster:
		_broadcaster.close()
		_broadcaster = null


func start_listening() -> void:
	stop_listening()
	_listener = PacketPeerUDP.new()
	if _listener.bind(DISCOVERY_PORT) != OK:
		_listener = null


func stop_listening() -> void:
	if _listener:
		_listener.close()
		_listener = null
	lan_hosts.clear()


func _process(delta: float) -> void:
	if _broadcaster:
		_broadcast_timer -= delta
		if _broadcast_timer <= 0.0:
			_broadcast_timer = 1.0
			var msg := JSON.stringify({"tag": GAME_TAG, "name": local_info.name, "players": players.size()})
			_broadcaster.put_packet(msg.to_utf8_buffer())
	if _listener:
		var changed := false
		while _listener.get_available_packet_count() > 0:
			var data := _listener.get_packet().get_string_from_utf8()
			var ip := _listener.get_packet_ip()
			var parsed = JSON.parse_string(data)
			if parsed is Dictionary and parsed.get("tag", "") == GAME_TAG:
				lan_hosts[ip] = {"name": str(parsed.get("name", "?")), "players": int(parsed.get("players", 1)), "seen": Time.get_ticks_msec() / 1000.0}
				changed = true
		var now := Time.get_ticks_msec() / 1000.0
		for ip in lan_hosts.keys():
			if now - lan_hosts[ip].seen > 4.0:
				lan_hosts.erase(ip)
				changed = true
		if changed:
			hosts_changed.emit()


## This machine's LAN addresses, so the host can read one out to a friend.
func local_addresses() -> Array[String]:
	var out: Array[String] = []
	for a in IP.get_local_addresses():
		if a.contains(".") and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out
