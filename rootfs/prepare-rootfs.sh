#!/bin/bash
# Configure the Ubuntu 22.04 arm64 rootfs for odessa (USB-only bring-up).
# Run with sudo (files must be root-owned). Idempotent.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
R=${ROOTFS_DIR:-$REPO/build/rootfs-tree}
TOOLS=${TOOLS:-$REPO/initramfs/tools}
PUB=${AUTHKEY:-$REPO/config/authorized_keys.pub}
BB="$TOOLS/busybox"

[ -f "$PUB" ] || { echo "missing public key: $PUB (set AUTHKEY=...)" >&2; exit 1; }

[ -d "$R/etc" ] || { echo "rootfs missing: $R" >&2; exit 1; }

# --- identity ---------------------------------------------------------------
echo odessa > "$R/etc/hostname"
cat > "$R/etc/hosts" <<'EOF'
127.0.0.1   localhost odessa
::1         localhost ip6-localhost ip6-loopback
172.16.42.1 odessa
EOF
if [ ! -s "$R/etc/machine-id" ]; then
    head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$R/etc/machine-id"
fi
chmod 444 "$R/etc/machine-id"

cat > "$R/etc/resolv.conf" <<'EOF'
nameserver 1.1.1.1
nameserver 9.9.9.9
EOF

# --- static busybox (proven toolkit: ip, udhcpd, tar, ...) -----------------
install -m 755 "$BB" "$R/usr/local/bin/busybox"

# --- ssh (dropbear, static, key-only) --------------------------------------
install -d -m 700 "$R/root/.ssh" "$R/etc/dropbear"
install -m 600 "$PUB" "$R/root/.ssh/authorized_keys"
install -m 755 "$TOOLS/dropbear"    "$R/usr/local/sbin/dropbear"
install -m 755 "$TOOLS/dropbearkey" "$R/usr/local/sbin/dropbearkey"

cat > "$R/etc/systemd/system/dropbear.service" <<'EOF'
[Unit]
Description=Dropbear SSH (USB link)
After=usb-gadget.service

[Service]
ExecStartPre=/bin/sh -c '[ -f /etc/dropbear/dropbear_ed25519_host_key ] || /usr/local/sbin/dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key'
ExecStart=/usr/local/sbin/dropbear -F -p 22 -r /etc/dropbear/dropbear_ed25519_host_key
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

# --- grow the root filesystem to the partition size ------------------------
# release images are small; after flashing (userdata or super) the ext4
# filesystem is grown online on first boot (idempotent, uses the real root dev)
cat > "$R/usr/local/sbin/odessa-growfs.sh" <<'EOF'
#!/bin/sh
dev=$(awk '$2=="/"{print $1}' /proc/mounts)
[ -n "$dev" ] || exit 0
exec /usr/sbin/resize2fs "$dev"
EOF
chmod 755 "$R/usr/local/sbin/odessa-growfs.sh"

cat > "$R/etc/systemd/system/odessa-growfs.service" <<'EOF'
[Unit]
Description=Grow the ext4 root filesystem to the partition size
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/odessa-growfs.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# --- USB NCM gadget + usb0 addressing + DHCP server ------------------------
cat > "$R/usr/local/sbin/usb-gadget.sh" <<'EOF'
#!/bin/sh
# NCM gadget + usb0 setup, using the static busybox shipped in this rootfs.
set -e
BB=/usr/local/bin/busybox

$BB mount -t configfs none /sys/kernel/config 2>/dev/null || true
G=/sys/kernel/config/usb_gadget/g1
if [ ! -d "$G" ]; then
    mkdir -p "$G"
    cd "$G"
    echo 0x1d6b > idVendor
    echo 0x0104 > idProduct
    echo 0x0100 > bcdDevice
    echo 0x0200 > bcdUSB
    mkdir -p strings/0x409
    echo "0123456789"        > strings/0x409/serialnumber
    echo "odessa"            > strings/0x409/manufacturer
    echo "odessa usb gadget" > strings/0x409/product
    mkdir -p configs/c.1/strings/0x409
    echo "ncm" > configs/c.1/strings/0x409/configuration
    echo 250   > configs/c.1/MaxPower
    mkdir -p functions/ncm.usb0
    [ -e configs/c.1/ncm.usb0 ] || ln -s functions/ncm.usb0 configs/c.1/
fi

cd "$G"
UDC=$(ls /sys/class/udc 2>/dev/null | head -n1)
[ -n "$UDC" ] || { echo "no UDC"; exit 1; }
if [ ! -s UDC ]; then echo "$UDC" > UDC; fi

