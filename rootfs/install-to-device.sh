#!/bin/bash
# install-to-device.sh — write an Ubuntu rootfs tarball onto the phone's
# userdata partition (sdb24), from the *prep* initramfs.
#
# DESTRUCTIVE: erases /dev/sdb24 (userdata). Requires the device to be booted
# into the prep image (ramdisk), NOT into the installed Ubuntu.
#
# By default the arm64 systemd package bundle in rootfs/debs/ is
# pre-installed into the freshly extracted rootfs (native chroot on the
# device), so the deployed image boots systemd from the first start.
#
# Usage:
#   ./rootfs/install-to-device.sh [rootfs.tar] [--yes] [--no-systemd] [--part /dev/sdb24]
#
# Env:
#   DEV=172.16.42.1        device IP on the USB link
#   KEY=.../id_ed25519     ssh key
#
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$SCRIPT_DIR/.." && pwd)

PART=/dev/sdb24
ASSUME_YES=0
WITH_SYSTEMD=1
TARBALL=${TARBALL:-$REPO/build/rootfs.tar}
while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y) ASSUME_YES=1; shift ;;
        --no-systemd) WITH_SYSTEMD=0; shift ;;
        --part) PART="$2"; shift 2 ;;
        -*) echo "unknown option: $1" >&2; exit 2 ;;
        *) TARBALL="$1"; shift ;;
    esac
done

[ -n "$TARBALL" ] && [ -f "$TARBALL" ] || { echo "usage: $0 <rootfs.tar> [--yes] [--no-systemd] [--part /dev/sdb24]" >&2; exit 2; }

# arm64 systemd package bundle (pre-installed into the image below)
DEBS_TAR=${DEBS_TAR:-$REPO/rootfs/debs/systemd-debs-2604.tar}

DEV=${DEV:-172.16.42.1}
KEY=${KEY:-$HOME/.ssh/id_ed25519}
SSH="ssh -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"

echo "== target: $DEV $PART"
$SSH root@"$DEV" "true" || { echo "ERROR: device not reachable at $DEV (prep image booted? ssh key ok?)" >&2; exit 1; }

# --- safety checks ----------------------------------------------------------
$SSH root@"$DEV" "test -b $PART" || { echo "ERROR: $PART not present" >&2; exit 1; }
# a leftover probe mount (read-only) is fine to unmount; a mount as / means we
# are running from the very filesystem we would destroy
if $SSH root@"$DEV" "grep -q '^$PART / ' /proc/mounts"; then
    echo "ERROR: $PART is mounted as / — boot the prep initramfs first." >&2
    exit 1
fi
if $SSH root@"$DEV" "grep -q '^$PART ' /proc/mounts"; then
    echo "== $PART is mounted, unmounting"
    $SSH root@"$DEV" "umount /mnt 2>/dev/null; umount $PART 2>/dev/null; true"
fi
if $SSH root@"$DEV" "grep -q '^$PART ' /proc/mounts"; then
    echo "ERROR: $PART still mounted on the device" >&2
    exit 1
fi
SIZE=$($SSH root@"$DEV" "blockdev --getsize64 $PART")
echo "== partition size: $SIZE bytes"
[ "$SIZE" -gt 1000000000 ] || { echo "ERROR: partition suspiciously small" >&2; exit 1; }

if [ "$ASSUME_YES" -ne 1 ]; then
    echo
    echo "This will DESTROY all data on $PART ($((SIZE/1024/1024/1024)) GiB)."
    printf "Type 'yes' to continue: "
    read -r ans
    [ "$ans" = "yes" ] || { echo "aborted."; exit 1; }
fi

# --- format + install -------------------------------------------------------
echo "== mke2fs"
$SSH root@"$DEV" "/sbin/mke2fs -t ext4 -F -O ^orphan_file -L odessa-root $PART"

echo "== mount"
$SSH root@"$DEV" "mkdir -p /mnt && mount $PART /mnt"

echo "== transfer rootfs ($(du -h "$TARBALL" | cut -f1))"
# copy first, then extract locally: streaming a decompressed tar over the USB
# link is fragile on large payloads (tar: short read)
$SSH root@"$DEV" "rm -f /mnt/.odessa-payload"
cat "$TARBALL" | $SSH root@"$DEV" "cat > /mnt/.odessa-payload"
case "$TARBALL" in
    *.gz|*.tgz)
        $SSH root@"$DEV" "gunzip -c /mnt/.odessa-payload | tar -x -C /mnt -f -"
        ;;
    *)
        $SSH root@"$DEV" "tar -x -C /mnt -f /mnt/.odessa-payload"
        ;;
esac
$SSH root@"$DEV" "rm -f /mnt/.odessa-payload"
# root entry must be root-owned (see build-rootfs.sh); otherwise dpkg/tar
# refuses unsafe path transitions and silently skips package members
$SSH root@"$DEV" "chown root:root /mnt"

