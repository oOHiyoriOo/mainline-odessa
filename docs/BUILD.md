# Rebuild from source

All paths below are relative to the repository root. Host prerequisites:
`gcc`, `make`, `bison`, `flex`, `bc`, `dtc`, `cpio` (or `bsdtar`), `gzip`,
`python3`, `e2fsprogs`, `sudo`, plus an aarch64 cross toolchain for kernel and
U-Boot (`aarch64-linux-gnu-`).

## 1. Keys and environment

```bash
cp config.env.example config.env
mkdir -p config
cp ~/.ssh/id_ed25519.pub config/authorized_keys.pub
. ./config.env
```

`AUTHKEY` is baked into the initramfs and the rootfs. For a foreign device,
use that device owner's public key.

## 2. Kernel (Linux 6.12.0)

```bash
TARBALL=/path/to/linux-6.12.tar.xz ./kernel/build-kernel.sh
# or let it download the pinned tarball:
./kernel/build-kernel.sh
```

The script verifies
`sha256 b1a2562be56e42afb3f8489d4c2a7ac472ac23098f1ef1c1e40da601f54625eb`,
extracts, applies `kernel/patches/0001-odessa-sm6150-support.patch` and builds
`Image.gz` with `kernel/config-6.12-odessa` (`-j12`, `nice -n 10`).

Patch contents:

- `drivers/clk/qcom/gcc-sdmmagpie.c` + dt-bindings header + Kconfig/Makefile:
  SM6150 global clock controller (clock IDs from the vendor tree)
- `drivers/phy/qualcomm/phy-qcom-qusb2.c`: tolerate a missing PHY core reset
  (`devm_reset_control_get_optional_exclusive`)
- `arch/arm64/boot/dts/qcom/sm6150-moto-odessa.dts` (bring-up DTS, not used at
  runtime; the runtime DTB is passed by the FIT)

## 3. Initramfs

```bash
make initramfs
```

Uses only `initramfs/tools/` (static aarch64 busybox, dropbear, e2fsprogs) and
`artifacts/rootfs-install.tar.gz`. The self-install block formats with
`mke2fs -O ^orphan_file` and unpacks `rootfs.tar.gz`.

## 4. FIT

```bash
make fit
```

`kernel/fit-6.12.its.in` is rendered with the actual paths and packed with
`tools/host/mkimage`. Configuration: kernel `Image.gz` at `0x90000000`, DTB at
`0x8F000000`, ramdisk at `0xA0000000`, bootargs
`console=tty0 loglevel=4 ... odessa.boot=ubuntu`.

## 5. Boot image

```bash
make bootimg
```

`uboot/pack-bootimg.sh` wraps `u-boot.bin` as kernel, the FIT as ramdisk and
`stock-boot.dtb` as the header DTB using `tools/host/mkbootimg.py`, then
refuses images larger than 64 MiB.

## 6. Rootfs

The release payload is the sanitized snapshot of the validated device rootfs:

```bash
make rootfs-tar          # build/rootfs.tar
make rootfs-img          # build/rootfs.img (2 GiB ext4, sudo)
make simg                # build/rootfs.simg
```

From the Ubuntu base instead:

```bash
sudo ./rootfs/build-rootfs.sh     # build/rootfs-tree + build/rootfs.tar
```

That tree has no systemd yet. Install it on the device with
`rootfs/install-to-device.sh` (native arm64 chroot; runs the maintainer
scripts). The installer:

1. unpacks the debs except `systemd-sysv`,
2. `dpkg --unpack` + `dpkg --configure -a` (libsystemd-shared must be
   configured before systemd),
3. then `systemd-sysv`,
4. bind-mounts `/proc`, `/sys`, `/dev` for postinst.

If the tarball already contains `/usr/lib/systemd/systemd`, the deb step is
skipped.

## 7. Sanitizing a snapshot

Never delete keys or logs on the running system. Snapshot raw, sanitize on the
host:

```bash
./rootfs/snapshot-rootfs.sh                 # build/rootfs-snapshot.tar
sudo mkdir -p build/tree
sudo tar xpf build/rootfs-snapshot.tar -C build/tree
sudo ./rootfs/sanitize-rootfs.sh build/tree
```

`sanitize-rootfs.sh` empties `/etc/machine-id`, removes Dropbear host keys,
logs, `/etc/resolv.conf`, the random seed and the dangling
`/etc/modules-load.d/modules.conf` from the 26.04 base, and creates
`/etc/odessa-ready` (the marker the initramfs checks).

Build the payload:

```bash
sudo chown root:root build/tree
sudo tar -C build/tree -cf - . | gzip -9 > artifacts/rootfs-install.tar.gz
```

## Ext4 feature note

The static `mke2fs 1.47.4` enables `orphan_file` by default; the rootfs userland
(`resize2fs` 1.46/1.47) rejects it and `odessa-growfs` would fail. All
`mke2fs` calls therefore use `-O ^orphan_file`. Keep this when changing the
image build.

## U-Boot (optional)

The prebuilt `artifacts/u-boot.bin` is included. To rebuild:

```bash
SRC=/path/to/u-boot-2026.10 ./uboot/build-uboot.sh
```

It copies the four board files, applies
`uboot/patches/0001-f_acm-nonblocking.patch` (the upstream ACM gadget waits for
a host to open the port; odessa must hand the initialized UDC to Linux without
blocking) and builds `qcom_qcs615_odessa_defconfig`.
