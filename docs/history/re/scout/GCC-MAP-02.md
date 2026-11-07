# GCC-MAP-02 — Mainline 6.12 qcom GCC registration mechanics (breadth)

- PROJECT=odessa-usbgadget, RUN_ID=20261106-odessa-usbgadget, TASK_ID=GCC-MAP-02
- TARGET_ID=/workspace/work/odessa/mainline/linux-6.12 (mainline linux-6.12 tree, local, read-only)
- ROLE=scout, PHASE=1, LEAD_ID=GCC-PORT
- Frage: Was verlangt/liefert mainline 6.12 fuer die Registrierung eines qcom-GCC-Treibers,
  damit der Vendor-4.14-Treiber mechanisch portiert werden kann? Nur Breite, kein Port-Code.
- MAX_CALL_DEPTH=2 (nicht ausgeschoepft), keine Delegation, keine Edits am Ziel.

## STATUS: DONE (PARTIAL wg. Budget-/Pfadgrenzen)

## Suchplan (tatsaechlich ausgefuehrt)
S1 ops-Symbole in clk-branch/clk-alpha-pll/clk-rcg2/clk-fixed-factor + Baum-Grep auf
`clk_dummy_ops|clk_branch2_hw_ctl_ops`; S2 structs in clk-regmap.h/clk-branch.h/
clk-rcg.h/clk-alpha-pll.h; S3 qcom_cc_desc/common.c probe; S4 parent_data in
gcc-sm6115.c/gcc-sdm660.c; S5 sm6115.dtsi gcc-Node; S6 clk.c parent-map/lookup;
S7 clk-fixed-rate.c; S8 Kconfig/Makefile; S9 alpha-pll `.type`/vco_table;
S10 dfs-Symbole.

## Befunde (Einstiegspunkte, kein Evidence Gate)

### 1. Ops-Symbole
- clk-branch.h:107-112 — `extern const struct clk_ops clk_branch_ops; clk_branch2_ops;
  clk_branch_simple_ops; clk_branch2_aon_ops; clk_branch2_mem_ops; clk_branch2_prepare_ops;`
- clk-branch.c:175-180 `clk_branch2_ops = { .enable=clk_branch2_enable,
  .disable=clk_branch2_disable, .is_enabled=clk_is_enabled_regmap }`
- clk-branch.c:182-186 `clk_branch2_aon_ops = { .enable=clk_branch2_enable,
  .is_enabled=clk_is_enabled_regmap }` (kein .disable!)
- clk-alpha-pll.h:159 `clk_alpha_pll_postdiv_ops`, :165 `clk_alpha_pll_fabia_ops`,
  :166 `clk_alpha_pll_fixed_fabia_ops`, :167 `clk_alpha_pll_postdiv_fabia_ops`
- clk-alpha-pll.c:1474-1480 fixed_fabia: enable/disable=alpha_pll_fabia_*
  is_enabled=clk_alpha_pll_is_enabled, recalc_rate=alpha_pll_fabia_recalc_rate,
  round_rate=clk_alpha_pll_round_rate
- clk-alpha-pll.c:1220-1224 postdiv: recalc_rate/round_rate/set_rate
- clk-rcg.h:191 `clk_rcg2_ops`; clk-rcg2.c:635-645 (is_enabled,get_parent,set_parent,
  recalc_rate,determine_rate,set_rate,set_rate_and_parent,get/set_duty_cycle)
- clk_fixed_factor_ops: Definition drivers/clk/clk-fixed-factor.c:71-76,
  Deklaration include/linux/clk-provider.h:1125. `drivers/clk/qcom/clk-fixed-factor.c`
  existiert NICHT (glob leer) -> Vendor-Nutzung muss auf den Core-Ops landen.
- `clk_branch2_hw_ctl_ops`: existiert NICHT (Baum-Grep: 0 Treffer).
- `clk_dummy_ops`: existiert NICHT; kein drivers/clk/qcom/clk-dummy.c. Einziger
  Treffer im Baum ist `mtk_clk_dummy_ops` (drivers/clk/mediatek/clk-mtk.[ch]).

### 2. Structs
- clk-regmap.h:20-26 `struct clk_regmap { struct clk_hw hw; struct regmap *regmap;
  unsigned int enable_reg; unsigned int enable_mask; bool enable_is_inverted; };`
  => .enable_reg/.enable_mask unveraendert; **kein `.flags`** mehr (ersetzt durch
  `enable_is_inverted`); `.hw.init` unveraendert (init liegt im eingebetteten clk_hw).
- clk-branch.h:24-39 `clk_branch { u32 hwcg_reg; u32 halt_reg; u8 hwcg_bit; u8 halt_bit;
  u8 halt_check; struct clk_regmap clkr; }` (hwcg_reg/hwcg_bit sind neu gegenueber 4.14).
