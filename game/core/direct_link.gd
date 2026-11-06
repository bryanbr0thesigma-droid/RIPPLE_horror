class_name DirectLink
extends RefCounted
## Direct online play (for closed playtests): friends connect straight to the host's public address,
## with no broker or relay in between. UPnP asks the host's router to forward the game's UDP port to
## this device; the room code is the public address and port, written as 8 code characters
## ("K7QX-M2AB"), so joining needs nothing but the code.
##
## When the router won't open the port (UPnP switched off) the code still works if the port is
## forwarded by hand; when the connection is shared (CGNAT, or a second router in front) nobody
## outside can reach the host, and the warning says to use the room-code mode instead.
## (The commercial release is meant to move to Epic Online Services for this.)

## code is "" when no public address could be found; warning is "" when all looks well.
signal finished(code: String, warning: String)

const PORTS_TRIED := 16          # external ports PORT .. PORT + 15 (offset 0..15 fits the code)
const LEASE := 4 * 3600          # seconds; routers that only take permanent ones get 0
const IP_ECHO := ["https://api.ipify.org", "https://icanhazip.com"]
const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   # the same as the room codes' (OnlineRoom)

var port := 0                    # the game's port on this device
var ext_port := 0                # the port friends connect to
var ext_ip := ""
var forced_ip := ""              # tests: skip UPnP and use this as the public address

var _thread: Thread
var _upnp: UPNP
var _mapped := 0                 # the port mapping we made on the router (0: none)
var _owner: Node                 # where the address lookup's HTTPRequest lives
var _http: HTTPRequest
var _echo := 0
var _forced_pending := false
var _closed := false


## Start finding the router (in the background). Call poll() every frame until finished fires.
func start(game_port: int, owner: Node) -> void:
	port = game_port
	_owner = owner
	if forced_ip != "":
		ext_ip = forced_ip
		ext_port = port
		_forced_pending = true
		return
	_thread = Thread.new()
	_thread.start(_work)


func poll() -> void:
	if _forced_pending:
		_forced_pending = false
		_finish("")
	if _thread and not _thread.is_alive():
		var out: Dictionary = _thread.wait_to_finish()
		_thread = null
		_got_upnp(out)


## Background thread: find the router, open the port, ask it for the public address.
func _work() -> Dictionary:
	var u := UPNP.new()
	var out := {"upnp": u, "mapped": 0, "ip": "", "found": false}
	var err := u.discover(2000, 2, "InternetGatewayDevice")
	var gw := u.get_gateway() if err == UPNP.UPNP_RESULT_SUCCESS else null
	if gw and gw.is_valid_gateway():
		out.found = true
		for k in PORTS_TRIED:
			var e := u.add_port_mapping(port + k, port, "RIPPLE playtest", "UDP", LEASE)
			if e == UPNP.UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED:
				e = u.add_port_mapping(port + k, port, "RIPPLE playtest", "UDP", 0)
			if e == UPNP.UPNP_RESULT_SUCCESS:
				out.mapped = port + k
				break
		out.ip = u.query_external_address()
	return out


func _got_upnp(out: Dictionary) -> void:
	_upnp = out.upnp
	_mapped = out.mapped
	ext_port = out.mapped
	if _closed:
		return
	if out.found and ext_port == 0:
		ext_port = port
		_lookup_ip("Your router didn't open the game's port. Forward UDP port %d to this device (%s) in its settings, or use Host online (room code)." % [port, _local()])
	elif not out.found:
		ext_port = port
		_lookup_ip("No router answered (UPnP may be switched off). Forward UDP port %d to this device (%s) in your router's settings, or use Host online (room code)." % [port, _local()])
	elif is_private(out.ip):
		ext_ip = out.ip
		_lookup_ip("Your internet connection is shared (CGNAT, or a second router in front of yours), so friends outside probably can't reach you. Use Host online (room code) instead.")
	else:
		ext_ip = out.ip
		_finish("")


