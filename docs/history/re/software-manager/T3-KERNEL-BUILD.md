# T3-KERNEL-BUILD — arm64 `Image.gz` aus dem gestagten 4.14.190-Config

- PROJECT: odessa-usbgadget
- RUN_ID: 20261106-odessa-usbgadget
- TASK_ID: T3-KERNEL-BUILD
- TARGET_ID: Moto G9 Plus "odessa", Kernel 4.14.190
  (LineageOS `android_kernel_motorola_sm6150` @ `112b525abbc08298256abedbf984e0e8c20d0338`)
- PHASE: Build
- ROLE: software-manager
- Zeitraum: 2026-11-06 14:06–14:30 UTC
- STATUS: **INSTALLED/BUILT — `Image.gz` erzeugt, rc=0, keine Kernel-Source-Aenderung**

## 1. Auftrag (vom Orchestrator)

Aus `/workspace/work/odessa/build/.config` (DEVTMPFS=y, DEVTMPFS_MOUNT=y,
kernelrelease 4.14.190-perf+) ein bootbares arm64 `Image.gz` bauen.
Harte Nutzer-Auflage: **maximal `-j12`**, `nice -n 10`, `ionice -c3` wenn
vorhanden, keine parallelen make-Instanzen. Kein Geraete-/adb-/fastboot-Zugriff.

## 2. Vorbedingungen (vom Hub bestaetigt, hier nur gegengeprueft)

| Punkt | Befund |
|---|---|
| Tree | `git log -1` = `112b525abbc08298256abedbf984e0e8c20d0338` "kernel: Use stock defconfig for /proc/config.gz" |
| Config | `build/.config` 168591 B, mtime 14:03 (vor dem Build, unveraendert), `CONFIG_DEVTMPFS=y`, `CONFIG_DEVTMPFS_MOUNT=y` |
| clang | `re-tools/clang-r450784d/bin/clang` — Android clang 14.0.6 (r450784d) |
| lld | `ld.lld` 14.0.6 (aus demselben Prebuilt) |
| binutils | `re-tools/bin/aarch64-linux-gnu-ld` — GNU ld 2.40 (Debian) |
| Host-Tools | bc/bison/flex/cpio/dtc aus `re-tools/bin`, make `/usr/bin/make`, `ionice` vorhanden |
| Platz | 336 GB frei auf `/workspace` (= selbe FS wie re-tools), 30 GB RAM, 16 GB verfuegbar |
| Tree-Sauberkeit | `git status --porcelain` im Kernel-Tree: **0 Zeilen** (keine Aenderung vor/nach dem Build) |

## 3. Build

Reproduzierbares Skript: `/workspace/work/odessa/scripts/build-image.sh`
(Log: `build/build.log`, Stdout: `build/build-run.out`).

### 3.1 Kanonischer Aufruf (identisch in allen Versuchen)

```
cd /workspace/work/odessa && . ./env.sh
nice -n 10 ionice -c3 make -C "$KSRC" O="$KOUT" ARCH=arm64 \
     LLVM=1 CROSS_COMPILE=aarch64-linux-gnu- CLANG_TRIPLE=aarch64-linux-gnu- \
     -j12 "$HOSTCFLAGS_ARG" "$HOSTLOADLIBES_sign-file" "$HOSTLOADLIBES_extract-cert" \
     Image.gz 2>&1 | tee -a "$LOG"
```

`-j12` (nicht `$(nproc)`=32), `nice 10`, `ionice -c3`; keine zweite
make-Instanz parallel. `kbuild()`-Variablen (LLVM=1/CROSS_COMPILE/CLANG_TRIPLE)
wie in `env.sh` vorgegeben; `nice/ionice` aussen davor.

### 3.2 Versuche

| # | Start | Ende | rc | Ergebnis |
|---|---|---|---|---|
| 1 | 14:06:34 | 14:06:36 | 2 | Abbruch: `openssl/*.h` fehlt (Host-Programme) — Log `build.log.attempt1` |
| 2 | 14:08:50 | ~14:10:20 | (kein Ende-Marker) | von der Tool-Session abgeschossen (Prozessgruppe), ~3.5k Objekte fertig — Log `build.log.attempt2-interrupted` |
| 3 | 14:29:06 | 14:29:33 | **0** | fertig, `Image.gz` gelinkt — Log `build.log` (enthaelt Versuch 2+3) |

