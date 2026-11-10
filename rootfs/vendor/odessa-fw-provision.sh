#!/bin/sh
# Expose the modem/WLAN firmware from the read-only vendor partition through
# /lib/firmware (ath10k, qcom_q6v5_pas and tqftpserv look there).
# Idempotent; runs before the modem is started.
set -eu
SRC=${SRC:-/vendor/firmware_mnt/image}
if [ ! -d "$SRC" ]; then
    # the vendor partition is not in fstab; mount it read-only on demand
    mkdir -p /vendor/firmware_mnt
    for cand in /dev/disk/by-partlabel/firmware_mnt /dev/sde17; do
        [ -e "$cand" ] || continue
        mount -o ro "$cand" /vendor/firmware_mnt 2>/dev/null && break
    done
fi
[ -d "$SRC" ] || { echo "no $SRC, skipping"; exit 0; }
mkdir -p /lib/firmware
n=0
for f in "$SRC"/*; do
    [ -f "$f" ] || continue
    b=$(basename "$f")
    case "$b" in
        *.mdt|*.mbn|*.jsn|*.bin|*.b[0-9][0-9]|*.elf|*.msc)
            # copy, not symlink: pd-mapper only considers regular files
            dst="/lib/firmware/$b"
            if [ ! -f "$dst" ] || [ "$(wc -c < "$f")" != "$(wc -c < "$dst")" ]; then
                cp -f "$f" "$dst"
                n=$((n + 1))
            fi
            ;;
    esac
done
echo "firmware links: $n"
