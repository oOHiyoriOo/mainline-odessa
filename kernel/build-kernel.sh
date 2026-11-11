#!/bin/sh
# Build the odessa Linux 6.12 kernel (Image.gz).
#
#   TARBALL=/path/to/linux-6.12.tar.xz ./kernel/build-kernel.sh
#
# Without TARBALL the pinned upstream tarball is downloaded once and verified.
# Requires an aarch64 cross toolchain (CROSS_COMPILE=aarch64-linux-gnu-).
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)

VER=6.12
SHA=b1a2562be56e42afb3f8489d4c2a7ac472ac23098f1ef1c1e40da601f54625eb
URL=https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${VER}.tar.xz
TARBALL=${TARBALL:-$REPO/build/linux-${VER}.tar.xz}
SRC=${SRC:-$REPO/build/linux-${VER}}
OUT=${OUT:-$REPO/build/Image-${VER}.gz}
JOBS=${JOBS:-12}
CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}

mkdir -p "$REPO/build"

if [ ! -d "$SRC" ]; then
    if [ ! -f "$TARBALL" ]; then
        echo "== download $URL"
        curl -fL --max-time 900 -o "$TARBALL" "$URL"
    fi
    echo "== verify sha256"
    echo "$SHA  $TARBALL" | sha256sum -c -
    echo "== extract"
    mkdir -p "$SRC"
    tar xf "$TARBALL" -C "$SRC" --strip-components=1
fi

echo "== apply odessa patches (idempotent)"
if [ ! -f "$SRC/drivers/clk/qcom/gcc-sdmmagpie.c" ]; then
    ( cd "$SRC" && patch -p1 < "$REPO/kernel/patches/0001-odessa-sm6150-support.patch" )
fi
if [ ! -f "$SRC/drivers/soc/qcom/odessa_glink.c" ]; then
    ( cd "$SRC" && patch -p1 < "$REPO/kernel/patches/0002-odessa-modem-pas.patch" )
fi
if [ ! -f "$SRC/drivers/power/supply/odessa_chg.c" ]; then
    ( cd "$SRC" && patch -p1 < "$REPO/kernel/patches/0003-odessa-charger.patch" )
fi
# Wi-Fi (WCN3990/ath10k) fixes, see docs/BUILD.md section 7
if ! grep -q "skipping quiet mode, no vdev exists yet" "$SRC/drivers/net/wireless/ath/ath10k/thermal.c"; then
    ( cd "$SRC" && patch -p1 < "$REPO/kernel/patches/0004-ath10k-snoc-skip-quiet-mode-before-vdev.patch" )
fi
if ! grep -q "ath10k_thermal_set_throttling(ar);" "$SRC/drivers/net/wireless/ath/ath10k/mac.c"; then
    ( cd "$SRC" && patch -p1 < "$REPO/kernel/patches/0005-ath10k-reapply-throttling-on-first-vif.patch" )
fi
if ! grep -q "failed to pre-create BSSID peer" "$SRC/drivers/net/wireless/ath/ath10k/mac.c"; then
    ( cd "$SRC" && patch -p1 < "$REPO/kernel/patches/0006-ath10k-snoc-sta-bssid-peer-before-vdev-start.patch" )
fi
# GENI UART: optional FIFO mode instead of the QUP DMA path (odessa BT), see
# kernel/patches/0007-qcom-geni-uart-fifo-mode.patch
if ! grep -q "qcom,geni-fifo" "$SRC/drivers/tty/serial/qcom_geni_serial.c"; then
    ( cd "$SRC" && patch -p1 < "$REPO/kernel/patches/0007-qcom-geni-uart-fifo-mode.patch" )
fi

echo "== configure"
cp -f "$REPO/kernel/config-6.12-odessa" "$SRC/.config"
make -C "$SRC" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" olddefconfig

echo "== build Image.gz (jobs=$JOBS, nice 10)"
nice -n 10 make -C "$SRC" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" -j"$JOBS" Image.gz

cp -f "$SRC/arch/arm64/boot/Image.gz" "$OUT"
ls -l "$OUT"
sha256sum "$OUT"