Effektive make-Rechenzeit: ca. 90 s (Versuch 2) + 27 s (Versuch 3) ≈ **117 s
Wall-Clock** auf 12 Jobs; die 19 Minuten dazwischen waren Stillstand durch den
abgebrochenen Versuch 2, keine Rechenzeit.

Konsistenz-Nachweis nach dem Build: erneuter Aufruf von `make Image.gz` mit
identischen Variablen ergab `rc=0` und **0 Rekompilierungen** (`CHK`/`find` only),
`sha256` unveraendert — d. h. keine veralteten/inkonsistenten Objekte aus dem
abgebrochenen Versuch.

## 4. Artifact

| Pruefung | Ergebnis |
|---|---|
| Pfad | `/workspace/work/odessa/build/arch/arm64/boot/Image.gz` |
| Groesse | 13.356.663 B |
| sha256 | `d13437cbe1244aa5e306544a57643e2764dcd4b3135a4a142bf44e1193f6245d` |
| `file` | `gzip compressed data, max compression, from Unix, original size modulo 2^32 35489808` |
| `gzip -t` | OK (rc 0) |
| entpackt | 35.489.808 B, `file` = **`Linux kernel ARM64 boot executable Image, little-endian, 4K pages`** |
| ARM64-Header | `magic@0x38` = `ARMd` (`0x644d5241`), `text_offset` = 0x80000, `image_size` = 40701952, `flags` = 0xa |
| Entpackt == `Image` | sha256 identisch: `112f843e617123d7deaa35bed65965f8cda5eca7f4d59ab006ae9a2af8e494e5` |
| `vmlinux` | 286.714.888 B, ELF64 ARM aarch64 PIE, `BuildID[xxHash]=77178efc51c0e3ee`, 139.940 Symbole; sha256 `1fd6c458585e47adbb9f2e64f0252fc874b47ce2c45f11410c1ab0a16d9e1681` |
| kernelrelease | **`4.14.190-perf+`** (via `make ... kernelrelease`; auch `include/generated/utsrelease.h` = `"4.14.190-perf+"`) |

Gadget-relevante Symbole im `vmlinux` (llvm-nm, auszugsweise):

```
ffffff80089762d4 T devtmpfs_mount
ffffff8008b44860 t ncm_bind
ffffff8008b48a20 t rndis_bind
ffffff8008af1818 t dwc3_msm_probe
ffffff8008b36ff4 T usb_get_function_instance
ffffff80082f1914 T configfs_register_subsystem
```

Vergleich zum Stock-Kernel (`firmeware/stock_boot.img`): Stock `kernel_size`
35.493.904 B vs. hier `Image` 35.489.808 B — gleiche Groessenordnung, gleiche
Konfigurationsbasis.

## 5. Log

- Pfad: `/workspace/work/odessa/build/build.log` (4224 Zeilen, 171.264 B), bleibt
  als Audit-Artefakt liegen; Vorgaenger-Logs `build.log.attempt1`,
  `build.log.attempt2`, `build.log.attempt2-interrupted`.
- `grep -c 'error:'` = **0**
- `grep -c 'warning:'` = **1**
- `grep -c '^  CC '` = 3165 (weitere Objekte via `HOSTCC`/`AS`/`GEN`)

Die einzige Warnung (vollstaendig, es gibt keine weitere):

```
kernel/block/blk-mq.c:567:44: warning: passing 8-byte aligned argument to
32-byte aligned parameter 2 of 'smp_call_function_single_async' may result in
an unaligned pointer access [-Walign-mismatch]
```

Bewertung: bekannte clang-`-Walign-mismatch`-Diagnose in `blk-mq.c`
(upstream in spaeteren Kernen bereinigt), keine Auswirkung auf den Bootpfad,
kein Fehler. Kosmetisch ausserdem:
`find: 'arch/arm64/boot/dts/': No such file or directory` (dieser Tree legt die
DTS unter `arch/arm64/boot/dts/qcom/` ab; `dtbs` ist fuer `Image.gz` irrelevant).

Nicht in `build.log`, aber bei der Fix-Validierung sichtbar: `HOSTCC
scripts/sign-file` und `scripts/extract-cert` erzeugen je 7
`-Wdeprecated-declarations`-Warnungen (`ERR_get_error_line`, `ENGINE_*`) gegen
OpenSSL 3.5 — erwartbar, keine Fehler.

**Bewertung: Build nicht "clean", aber nur 1 Warnung und 0 Fehler; keine
Source-Patches, Config unveraendert.**

## 6. Fixes (nur Build-Umgebung, keine Kernel-Semantik)

