# GCC-MAP-01 — Vendor GCC breadth inventory (sdmmagpie / SM6150)

- PROJECT: odessa-usbgadget
- RUN_ID: 20261106-odessa-usbgadget
- TASK_ID: GCC-MAP-01
- TARGET_ID: /workspace/work/odessa/kernel (Linux 4.14.190 vendor tree; odessa/SM6150 stock source)
- ROLE / PHASE: scout / 1
- LEAD_ID: GCC-PORT
- STATUS: DONE (breadth only; no port code, no call chains)
- MAX_CALL_DEPTH: 1 (not used beyond direct struct fields)

## Search plan / scope actually used
Read-only inspection of the 7 allowed paths only.
Patterns: `vdd_class|num_rate_max|rate_max|DEFINE_VDD_REGULATORS|vdd_corner|VDD_NUM|FABIA_PLL|hwclks|num_hwclks|rcg_dfs|clk_dfs|dfs_desc`,
`clk_branch2_hw_ctl_ops|clk_dummy_ops|clk_fabia_fixed_pll_ops|clk_generic_pll_postdiv_ops`,
`usb30_prim|usb3_prim|...`, `gcc_parent_names`, `struct gdsc|.gdscs`, `gdsc` (case-insensitive),
`regmap_config|qcom_cc_really_probe|qcom_cc_map|devm_regulator_get|regmap_write`, header `^#define`.
Extra single-line comparison read: `include/dt-bindings/clock/qcom,gcc-sm6150.h` (only GCC_USB30_PRIM_BCR / pipe clock), required by deliverable 9.

## 1. Vendor-only fields / macros in gcc-sdmmagpie.c (occurrence counts)
| item | occurrence | lines |
|---|---|---|
| `DEFINE_VDD_REGULATORS` | 2 | 42, 43 (`vdd_cx`, `vdd_cx_ao`) |
| `vdd_corner` (global array, not macro) | 2 uses in .c; defined vdd-level-sdmmagpie.h:31 | 42, 43 |
| `VDD_NUM` | 78 | 42,43 + each of 38 `num_rate_max` + 38 `rate_max` |
| `.vdd_class` | 38 (36 `vdd_cx`, 2 `vdd_cx_ao`) | 302,325 (ao); 358,378,398,424,449,474,512,532,552,572,592,612,633,654,674,694,714,734,754,774,794,814,848,876,908,940,965,993,1023,1044,1070,1099,1129,1153,1171,1196 |
| `.num_rate_max` | 38 | same list as above |
| `.rate_max` | 38 | same list as above |
| `.type = FABIA_PLL` | 3 | 206, 256, 273 |
| `.hwclks` | 1 | 3276 |
| `.num_hwclks` | 1 | 3277 |
| `struct clk_dfs gcc_dfs_clocks[]` | 1 | 3242 |
| `qcom_cc_dfs_desc` (`gcc_sdmmagpie_dfs_desc`) | 1 | 3261 |
| `qcom_cc_register_rcg_dfs` | 1 | 3332 |
| `clk_branch2_hw_ctl_ops` | 5 | 1252, 2597, 2637, 2677, 2743 |
| `clk_dummy_ops` | 4 | 3024, 3034, 3043, 3052 |
| `clk_fabia_fixed_pll_ops` | 3 | 214, 264, 281 |
| `clk_generic_pll_postdiv_ops` | 1 | 237 |

Additional vendor-only surface spotted:
- `#include "vdd-level-sdmmagpie.h"` (line 34) — the whole VDD-corner mechanism is vendor-only.
- `F(f,s,h,m,n)` macro (line 36) encodes half-integer dividers `(2*(h)-1)` — line 36.
- `enum vdd_levels` + `vdd_corner[]` in vdd-level-sdmmagpie.h:20-39.
- `clk-rcg.h:178-180` adds flags `FORCE_ENABLE_RCG`, `DFS_ENABLE_RCG`, `HW_CLK_CTRL_MODE`; `clk_rcg2` itself (clk-rcg.h:167-181) has NO vdd_class/num_rate_max/rate_max — those live in `struct clk_init_data` (QTI patch to include/linux/clk-provider.h). NEW_LEAD.

## 2. clk_branch2_hw_ctl_ops users (all UFS)
- `gcc_aggre_ufs_phy_axi_hw_ctl_clk` — decl 1237, ops 1252
- `gcc_ufs_phy_axi_hw_ctl_clk` — decl 2582, ops 2597
- `gcc_ufs_phy_ice_core_hw_ctl_clk` — decl 2622, ops 2637
- `gcc_ufs_phy_phy_aux_hw_ctl_clk` — decl 2662, ops 2677
- `gcc_ufs_phy_unipro_core_hw_ctl_clk` — decl 2728, ops 2743

## 2b. clk_dummy_ops users (measure-only)
- `measure_only_mccc_clk` 3020 (ops 3024)
- `measure_only_cnoc_clk` 3030 (ops 3034)
- `measure_only_ipa_2x_clk` 3039 (ops 3043)
- `measure_only_snoc_clk` 3048 (ops 3052)

