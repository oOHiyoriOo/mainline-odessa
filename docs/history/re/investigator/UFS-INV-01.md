# UFS-INV-01 — UFS HC + QCOM UFS PHY DT requirements (odessa / SDMMAGPIE, mainline 6.12)

- PROJECT: odessa-usbgadget
- RUN_ID: 20261106-odessa-usbgadget
- TASK_ID: UFS-INV-01
- ROLE: investigator (Phase 2)
- LEAD_ID: UFS
- TARGET_ID: mainline `/workspace/work/odessa/mainline/linux-6.12` + vendor DTS `/workspace/work/odessa/.re/uboot/abl-merged-gcc.dts`
- MAX_CALL_DEPTH: 2 (entry = ufs-qcom probe, depth 0)

## QUESTION (exactly one)
What must the odessa DTB provide so that mainline 6.12 `ufs-qcom` and the mainline QCOM UFS PHY
bind and initialize, given the vendor node's vendor-specific clock names/supplies/properties?
Per property: exact mainline consumer + exact current DTB value; which values are safe to
substitute with fixed regulators / `xo_board`.

## Method / paths actually examined (read-only)
- `drivers/ufs/host/ufs-qcom.c`, `ufs-qcom.h`
- `drivers/ufs/host/ufshcd-pltfrm.c` *(UFS core host library; needed for clock/regulator parsing
  that ufs-qcom delegates to — not in the enumerated ALLOWED_PATHS list, see LIMITATIONS)*
- `drivers/ufs/core/ufshcd.c` (probe ordering, vreg enable/disable, ref-clk handling)
- `drivers/phy/qualcomm/phy-qcom-qmp-ufs.c`, `phy-qcom-qmp.h`, `phy-qcom-qmp-pcs-ufs-v3.h`
- `arch/arm64/boot/dts/qcom/sdm670.dtsi` (no UFS node exists there), plus mainline precedents
  `sm8250.dtsi`, `sm6115.dtsi`, `sdm845.dtsi` (cross-reference only)
- `drivers/regulator/core.c`, `drivers/interconnect/core.c`, `drivers/reset/core.c`,
  `drivers/base/platform.c`, `drivers/base/power/common.c` (semantics of the consumers above)
- `drivers/clk/qcom/gcc-sdmmagpie.c`, `include/dt-bindings/clock/qcom,gcc-sdmmagpie.h`
  (team port), `drivers/clk/qcom/gcc-sdm845.c`, `drivers/clk/qcom/gdsc.c`
- vendor DTS `abl-merged-gcc.dts` UFS/GDSC/xo_board nodes

## Findings

### F1 — UFS PHY driver name is wrong in the task's ALLOWED_PATHS; actual driver found
There is **no** `drivers/phy/qualcomm/phy-qcom-ufs*.c` in this tree. The mainline UFS PHY is
`drivers/phy/qualcomm/phy-qcom-qmp-ufs.c` (QMP UFS PHY). All PHY statements below refer to it.
`arch/arm64/boot/dts/qcom/sdm670.dtsi` contains **no UFS node** (only one unrelated
`GCC_AGGRE_UFS_PHY_AXI_CLK` reference at line 641), so sdm670 cannot serve as a UFS reference.

### F2 — HC clocks: names are not used for acquisition; the 8-name vendor set is compatible
- `ufs-qcom.c:232` `devm_clk_bulk_get_all(dev, &host->clks)` grabs **every** clock of the node by
  index; names play no role there. `ufs-qcom.c:215` bulk-enables all of them.
- The core parses `clock-names` + `freq-table-hz` (`ufshcd-pltfrm.c:39,52,58`) and does
  `devm_clk_get(dev, clki->name)` (`ufshcd.c:9249`), i.e. **every name must resolve** in its provider.
- Only three names have semantics: `core_clk` (SYS1CLK_1US, `ufs-qcom.c:486`), `core_clk_unipro`
  (DME core-clk ctrl, `ufs-qcom.c:1103,1228`) and `ref_clk` (`ufshcd.c:9262`).
