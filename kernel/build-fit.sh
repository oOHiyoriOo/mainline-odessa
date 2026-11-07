#!/bin/sh
# Pack kernel + DTB + initramfs into a FIT image (the boot.img "ramdisk").
#
#   INITRD=build/initramfs.cpio.gz ./kernel/build-fit.sh
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)

KERNEL=${KERNEL:-$REPO/artifacts/Image-6.12.gz}
DTB=${DTB:-$REPO/artifacts/odessa-6.12.dtb}
INITRD=${INITRD:-$REPO/build/initramfs.cpio.gz}
OUT=${OUT:-$REPO/build/fit-6.12.itb}
MKIMAGE=${MKIMAGE:-$REPO/tools/host/mkimage}
ITS=${ITS:-$REPO/build/fit-6.12.its}

for f in "$KERNEL" "$DTB" "$INITRD"; do
    [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
done
[ -x "$MKIMAGE" ] || { echo "missing $MKIMAGE" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
# mkimage shells out to dtc to parse the FIT source; prefer the bundled one
PATH="$REPO/tools/host:$PATH"; export PATH

sed -e "s|@KERNEL@|$KERNEL|g" \
    -e "s|@DTB@|$DTB|g" \
    -e "s|@INITRAMFS@|$INITRD|g" \
    "$REPO/kernel/fit-6.12.its.in" > "$ITS"

"$MKIMAGE" -f "$ITS" "$OUT"
ls -l "$OUT"
sha256sum "$OUT"
"$MKIMAGE" -l "$OUT" | head -20
