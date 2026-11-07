# U-Boot-Chainload — Plan und belegte Fakten

PROJECT=odessa-usbgadget
RUN_ID=20261106-odessa-usbgadget
TARGET_ID=Moto G9 Plus „odessa“ (XT2087-2), SM6150/SDMMAGPIE,
S/N ZY227VHMSS, Bootloader MBM-3.0-odessa_retail-e69c40c38d6-220818
ROLE=orchestrator
Stand: 2026-11-06 (UTC)
Status: Tool-Readiness (`UBOOT-TOOLS-01`) läuft; Plan/Evidence fixiert.

---

## 1. Ziel

Einen **aktuellen Mainline-Linux-Kernel (6.12+)** auf dem odessa booten,
ohne die ABL-Einschränkungen (DTBO-AVB, `boota (786)`, Boot.img-DTB-Zwang)
zu umgehen, indem **U-Boot als zweite Bootstufe** in ein `boot.img` v2
gepackt wird. U-Boot lädt anschließend einen FIT mit eigenem Kernel, eigenem
DTB und Initramfs.

Abnahmekriterien für die erste U-Boot-Stufe:

1. U-Boot startet per `fastboot boot` (RAM only, nichts persistent geflasht).
2. U-Boot hat eine sichtbare Konsole (Display-`simplefb`; UART/USB-TTY als
   Fallback) und meldet sich.
3. U-Boot lädt den FIT und bootet den 6.12-Kernel bis `/init`.
4. Der 6.12-Kernel liefert pstore/ramoops oder eine sichtbare Konsole.
5. Rollback: `fastboot boot` des 4.14-Rescue-Images; `dtbo_a` bleibt
   unverändert (bzw. wird nach dem Test aus `stock_dtbo.img` restauriert).

Nicht Teil der ersten Stufe: vollständige Mainline-Hardware (USB/UFS/Display
im Linux-Kernel), Kamera, Cellular.

---

## 2. Architektur

```
ABL
 └─ boot.img v2 (fastboot boot)
     ├─ kernel  = u-boot.bin (arm64, Linux-Image-Header, position-independent)
     ├─ dtb     = Stock-DTB (nur für ABL/U-Boot-Start)
     └─ ramdisk = FIT (mainline Image.gz + odessa-DTB + Initramfs)
          │
          ▼
       U-Boot (eigene Konsole: simplefb / UART / USB-TTY)
          │  bootm 0x85367000
          ▼
       FIT-Komponenten
         ├─ kernel  -> 0x90000000
         ├─ fdt     -> 0x8F000000
         └─ ramdisk -> 0xA0000000
          │
          ▼
       Linux 6.12 -> /init
```

**Warum dieser Weg:** ABL verifiziert `dtbo_a` per AVB und löscht bei
Hash-Mismatch die Partition. Ein eigenes DTBO ist ohne Motorola-Signatur
nicht flashbar. U-Boot umgeht ABLs DTBO-/`boota`-Pfad vollständig und kann
ein beliebiges, selbstgebautes DTB an den Kernel übergeben.

---

## 3. Belegte Fakten (Evidence Gate)

### F1 — ABL lädt die Ramdisk (und damit den FIT) nach `0x85367000`

Quelle: laufender 4.14-Rescue, gebootet per `fastboot boot`
(`test-boot-414190-pstore-ro.img`), 2026-11-06.

```
/proc/device-tree/chosen/linux,initrd-start
00 00 00 00 85 36 70 00        -> 0x0000000085367000

/proc/device-tree/chosen/linux,initrd-end
00 00 00 00 85 6f e6 a2        -> 0x00000000856fe6a2
```

Differenz = `0x3976a2` = 3.767.970 B; der 6.12-Log meldete
`Freeing initrd memory: 3676K` — konsistent. **Der FIT muss an
`0x85367000` erwartet werden**, nicht an der Header-`ramdisk_addr`
(`0x1000000`).

### F2 — Von ABL gesetzte Speicherregionen

```
/proc/device-tree/memory/reg
00 00 00 00 80 00 00 00  00 00 00 00 80 00 00 00
00 00 00 01 00 00 00 00  00 00 00 00 7d d0 00 00
```

Mit `#address-cells=<2>`, `#size-cells=<2>`:

