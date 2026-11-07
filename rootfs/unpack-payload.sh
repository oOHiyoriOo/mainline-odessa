#!/bin/sh
# Unpack the release rootfs payload.
#
#   ./rootfs/unpack-payload.sh            -> build/rootfs.tar
#   ./rootfs/unpack-payload.sh --extract  -> build/rootfs-tree/ (needs sudo)
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
PAYLOAD=${PAYLOAD:-$REPO/artifacts/rootfs-install.tar.gz}
OUT=${OUT:-$REPO/build/rootfs.tar}

mkdir -p "$REPO/build"
gunzip -c "$PAYLOAD" > "$OUT"
tar tf "$OUT" >/dev/null
echo "rootfs.tar: $(du -h "$OUT" | cut -f1)"
sha256sum "$OUT"

if [ "${1:-}" = "--extract" ]; then
    TREE=${TREE:-$REPO/build/rootfs-tree}
    sudo rm -rf "$TREE"; mkdir -p "$TREE"
    sudo tar xpf "$OUT" -C "$TREE"
    sudo chown root:root "$TREE"
    echo "tree: $TREE"
fi
