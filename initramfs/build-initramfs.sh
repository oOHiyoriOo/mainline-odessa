#!/bin/bash
# Build the odessa initramfs (BusyBox + NCM + DHCP + Dropbear + e2fsprogs).
#
# Self-contained: uses only the static aarch64 tools in initramfs/tools/ and
# the rootfs payload in artifacts/. No host packages besides a shell, gzip
# and either cpio or bsdtar.
#
#   AUTHKEY=~/.ssh/id_ed25519.pub ./initramfs/build-initramfs.sh
#
# The public key is compiled into the initramfs for emergency SSH access and
# into the rootfs by prepare-rootfs.sh. Replace it for your own device.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
TOOLS=${TOOLS:-$REPO/initramfs/tools}
AUTHKEY=${AUTHKEY:-$REPO/config/authorized_keys.pub}
BUILD=${BUILD:-$REPO/build}
# The rootfs payload cannot ride inside the release boot image: it is ~124 MB
# and boot_b is a 64 MiB partition, so the initramfs stays payload-less by
# default and the rootfs is installed by flash-odessa.sh.  Set PAYLOAD=...
# explicitly only for a target with a bigger boot partition.
PAYLOAD=${PAYLOAD:-}

BB="$TOOLS/busybox"
DROPBEAR="$TOOLS/dropbear"
DROPBEARKEY="$TOOLS/dropbearkey"

[ -x "$BB" ]       || { echo "missing $BB" >&2; exit 1; }
[ -x "$DROPBEAR" ] || { echo "missing $DROPBEAR" >&2; exit 1; }
[ -f "$AUTHKEY" ]  || { echo "missing public key: $AUTHKEY (set AUTHKEY=...)" >&2; exit 1; }

IR="$BUILD/initramfs"
rm -rf "$IR"
mkdir -p "$IR"/{bin,sbin,dev,proc,sys,tmp,run,etc/dropbear,root/.ssh,var/lib/misc,var/log}
mkdir -p "$BUILD"

cp "$BB" "$IR/bin/busybox"; chmod 755 "$IR/bin/busybox"
for a in sh ash mount umount mknod mkdir ls cat chmod chown sleep ip telnetd \
         udhcpd udhcpc ps dmesg grep sed cut head tail uname hostname sync \
         reboot poweroff nc ping ifconfig route free df kill killall env id date mdev \
         cp mv rm ln touch printf wc sort find vi more less hexdump od xxd \
         tar gzip gunzip zcat switch_root modprobe lsmod blkid dd; do
    ln -sf ../bin/busybox "$IR/bin/$a"
done

# e2fsprogs 1.47.4 (static). mke2fs writes -O ^orphan_file: the rootfs ships
# e2fsprogs 1.46/1.47 userland where resize2fs rejects orphan_file.
for b in mke2fs tune2fs dumpe2fs; do
    install -m 755 "$TOOLS/$b" "$IR/sbin/$b"
    ln -sf "../sbin/$b" "$IR/bin/$b"
done
ln -sf mke2fs "$IR/sbin/mkfs.ext4"
ln -sf mke2fs "$IR/sbin/mkfs.ext2"

cp "$DROPBEAR"    "$IR/sbin/dropbear";    chmod 755 "$IR/sbin/dropbear"
cp "$DROPBEARKEY" "$IR/sbin/dropbearkey"; chmod 755 "$IR/sbin/dropbearkey"
ln -sf ../sbin/dropbear    "$IR/bin/dropbear"
ln -sf ../sbin/dropbearkey "$IR/bin/dropbearkey"

install -m 600 "$AUTHKEY" "$IR/root/.ssh/authorized_keys"
chmod 700 "$IR/root/.ssh" "$IR/etc/dropbear" "$IR/root"

cp "$REPO/initramfs/init" "$IR/init"; chmod 755 "$IR/init"

# optional self-install payload: the release boot image writes it to userdata
if [ -n "$PAYLOAD" ] && [ -f "$PAYLOAD" ]; then
    cp "$PAYLOAD" "$IR/rootfs.tar.gz"
    echo "payload: $(du -h "$PAYLOAD" | cut -f1)"
fi

printf '%s\n' "odessa 6.12" > "$IR/etc/issue"
printf '%s\n' "root:x:0:0:root:/root:/bin/sh" > "$IR/etc/passwd"
printf '%s\n' "root:x:0:"                     > "$IR/etc/group"
printf '%s\n' "root:*:19000:0:99999:7:::"     > "$IR/etc/shadow"
chmod 600 "$IR/etc/shadow"

echo "== initramfs tree: $(du -sh "$IR" | cut -f1)"
if command -v cpio >/dev/null 2>&1; then
    ( cd "$IR" && find . -print0 | cpio --null -o -H newc --owner=0:0 --quiet ) \
      | gzip -9 > "$BUILD/initramfs.cpio.gz"
elif command -v bsdtar >/dev/null 2>&1; then
    ( cd "$IR" && bsdtar --format=newc --uid 0 --gid 0 -cf - . ) \
      | gzip -9 > "$BUILD/initramfs.cpio.gz"
else
    echo "need cpio or bsdtar" >&2; exit 1
fi
gzip -t "$BUILD/initramfs.cpio.gz"
ls -l "$BUILD/initramfs.cpio.gz"
sha256sum "$BUILD/initramfs.cpio.gz"
