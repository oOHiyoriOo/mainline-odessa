# Verification evidence (2026-11-07, Wi-Fi 2026-11-10, Bluetooth 2026-11-11)

Reference device: Moto G9 Plus XT2087-2, S/N ZY227VHMSS, bootloader
`MBM-3.0-odessa_retail-e69c40c38d6-220818`, `flashing_unlocked`, slot b active.

## Release image

| File | Size | SHA256 |
|---|---|---|
| `artifacts/odessa-6.12-boot.img` | 65,974,272 B (62.92 MiB) | `6ca154f92bd8c4219ccc7b9a979fdc2eff0253cbc07a0de2b6080dcd3e9f29e8` |
| `artifacts/rootfs-install.tar.gz` | 44,239,575 B (42.14 MiB) | `302256657bdb22d37e57fcce01d2683856f03a077ae6b2f48e537081dcd3fb71` |
| `artifacts/Image-6.12.gz` | 15,888,295 B | `cf8635f255d36ea79c4dfd816b00680a9421c185a6259670a1a7e12d2d3fa9a6` |
| `artifacts/odessa-6.12.dtb` | 588,303 B | `b2b43adcd2e86a5c21b0052dbeb92af5a2e45f2054593910987f444ced14e7d2` (modem DT + LED) |
| `artifacts/u-boot.bin` | 1,509,904 B | U-Boot v2026.10 build |

The boot image reserves 1,134,592 bytes under the 64 MiB `boot_b` limit.

Kernel build 2026-11-08 (`6.12.0 #8 SMP PREEMPT Sun Nov  8 13:55:02 UTC 2026`)
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

### Why the modem never reached userspace

The modem image was running, but the AP never read its QRTR traffic: the
release is monolithic (no `/lib/modules` at all) while `CONFIG_QRTR_SMD` was
`=m`, so no driver bound the `IPCRTR` rpmsg channel:

```
4080000.qcom,mss:glink-edge.IPCRTR.-1.-1              -> driver: NONE
/sys/bus/rpmsg/drivers: qcom_glink_ssr, qcom_smd_rpm, qcom_sysmon, rpmsg_ns
```

`CONFIG_QRTR_SMD`, `CONFIG_RPMSG_CTRL` and `CONFIG_RPMSG_CHAR` are now `=y`.
With that the modem is reachable and registers nine QRTR services within
0.6 s of `is now up` (node id 0, as announced by the firmware):

```
43 66 15 51 21 24 23 22 36 49      (49 = IPA control service, last)
```

The second fix is the PD map. `pd-mapper` resolves it next to the remoteproc
firmware, i.e. `/lib/firmware/modemr.jsn` and `modemuw.jsn`, but the package
ships them under `/lib/firmware/qcom/`. Without them it logs
`no pd maps available` and answers the domain-list request with an empty map,
so `msm/modem/wlan_pd` (`qmi_instance_id 180`) does not exist for the modem.
`kernel/install-pd-map.sh` copies the two files into place.

### Open issue: crash in the first heap access after RF file loading

With the transport and the PD map fixed the modem still dies, now with a
crash reason instead of silence:

```
qcom_q6v5_pas 4080000.qcom,mss: fatal error received:
    :0:EX:kernel:0:rf:16e:PC=c06c9b50
```

The string format is the firmware's own `EX:%s:%x:%s:%x:PC=%x`
(`modem.b16`, `modem.b29`): context `kernel`, thread `rf`, and a counter that
increments on every restart.

#### What the faulting function does

`0xc06c9b50` is a load inside the function at `0xc06c9af4` (segment `b11`).
It is not a page-table walker but a **heap-bank selector**. Fully decoded:

```
c06c9af8  r2 = memw(r3=##0xc22812a0)   ; bank table, static data in b17
c06c9afc  r2 += asl(r1,#0xc)           ; base + idx*0x1000
c06c9b0c  r6 = memw(r2+r4)             ; tag word of bank 1   (read succeeds)
c06c9b1c  r6 = asl(r1,#0xc)
c06c9b20  r2 = memw(r3+#0x4)           ; bank 2
c06c9b24  r2 = add(r2,r6)
c06c9b28  r7 = memw(r2+r4)             ; tag word of bank 2   (read succeeds)
c06c9b2c  p0 = bitsclr(r5,r7)          ; tag & mask == 0 ?
c06c9b30  if (p0) jump 0xc06c9b4c      ; same packet
c06c9b34  if (p0) r2 = memw(r3+#0x8)   ; bank 3 base
c06c9b4c  r2 = add(r2,r6)
c06c9b50  r3 = memw(r2+r4)             ; <-- fault
```

The bank table at VA `0xc22812a0` (file offset `0xdf2a0` in `modem.b17`) holds
`0xa1a00000`, `0xa1e00000`, `0xa1600000`; the following words
(`0xc22812b0`) hold the corresponding allocation watermarks
`0xa1a8a000`, `0xa1e87000`, `0xa1682000`. The table is never written at
runtime — the whole firmware references it only from `b11` offsets
`0x21f6d0..0x21fb38`, so the layout is fixed at build time.

`pool_init` at `0xc06c9dc..0xc06c9af0` fills the descriptor `0xc4844bec`
(segment `b19`, a pure zero-fill segment) with the constants that make the
fault address exact:

| field | value | meaning |
|---|---|---|
| `+0x04` | `0x77` | number of 4 KiB slots |
| `+0xdc` | `0x10` | tag-word offset inside each slot |
| `+0xe4` | `0x01` | mask: bit 0 marks the owning bank |
| `+0xa4` | `0xc4844cd8` | slot array |

