#!/bin/sh
# Build the runtime DTB from the decompiled validated DTS.
#
#   DTS=kernel/dts/odessa-6.12-wled.dts ./kernel/build-dtb.sh
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
DTC=${DTC:-$REPO/tools/host/dtc}
DTS=${DTS:-$REPO/kernel/dts/odessa-6.12-modem.dts}
OUT=${OUT:-$REPO/build/odessa-6.12.dtb}
mkdir -p "$(dirname "$OUT")"
"$DTC" -I dts -O dtb -o "$OUT" "$DTS"
ls -l "$OUT"
sha256sum "$OUT"
