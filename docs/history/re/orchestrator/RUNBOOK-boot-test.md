# Runbook — odessa: Boot, Rescue, pstore, Mainline-Tests

RUN_ID=20261106-odessa-usbgadget
Stand: 2026-11-06 (UTC)
Zielgeraet: Moto G9 Plus `odessa` (XT2087-2), S/N ZY227VHMSS.

Dieses Runbook beschreibt den **aktuellen** Stand. Es ersetzt das fruehere
Runbook, das nur den ersten RAM-Boot-Test beschrieb.

## 0. Uebersicht der Betriebsarten

| Modus | Wie starten | Was laeuft | Persistenz |
|---|---|---|---|
| Android | `fastboot set_active a`, Reboot | Stock/LineageOS `boot_a` | unveraendert |
| Rescue/Prep (Slot b) | normaler Reboot bei aktivem Slot b | unser Initramfs v3, SSH/Telnet, pstore-Dump | `boot_b` geflasht |
| Prep per RAM | `fastboot boot test-boot-odessa-prep.img` | dito, ohne Slot-Wechsel | keine |
| Ubuntu 22.04 | `fastboot boot test-boot-odessa-ubuntu.img` | Initramfs `switch_root` -> `/dev/sdb24` | RootFS auf userdata |
| Mainline M0 | `fastboot boot test-boot-mainline-*.img` | Linux 6.12 (derzeit **erfolglos**) | keine |

Wichtig: `boot_b` enthaelt das **Prep**-Image ohne `odessa.boot=ubuntu`.
Ein normaler Reboot in Slot b landet daher in der Rescue-Shell, nicht in
Ubuntu. Ubuntu wird derzeit nur per `fastboot boot` des Ubuntu-Images
gestartet.

## 1. Host-Werkzeuge

```bash
RT=/home/zero/.local/share/opencode/re-tools
ADB=$RT/bin/adb
FB=$RT/bin/fastboot
KEY=$RT/_scratch/odessa/id_ed25519
DIST=$RT/_scratch/odessa/dist
```

Der Container darf wegen Device-cgroup/USB-Minor **kein** neues
`fastboot`-Geraet oeffnen. `fastboot` und das Setzen der Host-IP laufen auf dem
Host. `adb` funktioniert im laufenden Android/Recovery (Minor 23).

## 2. In den Bootloader

Aus Android/Recovery:

```bash
$ADB reboot bootloader
sleep 12
$FB devices
```

Aus dem Rescue-Initramfs (SSH) geht auch:

```bash
ssh -i $KEY root@172.16.42.1 '/bin/busybox reboot -f'
```

Danach Vol-Down halten, falls das Geraet nicht direkt im Fastboot landet.

**Bekannt:** Ein fehlgeschlagenes `fastboot boot` laesst das Geraet meist im
Fastboot oder startet nach zwei Reboots die Lineage-Recovery. Das ist kein
Flash-Fehler.

## 3. Rescue-Slot b (bereits eingerichtet)

`boot_b` = `/dev/block/sdf21` (64 MiB), geflasht mit
`test-boot-odessa-prep.img`; `boot_a` = `/dev/block/sde21` blieb Stock.

Aktivieren:

```bash
$FB set_active b
$FB reboot
```

Zurueck zu Android:

```bash
$FB set_active a
$FB reboot
```

Neu flashen (nur mit ausdruecklicher Freigabe; zerstoert das Rescue-Image
nicht, ersetzt es):

```bash
$FB flash boot_b $DIST/test-boot-odessa-prep.img
$FB set_active b
```

**Niemals** `boot_a` flashen. `recovery_a`/`recovery_b` bleiben unberuehrt.

Verifizierter Slot-Zustand am 2026-11-06:

- `boot_a`: `ANDROID!`, Kernel 35.493.904 B, Ramdisk 2.797.028 B (Stock).
- `boot_b`: `ANDROID!`, Kernel 13.356.663 B, Ramdisk 3.765.922 B
  (= unser Prep-Image).
