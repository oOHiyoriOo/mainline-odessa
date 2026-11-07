# Flash and first boot

## Prerequisites

- Moto G9 Plus XT2087-2 (`odessa`), unlocked bootloader
  (`fastboot getvar securestate` -> `flashing_unlocked`)
- fastboot/adb on the host, USB cable
- The device must be in bootloader mode (`adb reboot bootloader`)

## What gets written

| Partition | Content | Touched |
|---|---|---|
| `boot_b` (`/dev/sdf21`) | U-Boot chainload + FIT | yes |
| `userdata` (`/dev/sdb24`) | ext4 rootfs, written by the boot image | yes (wiped) |
| `boot_a` (`/dev/sde21`) | stock Android | no |
| `dtbo_a/b` | stock | no |

The Motorola bootloader refuses `fastboot flash userdata` and
`fastboot flash super`. That is why the rootfs is embedded in the boot image
and written by the initramfs on first boot.

## Flash

```bash
cd odessa-linux-6.12
./flash-odessa.sh
```

The script prints the image hash, requires `yes`, then runs:

```bash
fastboot erase userdata
fastboot flash boot_b artifacts/odessa-6.12-boot.img
fastboot set_active b
fastboot reboot
```

The image is 62.27 MiB and fits the 64 MiB boot partition (2.43 MB reserve).

## First boot

Watch the display:

```
[init] self-install: writing embedded rootfs to /dev/sdb24
[init] self-install: rootfs written
[init] switching root to /dev/sdb24 (ubuntu)
```

Timing measured on the reference device: write at 4.4 s, done at 20.4 s,
switch at 21.5 s. Subsequent boots skip the install and switch at ~4.4 s.

## Host USB link

The phone exposes a CDC-NCM gadget with the static address `172.16.42.1/24`.
There is no DHCP client on the host side. Give the host interface an address
in the same subnet, e.g.:

```bash
sudo ip addr add 172.16.42.13/24 dev <usb-iface>
ssh -i ~/.ssh/id_ed25519 root@172.16.42.1
```

`<usb-iface>` is usually `enx...` (MAC `a6:00:00:00:00:02` on the device).

## Verify

```bash
ssh -i ~/.ssh/id_ed25519 root@172.16.42.1 '
  cat /proc/1/comm                        # systemd
  cat /etc/os-release | head -2           # Ubuntu 26.04.1 LTS
  systemctl is-system-running             # running
  systemctl --failed                      # 0 loaded units listed
  df -h /                                 # 107G, /dev/sdb24
  ip -o addr show usb0                    # 172.16.42.1/24
'
```

## Key replacement

The shipped rootfs contains the build public key in
`/root/.ssh/authorized_keys` (Dropbear runs key-only). Replace it with your
own key before using the image on a foreign device:

```bash
cat > /root/.ssh/authorized_keys <<'EOF'
ssh-ed25519 AAAA... you@host
EOF
chmod 600 /root/.ssh/authorized_keys
```

The initramfs (emergency SSH before the rootfs is ready) also contains this
key; rebuild `boot.img` with `AUTHKEY=...` to change it:
`make initramfs fit bootimg`.

## Recovery

The bootloader is never locked out by this release.

- Rootfs broken but boot image fine: boot the device, the initramfs runs
  dropbear; SSH in and re-run the install
  (`rootfs/install-to-device.sh --yes`).
- Boot image broken: in bootloader mode flash the image again, or
  `fastboot boot artifacts/odessa-6.12-boot.img` for a RAM-only test.
- `fastboot erase userdata` is always available and the boot image reinstalls
  the rootfs on the next boot.

Do **not** flash `boot_a` or the `dtbo` partitions during normal operation.

## Note on `androidboot.slot_suffix`

The kernel command line may report `androidboot.slot_suffix=_a` even though
the image was flashed to `boot_b`. The value is inherited from the merged
stock DTB (the ABL bootargs), not an indication of the booted slot.
