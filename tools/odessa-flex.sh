#!/usr/bin/env bash
# odessa-flex — one-screen status panel for the mainline Ubuntu port.
# Runs on the device (or over SSH: ssh root@172.16.42.1 odessa-flex).
set -u

R=$(printf '\033[0m'); B=$(printf '\033[1m'); D=$(printf '\033[2m')
CY=$(printf '\033[36m'); GR=$(printf '\033[32m'); YL=$(printf '\033[33m')
MG=$(printf '\033[35m'); BL=$(printf '\033[94m'); WH=$(printf '\033[97m')

row() { printf '   %s%-10s%s %s\n' "$D" "$1" "$R" "$2"; }
bar() { printf '   %s\n' "$(printf '\033[36m%s\033[0m' '────────────────────────────────────────────────────────────')"; }

os=$(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-unknown}")
krel=$(uname -r)
kbuild=$(uname -v)
upt=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
d=$((upt/86400)); h=$(((upt%86400)/3600)); m=$(((upt%3600)/60))
if [ "$d" -gt 0 ]; then up_s="${d}d ${h}h ${m}m"; else up_s="${h}h ${m}m"; fi

memt=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
mema=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
mem_u=$(( (memt - mema) / 1024 )); mem_t=$(( memt / 1024 ))

root=$(findmnt -no SOURCE,FSTYPE,SIZE,USED,USE% / 2>/dev/null | awk '{printf "%s (%s) %s, %s used, %s", $1, $2, $3, $4, $5}')
usb=$(ip -4 -o addr show usb0 2>/dev/null | awk '{print $4}')
defrt=$(ip route 2>/dev/null | awk '/^default/{print $3; exit}')

batt="n/a"
chg=$(ls -d /sys/devices/platform/soc/*/spmi-0/*/*odessa-chg 2>/dev/null | head -1)
if [ -n "$chg" ]; then
    cap=$(dd if=/sys/bus/nvmem/devices/spmi_sdam0/nvmem bs=1 skip=71 count=1 2>/dev/null | od -An -tu1 | tr -d ' ')
    vbat=$(cat /sys/bus/iio/devices/iio:device0/in_voltage_vbat_sns_input 2>/dev/null)
    en=$(cat "$chg/charge_enable" 2>/dev/null)
    if [ -n "${vbat:-}" ]; then
        v=$(awk -v u="$vbat" 'BEGIN{printf "%.2f", u/1000000}')
        [ "${en:-x}" = "1" ] && st="charging" || st="guard hold"
        batt="${cap:-?}% · ${v} V · ${st}"
    fi
fi

bl=$(cat /sys/class/backlight/backlight/brightness 2>/dev/null)
[ "${bl:-x}" = "0" ] && disp="off (WLED)" || disp="on (${bl:-?})"

if command -v docker >/dev/null 2>&1 && timeout 3 docker info >/dev/null 2>&1; then
    dv=$(timeout 3 docker info --format '{{.ServerVersion}}' 2>/dev/null)
    di=$(timeout 3 docker image ls -q 2>/dev/null | wc -l | tr -d ' ')
    dc=$(timeout 3 docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    drv=$(timeout 3 docker info --format '{{.Driver}}' 2>/dev/null)
    docker_s="${dv} · ${di} image(s) · ${dc} running · ${drv}"
else
    docker_s="not running"
fi

printf '\n'
printf '%s\n' "$(printf '\033[36m      ██████╗ ██████╗ ███████╗███████╗███████╗ █████╗\033[0m')"
printf '%s\n' "$(printf '\033[36m     ██╔═══██╗██╔══██╗██╔════╝██╔════╝██╔════╝██╔══██╗\033[0m')"
printf '%s\n' "$(printf '\033[96m     ██║   ██║██║  ██║█████╗  ███████╗███████╗███████║\033[0m')"
printf '%s\n' "$(printf '\033[96m     ██║   ██║██║  ██║██╔══╝  ╚════██║╚════██║██╔══██║\033[0m')"
printf '%s\n' "$(printf '\033[94m     ╚██████╔╝██████╔╝███████╗███████║███████║██║  ██║\033[0m')"
printf '%s\n' "$(printf '\033[94m      ╚═════╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝\033[0m')"
printf '\n'
printf '   %s%s%s\n' "$WH" "$os · aarch64 · mainline ${krel}" "$R"
printf '   %sMotorola Moto G9 Plus (XT2087-2) · SM6150 "sdmmagpie" · 8 cores%s\n' "$D" "$R"
printf '\n'
bar
row "boot"     "ABL ${CY}→${R} U-Boot ${CY}→${R} FIT ${CY}→${R} Linux ${krel}"
row "kernel"   "${kbuild}"
row "uptime"   "${up_s}"
row "memory"   "${mem_u} MiB / ${mem_t} MiB"
row "root"     "${root}"
row "usb"      "${usb:-no address} ${D}(NCM gadget)${R}"
[ -n "${defrt:-}" ] && row "gateway" "default via ${defrt} (host NAT)"
row "battery"  "${batt}"
row "display"  "${disp}"
row "docker"   "${docker_s}"
bar
printf '   %s%s%s\n' "$D" "no Android, no vendor kernel, no boot-path blobs" "$R"
printf '   %s%s%s\n' "$D" "known limit: Wi-Fi blocked (modem pool-C fault)" "$R"
printf '\n'
