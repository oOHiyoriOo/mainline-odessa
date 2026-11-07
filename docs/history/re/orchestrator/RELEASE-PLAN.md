# RELEASE-PLAN — flashbares Odessa-6.12-Image

Ziel: **ein einfaches Image, flashen, fertig** — kein manuelles
`dpkg`/`chroot`/Installer-Gefummel auf dem Zielgeraet. Der aktuelle
RAM-/Installer-Weg bleibt fuer die Entwicklung, ist aber nicht das Release.

## Zielartefakte

| Datei | Inhalt | Flash-Ziel |
|---|---|---|
| `odessa-6.12-boot.img` | U-Boot-Chainload + FIT (Kernel 6.12 + ABL-DTB + Initramfs) | `boot_b` (Rescue-Slot), optional `fastboot boot` |
| `odessa-6.12-rootfs.img` | ext4 mit Ubuntu 22.04.5, systemd, `usb-gadget.service`, `dropbear.service`, `/etc/odessa-ready` | `userdata` (`/dev/sdb24`) |
| `flash-odessa.sh` | `fastboot flash userdata …`, `fastboot flash boot_b …`, `fastboot --set-active=b` | — |
| `SHA256SUMS`, `README.md` | Hashes, Kurzanleitung, Unlock-Hinweis | — |

`boot_a` bleibt **Stock** (Rettung), `dtbo_a`/`dtbo_b` bleiben **unberuehrt**.
`boot_a`/`boot_b` sind je 64 MiB; das aktuelle Boot-Image ist ~21 MB.

## Build-Pipeline

### 1. Boot-Image (heute schon reproduzierbar)

```bash
U=/workspace/work/odessa/.re/uboot
# FIT mit Keeper-DTB + Kernel + Initramfs
$U/build-odessa/tools/mkimage -f $U/fit-6.12-fix35.its $U/fit-release.itb
UBOOT=$U/unpacked-uboot-fix9/kernel FIT=$U/fit-release.itb \
  OUT=$U/odessa-6.12-boot.img $U/pack-uboot-bootimg.sh
```

Der Keeper-Stand ist Fix35: PDC mainline, 31 RPMh-Regler registriert,
0 IRQ-Warnungen, UFS auf Fixed-Rails.

### 2. Rootfs-Image (host-only, ohne qemu)

`dpkg-deb -x` ist architekturunabhaengig; die Maintainer-Scripts muessen fuer
das Release nicht laufen, weil systemd beim ersten Boot `systemd-sysusers`
und `systemd-tmpfiles` ausfuehrt und die Pakete ihre `.wants`-Symlinks in
`/usr/lib/systemd/system` mitbringen.

```bash
STAGE=/workspace/work/odessa/out/release-rootfs
rm -rf "$STAGE"; mkdir -p "$STAGE"
tar -xpf /workspace/work/odessa/out/rootfs.tar -C "$STAGE"
for d in /workspace/work/odessa/apt-arm64/cache/archives/*.deb; do
  dpkg-deb -x "$d" "$STAGE"
done
rm -f "$STAGE/sbin/init"
ln -sf /lib/systemd/systemd "$STAGE/sbin/init"
grep -q '^LABEL=odessa-root' "$STAGE/etc/fstab" || \
  echo 'LABEL=odessa-root / ext4 defaults 0 1' >> "$STAGE/etc/fstab"
truncate -s 4G /workspace/work/odessa/out/odessa-6.12-rootfs.img
mke2fs -q -t ext4 -L odessa-root -d "$STAGE" \
  /workspace/work/odessa/out/odessa-6.12-rootfs.img
e2fsck -fy /workspace/work/odessa/out/odessa-6.12-rootfs.img
```

Offener Punkt: dieser Pre-Seed-Weg muss einmal gegen den Installer-Weg
(echte Postinst-Scripts im chroot) validiert werden. Falls Unterschiede
auftreten (z. B. fehlende Nutzer/Enables), ist der Installer-Weg die Referenz.

### 3. Flash-Script

```bash
#!/bin/sh
set -e
fastboot flash userdata odessa-6.12-rootfs.img
fastboot flash boot_b   odessa-6.12-boot.img
fastboot --set-active=b
fastboot reboot
```

## Validierungsmatrix (vor Veroeffentlichung)

