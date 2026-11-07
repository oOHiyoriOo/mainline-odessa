# STATUS — RUN 20261106-odessa-usbgadget

PROJECT=odessa-usbgadget
RUN_ID=20261106-odessa-usbgadget
TARGET_ID=Moto G9 Plus „odessa“ (XT2087-2), S/N ZY227VHMSS,
LineageOS 20.0-20231120-UNOFFICIAL-odessa (Android 13),
Kernel 4.14.190-perf+, Bootloader MBM-3.0-odessa_retail-e69c40c38d6-220818
ROLE=orchestrator
Stand: 2026-11-06 (UTC)

Dieses Dokument ist das zentrale, laufend gepflegte Protokoll des Runs. Es
dokumentiert Auftrag, Zielidentitaet, alle Tasks, bestaetigte Fakten,
Fehlschlaege, Hypothesen, Artefakte und offene Punkte. Spoke-Notizen liegen
unter `docs/re/20261106-odessa-usbgadget/<ROLE>/`; der Artefakt-Katalog in
`ARTIFACTS.md`, die externe Recherche in `RESEARCH-mainline-sm6150.md`.

---

## 0. Kurzfassung (Ist-Zustand)

**Funktioniert und verifiziert:**

- Eigener Kernel **4.14.190** aus dem LineageOS-Tree, `CONFIG_DEVTMPFS=y`,
  bootet per `fastboot boot`.
- Eigenes **BusyBox-Initramfs** mit USB-NCM-Gadget, DHCP-Server
  (`172.16.42.1/24`), Dropbear-SSH (key-only) und Telnet-Fallback.
- **Ubuntu 22.04.5 LTS arm64** auf `userdata` (`/dev/sdb24`, ext4), Start per
  `switch_root` mit `odessa.boot=ubuntu`; SSH, DHCP, Batterie-Sysfs.
- **Rescue-Architektur:** Prep-Initramfs in `boot_b`, `boot_a` unveraendert
  Stock; Umschalten per `fastboot set_active a|b`.
- **pstore/ramoops** als Post-Mortem-Kanal: kontrollierter Panic ueberlebt
  Reboot und ist im Rescue lesbar.
- **Wiederverwendbarer Installer** (`install-to-device.sh`), end-to-end und
  idempotent getestet (inkl. Reinstall nach versehentlichem Userdata-Wipe).

**Blockiert:**

- **Mainline Linux 6.12** baut, bootet aber nicht:
  - eigenes/rekompiliertes DTB -> Bootloader lehnt ab (2 Reboots -> Recovery);
  - **genulltes `dtbo_a` ist kein Bypass**: ABL meldet
    `Dtbo hdr magic mismatch 0, with D7B7AB1E` -> `BootLinux() failed:
    Not Found`;
  - Original-Stock-DTB -> kein sichtbarer Kernel-Output (kein fbcon, kein USB,
    kein 6.12-pstore-Eintrag; Ringpuffer-Caveat beachten);
  - Ursache lokal eingegrenzt: Der aktive DTBO-Overlay (Entry 2) hat 104
    Fragments/190 Symbol-Fixups und braucht den vollen Vendor-Base-Tree; ein
    Minimal-DTB kann den Merge nicht erfuellen;
  - kein UART -> keine direkte fruehe Konsole.
- **DTBO0-Test vorbereitet** (nur `dtbo_a`, nicht geflasht): drei Mainline-
  Images mit korrigierter Board-ID `<0x49 0xc000>`, leerem `/memory` und
  `dtc -@`; Freigabe fuer den persistenten `dtbo_a`-Eingriff steht aus.
- Externe Recherche zu SM6150-Mainline/ABL-DTB laeuft (Nutzer, Option D).

**Aktueller Geraetezustand (verifiziert 2026-11-06):**

- Aktiver Slot `_a`, Geraet in **Lineage-Recovery**.
- `boot_a` (sde21): Stock-Android, `ANDROID!`, Kernel 35.493.904 B,
  Ramdisk 2.797.028 B.
- `boot_b` (sdf21): unser **Rescue-Prep-Image**, Kernel 13.356.663 B,
  Ramdisk 3.765.922 B.
- Akku: 87 %, `status=Charging`, `current_now=748596`,
  `voltage_now=4471395` (Recovery-Sicht). Das Rescue-Initramfs hat **keinen**
  Battery-Guard und laedt bei gestecktem Kabel durch.

---

## 1. Auftrag, Ziel und Abnahme

### 1.1 Urspruenglicher Auftrag

Ein modernes Linux (zunaechst Ubuntu 22.04) auf dem Moto G9 Plus per
`fastboot boot` starten, ohne Boot/Recovery dauerhaft zu bespielen:

1. Boot-Parameter und Header verifizieren.
2. Einen 4.14.190-Kernel aus der LineageOS-Quelle bauen.
3. Ein Initramfs mit USB-Gadget bauen.
4. Ein `boot.img` packen und den Header pruefen.
5. Per `fastboot boot` starten und eine Shell ueber USB erreichen.

Spaeter erweitert:

- dauerhaftes Ubuntu auf `userdata` mit `switch_root`;
- wiederverwendbarer Installer;
- Rescue-Slot mit pstore-Observability;
- Mainline-Port (Linux 6.12) fuer ein aktuelles Ubuntu mit systemd/cgroup v2.

### 1.2 Abnahmekriterien Produktivpfad

| Kriterium | Status | Beleg |
|---|---|---|
| Header/Adressen verifiziert | **PASS** | STATUS §4.3, `ARTIFACTS.md` |
| Kernel 4.14.190 gebaut | **PASS** | `Image.gz` 13.356.663 B, 0 Errors |
| Initramfs erzeugt | **PASS** | BusyBox/NCM/DHCP/SSH |
| Boot-Image gepackt + Header geprueft | **PASS** | v2/4096, DTB 393.031 |
| `fastboot boot` + Shell ueber USB | **PASS** | Stock **und** Eigenbau |
| Ubuntu bootet von `userdata` | **PASS** | 22.04.5, `/dev/sdb24` |
| Installer end-to-end | **PASS** | inkl. Reinstall |
| Panic-Roundtrip ueber pstore | **PASS** | sysrq-Crash + Rescue |
| Mainline 6.12 bootet | **FAIL/BLOCKED** | DTB-/Observability-Blocker |

### 1.3 Nicht-Ziele / ausgeschlossen

- Kamera und Mobilfunk (vom Nutzer explizit ausgeklammert).
- Display-Initialisierung im Produktivpfad (Bootloader-Logo bleibt).
- Remote-/Online-Interaktion mit dem Geraet ausserhalb des lokalen USB-Pfads.
- Flashen von `boot_a`/Recovery ohne Einzelfreigabe.

---

## 2. Zielidentitaet und Geraet

### 2.1 Geraet

