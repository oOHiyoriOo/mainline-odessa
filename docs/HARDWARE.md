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

## USB

DWC3 at `a600000.dwc3` with the QUSB2 PHY. The gadget is configured from
userspace (`usb-gadget.service`) as CDC-NCM:

- device address `172.16.42.1/24`, MAC `a6:00:00:00:00:02`
- host side needs a static address in `172.16.42.0/24`
- Dropbear listens on port 22, key-only

There is no DHCP client on the host and no NAT; the link is point-to-point.