- Aktiver Slot: `_a`; Geraet stand in Lineage-Recovery.

## 4. Prep/Ubuntu per RAM booten

```bash
$FB boot $DIST/test-boot-odessa-prep.img
# warten, bis USB-Gadget + DHCP + SSH da sind
ssh -i $KEY root@172.16.42.1
```

Ubuntu:

```bash
$FB boot $DIST/test-boot-odessa-ubuntu.img
```

Host bekommt per DHCP eine Adresse aus `172.16.42.10-20`; das Geraet ist
`172.16.42.1`. Bei Problemen mit NetworkManager:

```bash
nmcli device set <iface> managed no
ip addr add 172.16.42.2/24 dev <iface>
ip link set <iface> up
```

(Das Geraet setzt seine MAC auf `a6:00:00:00:00:02`; die Host-MAC bleibt
zufaellig, daher wechselt der Interface-Name pro Boot.)

## 5. pstore lesen (Post-Mortem)

Das Prep-Initramfs mountet pstore und kopiert die Dateien nach `/tmp`:

```bash
ssh -i $KEY root@172.16.42.1 \
  'ls -l /tmp/pstore-*; tail -c 2000 /tmp/pstore-console-ramoops-0'
```

In Android/Recovery direkt:

```bash
$ADB shell 'ls -l /sys/fs/pstore/'
$ADB shell 'grep -a -n -E "Linux version|Kernel panic|Unable to handle" /sys/fs/pstore/console-ramoops-0'
```

Layout: Basis `0xaf000000`, `console-size 0x40000`, `pmsg-size 0x40000`,
`record-size 0x3f800`, Gesamt `0xbf800`.

**Interpretations-Caveat:** Der Ramoops-Ringpuffer ist persistent, aber der
naechste Boot (z. B. Recovery) schreibt hinein. Ein fehlender Mainline-Text
beweist daher nicht zwingend, dass der Kernel nichts geschrieben hat — er kann
ueberschrieben worden sein. Fuer saubere Zuordnung: nach dem Test-Boot
**nicht** in Recovery/Android booten, sondern direkt per `fastboot reboot` in
Slot b (Rescue) und dort auslesen.

**Read-only-pstore-Rescue (fuer 6.12-Logs):** Der normale Prep-Kernel
(`PSTORE_CONSOLE=y`) ueberschreibt den 6.12-Console-Ringpuffer beim Boot.
`test-boot-414190-pstore-ro.img` ist ein 4.14-Kernel mit
`CONFIG_PSTORE_CONSOLE`/`PSTORE_PMSG` **aus** und `PSTORE_RAM=y`; er kopiert
den vorhandenen 6.12-Log, ohne ihn neu zu beschreiben:

```bash
$FB boot $DIST/test-boot-414190-pstore-ro.img
ssh -i $KEY root@172.16.42.1 \
  'ls -l /tmp/pstore-*; cat /tmp/pstore-console-ramoops-0'
```

## 6. DTB-Regeln (harte Erfahrung)

- **Nur das Original-DTB** aus `stock_boot.img` funktioniert zuverlaessig.
- Die **live** Board-ID ist `qcom,board-id = <0x49 0xc000>` (nicht `<0 0>`);
  sie passt zu DTBO-Entry 2 (`androidboot.dtbo_idx=2`).
- Der aktive DTBO-Entry 2 hat **104 Fragments** und **190 Symbol-Fixups**
  gegen den vollen Vendor-Base-Tree. Ein Minimal-DTB kann diesen Merge nicht
  erfuellen; `__symbols__` allein genuegt nicht.
- Das Stock-DTB hat einen **leeren** `/memory`-Platzhalter, den ABL fuellt,
  und **keinen** `ramoops`-Knoten; `ramoops_mem` kommt aus dem DTBO-Overlay.
