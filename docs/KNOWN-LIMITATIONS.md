# Known limitations

Each item lists the observed behaviour and the cause. None of them prevents
booting, storing data, or SSH access.

## UFS on fixed rails (blocker for PM)

`regulator_enable()` on the RPMh rails used by UFS hangs in the TCS wait
(`L-REG-02`). The DTB therefore keeps UFS on the bootloader-initialized fixed
rails. dmesg shows `ufshcd_populate_vreg: Unable to find ... assuming enabled`.
The practical impact is that runtime PM / suspend is not usable.

## Kernel modules

The kernel is monolithic except for three out-of-tree helper modules shipped
in `/lib/modules/6.12.0/extra/` (`smmu_probe`, `wlan_rails`,
`mmi_unit_info`; loaded by their systemd units). They are built by
`wlan/modules/build-modules.sh` against the same kernel tree.
`systemd-modules-load` stays inactive by design (the 26.04 base shipped a
dangling `/etc/modules-load.d/modules.conf`, removed by
`sanitize-rootfs.sh`); arbitrary third-party modules still need a rebuild.

## No udev

The rootfs has no `udev` package; `/dev` is devtmpfs. Device nodes required by
the boot path (UFS, console) are created by the kernel. Tools that rely on
udev events (hotplug, persistent names) are unavailable.

## Wi-Fi status

Wi-Fi works (verified 2026-11-10): `wlan0` up, scan, WPA2-PSK association,
DHCP and ICMP in the local network. Three firmware/driver quirks had to be
fixed, all shipped in this repo:

1. `PDEV_SET_QUIET_MODE` before the first vdev made the firmware self-reset
   (`kernel/patches/0004`, `0005`);
2. the management-TX path needs firmware feature bit 18 (`MGMT_TX_BY_REF`) in
   `firmware-5.bin` (`wlan/firmware/`);
3. `WMI_VDEV_START` for the station vdev is rejected unless a BSSID peer
   exists beforehand (`kernel/patches/0006`).

Remaining limitations:

- 5 GHz operation was not exercised (no 5 GHz BSS in range during bring-up);
  the regulatory DB is installed and `country DE` applies.
- The MAC address is random per boot (the firmware reports
  `00:00:00:00:00:00`); a stable MAC would need a device-tree
  `local-mac-address`.
- No NetworkManager/iwd; association uses `wpa_supplicant` and the shipped
  static `iw`/`wpa_cli` (see `wlan/README.md`).

## Network

Only the point-to-point USB link exists. There is no default route, no DHCP
client, no DNS resolver and no NAT. `apt` can only work if the host forwards
traffic (host-side `ip_forward` + masquerade) — not part of this image.

## Battery guard

`battery-guard.timer` keeps the pack between 40% and 60%: it stops charging at
>=60% and resumes at <=40% via the PM6150 `CHARGING_ENABLE_CMD` bit. Capacity
comes from the QG SDAM (offset 0x47) through nvmem, with an ADC5
`vbat_sns` fallback (4.00 V / 3.65 V). In idle the device runs from the cable
without loading the battery, so it stays at the current SoC.

## Clock

The system clock starts at the rootfs build time (no RTC driver/NTP). Set it
manually (`date -s ...`) or add a time source.

## Accounts and login

Only `root` exists; Dropbear is key-only. `getty@tty1` runs but there is no
keyboard and no password set up, so SSH is the practical access path.

## Display

The bootloader framebuffer is used as a simple framebuffer console. There is
no mainline DSI/panel driver, so no graphical session. The PM6150L WLED
backlight is driven by mainline `qcom-wled`; `odessa-screen-off.service`
switches it off (non-zero -> zero transition) and masks `getty@tty1`.

## Out of scope

Wi-Fi/modem (blocked, see above), camera, GPU (KGSL), USB-PD, suspend.

## Device tree coupling

`artifacts/odessa-6.12.dtb` is merged from the stock firmware of the reference
device (`...e69c40c38d6-220818`, DTBO entry 2). Another firmware or panel
revision needs a new merge before the image is expected to work.

## Bootloader slot rollback

The stock bootloader tracks a retry counter for each slot. Mainline never
marks a boot as successful, so after several reboots without a flash the
counter runs out and the device falls back to slot `a` (stock Android/
recovery). Fix: `fastboot --set-active=b` (or flash `boot_b` again), then
boot. This is a bootloader behaviour, not a kernel defect.

## Bootloader policy

`fastboot flash userdata` and `fastboot flash super` are refused. Only
`boot_b` can be flashed; the rootfs is installed by the boot image on first
boot. `boot_a`/`dtbo` must stay untouched.