- Region 1: `0x0000000080000000`, Größe `0x0000000080000000` (2 GiB)
- Region 2: `0x0000000100000000`, Größe `0x000000007dd00000` (~2,06 GiB)
- Gesamt: `0x00000000fdd00000` = 4.258.267.136 B (~4,06 GiB)

### F3 — Board-/SoC-Identität

```
/proc/device-tree/qcom,board-id : 00 00 00 49 00 00 c0 00  -> <0x49 0xc000>
/proc/device-tree/qcom,msm-id   : 00 00 01 6d 00 00 00 00  -> <0x16d 0x0>
/proc/device-tree/model         : "odessa"
```

### F4 — Stock-DTB: GENI-Console-UART bei `0xa88000`

Auszug `/tmp/stock.dts` (aus `firmeware/unpacked_boot/dtb`):

```
qcom,qup_uart@0xa88000 {
    compatible = "qcom,msm-geni-console";
    reg = <0xa88000 0x4000>;
    clock-names = "se-clk", "m-ahb", "s-ahb";
    clocks = <0x27 0x5b 0x27 0x69 0x27 0x6a>;
    pinctrl-names = "default", "sleep";
    pinctrl-0 = <0x184>;
    pinctrl-1 = <0x185>;
    interrupts = <0x00 0x163 0x00>;
    qcom,wrapper-core = <0x186>;
    status = "disabled";
};
```

Pinctrl `qupv3_se8_2uart_active`: `pins = "gpio44", "gpio45"`,
`function = "qup12"`, `drive-strength = <2>`, `bias-disable`.
Alias: `serial0 = "/soc/qcom,qup_uart@0xa88000"`.
Der Stock-`chosen` hat **kein** `stdout-path`; die Kernel-Cmdline nutzt
`console=tty0`.

### F5 — Stock-GCC

```
qcom,gcc@100000 {
    compatible = "qcom,gcc-sdmmagpie\0syscon";
    reg = <0x100000 0x1f0000>;
    #clock-cells = <0x01>;
    #reset-cells = <0x01>;
};
```

### F6 — Mainline-Referenzen (lokal, linux-6.12)

- `sdm670.dtsi` GCC: `compatible = "qcom,gcc-sdm670"`,
  `reg = <0 0x00100000 0 0x1f0000>`, Clock-Header
  `qcom,gcc-sdm845.h` (SDM670 nutzt die SDM845-Clock-IDs).
- `sdm670-google-sargo.dts` `chosen`:
  ```
  stdout-path = "serial0:115200n8";
  framebuffer@9c000000 {
      compatible = "simple-framebuffer";
      reg = <0 0x9c000000 0 (1080 * 2220 * 4)>;
      width = <1080>;
      height = <2220>;
      stride = <(1080 * 4)>;
      format = "a8r8g8b8";
  };
  ```
- `sdm670-google-sargo.dts` USB:
  `&usb_1_hsphy` (status okay), `&usb_1`
  (`qcom,select-utmi-as-pipe-clk`), `&usb_1_dwc3`
  (`dr_mode = "peripheral"`, `phys = <&usb_1_hsphy>`,
  `phy-names = "usb2-phy"`, `maximum-speed = "high-speed"`).
- `sdm670.dtsi` USB: Wrapper `usb@a6f8800` (`qcom,sdm670-dwc3`,
  `qcom,dwc3`), Core `usb@a600000` (`snps,dwc3`), QUSB2-PHY
  `phy@88e2000` (`qcom,sdm670-qusb2-phy`, `qcom,qusb2-v2-phy`).
- `sc7180.dtsi` UART-Template bei `0xa88000`:
  `compatible = "qcom,geni-debug-uart"`,
  `clocks = <&gcc GCC_QUPV3_WRAP1_S2_CLK>` (ID 88),
  `interrupts = <GIC_SPI 355 ...>`.
- SDM845-GCC-Header: `GCC_QUPV3_WRAP_1_M_AHB_CLK` = 102,
  `GCC_QUPV3_WRAP_1_S_AHB_CLK` = 103,
  `GCC_QUPV3_WRAP1_S2_CLK` = 88.
  (Die Stock-Vendor-IDs 0x69/0x6a/0x5b sind **nicht** identisch mit den
  Mainline-IDs; der U-Boot-DTS muss die Mainline-IDs verwenden.)