- No name is hard-required to probe; `freq-table-hz` must be exactly `2 × #clock-names`
  (`ufshcd-pltfrm.c:58`), else `-EINVAL`.
- Vendor HC: 8 names / 16 freq-table-hz entries = valid. Exact current values:
  `core_clk`, `bus_aggr_clk`, `iface_clk`, `core_clk_unipro`, `core_clk_ice`, `ref_clk`,
  `tx_lane0_sync_clk`, `rx_lane0_sync_clk` with
  `clocks = <&gcc 126>, <&gcc 9>, <&gcc 125>, <&gcc 137>, <&gcc 129>, <&rpmh 0>, <&gcc 136>, <&gcc 135>`.
  All IDs exist in the ported driver/header:
  126=`GCC_UFS_PHY_AXI_CLK`, 9=`GCC_AGGRE_UFS_PHY_AXI_CLK`, 125=`GCC_UFS_PHY_AHB_CLK`,
  137=`GCC_UFS_PHY_UNIPRO_CORE_CLK`, 129=`GCC_UFS_PHY_ICE_CORE_CLK`,
  136=`GCC_UFS_PHY_TX_SYMBOL_0_CLK`, 135=`GCC_UFS_PHY_RX_SYMBOL_0_CLK`; `<&rpmh 0>`=`RPMH_CXO_CLK`=0.
  All are registered in `gcc-sdmmagpie.c` (hws table lines 2861/2974-2989).
- Conclusion: **no clock change needed**, only status/other properties. Ordering only has to stay
  consistent with `freq-table-hz`.

### F3 — Regulators: ufs-qcom itself requests nothing; the core does, all optional
- `ufs-qcom.c` contains **zero** regulator/vreg references (grep). All regulator work is core:
  `ufshcd-pltfrm.c:181-193` → `ufshcd_populate_vreg(dev, "vdd-hba"|"vcc"|"vccq"|"vccq2", ...)`.
- Absent `*-supply` property ⇒ `vreg = NULL` ⇒ "assume enabled", no `regulator_get` at all
  (`ufshcd-pltfrm.c:134-137`).
- Present property ⇒ `devm_regulator_get()` at `ufshcd.c:9117`; if the provider never probes the
  HC **defers forever** (`-EPROBE_DEFER`).
- `vdd-hba` is special: `skip_current=true` (`ufshcd-pltfrm.c:181`) ⇒ `max_uA = 0`, no load vote.
  It is still enabled/disabled by the driver (`ufshcd.c:9107`, `9620/9626`); a fixed always-on
  regulator (disable is a no-op) or an absent property is required.
- `vddp-ref-clk` is **not consumed anywhere** in this tree (grep `vddp-ref-clk` in `drivers/` = none);
  the vendor property is `qcom,vddp-ref-clk-supply`, which mainline would not match anyway.
- `vdd-hba-fixed-regulator` is **not supported in 6.12**: grep of `drivers/ufs` finds only
  `ufshcd-pltfrm.c:181`; no boolean property is read. (Upstream `always_on` exists as a struct field,
  but no DT property sets it; `always_on` is only consulted in `ufshcd.c:9061`.)
- Vendor values (must be removed/replaced):
  - `vdd-hba-supply = <0x9c>` → 0x9c is **`qcom,gdsc@177004`** ("ufs_phy_gdsc"), *not* a regulator
    (DTS:6509-6516). Mainline has no driver for it ⇒ `-EPROBE_DEFER` forever.
  - `vcc-supply = <0x3f0>` = `pm6150_l19` (init 0x2cec00 = 2 944 000 µV), DTS:16557-16565.
  - `vccq2-supply = <0x3ea>` = `pm6150_l12` (init 0x19e100 = 1 696 000 µV), DTS:16491-16499.
  - no `vccq-supply`.
  - RPMh regulators currently register zero rails (from hub context), so every present supply defers.

