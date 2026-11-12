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
- No NetworkManager/iwd. `odessa-wlan.service` runs `wpa_supplicant` and the
  busybox DHCP client with the shipped static `iw`/`wpa_cli`; it is a no-op
  until `/etc/wpa_supplicant.conf` contains a `network={}` block (see
  `wlan/README.md`).

## Bluetooth status

Bluetooth works (verified 2026-11-11): the WCN3990 comes up over GENI SE3,
downloads `qca/crbtfw21.tlv` + `qca/crnv21.bin` and reports
`QCA setup on UART is completed`; `hci0` exists and is rfkill-unblocked. Two
non-obvious constraints are documented in `docs/HARDWARE.md`:

1. the BT UART must run in **FIFO mode** (`qcom,geni-fifo`,
   `kernel/patches/0007`) — the QUP DMA path of this vendor DTB hard-locks the
   SoC on the first transmit;
2. the stack is loaded by `bt-stack.service` **after** `wlan-rails.service`,
   because the chip only answers once `pm6150l_l1/l2` are in their vendor
   windows.

Remaining limitations:

- **No userspace stack.** BlueZ (`bluetoothd`, `bluetoothctl`) is not part of
  the image; the controller works at the HCI level only. Installing BlueZ
  needs package downloads from the network.
- The BT MAC comes from the device tree (`local-bd-address` in the
  `qcom,wcn3990-bt` node): the WCN3990 reports no valid address, and userspace
  programming through mgmt proved unreliable (the request can race the
  boot-time setup and wedges the mgmt interface until the next reboot).
  `bt-set-addr.sh` still reads `androidboot.btmacaddr` as a fallback, so a
  unit with a different MAC needs either that property updated in the DTB or
  the userspace path.
- After a **warm** reboot the chip occasionally ignores the power-on pulse and
  stays silent (no firmware download). The PM6150(L) rails are fixed
  regulators here - mainline cannot enable the real RPMh regulators on this
  vendor DTB - so only the pulse resets the chip; a cold power cycle always
  works.
- SCO/audio routing through the BTFM Slimbus codec was not exercised.

## Network

Two links come up at boot:

- `usb0` — the point-to-point USB gadget (172.16.42.1/24, no DHCP server, no
  NAT); it exists for SSH and host-side tooling.
- `wlan0` — `odessa-wlan.service` associates with the network from
  `/etc/wpa_supplicant.conf` and runs the busybox DHCP client. Its hook installs
  the lease address, the **default route** and `/etc/resolv.conf` (DHCP
  resolvers, gateway as fallback). The service is a no-op while the shipped
  template has no `network={}` block.

There is no forwarding between the two links. IPv6 is SLAAC only (no IPv6
default route), so dual-stack clients fall back to IPv4.

## Battery guard

`battery-guard.timer` keeps the pack between 40% and 60%. The mainline kernel
does not run the QG fuel gauge, so `/sys/class/power_supply` is empty and the
SDAM msoc byte (offset 0x47) is a frozen bootloader anchor (normally 100%).
The guard therefore estimates the SoC from the relaxed `vbat_sns` voltage with
the vendor OCV table of the installed cell (mg50-atl-5000mah,
`qcom,pc-temp-v1-lut`, 25 C column) and only uses the gauge byte when it
agrees with that estimate within 8 points.

While charging the terminal voltage is dominated by IR drop and polarization,
so charging runs in pulses: at most 240 s on, then 180 s off, and the 60% stop
decision is taken on the relaxed voltage at the end of the rest. Charging
resumes once the relaxed voltage drops to <=40%. There is no current/power
telemetry, so the percentage stays an estimate (a few points low under load)
and could read high on a cell whose OCV curve differs from the shipped
profile.

## Clock

There is no RTC driver on odessa. systemd restores the last known time from
`/var/lib/systemd/timesync/clock` at boot and `systemd-timesyncd` (shipped in
the payload) steps it once the Wi-Fi link has a default route; `odessa-wlan`
restarts the unit after association so the correction happens immediately
instead of at the next poll interval. Consequences:

- after a long power-off the clock is behind by that duration until NTP syncs;
- without configured Wi-Fi credentials there is no time source, so `apt`
  rejects Release files as "not valid yet" until the clock is set manually
  (`date -s ...`).

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
