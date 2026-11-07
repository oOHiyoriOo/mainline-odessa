# T2-TOOLCHAIN - software-manager note

PROJECT=odessa-usbgadget
RUN_ID=20261106-odessa-usbgadget
TASK_ID=T2-TOOLCHAIN
TARGET_ID=Moto G9 Plus "odessa" (XT2087-2), LineageOS 20.0-20231120-UNOFFICIAL-odessa,
          kernel 4.14.190-perf+ (Android clang 14.0.6 / LLD 14.0.6, r450784d)
ROLE=software-manager, PHASE=Tool-Readiness
STATUS=INSTALLED (D1), DONE (D2/D3). No kernel build, no device access.

All persistent artifacts: `/home/zero/.local/share/opencode/re-tools/`
(`findmnt -T` -> `/dev/nvme1n1p1[/home/zero/.local/share/opencode] ext4 rw,relatime`).
Nothing installed to /usr, /opt, /srv; no sudo, no apt, no curl|sh, no docker change.
`/workspace/firmeware/**` untouched (read-only use of `running_kernel.config`).

---

## D1 - Toolchain

### a) AOSP clang r450784d (14.0.6)

| item | value |
|---|---|
| URL | `https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/tags/android-13.0.0_r3/clang-r450784d.tar.gz` (HTTP 200, no redirect to a mirror) |
| tarball | `re-tools/_downloads/t2-toolchain/clang-r450784d.tar.gz`, 561,422,402 bytes |
| sha256 | `edaa1a480fa73241714a234a51cccc8d2c5a4ff76ade3a0afe5b5890a3fd1006` |
| integrity | `gzip -t` OK. googlesource `+archive` of a git tag serves a generated tarball, the provider publishes no separate checksum/signature for it -> local sha256 recorded, first sha256 taken mid-download (`fdaf3294...`) was discardable/partial and is NOT the artifact hash |
| install dir | `re-tools/clang-r450784d/` (1.8 GB) |
| binary | `re-tools/clang-r450784d/bin/clang` |

```
$ re-tools/clang-r450784d/bin/clang --version
Android (8490178, based on r450784d) clang version 14.0.6 (https://android.googlesource.com/toolchain/llvm-project 4c603efb0cca074e9238af8b4106c30add4418f6)
Target: x86_64-unknown-linux-gnu
Thread model: posix
InstalledDir: /home/zero/.local/share/opencode/re-tools/clang-r450784d/bin
```
`AndroidVersion.txt`: `14.0.6` / `based on r450784d`.

Required binaries present in `bin/`: `clang`, `ld.lld`, `llvm-ar`, `llvm-nm`,
`llvm-objcopy`, `llvm-strip`, `llvm-objdump` (also `clang++`, `clang-14`,
`llvm-readelf`, `llvm-size`, `llvm-objcopy`).

NOTE (error class 1 of 3, resolved): `bin/clang` is AOSP's Go `compiler_wrapper`
which locates `clang.real` next to the *invoked* path. Symlinking it into
`re-tools/bin/` broke it (`compiler_wrapper.go:250 ... no such file or directory`).
Fix: no symlink; `re-tools/clang-r450784d/bin` is prepended to PATH in `env.sh`.
Side effect worth knowing: `clang -v` output is what `scripts/Kbuild.include`
greps for `cc-name`; with the broken symlink the kernel tree silently fell back
to the gcc code path and aborted with `CROSS_COMPILE_COMPAT not defined`.
With the real path, `cc-name == clang` is detected.

Cross-compile smoke test (not a kernel build):

```
$ clang --target=aarch64-linux-gnu -O2 -c t.c -o t.o
t.o: ELF 64-bit LSB relocatable, ARM aarch64, version 1 (SYSV), not stripped
$ ld.lld -o t.elf t.o -e f
t.elf: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), statically linked
```

### b) aarch64 binutils (Debian bookworm 2.40-2)

Needed because a 4.14 Android kernel invokes `$(CROSS_COMPILE)as` etc.;
`CC=clang` alone does not provide `aarch64-linux-gnu-as`.

| package | version | sha256 (Debian Packages index, verified on download) |
|---|---|---|
| binutils-aarch64-linux-gnu | 2.40-2 | `3d6f64a7a4ed6d73719f8fa2e85fd896f58ff7f211a6683942ba93de690aaa66` |
| binutils-common | 2.40-2 | `ab314134f43a0891a48f69a9bc33d825da748fa5e0ba2bebb7a5c491b026f1a0` |
| libbinutils | 2.40-2 | `fcf55b99e5f8a78f3c8ce9b6957f1024f394cf20c196b100d308a57e43547710` |

