# ODESSA-DTS-MAP-01 — Scout-Notiz (Phase 1, Breitensuche)

- PROJECT: odessa-usbgadget
- RUN_ID: 20261106-odessa-usbgadget
- TASK_ID: ODESSA-DTS-MAP-01
- TARGET_ID: local Linux 6.12 tree `/workspace/work/odessa/mainline/linux-6.12` (read-only)
- ROLE: scout, LEAD_ID: ODESSA-DTS-MAP, MAX_CALL_DEPTH=0
- STATUS: DONE (Breitensuche), keine Gate-Entscheidung, keine Tiefenanalyse

## Auftrag / Hypothese

Welche DTS-Knoten, Compatibles, Clock-IDs, Regulator-Namen, PHY- und
Display-Definitionen existieren im lokalen 6.12-Baum fuer SM6150/SDM670/SM7150,
und welche fehlen fuer Moto G9 Plus odessa (USB, UFS, GCC, TLMM, PM6150/PM6150L,
ft8756-Panel)?

## Wichtiger Vorbefund zur Baumhygiene

Der Baum enthaelt Artefakte frueherer Laeufe: `.dtb`, `.dtb.dts.tmp`,
`.tmp_vmlinux*` und `sm6150*.dts` (unsere eigenen Dateien). Alle Suchen wurden
deshalb auf `*.dts*`/Quellpfade eingeschraenkt; `.dtb.dts.tmp`-Treffer wurden als
Build-Artefakt verworfen, `sm6150*.dts` als Eigenbau erkannt.

- `arch/arm64/boot/dts/qcom/Makefile:278` -> `dtb-$(CONFIG_ARCH_QCOM) += sm6150-moto-odessa.dtb`
  (unsere Zeile; d. h. die DTS ist hausgemacht eingetragen, kein Upstream).

## 1. Einstiegspunkte (Bestand im Baum)

