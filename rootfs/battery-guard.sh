#!/bin/sh
# Battery charge guard for odessa (mainline 6.12): keep the pack between
# SOC_LOW and SOC_HIGH percent.
#
# Why the gauge byte is not trusted: the mainline kernel does not run the QG
# fuel gauge, so /sys/class/power_supply stays empty and the QG SDAM msoc byte
# (0x47) keeps whatever the bootloader wrote - normally 100 %.  A guard that
# trusts it disables charging at boot and never re-enables it; the pack then
# carries the peak load and slowly drains even on USB.
#
# SoC is estimated from the relaxed battery voltage with the vendor OCV table
# of the installed cell (mg50-atl-5000mah, qcom,pc-temp-v1-lut, 25 C column,
# see kernel/dts/abl-merged-gcc.dts; the mg50-scud curve differs by <1 %
# SoC inside the 40..60 % band).  The gauge byte is only used when it
# agrees with that estimate, which is what a working QG would do.
#
# While charging the terminal voltage is dominated by IR drop and
# polarization, so charging runs in bounded pulses: CHARGE_ON_MAX seconds on,
# then CHARGE_REST seconds off.  The decision is taken on the relaxed voltage
# at the end of the rest; this keeps the pack in the band without a current
# sensor.
#
# SDAM/IIO/CHG/STATE/NOW can be overridden; rootfs/test-battery-guard.sh does
# that against a fake sysfs.
SOC_LOW=40
SOC_HIGH=60
CHARGE_ON_MAX=240
CHARGE_REST=180

SDAM=${SDAM:-/sys/bus/nvmem/devices/spmi_sdam0/nvmem}
IIO=${IIO:-/sys/bus/iio/devices/iio:device0}
if [ -z "${CHG:-}" ]; then
	CHG=$(find /sys/devices -name charge_enable 2>/dev/null | head -n 1)
fi
if [ -z "${STATE:-}" ]; then
	# systemd mounts /run early; the busybox init fallback may not have it
	if [ -d /run ]; then STATE=/run/battery-guard.state
	else STATE=/tmp/battery-guard.state; fi
fi
mkdir -p "$(dirname "$STATE")" 2>/dev/null || true
NOW=${NOW:-$(date +%s)}

[ -w "${CHG:-/nonexistent}" ] || exit 0

log() { [ -w /dev/kmsg ] && echo "battery-guard: $*" > /dev/kmsg; }

byte() {
	dd if="$SDAM" bs=1 skip="$1" count=1 2>/dev/null | od -An -tu1 | tr -d " \n"
}

enable() {
	echo 1 > "$CHG"
	printf "charging %s\n" "$NOW" > "$STATE"
}

disable() {
	echo 0 > "$CHG"
	printf "idle %s\n" "$NOW" > "$STATE"
}

v=$(cat "$IIO/in_voltage_vbat_sns_input" 2>/dev/null)
case "$v" in *[!0-9]*|"") v="";; esac

# --- SoC from the OCV table (relaxed cell voltage) -------------------------
soc=""
if [ -n "$v" ]; then
	prev_s=""
	prev_v=""
	while read -r s u; do
		if [ -n "$prev_s" ] && [ "$v" -le "$prev_v" ] && [ "$v" -ge "$u" ]; then
			soc=$((prev_s - (prev_s - s) * (prev_v - v) / (prev_v - u)))
			break
		fi
		prev_s=$s
		prev_v=$u
	done <<OCV
100 4433200
98 4411600
96 4392000
94 4372100
92 4351100
90 4329400
88 4306700
86 4283000
84 4259000
82 4234800
80 4210500
78 4186800
76 4163600
74 4140800
72 4118600
70 4096900
68 4076100
66 4056000
64 4036800
62 4019200
60 4001300
58 3978300
56 3950400
54 3927900
52 3912300
50 3899200
48 3886700
46 3875200
44 3864800
42 3855100
40 3846400
38 3838500
36 3831300
34 3824900
32 3819500
30 3814300
28 3809200
26 3804200
24 3797300
22 3787100
20 3775300
18 3762500
16 3748200
14 3731200
12 3717100
10 3708800
9 3706300
8 3704800
7 3702100
6 3690000
5 3654800
4 3606600
3 3544200
2 3459200
1 3324800
0 3000000
OCV
	if [ -z "$soc" ] && [ -n "$prev_v" ]; then
		if [ "$v" -gt "$prev_v" ]; then
			soc=100
		elif [ "$v" -lt 3000000 ]; then
			soc=0
		fi
	fi
fi

# --- QG gauge byte: only when it agrees with the OCV estimate --------------
qg=$(byte 71)
case "$qg" in *[!0-9]*|"") qg="";; esac
if [ -n "$qg" ] && [ "$qg" -gt 100 ]; then qg=""; fi
if [ -n "$qg" ] && [ -n "$soc" ]; then
	d=$((qg - soc))
	[ "$d" -lt 0 ] && d=$((0 - d))
	[ "$d" -le 8 ] || qg=""
fi

use=""
[ -n "$soc" ] && use=$soc
[ -z "$use" ] && [ -n "$qg" ] && use=$qg

# --- state machine ---------------------------------------------------------
phase=""
ts=0
if [ -r "$STATE" ]; then
	read -r phase ts < "$STATE" 2>/dev/null || true
fi
case "$ts" in *[!0-9]*|"") ts=0;; esac
[ -z "$phase" ] && phase=idle

cur=$(cat "$CHG" 2>/dev/null)
# charger already on but no matching state (fresh boot, or /run was cleared)
if [ "$cur" = "1" ] && [ "$phase" = "idle" ]; then
	phase=charging
	ts=$NOW
	printf "charging %s\n" "$NOW" > "$STATE"
fi

action=""
case "$phase" in
charging)
	[ $((NOW - ts)) -ge "$CHARGE_ON_MAX" ] && action=stop
	;;
resting)
	[ $((NOW - ts)) -ge "$CHARGE_REST" ] && action=decide_rest
	;;
*)
	action=decide_idle
	;;
esac

case "$action" in
stop)
	echo 0 > "$CHG"
	printf "resting %s\n" "$NOW" > "$STATE"
	log "stop after ${CHARGE_ON_MAX}s, soc=${use:-?} v=${v:-?} qg=${qg:-?}"
	;;
decide_rest)
	if [ -z "$use" ]; then
		disable
	elif [ "$use" -ge "$SOC_HIGH" ]; then
		disable
		log "reached ${use}% (>= ${SOC_HIGH}%), charging off"
	else
		enable
		log "resume at ${use}% (< ${SOC_HIGH}%), charging on"
	fi
	;;
decide_idle)
	if [ -n "$v" ] && [ "$v" -lt 3450000 ]; then
		enable
		log "hard floor v=${v}, charging on"
	elif [ -n "$use" ] && [ "$use" -le "$SOC_LOW" ]; then
		enable
		log "low ${use}% (<= ${SOC_LOW}%), charging on"
	fi
	;;
esac
exit 0