- clk-rcg.h:164-178 `clk_rcg2 { u32 cmd_rcgr; u8 mnd_width; u8 hid_width;
  u8 safe_src_index; const struct parent_map *parent_map; union {freq_tbl,
  freq_multi_tbl}; struct clk_regmap clkr; u8 cfg_off; u32 parked_cfg;
  bool hw_clk_ctrl; }` => kein vdd_class/num_rate_max/rate_max.
- clk-alpha-pll.h:85-98 `clk_alpha_pll { u32 offset; const u8 *regs;
  const struct pll_vco *vco_table; size_t num_vco; u8 flags; struct clk_regmap clkr; }`
- clk-alpha-pll.h:111-120 `clk_alpha_pll_postdiv { u32 offset; u8 width; const u8 *regs;
  struct clk_regmap clkr; int post_div_shift; const struct clk_div_table *post_div_table;
  size_t num_post_div; }`

### 3. qcom_cc_desc / probe
- common.h:28-41 `{ config; clks; num_clks; resets; num_resets; gdscs; num_gdscs;
  clk_hws; num_clk_hws; icc_hws; num_icc_hws; icc_first_node_id; }`
  (.hwclks/.num_hwclks -> .clk_hws/.num_clk_hws, Typ struct clk_hw **)
- common.c:302-312: reset controller wird IMMER registriert
  (`devm_reset_controller_register`, nr_resets=desc->num_resets), auch bei 0 Resets.
- common.c:314-328: GDSCs nur bei `if (desc->gdscs && desc->num_gdscs)` -> `gdsc_register`.
- common.c:341-352: clks via devm_clk_register_regmap, danach Provider, dann icc.
- common.c:113 `devm_regmap_init_mmio(dev, base, desc->config)` => `.config` ist fuer
  qcom_cc_map/qcom_cc_probe zwingend; qcom_cc_really_probe selbst nutzt sie nicht.
- DT `#power-domain-cells`: sm6115.dtsi:818 `<1>`, Konsumenten 1193/1236
  `power-domains = <&gcc GCC_UFS_PHY_GDSC>`, 1640 `<&gcc GCC_USB30_PRIM_GDSC>`.
  Die genpd-Registrierung selbst liegt in gdsc.c (nicht in meinen ALLOWED_PATHS)
  => Mechanik nur als Beobachtung, nicht belegt.

### 4. Kanonischer DT-Node (sm6115.dtsi:811-819)
```
gcc: clock-controller@1400000 {
        compatible = "qcom,gcc-sm6115";
        reg = <0x0 0x01400000 0x0 0x1f0000>;
        clocks = <&rpmcc RPM_SMD_XO_CLK_SRC>, <&sleep_clk>;
        clock-names = "bi_tcxo", "sleep_clk";
        #clock-cells = <1>;
        #reset-cells = <1>;
        #power-domain-cells = <1>;
};
```
sdm660-GCC-Node: Datei arch/arm64/boot/dts/qcom/sdm660.dtsi ist NICHT in ALLOWED_PATHS
=> nicht gelesen (NEW_LEAD/LIMITATION).

### 5. XO-Referenzierung
- gcc-sm6115.c:67-69 `.parent_data = &(const struct clk_parent_data){ .fw_name = "bi_tcxo" }`
  (gpll0), Sammel-Arrays z.B. gcc_parents_0 :473-474 `{ .fw_name = "bi_tcxo" }`,
  gcc_parents_2 :501-504 zusaetzlich `{ .fw_name = "sleep_clk" }`.
- gcc-sdm660.c:41-44 `xo`-Fixed-Factor mit `.fw_name = "xo"`; :173-174
  `gcc_parent_data_xo_gpll0[] = { { .fw_name = "xo" }, ... }`.
- DT liefert die Bindung ueber clock-names: sm6115.dtsi:814-815
  `clocks = <&rpmcc RPM_SMD_XO_CLK_SRC>, <&sleep_clk>; clock-names = "bi_tcxo", "sleep_clk";`
  => fw_name muss exakt einem clock-names-Eintrag des Consumer-Nodes entsprechen.
  Vendor-Name "bi_tcxo" passt daher nur, wenn die odessa-DTS diesen clock-names-Eintrag
  (oder einen gleichnamigen Fixed-Clock) bereitstellt.

### 6. Legacy `parent_names`
- clk.c:4258-4264 (clk_core_populate_parent_map): bei `init->parent_names` wird nur
  `clk_cpy_name(&parent->name, parent_names[i], true)` kopiert (kein hw).
- clk.c:520-525 (clk_core_fill_parent_index): `parent = clk_core_get(core,index);
  if (PTR_ERR(parent)==-ENOENT && entry->name) parent = clk_core_lookup(entry->name);`
- clk.c:404-427 clk_core_lookup: sucht Namen global in `clk_root_list` und danach
  `clk_orphan_list`.
=> Legacy-`parent_names` loest in 6.12 weiterhin per globalem Clock-Namen auf
(Reihenfolge: DT/clkdev -> globaler Name). Voraussetzung: Parent-Clock ist zum
Registrierungszeitpunkt bereits global benannt/registriert, sonst -EPROBE_DEFER.

