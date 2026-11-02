class_name NtfyLink
extends RefCounted
## The same job as MqttLink (pass online co-op connection offers between players who share a room
## code) over ntfy.sh, a free public push-message service on the normal HTTPS port 443, which
## gets through networks that block unusual ports. Listens on a WebSocket per topic and sends
## with plain HTTPS POSTs. Topics use "-" where MqttLink's use "/".

signal opened
signal failed
signal message(topic: String, payload: String)

var _base := "https://ntfy.sh"
var _subs := {}            # topic -> WebSocketPeer
var _sub_open := {}        # topic -> its WebSocket has said "open"
var _opened_sent := false
var _closed := false
var _host: Node            # parent for the HTTPRequest nodes


func open(url: String, _user := "", _password := "") -> Error:
	_base = url.trim_suffix("/")
	_host = (Engine.get_main_loop() as SceneTree).root
	return OK


func is_open() -> bool:
	return _opened_sent


func close() -> void:
	_closed = true
	for t in _subs:
		_subs[t].close()
	_subs.clear()


static func _topic(t: String) -> String:
	return t.replace("/", "-")


func subscribe(topic: String) -> void:
	var t := _topic(topic)
	if _subs.has(t):
		return
	var ws := WebSocketPeer.new()
	# "since=20s": anything sent to us while the socket was still opening is not lost.
	if ws.connect_to_url(_base.replace("https://", "wss://").replace("http://", "ws://") + "/" + t + "/ws?since=20s") != OK:
		failed.emit()
		return
	_subs[t] = ws
	_sub_open[t] = false


func publish(topic: String, payload: String) -> void:
	if _closed:
		return
	var req := HTTPRequest.new()
	req.timeout = 10.0
	_host.add_child(req)
	req.request_completed.connect(func(_r, _code, _h, _b): req.queue_free())
	req.request(_base + "/" + _topic(topic), PackedStringArray(["Content-Type: text/plain"]), HTTPClient.METHOD_POST, payload)


func poll(_delta: float) -> void:
	if _closed:
		return
	for t in _subs.keys():
		var ws: WebSocketPeer = _subs[t]
		ws.poll()
		match ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				while ws.get_available_packet_count() > 0:
					var m = JSON.parse_string(ws.get_packet().get_string_from_utf8())
					if not m is Dictionary:
						continue
					match str(m.get("event", "")):
						"open":
							_sub_open[t] = true
							if not _opened_sent:      # ready once we can hear replies
								_opened_sent = true
								opened.emit()
						"message":
							message.emit(str(m.get("topic", t)), str(m.get("message", "")))
			WebSocketPeer.STATE_CLOSED:
				_subs.erase(t)
				if not _closed:
					failed.emit()
					return
