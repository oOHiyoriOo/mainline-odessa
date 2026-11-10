# pd-mapper (eigener Build)

Die Ubuntu-Paketversion (`protection-domain-mapper 1.0-4ubuntu6`) meldet auf
diesem System reproduzierbar `no pd maps available`, obwohl die `.jsn`-Maps in
`/lib/firmware` liegen; ohne pd-mapper laedt das Modem die WLAN-PD nicht
(kein QRTR-Dienst 0x45 → kein `wlan0`).

Dieses Binary ist aus `https://github.com/linux-msm/pd-mapper` (HEAD,
2026-11-10) statisch fuer aarch64 gebaut, mit zwei lokalen Anpassungen:

1. `lzma`-Unterstuetzung entfernt (`json.c`, `lzma_decomp.c`): im Cross-Sysroot
   fehlt `lzma.h`; die Maps liegen unkomprimiert vor.
2. `LDFLAGS` gegen das mitgelieferte `libqrtr.a` (`re-tools/diag-aarch64`).

Installiert von `rootfs/prepare-rootfs.sh` nach `/usr/bin/pd-mapper`; die Unit
`pd-mapper.service` (ohne `qrtr-ns`-Abhaengigkeit) wird mitgeliefert.
Verifiziert: Modem startet die WLAN-PD, `wlan0` erscheint, WPA2-Association
und DHCP funktionieren.
