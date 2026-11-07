# GCC-SYN-01 — Port report: vendor gcc-sdmmagpie to Linux 6.12

TASK_ID: GCC-SYN-01
TARGET_ID: mainline: /workspace/work/odessa/mainline/linux-6.12 ;
           vendor source: /workspace/work/odessa/kernel (4.14.190)
PHASE: 4 (synthesis)
ROLE: synthesizer
LEAD_ID: GCC-PORT
STATUS: BLOCKED — artifacts produced, target paths not writable by this role

## 0. Blocker (read first)

The tool permission layer of this session only allows writes below
`/workspace/docs/re/**`.  Every write attempt to the requested deliverable
paths was rejected:

- `/workspace/work/odessa/scripts/port-gcc-sdmmagpie.py` → `Permission denied: edit`
- `/workspace/work/odessa/mainline/linux-6.12/...` → `Permission denied: edit`
- `/workspace/work/odessa/scripts/.write-test` → `Permission denied: edit`
- `/tmp/opencode/...` → `Permission denied: external_directory`

Therefore the two requested files could not be created at their target
locations.  Their complete payload is written here, ready to be copied by a
role with write access:

| Intended path | Payload written here |
|---|---|
| `/workspace/work/odessa/scripts/port-gcc-sdmmagpie.py` | `docs/re/20261106-odessa-usbgadget/synthesizer/GCC-SYN-01-port-gcc-sdmmagpie.py` |
| `/workspace/work/odessa/scripts/gcc-port-kconfig.patch.txt` | `docs/re/20261106-odessa-usbgadget/synthesizer/GCC-SYN-01-gcc-port-kconfig.patch.txt` |

The driver and binding header are *emitted by the script*, not by the
synthesizer; once the script is copied and executed it creates

- `.../drivers/clk/qcom/gcc-sdmmagpie.c`
- `.../include/dt-bindings/clock/qcom,gcc-sdmmagpie.h`

Nothing was written to the vendor tree, the kernel tree, the device or any
boot artifact.

## 1. Inputs actually read

Vendor (read-only):

- `/workspace/work/odessa/kernel/drivers/clk/qcom/gcc-sdmmagpie.c` (3363 lines; all
  regions with struct definitions were read, plus the probe/desc/tail)
- `/workspace/work/odessa/kernel/include/dt-bindings/clock/qcom,gcc-sdmmagpie.h`
  (194 lines, 160 numeric clock defines, 11 reset defines)
- `/workspace/work/odessa/kernel/drivers/clk/qcom/clk-alpha-pll.h:20-29`
  (`struct pll_vco` field order: min_freq, max_freq, val — matches the
  positional `fabia_vco[]` initializer)

Mainline 6.12 (read-only):

- `drivers/clk/qcom/common.h:28-41` — `qcom_cc_desc` has `clk_hws`/`num_clk_hws`.
- `drivers/clk/qcom/common.c:103-115` — `qcom_cc_map(struct platform_device *, desc)`.
- `drivers/clk/qcom/common.c:240-252` — clock provider maps IDs through
  `cc->rclks[idx]` (= `desc->clks[]`), not through `clk_hws`.
- `drivers/clk/qcom/common.c:286-356` — `qcom_cc_really_probe(struct device *)`;
  resets always registered; GDSCs only if `desc->gdscs`; hws registered in a loop
  with **no NULL guard** (`:335-339`).
- `drivers/clk/qcom/clk-alpha-pll.h:15-36,62,85-120,156-167` — FABIA enum,
  `clk_alpha_pll_regs[][]`, struct layouts, ops names.
- `drivers/clk/qcom/clk-alpha-pll.c:36-63` — PLL register macros dereference
  `(p)->regs[...]`.
- `drivers/clk/qcom/clk-alpha-pll.c:1141-1230` — generic postdiv ops use
  `PLL_USER_CTL(pll)` and therefore `pll->regs`.
- `drivers/clk/qcom/gcc-sc7180.c:35-73` — precedent: FABIA `.regs` on both the
  PLL and the postdiv.
- `drivers/clk/qcom/clk-rcg.h:164-178` — 6.12 `clk_rcg2` has no
  `enable_safe_config`/`flags` field.
- `drivers/clk/qcom/clk-branch.h:24-39,107-110` — branch flags and
  `clk_branch_simple_ops`.
- `drivers/clk/qcom/gcc-sm6115.c` tail — mainline desc/probe style (no sparse
  hws array).
