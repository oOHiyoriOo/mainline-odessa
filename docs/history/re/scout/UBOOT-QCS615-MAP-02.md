# Scout UBOOT-QCS615-MAP-02 — U-Boot v2026.10 QCS615/SM6150 entry points

PROJECT=odessa-usbgadget
RUN_ID=20261106-odessa-usbgadget
TASK_ID=UBOOT-QCS615-MAP-02
TARGET_ID=read-only U-Boot v2026.10 copy at /workspace/work/odessa/.re/uboot/src
(commit 5508406582f6f7120dce0c4b3059819a41788db2)
ROLE=scout, PHASE=1, LEAD_ID=UBOOT-QCS615-MAP, MAX_CALL_DEPTH=0
Status: SUCHLAUF ABGESCHLOSSEN (Budget ~40 Treffer erreicht). Alle Angaben sind
Suchtreffer/Einstiegspunkte, keine Evidence-Gate-Entscheidung.

Scope: ausschliesslich obiger Pfad + stock-base.dts + orchestrator-FAKTEN-Datei.
Keine Shell, keine Builds, keine Remote-Zugriffe.
Vorgaenger UBOOT-QCS615-MAP-01 war an `external_directory` gesperrt; dieser
Lauf nutzt die In-Workspace-Kopie und war vollstaendig lesbar.

## 1. Einstiegspunkte — talos.dtsi
`dts/upstream/src/arm64/qcom/talos.dtsi`

| Anker | file:line | Auszug |
|---|---|---|
| memory | 465-469 | `memory@80000000 { device_type = "memory"; reg = <0 0x80000000 0 0>; }` — Groesse 0, "bootloader to fill in" |
| gcc | 669-671 | `gcc: clock-controller@100000 { compatible = "qcom,qcs615-gcc"; reg = <0 0x100000 0 0x1f0000>;` |
| qupv3_0 / uart0 | 786, 799-803 | `qupv3_id_0: geniqup@8c0000`, `uart0: serial@880000 { compatible = "qcom,geni-debug-uart"; ... clocks = <&gcc GCC_QUPV3_WRAP0_S0_CLK>;` |
| qupv3_1 | 966-977 | `qupv3_id_1: geniqup@ac0000 { compatible = "qcom,geni-se-qup"; reg = <0 0xac0000 0 0x2000>; ... status = "disabled";` |
| uart6 | 1133-1150 | `uart6: serial@a88000 { compatible = "qcom,geni-uart"; reg = <0 0xa88000 0 0x4000>; clocks = <&gcc GCC_QUPV3_WRAP1_S2_CLK>; clock-names = "se"; pinctrl-0 = <&qup_uart6_cts>,<&qup_uart6_rts>,<&qup_uart6_tx>,<&qup_uart6_rx>; ... status = "disabled";` |
| uart6 pins | 1759-1777 | `qup_uart6_tx: ... pins = "gpio8"; function = "qup1";` (rx gpio9, cts gpio6, rts gpio7) |
| tlmm | 1553-1567 | `tlmm: pinctrl@3100000 { compatible = "qcom,qcs615-tlmm"; reg = <0 0x3100000 0 0x300000>, <0 0x3500000 ...>, <0 0x3d00000 ...>; gpio-ranges = <&tlmm 0 0 124>;` |
| UFS | 1406-1411 | `ufs_mem_hc: ufshc@1d84000 { compatible = "qcom,qcs615-ufshc", "qcom,ufshc", "jedec,ufs-2.0"; reg std + ice` |
| UFS PHY | 1498 | `ufs_mem_phy: phy@1d87000` |
| RSC | 4758 | `apps_rsc: rsc@18200000` |
| rpmhcc | 4785-4790 | `rpmhcc: clock-controller { compatible = "qcom,qcs615-rpmh-clk"; clocks = <&xo_board_clk>; }` |
| rpmhpd | 4793-4796 | `rpmhpd: power-controller { compatible = "qcom,qcs615-rpmhpd"; ... }` |
| QUSB2 prim | 4854-4866 | `usb_1_hsphy: phy@88e2000 { compatible = "qcom,qcs615-qusb2-phy"; reg = 0x180; clocks = "cfg_ahb","ref"; resets = <&gcc GCC_QUSB2PHY_PRIM_BCR>; nvmem-cells = <&qusb2_hstx_trim>;` |
| USB wrapper | 4938-4977 | `usb_1: usb@a600000 { compatible = "qcom,qcs615-dwc3", "qcom,snps-dwc3"; reg = <0 0xa600000 0 0xfc100>; phys = <&usb_1_hsphy>, <&usb_qmpphy>; power-domains = <&gcc USB30_PRIM_GDSC>;` |
| reserved-memory | 623-660 | nur aop-cmd-db@85f20000, smem@86000000, pil-video/cdsp/adsp/gpu — **kein** framebuffer-/ramoops-Knoten |
| mdss | 4252, 4427, 4492 | `mdss: display-subsystem@ae00000` `qcom,sm6150-mdss`; `mdss_dsi0: dsi@ae94000`; `mdss_dsi0_phy: phy@ae94400` (fuer simplefb nicht noetig) |