## 3. PLL ops users
clk_fabia_fixed_pll_ops (`type = FABIA_PLL`):
- `gpll0` 202 (type 206, ops 214)
- `gpll6` 252 (type 256, ops 264)
- `gpll7` 269 (type 273, ops 281)

clk_generic_pll_postdiv_ops:
- `gpll0_out_even` 227 (ops 237; post_div_table_fabia_even 219)

## 4. USB clock inventory (ID / struct / regs / parents / freq table)
| clock | hdr ID (line) | struct (line) | enable_reg / halt_reg | parent(s) | freq table |
|---|---|---|---|---|---|
| GCC_USB30_PRIM_MASTER_CLK | 141 (h:158) | gcc_usb30_prim_master_clk 2748 | 0xf010 / 0xf010 | gcc_usb30_prim_master_clk_src | – |
| GCC_USB30_PRIM_MASTER_CLK_SRC | 142 (h:159) | gcc_usb30_prim_master_clk_src 1087 | cmd_rcgr 0xf01c | gcc_parent_names_0 | ftbl_gcc_usb30_prim_master_clk_src 1079 |
| GCC_USB30_PRIM_MOCK_UTMI_CLK | 143 (h:160) | gcc_usb30_prim_mock_utmi_clk 2766 | 0xf018 / 0xf018 | ..._mock_utmi_clk_src | – |
| GCC_USB30_PRIM_MOCK_UTMI_CLK_SRC | 144 (h:161) | gcc_usb30_prim_mock_utmi_clk_src 1117 | cmd_rcgr 0xf034 | gcc_parent_names_0 | ftbl_gcc_usb30_prim_mock_utmi_clk_src 1109 |
| GCC_USB30_PRIM_SLEEP_CLK | 145 (h:162) | gcc_usb30_prim_sleep_clk 2784 | 0xf014 / 0xf014 | none | – |
| GCC_USB3_PRIM_CLKREF_CLK | 146 (h:163) | gcc_usb3_prim_clkref_clk 2797 | 0x8c010 / 0x8c010 | none | – |
| GCC_USB3_PRIM_PHY_AUX_CLK | 147 (h:164) | gcc_usb3_prim_phy_aux_clk 2810 | 0xf050 / 0xf050 | gcc_usb3_prim_phy_aux_clk_src | – |
| GCC_USB3_PRIM_PHY_AUX_CLK_SRC | 148 (h:165) | gcc_usb3_prim_phy_aux_clk_src 1142 | cmd_rcgr 0xf060 | gcc_parent_names_3 | ftbl_gcc_usb3_prim_phy_aux_clk_src 1137 |
| GCC_USB3_PRIM_PHY_COM_AUX_CLK | 149 (h:166) | gcc_usb3_prim_phy_com_aux_clk 2828 | 0xf054 / 0xf054 | gcc_usb3_prim_phy_aux_clk_src (same src, no separate COM src) | – |
| GCC_USB3_PRIM_PHY_PIPE_CLK | 150 (h:167) | gcc_usb3_prim_phy_pipe_clk 2846 | 0xf058 / none (`BRANCH_HALT_SKIP`) | none | – |
| GCC_CFG_NOC_USB3_PRIM_AXI_CLK | 21 (h:41) | gcc_cfg_noc_usb3_prim_axi_clk 1405 | 0x502c / 0x502c | gcc_usb30_prim_master_clk_src | – |
| GCC_AGGRE_USB3_PRIM_AXI_CLK | 11 (h:31) | gcc_aggre_usb3_prim_axi_clk 1257 | 0x8201c / 0x8201c | gcc_usb30_prim_master_clk_src | – |

## 5. USB resets
Header: block `/* GCC Resets */` h:181. IDs: GCC_USB30_PRIM_BCR=4 (h:186), GCC_USB3_DP_PHY_PRIM_BCR=5 (h:187), GCC_USB3_DP_PHY_SEC_BCR=6 (h:188), GCC_USB3_PHY_PRIM_BCR=7 (h:189), GCC_USB3_PHY_SEC_BCR=8 (h:190), GCC_QUSB2PHY_PRIM_BCR=9 (h:191).
Table `gcc_sdmmagpie_resets[]` 3228:
- GCC_USB30_PRIM_BCR = { 0xf000 } — 3233
- GCC_USB3_DP_PHY_PRIM_BCR = { 0x50008 } — 3234
- GCC_USB3_DP_PHY_SEC_BCR = { 0x50014 } — 3235
- GCC_USB3_PHY_PRIM_BCR = { 0x50000 } — 3236
- GCC_USB3_PHY_SEC_BCR = { 0x5000c } — 3237
- GCC_QUSB2PHY_PRIM_BCR = { 0x26000 } — 3238
Note: entries carry only a register offset; bit defaults to 0 (contrast `{ 0xb01c, 2 }` at 3239). Reset bit semantics = NEW_LEAD (reset.h/qcom_cc_reset).