| Merkmal | Wert |
|---|---|
| Modell | Motorola Moto G9 Plus, XT2087-2 |
| Codename | `odessa` |
| SoC | Qualcomm SM6150 / Snapdragon 675 / `sdmmagpie` |
| RAM | 4 GB |
| Seriennummer | ZY227VHMSS |
| Android | LineageOS 20.0-20231120-UNOFFICIAL-odessa |
| Kernel | 4.14.190-perf+ (Stock: `deerfox@redstone`, #3, 2023-11-19) |
| Bootloader | MBM-3.0-odessa_retail-e69c40c38d6-220818 |
| Zustand | unlocked (`verifiedbootstate=orange`, `flash.locked=0`) |

### 2.2 Partitionen (aus `partitions.txt`, geraeteseitig bestaetigt)

| Name | Blockdev | Groesse / Rolle |
|---|---|---|
| `boot_a` | `/dev/block/sde21` | 64 MiB, Stock-Android-Boot |
| `boot_b` | `/dev/block/sdf21` | 64 MiB, Rescue-Prep (von uns geflasht) |
| `recovery_a` | `/dev/block/sde22` | 64 MiB, Lineage-Recovery |
| `recovery_b` | `/dev/block/sdf22` | 64 MiB, Lineage-Recovery |
| `userdata` | `/dev/block/sdb24` | 116.995.371.008 B (~109 GiB), Ubuntu |
| `misc` | `/dev/block/sdb4` | 1 MiB, BCB; Testeintrag `bootonce-bootloader` wurde vom Bootloader ignoriert, erste 64 B aktuell genullt |

Das Beschreiben von `sdb24` beruehrt weder Boot- noch Recovery-Partitionen.
`boot_a` wurde nie geflasht.

### 2.3 Boot-Header des Stock-Images (eigenes Parsing)

```
magic=ANDROID!  kernel_size=35493904  kernel_addr=0x8000
ramdisk_size=2797028  ramdisk_addr=0x1000000  second_size=0
tags_addr=0x100  page=4096  header_version=2
dtb_size=393031  dtb_addr=0x1f00000  base=0
```

Alle eigenen Images verwenden exakt diese Parameter.

---

## 3. Umgebung, Regeln und Grenzen

- Host: 32 CPUs, 30 GB RAM, 341 GB frei; Builds mit **maximal `-j12`** und
  `nice -n 10` (Nutzerauflage), `ionice -c3` wenn verfuegbar.
- Container teilt das Host-Netz, hat aber **kein `CAP_NET_ADMIN`** (nur
  `CAP_NET_RAW`). Die Host-IP muss der Nutzer setzen; DHCP loest das im
  Normalfall.
- Container-`/dev/bus/usb` ist ein statisches tmpfs; die Device-cgroup erlaubt
  nur Minor 23. **`fastboot` laeuft daher auf dem Host**, `adb` im laufenden
  Android/Recovery.
- Keine Remote-/Login-Interaktion; nur lokale Artefakte und das Geraet am
  USB-Kabel.
- Originale unter `/workspace/firmeware/` bleiben unveraendert.
- Abgeleitete Artefakte unter `/workspace/work/odessa/` und im persistenten
  Dist-Bundle `re-tools/_scratch/odessa/dist/`.
- Dokumentation unter `docs/re/<RUN_ID>/`; Spokes schreiben eigene Notizen.
- Private SSH-Key: `re-tools/_scratch/odessa/id_ed25519` (Mode 600), **nicht**
  in der Doku kopiert. Public Key im RootFS und im Dist-Bundle.

Werkzeug-Installationen (alle persistent unter `re-tools/`, kein `/usr`/`/opt`):

- AOSP clang r450784d (14.0.6), LLD 14.0.6, aarch64-binutils 2.40.
- Debian-bookworm-Hosttools: bc, bison, flex, m4, cpio, dtc, libfdt.
- mkbootimg/unpack_bootimg (AOSP), BusyBox 1.35.0 (arm64 + amd64).
- Dropbear 2026.94 (statisch, aarch64), e2fsprogs 1.47.4 (statisch, aarch64).

Bekannte Build-Umgebungs-Fixes (dokumentiert, damit reproduzierbar):

1. **m4:** Das Debian-`bison` hat `/usr/bin/m4` fest einkompiliert; im Container
   fehlte es. Container-lokaler Symlink `/usr/bin/m4 -> re-tools/bin/m4`.
2. **Bison-Datadir:** `BISON_PKGDATADIR=re-tools/build/t2-root/usr/share/bison`.
3. **OpenSSL (4.14):** `sign-file`/`extract-cert` brauchen Header/Libs;
   `HOSTCFLAGS=-I/srv/miniconda3/include`,
   `HOSTLOADLIBES_sign-file/extract-cert="-lcrypto -L/srv/miniconda3/lib -Wl,-rpath,/srv/miniconda3/lib"`.
   In 4.14 ist `HOSTLOADLIBES_*` korrekt.
4. **OpenSSL (6.12):** dort heisst die Variable `HOSTLDLIBS_*` (nicht
   `HOSTLOADLIBES_*`); `CONFIG_MODULE_SIG` wurde deaktiviert.
5. **6.12-Hostbuild:** `CONFIG_SYSTEM_TRUSTED_KEYRING=y` erzwingt weiterhin
   `extract-cert`; daher bleiben `HOSTCFLAGS`/`HOSTLDLIBS` noetig.

---

## 4. Chronologie und Ergebnisse

Zeiten sind UTC und stammen aus den Memory-/Dateizeitstempeln; sie sind
naeherungsweise, nicht sekundengenau.

| Zeit | Task | Ergebnis |
|---|---|---|
| 13:58 | HUB-RUN | Run angelegt, Boot-Header/Geraet verifiziert |
| 13:59-14:05 | T2 Toolchain + Kernel-Quelle | installiert, Commit `112b525a` |
| 14:06-14:10 | T3 Kernel 4.14.190 | `Image.gz` gebaut |
| 14:04-14:32 | T4/T5 Initramfs + Images | v1, Stock-/Eigenbau-Image |
| 14:54 | T6a Stock-Smoke-Test | **bestanden** |
| 15:04 | T6b Eigenbau-Kernel | **bestanden** |
| 15:14-15:36 | T8/T9 v2-Haertung | DHCP + SSH **bestanden** |
| 15:39-15:43 | T10 e2fsprogs | statisch aarch64 geliefert |
| 15:44-15:53 | T11/T12 Ubuntu-RootFS | **bootet** |
| 16:34-16:45 | Installer/Reinstall | **bestanden** |
| 16:38-17:03 | M0 Mainline 6.12 | Kernel baut |
| 16:42 | T14 Observability | pstore + Framebuffer analysiert |
| 16:56 | T15 Rescue/Panic | **bestanden** |
| 17:03-17:24 | Mainline-/DTB-Experimente | **alle fehlgeschlagen** |
| 17:28 | Option D | Rechercheauftrag formuliert |
| 17:43-17:46 | DTB/DTBO-Verifikation | Live-IDs, Overlay-Struktur, neue Testimages |

### 4.1 T2 — Toolchain und Kernel-Quelle

- Kernel: `github.com/LineageOS/android_kernel_motorola_sm6150`, Commit
  `112b525abbc08298256abedbf984e0e8c20d0338` (2023-11-04), Makefile 4.14.190.
- Config aus `firmeware/running_kernel.config`, `olddefconfig`, dann
  `CONFIG_DEVTMPFS=y` + `CONFIG_DEVTMPFS_MOUNT=y`.
- Nebenbefund: `olddefconfig` entfernte `CONFIG_CROSS_COMPILE_ARM32`,
  `CONFIG_WIREGUARD(+_DEBUG)` und `CONFIG_KSU(+_DEBUG)`. Die Stock-ROM wurde
  also aus einer KSU+WireGuard-gepatchten Variante gebaut; fuer unser Ziel
  ohne Belang.
- Spoke-Doku: `software-manager/T2-TOOLCHAIN.md`, `T3-KERNEL-BUILD.md`.

### 4.2 T3 — Kernel 4.14.190

- `build/arch/arm64/boot/Image.gz`, **13.356.663 B**,
  SHA256 `d13437cbe1244aa5e306544a57643e2764dcd4b3135a4a142bf44e1193f6245d`.
- gzip OK, entpackt 35.489.808 B, 0 Errors, 1 Warnung (`blk-mq.c`,
  align mismatch, bootpfad-irrelevant).
- Kernelrelease `4.14.190-perf+`; Tree danach clean.

### 4.3 T4/T5 — Initramfs v1 und erste Boot-Images

Initramfs v1 (988.877 B, `75976691…7f62`):

- BusyBox 1.35.0 statisch aarch64, NCM-Gadget `usb0`,
  `172.16.42.1/24`, `telnetd` auf Port 23.
- Init mountet proc/sys/configfs, legt Device-Nodes an, bindet die erste UDC.
- Kein DHCP, kein SSH in v1.

Images:

- `test-boot-stock.img` (36.884.480 B): Stock-Kernel + Stock-DTB + unser
  Initramfs.
- `test-boot-414190.img` (14.745.600 B): eigener Kernel + Stock-DTB +
  Initramfs.
- Header jeweils `ANDROID!`, v2, 4096, Adressen wie Stock, DTB 393.031.

### 4.4 T6a — Stock-Kernel-Smoke-Test: BESTANDEN

Ablauf: `fastboot boot test-boot-stock.img` (Sending 36.020 KB OKAY,
Booting OKAY ~11 s). Danach:

- USB: `1d6b:0104 "odessa usb gadget"`, Host-Interface `enx42dfd960260b`.
- ARP `172.16.42.1 -> 7a:c7:c2:65:5f:cd`; `ping` 3/3, 0 % Loss,
  1,7-3,4 ms.
- Telnet 23: BusyBox-ash als `uid=0(root)`.
- `uname -r` = `4.14.190-perf+`; `/proc/version` = Stock-Build
  `#3 SMP PREEMPT Sun Nov 19 22:36:49 -05 2023 deerfox@redstone`.

Damit bewiesen: Initramfs, NCM-Gadget, IP-Konfiguration und Host-Pfad
funktionieren; der Stock-Kernel ist ein vollwertiger Fallback.

Nebenbefunde:

- Host-NetworkManager entfernt manuell gesetzte IP beim Link-Reset
  (`nmcli device set <if> managed no`).
- Container ohne `CAP_NET_ADMIN`; IP setzt der Nutzer auf dem Host.
- Container-USB-cgroup erlaubt nur Minor 23; neue `adb`/`fastboot`-devnums
  sind nicht erreichbar.
- Reboot aus der Telnet-Shell (`reboot -f`) funktioniert (devnum 25 -> 26,
  `22b8:2e81`).

### 4.5 T6b — Eigener Kernel: BESTANDEN

`fastboot boot test-boot-414190.img` (Host). Geraet enumerierte als
`1d6b:0104`, neue MAC -> Host-Interface `enx7a78299354bc`. Nach Setzen von
`172.16.42.2/24`:

```
uname -r        -> 4.14.190-perf+
/proc/version   -> Linux version 4.14.190-perf+ (zero@ZeroCore)
                   ... #1 SMP PREEMPT Fri Nov 6 14:29:24 UTC 2026
id              -> uid=0(root)
ls /dev | wc -l -> 330
mount           -> devtmpfs on /dev; configfs on /sys/kernel/config
```

Bewiesen: Der selbstgebaute Kernel laeuft (Build 2026, nicht Stock 2023),
`CONFIG_DEVTMPFS=y` wirkt, Initramfs/Gadget/telnetd funktionieren identisch.

### 4.6 T8/T9 — Haertung v2: DHCP + SSH: BESTANDEN

- MAC via configfs **nicht moeglich** in diesem 4.14-Tree: Der Store-Handler
  verlangt `bound==true && refcnt==0`, mit configfs-Link unerreichbar
  (`-EBUSY`, live reproduziert). Geraete-MAC per
  `ip link set usb0 address a6:00:00:00:00:02`; Host-MAC bleibt zufaellig ->
  Interface-Name wechselt, DHCP loest das.
- BusyBox `udhcpd` auf `usb0`, Pool `172.16.42.10-20`, Router/DNS
  `172.16.42.1`.
- Dropbear 2026.94 statisch aarch64, key-only (Password-Auth im Build aus,
  kein libcrypt in bookworm main).
- Init loggt nach `/dev/kmsg`; Telnet bleibt Fallback.

Verifikation:

- Host-Interface `enxda6b31684853` (neue Zufalls-MAC), DHCP automatisch:
  `inet 172.16.42.15/24 ... dynamic`.
- `ping` 2/2, 1,69 ms.
- SSH key-only: `uid=0(root)`, `uname -r` 4.14.190-perf+,
  `/proc/version` eigener Build, Banner `SSH-2.0-dropbear_2026.94`.
- `dmesg`: `bound UDC a600000.dwc3`, `udhcpd started`,
  `host key generated`, `dropbear started on :22`, `telnetd started on :23`,
  `init done`.

Artefakt: `test-boot-414190-v2.img` 15.761.408 B,
`77daedc9…8c01`; Initramfs 2.003.054 B (`ffa05948…0a41`).

### 4.7 T10/T11 — e2fsprogs und Ubuntu-RootFS

- `partitions.txt`: `userdata -> sdb24` (116.995.371.008 B);
  `recovery_a/b` und `boot_a` separat -> Formatieren von `sdb24` ist
  unkritisch fuer Boot/Recovery.
- Statisches aarch64-e2fsprogs 1.47.4 (`mke2fs`, `tune2fs`, `dumpe2fs`) aus
  `mirrors.edge.kernel.org` (Tarball-SHA256 geprueft, GPG nicht verifiziert,
  kein Key lokal). Defaults enthalten `filetype` + `metadata_csum`, geeignet
  fuer Docker/overlay2.
- Ubuntu-Base **22.04.5** arm64 von `cdimage.ubuntu.com`, SHA256
  `075d4abd…979f` gegen `SHA256SUMS` geprueft.
- **24.04/26.04 bewusst verworfen:** deren systemd verlangt einen neueren
  Kernel als 4.14 (Upstream-Mindestanforderung; je nach systemd-Version
  4.15/5.x). Die 26.04.1-Base wurde zwar
  geladen (`5a190679…19fd`), aber nicht verwendet.
- Das Base-Image ist ein **Container-RootFS ohne Init** (kein systemd, kein
  `/sbin/init`). Deshalb eigenes BusyBox-`/sbin/init` eingebaut; systemd kann
  spaeter per `apt` nachgezogen werden (Kompatibilitaet der 22.04-Version mit
  4.14 nicht verifiziert).

Konfiguriertes RootFS (`scripts/prepare-rootfs.sh`, idempotent):

- Hostname `odessa`; Dropbear key-only; `authorized_keys` aus
  `id_ed25519.pub`.
- `/usr/local/sbin/usb-gadget.sh`: configfs-NCM, UDC `a600000.dwc3`,
  MAC `a6:00:00:00:00:02`, `172.16.42.1/24`, `udhcpd` Pool `.10-.20`.
- `/usr/local/sbin/battery-guard.sh`: 55/60-Hysterese auf
  `capacity`/`battery_charging_enabled`; das BusyBox-`/sbin/init` ruft es
  alle 30 s auf. Die systemd-Units (`usb-gadget.service`,
  `dropbear.service`, `battery-guard.{service,timer}`) liegen fuer einen
  spaeteren systemd-Betrieb bereit, laufen aber derzeit nicht.
- Kein systemd-networkd in der Base -> statisches BusyBox-`ip`/`udhcpd`.
- Marker `/etc/odessa-ready`.
- Groesse: ~86 MB im RootFS, 79 MB als `rootfs.tar`; Label `odessa`.

### 4.8 T12 — Ubuntu bootet: BESTANDEN

Boot mit `odessa.boot=ubuntu`; Initramfs mountet `sdb24`, haengt nested
Mounts ab, `switch_root`. Verifikation:

```
PRETTY_NAME="Ubuntu 22.04.5 LTS"
uname -r   -> 4.14.190-perf+
PID 1      -> /bin/sh /sbin/init
mount      -> /dev/sdb24 on / type ext4 (rw,noatime,data=ordered)
DHCP       -> Host enx922c08e4c459: inet 172.16.42.18/24
ssh        -> root@172.16.42.1, key-only
Akku       -> capacity=48, battery_charging_enabled=1
```

Wichtige Stolpersteine:

- BusyBox-ash preempts Applet-Namen im PATH -> `/sbin/mke2fs` absolut
  aufrufen.
- Ubuntu-Base hat kein `/sbin/reboot` -> `busybox reboot -f`.
- Initramfs v3 (3.765.922 B, `b4f6e19a…b833`) enthaelt `mke2fs`/`tune2fs`/
  `dumpe2fs` und die `switch_root`-Logik, gated durch
  `odessa.boot=ubuntu` **und** `/etc/odessa-ready`.

### 4.9 Installer und Reinstall-Test: BESTANDEN

Skripte unter `/workspace/work/odessa/scripts/`:

- `build-all.sh`, `build-kernel.sh`, `build-initramfs.sh`,
  `pack-images.sh`, `build-rootfs.sh`, `prepare-rootfs.sh`,
  `install-to-device.sh`, `build-image.sh` (Einzelbau).

Ablauf des Reinstall-Tests:

1. Prep-Image gebootet; `./scripts/install-to-device.sh out/rootfs.tar --yes`
   -> `mke2fs`, mount, 79 MB Tar-Stream, Marker, `INSTALL_OK`.
2. Zwischenfall: Nutzer waehlte im Android-Menue versehentlich
   „format user data“ -> `sdb24` ohne Filesystem-Signatur.
3. Installer erneut ausgefuehrt -> wieder `INSTALL_OK`.
4. Ubuntu gebootet: 22.04.5, `/dev/sdb24 / ext4 rw,noatime`,
   Label `odessa`, Marker vorhanden, PID 1 `/bin/sh /sbin/init`,
   Dropbear laeuft, DHCP `172.16.42.17/24`.
5. FS-UUID nach Reinstall: `d2342002-35b1-48ae-9228-910e3e5dc86a`
   (erster Install davor: `b4cce24a…`).

Damit ist der Installer end-to-end getestet und idempotent (formatiert neu).

### 4.10 T15 — Rescue-Slot b und Panic-Roundtrip: BESTANDEN

Aufbau:

- Prep-Image nach `boot_b` (`/dev/block/sdf21`, 64 MiB) geflasht,
  `set_active b`; `boot_a` unveraendert.
- Auto-Boot landet direkt im Initramfs (`slot_suffix=_b`), ohne Android.

Test:

1. Prep bootet aus Slot b.
2. `echo c > /proc/sysrq-trigger` -> kontrollierter Panic.
3. Geraet rebootet, bootet wieder Slot b.
4. pstore-Dump in `/tmp`:
   - `console-ramoops-0` (42.771 B), Zeile 255:
     `Kernel panic - not syncing: sysrq triggered crash`;
     Tail: `Rebooting in 5 seconds.. Going down for restart now`.
   - `dmesg-ramoops-0` (109.227 B): vollstaendiger Panic-Record.
5. SSH nach Reboot sofort wieder da.

=> Post-Mortem-Kanal ohne Timing, Tastendruck oder Android dazwischen.
Rueckweg: `fastboot set_active a`.

### 4.11 T14 — Observability-Analyse (pstore + Framebuffer)

**pstore/ramoops @ `0xaf000000`:**

- Im Moto-Downstream-Tree als reserviert definiert (`moto-mem-reserve.h`),
  vom Vendor-Kernel als pstore genutzt: console `0x40000`,
  pmsg `0x40000`, record `0x3f800`, Gesamt `0xbf800`.
- Unser 4.14-Kernel: `PSTORE=y`, `CONSOLE=y`, `PMSG=y`, `RAM=y`.
- Live: `mount -t pstore pstore /sys/fs/pstore` ->
  `console-ramoops-0` (19.604 B) + `pmsg-ramoops-0` (67.346 B) mit Logs
  frueherer Boots; dmesg: `Registered ramoops as persistent store backend`.
- Grenze: Ringpuffer wird von spaeteren Boots ueberschrieben/vermischt; der
  Panic-Text steht am Ende.

**simple-framebuffer @ `0x9c000000`:**

- `cont_splash_region`, Groesse `0x1700000`; diese Region wird vom
  Bootloader fuer den Splash (Moto-Logo) genutzt.
- Mainline-Praezedenz mit identischer Basisadresse:
  `sm8150-sony-xperia-kumano.dtsi` (`framebuffer@9c000000`,
  `simple-framebuffer`).
- Parameter: 1080x2400, stride 4320, `a8r8g8b8`.
- Mit `DRM_SIMPLEDRM` + `FRAMEBUFFER_CONSOLE` waere eine Live-Konsole moeglich
  — im Mainline-Test bisher **nicht** erreicht.

**Weitere Optionen:** UART-Testpads (Hardware, bester Kanal),
Vibrator-Heartbeat (setzt SPMI voraus).

Wichtiger beobachteter Nebenbefund aus dem Recovery-Boot:

```
OF: reserved mem: OVERLAP DETECTED!
disp_rdump_region@9c000000 ... overlaps with cont_splash_region@9c000000
pstore: allocate compression buffer error!
```

Das ist ein Log des **Recovery-Boots** (Vendor-Kernel), nicht unseres
Mainline-Tests. Es zeigt, dass der Recovery-Kernel den Ramoops-Puffer
beschreibt und damit alte Eintraege ueberschreiben kann. Aktueller
Recovery-Boot (2026-11-06): `console-ramoops-0` 50.311 B,
`pmsg-ramoops-0` 172.158 B; `grep` nach `Linux version`/`Booting Linux`
liefert keinen 6.12- oder 4.14-Testmarker, der Tail zeigt den
Recovery-Boot (`init: Rebooting into recovery`, `reboot: Restarting system
with command 'recovery'`).

### 4.12 M0 — Mainline Linux 6.12: Build erfolgreich, Boot blockiert

Quelle: Linux **6.12.0** (Tarball 147.906.904 B,
`b1a2562b…25eb`), extrahiert nach
`/workspace/work/odessa/mainline/linux-6.12/`.

Minimaler DTS-Satz:

- `sm6150.dtsi` (93 Zeilen): 8 CPUs (6x Cortex-A55, 2x Cortex-A76),
  PSCI 1.0 `smc`, GICv3 `0x17a00000` (GICD `0x10000`) +
  `0x17a60000` (GICR `0x100000`, Stride `0x20000`), ARMv8-Timer.
- `sm6150-moto-odessa.dts`: Modell, `compatible`
  `qcom,sm6150-moto-odessa`/`qcom,sdmmagpie`/`qcom,sm6150`,
  Vendor-IDs `qcom,msm-id = <0x16d 0x00>`, `qcom,board-id = <0 0>`,
  6 Memory-Ranges aus `/proc/iomem`, `reserved-memory` fuer
  Framebuffer (`0x9c000000`, `0x1700000`) und Ramoops (`0xaf000000`,
  `0xbf800`), `simple-framebuffer` 1080x2400/stride 4320/`a8r8g8b8`.
- DTB: 2.763 B, `e276c0a5…d61e`.

Kernel: `Image.gz` **14.686.906 B**, `3f8d9299…fdb7`; Config u. a.
`ARCH_QCOM=y`, `PSTORE*`, `DRM`, `DRM_SIMPLEDRM`, `FRAMEBUFFER_CONSOLE`,
`FONT_8x16`, `FONT_TER16x32`; `MODULE_SIG` aus,
`SYSTEM_TRUSTED_KEYRING=y`.

Build-Fehlschlaege und Fixes:

1. `bison: m4 subprocess failed` -> `/usr/bin/m4` fehlte; Symlink auf
   `re-tools/bin/m4`; zusaetzlich `BISON_PKGDATADIR`.
2. `openssl/bio.h: No such file` -> `HOSTCFLAGS=-I/srv/miniconda3/include`.
3. `cannot find -lcrypto` -> `HOSTLDLIBS_extract-cert`/`_sign-file` mit
   `-L/srv/miniconda3/lib -Wl,-rpath,...`.
4. Falscher Variablenname `HOSTLOADLIBES_` (4.14) vs. `HOSTLDLIBS_` (6.12)
   -> mit `HOSTLDLIBS_` erfolgreich.

### 4.13 DTB-Experimente: alle fehlgeschlagen

| # | Image | Kernel | DTB | Beobachtung |
|---|---|---|---|---|
| 1 | `test-boot-414190.img` | 4.14 | Original | **bootet**, SSH (Kontrolle) |
| 2 | `test-boot-mainline-m0.img` | 6.12 | eigenes Minimal-DTB | Moto-Logo -> Display aus -> Fastboot; kein fbcon |
| 3 | `test-boot-mainline-stockdtb.img` | 6.12 | Original | Fallback/Rescue; **kein 6.12-Log** im pstore |
| 4 | `test-boot-414190-mydtb.img` | 4.14 | eigenes Minimal-DTB (ohne Vendor-IDs) | landet im Fastboot |
| 5 | `test-boot-414190-mydtb2.img` | 4.14 | eigenes + `qcom,msm-id`/`board-id` | landet in Lineage-Recovery |
| 6 | `test-boot-414190-stockfb.img` | 4.14 | rekompiliertes Stock-DTB + fb, ohne Padding | 2 Reboots -> Recovery |
| 7 | `test-boot-414190-stockfb2.img` | 4.14 | wie #6, `dtc -p 4096` | Fastboot -> Moto-Logo -> Reboot -> Moto-Logo -> Reboot -> Recovery |

Beobachtungen und Grenzen:

- **Wichtig (ABL-Logs cycles 626–637):** Die beobachteten „2 Reboots" und
  die „Boot-Loop" von `explicit` waren **ABL-Fehler**, nicht Kernel-Panics:
  Zyklus 627 `ERROR: NO ACTIVE SLOT FOUND` (stockbin, gar nicht gebootet);
  Zyklen 628–634 `Dtbo hdr magic mismatch 0` -> `BootLinux() failed:
  Not Found` (genulltes `dtbo_a`). Der `kernel_panic`-Eintrag in LOG87 ist
  Zyklus 599 und aelter. §4.17 dokumentiert die Details.
- **Original-DTB funktioniert** mit 4.14 zuverlaessig.
- **Jedes im Test modifizierte/rekompilierte DTB wurde abgelehnt**; das
  schliesst semantisch identische Rekompilierung ein.
- Padding ist **nicht** die Ursache: 392.198 B (ohne) und 396.294 B (mit
  `-p 4096`) scheiterten beide; bestehende Root-Properties, Vendor-IDs und
  1.222 Phandles blieben gleich.
- `qcom,msm-id = <0x16d 0x00>` + `qcom,board-id = <0x00 0x00>` allein
  genuegen nicht.
- Stock-DTB enthaelt einen **leeren** `/memory`-Knoten (`reg = <0 0 0 0>`),
  den ABL beim Boot mit den DDR-Ranges fuellt (live: `0x80000000+2G`,
  `0x100000000+~2G`). **Kein** `ramoops`-Knoten im Stock-DTB; der kommt aus
  DTBO-Entry 2 (`fragment@28`, `ramoops_mem`) — lokal verifiziert.
- Bei den 4.14-Tests #4/#5 war im pstore **kein** 4.14-„Booting Linux“ zu
  finden; fuer #6/#7 wurde pstore nach dem Fehlschlag nicht mehr ausgelesen.
  Der anschliessende Recovery-Boot kann den Ringpuffer ohnehin ueberschrieben
  haben. Die Reboot-/Recovery-Beobachtung ist belastbar, die Aussage „Kernel
  kam nie bis pstore“ ist es **nicht** vollstaendig.
- Bei #2/#3 gilt derselbe Caveat: kein 6.12-Text im Snapshot, aber moegliche
  Ueberschreibung durch den Recovery-Boot.

Fazit: Zwei getrennte Probleme — (a) ABL akzeptiert kein selbstgebautes DTB,
(b) Mainline liefert ohne Original-DTB-Kontext keinen sichtbaren Output. Ohne
UART ist (b) nicht sauber diagnosefaehig.

### 4.14 `misc`-Trick: ignoriert

Aus dem Rescue wurde einmalig `bootonce-bootloader` an Offset 0 von
`/dev/sdb4` geschrieben und `reboot -f` ausgeloest. Das Geraet kam als
USB-Gadget (`1d6b:0104`) zurueck, nicht im Fastboot -> **Motorolas ABL
ignoriert den BCB-String**. Verifiziert am 2026-11-06: Die ersten 64 Byte von
`misc` sind wieder komplett 0; es bleibt kein Eintrag zurueck. Kein
Aufraeumschritt noetig.

### 4.15 Option D — externe Recherche

Der Nutzer recherchiert extern (Gemini + eigene Suche). Der vollstaendige
Prompt und die Suchliste stehen in `RESEARCH-mainline-sm6150.md`. Kernfragen:

1. Gibt es irgendein oeffentliches Mainline-Projekt fuer SM6150/`sdmmagpie`?
2. Wie behandelt ABL DTB + DTBO-Overlay? Warum wird ein rekompiliertes,
   semantisch gleiches DTB abgelehnt?
3. Gibt es einen unterstuetzten Weg, ein eigenes DTB per `fastboot boot`
   durchzureichen (oder den Overlay-Merge zu ueberspringen)?
4. Gibt es 4.19/5.4/5.10-Vendor-Trees von SM6150-Schwestergeraeten?
5. Wie debuggt man fruehen ARM64-Qualcomm-Boot ohne UART?
6. Gibt es dokumentierte 6.x-Mainline-Boots auf SM6150?

Bereits lokal geprueft (nicht extern): Kein `sm6150.dtsi` in
`torvalds/linux` oder `linux-msm`; naechste Verwandte `sdm670`, `sm6115`,
`sm6125`, `sm7125`; PM6150/PM6150L-Regulatoren, `pinctrl-sdm670`,
`ufs-qcom`, `dwc3`, `qusb2/qmp-phy`, `rpmh/scm/smem` vorhanden;
`gcc-sdm670` laeuft ueber `gcc-sdm845.c`; SM6150-GCC-IDs und Interconnect
fehlen. postmarketOS `odessa` nutzt nur Downstream 4.14.117.

### 4.16 Dokumentationskonsolidierung (dieser Stand)

- `STATUS.md` neu strukturiert und um Mainline-/DTB-Experimente,
  Ist-Zustand, Hypothesen und Artefakte ergaenzt.
- `ARTIFACTS.md` mit allen Groessen/Hashes angelegt.
- `RUNBOOK-boot-test.md` auf Rescue-/Ubuntu-/pstore-/DTB-Stand gebracht.
- `RESEARCH-mainline-sm6150.md` mit Gemini-Prompt und Suchliste angelegt.
- `/workspace/work/odessa/README.md` auf den aktuellen Stand gebracht.
- Dist-Bundle-README aktualisiert (Kopie).
- Keine neuen Geraeteaenderungen; nur Lesezugriffe (Slot-Header, Akku,
  pstore-Liste).

### 4.17 DTB/DTBO-Verifikation (2026-11-06, lokal)

Anlass: externe Recherche des Nutzers (SM6150-Mainline, ABL/DTBO-Verhalten).
Die lokal pruefbaren Aussagen wurden gegen Stock-DTB, DTBO-Image und den
Live-Tree in Recovery geprueft; externe Behauptungen bleiben als
`EXTERNAL_UNVERIFIED` markiert.

**Lokal bestaetigt:**

- Das Stock-DTB ist **ein** FDT (393.031 B, genau ein `0xd00dfeed`-Magic),
  keine concatenated Multi-DTB-Tabelle.
- Stock-DTB: **1.279 `__symbols__`-Eintraege**, **leerer** `/memory`-Knoten
  (`reg = <0 0 0 0>`), **kein** `qcom,pmic-id`, **kein** `ramoops`.
  GIC/Timer/PSCI sind mainline-kompatibel: `arm,gic-v3`,
  `arm,armv8-timer`, `arm,psci-1.0`.
- Live `/proc/device-tree` (Recovery): `qcom,msm-id = <0x16d 0x00>`,
  `qcom,board-id = <0x49 0xc000>`, `qcom,msm-name = "SDMMAGPIE"`,
  **kein** `qcom,pmic-id`; `/memory` hat zwei Ranges
  (`0x80000000+2G`, `0x100000000+~2G`); `reserved-memory/ramoops_mem`
  vorhanden; `__symbols__` 1.280 Eintraege.
- DTBO (`stock_dtbo.img`, 25.165.824 B): 3 Entries; Entry 2 hat
  `qcom,board-id = <0x49 0xc000>` und matcht den aktiven Slot
  (`androidboot.dtbo_idx=2`). Entry 2 enthaelt **104 Fragments** und
  **190 Symbol-Fixups** gegen den vollen Vendor-Base-Tree; `fragment@28`
  definiert `ramoops_mem`.
- Unser bisheriges Minimal-DTB: **0 `__symbols__`**, `qcom,board-id =
  <0x00 0x00>`. Es kann den 104-Fragment-/190-Fixup-Merge nicht erfuellen.
  Die `__symbols__`-Beobachtung ist damit richtig, aber nicht die alleinige
  Ursache.
- Linux **6.12.0** lokal enthaelt **kein** upstream `qcs615.dtsi` oder
  `sm6150.dtsi`; vorhanden ist nur unser selbstgebautes Minimal-DTS.
  Die 6.16+-Talos/SM6150-Behauptung ist lokal **nicht verifizierbar**.
- Extern (Nutzerangabe, **nicht lokal verifiziert**): Der QCS615-DTSI-Patch
  ging am 2024-10-22 auf die LKML und ist erst ab Linux 6.13 im Tree; in
  6.12.0 kann er daher nicht enthalten sein. Das deckt sich mit dem lokalen
  Befund.

**Als extern/unverified markiert:** Upstream-Rename-Commits
(`qcs615` -> `sm6150` -> `talos`), `sm7150-mainline`-Projekte,
`samsung-a70q`-Mainline, U-Boot-Chainload, 4.19/5.4/5.10-Vendor-Trees,
`fastboot erase dtbo`-Verhalten. Diese Punkte sind plausible Leads, aber
nicht durch lokale Artefakte belegt.

**Neu gebaute Testartefakte (nicht geflasht):**

| Artefakt | Groesse | SHA256 (Kurz) | Zweck |
|---|---:|---|---|
| `out/test-boot-mainline-stockbin.img` | 18.870.272 | `c188048a…90b` | Stock-DTB binaer gepatcht (fb), **dtbo_a aktiv** |
| `out/test-boot-414190-stockbin-dtb.img` | 17.539.072 | `81d74708…240` | 4.14-Kernel + dasselbe gepatchte Stock-DTB (DTB-Kontrolle) |
| `out/test-boot-414190-stockbin-emptycmd.img` | 17.522.688 | `26e14836…708` | 4.14 + gepatchtes DTB, **leere Header-Cmdline** |
| `out/test-boot-414190-stockdtb-emptycmd.img` | 17.522.688 | `cdf72ce9…454` | 4.14 + Original-DTB, **leere Header-Cmdline** |
| `out/test-boot-mainline-stockbin-emptycmd.img` | 18.853.888 | `470480ec…f9f` | 6.12 + gepatchtes DTB, **leere Header-Cmdline** |
| `out/test-boot-mainline-stockdtb-emptycmd.img` | 18.853.888 | `7832c9d0…ea1` | 6.12 + Original-DTB, **leere Header-Cmdline** |
| `out/test-boot-mainline-stockbin-cmdline.img` | 18.853.888 | `155ca8e2…dd5` | 6.12 **Force-Cmdline** + gepatchtes DTB, leere Header-Cmdline |
| `out/test-boot-mainline-stockdtb-cmdline.img` | 18.853.888 | `665f7381…24e` | 6.12 **Force-Cmdline** + Original-DTB, leere Header-Cmdline |
| `out/test-boot-mainline-dtbo0-explicit-cmdline.img` | 18.472.960 | `0aa910d6…43c` | 6.12 Force-Cmdline + Minimal-DTB (Mini-DTBO-Pfad) |
| `out/test-boot-414190-pstore-ro.img` | 17.522.688 | `0bd606e1…3a6` | 4.14-Rescue, `PSTORE_CONSOLE` aus, liest 6.12-Log |
| `out/test-boot-mainline-stockdtb-usb2.img` | 19.009.536 | `bf0ac350…d66` | 6.12 USB2 + Original-DTB (kein fb) |
| `out/test-boot-mainline-stockbin-usb2-fb.img` | 19.009.536 | `2f859a3b…4a4` | 6.12 USB2 + gepatchtes DTB + fb memory-region |
| `out/test-boot-mainline-dtbo0-inject.img` | 18.472.960 | `4da01e72…c4a` | Minimal-DTB, leeres `/memory`, Board-ID live |
| `out/test-boot-mainline-dtbo0-explicit.img` | 18.472.960 | `aff4d8cb…d179` | Minimal-DTB, explizite Ranges |
| `out/test-boot-mainline-stockbase-dtbo0.img` | 18.862.080 | `6ebe5f71…a79` | voller Stock-Base-DTB, `-@`, leerer `/memory`, ramoops |
| `out/empty-dtbo-24MiB.img` | 25.165.824 | `95aeaae0…369` | genulltes `dtbo_a` — **von ABL verworfen** |
| `out/mini-dtbo-odessa.img` | 25.165.824 | `e455c919…e77` | valider DTBO-Header + No-Op-Overlay, ohne AVB |
| `out/mini-dtbo-avb.img` | 25.165.824 | `0fc5347b…30c` | wie oben, Stock-AVB-Footer/vbmeta erhalten |
| `out/stock-patched-fb.dtb` | 392.185 | `5ee940b0…697` | binaer gepatchtes Stock-DTB, 1.279 Symbole erhalten |
| `out/stock-patched-fb-pad.dtb` | 408.569 | `b0d4322e…538` | wie oben + 16 KiB FDT-Freiraum (im Testimage) |
| `out/stockbase-dtbo0.dtb` | 400.561 | `3fa9ba5d…747` | Stock-DTS + fb + ramoops, Board-ID live |
| `.../sm6150-moto-odessa-dtbo0-inject.dtb` | 10.823 | `a933751a…c51` | Minimal, ABL-Inject |
| `.../sm6150-moto-odessa-dtbo0-explicit.dtb` | 11.191 | `b21ef32a…921` | Minimal, explizit |

Zusatzpruefungen:

- `dtbo_a` und `dtbo_b` wurden read-only gelesen: die ersten 24 MiB sind
  **byte-identisch** mit `stock_dtbo.img` (`111c29e9…a3b`). Das Backup ist
  damit verifiziert.
- `qcom,pmic-id` ist **nirgends** vorhanden (Stock-DTB, alle DTBO-Entries,
  Live-Tree). Es wird bewusst nicht erfunden; die Abwesenheit entspricht
  exakt dem funktionierenden Stock-DTB.
- `model="odessa"` und `compatible="qcom,sdmmagpie"` sind jetzt exakt die
  Stock-Werte.
- `stock-patched-fb.dtb` wurde mit `fdtput` **binaer** erzeugt (kein
  Decompile-Roundtrip). Alle 1.279 `__symbols__`-Eintraege und die
  numerischen Phandles bleiben erhalten; alle 190 Fixup-Labels des
  DTBO-Entry 2 sind aufloesbar (lokal geprueft).

**ABL-Log-Auswertung (logfs cycles 626–637, 2026-11-06):**

- Zyklus 627 (`LOG01`): Der erste `stockbin`-Test wurde mit
  `ERROR: NO ACTIVE SLOT FOUND` / `FindBootableSlotMot: No valid slot to try`
  / `No bootable A/B slot` abgebrochen, **bevor** das Image bewertet wurde.
  Der Test ist daher **nicht** aussagekraeftig; die Slot-Metadaten waren an
  diesem Punkt beschaedigt.
- Zyklen 628–634 (`LOG02`–`LOG08`): Mit genulltem `dtbo_a` meldet ABL
  `Dtbo hdr magic mismatch 0, with D7B7AB1E`, dann
  `Error: Device Tree blob not found` und `BootLinux() failed: Not Found`.
  **Ein genulltes DTBO ist kein „skip", sondern ein harter Fehler.**
- Zyklus 635 (`LOG09`): `fastboot flash dtbo_a` (24 MiB, genullt) wird
  angenommen, aber ABL loggt `validate_vbmeta_info_in_tree: image dtbo salt
  expected/digest expected` und `erasing dtbo_a`; der Slot wird wieder auf
  `a` gesetzt.
- Zyklus 636 (`LOG10`): Mit wiederhergestelltem Stock-DTBO findet ABL
  `Best Board Dtb 0x16D/0x0/0x49/0xC000` und `Apply Overlay total time:
  98 ms`; der Recovery-Boot funktioniert.
- Der `kernel_panic`-Eintrag in `LOG87` ist **Zyklus 599** (aelter) und
  gehoert **nicht** zu dieser Testrunde. Die „Boot-Loop" von `explicit` war
  ABL-Retry nach `BootLinux() failed`, kein 6.12-Kernel-Panic.
- **Sauberer `stockbin`-Retest (Zyklus 652/655):** `set_active:a` war OK;
  `download:011ff000` (18.870.272 B = stockbin), `Decompressing kernel image`
  2625 ms, `Best Board Dtb 0x16D/0x0/0x49/0xC000`, `Apply Overlay 569 ms`,
  dann `disabling console`, `SKU: XT2087-2` und
  `DXE_ASSERT!: /localrepo/.../platform/boota (786):` mit anschliessendem
  `ResetSytem` (DataSize 0). **Kein `Update Device Tree`, kein
  `Shutting Down UEFI Boot Services`, kein Kernel-Entry.**
- **Prep-Kontrolle (Zyklus 656):** `download:010b6000` (17.522.688 B),
  `Apply Overlay 567 ms`, `Update Device Tree total time: 164 ms`,
  `Shutting Down UEFI Boot Services` -> Prep bootet. Der Unterschied ist
  also das 6.12-Image bzw. das binaer gepatchte Stock-DTB, nicht der
  Overlay-Merge.
- **pstore des Prep-Boots:** `console-ramoops-0` 19.604 B,
  `pmsg-ramoops-0` 107.048 B; **kein** `Linux version`/6.12-Marker. Der Tail
  ist ein Vendor-Android/Recovery-Boot, der mit
  `reboot: Restarting system with command 'bootloader'` endet. Es gibt
  **keinen 6.12-Panic-Record**.
- Slot-Status beim Retest: `current-slot: a`,
  `slot-successful:a: no`, `slot-unbootable:a: no`; `set_active a` wird
  akzeptiert. Der `NO ACTIVE SLOT`-Fehler vom ersten Versuch ist damit weg.

- **6.12 erreicht (2026-11-06):** Mit leerer Header-Cmdline bootet
  Test 2 (4.14 + gepatchtes DTB) und liefert SSH (`4.14.190-perf+`). Die
  Tests 3/4 (6.12 + gepatchtes/originales DTB, leere Cmdline) bleiben auf
  dem Moto-Logo, **ohne Reset**. Der pstore enthaelt danach ein
  **6.12-Log**: `Linux version 6.12 ... (zero@ZeroCore) #1 SMP PREEMPT`,
  `GICv3: 928 SPIs`, `GICv3: CPU0: found redistributor 0 ... 0x17a60000`,
  `OF: reserved mem: initialized node ramoops_mem`, `Unpacking initramfs`,
  `Freeing initrd memory: 3676K`, `Run /init as init process`. Es gibt eine
  Warnung `Failed to initialize '/soc/timer'`, der Boot laeuft aber weiter.
  Damit ist bestaetigt: **Die leere Header-Cmdline beseitigt den
  `boota (786)`-Assert; 6.12 erreicht Kernel und Initramfs.**
- Der 6.12-Log wurde beim anschliessenden 4.14-Boot teilweise
  ueberschrieben (garbled). Deshalb wurde der Read-only-pstore-Kernel
  `test-boot-414190-pstore-ro.img` gebaut (`PSTORE_CONSOLE`/`PMSG` aus),
  der den Log kopiert, ohne ihn neu zu beschreiben.
- Slot/`dtbo`: `dtbo_a`/`dtbo_b` sind Stock; `set_active a` funktioniert;
  `slot-successful:a=no`, `slot-unbootable:a=no`.
- **Vollstaendiger 6.12-Log (RO-Rescue):** Der Kernel erreicht
  `Run /init as init process`; das Initramfs kopiert pstore. Weitere
  Befunde: `simple-framebuffer` scheitert mit
  `could not acquire memory region [mem 0x9c000000-0x9c9e33ff]` und
  `probe ... failed with error -12` (Region ist `reserved-memory`);
  `arch_timer`/`/soc/timer` melden Fehler, der Boot laeuft aber weiter;
  `Memory: ~415 MB/4 GB available` (vendor reserved-memory gross);
  USB/PHY/UFS-Treiber waren nur `=m`. Details in §4.17/`ARTIFACTS.md`.
- **6.12-USB2/Display-Build:** `Image-6.12-usb2.gz` mit
  `SM_GCC_7150=y`, `PINCTRL_SM7150=y`, USB/PHY/UFS `=y`; DTB mit
  Mainline-Compatibles (`qcom,sm7150-gcc`, `qcom,sm7150-tlmm`,
  `qcom,dwc3`, `qcom,qusb2-v2-phy`) und `memory-region` fuer den
  Framebuffer. Testimages: `test-boot-mainline-stockdtb-usb2.img`,
  `test-boot-mainline-stockbin-usb2-fb.img`.
- **USB2-Test-Ergebnis:** **kein** `dwc3`/`qusb2`-Probe im 6.12-Log;
  `/init` meldet `no UDC found`. `simpledrm` bevorzugt zwar
  `memory-region`, aber `devm_memremap` warnt weiter
  (`memremap`-Calltrace); Display bleibt aus. Die Vendor-USB-Knoten
  passen trotz Compatible-Aenderung nicht zu den Mainline-Treibern
  (Clocks/Regulatoren/PHY-Layout).
- **Mini-DTBO-Test: ABL lehnt Custom-DTBO per AVB ab.** Logfs Zyklus 655:
  `SSM: dtbo_a image vbmeta ok`,
  `dtbo: Hash of data mismatch digest in descriptor. Image corrupted?`,
  `validate_vbmeta_info_in_tree: image dtbo salt expected.`,
  `validate_vbmeta_info_in_tree: image dtbo digest expected.`,
  `erasing dtbo_a`. Ein eigenes DTBO ist ohne Motorola-Signatur/Hash
  **nicht flashbar**; ABL loescht die Partition. Der Custom-DTBO-Pfad ist
  damit tot. Aktuell ist `dtbo_a` leer, deshalb fehlt das Stock-Overlay
  (ramoops) und der pstore-Dump. Naechster Pfad: Stock-DTBO
  wiederherstellen und ein **mainline USB-Nodeset in das Boot.img-DTB**
  (unsigned, Stock-Basis + Stock-Overlay) einbauen — oder U-Boot
  chainloaden.

**Korrigierte naechste Schritte:**

0. **6.12-Log sauber sichern:** Nach einem 6.12-Test (Logo bleibt, kein
   Reset) per Vol-Down/Power in Fastboot, dann
   `test-boot-414190-pstore-ro.img` booten. Dieser 4.14-Kernel hat
   `PSTORE_CONSOLE`/`PMSG` aus und kopiert den 6.12-Log nach `/tmp`,
   ohne ihn zu ueberschreiben. Danach `pstore-console-ramoops-0`
   vollstaendig auslesen.
1. **Cmdline-Hypothese testen (extern, Gemini):** Der `boota (786)`-Assert
   soll durch eine nicht-leere `--cmdline` im `boot.img`-Header ausgeloest
   werden. Neue Images mit **leerer Header-Cmdline** und Kernel-Args in
   `/chosen/bootargs` sind gebaut:
   `test-boot-414190-stockbin-emptycmd.img`,
   `test-boot-mainline-stockbin-emptycmd.img`,
   `test-boot-mainline-stockdtb-emptycmd.img`.
   Testreihenfolge:
   - **4.14 + gepatchtes DTB + leere Cmdline** zuerst. Bootet es, ist die
     Cmdline der Ausloeser und das DTB in Ordnung.
   - Dann **6.12 + gepatchtes DTB + leere Cmdline**.
   - Dann **6.12 + Original-DTB + leere Cmdline**.
   - Falls die 6.12-Varianten weiter asserten: **Force-Cmdline-Kernel**
     (`test-boot-mainline-stockbin-cmdline.img`,
     `test-boot-mainline-stockdtb-cmdline.img`) testen.
   Wenn alle drei weiter asserten, ist die Hypothese falsch; dann
   `CONFIG_CMDLINE` im 6.12-Kernel oder U-Boot-Pfad.
2. **Isolation 6.12 vs. gepatchtes DTB (alte Testreihe):**
   - `test-boot-mainline-stockdtb.img` (6.12 + **Original**-Stock-DTB) im
     sauberen Slot erneut testen. Wenn auch `boota (786)` assertet, ist das
     6.12-`Image.gz`/Boot-Protokoll der Ausloeser; wenn nicht, das gepatchte
     DTB.
   - Als DTB-Kontrolle `test-boot-414190-stockbin-dtb.img` (4.14-Kernel +
     dasselbe binaer gepatchte Stock-DTB) booten. Wenn das laeuft, ist das
     DTB bootloader-tauglich.
2. **Kein genulltes `dtbo_a` mehr verwenden.** Fuer den Minimal-DTB-Pfad
   `mini-dtbo-avb.img` flashen (valider DTBO-Header, ein No-Op-Overlay,
   Stock-AVB-Metadaten). Ob ABL die AVB-Hash-Differenz im Orange-State
   akzeptiert, ist **nicht getestet**; falls nicht, muss ein korrekter
   AVB-Hash-Footer erzeugt werden oder U-Boot chainloaden.
3. Testreihenfolge mit mini-DTBO: `dtbo0-explicit` (echte Memory-Ranges)
   zuerst, dann `dtbo0-inject`/`stockbase-dtbo0`.
4. Nach jedem Test **ohne Android-Zwischenschritt** pstore ueber den
   Rescue-Slot `b` oder das Prep-Image lesen; `panic=10` durch
   Vol-Down/Fastboot unterbrechen.
5. Danach `dtbo_a` mit `stock_dtbo.img` wiederherstellen.

Der `dtbo_a`-Eingriff ist reversibel, aber persistent; er braucht eine
explizite Nutzerfreigabe. `dtbo_b` bleibt unangetastet.

---

## 5. Bestaetigte Kernfakten (Evidence Gate)

1. Boot-Header: `ANDROID!`, v2, Page 4096, Kernel `0x8000`, Ramdisk
   `0x1000000`, Tags `0x100`, DTB 393.031 @ `0x1f00000`.
2. Eigener 4.14.190-Kernel laeuft; `/proc/version` zeigt
   `zero@ZeroCore ... Nov 6 2026`, nicht den Stock-Build.
3. `CONFIG_DEVTMPFS=y` wirkt: 330 `/dev`-Nodes, devtmpfs gemountet.
4. USB-NCM + DHCP + Dropbear key-only funktionieren ohne manuelles
   Host-`ip addr`.
5. Ubuntu 22.04.5 bootet von `/dev/sdb24` per `switch_root`; PID 1 ist
   `/bin/sh /sbin/init` (kein systemd in der Base).
6. `install-to-device.sh` ist end-to-end getestet und idempotent.
7. `boot_b` enthaelt unser Prep-Image (Kernel 13.356.663 B, Ramdisk
   3.765.922 B); `boot_a` ist Stock (35.493.904/2.797.028 B).
8. Panic-Roundtrip: `Kernel panic - not syncing: sysrq triggered crash` im
   pstore nach Reboot, Rescue-SSH sofort wieder da.
9. pstore/ramoops liegt bei `0xaf000000` und funktioniert mit 4.14.
10. Stock-DTB hat einen **leeren** `/memory`-Platzhalter (ABL fuellt ihn) und
    **keinen** `ramoops`-Knoten; `ramoops_mem` kommt aus DTBO-Entry 2.
11. Jedes modifizierte/rekompilierte DTB wurde vom Bootloader abgelehnt;
    Original-DTB funktioniert.
12. Mainline 6.12 baut (`Image.gz` 14.686.906 B), bootet aber mit keinem der
    getesteten DTB-Szenarien sichtbar.
13. Das Geraet ist unlocked; `fastboot boot` und `set_active` funktionieren.
14. `misc`-`bootonce-bootloader` wird von Motorolas ABL ignoriert.

---

## 6. Hypothesen und Unknowns (ausdruecklich nicht bestaetigt)

- **CONFIRMED (2026-11-06):** `/memory` ist ein leerer Platzhalter im
  Stock-DTB, den ABL fuellt; `ramoops_mem` stammt aus DTBO-Entry 2
  (`fragment@28`).
- **UNVERIFIED_HYPOTHESIS:** ABL lehnt selbstgebaute DTBs ab, weil der aktive
  DTBO-Overlay 104 Fragments und 190 Symbol-Fixups auf den vollen
  Vendor-Base-Tree anwendet; ein Minimal-DTB kann diese Ziele nicht erfuellen.
  Die Overlay-Struktur ist lokal belegt, der exakte ABL-Fehlerpfad nicht.
- **UNVERIFIED_HYPOTHESIS:** ABL lehnt selbstgebaute DTBs wegen eines
  Hash-/Signatur-/Metadaten-Checks oder wegen erwarteter Overlay-Zielknoten
  ab. Getestet und ausgeschlossen: reine Groesse/Padding, fehlende
  `qcom,msm-id`/`board-id`, offensichtliche Root-Property-Unterschiede.
- **UNVERIFIED_HYPOTHESIS:** Mainline stirbt vor `pstore_init` (kein Log).
  Der Recovery-Boot kann den Ringpuffer ueberschrieben haben; die Aussage ist
  daher nur schwach belegt.
- **UNVERIFIED_HYPOTHESIS:** Ein 4.19/5.4-Vendor-Tree von einem
  SM6150-Schwestergeraet liesse sich mit ueberschaubarem Aufwand adaptieren;
  unklar, ob er ohne UART debugbar waere.
- **Unknown:** Ob ein Mainline-Boot mit Original-DTB ueberhaupt moeglich ist
  (fehlende `/memory` im DTB muesste der Kernel anders erhalten).
- **Unknown:** Ob UART-Testpads auf der Platine existieren und erreichbar
  sind.
- **Unknown:** Ob Motorola eine 4.19/5.4/5.10-Quelle fuer `odessa`
  veroeffentlicht hat.

---

## 7. Artefakte

Vollstaendiger Katalog mit Groessen und SHA256: **`ARTIFACTS.md`**.

Wichtigste Deliverables:

| Artefakt | Groesse | SHA256 (Kurz) |
|---|---:|---|
| `build/arch/arm64/boot/Image.gz` (4.14) | 13.356.663 | `d13437cb…6245d` |
| `out/initramfs.cpio.gz` | 3.765.922 | `b4f6e19a…4b833` |
| `out/rootfs.tar` | 81.981.440 | `2d8e9f3a…5b2c6` |
| `out/test-boot-odessa-prep.img` | 17.522.688 | `1f9b6c1e…dd9fc` |
| `out/test-boot-odessa-ubuntu.img` | 17.522.688 | `569de7de…f894e` |
| `out/test-boot-mainline-m0.img` | 18.464.768 | `39f23371…610f` |
| `out/test-boot-mainline-stockdtb.img` | 18.853.888 | `f4a2fc7b…7f877` |

Dist-Bundle (host-sichtbar):
`/home/zero/.local/share/opencode/re-tools/_scratch/odessa/dist/`

---

## 8. Entscheidungen

| ID | Entscheidung | Begruendung |
|---|---|---|
| D1 | 4.14.190 aus LineageOS-Quelle, `DEVTMPFS=y` | Nutzerplan; Stock-Config ohne devtmpfs |
| D2 | Stock-Kernel-Smoke-Test vor Eigenbau | trennt Initramfs-/Host- von Kernel-Fehlern |
| D3 | Stock-DTB wiederverwenden, kein `dtbs`-Build | passt nachweislich, `dtbo` bleibt separat |
| D4 | NCM statt RNDIS | Linux-Host; RNDIS als Fallback dokumentiert |
| D5 | Ubuntu 22.04.5 statt 24.04/26.04 | systemd dort verlangt neueren Kernel als 4.14 |
| D6 | BusyBox-`/sbin/init` statt systemd | Base-Image hat keinen Init |
| D7 | Dropbear key-only, Telnet als Fallback | kein Passwort/kein libcrypt in der Base |
| D8 | DHCP-Server auf dem Geraet | Host-Interface-Name wechselt (Zufalls-MAC) |
| D9 | Rescue-Image in `boot_b`, `set_active b` | persistenter Rettungsanker, `boot_a` bleibt Stock; Flash mit ausdruecklicher Nutzerfreigabe |
| D10 | pstore + simple-framebuffer als Observability | kein UART; Panic-Roundtrip bewiesen |
| D11 | Mainline M0 headless (CPUs/PSCI/GIC/Timer/Memory) | minimaler Bring-up, keine Treiber |
| D12 | Keine weiteren DTB-Raterunden ohne UART/Recherche | 3+ Fehlversuche, Strategiewechsel |
| D13 | 26.04-Base geladen, aber nicht installiert | Mainline bootet nicht; 4.14 zu alt fuer aktuelle systemd-Versionen |
| D14 | Private Key nicht in Doku/Dist | Sicherheitshygiene |

---

## 9. Offene Punkte / naechste Schritte

### Mainline (blockiert)

1. **DTBO0-Test** (vorbereitet, Freigabe noetig): `dtbo_a` leeren, dann
   `dtbo0-inject` -> `dtbo0-explicit` -> `stockbase-dtbo0` per
   `fastboot boot`; pstore ueber Slot b lesen; `dtbo_a` restaurieren.
2. Externe Recherche-Ergebnisse des Nutzers pruefen (Links, Patches, Repos);
   die lokal pruefbaren Teile sind in §4.17 dokumentiert.
3. Falls DTBO0 nicht reicht: U-Boot-Chainload oder UART.
4. Fuer echte SM6150-Treiber (UFS/USB/Display) einen neueren Tree
   (6.16+/linux-next) lokal beschaffen; im 6.12.0-Tree fehlt Upstream-Support.
5. Ohne UART: keine blinden DTB-Raterunden; nur noch quellenbasiert oder mit
   DTBO0-Hypothese arbeiten.

### Produktivpfad 4.14/Ubuntu (offen, nicht blockierend)

- Docker installieren/testen (overlay2; ext4 mit `metadata_csum` geeignet).
- WLAN-Firmware/Treiber (Stock-Firmware-Archiv `firmware.tar.gz` vorhanden;
  Eignung/Inhalt noch nicht geprueft).
- systemd auf dem Gerät per `apt` nachziehen (falls gewuenscht).
- Display/Framebuffer im 4.14-Pfad (optional).
- Battery-Guard auch im Rescue-Initramfs (optional).

### Hygiene / Doku

- Dist-Bundle aktuell halten (README/Skripte/Images).
- Spoke-Notizen bei neuen Tasks fortschreiben.

---

## 10. Schnellreferenz

```bash
RT=/home/zero/.local/share/opencode/re-tools
KEY=$RT/_scratch/odessa/id_ed25519

# Android
$RT/bin/adb devices
$RT/bin/adb reboot bootloader
$RT/bin/fastboot set_active a && $RT/bin/fastboot reboot

# Rescue (Slot b)
$RT/bin/fastboot set_active b && $RT/bin/fastboot reboot
ssh -i $KEY root@172.16.42.1

# Prep/Ubuntu per RAM
$RT/bin/fastboot boot $RT/_scratch/odessa/dist/test-boot-odessa-prep.img
$RT/bin/fastboot boot $RT/_scratch/odessa/dist/test-boot-odessa-ubuntu.img

# pstore
ssh -i $KEY root@172.16.42.1 'ls -l /tmp/pstore-*; tail -c 2000 /tmp/pstore-console-ramoops-0'
```

---

## 11. Dokumentindex

| Datei | Inhalt |
|---|---|
| `docs/re/20261106-odessa-usbgadget/orchestrator/STATUS.md` | dieses Dokument |
| `.../orchestrator/ARTIFACTS.md` | Artefakt-/Hash-Katalog (inkl. vollstaendigem 40-Image-/28-DTB-Index) |
| `.../orchestrator/DEAD-ENDS.md` | 20 verworfene Ansaetze mit Beleg und Konsequenz |
| `.../orchestrator/LEADS.md` | konsolidiertes State-Board (CLOSED/OPEN/BLOCKED/OUT_OF_SCOPE) |
| `.../orchestrator/RELEASE-PLAN.md` | Weg zum einfachen flashbaren Image |
| `.../orchestrator/RUNBOOK-boot-test.md` | Betrieb, Rescue, pstore, DTB-Regeln |
| `.../investigator/` | UFS-INV-01, GCC-INV-01, PDC-INV-02, REG-INV-02 |
| `.../scout/` | GCC-MAP-01/02, ODESSA-DTS-MAP-01, PDC-REG-MAP-01, UBOOT-QCS615-MAP-01/02 |
| `.../orchestrator/RESEARCH-mainline-sm6150.md` | Gemini-Prompt + Suchliste |
| `.../software-manager/T2-TOOLCHAIN.md` | Toolchain/Kernel-Quelle/Config |
| `.../software-manager/T3-KERNEL-BUILD.md` | 4.14-Build inkl. OpenSSL-Fix |
| `.../software-manager/T7-DROPBEAR.md` | Dropbear-Build |
| `.../software-manager/T10-E2FSPROGS.md` | statische e2fsprogs |
| `docs/re/20261106-adb-install/` | separater adb-Installations-Run |
| `/workspace/work/odessa/README.md` | Nutzer-/Builder-Doku |

---

## 12. Memory-Referenzen

Run-Knoten: `7846c605-0654-4c28-b651-deb92e712335`
(`PROJECT=odessa-usbgadget`, Typ `task`, Status OPEN).

Wichtige bestaetigte Eintraege:

- `6a7ebeff-c9b0-4a6b-8585-5d1a7ccb7398` — T5 Pack/Header.
- `3f231de4-19af-4e4e-98ba-791ceaa469f0` — T6a Stock-Smoke-Test.
- `4f4ab1ce-71fa-46ff-b780-473f6d798c0b` — T6b Eigenbau-Kernel.
- `5fcf597d-3b1b-4d4f-bd64-fb100e414dd9` — T9 v2 DHCP/SSH.
- `29b29063-8e30-4678-8d03-9c647ac3672f` — T11 RootFS-Prep.
- `ad028f41-8713-431c-aab8-eef34924df38` — T12 Ubuntu-Boot.
- `03f9e7dc-0a14-4c40-b684-770c5d7d82af` — T15 Panic/Ramoops.
- `a37c32df-ab0f-40be-a83b-151d0db857bb` — T14 Observability.
- `3ce67f62-6e8c-4aca-9232-b250e300a2ae` — M0 Mainline blockiert.
- `2c6545b0-5b06-47fc-9a14-c72c1a280bf2` — Korrektur zu DTB/Padding/pstore.
- `7f0c8fb8-5c6e-483e-87ca-4e0ab174ca4f` — Korrektur: `/memory`-Platzhalter,
  DTBO 104/190, Live-Board-ID, Single-FDT.
- `95afaeb2-ed9d-4a57-8b65-d72002261391` — DTBO0-Testartefakte (nicht geflasht).
- `e8a5acef-6d4e-4b0a-a1be-b3adea6439ba` — DTBO0-Prep V2 (exakte IDs,
  Stockbin-Vorabtest, neue Hashes).
- `666c0d0d-1a77-4a66-b18e-db3b6ddf3833` — ABL-Korrektur: Null-DTBO
  unbrauchbar, stockbin durch `NO ACTIVE SLOT` abgebrochen, Mini-DTBO-AVB.
- `95e22d46-b41f-4f3a-9a48-92531bf631fe` — `boota (786)`-Assert beim
  sauberen stockbin-Retest; Prep-Kontrolle laeuft.
- `b36a6d45-ef5b-4e29-887d-48535ee30ca2` — Cmdline-Fix-Artefakte
  (leere Header-Cmdline, Force-Cmdline-Kernel), Tests ausstehend.
- `36856559-cdfc-4315-87e0-7c1d506fd3c9` — 6.12 erreicht Initramfs;
  pstore-Log, Empty-Cmdline-Fix bestaetigt.
- `178ddcfb-2a6d-46d3-85ee-e05a3b4de512` — 6.12-USB2/Display-Build,
  Tests ausstehend.
- `a5bb5f83-52e9-4671-bcee-401c0fe553ae` — USB2-Test: kein
  `dwc3`/`qusb2`, `no UDC`; Vendor-DTB-Pfad ausgereizt.
- `74415d72-5378-4281-b67e-4c1d4306d701` — Mini-DTBO per AVB
  verworfen; Custom-DTBO-Pfad tot.
- `675de9d6-d08b-4f7a-b253-78755e3e6f2a` — Dokumentationskonsolidierung.

Memory-Fehler: keine in diesem Run festgestellt.

---

## 13. U-Boot-Chainload (aktiv, 2026-11-06)

**Entscheidung:** U-Boot als zweite Bootstufe; Detailplan in
`orchestrator/UBOOT-PLAN.md`. U-Boot wird als Kernel-Payload in ein
`boot.img` v2 gepackt (Stock-DTB, FIT im Ramdisk-Slot, leere
Header-Cmdline) und bootet anschließend einen FIT mit Mainline-Kernel,
odessa-DTB und Initramfs. Damit entfallen ABLs DTBO-AVB-Zwang und der
`boota (786)`-Pfad.

**Belegte Fakten (neu, Evidence Gate):**

- **ABL-Ramdisk/FIT-Adresse: `0x85367000`.** Aus
  `/proc/device-tree/chosen/linux,initrd-start` im laufenden 4.14-Rescue
  (per `fastboot boot`): `00 00 00 00 85 36 70 00`; End
  `00 00 00 00 85 6f e6 a2`; Größe 3.767.970 B (konsistent mit
  `Freeing initrd memory: 3676K`). **Nicht** die Header-`ramdisk_addr`
  `0x1000000`.
- **ABL-Speicher:** zwei Regionen
  `0x0000000080000000` + `0x0000000080000000` (2 GiB) und
  `0x0000000100000000` + `0x000000007dd00000` (~2,06 GiB); gesamt
  4.258.267.136 B (~4,06 GiB).
- **Board-ID `<0x49 0xc000>`, MSM-ID `<0x16d 0x0>`, Modell `odessa`.**
- **Stock-DTBO:** 3 Entries à ~266 KB; Entry 2 hat
  `qcom,board-id = <0x49 0xc000>` und enthält `ramoops_mem`
  (`/tmp/entry2.dts` Zeile 2494). Host-`fdtoverlay` 1.6.1 **und**
  Kernel-`fdtoverlay` scheitern mit `FDT_ERR_BADOVERLAY` (Qualcomm-
  Fixups); für den ersten U-Boot-Test wird daher das minimale
  odessa-DTB mit `ramoops` verwendet, nicht der Stock-Overlay-Merge.
- **`dtbo_a` ist nicht Stock:** erste 64 B = 0, MD5
  `ec87a838931d4d5d2e94a04644788a55`; `dtbo_b` ist Stock
  (`514d54012bb78591ef5b4f502859b564` = `firmeware/stock_dtbo.img`).
  Vor einem Slot-a-Normalboot: `fastboot flash dtbo_a
  firmeware/stock_dtbo.img` und Hash prüfen.

**U-Boot-Build (läuft):** `UBOOT-TOOLS-01` (software-manager) holt die
offizielle U-Boot-Quelle und die fehlenden Host-Tools nach `re-tools`.
Danach: Scout/Investigator für `qcom_defconfig`,
`CONFIG_POSITION_INDEPENDENT`, `CONFIG_LINUX_KERNEL_IMAGE_HEADER`,
GENI-Serial/GCC/Pinctrl/`simplefb`; anschließend DTS, Build, FIT.

**Erster Test (geplant, RAM only):** `boot.img` v2 mit `u-boot.bin` als
Kernel, Stock-DTB, FIT im Ramdisk-Slot, leerer Header-Cmdline; FIT:
`Image-6.12-original.gz` + minimales odessa-DTB (ramoops) + Initramfs;
Load `0x90000000` / `0x8F000000` / `0xA0000000`; `fastboot boot`.

**Memory-Refs:** `2fb72c42-9b6a-471d-9ac9-b45295ce20b5` (Plan),
`fe42051e-20dc-476b-b274-402bf74893da` (ABL-Ramdisk),
`066c3f52-a031-46a4-8eb1-7eed1d0f901e` (DTBO-Ist-Zustand).

**U-Boot-Quelle bereit (2026-11-06):** offizielles DENX-Repo, Tag
`v2026.10`, Commit `5508406582f6f7120dce0c4b3059819a41788db2`, Tag-Signatur
von Thomas Rini verifiziert. QCS615-Support ist vorhanden:
`configs/qcom_qcs615_defconfig`, `dts/upstream/src/arm64/qcom/talos.dtsi`
(QCS615-SoC-DTS) und `qcs615-ride.dts`
(`compatible = "qcom,qcs615-ride", "qcom,qcs615", "qcom,sm6150"` — QCS615
ist SM6150-Familie). `talos.dtsi` liefert GCC `0x100000`
(`qcom,qcs615-gcc`), TLMM `0x3400000` (`qcom,qcs615-tlmm`),
**`uart6: serial@a88000`** (`qcom,geni-uart`,
`GCC_QUPV3_WRAP1_S2_CLK`), QUSB2 (`qcom,qcs615-qusb2-phy`), DWC3
(`qcom,dwc3`) und `simplefb`. `pm6150.dtsi`/`pm6150l.dtsi` sind im
U-Boot-`dts/upstream` vorhanden. `qcom_defconfig` hat
`CONFIG_POSITION_INDEPENDENT=y`, `CONFIG_VIDEO=y`,
`CONFIG_VIDEO_SIMPLE=y`, `CONFIG_CLK_QCOM_QCS615=y`,
`CONFIG_PHY_QCOM_QUSB2=y`, `CONFIG_USB_DWC3_GENERIC=y`.
`qcom_qcs615_defconfig` setzt `TEXT_BASE=0x9fc00000`,
`DEBUG_UART_BASE=0x880000`, `DEFAULT_DEVICE_TREE="qcom/qcs615-ride"`,
`WATCHDOG_AUTOSTART=y`. **Kein `odessa`-Board** — Board-Port noetig.

**Laufend:** Baseline-Build `build-qcs615` (Toolchain/DTS-Validierung,
`-j12`, `nice -n 10`) und Scout `UBOOT-QCS615-MAP-02` (GPIO44/45-Pinctrl,
Image-Header/`text_offset`, Console/Video, USB, UFS, PM6150-Luecken).
Danach odessa-DTS + Defconfig + Build + FIT + `fastboot boot`.

**Tool-/Zugriffsstand (2026-11-06):** `xxd` wurde via software-manager
installiert (`UBOOT-TOOLS-02`, `re-tools/bin/xxd`, 9.1.0016, SHA256
`abe2a776…`). Der erste Scout (`UBOOT-QCS615-MAP-01`) scheiterte an der
Subagent-Permission (`external_directory`), weil die U-Boot-Quelle unter
`/home/zero/...` liegt. Workaround: U-Boot v2026.10 ohne `.git` nach
`/workspace/work/odessa/.re/uboot/src` kopiert (360 MB, Commit
`5508406…`); Scout `UBOOT-QCS615-MAP-02` liest diese Kopie. Der
Baseline-Build brauchte zusaetzlich
`BISON_PKGDATADIR=re-tools/build/t2-root/usr/share/bison` (der
`bison`-Wrapper findet `/usr/share/bison` nicht) und `xxd`.

**Baseline-Build erfolgreich (2026-11-06):** `qcom_qcs615_defconfig`,
`-j12`, `nice -n 10`: `u-boot.bin` 1.515.056 B, `u-boot.dtb` 92.944 B,
`tools/mkimage` 434.872 B, `u-boot.elf` 1.581.168 B. Der `u-boot.bin`
hat den ARM64-Image-Header: `ARMd` @ `0x38`, `text_offset=0x1fc00000`
(= `TEXT_BASE 0x9fc00000` − RAM-Base `0x80000000`), `image_size=0x2b4d10`,
`flags=0xa`. Fuer odessa mit `TEXT_BASE=0x80000000` wird
`text_offset=0`. Baseline-`.config` bestaetigt:
`CONFIG_LINUX_KERNEL_IMAGE_HEADER=y`, `CONFIG_CONSOLE_MUX=y`,
`CONFIG_SYS_CONSOLE_IS_IN_ENV=y`, `CONFIG_VIDEO_SIMPLE=y`,
`CONFIG_VIDEO_DT_SIMPLEFB` aus, `CONFIG_WATCHDOG_AUTOSTART=y`,
`CONFIG_BOOTDELAY=1`.

**FIT gebaut:** `fit-6.12.itb` 18.465.493 B, SHA256
`0a62cebb80b1e16a488f928cba930a837ffb51d076a0149a3e238ca9b915427a`;
Kernel `0x90000000` (SHA256 `3f8d9299…`), FDT `0x8F000000`
(`b21ef32a…`), Ramdisk `0xA0000000` (`b4f6e19a…`).

**U-Boot-Quellen-Evidence (Scout `UBOOT-QCS615-MAP-02`, am Original
verifiziert):**

- `talos.dtsi:966-977`: `qupv3_id_1` `status = "disabled"`;
  `talos.dtsi:1133-1151`: `uart6: serial@a88000`
  `compatible = "qcom,geni-uart"`, `status = "disabled"`.
- `serial_msm_geni.c:550-552`: `qcom,geni-uart` wird **nicht** geprobt
  (`return -ENOENT`); nur `qcom,geni-debug-uart`. Der Parent muss
  `qcom,geni-se-qup` sein (`:461-465`).
- `pinctrl-qcs615.c:263-264`: GPIO44/45 = `qspi`, **kein QUP-Mux**.
  Damit ist der odessa-UART auf GPIO44/45 in U-Boot **nicht nutzbar**;
  die Display-Konsole ist primaer.
- `talos.dtsi:1553-1567`: TLMM liegt bei **`0x3100000`** (drei Regionen,
  124 Pins), nicht `0x3400000`.
- `talos.dtsi:4854-4867`: `usb_1_hsphy` `qcom,qcs615-qusb2-phy`,
  `0x88e2000`, `status = "disabled"`. `talos.dtsi:4938-4994`: `usb_1`
  `qcom,qcs615-dwc3`/`qcom,snps-dwc3`, `0xa600000`,
  `status = "disabled"`.
- `simplefb.c:27-31,83-100`: akzeptiert `reg` oder `memory-region`,
  Format `a8r8g8b8`. `board/qualcomm/default.env:2-3`:
  `stdout=serial,vidconsole`.
- `board/qualcomm/qcom-phone.env`: `usbacm`-Gadget;
  `qcom-phone.config`: `CONFIG_USB_FUNCTION_ACM=y`,
  `CONFIG_CONSOLE_RECORD` etc.

**Synthese (2026-11-06):** `qcs615-odessa.dts` (`talos.dtsi`, Memory-
Overlay, `simple-framebuffer`, `uart6` als `geni-debug-uart` ohne
Pinctrl, USB peripheral), `qcom_qcs615_odessa_defconfig`
(`TEXT_BASE=0x80000000`, `DEBUG_UART_BASE=0xa88000`, `odessa.env`,
ACM, `CONSOLE_RECORD`, Watchdog aus, `REQUIRE_SERIAL_CONSOLE` aus),
`odessa.env` (`bootcmd=bootm 0x85367000`,
`stdout=serial,vidconsole`, `usbacm`). Build laeuft.

**Build-Fix (2026-11-06):** `serial_msm_geni.c:612-616` bricht mit
`#error Clocks cannot be set at early debug` ab, weil
`DEBUG_UART_CLOCK=19200000` kein ganzzahliges Vielfaches von
`BAUDRATE*UART_OVERSAMPLING` (`115200*32 = 3.686.400`) ist. Der
Early-Debug-UART ist fuer die Display-Konsole nicht noetig; daher
`CONFIG_DEBUG_UART` und `CONFIG_DEBUG_UART_MSM_GENI` deaktiviert. Der
normale GENI-Treiber bindet `uart6` weiterhin (`qcom,geni-debug-uart`),
die Display-Konsole bleibt primaer.

**DTS-Fix (2026-11-06):** Der erste DTS-Compile scheiterte an
(a) der zweiten Memory-Bank: `<0x0 0x100000000 0x0 0x7dd00000>` wird als
33-Bit-Wert auf `0` abgeschnitten; korrekt ist die 2-Zellen-Adresse
`<0x1 0x0 0x0 0x7dd00000>`. (b) `talos.dtsi` referenziert die
Board-Labels `sleep_clk`/`xo_board_clk`; die odessa-DTS definiert sie
jetzt als `fixed-clock` mit 32 kHz bzw. 38,4 MHz (wie
`qcs615-ride.dts`).

**Odessa-U-Boot gebaut (2026-11-06):** `u-boot.bin`/`u-boot-dtb.bin`
1.509.904 B (SHA256 `5c17cc3d25d5e1dc35970f389760f9ce4c2c66af7eeed6e8dc983e51d5377e97`),
`u-boot.dtb` 82.696 B (SHA256
`8fa3d1cb186d8df8950bd6698b1cdc31b8f9f725b4fd4a5f704e0b15c5f9d20a`).
Image-Header: `text_offset=0x0`, `image_size=0x2b5dc8`, `flags=0xa`,
`ARMd` @ `0x38`. DTB: Modell „Moto G9 Plus (odessa)“, zwei Memory-Baenke,
`simple-framebuffer` 1080×2400/`a8r8g8b8`, `uart6`
`qcom,geni-debug-uart` okay (ohne Pinctrl), `usb_1`
`qcom,snps-dwc3` peripheral/HS, `usb_1_hsphy` `qcs615-qusb2-phy` okay.

**`boot.img` gepackt:** `test-boot-uboot-odessa.img` 20.377.600 B
(SHA256 `3b7bb581cabec191ae749df2f1306610018c002a90ceb78ef4a2384c9e9d3661`),
`ANDROID!` v2, Page 4096, Kernel 1.509.904 @ `0x8000`, Ramdisk
18.465.493 @ `0x1000000`, DTB 393.031 @ `0x1f00000`, leere Cmdline.
**Bereit fuer `fastboot boot` (RAM only).**

**Env verifiziert (2026-11-06):** `strings u-boot.bin` enthaelt
`stdout=serial,vidconsole`, `stdin=serial,button-kbd`,
`stderr=serial,vidconsole`, `bootcmd=bootm 0x85367000`,
`serial_gadget=... usbacm ...` und
`bootmenu_0=Boot FIT=bootm 0x85367000; pause`. Die Dateien
`environment.h`/`env.in` sind leer (die `env.txt` ist die
Config-Header-Datei), aber der Default-Env ist im Binary; die
`odessa.env` wurde verwendet.

**Erster Test:** `fastboot boot test-boot-uboot-odessa.img` (RAM only).
Display zeigt U-Boot; FIT/6.12. **Kein SSH im ersten Test**, weil das
minimale FIT-DTB `sm6150-moto-odessa-dtbo0-explicit.dtb` keine
USB-Knoten hat — erwartet. USB/SSH kommen mit dem Mainline-DTB-Port
(naechste Phase). pstore via 4.14-Rescue. `dtbo_a`/`dtbo_b` unberuehrt;
Rollback = Reset.

**Revision 2026-11-06 21:16 (prevbl/scan):** Der erste U-Boot-Test
zeigte Display-Text, aber `bootm 0x85367000` -> "wrong image type" (-91).
Ursache: `0x85367000` war die Initrd-Adresse des 13-MB-4.14-Kernels;
ABL legt den FIT beim 1,5-MB-U-Boot-Kernel anders ab.
`CONFIG_SAVE_PREV_BL_INITRAMFS_START_ADDR=y` und
`CONFIG_SAVE_PREV_BL_FDT_ADDR=y` sind gesetzt; `save_prev_bl_data`
liest die echte ABL-Adresse aus dem x0-DTB nach
`prevbl_initrd_start_addr`. `bootcmd`/`bootmenu_0` versuchen diese
Adresse und scannen dann `0x81000000..0x87000000` per `iminfo`, bevor
`bootm`. Neue Artefakte: `u-boot.bin` 1.509.904 B SHA256
`7e7a4416a5f5831e43eeb20be8e0464d7eaba3f98a776f88c82ca22b9574597b`;
`test-boot-uboot-odessa.img` 20.377.600 B SHA256
`14350385d3b1028a66652b03c6f7c93424d644f6a8f7d3802de45abd4b690f1c`.
Header weiterhin `text_offset=0x0`.

---

## Revision 2026-11-06 21:45 UTC — Chainload bewiesen; DTB-Fix1 (Timer+Display)

**Pstore-Ergebnis des ABL-DTB-Tests (User-Ausgabe):** Der 6.12-Log ist im
ramoops angekommen. Damit ist die U-Boot-Kette **bewiesen**:
U-Boot -> FIT (Image 6.12 + ABL-merged DTB) -> Linux 6.12 -> ramoops.

Belege aus dem Log (trotz Terminal-Garbling lesbar):
- `Machine model: odessa`
- `OF: reserved mem: ... ramoops_mem ... 0xaf000000 ... 0xbf800`
- `ramoops: using 0xbf800@0xaf000000, ecc: 0`
- `pstore: Registered ramoops as persistent store backend`
- `simple-framebuffer 9c000000.framebuffer: [drm] could not acquire memory
  region` + `probe ... failed with error -12`
- `arch_timer: No interrupt available, giving up`
- `[init] ... no UDC found`

Hinweis: Die Garbling-Artefakte beim `cat` des pstore-Files sind
Terminal-Steuerzeichen aus dem Rohbuffer. Kuenftig mit
`cat -v` bzw. `tr -c '[:print:]\n' '.'` lesen.

### Analyse (belegt am 6.12-Baum, /workspace/work/odessa/mainline/linux-6.12)

**1. Arch-Timer (Blocker):** Im ABL-DTB erbt `/soc/timer` das
`interrupt-parent` der Wurzel = PDC (`phandle 1`,
`qcom,pdc-sdmmagpie`). Die PDCs uebersetzen die PPI-Interrupts nicht, also
liefert `of_irq_get()` 0 -> `arch_timer: No interrupt available`.
Fix: `interrupt-parent = <&intc>` (GIC, phandle `0x1a`) am Timer-Knoten.
Die PPI-Nummern `1,2,3,0` sind korrekt (identisch zu mainline
`sdm670.dtsi`, `GIC_PPI 1/2/3/0`).

**2. Display/simplefb (Blocker):** `simpledrm` nimmt den `reg`-Pfad und ruft
`devm_ioremap_wc()`. Auf arm64 verweigert `ioremap_prot()`
(`arch/arm64/mm/ioremap.c:28`) RAM, der im Linearmapping liegt
(`pfn_is_map_memory` -> `memblock_is_map_memory`) -> NULL -> `-ENOMEM`.
Der alternative `memory-region`-Pfad hilft nicht: `memremap(MEMREMAP_WC)`
verweigert System-RAM ebenfalls (`kernel/iomem.c:103`).
Fix: `cont_splash_region@9c000000` mit `no-map` versehen; `reg` bleibt.
Dann ist die Region nicht linear gemappt und `ioremap_wc(0x9c000000,
0x9e3400)` funktioniert; `request_mem_region` darf weiterhin harmlos
scheitern (Treiber behandelt das nicht fatal).

**3. Framebuffer-Geometrie:** ABL hat Dezimalziffern als Hex abgelegt:
`width=4224`, `height=9216`, `stride=17184`. Beweis fuer die echten Werte:
`reg`-Groesse `0x9e3400` = 1080*2400*4. Fix: `width=1080`, `height=2400`,
`stride=4320` (Bytes).

**4. USB (weiter offen):** Die Vendor-Knoten passen nicht zu mainline:
`ssusb@a600000` = `qcom,dwc-usb3-msm` (mainline `dwc3-qcom` matcht nur
`qcom,dwc3`), `qusb@88e2000` = `qcom,qusb2phy-v2` (mainline:
`qcom,qusb2-v2-phy`/`qcom,sdm845-qusb2-phy`, braucht `#phy-cells`).
Zusaetzlich fehlen Clock-/Reset-/Regulator-Provider: mainline 6.12 hat
**keinen** `qcom,gcc-sdmmagpie`-Treiber. Naechster Ansatz: sdm670-Reuse
(`qcom,gcc-sdm670` existiert; `sdm670.dtsi` nutzt denselben QSCRATCH
`0xa6f8800` und dieselbe Timer-PPI-Kodierung).

### Artefakt Fix1 (RAM-only)

- `odessa-6.12-fix1.dtb` 598.071 B
  SHA256 `d96694dc59dd44945d25c0e42d7c659c3a635d775af13a66da31ae76582d81c8`
- `fit-6.12-fix1.itb` 19.052.413 B
  SHA256 `7fe12ecf6ea518ff7b63a6f26abf589ae3269bb8cbbafb5047792bbbeb2b4d2c`
- `test-boot-uboot-odessa-fix1.img` 20.963.328 B
  SHA256 `07694cedb4dd75342af4f120e39b79a060b8e421c906ff9128fb1a78321d5e7b`

Aenderungen gegenueber `odessa-abl-merged.dtb` (per `fdtput`, Original
unveraendert):
1. `/soc/timer:interrupt-parent = <0x1a>`
2. `/framebuffer@9c000000:width/height/stride = 1080/2400/4320`
3. `/reserved-memory/cont_splash_region@9c000000:no-map` (leer)

**Naechster Test:** `fastboot boot test-boot-uboot-odessa-fix1.img`.
Erwartung: Kernel-Log auf dem Display (fbcon), keine
`arch_timer: No interrupt available`-Zeile, UDC weiterhin nein.

---

## Revision 2026-11-06 21:52 UTC — Pstore-Record durch Android-Boot ueberschrieben

Die vom Nutzer gelesene `pstore-console-ramoops-0` enthielt **nicht** den
6.12-Log, sondern den Boot des installierten **LineageOS 20 / Vendor-4.14**:
`msm_bus`, `msm-dwc3`, `msm_drm`, `KernelSU`, `LineageOS Version:
'20.0-20231120-UNOFFICIAL-odessa'`, `keystore2`, `vold`, am Ende
`init: Rebooting into recovery, reason: init_user0_failed`.

Ursache: Nach dem RAM-Test rebootete das Geraet in den normalen Slot-a-Boot
(Android). Der Vendor-Kernel schreibt selbst in den Ramoops-Console-Record und
ueberschreibt damit den 6.12-Log. Zusaetzlich kann Android `/data` nicht
mounten (userdata ist die Ubuntu-ext4-Partition) und rebooting dauerhaft nach
Recovery — jeder normale Boot zerstoert den pstore-Record.

**Konsequenz:** Der 6.12-Test muss ohne zwischenzeitlichen Android-Boot
ausgewertet werden: nach dem Test direkt per Power+Vol-Down in den
ABL-Fastboot, dann `test-boot-414190-pstore-ro.img`. Zusaetzlich darf der
6.12-Kernel nicht selbst rebooten.

### Fix2: `panic=0`

`odessa-6.12-fix2.dtb` = Fix1 + `chosen/bootargs`: `panic=5` -> `panic=0`
(kein Auto-Reboot nach Panic; Geraet bleibt im Testzustand).

- `odessa-6.12-fix2.dtb` 598.071 B
  SHA256 `b29fb87e120f393a01503257dd901577dd7accf02ab0de71c16b2606637e65c7`
- `fit-6.12-fix2.itb` 19.052.421 B
  SHA256 `824b49a768c666dc8a602c35ddb3705cccbed75ee42f74d3956c9ed277f1c858`
- `test-boot-uboot-odessa-fix2.img` 20.963.328 B
  SHA256 `b88a42065e15befd4b54594c90119ee2e5f55dec2319475a700a4b98142c33a2`

Offen: Rueckmeldung, ob Fix1/Fix2 den 6.12-Log auf dem Display zeigt
(fbcon) und bis `[init] init done` kommt.

---

## Revision 2026-11-06 22:00 UTC — Fix1/Fix2-Geometrie war Hex statt Dezimal

Der jetzt gelesene 6.12-Log (Fix1/Fix2-Boot) beweist:

- **Timer-Fix wirkt**: `arch_timer: Enabling local workaround for ARM erratum
  1418040`, keine `No interrupt available`-Zeile mehr. Die verbleibende
  Meldung `Failed to initialize '/soc/timer@0x17c20000'` betrifft nur den
  separaten `arm,armv7-timer-mem`-Frame, nicht den Arch-Timer.
- **simpledrm initialisiert**: `[drm] Initialized simpledrm 0.0.0 for
  9c000000.framebuffer on minor 0`.
- Danach **Oops** in `__memcpy_toio -> drm_fb_blit ->
  simpledrm_primary_plane_helper_atomic_update -> register_framebuffer`.

Ursache: `fdtput -t x ... width 1080` interpretiert `1080` als **Hex**
(0x1080 = 4224); ebenso `height 0x2400` (9216) und `stride 0x4320` (17184).
Die Werte waren also unveraendert falsch. Der Blit schrieb 16896-Byte-Zeilen
(4224*4) in einen 4320er-Pitch und lief ueber das 0x9e3400-Framebuffer
hinaus -> `Unable to handle kernel paging request ... 0x9e4000`.

Korrekt (Dezimal -> Hex): `1080 = 0x438`, `2400 = 0x960`, `4320 = 0x10e0`.

### Fix3 (korrigierte Geometrie)

- `odessa-6.12-fix3.dtb` 598.071 B
  SHA256 `242b143be6f7e5b32ba7be823b5016d5d9a70ffd4c68f696319925266e368bf4`
- `fit-6.12-fix3.itb` 19.052.433 B
  SHA256 `5216e329eeece7b356d009d4de4291e8fa9cd2ad5490ae3f5f94bdb045dae089`
- `test-boot-uboot-odessa-fix3.img` 20.963.328 B
  SHA256 `e9f77ab97960c2051a94f0b62151ac2b3c4733991d7e36a4ded3dd7f911d5c2b`

Verifiziert (dezimal): width 1080, height 2400, stride 4320; Timer-Parent 26
(0x1a = GIC); cont_splash `no-map`; `panic=0`.

---

## Revision 2026-11-06 22:15 UTC — Fix3 bestaetigt; USB-Root-Cause (Vendor- vs Mainline-RPMh)

User-Rueckmeldung zum Fix3-Boot (Display): `[init] init done`, davor
USB-Meldungen und `[init] usb0 addr failed`, ausserdem
`mkdir .../usb_gadget: Operation not permitted`. Damit bestaetigt:

- fbcon/Timer/6.12-Userspace funktionieren.
- `usb0 addr failed` ist **erwartet**: ohne UDC gibt es kein `usb0`.
- Der `usb_gadget`-mkdir-Fehler ist sekundaer (configfs-Mount bzw.
  libcomposite-Subsystem); er blockiert erst nach Vorhandensein eines UDC.

**Root Cause USB (belegt):** Das Vendor-DTB nutzt eine andere RPMh-Architektur
als mainline 6.12:
- Vendor: `mailbox@18220000` (`qcom,tcs-drv`, label `apps_rsc`, TCS @0x18220d00)
  und ein 8-Byte-Dictionary `qcom,cmd-db@c3f000c`.
- Mainline: `qcom,rpmh-rsc` (sdm670: 0x179c0000) + Reserved-Memory-Kind
  `qcom,cmd-db` (sdm670: 0x85fe0000); `cmd_db_dev_probe()` verlangt
  `of_reserved_mem_lookup()`.
- Vendor `drivers/soc/qcom/cmd-db.c` liest am Dictionary 0xc3f000c zwei u32
  (Start, Groesse) und mappt damit die echte DB.
- Deshalb im Log: `cmd-db ... failed to acquire memory region` ->
  `-EINVAL`, danach `rpmh_regulator_probe ... could not find RPMh address`.

Ohne RPMh keine GCC-Clocks/Resets und keine PM6150-Regulatoren; ohne die
binden `dwc3-qcom`/`qusb2` nicht (of_clk_get/-EPROBE_DEFER).

**Naechster Datenpunkt:** echte cmd-db-Basis aus dem Vendor-Kernel
(`/proc/iomem`, Resource des gemappten cmd-db) sowie RSC/IMEM-Bereiche.
Danach mainline-taugliches DTB (sdm670-Basis bzw. Vendor-DTB mit
RPMh-RSC/cmd-db-Reserved-Memory) und GCC-Port (gcc-sdmmagpie).

---

## Revision 2026-11-06 22:32 UTC — Fix4: RPMh/cmd-db aus /proc/iomem

Datenpunkt vom Vendor-4.14-Kernel (`/proc/iomem`):

- `85f20000-85f21078 : c3f000c.qcom,cmd-db` -> echte cmd-db Basis
  `0x85f20000`, Groesse `0x1078`
- `18220000-182200ff : mailbox@18220000` -> RSC DRV
- `18220d00-18223cff : mailbox@18220000` -> RSC TCS (Offset `0xd00`)
- `0a60c100-0a60ccff : dwc3@a600000`, `088e2000-088e23ff : qusb_phy_base`

Fix4 (DTS-Roundtrip des ABL-DTBs, da neue Knoten noetig):
1. `reserved-memory/cmd-db@85f20000`: `compatible = "qcom,cmd-db"`,
   `reg = <0 0x85f20000 0 0x1078>`, `no-map`.
2. `soc/rsc@18220000`: `compatible = "qcom,rpmh-rsc"`,
   `interrupt-parent = <GIC>` (0x1a), drei `drv-*`-Regs je `0x18220000 0x4000`,
   drei IRQs SPI 5, `qcom,tcs-offset = <0xd00>`, `qcom,drv-id = <2>`,
   `qcom,tcs-config = <WAKE 2>, <ACTIVE 3>, <SLEEP 3>, <CONTROL 1>`
   (Werte aus dem Vendor-Mailbox-Knoten).
3. Kind `rpmhcc`: `compatible = "qcom,sdm670-rpmh-clk"` + Fixed-Clock
   `xo_board` 19.2 MHz.
4. Fix1/2/3-Fixes beibehalten: Timer-Interrupt-Parent, simplefb
   `no-map` + 1080x2400@4320, `panic=0`.

Magie geprueft: Vendor `CMD_DB_MAGIC 0x0C0330DB` = mainline
`{0xdb,0x30,0x03,0x0c}` — identisch.

Artefakte:
- `odessa-6.12-fix4.dtb` 597.808 B
  SHA256 `6b771aba18facf24c319460c56482ee7e2ee8f70e9ac68d3b653515a10045108`
- `fit-6.12-fix4.itb` 19.052.157 B
  SHA256 `d3100fac14096f4fb6239175ad7e5fd8dade3c4a47d9495f8442ac3e76dfddc3`
- `test-boot-uboot-odessa-fix4.img` 20.963.328 B
  SHA256 `140f7aac6b97e01d2ccd0a1556a1453c89006981d65377e56dcc4527bbe89dae`

Erwartung: cmd-db-Magic OK, `rpmh-rsc` probe, `rpmhcc` registriert,
RPMh-Regulatoren finden ihre Adressen. Noch **kein** USB, weil GCC fehlt.

Kernel-Build-Umgebung repariert (OpenSSL-3-Header-Symlinks in
`re-tools/uboot-hostroot/usr/include/openssl/`); `make Image.gz` laeuft
jetzt wieder durch (rc=0). Damit sind Treiber-Patches moeglich.

---

## Revision 2026-11-06 22:38 UTC — Fix4-Testergebnis (RPMh) + Fix5-Diagnose

Grep aus dem fix4-pstore (garblingsbedingt unvollstaendig):

- `cmd-db c3f000c.qcom,cmd-db: probe ... failed with error -22` — nur der
  **Vendor-Dictionary-Knoten**; der neue Reserved-Memory-Knoten ist still
  (Erfolg wird nicht geloggt).
- **Keine** `rpmh_regulator_probe: ... could not find RPMh address`-Zeilen
  mehr (in fix3 waren sie bei 0.37 s vorhanden).
- `platform 1.gpio-regulator: deferred probe pending: platform: wait for
  supplier /soc/rpmh-regulator-smpc8/regulator-pm6150-s8` — der
  RPMh-Regulator-Knoten existiert und wird als Supplier aufgeloest.

Interpretation: cmd-db/RSC/rpmhcc sind sehr wahrscheinlich aktiv; die
Regulatoren finden ihre Adressen. Sauberer Nachweis ueber die
Initramfs-Zusammenfassung (Fix5).

Fix5 = Fix4-DTB + erweitertes Initramfs, das am Ende auf tty0 ausgibt:
Regulator-Liste (Name/state/uV), `udc:`, `cmd-db:`- und `rsc:`-Device-Namen.

- `fit-6.12-fix5.itb` 19.052.357 B
  SHA256 `95cba8e8f7d0eb9d5bb9c15392e510551fc33c39c7ca22c31b1b89811700509e`
- `test-boot-uboot-odessa-fix5.img` 20.963.328 B
  SHA256 `818ace8194da617350f4ab39abffbad94303573f169ab1a3a6efdc6915701e65`
- Initramfs `initramfs.cpio.gz` 3.766.112 B
  SHA256 `07cd5c7b86ec4e88035e7f1d73695ed1d4487703c2402698f13a1ca8c49bbe5f`

---

## Revision 2026-11-06 22:43 UTC — Fix6: 16x32-Font + Log-faehige Diagnose

User-Feedback: Displaytext zu klein; Frage, ob alles im Log landet.

- Fehler behoben: Die Regulator-Zeilen im Initramfs nutzten einfaches `echo`
  (nur tty0). Jetzt `say()` -> zusaetzlich `/dev/kmsg` -> Ramoops-Console.
- Kernel neu gebaut mit `CONFIG_FONTS=y` + `CONFIG_FONT_TER16x32=y`
  (vorher von `olddefconfig` verworfen; per direkter .config-Aenderung +
  `olddefconfig` gesetzt, `TER16x32` im Image verifiziert).
  `Image-6.12-font.gz` 14.847.342 B
  SHA256 `46768505304c22cc295f875fb049e721132422ae39079dec39d7a1b04b54b7cf`.
- `chosen/bootargs`: `fbcon=map=0` -> `fbcon=font:TER16x32`
  (map=0 war ohnehin falsche Syntax; fbcon erwartet `map:`).
  Damit 16x32-Font, 67x75 Zeichen statt 135x150.

Artefakte:
- `odessa-6.12-fix6.dtb` 597.816 B
  SHA256 `d25eda1257776923d1ca1aced1164804e56746eb558d87080ac55fe6d37b5e44`
- `fit-6.12-fix6.itb` 19.212.789 B
  SHA256 `d54b38e97a53954f7b5fc6a8477f476051304b16c42e0e5116d221cb86caaddb`
- `test-boot-uboot-odessa-fix6.img` 21.123.072 B
  SHA256 `9738a2f95a5489ccafc5b64d902c3de7d183ba9ea5c7f224cfc789f3cd595693`
- `initramfs.cpio.gz` 3.766.112 B
  SHA256 `5529d7e88ea762ddadddaf2ab53195857e94d27188176b7d81b265c4bbc8c2b9`

---

## Revision 2026-11-06 23:05 UTC — Fix9-Ergebnis + Fix10 USB-Handoff

Fix9 (mainline PMIC-Regulatorgruppen) Ergebnis:
- `bound rpmh: 18220000.rsc` — RSC/cmd-db arbeiten.
- `qcom-rpmh-regulator soc:regulators-pm6150l: smps8: could not find RPMh
  address for resource smpc8` und `ldo15: devm_regulator_register() failed,
  ret=-22` -> Vendor-Init-Daten/DB-Namen passen nicht vollstaendig zur
  mainline PMIC-Tabelle. RPMh-Regulatorport bleibt offen (nicht USB-kritisch).

Fix10 = USB-Handoff (ABL hat USB-Clocks/PHY-Rails bereits an):
- ssusb: `qcom,dwc3` + QSCRATCH `0xa6f8800/0x400`, keine Clocks/Resets/Extcon,
  `qcom,select-utmi-as-pipe-clk`.
- dwc3-Kind: `phys = <&qusb>`, `phy-names = "usb2-phy"`,
  `peripheral`, `high-speed`.
- qusb: `qcom,qusb2-v2-phy`, `#phy-cells = <0>`, Fixed-Clocks `ref`/`cfg_ahb`
  (xo_board 19,2 MHz), Fixed-Regulatoren `usb_vdd`/`usb_vdda_pll`/
  `usb_vdda_dpdm` (always-on), kein Reset.
- Kernel-Patch: `devm_reset_control_get_optional_exclusive()` im QUSB2-Treiber.
- Initramfs-dmesg-Filter um `dwc3|qusb|udc|usb|phy` erweitert.

Artefakte:
- `Image-6.12-usb.gz` 14.8x MB SHA256 `815627efd6beaf34c5b16a11071e3aff7a520df5bdb6e6f57bc5b865c97b66f7`
- `odessa-6.12-fix10.dtb` SHA256 `a92f2e9d2c775afbeacd2bcd157fea88c50f85fbf1b89e3a06c425d0f0a99101`
- `fit-6.12-fix10.itb` SHA256 `1ff94f75098453bbd086a0794a1cb7ceed1e66d421a49c10938f6f64f471d4eb`
- `test-boot-uboot-odessa-fix10.img` SHA256 `e814ebcc33bc7df2b0049a98636896a63d9bc18390ab3d3ffc22fab39a648f03`
- `initramfs.cpio.gz` SHA256 `2d47971cc925fb38212c490dc4ae189d271f75057cb250ca1f93b2fa0cddfee3`

---

## Revision 2026-11-06 23:42 UTC — Fix10 haengt bei 0.504 s; Fix11 laesst U-Boot USB initialisieren

Fix10-Ergebnis: Der 6.12-Log endet bei **0.504 s** (letzte Zeile amba/coresight).
Der Kernel haengt beim ersten USB-Probe: ohne GCC-Treiber ist der USB-Block
(QSCRATCH 0xa6f8800, QUSB2 0x88e2000) nicht getaktet; der erste Registerzugriff
blockiert den Bus. Der Handoff allein reicht also nicht.

U-Boot kann die Luecke schliessen:
- `clock-qcs615.c` kennt die USB-Gates (USB30_PRIM_MASTER/MOCK_UTMI/SLEEP,
  CFG_NOC_USB3_PRIM_AXI, AGGRE_USB3_PRIM_AXI, PHY_AUX/PIPE/CLKREF).
- `phy-qcom-qusb2.c` matcht `qcom,qcs615-qusb2-phy`.
- `dwc3-generic.c` hat den Qualcomm-Glue fuer `qcom,snps-dwc3` (QSCRATCH,
  `qcom,select-utmi-as-pipe-clk`).
- `drv_usbacm_init`/`f_acm.c` stellt den `usbacm`-Console-Gadget bereit.

Fix11: U-Boot-Env `bootcmd=run serial_gadget; <FIT-Scan/bootm>`. Damit
initialisiert U-Boot DWC3+QUSB2 (Clocks/PHY an) und bootet erst dann den FIT.

- U-Boot `u-boot-dtb.bin` 1.509.904 B
  SHA256 `071e12b5bb694e285b45bca933c938e6dac740ac6beaea93fe13b18b57b49b78`
- `test-boot-uboot-odessa-fix11.img` 21.114.880 B
  SHA256 `9a1925802cc36115ca82236a10900ebaacf7c6e52d7b25fe1b5f00f31b99bf34`

Erwartung: U-Boot legt einen USB-ACM-Gadget an (Host sieht ggf.
`/dev/ttyACM0`); danach sollte Linux mit getaktetem USB-Block booten und
`udc: a600000.dwc3` zeigen. Haengt U-Boot schon beim Gadget, bleibt der
Bildschirm bei U-Boot stehen; dann ist der GCC-Port der naechste Schritt.

---

## Revision 2026-11-07 00:05 UTC — Fix11/Fix12: U-Boot-USB-Handoff unzuverlaessig

Fix11 (U-Boot `bootcmd=run serial_gadget; ...`) blieb stehen: `acm_stdio_start()`
wartete in `while (!acm_connected(dev))` endlos auf einen Host, der den
ACM-Port oeffnet. Fix12 entfernt diese Warteschleife (UDC/Clocks/PHY werden
trotzdem initialisiert).

User-Beobachtung (vermutlich Fix12 oder Fallback): U-Boot meldet
`Failed to find boot partition` (Snapdragon-Capsule-Update, harmlos),
`No ethernet found` (Netzwerk-Boot/Distro-Fallback) und
`no key labeled "Volume Down"` (button_cmd, harmlos). Fix9 bootet weiterhin
(sicherer Fallback).

Bewertung: `No ethernet found` stammt aus dem U-Boot-Netzwerkstack
(`eth-uclass`), d. h. es lief ein Distro-/Default-Bootpfad, nicht der
FIT-Scan. Entweder wurde der FIT durch die U-Boot-USB-DMA-Puffer
ueberschrieben (ABL-FIT-Adresse) oder der Custom-`bootcmd` schlug fehl.
Der U-Boot-USB-Handoff ist damit kein verlaesslicher Weg.

**Naechster sauberer Schritt:** Port des Vendor-`gcc-sdmmagpie`-Clocktreibers
(3363 Zeilen, gleiches clk-regmap-Framework wie mainline) in 6.12, damit
USB-Clocks/Resets (und spaeter UFS/Display) echt sind. RPMh-Regulatorport
(`smpc8`/`ldo15`) bleibt separat offen.

---

## Revision 2026-11-07 00:20 UTC — Phase 1/2: GCC-Port (SM6150/sdmmagpie) gestartet

Nutzerfreigabe: "Go for the GCC port". Fix9 bleibt der bootende Fallback.

**Ziel dieses Schritts:** `qcom,gcc-sdmmagpie` in Linux 6.12 mit den
**Vendor-Clock-IDs** registrieren, damit USB (DWC3/QUSB2), UFS und Display
echte Clocks/Resets bekommen. Kein Flashen, weiterhin alles RAM-only.

Bestandsaufnahme (Orchestrator, Strukturpruefung, noch kein Gate):

- DTB-Knoten vorhanden: `/soc/qcom,gcc@100000`, compatible
  `qcom,gcc-sdmmagpie`, `reg = <0x100000 0x1f0000>` (2031616 B),
  `#clock-cells = <1>`, `#reset-cells = <1>`.
  **Kein** `clocks`/`clock-names` (Vendor-DTS), dafuer `vdd_cx-supply`/
  `vdd_cx_ao-supply` (rpmh-Regulatoren, aktuell nicht probe-faehig).
- XO: `/xo-board` (fixed-clock, 19,2 MHz, `#clock-cells = <0>`, kein
  `clock-output-names`). Vendor-Treiber nutzt Parent-Namen `"bi_tcxo"`.
- Vendor-Quelle: `kernel/drivers/clk/qcom/gcc-sdmmagpie.c` (3363 Zeilen,
  4.14.190) + `include/dt-bindings/clock/qcom,gcc-sdmmagpie.h`
  (Clocks **und** Resets; Reset-IDs ab Zeile 182). Die Clock-IDs sind
  identisch mit `qcom,gcc-sm6150.h` (diff der `#define`-Zeilen leer), der
  DTB-Knoten heisst aber `qcom,gcc-sdmmagpie` -> dieser Compatible wird
  gematcht.
- Vendor-Fremd-APIs, die mainline 6.12 **nicht** hat:
  `vdd_class`/`num_rate_max`/`rate_max` (RCG-Corner-Voting, u. a. Z. 302-305),
  `DEFINE_VDD_REGULATORS`/`vdd-level-sdmmagpie.h` (Z. 34,42-43),
  `.type = FABIA_PLL` (PLL-Defs), `.hwclks`/`.num_hwclks` im `qcom_cc_desc`,
  `qcom_cc_register_rcg_dfs`/`gcc_sdmmagpie_dfs_desc`, `clk_dfs`.
- Ops-Mapping-Kandidaten: `clk_fabia_fixed_pll_ops` ->
  `clk_alpha_pll_fixed_fabia_ops`; `clk_generic_pll_postdiv_ops` ->
  `clk_alpha_pll_postdiv_ops`; `clk_branch2_hw_ctl_ops` und `clk_dummy_ops`
  fehlen in 6.12 (Port oder Ersatz zu klaeren; betrifft nur UFS-/measure-only-
  Clocks, nicht USB).
- Vendor-Probe verlangt `vdd_cx`/`vdd_cx_ao` per `devm_regulator_get`
  (Z. ~3290ff) -> wuerde ohne RPMh-Regulatoren dauerhaft `-EPROBE_DEFER`
  liefern; mainline-Probe (`gcc-sdm660`) kommt ohne Regulatoren aus.
- `qcom_cc_really_probe` (6.12) registriert Resets unbedingt, GDSCs nur wenn
  `desc->gdscs` gesetzt; `gcc-sdmmagpie.c` enthaelt **keine** GDSCs
  (USB-GDSC ist ein eigener DT-Knoten `/soc/qcom,gdsc@10f004`, phandle 0x25c).

Naechste Schritte: scout GCC-MAP-01 (Vendor-Inventar), scout GCC-MAP-02
(mainline-Mechanik), investigator GCC-INV-01 (hw_ctl/dummy-ops), danach
Synthese + Build.

### Gate-Ergebnisse Phase 1/2 (GCC-Port)

**Bestaetigt (Kandidaten nach Kontrolle):**
- `GCC-MAP-01`: Vendor-Inventar. Wichtigste Korrektur: `qcom,gcc-sdmmagpie.h`
  und `qcom,gcc-sm6150.h` haben **unterschiedliche** ID-Nummerierung
  (`GCC_USB30_PRIM_MASTER_CLK` 141 vs 147; `GCC_USB30_PRIM_BCR` 4 vs 2).
- Gegenprobe am DTB: ssusb `clocks = <0x27 0x8d 0x27 0x15 0x27 0x0b
  0x27 0x8f 0x27 0x91 0x27 0x92>` = 141/21/11/143/145/146 und diese IDs
  sind **nur** in `qcom,gcc-sdmmagpie.h` USB/CFG-NOC/Aggre/Mock-UTMI/Sleep/
  CLKREF. -> Port MUSS den sdmmagpie-Header und `qcom,gcc-sdmmagpie` nutzen.
- `GCC-MAP-02`: mainline-Mechanik. `qcom_cc_desc` hat `.clk_hws`/`.num_clk_hws`
  statt `.hwclks`; Resets werden unbedingt registriert; GDSCs nur bei
  `.gdscs`; `parent_names` werden bei der Registrierung nur kopiert, nicht
  aufgeloest (fehlende Namen -> Orphan, kein Probe-Fehler);
  `of_fixed_clk_setup` honoriert `clock-output-names`
  (`clk-fixed-rate.c:163,173`).
- `GCC-INV-01`: `clk_branch2_hw_ctl_ops` (nur 5 UFS-Clocks) == mainline
  `clk_branch_simple_ops` (exakt gleiche Register-Semantik, kein Halt-Wait,
  bereits exportiert). `clk_dummy_ops` (4 measure-only-Clocks) existiert in
  6.12 nicht -> lokale statische Ops im Treiber.
- `clk_fabia_fixed_pll_ops` -> `clk_alpha_pll_fixed_fabia_ops`;
  `.type = FABIA_PLL` -> `.regs = clk_alpha_pll_regs[CLK_ALPHA_PLL_TYPE_FABIA]`
  (Beleg: `camcc-sc7180.c:52-57`).
- `clk_generic_pll_postdiv_ops` -> `clk_alpha_pll_postdiv_ops`.

**Risiko notiert:** `CONFIG_SCSI_UFS_QCOM=y` und der DTB-Knoten
`ufshc@1d84000` (`qcom,ufshc`, aktiv) wird nach GCC-Bindung proben. UFS-GDSC
ist nicht registriert -> potenzieller zweiter Register-Hang. Fuer den
GCC-Test wird UFS im Test-DTB deaktiviert.

**Naechster Schritt:** Synthese (GCC-SYN-01) mit den bestaetigten Fakten:
Treiber `gcc-sdmmagpie.c`, Header-Kopie, Kconfig/Makefile,
Port-Skript mit Invarianten; danach Build + DTB (`clock-output-names =
"bi_tcxo"` an `/xo-board`) und RAM-Boot.

### Umsetzung GCC-Port (GCC-SYN-01 -> Build)

- Port-Skript: `/workspace/work/odessa/scripts/port-gcc-sdmmagpie.py`
  (Quelle: Synthesizer-Payload; ein Regex-Bug im hws-Array wurde korrigiert:
  Vendor-Array ist ohne `static` deklariert).
- Erzeugt: `drivers/clk/qcom/gcc-sdmmagpie.c` (3102 Zeilen),
  `include/dt-bindings/clock/qcom,gcc-sdmmagpie.h` (byte-identisch zum Vendor).
- Kconfig `SM_GCC_SDMMAGPIE` + Makefile-Zeile ergaenzt, `.config` aktiviert.
- Invarianten bestanden: 0 Vendor-Fremdtokens, 5x `clk_branch_simple_ops`,
  3x `clk_alpha_pll_fixed_fabia_ops`, 4x FABIA-`.regs`, 11 Resets,
  160 Clock-ID-Defines, 155 `clocks[]`-Eintraege, dichte 5er-hws.
- Test-DTB `odessa-6.12-fix13.dtb` (SHA256
  `409e99c92c4c2995f8a5864af3ba211615ea19c37a4dbddd6626269968300a9c`):
  `/xo-board` mit `clock-output-names = "bi_tcxo"`, `ssusb`, `qusb`,
  `ufshc`, `ufsphy_mem` auf `status = "disabled"` (erster GCC-Bindungstest
  ohne USB/UFS-Registerzugriff).
- Offen: `enable_safe_config` -> `clk_rcg2_shared_ops` (6 RCGs) als v2 des
  Skripts in Arbeit; v1 baut zunaechst ohne diese Praezisierung.

### Fix13 gebaut (GCC-Bindungstest, RAM-only)

Treiber kompiliert und eingebaut (`drivers/clk/qcom/gcc-sdmmagpie.o`,
`gcc_sdmmagpie` in `System.map`, String "Registered GCC clocks" im vmlinux).
v2-Skript mit `clk_rcg2_shared_ops` fuer die 6 RCGs ist angewendet
(6x shared, 32x plain, 38 Definitionen).

Test-DTB `odessa-6.12-fix13.dtb`:
- `/xo-board` -> `clock-output-names = "bi_tcxo"` (loest den Vendor-Parent-Namen
  per globalem Lookup auf)
- `ssusb@a600000`, `qusb@88e2000`, `ufshc@1d84000`, `ufsphy_mem@1d87000`,
  `sdhci@7c4000`, `sdhci@8804000` auf `status = "disabled"`
  (kein Registerzugriff auf Bloecke ohne registrierte GDSC/Power-Domain)

Boot-Image verwendet bewusst das **Fix9-U-Boot** (`7e7a4416...`, ohne
`serial_gadget`-bootcmd), nicht den Fix12-Build.

Artefakte (final):
- `out/Image-6.12-gcc.gz` 14.585.686 B
  SHA256 `419dfc0fb4c92dc0814eb33bd2ebc7317cee50b37604d07968c5675884bbc0c0`
- `out/initramfs.cpio.gz` SHA256
  `60a91e0bdab009466937dad1fb6a25627c9dffadc7327539b0b74820614abe28`
- `.re/uboot/odessa-6.12-fix13.dtb` 589.256 B
  SHA256 `708c33a054ebb3448f7590a8733ee66328e90cd8bd53ef11fac9bab56507f2f6`
- `.re/uboot/fit-6.12-fix13.itb`
  SHA256 `c05a46a342e7079d82acd2cb1c3a3fdae26e85e615781f5986d3540d3bb930d8`
- `.re/uboot/test-boot-uboot-odessa-fix13.img` 20.852.736 B
  SHA256 `c377379647f5d97da8c925ebdd5ad6b7dc64c3688569da2aff51173f565fd9a7`

Erwartung beim Boot: GCC bindet (`Registered GCC clocks`), `[init] gcc:` zeigt
`100000.qcom,gcc`, `[init] clocks (usb/pll/tcxo):` listet `gpll0`,
`gcc_usb30_prim_master_clk` etc. Kein Haenger bei 0.504 s.
Offen danach: USB/UFS/SD wieder aktivieren, echte USB-Clocks/Resets setzen.

### Fix13 Nachtrag: pstore-Ampel + finale Hashes

Initramfs schreibt jetzt zusaetzlich eine Ein-Zeilen-Ampel:
`[init] VERDICT gcc_bound=<0|1> usb_clk=<n>` und die erste `gpll0`-Zeile
aus `clk_summary`. Finale Artefakte:
- `out/initramfs.cpio.gz` `b30c5f8078c6422f834b6d246c21322ddadd82fcc7ab6881e85b5dbe38d7285d`
- `fit-6.12-fix13.itb` `b040eae862d6081b7852c63f11f71758c5d91c5415ab0483cc151ec289c220e3`
- `test-boot-uboot-odessa-fix13.img` `d1f001fffc41f3fdc35c549e56af2195e948ee6fbd1bc2c047cdb3f3a0d4cfb6`
Logpfad: ramoops `console-size=0x40000`; `[init]`-Zeilen stehen am Logende.

### Fix14 — Cmdline- und ramoops-Korrektur (2026-11-07)

Zwei echte Fehler gefunden:

1. **FIT-`bootargs` ueberschreiben die DTB-`bootargs`.** Alle FITs seit
   `fit-6.12.its` setzen nur
   `console=tty0 loglevel=8 ignore_loglevel pstore.backend=ramoops init=/init`.
   Damit waren `fbcon=font:TER16x32`, `clk_ignore_unused`, `pd_ignore_unused`,
   `keep_bootcon` und `panic=0` aus dem DTB **nie aktiv**. Folge: fbcon nutzte
   den Default-8x16-Font (kleiner Text) und `clk_disable_unused()` durfte nach
   der GCC-Registrierung unbenutzte NOC/Aggre-Clocks abschalten (Bus-Hang-
   Risiko).
2. **ramoops-Konsole zu klein / nicht wrap-sicher.** `console-size=0x40000`
   (256 KiB) bei `loglevel=8` + `ignore_loglevel`; pstore liest den Ringpuffer
   linear, daher ist `tail` nicht der echte Log-Schluss.

Fix14:
- Bootargs: `console=tty0 loglevel=7 fbcon=font:TER16x32
  pstore.backend=ramoops clk_ignore_unused pd_ignore_unused panic=0
  keep_bootcon init=/init`
- ramoops: `console-size=0x70000` (448 KiB), `pmsg-size=0x10000`,
  `record-size=0x3f800` (Summe weiterhin 0xbf800).

Artefakte:
- `odessa-6.12-fix14.dtb` `afbf660ac2f451cca39d75105505fd7fe34eaab0b389162f7cf579845b9cb119`
- `fit-6.12-fix14.itb` `f072b08fef4b5f6623c9f73e0fb17a77103c02a36ff3f8533080695d7b080e2c`
- `test-boot-uboot-odessa-fix14.img` `27e101fddb9a3df9b8f838ba5e52d53fc907ca6dd07616e94c99ab2de1ce1767`

### Fix16 — GCC-Blockade durch fw_devlink aufgeloest (2026-11-07)

Boot-Evidenz aus Fix13 (trotz garbled pstore lesbar):
- `[init] VERDICT gcc_bound=0 usb_clk=0`
- Deferred-Liste: `100000.qcom,gcc Platform: deferred probe pending:
  wait for supplier /soc/rpmh-regulators-cxlvl/regulator-pm6150l-s2-level-ao`

**Ursache:** Der Vendor-DTB-GCC-Knoten hat `vdd_cx-supply = <0x1d>` und
`vdd_cx_ao-supply = <0x1e>`. `fw_devlink` erzeugt daraus Device-Links; da die
RPMh-Regulatoren nie proben, wird das GCC-Device nie gebunden — obwohl der
mainline Treiber die Regulatoren gar nicht anfordert.

**Fix:** beide Properties aus `/soc/qcom,gcc@100000` entfernen (mainline nutzt
sie nicht). Zusaetzlich DTB-`bootargs` von `loglevel=8 ignore_loglevel` auf
`loglevel=4` gesetzt; die DTB-Cmdline ist die effektive (U-Boot ersetzt sie
nicht durch die FIT-`bootargs`).

Weitere bestaetigte Punkte:
- `/xo-board` -> `bi_tcxo` funktioniert; `clk_summary` zeigt
  `bi_tcxo 19200000`.
- `say()` muss `<3>` (KERN_ERR) schreiben, sonst greift der Loglevel-Filter.
- ramoops-Layout muss 0x40000/0x40000/0x3f800 bleiben, sonst ist der Record
  fuer den fix9-Leser ungueltig.

Artefakte (Fix16):
- `odessa-6.12-fix16.dtb` `2bdf152443339f6f157c7774038457dc8b8a2a7c977f5f8349c24aa99a99d409`
- `fit-6.12-fix16.itb` `bec3bee7a9f041398e3b6fd96bf4f41f773d5de8a8d02eaa01fd63cf38479b5b`
- `test-boot-uboot-odessa-fix16.img` `ee67ae47fbf7e96510e0b86958c7ec49d4ef9447214fc86228dfd002188e5055`

### Fix17 — USB mit echten GCC-Clocks/Resets (2026-11-07)

GCC-Bindung bestaetigt: `gcc_gpu_gpll0_clk_src 600000000` aus dem portierten
Treiber erscheint in `clk_summary`. Damit ist der GCC-Port funktional.

Fix17-DTB:
- Wrapper `usb@a6f8800` (vormals `ssusb@a600000`):
  `compatible = "qcom,sdm670-dwc3","qcom,dwc3"`, `reg = <0xa6f8800 0x400>`,
  Clocks in Index-Reihenfolge des Treibers (`of_clk_get(np, i)`):
  cfg_noc=21, core=141, iface=11, sleep=145, mock_utmi=143;
  `assigned-clock-rates = <19200000 133333333>` (beide in der Vendor-Freqtabelle);
  `resets = <&gcc 4>` (GCC_USB30_PRIM_BCR); `qcom,select-utmi-as-pipe-clk`.
  Entfernt: `USB3_GDSC-supply`, `dpdm-supply`, `extcon`, `iommus`,
  `qcom,smmu-s1-bypass` (alle wuerden Device-Links auf nicht probe-faehige
  Supplier erzeugen).
- Kind `dwc3@a600000`: `phys=<&qusb>`, `phy-names="usb2-phy"`,
  `dr_mode="peripheral"`, `maximum-speed="high-speed"`.
- PHY `qusb@88e2000`: `qcom,sdm670-qusb2-phy`/`qcom,qusb2-v2-phy`,
  `clocks = <&gcc 151 GCC_USB_PHY_CFG_AHB2PHY_CLK>, <&xo_board>`,
  Namen `cfg_ahb`, `ref`; `resets = <&gcc 9>` (GCC_QUSB2PHY_PRIM_BCR);
  Fixed-Supplies `vdd`/`vdda-pll`/`vdda-phy-dpdm`; Init-Seq unveraendert.
- UFS und beide SDHCI bleiben deaktiviert.

Artefakt: `odessa-6.12-fix17.dtb`
`a1b781baaebb1765d9c05cc1e1792ef142fb756afa96d7b4aa0e0fe4e7b9302f`.
Risiko: USB-GDSC ist ein separater Vendor-Knoten ohne mainline-Treiber; ist er
von ABL nicht eingeschaltet, kann der erste DWC3-Registerzugriff haengen.

### Fix20 — DWC3-Deferral auf PDC aufgeloest (2026-11-07)

Fix19-Evidenz (pmsg, lesbar):
```
[init] usb: dev=… wrap=… core=… phy=1
[init] a6f8800.usb  : supplier b220000.interrupt-controller not ready
        a600000.dwc3: supplier b220000.interrupt-controller not ready
[init] deferred count: 15
```
Ursache: Der PDC-Knoten `/soc/interrupt-controller@b220000` hat nur
`compatible = "qcom,pdc-sdmmagpie"` (mainline matcht `qcom,pdc`) und
`#interrupt-cells = <3>` statt `<2>`; zusaetzlich fehlt `qcom,pdc-ranges`.
Der Root-`interrupt-parent` ist der PDC (phandle 1), daher deferren alle
Geraete mit PDC-IRQs — inklusive DWC3-Wrapper und -Core.

Fix20 (USB umgeht den PDC):
- Wrapper `usb@a6f8800`: alle optionalen `interrupts`/`interrupt-names`
  entfernt (dp/dm/ss/qusb2 sind optional).
- Kind `dwc3@a600000`: `interrupt-parent = <&intc>` (phandle 26),
  `interrupts = <0 133 0>` (GIC SPI 133, identisch zu mainline sdm670).
- DTS-Datei von versehentlichen NUL-Bytes befreit (`\0` als Text).

Artefakt: `odessa-6.12-fix20.dtb`
`a47a64c74348bbc0a6f6e777e6877eee5eaf807f631d457640babc9b76f0cc8b`.

Offener Lead: PDC selbst mainline-faehig machen (`qcom,pdc`-Fallback +
`qcom,pdc-ranges` + `#interrupt-cells = <2>`), damit spaeter auch SPMI/PMIC
und die optionalen USB-IRQs funktionieren.

---

## MEILENSTEIN 2026-11-07 — USB/SSH auf Linux 6.12 erreicht

Live-Evidenz vom laufenden 6.12-System (SSH ueber USB-NCM):
```
Linux odessa 6.12.0 #10 SMP PREEMPT Sat Nov 7 00:37:16 UTC 2026 aarch64
/sys/class/udc: a600000.dwc3
usb0: inet 172.16.42.1/24
gcc_usb_phy_cfg_ahb2phy_clk 1 1 ... 88e2000.qusb cfg_ahb
bi_tcxo 2 2 ... 19200000 ... 88e2000.qusb ref
[init] bound UDC a600000.dwc3
[init] udc: a600000.dwc3
```

Kette: ABL -> U-Boot (Fix9-Binary, plain bootcmd) -> FIT -> Linux 6.12 ->
`qcom,gcc-sdmmagpie` -> DWC3/QUSB2 -> USB-NCM -> SSH. Kein
`serial_gadget`-Handoff, keine Fixed-Clock-Stubs, kein `dtbo`, alles RAM-only.

Funktionierende Artefakte:
- `out/Image-6.12-gcc.gz` `419dfc0fb4c92dc0814eb33bd2ebc7317cee50b37604d07968c5675884bbc0c0`
- `out/initramfs.cpio.gz` `31235f5366458a6224f883d2c1037ad3c7ffa47bf957c2d688d40f0678d42105`
- `odessa-6.12-fix20.dtb` `a47a64c74348bbc0a6f6e777e6877eee5eaf807f631d457640babc9b76f0cc8b`
- `fit-6.12-fix20.itb` `507bd06d73283caa8b1db6c43bc29d1493dce9a734bb64a98de4d66a4561c4a2`
- `test-boot-uboot-odessa-fix20.img` `eab1be4942c79763caa2a63b6bab2e18e47e8ba4b41d7d4afb20a6ab4242b993`

Offen: zwei `dwc3_gadget_init+0x74`-Warnungen beim Probe (funktional
unkritisch, UDC/Gadget laufen); PDC/RPMh/UFS noch nicht mainline-faehig.

### Fix21–Fix23 — Warnung, PDC-Bypass, XO-Rename (2026-11-07)

- **Fix21**: DWC3-Core-IRQ `interrupts = <0 133 4>` (IRQ_TYPE_LEVEL_HIGH).
  Ursache der Warnung: `WARN_ON(*type == IRQ_TYPE_NONE)` in
  `gic_irq_domain_translate`.
- **Fix22**: Root-`interrupt-parent` = GIC (0x1a) statt PDC; bogus
  `/soc/qcom,cmd-db@c3f000c` entfernt. Ergebnis: SPMI/PMIC-Arbiter probt jetzt
  (`PMIC arbiter version v5`), USB/SSH laeuft weiter.
  Nebenbefund: 9 GIC-Type-Warnungen von Vendor-Knoten mit `IRQ_TYPE_NONE`
  (kosmetisch; spaeter IRQ-Typen normalisieren).
- **Fix23**: Fixed XO-Clock heisst jetzt `xo_board` (DTS) und der GCC-Treiber
  verwendet `"xo_board"` als Parent (12 Stellen im Port-Skript). Damit kann
  `clk-rpmh` seine ARC-Clock `bi_tcxo` registrieren (vorher -EEXIST).
  Neues Image: `out/Image-6.12-gcc23.gz`
  `edef7dd81d259f5680a27e58285952d37d17e9decf49c7705ef07225c84fa5f6`.

Offene Kette fuer UFS: clk-rpmh -> RPMH_CXO_CLK -> UFS ref_clk;
RPMh-Regulatoren (aktuell 0 registriert) -> UFS-Rails; UFS-GDSC.

### Fix24 — UFS-Enablement (2026-11-07)

Nach UFS-INV-01 (CONFIRMED):
- HC: `status=okay`, `reset-names="rst"` (mainline erwartet "rst", nicht
  "core_reset"), `#reset-cells=<1>` (PHY nutzt `<&ufshc 0>`), IRQ-Typ LEVEL_HIGH.
  Entfernt: `vdd-hba-supply` (zeigt auf den Vendor-GDSC `ufs_phy_gdsc`),
  `vcc`/`vccq2`/`vddp-ref-clk`-Supplies und alle Vendor-Bus/QoS-/Voltage-Props.
  Keine `interconnects`/`power-domains` (waeren Deferral-Fallen).
- PHY: `compatible="qcom,sm7150-qmp-ufs-phy"` (v3-Regs, 1 Lane,
  UNVERIFIED_HYPOTHESIS), `reg=<0x1d87000 0x1000>`,
  `clocks=<&xo_board>,<&gcc 132>,<&gcc 124>`, Namen `ref/ref_aux/qref`,
  `resets=<&ufshc 0>`, Namen `ufsphy`.
  Rails als Fixed-Regulatoren: `ufs_vdda_phy` 824 mV, `ufs_vdda_pll` 1144 mV
  (always-on; Werte aus den Vendor-PMIC-Knoten).

Risiko: Der UFS-PHY-GDSC ist im portierten GCC nicht registriert; ist er von
ABL nicht an, haengt der erste PHY-Registerzugriff. Fallback: Fix23-Image.

Artefakte: `odessa-6.12-fix24.dtb`
`2975329be9236068cf5f50e743459a89d1294380f2f64db7dbc554c2409968d5`,
`fit-6.12-fix24.itb` `772d7bd552e7fd6b0c39f3cc9ce8476cd9417982dc35dd1f58589b4a163fd6c1`,
`test-boot-uboot-odessa-fix24.img` `e9336509254ff5023b5f2894f534edc2c07848c324e5cd964c8ad37d3f7b162a`.

### Fix25 — UFS-ref_clk auf xo_board (2026-11-07)

Fix24-Lauf: UFS-Core probt, aber `ufshcd_init_clocks: ref_clk clk get
failed, -517`, deferred auf `soc:qcom,rpmh` (Vendor-Knoten mit
compatible `qcom,rpmh-clk-sdmmagpie`, kein mainline-Treiber). Die PWM-Clocks
des HC loesen auf; nur der 6. Clock-Eintrag (`<0x2f 0x00>`) zeigte dorthin.
Fix25: `<0x2f 0x00>` -> `<0x86>` (xo_board, 19,2 MHz = gueltige bRefClkFreq).

Weitere Beobachtungen: fw_devlink meldet den Zyklus
`ufshc <-> ufsphy` (HC `phys`, PHY `resets`) und "fixt" ihn — unkritisch.

Artefakte: `odessa-6.12-fix25.dtb`
`392754a4920b10df239abd2c6391537d62081d7f4fc9da227cbe92d83788e430`,
`fit-6.12-fix25.itb` `43630ea0fb0767899f16e5d6fc84c930c2fdc880b7ab5b0909ab58439441f9ef`,
`test-boot-uboot-odessa-fix25.img` `3dd4b65da0d921ae9c20529ee20f6a263acb4352b05579258fd249fec4bf127b`.

### Fix26/Fix27 — UFS laeuft, switch_root vorbereitet (2026-11-07)

Fix25-Lauf: HC probe ok, aber `ufshcd_pltfrm_init() failed`/Deferral, weil
`CONFIG_PHY_QCOM_QMP_UFS=m` — der UFS-QMP-PHY war nur ein Modul und nicht im
Initramfs. Fix26 baut ihn fest ein (`=y`).

Fix26-Ergebnis (live): alle UFS-LUNs enumeriert (sda..sdf), `sdb24` 109 GiB
vorhanden. Damit sind GCC, USB/SSH und UFS auf 6.12 funktional.

Fix27 haengt `odessa.boot=ubuntu` an die effektive DTB-Cmdline; der Init
wechselt dann per `switch_root` auf die Ubuntu-Installation auf /dev/sdb24.

Artefakte:
- `out/Image-6.12-gcc26.gz` `7c5d876aecb6ccdf7f2b9abb40689a2a6f59e0d31a1afa76e842870b30aaa69f`
- `odessa-6.12-fix27.dtb` `c9d4ca4c586b22e903843cf2f1c05470df005a97f2011eb383b0e7cac9f6622d`
- `fit-6.12-fix27.itb` `fc37d17d9efbfc8ecbfd9dfe64e7a6610c448bbf70a56e846a1658603a7b1a90`
- `test-boot-uboot-odessa-fix27.img` `1a9bc2a5e09cc40ab8aad1ac5b7b301b163cb7d650e3c6c64bfabca8507958e0`

---

## FINALER STAND 2026-11-07 — Ziel erreicht

Live-Evidenz (SSH auf 172.16.42.1):
```
uname -r                      -> 6.12.0
/ (proc/mounts)               -> /dev/sdb24 ext4
/etc/os-release               -> Ubuntu 22.04.5 LTS (jammy)
/sbin/init                    -> 1341-Byte-Shellskript (minimales debootstrap,
                                 kein systemd; /usr/sbin/init existiert)
/proc/cmdline                 -> ... fbcon=font:TER16x32 ... odessa.boot=ubuntu
[init] switching root to /dev/sdb24 (ubuntu)
```

Kette: ABL -> U-Boot (Fix9-Binary, plain bootcmd) -> FIT -> Linux 6.12 ->
qcom,gcc-sdmmagpie -> DWC3/QUSB2 -> USB-NCM/SSH -> UFS -> switch_root ->
Ubuntu 22.04.5 auf /dev/sdb24. Alles RAM-only, kein Flash, dtbo unberuehrt.

**Entscheidende Erkenntnis am Ende:** Der Kernel war mit
`CONFIG_CMDLINE_FORCE=y` gebaut; die Bootloader-/DTB-Cmdline wurde komplett
ignoriert (daher fehlten `odessa.boot=ubuntu` und `fbcon=font:TER16x32`).
Fix28: `CONFIG_CMDLINE_FROM_BOOTLOADER=y`, FIT-Cmdline mit `odessa.boot=ubuntu`.

### Funktionierende Artefakte (final)

| Artefakt | SHA256 |
|---|---|
| `out/Image-6.12-gcc28.gz` | `48a3972cd325e51050270d6ea182f157ad4150d04199bb983359b18d4c1ad4fe` |
| `out/initramfs.cpio.gz` | `31235f5366458a6224f883d2c1037ad3c7ffa47bf957c2d688d40f0678d42105` |
| `.re/uboot/odessa-6.12-fix27.dtb` | `c9d4ca4c586b22e903843cf2f1c05470df005a97f2011eb383b0e7cac9f6622d` |
| `.re/uboot/fit-6.12-fix28.itb` | `b691de13af3accc6bd412aadf9039a903c4023fd667dc49761a29f18faf3901b` |
| `.re/uboot/test-boot-uboot-odessa-fix28.img` | `5cd60228b9f6c0d02817bb7bbbef5f8718963ff4fc0cbe87fa8085a4cf7b7b0c` |
| U-Boot-Binary (Fix9, plain bootcmd) | `7e7a4416a5f5831e43eeb20be8e0464d7eaba3f98a776f88c82ca22b9574597b` |

Quellen: `scripts/port-gcc-sdmmagpie.py`, `.re/uboot/abl-merged-gcc.dts`,
`initramfs-src/init`.

### Offene Leads (nicht bootkritisch)
1. PDC mainline-faehig (`qcom,pdc`-Fallback, `qcom,pdc-ranges`, 2 Zellen) ->
   SPMI/PMIC vollstaendig, Tasten, optionale USB-IRQs.
2. RPMh-Regulatoren statt Fixed-Rails (cmd-db liefert `smpc8`/`bobc1`;
   Registrierung scheitert derzeit an der DT-/Treiber-Erwartung).
3. 9 GIC-`IRQ_TYPE_NONE`-Warnungen in Vendor-Knoten normalisieren.
4. Optional: 32x64-Font fuer die Display-Konsole.
5. Optional: volles Ubuntu mit systemd statt Shell-Init.

---

## Freigabe 2026-11-07 — vier Aufraeum-Leads (W1-W4)

Nutzerfreigabe fuer alle vier offenen Punkte. Arbeitsstand-Basis: Fix28
(`test-boot-uboot-odessa-fix28.img`, `5cd60228…7b7b0c`) laeuft und bleibt
unveraenderter Fallback. Weiterhin RAM-only, kein Flash.

### Auftraege (State-Board)

| ID | Ziel | Risiko | Status |
|---|---|---|---|
| W1 | PDC mainline-faehig: `qcom,pdc`-Fallback, `qcom,pdc-ranges`, `#interrupt-cells=<2>`, `wakeup-parent` | mittel | Investigation laeuft |
| W2 | RPMh-Regulatoren statt Fixed-Rails (pm6150/pm6150l/pm8009) | niedrig (keine Verbraucher haengen daran) | Investigation laeuft |
| W3 | 9 `IRQ_TYPE_NONE`-Warnungen normalisieren | niedrig | wartet auf exakte dmesg-Liste |
| W4 | Volles systemd-Ubuntu auf /dev/sdb24 | mittel (SSH-Kanal!) | wartet auf Rootfs-Diagnose |

### Geplante Test-Leiter (jeweils ein RAM-Boot, Fallback Fix28)

1. **Fix29** = W3 (nur IRQ-Typen). Erwartung: 0 `gic_irq_domain_translate`-
   WARNs, USB/UFS/SPMI unveraendert.
2. **Fix30** = Fix29 + W1 (PDC bindet, `wakeup-parent` auf TLMM).
   Erwartung: `qcom-pdc b220000.interrupt-controller: ...`, SPMI/PMIC/USB
   unveraendert, keine Disconnect-Warnungen.
3. **Fix31** = Fix30 + W2. Erwartung: `qcom-rpmh-regulator` registriert
   Regler (Anzahl > 0), `regulator_summary` zeigt pm6150/pm6150l/pm8009.
4. **W4** getrennt vom Kernel: Rootfs-Umbau auf systemd, eigener Boot-Test.

### Bekannte Ausgangsdaten (belegt)

- PDC-Vendor-Tabelle: `kernel/drivers/irqchip/qcom/pdc-sdmmagpie.c:17-145`,
  Paare `{pdc_pin, gic_hwirq}`. Mainline braucht Tripel
  `qcom,pdc-ranges = <pin_base parent_base cnt>` und 2-Zellen-Translate
  (`qcom-pdc.c:266,275-304`); Match nur `"qcom,pdc"` (`:370`).
- RPMh: mainline bildet den Ressourcennamen aus **Child-Name + pmic-id**
  (`smps8`+`c` -> `smpc8`); `smpc8`-Lookup liefert 0, `ldo15`
  `devm_regulator_register` = -22. `CONFIG_REGULATOR_QCOM_RPMH=y`.
- cmd-db: `drivers/soc/qcom/cmd-db.c` hat Debugfs `cmd-db`
  (`:364`, Dump `cmd_db_debugfs_dump`), damit laesst sich die echte
  Ressourcenliste am Geraet lesen.
- systemd: Rootfs ist debootstrap + Shell-Init (`/sbin/init` 1341 B),
  `/usr/sbin/init` existiert, `/etc/systemd` existiert. Paketstand unbekannt.

### Fix29 — PDC mainline-faehig (2026-11-07)

Umsetzung von PDC-INV-02 (Evidence Gate bestanden, Belege kontrolliert):

- `interrupt-controller@b220000`: `compatible = "qcom,sdmmagpie-pdc","qcom,pdc"`,
  `reg = <0xb220000 0x30000>` (Treiber mappt ohnehin `max(reg,0x30000)` und warnte
  vorher), `#interrupt-cells = <0x02>`,
  `qcom,pdc-ranges = <0 512 94>, <94 641 31>, <125 95 1>`.
  Die Tripel sind aus der Vendor-Tabelle `pdc-sdmmagpie.c:17-145` (126 Paare)
  mechanisch verdichtet; `parent_base` = GIC-hwirq, `cnt` = Pin-Anzahl.
  Der nicht-monotone Lauf `<125 95 1>` ist gueltig (`get_pin_region` ist ein
  linearer Scan ohne Sortier-/Ueberlappungspruefung).
- 7 `interrupts-extended`-Konsumenten des Vendor-PDC-Phandles `0x01` auf GIC
  `0x1a` umgehaengt (ADSP/CDSP/modem PIL, 4 QUP-UARTs). Beide Compatible-
  Familien haben keinen Mainline-Treiber (`qcom,pil-tz-generic`,
  `qcom,msm-geni-serial-hs`), die Aenderung ist daher inert, verhindert aber
  den Zellen-Shift beim Wechsel 3 -> 2.
- Root-`interrupt-parent` bleibt GIC; PDC bleibt Kind der GIC.
  `wakeup-parent` ist bewusst **nicht** gesetzt (Phase B, erst nach
  bestaetigter Bindung; ohne Suspend derzeit ohne Nutzen).

Verifikation am Geraet: `ls /sys/bus/platform/drivers/qcom-pdc/` muss
`b220000.interrupt-controller` zeigen; dmesg darf weder
`invalid reg size, please fix DT` noch `failed to init PDC pin-hwirq mapping`
enthalten; SPMI/USB/UFS muessen unveraendert bleiben.

Artefakte: `odessa-6.12-fix29.dtb`
`a5178e1b0b444fc63495dc82fd48520c7d8365e189a87f3e24ef018f57309524`,
`fit-6.12-fix29.itb` `153aa7089b1f65259d751ee48679135d208b5ea23b518adbd13e77a28cf7e603`,
`test-boot-uboot-odessa-fix29.img` `cda5dea7ae8d758d275745d8137af03c3297c83f176f738e3c40f6450e886e6c`.

### Diagnose-Bedarf (offen, eine Geraete-Runde)

1. exakte 9 `gic_irq_domain_translate`-WARN-Blöcke (Backtrace nennt den
   aufrufenden Treiber) -> daraus Fix30 (IRQ-Typen).
2. `cat /sys/kernel/debug/cmd-db` -> entscheidet W2: existiert `smpc8`
   (fehlend vs. `0x00000`) und ist die Region `0x1078` gross genug?
3. Rootfs-Paketstand (systemd/systemd-sysv/udev/dbus, `/lib/systemd/systemd`)
   -> entscheidet W4 (lokaler Umbau vs. Paketbeschaffung).

### Fix29-Lauf — Ergebnis und Korrektur (2026-11-07)

- **PDC-Check war falsch benannt:** `IRQCHIP_PLATFORM_DRIVER_END(qcom_pdc)`
  erzeugt `.name = "qcom_pdc"` (`include/linux/irqchip.h:56`). Das
  Sysfs-Verzeichnis heisst also `qcom_pdc`, nicht `qcom-pdc`. Der Treiber ist
  builtin (`drivers/irqchip/qcom-pdc.o`, `System.map` enthaelt `qcom_pdc_*`);
  die Bindung ist damit sehr wahrscheinlich, aber noch nicht live bestaetigt.
- Keine Regression: `scsi host0: ufshcd`, UFS-Partitionen und
  `bound UDC a600000.dwc3` unveraendert.
- Die **9** GIC-Warnungen sind unveraendert (wie erwartet); die
  `-A16`-Auszuege enthielten nur Register, nicht die Call-Traces. Fuer die
  Zuordnung fehlen die Symbolzeilen der Backtraces.

#### cmd-db-Dump (live, Beweis)

`/sys/kernel/debug/cmd-db` (VRM v1.0) enthaelt:
`smpa1..5`, `ldoa1..19`, `smpc1`, `smpc2`, `smpc7`, `smpc8` (0x40300),
`ldoc1..11`, `bobc1` (0x40400), `pbs`, `vrm.*`.
**Nicht** enthalten: `smpf*`/`ldof*` (PM8009) und `smpc3..6`.
=> `smpc8` existiert; die frueher beobachtete Meldung stammt aus dem alten
fix9-DTB. PM8009 ist auf odessa offenbar nicht vorhanden (oder nicht in der
DB) und ist der einzige Container, der zwingend scheitern muss.

#### Fix30 — RPMh-Regulatoren aktiviert

- PM8009-Container entfernt (unreferenziert; alle Kind-Phandles nur
  SelbstdEFinition). PM6150 (pmic-id `a`) und PM6150L (pmic-id `c`) bleiben.
- Resource-Namen geprueft: `smp%s1`->`smpc1`, `smp%s8`->`smpc8`,
  `ldo%sN`->`ldocN`, `bob%s1`->`bobc1` — alle in der DB.
- Keine `regulator-always-on`/`boot-on`-Flags an den Kindern, daher kein
  Schreibzugriff auf RPMh beim Registrieren (nur Registrierung/Readback).

Artefakte: `odessa-6.12-fix30.dtb`
`1d107b49197d1f30d3282747238fec1ed394589772db5d4aa1a151fe279c1136`,
`fit-6.12-fix30.itb` `c59fe96ac7761f8df67917f97fb0be85fa7f13657629042d510ec446681d3fac`,
`test-boot-uboot-odessa-fix30.img` `f763eb1137739eecd98fc6b5208bf281766ff564b624b10eb8b3222356453e60`.

### W4 — systemd: Blocker Paketquelle

- `ubuntu-base-22.04.5-base-arm64.tar.gz` enthaelt **kein** systemd
  (`tar tzf | grep lib/systemd/systemd` leer).
- Kein lokaler Deb-Cache (`rootfs-dl`, `rootfs/var/cache/apt`, Host-Cache leer).
- Host-APT zeigt auf `archive.ubuntu.com`/`security.ubuntu.com` (Internet).
- Das Staging-Rootfs `/workspace/work/odessa/rootfs` hat bereits
  systemd-Units (`usb-gadget.service`, `dropbear.service`, `battery-guard.*`),
  aber keine systemd-Binaries.
=> Ohne Nutzerentscheidung zur Paketquelle ist W4 nicht fortsetzbar (Regel:
nur lokale Artefakte ausserhalb der freigegebenen LANs).

### Fix29-Lauf: W1 bestaetigt, W2/W3 eingegrenzt (2026-11-07)

**W1 CONFIRMED (live):** `/sys/bus/platform/drivers/qcom_pdc/` enthaelt
`b220000.interrupt-controller`; keine `invalid reg size`/`failed to init PDC
pin-hwirq mapping`-Meldung. Der Treibername ist `qcom_pdc` (Unterstrich,
`IRQCHIP_PLATFORM_DRIVER_END(qcom_pdc)` -> `.name = #drv_name`).

**W2 — exakte Ursache des -22:** Die ABL-DTB enthaelt zwei **3-Byte**-
Properties statt u32:
- `regulators-pm6150/ldo17: regulator-max-microvolt = [01 51 00]`
- `regulators-pm6150l/bob: regulator-min-microvolt = [02 4b 00]` (und
  `qcom,init-voltage` identisch)
`of_property_read_u32()` scheitert daran (`-EINVAL`), die Constraints bleiben
unvollstaendig, `devm_regulator_register()` bricht mit -EINVAL ab; der erste
Fehler killt den ganzen Container (devm-Cleanup -> 0 Regler).
Vendor-Sollwerte: `ldo17` max 3.232.000 uV
(`sdmmagpie-regulator.dtsi:505`), `bob` min 3.296.000 uV
(`sm6150-regulator.dtsi:747`). Beide liegen in den Mainline-Fenstern
(pldo 1.504-3.544 V, bob 3.0-3.992 V). `ldo16` max ist 4 Byte (0x2d6900) und
war daher unauffaellig.

**W3 — Struktur der 9 Warnungen:** Ein einzelner IRQ-Mapping erzeugt **3**
WARNs (Phasen: `gic_irq_domain_select` -> `gic_irq_domain_translate`,
`irq_create_fwspec_mapping` -> translate, `gic_irq_domain_alloc` ->
translate). Die drei gezeigten Traces sind also **ein** Mapping:
`spmi_pmic_arb_bus_init` -> `of_irq_get_byname(node,"periph_irq")`.
=> 9 WARNs = 3 Mappings; eines ist der SPMI-`periph_irq`
(`interrupts = <0 0x1e1 0>`), jetzt LEVEL_HIGH. Die anderen zwei Mappings
sind noch nicht identifiziert (sdhci ist `disabled`, i2c/spi-geni sind
Module, tsens/wdt-compatibles matchen mainline nicht) -> Symbol-Histogramm
der Backtraces noetig.

#### Fix31

- `ldo17` max -> `0x315280` (3.232.000 uV)
- `bob` min + `qcom,init-voltage` -> `0x324b80` (3.296.000 uV)
- SPMI `interrupts` -> `<0 0x1e1 IRQ_TYPE_LEVEL_HIGH>`

Artefakte: `odessa-6.12-fix31.dtb`
`d585b9aa268d2c8c1e90f0993eedcf6307a936a7415a7503c5b7af46ffa16ff9`,
`fit-6.12-fix31.itb` `1a03e99507b83b6649b7d2b2d4e6a30d7c3604045517cb43af04db14617dcc1c`,
`test-boot-uboot-odessa-fix31.img` `e9e467e6d55bc526d71cad52dc1c22d51f9570ba89d286d38fc1ba2f8dd86570`.

### W4 — weiterhin Entscheidung offen

Kein systemd im ubuntu-base-Tarball, kein lokaler Deb-Cache, Host-APT nur mit
Internetquellen. Optionen A (Host-NAT + apt auf dem Geraet), B (Nutzer laedt
arm64-debs lokal), C (ausdrueckliche Netzfreigabe fuer den Paketabruf).

### Fix31-Regress: Haenger vor der Initramfs-Ausgabe (2026-11-07)

Symptom: Anzeige bleibt bei U-Boot `Starting Kernel . . .` stehen, kein
`[init]`-Output, kein SSH (offen bestaetigt).

Einordnung:
- Die `mkimage`-Warnung `compression nodes for ramdisks are deprecated` ist
  **nicht** die Ursache: die `.its` ist seit Fix28 unveraendert (Ramdisk
  `compression = "gzip"`), Fix28/29/30 booten damit.
- Es ist **kein** Beweis fuer einen sehr fruehen Haenger: `loglevel=4`
  unterdrueckt alle `pr_info`; die erste sichtbare Konsolenzeile ist das
  `say()` der Initramfs (~4 s). Ein Haenger bei 1,06 s (RPMh-Regler) und bei
  1,24 s (SPMI) sieht identisch aus.
- DTB-Diff Fix30 -> Fix31 enthaelt exakt drei Aenderungen: SPMI-IRQ-Typ,
  `ldo17`-max, `bob`-min/init. Kein Strukturschaden.

Bisect-Artefakt **Fix32 = Fix30 + nur SPMI-IRQ-Typ** (Regler-Aenderungen
zurueckgenommen; `abl-merged-gcc.dts` entspricht Fix32, Fix31-Quellstand als
`abl-merged-gcc-fix31.dts` gesichert).

Artefakte: `odessa-6.12-fix32.dtb`
`e4a9ad19a756bc6a86e5db907bb235339259069c9a4bcbb98fe6df1a65d58bf5`,
`fit-6.12-fix32.itb` `6574a000a8407aa91770875ef39a701bfc7001e209a5f11819b5ef16f696f3fb`,
`test-boot-uboot-odessa-fix32.img` `6f809fe2ab9c199687aa49628c2ebc16646dff5029cef92b7bfe755e66aea760`.

Entscheidung:
- Fix32 bootet -> SPMI-Aenderung unbedenklich, Regler-Aenderung ist die
  Ursache; danach `ldo17` und `bob` getrennt testen.
- Fix32 haengt -> SPMI-IRQ-Typ ist die Ursache (Level-IRQ-Storm moeglich);
  dann Typ zurueck auf NONE und W3 anders loesen.

### Korrektur: Fix31 "haengt" nicht — SSH laeuft (2026-11-07)

Live: `ssh root@172.16.42.1 'uname -r'` -> `6.12.0`, dmesg bis 11.8 s
vorhanden. Der Kernel bootet also; die Anzeige bleibt auf dem U-Boot-Text
`Starting Kernel . . .` stehen. Damit ist der vermutete Regress **kein**
Boot-Haenger.

Neue Befunde aus dem dmesg-Rest:
- `Failed to enable clk 'gcc_gpu_memnoc_gfx_clk': -16` und
  `arm-smmu 5040000.arm,smmu-kgsl: probe with driver arm-smmu failed with error -16`
  (GPU-SMMU, nicht bootkritisch).
- `platform 1..3.gpio-regulator: deferred probe pending: ... wait for supplier
  /soc/regulators-pm6150l/smps8` und `soc:gpio_keys: ... wait for supplier
  /soc/pinctrl@3400000/tlmm_gpio_key/gpio_key_active` (fw_devlink-Deferrals).

Offen: ob die laufende Image-Version Fix31 (Regler gebunden) oder Fix32
(Fix30 + SPMI) ist, und ob `simpledrm`/`fbcon` ueberhaupt bindet.
`CONFIG_DRM_SIMPLEDRM=y`, `CONFIG_FRAMEBUFFER_CONSOLE=y`,
`CONFIG_FB_SIMPLE` **nicht** gesetzt; der DTB-Knoten `framebuffer@9c000000`
(`simple-framebuffer`, a8r8g8b8, 0x438x0x960, stride 0x10e0) ist seit Fix28
unveraendert.

Moeglicher Spaet-Effekt: `regulator_init_complete` plant nach **30 s** das
Abschalten ungenutzter Regler (`schedule_delayed_work(..., 30000)`); falls
die DSI-PHY-Rails (ldo3/ldo4) darunter sind, koennte das Display danach
einfrieren. Erst nach Sicherung der Bildschirm-Diagnose bewerten.

### Fix32-Lauf: Bisect-Ergebnis + Console-Nachweis (2026-11-07)

Laufendes Image ist Fix32 (Fix30 + SPMI). dmesg:
- `pm6150l_bob: invalid voltage constraints` + `bob: devm_regulator_register()
  failed, ret=-22` und `ldo17: ... ret=-22` -> bestaetigt die 3-Byte-Property-
  Ursache (der Core meldet jetzt explizit die ungueltigen Constraints).
- SPMI-Aenderung verursacht keinen Haenger -> **Fix32 bootet**.
- Bildschirm-Console ist vorhanden und korrekt:
  `fb0 -> 9c000000.framebuffer`, Name `simpledrmdrmfb`,
  `Console: switching to colour frame buffer device 67x75` (16x32-Font),
  `fbcon` ist gebunden. `simple-framebuffer ... could not acquire memory
  region [0x9c000000-0x9c9e33ff]` ist erwartbar: der Bereich ueberlappt
  `reserved-memory/cont_splash_region@9c000000` (no-map); simpledrm faehrt
  trotzdem fort.
- `[init] switching root to /dev/sdb24 (ubuntu)` bei 3.85 s, dropbear 4.06 s,
  uptime 145 s -> vollstaendiger Boot.

Offen: ob das Panel das Framebuffer noch scannt (Bildschirm-Update) und ob
Fix31 (gueltige Reglerwerte) die Regler wirklich bindet. Naechster Test:
`echo "<3>..." > /dev/kmsg` + `md5sum /dev/fb0` vor/nach.

### Anzeige geklaert + Fix33 (2026-11-07)

Sehtest bestaetigt: `head -c 10368000 /dev/zero > /dev/fb0` macht den Schirm
schwarz, ein folgender `<3>`-kmsg-Eintrag zeichnet die Konsole wieder.
=> Scanout und fbcon laufen; "Starting Kernel . . ." war nur der Zustand bis
zum ersten Kernel-Output (`loglevel=4`).

Risiko gefunden: `regulator_late_cleanup()` (30-s-Work) deaktiviert Regler,
die enabled, unbenutzt und nicht `always_on` sind (`core.c:6394`); ein
`always-on` im DT wuerde wegen der fehlenden `vdd-*`-Parentsupplies
`-EPROBE_DEFER` ausloesen. Sauberer Hebel: Kernel-Parameter
`regulator_ignore_unused` (`core.c:6376`) -> der Work kehrt sofort zurueck
und loggt `regulator: Not disabling unused regulators`.

**Fix33** = Fix31-DTB (korrigierte `ldo17`/`bob`-Werte + SPMI LEVEL_HIGH) +
`regulator_ignore_unused` in den FIT-Bootargs. Damit sollten beide Container
binden (~31 Regler) und die DSI-PHY-Rails (ldo3/ldo4) nicht abgeschaltet
werden.

Artefakt: `test-boot-uboot-odessa-fix33.img`
`2f6a0342738c604c9eabab305c1d04827324ad1e0823eeafe2e68de1c2803361`
(FIT `odessa-6.12-fix33.itb`, DTB unveraendert Fix31
`d585b9aa268d2c8c1e90f0993eedcf6307a936a7415a7503c5b7af46ffa16ff9`).

### Fix33 haengt (bestaetigt), Fix34 = Diagnose-Image (2026-11-07)

Rueckmeldung: Fix32 bootet wieder; Fix33 ("Fix31-DTB + regulator_ignore_unused")
nicht. Da `regulator_ignore_unused` erst im 30-s-Work greift und der Work
vorher noch `regulator_register_resolve_supply` fuer alle Regler aufruft,
bleiben zwei Moeglichkeiten: (a) Haenger schon bei der Registrierung/Probe,
(b) Haenger im 30-s-Work trotz ignore_unused.

Deshalb **Fix34** = Fix33-Inhalt + `ignore_loglevel` + `initcall_debug`,
damit der letzte Initcall auf dem Display sichtbar ist (bisher verschluckte
`loglevel=4` jeden Fortschritt; "Starting Kernel . . ." ist KEIN
Fehlerindikator).

Artefakt: `test-boot-uboot-odessa-fix34.img`
`b8096568a0279f7a96bb9b46334fb57f461790961481661d31476d565995d5f0`
(DTB Fix31 `d585b9aa…a16ff9`, FIT `fit-6.12-fix34.itb`).

### Fix34-Lauf: Haenger vor fbcon bestaetigt; Mechanismus + Fix35 (2026-11-07)

Auch mit `ignore_loglevel`/`initcall_debug` keine Ausgabe -> der Haenger liegt
**vor** fbcon (~1,15 s), also im RPMh-Regler-Probe (~1,06 s).

Mechanismus-Kandidat (Code-belegt): `rpmh_rsc_send_data()`
(`drivers/soc/qcom/rpmh-rsc.c:658-661`) wartet mit
`wait_event_lock_irq(drv->tcs_wait, (tcs_id = claim_tcs_for_req(...)) >= 0, ...)`
**unbegrenzt** auf einen freien TCS, mit IRQs aus. Der einzige *neue*
Codepfad gegenueber Fix32 ist `ldo18` mit `regulator-boot-on` +
`regulator-always-on`: beim Registrieren laeuft erstmals
`_regulator_do_enable()` -> `rpmh_regulator_enable()` ->
`rpmh_regulator_send_request(..., wait_for_ack=true)` -> synchroner
`rpmh_write()`.

Fix35 = Fix32 + korrigierte `ldo17`/`bob`-Werte + `ldo18` ohne
`boot-on`/`always-on` (Rail bleibt durch `regulator_ignore_unused` unberuehrt).
Damit registrieren beide Container alle Regler, ohne den synchronen
Enable-Pfad beim Probe.

Artefakt: `test-boot-uboot-odessa-fix35.img`
`145bb97c96c0f40042dd367ac0ed05645cf33bf29dde1a901085f0c2e4fcf925`
(DTB `odessa-6.12-fix35.dtb`
`a1d18b512220514c9508dedde0a4962fcba7f163546d3032ef52cd39406a493c`).

### Fix35 bootet — W2-Registrierung belegt (2026-11-07)

Live: `uname -r` = 6.12.0, uptime 134 s, **31** `pm6150*`-Regler in
`regulator_summary`. Beide Container binden; `ldo18` ohne
`boot-on`/`always-on` vermeidet den synchronen RPMh-Enable beim Probe
(Mechanismus: `rpmh_rsc_send_data()` wartet unbegrenzt auf einen freien TCS).
`regulator_ignore_unused` ist in den Bootargs; der 30-s-Cleanup deaktiviert
nichts, weil `rpmh_regulator_is_enabled()` fuer unbenutzte Rails `-EINVAL`
liefert (`<= 0` -> skip).

Fix36 = Fix35 + UFS auf echte RPMh-Rails:
- PHY `vdda-phy` -> pm6150 `ldo4` (0x1ad), `vdda-pll` -> pm6150l `ldo3` (0x1ac)
- HC `vcc` -> pm6150 `ldo19` (0x3f0), `vccq2` -> pm6150 `ldo12` (0x3ea)
- Fixed-Rails `regulator-ufs-vdda-phy/-pll` entfernt

Artefakte: `odessa-6.12-fix36.dtb`
`f78a5621063d59897d4fcadb2ea2777197b6ca0bf83fc79726059d0557b5ee41`,
`test-boot-uboot-odessa-fix36.img`
`42b31a877ffa8fb2e788d1d81661cbc17e9cb5bbdfe51006ad1234e93dbc3d8e`.
Fix35 (`145bb97c…f925`) bleibt Fallback.

### Fix35/Fix36-Lauf: W3 = 0 Warnungen, Fix36 bootet (2026-11-07)

- `dmesg | grep -c gic_irq_domain_translate` = **0** auf Fix35. Die neun
  Warnungen stammten also vollstaendig aus dem SPMI-`periph_irq`-Mapping
  (je Mapping 3 WARNs: select/translate/alloc). W3 damit erledigt.
- Regler-Summary: 31 Rails mit korrekten Fenstern, u. a.
  `pm6150_l4` 824-920 mV, `pm6150_l3` 968-1064 mV,
  `pm6150l_l3` 1144-1256 mV, `pm6150_l12` 1696-1952 mV,
  `pm6150_l19` 2944-3304 mV, `pm6150l_bob` 3320-3960 mV.
- Fix36 bootet. dmesg zeigt `OVERLAP DETECTED!`: das ist **erwartbar** und
  vorbestehend — `cont_splash_region@9c000000` (0x1700000) und
  `disp_rdump_region@9c000000` (0x1800000) liegen absichtlich uebereinander
  (`of_reserved_mem.c:420`). Kein Fehler.
- Offen: UFS-Verifikation auf den RPMh-Rails (`sdb24`, switch_root) und W4.

W3 abgeschlossen: keine IRQ_TYPE_NONE-Warnungen mehr.

### Fix36-Regress: kein USB (2026-11-07)

Fix36 bootet laut Anzeige, aber **kein USB-Netz/SSH**; letzte sichtbare Zeile
`amba_device_add() failed (-16) for /soc/cti@6867...` (Coresight/AMBA,
vermutlich vorbestehend, nicht bootkritisch).

Interpretation: Der Kernel haengt vor der Initramfs. Verdacht: die UFS-Rails
werden jetzt ueber `regulator_enable()` aktiviert -> `rpmh_regulator_enable()`
-> `rpmh_regulator_send_request(..., wait_for_ack=true)` -> synchroner
`rpmh_write()`. Genau dieser synchrone Pfad war schon bei `ldo18` der
Ausloeser (Fix33/34). Fix35 (ohne UFS-RPMh-Rails) bootet weiterhin.

Naechster Schritt: pstore-Rest des Fix36-Boots auf Fix35 lesen
(`/tmp/pstore-*`), danach UFS-Rails getrennt testen
(PHY ldo4/ldo3 vs. HC ldo19/ldo12).

### UFS-auf-RPMh: Enable-Pfad als Ursache; Fix39 (2026-11-07)

Fix37 (nur PHY-Rails) und Fix38 (nur HC-Rails) haengen beide. Der Diff
Fix35 -> Fix38 enthaelt ausschliesslich die zwei HC-Supplies, d. h. **jedes**
`regulator_enable()` auf diesen RPMh-Rails blockiert.

Code-Ursache (belegt):
`rpmh_regulator_set_enable_state()` (`qcom-rpmh-regulator.c:229-249`) sendet
zuerst — wenn `enabled == -EINVAL` und `voltage_selector` gesetzt ist — die
Spannung **synchron** erneut (`_rpmh_regulator_vrm_set_voltage_sel(..., true)`)
und danach den Enable-Befehl synchron (`wait_for_ack=true`).
`check_for_req_inflight()` (`rpmh-rsc.c:547-568`) vergleicht VRM-Adressen
**offset-unabhaengig** (`cmd_db_match_resource_addr`, `cmd-db.c:232-245`),
sodass ein noch in Flight befindlicher Spannungs-Request derselben Ressource
den Claim blockiert; `rpmh_rsc_send_data()` wartet dann unbegrenzt
(`rpmh-rsc.c:658-661`).

Fix39: UFS-Rails angeschlossen, aber `regulator-min/max-microvolt` an
`ldo4`, `ldo3` (PM6150L), `ldo12`, `ldo19` entfernt -> `apply_uV=false`,
`voltage_selector` bleibt `-ENOTRECOVERABLE`, der erneute Spannungs-Send
entfaellt; es bleibt nur der Enable-Befehl. Die Rails behalten die vom
Bootloader gesetzten Werte.

Artefakt: `test-boot-uboot-odessa-fix39.img`
`3c7e012a5ddb916c97dc3356c85f91527bc88dae139d6b60083f5fb6702c333a`
(DTB `odessa-6.12-fix39.dtb`
`e8d949dbb7a41a6cf1765e76637a72a372ba66ad2f9af08e030b743fcf832350`).

### Abschluss W2-Teil "Verbraucher-Umstieg": BLOCKER (2026-11-07)

Fix39 (UFS-Rails angeschlossen, ohne min/max an den vier Rails, damit nur der
Enable-Befehl gesendet wird) haengt ebenfalls. Damit ist belegt:

- Die **Registrierung** der 31 RPMh-Regler funktioniert (Fix35).
- Jeder **Verbraucher-Enable** auf einer dieser Rails (`regulator_enable()` ->
  `rpmh_regulator_set_enable_state()` -> synchroner `rpmh_write()`)
  blockiert den Boot vor der Initramfs.
- Auch ohne Spannungs-Resend (Fix39) haengt es -> der **synchronen
  Enable-Befehl** (`vreg->addr + 0x4`) bzw. der TCS-Completion-Pfad ist die
  Ursache, nicht der Spannungs-Resend.

Entscheidung: **Fix35 ist der Keeper.** UFS bleibt auf den Fixed-Rails
(`ufs_vdda_phy`/`ufs_vdda_pll` + `vcc`/`vccq2` werden von `ufshcd` als
"assuming enabled" behandelt). Der RPMh-Verbraucher-Pfad bleibt als offener
Blocker dokumentiert; naechster sinnvoller Schritt waere eine gezielte
Untersuchung von `qcom,tcs-config`/RSC-Completion fuer die Vendor-DTB
(`<0x02 0x02 0x00 0x03 0x01 0x03 0x03 0x01>`).

### Keeper-Stand (2026-11-07)

| Punkt | Ergebnis |
|---|---|
| W1 PDC mainline | ✅ bindet (`qcom_pdc`/`b220000.interrupt-controller`), keine Warnung |
| W2 RPMh-Regler | ✅ 31 Regler registriert; ⛔ Verbraucher-Umstieg blockiert |
| W3 IRQ-Typen | ✅ 0 `gic_irq_domain_translate`-Warnungen |
| W4 systemd | ⛔ braucht Paketquelle (Nutzerentscheidung) |

Keeper-Image: `test-boot-uboot-odessa-fix35.img`
`145bb97c96c0f40042dd367ac0ed05645cf33bf29dde1a901085f0c2e4fcf925`
DTB `odessa-6.12-fix35.dtb`
`a1d18b512220514c9508dedde0a4962fcba7f163546d3032ef52cd39406a493c`.

Weitere Artefakte (Bisect, alle haengen): Fix36 `42b31a87…3d8e`,
Fix37 `7356eda7…e04f2`, Fix38 `31d0bc06…234e`, Fix39 `3c7e012a…333a`.

### W4: arm64-Pakete beschafft (Freigabe 3, 2026-11-07)

Quelle: offizielles Ubuntu-Ports-Repo (`ports.ubuntu.com/ubuntu-ports`,
jammy/-updates/-security, main), privater APT-State unter
`/workspace/work/odessa/apt-arm64` (Host-APT unveraendert).

Geladen (15 Pakete, 7,0 MB, alle `arm64`, systemd 249.11-0ubuntu3.23):
`systemd`, `systemd-sysv`, `udev`, `dbus`, `libsystemd0`, `libudev1`,
`libapparmor1`, `libargon2-1`, `libcryptsetup12`, `libdbus-1-3`,
`libdevmapper1.02.1`, `libexpat1`, `libip4tc2`, `libjson-c5`, `libkmod2`.

Abhaengigkeitspruefung gegen den dpkg-Status des Staging-Rootfs: keine
fehlenden Pakete. `systemd-sysv` liefert `/sbin/init -> /lib/systemd/systemd`;
`udev` liefert `systemd-udevd`; Postinsts sind ohne laufendes systemd
toleranterweise no-op (`_systemctl`-Wrapper).

Recovery-Image **Fix40** = Fix35-DTB ohne `odessa.boot=ubuntu` (bleibt in der
Initramfs, USB/SSH):
`test-boot-uboot-odessa-fix40.img`
`8b250adb6f5a7433135033ba915a95a3532d29492d97eebe4e8fa4cfefb48213`.

### W4: systemd als Bestandteil des Images (Installer-Pre-Install, 2026-11-07)

Nutzerkorrektur: systemd soll nicht manuell aufs laufende Geraet, sondern in
den Image-/Installationspfad. Umgesetzt:

- `rootfs-dl/systemd-debs.tar` (15 arm64-Pakete, 7,0 MB, systemd
  249.11-0ubuntu3.23; Ports-Repo jammy/-updates/-security).
- `scripts/install-to-device.sh` hat jetzt einen Pre-Install-Schritt:
  nach dem Entpacken des RootFS wird das Buendel nach `/mnt/tmp/debs`
  uebertragen und **nativ im Zielrootfs** per
  `busybox chroot /mnt /bin/sh -c 'dpkg --unpack ... && dpkg --configure -a'`
  installiert; danach `/sbin/init -> /lib/systemd/systemd` geprueft und ein
  `LABEL=odessa-root / ext4 defaults 0 1`-Eintrag in `/etc/fstab` ergaenzt.
  `--no-systemd` ueberspringt den Schritt.
- Damit ist das deployte Image ab dem ersten Boot ein systemd-System; der
  Basistarball bleibt unveraendert (reproduzierbarer Pre-Install).
- Prep-Image fuer die Installation: `test-boot-uboot-odessa-fix40.img`
  (Fix35-DTB ohne `odessa.boot=ubuntu`, bleibt in der Initramfs).

Offen: Reinstall auf dem Geraet + Verifikation (`ps -p 1`, `systemctl`).

### Dokumentations-Audit 2026-11-07

Ergaenzt, weil im Audit gefehlt:
- `orchestrator/DEAD-ENDS.md` — 20 verworfene/fehlgeschlagene Ansaetze mit
  Beleg (DTB/DTBO, U-Boot-USB-Handoff, PDC-Pass-Through, cmd-db-Pointer,
  GCC-Ops, CMDLINE_FORCE, QMP-UFS-Modul, ldo18-always-on, UFS-RPMh-Rails,
  manuelle systemd-Installation, pstore, Bildschirm-Fehlschluss u. a.).
- `orchestrator/LEADS.md` — konsolidiertes State-Board (CLOSED/OPEN/BLOCKED/
  OUT_OF_SCOPE) inkl. der kosmetischen Leads (GPU-SMMU, AMBA/Coresight,
  lpi_pinctrl) und der bewusst nicht verfolgten Bereiche.
- `orchestrator/RELEASE-PLAN.md` — Weg zum einfachen flashbaren Image
  (`boot.img` + `rootfs.img` + `flash.sh`), Host-Pre-Seed-Pipeline ohne qemu.
- `ARTIFACTS.md` — vollstaendiger generierter Index aller 40 Boot-Images und
  28 DTBs mit SHA256; Fix7/8/15/18/19 sind ehrlich als Zwischenstaende ohne
  eigenen STATUS-Eintrag markiert.

Hinweis: ES fehlen weiterhin Einzelbeschreibungen fuer Fix7/8/15/18/19; sie
sind nur ueber den Index auffindbar. Das ist bewusst so dokumentiert.

### Rootfs-Ownership-Bug gefunden (2026-11-07)

Beim systemd-Pre-Install auf dem Geraet blieb `/sbin/init` das Shell-Script.
Ursache: Der Rootfs-Tarball hatte `./` als **1000/1000**. GNU tar (von dpkg
zum Entpacken benutzt) meldet dann `Detected unsafe path transition ...` und
ueberspringt einzelne Mitglieder.

Fix:
- `scripts/build-rootfs.sh`: `sudo chown root:root "$R"` vor dem Tar.
- `scripts/install-to-device.sh`: `chown root:root /mnt` nach der Extraktion.
- Rootfs neu gebaut: `out/rootfs.tar` 75.724.800 B,
  SHA256 `1c43d34f9fece1928e4952c4594682b023051d6964621a60766b5249cec526a2`;
  nur noch 12 Nicht-Root-Eintraege (Standard-Systemgruppen 8/42/43/50).

### Fix41 — switch_root mit systemd-Symlink (2026-11-07)

Zweite Ursache des fehlgeschlagenen systemd-Boots: Die Initramfs prueft
`[ -x /mnt/sbin/init ]`. Bei systemd ist `/sbin/init` ein **absoluter**
Symlink (`-> /lib/systemd/systemd`); `test -x` loest ihn im
Initramfs-Namensraum auf -> dangling -> kein `switch_root`. Das Rootfs selbst
war korrekt (Symlink + `/lib/systemd/systemd` + `/etc/odessa-ready` vorhanden).

Fix in `initramfs-src/init`: akzeptiere zusaetzlich
`/mnt/lib/systemd/systemd` bzw. `/mnt/usr/lib/systemd/systemd`
(usrmerge), weiterhin nur bei vorhandenem `/etc/odessa-ready`.

Weitere Build-Fixes:
- Host hat kein `cpio`; `build-initramfs.sh` nutzt jetzt `bsdtar --format=newc`
  als Fallback (libarchive, 0/0-Owner verifiziert).

Artefakte: Initramfs `2077b8e18e794f00865b3c6d3e00ee834a6ee0a85165d6242541ea4d6378933e`,
Boot-Image `test-boot-uboot-odessa-fix41.img`
`c45d8e5fa5196ce13d855cde7a494550b3d1ec2db7faef979c85824ab364722f`
(DTB Fix35 `a1d18b51…a493c`).

### systemd-Boot erreicht — SSH-Ausfall durch entfallenes `-E` (2026-11-07)

Meilenstein: Fix41 bootet in **systemd** bis zum Ubuntu-Login-Screen
(getty auf tty1). SSH war "Connection refused", weil
`dropbear.service` mit `dropbear -F -E -p 22 ...` startet — Dropbear
**v2026.94** kennt `-E` nicht mehr (`Invalid option -E`), die Unit stirbt
sofort. Das Binary ist statisch und laeuft; der Host-Key wird korrekt erzeugt.

Fix: `-E` aus der Unit entfernt (`prepare-rootfs.sh`), Rootfs neu gebaut:
`out/rootfs.tar` 75.724.800 B,
SHA256 `755a807c6a7b6edae20699474cc033207238f1fa6cc6f6be3203fe30cb2ee407`.

Auf dem laufenden Dev-Rootfs: `sed -i 's|dropbear -F -E -p 22|dropbear -F -p 22|'`.

### W4 VERIFIED — volles systemd-Ubuntu auf 6.12 (2026-11-07)

Live auf Fix41:
- `/proc/1/comm` = `systemd`
- `systemctl is-system-running` = `running`
- `dropbear.service` = `active (running)`, `enabled`, Main PID lauscht auf :22
- SSH ueber usb0 funktioniert

Damit ist die Kette komplett:
ABL -> U-Boot-Chainload -> FIT -> Linux 6.12 -> SM6150-GCC -> DWC3/QUSB2 ->
USB-NCM/SSH -> UFS -> systemd -> Ubuntu 22.04.5.

Kleinigkeit: `ip` fehlt im minimalen Base-Rootfs (iproute2 nicht installiert);
die Gadget-/Installer-Skripte nutzen `/usr/local/bin/busybox ip`. Fuer ein
Release-Image waere `iproute2` (plus ggf. `procps`) sinnvoll.

Offen bleibt nur der RPMh-Verbraucher-Blocker (L-REG-02) und das Release-Image
(L-REL-01).

### Release-Portabilitaet (2026-11-07)

- FIT-Bootargs sind bereits minimal (keine Serial/MACs/Bootloader-Strings).
- `prepare-rootfs.sh` leert jetzt `/etc/machine-id` und entfernt
  Dropbear-Hostkeys -> pro Geraet neu erzeugt.
- Rootfs neu gebaut: `out/rootfs.tar` 75.735.040 B,
  SHA256 `45a8888a1641d0dc73524fc58202402ae0c74f582ac6fef39117d0d684f5cbc7`.
- Bewusste Restpunkte im `RELEASE-PLAN.md`: DTB an Build-Firmware gebunden,
  `authorized_keys` = Build-Key, `/dev/sdb24` modellspezifisch.

### Bootloader-Flashgrenzen + selbstinstallierendes Boot-Image (2026-11-07)

Live geprueft (Fastboot, `securestate: flashing_unlocked`, `frp-state: no
protection`):
- `fastboot flash boot_b ...` -> **OKAY**
- `fastboot erase userdata` -> **OKAY**
- `fastboot flash userdata ...` -> **`flash permission denied`** (auch mit
  20-MB-Image; Motorola-Policy, unabhaengig von Unlock/FRP/Groesse)
- `fastboot flash super ...` -> **`Unsupported super image format`**
  (Bootloader validiert das Android-Super-Format)

Fazit: Ein reines Fastboot-Rootfs-Image ist auf diesem Bootloader nicht
moeglich. Loesung: **selbstinstallierendes Boot-Image** — `boot_b` ist
flashbar, Linux darf `userdata` schreiben.

- Initramfs enthaelt `rootfs.tar.gz` (42 MB, Snapshot des validierten
  Systems) und schreibt es beim Boot nach `/dev/sdb24` (mke2fs + untar),
  falls dort kein `/etc/odessa-ready` liegt; danach `switch_root`.
- Initramfs erkennt jetzt beide Layouts (`/dev/sdb24` = userdata,
  `/dev/sdb23` = super).
- `odessa-growfs.service` nutzt das echte Root-Device aus `/proc/mounts`.
- Boot-Image: 61,4 MB (Limit `boot_b` 64 MB), SHA256
  `6a522327fa6308a2d20fd1052a46367348c668dc8d74d6578f04ec86eab7e765`.

Ablauf fuer den Nutzer: `fastboot flash boot_b odessa-6.12-boot.img`,
`fastboot set_active b`, `fastboot reboot` — kein Prep-Boot, kein Host-Skript.

### Release-Validierung: Slot-Boot ok, zwei Fixes (2026-11-07)

- **Slot-Boot funktioniert** (boot_b 61,4 MB, `set_active b`).
- Self-Install-Bug gefunden: im Block fehlte `mkdir -p /mnt` -> `mount`
  scheiterte, obwohl `mke2fs` lief. Gefixt.
- Growfs-Bug: das statische `mke2fs 1.47.4` im Initramfs aktiviert
  `orphan_file` (dumpe2fs 1.46.5 zeigt `FEATURE_C12`/`FEATURE_R16`), das
  `resize2fs 1.46.5` im Rootfs nicht kennt -> `Filesystem has unsupported
  feature(s)`. Fix: `-O ^orphan_file` bei allen mke2fs-Aufrufen
  (Self-Install, Installer, Host-Image).
- Manueller Self-Install-Payload-Test: mkfs+mount+untar ok, Rootfs 145 MB,
  `/etc/odessa-ready`, `/sbin/init -> /lib/systemd/systemd` vorhanden.
- Finale Artefakte nach den Fixes:
  - `odessa-6.12-boot.img` (61,4 MB) `5c3d26e4e35c6506a777ba0fc35a6534a1934f1e48dc2073748c594416c93a86`
  - `odessa-6.12-rootfs.img` (2,0 GB) `197d43a1f73f32bd572cd9fcc627993af2f1b6440b3b902cbfc3cbcdfed909b3`
  - `odessa-6.12-rootfs.simg` (140 MB) s. ARTIFACTS
  - `out/rootfs.tar` (Installer) `483eff3c...f220ff4b`
- Offen: End-to-End-Validierung auf **leerem userdata** (Erase + Reboot mit
  dem neuen Boot-Image) und Test auf dem Zweitgeraet.

### RELEASE VALIDIERT (2026-11-07)

End-to-End auf leerem `userdata`: `fastboot erase userdata`,
`fastboot flash boot_b odessa-6.12-boot.img`, `set_active b`, `reboot`
-> Self-Install -> `switch_root` -> systemd.

Live-Verifikation:
- `/proc/1/comm` = systemd
- `systemctl is-system-running` = **running**
- `systemctl --failed` = **0 loaded units listed**
- `/` = `/dev/sdb24` 107G, 154M belegt
- usb0 = 172.16.42.1/24

Damit ist die Release-Kette:
ABL -> U-Boot -> FIT -> Linux 6.12 -> GCC/USB/UFS -> systemd ->
Self-Install auf userdata.

Finale Artefakte:
| Datei | SHA256 |
|---|---|
| `out/odessa-6.12-boot.img` (61,4 MB) | `5c3d26e4e35c6506a777ba0fc35a6534a1934f1e48dc2073748c594416c93a86` |
| `out/odessa-6.12-rootfs.img` (2,0 GB) | `197d43a1f73f32bd572cd9fcc627993af2f1b6440b3b902cbfc3cbcdfed909b3` |
| `out/odessa-6.12-rootfs.simg` (140 MB) | `e6926f9d979474ae02085793d83df361f5dbd8f31af0f9e0a4aad753501eb8b5` |
| `out/rootfs.tar` (Installer) | `483eff3c629260018d6d1e646e20dcfc175f7a8a0a222e565d444ca0f220ff4b` |
| `out/flash-odessa.sh` | (Skript, boot_b + set_active b + reboot) |

`flash-odessa.sh` wurde auf den real funktionierenden Weg korrigiert
(kein `flash userdata` mehr). Offen: Test auf dem Zweitgeraet.

### 26.04 bootet (2026-11-07)

Live verifiziert auf /dev/sdb24:
- `/proc/1/comm` = systemd
- `/etc/os-release` = Ubuntu 26.04.1 LTS (Resolute Raccoon)
- `systemd 259 (259.9-0ubuntu0.1)`, `systemctl is-system-running` = running
- `/` = /dev/sdb24, 107G, 162M belegt; usb0 = 172.16.42.1/24
- growfs aktiv (107G), dropbear/usb-gadget/dbus aktiv

Ein Unit-Fehler gefunden und behoben: `systemd-modules-load` scheiterte, weil
die 26.04-Base `/etc/modules-load.d/modules.conf -> ../modules` als toten
Symlink mitbringt (kein `/etc/modules`, Kernel monolithisch ohne
`/lib/modules`). Entfernt -> Unit wird per Condition uebersprungen,
`systemctl --failed` = 0. Fix in `scripts/prepare-rootfs.sh` aufgenommen.

#### Zwischenfall: SSH nach Live-Cleanup tot

Beim Sanitizing auf dem *laufenden* System wurden die Dropbear-Hostkeys
geloescht. Ergebnis: TCP:22 nimmt an, schliesst aber sofort ohne Banner
(`recv` = b''), andere Ports = connection refused, ICMP ok. Der laufende
Dropbear braucht die Key-Datei fuer neue Sessions. Lehre: Hygiene nur auf der
Host-Kopie, nie am laufenden System.
Neu: `scripts/snapshot-rootfs.sh` (read-only Snapshot, Excludes) und
`scripts/sanitize-rootfs.sh` (Hygiene auf der Host-Kopie).
Recovery: Reboot -> dropbear.service erzeugt den Key per ExecStartPre neu.

### 26.04 Release-Kandidat gebaut (2026-11-07)

- Snapshot vom laufenden 26.04 (`scripts/snapshot-rootfs.sh`, read-only,
  Excludes fuer /var/log,/var/cache,/tmp) -> `out/rootfs-2604.tar` (141 MiB).
- Hygiene nur auf der Host-Kopie (`scripts/sanitize-rootfs.sh`):
  machine-id leer, Hostkeys entfernt, Logs/Tmp/random-seed weg,
  modules.conf entfernt, `/etc/odessa-ready` gesetzt.
- Payload `out/rootfs-install.tar.gz` 42,19 MiB; Boot-Image
  `odessa-6.12-boot-2604.img` 61,68 MiB von 64 MiB (2,3 MiB Reserve).
- Rootfs-Image 2 GB + Sparse (125 MiB) aus demselben Tree gebaut,
  Features ohne `orphan_file` (resize2fs-kompatibel).
- Initramfs verifiziert: `mkdir -p /mnt` + `mke2fs -O ^orphan_file` +
  switch_root-Pfad vorhanden.
- Offen: End-to-End auf leerem userdata (erase + boot_b + reboot) und
  Zweitgeraet.

### RELEASE 26.04 VALIDIERT (2026-11-07)

End-to-End auf leerem userdata, mit dem finalen `odessa-6.12-boot.img`:

1. `fastboot erase userdata`
2. `fastboot flash boot_b odessa-6.12-boot.img`
3. `fastboot set_active b` / `reboot`

Log: self-install 4,4 s -> rootfs written 20,4 s -> switch_root 21,5 s.
Danach systemd 259.9, `running`, **0 failed units**, `/` 107 G auf
/dev/sdb24, usb0 172.16.42.1/24, `dpkg --audit` leer, 112 Pakete.

Zweiter Boot: kein Self-Install, `switch_root` nach 4,4 s, machine-id
(`6ada953a…`) und Dropbear-Hostkey bleiben stabil.

Artefakte sind auf kanonische Namen promoted (`out/odessa-6.12-boot.img`
etc.), 22.04 liegt als `out/legacy-2204/` daneben.
Offen: Zweitgeraet (SSH-Key ersetzen, Firmware/Panel).