| Test | Erwartung |
|---|---|
| `fastboot boot odessa-6.12-boot.img` (RAM-only) | Boot bis systemd, SSH auf `172.16.42.1` |
| `fastboot flash boot_b` + `set_active=b` | Startet ohne Host-Interaktion |
| Erster Boot nach Rootfs-Flash | systemd als PID 1, `systemctl is-system-running` = `running`/`degraded`, `usb0` up, `dropbear` aktiv |
| UFS | `sdb24` vorhanden, `/` = `/dev/sdb24` |
| Reboot-Zyklus | 2x hintereinander sauber |
| Rettung | `fastboot --set-active=a` bootet Stock-Android |
| `dtbo_a`/`dtbo_b` | unveraendert |

## Veroeffentlichung

- Lizenzen: Linux/U-Boot GPL-2.0, Ubuntu-Pakete nach ihren Lizenzen; keine
  proprietaeren Vendor-Bloecke im Image.
- Keine Bootloader-/DTBO-Dateien mitschicken (nur unser Boot-/Rootfs-Image).
- Unlock-Hinweis: entsperrter Bootloader noetig; Flashen von `userdata`
  loescht Android-Daten.
- Kernel-Quelle + GCC-Port-Skript (`scripts/port-gcc-sdmmagpie.py`) und
  DTS-Quelle (`abl-merged-gcc.dts`) mitliefern, damit der Build
  nachvollziehbar ist.
- Bekannte Einschraenkungen nennen: kein Mainline-DSI/Suspend, RPMh-Regler
  nur registriert (UFS auf Fixed-Rails), Kamera/Modem ausser Scope.

## Portabilitaet: zweites, baugleiches Moto G9 Plus

Ziel: dasselbe Image soll auf einem zweiten `odessa` (XT2087-2) laufen.

Bereits unit-unabhaengig:
- FIT-Bootargs enthalten **keine** Serial/MAC/Bootloader-Strings; sie sind
  minimal (`console`, `loglevel`, `fbcon`, `pstore`, `clk/pd/regulator_
  ignore_unused`, `odessa.boot=ubuntu`). Serial/MACs liefert der ABL zur
  Laufzeit.
- Keine SSH-Hostkeys im Image; `dropbear.service` erzeugt sie beim ersten Boot.
- Leere `/etc/machine-id`; systemd generiert pro Geraet eine neue.
- Rootfs ist generisch (Ubuntu Base + systemd + unsere Units).

Bewusste Restpunkte:
- **DTB/Firmware**: Der ABL-gemergte DTB stammt vom Build-Geraet
  (Bootloader `MBM-3.0-odessa_retail-e69c40c38d6-220818`). Bei identischer
  Firmware/SoC-Revision ist er uebertragbar; bei anderer Bootloader-/Panel-
  Variante kann das reserved-memory-Layout oder die Panel-Konfiguration
  abweichen. Dann DTB von der Zielunit neu dumpen und Image neu bauen.
- **SSH-Key**: `root/.ssh/authorized_keys` enthaelt den Build-Key
  (`odessa-initramfs`). Fuer fremde Units ersetzen (oder eigenen Key
  injizieren); das ist bewusst kein Default-Passwort.
- **UFS-Namen**: `/dev/sdb24` ist bei diesem Modell stabil; die Growfs-Unit
  nutzt ihn direkt.

Validierung auf dem Zweitgeraet:
1. `fastboot flash userdata odessa-6.12-rootfs.img`
2. `fastboot flash boot_b odessa-6.12-boot.img`
3. `fastboot --set-active=b`
4. Erster Boot: systemd, usb0, SSH mit eigenem Key, `df -h /` = 114G.
5. `boot_a` (Stock) muss weiterhin booten.

## Release-Artefakte 2026-11-07 (Snapshot des validierten Systems)

| Datei | Groesse | SHA256 |
|---|---|---|
| `out/odessa-6.12-boot.img` | 20 MB | `444e07c90b1de8b68c84f85f4bd006427e50901fb7162954830a3997263e39db` |
| `out/odessa-6.12-rootfs.img` | 2,0 GB | `2418b497c9d03932bb18d3dd3086a39c57566e357023cfe3b4e813a66d3b6ab1` |
| `out/flash-odessa.sh` | — | — |

Inhalt Rootfs-Image (per `debugfs` verifiziert): `/sbin/init ->
/lib/systemd/systemd`, `/lib/systemd/systemd` 1.793.736 B, leere
`/etc/machine-id`, keine Dropbear-Hostkeys, `LABEL=odessa-root / ext4` in
`/etc/fstab`, `odessa-growfs.service` enabled, dpkg-Status
`systemd/systemd-sysv/udev/dbus/iproute2` = *install ok installed*.

