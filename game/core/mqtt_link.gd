class_name MqttLink
extends RefCounted
## A tiny MQTT 3.1.1 client over a WebSocket, only what online co-op needs to find each other:
## connect, subscribe, publish (QoS 0) and keep-alive. Used with free public brokers to pass the
## WebRTC connection offers between players who share a room code; no game traffic goes through it.
##   var link := MqttLink.new(); link.open("wss://broker.hivemq.com:8884/mqtt")
##   link.subscribe("topic"); link.publish("topic", "text"); call link.poll() every frame.

signal opened
signal failed
signal message(topic: String, payload: String)

const KEEP_ALIVE := 30

var _ws := WebSocketPeer.new()
var _buf := PackedByteArray()
var _connected := false       # MQTT session accepted (CONNACK)
var _open_sent := false
var _next_id := 1
var _ping_t := 0.0
var _pending: Array = []      # subscriptions/publishes asked for before the session was accepted
var _done := false
var _user := ""
var _pass := ""


func open(url: String, user := "", password := "") -> Error:
	_user = user
	_pass = password
	_ws.supported_protocols = PackedStringArray(["mqtt"])
	_ws.inbound_buffer_size = 1 << 18
	_ws.outbound_buffer_size = 1 << 18
	return _ws.connect_to_url(url)


func is_open() -> bool:
	return _connected


func close() -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if _connected:
			_ws.put_packet(PackedByteArray([0xE0, 0x00]))      # DISCONNECT
		_ws.close()
	_connected = false
	_done = true


func subscribe(topic: String) -> void:
	if not _connected:
		_pending.append(["sub", topic])
		return
	var body := PackedByteArray()
	body.append_array(_u16(_next_id))
	_next_id = _next_id % 65535 + 1
	body.append_array(_str(topic))
	body.append(0)                                   # QoS 0
	_send(0x82, body)


func publish(topic: String, payload: String) -> void:
	if not _connected:
		_pending.append(["pub", topic, payload])
		return
	var body := _str(topic)
	body.append_array(payload.to_utf8_buffer())
	_send(0x30, body)


func poll(delta: float) -> void:
	if _done:
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _open_sent:
				_open_sent = true
				_send_connect()
			while _ws.get_available_packet_count() > 0:
				_buf.append_array(_ws.get_packet())
			_parse()
			if _connected:
				_ping_t += delta
				if _ping_t > KEEP_ALIVE * 0.5:
					_ping_t = 0.0
					_ws.put_packet(PackedByteArray([0xC0, 0x00]))   # PINGREQ
		WebSocketPeer.STATE_CLOSED:
			_done = true
			_connected = false
			failed.emit()


func _send_connect() -> void:
	var body := _str("MQTT")
	body.append(4)                                   # protocol level 3.1.1
	body.append(0x02 | (0xC0 if _user != "" else 0))   # clean session (+ user name and password)
	body.append_array(_u16(KEEP_ALIVE))
	body.append_array(_str("ripple-%08x%08x" % [randi(), randi()]))
	if _user != "":
		body.append_array(_str(_user))
		body.append_array(_str(_pass))
	_send(0x10, body)


func _parse() -> void:
	while _buf.size() >= 2:
		# Remaining length: up to four 7-bit groups.
		var mult := 1
		var length := 0
		var i := 1
		var complete := false
		while i < _buf.size() and i <= 4:
			var b := _buf[i]
			length += (b & 0x7F) * mult
			mult *= 128
			i += 1
			if b & 0x80 == 0:
				complete = true
				break
		if not complete or _buf.size() < i + length:
			return
		var header := _buf[0]
		var kind := header >> 4
		var body := _buf.slice(i, i + length)
		_buf = _buf.slice(i + length)
		match kind:
			2:   # CONNACK
				if body.size() >= 2 and body[1] == 0:
					_connected = true
					opened.emit()
					for p in _pending:
						if p[0] == "sub":
							subscribe(p[1])
						else:
							publish(p[1], p[2])
					_pending.clear()
				else:
					close()
					failed.emit()
			3:   # PUBLISH
				var tlen := (body[0] << 8) | body[1]
				var topic := body.slice(2, 2 + tlen).get_string_from_utf8()
				var at := 2 + tlen
				if (header >> 1) & 3 > 0:             # QoS 1/2 messages carry a packet id
					at += 2
				message.emit(topic, body.slice(at).get_string_from_utf8())


func _send(header: int, body: PackedByteArray) -> void:
	var pkt := PackedByteArray([header])
	var n := body.size()
	while true:
		var b := n % 128
		n = n / 128
		if n > 0:
			b |= 0x80
		pkt.append(b)
		if n == 0:
			break
	pkt.append_array(body)
	_ws.put_packet(pkt)


static func _u16(v: int) -> PackedByteArray:
	return PackedByteArray([(v >> 8) & 0xFF, v & 0xFF])


static func _str(s: String) -> PackedByteArray:
	var b := s.to_utf8_buffer()
	var out := _u16(b.size())
	out.append_array(b)
	return out