URLs: `https://deb.debian.org/debian/pool/main/b/binutils/<file>.deb`.
Extracted with `dpkg -x` into `re-tools/build/t2-root/` (45 MB). The cross
binaries need `libbfd-2.40-arm64.so` / `libopcodes-2.40-arm64.so` and would
otherwise bind to the host's 2.42 libraries -> per-tool wrapper scripts in
`re-tools/bin/aarch64-linux-gnu-*` set `LD_LIBRARY_PATH=re-tools/build/t2-root/usr/lib/x86_64-linux-gnu`
for that invocation only (no global LD_LIBRARY_PATH, host binutils 2.42 untouched).

```
$ aarch64-linux-gnu-ld --version | head -1
GNU ld (GNU Binutils for Debian) 2.40
$ aarch64-linux-gnu-as --version | head -1
GNU assembler (GNU Binutils for Debian) 2.40
```

### c) Host build tools (Debian bookworm amd64 .debs, dpkg -x, no install)

| tool | version | deb sha256 |
|---|---|---|
| bc | 1.07.1-3+b1 | `baaa4e935c5e3bcd57d4f2f4e7a1ddc67bd4eb8629d98f97a696548849ae01ac` |
| bison | 3.8.2+dfsg-1+b1 | `a414afd7519c53bfa33415ba5b951bc8b4906877004c49723ffda50a6033c3e8` |
| flex | 2.6.4-8.2 | `da3fd55dbb6aff4f7b3187580813e0ef707d0c596402e37c8fd144df60003636` |
| m4 (bison runtime dep) | 1.4.19-3 | `b2dd7bfca426712416e651bb5ff6dabe7d05e4caebbac61d714dbe261b31e4c3` |
| libfl2 | 2.6.4-8.2 | `bd878478de2e95bbac86c15658b9fde713233999e0bcf7f1e6771df6ff4dcf7a` |
| cpio | 2.13+dfsg-7.1 | `73d4a22bdd7eb6be1e480d6884b103eb500cfd539cc20ae0f3e44dd8b0614798` |
| device-tree-compiler (dtc) | 1.6.1-4+b1 | `f56fbb1e1da6545619dd2a17b7a85b2c4c674bd276d1b844e01a8b9901dd349d` |
| libfdt1 (dtc dep) | 1.6.1-4+b1 | `e7312b61267979a58ae1fa9e34746d077707560c955f6455d02a9ff0f8fa7995` |

Verified via wrappers: `bc 1.07.1`, `bison (GNU Bison) 3.8.2`, `flex 2.6.4`,
`m4 (GNU M4) 1.4.19`, `cpio (GNU cpio) 2.13`, `Version: DTC 1.6.1`.
`rsync` and `lz4` were NOT installed: the 4.14 arm64 build uses gzip (`Image.gz`)
and the host gzip is present; no build step needs rsync. `openssl`/libssl headers
NOT installed: `CONFIG_MODULE_SIG`/`SYSTEM_TRUSTED_KEYS` are not part of the
target config, so `scripts/extract-cert` is not invoked (re-check in T3; if the
build ever demands it, request libssl-dev explicitly).

### d) mkbootimg / unpack_bootimg

`git clone --depth 1 https://android.googlesource.com/platform/system/tools/mkbootimg`
-> `re-tools/src/mkbootimg`, HEAD `d2bb0af5ba6d3198a3e99529c97eda1be0b5a093`
(2025-03-02, "Cleanup python version properties am: a545f5b3b6").
```
$ python3 $MKBOOTIMG/mkbootimg.py --help   -> rc 0 (mkbootimg-ok)
$ python3 $MKBOOTIMG/unpack_bootimg.py --help -> rc 0 (unpack_bootimg-ok)
```

### e) busybox-static (Debian 1:1.35.0-4+deb12u1+b1, both arches)

| arch | deb | sha256 |
|---|---|---|
| amd64 | busybox-static_1.35.0-4+deb12u1+b1_amd64.deb | `3d3fdbe91d4660c873e14b092c213fe81c1da6362daa236eb25d0171eb108744` |
| arm64 | busybox-static_1.35.0-4+deb12u1+b1_arm64.deb | `732c9135564fc71337e0e05fb4da4d11e6c28c1834bce3e405e575afef2a52f5` |

Extracted into separate roots (`re-tools/build/busybox-amd64`, `.../busybox-arm64`)
because both debs ship `/bin/busybox`; exposing them as `re-tools/bin/busybox-amd64`
and `re-tools/bin/busybox-arm64`.