| Bereich | Fundstelle | Auszug | Relevanz |
|---|---|---|---|
| GCC SDM670 Node | `sdm670.dtsi:600-601` | `gcc: clock-controller@100000 {` / `compatible = "qcom,gcc-sdm670";` | Basis fuer odessa GCC @0x100000 |
| GCC Treiber-Match | `drivers/clk/qcom/gcc-sdm845.c:3969` | `{ .compatible = "qcom,gcc-sdm670", .data = &gcc_sdm670_desc },` | SDM670 GCC wird vom SDM845-Treiber bedient |
| GCC Clock-Header | `drivers/clk/qcom/gcc-sdm845.c:16` | `#include <dt-bindings/clock/qcom,gcc-sdm845.h>` | es gibt **kein** `gcc-sdm670.h`; IDs kommen aus sdm845-Header |
| SDM670-spez. Clocks | `gcc-sdm845.c:266,272,806,817` | `ftbl_gcc_sdm670_cpuss_rbcpr_clk_src[]`, `ftbl_gcc_sdm670_sdcc4_apps_clk_src[]` | zeigt Umfang der SDM670-Abweichungen |
| TLMM Node | `sdm670.dtsi:1160-1162` | `tlmm: pinctrl@3400000 {` / `compatible = "qcom,sdm670-tlmm";` / `reg = <0 0x03400000 0 0xc00000>;` | Adresse == odessa-Stock 0x3400000 |
| TLMM gpio-range | `sdm670.dtsi:1168` | `gpio-ranges = <&tlmm 0 0 151>;` | 151 Pins (odessa-Pinzahl nicht geprueft) |
| TLMM Treiber | `drivers/pinctrl/qcom/pinctrl-sdm670.c:1328-1329` | `{ .compatible = "qcom,sdm670-tlmm", },` | Treiber vorhanden |
| USB2 HS PHY Node | `sdm670.dtsi:1302-1304` | `usb_1_hsphy: phy@88e2000 {` / `compatible = "qcom,sdm670-qusb2-phy", "qcom,qusb2-v2-phy";` / `reg = <0 0x088e2000 0 0x400>;` | Adresse == odessa QUSB2 0x88e2000 |
| QUSB2 PHY Treiber | `drivers/phy/qualcomm/phy-qcom-qusb2.c:945` | `.compatible = "qcom,qusb2-v2-phy",` | generischer Fallback bindet |
| USB-Wrapper/Core | `sdm670.dtsi:1318-1320` | `usb_1: usb@a6f8800 {` / `compatible = "qcom,sdm670-dwc3", "qcom,dwc3";` / `reg = <0 0x0a6f8800 0 0x400>;` | Wrapper == odessa 0xa6f8800 |
| USB-Clocks | `sdm670.dtsi:1326-1330` | `GCC_CFG_NOC_USB3_PRIM_AXI_CLK, GCC_USB30_PRIM_MASTER_CLK, GCC_AGGRE_USB3_PRIM_AXI_CLK, ...` | Clock-Namen `cfg_noc/core/iface/sleep/mock_utmi` |
| USB-PD/IRQ | `sdm670.dtsi:1341-1350` | `GIC_SPI 130/131`, `pdc 9/8/6`, Namen `pwr_event, hs_phy_irq, dp_hs_phy_irq, dm_hs_phy_irq, ss_phy_irq` | IRQ-Layout als Vorlage |
| USB-GDSC | `sdm670.dtsi:1352` | `power-domains = <&gcc USB30_PRIM_GDSC>;` | |
| RPMH clock ctrl | `sdm670.dtsi:1771-1772` | `rpmhcc: clock-controller {` / `compatible = "qcom,sdm670-rpmh-clk";` | |
| RPMPD | `sdm670.dtsi:1778-1779` | `rpmhpd: power-controller {` / `compatible = "qcom,sdm670-rpmhpd";` | |
| MDSS | `sdm670.dtsi:1403,1431` | `mdss: display-subsystem@ae00000` / `mdss_mdp: display-controller@ae01000` | |
| DSI0 Ctrl | `sdm670.dtsi:1496-1497` | `mdss_dsi0: dsi@ae94000 {` / `compatible = "qcom,sdm670-dsi-ctrl", ...` | |
| DSI0 PHY | `sdm670.dtsi:1551-1552` | `mdss_dsi0_phy: phy@ae94400 {` / `compatible = "qcom,dsi-phy-10nm";` | 10nm-DSI-PHY-Treiber |
| Sargo Panel | `sdm670-google-sargo.dts:452-461` | `panel@0 { compatible = "samsung,s6e3fa7-ams559nk06"; reset-gpios = <&tlmm 75 ...>; power-supply = <&vreg_l6b_3p3>;` | Muster fuer DSI-Panel-Knoten |
| Sargo USB HS PHY Supplies | `sdm670-google-sargo.dts:574-579` | `vdd-supply = <&vreg_l1b_0p925>; vdda-pll-supply = <&vreg_l10a_1p8>; vdda-phy-dpdm-supply = <&vreg_l7b_3p125>;` | exakte Supply-Namen fuer QUSB2 |
| Sargo USB Wrapper | `sdm670-google-sargo.dts:582-585` | `qcom,select-utmi-as-pipe-clk; status = "okay";` | |
| Sargo DWC3 Peripheral | `sdm670-google-sargo.dts:587-594` | `dr_mode = "peripheral"; phys = <&usb_1_hsphy>; maximum-speed = "high-speed";` | genau odessas Gadget-Bedarf (nur peripheral/HS) |
| PM660 Regulatoren | `sdm670-google-sargo.dts:184` | `compatible = "qcom,pm660-rpmh-regulators";` | PMIC-Seite des SDM670-Referenzboards |
| PM660L Regulatoren | `sdm670-google-sargo.dts:323-325` | `regulators-1 { compatible = "qcom,pm660l-rpmh-regulators"; qcom,pmic-id = "b";` | |
| PM6150 Regulatoren (Fremd-SoC) | `sc7180-trogdor.dtsi:440-442` | `regulators-0 { compatible = "qcom,pm6150-rpmh-regulators"; qcom,pmic-id = "a";` | einzige PM6150-Regulator-Definition im Baum |
| PM6150 USB/UFS-LDO-Namen | `sc7180-trogdor.dtsi:451-467` | `vdd_qusb_hs0_core:` / `vdd_ufs1_core:` / `pp900_l4a: ldo4 { regulator-min-microvolt = <824000>; ... <928000>; }` | konkrete PM6150-LDO-Zuordnung fuer USB/UFS |
| PM6150L Regulatoren | `sc7180-trogdor.dtsi:556` | `compatible = "qcom,pm6150l-rpmh-regulators";` | |
| PM6150 PMIC-DTS | `pm6150.dtsi:36-39` | `&spmi_bus { pm6150_lsid0: pmic@0 { compatible = "qcom,pm6150", "qcom,spmi-pmic"; reg = <0x0 SPMI_USID>;` | Upstream-Datei vorhanden (BSD-3, (c) 2019 LF) |
| PM6150L PMIC-DTS | `pm6150l.dtsi:38-41` | `pm6150l_lsid4: pmic@4 { compatible = "qcom,pm6150l", "qcom,spmi-pmic"; reg = <0x4 SPMI_USID>;` | dito |
| RPMH-Regulator-Daten | `drivers/regulator/qcom-rpmh-regulator.c:1271,1299,1630,1634` | `pm6150_vreg_data[]`, `pm6150l_vreg_data[]`, `.compatible = "qcom,pm6150-rpmh-regulators"` / `...pm6150l...` | PM6150/PM6150L regulatorisch unterstuetzt |
| RPMH-Regulator-Daten PM660 | `qcom-rpmh-regulator.c:1490,1519,1682,1686` | `pm660_vreg_data[]`, `pm660l_vreg_data[]` + Compatibles | Referenz fuer SDM670 |
| UFS-Template (fehlt bei sdm670) | `sm8250.dtsi:2495-2498` | `ufs_mem_hc: ufshc@1d84000 {` / `compatible = "qcom,sm8250-ufshc", "qcom,ufshc", "jedec,ufs-2.0";` / `reg = <0 0x01d84000 0 0x3000>;` | Adresse == odessa UFS; gleiche SoC-Generation |
| UFS-Host-Treiber | `drivers/ufs/host/ufs-qcom.c:1853` | `{ .compatible = "qcom,ufshc" },` | generischer Fallback |
| UFS-QMP-PHY | `drivers/phy/qualcomm/phy-qcom-qmp-ufs.c:2047` | `.compatible = "qcom,sm8250-qmp-ufs-phy",` | kein SM6150-Eintrag |
| DSI-Panel-Treiber | `drivers/gpu/drm/panel/` | kein ft8756-Treffer (siehe leere Suchen) | |