## When the router can't tell us, a public "what's my address" page can.
func _lookup_ip(warning: String) -> void:
	if _echo >= IP_ECHO.size() or _owner == null:
		_finish(warning)
		return
	var http := HTTPRequest.new()
	http.timeout = 6.0
	_owner.add_child(http)
	_http = http
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		_http = null
		if _closed:
			return
		var ip := body.get_string_from_utf8().strip_edges()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and ip.is_valid_ip_address() and ip.contains("."):
			ext_ip = ip
			_finish(warning)
		else:
			_echo += 1
			_lookup_ip(warning))
	if http.request(IP_ECHO[_echo]) != OK:
		http.queue_free()
		_http = null
		_echo += 1
		_lookup_ip(warning)


func _finish(warning: String) -> void:
	if _closed:
		return
	var code := encode(ext_ip, ext_port - port) if ext_ip != "" and not is_private(ext_ip) or forced_ip != "" else ""
	if code == "" and warning == "":
		warning = "Couldn't find your public address, so there's no code to give out."
	finished.emit(pretty(code), warning)


func _local() -> String:
	if _upnp and _upnp.get_gateway():
		return _upnp.get_gateway().our_addr
	for a in IP.get_local_addresses():
		if a.contains(".") and not a.begins_with("127.") and not a.begins_with("169.254."):
			return a
	return "this device"


## Close the port on the router again (when the host leaves).
func close() -> void:
	_closed = true
	if _thread:                  # still talking to the router: let it finish, then undo it
		var out: Dictionary = _thread.wait_to_finish()
		_thread = null
		_upnp = out.upnp
		_mapped = out.mapped
	if _http:
		_http.queue_free()
		_http = null
	if _upnp and _mapped != 0:
		_upnp.delete_port_mapping(_mapped, "UDP")
	_upnp = null
	_mapped = 0


# --- The code ------------------------------------------------------------------------------------

## The public IPv4 address and the port offset (0..15) as 8 code characters: 32 + 4 bits, and 4
## bits of check so a mistyped code is caught instead of connecting somewhere else.
static func encode(ip: String, offset: int) -> String:
	var b := ip.split(".")
	if b.size() != 4 or offset < 0 or offset > 15:
		return ""
	var v := 0
	for s in b:
		v = (v << 8) | (int(s) & 255)
	v = (v << 8) | (offset << 4) | _check(v, offset)
	var out := ""
	for i in 8:
		out = ALPHABET[v & 31] + out
		v >>= 5
	return out


## The address and port offset in a code, or {} if it isn't a valid direct code.
static func decode(code: String) -> Dictionary:
	var c := clean(code)
	if c.length() != 8:
		return {}
	var v := 0
	for ch in c:
		v = (v << 5) | ALPHABET.find(ch)
	var check := v & 15
	var offset := (v >> 4) & 15
	var ipv := v >> 8
	if _check(ipv, offset) != check:
		return {}
	return {"ip": "%d.%d.%d.%d" % [(ipv >> 24) & 255, (ipv >> 16) & 255, (ipv >> 8) & 255, ipv & 255], "offset": offset}


static func _check(ipv: int, offset: int) -> int:
	var h := offset * 7 + 3
	for i in 4:
		h = (h * 31 + ((ipv >> (8 * i)) & 255)) % 65521
	return h & 15


## Upper case, with anything that isn't a code character (spaces, dashes) dropped.
static func clean(s: String) -> String:
	var out := ""
	for ch in s.to_upper():
		if ch in ALPHABET:
			out += ch
	return out


## "K7QXM2AB" -> "K7QX-M2AB" (easier to read out).
static func pretty(code: String) -> String:
	return code.substr(0, 4) + "-" + code.substr(4) if code.length() == 8 else code


## Addresses nobody outside the local network can reach (private ranges and CGNAT's 100.64/10).
static func is_private(ip: String) -> bool:
	var b := ip.split(".")
	if b.size() != 4:
		return true
	var a := int(b[0])
	var c := int(b[1])
	return a == 10 or a == 127 or a == 0 or (a == 172 and c >= 16 and c <= 31) or (a == 192 and c == 168) \
		or (a == 169 and c == 254) or (a == 100 and c >= 64 and c <= 127)
