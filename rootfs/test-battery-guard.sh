#!/bin/sh
# Offline regression test for rootfs/battery-guard.sh.
#
# Builds a fake sysfs in a temp dir and drives the guard with fixed NOW values,
# so the charge state machine runs without a device.  Exit status 0 = pass.
set -u

GUARD=${GUARD:-$(cd "$(dirname "$0")" && pwd)/battery-guard.sh}
[ -r "$GUARD" ] || { echo "guard not found: $GUARD" >&2; exit 1; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/iio" "$T/chg"
: > "$T/chg/charge_enable"

fail=0
ok()  { printf '  ok   %s\n' "$*"; }
bad() { printf '  FAIL %s\n' "$*"; fail=$((fail + 1)); }

# 256 zero bytes; the guard reads the QG msoc byte at offset 0x47 = 71
dd if=/dev/zero of="$T/sdam" bs=1 count=256 2>/dev/null

set_qg() { # percent
	printf "\\$(printf '%03o' "$1")" |
		dd of="$T/sdam" bs=1 seek=71 conv=notrunc 2>/dev/null
}
set_v() { echo "$1" > "$T/iio/in_voltage_vbat_sns_input"; }
no_v()  { rm -f "$T/iio/in_voltage_vbat_sns_input"; }
set_t() { echo "$1" > "$T/iio/in_temp_bat_therm_input"; }
no_t()  { rm -f "$T/iio/in_temp_bat_therm_input"; }
set_chg() { echo "$1" > "$T/chg/charge_enable"; }
set_id() { printf '%s\000' "$1" > "$T/battid"; }
set_id SB18C80753
guard() {
	NOW=$1 SDAM=$T/sdam IIO=$T/iio CHG=$T/chg/charge_enable BATTID=$T/battid \
		STATE=$T/state sh "$GUARD"
}
expect() { # name, expected charge_enable
	got=$(cat "$T/chg/charge_enable")
	if [ "$got" = "$2" ]; then ok "$1 (charge_enable=$got)"
	else bad "$1: want $2, got $got"; fi
}

echo "== battery-guard: $GUARD"

echo "-- frozen gauge must not pin the charger off"
set_qg 100
set_v 4030000
set_chg 0
rm -f "$T/state"
guard 1000
expect "100% anchor and 4.03 V (~63%) stays off" 0

echo "-- 40/50 band, pulsed charge with rest measurement"
set_v 3820000
guard 1030
expect "~34% enables charging" 1
guard 1269
expect "inside charge window stays on" 1
guard 1270
expect "charge window expired -> off" 0
grep -q '^resting ' "$T/state" && ok "state=resting" || bad "state is not resting"
guard 1449
expect "rest period not over yet" 0
set_v 3870000
guard 1450
expect "~45% after rest resumes charging" 1
guard 1690
expect "second pulse expired -> off" 0
guard 1869
expect "rest after second pulse" 0
set_v 3905000
guard 1870
expect "~51% after rest ends the charge phase" 0

echo "-- idle hysteresis: no top-up between 40% and 50%"
set_v 3870000
guard 1900
expect "~45% idle stays off" 0
set_v 3820000
guard 1930
expect "~34% idle starts charging" 1

echo "-- charger already on without state is adopted, then stopped"
rm -f "$T/state"
set_qg 100
set_v 4030000
set_chg 1
guard 3000
expect "running charger keeps charging" 1
grep -q '^charging 3000' "$T/state" && ok "state records the adoption time" ||
	bad "state does not record the adoption time"
guard 3240
expect "adopted charge window expires" 0

echo "-- gauge fallback and sanity window"
rm -f "$T/state"
set_chg 0
no_v
set_qg 30
guard 2000
expect "no vbat, gauge 30% -> charging" 1
rm -f "$T/state"
set_chg 0
set_qg 30
set_v 4030000
guard 2100
expect "gauge 30% contradicts 63% -> gauge ignored, stays off" 0
rm -f "$T/state"
set_chg 0
no_v
set_qg 200
guard 2200
expect "invalid gauge byte and no vbat -> state unchanged" 0

echo "-- battery id selects the OCV table"
rm -f "$T/state" "$T/state.unknown"
set_qg 0
set_chg 0
set_v 3840000
guard 2300
expect "MG50 at 3.84 V (~38%) starts charging" 1
rm -f "$T/state"
set_chg 0
set_id SB18C41148
guard 2400
expect "KZ40 at 3.84 V (~42%) stays off" 0
rm -f "$T/state"
set_chg 0
set_v 3300000
set_id SB18C99999
guard 2500
expect "unknown id leaves the charger alone, even below the floor" 0
[ -e "$T/state.unknown" ] && ok "unknown id is remembered" ||
	bad "unknown id is not remembered"
rm -f "$T/battid"
guard 2600
expect "missing id leaves the charger alone" 0

echo
# reported values are what mainline adc5 prints for the given real
# temperature (100k NTC table applied to the pack's own NTC)
echo "-- temperature window (5..40 C)"
rm -f "$T/state" "$T/state.unknown"
set_id SB18C80753
set_qg 0
set_chg 0
set_v 3820000
set_t 81643
guard 3000
expect "10k NTC at 25 C (reported 81.6 C) charges" 1
set_t 99156
guard 3010
expect "41 C stops a running charge" 0
grep -q '^resting ' "$T/state" && ok "hot stop rests" || bad "hot stop does not rest"
guard 3190
expect "still 41 C after rest stays off" 0
guard 3200
expect "41 C idle at ~34% does not start" 0
set_t 58089
guard 3210
expect "4 C idle does not start" 0
set_t 103360
set_v 3300000
guard 3220
expect "hard floor charges even at 45 C" 1
rm -f "$T/state"
set_chg 0
set_v 3820000
set_id SB18C86661
set_t 37931
guard 3300
expect "100k NTC at 41 C (reported 37.9 C) does not start" 0
set_t 24977
guard 3310
expect "100k NTC at 25 C charges" 1
rm -f "$T/state"
set_chg 0
set_id SB18C80753
set_t garbage
guard 3400
expect "unreadable temperature skips the check" 1
no_t

if [ "$fail" -eq 0 ]; then
	echo "battery-guard tests: PASS"
	exit 0
fi
echo "battery-guard tests: $fail FAILED"
exit 1