i=0
while [ ! -e /sys/class/net/usb0 ] && [ $i -lt 100 ]; do i=$((i+1)); sleep 0.1; done
$BB ip link set usb0 address a6:00:00:00:00:02 2>/dev/null || true
$BB ip link set usb0 up 2>/dev/null || true
$BB ip addr add 172.16.42.1/24 dev usb0 2>/dev/null || true

cat > /etc/udhcpd.conf <<'CONF'
start 172.16.42.10
end 172.16.42.20
interface usb0
option subnet 255.255.255.0
option router 172.16.42.1
option dns 172.16.42.1
lease_file /var/lib/misc/udhcpd.leases
CONF
mkdir -p /var/lib/misc
pkill -x udhcpd 2>/dev/null || $BB pkill -x udhcpd 2>/dev/null || true
$BB udhcpd /etc/udhcpd.conf
exit 0
EOF
chmod 755 "$R/usr/local/sbin/usb-gadget.sh"

cat > "$R/etc/systemd/system/usb-gadget.service" <<'EOF'
[Unit]
Description=USB NCM gadget + usb0 (odessa)
DefaultDependencies=no
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/usb-gadget.sh
TimeoutStartSec=40

[Install]
WantedBy=sysinit.target
EOF

# --- battery charge guard (hysteresis 55/60) -------------------------------
cat > "$R/usr/local/sbin/battery-guard.sh" <<'EOF'
#!/bin/sh
# Keep the battery between 40% and 60% while on USB power.
#
# Capacity comes from the QG SDAM block (offset 0x47) via mainline nvmem;
# the fallback is the ADC5 vbat_sns channel. Charging is controlled by the
# odessa-chg driver (PM6150 CHARGING_ENABLE_CMD, 0x1042 bit 0).
CHG=$(find /sys/devices -name charge_enable 2>/dev/null | head -1)
[ -w "$CHG" ] || exit 0
N=/sys/bus/nvmem/devices/spmi_sdam0/nvmem
V=/sys/bus/iio/devices/iio:device0/in_voltage_vbat_sns_input
cap=""
[ -r "$N" ] && cap=$(dd if="$N" bs=1 skip=71 count=1 2>/dev/null | od -An -tu1 | tr -d ' ')
v=""
[ -r "$V" ] && v=$(cat "$V" 2>/dev/null)
if [ -n "$cap" ] && [ "$cap" -ge 0 ] && [ "$cap" -le 100 ]; then
    # stale QG value: 100% but the cell is clearly below full
    if [ "$cap" -eq 100 ] && [ -n "$v" ] && [ "$v" -lt 3900000 ]; then
        cap=""
    fi
fi
old=$(cat "$CHG" 2>/dev/null)
if [ -n "$cap" ]; then
    if [ "$cap" -ge 60 ]; then echo 0 > "$CHG"; fi
    if [ "$cap" -le 40 ]; then echo 1 > "$CHG"; fi
elif [ -n "$v" ]; then
    if [ "$v" -ge 4000000 ]; then echo 0 > "$CHG"; fi
    if [ "$v" -le 3650000 ]; then echo 1 > "$CHG"; fi
fi
new=$(cat "$CHG" 2>/dev/null)
[ "$old" != "$new" ] && echo "battery-guard: cap=${cap:-?} v=${v:-?} charge=$new" > /dev/kmsg
exit 0
EOF
chmod 755 "$R/usr/local/sbin/battery-guard.sh"

cat > "$R/etc/systemd/system/battery-guard.service" <<'EOF'
[Unit]
Description=Battery charge guard (55-60%)

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/battery-guard.sh
EOF

cat > "$R/etc/systemd/system/battery-guard.timer" <<'EOF'
[Unit]
Description=Run battery charge guard every 30s

[Timer]
OnBootSec=30s
OnUnitActiveSec=30s

[Install]
WantedBy=timers.target
EOF

# --- modem RFS plumbing (rmtfs / tqftpserv) --------------------------------
# The odessa rootfs has no udev, so the by-partlabel links and the RFS
# bind mounts have to be created by hand.  Both scripts are idempotent and
# run as ExecStartPre of rmtfs/tqftpserv (see the drop-ins below).
cat > "$R/usr/local/sbin/odessa-partlabels" <<'EOF'
#!/bin/sh
# Populate /dev/disk/by-partlabel for rmtfs -P.
#
# The odessa release rootfs deliberately has no udev, so the by-partlabel
# symlinks normally created by udev are missing.  rmtfs resolves the modem's
# /boot/modem_fs* requests through /dev/disk/by-partlabel/<partlabel>.
set -eu

