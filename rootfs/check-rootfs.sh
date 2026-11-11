#!/bin/sh
# Static regression check for the prepared odessa rootfs tree.
#
#   ./rootfs/check-rootfs.sh [build/rootfs-tree] [debs.tar]
#
# Verifies exactly the things whose absence caused real regressions:
#   - the SSH-only screen-off unit/script (a missing service left the panel
#     glowing while the framebuffer was already black)
#   - masked getty/systemd-backlight (they redraw the console or restore a
#     saved brightness after the screen-off service ran)
#   - the modem RFS plumbing (by-partlabel + RFS link scripts, unit drop-ins)
#   - the modem firmware and PD maps (a missing modem.mdt aborts the start)
#
# Exit status 0 = all checks passed; 1 = at least one failure.
set -eu

REPO=$(cd "$(dirname "$0")/.." && pwd)
R=${1:-${ROOTFS_DIR:-$REPO/build/rootfs-tree}}
DEBS=${2:-$REPO/build/debs-combined.tar}

fail=0
ok()   { printf '  ok   %s\n' "$*"; }
bad()  { printf '  FAIL %s\n' "$*"; fail=$((fail + 1)); }

check_file() { # path, min size
	if [ -f "$1" ] && [ "$(wc -c < "$1")" -ge "${2:-1}" ]; then
		ok "$1"
	else
		bad "$1 (missing or empty)"
	fi
}

check_exec() {
	if [ -x "$1" ]; then ok "$1"; else bad "$1 (missing or not executable)"; fi
}

