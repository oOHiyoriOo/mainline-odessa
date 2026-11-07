# UBOOT-TOOLS-01 — U-Boot aarch64 host build environment

- PROJECT: odessa-usbgadget
- RUN_ID: 20261106-odessa-usbgadget
- TASK_ID: UBOOT-TOOLS-01
- TARGET_ID: host build environment for Moto G9 Plus odessa (SM6150/SDMMAGPIE); workspace /workspace
- ROLE: software-manager, PHASE: Tool-Readiness (pre-Phase 1)
- STATUS: INSTALLED
- Date: 2026-11-06 (UTC)

Scope was tool readiness only: fetch pinned official U-Boot source and provide the
missing host build prerequisites in the persistent area. No U-Boot configure/build,
no device interaction, no target network, no writes to `/workspace/work/odessa` or
`/workspace/firmeware`.

## 1. U-Boot source (official, pinned)

Selection rule from the task: newest stable, non-rc release tag matching `v20YY.MM`.

Enumerated tags with:

```
git ls-remote --tags https://source.denx.de/u-boot/u-boot.git 'v2026*'
```

Newest stable non-rc entry is `v2026.10` (only `v2026.10-rc1..rc5` are newer).

| item | value |
|---|---|
| repository | https://source.denx.de/u-boot/u-boot.git (official DENX) |
| tag | `v2026.10` |
| annotated tag object | `a58e2b7af42c179ace2c6210de0a219fa3f3cf3c` |
| peeled commit (HEAD) | `5508406582f6f7120dce0c4b3059819a41788db2` |
| tagger | Tom Rini <trini@konsulko.com>, 2026-10-05 |
| clone path | `/home/zero/.local/share/opencode/re-tools/src/u-boot-v2026.10` |
| stable symlink | `/home/zero/.local/share/opencode/re-tools/src/u-boot` -> `u-boot-v2026.10` |
| size | 625 MB, full history of that tag (not shallow), no submodules (`.gitmodules` absent) |
| working tree | clean (`git status --porcelain` = 0 lines) |

Commands:

```
git clone --branch v2026.10 --single-branch \
  https://source.denx.de/u-boot/u-boot.git u-boot-v2026.10
cd u-boot-v2026.10
git describe --tags --always   # -> v2026.10
git rev-parse HEAD             # -> 5508406582f6f7120dce0c4b3059819a41788db2
```

Source tree was not modified. No patch, no build, no `.config`.

### Tag signature verification