- `drivers/clk/qcom/reset.h:11-16` — `qcom_reset_map.reg` is `unsigned int`
  (the 0x50008-style offsets fit).
- `drivers/clk/qcom/Kconfig:978-995`, `drivers/clk/qcom/Makefile:127-133` —
  placement of the new symbol/object.

## 2. Confirmed facts cited (task facts 1–10)

- Fact 1 (DTB node `qcom,gcc-sdmmagpie`, reg 0x100000/0x1f0000, no
  clocks/clock-names): not modified; driver has no clock input.
- Fact 2 (ssusb clocks 141/21/11/143/145/146; only the sdmmagpie header
  resolves them): encoded as a hard check against the copied binding header and
  the ported `gcc_sdmmagpie_clocks[]`.
- Fact 3 (vendor line map): used to locate every transformation anchor.
- Fact 4 (6.12 API): `clk_hws`/`num_clk_hws`, unconditional resets, no GDSCs,
  `desc->config` required, struct field sets.
- Fact 5 (ops mapping): `clk_fabia_fixed_pll_ops` →
  `clk_alpha_pll_fixed_fabia_ops`; `clk_generic_pll_postdiv_ops` →
  `clk_alpha_pll_postdiv_ops`; `clk_branch2_hw_ctl_ops` →
  `clk_branch_simple_ops`; local ops for the dummy clocks.
- Fact 6 (`.type = FABIA_PLL` → `.regs = clk_alpha_pll_regs[CLK_ALPHA_PLL_TYPE_FABIA]`):
  implemented for all 3 PLLs, plus the postdiv (decision D2).
- Fact 7 (strip VDD/DFS): implemented.
- Fact 8 (keep 3 MISC writes, regmap config, reset table): implemented and
  checked.
- Fact 9 (legacy `parent_names` still resolved lazily): kept; no parent_data
  conversion.
- Fact 10 (no NULL holes in hws): resolved by densifying the array (decision D1).

## 3. Transformations performed by the script (with the counts it asserts/prints)

Anchor counts were established by reading the vendor source; the script
re-computes them at run time and aborts if they differ.

| # | Transformation | Count |
|---|---|---|
| 1 | drop `#include "vdd-level-sdmmagpie.h"` | 1 |
| 2 | insert provenance comment line | 1 |
| 3 | drop `DEFINE_VDD_REGULATORS(vdd_cx/vdd_cx_ao)` | 2 |
| 4 | drop `.vdd_class = &vdd_cx[_ao]` | 38 |
| 5 | drop `.num_rate_max = VDD_NUM` | 38 |
| 6 | drop `.rate_max = (unsigned long[VDD_NUM]) { ... }` arrays | 38 |
| 7 | drop `.flags = FORCE_ENABLE_RCG` (clk_rcg2 level) | 4 |
| 8 | drop `.enable_safe_config = true` | 6 |
| 9 | `.type = FABIA_PLL` → `.regs = clk_alpha_pll_regs[...FABIA]` | 3 |
| 10 | add `.regs = ...FABIA` to `gpll0_out_even` | 1 |
| 11 | ops mapping (fixed fabia / postdiv / branch simple / dummy) | 3 / 1 / 5 / 4 |
| 12 | `struct clk_dummy` → `struct gcc_dummy_clk` | 4 |
| 13 | sparse hws array → dense 5-entry array | 1 |
| 14 | `.hwclks`/`.num_hwclks` → `.clk_hws`/`.num_clk_hws` | 2 |
| 15 | drop probe `devm_regulator_get()` blocks | 1 block (2 supplies) |
| 16 | drop probe `qcom_cc_register_rcg_dfs()` call | 1 |
| 17 | `qcom_cc_really_probe(pdev, ...)` → `(&pdev->dev, ...)` | 1 |
| 18 | drop `gcc_dfs_clocks[]` + `gcc_sdmmagpie_dfs_desc` | 1 block |
| 19 | init/exit boilerplate → `module_platform_driver()` | 1 |
| 20 | `MODULE_LICENSE("GPL v2")` → `MODULE_LICENSE("GPL")` | 1 |
| 21 | insert local `gcc_dummy_clk`/`gcc_dummy_ops` | 1 |

Explicit check anchors from the task: exactly 5 replacements of
`clk_branch2_hw_ctl_ops`, exactly 3 `.type` lines, 4 dummy clocks retyped,
11 reset entries, and the clocks[] index set must be identical before/after.