mkdir -p /dev/disk/by-partlabel

for disk in /dev/sd?; do
	[ -b "$disk" ] || continue
	partx -s -o NR,NAME "$disk" 2>/dev/null | while read -r nr name; do
		case "$nr" in
		''|NR) continue ;;
		esac
		[ -n "${name:-}" ] || continue
		ln -sfn "../../$(basename "$disk")$nr" "/dev/disk/by-partlabel/$name"
	done
done

# rmtfs's generic table asks for the unslotted name 'fsg'; odessa only has
# fsg_a/fsg_b.  Slot a is the original stock slot.
if [ -e /dev/disk/by-partlabel/fsg_a ]; then
	ln -sfn fsg_a /dev/disk/by-partlabel/fsg
elif [ -e /dev/disk/by-partlabel/fsg_b ]; then
	ln -sfn fsg_b /dev/disk/by-partlabel/fsg
fi

# odessa has no 'tunning' partition.  Back it with an empty file so a modem
# request does not fail (rmtfs -r serves it from a RAM shadow buffer).
if [ ! -e /dev/disk/by-partlabel/tunning ]; then
	mkdir -p /var/lib/rmtfs
	if [ ! -f /var/lib/rmtfs/tunning ]; then
		truncate -s 2M /var/lib/rmtfs/tunning
	fi
	ln -sfn /var/lib/rmtfs/tunning /dev/disk/by-partlabel/tunning
fi
EOF
chmod 755 "$R/usr/local/sbin/odessa-partlabels"

cat > "$R/usr/local/sbin/odessa-rfs-links" <<'EOF'
#!/bin/sh
# Wire the modem RFS files into the places where tqftpserv looks for them.
#
# tqftpserv resolves
#   /readonly/firmware/image/<file>  ->  /lib/firmware/<file>
#   /readwrite/<file>                ->  /tmp/tqftpserv/<file>
#
# The modem's RFS files live in the persist partition, which the release
# rootfs does not mount and which is not reachable through udev (no udev).
set -eu

/usr/local/sbin/odessa-partlabels

mkdir -p /persist
if ! grep -q " /persist " /proc/mounts; then
	mount -o ro /dev/disk/by-partlabel/persist /persist
fi

