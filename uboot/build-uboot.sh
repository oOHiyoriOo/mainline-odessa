#!/bin/sh
# Rebuild U-Boot v2026.10 with the odessa board support (optional).
#
# The repository ships the prebuilt artifacts/u-boot.bin, so this script is
# only needed if you want to rebuild the chainloader. It requires the upstream
# source tree and an aarch64 cross toolchain.
#
#   SRC=/path/to/u-boot-2026.10 ./uboot/build-uboot.sh
#
# The source tarball is not vendored (large); the version is pinned and the
# only code change is uboot/patches/0001-f_acm-nonblocking.patch.
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
SRC=${SRC:-$REPO/build/u-boot-2026.10}
OUT=${OUT:-$REPO/build/u-boot-build}
JOBS=${JOBS:-12}
CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}

[ -d "$SRC" ] || {
    echo "missing U-Boot source tree: $SRC" >&2
    echo "Download u-boot-2026.10 from https://ftp.denx.de/pub/u-boot/ and pass SRC=..." >&2
    exit 1
}

echo "== board files"
mkdir -p "$SRC/dts/upstream/src/arm64/qcom" "$SRC/arch/arm/dts" "$SRC/configs" "$SRC/board/qualcomm"
cp -f "$REPO/uboot/board/qcs615-odessa.dts"         "$SRC/dts/upstream/src/arm64/qcom/"
cp -f "$REPO/uboot/board/qcs615-odessa-u-boot.dtsi" "$SRC/arch/arm/dts/"
cp -f "$REPO/uboot/board/qcom_qcs615_odessa_defconfig" "$SRC/configs/"
cp -f "$REPO/uboot/board/odessa.env"                "$SRC/board/qualcomm/"

echo "== patch (idempotent)"
if ! grep -q "odessa: do not block the boot" "$SRC/drivers/usb/gadget/f_acm.c"; then
    ( cd "$SRC" && patch -p1 < "$REPO/uboot/patches/0001-f_acm-nonblocking.patch" )
fi

echo "== build"
mkdir -p "$OUT"
make -C "$SRC" O="$OUT" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" qcom_qcs615_odessa_defconfig
nice -n 10 make -C "$SRC" O="$OUT" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" -j"$JOBS"
ls -l "$OUT/u-boot.bin"
sha256sum "$OUT/u-boot.bin"
