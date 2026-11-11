#!/bin/sh
# Post-boot smoke test for the installed odessa rootfs (over SSH).
#
#   KEY=... ./tools/dev/check-boot.sh [host]
#
# Catches runtime regressions that a static rootfs check cannot see:
#   - the panel backlight really is off and the screen-off unit ran
#   - getty/systemd-backlight were not resurrected by udev/systemd
#   - the RFS stack (rmtfs/tqftpserv/pd-mapper) is up
#   - the modem firmware is in place
set -eu

HOST=${1:-${HOST:-172.16.42.1}}
KEY=${KEY:-/home/zero/.local/share/opencode/re-tools/_scratch/odessa/id_ed25519}
SSH="ssh -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 root@$HOST"

fail=0
ok()  { printf '  ok   %s\n' "$*"; }
bad() { printf '  FAIL %s\n' "$*"; fail=$((fail + 1)); }
run() { $SSH "$@" 2>/dev/null; }

echo "== boot check: $HOST"
echo "-- identity"
UNAME=$(run 'uname -r') || { echo "SSH unreachable" >&2; exit 1; }
printf '  %s\n' "$(run 'uname -a')"

echo "-- screen"
B=$(run 'cat /sys/class/backlight/backlight/brightness 2>/dev/null || echo missing')
[ "$B" = "0" ] && ok "backlight brightness=0" || bad "backlight brightness=$B"
[ "$(run 'systemctl is-active odessa-screen-off.service 2>/dev/null')" = active ] &&
	ok "odessa-screen-off active" || bad "odessa-screen-off not active"
[ "$(run 'systemctl is-enabled getty@tty1.service 2>/dev/null')" = masked ] &&
	ok "getty@tty1 masked" || bad "getty@tty1 not masked"
[ "$(run 'systemctl is-enabled systemd-backlight@backlight:backlight.service 2>/dev/null')" = masked ] &&
	ok "systemd-backlight masked" || bad "systemd-backlight not masked"

echo "-- RFS stack"
for u in rmtfs tqftpserv pd-mapper; do
	[ "$(run "systemctl is-active $u.service 2>/dev/null")" = active ] &&
		ok "$u active" || bad "$u not active"
done
run 'test -s /lib/firmware/modem.mdt' && ok "modem.mdt present" || bad "modem.mdt missing"
run 'test -s /lib/firmware/modemr.jsn' && ok "modemr.jsn present" || bad "modemr.jsn missing"

echo "-- modem"
printf '  state: %s\n' "$(run 'cat /sys/class/remoteproc/remoteproc0/state 2>/dev/null || echo n/a')"

echo "-- bluetooth"
[ "$(run 'systemctl is-active bt-stack.service 2>/dev/null')" = active ] &&
	ok "bt-stack active" || bad "bt-stack not active"
[ -n "$(run 'ls /sys/class/bluetooth/hci0 2>/dev/null')" ] &&
	ok "hci0 present" || bad "no hci0"
[ "$(run 'systemctl is-active bluetooth.service 2>/dev/null')" = active ] &&
	ok "bluetoothd active" || bad "bluetoothd not active"
ADDR=$(run 'bluetoothctl show 2>/dev/null | sed -n "s/^[[:space:]]*Controller \([0-9A-Fa-f:]\{17\}\).*/\1/p"')
[ -n "$ADDR" ] && ok "controller $ADDR" || bad "bluetoothctl show found no controller"
FW=$(run 'dmesg | grep -c "QCA setup on UART is completed"')
[ "${FW:-0}" -ge 1 ] && ok "WCN3990 firmware download" || bad "WCN3990 setup not completed"

echo
if [ "$fail" -eq 0 ]; then echo "check-boot: PASS"; else echo "check-boot: $fail failure(s)"; exit 1; fi