## 4. Non-mechanical decisions (with evidence)

**D1 — Densify `gcc_sdmmagpie_hws[]`.**
The vendor array (`gcc-sdmmagpie.c:3056-3063`) is designated by global clock ID:
`[MEASURE_ONLY_*]` (0..3) and `[GCC_GPLL0_MAIN_DIV_CDIV]` (162), i.e. an
`ARRAY_SIZE` of 163 with 158 NULL elements.  Mainline
`qcom_cc_really_probe()` registers every entry in a loop without a NULL check
(`common.c:335-339`), so `devm_clk_hw_register(NULL)` would crash.  The array
is converted to a dense 5-element list in the vendor's order.  This is safe
because the ID→hw mapping is done by `desc->clks[]`
(`common.c:240-252`), not by the hws array; the hws array only performs
registration.  No clock ID changes.

**D2 — Add `.regs` to `gpll0_out_even`.**
The task fact 5 gives the ops mapping, but the 6.12 generic postdiv ops also
read `pll->regs`: `PLL_USER_CTL(p)` expands to
`(p)->offset + (p)->regs[PLL_OFF_USER_CTL]` (`clk-alpha-pll.c:41`) and is used
by `clk_alpha_pll_postdiv_recalc_rate`/`_set_rate`
(`clk-alpha-pll.c:1141-1153,1206-1218`).  Without `.regs` this is a NULL
dereference.  The fix follows the FABIA precedent in `gcc-sc7180.c:58-73`.
This is an implementation necessity, not a new hardware claim: the register
map is the one already used for the three PLLs.

**D3 — Remove `.enable_safe_config` (6 occurrences).**
6.12 `struct clk_rcg2` has no such field (`clk-rcg.h:164-178`).  The vendor
initialization cannot be reconstructed from confirmed facts; it is dropped
rather than guessed.  Affected: sdcc1_apps, sdcc1_ice, sdcc2, sdcc4,
usb30_prim_master, usb30_prim_mock_utmi sources.  See UNKNOWN U3.

**D4 — Remove `.flags = FORCE_ENABLE_RCG` (4 occurrences).**
Vendor-only `clk_rcg2` flag; 6.12 has `bool hw_clk_ctrl` but the vendor flag's
numeric value/semantics are not in the confirmed facts, so no mapping is
invented.  Affected: the four UFS RCGs (axi, ice_core, phy_aux, unipro_core);
the USB RCGs do not carry it.  See UNKNOWN U4.

**D5 — VDD/regulator infrastructure removed.**
Include, the two `DEFINE_VDD_REGULATORS` declarations (vendor lines 42-43),
all `.vdd_class`/`.num_rate_max`/`.rate_max` fields, and the probe's two
`devm_regulator_get()` blocks.  The DT still has `vdd_cx-supply`/
`vdd_cx_ao-supply`; with no consumer they are simply unused.  The driver no
longer defers on regulators.

**D6 — DFS removed.**
`gcc_dfs_clocks[]`, `gcc_sdmmagpie_dfs_desc` and the
`qcom_cc_register_rcg_dfs()` call are removed, because the 4.14
`struct clk_dfs` / `qcom_cc_dfs_desc` do not exist in 6.12 (the 6.12
`clk_rcg_dfs_data`/`DEFINE_RCG_DFS` API has a different shape; converting the
vendor table would add unverified init data).  DFS is not needed for the USB
path.

**D7 — Probe call signature.**
Vendor: `qcom_cc_really_probe(pdev, ...)`.  6.12:
`qcom_cc_really_probe(struct device *dev, ...)` (`common.c:286`).  Changed to
`&pdev->dev`; without this the file does not compile.

**D8 — Dummy clocks.**
Local `struct gcc_dummy_clk`, `gcc_dummy_recalc_rate()` and static
`gcc_dummy_ops` are inserted after the includes.  The four definitions keep
`.rrate = 1000` and their names; only the type and ops pointer change.  They
are registered through the dense hws array.

**D9 — Module tail.**
`gcc_sdmmagpie_init()`/`gcc_sdmmagpie_exit()`/`subsys_initcall`/`module_exit`
are replaced by `module_platform_driver(gcc_sdmmagpie_driver);`.
`MODULE_DEVICE_TABLE`, `MODULE_DESCRIPTION`, `MODULE_ALIAS` are kept;
`MODULE_LICENSE` is set to `"GPL"` as requested.

