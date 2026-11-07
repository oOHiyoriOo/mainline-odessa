# GCC-INV-01 — `clk_branch2_hw_ctl_ops` / `clk_dummy_ops` port to mainline 6.12

- PROJECT: odessa-usbgadget
- RUN_ID: 20261106-odessa-usbgadget
- TASK_ID: GCC-INV-01
- ROLE: investigator
- PHASE: 2
- LEAD_ID: GCC-OPS
- TARGET_ID: /workspace/work/odessa/kernel (vendor 4.14.190) vs /workspace/work/odessa/mainline/linux-6.12
- MAX_CALL_DEPTH: 2 (entry = depth 0)
- STATUS (candidate): CONFIRMED for the ops question; numeric clock IDs PARTIAL (dt-bindings header outside ALLOWED_PATHS)

## Question

Minimal correct adaptation when porting `gcc-sdmmagpie.c` into mainline 6.12 for
`clk_branch2_hw_ctl_ops` and `clk_dummy_ops`: port verbatim, or map the affected
entries to existing mainline ops? State behavioral risk for the affected clocks.

## Work log / searched paths

- neo-memory recall "clk_branch2_hw_ctl_ops clk_dummy_ops port" + "gcc-sdmmagpie clock driver port mainline 6.12 ops"
  → hit `c952ae6a` (GCC-PORT-START) claiming both ops absent in 6.12; verified independently.
- Read (vendor): clk-branch.c 1–90, 263–347, 380–397, 390–469; clk-branch.h 1–78;
  clk-dummy.c 1–154; common.h 40–94; common.c 245–279;
  gcc-sdmmagpie.c 1237–1255, 2544–2581, 2580–2629, 2630–2774, 2995–3069, 3276–3277.
- Read (mainline 6.12): clk-branch.c 80–200; clk-branch.h 15–39, 40–84, 90–107;
  clk-regmap.c 14–88; common.h 1–50; common.c 290–349;
  gcc-sm6115.c 2856–2895; grep gcc-sdm660.c.
- Read/grep DTS: /workspace/work/odessa/.re/uboot/abl-merged-regs.dts 618–629, 4730–4784;
  grep `hw_ctl|measure_only`, `clock-names`, `0x27 0x0[0-9a-f]`.
- Not read (outside ALLOWED_PATHS): include/dt-bindings/clock/qcom,gcc-sdmmagpie.h,
  clk-provider.h/clk.c, ufs-qcom.c, clk-debug.c.

## Findings

### 1. Vendor `clk_branch2_hw_ctl_ops` (clk-branch.c:452–462)

```c
const struct clk_ops clk_branch2_hw_ctl_ops = {
	.enable = clk_branch2_hw_ctl_enable,
	.disable = clk_branch2_hw_ctl_disable,
	.is_enabled = clk_is_enabled_regmap,
	.set_rate = clk_branch2_hw_ctl_set_rate,
	.recalc_rate = clk_branch2_hw_ctl_recalc_rate,
	.determine_rate = clk_branch2_hw_ctl_determine_rate,
	.set_flags = clk_branch_set_flags,
	.bus_vote = clk_debug_bus_vote,
};
```

Helpers (clk-branch.c:398–450):

```c
static int clk_branch2_hw_ctl_set_rate(struct clk_hw *hw, unsigned long rate,
		unsigned long parent_rate)
{
	if (!(hw->init->flags & CLK_SET_RATE_PARENT)) {
		pr_err("SET_RATE_PARENT flag needs to be set for %s\n",
					clk_hw_get_name(hw));
		return -EINVAL;
	}
	return 0;
}
static unsigned long clk_branch2_hw_ctl_recalc_rate(struct clk_hw *hw,
		unsigned long parent_rate)
{
	return parent_rate;
}
static int clk_branch2_hw_ctl_determine_rate(struct clk_hw *hw,
		struct clk_rate_request *req)
{
	struct clk_hw *clkp;
	clkp = clk_hw_get_parent(hw);
	if (!clkp)
		return -EINVAL;
	req->best_parent_hw = clkp;
	req->best_parent_rate = clk_round_rate(clkp->clk, req->rate);
	return 0;
}
static int clk_branch2_hw_ctl_enable(struct clk_hw *hw)
{
	struct clk_hw *parent = clk_hw_get_parent(hw);
	/* The parent branch clock should have been prepared prior to this. */
	if (!parent || (parent && !clk_hw_is_prepared(parent)))
		return -EINVAL;
	return clk_enable_regmap(hw);
}
static void clk_branch2_hw_ctl_disable(struct clk_hw *hw)
{
	struct clk_hw *parent = clk_hw_get_parent(hw);
	if (!parent)
		return;
	clk_disable_regmap(hw);
}
```

