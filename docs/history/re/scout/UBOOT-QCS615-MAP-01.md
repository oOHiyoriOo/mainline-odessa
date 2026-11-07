# UBOOT-QCS615-MAP-01 — Scout-Notiz (Phase 1, Breitensuche)

- PROJECT: odessa-usbgadget
- RUN_ID: 20261106-odessa-usbgadget
- TASK_ID: UBOOT-QCS615-MAP-01
- TARGET_ID: U-Boot v2026.10 source `/home/zero/.local/share/opencode/re-tools/src/u-boot-v2026.10` (read-only)
- ROLE: scout, LEAD_ID: UBOOT-QCS615-MAP, PHASE 1, MAX_CALL_DEPTH=0
- STATUS: **BLOCKED (Tool-Permission)** — U-Boot-Baum nicht lesbar. Lokale
  In-Workspace-Artefakte wurden als Ersatz teilweise ausgewertet; keine
  Gate-Entscheidung, keine Tiefenanalyse.

## 1. BLOCKER (zuerst, weil er den Auftragskern trifft)

Jeder Zugriff auf den zugewiesenen Zielpfad wird von der Tool-Permission-Schicht
abgewiesen (`external_directory`). Konkret versucht und abgewiesen:

| # | Aufruf | Ergebnis |
|---|---|---|
| B1 | `read configs/qcom_qcs615_defconfig` | `permission.rejected: Permission denied: external_directory` |
| B2 | `read <tree>` (Verzeichnislisting `.../re-tools`) | dito |
| B3 | `grep -n "qcs615" configs/` | dito |
| B4 | `glob dts/upstream/src/arm64/qcom/qcs615*` | dito |
| B5 | `glob .../qcom/{talos,pm6150,pm6150l}*` | dito |

Damit sind **alle** in der Aufgabe geforderten U-Boot-Einstiegspunkte
(`talos.dtsi`, `qcs615-ride.dts`, `qcs615-ride-u-boot.dtsi`, beide defconfigs,
`clock-qcs615.c`, `pinctrl-qcs615.c`, `serial_msm_geni.c`, `phy-qcom-qusb2.c`,
`dwc3-generic.c`, `simplefb.c`/video-Kconfig, `arch/arm/cpu/armv8/start.S`,
`u-boot.lds`, Bootflow/Binman) **nicht belegbar**. Ich erfinde dafür keine
`file:line`-Angaben. Permission-Umgehung (MCP, andere Rolle, Shell) ist nach
AGENTS.md ausgeschlossen und wurde nicht versucht.

Ein U-Boot-Quellbaum existiert auch nicht innerhalb von `/workspace`:
`glob **/u-boot*/configs/qcom_qcs615_defconfig` → 0 Treffer; `grep
"qcs615|talos.dtsi|QCS615"` in `/workspace` → nur Dokumentations- und
Memory-Notizen, kein Quellcode. `/workspace/out` und
`/workspace/work/odessa/t3-extra` enthalten keinen U-Boot-Baum.

## 2. Ersatzbefunde (lokal, selbst gelesen)

Quelle A: `/workspace/work/odessa/.re/uboot/stock-base.dts` (dekompilierter
Stock-DTB; nur zur Bestaetigung von Pin-/Regulator-/Node-Namen genutzt, wie im
Auftrag erlaubt). Quelle B: `linux-6.12/arch/arm64/boot/dts/qcom/pm6150.dtsi`.