### F1 — fehlende OpenSSL-Header fuer Host-Programme

Erster echter Fehler (Versuch 1):

```
kernel/scripts/extract-cert.c:21:10: fatal error: 'openssl/bio.h' file not found
kernel/scripts/sign-file.c:25:10: fatal error: 'openssl/opensslv.h' file not found
make[2]: *** [scripts/Makefile.host:102: scripts/extract-cert] Error 1
make[2]: *** [scripts/Makefile.host:102: scripts/sign-file] Error 1
```

Ursache: `CONFIG_MODULE_SIG=y`, `CONFIG_MODULE_SIG_ALL=y`,
`CONFIG_SYSTEM_TRUSTED_KEYRING=y` erzwingen die Host-Programme `sign-file` und
`extract-cert`; im Container fehlt `libssl-dev` (`/usr/include/openssl` nicht
vorhanden). `HOSTCC` ist hier clang (AOSP 14), nicht gcc.

Fix ohne Netz und ohne Systeminstallation — vorhandenes OpenSSL 3.5.9 aus
`/srv/miniconda3` ueber einen schmalen Include-Shim:

```
mkdir -p /workspace/work/odessa/t3-extra/include
ln -sfn /srv/miniconda3/include/openssl /workspace/work/odessa/t3-extra/include/openssl
```

Make-Variablen (nur Host-Tools, Ziel-Compiles unberuehrt):

```
HOSTCFLAGS=-Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer \
  -std=gnu89 -Wno-unused-value -Wno-unused-parameter -Wno-missing-field-initializers \
  -I/workspace/work/odessa/t3-extra/include
HOSTLOADLIBES_sign-file=-lcrypto -L/srv/miniconda3/lib -Wl,-rpath,/srv/miniconda3/lib
HOSTLOADLIBES_extract-cert=-lcrypto -L/srv/miniconda3/lib -Wl,-rpath,/srv/miniconda3/lib
```

Stolperstein: 4.14 `scripts/Makefile.host` nutzt
`$(HOSTCFLAGS_$(basetarget).o)`; ein `HOSTCFLAGS_sign-file` (ohne `.o`) ist
wirkungslos, deshalb globales `HOSTCFLAGS` (identische Flags wie
`Makefile:371` plus `-I`). Validierung: `make scripts` baut beide Programme,
`./sign-file` und `./extract-cert` geben ihre Usage mit rc 0 aus.
Keine Aenderung an `.config`, kein Abschalten von `CONFIG_MODULE_SIG`.

### F2 — Build ueberlebt die Tool-Session (Betrieb, kein Buildfehler)

Versuch 2 wurde beim Ende des aufrufenden Shell-Kommandos mit der Prozessgruppe
abgeschossen (`nohup ... &` genuegt nicht; make/clang blieben als `<defunct>`
Zombies, kein `=== end`-Marker, keine Fehlermeldung). Versuch 3 deshalb mit
eigener Session:

```
setsid nohup ./scripts/build-image.sh > build/build-run.out 2>&1 < /dev/null &
```

## 7. Grenzen / Blocker

- Keine Blocker; Ziel erreicht.
- Keine Geraete-Interaktion, kein adb/fastboot, kein `firmeware/**` angefasst.
- Keine Systeminstallation, kein sudo, keine Netzwerk-Downloads in T3
  (OpenSSL kam aus dem bereits vorhandenen `/srv/miniconda3`).
- `Image.gz` ist noch **nicht** gebootet/getestet — das ist T5/T6.
- Boot-Header-Packen (`mkbootimg`, Seiten/Kernel-Addr) ist nicht Teil von T3.
- Verbleibende Unsicherheit: der Build lief in zwei Segmenten; die
  Idempotenz-Pruefung (0 Rekompilierung, gleicher sha256) belegt aber
  Konsistenz.

## 8. Referenzen

- Skript: `/workspace/work/odessa/scripts/build-image.sh`
- Logs: `/workspace/work/odessa/build/build.log` (+ `*.attempt*`, `build-run.out`)
- Checksummen: `/workspace/work/odessa/build/SHA256SUMS`
- Memory: `b052d520-5f6f-48b8-870b-6ae799d75f57` (Auftrag),
  `bbe4511f-9a88-4e29-a6d1-09b0e50dceaf` (Env-Precheck),
  `204b066a-35c3-4fdc-9461-f946395e510f` (F1 OpenSSL),
  `51a56c78-a723-4338-9933-4d0da1156bc6` (F2 Prozessgruppe)
