#!/bin/sh
# Install the static Docker Engine (v2 CLI/engine) on the device.
#
#   extras/docker/install-docker-static.sh /path/to/docker-28.5.1.tgz
#
# Bridge/NAT require the iptables userspace (packages in rootfs/debs) and the
# netfilter/bridge kernel options, which the release kernel has (=y).
set -eu
TARBALL=${1:?usage: $0 <docker-<ver>.tgz>}
[ -f "$TARBALL" ] || { echo "missing $TARBALL" >&2; exit 1; }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
tar xzf "$TARBALL" -C "$TMP"
install -m 755 "$TMP"/docker/* /usr/local/bin/

cat > /etc/systemd/system/docker.service <<'UNIT'
[Unit]
Description=Docker Engine (static)
After=network.target

[Service]
Type=notify
ExecStart=/usr/local/bin/dockerd
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now docker
sleep 5
docker version --format '{{.Server.Version}}' || systemctl status docker --no-pager | tail -5