# --- systemd pre-install (native arm64, inside the target rootfs) -----------
# Runs the real maintainer scripts so the deployed image is a systemd system
# from the first boot on. No qemu/chroot on the host needed: the device is
# arm64 and busybox provides chroot.
# real systemd is an ELF binary; a shell script here is a bring-up stub and
# must be replaced by the packaged systemd
if [ "$WITH_SYSTEMD" -eq 1 ] && $SSH root@"$DEV" "head -c 4 /mnt/usr/lib/systemd/systemd 2>/dev/null | grep -q ELF"; then
    # the 26.04 release tarball already contains a configured systemd
    echo "== systemd already present in rootfs.tar, skipping deb pre-install"
elif [ "$WITH_SYSTEMD" -eq 1 ]; then
    [ -f "$DEBS_TAR" ] || { echo "ERROR: $DEBS_TAR missing (use --no-systemd to skip)" >&2; exit 1; }
    echo "== pre-install systemd ($(du -h "$DEBS_TAR" | cut -f1))"
    cat "$DEBS_TAR" | $SSH root@"$DEV" "mkdir -p /mnt/tmp/debs && tar -x -C /mnt/tmp/debs -f -"
    # maintainer scripts (systemd-sysusers/tmpfiles, dbus) need /proc and /sys
    $SSH root@"$DEV" "mkdir -p /mnt/dev /mnt/proc /mnt/sys; mount --bind /dev /mnt/dev 2>/dev/null; mount --bind /proc /mnt/proc 2>/dev/null; mount --bind /sys /mnt/sys 2>/dev/null; true"
    $SSH root@"$DEV" "test -c /mnt/dev/null" || {
        echo "ERROR: /dev not available in the target chroot" >&2
        exit 9
    }
    # dpkg ordering matters: systemd pre-depends on libsystemd-shared (must be
    # configured first) and systemd-sysv pre-depends on systemd. Unpacking all
    # debs in one transaction fails, so install libsystemd-shared first, then
    # systemd, then systemd-sysv.
    $SSH root@"$DEV" "busybox chroot /mnt /bin/sh -c '
        mkdir -p /tmp/debs-sysv /tmp/debs-main
        mv /tmp/debs/systemd-sysv_*.deb /tmp/debs-sysv/ 2>/dev/null || true
        mv /tmp/debs/systemd_*.deb /tmp/debs-main/ 2>/dev/null || true
        dpkg --unpack /tmp/debs/*.deb || exit 1
        # dbus-system-bus-common needs adduser|systemd-sysusers, provided by
        # the systemd package that is installed in the second stage; errors
        # here are expected and re-checked by the final dpkg --audit.
        dpkg --configure -a || true
        if ls /tmp/debs-main/*.deb >/dev/null 2>&1; then
            dpkg --unpack /tmp/debs-main/*.deb || exit 3
            dpkg --configure -a || true
        fi
        if ls /tmp/debs-sysv/*.deb >/dev/null 2>&1; then
            dpkg --unpack /tmp/debs-sysv/*.deb || exit 5
            dpkg --configure -a || true
        fi
        dpkg --audit > /tmp/dpkg-audit.txt 2>&1 || exit 7
        if [ -s /tmp/dpkg-audit.txt ]; then cat /tmp/dpkg-audit.txt; exit 7; fi
        test -L /sbin/init || exit 8
    '"
    $SSH root@"$DEV" "umount /mnt/proc /mnt/sys /mnt/dev 2>/dev/null; true"
    $SSH root@"$DEV" "rm -rf /mnt/tmp/debs /mnt/tmp/debs-main /mnt/tmp/debs-sysv"
    $SSH root@"$DEV" "test -L /mnt/sbin/init || { echo 'ERROR: /sbin/init is not a symlink' >&2; exit 1; }; readlink /mnt/sbin/init"
    # systemd remounts / from fstab; give it the root entry (filesystem label
    # is set by mke2fs above)
    $SSH root@"$DEV" "grep -q '^LABEL=odessa-root' /mnt/etc/fstab || echo 'LABEL=odessa-root / ext4 defaults 0 1' >> /mnt/etc/fstab"
fi

# the systemd package drops a dangling modules-load link into images without
# /etc/modules; this kernel is monolithic apart from three helper modules
$SSH root@"$DEV" "rm -f /mnt/etc/modules-load.d/modules.conf 2>/dev/null; true"

echo "== finalize"
$SSH root@"$DEV" "touch /mnt/etc/odessa-ready && sync && du -sh /mnt && umount /mnt && echo INSTALL_OK"

echo
echo "Done. Now boot the ubuntu image (cmdline contains odessa.boot=ubuntu)."
