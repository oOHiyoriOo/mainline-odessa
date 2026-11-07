#!/bin/sh
# Snapshot a running odessa rootfs (read-only) into a tar.
#
# NEVER sanitize on the live system: deleting the dropbear host key while
# dropbear runs breaks every new SSH session (TCP accepts, then the server
# closes without a banner). Snapshot raw and run sanitize-rootfs.sh on the
# host copy.
#
#   DEV=172.16.42.1 KEY=~/.ssh/id_ed25519 ./rootfs/snapshot-rootfs.sh
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
DEV=${DEV:-172.16.42.1}
KEY=${KEY:-$HOME/.ssh/id_ed25519}
OUT=${OUT:-$REPO/build/rootfs-snapshot.tar}
SSH="ssh -i $KEY -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"

mkdir -p "$REPO/build"
echo "== snapshot from $DEV"
# --ignore-failed-read: 26.04 is usr-merged and has no /lib64
$SSH root@"$DEV" 'tar --one-file-system --ignore-failed-read \
    --exclude=var/log/* --exclude=var/cache/* --exclude=var/tmp/* \
    --exclude=var/lib/systemd/random-seed \
    -C / -cf - bin boot etc home lib lib64 media opt root sbin srv usr var' > "$OUT"

echo "== snapshot: $(du -h "$OUT" | cut -f1) $OUT"
tar tf "$OUT" >/dev/null
echo "== tar ok"