### F7 — Slot-/DTBO-Ist-Zustand (2026-11-06)

- Aktiv: `androidboot.slot_suffix=_a`, `androidboot.dtbo_idx=2`.
- `dtbo_a` (sde23, 24 MiB): erste 64 Byte = 0; MD5
  `ec87a838931d4d5d2e94a04644788a55` — **nicht** Stock, Header zerstört.
- `dtbo_b` (sdf23, 24 MiB): MD5 `514d54012bb78591ef5b4f502859b564` =
  `firmeware/stock_dtbo.img` (SHA256
  `111c29e9ddaa3d910360b03dfe518c3d0adec26e3d7698c4aa606f994c9b8a3b`).
- Der laufende 4.14-Rescue wurde per `fastboot boot` gestartet; er braucht
  `dtbo_a` nicht. Für einen normalen Slot-a-Boot und für das Stock-Overlay
  (ramoops) muss `dtbo_a` aus `stock_dtbo.img` restauriert werden.

### F8 — Stock-DTBO-Overlay

Der Stock-`dtbo_a`/`dtbo_b` enthält u. a. `ramoops_mem` (Entry 2,
`0xaf000000`); der 6.12-Log zeigte
`OF: reserved mem: ... ramoops_mem`. Für den ersten U-Boot-Test wird das
Overlay offline in den Kernel-DTB gemerged (kein ABL-DTBO nötig).

---

## 4. U-Boot-Buildplan

### 4.1 Quelle und Werkzeuge

- `UBOOT-TOOLS-01` (software-manager, läuft): offizielle U-Boot-Quelle,
  stabiler Tag, persistente Ablage unter
  `/home/zero/.local/share/opencode/re-tools/src/u-boot`.
- Fehlende Host-Tools: `bison`, `flex`, `bc`, `dtc`, `swig`, ggf.
  `python3-setuptools`, `libssl`/`libuuid`/`libgnutls`-Header. Vorhanden:
  Cross-GCC 12.2.0 (`cross-aarch64/usr/bin/aarch64-linux-gnu-gcc`),
  `dtc` in `re-tools/bin`.

### 4.2 Source-Scouting (nach Quellenankunft)

Konkrete Suchhypothesen für den Scout:

- `configs/qcom_defconfig`, `arch/arm64/configs/`, `CONFIG_TARGET_QCOM`.
- `arch/arm64/dts/qcom-*` (SDM845/SDM670/SM7150), `Makefile`-Einträge.
- `drivers/serial/qcom_geni_serial.c` — kompatible Strings
  (`qcom,geni-uart`, `qcom,geni-debug-uart`, `qcom,msm-geni-console`),
  Clock-/Pinctrl-Anforderungen.
- `drivers/clk/qcom/clock-sdm845.c` — unterstützte Compatibles,
  `GCC_QUPV3_WRAP1_S2_CLK`, `GCC_QUPV3_WRAP_1_M_AHB_CLK`.
- `drivers/pinctrl/qcom/pinctrl-qcom.c` — `qcom,sdm670-tlmm`,
  Funktion `qup12`/`qup1`.
- `drivers/phy/qcom/phy-qcom-qusb2.c` — `qcom,qusb2-v2-phy`.
- `drivers/usb/dwc3/dwc3-qcom.c` — `qcom,dwc3`.
- `drivers/video/simplefb.c` — `simple-framebuffer`, `a8r8g8b8`.
- `CONFIG_POSITION_INDEPENDENT`, `CONFIG_LINUX_KERNEL_IMAGE_HEADER`,
  `CONFIG_TEXT_BASE`, `CONFIG_SYS_TEXT_BASE`.
- `CONFIG_USB_TTY`/`CONFIG_USB_GADGET`/`CONFIG_USB_DWC3` als
  Konsolen-Fallback.

### 4.3 U-Boot-DTS `qcom-sdm670-odessa.dts`

Basis: `sdm670.dtsi` + `sdm670-google-sargo.dts` (lokal), mit:

- `/memory`: F2-Regionen.
- `chosen`: `stdout-path = "serial0:115200n8"` und
  `simple-framebuffer` bei `0x9c000000`, `1080x2400`, stride `4320`,
  `a8r8g8b8` (F6).