Key: no halt polling at all. It writes/reads only the branch `enable_reg` /
`enable_mask` through `clk_enable_regmap` / `clk_disable_regmap` /
`clk_is_enabled_regmap`. `.set_rate` does not touch hardware (only validates the
`CLK_SET_RATE_PARENT` flag); `.determine_rate` forwards to the parent.

### 2. Vendor `clk_branch2_ops` for comparison (clk-branch.c:382–395)

```c
const struct clk_ops clk_branch2_ops = {
	.prepare = clk_branch2_prepare,
	.enable = clk_branch2_enable,
	.unprepare = clk_branch2_unprepare,
	.disable = clk_branch2_disable,
	.is_enabled = clk_is_enabled_regmap,
	.set_rate = clk_branch2_set_rate,
	.round_rate = clk_branch2_round_rate,
	.recalc_rate = clk_branch2_recalc_rate,
	.set_flags = clk_branch_set_flags,
	.list_registers = clk_branch2_list_registers,
	.debug_init = clk_debug_measure_add,
	.bus_vote = clk_debug_bus_vote,
};
```

`clk_branch2_enable/disable` call `clk_branch_toggle(..., clk_branch2_check_halt)`
(clk-branch.c:271–274, 314–317), which writes the enable bit and then polls the
halt status (bit 31 `BRANCH_CLK_OFF` + NOC FSM bits 30:28, clk-branch.c:55–77).

### 3. Mainline 6.12 candidates

clk-branch.c:175–186:

```c
const struct clk_ops clk_branch2_ops = {
	.enable = clk_branch2_enable,
	.disable = clk_branch2_disable,
	.is_enabled = clk_is_enabled_regmap,
};
EXPORT_SYMBOL_GPL(clk_branch2_ops);

const struct clk_ops clk_branch2_aon_ops = {
	.enable = clk_branch2_enable,
	.is_enabled = clk_is_enabled_regmap,
};
EXPORT_SYMBOL_GPL(clk_branch2_aon_ops);
```

Helper (clk-branch.c:94–109):

```c
static int clk_branch_toggle(struct clk_hw *hw, bool en,
		bool (check_halt)(const struct clk_branch *, bool))
{
	struct clk_branch *br = to_clk_branch(hw);
	int ret;

	if (en) {
		ret = clk_enable_regmap(hw);
		if (ret)
			return ret;
	} else {
		clk_disable_regmap(hw);
	}

	return clk_branch_wait(br, en, check_halt);
}
```

`clk_branch2_enable` = `clk_branch_toggle(hw, true, clk_branch2_check_halt)`,
`clk_branch2_disable` = `clk_branch_toggle(hw, false, clk_branch2_check_halt)`
(clk-branch.c:128–136). So mainline `clk_branch2_ops` == vendor `clk_branch2_ops`
enable/disable semantics, but **with** the halt wait.

Exact register primitive (mainline clk-regmap.c:48–60):

```c
int clk_enable_regmap(struct clk_hw *hw)
{
	struct clk_regmap *rclk = to_clk_regmap(hw);
	unsigned int val;

	if (rclk->enable_is_inverted)
		val = 0;
	else
		val = rclk->enable_mask;

	return regmap_update_bits(rclk->regmap, rclk->enable_reg,
				  rclk->enable_mask, val);
}
```

`clk_disable_regmap` writes the inverse value to the same `enable_reg`/`enable_mask`
(clk-regmap.c:72–85); `clk_is_enabled_regmap` reads `enable_reg & enable_mask`
(clk-regmap.c:22–36).

Third, exact-match candidate (clk-branch.c:188–193):

```c
const struct clk_ops clk_branch_simple_ops = {
	.enable = clk_enable_regmap,
	.disable = clk_disable_regmap,
	.is_enabled = clk_is_enabled_regmap,
};
EXPORT_SYMBOL_GPL(clk_branch_simple_ops);
```

