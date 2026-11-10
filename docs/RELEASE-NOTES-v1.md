# odessa-linux-6.12 — V1 (2026-11-10)

Erster abgeschlossener Stand: mainline Linux 6.12 auf dem Moto G9 Plus
(`odessa`, SM6150) inklusive funktionierendem Wi-Fi.

## Neu in V1

- **Wi-Fi (WCN3990/ath10k):** `wlan0` up, Scan, WPA2-PSK-Association, DHCP,
  Ping im lokalen Netz. Drei Ursachen behoben:
  `PDEV_SET_QUIET_MODE` vor dem ersten vdev (FW-Selbst-Reset),
  fehlendes `MGMT_TX_BY_REF`-Feature-Bit (Auth-Frames verworfen, `-95`) und
  `WMI_VDEV_START` ohne BSSID-Peer (`0xffffffff`).
- **Modem stabil:** SMEM-`mmi_unit_info` v3 (`wlan/modules/mmi_unit_info.c`),
  kein Selbst-Reset nach 0,6 s mehr; QRTR/Diag nutzbar.
- **Reproduzierbarer Build:** `kernel/patches/0004-0006`, `wlan/` (Module,
  Units, Firmware, Tools), `make wlan-modules`, Rootfs-Integration in
  `rootfs/prepare-rootfs.sh`, Checks in `rootfs/check-rootfs.sh`.

## Enthaltene Komponenten (WLAN)

| Komponente | Version/Quelle |
|---|---|
| ath10k-Fixes | `kernel/patches/0004`–`0006` |
| firmware-5.bin | Feature-Bits 18+19 (`00 00 0c`), sha256 `2982f96f…` |
| board-2.bin | linux-firmware, API 2, `qmi-board-id=ff` |
| regulatory.db(.p7s) | upstream-signiert (wens), Debian `wireless-regdb` |
| iw | 6.17, statisch |
| wpa_supplicant/wpa_cli | 2.11, statisch (libnl 3.7.0, internal TLS) |
| Helper-Module | `smmu_probe`, `wlan_rails`, `mmi_unit_info` |

## Verifikation

Siehe `docs/VERIFICATION.md` (Abschnitt „Wi-Fi (WCN3990)") und
`docs/BUILD.md` §7. `make check` / `make check-rootfs` prüfen die Artefakte.

## Offen (nicht V1-blockierend)

- 5-GHz-Betrieb nicht praktisch getestet.
- MAC-Adresse pro Boot zufällig (FW liefert `00:00:00:00:00:00`).
- Suspend/PM weiterhin durch die UFS-Fixed-Rails blockiert.

## Clean-Room-Abnahme (2026-11-10)

Frischer Installationslauf: `boot_b` geflasht, `userdata` formatiert, Rootfs
per `install-to-device.sh` installiert, Reboot. Ergebnis:

| Ziel | Status |
|---|---|
| WLAN verbindet | **OK** — WPA2-PSK (`wpa_state=COMPLETED`), DHCP 192.168.179.50, Ping 3/3 |
| Docker Engine | **OK** (static 28.5.1, overlay2, Container gestartet; Bridge/NAT ohne `iptables` deaktiviert) |
| Display aus | **OK** — `odessa-screen-off` aktiv, Backlight 0 |
| LED Heartbeat | **OK** — `charging` blinzelt (0/511) |
| Sauberer Start | **OK** — `systemctl is-system-running = running` |

Dabei gefunden und behoben: `prepare-rootfs.sh` überschrieb systemd durch den
`usr/sbin/init`-Symlink; der Installer erkannte den Stub als systemd und
übersprang die Deb-Installation; `mke2fs` scheiterte an einem Probe-Mount;
`pd-mapper` (Distro) fand die Maps nicht; Vendor-Firmware musste kopiert
statt verlinkt werden.