### F4 — HC reset: mainline wants name "rst", vendor has "core_reset"; PHY reset is HC-provided
- `ufs-qcom.c:1060`: `devm_reset_control_get_optional(hba->dev, "rst")`. Vendor `reset-names =
  "core_reset"` ⇒ lookup by name fails, optional ⇒ `core_reset = NULL`, `ufs_qcom_host_reset()`
  becomes a no-op (`ufs-qcom.c:298-299`). Rename to `"rst"`.
- `resets = <&gcc 3>`; 3 = `GCC_UFS_PHY_BCR` (header:185), registered in the ported driver
  (`gcc-sdmmagpie.c:3026`). Value can stay.
- PHY reset: every QMP-UFS config reachable for this PHY (`sdm845` 1220, `sm6115` 1247,
  `sm7150` 1274) sets `no_pcs_sw_reset = true`, so the PHY **always** does
  `devm_reset_control_get_exclusive(dev, "ufsphy")` **lazily in `phy_init`**
  (`phy-qcom-qmp-ufs.c:1652-1656`) and later asserts/deasserts it (`1668`, `1691`).
  Missing ⇒ `phy_init` fails ⇒ UFS link startup fails. Mainline precedent: the reset comes from the
  **HC itself** (`<&ufs_mem_hc 0>`, `sm8250.dtsi:2578-2579`, `sm6115.dtsi:1238-1239`,
  `sdm845.dtsi:2672-2673`) and the HC is a 1-reset provider (`ufs-qcom.c:1071` `nr_resets = 1`).
  Therefore the HC node needs `#reset-cells = <1>`; the vendor node has none.
  `reset_control_deassert(NULL)` would be safe (`reset/core.c:556-558`), but it is not reachable
  here because the fetch itself fails first.

### F5 — PHY clocks: bulk-get, names not enforced; three clocks must all resolve
- `phy-qcom-qmp-ufs.c:1810`: `devm_clk_bulk_get_all(dev, &qmp->clks)`; enabled in
  `qmp_ufs_com_init` (`1612`). So this driver version does **not** request specific names/order.
- Canonical mainline naming (for readability) is `ref`, `ref_aux`, `qref`
  (`sm8250.dtsi:2574-2576`, `sdm845.dtsi:2666-2668`, `sm6115.dtsi:1232-1234`).
- Vendor mapping: `ref_clk_src=<&rpmh 0>` (xo 19.2 MHz), `ref_clk=<&gcc 124>`
  (`GCC_UFS_MEM_CLKREF_CLK`), `ref_aux_clk=<&gcc 132>` (`GCC_UFS_PHY_PHY_AUX_CLK`).
  Same three physical clocks as mainline's ref/ref_aux/qref, only order/names differ.
- `xo_board` is a 19.2 MHz fixed clock (`DTS:22840-22845`, `clock-frequency = <0x124f800>`), so it is
  a valid `ref` substitute for both the PHY and the HC. The HC derives bRefClkFreq from the
  `ref_clk` **rate** (`ufshcd.c:8494-8505`; 19200000 → `REF_CLK_FREQ_19_2_MHZ`, `8474-8476`).

### F6 — PHY supplies: `vdda-phy`, `vdda-pll`; missing ⇒ dummy; present-but-broken ⇒ defer
- `phy-qcom-qmp-ufs.c:1049-1051` `qmp_phy_vreg_l[] = { "vdda-phy", "vdda-pll" }`, acquired with
  `devm_regulator_bulk_get` (`1789-1803`) and only enabled/disabled (`1606`, `1621`, `1634`).
- Both are `NORMAL_GET`; a missing supply yields the dummy regulator
  (`regulator/core.c:2162-2171`, allowed because `have_full_constraints()` is true on DT,
  `core.c:114-117`). A present supply pointing at a non-probing RPMh rail ⇒ `-EPROBE_DEFER`.
- Fixed always-on regulators are acceptable: the driver only enables/disables and does no voltage or
  load configuration (no `regulator_set_voltage`/`set_load` in this file).
