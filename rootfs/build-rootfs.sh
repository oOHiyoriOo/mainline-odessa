#!/bin/bash
# Build the Ubuntu 26.04.1 arm64 rootfs from the pinned base tarball.
#
#   sudo ./rootfs/build-rootfs.sh
#
# Produces build/rootfs-tree/ and build/rootfs.tar (systemd is NOT included;
# either use the release payload from artifacts/ or install the debs with
# rootfs/install-to-device.sh, which runs the maintainer scripts on the
# device where the architecture is native).
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
BASE="$REPO/rootfs/base"
TAR="$BASE/ubuntu-base-26.04.1-base-arm64.tar.gz"
SHA=5a1906794ced63a71a8119c3f211ef5f0bbe0a243001b4bbd41fdf80c5b219fd
TREE=${TREE:-$REPO/build/rootfs-tree}
OUT=${OUT:-$REPO/build/rootfs.tar}

[ -f "$TAR" ] || {
    echo "missing $TAR" >&2
    echo "Download ubuntu-base-26.04.1-base-arm64.tar.gz from" >&2
    echo "https://cdimage.ubuntu.com/ubuntu-base/releases/26.04/release/" >&2
    exit 1
}
echo "== verify sha256"
echo "$SHA  $TAR" | sha256sum -c -

echo "== extract"
rm -rf "$TREE"
mkdir -p "$TREE"
tar -xpf "$TAR" -C "$TREE"

echo "== configure"
ROOTFS_DIR="$TREE" \
TOOLS="${TOOLS:-$REPO/initramfs/tools}" \
AUTHKEY="${AUTHKEY:-$REPO/config/authorized_keys.pub}" \
    bash "$REPO/rootfs/prepare-rootfs.sh"

echo "== package"
# the root entry must be root-owned: GNU tar (used by dpkg to unpack packages)
# refuses "unsafe path transitions" otherwise and silently skips members
chown root:root "$TREE"
mkdir -p "$REPO/build"
tar -C "$TREE" -cf "$OUT" --numeric-owner .
ls -l "$OUT"
sha256sum "$OUT"
