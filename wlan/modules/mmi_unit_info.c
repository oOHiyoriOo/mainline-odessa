// SPDX-License-Identifier: GPL-2.0
/* Publishes Motorola's mmi_unit_info (v3) in SMEM item 134 for the modem. */
#include <linux/module.h>
#include <linux/soc/qcom/smem.h>
#include <linux/stddef.h>
#include <linux/string.h>

#define SMEM_ID_VENDOR0 134
#define SMEM_KERNEL_RESERVE_SIZE 1024

struct mmi_unit_info {
	u32 version;
	u32 system_rev;
	u32 system_serial_low;
	u32 system_serial_high;
	char machine[33];
	char barcode[65];
	char carrier[65];
	char baseband[97];
	char device[33];
	u32 radio;
	u32 powerup_reason;
	char radio_str[33];
};

static_assert(offsetof(struct mmi_unit_info, radio) == 312);
static_assert(offsetof(struct mmi_unit_info, radio_str) == 320);
static_assert(sizeof(struct mmi_unit_info) <= SMEM_KERNEL_RESERVE_SIZE);

static int __init mui_init(void)
{
	struct mmi_unit_info *p;
	size_t size;
	int ret;

	ret = qcom_smem_alloc(QCOM_SMEM_HOST_ANY, SMEM_ID_VENDOR0,
			      SMEM_KERNEL_RESERVE_SIZE);
	if (ret && ret != -EEXIST)
		return ret;

	p = qcom_smem_get(QCOM_SMEM_HOST_ANY, SMEM_ID_VENDOR0, &size);
	if (IS_ERR(p))
		return PTR_ERR(p);
	if (size < SMEM_KERNEL_RESERVE_SIZE)
		return -EINVAL;

	memset(p, 0, SMEM_KERNEL_RESERVE_SIZE);
	p->version = 3;
	p->system_rev = 0xc000;
	p->system_serial_low = 0x489fe2f5;
	p->system_serial_high = 0;
	strscpy(p->barcode, "ZY227VHMSS", sizeof(p->barcode));
	strscpy(p->carrier, "reteu", sizeof(p->carrier));
	strscpy(p->device, "odessa", sizeof(p->device));
	p->radio = 0;		/* kstrtouint("APEU", 16) fails -> 0, as on stock */
	p->powerup_reason = 0x4000;
	strscpy(p->radio_str, "APEU", sizeof(p->radio_str));

	pr_info("mmi_unit_info: SMEM item %d written (%zu bytes)\n",
		SMEM_ID_VENDOR0, size);
	return 0;
}
module_init(mui_init);

MODULE_DESCRIPTION("Motorola mmi_unit_info SMEM item for the modem");
MODULE_LICENSE("GPL");