# Read-only firmware requests: expose the RFS tree through /lib/firmware.
for entry in /persist/rfs/msm/mpss/*; do
	[ -e "$entry" ] || continue
	ln -sfn "$entry" "/lib/firmware/$(basename "$entry")"
done

# Read-write requests: tqftpserv uses the compile-time /tmp/tqftpserv, which
# is tmpfs.  Back it with a persistent directory on the root filesystem and
# seed it (without clobbering the modem's own writes) from persist.
mkdir -p /var/lib/tqftpserv /tmp/tqftpserv
cp -an /persist/rfs/msm/mpss/. /var/lib/tqftpserv/ 2>/dev/null || true

# odessa has no persisted ota_firewall/ruleset (the modem normally finds it
# in the vendor's /data/vendor/tmp/tqftpserv); provide an empty ruleset so the
# open succeeds instead of failing with ENOENT.
if [ ! -e /var/lib/tqftpserv/ota_firewall/ruleset ]; then
	mkdir -p /var/lib/tqftpserv/ota_firewall
	: > /var/lib/tqftpserv/ota_firewall/ruleset
fi
if ! grep -q " /tmp/tqftpserv " /proc/mounts; then
	cp -an /tmp/tqftpserv/. /var/lib/tqftpserv/ 2>/dev/null || true
	mount --bind /var/lib/tqftpserv /tmp/tqftpserv
fi
EOF
chmod 755 "$R/usr/local/sbin/odessa-rfs-links"

# Seed the file-backed rmtfs storage from the real calibration partitions.
# The modem expects /boot/modem_fs1|fs2|fsc|fsg; rmtfs -o serves them from
# files, so the modem's writes never touch modemst1/2, fsc or fsg.
cat > "$R/usr/local/sbin/odessa-rmtfs-efs" <<'EOF'
#!/bin/sh
# Create the file-backed rmtfs storage tree (idempotent).
set -eu

D=/var/lib/rmtfs-efs
mkdir -p "$D"

seed() {
	src=$1
	dst=$2
	[ -e "$D/$dst" ] && return 0
	[ -b "$src" ] || return 0
	if dd if="$src" of="$D/$dst.tmp" bs=1M 2>/dev/null; then
		mv "$D/$dst.tmp" "$D/$dst"
	fi
}

seed /dev/disk/by-partlabel/modemst1 modem_fs1
seed /dev/disk/by-partlabel/modemst2 modem_fs2
seed /dev/disk/by-partlabel/fsc       modem_fsc

# fsg is *not* a raw modem image: the partition is a small ext4 filesystem
# that Android mounts at /vendor/fsg and that holds the factory FSG as a
# gzip file (e.g. odessa_dsds_apeu.img.gz -> "IMAGEFS- SIGNED_IMAGE").
# The modem expects the decompressed image, so serving the raw ext4
# partition makes the rf image fail.
seed_fsg() {
	[ -e "$D/modem_fsg" ] && return 0
	mkdir -p /run/fsg
	if mount -o ro /dev/disk/by-partlabel/fsg /run/fsg 2>/dev/null; then
		for f in /run/fsg/odessa_dsds_apeu.img.gz /run/fsg/*.img.gz; do
			[ -f "$f" ] || continue
			if gzip -dc "$f" > "$D/modem_fsg.tmp" 2>/dev/null &&
			   [ -s "$D/modem_fsg.tmp" ]; then
				mv "$D/modem_fsg.tmp" "$D/modem_fsg"
				umount /run/fsg
				return 0
			fi
			rm -f "$D/modem_fsg.tmp"
		done
		umount /run/fsg
	fi
	# last resort: raw partition (wrong for this device, but keeps the
	# service startable if the factory image is unavailable)
	seed /dev/disk/by-partlabel/fsg modem_fsg
}
seed_fsg

if [ ! -e "$D/modem_tunning" ]; then
	dd if=/dev/zero of="$D/modem_tunning" bs=1M count=2 2>/dev/null || true
fi
EOF
chmod 755 "$R/usr/local/sbin/odessa-rmtfs-efs"

# Drop-ins for the distribution units (rmtfs/tqftpserv from Ubuntu).
mkdir -p "$R/etc/systemd/system/rmtfs.service.d" \
         "$R/etc/systemd/system/tqftpserv.service.d"

cat > "$R/etc/systemd/system/rmtfs.service.d/override.conf" <<'EOF'
[Unit]
StartLimitIntervalSec=300
StartLimitBurst=3
[Service]
Restart=on-failure
RestartSec=5
ExecStart=
ExecStart=/usr/bin/rmtfs -o /var/lib/rmtfs-efs
ExecStartPre=/usr/local/sbin/odessa-partlabels
ExecStartPre=/usr/local/sbin/odessa-rmtfs-efs
ExecStartPre=/bin/sh -c 'for i in $(seq 1 30); do [ -e /dev/qcom_rmtfs_mem1 ] && exit 0; sleep 1; done; exit 1'
EOF

cat > "$R/etc/systemd/system/tqftpserv.service.d/override.conf" <<'EOF'
[Service]
Restart=always
RestartSec=2
LimitNOFILE=65536
ExecStartPre=/usr/local/sbin/odessa-rfs-links
ExecStart=
ExecStart=/usr/bin/tqftpserv
EOF

# pd-mapper: the Ubuntu build only scans /lib/firmware/updates/<dirname>
# (dirname of /sys/class/remoteproc/*/firmware).  The PD maps must be there,
# and the service must wait for the remoteproc device, which appears ~12 s
# after boot when q6v5_pas probes.
install -d "$R/lib/firmware/updates"
if [ -f "$R/lib/firmware/modemr.jsn" ]; then
    install -m 644 "$R/lib/firmware/modemr.jsn" "$R/lib/firmware/modemuw.jsn" \
        "$R/lib/firmware/updates/"
fi
mkdir -p "$R/etc/systemd/system/pd-mapper.service.d"
cat > "$R/etc/systemd/system/pd-mapper.service.d/override.conf" <<'PDMAPPER_EOF'
[Unit]
StartLimitIntervalSec=0
[Service]
Restart=always
RestartSec=2
ExecStartPre=/bin/sh -c 'i=0; while [ $i -lt 60 ] && [ ! -e /sys/class/remoteproc/remoteproc0/firmware ]; do i=$((i+1)); sleep 1; done; exit 0'
PDMAPPER_EOF