- `serial@a88000`: `qcom,geni-debug-uart`, `reg = <0 0xa88000 0 0x4000>`,
  `clocks = <&gcc GCC_QUPV3_WRAP1_S2_CLK>`,
  `pinctrl-0 = <&qup_uart8_default>` (GPIO44/45, Funktion `qup12`),
  `status = "okay"`.
- GCC: `qcom,gcc-sdm670`, Mainline-Clock-IDs.
- USB: `usb_1_hsphy`/`usb_1`/`usb_1_dwc3` mit
  `dr_mode = "peripheral"`, `maximum-speed = "high-speed"`.
- Ggf. Fixed-Regulatoren für `vdd`/`vdda-pll`/`vdda-phy-dpdm`, falls
  U-Boot die PM6150-Regler nicht selbst treibt.

### 4.4 Build

- `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom_defconfig`
- `CONFIG_DEFAULT_DEVICE_TREE="qcom-sdm670-odessa"`
- `CONFIG_POSITION_INDEPENDENT=y`
- `CONFIG_LINUX_KERNEL_IMAGE_HEADER=y`
- `CONFIG_OF_LIBFDT=y`, `CONFIG_CMD_BOOTM=y`, `CONFIG_CMD_FDT=y`
- `CONFIG_VIDEO=y`, `CONFIG_VIDEO_SIMPLE=y`, `CONFIG_VIDEO_DT_SIMPLEFB=y`
  (exakte Symbole nach Source-Sichtung)
- `CONFIG_USB_GADGET=y`, `CONFIG_USB_DWC3=y`, `CONFIG_USB_TTY=y`
  (Fallback)
- `nice -n 10 make -j12` (Nutzerlimit), ein Build pro Ansatz.

### 4.5 `boot.img` packen

- `kernel = u-boot.bin` (mit Linux-Image-Header; `text_offset` passend zur
  ABL-Ladephysik, voraussichtlich 0 oder `0x80000`).
- `dtb = Stock-DTB` (nur für ABL; U-Boot nutzt sein eigenes eingebettetes
  DTB).
- `ramdisk = FIT` (siehe 4.6).
- Header v2, Page 4096, **leere Header-Cmdline** (`--cmdline ''`) — der
  `boota (786)`-Fix bleibt gültig.
- Kein Flashen; Test nur per `fastboot boot`.

### 4.6 FIT

- `kernel`: `Image-6.12-original.gz` (14.686.906 B) oder neuer Build.
- `fdt`: gemergter Stock-DTB + Stock-DTBO-Entry 2 (offline mit
  `fdtoverlay`) für den ersten Test; später eigenes odessa-DTB.
- `ramdisk`: vorhandenes Initramfs (`out/initramfs.cpio.gz`, ~989 KB)
  bzw. das 3,7-MB-Rescue-Initramfs.
- Load-Adressen: Kernel `0x90000000`, FDT `0x8F000000`,
  Ramdisk `0xA0000000`; FIT selbst bei `0x85367000` (F1).
- `bootargs`: `console=tty0 loglevel=8 ignore_loglevel
  pstore.backend=ramoops` (plus ggf. `init=/init`).

### 4.7 Observability

1. **Display** über `simple-framebuffer` (U-Boot `vidconsole`) — primär,
   weil der Bootloader das Panel bereits initialisiert hat.
2. **UART** `a88000` (GPIO44/45, `qup12`) — nur nutzbar, wenn die Pins
   zugänglich sind; trotzdem initialisieren.
3. **USB-TTY** (DWC3/QUSB2/CDC-ACM) — Fallback, wenn Display/UART fehlen.

### 4.8 Test und Rollback

```bash
# Test (RAM only)
$FB boot $DIST/test-boot-uboot-odessa.img

# Beobachten: Display-Konsole / UART / USB-TTY; danach 4.14-Rescue
$FB boot $DIST/test-boot-414190-pstore-ro.img
ssh -i $KEY root@172.16.42.1 'cat /tmp/pstore-console-ramoops-0'

# Persistente Slot-a-Nutzung erst nach Erfolg; vorher dtbo_a restaurieren:
$FB flash dtbo_a firmeware/stock_dtbo.img
$FB set_active a
```