Declared in clk-branch.h:109.

Negative check inside allowed scope: `clk_branch2_hw_ctl_ops` and
`clk_dummy_ops` occur nowhere in mainline clk-branch.c/h, common.c/h, clk-regmap.c,
gcc-sdm660.c or gcc-sm6115.c (grep, no matches). Mainline also has no `set_flags`,
`bus_vote` or `debug_init` users in clk-branch.c (grep, no matches).

### 4. Register-bit, line-by-line diff for the five hw_ctl clocks

All five entries (gcc-sdmmagpie.c:1237–1255, 2582–2600, 2622–2640, 2662–2680,
2728–2746) are `struct clk_branch` with:

- `halt_reg` = `enable_reg` = 0x82024 / 0x77038 / 0x77090 / 0x77094 / 0x7708c
- `enable_mask = BIT(1)` (the hw-ctl bit)
- `halt_check = BRANCH_HALT`, `hwcg_reg` = same address, `hwcg_bit = 1`
- parent = the corresponding **non**-hw_ctl branch clock, which is a sibling on
  `BIT(0)` of the *same* register (e.g. `gcc_ufs_phy_axi_clk`, gcc-sdmmagpie.c:2562–2580:
  `enable_reg = 0x77038`, `enable_mask = BIT(0)`, `ops = &clk_branch2_ops`).

Vendor hw_ctl path:
1. enable: check parent `clk_hw_is_prepared()`; `regmap_update_bits(enable_reg, BIT(1), BIT(1))`.
   No read of any status bit.
2. disable: `regmap_update_bits(enable_reg, BIT(1), 0)`. No status read, no wait.
3. is_enabled: read `enable_reg & BIT(1)`.
4. set_rate: only checks `CLK_SET_RATE_PARENT`; returns 0. No register write.

Mapping to mainline `clk_branch_simple_ops`:
1. enable: `regmap_update_bits(enable_reg, BIT(1), BIT(1))` — identical write.
2. disable: `regmap_update_bits(enable_reg, BIT(1), 0)` — identical write.
3. is_enabled: read `enable_reg & BIT(1)` — identical read.
Differences: no explicit parent-prepared check (CCF enables/prepares the parent
before the child, so the hardware ordering is preserved); no
`set_rate`/`determine_rate`/`recalc_rate` overrides (no in-tree consumer sets a
rate on these clocks; default CCF behaviour for a missing recalc_rate is the
parent rate — UNVERIFIED_HYPOTHESIS for clk.c internals, clk.c outside scope).

Mapping to mainline `clk_branch2_ops` instead would **add** a halt wait after
each write: on enable, `clk_branch2_check_halt` reads `halt_reg` (same address)
and accepts if `BIT(31)==0` or `NOC_FSM == ON`; on disable it requires `BIT(31)==1`.
Because the hw_ctl bit only *allows* HW control while the parent BIT(0) branch
stays enabled, `BIT(31)` can legitimately remain 0 after clearing BIT(1); the
disable path would then spin 200 µs and emit
`WARN(1, "%s status stuck at 'o%s'", ...)` (clk-branch.c:80–89). Also, if BIT(31)
is not yet set at enable time, enable returns `-EBUSY`. That is the behavioral
risk of the naive "just use clk_branch2_ops" mapping.

`clk_branch2_aon_ops` is **not** a match: it has no `.disable`, so the CCF would
never clear BIT(1) — the hw-ctl vote would stay asserted.

### 5. Vendor `clk_dummy_ops` (clk-dummy.c:60–67)

```c
const struct clk_ops clk_dummy_ops = {
	.set_rate = dummy_clk_set_rate,
	.round_rate = dummy_clk_round_rate,
	.recalc_rate = dummy_clk_recalc_rate,
	.set_flags = dummy_clk_set_flags,
	.debug_init = clk_debug_measure_add,
};
EXPORT_SYMBOL_GPL(clk_dummy_ops);
```

`struct clk_dummy` (vendor common.h:48–52):

```c
struct clk_dummy {
	struct clk_hw hw;
	struct reset_controller_dev reset;
	unsigned long rrate;
};
```

