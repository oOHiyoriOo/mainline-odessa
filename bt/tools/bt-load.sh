#!/bin/sh
# Load the WCN3990 Bluetooth stack.
#
# Must run *after* wlan-rails.service: the chip does not boot while
# pm6150l_l1 (xtal) / pm6150l_l2 (core) are below their vendor windows, and
# hci_qca probes (and powers up over UART) as soon as hci_uart is loaded.
M=/lib/modules/6.12.0/extra
INSMOD=/usr/local/sbin/insmod_static
for m in ecc ecdh_generic bluetooth btqca btbcm hci_uart rfcomm hidp; do
    [ -f "$M/$m.ko" ] || continue
    "$INSMOD" "$M/$m.ko" || echo "bt-load: $m failed" >&2
done
