# Externe Recherche: Mainline SM6150 / ABL-DTB / frueher Boot ohne UART

RUN_ID=20261106-odessa-usbgadget
Status: **offen** — Nutzer recherchiert extern (Option D, 2026-11-06).
Zweck: belastbare oeffentliche Quellen finden, bevor weitere Boot-Zyklen oder
Hardware-Eingriffe unternommen werden.

## Bekannter, verifizierter Kontext (fuer die Recherche)

- Geraet: Motorola Moto G9 Plus, XT2087-2, Codename `odessa`, SoC Qualcomm
  SM6150 / Snapdragon 675 / `sdmmagpie`, 4 GB RAM.
- Bootloader unlocked (`verifiedbootstate=orange`, `flash.locked=0`);
  `fastboot boot` funktioniert.
- Stock/LineageOS-Kernel: 4.14.190 (Downstream-Vendor-Tree).
- Kein UART/Serial zugänglich.
- Eigener 4.14-Kernel + Stock-DTB + eigenes Initramfs bootet; USB-NCM +
  DHCP + SSH funktionieren.
- pstore/ramoops @ `0xaf000000` funktioniert mit Stock-DTB; Panic-Logs
  ueberleben einen Reboot.
- Linux 6.12 arm64 baut mit minimalem DTS.

## Beobachtete Fehlschläge (verifiziert)

1. Linux 6.12 + **Original-Stock-DTB**: `fastboot boot` meldet OKAY; Moto-Logo
   verschwindet; danach Reboot/Fallback. **Kein 6.12-Log im pstore-Snapshot**
   (Caveat: der anschliessende Recovery-Boot kann den Ringpuffer ueberschrieben
   haben). Kein fbcon, kein USB.
2. Jedes Boot-Image mit **geaendertem oder rekompiliertem DTB** (auch fast
   identisch, inkl. `dtc -p 4096` Overlay-Padding) fuehrt zu zwei Reboots und
   Lineage-Recovery. Das **Original-DTB** funktioniert unveraendert.
3. Das Stock-DTB enthaelt einen **leeren** `/memory`-Platzhalter
   (`reg = <0 0 0 0>`), den ABL beim Boot fuellt, und **keinen**
   `ramoops`-Knoten; `ramoops_mem` kommt aus DTBO-Entry 2 (`fragment@28`).

## Prompt fuer Gemini (copy-paste, Englisch)

```text
Context: I need public prior work and technical details for running a mainline
Linux kernel on a Qualcomm SM6150 phone.

Device: Motorola Moto G9 Plus (XT2087-2), codename "odessa", SoC Qualcomm SM6150
/ Snapdragon 675, also known as "sdmmagpie", 4 GB RAM. Bootloader is unlocked;
`fastboot boot` works. Stock/LineageOS kernel is 4.14.190 (downstream vendor
tree). No UART/serial console is accessible on the device.

What already works (verified):
- A custom boot.img (header v2, page size 4096) with the stock 4.14 kernel, the
  ORIGINAL stock DTB extracted from stock_boot.img, and a custom initramfs boots
  fine; USB NCM gadget + SSH come up.
- pstore/ramoops at physical 0xaf000000 works when the stock DTB is used; panic
  logs survive a reboot.
- Linux 6.12 arm64 builds with a minimal custom DTS.

What fails:
- Linux 6.12 + the ORIGINAL stock DTB: `fastboot boot` returns OKAY, the Moto
  logo disappears, then the device reboots; there is NO 6.12 pstore output
  (though a later recovery boot may have overwritten the buffer). No fbcon, no
  USB.
- Any boot.img whose DTB is modified or even recompiled from the stock DTB
  (`dtc -I dtb -O dts`, add one simple-framebuffer node, recompile with
  `-p 4096` padding) causes two reboots, then Lineage recovery. The original DTB
  works; the recompiled near-identical one does not.
- The stock DTB contains an EMPTY /memory placeholder (reg = <0 0 0 0>) that
  the bootloader fills at boot, and NO ramoops node; ramoops_mem comes from
  the dtbo overlay (entry 2, fragment@28).

Please find concrete, linkable answers to:
1. Does ANY public project run mainline Linux (5.x/6.x) on Qualcomm SM6150 /
   "sdmmagpie"? Look for sm6150.dtsi, board DTS for odessa/Moto G9 Plus, patches
   on lore.kernel.org, linux-msm, linux-next, postmarketOS. (I know pmOS has only
   a downstream 4.14.117 port for odessa.)
2. How does Qualcomm/Motorola ABL handle the DTB inside a boot.img (header v2
   dtb field) together with the dtbo partition overlay? Why would a recompiled
   but semantically equivalent DTB be rejected? Are there constraints on
   padding, phandle numbering, string table, qcom,msm-id/qcom,board-id, or a
   hash/signature check?
3. Is there a supported way on Motorola/Qualcomm devices to supply a custom DTB
   (or disable/skip the dtbo overlay merge) via `fastboot boot`? E.g. fastboot
   oem flags, appended DTB, androidboot.dtbo_idx=0, or a boot.img variant.
4. Do newer vendor kernel trees exist for SM6150 devices (Moto G8 Plus, Nokia
   6.2/7.2, etc.) with 4.19/5.4/5.10 that could be adapted to odessa?
5. Proven ways to debug very early ARM64 Qualcomm boot without UART:
   ramoops/pstore, ABL logs in mmi_annotate/utags partitions, qcom cmd-db,
   EDL/crash dumps, earlycon alternatives, anything else.
6. Any documented case of booting a 6.x mainline kernel on an SM6150 phone at
   all?

Prioritize concrete repos, commit links, XDA threads, Matrix/IRC logs, kernel
mailing list posts, and postmarketOS issues over generic explanations. If
something is unknown, say so explicitly. Give me a list of URLs I can read.
```