KORREKTUR zum Orchestrator-Kontext: TLMM sitzt bei **0x3100000** (drei Regionen
east/west/south), nicht 0x3400000.

## 2. Einstiegspunkte — qcs615-ride.dts
`dts/upstream/src/arm64/qcom/qcs615-ride.dts`

- 11: `#include "pm8150.dtsi"` (nicht pm6150!)
- 14: `compatible = "qcom,qcs615-ride","qcom,qcs615","qcom,sm6150"`
- 17-22: `aliases { mmc0=sdhc_1; mmc1=sdhc_2; serial0=uart0; serial1=uart7; }`
- 24-26: `chosen { stdout-path = "serial0:115200n8"; }` — **kein /memory-Node**
- 190-193: `&apps_rsc { regulators-0 { compatible = "qcom,pm8150-rpmh-regulators"; qcom,pmic-id = "a";`
- 617-623: `&usb_1_hsphy { vdd-supply = <&vreg_l5a>; vdda-pll-supply = <&vreg_l12a>; vdda-phy-dpdm-supply = <&vreg_l13a>; status="okay"; }`
- 639-643: `&usb_1 { dr_mode = "peripheral"; status = "okay"; }`
- 659-674: `&ufs_mem_hc { reset-gpios = <&tlmm 123 GPIO_ACTIVE_LOW>; vcc-supply = <&vreg_l17a>; vccq2-supply = <&vreg_s4a>; }`, `&ufs_mem_phy { vdda-phy/vdda-pll }`
- 501-507: `&qupv3_id_0/1 { status = "okay"; }`

## 3. Defconfigs
`configs/qcom_defconfig` (155 Zeilen): 3 POSITION_INDEPENDENT=y · 5 ARCH_SNAPDRAGON=y ·
6 NR_DRAM_BANKS=24 · 14 FIT=y · 16 BOOTSTD_FULL=y · 19 OF_BOARD_SETUP=y ·
21 SAVE_PREV_BL_INITRAMFS_START_ADDR=y · 54-55 ENV_USE_DEFAULT_ENV_TEXT_FILE +
"board/qualcomm/default.env" · 64 CLK_QCOM_QCS615 · 101 QCOM_GENI · 115 PHY_QCOM_QUSB2 ·
126 DM_REGULATOR_QCOM_RPMH · 130-131 MSM_SERIAL/MSM_GENI_SERIAL · 143 USB_DWC3_GENERIC ·
144 USB_GADGET · 145-146 UFS/UFS_QCOM · 147 VIDEO · 152 VIDEO_SIMPLE · 153-154 WDT/WDT_QCOM.
NICHT enthalten (auch nicht noetig, per select/default): CONSOLE_MUX, SYS_CONSOLE_IS_IN_ENV,
LINUX_KERNEL_IMAGE_HEADER, CMD_BOOTM, BOOTCOMMAND, BINMAN, USB_TTY.

