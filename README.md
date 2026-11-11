# Ubuntu 26.04 on the Moto G9 Plus (`odessa`, SM6150)

Mainline Linux 6.12 booted through U-Boot chainload, with a self-installing
Ubuntu 26.04.1 rootfs and systemd 259. Validated end-to-end on a Moto G9 Plus
XT2087-2 on 2026-11-07; Wi-Fi 2026-11-10, Bluetooth 2026-11-11.

```
ABL -> boot_b (U-Boot chainload) -> FIT (Linux 6.12 + DTB + initramfs)
    -> USB-NCM / Dropbear -> UFS -> self-install to userdata -> systemd 259
```

## What works

| Area | State |
|---|---|
| Kernel | mainline 6.12.0 + `gcc-sdmmagpie` clock driver + QUSB2 reset fix |
| Interrupts | mainline PDC (`qcom,pdc`), 0 IRQ-type warnings |
| Regulators | 31 PM6150/PM6150L regulators registered; UFS on fixed rails |
| Storage | UFS, root on `/dev/sdb24` (userdata), growfs to 107 G |
| USB | DWC3/QUSB2 gadget, NCM, `usb0` 172.16.42.1/24, Dropbear SSH |
| Userspace | Ubuntu 26.04.1 LTS, systemd 259.9, dbus, iproute2 |
| Battery | 40-60% charge guard, PM6150 charge control (0x1042[0]) |
| Screen | boot console visible, then WLED backlight off (true off) |
| Status LED | PM6150L TRILED (`qcom-spmi-lpg`), front LED on channel 1, `heartbeat` trigger |
| Modem | `remoteproc0` = `4080000.qcom,mss` (`qcom,sm6150-mpss-pas`), runs stably (SMEM `mmi_unit_info` v3 via `wlan/modules/mmi_unit_info.c`), GLINK/IPCRTR up, QRTR works, `rmtfs` + `pd-mapper` active |
| Bluetooth | WCN3990 over GENI SE3 (`qcom,geni-uart` + serdev), FIFO mode (this vendor DTB has no QUP DMA path): `hci0` up, scan, SSP pairing/bond (verified 2026-11-11 on a fresh install); firmware `qca/crbtfw21.tlv`+`crnv21.bin`, BD address from the DTS, BlueZ 5.85 in the image; `bt-stack`/`bt-addr`/`bt-agent` units, see `docs/HARDWARE.md` |
| Wi-Fi | WCN3990 / `ath10k_snoc`: `wlan0` up, scan, WPA2-PSK association, DHCP (verified on a clean install 2026-11-10); needs `kernel/patches/0004-0006`, the firmware feature bit, the SMMU bypass, the modem userspace debs and the self-built `pd-mapper` — all shipped via `wlan/` (`docs/BUILD.md` §7) |
| Containers | Docker Engine 28.5.1 (static, `extras/docker/`): overlay2, cgroup systemd, bridge/NAT via the bundled `iptables`/`libnftnl` debs and the CA bundle for registry TLS; `docker run alpine` verified on a clean install 2026-11-11 |
| Boot | `systemctl is-system-running` = running, 0 failed units |

Out of scope / blocked: camera, DSI panel, GPU, suspend/PM. Wi-Fi is
functional since 2026-11-10 (see the Wi-Fi row above).

## Flash

Prerequisites: unlocked bootloader, `fastboot` on the host, USB cable.

```bash
cd odessa-linux-6.12
./flash-odessa.sh
# or manually:
fastboot erase userdata
fastboot flash boot_b artifacts/odessa-6.12-boot.img
fastboot set_active b
fastboot reboot
```

`boot_a` and `dtbo_a/b` stay untouched. The image writes the rootfs to
`userdata` on first boot (the Motorola bootloader refuses
`fastboot flash userdata`); the display shows:

```
[init] self-install: writing embedded rootfs to /dev/sdb24
[init] self-install: rootfs written
[init] switching root to /dev/sdb24 (ubuntu)
```

First boot takes ~1-2 minutes; later boots switch after ~4 s.

Then, from the host (the USB link has no DHCP; configure `172.16.42.13/24` on
your USB interface if needed):

```bash
ssh -i ~/.ssh/id_ed25519 root@172.16.42.1
```

**The shipped image contains the build key** in
`root/.ssh/authorized_keys` (public key only). Replace it before using the
image on a device that is not yours:

```bash
# on the device
cat > /root/.ssh/authorized_keys <<'EOF'
ssh-ed25519 AAAA... your-key
EOF
```

## Repository layout