### 7. Fixed-Clock-Naming
- clk-fixed-rate.c:163 `const char *clk_name = node->name;`
- clk-fixed-rate.c:173 `of_property_read_string(node, "clock-output-names", &clk_name);`
=> `clock-output-names` wird honoriert; ohne Property gilt der Node-Name
(ohne Unit-Address). Ein Node `xo-board` heisst also "xo-board", nicht "bi_tcxo"/"xo".

### 8. Kconfig/Makefile
- Kconfig:978-985 `config SM_GCC_6115 / tristate "SM6115 and SM4250 Global Clock
  Controller" / depends on ARM64 || COMPILE_TEST / select QCOM_GDSC / help ...`
- Kconfig:680-687 `config SDM_GCC_660 / tristate "SDM660 Global Clock Controller" /
  depends on ARM64 || COMPILE_TEST / select QCOM_GDSC / help ...`
- Makefile:128 `obj-$(CONFIG_SM_GCC_6115) += gcc-sm6115.o`
- Makefile:100 `obj-$(CONFIG_SDM_GCC_660) += gcc-sdm660.o`

### 9. clk_alpha_pll `.type`
- Kein `.type`-Feld mehr (clk-alpha-pll.h:85-98). Ersatz: `const u8 *regs` +
  `extern const u8 clk_alpha_pll_regs[CLK_ALPHA_PLL_TYPE_MAX][PLL_OFF_MAX_REGS]`
  (clk-alpha-pll.h:62) mit Enum CLK_ALPHA_PLL_TYPE_* (clk-alpha-pll.h:16-35,
  inkl. DEFAULT_EVO/B RAMMO_EVO). Zuweisung z.B. gcc-sm6115.c:61
  `.regs = clk_alpha_pll_regs[CLK_ALPHA_PLL_TYPE_DEFAULT_EVO]`.
- vco_table-Beispiel: gcc-sm6115.c:45-47 `default_vco[] = { { 500000000, 1000000000, 2 } }`;
  :57-61 gpll0 `.vco_table = default_vco; .num_vco = ARRAY_SIZE(default_vco);`
  (ebenso gpll9_vco :49-51, gpll10_vco :53-55).

### 10. DFS-Symbole
- `qcom_cc_register_rcg_dfs` JA: clk-rcg.h:212-214, clk-rcg2.c:1546-1559, benutzt in
  gcc-sm6115.c:3506-3507, gcc-sdm660.c: keine Nutzung gefunden.
- `struct clk_rcg_dfs_data` JA: clk-rcg.h:204-207 `{ struct clk_rcg2 *rcg;
  struct clk_init_data *init; }`, Makro `DEFINE_RCG_DFS(r)` :209-210.
- `struct clk_dfs`: NEIN (kein Treffer im qcom-Teilbaum).
- `qcom_cc_dfs_desc`: NEIN; stattdessen pro Treiber Arrays `gcc_dfs_clocks[]`
  bzw. `gcc_sm7150_dfs_desc[]` (gcc-sm7150.c:2924).

## SEARCHED_AND_EMPTY
- `clk_branch2_hw_ctl_ops` und `clk_dummy_ops` im gesamten Baum:
  nur `mtk_clk_dummy_ops` (mediatek) — kein qcom-Symbol.
- `drivers/clk/qcom/clk-dummy*` (glob): keine Datei.
- `drivers/clk/qcom/clk-fixed-factor.c` (glob): keine Datei.
- `clk_alpha_pll_fixed_fabia_ops|clk_branch2_aon_ops` in gcc-sm6115.c: 0 Treffer.

## LIMITATIONS
- Lesebudget ueberschritten: ~790 gelesene Zeilen vs. 500 erlaubt (viele kleine
  Struct-/Konstanten-Fenster). Suche danach abgebrochen; keine weiteren Pfade gelesen.
- sdm660.dtsi (GCC-Node, clock-names) nicht in ALLOWED_PATHS -> nicht gelesen.
- gdsc.c (genpd-Registrierung/#power-domain-cells-Mechanik) nicht in ALLOWED_PATHS.
- include/linux/clk-provider.h nur fuer eine Deklarationszeile (1125) geprueft,
  liegt formal ausserhalb der ALLOWED_PATHS.
- Keine Call-Ketten, keine Verhaltensbestaetigung; alles nur Einstiegspunkte.

## OFFENE FRAGEN (fuer Investigator)
1. Ist `.enable_is_inverted` funktional aequivalent zu Vendor-`.flags` bzw. was
   passiert mit Vendor-Flags-Werten beim Port?
2. Registriert gdsc.c einen genpd-Onecell-Provider, der `#power-domain-cells`
   zwingend braucht, und was passiert ohne die Property?
3. Woher stammt bei sm6115 `RPM_SMD_XO_CLK_SRC` (rpmcc) und kann odessa stattdessen
   einen fixed-clock mit clock-output-names="bi_tcxo" liefern?
4. Verhalten von `clk_branch2_aon_ops` ohne `.disable` (Gate bleibt an) — relevant
   fuer USB-Clocks?
