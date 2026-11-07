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

## Network

Only the point-to-point USB link exists. There is no default route, no DHCP
client, no DNS resolver and no NAT. `apt` can only work if the host forwards
traffic (host-side `ip_forward` + masquerade) — not part of this image.

## Clock

The system clock starts at the rootfs build time (no RTC driver/NTP). Set it
manually (`date -s ...`) or add a time source.

## Accounts and login

Only `root` exists; Dropbear is key-only. `getty@tty1` runs but there is no
keyboard and no password set up, so SSH is the practical access path.

## Display

The bootloader framebuffer is used as a simple framebuffer console. There is
no mainline DSI/panel driver, so no graphical session.

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