So the faulting access is `0xa1600000 + idx*0x1000 + 0x10`, i.e. the
`idx`-th slot of the third bank. `idx` is unknown but bounded: the slot count
at `+0x04` is `0x77`, and no caller in the image passes more. The two
preceding reads — same `idx`, same offset, banks at `0xa1a00000` and
`0xa1e00000` — complete without a fault. The discriminator is therefore the
*address*, not the index or the offset.

Note (2026-11-08, correction): an earlier reading concluded `idx = 0x82`
because the third watermark is `0xa1682000` = `0xa1600000 + 0x82000`. That was
circular. With the `0x77` gate the largest legal offset is `0x76000`, which is
below *all three* watermarks (`0x8a000`/`0x87000`/`0x82000`), so the fault lies
inside the third bank's permitted range — the bank is simply not mapped there.

#### Ordering: the crash follows the completed RFS phase

A live trace with `rmtfs` and `tqftpserv` under
`strace -f -tt -e trace=openat,read,sendto,recvfrom` (artifacts in the run
directory, `PREP-TRACE-01/`) shows the whole file phase completing normally:

```
14:55:51.996  "is now up"
14:55:52.008  rmtfs  /boot/modem_fs1
14:55:52.011  rmtfs  /boot/modem_fs2
14:55:52.012  rmtfs  /boot/modem_fsg
14:55:52.014  rmtfs  buffer base 0x97800000
14:55:52.810  tqftp  /readwrite/server_check.txt   (write)
14:55:52.826  tqftp  /readwrite/dhob.bin           (read)
14:55:52.874  tqftp  /readwrite/datablock/id_00    (read)
14:55:52.947  tqftp  /readwrite/datablock/id_01    (read)
14:55:53.023  tqftp  /readwrite/mot_rfs/imei_sv    (read)
14:55:53.113  tqftp  /readwrite/ota_firewall/ruleset (read)
14:55:53.137  tqftp  /readwrite/ota_firewall/ruleset (unlink)
14:55:53.211  fatal error, PC=c06c9b50
```