# --- modem start (PAS) -----------------------------------------------------
# The kernel only registers the remoteproc; the MSS has to be started
# explicitly. pd-mapper must serve the PD map first (QRTR 0x45), otherwise the
# WLAN PD never appears, and the ath10k helper modules must be loaded before
# icnss probes. Without this unit wlan0 only appears after a manual
# `echo start > /sys/class/remoteproc/remoteproc0/state`.
cat > "$R/etc/systemd/system/odessa-modem.service" <<'EOF'
[Unit]
Description=Odessa modem (start the MSS remoteproc)
After=odessa-fw-provision.service pd-mapper.service rmtfs.service wlan-smmu.service wlan-rails.service mmi-unit-info.service
Wants=odessa-fw-provision.service pd-mapper.service
Before=odessa-wlan.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/sh -c 'for i in $(seq 1 90); do [ -e /sys/class/remoteproc/remoteproc0/state ] && exit 0; sleep 1; done; exit 1'
ExecStart=/bin/sh -c 'grep -q running /sys/class/remoteproc/remoteproc0/state || echo start > /sys/class/remoteproc/remoteproc0/state'
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF
ln -sfn /etc/systemd/system/odessa-modem.service \
    "$R/etc/systemd/system/multi-user.target.wants/odessa-modem.service"

# --- SSH-only console: blank the framebuffer after boot --------------------
# There is no backlight class with simpledrm, so this clears the scanout to
# black and suppresses further console output. getty@tty1 is masked because
# no keyboard is attached and its login prompt would redraw the screen.
cat > "$R/usr/local/sbin/odessa-screen-off.sh" <<'EOF'
#!/bin/sh
# Run once after boot: silence console output, turn the panel backlight off
# and clear the framebuffer.
echo 1 > /proc/sys/kernel/printk 2>/dev/null || true
systemctl log-level warning 2>/dev/null || true
systemctl log-target journal 2>/dev/null || true

# WLED quirk: the driver starts with brightness=0 while the bootloader may
# have the module enabled. Writing 0 directly does not call module_enable();
# force a non-zero -> zero transition.
B=/sys/class/backlight/backlight
if [ -w "$B/brightness" ]; then
    echo 0 > "$B/bl_power" 2>/dev/null || true
    echo 2048 > "$B/brightness" 2>/dev/null || true
    sleep 0.2
    echo 0 > "$B/brightness" 2>/dev/null || true
fi