| # | Fundstelle | Auszug (verbatim) | Relevanz |
|---|---|---|---|
| L1 | `stock-base.dts:11579-11593` | `qupv3_se8_2uart_pins {` / `qupv3_se8_2uart_active {` / `pins = "gpio44\0gpio45"; function = "qup12";` / `drive-strength = <0x02>; bias-disable;` | Exakte odessa-UART-Pinbelegung; `function = "qup12"` ist der Vendor-String, den die U-Boot-DTS treffen muss |
| L2 | `stock-base.dts:11545-11576` | `qupv3_se8_i2c_pins {` … `pins = "gpio42\0gpio43"; function = "qup12";` … sleep: `function = "gpio"; bias-pull-up;` | Belegt: dieselbe TLMM-Funktion `qup12` bedient SE8-I2C (42/43) **und** SE8-2UART (44/45); Namensschema ist SE-indexiert, nicht QUP-Wrapper-indexiert |
| L3 | `stock-base.dts:8640-8652` | `qcom,qup_uart@0xa88000 { compatible = "qcom,msm-geni-console"; reg = <0xa88000 0x4000>; clock-names = "se-clk\0m-ahb\0s-ahb"; … qcom,wrapper-core = <0x186>; status = "disabled";` | Stock-Compatible ist `qcom,msm-geni-console` (4.14-Vendor), **nicht** `qcom,geni-uart`/`qcom,geni-debug-uart`; UART braucht 3 Clocks + wrapper-core-Phandle |
| L4 | `stock-base.dts:18046-18056` | `serial0 = "/soc/qcom,qup_uart@0xa88000";` … `ufshc1 = "/soc/ufshc@1d84000";` | Aliases bestaetigen: UART = SE8/Wrapper1, UFS = 0x1d84000 |
| L5 | `stock-base.dts:18041-18044` | `chosen { bootargs = "rcupdate.rcu_expedited=1 rcu_nocbs=0-7"; phandle = <0x4b7>; };` | Stock-chosen hat **kein** `stdout-path` — das muss die odessa-U-Boot-DTS neu setzen |
| L6 | `stock-base.dts:16170-16204` | `ssusb@a600000 {` / `reg = <0xa600000 0x100000>;` … `dwc3@a600000 { compatible = "snps,dwc3";` | Stock-USB-Wrapper sitzt auf **0xa600000**, nicht 0xa6f8800 (SDM670-Mainline-Wert) — Adressdifferenz pruefen |
| L7 | `stock-base.dts:16249-16267` | `qusb@88e2000 { compatible = "qcom,qusb2phy-v2"; reg = <0x88e2000 0x400 0x780200 0x04 …>; vdd-supply/vdda18-supply/vdda33-supply …; clocks = <0x2f 0x00 0x27 0x97>;` | QUSB2-PHY: 3 Reg-Regionen (efuse/refgen), 3 Supplies, 2 Clocks; U-Boot-`qcom,qcs615-qusb2-phy`-Bindung muss diese Ressourcen abdecken |
| L8 | `stock-base.dts:4422-4450` | `ufshc@1d84000 { compatible = "qcom,ufshc"; reg = <0x1d84000 0x3000 0x1d90000 0x8000>; reg-names = "ufs_mem\0ufs_ice"; phys = <0x9d>; clock-names = "core_clk\0…\0ref_clk\0…"` | UFS-Node inkl. ICE-Region und 8 Clocks vorhanden; `phys`-Phandle separat |
| L9 | `stock-base.dts:12664-13117` (25 Treffer) | `rpmh-regulator-gfxlvl/-mxlvl/-smpc1/-cxlvl/-ldoa1…-ldoa17` | Alle odessa-Rails sind **RPMh-Regulatoren** (PM6150/PM6150L), keine SPMI-Direktregler |
| L10 | `pm6150.dtsi:36-38` | `&spmi_bus { pm6150_lsid0: pmic@0 { compatible = "qcom,pm6150", "qcom,spmi-pmic";` | PMIC-Identitaet (nur Referenz; Regler liegen in RPMh, vgl. L9) |
| L11 | `pm6150.dtsi:66-74` | `pm6150_vbus: usb-vbus-regulator@1100 { compatible = "qcom,pm6150-vbus-reg",` / `qcom,pm6150-typec` | VBUS/TypeC liegt im PM6150-LSID0 — fuer U-Boot irrelevant, aber Abgrenzung |

## 3. U-Boot-Tabelle: NICHT LIEFERBAR

Die in der Aufgabe verlangten Eintraege konnten nicht verifiziert werden. Der
Hub hat in CONTEXT bereits eine Reihe von Fakten vorgegeben (talos.dtsi-Knoten,
`uart6: serial@a88000`, defconfig-Symbole, Treiberdateien). Diese sind hier
**nicht** als Scout-Beleg wiederholt — sie stammen aus der Auftragsvorgabe, nicht
aus meiner Suche.

