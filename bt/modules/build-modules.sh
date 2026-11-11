#!/bin/sh
# Collect the Bluetooth modules built by kernel/build-kernel.sh into bt/modules/
# so that prepare-rootfs.sh can install them.  BT is a module set (not built in)
# because the WCN3990 needs the PM6150(L) rails in their vendor windows before
# the UART is touched, and those are set from userspace (wlan-rails.service).
set -eu
REPO=$(cd "$(dirname "$0")/../.." && pwd)
SRC=${SRC:-$REPO/build/linux-6.12}
OUT=${OUT:-$REPO/bt/modules}

mkdir -p "$OUT"
for m in crypto/ecc.ko crypto/ecdh_generic.ko net/bluetooth/bluetooth.ko \
         net/bluetooth/rfcomm/rfcomm.ko net/bluetooth/hidp/hidp.ko \
         drivers/bluetooth/btqca.ko drivers/bluetooth/btbcm.ko \
         drivers/bluetooth/hci_uart.ko; do
    [ -f "$SRC/$m" ] || { echo "missing $SRC/$m - run kernel/build-kernel.sh" >&2; exit 1; }
    cp -f "$SRC/$m" "$OUT/"
done
ls -l "$OUT"/*.ko
sha256sum "$OUT"/*.ko