**D10 — Parents.**
All `parent_names`/`num_parents`/`parent_map` data are kept verbatim (fact 9).
The DTB must provide `clock-output-names = "bi_tcxo"` on `/xo-board`; no
`parent_data`/`fw_name` conversion is done.

**D11 — Binding header.**
Copied byte-for-byte (`shutil.copyfile`) and re-verified with `read_bytes()`.
It contains 160 clock defines spanning the numeric ID space 0..162 with 77,
122 and 139 unused, plus 11 reset defines 0..10.  This preserves the ssusb
IDs 141/21/11/143/145/146.

## 5. Invariants asserted by the script before writing

1. Zero occurrences of: `vdd_class`, `num_rate_max`, `rate_max`,
   `DEFINE_VDD_REGULATORS`, `vdd_corner`, `vdd-level-sdmmagpie`, `vdd_cx`,
   `VDD_`, `hwclks`, `num_hwclks`, `qcom_cc_dfs_desc`, `clk_dfs`, `FABIA_PLL`,
   `enable_safe_config`, `FORCE_ENABLE_RCG`, `clk_dummy`,
   `clk_branch2_hw_ctl_ops`, `clk_fabia_fixed_pll_ops`,
   `clk_generic_pll_postdiv_ops`, `DFS_ENABLE_RCG`.
2. Exactly 5 `clk_branch_simple_ops`, 3 `clk_alpha_pll_fixed_fabia_ops`,
   1 `clk_alpha_pll_postdiv_ops`.
3. Exactly 4 `clk_alpha_pll_regs[CLK_ALPHA_PLL_TYPE_FABIA]` (3 PLL + postdiv).
4. `struct gcc_dummy_clk` 6 occurrences (1 definition, 1 `container_of`,
   4 instances); 4 `&gcc_dummy_ops`; exactly one ops definition.
5. `module_platform_driver(gcc_sdmmagpie_driver);` present; no
   `subsys_initcall`/`module_exit`; `MODULE_DEVICE_TABLE`/`MODULE_DESCRIPTION`
   present; only `MODULE_LICENSE("GPL")`.
6. `qcom_cc_really_probe(&pdev->dev, ...)` present.
7. The three MISC writes (`GCC_MMSS_MISC 0x9ffc`, `GCC_NPU_MISC 0x4d110`,
   `GCC_GPU_MISC 0x71028`) are byte-identical in the output.
8. Reset table has exactly 11 entries and their names equal the 11 binding
   reset names.
9. Binding header: 160 clock defines, 11 reset defines, gaps exactly
   {77,122,139}, reset values exactly 0..10.
10. `gcc_sdmmagpie_clocks[]` designator set is identical before/after
    (155 entries; `ARRAY_SIZE` is 162 because the highest index is 161).
11. `clocks[] ∪ hws` covers all 160 binding clock names (this is the formal
    "all clock IDs preserved" check).
12. Output hws array is dense: 5 entries, no designators, no `NULL`.
13. The six odessa ssusb IDs resolve to 141/21/11/143/145/146 and are present
    in `gcc_sdmmagpie_clocks[]`.

## 6. Open / unknown

- **U1 — `bi_tcxo_ao` has no provider.** The planned DT note only adds
  `clock-output-names = "bi_tcxo"` to `/xo-board`.  The two AO RCGs
  (`gcc_cpuss_ahb_clk_src`, `gcc_cpuss_rbcpr_clk_src`) therefore have a
  missing parent at index 0 and stay orphaned; their branches may fail rate
  changes.  Not on the USB path.  Fix would need a second named fixed clock
  (not invented here).
- **U2 — Other absent parent names.** `sleep_clk`, `aud_ref_clk`,
  `gpll1`, `gpll4`, `core_bi_pll_test_se` are not provided by this driver.
  Per fact 9 they only affect per-index parent resolution; registration does
  not fail.  `gpll4` appears in `gcc_parent_map_6` (sdcc2) but no sdcc2 rate
  entry selects it.
- **U3 — `enable_safe_config` semantics lost.** 6.12 cannot express the
  vendor field; whether the bootloader already programmed the safe source is
  unknown.  Affects SDCC and USB RCGs cosmetically, not the enable gates.
