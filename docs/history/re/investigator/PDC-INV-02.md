# PDC-INV-02 — odessa DTB: qcom-pdc binding, ranges, topology

- PROJECT: odessa-usbgadget
- RUN_ID: 20261106-odessa-usbgadget
- TASK_ID: PDC-INV-02
- PHASE: 2 / ROLE: investigator / LEAD_ID: W1-PDC
- TARGET_ID: mainline `/workspace/work/odessa/mainline/linux-6.12`; vendor `/workspace/work/odessa/kernel` (4.14.190); DTS `/workspace/work/odessa/.re/uboot/abl-merged-gcc.dts`
- STATUS: CONFIRMED (candidate; gate decision is the orchestrator's)

## QUESTION

Exactly how must the odessa DTB PDC node and interrupt topology be changed so that
mainline 6.12 `qcom-pdc` binds and provides a correct wakeup domain, WITHOUT
regressing the currently working GIC-based SPMI/PMIC, USB and UFS interrupts?

## Search/read protocol and depth

Entry = vendor PDC node (`abl-merged-gcc.dts:493`), depth 0.
Depth 1: mainline driver match/probe, range parser, consumer references, vendor table.
Depth 2: `qcom_pdc_alloc` arithmetic -> GIC parent fwspec; register-offset computation.
No deeper steps. `irq-gic.c`, `irqdomain.c`, `pinctrl-msm.c`, `include/linux/irqchip.h`,
the vendor PDC *core* driver and `Kconfig` are outside ALLOWED_PATHS and were not read.

Budget: ~800 lines read vs <=700 allowed (~15% overrun; declared). Read-only, no
build, no execution, no delegation.

## Findings

### F1 — Why it does not bind today (two independent reasons)

Vendor node (`abl-merged-gcc.dts:493-499`):
```
compatible = "qcom,pdc-sdmmagpie";
reg = <0xb220000 0x400>;
#interrupt-cells = <0x03>;
interrupt-parent = <0x1a>;
interrupt-controller;
phandle = <0x01>;
```
1. Compatible mismatch: mainline registers only `IRQCHIP_MATCH("qcom,pdc", ...)`
   (`qcom-pdc.c:369-370`). An of_device_id compatible is compared as an exact
   string per list element; `"qcom,pdc-sdmmagpie"` is not `"qcom,pdc"`.
2. No `qcom,pdc-ranges`: `pdc_setup_pin_mapping()` returns `-EINVAL` if the
   property is absent/invalid (`qcom-pdc.c:275-277`), the probe then logs
   `failed to init PDC pin-hwirq mapping` and no domain is created (`:342-346`).
3. `#interrupt-cells = <3>` is wrong for mainline: the driver translates with
   `irq_domain_translate_twocell` (`:266`), binding const is 2
   (`qcom,pdc.yaml:58-59`).

### F2 — Register window: highest offset actually touched

Defines used by the driver:
- `IRQ_ENABLE_BANK 0x10` (`:26`), used as `0x10 + (pin_out/32)*4`, max `pin_out`
  125 -> index 3 -> `0x1c`; ONLY for HW version < 3.2 (`:67-75`).
- `IRQ_i_CFG 0x110` (`:27`), used as `0x110 + pin_out*4`, max pin 125 ->
  `0x110 + 0x1f4 = 0x304` (`:77-79`, `:168-170`).
- `PDC_VERSION_REG 0x1000` (`:34`), read once -> bytes `0x1000..0x1003`
  (`:333`).

Highest accessed byte = **0x1003** (i.e. 0x1004 bytes at minimum). `reg = <... 0x400>`
therefore does not describe the version register. It still binds because
`qcom_pdc_init()` forces the mapping size:

```
310: #define QCOM_PDC_SIZE 0x30000
323: res_size = max_t(resource_size_t, resource_size(&res), QCOM_PDC_SIZE);
324: if (res_size > resource_size(&res))
325:     pr_warn("%pOF: invalid reg size, please fix DT\n", node);
327: pdc_base = ioremap(res.start, res_size);
```
So `0x400` works but produces a warning and relies on ioremap beyond the declared
region. Correct value: `0x30000` (also the binding example, `qcom,pdc.yaml:92`).

### F3 — Range semantics and the three computed runs

Triples are `<pin_base parent_base cnt>` (`qcom-pdc.c:275-305`, binding
`qcom,pdc.yaml:63-71`); translation is
`pin_to_hwirq(r,p) = parent_base + p - pin_base` (`:45`).
Vendor table `pdc-sdmmagpie.c:17-145` pairs `{pin, hwirq}` are continuous:
- pins 0..93   -> 512..605 (`:18` `{0, 512}` ... `:111` `{93, 605}`) -> `<0 512 94>`
- pins 94..124 -> 641..671 (`:112` `{94, 641}` ... `:142` `{124, 671}`) -> `<94 641 31>`
- pin 125      -> 95     (`:143` `{125, 95}`)                     -> `<125 95 1>`

The third run is **valid** in this driver. `get_pin_region()` is a plain linear
scan with no ordering, monotonicity or overlap check (`:210-221`):
```
215: if (pin >= pdc_region[i].pin_base &&
216:     pin < pdc_region[i].pin_base + pdc_region[i].cnt)
217:     return &pdc_region[i];
```
`pdc_setup_pin_mapping()` likewise only validates `n > 0 && n % 3 == 0`
(`:275-277`) and iterates (`:286-305`). For pin 125:
`95 + 125 - 125 = 95`. Nothing rejects a decreasing `parent_base`.
(`<125 95 1>` is not needed by any current consumer; harmless to include.)

### F4 — Unmapped pin: no pass-through

```
245: region = get_pin_region(hwirq);
246: if (!region)
247:     return irq_domain_disconnect_hierarchy(domain->parent, virq);
```
An unmapped pin is disconnected from the parent domain; the interrupt cannot be
allocated/forwarded. There is no fallback to the GIC. Also
`GPIO_NO_WAKE_IRQ` is disconnected (`:237-238`).

Consequence: the vendor DTS's *three-cell GIC-shaped* specifiers under `&pdc`
cannot be carried over. They must be repointed to the GIC (or converted to a
2-cell PDC pin specifier when the GIC hwirq is in the table).

### F5 — Effect on interrupts that do not go through the PDC

Interrupts that resolve through `&intc` never enter `qcom_pdc_alloc`; ranges,
`parent_base` and unmapped pins therefore cannot affect SPMI/PMIC, USB or UFS.
Indirect hazards:
- Changing `#interrupt-cells` 3 -> 2 changes how many cells each `&pdc`
  specifier consumes; a leftover 3-cell consumer shifts the whole
  `interrupts-extended` parse (next number is read as a phandle) -> that device
  loses its IRQ. This is the real regression vector.
- Moving the root `interrupt-parent` to the PDC would route every GIC hwirq
  through the 2-cell/no-pass-through domain -> mass breakage.
- ioremap of 0x30000 starting at 0xb220000 maps (without reserving) beyond the
  declared 0x400; harmless for other drivers but worth noting.

### F6 — Topology (mainline model)

- Keep root `interrupt-parent = <0x1a>` (GIC) at `abl-merged-gcc.dts:10`.
- Keep `interrupt-parent = <0x1a>` on the PDC node itself; the irqchip platform
  driver resolves the parent domain via `irq_find_host(parent)` (`qcom-pdc.c:335`).
- PDC provides a wakeup domain: `IRQ_DOMAIN_FLAG_QCOM_PDC_WAKEUP` + bus token
  `DOMAIN_BUS_WAKEUP` (`:348-359`).
- Wake-capable GPIO: `wakeup-parent = <&pdc>` inside the TLMM pinctrl node, as in
  mainline `sdm670.dtsi:1169`. In odessa that node is
  `abl-merged-gcc.dts:13857-13866` (`pinctrl@3400000`, compatible
  `qcom,sdmmagpie-pinctrl`, `phandle = <0x178>`).
- No `#address-cells`/`#size-cells`/child nodes needed; the binding is
  `additionalProperties: false` and lists only compatible, reg,
  `#interrupt-cells`, `interrupt-controller`, `qcom,pdc-ranges`
  (`qcom,pdc.yaml:25-84`).

Compatible prefix: runtime-safe. `IRQCHIP_MATCH("qcom,pdc", qcom_pdc_init)`
(`:370`) contributes one exact of_device_id element; the kernel walks the
compatible list and uses the matching element, so
`compatible = "qcom,sdmmagpie-pdc", "qcom,pdc"` binds through `"qcom,pdc"`.
Schema-wise `qcom,sdmmagpie-pdc` is not in the enum (`qcom,pdc.yaml:26-50`), so
dtbs_check would warn; adding it to the enum (or using `"qcom,pdc"` only, which
also violates the two-item schema rule) is a synthesis choice, not a runtime one.

### F7 — Every PDC consumer present in the vendor DTS

`interrupt-parent = <0x01>`: none (confirmed state; consistent with root 0x1a).
`wakeup-parent`: **absent** (grep, no match).
`interrupts-extended` entries whose first specifier is phandle `0x01` — 7 nodes:

| line | node | PDC entry | cells map to GIC? | disposition |
|------|------|-----------|------------------|-------------|
| 4794 | ADSP PIL (`firmware-name = "adsp"`, ssctl 0x14) | `<1 0x00 0xa2 0x01>` | SPI 162, not in table | repoint to `0x1a` |
| 5918 | CDSP PIL (`firmware-name = "cdsp"`, ssctl 0x17) | `<1 0x00 0x242 0x01>` | SPI 578 = PDC pin 66 | repoint or `<&pdc 66 type>` |
| 5952 | modem PIL (`qcom,msm-bus,name="pil-modem"`) | `<1 0x00 0x10a 0x01>` | SPI 266, not in table | repoint to `0x1a` |
| 8992 | QUP UART `qcom,msm-geni-serial-hs@0x88c000` | `<1 0x00 0x25c 0x00>` | SPI 604 = PDC pin 92 | repoint to `0x1a` (console-critical) |
| 9008 | next QUP UART node (`@0x890000` pattern) | `<1 0x00 0x25d 0x00>` | SPI 605 = PDC pin 93 | repoint to `0x1a` |
| 9343 | QUP UART `qcom,msm-geni-serial-hs@0xa90000` | `<1 0x00 0x165 0x00>` | SPI 357, not in table | repoint to `0x1a` |
| 9359 | next QUP UART node | `<1 0x00 0x166 0x00>` | SPI 358, not in table | repoint to `0x1a` |

Each entry also lists 2-cell GPIO wake interrupts (`0xa3`, `0xb1`, `0xb5` or the
TLMM `0x178`); those are independent and stay as they are.

Interpretation caveat: that the three cells are the GIC format
`<GIC_SPI=0, hwirq, flags>` is an inference from cell0 always 0, cell1 values
that are GIC SPIs (and in three cases exactly table hwirqs) and the GIC-shaped
node at `:487`. The vendor PDC *core* driver that would prove the xlate is out of
scope. It is marked UNVERIFIED_HYPOTHESIS; the safe conversion (same cells,
phandle 0x01 -> 0x1a) does not depend on guessing cell semantics beyond "these
are the same cells the GIC accepted".

SPMI/PMIC, USB and UFS nodes are **not** in this list, so they are untouched by
the PDC change (this matches the confirmed working state).

## Patch plan (values computed)

Phase A — mandatory, order matters (fix consumers first, then PDC node):

1. `abl-merged-gcc.dts:4794, 5918, 5952, 8992, 9008, 9343, 9359`: change the PDC
   phandle `0x01` in the first specifier to `0x1a` (GIC), leaving its 3 cells
   unchanged. Optional wake variant for the in-table ones:
   `<0x01 66 type>`, `<0x01 92 type>`, `<0x01 93 type>`.
2. PDC node `:493-499` ->
   - `compatible = "qcom,sdmmagpie-pdc\0qcom,pdc";`
   - `reg = <0xb220000 0x30000>;`
   - `#interrupt-cells = <0x02>;`
   - `qcom,pdc-ranges = <0x00 0x200 0x5e>, <0x5e 0x281 0x1f>, <0x7d 0x5f 0x01>;`
   - keep `interrupt-parent = <0x1a>; interrupt-controller; phandle = <0x01>;`
   - no `#address-cells`.

Phase B — optional wakeup wiring:
3. TLMM `pinctrl@3400000` (`:13857`), after `phandle = <0x178>` (`:13866`):
   `wakeup-parent = <0x01>;`

Phase C — optional: convert selected devices to `<&pdc pin type>` for wake.

## Risks / detection

- UART console node (8992/9008): if left with 3 cells after step 2, the IRQ
  parse shifts -> UART probe/console RX failure. dmesg: `geni`/`msm_geni_serial`
  probe errors, `Failed to parse interrupts`; `cat /proc/interrupts`.
- PIL/remoteproc (4794/5918/5952): probe `-EINVAL` / no IRQ; dmesg
  `remoteproc`/`qcom_q6v5_pas`.
- PDC: absence of `failed to init PDC pin-hwirq mapping` and `invalid reg size`
  means bind+ranges OK; `/sys/kernel/debug/irq/domains` should list PDC.
- SPMI/PMIC, USB, UFS: unaffected by construction; verify `spmi-pmic-arb`,
  PMIC children, USB and UFS probe messages and `/proc/interrupts` are unchanged.
- If wakeup-parent (B) is wrong: suspend wake broken, no IRQ regression; detect
  via `/sys/kernel/debug/wakeup_sources` and a suspend test.

Safe incremental step: Phase A only (PDC binds, nobody consumes it) -> then B.

## UNKNOWNs

- `CONFIG_QCOM_PDC` in the built kernel (Kconfig out of scope).
- Whether the working fix28 DTS source already repointed the 7 consumers
  (no source artefact available).
- Exact vendor PDC 3-cell xlate (core driver out of scope).
- `wakeup-parent` handling inside `pinctrl-msm` 6.12 (out of scope).
- Whether `0xb230000..0xb250000` is used by another node (ioremap overlap note).
- Whether `IRQ_TYPE_NONE` (flags 0) in the UART specifiers is accepted by the
  mainline geni driver after repointing.

## New leads (out of scope)

- `include/linux/irqchip.h` IRQCHIP_MATCH expansion / of_match_table semantics.
- `drivers/irqchip/irq-gic.c` translate (whether parent_base is DT-SPI or hwirq).
- `kernel/irq/irqdomain.c` disconnect return semantics.
- `drivers/pinctrl/pinctrl-msm.c` wakeup-parent behaviour.
- vendor `drivers/irqchip/qcom/pdc.c` core xlate.
