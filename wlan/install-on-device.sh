#!/bin/sh
# Install the Wi-Fi (WCN3990) pieces on a running odessa system.
# Run as root *on the device* from a copied wlan/ directory:
#
#   scp -r wlan root@<dev>:/root/ && ssh root@<dev> /root/wlan/install-on-device.sh
#
# Idempotent. The .ko files must match the running kernel (build them with
# wlan/modules/build-modules.sh against the same kernel tree).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
KREL=$(uname -r)

[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }

for m in smmu_probe wlan_rails mmi_unit_info; do
    [ -f "$HERE/modules/$m.ko" ] || { echo "missing $HERE/modules/$m.ko" >&2; exit 1; }
done

install -d -m 755 /usr/local/sbin "/lib/modules/$KREL/extra" /opt/re-tools \
    /lib/firmware/ath10k/WCN3990/hw1.0 /etc/systemd/system
install -m 755 "$HERE/tools/insmod_static" /usr/local/sbin/insmod_static
for m in smmu_probe wlan_rails mmi_unit_info; do
    install -m 644 "$HERE/modules/$m.ko" "/lib/modules/$KREL/extra/$m.ko"
done
for t in iw wpa_supplicant wpa_cli; do
    install -m 755 "$HERE/tools/$t" "/opt/re-tools/$t"
done
install -m 644 "$HERE/firmware/firmware-5.bin" /lib/firmware/ath10k/WCN3990/hw1.0/firmware-5.bin
install -m 644 "$HERE/firmware/board-2.bin"    /lib/firmware/ath10k/WCN3990/hw1.0/board-2.bin
install -m 644 "$HERE/firmware/regulatory.db" "$HERE/firmware/regulatory.db.p7s" /lib/firmware/

for u in wlan-smmu wlan-rails mmi-unit-info; do
    sed "s|/lib/modules/6\.12\.0/|/lib/modules/$KREL/|" "$HERE/units/$u.service" \
        > "/etc/systemd/system/$u.service"
    systemctl enable "$u" >/dev/null 2>&1 || true
done
# association + DHCP (installs default route and DNS from the lease)
install -m 755 "$HERE/scripts/odessa-wlan-up.sh" /usr/local/sbin/odessa-wlan-up.sh
install -m 755 "$HERE/scripts/odessa-udhcpc.sh"  /usr/local/sbin/odessa-udhcpc.sh
install -m 644 "$HERE/units/odessa-wlan.service" /etc/systemd/system/odessa-wlan.service
systemctl enable odessa-wlan >/dev/null 2>&1 || true
systemctl daemon-reload

if [ ! -f /etc/wpa_supplicant.conf ]; then
    cat > /etc/wpa_supplicant.conf <<'WPAEOF'
ctrl_interface=/run/wpa_supplicant
update_config=1
# network={ ssid="SSID" psk="passphrase" key_mgmt=WPA-PSK proto=RSN pairwise=CCMP group=CCMP }
WPAEOF
    chmod 600 /etc/wpa_supplicant.conf
fi

echo "install-on-device: done (kernel $KREL)"
