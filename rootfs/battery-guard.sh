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
# of the installed cell (qcom,pc-temp-v1-lut, 25 C column, see
# kernel/dts/abl-merged-gcc.dts).  ABL reads the pack serial number into
# /chosen/mmi,battid; it selects the table:
#   SB18C80753 mg50-atl-5000mah   SB18C86661 mg50-scud-5000mah
#   SB18C41148 kz40-atl-3600mah   SB18C41504 kz40-swd-3600mah
# ATL and SCUD/SWD curves of the same pack differ by <1 % SoC in the band, so
# one table per pack is used.  An unknown or missing ID leaves the charger
# alone.  The gauge byte is only used when it agrees with the OCV estimate,
# which is what a working QG would do.
#
# While charging the terminal voltage is dominated by IR drop and
# polarization, so charging runs in bounded pulses: CHARGE_ON_MAX seconds on,
# then CHARGE_REST seconds off.  The decision is taken on the relaxed voltage
# at the end of the rest; this keeps the pack in the band without a current
# sensor.
#
# Charging only runs while the pack is between TEMP_MIN and TEMP_MAX C; the
# hard voltage floor still charges, a deep discharge is worse.  The mainline
# adc5 driver converts bat_therm (0x4a, 100k pull-up) with the 100k NTC table
# (adcmap_100k_104ef_104fb_1875_vref), but MG50-ATL and KZ40 packs carry a 10k
# NTC.  The guard maps the reported value back to the divider voltage through
# that table and recomputes the temperature with the pack's own NTC
# (qcom,battery-therm-kohm / qcom,battery-beta).  An unreadable value
# disables the temperature check.
#
# SDAM/IIO/CHG/STATE/NOW/BATTID can be overridden; rootfs/test-battery-guard.sh does
# that against a fake sysfs.
SOC_LOW=40
SOC_HIGH=50
CHARGE_ON_MAX=240
CHARGE_REST=180
TEMP_MIN=5
TEMP_MAX=40

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
BATTID=${BATTID:-/proc/device-tree/chosen/mmi,battid}

[ -w "${CHG:-/nonexistent}" ] || exit 0

log() { [ -w /dev/kmsg ] && echo "battery-guard: $*" > /dev/kmsg; }

id=$(tr -d '\000' 2>/dev/null < "$BATTID")
case "$id" in
SB18C80753) pack=mg50 ntc_k=10 ntc_b=3440 ;;
SB18C86661) pack=mg50 ntc_k=100 ntc_b=3440 ;;
SB18C41148|SB18C41504) pack=kz40 ntc_k=10 ntc_b=3380 ;;
*)
	# log once per boot, the timer runs every minute
	[ -e "$STATE.unknown" ] ||
		log "unknown battery id '${id:-none}', charger left alone"
	: > "$STATE.unknown"
	exit 0
	;;
esac

ocv() {
	case "$pack" in
	mg50) cat <<OCV
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
		;;
	kz40) cat <<OCV
100 4384000
98 4366500
96 4343500
94 4320400
92 4296900
90 4273100
88 4249700
86 4226400
84 4203400
82 4180600
80 4158100
78 4136400
76 4115000
74 4094300
72 4074100
70 4054200
68 4033600
66 4013400
64 3996000
62 3982200
60 3966400
58 3940800
56 3911100
54 3892400
52 3880600
50 3870600
48 3861200
46 3852600
44 3844400
42 3836600
40 3829400
38 3822700
36 3816700
34 3811500
32 3807200
30 3803000
28 3798700
26 3794300
24 3788000
22 3778800
20 3768300
18 3757100
16 3744400
14 3728800
12 3715200
10 3706600
9 3704300
8 3702800
7 3700900
6 3695800
5 3670700
4 3627100
3 3569600
2 3491200
1 3368800
0 3000000
OCV
		;;
	esac
}

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

# --- pack temperature (C) from bat_therm, see header ------------------------
t=$(cat "$IIO/in_temp_bat_therm_input" 2>/dev/null)
case "${t#-}" in *[!0-9]*|"") t="";; esac
if [ -n "$t" ]; then
	t=$(awk -v m="$t" -v k="$ntc_k" -v b="$ntc_b" '
	BEGIN {
		n = split("1831 1814 1791 1761 1723 1675 1616 1545 1463 1370 1268 " \
			"1160 1049 937 828 726 630 544 467 399 340 290 247 209 179 " \
			"153 130 112 96 82 71 62 53 46", mv, " ")
		# table steps are 5 C from -40 C; the ends are clamped, so reject them
		if (m <= -40000 || m >= 125000) exit
		i = int((m + 40000) / 5000) + 1
		u = mv[i] + (mv[i + 1] - mv[i]) * (m + 40000 - (i - 1) * 5000) / 5000
		r = 100 * u / (1875 - u)
		printf "%d\n", 1 / (1 / 298.15 + log(r / k) / b) - 273.15
	}')
fi
hot=""
if [ -n "$t" ] && { [ "$t" -lt "$TEMP_MIN" ] || [ "$t" -ge "$TEMP_MAX" ]; }; then
	hot=1
fi

# --- SoC from the OCV table (relaxed cell voltage) -------------------------
soc=""
if [ -n "$v" ]; then
	soc=$(ocv | {
		prev_s=""
		prev_v=""
		while read -r s u; do
			if [ -n "$prev_s" ] && [ "$v" -le "$prev_v" ] && [ "$v" -ge "$u" ]; then
				echo $((prev_s - (prev_s - s) * (prev_v - v) / (prev_v - u)))
				exit
			fi
			prev_s=$s
			prev_v=$u
		done
		if [ -n "$prev_v" ]; then
			if [ "$v" -gt "$prev_v" ]; then
				echo 100
			elif [ "$v" -lt 3000000 ]; then
				echo 0
			fi
		fi
	})
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
	[ -n "$hot" ] && action=stop
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
	log "stop after $((NOW - ts))s, soc=${use:-?} v=${v:-?} qg=${qg:-?} t=${t:-?}"
	;;
decide_rest)
	if [ -z "$use" ]; then
		disable
	elif [ -n "$hot" ]; then
		disable
		log "pack at ${t} C (outside ${TEMP_MIN}..${TEMP_MAX} C), charging off"
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
	elif [ -z "$hot" ] && [ -n "$use" ] && [ "$use" -le "$SOC_LOW" ]; then
		enable
		log "low ${use}% (<= ${SOC_LOW}%), charging on"
	fi
	;;
esac
exit 0