The tag carries a detached PGP signature (EdDSA, key
`F3CEA8743D60E0192F9B4C7A2BE2A0F50ABFE40A`, uid "Thomas Rini
<trini@konsulko.com>"). No U-Boot key was present locally; keyserver protocols
(`hkps://keys.openpgp.org`, `hkps://keyserver.ubuntu.com`, `hkps://pgp.mit.edu`)
failed from this container, so the key was fetched over HTTPS from the official
key lookup service by full fingerprint:

```
curl -fsSL -o uboot-trini.asc \
  https://keys.openpgp.org/vks/v1/by-fingerprint/F3CEA8743D60E0192F9B4C7A2BE2A0F50ABFE40A
GNUPGHOME=/home/zero/.local/share/opencode/re-tools/src/.gnupg-u-boot \
  gpg --import uboot-trini.asc
GNUPGHOME=/home/zero/.local/share/opencode/re-tools/src/.gnupg-u-boot git tag -v v2026.10
```

Result:

```
gpg: Signature made Mon Oct  5 21:37:34 2026 UTC
gpg:                using EDDSA key F3CEA8743D60E0192F9B4C7A2BE2A0F50ABFE40A
gpg: Good signature from "Thomas Rini <trini@konsulko.com>" [unknown]
```

Integrity: **signature cryptographically valid**. Authenticity caveat: the key is
not WoT-certified in the fresh keyring (`[unknown]`, "no indication that the
signature belongs to the owner"); identity rests on the verified uid served by
keys.openpgp.org plus the tagger field of the official DENX tag. The keyring is
kept at `re-tools/src/.gnupg-u-boot` so the check is repeatable offline.

## 2. Host prerequisites

Method: check first, then install only the missing items into
`/home/zero/.local/share/opencode/re-tools/` (persistent ext4 mount
`/dev/nvme1n1p1` on `/home/zero/.local/share/opencode`). No sudo, no apt/dpkg
database write, no `/usr`, `/opt`, `/srv/miniconda3`, no target workspace writes.
Host dev packages are absent from this container image, so Ubuntu 24.04 (noble)
binary packages were fetched from `archive.ubuntu.com`, SHA-256 verified against
the official `Packages.xz` indices, and extracted with `dpkg -x` into a dedicated
host sysroot.

### Already present (not reinstalled)

| tool | path | version |
|---|---|---|
| bison | `re-tools/bin/bison` | 3.8.2 |
| flex | `re-tools/bin/flex` | 2.6.4 |
| bc | `re-tools/bin/bc` | 1.07.1 |
| m4 | `re-tools/bin/m4` | 1.4.19 |
| cpio | `re-tools/bin/cpio` | 2.13 |
| dtc | `re-tools/bin/dtc` | DTC 1.6.1 |
| aarch64 cross gcc | `re-tools/cross-aarch64/usr/bin/aarch64-linux-gnu-gcc` | Debian 12.2.0-14 |
| aarch64 binutils | `re-tools/bin/aarch64-linux-gnu-*` (wrappers) | GNU ld 2.40 |
| make | `/usr/bin/make` | GNU Make 4.3 |
| host gcc | `/usr/bin/gcc` | 13.3.0 |
| git | `/usr/bin/git` | 2.43.0 |
| python3 | `/srv/miniconda3/envs/py12/bin/python3` | 3.12.16 |
| python3-setuptools | same interpreter | 84.0.0 |
| e2fsprogs (mkfs.ext4, e2fsck, mke2fs) | `/usr/sbin/*` | 1.47.0 |

### Installed in this task (new)

Host sysroot: `/home/zero/.local/share/opencode/re-tools/uboot-hostroot`
(38 MB). Binary entry points are symlinked/wrapped in `re-tools/bin`.

| component | installed version | entry point |
|---|---|---|
| OpenSSL headers/libs (`libssl-dev`) | 3.0.13-0ubuntu3.16 | `re-tools/uboot-hostroot/usr/include/openssl` |
| libuuid headers (`uuid-dev`) | 2.39.3-9ubuntu6.6 | `.../usr/include/uuid` |
| ncurses headers + lib (`libncurses-dev`, `libncurses6`) | 6.4+20240113 | `.../usr/include/ncurses.h`, `-lncurses` |
| GnuTLS headers (`libgnutls28-dev`) | 3.8.3-1.1ubuntu3.6 | `.../usr/include/gnutls` |
| zlib headers (`zlib1g-dev`) | 1.3 | `.../usr/include/zlib.h` |
| swig | 4.2.0-2ubuntu1 | `re-tools/bin/swig` -> `uboot-hostroot/usr/bin/swig4.0` |
| pkgconf / pkg-config | 1.8.1-2build1 | `re-tools/bin/pkg-config` wrapper -> `.../usr/bin/pkgconf` |
| mtools | 4.0.43-1build1 | `re-tools/bin/{mformat,mcopy,mmd,mdir,minfo,...}` |
| dosfstools | 4.2-1.1build1 | `re-tools/bin/{mkfs.vfat,mkfs.fat,fsck.fat,...}` |

Runtime shared objects for the dev symlinks were copied from the container's
`/lib/x86_64-linux-gnu` into the same hostroot lib dir (libssl.so.3,
libcrypto.so.3, libuuid.so.1.3.0, libgnutls.so.30.37.1, libz.so.1.3), so the
sysroot is self-contained for linking.

Integrity: 13 `.deb` files, all `sha256sum -c` OK against the noble /
noble-updates `Packages.xz` entries. Checksums, versions and filenames are
recorded in `re-tools/uboot-hostroot/MANIFEST.txt`; archives remain under
`re-tools/_downloads/uboot-tools/`.

### Build environment usage

```
. /home/zero/.local/share/opencode/re-tools/uboot-hostroot/env.sh
```

exports `CPATH`, `LIBRARY_PATH`, `LD_LIBRARY_PATH`, `PKG_CONFIG_PATH`,
`PKG_CONFIG_SYSROOT_DIR`, prepends `re-tools/bin` and the cross binutils dir to
`PATH`. For a later build the usual U-Boot invocation is then, for example,
`make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- <defconfig>` (not executed here).

## 3. Verification (exact commands and results)

Full log: `/home/zero/.local/share/opencode/re-tools/_scratch/uboot-tools-check/check.log`.

Header + link smoke tests (compiled with the environment, executed once):

| test | command | result |
|---|---|---|
| OpenSSL | `gcc t_ssl.c -lssl -lcrypto && ./t_ssl` | `ssl=OpenSSL 3.0.13 30 Jan 2024 num=300000d0` |
| libuuid | `gcc t_uuid.c -luuid && ./t_uuid` | valid UUID printed, buffer len 37 |
| GnuTLS | `gcc t_gnutls.c -lgnutls && ./t_gnutls` | `gnutls=3.8.3 check=ok` |
| ncurses | `gcc t_ncurses.c -lncurses && ./t_ncurses` | `ncurses=ncurses 6.4.20240113 macro=6.4` |
| zlib | `gcc t_zlib.c -lz && ./t_zlib` | `zlib=1.3` |

CLI checks:

```
swig -version                         -> SWIG Version 4.2.0
pkg-config --version                  -> 1.8.1
pkg-config --modversion openssl uuid gnutls ncursesw zlib
                                      -> 3.0.13 / 2.39.3 / 3.8.3 / 6.4.20240113 / 1.3
mformat -V                            -> mformat (GNU mtools) 4.0.43
mkfs.vfat --help                      -> "Usage: mkfs.vfat [OPTIONS] TARGET [BLOCKS]"
fsck.fat -V                           -> "Usage: fsck.fat [OPTIONS] DEVICE"
aarch64-linux-gnu-gcc --version       -> Debian 12.2.0-14
python3 -c 'import setuptools'        -> setuptools 84.0.0
git tag -v v2026.10                   -> Good signature from "Thomas Rini <trini@konsulko.com>"
```

Persistence evidence:

```
findmnt -no TARGET,SOURCE,FSTYPE,OPTIONS /home/zero/.local/share/opencode
-> /home/zero/.local/share/opencode /dev/nvme1n1p1[/home/zero/.local/share/opencode] ext4 rw,relatime
```

All installed artifacts are below that mount; `re-tools` is not a container-layer
directory. No global PATH file was changed; `env.sh` is opt-in per shell.

## 4. Deviations, limitations, open points

- `libgnutls28-dev` was extracted as headers + link symlink only. `gnutls.pc`
  declares `Requires.private: nettle, hogweed, libtasn1, libidn2, p11-kit-1`;
  those `.pc` files are not installed, so `pkg-config --cflags gnutls` prints
  "package not found" warnings. Header use and `-lgnutls` linking work (tested).
  This only affects static GnuTLS linking; `mkeficapsule` is not needed for a
  qcom chainload build.
- `python3`/`setuptools` come from the container's miniconda env
  (`/srv/miniconda3/envs/py12`), which is outside the persistent re-tools area but
  part of the image. `pyelftools` is **not** installed; it is only needed by
  binman for ELF inputs, not for a plain `u-boot.bin` build. Flag if binman ELF
  packaging is required later.
- `aarch64-linux-gnu-` resolves to the existing 2.40 binutils wrappers in
  `re-tools/bin`; the cross-gcc tree also carries its own binutils. Both are
  present; the wrapper path wins on `PATH` per `env.sh`.
- Observation, not analysis: upstream `v2026.10` has **no** `sm6150`/odessa
  board. Available Qualcomm defconfigs are `dragonboard410c`, `dragonboard820c`,
  `qcom_defconfig`, `qcom_ipq5424_mmc`, `qcom_ipq9574_mmc`, `qcom_qcs615`,
  `qcom_qcs8300`, `qcom_qcs9100`. `qcom_qcs615` is the QCS615 SoC, not SM6150.
  A board port/derivative will be needed before any build target exists.
- No sudo, no apt, no system-wide install, no `curl | sh`, no downloaded
  application execution beyond version/help queries of the installed host tools.
- Nothing was built or configured; no device, SSH, fastboot or target network
  activity.
