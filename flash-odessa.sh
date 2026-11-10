#!/bin/sh
# Flash the odessa 6.12 V1 release and install the rootfs from scratch.
#
#   boot_a  : stock Android stays untouched (rescue)
#   dtbo_a/b: untouched
#   boot_b  : U-Boot chainload + FIT (prep initramfs, no embedded payload)
#   userdata: formatted and installed over SSH by rootfs/install-to-device.sh
#
# Usage: ./flash-odessa.sh
# Env:   IMG, ROOTFS, KEY, DEV, ASSUME_YES=1
set -e
REPO=$(cd "$(dirname "$0")" && pwd)
IMG=${IMG:-$REPO/artifacts/odessa-6.12-boot.img}
ROOTFS=${ROOTFS:-$REPO/artifacts/rootfs-install.tar.gz}
KEY=${KEY:-$HOME/.ssh/id_ed25519}
DEV=${DEV:-172.16.42.1}
ASSUME_YES=${ASSUME_YES:-0}
SSH="ssh -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"

[ -f "$IMG" ]    || { echo "missing $IMG" >&2; exit 1; }
[ -f "$ROOTFS" ] || { echo "missing $ROOTFS" >&2; exit 1; }
echo "boot image: $IMG"
echo "sha256:     $(sha256sum "$IMG" | cut -d' ' -f1)"
echo "rootfs:     $ROOTFS ($(du -h "$ROOTFS" | cut -f1))"
fastboot devices

if [ "$ASSUME_YES" != 1 ]; then
    printf "This flashes boot_b, wipes userdata and installs the rootfs. Type 'yes': "
    read -r a; [ "$a" = yes ] || { echo aborted; exit 1; }
fi

echo "== flash boot_b"
fastboot flash boot_b "$IMG"
fastboot set_active b
fastboot reboot

wait_ssh() {
    i=0
    while [ "$i" -lt 60 ]; do
        if $SSH root@"$DEV" true 2>/dev/null; then return 0; fi
        i=$((i + 1)); sleep 3
    done
    return 1
}

echo "== waiting for the prep initramfs at $DEV"
wait_ssh || { echo "device did not come up at $DEV" >&2; exit 1; }

# Re-install on a device that still boots the old rootfs: drop the ready flag
# and reboot into the initramfs.
if $SSH root@"$DEV" "grep -q \" / \" /proc/mounts && grep -q '/dev/sdb24 / ' /proc/mounts" 2>/dev/null; then
    echo "== target booted the installed rootfs; rebooting into the prep initramfs"
    $SSH root@"$DEV" "rm -f /etc/odessa-ready; sync; reboot" || true
    sleep 20
    wait_ssh || { echo "device did not return to the initramfs" >&2; exit 1; }
fi

echo "== install rootfs (wipes userdata)"
KEY="$KEY" DEV="$DEV" "$REPO/rootfs/install-to-device.sh" "$ROOTFS" --yes

echo "== reboot into the installed system"
$SSH root@"$DEV" "sync; reboot" || true
echo "Done. After ~60 s: ssh -i $KEY root@$DEV"
