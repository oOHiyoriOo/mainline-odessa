# Hardware and boot chain

## Device

- Motorola Moto G9 Plus (`odessa`), XT2087-2
- Qualcomm SM6150 / Snapdragon 675, platform name `sdmmagpie`
- 4 GB RAM, UFS storage
- Bootloader `MBM-3.0-odessa_retail-e69c40c38d6-220818`, unlocked

## Partitions (relevant)

| Name | Device | Use |
|---|---|---|
| `boot_a` | `/dev/sde21` | stock Android boot (untouched) |
| `boot_b` | `/dev/sdf21` | release image |
| `dtbo_a` | `/dev/sde23` | stock (untouched) |
| `dtbo_b` | `/dev/sdf23` | stock (untouched) |
| `userdata` | `/dev/sdb24` | Ubuntu rootfs |

The bootloader validates Android boot images and refuses writes to `userdata`
and `super`, but accepts `boot_b`. Linux can write `userdata`, so the release
image installs the rootfs itself.

## Chain

```
ABL (stock)
  └─ loads boot_b: u-boot.bin as "kernel", FIT as "ramdisk", stock DTB in header
       └─ U-Boot (qcom_qcs615_odessa_defconfig)
            └─ bootm FIT
                 ├─ kernel  Image.gz   @ 0x90000000
                 ├─ DTB     odessa.dtb @ 0x8F000000
                 └─ ramdisk initramfs @ 0xA0000000
                      └─ Linux 6.12
                           ├─ UFS 1d84000.ufshc -> /dev/sdb24
                           ├─ DWC3/QUSB2 -> CDC-NCM usb0 172.16.42.1/24
                           └─ self-install -> switch_root -> systemd
```

Bootargs: `console=tty0 loglevel=4 fbcon=font:TER16x32 pstore.backend=ramoops
clk_ignore_unused pd_ignore_unused panic=0 keep_bootcon init=/init
regulator_ignore_unused odessa.boot=ubuntu`.

## Device tree

Two DTS sources exist for different purposes:

- `kernel/dts/abl-merged-gcc.dts` — the **runtime** DTB source. It is the
  ABL-merged tree (stock DTB + DTBO entry 2 for this firmware) with the odessa
  bring-up changes: mainline PDC (`qcom,pdc`, `qcom,pdc-ranges`, two cells),
  31 PM6150/PM6150L regulators, UFS nodes, USB DWC3/QUSB2, active GCC.
  `artifacts/odessa-6.12.dtb` is its compiled form (fix35).
- `kernel/patches/0001-...` contains `arch/arm64/boot/dts/qcom/sm6150-moto-odessa.dts`
  — an early bring-up DTS inside the kernel tree. It is not used at runtime.

The DTB is tied to the stock firmware/panel. A different unit with another
firmware build needs a new ABL merge.

## Clocks, regulators, interrupts

- `gcc-sdmmagpie` clock driver ported from the vendor tree (clock IDs in
  `include/dt-bindings/clock/qcom,gcc-sdmmagpie.h`).
- PM6150/PM6150L RPMh regulators register (31 in `regulator_summary`), but
  consumer enables hang in the TCS wait; UFS therefore uses fixed rails
  (`vdd-hba-supply`, `vcc*` "assuming enabled" in dmesg).
- Mainline PDC handles the SPMI peripheral IRQs; no `IRQ_TYPE_NONE` warnings.

## Bluetooth (WCN3990)

Transport is GENI SE3 (`qcom,qup_uart@0x88c000`, 4-wire, gpio38/39/40/41,
function `qup03`) exposed to mainline as `qcom,geni-se-qup` +
`qcom,geni-uart` with a `qcom,wcn3990-bt` serdev child.

Two things are specific to this vendor DTB and are easy to get wrong:

- **The UART has no QUP DMA path.** The vendor node carries no `dmas`, and
  this DTB exposes no interconnect provider (`qup_virt`/`config_noc`), so the
  first QUP DMA transaction never completes and the SoC hard-locks (watchdog
  reset, no oops). `kernel/patches/0007-qcom-geni-uart-fifo-mode.patch` adds
  the `qcom,geni-fifo` property, which switches the port to the SE FIFO
  primitives the driver already uses for its console. The BT UART node sets
  it.
- **The chip needs the PMIC rails in their vendor windows first.**
  `pm6150l_l1` (xtal, 1.8 V) and `pm6150l_l2` (core, 1.304 V) are below spec
  after the bootloader; `pm6150l_l10/l11` (3.312 V) and `pm6150_l10`
  (vddio, 1.8 V) complete the set. Only `wlan_rails.ko` sets them, from
  userspace, and mainline cannot enable RPMh regulators on this DTB
  (`rpmh_write` dereferences a NULL controller), so the rails rely on the
  bootloader having enabled them.

Because of that ordering, Bluetooth is a module set, not built in: the probe
runs when `hci_uart.ko` is loaded, and `bt-stack.service` loads it after
`wlan-rails.service`:

```
ecc -> ecdh_generic -> bluetooth -> btqca -> btbcm -> hci_uart -> rfcomm -> hidp
```

Firmware comes from the device's `bluetooth_a` partition and is shipped in
`bt/firmware/`: `qca/crbtfw21.tlv` (patch) and `qca/crnv21.bin` (NVM).
Expected dmesg on success:

```
Bluetooth: hci0: setting up wcn399x
Bluetooth: hci0: QCA Product ID   :0x0000000a
Bluetooth: hci0: QCA Downloading qca/crbtfw21.tlv
Bluetooth: hci0: QCA Downloading qca/crnv21.bin
Bluetooth: hci0: QCA setup on UART is completed
```

Rebuild the shipped modules with `bt/modules/build-modules.sh`; the rootfs
installer copies them to `/lib/modules/6.12.0/extra/`.

Notes for using the controller:

- The BD address comes from the device tree (`local-bd-address`), because the
  chip reports none and a userspace `mgmt` request can race the boot-time setup
  and wedge the interface.
- Pair with `btmgmt pair -c 3 <MAC>` (IO capability `NoInputNoOutput`): the
  controllers here have no keyboard/display, and the phone then uses Just Works
  instead of a passkey nobody can confirm. `bluetoothctl` works interactively
  (`agent on`, `default-agent`) but a piped session cannot answer the
  confirmation prompt.

## USB

DWC3 at `a600000.dwc3` with the QUSB2 PHY. The gadget is configured from
userspace (`usb-gadget.service`) as CDC-NCM:

- device address `172.16.42.1/24`, MAC `a6:00:00:00:00:02`
- host side needs a static address in `172.16.42.0/24`
- Dropbear listens on port 22, key-only

There is no DHCP client on the host and no NAT; the link is point-to-point.