check_link() { # link, target
	if [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; then
		ok "$1 -> $2"
	else
		bad "$1 is not a symlink to $2"
	fi
}

echo "== rootfs tree: $R"
[ -d "$R/etc" ] || { echo "rootfs missing (build it first)" >&2; exit 1; }

echo "-- screen-off"
check_exec "$R/usr/local/sbin/odessa-screen-off.sh"
check_file "$R/etc/systemd/system/odessa-screen-off.service"
check_link "$R/etc/systemd/system/multi-user.target.wants/odessa-screen-off.service" \
	/etc/systemd/system/odessa-screen-off.service
grep -q '2048 > "\$B/brightness"' "$R/usr/local/sbin/odessa-screen-off.sh" 2>/dev/null &&
	ok "screen-off does the non-zero -> zero WLED transition" ||
	bad "screen-off script lacks the 2048 brightness transition"
check_link "$R/etc/systemd/system/getty@tty1.service" /dev/null
check_link "$R/etc/systemd/system/systemd-backlight@backlight:backlight.service" /dev/null

echo "-- modem RFS plumbing"
check_exec "$R/usr/local/sbin/odessa-partlabels"
check_exec "$R/usr/local/sbin/odessa-rfs-links"
check_file "$R/etc/systemd/system/rmtfs.service.d/override.conf"
check_file "$R/etc/systemd/system/tqftpserv.service.d/override.conf"
grep -q 'odessa-partlabels' "$R/etc/systemd/system/rmtfs.service.d/override.conf" 2>/dev/null &&
	ok "rmtfs runs odessa-partlabels" || bad "rmtfs drop-in does not create by-partlabel"
grep -q 'odessa-rfs-links' "$R/etc/systemd/system/tqftpserv.service.d/override.conf" 2>/dev/null &&
	ok "tqftpserv runs odessa-rfs-links" || bad "tqftpserv drop-in does not link the RFS tree"

echo "-- firmware"
# modem firmware may be a symlink into the (read-only) vendor partition,
# which is not mounted on the build host - accept a link as well
# The payload intentionally ships no proprietary modem firmware; it is linked
# from the read-only vendor partition at boot by odessa-fw-provision.
prov=0
[ -x "$R/usr/local/sbin/odessa-fw-provision" ] &&
	[ -e "$R/etc/systemd/system/odessa-fw-provision.service" ] && prov=1
if [ -f "$R/lib/firmware/modem.mdt" ] || [ -L "$R/lib/firmware/modem.mdt" ]; then
	ok "$R/lib/firmware/modem.mdt"
elif [ "$prov" -eq 1 ]; then
	ok "modem.mdt provided by odessa-fw-provision (vendor partition)"
else
	bad "$R/lib/firmware/modem.mdt (missing, no provisioning unit)"
fi
if ls "$R"/lib/firmware/modem.b[0-9]* >/dev/null 2>&1 || [ "$prov" -eq 1 ]; then
	ok "modem.b* segments ($([ "$prov" -eq 1 ] && echo runtime || echo present))"
else
	bad "modem.b* segments missing"
fi
if [ -f "$R/lib/firmware/modemr.jsn" ] || [ "$prov" -eq 1 ]; then
	ok "$R/lib/firmware/modemr.jsn (provisioned)"
else
	bad "$R/lib/firmware/modemr.jsn missing"
fi
if [ -f "$R/lib/firmware/modemuw.jsn" ] || [ "$prov" -eq 1 ]; then
	ok "$R/lib/firmware/modemuw.jsn (provisioned)"
else
	bad "$R/lib/firmware/modemuw.jsn missing"
fi

echo "-- battery guard"
check_exec "$R/usr/local/sbin/battery-guard.sh"
if cmp -s "$REPO/rootfs/battery-guard.sh" "$R/usr/local/sbin/battery-guard.sh"; then
	ok "guard matches rootfs/battery-guard.sh"
else
	bad "guard differs from rootfs/battery-guard.sh (re-run prepare-rootfs.sh)"
fi
for pat in 'SOC_LOW=40' 'SOC_HIGH=60' 'CHARGE_ON_MAX' 'CHARGE_REST' '4384000'; do
	grep -q "$pat" "$R/usr/local/sbin/battery-guard.sh" 2>/dev/null &&
		ok "guard carries $pat" || bad "guard lacks $pat"
done
if "$REPO/rootfs/test-battery-guard.sh" >/dev/null 2>&1; then
	ok "rootfs/test-battery-guard.sh"
else
	bad "rootfs/test-battery-guard.sh failed"
fi

echo "-- boot readiness"
# /etc/odessa-ready is written by rootfs/install-to-device.sh on the device,
# not by prepare-rootfs.sh; check the installer still does it.
grep -q 'odessa-ready' "$REPO/rootfs/install-to-device.sh" 2>/dev/null &&
	ok "installer writes /etc/odessa-ready" || bad "installer does not write /etc/odessa-ready"
# Either systemd is part of the payload (ELF), or the payload is the base
# image and rootfs/install-to-device.sh installs the bundled arm64 systemd
# debs on the device (real systemd must not be a /bin/sh stub).
if [ -x "$R/sbin/init" ] || head -c 4 "$R/usr/lib/systemd/systemd" 2>/dev/null | grep -q ELF; then
	ok "init/systemd present"
elif [ -f "$REPO/rootfs/debs/systemd-debs-2604.tar" ]; then
	ok "init/systemd installed from rootfs/debs at install time"
else
	bad "no init/systemd and no systemd debs"
fi
[ -x "$R/sbin/init" ] && ok "$R/sbin/init"
grep -qE '^proc[[:space:]]+/proc' "$R/etc/fstab" 2>/dev/null &&
	ok "fstab mounts /proc" || bad "fstab lacks /proc"

echo "-- RFS packages (from $DEBS)"
if [ -f "$DEBS" ]; then
	LIST=$(tar -tf "$DEBS" 2>/dev/null || true)
	for pkg in rmtfs tqftpserv protection-domain-mapper libqrtr1; do
		if printf '%s\n' "$LIST" | grep -qiE "(^|/)${pkg}_[^/]*\.deb$"; then
			ok "$pkg deb in $DEBS"
		else
			bad "$pkg deb not found in $DEBS"
		fi
	done
else
	printf '  skip %s not built\n' "$DEBS"
fi

# --- Wi-Fi (WCN3990) -------------------------------------------------------
KREL=6.12.0
for m in smmu_probe wlan_rails mmi_unit_info; do
	check_file "$R/lib/modules/$KREL/extra/$m.ko" 1000
done
check_file "$R/usr/local/sbin/insmod_static" 1000
for u in wlan-smmu wlan-rails mmi-unit-info; do
	check_file "$R/etc/systemd/system/$u.service" 50
	if [ -L "$R/etc/systemd/system/multi-user.target.wants/$u.service" ]; then
		ok "$u enabled"
	else
		bad "$u not enabled"
	fi
done
check_file "$R/lib/firmware/ath10k/WCN3990/hw1.0/firmware-5.bin" 30
check_file "$R/lib/firmware/ath10k/WCN3990/hw1.0/board-2.bin" 100000
check_file "$R/lib/firmware/regulatory.db" 1000
check_file "$R/lib/firmware/regulatory.db.p7s" 500

# --- Bluetooth (WCN3990 over GENI SE3) -------------------------------------
for f in crbtfw21.tlv crnv21.bin; do
	check_file "$R/lib/firmware/qca/$f" 1000
done
for m in ecc ecdh_generic bluetooth btqca btbcm hci_uart rfcomm hidp; do
	check_file "$R/lib/modules/6.12.0/extra/$m.ko" 1000
done
check_exec "$R/usr/local/sbin/bt-load.sh"
check_file "$R/etc/systemd/system/bt-stack.service" 50
if [ -L "$R/etc/systemd/system/multi-user.target.wants/bt-stack.service" ]; then
	ok "bt-stack enabled"
else
	bad "bt-stack not enabled"
fi
# the stack must come up after the PMIC rails are in their vendor windows
if grep -q '^After=wlan-rails.service' "$R/etc/systemd/system/bt-stack.service" 2>/dev/null; then
	ok "bt-stack ordered after wlan-rails"
else
	bad "bt-stack is not ordered after wlan-rails.service"
fi
# and the UART must run in FIFO mode (no QUP DMA path in this vendor DTB)
if grep -q 'qcom,geni-fifo' "$REPO/kernel/dts/odessa-6.12-modem.dts" 2>/dev/null; then
	ok "BT UART uses qcom,geni-fifo"
else
	bad "qcom,geni-fifo missing from the BT UART node"
fi

# --- BlueZ (userspace stack, bundled debs) ---------------------------------
check_file "$R/usr/libexec/bluetooth/bluetoothd" 1000
check_file "$R/usr/bin/bluetoothctl" 1000
check_file "$R/usr/bin/btmgmt" 1000
check_file "$R/etc/bluetooth/main.conf" 100
check_file "$R/usr/share/dbus-1/system.d/bluetooth.conf" 100
check_file "$R/usr/lib/systemd/system/bluetooth.service" 100
check_file "$R/etc/systemd/system/bluetooth.service.d/10-odessa-bt-stack.conf" 20
if [ -L "$R/etc/systemd/system/multi-user.target.wants/bluetooth.service" ]; then
	ok "bluetooth.service enabled"
else
	bad "bluetooth.service not enabled"
fi
if grep -q '^After=bt-stack.service' \
	"$R/etc/systemd/system/bluetooth.service.d/10-odessa-bt-stack.conf" 2>/dev/null; then
	ok "bluetoothd ordered after bt-stack"
else
	bad "bluetoothd is not ordered after bt-stack.service"
fi
# the WCN3990 is a combo chip: BT only answers once WLAN (icnss) initialised it
if grep -q '^After=.*odessa-wlan.service' "$R/etc/systemd/system/bt-stack.service" 2>/dev/null; then
	ok "bt-stack ordered after odessa-wlan"
else
	bad "bt-stack is not ordered after odessa-wlan.service"
fi
if grep -q '^bluetooth:' "$R/etc/group"; then
	ok "bluetooth group present"
else
	bad "bluetooth group missing"
fi
# TLS trust + the account systemd-timesyncd runs as (both were missing in the
# sanitized payload and broke apt/docker and NTP out of the box)
check_file "$R/etc/ssl/certs/ca-certificates.crt" 100000
check_file "$R/usr/bin/openssl" 100000
if grep -q '^systemd-timesync:' "$R/etc/passwd"; then
	ok "systemd-timesync user present"
else
	bad "systemd-timesync user missing (timesyncd fails with status 217/USER)"
fi
# every DT_NEEDED of the two shipped binaries must resolve inside the tree
READELF=$(command -v aarch64-linux-gnu-readelf || true)
if [ -n "$READELF" ]; then
	missing_lib=0
	for b in usr/libexec/bluetooth/bluetoothd usr/bin/bluetoothctl; do
		for l in $("$READELF" -d "$R/$b" 2>/dev/null | \
			sed -n 's/.*Shared library: \[\(.*\)\]/\1/p'); do
			found=
			for d in usr/lib/aarch64-linux-gnu lib/aarch64-linux-gnu usr/lib lib; do
				[ -e "$R/$d/$l" ] && found=1 && break
			done
			[ -n "$found" ] || { bad "missing lib $l for $b"; missing_lib=1; }
		done
	done
	[ "$missing_lib" = 0 ] && ok "bluez shared libraries resolve"
fi
for t in iw wpa_supplicant wpa_cli; do
	check_file "$R/opt/re-tools/$t" 100000
done
# the firmware metadata must carry MGMT_TX_BY_REF (bit 18) + NON_BMI (bit 19)
if [ -f "$R/lib/firmware/ath10k/WCN3990/hw1.0/firmware-5.bin" ]; then
	byte=$(od -An -tx1 -j34 -N1 "$R/lib/firmware/ath10k/WCN3990/hw1.0/firmware-5.bin" | tr -d ' ')
	case "$byte" in
	0c) ok "firmware features byte 0x0c (mgmt-tx-by-ref)" ;;
	*)  bad "firmware features byte is 0x$byte, expected 0x0c" ;;
	esac