- **U4 — `FORCE_ENABLE_RCG` / `hw_clk_ctrl` mapping unconfirmed.** The vendor
  flag is removed.  If UFS is later enabled, this must be revisited (likely
  `hw_clk_ctrl = true`, but that is a hypothesis, not a confirmed fact).
- **U5 — Measure-only IDs 0..3 are not DT-resolvable.** They are only in
  `clk_hws`, not in `desc->clks[]`, so `#clock-cells` lookups of 0..3 return
  NULL (same behaviour as the vendor driver).  Nothing in the DTB uses them.
- **U6 — `GCC_GPLL0_MAIN_DIV_CDIV` (ID 162) is not provider-resolvable.**
  It is registered through `clk_hws`, and `num_clks` is 162
  (`clocks[]` highest index 161), so index 162 is out of range for
  `qcom_cc_clk_hw_get()`.  Consumers reference it by name only, as in the
  vendor driver.
- **U7 — Exact dmesg device prefix unknown.** The message text is fixed
  ("Registered GCC clocks"), but the prefix depends on the DT node name
  (`qcom,gcc@100000`), so the full line must be confirmed at boot.
- **U8 — No GDSCs in this driver.** The USB/UFS GDSC is the separate DT node
  `/soc/qcom,gdsc@10f004`; `qcom_cc_really_probe()` registers GDSCs only when
  `desc->gdscs` is set (`common.c:314-328`).  With UFS enabled but its GDSC
  provider absent, UFS probe would fail — hence the DT change below.

## 7. Exact DT changes still needed

1. `/xo-board` fixed clock (19.2 MHz): add
   `clock-output-names = "bi_tcxo";`
   so the vendor parent name resolves through the global lookup
   (`clk-fixed-rate.c:163,173`).  This is the only change needed for the GCC
   clock tree to link up.
2. First bring-up only: `status = "disabled";` on
   `ufshc@1d84000` and on its UFS PHY node (`phy@1d87000`), because the UFS
   GDSC provider is not registered by this GCC driver and UFS would probe
   after the GCC provider.
3. Later, for the USB wrapper: the confirmed DTB already lists the six clocks
   141/21/11/143/145/146 on the ssusb node.  Once the wrapper driver consumes
   them, it will additionally need the USB resets that the binding exposes:
   `GCC_USB30_PRIM_BCR = 4`, `GCC_QUSB2PHY_PRIM_BCR = 9`,
   `GCC_USB3_PHY_PRIM_BCR = 7`, `GCC_USB3_PHY_SEC_BCR = 8`,
   `GCC_USB3_DP_PHY_PRIM_BCR = 5`, `GCC_USB3_DP_PHY_SEC_BCR = 6`.
   Which of these the wrapper actually requires, and in which
   `clock-names`/`reset-names` order, is a DT-binding question and is **not**
   invented here.

## 8. Expected dmesg evidence

Success (emitted by the probe at the end of the ported function):

```
Registered GCC clocks
```

Failure path (same probe):

```
Failed to register GCC clocks
```

The prefix is the platform device name derived from the DTB node
(`...qcom,gcc@100000...`); the exact prefix is only known after boot (U7).
Clock registration errors from the framework appear as `clk: ...` lines
because the vendor file keeps `#define pr_fmt(fmt) "clk: %s: " fmt, __func__`.

## 9. Checks

- Script execution: **NOT_RUN** — no shell/test runner is available to this
  role, and the Code Mode runtime has no filesystem access.  All counts above
  were derived by reading the source and are re-asserted by the script at run
  time; they are not the output of an executed run.
- Compile check: **NOT_RUN** (same reason; no kernel build).
- LSP diagnostics: not applicable.
- Static consistency: done by inspection against the mainline headers listed
  in section 1.  This is not a substitute for a compile.

## 10. Handoff steps for the orchestrator

1. Copy `GCC-SYN-01-port-gcc-sdmmagpie.py` to
   `/workspace/work/odessa/scripts/port-gcc-sdmmagpie.py`.
2. Run `python3 scripts/port-gcc-sdmmagpie.py` (add `--force` to overwrite).
   It prints every transformation and invariant count and writes the driver
   plus the byte-identical binding header.
3. Apply the two hunks from `GCC-SYN-01-gcc-port-kconfig.patch.txt`.
4. Enable `CONFIG_SM_GCC_SDMMAGPIE` and build.  Do not claim success until
   the build and the dmesg substring in section 8 are observed.