`configs/qcom_qcs615_defconfig` (26 Zeilen): 6 include qcom_defconfig · 11 DEBUG_UART=y ·
13 `DEBUG_UART_BASE=0x880000` (uart0!) · 14 DEBUG_UART_MSM_GENI · 15 DEBUG_UART_CLOCK=7372800 ·
17 `DEFAULT_DEVICE_TREE="qcom/qcs615-ride"` · 19 REMAKE_ELF=y · 22 `TEXT_BASE=0x9fc00000` ·
24 FASTBOOT_BUF_ADDR=0xa1600000 · 26 WATCHDOG_AUTOSTART=y.

## 4. Treiber
- `drivers/clk/qcom/clock-qcs615.c`: 34-39 WRAP1 S0..S5 Enable-Bits; 128-133
  `GATE_CLK(GCC_QUPV3_WRAP1_S2_CLK, 0x5200c, BIT(24))`; 212-223 of_match
  `qcom,qcs615-gcc`; set_rate (68-110) behandelt nur USB/UFS/SDCC — **kein UART-Rate-Setup**.
- `drivers/pinctrl/qcom/pinctrl-qcs615.c`: 57-134 Funktions-Enum, nur `msm_mux_qup0`
  (116) und `msm_mux_qup1` (117); 136-137 `MSM_PIN_FUNCTION(fname) = {#fname, ...}` →
  DTS-String ist exakt der Enum-Name. 263-264: `[44] = PINGROUP(44, qspi, _, phase_flag,
  qdss_gpio, ...)`, `[45] = PINGROUP(45, qspi, _, phase_flag, qdss_gpio, ...)`.
  ⇒ **"qup12" existiert nicht, GPIO44/45 haben keinen QUP-Mux**.
- `drivers/serial/serial_msm_geni.c`: 582-584 ids `qcom,geni-debug-uart`, `qcom,geni-uart`;
  461-465 Parent **muss** `qcom,geni-se-qup` sein; 550-552 `qcom,geni-uart` → `return -ENOENT`
  ("Don't actually probe non-debug UARTs"); 444-461 nur `cfg_ahb`-Clock.
- `drivers/phy/qcom/phy-qcom-qusb2.c`: 500-510 ids inkl. `qcom,qcs615-qusb2-phy`;
  205-217 qcs615_init_tbl; 444-461 **keine** Regulatoren, ref-Clock wird ignoriert;
  479-483 reset index 0 ist Pflicht.
- `drivers/usb/dwc3/dwc3-generic.c`: 756-757 `{qcom,dwc3 → qcom_ops}`,
  `{qcom,snps-dwc3 → qcom_flat_dt_ops}`; 467 `SDM845_QSCRATCH_BASE_OFFSET 0xf8800`;
  512-513 Offset nur bei `qcom,snps-dwc3` → 0xa600000+0xf8800 = 0xa6f8800;
  629-636 Reset-Assert nur bei `qcom,dwc3`; 200-207 dr_mode-Fallback OTG.
- `drivers/ufs/ufs-qcom.c`: 682 `{ .compatible = "qcom,ufshc" }`.
- `drivers/power/regulator/qcom-rpmh-regulator.c`: 633 `pm6150l_vreg_data`,
  679 `pm8150_vreg_data`, 711 `pm8150l_vreg_data`; ids 976-1018 enthalten
  `qcom,pm6150l-rpmh-regulators` (978) — **kein `qcom,pm6150-rpmh-regulators`**.
- `drivers/video/simplefb.c`: 106 `{ .compatible = "simple-framebuffer" }`;
  27-31 `memory-region`-Phandle ODER direktes `reg`; 59-73 width/height/stride;
  83-96 Formatliste inkl. `a8r8g8b8` → `VIDEO_X8R8G8B8`; 48-53 mmu_map_region.
