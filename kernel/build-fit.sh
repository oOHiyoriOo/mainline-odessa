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

# Layout guard: the arm64 Image header's image_size includes BSS. 0x9B000000
# (the old FDT load) sits only 48 MiB above the kernel load, and a kernel with
# Bluetooth built in is already 48.1 MiB - the BSS then overwrote the FDT and
# the board hung before the console. Fail the build instead of booting that.
python3 - "$KERNEL" "$DTB" <<'PYEOF'
import gzip, struct, sys
kernel, dtb = sys.argv[1], sys.argv[2]
hdr = gzip.open(kernel, "rb").read(64)
if hdr[56:60] != b"ARMd":
    sys.exit("fit layout: %s has no arm64 Image header" % kernel)
image_size = struct.unpack("<Q", hdr[16:24])[0]
kernel_load, fdt_load, initrd_load = 0x98000000, 0x9F800000, 0xA0000000
dtb_size = __import__("os").path.getsize(dtb)
if kernel_load + image_size > fdt_load:
    sys.exit("fit layout: kernel %#x+%#x overlaps fdt %#x"
             % (kernel_load, image_size, fdt_load))
if fdt_load + dtb_size > initrd_load:
    sys.exit("fit layout: fdt %#x+%#x overlaps initramfs %#x"
             % (fdt_load, dtb_size, initrd_load))
print("fit layout: kernel %#x+%#x, fdt %#x+%#x, initramfs %#x"
      % (kernel_load, image_size, fdt_load, dtb_size, initrd_load))
PYEOF
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
