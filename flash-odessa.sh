#!/bin/sh
# Flash the odessa 6.12 release (Ubuntu 26.04.1 + systemd 259).
#
# The Motorola bootloader refuses "fastboot flash userdata" (policy) and
# validates the Android super format, but flashing boot_b is allowed and
# Linux may write userdata. The release boot image therefore installs the
# rootfs itself on first boot.
#
#   boot_a  : stock Android stays untouched (rescue)
#   dtbo_a/b: untouched
#   boot_b  : U-Boot chainload image (slot b becomes active)
#   userdata: written by the boot image itself on first boot (WIPED then)
#
# Usage: ./flash-odessa.sh
set -e
REPO=$(cd "$(dirname "$0")" && pwd)
IMG=${IMG:-$REPO/artifacts/odessa-6.12-boot.img}
[ -f "$IMG" ] || { echo "missing $IMG" >&2; exit 1; }
echo "image: $IMG"
echo "sha256: $(sha256sum "$IMG" | cut -d' ' -f1)"
[ "$(sha256sum "$IMG" | cut -d' ' -f1)" = "293533942759a466b0193645bb74e989be78e59988508b9dd2fce54744731f15" ] \
    || { echo "WARNING: sha256 differs from the tested release" >&2; }
fastboot devices
printf "This wipes userdata and sets slot b. Type 'yes': "
read -r a; [ "$a" = yes ] || { echo aborted; exit 1; }
fastboot erase userdata
fastboot flash boot_b "$IMG"
fastboot set_active b
fastboot reboot
echo "First boot installs Ubuntu 26.04 to userdata; wait ~2 min, then ssh root@172.16.42.1."