- Jedes rekompilierte oder modifizierte DTB — auch semantisch identisch, auch
  mit `dtc -p 4096` — wurde mit aktivem DTBO vom Bootloader abgelehnt:
  Moto-Logo -> Reboot -> Reboot -> Lineage-Recovery.
- `qcom,msm-id = <0x16d 0x00>` und `qcom,board-id` allein genuegen nicht.
- Padding ist **nicht** die Ursache (getestet: 392.198 B ohne, 396.294 B mit
  Padding; beide abgelehnt).
- Konsequenz: Mainline-Tests mit eigenem DTB brauchen einen DTBO-Bypass
  (geleertes `dtbo_a`) oder U-Boot-Chainload; sonst sind sie nicht sinnvoll.

## 7. Mainline-Test (nur falls wieder aufgenommen)

```bash
$FB boot $DIST/test-boot-mainline-stockdtb.img   # 6.12 + Original-DTB
# oder
$FB boot $DIST/test-boot-mainline-m0.img         # 6.12 + Minimal-DTB
```

Beobachtung notieren:

| Beobachtung | Bedeutung |
|---|---|
| Kernel-Text auf Display | fbcon/simple-framebuffer funktioniert |
| Moto-Logo -> Display aus -> Fastboot | Bootloader hat Display abgegeben, Kernel aber nicht sichtbar |
| 2 Reboots -> Recovery | DTB vom Bootloader abgelehnt (bei eigenem DTB) |
| Rescue/SSH kommt | Kernel bootete; pstore lesen |

Danach **ohne Android-Zwischenschritt** in Slot b booten und pstore lesen
(Abschnitt 5).

## 7a. DTBO0-Test (vorbereitet, Freigabe noetig)

Ziel: Den Vendor-Overlay-Merge umgehen, damit ein eigenes Mainline-DTB
ueberhaupt akzeptiert werden kann. **Nur `dtbo_a` anfassen; `dtbo_b` bleibt
unangetastet, damit der Rescue-Slot `b` weiter funktioniert.**

**ABL-Befund 2026-11-06:** Ein **genulltes `dtbo_a` ist kein Bypass**. ABL
meldet `Dtbo hdr magic mismatch 0, with D7B7AB1E` -> `Error: Device Tree blob
not found` -> `BootLinux() failed: Not Found`. `erase dtbo_a` wird zudem mit
`Permission denied` abgelehnt. Der erste `stockbin`-Test wurde durch
`ERROR: NO ACTIVE SLOT FOUND` abgebrochen, nicht durch das Image.

### 7a.1 Sauberer `stockbin`-Retest (zuerst, ohne dtbo-Flash)

`test-boot-mainline-stockbin.img` enthaelt das **binaer** mit `fdtput`
gepatchte Stock-DTB (simple-framebuffer, keine Decompile-Runde). Alle 1.279
`__symbols__` und die 190 Fixup-Ziele bleiben erhalten. Mit **aktivem**
`dtbo_a` wird die Stock-Overlay-Merge-Strecke getestet:

```bash
$FB set_active a
$FB getvar current-slot          # muss a sein
$FB getvar slot-successful:a
$FB getvar slot-unbootable:a
$FB boot $DIST/test-boot-mainline-stockbin.img
```

Wenn das bootet, braucht es keinen `dtbo_a`-Eingriff. Wenn nicht: pstore
sichern (Abschnitt 5) und erst danach den DTBO0-Pfad versuchen.

**ABL-Befund 2026-11-06:** Der saubere Retest (Zyklus 652/655) laedt und
decompressed das 6.12-Image, appliziert das Overlay (569 ms), bleibt dann
aber in `DXE_ASSERT!: .../platform/boota (786):` haengen und resettet
(DataSize 0), **bevor** `Update Device Tree`/`Shutting Down UEFI Boot
Services`/Kernel-Entry. Das Prep-Image (4.14 + Stock-DTB) laeuft an
derselben Stelle durch. Zur Isolation:

