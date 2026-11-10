# Wi-Fi (WCN3990 / ath10k) — odessa

Alles, was der Release-Build für WLAN braucht. Installation in das Rootfs
erfolgt durch `rootfs/prepare-rootfs.sh` (Abschnitt "Wi-Fi").

## Komponenten

| Pfad | Inhalt |
|---|---|
| `firmware/firmware-5.bin` | Ath10k-Metadaten (60 B). Features-IE id 2 = `00 00 0c`: Bit 18 `MGMT_TX_BY_REF` + Bit 19 `NON_BMI`. Ohne Bit 18 ruft der Treiber `ath10k_wmi_mgmt_tx()`, das für WMI-TLV fehlt -> `-95`, Auth-Frames werden verworfen. |
| `firmware/board-2.bin` | BDF (linux-firmware, API 2, Eintrag `bus=snoc,qmi-board-id=ff`), 867116 B. Wird bevorzugt vor `board.bin` geladen. |
| `firmware/regulatory.db`, `.p7s` | Signierte Regdomain-DB (upstream-signiert, passt zu `CONFIG_CFG80211_USE_KERNEL_REGDB_KEYS`). |
| `modules/smmu_probe.c` | Apps-SMMU: routet Stream 0x240/0x241 über den freien `SMR[6]` auf CB0 (bereits S1_TRANS_S2_BYPASS). Ohne das kein CE-Traffic. |
| `modules/wlan_rails.c` | Setzt PM6150(L) WLAN-Rails auf Stock-Werte (nur `set_voltage`; `enable` oopsed im RPMh-Treiber). |
| `modules/mmi_unit_info.c` | Legt `mmi_unit_info` v3 in SMEM-Item 134 ab; ohne das stirbt der Modem-PD nach ~0,6 s. |
| `units/*.service` | `wlan-smmu`, `wlan-rails`, `mmi-unit-info` (oneshot, enabled). |
| `tools/insmod_static` | Statischer Modul-Loader für die Units. |
| `tools/iw`, `wpa_supplicant`, `wpa_cli` | Statische aarch64-Builds (iw 6.17, wpa_supplicant 2.11, libnl 3.7.0). |

`wlan/SHA256SUMS` pinnt alle Binaries/Firmware-Dateien.

## Firmware-5.bin neu erzeugen

Für ein anderes Gerät die vorhandene Datei patchen (idempotent):

```sh
./wlan/firmware/patch-firmware-features.sh /lib/firmware/ath10k/WCN3990/hw1.0/firmware-5.bin
```

Das Skript setzt in der Features-IE (id 2) Byte 2 die Bits 18 und 19
(`0x08` -> `0x0c`) und lässt die Datei sonst unverändert.

`wlanmdsp.mbn` (eigentliche FW) und die Vendor-BDF kommen weiterhin aus der
Modem-Partition (`/vendor/firmware_mnt`, Provisionierung über die vorhandenen
RFS-Links) und sind nicht Teil dieses Repos.

## Installation

Zwei Wege:

- **Image-Build:** `sudo rootfs/prepare-rootfs.sh` installiert alles in
  `build/rootfs-tree` (siehe `docs/BUILD.md` §7).
- **Laufendes System:** `wlan/install-on-device.sh` auf das Gerät kopieren und
  als root ausführen (idempotent; Module müssen zum laufenden Kernel passen).

## Inbetriebnahme

```sh
ip link set wlan0 up
iw dev wlan0 scan
# /etc/wpa_supplicant.conf: network={ ssid="..." psk="..." key_mgmt=WPA-PSK }
wpa_supplicant -Dnl80211 -i wlan0 -c /etc/wpa_supplicant.conf -B
udhcpc -i wlan0            # oder ip addr add / ip route
iw dev wlan0 link
```

## Hinweis zu älteren Kerneln

Kernel ohne Patch `0006-ath10k-snoc-sta-bssid-peer-before-vdev-start` brauchen
zusätzlich `ath10k_core.bssid_peer_first=1` (Runtime-Quirk). Mit dem
Release-Kernel entfällt das.
