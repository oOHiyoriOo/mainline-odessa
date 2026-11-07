# RUN 20261106-odessa-usbgadget — Dokumentationsindex

Ziel: Linux/Ubuntu auf dem Moto G9 Plus (`odessa`, SM6150) per
`fastboot boot` starten; spaeter Mainline-Port versuchen.

Status: **Produktivpfad 4.14/Ubuntu 22.04.5 läuft; Mainline 6.12 blockiert.**

## Einstieg

| Dokument | Inhalt |
|---|---|
| [`orchestrator/STATUS.md`](orchestrator/STATUS.md) | zentraler Status, Chronologie, Fakten, Hypothesen, offene Punkte |
| [`orchestrator/ARTIFACTS.md`](orchestrator/ARTIFACTS.md) | alle Artefakte mit Größe und SHA256 |
| [`orchestrator/RUNBOOK-boot-test.md`](orchestrator/RUNBOOK-boot-test.md) | Boot, Rescue-Slot, pstore, DTB-Regeln, Wiederherstellung |
| [`orchestrator/RESEARCH-mainline-sm6150.md`](orchestrator/RESEARCH-mainline-sm6150.md) | Gemini-Prompt und Suchliste für Mainline/ABL |

## Spoke-Notizen

| Dokument | Inhalt |
|---|---|
| [`software-manager/T2-TOOLCHAIN.md`](software-manager/T2-TOOLCHAIN.md) | Toolchain, Kernel-Quelle, Config |
| [`software-manager/T3-KERNEL-BUILD.md`](software-manager/T3-KERNEL-BUILD.md) | 4.14.190-Build, OpenSSL-Fix |
| [`software-manager/T7-DROPBEAR.md`](software-manager/T7-DROPBEAR.md) | statischer Dropbear |
| [`software-manager/T10-E2FSPROGS.md`](software-manager/T10-E2FSPROGS.md) | statische e2fsprogs |

Verwandter Run: `docs/re/20261106-adb-install/` (adb/platform-tools).

## Kurzfassung

- **Läuft:** 4.14.190 + USB-NCM-Initramfs (DHCP, SSH), Ubuntu 22.04.5 auf
  `/dev/sdb24`, Rescue in `boot_b`, pstore-Panic-Roundtrip, Installer.
- **Blockiert:** Linux 6.12 bootet nicht sichtbar; eigenes/rekompiliertes DTB
  wird vom Bootloader abgelehnt, Original-DTB liefert keinen Output. Ursache
  lokal eingegrenzt: Der aktive DTBO-Overlay braucht den vollen Vendor-Tree
  (104 Fragments/190 Fixups). DTBO0-Testartefakte sind vorbereitet, aber
  **nicht geflasht**. Kein UART.
- **Gerätezustand:** Slot `_a`, Lineage-Recovery; `boot_a` Stock,
  `boot_b` Rescue. Akku 87 %, lädt (Rescue ohne Battery-Guard).