```bash
# 6.12 + Original-Stock-DTB (kein fdtput-Patch)
$FB boot $DIST/test-boot-mainline-stockdtb.img
# 4.14 + dasselbe binaer gepatchte Stock-DTB (DTB-Kontrolle)
$FB boot $DIST/test-boot-414190-stockbin-dtb.img
```

Wenn `stockdtb` ebenfalls assertet, ist das 6.12-Image der Ausloeser; wenn
`414190-stockbin-dtb` bootet, ist das gepatchte DTB in Ordnung.

**Cmdline-Hypothese (extern, Gemini):** Der `boota (786)`-Assert soll durch
eine nicht-leere `--cmdline` im `boot.img`-Header ausgeloest werden. Dafuer
gebaute Varianten mit leerer Header-Cmdline und Kernel-Args in
`/chosen/bootargs`:

```bash
# 4.14 + gepatchtes DTB, leere Header-Cmdline (Cmdline-Kontrolle)
$FB boot $DIST/test-boot-414190-stockbin-emptycmd.img
# 6.12 + gepatchtes DTB, leere Header-Cmdline
$FB boot $DIST/test-boot-mainline-stockbin-emptycmd.img
# 6.12 + Original-DTB, leere Header-Cmdline
$FB boot $DIST/test-boot-mainline-stockdtb-emptycmd.img
```

Bootet die 4.14-Variante, war die Header-Cmdline der Ausloeser; assertet
auch sie, liegt es am gepatchten DTB. Bootet 6.12 + Original-DTB nicht,
liegt es am 6.12-Image/Boot-Protokoll.

Falls die 6.12-Varianten weiter asserten, mit **eingebauter Force-Cmdline**
testen (`CONFIG_CMDLINE_FORCE=y`):

```bash
$FB boot $DIST/test-boot-mainline-stockbin-cmdline.img
$FB boot $DIST/test-boot-mainline-stockdtb-cmdline.img
```

### 7a.3 USB2-/Display-Build (6.12)

`Image-6.12-usb2.gz` hat `SM_GCC_7150`, `PINCTRL_SM7150`, USB/PHY/UFS
**eingebaut**; die DTBs `stock-usb2.dtb`/`stockbin-usb2.dtb` nutzen
Mainline-Compatibles (`qcom,sm7150-gcc`, `qcom,sm7150-tlmm`,
`qcom,dwc3`, `qcom,qusb2-v2-phy`) und `dr_mode=peripheral` /
`maximum-speed=high-speed`; `stockbin-usb2.dtb` setzt zusaetzlich
`memory-region` am Framebuffer.

```bash
# Original-DTB, nur USB2 (kein fb)
$FB boot $DIST/test-boot-mainline-stockdtb-usb2.img
# gepatchtes DTB, USB2 + simple-framebuffer memory-region
$FB boot $DIST/test-boot-mainline-stockbin-usb2-fb.img
```

Wenn SSH/USB kommt: `uname -r` = 6.12; pstore/Logs pruefen. Wenn nicht:
RO-Rescue (`test-boot-414190-pstore-ro.img`) booten und den 6.12-Log
auslesen; dort stehen `dwc3`/`qusb2`/`gcc`/`simpledrm`-Fehler.

### 7a.4 Mini-DTBO: von ABL verworfen (Custom-DTBO-Pfad tot)

Der Test hat gezeigt: ABL prueft den AVB-Hash des DTBO und loescht bei
Abweichung:

```text
SSM: dtbo_a image vbmeta ok
dtbo: Hash of data mismatch digest in descriptor. Image corrupted?
validate_vbmeta_info_in_tree: image dtbo salt expected.
validate_vbmeta_info_in_tree: image dtbo digest expected.
erasing dtbo_a
```

