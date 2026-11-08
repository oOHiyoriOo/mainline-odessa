# Verification evidence (2026-11-07)

Reference device: Moto G9 Plus XT2087-2, S/N ZY227VHMSS, bootloader
`MBM-3.0-odessa_retail-e69c40c38d6-220818`, `flashing_unlocked`, slot b active.

## Release image

| File | Size | SHA256 |
|---|---|---|
| `artifacts/odessa-6.12-boot.img` | 65,970,176 B (62.92 MiB) | `7b10fd3a50f5c1daf0dd471a5820370e95a99a88dee46445c2f10a5bb2cd612e` |
| `artifacts/rootfs-install.tar.gz` | 44,239,575 B (42.14 MiB) | `302256657bdb22d37e57fcce01d2683856f03a077ae6b2f48e537081dcd3fb71` |
| `artifacts/Image-6.12.gz` | 15,885,952 B | `7dd891d6a96f4cfc97301eabf1cfbea72bd7a1e4c96412c4a9a9b1278e0acb89` |
| `artifacts/odessa-6.12.dtb` | 588,303 B | `b2b43adcd2e86a5c21b0052dbeb92af5a2e45f2054593910987f444ced14e7d2` (modem DT + LED) |
| `artifacts/u-boot.bin` | 1,509,904 B | U-Boot v2026.10 build |

The boot image reserves 1,138,688 bytes under the 64 MiB `boot_b` limit.

Kernel build 2026-11-08 (`6.12.0 #6 SMP PREEMPT Sun Nov  8 12:25:05 UTC 2026`)
adds the container prerequisites that the 2026-11-07 build only had as
modules: `NF_TABLES`, `NF_NAT`, `NFT_*` (nat/masq/redir/ct/reject/compat),
iptables/ip6tables compatibility, `BRIDGE`, `BRIDGE_NETFILTER`, `VETH`,
`OVERLAY_FS`, and `IPV6` (needed because `BRIDGE` depends on
`IPV6 || IPV6=n`); `NETFILTER_ADVANCED=y` is required or `olddefconfig`
silently keeps the netfilter options at `=m`.

## Containers (2026-11-08)

Boot image flashed to `boot_b`, `fastboot set_active b`, cold boot. Verified on
the device:

```
uname -r                         6.12.0
/proc/filesystems                overlay
docker info                      Server 29.9.3, Storage Driver overlayfs,
                                 Cgroup Driver systemd, Cgroup Version 2
ip -brief addr show docker0      docker0 UP 172.17.0.1/16
/proc/sys/net/ipv4/ip_forward    1
/proc/sys/net/bridge/bridge-nf-call-iptables  1
iptables -t nat -S               -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
iptables -S DOCKER               -A DOCKER ! -i docker0 -o docker0 -j DROP
dmesg                            "Bridge firewalling registered"
```

With the previous image `mount -t overlay` failed with `ENODEV` (overlay was a
module and the kernel image ships none). With the `vfs` storage driver and
`bridge: none` Docker could still start, but had no container network.

## Status LED (2026-11-08)

The front LED next to the selfie camera is the PM6150L TRILED block. The vendor
DT describes it as `qcom,leds@d000` with `compatible = "qcom,tri-led"`, which
has no mainline driver; the LPG hardware behind it (`qcom,pwms@b100`) does.
The DT node was retargeted to the mainline binding:

```
/soc/qcom,spmi@c440000/qcom,pm6150l@5/pwm {
        compatible = "qcom,pm6150l-lpg", "qcom,pm8150l-lpg";
        #address-cells = <1>; #size-cells = <0>; #pwm-cells = <2>;
        status = "okay";
        led@1 { reg = <1>; label = "charging";
                linux,default-trigger = "heartbeat"; };
        led@2 { reg = <2>; label = "green"; };
        led@3 { reg = <3>; label = "blue"; };
};
```

`led@N` uses a 1-based `reg` that maps to `lpg->channels[reg - 1]`; for the
`qcom,pm8150l-lpg` data those are `0xb100/BIT(7)`, `0xb200/BIT(6)` and
`0xb300/BIT(5)`, with `triled_base = 0xd000`. `qcom,power-source` is only read
when the matched data sets `triled_has_src_sel`, which is not the case here, so
it is not required. `CONFIG_LEDS_CLASS_MULTICOLOR`, `CONFIG_LEDS_QCOM_LPG` and
`CONFIG_QCOM_PBS` are now built in (`=y`); the driver needs
`qcom_pbs_trigger_event`/`get_pbs_client_device`.

Verified on the device (no modules loaded):

```
/sys/class/leds/                 charging  green  blue
/sys/class/leds/charging/device/driver   qcom-spmi-lpg
charging/trigger                 [heartbeat]
brightness samples               0 0 511 0 511 0 0 0 0 0
/proc/modules                    0 entries
```

Only channel 1 (`0xb100`) is populated on this board and it is white; channels
2 and 3 stay dark at full brightness. The vendor label `charging` is just a
label, not a colour.


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

## Modem / remoteproc (2026-11-08)

Three separate regressions had to be fixed before the modem could be started
at all. All three were drift inside this project, not missing hardware
support:

1. `odessa_glink.c` existed only in one source tree. It is now part of
   `kernel/patches/0002-odessa-modem-pas.patch`, so a build from the pinned
   tarball contains it.
2. `qcom_q6v5_pas.c` lacked the `qcom,sm6150-mpss-pas` compatible and its
   `sm6150_mpss_resource` descriptor (`pas_id 4`, `crash_reason_smem 421`,
   `ssr_name "mpss"`). Same patch.
3. `CONFIG_QCOM_TZMEM_MODE_SHMBRIDGE=y` made the first TZ memory call hang,
   which surfaced as `Starting Kernel ...` with no output. The release config
   now uses `CONFIG_QCOM_TZMEM_MODE_GENERIC=y`, the setting the 2026-11-07
   test kernel used.

`CONFIG_QCOM_RMTFS_MEM` is now `=y` as well (it was `=m`, and loading the
module hung for the same TZMEM reason), so `/dev/qcom_rmtfs_mem1` exists at
boot and `rmtfs.service` starts.

The device tree used for this image (`kernel/dts/odessa-6.12-modem.dts`)
keeps the vendor `odessa-glink` node **disabled**: the custom GLINK-edge
driver and the PAS subdevice both claim IRQ 35, and only one of them may.
With PAS working the custom node is redundant.

Verified on the device:

```
remoteproc0: Booting fw image modem.mdt, size 9100
remoteproc0: remote processor 4080000.qcom,mss is now up
4080000.qcom,mss:glink-edge.IPCRTR.-1.-1
4080000.qcom,mss:glink-edge.SSM_RTR_MODEM_APPS.-1.-1
4080000.qcom,mss:glink-edge.glink_ssr.-1.-1
4080000.qcom,mss:glink-edge.rpmsg_ctrl.0.0
/dev/qcom_rmtfs_mem1          present, rmtfs.service active
```

The modem is **not** auto-started (`auto_boot = false`); it comes up with
`echo start > /sys/class/remoteproc/remoteproc0/state`.

Open issue: the firmware reports `fatal error without message` 40 s after a
start and the crash-reason SMEM item (421) is never written, so there is no
PC or register context on the AP side. With `rmtfs` running the crash is
unchanged, and a logging TFTP server records zero requests, so neither EFS
nor TFTP is the trigger. Wi-Fi stays blocked; the remaining difference to
the vendor stack is IPA (`qcom,ipa@1e00000`, `pas_id 0xf`), for which
mainline 6.12 has no SM6150 glue.

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