Das Image ist ein Snapshot des auf dem Dev-Geraet validierten Rootfs
(nativ per dpkg installiert -> korrekte dpkg-Datenbank). Es wurde **nicht**
geflasht; der erste Flash-/Boot-Test steht aus.

## STATUS 2026-11-07: validiert

End-to-End auf leerem userdata bestanden (Self-Install -> systemd, 0 failed
units). `flash-odessa.sh` nutzt nur noch `boot_b` + `set_active b` + `reboot`.

- **Ein Image** (`odessa-6.12-boot.img`, 61,4 MB) genuegt fuer eine
  Neuinstallation; es schreibt die Rootfs beim ersten Boot selbst nach
  userdata (Bootloader verlaubt kein `fastboot flash userdata`).
- `boot_a`/`dtbo` bleiben unberuehrt.
- `odessa-6.12-rootfs.img/.simg` und `rootfs.tar` bleiben als alternative
  Wege (Installer) erhalten.
- Offen: Test auf einem zweiten baugleichen Geraet; SSH-Key ersetzen.

## 2026-11-07: Release 26.04 validiert (final)

Gewaehlt: **Ubuntu 26.04.1 LTS "Resolute Raccoon"** mit systemd 259.9.
Der 22.04-Stand bleibt als `out/legacy-2204/` erhalten.

### Flash-Weg

```bash
fastboot erase userdata
fastboot flash boot_b odessa-6.12-boot.img
fastboot set_active b
fastboot reboot
```

`boot_a` und `dtbo_a/b` bleiben Stock. Der Bootloader verweigert
`fastboot flash userdata`/`super`; deshalb schreibt das Boot-Image die
Rootfs beim ersten Start selbst.

### Nachweis (leeres userdata, 2026-11-07)

```
[    4.405] [init] self-install: writing embedded rootfs to /dev/sdb24
[   20.401] [init] self-install: rootfs written
[   21.495] [init] switching root to /dev/sdb24 (ubuntu)
```

Danach: `/proc/1/comm` = systemd, `systemctl is-system-running` = running,
`systemctl --failed` = 0, `/` = /dev/sdb24 107 G, usb0 = 172.16.42.1/24,
`dpkg --audit` leer (112 Pakete). Zweiter Boot: kein Self-Install,
`switch_root` nach 4,4 s, machine-id und Dropbear-Hostkey bleiben stabil.

### Artefakte

| Datei | SHA256 |
|---|---|
| `out/odessa-6.12-boot.img` (61,68 MiB) | `293533942759a466b0193645bb74e989be78e59988508b9dd2fce54744731f15` |
| `out/odessa-6.12-rootfs.img` (2,0 GB) | `ac5cf5ec532863600f585489e9862151c28daeeb73d0be3b77c16193beb1adc2` |
| `out/odessa-6.12-rootfs.simg` (125 MiB) | `08682cb205f8c2de8c1d55c7a6cfdbdee0b97e88041bbc0069699033972e7a7e` |
| `out/rootfs.tar` (Installer) | `d0b8af09a8d1b4bf942531c27634297b653c10fc4823421c63ea3b28bf927d70` |
| `out/rootfs-install.tar.gz` (Payload) | `0d000d5df6a58bed5c3d94079f111b9545f6d24b49f16b96bf09b52e9fcaee07` |
| `out/flash-odessa.sh` | `d47478839bd1ec80ca2ba68cd1007407df00b671733a222a0e03eb4d8c6a9835` |

### Reproduktion

1. `scripts/snapshot-rootfs.sh` — read-only Tar vom laufenden Rootfs
   (Excludes: `/var/log`, `/var/cache`, `/var/tmp`, random-seed).
2. `scripts/sanitize-rootfs.sh <dir>` — machine-id leeren, Hostkeys/Logs/
   resolv/random-seed entfernen, `modules.conf` entfernen, `odessa-ready`.
3. Payload: `tar -C <dir> -cf - . | gzip -9 > out/rootfs-install.tar.gz`
4. `scripts/build-initramfs.sh` (nimmt den Payload automatisch), dann
   `mkimage -f fit-6.12-release.its` und `pack-uboot-bootimg.sh`.
5. Rootfs: `mke2fs -O ^orphan_file -d <dir>`; Sparse via
   `scripts/make-simg.py`.

## Offen

- Zweitgeraet: SSH-Key ersetzen (`root/.ssh/authorized_keys`), gleiche
  Firmware/Panel voraussetzen, sonst DTB neu mergen.
- `systemd-modules-load` bleibt `inactive` (monolithischer Kernel, keine
  Module) — bewusst, kein Fehler.
- UFS weiterhin auf Fixed-Rails (L-REG-02).
