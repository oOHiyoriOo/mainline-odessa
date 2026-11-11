#!/bin/sh
# Program the controller's public BD address (WCN3990).
#
# The chip reports no valid address and this vendor DTB carries no
# "local-bd-address", so hci_dev_setup_sync() marks it HCI_UNCONFIGURED and
# hci_dev_open() refuses to power it (-EOPNOTSUPP).  BlueZ can only configure
# it through mgmt, and that request blocks while the setup/transition is still
# in flight, so retry it a few times with a per-attempt kill timeout.
mac=$(sed -n 's/.*androidboot\.btmacaddr=\([0-9A-Fa-f:]\{17\}\).*/\1/p' /proc/cmdline)
[ -n "$mac" ] || mac=$(sed -n 's/.*btmacaddr=\([0-9A-Fa-f:]\{17\}\).*/\1/p' /proc/cmdline)
[ -n "$mac" ] || exit 0

[ -d /sys/class/bluetooth/hci0 ] || exit 0

sleep 10
i=0
while [ "$i" -lt 6 ]; do
    cur=$(hciconfig hci0 2>/dev/null | sed -n 's/.*BD Address: \([0-9A-Fa-f:]*\).*/\1/p')
    [ "$cur" = "$mac" ] && exit 0
    /usr/bin/btmgmt public-addr "$mac" >/dev/null 2>&1
    i=$((i + 1))
done
exit 0
