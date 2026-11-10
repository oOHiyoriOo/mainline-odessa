#!/bin/sh
# Set ATH10K_FW_FEATURE_MGMT_TX_BY_REF (bit 18) in the features IE of a
# WCN3990 firmware-5.bin. Idempotent; keeps a .bak on first change.
#
#   ./patch-firmware-features.sh /lib/firmware/ath10k/WCN3990/hw1.0/firmware-5.bin
set -eu
F=${1:?usage: $0 <firmware-5.bin>}
[ -f "$F" ] || { echo "missing $F" >&2; exit 1; }

# magic "QCA-ATH10K\0" = 11 bytes, padded to 12; then IEs: id, len, data.
# features IE = id 2; its data starts at offset 32, byte 2 at offset 34.
cur=$(od -An -tx1 -j34 -N1 "$F" | tr -d ' ')
case "$cur" in
0c) echo "already patched (0x0c)"; exit 0 ;;
08) ;;
*) echo "unexpected features byte 0x$cur at offset 34 - refusing" >&2; exit 1 ;;
esac

[ -f "$F.bak" ] || cp -p "$F" "$F.bak"
# POSIX printf has no \xNN; octal \014 is 0x0c
printf '\014' | dd of="$F" bs=1 seek=34 conv=notrunc 2>/dev/null
now=$(od -An -tx1 -j34 -N1 "$F" | tr -d ' ')
[ "$now" = "0c" ] || { echo "patch failed (byte is 0x$now)" >&2; exit 1; }
echo "patched: $(od -An -tx1 -j32 -N3 "$F")"
