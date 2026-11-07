# GCC-SYN-01 v2 — Port report (addendum: disable-time CXO parking)

TASK_ID: GCC-SYN-01
TARGET_ID: mainline: /workspace/work/odessa/mainline/linux-6.12 ;
           vendor source: /workspace/work/odessa/kernel (4.14.190)
PHASE: 4 (synthesis)
ROLE: synthesizer
LEAD_ID: GCC-PORT
STATUS: BLOCKED — payloads produced, target paths not writable by this role

This v2 supersedes the v1 script only in the treatment of the vendor
`.enable_safe_config` field.  Everything else is unchanged and remains as
documented in `GCC-SYN-01.md`.

## 1. Blocker (unchanged)

The tool permission layer only allows writes below `/workspace/docs/re/**`.
Writes to `/workspace/work/odessa/scripts/**` and the kernel tree were
rejected (`Permission denied: edit`; `/tmp` → `external_directory`).  The
complete v2 payload is therefore here:

| Intended path | v2 payload |
|---|---|
| `/workspace/work/odessa/scripts/port-gcc-sdmmagpie.py` | `docs/re/20261106-odessa-usbgadget/synthesizer/GCC-SYN-01-port-gcc-sdmmagpie-v2.py` |
| (unchanged) `/workspace/work/odessa/scripts/gcc-port-kconfig.patch.txt` | `.../GCC-SYN-01-gcc-port-kconfig.patch.txt` (v1, still valid) |

The script emits the driver and the byte-identical binding header.  Nothing
was written to the vendor tree, kernel tree, device or boot artifacts.

## 2. Delta: `.enable_safe_config` → `clk_rcg2_shared_ops`

### 2.1 Semantic mapping (confirmed)

In the vendor 4.14 tree, `.enable_safe_config = true` on an RCG makes the
clock park at CXO when it is disabled.  Mainline 6.12 expresses exactly this
with `clk_rcg2_shared_ops`:

- `clk_rcg2_shared_disable()` writes
  `rcg->safe_src_index << CFG_SRC_SEL_SHIFT` and caches the previous config;
  `clk_rcg2_shared_enable()` restores the cached config
  (`drivers/clk/qcom/clk-rcg2.c:1241-1249`).
- Every vendor `gcc_parent_map_*` starts with `{ P_BI_TCXO, 0 }`, so
  `.safe_src_index` is 0 (CXO) by zero-initialisation.  No explicit field is
  needed — same idiom as the gcc-sc7180 qupv3 RCGs.
- `clk_rcg2_shared_ops` is declared/exported in `clk-rcg.h:200` in the local
  6.12 tree.

### 2.2 Affected RCGs (exactly 6)

| struct variable | cmd_rcgr | parent map |
|---|---|---|
| `gcc_sdcc1_apps_clk_src` | 0x12028 | map_5 |
| `gcc_sdcc1_ice_core_clk_src` | 0x12010 | map_0 |
| `gcc_sdcc2_apps_clk_src` | 0x1400c | map_6 |
| `gcc_sdcc4_apps_clk_src` | 0x1600c | map_0 |
| `gcc_usb30_prim_master_clk_src` | 0xf01c | map_0 |
| `gcc_usb30_prim_mock_utmi_clk_src` | 0xf034 | map_0 |

The other 32 `struct clk_rcg2` definitions keep `.ops = &clk_rcg2_ops,`
untouched.  The rewrite is done per struct block, matched by the struct
variable name (`static struct clk_rcg2 <name> = { ... };`), never by a global
string replacement.

### 2.3 Script changes

1. New constant `SAFE_CONFIG_RCGS` containing exactly the six variable names.
2. New helpers `rcg_block_re(name)` / `rcg_block(text, name)` that isolate one
   complete `struct clk_rcg2` definition (outer `\n};\n`, inner initializers
   are indented and therefore not matched).