- `drivers/video/Kconfig`: 7 `config VIDEO depends on DM`; 994 `config VIDEO_SIMPLE`.
  `common/Kconfig`: 259-268 `CONFIG_CONSOLE_MUX default y if VIDEO || LCD`;
  270-278 `SYS_CONSOLE_IS_IN_ENV default y if CONSOLE_MUX` (stdout "serial,vidconsole").
  `drivers/video/video-uclass.c`: 683-699 legt immer ein vidconsole-Kind an.
- `board/qualcomm/default.env`: 2-3 `stdout=serial,vidconsole`; 11 `bootcmd=run do_boot`
  (→ `bootefi bootmgr`). `board/qualcomm/qcom-phone.env`: 15-19 `serial_gadget`
  mit `usbacm`; 24 bootcmd `bootefi bootmgr; pause; run menucmd`.
  `board/qualcomm/qcom-phone.config`: 2 qcom-phone.env, 14 USB_FUNCTION_ACM,
  19-22 CONSOLE_RECORD + FASTBOOT_CMD_OEM_CONSOLE, 30 REQUIRE_SERIAL_CONSOLE not set.

## 5. Image-Header / Load / Boot-Flow
- `arch/arm/cpu/armv8/start.S`: 21-22 `#if defined(CONFIG_LINUX_KERNEL_IMAGE_HEADER)`
  `#include <asm/boot0-linux-kernel-header.h>`; 36-38 `_TEXT_BASE: .quad CONFIG_TEXT_BASE`.
- `arch/arm/include/asm/boot0-linux-kernel-header.h`: 37-46 `b reset` (code0) + `text_offset`
  (`_kernel_offset_le`) + `image_size` (`_kernel_size_le`) + `flags_le` + `"ARM\x64"`.
- `arch/arm/cpu/armv8/linux-kernel-image-header-vars.h`: 72-73
  `TEXT_OFFSET = CONFIG_TEXT_BASE - CONFIG_LNX_KRNL_IMG_TEXT_OFFSET_BASE`;
  80-83 `_kernel_size_le = __MEM_USAGE`, `_kernel_offset_le = TEXT_OFFSET`,
  `_kernel_flags_le = __HEAD_FLAGS` (BE=0, page 4K, phys_base=1).
- `arch/arm/mach-snapdragon/Kconfig`: 26-27 `LNX_KRNL_IMG_TEXT_OFFSET_BASE default 0x80000000`
  ⇒ text_offset = 0x9fc00000-0x80000000 = **0x1fc00000** (mit qcs615 TEXT_BASE).
- `arch/arm/Kconfig`: 94-102 `LINUX_KERNEL_IMAGE_HEADER depends on ARM64`;
  1151 `ARCH_SNAPDRAGON select LINUX_KERNEL_IMAGE_HEADER if !ENABLE_ARM_SOC_BOOT0_HOOK`
  (also automatisch, kein Defconfig-Symbol).
- `arch/arm/cpu/armv8/u-boot.lds`: 175-177 Header-Variablen am Skriptende; 15 ENTRY(_start).
- `arch/arm/mach-snapdragon/board.c`: 207-258 `board_fdt_blob_setup()` — internes FDT
  bevorzugt, wenn valides `/memory`; sonst Speicher aus ABL-FDT; 76-88 dram_banks;
  252-258 internes FDT gewinnt (`-EEXIST`), ABL-FDT nur Fallback.
- `cmd/Kconfig`: 309-313 `CMD_BOOTM` default y (bootm auf FIT@0x85367000 ohne Zusatzsymbol).
- `dts/Makefile`: 13-25 OF_UPSTREAM → `dts/upstream/src/arm64`; 36
  `DTB := $(dt_dir)/$(DEVICE_TREE).dtb` ⇒ neues Board-DTS muss unter
  `dts/upstream/src/arm64/qcom/` liegen und via DEFAULT_DEVICE_TREE gewaehlt werden.