```
artifacts/           build inputs (small) + build outputs (git-ignored)
  odessa-6.12.dtb        ABL-merged DTB used in the FIT          [tracked]
  u-boot.bin             U-Boot chainloader (boot.img "kernel")  [tracked]
  stock-boot.dtb         stock boot DTB (boot.img header field)  [tracked]
  Image-6.12.gz          kernel used in the FIT        \
  odessa-6.12-boot.img   ready-to-flash boot image      > build outputs,
  rootfs-install.tar.gz  rootfs payload                 /  see .gitignore
kernel/              config, patches (0001..0008), DTS source, FIT template, build scripts
wlan/                Wi-Fi (WCN3990): ath10k helper modules, systemd units,
                     firmware metadata + regdb, static iw/wpa_supplicant tools
bt/                  Bluetooth (WCN3990): stack modules, firmware, bt-load/set-addr/agent
                     scripts and the bt-stack/bt-addr/bt-agent units
uboot/               board files, f_acm patch, build/pack scripts
initramfs/           init script, build script, static aarch64 tools
rootfs/              base tarball, systemd debs, install/sanitize/snapshot
tools/host/          mkimage, dtc, mkbootimg (host-side packing)
docs/                build, flash, verification, hardware, limits, history
```

The large files in `artifacts/` are **build outputs** and are not tracked by
Git (GitHub rejects blobs of 100 MB and up; the rootfs payload alone is
~120 MB). They are attached to the GitHub release, or rebuilt with
`docs/BUILD.md`. `make check` verifies whichever of them are present.

Everything needed to rebuild
the boot image offline is in `kernel/`, `uboot/`, `initramfs/` and
`tools/host/`; only the kernel and U-Boot *source trees* are fetched (pinned
versions, SHA256 for the kernel tarball).

## Verify the shipped artifacts

```bash
make check
```

## Rebuild

```bash
cp config.env.example config.env
mkdir -p config && cp ~/.ssh/id_ed25519.pub config/authorized_keys.pub
. ./config.env

make initramfs      # initramfs from payload + static tools
make fit            # kernel + DTB + initramfs -> FIT
make bootimg        # U-Boot + FIT + stock DTB -> boot.img (size-checked)
make rootfs-img     # ext4 image from the payload (sudo)
make simg           # Android sparse image
```

Kernel and U-Boot sources are optional rebuilds:

```bash
TARBALL=/path/to/linux-6.12.tar.xz ./kernel/build-kernel.sh
SRC=/path/to/u-boot-2026.10        ./uboot/build-uboot.sh
```

The kernel patch is `kernel/patches/0001-odessa-sm6150-support.patch`
(gcc-sdmmagpie, QUSB2 optional reset, odessa DTS). The U-Boot change is
`uboot/patches/0001-f_acm-nonblocking.patch` (do not block boot until the host
opens the ACM port).

## Hardware facts

- SoC: Qualcomm SM6150 / Snapdragon 675 (`sdmmagpie`), 4 GB RAM
- Device: Motorola Moto G9 Plus XT2087-2, bootloader
  `MBM-3.0-odessa_retail-e69c40c38d6-220818`
- `userdata` = `/dev/sdb24` (107 GiB ext4 after growfs)
- `boot_a` = `/dev/sde21`, `boot_b` = `/dev/sdf21`
- `dtbo_a/b` = `/dev/sde23` / `/dev/sdf23` (stock, untouched)
- Bootloader policy: `fastboot flash boot_b` allowed, `flash userdata` and
  `flash super` refused; Linux writes userdata itself

## Known limitations

- UFS stays on fixed rails: the RPMh consumer enable hangs in the TCS wait
  (`L-REG-02`). No practical impact on this use case.
- Monolithic kernel: no `/lib/modules`; `systemd-modules-load` is inactive by
  design. `/dev` is devtmpfs (no udev package).
- No network beyond the point-to-point USB link: no default route, no NAT, no
  DNS unless the host provides it. The system clock starts at the image build
  time (no NTP); set it manually or add a time source.
- The DTB is derived from the stock ABL DTB/DTBO of this firmware
  (`...e69c40c38d6-220818`). A different firmware or panel may need a new
  merge (`kernel/dts/abl-merged-gcc.dts` is the source of the shipped DTB).
- No user accounts besides root; console login is not set up for a password.
  Access is SSH with the authorized key.

## Documentation

- `docs/FLASH.md` — flash, first boot, recovery, fallback
- `docs/BUILD.md` — full rebuild from sources
- `docs/VERIFICATION.md` — measured evidence of the validated release
- `docs/HARDWARE.md` — boot chain, partitions, device tree
- `docs/KNOWN-LIMITATIONS.md` — limitations and their causes
- `docs/history/` — full reverse-engineering run log (status, artifacts,
  dead ends, leads, runbook)

## Licensing

Kernel and U-Boot are GPL-2.0 (patches and board files included). BusyBox is
GPL-2.0, Dropbear is MIT, e2fsprogs is GPL-2.0/LGPL-2.1, mkbootimg.py is
Apache-2.0. The Ubuntu base rootfs contains packages under their respective
licenses (copyright files are inside the payload). See `NOTICE.md`.
