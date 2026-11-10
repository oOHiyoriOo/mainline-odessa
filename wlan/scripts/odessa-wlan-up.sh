#!/bin/sh
# Bring up wlan0 end to end: wait for the device, associate with the network
# from /etc/wpa_supplicant.conf, then lease an address plus default route and
# DNS through the busybox DHCP client.
#
# The unit is a no-op while the shipped template has no network={} block, so a
# fresh install boots without Wi-Fi exactly as before.
set -u
BB=/usr/local/bin/busybox
CONF=${CONF:-/etc/wpa_supplicant.conf}
IFACE=wlan0

grep -q '^[[:space:]]*network=' "$CONF" 2>/dev/null || {
	echo "odessa-wlan: no network configured in $CONF, skipping"
	exit 0
}

for _ in $(seq 1 90); do
	[ -e "/sys/class/net/$IFACE" ] && break
	sleep 1
done
[ -e "/sys/class/net/$IFACE" ] || {
	echo "odessa-wlan: $IFACE did not appear (modem/firmware up?)" >&2
	exit 1
}

$BB ip link set "$IFACE" up 2>/dev/null

if ! pidof wpa_supplicant >/dev/null 2>&1; then
	/opt/re-tools/wpa_supplicant -Dnl80211 -i "$IFACE" -c "$CONF" -B
fi

# wpa_supplicant needs a few seconds after the firmware load; wait for the
# 4-way handshake instead of racing it
st=""
for _ in $(seq 1 60); do
	st=$(/opt/re-tools/wpa_cli -i "$IFACE" status 2>/dev/null | sed -n 's/^wpa_state=//p')
	[ "$st" = "COMPLETED" ] && break
	sleep 1
done
[ "$st" = "COMPLETED" ] || {
	echo "odessa-wlan: association failed (wpa_state=${st:-unknown})" >&2
	exit 1
}

# -b: daemonise after the lease, -p: pidfile for ExecStop, -s: our hook
if ! pidof udhcpc >/dev/null 2>&1; then
	$BB udhcpc -i "$IFACE" -b -p /run/udhcpc.$IFACE.pid \
		-s /usr/local/sbin/odessa-udhcpc.sh
fi

# wait for the hook to install the default route before the unit goes active
for _ in $(seq 1 30); do
	$BB ip route show default 2>/dev/null | grep -q "dev $IFACE" && break
	sleep 1
done
if $BB ip route show default 2>/dev/null | grep -q "dev $IFACE"; then
	# the clock starts at the rootfs build time (no RTC); restarting tsyncd
	# here makes it step the clock immediately instead of waiting for its
	# next (backed-off) poll interval
	[ -x /usr/lib/systemd/systemd-timesyncd ] && \
		systemctl try-restart systemd-timesyncd >/dev/null 2>&1 || true
	echo "odessa-wlan: up ($( $BB ip -4 -o addr show "$IFACE" 2>/dev/null | awk '{print $4}' ))"
else
	echo "odessa-wlan: associated but no default route (DHCP?)" >&2
	exit 1
fi
