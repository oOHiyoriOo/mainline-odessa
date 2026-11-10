#!/bin/sh
# busybox udhcpc hook for wlan0: address, default route and DNS from the lease.
#
# Without the default route the link works only inside its own prefix (ping to
# the AP, no apt/DNS), which is exactly what a bare `ip addr add` leaves behind.
# DNS is rewritten so the resolver follows the network instead of the baked-in
# fallback in /etc/resolv.conf.
set -u
BB=/usr/local/bin/busybox
IFACE=${interface:-wlan0}

case "${1:-}" in
deconfig)
	$BB ip addr flush dev "$IFACE" 2>/dev/null
	;;
bound | renew)
	# re-apply from scratch: renewals may hand out a different address or router
	$BB ip addr flush dev "$IFACE" 2>/dev/null
	$BB ip addr add "$ip/$mask" dev "$IFACE" 2>/dev/null

	gw=""
	for r in ${router:-}; do
		gw=$r
		break
	done
	if [ -n "$gw" ]; then
		$BB ip route del default 2>/dev/null
		$BB ip route add default via "$gw" dev "$IFACE"
		# DHCP-provided resolvers first, the gateway as fallback
		: >/etc/resolv.conf
		if [ -n "${dns:-}" ]; then
			for d in $dns; do echo "nameserver $d"; done >>/etc/resolv.conf
		else
			echo "nameserver $gw" >>/etc/resolv.conf
		fi
		echo "odessa-wlan: $IFACE $ip/$mask via $gw" >/dev/kmsg 2>/dev/null || true
	fi
	;;
esac
exit 0
