// SPDX-License-Identifier: GPL-2.0
// Read-only probe of the Qualcomm apps-SMMU (GR0 @ 0x15000000) for odessa
// WLAN bring-up. Optionally installs a bypass SMR for stream ID 0x240.
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/io.h>
#include <linux/kthread.h>
#include <linux/delay.h>
#include <linux/bitops.h>

#define SMMU_BASE   0x15000000UL
#define SMMU_SIZE   0x100000UL
#define SMMU_CR0    0x000
#define SMMU_IDR0   0x020
#define SMMU_GFSR   0x048
#define SMMU_GFSYNR1 0x054
#define SMMU_SMR    0x800
#define SMMU_S2CR   0xC00

static void __iomem *smmu;
static int fix = 1;
module_param(fix, int, 0644);

static void dump_tables(void)
{
	u32 cr0 = readl(smmu + SMMU_CR0);
	u32 idr0 = readl(smmu + SMMU_IDR0);
	int n = idr0 & 0xff;
	int i;

	pr_info("smmu_probe: CR0=0x%08x (USFCFG=%d) IDR0=0x%08x NUMSMR=%d\n",
		cr0, !!(cr0 & BIT(10)), idr0, n);
	if (n <= 0 || n > 128)
		n = 128;
	for (i = 0; i < n; i++) {
		u32 smr = readl(smmu + SMMU_SMR + 4 * i);
		u32 s2cr = readl(smmu + SMMU_S2CR + 4 * i);

		if (smr || s2cr)
			pr_info("smmu_probe: [%3d] SMR=0x%08x S2CR=0x%08x\n",
				i, smr, s2cr);
	}
}

static int bypass_thread(void *unused)
{
	u32 last = 0;
	int i;

	for (i = 0; i < 600 && !kthread_should_stop(); i++) {
		u32 gfsr = readl(smmu + SMMU_GFSR);
		u32 synr1 = readl(smmu + SMMU_GFSYNR1);

		if (gfsr != last) {
			pr_info("smmu_probe: GFSR=0x%08x GFSYNR1=0x%08x\n",
				gfsr, synr1);
			last = gfsr;
		}
		if (i && i % 100 == 0)
			pr_info("smmu_probe: heartbeat GFSR=0x%08x GFSYNR1=0x%08x\n",
				gfsr, synr1);
		msleep(10);
	}
	return 0;
}

static struct task_struct *poll_task;

static int __init smmu_probe_init(void)
{
	int i, n;

	smmu = ioremap(SMMU_BASE, SMMU_SIZE);
	if (!smmu) {
		pr_err("smmu_probe: ioremap failed\n");
		return -ENOMEM;
	}
	dump_tables();
	pr_info("smmu_probe: GFSR0=0x%08x GFSYNR1_0=0x%08x\n",
		readl(smmu + SMMU_GFSR), readl(smmu + SMMU_GFSYNR1));

	if (fix) {
		u32 idr1 = readl(smmu + 0x24);
		u32 pgsz = (idr1 & BIT(31)) ? 0x10000 : 0x1000;
		u32 npdxb = (idr1 >> 28) & 0x7;
		u32 numpage = 1u << (npdxb + 1);
		void __iomem *gr1 = smmu + pgsz;
		void __iomem *cbbase = smmu + numpage * pgsz;
		u32 free_idx = 0;
		u32 cb0_sctlr = readl(cbbase);
		u32 cb0_cbar = readl(gr1);

		pr_info("smmu_probe: CB0 SCTLR=0x%08x CBAR=0x%08x (M=%d)\n",
			cb0_sctlr, cb0_cbar, !!(cb0_sctlr & BIT(0)));

		for (i = 0; i < 128; i++) {
			if (!(readl(smmu + SMMU_SMR + 4 * i) & BIT(31))) {
				free_idx = i;
				break;
			}
		}
		pr_info("smmu_probe: routing 0x240/0x241 via SMR[%u] to CB0\n",
			free_idx);
		writel(0, smmu + SMMU_S2CR + 4 * free_idx);
		wmb();
		writel(BIT(31) | (0x1 << 16) | 0x240,
		       smmu + SMMU_SMR + 4 * free_idx);
		wmb();
		pr_info("smmu_probe: SMR[%u]=0x%08x S2CR[%u]=0x%08x\n",
			free_idx, readl(smmu + SMMU_SMR + 4 * free_idx),
			free_idx, readl(smmu + SMMU_S2CR + 4 * free_idx));
	}
	poll_task = kthread_run(bypass_thread, NULL, "smmu_probe");
	return 0;
}

static void __exit smmu_probe_exit(void)
{
	if (poll_task)
		kthread_stop(poll_task);
	iounmap(smmu);
}

module_init(smmu_probe_init);
module_exit(smmu_probe_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("odessa apps-SMMU probe");