## 2. Verfuegbare dt-bindings-Header (Auswahl, geprueft vorhanden)

- `include/dt-bindings/clock/qcom,gcc-sdm845.h` (von sdm670.dtsi:10 genutzt; GCC_USB_PHY_CFG_AHB2PHY_CLK=161)
- `include/dt-bindings/clock/qcom,dispcc-sdm845.h` (sdm670.dtsi:9)
- `include/dt-bindings/clock/qcom,rpmh.h` (sdm670.dtsi:11)
- `include/dt-bindings/clock/qcom,sm7150-gcc.h` (vorhanden, aber ohne passende sm7150-SoC-DTS)
- `include/dt-bindings/interconnect/qcom,sdm670-rpmh.h` (MASTER_UFS_MEM=6, SLAVE_...)
- `include/dt-bindings/phy/phy-qcom-qusb2.h`, `include/dt-bindings/phy/phy-qcom-qmp.h`
- `include/dt-bindings/regulator/qcom,rpmh-regulator.h`, `include/dt-bindings/power/qcom-rpmpd.h`
- `Documentation/devicetree/bindings/clock/qcom,gcc-sdm845.yaml:22,46` listet `qcom,gcc-sdm670`

## 3. Gap-Liste (odessa-spezifisch fehlend)

1. **Kein upstream SM6150/SDMMAGPIE**: `sm6150.dtsi` im Baum ist unsere Minimaldatei
   (nur cpus/psci/gic/timer/memory/ramoops/framebuffer, vgl. Grep: nur
   `arm,cortex-a55`, `arm,cortex-a76`, `arm,psci-1.0`, `arm,gic-v3`,
   `arm,armv8-timer`). Kein `qcom,sm6150*`-Compatible ausser in unseren Dateien.
2. **Kein GCC-SM6150**: weder `dt-bindings/clock/qcom,gcc-sm6150.h` noch
   `drivers/clk/qcom/gcc-sm6150.c`; kein `qcom,gcc-sm6150`-Compatible im Baum.
3. **Kein TLMM-SM6150**: nur `pinctrl-sdm670.c` und `pinctrl-sm7150.c`;
   `sm7150_tlmm_of_match` kennt ausschliesslich `qcom,sm7150-tlmm`.