fi
if grep -q 'ctrl_interface=/run/wpa_supplicant' "$R/etc/wpa_supplicant.conf" 2>/dev/null; then
	ok "wpa_supplicant.conf template"
else
	bad "wpa_supplicant.conf template missing"
fi
# bring-up: association + DHCP must install the default route and DNS
for f in /usr/local/sbin/odessa-wlan-up.sh /usr/local/sbin/odessa-udhcpc.sh; do
	if [ -x "$R$f" ]; then ok "$R$f"; else bad "$R$f missing"; fi
done
if [ -x "$R/usr/lib/systemd/systemd-timesyncd" ]; then
	ok "systemd-timesyncd present"
else
	bad "systemd-timesyncd missing (clock stays at build time)"
fi
if [ -L "$R/etc/systemd/system/sysinit.target.wants/systemd-timesyncd.service" ]; then
	ok "systemd-timesyncd enabled"
else
	bad "systemd-timesyncd not enabled"
fi
if grep -q "try-restart systemd-timesyncd" "$R/usr/local/sbin/odessa-wlan-up.sh" 2>/dev/null; then
	ok "wlan bring-up restarts timesyncd"
else
	bad "wlan bring-up does not restart timesyncd"
fi
check_file "$R/etc/systemd/system/odessa-modem.service" 50
if [ -L "$R/etc/systemd/system/multi-user.target.wants/odessa-modem.service" ]; then
	ok "odessa-modem enabled"