There is **no failed syscall** in either trace (no `ENOENT`, no short read,
no timeout), and the last AP interaction is 74 ms before the crash. The fault
is therefore modem-local and sits at the transition out of the RFS phase, not
inside it. (An earlier note in this file claimed "zero TFTP requests are
made"; that was an artifact of the services not being traced, and is wrong.)

Crash timing, all with identical `PC`:

| AP services available | crash after `is now up` | message |
|---|---|---|
| none | 40.5 s | `fatal error without message` |
| `rmtfs` | 12.5 s | `rf:...:PC=c06c9b50` |
| `rmtfs` + `pd-mapper` with empty map | 0.57 s | `rf:...:PC=c06c9b50` |
| `rmtfs` + `pd-mapper` + `tqftpserv` | 0.5807 s | `rf:...:PC=c06c9b50` |
| same, but under `strace` | 1.19 / 1.22 s | `rf:...:PC=c06c9b50` |

The trace slows the AP down, so the modem reaches the same fault later; the
address never changes.

#### Rejected explanations

Each of the following was tested and does not explain the crash:

* **Handover power votes.** `qcom_pas_handover()` was patched to keep
  `cx`/`px`/`xo`/`aggre2` enabled. The modem still dies at the same PC after
  0.58 s. `vreg_mss_cx`/`vreg_mss_px` in the DTS are `regulator-fixed` with
  `always-on` anyway, so only the clock votes were ever real.
* **Subsystem minidump.** SMEM item 602 decodes to a table with two populated
  entries (1 region at `0x85761098`, 18 regions at `0x860125e0`) and no entry
  for the modem, at boot *and* at handover. The firmware also uses a different
  layout than mainline expects (`status` is `0xDEEDDEED`, not 1;
  `encryption_status` is `"STRT"`, not `"DONE"`), which is why
  `qcom_minidump()` falls back to the ELF dump. Reading the region tables from
  the AP hangs the CPU (RCU stall), so the crash context is not reachable this
  way either.
* **`rmtfs_mem` placement / guard pages.** The stock node is
  `qcom,sharedmem-uio`; the fixed `0x97800000` region is the mainline
  replacement. The modem uses it successfully: `rmtfs` serves
  `modem_fs1/fs2/fsg` and the trace shows the modem obtaining the buffer base
  `0x97800000`.
* **Page-table words at `0xc00a1600`/`1a00`/`1e00`.** These are positions
  inside a contiguous run of 216 8-byte records (`0xc22221e0..0xc22228a0`,
  0xFF-padded) in which both words advance linearly (`+0x100` / `+0x200` per
  entry), so three consecutive entries would carry the same PPN — impossible
  for a page table. The run also contains a parameter block and `(start,end)`
  pairs, and `b11` reads 4-byte fields from it at unaligned offsets.
* **Handing the TZ the full 132 MiB carveout.** `modem.mdt` has
  `QCOM_MDT_RELOCATABLE` set, so `qcom_scm_pas_mem_setup()` is called with the
  image span (`0x7e00000`, 126 MiB). A test kernel that passed the DT region
  size (`0x8400000`) instead wedges the AP inside the SCM call — the CPU never
  returns and the device ends up in fastboot. The size argument is therefore
  not a usable lever; the hypothesis that mainline withholds 6 MiB from the
  modem cannot be tested this way, and there is no evidence for it.

#### What is left

The modem can read `0xa1a00000` and `0xa1e00000`, both far outside the
0x8b000000..0x92e00000 carveout, which rules out an XPU/assignment boundary as
the discriminator. The remaining difference between the three banks is the modem's **own MMU
mapping**. It is established outside the image: the resolver is the *only*
code reference to the bank table at `0xc22812a0`, and no function in headers
`b02`, `b04`, `b07`, `b09`, `b11` or `b26` maps `0xa1600000`/`0xa1a00000`/
`0xa1e00000`; the three watermark words are compile-time file initialisers
that no reachable code ever writes (the only aliasing path, `0xc06c9950`, has
an unreachable loop). The mapping must therefore come from the loader, the PAS
path in TZ, or the modem's own boot ROM — not from the firmware payload.

Wi-Fi stays blocked because the modem dies before it can load the WLAN
protection domain; the remaining difference to the vendor stack is IPA
(`qcom,ipa@1e00000`, `pas_id 0xf`), for which mainline 6.12 has no SM6150
glue.

### What the three "banks" actually are

The descriptor at `0xc4844bec` and its neighbourhood were mapped field by
field. `pool_init` (`0xc06c99dc`) fills it; the initialiser and the two
inlined accessors are the only code in the whole image that touches it.

```
0xc2281210  "/clk/mss/config_bus"
0xc228123c  "clk_bus_config"
0xc2281244  "navss"
0xc2281290  "clk_q6"
0xc22812c0  0x02000070          DAL device type
0xc22812a0  0xa1a00000 0xa1e00000 0xa1600000      the three arenas
0xc22812b0  0xa1a8a000 0xa1e87000 0xa1682000      their watermark pointers
0xc2281480  register-map object, payload at 0xc22814b0:
             (0x04100000, 0x8000, 0x0004_0004) x8
0xc2281750  "/vcs/vdd_mx"   0xc22817e0  "/vcs/vdd_mx/modem_hw"
0xc2281870  "/vcs/vdd_cx"
```

Two facts follow:

* Hardware is described with **physical** addresses in this firmware: the
  clock-controller map carries the SoC address `0x04100000` with a `0x8000`
  window and eight `(count, offset)` sub-blocks. The three arenas never
  appear with a physical sibling anywhere in the image.
* Therefore the arenas are the clock driver's own **heap**, 119 slots of
  4 KiB with a status word at `+0x10`, not MMIO. The fault is a plain
  missing mapping in the modem's own page tables, not a bus error on an
  unclocked block.

The real CMD-DB level maps were read from the running device (debugfs
`cmd-db`, no reboot needed):

```
cx.lvl   7 levels: 0x0000 0x0010 0x0040 0x0080 0x00c0 0x0100 0x0180
mx.lvl   5 levels: 0x0000 0x0010 0x00c0 0x0140 0x0180
mss.lvl  8 levels: 0x0000 0x0010 0x0040 0x0080 0x00c0 0x0100 0x0140 0x0180
gfx.lvl  9 levels: 0x0000 ... 0x01a0
```

An OPP table that does not match these values (e.g. levels above `0x0180`)
makes `rpmhpd` clamp a performance-state request to the wrong corner.

### Why the power-domain route is closed

Stock votes two rails at the modem node (`vdd_cx` = `cx.lvl`, `vdd_mss` =
`mss.lvl`, 100 mA each). mainline votes nothing: `qcom-rpmh-regulator` has no
ARC support, and `qcom-rpmhpd` only binds if the DT provides a
`qcom,<soc>-rpmhpd` node **with an OPP table** — without it
`dev_pm_opp_of_add_table_indexed()` returns `-EPROBE_DEFER`, which
`dev_err_probe()` deliberately hides, and the modem device stays deferred
forever (`supplier ...power-controller not ready`).

With the OPP table the domains appear and are attached. An earlier test
appeared to show that every ARC write hangs the AP; **that result was an
artifact of the build**, not of the hardware: `mdt_loader.o` had been left
over from an experiment and kept a `mem_size` argument that the rebuilt
`qcom_q6v5_pas.o` no longer passed, so `qcom_scm_pas_mem_setup()` received a
stack pointer as the size, returned `-EINVAL`, and the resulting page fault
stalled the machine. After forcing a rebuild of that object the picture is
completely different:

```
ODESSA_RPMHPD: power_on mss.lvl corner=7 enable_corner=1 (lvl=0x180) max=7 (lvl=0x180) levels=8
remote processor 4080000.qcom,mss is now up
fatal error received: :0:EX:kernel:0:rf:16e:PC=c06c9b50
```

The performance state reaches `rpmhpd` (corner 7 = TURBO), the synchronous
`rpmh_write(ACTIVE_ONLY)` returns, and the modem boots. It still dies at the
same PC 0.569 s later, so the `mss.lvl` vote alone does not change the fault.

Lesson for this tree: never restore a source file with `cp -a`/`mv` without
touching it, or `make` keeps the stale object and silently produces a mixed
ABI.

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

The guard stops at >=60% and resumes at <=40%. Since the mainline kernel runs
no QG fuel gauge, the SDAM value above is a frozen bootloader anchor and not a
live SoC; see "Battery guard rebuilt on the OCV curve (2026-11-11)" below.

### Battery guard rebuilt on the OCV curve (2026-11-11)

The SDAM msoc byte only changes while the vendor QG driver runs, so on
mainline it stays at 100% for the whole uptime. The old guard disabled
charging at boot (`cap=100 >= 60`) and re-enabled it only when the fallback
triggered at <=3.65 V, so the pack silently drained and cycled far below the
intended band.

`rootfs/battery-guard.sh` now estimates the SoC from the relaxed `vbat_sns`
voltage with the vendor OCV table of the installed cell (kz40-atl-3600mah,
`qcom,pc-temp-v1-lut`, 25 C column, `kernel/dts/abl-merged-gcc.dts`) and only
trusts the gauge byte when it agrees within 8 points. While charging the
terminal voltage is dominated by IR drop, so charging runs in pulses
(240 s on, 180 s off); the 60% stop decision is made on the relaxed voltage at
the end of the rest, and charging resumes at <=40%. The state machine lives in
`/run/battery-guard.state` (`/tmp` when the busybox init runs without /run).

```
4.023 V -> 67 %   3.900 V -> 55 %   3.830 V -> 41 %   3.800 V -> 29 %
rootfs/test-battery-guard.sh        PASS (fake sysfs, fixed NOW values)
check-rootfs.sh                     runs that test and compares the installed
                                    guard with rootfs/battery-guard.sh
```

### Charge control restored (2026-11-08)

`drivers/power/supply/odessa_chg.c` existed only in the reference tree, so the
release kernel had no `charge_enable` node at all and the guard exited at its
first `[ -w "$CHG" ]` check without a trace. The driver now comes from
`kernel/patches/0003-odessa-charger.patch` and exposes the PM6150
`CHARGING_ENABLE_CMD` (0x1042 bit 0) plus `charge_inhibit` and `status`.

```
path    /sys/devices/platform/soc/c440000.qcom,spmi/spmi-0/0-00/\
        c440000.qcom,spmi:qcom,pm6150@0:odessa-chg/charge_enable
cap     71 %   vbat 4.093 V
0       status 7 (DISABLE_CHARGE)
1       status 3 (FAST_CHARGE)
```

Round trip verified with the 30 s timer: write 1, the timer fires, the guard
writes 0 and the PMIC reports 7 again.

### QuRT's own physical memory pools (static, from `modem.b17`)

The generated QuRT configuration lives in `b17` (VA `0xc2453100` onwards) as a
table of entries with a 32-byte name followed by fields, stride `0xa0`:

| Pool | field 0 | field 1 |
|---|---|---|
| `DEFAULT_PHYSPOOL` | `0x0008b000` = PFN → **0x8b000000** | `0x07e00000` = **126 MiB** |
| `HWIO_POOL` | `0x00009000` → 0x09000000 | `0x01000000` = 16 MiB |
| `TCM_POOL` | `0x00004400` → 0x04400000 | `0x00100000` = 1 MiB |
| `AMSS_MEM_HEAP_POOL` | `0xffffffff` (dynamic) | `0x00340000` = 3.25 MiB |
| `MODEM_MEM_HEAP_POOL` | `0xffffffff` (dynamic) | `0x00c40000` = 12.25 MiB |
| `CLADE_DICT` | `0x000045d2` → 0x045d2000 | `0x00006000` = 24 KiB |

This settles the `pas_mem_setup()` size question **statically**: QuRT's default
pool is exactly 126 MiB at 0x8b000000, which is what mainline already passes
(`max_addr - min_addr = 0x7e00000`). The 132 MiB from the DT carveout are not
part of QuRT's pool, so "handing the TZ 132 MiB" cannot be the fix.

The three arenas (`0xa1a00000`, `0xa1e00000`, `0xa1600000`) do **not** appear
in this table — they are not physical pools.

The table is consumed by a first-fit allocator at `0xc065e0d0`, which walks
entries with `r4 = 0xc2453100`, adds `0x20` (past the name), scales the index
by `0x14` (`<<3` → stride `0xa0`) and compares `size >> 12` in pages.

Open: with the image occupying 125.6 MiB of the 126 MiB default pool, the two
dynamic heaps (15.5 MiB total) cannot come from it — how `pfn = 0xffffffff`
is resolved is the next thing to decode.

### QuRT pool table: what `pfn = 0xffffffff` means (static, no flash)

The static physpool table in `modem.b17` (VA `0xc2453100`, stride `0xa0`)
contains a seventh entry that was previously missed:

| Pool | pair 0 |
|---|---|
| `QURTOS_ISLAND_POOL` @ `0xc24534c0` | `0x00007d80` → PA `0x07d80000`, `0x00080000` (512 KiB) |

That resolves the `0xc7d80001` values in the boot table of `modem.b02`: they
are island virtual addresses (`0xc0000000 + PA`), not addresses in the
15.4 MiB NOBITS segment `b30`. The sum of the type-3 record lengths is
`0x7d000`, which fits the 512 KiB island pool exactly.

Every entry has room for 16 `(pfn,size)` pairs; statically only pair 0 is
populated. The pool initialiser at `0xc0657bd0` walks this table, creates a
pool object per entry (`0xc065ddf0`, inserted into the list at `0xc50bdaa8`)
and then iterates the pairs:

```
c0657d10:  r3 = memw(r17+r23)          ; pfn of pair i
c0657d14:  if (cmp.eq(r3.new,#-1)) jump ; pfn == 0xffffffff -> skip pair
```

So `0xffffffff` is a sentinel meaning "this pool has no static region".
`AMSS_MEM_HEAP_POOL` (3.25 MiB) and `MODEM_MEM_HEAP_POOL` (12.25 MiB) are
therefore created without any pages from the image; their memory has to be
added at runtime.

The table itself is never patched: scanning all segments for the immediate
encodings of `0xc2453100`/`0xc24530c0` finds only the three read sites in
`b11` (0x1adc1c, 0x1b40e0, 0x1b8fac); `b04`/`b07` reference only the
runtime memory-map globals `0xc2452080` and the free-list pointer
`0xc24526c0`.

`HLOS_PHYSPOOL` (`b16` @ `0xc121b9e1`) has exactly one code reference:
`0xc065e27c` inside handler `0x32` of the `memory.c` method table, where it
is passed to the word-wise string compare `0xc0667ac0`. The function at
`0xc065dd90` does **not** reference it; that address belongs to the reclaim
routine `0xc065dd00`, which only logs
`"While reclaiming %x000-%xfff, ..."`.

### Full executable-segment sweep and the one legitimate table write

All segments with execute permission were disassembled (`b02`, `b04`, `b07`,
`b09`, `b11`, `b26`; dumps under `.re/dumps/`). This corrects an earlier
address assumption: `VA = PA + 0x35000000` only holds for segments #2..#25.
The tail segments have unrelated VAs (`b26` = 0x1e400000, `b29` = 0xa2100000,
`b30` = 0xa2179000), so the 15.4 MiB NOBITS reserve is at
0xa2179000..0xa30d4000 — and that range is referenced **nowhere** in the code.

The pool table has exactly one writer, and it is guarded by a string compare:

```
c0657bdc..c0657c0c   build "DEFAULT_PHYSPOOL" on the stack
c0657cbc:  p0 = cmp.gtu(r2,#0x1f); if (p0) jump 0xc0657cdc
c0657cc0:  r3 = memb(r22+0)          ; stack string byte
c0657cc4:  if (r3 == 0) jump 0xc0657cdc
c0657cd0:  r4 = memb(r17+r2)         ; entry name byte
c0657cd4:  if (r4 == r3) jump 0xc0657cbc
c0657cd8:  jump 0xc0657cec           ; mismatch: skip the store
c0657cdc:  r2 = memw(0xc2452090)
c0657ce4:  r2 = lsr(r2,#0xc)
c0657ce8:  memw(r17+0x20) = r2       ; only DEFAULT_PHYSPOOL pair0.pfn
```

So only `DEFAULT_PHYSPOOL` gets its start PFN rewritten to the runtime base
(`0xc2452090 >> 12`). Every other entry — including
`AMSS_MEM_HEAP_POOL` and `MODEM_MEM_HEAP_POOL` — keeps its static content,
and `0xffffffff` stays `0xffffffff` and is skipped by the pair loop at
0xc0657d14. The `size` fields are never written at all.

`0xc2452090` itself has no writer anywhere in the image: all seven references
are loads, no segment contains a data word pointing at it, and GP-relative
access is excluded because `gp = 0xc50b6000` (segment b20). The value must be
supplied by the loader/PAS path outside these segments.

### Reclassification: the three 4 MiB windows are the HWIO BaseMap arenas

The windows C=0xa1600000, A=0xa1a00000, B=0xa1e00000 are not heap banks. The
registration blob at VA 0xc0b74a34 holds a pointer to the struct at
0xc22812c0, thirteen function pointers (0xc06c9b60..0xc06c9de0), and is
immediately followed by the literal string `"BaseMap"` and the messages

```
HWIO: Unable to find "%s"
HWIO: Unable to find address "0x%08x"
HWIO mapping failed: %s @ 0x%08x
HWIO mapping already exists: %s @ 0x%08x
HWIO mapping: %s, physical address 0x%08x, virtual address 0x%08x
```

The mapper at 0xc06c9fc8 prints exactly these strings and calls 0xc06a56ec
(physical -> virtual) and 0xc06a57b4 (virtual arena). The resolver
0xc06c9af4 walks A, B, C and reads a tag word at `base + index*0x1000 + 0x10`;
bank C's page is unmapped, which is the fault at 0xc06c9b50.

The QuRT pool layer is separate and now fully mapped:

- `0xc065f310(body, pfn, npages)` is the only page installer; it stores
  `{pfn, npages}` in a sorted, non-overlapping list at `body+0xa8`, treats
  `npages == 0` as a silent no-op and returns 0 on success.
- `body` is `pool+0x18` (0xb4 bytes: 21 order buckets plus the sorted list).
- `0xc065e560` is the range allocator over those buckets, not an installer.
- The pool initialiser installs only pairs whose pfn is not `0xffffffff`
  (0xc0657d14), so AMSS/MODEM stay empty and an allocation from them fails.
- `DYN_MEM_PHYS_POOL` (string 0xc0b1d1d8) is created at runtime (0xc06a2bfc)
  and is the dynamic region provider; the AMSS heap (0xc06a36b4) is created
  by name and allocated from its pool, failing only with a log message.

## Modem blocker: consolidation (2026-11-08 evening)

Everything below was measured on the device or read from the shipped
artefacts; no firmware blob was modified and no vendor image was used.

### Instrumentation added

`/dev/mem` is unusable here (`CONFIG_STRICT_DEVMEM=y` returns `EFAULT` for
every reserved region, including SMEM). Three small out-of-tree tools were
built instead (sources under `work/odessa/probe/`, loaded with a static
`init_module(2)` helper because the rootfs has no kmod):

* `odessa_probe` — read-only physical window, debugfs `odessa_probe/mem`,
  parameters `mem_base`/`mem_size`/`mem_mode` (0 = `ioremap`, i.e.
  Device-nGnRnE; 1 = `memremap(MEMREMAP_WB)`). Mapping *type* matters: reading
  normal RAM as Device memory is what wedged the interconnect during the first
  SMEM attempts.
* `smem_dump` — enumerates and snapshots SMEM items through `qcom_smem_get()`,
  i.e. only the ranges the driver itself validates. Raw page reads are not
  safe: unused partition tails and partitions without APPS as a host (for
  example `p8` = modem+ADSP) are not AP-readable and hang the bus.
* `qrtr_lookup` — AF_QIPCRTR client; protocol derived from `net/qrtr/ns.c`
  (`NEW_LOOKUP` with service 0 / instance 0 to `{node 0, QRTR_PORT_CTRL}`;
  `server_match()` treats service 0 as wildcard; an all-zero reply ends the
  listing). `bind()` returns `EINVAL` (`qrtr_bind` requires
  `sq_node == ipc->us.sq_node`), so the tool relies on autobind at the first
  `sendto`; the local node id is 1.

### SMEM layout on this device

`struct smem_proc_comm` is 16 bytes, so `initialized` sits at `0xC0` and the
global `toc[]` starts at `0xD0` (it is empty here). The partition table
(`$TOC`, last 4 KiB of the region = `0x861ff000`, 11 entries of 0x30 bytes)
shows the interesting partitions:

```
p7  0x11d000 0x07c000  hosts APPS+modem   508 KiB
p8  0x0fd000 0x020000  hosts modem+ADSP   not AP-readable
p9  0x001000 0x0fc000  hosts global       holds the boot information
```

Item 421 (the crash reason) is resolved through the *global* partition:
`qcom_smem_get(QCOM_SMEM_HOST_ANY, 421)` skips the host branch and uses
`global_partition` -> `qcom_smem_get_private()`, i.e. a private entry with a
numeric item id.

### Item inventory after a crash

Host 1 (modem) holds exactly six items: `428`/`435` (SMP2P `$SMP`), `478`,
`479` (16 KiB certificate chain), `480` (16 KiB RFS/transport trace) and `497`
(8 KiB, all zero). The global partition holds `78`, `79` (40 kB binary), `80`,
`81`, `135`, `136` (the `MOTOSMEM` key/value block), `137`, `402`, `403`,
`404`, `417`, `421`, `469` (bootloader version string), `473`, `474`.

Searching every captured item for `hwio`, `dalsys`, `mapping`, `pool`, `qurt`
or `arena` yields **no hit**. Item 421 is 256 bytes and contains only
`:0:EX:kernel:0:rf:16e:PC=c06c9b50` followed by leftovers — no fault address,
no `LR`, no `SP`. The `HWIO mapping failed: %s @ 0x%08x` message therefore
never reaches SMEM; it stays in the modem's own RAM.

Item 480 is still a witness for ordering: the trace begins at boot
(`IPCRTR`, `glink_ssr`, `tms/pdr_enabled`, `SSM_RTR_MODEM_APPS`), covers
`/boot/modem_fs1|fs2|fsg`, `server_check.txt`, `apr_voice_svc`, `apr_apps2`,
`LOOPBACK_CTL_MPSS`, `dhob.bin`, `datablock/id_00|id_01`, `mot_rfs/imei_sv`,
and ends exactly with `/readwrite/ota_firewall/ruleset` (last non-zero byte at
offset `0x191b`). Nothing follows: the crash sits in the step after the
firewall ruleset was consumed, i.e. in the data-path bring-up.

### Boot chain and stock comparison

* The SBL1 log was recovered from the `MOTOSMEM` value block
  (`sbl1_log_buf` = physical `0x85e11040`, size `0x1fc0`) and read with
  `odessa_probe`. SBL1 loads APDP, OEM_MISC, QTI_MISC, AOP, QSEE devcfg, QSEE,
  QHEE and APPSBL, then logs `SBL1, End`. **It never touches the modem** — no
  PIL step, no MMU windows — so the arena mappings cannot come from the
  bootloader.
* The stock DTB was extracted from `boot_a` (FDT at file offset `0x2486000`)
  and decompiled. Its `qcom,mss@4080000` node matches the running one in every
  relevant value: `qcom,pas-id = 4`, `qcom,smem-id = 0x1a5` (421),
  `qcom,minidump-id = 3`, `qcom,ssctl-instance-id = 0x12`,
  `qcom,firmware-name = "modem"` and `memory-region` =
  `modem_region@8b000000` with `0x8400000` (132 MiB).
* `modem.mdt` and `modem.b11` are byte-identical in slot A and slot B
  (md5 compared), so there is no alternative firmware variant on the device.
* `drivers/soc/qcom/mdt_loader.c` zeroes the difference between `p_memsz` and
  `p_filesz` (lines 384-385), so stale DRAM in the NOBITS segments is not the
  explanation either.

### The power/clock route is closed twice over

* `drivers/pmdomain/qcom/rpmhpd.c` has no sm6150 match (0 hits) and the DT has
  no `power-controller` node; `pm_genpd_summary` is empty and no `rpmhpd`
  driver is bound. Every earlier `proxy_pd_names` / `mss.lvl` experiment was
  therefore a **no-op** — there is nothing for those votes to act on.
* The clock driver that does bind for sm6150 is `gcc-sdmmagpie` (compatible
  `qcom,gcc-sdmmagpiesyscon`; upstream has no `gcc-sm6150.c`), and it
  registers **no GDSC tables** (`grep -c GDSC` = 0). There are no
  AP-switchable power domains on this platform either.
* `clk_summary` (208 clocks, GCC bound) reports `ipa` with rate 0 and
  enable count 0: the IPA block is not brought up by the AP. mainline has no
  sm6150 IPA glue (`drivers/net/ipa`: 0 hits, `CONFIG_QCOM_IPA=m` unloaded),
  so this cannot be fixed from Linux as things stand.

### Why Wi-Fi cannot bypass the modem

The modem firmware carries `wlanmdsp` (`modem.b03`, `b16`, `b26`) and `WlFw`
(`b21`): the modem loads the WLAN firmware through WLFW. A dead modem means no
WLAN firmware, no matter what the AP does. (`bdwlan.*` board data is present in
the firmware set; `wlanmdsp.mbn` itself is not in the image directory that the
AP serves over RFS.)

### Closed channels

| Channel | Result |
|---|---|
| SMEM items (all, via the driver) | no `HWIO`/`DALSYS` text; item 421 = PC only |
| Diag / QRTR | no diag service; modem services appear only ~100 ms before the crash |
| Modem carveout | not AP-readable (bus hang, even in `crashed` state) |
| TZ log (`0xaefa2000`, 0x30000) | all zero |
| SBL1 log | SBL1 does not load the modem |
| Shadow registers | not implemented in this kernel |
| AP configuration | stock-identical (region, pas id, smem id, minidump, firmware, BSS zeroing) |
| Power / clock | no GDSCs, no sm6150 `rpmhpd`, no sm6150 IPA support |

The crash mechanism itself is fully explained: `0xc06c9af4` probes the three
arenas A -> B -> C, reading a tag word at `base + idx*0x1000 + 0x10` with no
bounds check; A and B are mapped, C is not, and C's window is created outside
the image. What remains unknown is *which* register block is being looked up in
C and *which* component establishes the arena windows (TZ's PAS runtime or the
modem's boot ROM).

### Appendix: the `BaseMap` table rebuilt from the raw segments

The disassembly dumps elide zero runs, which made several pre-map VAs look
like "not printed". Re-read from the raw segments (`modem.b16`/`modem.b17`)
**every** record has a non-zero pre-map VA, and the mapper therefore never
creates a mapping for any of them:

```
#  name                                  phys        size        pre-map VA
0  CLK_CTL                               0x00100000  0x00200000  0xa0000000
1  BOOT_ROM                              0x00300000  0x00100000  0xa0200000
2  RAMBLUR_PIMEM                         0x00610000  0x00008000  0xa0310000
3  OCIMEM_WRAPPER_CSR                    0x00618000  0x00006000  0xa0418000
4  SPDM_WRAPPER_TOP                      0x00620000  0x00008000  0xa0520000
5  SECURITY_CONTROL                      0x00780000  0x00010000  0xa0680000
6  PRNG_CFG_PRNG_TOP                     0x00790000  0x00010000  0xa0790000
7  PERIPH_SS_SDC1_SDCC5_TOP              0x007c0000  0x00020000  0xa08c0000
8  QUPV3_0_QUPV3_ID_1                    0x00800000  0x000c7000  0xa0900000
9  QUPV3_1_QUPV3_ID_1                    0x00a00000  0x000c7000  0xa0a00000
10 QC_DCC_CSAFB9399A                     0x010a0000  0x00010000  0xa0ba0000
11 QM_MPU_CFG_QM_MPU_WRAPPER             0x010bc000  0x00001200  0xa0cbc000
12 CONFIG_NOC_WRAPPER                    0x01500000  0x00028000  0xa0d00000
13 SYSTEM_NOC                            0x01620000  0x00018080  0xa0e20000
14 AGGRE_NOC_AGGRE_NOC                    0x016e0000  0x00060000  0xa0fe0000
15 UFS_MEM_UFS_1LANE_REGS                0x01d80000  0x00020000  0xa1180000
16 CRYPTO0_CRYPTO_TOP                    0x01dc0000  0x00040000  0xa12c0000
17 IPA_0_IPA_WRAPPER                     0x01e00000  0x00100000  0xa1300000
18 CORE_TOP_CSR                          0x01f00000  0x00100000  0xa1400000
19 TLMM                                  0x03400000  0x00c00000  0xa1500000
20 MODEM_TOP                             0x04000000  0x003c8000  0xeb000000
21 MSS_L2_CFG                            0x045a0000  0x00001000  0xa21a0000
22 QDSS_SOC_DBG                          0x06000000  0x02000000  0xa2200000
23 DDR_SS                                0x09000000  0x00800000  0xa4200000
24 AOSS                                  0x0b000000  0x04000000  0xa5200000
25 AOP_SS_MSG_RAM_START_ADDRESS           0x0c300000  0x00100000  0xa9200000
26 MODEM                                 0x10000000  0x02000000  0xec000000
27 MSS_NAV_MS_MPU_CFG_MPU32Q2N7S1V0_8_CL36M  0x14400000  0x00001400  0xa9300000
28 A1_NOC_MS_MPU_CFG_MPU32Q2N7S1V0_8_CL36M3  0x14402000  0x00001400  0xa9402000
29 A2_NOC_MS_MPU_CFG_MPU32Q2N7S1V0_16_CL36M  0x14404000  0x00001800  0xa9504000
30 BOOT_IMEM_SS_MPU_CFG_MPU32Q2N7S1V0_4_CL3    0x14406000  0x00001200  0xa9606000
31 WCSS_WRAPPER                          0x18800000  0x00800000  0xa9700000
```

Two consequences: the three 4 MiB arenas are *not* part of this static table
(they are the driver's heap, see above), and the TLMM record's window
`0xa1500000..0xa2100000` overlaps all three arenas — so TLMM is not mapped as
one 12 MiB block in this run, otherwise the third probe could not fault.

## Wi-Fi (WCN3990), 2026-11-10

Checks performed on the device (mainline 6.12, slot b), after a clean reboot:

```text
$ iw dev wlan0 link
Connected to <AP-BSSID> (on wlan0)
        SSID: <SSID>
        freq: 2462.0
        signal: -48 dBm
        rx bitrate: 72.2 MBit/s MCS 7 short GI
        bss flags: short-preamble short-slot-time
        dtim period: 1
        beacon int: 100

$ wpa_cli -i wlan0 status
wpa_state=COMPLETED
key_mgmt=WPA2-PSK
pairwise_cipher=CCMP

$ udhcpc -i wlan0
udhcpc: lease of <LAN-ADDR> obtained from <LAN-GW>

$ ping -c 20 <LAN-GW>
20 packets transmitted, 20 received, 0% packet loss (13-21 ms)

$ cat /sys/class/remoteproc/remoteproc0/state
running
```

Kernel evidence:

```text
ath10k_snoc 18800000.qcom,icnss: vdev-start-response status 0x00000000
ath10k_snoc 18800000.qcom,icnss: mac vdev 0 up (associated) bssid <AP-BSSID> aid 2
```

Negative checks that would indicate regressions:

```text
# must be absent:
dmesg | grep "failed to transmit management frame via WMI"   # -95 => feature bit 18 missing
dmesg | grep "firmware crashed"                               # => quiet-mode guard missing
dmesg | grep "vdev-start-response reports status error"       # => BSSID peer patch missing
```

`make check-rootfs` asserts the matching rootfs content (feature byte `0x0c`,
modules, units, firmware, regdb, tools).

## Bluetooth (WCN3990), 2026-11-11

Verified on a freshly installed image (`flash-odessa.sh` -> `INSTALL_OK`),
without any manual step after the reboot:

```text
$ systemctl --failed --no-legend | wc -l
0

$ hciconfig -a
hci0:   Type: Primary  Bus: UART
        BD Address: 08:AA:55:39:A2:9C  ACL MTU: 1024:7  SCO MTU: 60:8
        UP RUNNING PSCAN ISCAN
        RX bytes:1451 acl:0 sco:0 events:107 errors:0

$ bluetoothctl show
Controller 08:AA:55:39:A2:9C (public)
        Manufacturer: 0x001d (29)
        Version: 0x0a (10)
        Name: odessa
        Powered: yes

$ dmesg | grep -E "setting up wcn399x|QCA "
Bluetooth: hci0: setting up wcn399x
Bluetooth: hci0: QCA controller version 0x01400201
Bluetooth: hci0: QCA Downloading qca/crbtfw21.tlv
Bluetooth: hci0: QCA Downloading qca/crnv21.bin
Bluetooth: hci0: QCA setup on UART is completed

$ bluetoothctl --timeout 15 scan on; bluetoothctl devices
Device <PHONE-MAC> Zero              # Icon: phone, RSSI -61

$ btmgmt pair -c 3 <PHONE-MAC>
hci0 <PHONE-MAC> new_link_key type 0x07 store_hint 1
Paired with <PHONE-MAC> (BR/EDR)
```

`bluetoothctl info <PHONE-MAC>` afterwards reports
`Paired: yes | Bonded: yes | Connected: yes`.

Three pieces beyond the mainline drivers are required and shipped here:

- `qcom,geni-fifo` plus `kernel/patches/0007`: this vendor DTB exposes no QUP
  DMA path (no `dmas`, no interconnect provider), and the first QUP DMA
  transmit hard-locks the SoC. The driver then uses the FIFO primitives it
  already uses for its console.
- `local-bd-address` in the BT node plus `kernel/patches/0008`: the chip
  reports no valid BD address, so `hci_dev_setup_sync()` would mark the
  controller `HCI_UNCONFIGURED` and `hci_dev_open()` would fail with
  `-EOPNOTSUPP` (mgmt/hcitool hide such a device, `hciconfig` shows `DOWN RAW`).
  The serdev layer now sets `HCI_QUIRK_USE_BDADDR_PROPERTY`, so the address is
  programmed by the driver's `set_bdaddr` during the setup.
- `bt-stack`, `bt-addr` and `bt-agent` units: the combo chip only answers once
  `pm6150l_l1/l2` are in their vendor windows (`wlan-rails`) and Wi-Fi
  initialised the chip (`odessa-wlan`); `bt-agent` keeps a default
  `NoInputNoOutput` agent registered, otherwise a phone pairing fails with
  `0x05 (Authentication Failed)` / "PIN or Passkey wrong".

Statistics after the pairing test: `RX bytes` in the hundreds of kB (firmware
download), `acl:56/53` link-layer traffic with the phone.

Limits: see `docs/KNOWN-LIMITATIONS.md` (BD address from the DTS, warm-reboot
pulse behaviour, no SCO audio test).