## 6. Probe / regmap / misc
- regmap config 3266-3272: reg_bits 32, reg_stride 4, val_bits 32, max_register 0x1820b0, fast_io true.
- desc 3274-3282 (`.hwclks` 3276, `.num_hwclks` 3277, resets 3280-3281).
- probe `gcc_sdmmagpie_probe` 3290-3339.
- `devm_regulator_get(..., "vdd_cx")` 3295; `"vdd_cx_ao"` 3303 — both return PTR_ERR incl. -EPROBE_DEFER.
- `qcom_cc_map` 3311.
- `regmap_update_bits(regmap, GCC_MMSS_MISC, 0x3, 0x3)` 3321; `GCC_NPU_MISC` 3322; `GCC_GPU_MISC` 3323 (offsets defined 38-40).
- `qcom_cc_really_probe` 3325.
- `qcom_cc_register_rcg_dfs(pdev, &gcc_sdmmagpie_dfs_desc)` 3332.

## 7. Parent-name arrays (all contain "bi_tcxo" except the two _ao variants, which use "bi_tcxo_ao")
- gcc_parent_names_0 (65): bi_tcxo, gpll0, gpll0_out_even, core_bi_pll_test_se
- gcc_parent_names_0_ao (71): bi_tcxo_ao, gpll0, gpll0_out_even, core_bi_pll_test_se
- gcc_parent_names_1 (86): bi_tcxo, gpll0, sleep_clk, gpll0_out_even, core_bi_pll_test_se
- gcc_parent_names_2 (100): bi_tcxo, gpll0, core_bi_pll_test_se
- gcc_parent_names_2_ao (105): bi_tcxo_ao, gpll0, core_bi_pll_test_se
- gcc_parent_names_3 (117): bi_tcxo, sleep_clk, core_bi_pll_test_se
- gcc_parent_names_4 (128): bi_tcxo, core_bi_pll_test_se
- gcc_parent_names_5 (141): bi_tcxo, gpll0, gpll6, gpll0_out_even, core_bi_pll_test_se
- gcc_parent_names_6 (158): bi_tcxo, gpll0, gpll7, gpll4, gpll0_out_even, core_bi_pll_test_se
- gcc_parent_names_7 (175): bi_tcxo, gpll0, aud_ref_clk, gpll0_out_even, core_bi_pll_test_se
- gcc_parent_names_8 (190): bi_tcxo, gpll0, gpll1, core_bi_pll_test_se
All 11 arrays are name-based (no `struct clk_parent_data`); `bi_tcxo` must resolve globally ⇒ DT clock-output-names issue is real.

## 8. GDSC
NO. `grep -i gdsc` in gcc-sdmmagpie.c → 0 matches. No `struct gdsc`, no `.gdscs` in `gcc_sdmmagpie_desc`.

## 9. Header inventory (qcom,gcc-sdmmagpie.h, 194 lines)
- 162 clock `#define`s, lines 18-179. First ID 0 = MEASURE_ONLY_SNOC_CLK (18); last ID 162 = GCC_GPLL0_MAIN_DIV_CDIV (179).
- ID span 0..162 but values 77, 122, 139 do not occur (grep: 76→78 at 96/97, 121→123 at 140/141, 138→140 at 156/157) ⇒ two IDs are aliased/duplicated within 18-179; not resolved (budget).
- 11 reset `#define`s, lines 182-192, contiguous 0..10; first GCC_PCIE_0_BCR=0 (182), last GCC_VIDEO_AXI_CLK_BCR=10 (192).
- Reset numbering is NOT identical to qcom,gcc-sm6150.h: sdmmagpie GCC_USB30_PRIM_BCR=4 (h:186) vs sm6150=2 (sm6150 h:207). Clock numbering also differs: GCC_USB3_PRIM_PHY_PIPE_CLK=150 here vs 156 in sm6150 (h:176). ⇒ Prior assumption "IDs identical to sm6150" is wrong for USB (corrected in memory).

## Open questions / next
- Where are `vdd_class`/`num_rate_max`/`rate_max`/`DEFINE_VDD_REGULATORS` declared in this tree (include/linux/clk-provider.h?) — NEW_LEAD.
- Reset bit field semantics of `struct qcom_reset_map` in this tree (reset.h) — NEW_LEAD.
- Duplicate clock ID pair inside 18-179 — cheap grep done, resolution needs a full header diff (not budgeted).
- Mainline side (what 6.12 actually provides) is GCC-MAP-02, not this task.

## Limitations
- Budget: ~520 lines of read slices plus ~430 grep match lines were emitted; the nominal 500-line reading cap was slightly exceeded to cover item 9 (full `^#define` enumeration).
- `enable_reg`/`halt_reg` for RCGs do not exist (they use `cmd_rcgr`), stated as such.
- No call chains, no decompiler, no mainline comparison beyond the one sm6150 BCR/pipe line.