Ein selbstgebautes DTBO ist ohne Motorola-Signatur **nicht flashbar**.
`dtbo_a` ist danach leer; das Stock-Overlay (ramoops) fehlt, deshalb
kein pstore. **Stock-DTBO wiederherstellen** und pruefen:

```bash
$FB flash dtbo_a firmeware/stock_dtbo.img
$FB set_active a
# optional in Recovery: adb exec-out dd if=/dev/block/by-name/dtbo_a bs=1M count=24 | sha256sum
# Erwartung: 111c29e9ddaa3d910360b03dfe518c3d0adec26e3d7698c4aa606f994c9b8a3b
```

Naechster Weg ohne Custom-DTBO: mainline USB-Nodes in das **Boot.img-DTB**
(unsigned, Stock-Basis + Stock-Overlay) einbauen, oder U-Boot chainloaden.

### 7a.2 DTBO0-Pfad mit valider Mini-DTBO

Voraussetzungen:

- Aktiver Slot ist `a` (`fastboot getvar current-slot`).
- Backup: `/workspace/firmeware/stock_dtbo.img`, 25.165.824 B,
  SHA256 `111c29e9…a3b`. Read-only gegen `dtbo_a`/`dtbo_b` geprueft:
  erste 24 MiB byte-identisch.
- `qcom,pmic-id` ist auf diesem Geraet **nicht vorhanden** (Stock-DTB, DTBO,
  Live-Tree); die Minimal-DTBs uebernehmen exakt diese Abwesenheit.
  `model="odessa"`, `compatible="qcom,sdmmagpie"` sind exakt die Stock-Werte.
- `out/mini-dtbo-avb.img` (25.165.824 B): valider DTBO-Header, **ein
  No-Op-Overlay** (`target-path="/"`, 0 Fixups), Stock-AVB-Footer/vbmeta
  erhalten. Die AVB-Hashes passen nicht mehr zum geaenderten DTBO-Inhalt;
  ob ABL das im Orange-State akzeptiert, ist **nicht getestet**.

Ablauf:

```bash
# 1. Sauberer Slot + Sicherheitscheck
$FB set_active a
$FB getvar current-slot          # muss a sein
sha256sum /workspace/firmeware/stock_dtbo.img

# 2. Valide Mini-DTBO flashen (NICHT das genullte Image!)
$FB flash dtbo_a $DIST/mini-dtbo-avb.img

# 3. Testreihenfolge: explicit zuerst (echte Memory-Ranges)
$FB boot $DIST/test-boot-mainline-dtbo0-explicit.img
# falls ohne Output:
$FB boot $DIST/test-boot-mainline-dtbo0-inject.img
$FB boot $DIST/test-boot-mainline-stockbase-dtbo0.img

# 4. Post-Mortem ohne Android-Zwischenschritt
$FB set_active b && $FB reboot
ssh -i $KEY root@172.16.42.1 'ls -l /tmp/pstore-*; tail -c 3000 /tmp/pstore-console-ramoops-0'

# 5. dtbo_a wiederherstellen, BEVOR Android gestartet wird
$FB flash dtbo_a /workspace/firmeware/stock_dtbo.img
$FB set_active a
```

Falls `fastboot flash dtbo_a mini-dtbo-avb.img` die Partition erneut leert
oder ABL `dtbo salt/digest`/Hash-Fehler meldet: **nicht weiter raten** —
dann braucht es entweder einen korrekten AVB-Hash-Footer (Signatur im
Orange-State unkritisch) oder den U-Boot-Chainload.

Erwartete Beobachtungen:

| Beobachtung | Deutung |
|---|---|
| Kernel-Text auf Display | fbcon/simple-framebuffer funktioniert |
| 6.12-Zeilen im pstore | Kernel lief mindestens bis pstore_init |
| Moto-Logo -> Display aus -> Reboot | Kernel kam nicht bis fbcon; pstore pruefen |
| sofortiges Fastboot/Recovery | ABL hat DTB/DTBO weiterhin abgelehnt |