## 4. GAP-LISTE fuer odessa (soweit lokal belegbar)

1. **Pin-Funktion (Kernrisiko).** Stock nutzt `function = "qup12"` fuer GPIO44/45
   (`stock-base.dts:11587`). Ob `drivers/pinctrl/qcom/pinctrl-qcs615.c` diese
   Funktionsbezeichnung fuer GPIO44/45 anbietet (oder `qup1_se2`/`qup1` o. ae.),
   ist **unbekannt** (Blocker B1-B5). Ohne Treffer im Funktionsarray wird
   `pinctrl-0` beim U-Boot-DFU/-Init fehlschlagen.
2. **UART-Compatibles.** Stock: `qcom,msm-geni-console` (L3). U-Boot braucht
   `qcom,geni-uart` plus `qcom,geni-debug-uart` fuer die Debug-Konsole; ob
   `serial_msm_geni.c` `qcom,msm-geni-console` ebenfalls bindet: unbekannt.
3. **UART-Clocks.** Stock fordert `se-clk`, `m-ahb`, `s-ahb` (L3). Ob
   `clock-qcs615.c` alle drei IDs bereitstellt und ob `DEBUG_UART_BASE=0x880000`
   (defconfig, Hub-Kontext) zum tatsaechlichen 0xa88000 passt, ist zu pruefen —
   die Abweichung `0x880000` vs `0xa88000` ist ein konkreter Verdacht.
4. **USB-Basisadresse.** Stock `ssusb@a600000` (L6) vs. SDM670-Mainline
   `a6f8800`; welchen Wrapper `talos.dtsi` definiert, ist unbekannt.
5. **USB-PHY-Ressourcen.** Drei Reg-Regionen und drei Supplies (L7). Ob
   `phy-qcom-qusb2.c` die efuse-/refgen-Regionen fuer QCS615 akzeptiert (und ob
   `qcom,qcs615-qusb2-phy` ueberhaupt in der Match-Tabelle steht): unbekannt.
6. **Regulatoren (Kernrisiko).** Alle Rails sind RPMh-Regler (L9). Fehlt in
   U-Boot ein RPMh/RSC-Treiber, kann die odessa-DTS keine funktionierenden
   `vdd-supply`-Phandles liefern; USB/UFS muessten dann auf den von ABL
   hinterlassenen Reglerzustand vertrauen. Das ist eine offene Architekturfrage,
   keine Nebensache.
7. **PM6150 vs. PM8150.** `qcs615-ride` referenziert (laut Hub-Kontext)
   PM6150/PM6150L — odessa hat ebenfalls PM6150/PM6150L. Eine PM8150-Annahme
   waere falsch; im Scout war kein PM8150-Bezug in odessa-Artefakten sichtbar.
8. **Display.** Stock-chosen setzt keinen Konsolpfad (L5); odessa braucht
   `stdout-path = "serial0:115200n8", "vidconsole"` bzw. `CONSOLE_MUX`, plus
   `simple-framebuffer`-Knoten (0x9c000000/1080x2400/stride 4320/a8r8g8b8,
   Hub-Kontext). Ob `simplefb.c` ohne `CONFIG_VIDEO`-Konsolpfad als
   `vidconsole` registriert: unbekannt.
9. **UFS.** Node/Ressourcen sind bekannt (L8), aber ob U-Boot QCS615-UFS
   (PHY/ICE/8 Clocks) ueberhaupt treibt, ist ausserhalb des belegbaren Bereichs.
   Fuer das erste Milestone (Konsolen-Sichtbarkeit + Chainload) nicht kritisch.
10. **Board-ID/Memory.** Board-ID `<0x49 0xc000>` und die Memory-Knoten
    (`0x80000000/0x80000000`, `0x100000000/0x7dd00000`) sind Hub-Kontext; im
    Stock-DTS nicht gegengeprueft (ausserhalb des Pin-/Regler-Auftrags).

