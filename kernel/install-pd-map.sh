#!/bin/sh
# Install the modem PD map next to the firmware.
#
# pd-mapper resolves the PD map from the same directory as the remoteproc
# firmware: for "modem.mdt" it reads /lib/firmware/modemr.jsn and
# /lib/firmware/modemuw.jsn.  The qrtr-tools package ships those files under
# /lib/firmware/qcom/, where pd-mapper does not look, so it logs
# "no pd maps available" and answers every domain-list request with an empty
# map.  The modem then has no "msm/modem/wlan_pd" entry (qmi_instance_id 180)
# and never reaches its WLAN protection domain.
#
# Run this once on the target (idempotent):
#
#   ./kernel/install-pd-map.sh            # install
#   ./kernel/install-pd-map.sh --check    # report only
set -eu

SRC=${SRC:-/lib/firmware/qcom}
DST=${DST:-/lib/firmware}
FILES="modemr.jsn modemuw.jsn"

check_only=0
[ "${1:-}" = "--check" ] && check_only=1

missing=0
for f in $FILES; do
    if [ -f "$DST/$f" ]; then
        echo "ok       $DST/$f"
    elif [ -f "$SRC/$f" ]; then
        missing=1
        echo "missing  $DST/$f (available as $SRC/$f)"
    else
        echo "absent   $SRC/$f" >&2
        exit 1
    fi
done

if [ "$missing" -eq 0 ]; then
    echo "PD map already installed"
    exit 0
fi

if [ "$check_only" -eq 1 ]; then
    exit 1
fi

for f in $FILES; do
    [ -f "$DST/$f" ] || cp -v "$SRC/$f" "$DST/$f"
done

# pd-mapper reads the map at startup
if command -v systemctl >/dev/null 2>&1; then
    systemctl try-restart pd-mapper
fi
echo "PD map installed; restart pd-mapper (done)"