**Wichtig:** Nach dem Test `dtbo_a` zurueckschreiben. Ohne Overlay fehlen
Android/Recovery die Vendor-Knoten; Slot `a` ist dann nicht normal bootbar.
Slot `b` (Rescue) bleibt durch das unveraenderte `dtbo_b` intakt.

**Status:** Artefakte gebaut, **nichts geflasht**. Der Schritt ist reversibel,
aber persistent und braucht ausdrueckliche Freigabe.

### 7b. U-Boot-Chainload (Test, RAM only)

Detailplan: `UBOOT-PLAN.md`. Voraussetzungen: `u-boot.bin` und FIT sind
gebaut; `mkimage`/`mkbootimg` liegen unter `re-tools`. Der FIT ersetzt die
Ramdisk im `boot.img`; ABL laedt ihn nach **`0x85367000`** (belegt ueber
`/proc/device-tree/chosen/linux,initrd-start`).

```bash
# 1. FIT bauen (Kernel 6.12 + minimales odessa-DTB + Initramfs)
/workspace/work/odessa/.re/uboot/build-fit.sh

# 2. boot.img v2 packen: u-boot.bin als Kernel, FIT als Ramdisk,
#    Stock-DTB, leere Header-Cmdline
/workspace/work/odessa/.re/uboot/pack-uboot-bootimg.sh

# 3. RAM-only testen (nichts flashen)
$FB boot /workspace/work/odessa/.re/uboot/test-boot-uboot-odessa.img

# 4. Beobachtung: Display-Konsole (simplefb, 0x9c000000, 1080x2400),
#    UART 0xa88000 (falls Pins zugreifbar), USB-TTY als Fallback.
# 5. Nach dem Test: 4.14-Rescue booten und pstore lesen
$FB boot $DIST/test-boot-414190-pstore-ro.img
ssh -i $KEY root@172.16.42.1 'cat /tmp/pstore-console-ramoops-0'

# 6. Kein Flash. Nur fuer einen Slot-a-Normalboot danach:
$FB flash dtbo_a /workspace/firmeware/stock_dtbo.img
```

Erwartung: U-Boot startet, zeigt eine Konsole, liest den FIT bei
`0x85367000`, laedt Kernel/FDT/Initramfs nach `0x90000000`/`0x8F000000`/
`0xA0000000` und bootet 6.12 bis `/init`; pstore unter `0xaf000000`.
Bei Fehlschlag: 4.14-Rescue booten; `dtbo_a`/`dtbo_b` nicht anfassen.

## 8. Aufraeumen / Wiederherstellung

```bash
# Android zurueck
$FB set_active a
$FB reboot

# Falls ein Test-Boot haengt: Power ~10 s halten, dann Vol-Down -> Fastboot
```

Optionaler Hygiene-Punkt: Beim `misc`-Test wurde einmalig
`bootonce-bootloader` an Offset 0 von `/dev/sdb4` geschrieben. Motorolas ABL
ignoriert das (Gerät kam als USB-Gadget zurueck). Verifiziert am 2026-11-06:
Die ersten 64 Byte von `misc` sind wieder komplett 0; kein Aufraeumen noetig.

## 9. Akku

- Ubuntu-RootFS: BusyBox-Init ruft `battery-guard.sh` alle 30 s auf
  (55/60-Hysterese); systemd-Units liegen nur fuer spaeter bereit.
- Das **Rescue-Initramfs hat keinen Guard**: Solange das Kabel steckt, laedt
  das Geraet durch. Akkustand am 2026-11-06: 87 %, `status=Charging`,
  `current_now=748596`, `voltage_now=4471395` (Recovery-Sicht).
- Bei langer Arbeit im Rescue: entweder Kabel ziehen oder Guard nachruesten.

