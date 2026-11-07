#!/bin/sh
# Pack u-boot.bin as the "kernel", the FIT as the "ramdisk" and the stock
# boot DTB into an Android boot image v2 (the format ABL loads from boot_b).
#
#   FIT=build/fit-6.12.itb ./uboot/pack-bootimg.sh
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)

UBOOT=${UBOOT:-$REPO/artifacts/u-boot.bin}
FIT=${FIT:-$REPO/build/fit-6.12.itb}
DTB=${DTB:-$REPO/artifacts/stock-boot.dtb}
OUT=${OUT:-$REPO/build/odessa-6.12-boot.img}
MKBOOTIMG=${MKBOOTIMG:-$REPO/tools/host/mkbootimg/mkbootimg.py}

for f in "$UBOOT" "$FIT" "$DTB" "$MKBOOTIMG"; do
    [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
done

python3 "$MKBOOTIMG" \
    --kernel "$UBOOT" \
    --ramdisk "$FIT" \
    --dtb "$DTB" \
    --header_version 2 \
    --pagesize 4096 \
    --base 0 \
    --kernel_offset 0x8000 \
    --ramdisk_offset 0x1000000 \
    --tags_offset 0x100 \
    --dtb_offset 0x1f00000 \
    --cmdline '' \
    -o "$OUT"

ls -l "$OUT"
sha256sum "$OUT"

# boot_b is a 64 MiB partition; refuse to emit something that cannot fit
SIZE=$(wc -c < "$OUT")
if [ "$SIZE" -gt 67108864 ]; then
    echo "ERROR: image is $SIZE bytes, larger than the 64 MiB boot partition" >&2
    exit 1
fi
echo "fits: $SIZE / 67108864 bytes"
