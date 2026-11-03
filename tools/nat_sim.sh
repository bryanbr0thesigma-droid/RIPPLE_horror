#!/bin/sh
# A pretend internet with two home networks behind NAT routers, built from Linux network
# namespaces (needs root), to test online co-op between two homes without two homes.
#
#   inet  - "the internet": a bridge with the servers on 203.0.113.10 (matchmaking, STUN, TURN)
#   r1/r2 - the home routers: public 203.0.113.1/.2, home side 192.168.1.1, NAT + firewall
#   h1/h2 - a device in each home: 192.168.1.2 (both homes use the same range, like real ones)
#
# Router kinds: "cone" is a normal home router (Linux MASQUERADE: keeps the same outside port per
# inside port, lets in only replies from places it has sent to); "symmetric" is a strict one (a
# new random outside port for every destination), like some mobile and work networks.
#   sudo sh tools/nat_sim.sh up cone|symmetric cone|symmetric
#   sudo sh tools/nat_sim.sh down
set -e
case "$1" in
up)
	ip netns add inet
	ip netns exec inet ip link set lo up
	ip netns exec inet ip link add br0 type bridge
	ip netns exec inet ip addr add 203.0.113.10/24 dev br0
	ip netns exec inet ip link set br0 up
	n=1
	for kind in "$2" "$3"; do
		r=r$n; h=h$n
		ip netns add $r
		ip netns add $h
		ip link add $r-i type veth peer name i-$r
		ip link set i-$r netns inet
		ip link set $r-i netns $r
		ip netns exec inet ip link set i-$r master br0
		ip netns exec inet ip link set i-$r up
		ip link add $r-h type veth peer name $h-r
		ip link set $r-h netns $r
		ip link set $h-r netns $h
		rnd=""
		[ "$kind" = symmetric ] && rnd="--random-fully"
		ip netns exec $r sh -c "
			ip link set lo up
			ip addr add 203.0.113.$n/24 dev $r-i && ip link set $r-i up
			ip addr add 192.168.1.1/24 dev $r-h && ip link set $r-h up
			sysctl -qw net.ipv4.ip_forward=1
			iptables -P FORWARD DROP
			iptables -A FORWARD -i $r-h -o $r-i -j ACCEPT
			iptables -A FORWARD -i $r-i -o $r-h -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
			iptables -t nat -A POSTROUTING -o $r-i -j MASQUERADE $rnd"
		ip netns exec $h sh -c "
			ip link set lo up
			ip addr add 192.168.1.2/24 dev $h-r && ip link set $h-r up
			ip route add default via 192.168.1.1"
		echo "home $n: $kind router"
		n=$((n + 1))
	done
	;;
down)
	for ns in h1 h2 r1 r2 inet; do ip netns del $ns 2>/dev/null || true; done
	;;
esac