## 10. Abnahmekriterien (Produktivpfad)

1. `fastboot boot` des Prep-Images liefert OKAY.
2. USB-Gadget erscheint, Host bekommt per DHCP eine Adresse.
3. `ssh -i id_ed25519 root@172.16.42.1` liefert `uid=0(root)`.
4. `uname -r` = `4.14.190-perf+`; `/proc/version` = eigener Build.
5. Ubuntu-Image: `PRETTY_NAME="Ubuntu 22.04.5 LTS"`, `/` auf `/dev/sdb24`.
6. Panic-Test: nach `echo c > /proc/sysrq-trigger` steht
   `Kernel panic - not syncing: sysrq triggered crash` im pstore.

## Finaler Boot-Stand (2026-11-07)

```
RT=/home/zero/.local/share/opencode/re-tools
$RT/bin/fastboot boot /workspace/work/odessa/.re/uboot/test-boot-uboot-odessa-fix28.img
```

Erwartung: U-Boot -> FIT -> 6.12 -> initramfs -> UFS -> switch_root ->
Ubuntu 22.04.5 auf /dev/sdb24, SSH auf 172.16.42.1 (usb0).

Recovery/Fallbacks (RAM-only):
- `test-boot-uboot-odessa-fix26.img` — 6.12 mit UFS, ohne switch_root
- `test-boot-uboot-odessa-fix23.img` — 6.12 mit USB/SSH, UFS aus
- `test-boot-uboot-odessa-fix9.img` — aelterer 6.12-Stand ohne GCC/USB

Wichtig: `CONFIG_CMDLINE_FROM_BOOTLOADER=y`; die effektive Cmdline kommt aus
FIT/DTB. Aenderungen an `bootargs` muessen dort erfolgen, nicht in
`CONFIG_CMDLINE`.

## Keeper 2026-11-07 (W1/W2-reg/W3)

```
RT=/home/zero/.local/share/opencode/re-tools
$RT/bin/fastboot boot /workspace/work/odessa/.re/uboot/test-boot-uboot-odessa-fix35.img
```

Enthaelt: PDC mainline (`qcom,pdc` + `qcom,pdc-ranges`, 2 Zellen),
SPMI-`periph_irq` LEVEL_HIGH (0 Warnungen), 31 registrierte
PM6150/PM6150L-Regler und `regulator_ignore_unused`.
UFS nutzt weiterhin die Fixed-Rails; der Umstieg auf RPMh-Rails haengt im
synchronen Enable-Pfad (siehe STATUS, W2-Blocker).

Der Bildschirm zeigt bei `loglevel=4` bis zu den `[init]`-Zeilen (~3,9 s) nur
den U-Boot-Text `Starting Kernel . . .` — das ist **kein** Fehlerindikator.
SSH ist der Indikator (`ssh -i $KEY root@172.16.42.1`).

## Release flashen (Ubuntu 26.04, validiert 2026-11-07)

```bash
cd /workspace/work/odessa/out
sha256sum -c <<'SUMS'
293533942759a466b0193645bb74e989be78e59988508b9dd2fce54744731f15  odessa-6.12-boot.img
SUMS
fastboot erase userdata
fastboot flash boot_b odessa-6.12-boot.img
fastboot set_active b
fastboot reboot
```

Erster Boot: Self-Install (~20 s), danach `switch_root` -> systemd.
Zweiter Boot: direkt, ohne Self-Install.
Pruefen: `systemctl is-system-running` = running, `systemctl --failed` = 0,
`df -h /` = 107G, usb0 = 172.16.42.1/24.

Rueckweg 22.04: `out/legacy-2204/odessa-6.12-2204-boot.img` flashen.
Wichtig: nie Hostkeys/Logs auf dem *laufenden* System loeschen (SSH bricht);
Hygiene nur mit `scripts/sanitize-rootfs.sh` auf der Host-Kopie.