## 6. GAP-Liste odessa
1. **Pinctrl GPIO44/45**: U-Boot-Tabelle hat fuer Pin 44/45 nur qspi/phase_flag/qdss_gpio/gpio;
   Funktion `qup12` (Stock-Funktion) fehlt. Optionen: (a) `pinctrl-0` im Console-Node weglassen
   und ABL-Padzustand nutzen (UNVERIFIED, ob ABL die Pads mux't), (b) pinctrl-qcs615.c um
   QUP12-Mux fuer 44/45 erweitern, (c) anderen UART mit vorhandenen Pins waehlen.
2. **PM6150 vs PM8150**: qcs615-ride nutzt pm8150; odessa PM6150/PM6150L. U-Boot kennt
   `pm6150l`- und `pm8150`-RPMh-Daten, aber **keine `qcom,pm6150-rpmh-regulators`**.
   Fuer den ersten Test reichen Fixed-Regulatoren bzw. gar keine (QUSB2 braucht keine Supplies).
3. **DEBUG_UART_BASE**: 0x880000 ist uart0 (Wrap0/SE0). Fuer odessa 0xa88000 (uart6) noetig;
   DEBUG_UART_CLOCK=7372800 ungeprueft fuer GCC_QUPV3_WRAP1_S2_CLK.
4. **uart6-Binding**: talos.dtsi-Node ist `qcom,geni-uart` → Probe endet mit -ENOENT.
   Odessa-DTS muss `qcom,geni-debug-uart` setzen (Override), sonst keine DM-Konsole.
5. **qupv3_id_1** ist disabled → muss im Board-DTS auf okay.
6. **/memory**: talos.dtsi `reg = <0 0x80000000 0 0>`; odessa braucht die zwei Baenke,
   sonst nimmt board.c den ABL-FDT (funktioniert, aber unkontrolliert).
7. **Display/Panel ft8756**: kein Panel-Treiber noetig; simplefb deckt den Framebuffer
   (0x9c000000, 1080x2400, stride 4320, a8r8g8b8) — `memory-region` oder `reg` + Format.
8. **UFS**: Knoten + `qcom,ufshc`-Treiber + PHY_QCOM_QMP_UFS vorhanden, aber `vcc/vccq2`
   brauchen RPMh-Rails (PM6150-Luecke) und `reset-gpios`; fuer Stufe 1 nicht erforderlich.
9. **Watchdog**: `WATCHDOG_AUTOSTART=y` startet QCOM-WDT; fuer den ersten Boot abschalten
   oder Petting verifizieren (Reset-Risiko).
10. **Board-ID/MSM-ID**: fuer U-Boot-DTS nicht erforderlich (board_fdt_blob_setup wertet sie
    nicht aus); ABL wertet sie fuer das Boot.img-DTB.
11. Kein odessa-Board, kein `qcom/qcs615-odessa.dts`; talos-evk/talos-ride vorhanden.
12. Klein: Orchestrator-Kontext nennt TLMM 0x3400000 — real 0x3100000.

## 7. Grenzen dieses Laufs
- Baum ist eine **prune-/Teilkopie**: `drivers/regulator/` fehlt ( Treiber liegen unter
  `drivers/power/regulator/`), `dts/upstream/src/arm64/qcom/Makefile` fehlt. Ob ein neues
  Board-DTS zusaetzlich in eine Makefile-Liste muss, konnte daher nicht geprueft werden.
- Budget erreicht (~40 Treffer). NICHT gelesen: `arch/arm/mach-snapdragon/of_fixup.c`,
  `drivers/watchdog/qcom-wdt.c`, `drivers/ufs/ufs-qcom.c` (nur match-Zeile),
  `include/configs/qcom.h`, `doc/board/qualcomm/*`, `drivers/power/regulator` Details,
  `arch/arm/cpu/armv8/relocate_64.S` (PIE-Mechanik).
- Keine Aussage ueber ABL-Ladeadresse (0x80000000 vs 0x80008000) — nicht im Baum.
- Alle Zeilen sind Suchtreffer, kein Evidence Gate.