- Vendor values: `vdda-phy-supply = <0x1ad>` = `pm6150_l4` (init 0x0c92c0 = 824 000 µV,
  DTS:16437-16445), `vdda-pll-supply = <0x1ac>` = `pm6150l_l3` (init 0x1174c0 = 1 144 000 µV,
  DTS:16606-16614). `vdda-*-max-microamp` are vendor-only, ignored by this driver.

### F7 — PHY compatible: the vendor string does not exist in mainline; cfg must be chosen
- Vendor: `compatible = "qcom,ufs-phy-qmp-v3"` (DTS:4751). Match table
  `phy-qcom-qmp-ufs.c:2006-2066` has **no** such string (and no `qcom,sdm670-qmp-ufs-phy`).
- Candidate configs (all three set `no_pcs_sw_reset = true`, i.e. all need the `ufsphy` reset):
  - `qcom,sdm845-qmp-ufs-phy` → `sdm845_ufsphy_cfg`: lanes=2, v3 register layout — 1196-1221.
  - `qcom,sm7150-qmp-ufs-phy` → `sm7150_ufsphy_cfg`: lanes=1, v3 register layout — 1250-1275.
  - `qcom,sm6115-qmp-ufs-phy` → v2 register layout, lanes=1 — 1223-1248.
- Vendor node is 1 lane (`lanes-per-direction = <1>`) and single MMIO region 0x1d87000/0xddc
  (`0xc00` PCS + `0x1dc`), which matches the v3 layout (PCS `0xc00`, ready-status `0x160` ⇒ 0xd60).
  ⇒ `sm7150` is the most plausible candidate (**UNVERIFIED_HYPOTHESIS**; register-table identity
  cannot be proven from the DTS). `sdm845` remains the fallback, but its cfg declares lanes=2.
- The driver uses the new single-register binding: `devm_platform_ioremap_resource(pdev, 0)`
  (`1928`), so `reg = <0x1d87000 0xddc>` is already sufficient (mainline precedents use 0x1000).

### F8 — Power domains / GDSC: no code in ufs-qcom; adding `power-domains` without a provider defers
- `grep GDSC|genpd|power-domains` over all of `drivers/ufs` = **no matches**. ufs-qcom never calls
  genpd; it relies on the driver core. `platform.c:1399-1401`: `dev_pm_domain_attach()` runs before
  `drv->probe()` and any error (incl. `-EPROBE_DEFER` when no provider exists) aborts probe.
- If `power-domains` is absent ⇒ nothing happens, probe proceeds.
- Mainline normally provides it from the GCC driver as genpd (`gcc-sdm845.c:3437-3444`
  `ufs_phy_gdsc.gdscr = 0x77004`, PD name "ufs_phy_gdsc"); mainline DTS references it on both HC
  and PHY (`sm8250.dtsi:2507,2581`).
- The ported `gcc-sdmmagpie.c` registers **no GDSC** (`3046-3047` only `.clk_hws`), and the
  standalone vendor `qcom,gdsc@177004` has no mainline driver (grep `"qcom,gdsc"` in
  `drivers/clk/qcom` = none; `gdsc.c` is only a library used by clock drivers).
  ⇒ Do **not** add `power-domains` to the odessa UFS nodes; the GDSC stays on from the
  bootloader (the device boots from UFS). Adding it now would defer both devices forever.
  Adding `ufs_phy_gdsc` to the ported GCC driver is the proper fix (NEW_LEAD).

### F9 — Interconnect: requested unconditionally but safe to omit
- `ufs-qcom.c:1011,1016`: `devm_of_icc_get(dev, "ufs-ddr")` / `"cpu-ufs"`, fatal on error.
- `interconnect/core.c:569-570`: **no `interconnects` property ⇒ returns NULL**, and
  `icc_set_bw(NULL,...)` returns 0 (`core.c:699-700`). So omitting `interconnects` is safe.
- If `interconnects` *is* present, `interconnect-names` must contain exactly these two names
  (`core.c:577-580`) and the providers must exist, else probe fails/defers.

