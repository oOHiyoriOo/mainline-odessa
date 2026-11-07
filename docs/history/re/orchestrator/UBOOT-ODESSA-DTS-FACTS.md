# U-Boot odessa DTS — bestätigte Fakten und offene Punkte

PROJECT=odessa-usbgadget
RUN_ID=20261106-odessa-usbgadget
TASK_ID=UBOOT-ODESSA-DTS-FACTS
ROLE=orchestrator
Stand: 2026-11-06
Status: Faktensammlung für die Synthese; Quelle U-Boot v2026.10.

---

## 1. Bestätigte Basis

- U-Boot v2026.10, Commit `5508406582f6f7120dce0c4b3059819a41788db2`.
- `dts/upstream/src/arm64/qcom/talos.dtsi` ist die **QCS615/SM6150-SoC-DTS**.
- `qcs615-ride.dts`:
  `compatible = "qcom,qcs615-ride", "qcom,qcs615", "qcom,sm6150"` —
  QCS615 ist SM6150-Familie. Board-Referenz inkl.
  `talos.dtsi` + `pm8150.dtsi`.
- Für odessa: `talos.dtsi` + `pm6150.dtsi` + `pm6150l.dtsi` einbinden,
  Memory/Chosen/Aliases/USB/Pinctrl überschreiben.

## 2. Odessa-spezifische Fakten (Evidence Gate)

- **Memory:** `<0x0 0x80000000 0x0 0x80000000>` und
  `<0x0 0x100000000 0x0 0x7dd00000>` (aus ABL-DTB).
- **Board-ID:** `<0x49 0xc000>`; **MSM-ID:** `<0x16d 0x0>`; Modell
  `odessa`.
- **UART-Konsole:** `talos.dtsi` `uart6: serial@a88000`,
  `compatible = "qcom,geni-uart"`,
  `clocks = <&gcc GCC_QUPV3_WRAP1_S2_CLK>`.
  Stock-Pins: GPIO44/45, Stock-Funktion `qup12`.
  U-Boot-`pinctrl-qcs615` verwendet `qup0`/`qup1`; exaktes Mapping offen.
- **Display:** `simple-framebuffer` bei `0x9c000000`, 1080×2400,
  stride 4320, `a8r8g8b8` (aus dem minimalen odessa-DTB).
- **USB:** `talos.dtsi` QUSB2 (`qcom,qcs615-qusb2-phy`) + DWC3
  (`qcom,dwc3`); peripheral/high-speed; PM6150-Rails oder
  Fixed-Regulatoren.
- **GCC:** `talos.dtsi` `qcom,qcs615-gcc` bei `0x100000`.
- **TLMM:** `talos.dtsi` `qcom,qcs615-tlmm` bei `0x3400000`.
- **PMIC:** `pm6150.dtsi`/`pm6150l.dtsi` sind im U-Boot-`dts/upstream`
  vorhanden.
- **U-Boot-Config:** `qcom_defconfig` hat
  `CONFIG_POSITION_INDEPENDENT=y`, `CONFIG_VIDEO=y`,
  `CONFIG_VIDEO_SIMPLE=y`, `CONFIG_CLK_QCOM_QCS615=y`,
  `CONFIG_PHY_QCOM_QUSB2=y`, `CONFIG_USB_DWC3_GENERIC=y`.
- **QCS615-Defconfig:** `TEXT_BASE=0x9fc00000`,
  `DEBUG_UART_BASE=0x880000`, `DEBUG_UART_CLOCK=7372800`,
  `DEFAULT_DEVICE_TREE="qcom/qcs615-ride"`, `WATCHDOG_AUTOSTART=y`.
- **Image-Header:** `CONFIG_LINUX_KERNEL_IMAGE_HEADER` existiert für
  ARM64 (`arch/arm/Kconfig:94`); Felder `text_offset`/`image_size` und
  ABL-Sprungziel noch zu belegen.

## 3. ABL-/FIT-Fakten

- FIT/Ramdisk-Ladeadresse: **`0x85367000`**
  (`/proc/device-tree/chosen/linux,initrd-start` im laufenden
  4.14-Rescue; Ende `0x856fe6a2`).
- FIT-Ladeadressen: Kernel `0x90000000`, FDT `0x8F000000`, Ramdisk
  `0xA0000000`.
- `boot.img` v2, Page 4096, leere Header-Cmdline; Stock-DTB als
  Bootloader-DTB; FIT als Ramdisk.
- `dtbo_a` ist nicht Stock; `dtbo_b` = `stock_dtbo.img`.

## 4. Offene Punkte (Scout `UBOOT-QCS615-MAP-01`)

- **Pinctrl GPIO44/45:** Welche Funktion (`qup0`/`qup1`/…) und welcher
  Pin-Deskriptor in `pinctrl-qcs615.c`? Wie wird der DTS-String gemappt?
- **Image-Header:** `text_offset`/`image_size` in
  `arch/arm/cpu/armv8/start.S`/`u-boot.lds`; lädt ABL bei `0x80000000`
  oder `0x80008000`?
- **Video-Konsole:** Reicht `CONFIG_VIDEO_SIMPLE=y`, oder braucht es
  `CONFIG_CONSOLE_MUX=y` + `stdout=serial,vidconsole`? Wird
  `simple-framebuffer` unter `chosen` oder am Root erwartet?
- **USB:** QUSB2-Supplies (`vdd`, `vdda-pll`, `vdda-phy-dpdm`) —
  PM6150-Rails oder Fixed-Regulatoren? Welche `dr_mode`/`maximum-speed`?
- **UFS:** Gibt es in `talos.dtsi` einen UFS-Knoten? (Für den ersten
  Test nicht nötig.)
- **Watchdog:** `WATCHDOG_AUTOSTART` für den ersten Test wirklich
  abschalten?
- **Board-ID:** Muss der U-Boot-DTS `qcom,board-id`/`qcom,msm-id`
  enthalten? (ABL wertet sie für das Boot.img-DTB aus; U-Boot selbst
  braucht sie nicht.)

## 5. Nächste Synthese

`qcom/qcs615-odessa.dts` + `qcs615-odessa-u-boot.dtsi` (Memory) +
`configs/qcom_qcs615_odessa_defconfig`. Danach Build, FIT, `boot.img`,
`fastboot boot`. Keine Persistenz im ersten Test.