Registration helper for the DT variant (clk-dummy.c:94–130, 135–154):
`clk_register_dummy()` does `kzalloc`, `init.ops = &clk_dummy_ops`,
`init.flags = flags | CLK_IS_BASIC`, `init.num_parents = 0`,
`clk = clk_register(dev, &dummy->hw)`, then registers a dummy reset controller
with `RESET_MAX 100`; `of_dummy_clk_setup()` + `CLK_OF_DECLARE(dummy_clk, "qcom,dummycc", ...)`.

For gcc-sdmmagpie the four measure-only clocks are **static** `struct clk_dummy`
instances (gcc-sdmmagpie.c:3019–3054, `.rrate = 1000`, no parents, no regmap) and
are registered via the desc hw array, not via `clk_register_dummy`:

vendor common.c:262–269:

```c
	for (i = 0; i < num_hwclks; i++) {
		if (!hwclks[i])
			continue;

		ret = devm_clk_hw_register(dev, hwclks[i]);
```

Mainline equivalent loop, common.c:335–339, has **no NULL guard**:

```c
	for (i = 0; i < num_clk_hws; i++) {
		ret = devm_clk_hw_register(dev, clk_hws[i]);
		if (ret)
			return ret;
	}
```

Mainline `qcom_cc_desc` carries `struct clk_hw **clk_hws; size_t num_clk_hws;`
(common.h:36–37), so the array mechanism exists; only the ops/struct are missing.

### 6. The clocks in question

Five `clk_branch2_hw_ctl_ops` users (names, symbolic IDs from the clocks array):
1. `gcc_aggre_ufs_phy_axi_hw_ctl_clk` — `GCC_AGGRE_UFS_PHY_AXI_HW_CTL_CLK`
   (gcc-sdmmagpie.c:1237, array 3068)
2. `gcc_ufs_phy_axi_hw_ctl_clk` — `GCC_UFS_PHY_AXI_HW_CTL_CLK` (2582, array 3184)
3. `gcc_ufs_phy_ice_core_hw_ctl_clk` — `GCC_UFS_PHY_ICE_CORE_HW_CTL_CLK` (2622, array 3187)
4. `gcc_ufs_phy_phy_aux_hw_ctl_clk` — `GCC_UFS_PHY_PHY_AUX_HW_CTL_CLK` (2662, array 3191)
5. `gcc_ufs_phy_unipro_core_hw_ctl_clk` — `GCC_UFS_PHY_UNIPRO_CORE_HW_CTL_CLK` (2728, array 3197)

Four `clk_dummy_ops` users (hws array indices):
1. `measure_only_mccc_clk` — `MEASURE_ONLY_BIMC_CLK` (3020, array 3057)
2. `measure_only_cnoc_clk` — `MEASURE_ONLY_CNOC_CLK` (3030, array 3058)
3. `measure_only_ipa_2x_clk` — `MEASURE_ONLY_IPA_2X_CLK` (3039, array 3059)
4. `measure_only_snoc_clk` — `MEASURE_ONLY_SNOC_CLK` (3048, array 3060)

Numeric ID values cannot be resolved: `include/dt-bindings/clock/qcom,gcc-sdmmagpie.h`
is outside ALLOWED_PATHS. Numeric values are therefore UNVERIFIED_HYPOTHESIS.
(The memory note `c952ae6a` says the IDs are identical to `qcom,gcc-sm6150.h`, also
outside scope.)

### 7. DT consumer check

DTS `/workspace/work/odessa/.re/uboot/abl-merged-regs.dts`:
- gcc node: `qcom,gcc@100000` compatible `qcom,gcc-sdmmagpie`, `#clock-cells=<1>`,
  `phandle = <0x27>` (lines 620–629).
- `ufshc@1d84000` clock-names = "core_clk\0bus_aggr_clk\0iface_clk\0core_clk_unipro\0core_clk_ice\0ref_clk\0tx_lane0_sync_clk\0rx_lane0_sync_clk"
  (4775), clocks = `<0x27 0x7e 0x27 0x09 0x27 0x7d 0x27 0x89 0x27 0x81 0x2f 0x00 0x27 0x88 0x27 0x87>` (4776).
  Exactly 8 clock slots, all named after the **non**-hw_ctl parent clocks; there is
  no 9th slot and no `*_hw_ctl_clk` name.
- `ufsice@1d90000` 4 slots "ufs_core_clk\0bus_clk\0iface_clk\0ice_core_clk" (4736–4737);
  `ufsphy_mem@1d87000` 3 slots "ref_clk_src\0ref_clk\0ref_aux_clk" (4754–4755).