```
$ file build/busybox-amd64/bin/busybox
ELF 64-bit LSB executable, x86-64, ... statically linked, stripped
$ file build/busybox-arm64/bin/busybox
ELF 64-bit LSB executable, ARM aarch64, ... statically linked, for GNU/Linux 3.7.0, stripped
$ python3 (ELF header parse)
EI_CLASS=2 EI_DATA=1 e_type=2 (ET_EXEC) e_machine=183 (AArch64) version=1
$ busybox-amd64 | head -1
BusyBox v1.35.0 (Debian 1:1.35.0-4+deb12u1+b1) multi-call binary.
```
busybox **v1.35.0**. The arm64 binary was NOT executed (no binfmt/qemu run);
its identity is proven by `file` + ELF header parse only.

### f) Environment file `/workspace/work/odessa/env.sh`

Exports `PATH=re-tools/clang-r450784d/bin:re-tools/bin:$PATH`, `ARCH=arm64`,
`SUBARCH=arm64`, `CROSS_COMPILE=aarch64-linux-gnu-`, `CLANG_TRIPLE=aarch64-linux-gnu-`,
`CC=clang`, `KSRC`, `KOUT`, `MKBOOTIMG`, and defines

```
kbuild() { make -C "$KSRC" O="$KOUT" ARCH=arm64 LLVM=1 \
                 CROSS_COMPILE=aarch64-linux-gnu- CLANG_TRIPLE=aarch64-linux-gnu- "$@"; }
```

`LLVM=1` is deliberate: `arch/arm64/kernel/vdso32/Makefile` uses
`LD_COMPAT ?= $(LD)` only when `LLVM` is set; otherwise it wants
`CROSS_COMPILE_COMPAT` (arm32 binutils) which is intentionally not installed.
`CONFIG_COMPAT_VDSO=y` is in the target config, so T3 must keep `LLVM=1`.

Verification, exactly the requested command:

```
$ bash -c 'source /workspace/work/odessa/env.sh; clang --version; aarch64-linux-gnu-ld --version | head -1; cpio --version | head -1; dtc --version; python3 $MKBOOTIMG/mkbootimg.py --help >/dev/null && echo mkbootimg-ok'
Android (8490178, based on r450784d) clang version 14.0.6 (...)
Target: x86_64-unknown-linux-gnu
Thread model: posix
InstalledDir: /home/zero/.local/share/opencode/re-tools/clang-r450784d/bin
GNU ld (GNU Binutils for Debian) 2.40
cpio (GNU cpio) 2.13
Version: DTC 1.6.1
mkbootimg-ok
rc=0
$ bash -c 'source /workspace/work/odessa/env.sh; kbuild kernelrelease'
4.14.190-perf+
```

---

## D2 - Kernel source (LineageOS, 4.14.190)

Repo: `https://github.com/LineageOS/android_kernel_motorola_sm6150`
Clone (full history, 2.7 GB incl. .git): `/workspace/work/odessa/kernel`
Refs (repo has **0 tags**):

```
refs/heads/lineage-20            112b525abbc08298256abedbf984e0e8c20d0338  2023-11-04
refs/remotes/origin/HEAD      -> origin/lineage-20
refs/remotes/origin/lineage-20   112b525abbc0  2023-11-04
refs/remotes/origin/lineage-19.1 ce0780ecded9  2022-06-02
```

Makefile at every tip: `VERSION=4 PATCHLEVEL=14 SUBLEVEL=190 EXTRAVERSION=`
(NAME "Petit Gorille") - both `lineage-20` and `lineage-19.1`, and the default
branch (= `lineage-20`). History: 795,510 commits, 2005-04-16 .. 2023-11-04.

SUBLEVEL=190 commit search:

```
$ git log --all --oneline -S 'SUBLEVEL = 190' -- Makefile
e5a54aa2d312e75fe4bc66c7b84400b02266e946  Linux 4.14.190   (2020-07-29 07:42:58 +0200)
```
That is the only commit that introduced `SUBLEVEL = 190`; the Android/Lineage
branches never bump SUBLEVEL afterwards, so the branch tip still reports
4.14.190. It is an ancestor of `lineage-20` (69,636 commits lie between it and
the tip).

