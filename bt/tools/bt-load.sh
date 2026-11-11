#!/bin/sh
# Load the WCN3990 Bluetooth stack.
#
# Must run *after* wlan-rails.service: the chip does not boot while
# pm6150l_l1 (xtal) / pm6150l_l2 (core) are below their vendor windows, and
# hci_qca probes (and powers up over UART) as soon as hci_uart is loaded.
#
# The controller reports no valid BD address and this vendor DTB carries no
# "local-bd-address" property, so hci_dev_setup_sync() marks it
# HCI_UNCONFIGURED and hci_dev_open() refuses to power it (-EOPNOTSUPP).
# Program the address the bootloader passes on the kernel command line while
# the controller still answers; it then transitions to configured and BlueZ
# can use it.
M=/lib/modules/6.12.0/extra
INSMOD=/usr/local/sbin/insmod_static

for m in ecc ecdh_generic bluetooth btqca btbcm hci_uart rfcomm hidp; do
    [ -f "$M/$m.ko" ] || continue
    "$INSMOD" "$M/$m.ko" || echo "bt-load: $m failed" >&2
done

mac=$(sed -n 's/.*androidboot\.btmacaddr=\([0-9A-Fa-f:]\{17\}\).*/\1/p' /proc/cmdline)
[ -n "$mac" ] || mac=$(sed -n 's/.*btmacaddr=\([0-9A-Fa-f:]\{17\}\).*/\1/p' /proc/cmdline)