- grep `hw_ctl|measure_only` in the whole DTS: **no matches**.
- grep `0x27 0x0[0-9a-f]`: gcc IDs used are 0x08, 0x09, 0x0b, 0x0e, 0x0f, 0x10, 0x15,
  0x7d, 0x7e, 0x81, 0x87, 0x88, 0x89, 0x8d, 0x8f, 0x91, 0x92. No gcc clock ID below
  0x08 is referenced anywhere in the DTS.

Conclusion: no DT consumer in the odessa DTB enables any `*_hw_ctl_clk` (no clock
slot for it) and none references a measure-only clock by name; the numeric
measure-only IDs are unresolved (if they are 0x00–0x03, nothing in the DTS uses
them either — conditional, UNVERIFIED_HYPOTHESIS).

### 8. Upstream precedent

Mainline `gcc-sm6115.c` (closest in-family driver) has **no** hw_ctl clocks at all
(grep `hw_ctl` → no matches). Its UFS clocks are plain `clk_branch2_ops` entries
with `enable_mask = BIT(0)` (e.g. `gcc_ufs_phy_axi_clk`, gcc-sm6115.c:2856–2874).
The same file has no dummy/measure-only clocks. So upstream practice is to omit
the BIT(1) hw-ctl duplicates, not to port the ops.

## Recommendation

**Do not port either vendor ops file verbatim.** Single coherent adaptation:

- (b) Map the 5 `clk_branch2_hw_ctl_ops` entries to existing mainline
  `clk_branch_simple_ops` (clk-branch.c:188–193, exported). Register-level
  behaviour is bit-identical (write/clear/read `BIT(1)` of the same CBCR), and it
  avoids the halt wait that `clk_branch2_ops` would add.
- (c) Keep the 4 measure-only clocks with a small **local static** `clk_ops` in
  gcc-sdmmagpie.c (e.g. `.recalc_rate` returning 1000), because mainline has no
  `clk_dummy_ops`/`struct clk_dummy`; do not add clk-dummy.c (it pulls in
  `clk_debug_measure_add`, the dummy reset controller and a new `CLK_OF_DECLARE`).
  Alternatively drop all four entries and keep every array slot non-NULL, matching
  gcc-sm6115's omission; but mainline's `num_clk_hws` loop has no NULL guard, so
  empty slots must not be left behind.

Build consequences: no new exports, no new files, no `clk-debug` dependency;
`clk_branch_simple_ops` is already `EXPORT_SYMBOL_GPL`. A verbatim port would need
`set_flags`, `bus_vote`, `debug_init` and `clk_debug_bus_vote`/`clk_debug_measure_add`,
none of which exist in mainline clk-branch.c (grep, no matches), plus new exports.

UFS consequences: the functional UFS core clocks
(`gcc_ufs_phy_axi_clk`, `gcc_ufs_phy_ahb_clk`, `gcc_ufs_phy_ice_core_clk`,
`gcc_ufs_phy_unipro_core_clk`, `gcc_ufs_phy_phy_aux_clk`, `gcc_aggre_ufs_phy_axi_clk`,
`gcc_ufs_phy_{tx,rx}_symbol_0_clk`) stay on `clk_branch2_ops` and keep the CBCR halt
handshake, which is what the UFS host/PHY actually needs. The hw_ctl votes only
release HW ownership of the branch; using `clk_branch_simple_ops` preserves the
same BIT(1) writes without risking spurious `-EBUSY`/WARN on the hw-ctl writes.
Risk of the mapping: losing the vendor's explicit `-EINVAL` when the parent branch
is not prepared (CCF ordering makes this unreachable in normal use), and no
vendor `bus_vote` (mainline uses interconnect instead).

## Open questions / limits

- Numeric clock IDs not verified (dt-bindings header outside ALLOWED_PATHS).
- `clk.c` default-ops behaviour for missing `set_rate`/`recalc_rate` reasoned, not quoted.
- Whether any non-DT kernel driver calls `clk_get()` on a `*_hw_ctl_clk` or
  `measure_only_*` name (ufs-qcom.c not in scope) — UNVERIFIED. DT clocks
  properties do not reference them.
- Untested: no build/run (editing/building out of scope).