# fallback: black out the simple-framebuffer scanout
VS=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null) || exit 0
W=${VS%,*}; H=${VS#*,}
BPP=$(cat /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null || echo 32)
[ -n "$W" ] && [ -n "$H" ] || exit 0
BYTES=$((W * H * BPP / 8))
dd if=/dev/zero of=/dev/fb0 bs=4096 count=$(( (BYTES + 4095) / 4096 )) 2>/dev/null || true
EOF
chmod 755 "$R/usr/local/sbin/odessa-screen-off.sh"

cat > "$R/etc/systemd/system/odessa-screen-off.service" <<'EOF'
[Unit]
Description=Blank the framebuffer console for SSH-only operation
After=systemd-user-sessions.service systemd-backlight@backlight:backlight.service
Before=getty@tty1.service

[Service]
Type=oneshot
# The WLED device appears with the SPMI bus; do not race it.
ExecStartPre=/bin/sh -c 'i=0; while [ $i -lt 50 ] && [ ! -e /sys/class/backlight/backlight/brightness ]; do i=$((i+1)); sleep 0.1; done; exit 0'
ExecStart=/usr/local/sbin/odessa-screen-off.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# --- enable units without systemctl ---------------------------------------
mkdir -p "$R/etc/systemd/system/sysinit.target.wants" \
         "$R/etc/systemd/system/multi-user.target.wants" \
         "$R/etc/systemd/system/timers.target.wants"
ln -sf /etc/systemd/system/usb-gadget.service  "$R/etc/systemd/system/sysinit.target.wants/usb-gadget.service"
ln -sf /etc/systemd/system/dropbear.service    "$R/etc/systemd/system/multi-user.target.wants/dropbear.service"
ln -sf /etc/systemd/system/odessa-growfs.service "$R/etc/systemd/system/multi-user.target.wants/odessa-growfs.service"
ln -sf /etc/systemd/system/battery-guard.timer "$R/etc/systemd/system/timers.target.wants/battery-guard.timer"
ln -sf /etc/systemd/system/odessa-screen-off.service "$R/etc/systemd/system/multi-user.target.wants/odessa-screen-off.service"
# local console login is not usable (no keyboard); SSH is the access path
ln -sf /dev/null "$R/etc/systemd/system/getty@tty1.service"
# systemd-backlight restores a saved brightness at boot and would undo the
# screen-off service. Mask the instance for the WLED backlight.
ln -sf /dev/null "$R/etc/systemd/system/systemd-backlight@backlight:backlight.service"
# no networkd in this rootfs; drop leftovers if a previous run added them
rm -f "$R/etc/systemd/system/multi-user.target.wants/systemd-networkd.service" \
      "$R/etc/systemd/system/sockets.target.wants/systemd-networkd.socket" 2>/dev/null || true

# --- fstab ------------------------------------------------------------------
cat > "$R/etc/fstab" <<'EOF'
# <file system> <mount point> <type> <options> <dump> <pass>
proc            /proc         proc    defaults          0 0
sysfs           /sys          sysfs   defaults          0 0
tmpfs           /tmp          tmpfs   defaults          0 0
EOF

# --- init (only for base images without any init) --------------------------
# Ubuntu Base is a container rootfs without systemd. The release payload,
# however, already contains real systemd; /usr/sbin/init is a symlink to
# /lib/systemd/systemd there, so writing to it would overwrite the systemd
# binary. Only install the bring-up init when no systemd is present.
if [ ! -e "$R/usr/lib/systemd/systemd" ]; then
cat > "$R/usr/sbin/init" <<'EOF'
#!/bin/sh
# odessa Ubuntu bring-up init (PID 1)
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BB=/usr/local/bin/busybox
[ -x "$BB" ] || BB=/bin/busybox

mount -t proc    proc    /proc 2>/dev/null
mount -t sysfs   sysfs   /sys  2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null
mkdir -p /dev/pts /dev/shm /tmp /run /var/lib/misc /var/log
mount -t devpts  devpts  /dev/pts 2>/dev/null
mount -t tmpfs   tmpfs   /dev/shm 2>/dev/null
mount -t tmpfs   tmpfs   /tmp     2>/dev/null
hostname odessa 2>/dev/null

# --- USB NCM gadget + usb0 + DHCP -----------------------------------------
/usr/local/sbin/usb-gadget.sh || echo "[init] gadget setup failed" > /dev/kmsg

# --- SSH -------------------------------------------------------------------
if [ ! -f /etc/dropbear/dropbear_ed25519_host_key ]; then
    /usr/local/sbin/dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key >/dev/null 2>&1
fi
/usr/local/sbin/dropbear -p 22 -r /etc/dropbear/dropbear_ed25519_host_key \
    && echo "[init] dropbear on :22" > /dev/kmsg

# --- battery charge guard (55/60 hysteresis) ------------------------------
(
  while :; do
    /usr/local/sbin/battery-guard.sh
    sleep 30
  done
) &

echo "[init] odessa init done" > /dev/kmsg

# PID 1: reap children, stay alive
while :; do
    sleep 3600 &
    wait $!
done
EOF
chmod 755 "$R/usr/sbin/init"
# /sbin is a symlink to usr/sbin in this image, so /sbin/init resolves automatically.
elif head -c 10 "$R/usr/lib/systemd/systemd" 2>/dev/null | grep -q '^#!/bin/sh'; then
    # a previous build overwrote the systemd binary through the
    # /usr/sbin/init symlink.  Drop the wrapper (and the now dangling init
    # symlinks) so rootfs/install-to-device.sh installs real systemd from
    # the bundled arm64 debs on the device.
    echo "removing stale bring-up init wrapper from the payload"
    rm -f "$R/lib/systemd/systemd" "$R/sbin/init" "$R/usr/sbin/init"
else
    echo "systemd present ($(head -c 4 "$R/usr/lib/systemd/systemd" | tail -c 3))"
fi

# --- vendor firmware provisioning (modem + WLAN) --------------------------
# The vendor partition is read-only and always present; expose its firmware
# through /lib/firmware before the modem is started.
install -m 755 "$REPO/rootfs/vendor/odessa-fw-provision.sh" \
    "$R/usr/local/sbin/odessa-fw-provision"
cat > "$R/etc/systemd/system/odessa-fw-provision.service" <<'FWEOF'
[Unit]
Description=Expose vendor modem/WLAN firmware through /lib/firmware
After=local-fs.target
Before=rmtfs.service pd-mapper.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/odessa-fw-provision
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
FWEOF
install -d -m 755 "$R/etc/systemd/system/multi-user.target.wants"
ln -sfn /etc/systemd/system/odessa-fw-provision.service \
    "$R/etc/systemd/system/multi-user.target.wants/odessa-fw-provision.service"

# --- Docker Engine (static binaries, no package manager needed) -----------
DOCKER_TGZ=$REPO/extras/docker/docker-28.5.1-aarch64.tgz
if [ -f "$DOCKER_TGZ" ]; then
    TMPD=$(mktemp -d)
    tar xzf "$DOCKER_TGZ" -C "$TMPD"
    install -d -m 755 "$R/usr/local/bin"
    install -m 755 "$TMPD"/docker/* "$R/usr/local/bin/"
    rm -rf "$TMPD"
    cat > "$R/etc/systemd/system/docker.service" <<'UNIT'
[Unit]
Description=Docker Engine (static)
After=network.target

[Service]
Type=notify
# bridge/NAT need iptables (packages in rootfs/debs, kernel flags are =y)
ExecStart=/usr/local/bin/dockerd
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
    install -d -m 755 "$R/etc/systemd/system/multi-user.target.wants"
    ln -sfn /etc/systemd/system/docker.service \
        "$R/etc/systemd/system/multi-user.target.wants/docker.service"
fi

# --- modem userspace (rmtfs, tqftpserv, qrtr) + pd-mapper ---------------
# The base payload has no arm64 dpkg for these; extract the bundled debs
# directly into the tree and enable their units.
for d in "$REPO"/rootfs/debs/libqrtr1_*_arm64.deb \
         "$REPO"/rootfs/debs/rmtfs_*_arm64.deb \
         "$REPO"/rootfs/debs/tqftpserv_*_arm64.deb \
         "$REPO"/rootfs/debs/qrtr-tools_*_arm64.deb \
         "$REPO"/rootfs/debs/iptables_*_arm64.deb \
         "$REPO"/rootfs/debs/libxtables*_arm64.deb \
         "$REPO"/rootfs/debs/libip4tc*_arm64.deb \
         "$REPO"/rootfs/debs/libip6tc*_arm64.deb \
         "$REPO"/rootfs/debs/libnftnl*_arm64.deb \
         "$REPO"/rootfs/debs/libmnl*_arm64.deb \
         "$REPO"/rootfs/debs/libnfnetlink*_arm64.deb \
         "$REPO"/rootfs/debs/libnetfilter-conntrack*_arm64.deb \
         "$REPO"/rootfs/debs/netbase_*_all.deb \
         "$REPO"/rootfs/debs/systemd-timesyncd_*_arm64.deb; do
    [ -f "$d" ] || continue
    dpkg-deb -x "$d" "$R"
done

# --- clock: NTP ------------------------------------------------------------
# There is no RTC driver on odessa, so the clock starts at the rootfs build
# time. apt rejects Release files that are dated in the future ("not valid
# yet") until the clock is right. systemd-timesyncd starts after the Wi-Fi
# bring-up and steps the clock as soon as the link has a default route.
if [ -x "$R/usr/lib/systemd/systemd-timesyncd" ]; then
    mkdir -p "$R/etc/systemd/system/systemd-timesyncd.service.d"
    # ordered by odessa-wlan's Before=systemd-timesyncd (no cycle: both are
    # pulled by multi-user.target)
    cat > "$R/etc/systemd/system/systemd-timesyncd.service.d/odessa.conf" <<'EOF'
[Unit]
After=network.target
Wants=network.target
EOF
    mkdir -p "$R/etc/systemd/system/multi-user.target.wants"
    ln -sfn /usr/lib/systemd/system/systemd-timesyncd.service \
        "$R/etc/systemd/system/multi-user.target.wants/systemd-timesyncd.service"
fi

# dpkg-deb -x does not run postinst/update-alternatives; wire the nft
# front-ends explicitly (docker calls plain `iptables`)
for a in iptables ip6tables; do
    if [ -e "$R/usr/sbin/$a-nft" ] && [ ! -e "$R/usr/sbin/$a" ]; then
        ln -sfn "$a-nft" "$R/usr/sbin/$a"
    fi
done
install -d -m 755 "$R/etc/systemd/system/multi-user.target.wants"
for u in rmtfs pd-mapper tqftpserv; do
    if [ -e "$R/usr/lib/systemd/system/$u.service" ]; then
        ln -sfn "/usr/lib/systemd/system/$u.service" \
            "$R/etc/systemd/system/multi-user.target.wants/$u.service"
    fi
done
# pd-mapper: the distro binary does not find the vendor maps on this system,
# ship the self-built one with a dependency-free unit (see wlan/pd-mapper)
install -m 755 "$REPO/wlan/pd-mapper/pd-mapper" "$R/usr/bin/pd-mapper"
install -m 644 "$REPO/wlan/pd-mapper/pd-mapper.service" \
    "$R/etc/systemd/system/pd-mapper.service"
ln -sfn /etc/systemd/system/pd-mapper.service \
    "$R/etc/systemd/system/multi-user.target.wants/pd-mapper.service"

# --- Wi-Fi (WCN3990/ath10k), see wlan/README.md ---------------------------
WLAN=$REPO/wlan
KREL=6.12.0
if [ -d "$WLAN" ]; then
    for m in smmu_probe wlan_rails mmi_unit_info; do
        [ -f "$WLAN/modules/$m.ko" ] || {
            echo "missing $WLAN/modules/$m.ko - run ./wlan/modules/build-modules.sh" >&2
            exit 1
        }
    done
    install -d -m 755 "$R/usr/local/sbin" "$R/lib/modules/$KREL/extra" \
        "$R/opt/re-tools" "$R/lib/firmware/ath10k/WCN3990/hw1.0"
    install -m 755 "$WLAN/tools/insmod_static" "$R/usr/local/sbin/insmod_static"
    for m in smmu_probe wlan_rails mmi_unit_info; do
        install -m 644 "$WLAN/modules/$m.ko" "$R/lib/modules/$KREL/extra/"
    done
    for t in iw wpa_supplicant wpa_cli; do
        install -m 755 "$WLAN/tools/$t" "$R/opt/re-tools/"
    done
    install -m 644 "$WLAN/firmware/firmware-5.bin" \
        "$R/lib/firmware/ath10k/WCN3990/hw1.0/firmware-5.bin"
    install -m 644 "$WLAN/firmware/board-2.bin" \
        "$R/lib/firmware/ath10k/WCN3990/hw1.0/board-2.bin"
    install -m 644 "$WLAN/firmware/regulatory.db" \
        "$WLAN/firmware/regulatory.db.p7s" "$R/lib/firmware/"
    for u in wlan-smmu wlan-rails mmi-unit-info; do
        install -m 644 "$WLAN/units/$u.service" "$R/etc/systemd/system/$u.service"
        install -d -m 755 "$R/etc/systemd/system/multi-user.target.wants"
        ln -sfn "/etc/systemd/system/$u.service" \
            "$R/etc/systemd/system/multi-user.target.wants/$u.service"
    done
    install -d -m 755 "$R/etc/wpa_supplicant"
    if [ ! -f "$R/etc/wpa_supplicant.conf" ]; then
        cat > "$R/etc/wpa_supplicant.conf" <<'WPAEOF'
ctrl_interface=/run/wpa_supplicant
update_config=1
# Add your network here, then start:
#   wpa_supplicant -Dnl80211 -i wlan0 -c /etc/wpa_supplicant.conf -B
# network={
#     ssid="SSID"
#     psk="passphrase"
#     key_mgmt=WPA-PSK
#     proto=RSN
#     pairwise=CCMP
#     group=CCMP
# }
WPAEOF
        # template only (no credentials); the user sets 0600 after adding a network
        chmod 644 "$R/etc/wpa_supplicant.conf"
    fi
    # associate + DHCP at boot (no-op until a network= block exists); the
    # DHCP hook installs address, default route and DNS from the lease
    install -m 755 "$WLAN/scripts/odessa-wlan-up.sh" \
        "$R/usr/local/sbin/odessa-wlan-up.sh"
    install -m 755 "$WLAN/scripts/odessa-udhcpc.sh" \
        "$R/usr/local/sbin/odessa-udhcpc.sh"
    install -m 644 "$WLAN/units/odessa-wlan.service" \
        "$R/etc/systemd/system/odessa-wlan.service"
    ln -sfn /etc/systemd/system/odessa-wlan.service \
        "$R/etc/systemd/system/multi-user.target.wants/odessa-wlan.service"
fi

# cloning: no fixed machine-id and no SSH host keys in the image; systemd and
# dropbear generate them per device on first boot
: > "$R/etc/machine-id" 2>/dev/null || true
rm -f "$R"/etc/dropbear/dropbear_*_host_key* 2>/dev/null || true

# 26.04 base ships /etc/modules-load.d/modules.conf -> ../modules as a dangling
# symlink. There is no /etc/modules and this kernel is monolithic (no
# /lib/modules), so systemd-modules-load fails at boot. Drop the link; the
# unit then skips via its ConditionDirectoryNotEmpty checks.
rm -f "$R/etc/modules-load.d/modules.conf" 2>/dev/null || true

echo "rootfs configured:"
ls -l "$R/usr/local/sbin/" | sed 's/^/  /'
echo "  enabled:"; find "$R/etc/systemd/system" -name '*.wants' -type d -exec ls {} \; 2>/dev/null | sed 's/^/    /'