3. The previous global `.enable_safe_config` removal was replaced by a
   per-block loop:
   - assert the block contains exactly one `.enable_safe_config = true,`;
   - assert the block contains exactly one `.ops = &clk_rcg2_ops,`;
   - remove the `.enable_safe_config` line;
   - rewrite that block's ops to `&clk_rcg2_shared_ops`;
   - splice the block back.
4. New invariants (see §3): global 6/32 split, 38 RCG definitions, and a
   per-name block check.

## 3. Invariants (v2)

New/changed assertions, in addition to every v1 invariant:

1. `out.count("&clk_rcg2_shared_ops") == 6`.
2. `out.count("&clk_rcg2_ops") == 32`.
3. `len(re.findall(r"static struct clk_rcg2 \w+ = \{", out)) == 38`.
4. For each of the six names in `SAFE_CONFIG_RCGS`, the isolated block
   contains exactly one `&clk_rcg2_shared_ops`, contains no `&clk_rcg2_ops`,
   and contains no `enable_safe_config` (per-struct check, not a global
   count).
5. `enable_safe_config` remains in the zero-occurrence forbidden-token list.

Unchanged v1 invariants still enforced: 0 surviving vendor-only tokens;
5× `clk_branch_simple_ops`; 3× `.type`→`.regs`; 4× FABIA `.regs`;
4 dummy clocks + local ops; 11 resets matching the header; clocks[] index set
unchanged (155 entries, ARRAY_SIZE 162); clocks[]∪hws covers all 160 clock
defines over the 0..162 ID space; dense 5-entry hws with no NULL; ssusb IDs
141/21/11/143/145/146 resolve; `qcom_cc_really_probe(&pdev->dev, ...)`;
module tail rewritten.

## 4. Updated transformation table (delta only)

| # | Transformation | Count |
|---|---|---|
| 7a | rewrite targeted RCG block ops to `clk_rcg2_shared_ops` | 6 |
| 7b | drop `.enable_safe_config = true` inside those blocks | 6 |

All other rows (VDD/DFS stripping, ops mapping, dense hws, probe/desc/module
rewrites) are identical to `GCC-SYN-01.md` §3.

## 5. Unknowns / limits (delta)

- **U3 resolved as design choice:** CXO parking is restored via
  `clk_rcg2_shared_ops`; `.safe_src_index = 0` is implicit from the common
  `{ P_BI_TCXO, 0 }` first entry.  No explicit `safe_src_index` is invented.
- **New U9:** `clk_rcg2_shared_ops` parks the RCG but does not itself enable
  the CXO parent at the framework level; the parent clock must be present
  (`bi_tcxo` on `/xo-board`).  This is the same DT prerequisite already
  documented.
- All v1 unknowns remain valid, in particular: `bi_tcxo_ao` has no provider,
  the UFS `FORCE_ENABLE_RCG`/`hw_clk_ctrl` mapping is not confirmed, and the
  UFS GDSC lives in a separate DT node.

## 6. DT changes and dmesg evidence (unchanged)

- `/xo-board`: `clock-output-names = "bi_tcxo";`
- First test: `status = "disabled";` on `ufshc@1d84000` and its PHY.
- Later wrapper: the six ssusb clocks 141/21/11/143/145/146 already exist; the
  binding exposes USB resets 4, 9, 7, 8, 5, 6 (which the wrapper needs and in
  which order is not invented here).
- Success dmesg substring: `Registered GCC clocks`; failure:
  `Failed to register GCC clocks`.

## 7. Checks

- Script execution: **NOT_RUN** — no shell; Code Mode has no filesystem
  access.  All counts are static readings re-asserted by the script.
- Kernel compile: **NOT_RUN**.
- Static API cross-check (`clk-rcg2.c:1241-1249`, `clk-rcg.h:200`, parent maps):
  PASSED by inspection only.

## 8. Handoff

1. Copy the v2 payload to `/workspace/work/odessa/scripts/port-gcc-sdmmagpie.py`.
2. Run `python3 scripts/port-gcc-sdmmagpie.py` (add `--force` to overwrite).
3. Apply the unchanged Kconfig/Makefile hunks from v1.
4. Build and confirm `Registered GCC clocks` before claiming success.