## Eigene Suchliste

| Suchbegriff | Ort | Worauf achten |
|---|---|---|
| `sm6150 mainline linux dts` | Google, GitHub | irgendein `sm6150.dtsi`, auch unfertig |
| `"sdmmagpie" site:lore.kernel.org` | Google | Patches von Qualcomm-Ingenieuren |
| `Moto G9 Plus mainline kernel` | XDA, Google | Threads im Moto-G9-Plus-Forum |
| `motorola odessa postmarketOS` | postmarketOS Wiki/Matrix | Port-Status, ob jemand Mainline versucht |
| `qcom dtbo overlay fastboot boot custom dtb` | Google, XDA | wie ABL Overlays anwendet |
| `abl dtbo_idx boot.img dtb` | Google | Qualcomm-ABL-Verhalten |
| `"fdt_overlay_apply" bootloader padding` | Google | Puffer-Anforderung beim Merge |
| `sm6150 4.19 kernel source` / `5.4` / `5.10` | GitHub | neuere Vendor-Trees von Schwestergeraeten |
| `qualcomm early boot debug without uart ramoops` | Google, lore | Alternativen zu UART |
| `Moto G9 Plus UART test points` | XDA, Google | Lage der Testpads (Option A) |

## Konkrete Orte

- GitHub: `sm6150-motorola/android_kernel_motorola_sm6150`,
  `LineageOS/android_kernel_motorola_sm6150`, `linux-msm/linux`,
  `postmarketOS/pmaports` (`device/testing/device-motorola-odessa`)
- postmarketOS Matrix (`#postmarketos:matrix.org`) — direkt fragen, ob jemand
  an `odessa`/`sm6150` mainline arbeitet
- lore.kernel.org — Suche nach `sm6150`, `sdmmagpie`
- XDA — Moto G9 Plus Forum, „kernel“, „mainline“, „UART“
- Motorola Open Source (`opensource.motorola.com`) — 4.19/5.4/5.10-Quellen
- Qualcomm CodeAurora (`source.codeaurora.org` / `git.codelinaro.org`) —
  Downstream-Tags fuer `msm-4.19`/`msm-5.4`

## Bereits lokal geprueft (nicht extern)

- `torvalds/linux` und `linux-msm/linux`: **kein** `sm6150.dtsi` (404).
- Naechste Verwandte in Mainline: `sdm670.dtsi`, `sm6115`, `sm6125`, `sm7125`.
- PM6150/PM6150L RPMh-Regulatoren vorhanden; `pinctrl-sdm670`, `ufs-qcom`,
  `dwc3`, `qusb2/qmp-phy`, `rpmh/scm/smem` vorhanden.