---

## 5. Offene Fragen / Unknowns

- **U1:** Unterstützt U-Boots `qcom_defconfig` SM6150/SDM670 out-of-the-box,
  oder braucht es ein neues Board-Target/DTS? (Source-Sichtung)
- **U2:** Akzeptiert ABL `u-boot.bin` als Kernel-Payload mit
  Linux-Image-Header? (Test; `CONFIG_LINUX_KERNEL_IMAGE_HEADER`,
  `text_offset`)
- **U3:** Funktioniert U-Boots `simplefb` mit der `cont_splash_region`
  (`0x9c000000`, `a8r8g8b8`, 1080×2400)? (Test)
- **U4:** Bindet U-Boots GENI-Serial-Treiber den Stock-UART bei `0xa88000`
  mit `qcom,geni-debug-uart` und der SDM845-Clock-ID 88? (Source/Test)
- **U5:** Reichen die Fixed-Regulatoren, oder braucht U-Boot PM6150/RPMH-
  Regler für USB/UART? (Source/Test)
- **U6:** Ist `0x85367000` als FIT-Adresse stabil, auch bei größerem FIT?
  (Test; ggf. Adresse aus `/chosen/linux,initrd-start` im U-Boot-DTB
  ableiten)
- **U7:** Kann U-Boot den FIT überhaupt von `0x85367000` lesen, ohne dass
  ABL ihn überschreibt/verschiebt? (Test)
- **U8:** Linux 6.16+ soll upstream SM6150/SDM670-DTS-Support haben
  (`RESEARCH-mainline-sm6150.md`); der lokale 6.12-Tree hat nur unser
  Minimal-DTS. Für den finalen Mainline-Kernel ggf. 6.16/6.17 beschaffen
  und dessen `sm6150`/`sdm670`-DTS als Basis prüfen (lokal noch nicht
  vorhanden; nicht als Fakt behandeln).

---

## 6. Risiken

- **Kein UART-Pad:** Frühe U-Boot-Fehler bleiben ohne Display unsichtbar.
  Deshalb Display-`simplefb` als erste Observability.
- **U-Boot-Portumfang:** SM6150 ist kein upstream-unterstütztes
  U-Boot-Board; GCC/Pinctrl/PHY-Tabellen können fehlen.
- **ABL-Ladephysik:** `kernel_addr=0x8000`/`ramdisk_addr=0x1000000` im
  Header sind nicht die realen Adressen; die realen Adressen kommen aus
  ABL (F1/F2). Falsche Annahmen führen zu Blind-Boots.
- **FIT-Größe:** Kernel+DTB+Initramfs ~20 MB; muss unterhalb der
  U-Boot-/Kernel-Ladebereiche bleiben.
- **Persistenz:** Kein Flash im ersten Test; `dtbo_a` bleibt unangetastet.

---

## 7. Nächste Schritte

1. `UBOOT-TOOLS-01` abschließen (Quelle + Tools), Ergebnis prüfen.
2. Scout: U-Boot-qcom-Support und Treiber-Compatibles belegen.
3. Investigator: `qcom_defconfig`/Board-Target, `POSITION_INDEPENDENT`,
   `LINUX_KERNEL_IMAGE_HEADER`, `simplefb`, GENI-Serial, GCC/Pinctrl.
4. Synthesizer: `qcom-sdm670-odessa.dts` + Build-Config aus bestätigten
   Fakten.
5. Build (ein Ansatz), `boot.img` + FIT packen, Header prüfen.
6. `fastboot boot`; Display/UART/USB beobachten; 6.12-Log via pstore
   sichern.
7. Bei Erfolg: Linux-DTB-Port (USB/UFS/Display) auf Basis `sdm670` +
   `sm6150`; danach Slot-a-Installation und `dtbo_a`-Restore.

---

## 8. Memory-Referenzen

- Run-Knoten: `7846c605-0654-4c28-b651-deb92e712335`
- U-Boot-Plan: `UBOOT-PLAN-01` (dieses Dokument)
- ABL-Adressen: `ABL-INITRD-ADDR-01`
- DTBO-Ist-Zustand: `DTBO-STATE-01`