## 5. NEW_LEADS (max. 5, nicht weiter untersucht)

1. `drivers/pinctrl/qcom/pinctrl-qcs615.c` — Funktionsarray-Eintrag fuer
   GPIO44/45: enthaelt er `"qup12"`? (Blockiert; hoechste Prioritaet.)
2. `drivers/serial/serial_msm_geni.c` — Match-Tabelle: `qcom,geni-uart`,
   `qcom,geni-debug-uart`, `qcom,msm-geni-console`? Clock-/Baud-Handling.
3. `drivers/regulator/` — existiert ein RPMh-Regulator-/RSC-Treiber fuer
   QCS615/PM6150? Falls nein: USB/UFS-Supply-Strategie neu planen.
4. `dts/upstream/src/arm64/qcom/talos.dtsi` — Wrapper-Basisadresse USB
   (0xa600000 vs 0xa6f8800) und ob `uart6` `se-clk/m-ahb/s-ahb` nennt.
5. `configs/qcom_qcs615_defconfig` + `configs/qcom_defconfig` — `DEBUG_UART_BASE`
   (`0x880000` vs `0xa88000`), `CONSOLE_MUX`, `SYS_CONSOLE_IS_IN_ENV`,
   `USB_TTY`/`USB_GADGET`, `BOOTCOMMAND`, `REMAKE_ELF`/Binman, `WATCHDOG`.

## 6. SEARCHED_AND_EMPTY (tatsaechlich gelaufen, ohne Treffer)

- `glob /workspace **/u-boot*/configs/qcom_qcs615_defconfig` → 0 Treffer
  (kein U-Boot-Baum im Workspace).
- `grep "qcs615|talos\.dtsi|QCS615" /workspace` → nur Doku-/Memory-Notizen
  (`orchestrator/STATUS.md:1088-1106`, `software-manager/UBOOT-TOOLS-01.md:208`),
  kein Quellcode.
- `grep "geni-uart|qcom,geni-debug-uart|qcs615-ride|U_BOOT_DRIVER.*geni"
  /workspace` → nur Linux-6.12-DTS und Doku, kein U-Boot-Quelltext.
- `grep "simple-framebuffer|memory@|stdout-path" stock-base.dts` → nur
  `chosen {` (Zeile 18041); kein `stdout-path`, kein `memory@`-Knoten im
  dekompilierten Stock-DTS.
- `read /workspace/out`, `read /workspace/work/odessa/t3-extra` → kein
  U-Boot-Material.

## 7. GRENZEN

- U-Boot-Baum durchgehend `permission.rejected: external_directory`
  (5 Zugriffsversuche, verschiedene Tools) → Abschnitt 3 nicht lieferbar.
- MAX_CALL_DEPTH=0 eingehalten; keine Call-Ketten, keine Treiberlogik.
- Stock-DTB nur als dekompilierte `.dts` gelesen, nicht als Originalbyte.
- Keine Aussage ueber globale Abwesenheit von Symbolen im U-Boot-Baum.
- Suchbudget nicht ausgeschoepft (~14 Treffer-Gruppen), weil der Kernpfad
  gesperrt war.

## 8. Memory-Referenzen (Scratchboard)

- Plan: `8538cd27-b769-4945-bbf5-5e37893f1f36` (part_of_run, depends_on UBOOT-PLAN-01)
- Blocker: `ff6740d8-39cd-478a-bf0b-fa202aa5190f` (part_of_run)
- Finding-1 Pinconf: `0f8edaae-582b-4aa0-8d8a-9cc93074088a` (blocked_by Blocker)
- Finding-2 UART/geni: `f02633e9-567e-4960-8fbf-eda0a37fc01e`
- Finding-3 USB/QUSB2/UFS: `a31ac07e-6b54-4f5b-94f3-620b1115cd4a`
- Finding-4 RPMh-Regulatoren: `a1186601-6742-4819-8312-3689b313f45b`
- Gaps/Leads: `ba2caa5b-0faa-4aa3-9435-cc68f76a490e`
- MEMORY_ERRORS: none