**Chosen commit: `112b525abbc08298256abedbf984e0e8c20d0338`** (tip of `lineage-20`,
committer date 2023-11-04 03:00:46 +0530, "kernel: Use stock defconfig for
/proc/config.gz"). Rationale: latest commit on the default branch, 16 days before
the ROM build stamp 2023-11-20, Makefile 4.14.190 - consistent with the
installed `4.14.190-perf+`. UNVERIFIED_HYPOTHESIS: the ROM was built from exactly
this commit; the ROM ships no build-id, so "tip at build time" is the best
evidence available, not proof.

Odessa device support (present on `lineage-20`):

```
arch/arm64/configs/vendor/odessa_defconfig
arch/arm64/configs/vendor/ext_config/{moto,factory,debug}-sdmmagpie-odessa.config
arch/arm64/boot/dts/qcom/sdmmagpie-odessa-base.dts
arch/arm64/boot/dts/qcom/sdmmagpie-odessa-{evt1,dvt2,pvt}-overlay.dts
arch/arm64/boot/dts/qcom/sdmmagpie-odessa-{audio,charger,common,fps,touch}-overlay.dtsi
arch/arm64/boot/dts/qcom/odessa-panel.dtsi
arch/arm64/boot/dts/qcom/sdmmagpie-camera-sensor-mot-odessa-overlay.dtsi
arch/arm64/boot/dts/qcom/sm7150-camera-sensor-mot-odessa-overlay.dtsi
```
12 odessa dts/dtsi files, referenced from `arch/arm64/boot/dts/qcom/Makefile`
(`sdmmagpie-odessa-{evt1,dvt2,pvt}-overlay.dtbo`). The path requested in the
task (`arch/arm64/boot/dts/vendor/qcom/*odessa*`) does not exist in this tree;
the real location is `arch/arm64/boot/dts/qcom/`.

Corroborating fact: `arch/arm64/configs/vendor/odessa_defconfig:1297` also has
`# CONFIG_DEVTMPFS is not set`, matching `running_kernel.config:1381`.

---

## D3 - Config staging (no build)

```
cp /workspace/firmeware/running_kernel.config /workspace/work/odessa/build/.config
kbuild olddefconfig          # ARCH=arm64 CC=clang, host gcc 13 for scripts/kconfig
scripts/config --file $KOUT/.config -e DEVTMPFS -e DEVTMPFS_MOUNT
kbuild olddefconfig          # re-resolve
```

`olddefconfig` diff (`.config.orig` -> `.config`), 8 removals / 1 addition plus
the two DEVTMPFS lines we forced:

```
-CONFIG_CROSS_COMPILE_ARM32=""
+CONFIG_CROSS_COMPILE_COMPAT=""          (symbol renamed in this tree)
-CONFIG_WIREGUARD=y
-# CONFIG_WIREGUARD_DEBUG is not set     (wireguard-linux-compat not in this tree)
-# KernelSU
-CONFIG_KSU=y
-# CONFIG_KSU_DEBUG is not set           (KernelSU not in this tree)
-# CONFIG_DEVTMPFS is not set
+CONFIG_DEVTMPFS=y
+CONFIG_DEVTMPFS_MOUNT=y
```

**Finding for the hub:** the stock ROM config enables `CONFIG_KSU=y` and
`CONFIG_WIREGUARD=y`, which this LineageOS tree does not know. So the installed
kernel was built from a *patched* variant (KernelSU + WireGuard backport), not
from the plain LineageOS branch. For the initramfs/USB-gadget goal these two
symbols are irrelevant (they only drop KernelSU and WireGuard support in our
build); nothing else in the 6,322-line config was altered by olddefconfig.

Final state:

```
$ grep -n DEVTMPFS /workspace/work/odessa/build/.config
1379:CONFIG_DEVTMPFS=y
1380:CONFIG_DEVTMPFS_MOUNT=y

$ kbuild kernelrelease
4.14.190-perf+
```
The `+` suffix comes from `scripts/setlocalversion` because the repo carries no
tags - the same mechanism produces the device's reported `4.14.190-perf+`,
which is a positive consistency check. `CONFIG_LOCALVERSION="-perf"`.

`/workspace/work/odessa/build` (6.3 MB) contains `.config`, `.config.orig`,
`.config.old`, `olddefconfig.diff`, `include/`, `scripts/`, `Makefile`,
`source -> ../kernel`. No object files, no kernel image (build belongs to T3).

---

## LIMITS / BLOCKERS

- No kernel build performed (out of scope); `make prepare`/`Image.gz` and the
  first real compile are T3's. Residual risk: `--gcc-toolchain`/`--prefix` are
  derived from `$(CROSS_COMPILE)elfedit` (our wrapper dir), which contains no
  libgcc tree; if T3 trips over it, the fix is `CROSS_COMPILE=aarch64-linux-gnu-`
  with an installed arm64 gcc/`--gcc-toolchain` or explicit `GCC_TOOLCHAIN_DIR=`.
- `CONFIG_COMPAT_VDSO=y` requires `LLVM=1` for the compat vDSO link; documented
  in `env.sh`. Without it the tree errors out before compiling anything.
- No arm32 (`arm-linux-gnueabi`) toolchain installed - deliberately not needed
  with `LLVM=1`.
- clang tarball has no upstream-published checksum (generated `+archive`);
  only the local sha256 is available. All Debian debs were verified against the
  `SHA256` field of the official `dists/bookworm/main/binary-<arch>/Packages.xz`.
- busybox-arm64 was not executed (no emulation), verified statically only.
- No network destination outside dl.google.com / android.googlesource.com /
  github.com / deb.debian.org was contacted. No adb/fastboot/device access.
