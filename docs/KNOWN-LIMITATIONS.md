# Known limitations

Each item lists the observed behaviour and the cause. None of them prevents
booting, storing data, or SSH access.

## UFS on fixed rails (blocker for PM)

`regulator_enable()` on the RPMh rails used by UFS hangs in the TCS wait
(`L-REG-02`). The DTB therefore keeps UFS on the bootloader-initialized fixed
rails. dmesg shows `ufshcd_populate_vreg: Unable to find ... assuming enabled`.
The practical impact is that runtime PM / suspend is not usable.

## No kernel modules

The kernel is built monolithic (no `/lib/modules`). `systemd-modules-load`
is `inactive` by design (the 26.04 base shipped a dangling
`/etc/modules-load.d/modules.conf`, which is removed by
`sanitize-rootfs.sh`). Loading modules at runtime is not possible without a
kernel rebuild.

## No udev

The rootfs has no `udev` package; `/dev` is devtmpfs. Device nodes required by
the boot path (UFS, console) are created by the kernel. Tools that rely on
udev events (hotplug, persistent names) are unavailable.

## Wi-Fi (blocked)

WCN3990 is not usable yet. The kernel has ATH10K/ATH10K_SNOC, QRTR and the
GLINK transport built in, and three GLINK edges (modem/adsp/cdsp) register,
but the remote side never opens an `IPCRTR` channel. Without a QRTR endpoint
`ath10k_qmi` waits 30 s and fails; there is no WLFW service. SMEM IDs
(478/479/480), mailbox offset 12 and IRQ 449 match the vendor DTS, so this is
a modem firmware/PD handshake issue, not a device-tree fix. It requires a
modem PD/QMI port or a modem restart.

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

Wi-Fi, modem/cellular, camera, GPU (KGSL), USB-PD, suspend.

## Device tree coupling

`artifacts/odessa-6.12.dtb` is merged from the stock firmware of the reference
device (`...e69c40c38d6-220818`, DTBO entry 2). Another firmware or panel
revision needs a new merge before the image is expected to work.

## Bootloader policy

`fastboot flash userdata` and `fastboot flash super` are refused. Only
`boot_b` can be flashed; the rootfs is installed by the boot image on first
boot. `boot_a`/`dtbo` must stay untouched.