4. **Kein UFS in `sdm670.dtsi`**: `ufs|ufshc|ice|ufs_mem` = 0 Treffer in
   `sdm670*.dts*`. UFS-Node + UFS-PHY + ICE muessen aus sm8250/sdm845 uebernommen
   werden; ICE-Node (`qcom,ice`) in sdm670 fehlt ebenfalls.
5. **Kein USB3-QMP-PHY in `sdm670.dtsi`**: sargo nutzt nur `usb_1_hsphy` +
   `maximum-speed = "high-speed"`; kein `usb_1_qmpphy`/`qcom,qmp-usb3-dp-phy`.
6. **Kein ft8756**: `ft8756` = 0 Treffer im gesamten Baum (Treiber, Binding, DTS).
   Panel `dsi_ft8756_txd_vid_display` (1080x2400, video mode) hat keine Mainline-
   Entsprechung.
7. **Keine odessa-Board-DTS**: nur unsere `sm6150-moto-odessa.dts` (+ dtbo0-Varianten).
8. **Kein SM7150-SoC-DTS**, obwohl Treiber/Bindings existieren
   (`gcc-sm7150.c`, `pinctrl-sm7150.c`, `qcom,sm7150-gcc.h`); `sm7125.dtsi` ist nur
   `#include "sc7180.dtsi"` + Kryo-465-Overrides.
9. **Kein SM6150-Interconnect**: nur `qcom,sdm670-rpmh.h`; SM6150-BW-Tabellen fehlen.
10. **PM6150/PM6150L-Regulator-Knoten** existieren nur im sc7180-trogdor-Kontext
    (PMIC-ID "a" bzw. "b"), nicht fuer SM6150-RPMh-Slots.

## 4. Leere Suchen (tatsaechlich ausgefuehrt)

- `rg -n "ft8756" /workspace/work/odessa/mainline/linux-6.12` -> 0 Treffer (gesamter Baum).
- `rg -n "sm6150|sdmmagpie" Documentation/devicetree/bindings` -> 0 Treffer.
- `rg -n "sm6150|sdmmagpie" drivers` -> 0 Treffer.
- `rg -n "ufs|ufshc|ice@|crypto" arch/arm64/boot/dts/qcom/sdm670*.dts*` -> 0 Treffer.
- `rg -n "qcom,pm660l-rpmh-regulators" *.dts*` -> nur `sdm670-google-sargo.dts:324` (+ Build-Artefakt).
- `rg -n "GCC_USB_PHY_CFG_AHB2PHY_CLK" include/dt-bindings/clock/qcom,gcc-*.h` ->
  Treffer nur in msm8998/sdx55/sdx65/msm8996/sdm845/sdm660/msm8994/sc7180,
  **nicht** in einem sdm670/sm6150-spezifischen Header (existiert nicht).

## 5. Grenzen

- Nur gelesen, nichts geaendert, keine Call-Ketten, keine Treiberlogik.
- Pinzahl/Funktionsliste von SM6150-TLMM nicht geprueft (kein sm6150-pinctrl im Baum).
- Ob `qcom,sdm670-qusb2-phy` oder nur der Fallback `qcom,qusb2-v2-phy` bindet,
  wurde nicht verifiziert (Treiber-Match-Tabelle nur teilweise gelesen).
- RPMh-Slave-/VRM-IDs der PM6150-Regulatoren fuer SM6150 nicht geprueft.
- Treffer in `.dtb.dts.tmp`/`.tmp_vmlinux*` sind Build-Artefakte und wurden nicht
  als Quellbelege verwendet.

## 6. Memory-Referenzen (Scratchboard)

- Plan: `d862c190-af6c-4a6c-a42c-d85d98f8adf0` (part_of_run -> `7846c605-...`)
- Finding-1 (Baumhygiene/PM6150 vorhanden): `b0091b61-a89f-4fe1-bc9c-845da115f95c`
- Finding-2 (SoC-Seite SDM670/USB/TLMM/GCC/DSI): `d24553f6-d8b6-4e8a-b094-56960cb5ce81`
- Finding-3 (PM6150/PM6150L/PM660 Regulatoren): `172ad0cd-bd3d-4517-b23b-3efc0bf23d3b`
- Gaps: `1e8865aa-959b-4bdc-b4e6-88aa11470598`
- MEMORY_ERRORS: none
