#!/bin/sh
# Build the odessa helper modules against the kernel built by
# kernel/build-kernel.sh (needs Module.symvers in SRC).
set -eu
REPO=$(cd "$(dirname "$0")/../.." && pwd)
SRC=${SRC:-$REPO/build/linux-6.12}
CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
JOBS=${JOBS:-12}

# make sure the cross toolchain is on PATH (persistent re-tools location)
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    for d in /home/zero/.local/share/opencode/re-tools/cross-aarch64/usr/bin; do
        if [ -x "$d/${CROSS_COMPILE}gcc" ]; then
            PATH="$d:$PATH"
            # x86_64 binutils helpers (libopcodes-*.so) live in the same prefix
            libdir=$(cd "$d/../lib/x86_64-linux-gnu" 2>/dev/null && pwd) || libdir=
            [ -n "$libdir" ] && LD_LIBRARY_PATH="$libdir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        fi
    done
    export PATH LD_LIBRARY_PATH
fi
command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1 || {
    echo "cross compiler ${CROSS_COMPILE}gcc not found in PATH" >&2
    exit 1
}

[ -f "$SRC/include/config/auto.conf" ] || {
    echo "missing $SRC/include/config/auto.conf - run kernel/build-kernel.sh first" >&2
    exit 1
}
# out-of-tree modpost resolves symbols through $SRC/Module.symvers, which the
# kernel build only generates while building in-tree modules
if [ ! -f "$SRC/Module.symvers" ]; then
    echo "== generating $SRC/Module.symvers (make modules)"
    nice -n 10 make -C "$SRC" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" \
        -j"$JOBS" modules
fi

nice -n 10 make -C "$SRC" M="$REPO/wlan/modules" \
    ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" -j"$JOBS" modules
ls -l "$REPO"/wlan/modules/*.ko
sha256sum "$REPO"/wlan/modules/*.ko
