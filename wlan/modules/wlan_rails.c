// SPDX-License-Identifier: GPL-2.0
// Raise the WLAN/BT PM6150(L) rails to the vendor (icnss) values before the
// modem/WLAN PD starts. Diagnostic module for odessa bring-up.
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/err.h>
#include <linux/regulator/consumer.h>

struct rail { const char *name; int uv; };

static const struct rail rails[] = {
	{ "pm6150_l9",  752000  }, /* vdd-cx-mx  */
	{ "pm6150l_l1", 1800000 }, /* vdd-1.8-xo */
	{ "pm6150l_l2", 1304000 }, /* vdd-1.3-rfa */
	{ "pm6150l_l10", 3312000 }, /* vdd-3.3-ch0 */
	{ "pm6150l_l11", 3312000 }, /* vdd-3.3-ch1 */
	{ "pm6150_l10",  1800000 }, /* vdd-bt-io (WCN3990 vddio) */
};

static struct regulator *held[ARRAY_SIZE(rails)];

static int __init wlan_rails_init(void)
{
	int i, ret;

	for (i = 0; i < ARRAY_SIZE(rails); i++) {
		struct regulator *r = regulator_get(NULL, rails[i].name);

		if (IS_ERR(r)) {
			pr_err("wlan_rails: get %s failed: %ld\n",
			       rails[i].name, PTR_ERR(r));
			continue;
		}
		ret = regulator_set_voltage(r, rails[i].uv, rails[i].uv);
		pr_info("wlan_rails: %s set %duV -> %d\n",
			rails[i].name, rails[i].uv, ret);
		/* Do not call regulator_enable(): the mainline RPMh driver
		 * oopses on this vendor DT node. The rails are already on.
		 */
		held[i] = r;
	}
	return 0;
}

static void __exit wlan_rails_exit(void)
{
	int i;

	for (i = 0; i < ARRAY_SIZE(rails); i++) {
		if (held[i]) {
			regulator_disable(held[i]);
			regulator_put(held[i]);
			held[i] = NULL;
		}
	}
}

module_init(wlan_rails_init);
module_exit(wlan_rails_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("odessa WLAN rail voltage setup");
