#!/bin/sh
# Host-side clone hygiene for an extracted Ubuntu rootfs tree.
#
#   ./rootfs/sanitize-rootfs.sh build/tree
#
# Must run as root (ownership of the tree matters for dpkg/tar).
set -eu
R=${1:?usage: sanitize-rootfs.sh <rootfs-dir>}
[ -f "$R/etc/os-release" ] || { echo "ERROR: $R does not look like a rootfs" >&2; exit 1; }

# per-device identity: systemd/dropbear regenerate on first boot
: > "$R/etc/machine-id"
chmod 444 "$R/etc/machine-id"
rm -f "$R"/etc/dropbear/dropbear_*_host_key*

# runtime state
rm -rf "$R"/var/log/* "$R"/var/log/journal
rm -rf "$R"/tmp/* "$R"/var/tmp/*
rm -f "$R"/var/cache/apt/archives/*.deb
rm -f "$R"/var/lib/systemd/random-seed
rm -f "$R"/etc/resolv.conf
rm -f "$R"/root/.bash_history "$R"/root/.wget-hsts "$R"/root/.selected_editor "$R"/root/.lesshst
rm -f "$R"/var/lib/dpkg/lock-frontend "$R"/var/lib/dpkg/lock

# 26.04 base ships this as a dangling symlink; systemd-modules-load fails on it
rm -f "$R"/etc/modules-load.d/modules.conf

# the release must self-detect as installed
touch "$R/etc/odessa-ready"

echo "sanitized $R"
du -sh "$R" | cut -f1
