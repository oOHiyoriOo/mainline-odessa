# DEAD ENDS — RUN 20261106-odessa-usbgadget

Konsolidierte Liste aller Ansaetze, die **nicht** zum Ziel fuehrten, mit Beleg
und Konsequenz. Bewusst als eigene Datei, damit sie beim Publizieren nicht
zwischen den Erfolgsmeldungen untergehen. Details stehen im `STATUS.md`.

| # | Dead End | Beleg | Konsequenz |
|---|---|---|---|
| D1 | Eigene/korrigierte DTB per `fastboot boot` (eigener `dtb`-Offset) | STATUS §4.13 | Bootloader lehnt ab (2 Reboots -> Recovery). Nur der ABL-gemergte Vendor-Base-Tree funktioniert. |
| D2 | Genulltes `dtbo_a` als Bypass | STATUS §4.13 | ABL: `Dtbo hdr magic mismatch 0, with D7B7AB1E` -> `BootLinux() failed: Not Found`. |
| D3 | Minimal-DTB statt Vendor-Merge | STATUS §4.13 | Der aktive DTBO (Entry 2) hat 104 Fragments/190 Symbol-Fixups und braucht den vollen Base-Tree. |
| D4 | `misc`-Trick | STATUS §4.14 | Wird vom Bootloader ignoriert. |
| D5 | Custom-DTBO auf `dtbo_a` flashen | STATUS §4.13 / Entscheidungen | Verworfen; `dtbo_a`/`dtbo_b` bleiben Stock, `dtbo_b` ist Rettungsslot. |
| D6 | U-Boot-USB-Gadget-Handoff (Fix11/Fix12, `serial_gadget`) | STATUS Rev. 00:05 | Unzuverlaessig bzw. haengt; ersetzt durch echten GCC-Port + DWC3/QUSB2. |
| D7 | RPMh-Regulatoren aus U-Boot | Scout UBOOT-QCS615-MAP-02 | U-Boot hat `pm6150l_vreg_data`, aber keinen `pm6150`-Eintrag; QUSB2 braucht keine Supplies, UFS schon. |
| D8 | Vendor-PDC als Root-IRQ-Controller (3 Zellen) | STATUS Fix22, PDC-INV-02 | Mainline `qcom-pdc` matcht nur `"qcom,pdc"`, braucht 2 Zellen + `qcom,pdc-ranges`; unmapped Pins werden **disconnected** (kein Pass-Through). Zwischenloesung: Root -> GIC; spaeter Fix29. |
| D9 | Vendor-`cmd-db`-Pointer-Knoten `/soc/qcom,cmd-db@c3f000c` (8 Byte) | STATUS Fix22, REG-INV-02 | Mainline akzeptiert nur ein `/reserved-memory`-Kind mit `reg`; Entfernen des Knotens machte SPMI probe-faehig. |
| D10 | Mainline-GCC mit 6.12er-Ops-Namen | GCC-INV-01 / GCC-SYN-01 | `clk_branch2_hw_ctl_ops`, `clk_dummy_ops`, `clk_fabia_fixed_pll_ops`, `clk_generic_pll_postdiv_ops` existieren nicht in 6.12; ersetzt durch `clk_branch_simple_ops`, lokale `gcc_dummy_ops`, `clk_alpha_pll_fixed_fabia_ops`, `clk_alpha_pll_postdiv_ops`. |
| D11 | XO-Clock heisst `bi_tcxo` | STATUS Fix23 | `clk-rpmh` kann seine ARC-Clock nicht registrieren (-EEXIST); Rename auf `xo_board`. |
| D12 | `CONFIG_CMDLINE_FORCE=y` | STATUS Fix28 | Bootloader-/DTB-Cmdline wurde komplett ignoriert (kein `odessa.boot=ubuntu`, kein 16x32-Font). |
| D13 | `CONFIG_PHY_QCOM_QMP_UFS=m` | STATUS Fix26 | UFS-PHY war nur Modul und nicht im Initramfs -> HC deferrte endlos. |
| D14 | `ldo18` mit `regulator-boot-on`/`always-on` | STATUS Fix33/34/35 | Loest beim Probe ein **synchrones** RPMh-Enable aus; `rpmh_rsc_send_data()` wartet unbegrenzt auf einen freien TCS -> Boot-Haenger vor der Initramfs. Fix35 entfernt die Flags. |
| D15 | UFS auf echten RPMh-Rails (Fix36/37/38/39) | STATUS W2-Blocker | Jeder `regulator_enable()` auf diesen Rails haengt im TCS-Wait, auch ohne Spannungs-Resend (Fix39). UFS bleibt auf Fixed-Rails. |
| D16 | systemd manuell aufs laufende Geraet installieren | Nutzerfeedback 2026-11-07 | Durch Installer-Pre-Install ersetzt (`rootfs-dl/systemd-debs.tar` + chroot im Zielrootfs). |
| D17 | pstore als primaere Post-Mortem-Quelle | STATUS Rev. 22:43 / Fix31 | Konsole-Record wird vom naechsten Boot ueberschrieben; `/tmp/pstore-*` teils leer. Live-SSH/dmesg ist die Wahrheit. |
| D18 | Bildschirm `Starting Kernel . . .` als Haenger-Indikator | STATUS Fix32/33 | Fehlschluss: `loglevel=4` zeigt bis zu den `[init]`-Zeilen (~3,9 s) nichts. SSH bzw. ein `fb0`-Sehtest entscheidet. |
| D19 | Vendor-Compatibles `qcom,msm-geni-serial-hs`, `qcom,pil-tz-generic`, `qcom,tsens24xx`, `qcom,msm-watchdog` | PDC-INV-02, IRQ-Audit | Kein Mainline-Match; Repointen der PDC-Phandles ist inert. |
| D20 | `qcom,pdc-sdmmagpie` als einziger Compatible | PDC-INV-02 | Matcht nicht; `"qcom,pdc"` muss mit im `compatible` stehen (Fix29). |
