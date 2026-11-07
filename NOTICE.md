# Third-party components

This repository combines components with different licenses. The shipped
binaries are unmodified builds from the projects below except where noted.

| Component | Version | License | Source |
|---|---|---|---|
| Linux kernel | 6.12.0 | GPL-2.0 | https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.tar.xz (sha256 `b1a2562b...f54625eb`) |
| kernel patch `kernel/patches/0001-odessa-sm6150-support.patch` | — | GPL-2.0 | this repository |
| U-Boot | v2026.10 | GPL-2.0+ | https://ftp.denx.de/pub/u-boot/ |
| U-Boot patch `uboot/patches/0001-f_acm-nonblocking.patch` | — | GPL-2.0+ | this repository |
| BusyBox (static aarch64) | see `busybox --help` | GPL-2.0 | https://busybox.net/ |
| Dropbear SSH | see `dropbear -V` | MIT | https://matt.ucc.asn.au/dropbear/ |
| e2fsprogs (static aarch64) | 1.47.4 | GPL-2.0 / LGPL-2.1 | https://e2fsprogs.sourceforge.net/ |
| mkbootimg.py | AOSP | Apache-2.0 | https://android.googlesource.com/platform/system/tools/mkbootimg/ |
| Ubuntu base rootfs | 26.04.1 | mixed (per package) | https://cdimage.ubuntu.com/ubuntu-base/releases/26.04/release/ |
| systemd packages | 259.9-0ubuntu0.1 | LGPL-2.1+ | Ubuntu `resolute` ports repository |

Full license texts and copyright files for the rootfs packages are inside
`artifacts/rootfs-install.tar.gz` under `/usr/share/doc/*/copyright`.

The device tree source `kernel/dts/abl-merged-gcc.dts` is derived from the
stock firmware DTB/DTBO of the Moto G9 Plus and from mainline Qualcomm DTS
files (GPL-2.0 / BSD-3-Clause as indicated in the file).