### F10 — Other vendor properties (all ignored by 6.12)
`qcom,msm-bus*`, `qcom,pm-qos-*`, `spm-level`, `dev-ref-clk-freq`, `vcc-voltage-level`,
`vccq2-voltage-level`, `vdda-*-max-microamp`, `pinctrl-names/pinctrl-0/1` (dev-reset-assert/
deassert; no UFS pinctrl consumer in `drivers/ufs`), `non-removable`, PHY `lanes-per-direction`
(HС's value is the one read, `ufshcd-pltfrm.c:203-210`). Harmless; optional cleanup.
`reg-names = "ufs_mem","ufs_ice"`: core maps resource 0 only (`ufshcd-pltfrm.c:467`); "ufs_mem" is
what the (MCQ-only) `ufs_qcom_mcq_config_resource` expects (`ufs-qcom.c:1573-1574,1599`). Keep.
The separate `ufsice@1d90000` node is dead: mainline ICE matches `qcom,inline-crypto-engine`
(`ice.c:348`), and `of_qcom_ice_get` returns NULL when there is neither an `ice` reg range nor a
`qcom,ice` phandle (`ice.c:280-298`) — so ICE is simply disabled, no defer.

## Concrete minimal property plan

### HC `ufshc@1d84000` (DTS:4758-4797)
Keep: `compatible = "qcom,ufshc"`, `reg`/`reg-names`, `interrupts`, `phys`, `phy-names`,
`lanes-per-direction = <1>`, all `clocks`/`clock-names`, `freq-table-hz` (16 entries).
Change:
- `status`: `"disabled"` → `"okay"`.
- `reset-names`: `"core_reset"` → `"rst"`; `resets = <&gcc 3>` unchanged.
- add `#reset-cells = <1>;`
Remove (or replace with fixed always-on regulators):
- `vdd-hba-supply = <&gdsc_ufs_phy>` — **must go** (GDSC is not a regulator in mainline).
- `vcc-supply`, `vccq2-supply` — remove (assumed enabled) or repoint to fixed regulators.
- `qcom,vddp-ref-clk-supply` (unused), `vcc-voltage-level`, `vccq2-voltage-level`,
  `vcc-max-microamp`, `vccq2-max-microamp`, `qcom,vddp-ref-clk-max-microamp`,
  `qcom,msm-bus*`, `qcom,pm-qos-*`, `spm-level`, `dev-ref-clk-freq` (ignored; optional cleanup).
Do NOT add: `interconnects`, `power-domains`.

Optional fixed regulators (values = vendor PMIC init voltages):
```
ufs_vcc:      regulator-fixed, regulator-name="ufs_vcc",      min=max=2944000, always-on
ufs_vccq2:    regulator-fixed, regulator-name="ufs_vccq2",    min=max=1696000, always-on
```

### PHY `ufsphy_mem@1d87000` (DTS:4742-4756)
- `status`: `"disabled"` → `"okay"`.
- `compatible`: `"qcom,ufs-phy-qmp-v3"` → `"qcom,sm7150-qmp-ufs-phy"` (candidate, see UNKNOWNS;
  fallback `"qcom,sdm845-qmp-ufs-phy"`, lanes=2 but same v3 layout).
- `reg = <0x1d87000 0x1000>` (0xddc also works; keeping the existing 0xddc is fine). Drop `reg-names`.
- `clocks = <&xo_board>, <&gcc 132>, <&gcc 124>;`  (or keep `<&rpmh 0>` instead of `&xo_board`)
  `clock-names = "ref", "ref_aux", "qref";` — content is what matters, not names.
- add `resets = <&ufshc 0>;` and `reset-names = "ufsphy";` — **required for every reachable cfg**
  (sdm845/sm6115/sm7150 all set `no_pcs_sw_reset = true`).
- `#phy-cells = <0>` keep.
- `vdda-phy-supply`/`vdda-pll-supply`: remove (dummy = OK) or fixed always-on:
```
ufs_vdda_phy: regulator-fixed, name="ufs_vdda_phy", min=max=824000,  always-on
ufs_vdda_pll: regulator-fixed, name="ufs_vdda_pll", min=max=1144000, always-on
```
- Drop `vdda-phy-max-microamp`, `vdda-pll-max-microamp`, `lanes-per-direction` (ignored).
- Do NOT add `power-domains`.

## UNKNOWNS / hypotheses
- UNVERIFIED_HYPOTHESIS: `qcom,sm7150-qmp-ufs-phy` is the correct mainline cfg for the SM6150/
  SDMMAGPIE QMP v3 PHY. Only the vendor compatible `qcom,ufs-phy-qmp-v3` and the v3 register window
  size are evidence; the per-SoC register tables cannot be compared locally.
- UNKNOWN: exact required fixed-regulator voltages beyond the vendor PMIC `qcom,init-voltage`
  values (taken verbatim as 2944000/1696000/824000/1144000 µV).
- UNKNOWN/risk: with no GDSC provider, UFS_PHY_GDSC must already be on (bootloader). If U-Boot or
  ABL leaves it off, register access to 0x1d84000/0x1d87000 will hang; proper fix is adding
  `ufs_phy_gdsc` to the ported GCC driver.
- UNKNOWN: PHY `ref_aux` rate/parent defaults of the ported GCC driver; no `assigned-clock-rates`
  is needed per mainline precedent, but the AUX RCG must produce the correct rate.

## NEW_LEADS
- `gcc-sdmmagpie.c` add `ufs_phy_gdsc` (gdscr 0x77004, `POLL_CFG_GDSCR`, `PWRSTS_OFF_ON`, copy
  `gcc-sdm845.c:3437-3444`), add `UFS_PHY_GDSC` id to `qcom,gcc-sdmmagpie.h`, then add
  `power-domains = <&gcc UFS_PHY_GDSC>` to both UFS nodes. (Driver work, outside this DTB question.)
- Compare SM6150/SM7150/SDM845 PHY register tables to settle the compatible choice; needs the
  vendor `phy-qcom-ufs-qmp-v3` settings or a hardware test (outside local scope).
- `sdm670.dtsi` has no UFS node: any "reuse sdm670 UFS" assumption is wrong.
- ICE: if inline crypto is ever wanted, a `qcom,inline-crypto-engine` node must be created; the
  vendor `qcom,ice` node is ignored.

## MEMORY_REFS (persisted)
- Task/scope: `c86afb79-451e-481c-a6f4-670084e0b71f`
- FINDING-A clocks/regulators: `6de7b5b1-ad8e-49c1-93a9-037bc1c3fbdb`
- FINDING-B resets: `b226b071-c822-4b6f-bcec-2ebecd6280ab`
- FINDING-C PHY clocks/supplies: `f31bc6e8-62f0-44e4-ac13-d68cd18cf2ec`
- FINDING-D PHY compatible unknown: `f2542343-fa00-4a95-8068-208f0640fb7f`
- FINDING-E GDSC + interconnect: `083a2836-4260-4341-ba61-35982a8709a7`
- Result candidate / plan: `6bfcacbd-49ae-4a9c-94a1-b4ad35289c69`
- CORRECTION (PHY reset required for all reachable cfgs): `62995206-3efe-4589-8664-892b9ee340fa`
  (connected `corrects` → FINDING-B, FINDING-D, plan)
All findings connected `part_of_task`; GDSC finding additionally connected
`extends_gcc_gate_gdsc` → `f4223197-a972-40f9-97c2-78e0521b1219`.

## Budget / limits
~640 lines read in the primary drivers, well under the 700-line budget; per-hit reads ≤60 lines.
Depth: entry ufs-qcom probe (0) → ufs_qcom_init / init_lane_clks / icc_init / phy_qmp functions (1)
→ ufshcd/regulator/icc/reset/genpd core helpers (2). Never exceeded 2.
