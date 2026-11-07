# LEADS / State Board — RUN 20261106-odessa-usbgadget

Stand 2026-11-07. Terminale Zustaende werden nicht blind neu gestartet.
Legende: **CLOSED** (belegt erledigt), **OPEN**, **BLOCKED** (konkreter
Blocker dokumentiert), **OUT_OF_SCOPE** (bewusst nicht verfolgt).

| ID | Lead | Status | Beleg / naechster Schritt |
|---|---|---|---|
| L-PDC-01 | PDC mainline-faehig (`qcom,pdc`, `qcom,pdc-ranges`, 2 Zellen) | **CLOSED** | Fix29/35; `/sys/bus/platform/drivers/qcom_pdc/` = `b220000.interrupt-controller`, keine Fehlermeldung |
| L-IRQ-01 | 9 `IRQ_TYPE_NONE`-Warnungen | **CLOSED** | Fix32/35; `dmesg \| grep -c gic_irq_domain_translate` = 0. Alle neun kamen vom SPMI-`periph_irq` (3 WARNs je Mapping) |
| L-REG-01 | RPMh-Regler registrieren (PM6150/PM6150L) | **CLOSED** | Fix35; 31 Regler in `regulator_summary` |
| L-REG-02 | RPMh-Regler als Verbraucher (UFS-Rails) | **BLOCKED** | Fix36-39 haengen im synchronen Enable/TCS-Wait; UFS bleibt auf Fixed-Rails. Naechster Ansatz: `qcom,tcs-config`/RSC-Completion der Vendor-DTB gegen Mainline pruefen |
| L-SYS-01 | systemd im Image | **CLOSED** | 26.04: systemd 259.9 als PID1 `running`, 0 failed units, self-install auf leerem userdata; `systemd-debs-2604.tar` + Installer-Reihenfolge gefixt |
| L-REL-01 | Einfaches flashbares Release-Image | **CLOSED** | 26.04-Release: `boot_b` + `set_active b` + reboot; Self-Install -> systemd 259, 0 failed; zweiter Boot ohne Self-Install. Siehe `RELEASE-PLAN.md` |
| L-REL-02 | Zweitgeraet (baugleich, XT2087-2) | **OPEN** | SSH-Key ersetzen; DTB an Build-Firmware/Panel gebunden; Flash-Weg identisch |
| L-PDC-02 | `wakeup-parent = <&pdc>` am TLMM (Phase B) | **OPEN** | Optional; ohne Suspend derzeit ohne Nutzen. Erst nach L-REG-02/L-PM-01 sinnvoll |
| L-PM-01 | Suspend/PM (PDC-Wakeup + RPMh-Rails) | **OPEN** | Haengt an L-REG-02 und L-PDC-02 |
| L-GPU-01 | `arm-smmu 5040000.arm,smmu-kgsl` + `gcc_gpu_memnoc_gfx_clk` (-16) | **OPEN (kosmetisch)** | GPU/KGSL nicht im Scope; Probe-Fehler ist nicht bootkritisch |
| L-AMBA-01 | `amba_device_add() failed (-16)` fuer Coresight-CTIs (~190 Zeilen) | **OPEN (kosmetisch)** | Vendor-DTS/AMBA-Ressourcenkonflikte; kein Boot-Einfluss |
| L-LPI-01 | `lpi_pinctrl@62b40000: could not get #gpio-cells ...` | **OPEN (kosmetisch)** | Vendor-DTS-Verweis auf Regler-Knoten statt Pinctrl |
| L-DSI-01 | Mainline-DSI/Panel | **OUT_OF_SCOPE** | Bootloader-Framebuffer traegt die Konsole; kein DSI-Treiber in 6.12 |
| L-FONT-01 | Noch groesserer Font als TER16x32 | **OPEN (optional)** | 67x75 Zeichen aktuell; 32x64 moeglich, aber nicht noetig |
| L-ARC-01 | `qcom,rpmh-arc-regulator` (cx/mx/gfx.lvl) | **OPEN** | Kein Mainline-Treiber; aktuell nicht benoetigt |
| L-USBPD-01 | USB-PD/Type-C (`qcom,qpnp-pdphy`) | **OUT_OF_SCOPE** | Kein Mainline-Match; USB-NCM/SSH laeuft ohne |
| L-CAM-01 | Kamera/CSI | **OUT_OF_SCOPE** | Kein Bedarf |
| L-MODEM-01 | Modem/Mobilfunk | **OUT_OF_SCOPE** | Kein Bedarf |
| L-RESCUE-01 | Rettungsslot-Architektur (`boot_b`, `dtbo_b` Stock) | **CLOSED** | Unveraendert; alle Tests RAM-only, kein Flash |

## Offene Entscheidungen

- **W4 Paketquelle**: erledigt (Freigabe 3, offizielles Ports-Repo) — systemd
  ist jetzt Teil des Installer-Pre-Installs.
- **Release-Form**: entschieden und validiert — ein `boot.img` (Self-Install)
  plus optional `rootfs.img`; Sanitizing host-seitig, siehe `RELEASE-PLAN.md`.
