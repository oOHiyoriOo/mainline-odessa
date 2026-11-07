# Attribution

The authoritative component/license table is `NOTICE.md` at the repository
root. Short version:

- Linux 6.12.0 — GPL-2.0 (patch and board DTS in this repo, GPL-2.0)
- U-Boot v2026.10 — GPL-2.0+ (patch in this repo, GPL-2.0+)
- BusyBox — GPL-2.0
- Dropbear — MIT
- e2fsprogs 1.47.4 — GPL-2.0 / LGPL-2.1
- mkbootimg (AOSP) — Apache-2.0
- Ubuntu 26.04.1 base + systemd 259.9 — per-package licenses; copyright files
  are inside `artifacts/rootfs-install.tar.gz` under `/usr/share/doc/*/copyright`

The `kernel/dts/abl-merged-gcc.dts` is derived from the device's stock
firmware DTB/DTBO and mainline Qualcomm DTS files (GPL-2.0 / BSD-3-Clause as
marked in the file).