else
	bad "odessa-modem not enabled"
fi
if grep -q "echo start > /sys/class/remoteproc/remoteproc0/state" \
   "$R/etc/systemd/system/odessa-modem.service" 2>/dev/null; then
	ok "modem unit starts the remoteproc"
else
	bad "modem unit does not start the remoteproc"
fi
check_file "$R/etc/systemd/system/odessa-wlan.service" 50
if [ -L "$R/etc/systemd/system/multi-user.target.wants/odessa-wlan.service" ]; then
	ok "odessa-wlan enabled"
else
	bad "odessa-wlan not enabled"
fi
if grep -q "ip route add default via" "$R/usr/local/sbin/odessa-udhcpc.sh" 2>/dev/null; then
	ok "dhcp hook installs default route"
else
	bad "dhcp hook does not install a default route"
fi

# --- modem userspace / pd-mapper ------------------------------------------
for t in /usr/bin/pd-mapper /usr/bin/rmtfs /usr/bin/tqftpserv; do
	if [ -x "$R$t" ]; then ok "$R$t"; else bad "$R$t missing"; fi
done
if [ -e "$R/etc/systemd/system/pd-mapper.service" ] &&
   [ -L "$R/etc/systemd/system/multi-user.target.wants/pd-mapper.service" ]; then
	ok "pd-mapper unit enabled"
else
	bad "pd-mapper unit missing/not enabled"
fi
if [ -x "$R/usr/local/sbin/odessa-fw-provision" ]; then
	ok "odessa-fw-provision present"
else
	bad "odessa-fw-provision missing"
fi

# --- iptables (docker bridge/NAT) -----------------------------------------
for t in /usr/sbin/iptables /usr/sbin/iptables-nft /usr/sbin/ip6tables; do
	if [ -e "$R$t" ]; then ok "$R$t"; else bad "$R$t missing"; fi
done
if [ -e "$R/usr/lib/aarch64-linux-gnu/libnftnl.so.11" ] ||
   ls "$R"/usr/lib/aarch64-linux-gnu/libnftnl.so.11* >/dev/null 2>&1; then
	ok "libnftnl present"
else
	bad "libnftnl missing"
fi


# --- docker ---------------------------------------------------------------
for t in /usr/local/bin/dockerd /usr/local/bin/docker /usr/local/bin/containerd; do
	if [ -x "$R$t" ]; then ok "$R$t"; else bad "$R$t missing"; fi
done
if [ -L "$R/etc/systemd/system/multi-user.target.wants/docker.service" ]; then
	ok "docker enabled"
else
	bad "docker not enabled"
fi

echo
if [ "$fail" -eq 0 ]; then
	echo "check-rootfs: PASS"
else
	echo "check-rootfs: $fail failure(s)"
	exit 1
fi
