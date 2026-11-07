# Verification evidence (2026-11-07)

Reference device: Moto G9 Plus XT2087-2, S/N ZY227VHMSS, bootloader
`MBM-3.0-odessa_retail-e69c40c38d6-220818`, `flashing_unlocked`, slot b active.

## Release image

| File | Size | SHA256 |
|---|---|---|
| `artifacts/odessa-6.12-boot.img` | 64,675,840 B (62.27 MiB) | `2fb98a100e7e0de9146b37b00dd1fcae83cdacc60cdd4a0f9037f4448310c81f` |
| `artifacts/rootfs-install.tar.gz` | 44,239,575 B (42.14 MiB) | `302256657bdb22d37e57fcce01d2683856f03a077ae6b2f48e537081dcd3fb71` |
| `artifacts/Image-6.12.gz` | 14,592,555 B | `48a3972c...1ad4fe` (kernel build) |
| `artifacts/odessa-6.12.dtb` | 587,152 B | ABL-merged DTB (fix35) |
| `artifacts/u-boot.bin` | 1,509,904 B | U-Boot v2026.10 build |

The boot image reserves 2,433,024 bytes under the 64 MiB `boot_b` limit.

## End-to-end run on empty userdata

Commands: `fastboot erase userdata`, `fastboot flash boot_b
artifacts/odessa-6.12-boot.img`, `fastboot set_active b`, `fastboot reboot`.

Kernel log:

```
[    4.405105] [init] self-install: writing embedded rootfs to /dev/sdb24
[   20.401090] [init] self-install: rootfs written
[   21.495588] [init] switching root to /dev/sdb24 (ubuntu)
```

After boot:

```
/proc/1/comm                     systemd
/etc/os-release                  Ubuntu 26.04.1 LTS (Resolute Raccoon)
systemd --version                systemd 259 (259.9-0ubuntu0.1)
systemctl is-system-running      running
systemctl --failed               0 loaded units listed
/                                /dev/sdb24 ext4, 107G, 161M used
usb0                             172.16.42.1/24
dpkg --audit                     (empty)
installed packages               112
```

## Second boot (no self-install)

```
[    4.427757] [init] switching root to /dev/sdb24 (ubuntu)
```

`systemctl is-system-running` = running, 0 failed units, machine-id and
Dropbear host key unchanged (`/etc/machine-id` stable across the reboot).

## Root filesystem image

The 2 GiB image was built with `mke2fs -O ^orphan_file`, `e2fsck -f` clean,
and inspected with `debugfs`:

```
/usr/lib/os-release      Ubuntu 26.04.1 LTS
/usr/lib/systemd/systemd 133,696 B
/sbin/init -> ../lib/systemd/systemd
/etc/odessa-ready        present
/etc/machine-id          0 bytes
/etc/dropbear/           empty (keys generated on first boot)
/etc/modules-load.d/     empty
```

The sparse image was expanded and hashed to verify the round trip: the
expanded SHA256 equals the raw image SHA256.

## Known non-fatal boot messages

- `arm-smmu 5040000.arm,smmu-kgsl: probe ... -16` (GPU/KGSL, out of scope)
- `amba_device_add() failed (-16)` for Coresight CTIs (cosmetic)
- `lpi_pinctrl@62b40000: could not get #gpio-cells` (cosmetic)
- `gpio-regulator: deferred probe pending` (unused regulator stubs)

None of these produce a failed systemd unit or affect storage, USB or SSH.


## Backlight off (WLED, 2026-11-07)

The release kernel enables `CONFIG_BACKLIGHT_QCOM_WLED=y`; the runtime DTS uses
the mainline binding `qcom,pm6150l-wled` (strings 0-2, 25 mA, OVP 23500 mV,
boost 1050 mA, CABC, default brightness 2048).

```
/sys/class/backlight/backlight   -> ...pm6150l@5:qcom,wled@d800/backlight/backlight
brightness / max_brightness      0 / 4095
actual_brightness                0
```

The panel glow disappears only after a non-zero -> zero transition: the
driver starts with `wled->brightness = 0`, so a direct write of 0 does not call
`wled_module_enable(false)`. `odessa-screen-off.service` therefore writes
`bl_power=0`, `brightness=2048`, waits 200 ms and writes `0` before clearing
`/dev/fb0`.


## Battery guard (2026-11-07)

```
QG SDAM offset 0x47                 100 (%)
ADC5 in_voltage_vbat_sns_input      4,455,426 uV (USB attached)
charge_enable=0 / status 0x1006     7 (DISABLE_CHARGE)
charge_enable=1 / status 0x1006     4 (TAPER_CHARGE)
battery-guard.timer                 active, 30 s period
```

The guard stops at >=60% and resumes at <=40%; the voltage fallback uses
4.00 V / 3.65 V if the QG value is stale.