- `gcc-sdm670` wird von `gcc-sdm845.c` behandelt; SM6150-GCC-IDs und
  Interconnect fehlen.
- postmarketOS `odessa`: nur Downstream `linux-motorola-odessa 4.14.117`.

## Entscheidungsregel

Erst nach belastbaren Links/Patches wird wieder ein Boot-Zyklus gestartet.
Reine Wiederholung derselben DTB-Varianten gilt als verschwendet
(3 fehlgeschlagene Ansaetze -> Strategiewechsel, siehe Betriebsregeln).

## Ergebnisse

Noch keine externen Ergebnisse eingetragen. Nutzer liefert Links; Hub prueft
sie lokal (Clone/Read) und dokumentiert hier sowie in `STATUS.md`.

## Lokale Verifikation der Recherche (2026-11-06)

| Behauptung | Lokaler Befund |
|---|---|
| Stock-DTB ist concatenated Multi-DTB | **Falsch für dieses Gerät**: ein FDT, `totalsize=393031`, nur ein `0xd00dfeed`-Magic |
| Stock-DTB hat kein `/memory` | **Falsch**: leerer `memory`-Knoten `reg=<0 0 0 0>` vorhanden; ABL fuellt ihn (live: `0x80000000+2G`, `0x100000000+~2G`) |
| Stock-DTB hat `qcom,pmic-id` | **Nicht vorhanden** (weder im DTB noch live) |
| Mainline kann GIC/Timer aus Vendor-FDT nicht initialisieren | **Nicht durch Bindings gestuetzt**: Stock-DTB nutzt `arm,gic-v3`, `arm,armv8-timer`, `arm,psci-1.0`; Ursache damit nicht belegt |
| Minimal-DTB scheitert nur an `__symbols__` | **Unvollstaendig**: Stock-DTB hat 1.279 Symbole; der aktive DTBO-Entry 2 hat 104 Fragments und 190 Symbol-Fixups auf den vollen Vendor-Tree. Ein Minimal-DTB kann den Merge nicht erfuellen |
| Board-ID `<0 0>` | **Falsch für diesen Boot**: live `qcom,board-id=<0x49 0xc000>`, passend zu DTBO-Entry 2 (`dtbo_idx=2`) |
| Genulltes `dtbo_a` = Bypass | **Falsch**: ABL meldet `Dtbo hdr magic mismatch 0, with D7B7AB1E` -> `BootLinux() failed: Not Found` (logfs cycles 628–634) |
| `fastboot erase dtbo_a` | **Nicht erlaubt**: `Permission denied`; Flashen eines 24-MiB-Null-Images wird angenommen, aber ABL verwirft das DTBO beim Boot |
| Erster `stockbin`-Test beweist Vendor-DTB-Dead-End | **Nein**: Abbruch durch `ERROR: NO ACTIVE SLOT FOUND` / `No bootable A/B slot` (Zyklus 627), bevor das Image bewertet wurde |
| `explicit` erzeugte einen Kernel-Panic | **Nicht belegt**: Die „Boot-Loop" war ABL-Retry nach `BootLinux() failed`; der `kernel_panic`-Eintrag in LOG87 ist Zyklus 599 (aelter) |
| Linux 6.12 hat QCS615/SM6150-Support | **Im lokalen 6.12.0 nicht vorhanden**: kein `qcs615.dtsi`/`sm6150.dtsi` von Upstream; nur unser Minimal-DTS |
| SM6150-Mainline erst ab 6.16+ | **Extern, lokal nicht verifizierbar** (kein neuerer Tree lokal) |
| A70/U-Boot/odessa-Ports | **Extern, lokal nicht verifizierbar** (keine Quellen lokal) |

Konsequenz: Der DTBO-Overlay-Merge ist der harte Blocker fuer jedes
nicht-vendor-konforme DTB. Ohne `dtbo`-Bypass (leeres `dtbo_a`) oder
U-Boot-Chainload ist ein eigenes Mainline-DTB auf diesem Bootloader nicht
testbar. Die Behauptung "Vendor-DTB ist immer ein Dead End" ist plausibel,
aber die genannten GIC/Timer-Gruende sind lokal nicht belegt.
