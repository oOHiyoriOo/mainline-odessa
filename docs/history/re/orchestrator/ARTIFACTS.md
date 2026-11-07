# Artefakt- und Hash-Katalog — RUN 20261106-odessa-usbgadget

Stand: 2026-11-06 (UTC). Alle Groessen in Bytes, alle SHA256 ueber den
kompletten Dateiinhalt. Pfade sind absolut, damit sie ohne Kontext pruefbar
sind.

Pruefbefehl:

```bash
sha256sum <datei>
stat -c '%s %n' <datei>
```

## 1. Unveraenderte Eingangsdaten (`/workspace/firmeware/`)

| Datei | Groesse | SHA256 |
|---|---:|---|
| `stock_boot.img` | 67.108.864 | `4ddcb340509124d9178225da9dbbf1cb0dadbcc3b3eb6c1f9bb467cd811cce3d` |
| `stock_dtbo.img` | 25.165.824 | `111c29e9ddaa3d910360b03dfe518c3d0adec26e3d7698c4aa606f994c9b8a3b` |
| `unpacked_boot/kernel` | 35.493.904 | `77d455f574ffb80f4b904ffeefd345aa66b99907738b5e09bc04998175b59f5b` |
| `unpacked_boot/dtb` | 393.031 | `0cd0fdeb9522c0ca13a015344bb482f3a062ce6c8076df3a65e26e5124d979eb` |
| `running_kernel.config` | 168.691 | `bb3654769470d5ea7fd22b29d4753c1568bbd66398c14cea8023632418b181f5` |
| `partitions.txt` | 5.774 | `3eab7929e65b8a6810badc7c0209f05167954a39024857f21fedbfd99e6c61db` |
| `cmdline.txt` | 1.298 | `deff7660f6173042e6f43c339706e7c604f76bb708a3885f31f9b8255723e197` |
| `version.txt` | 263 | `4bffa8ee7dcc22061d3b09eb20403f7e847291fd86edeea69aae5ef1f2d6d161` |
| `firmware.tar.gz` | 55.044.578 | `4b6709a39134f2c21d8a3a6ed73544f9785706bf52447ad6acd3a06bece3518f` |

Diese Dateien wurden nie veraendert. Alle abgeleiteten Artefakte liegen unter
`/workspace/work/odessa/` oder im host-sichtbaren Dist-Bundle.

Herkunft: Die Stock-Dateien lagen bereits vor Run-Start unter
`/workspace/firmeware/` (mtime 2026-11-06 12:37, Run-Start 13:58). Sie wurden
in diesem Run nicht neu beschafft; verifiziert wurden lediglich Existenz,
Groesse, SHA256 und der Boot-Header. `stock_dtbo.img` wurde nicht verwendet.

## 2. Kernel 4.14.190 (Produktivpfad)

| Artefakt | Groesse | SHA256 |
|---|---:|---|
| `build/arch/arm64/boot/Image.gz` | 13.356.663 | `d13437cbe1244aa5e306544a57643e2764dcd4b3135a4a142bf44e1193f6245d` |
| entpacktes `Image` (nicht separat abgelegt) | 35.489.808 | — |

Quelle: `LineageOS/android_kernel_motorola_sm6150`, Commit
`112b525abbc08298256abedbf984e0e8c20d0338`, `Makefile` 4.14.190.
Build: `-j12`, `nice -n 10`, 0 Errors, 1 Warnung (`blk-mq.c`, align mismatch,
bootpfad-irrelevant).

## 3. Initramfs und RootFS

| Artefakt | Groesse | SHA256 | Rolle |
|---|---:|---|---|
| `out/initramfs.cpio.gz` (v3, aktuell) | 3.765.922 | `b4f6e19ab94085f28f7c1b1d3ace063dd568af638fb057b4dd47a2136974b833` | Prep/Rescue + Ubuntu-Switch |
| `out/rootfs.tar` | 81.981.440 | `2d8e9f3a1615a554e3baf4d0111fc3e61470e7d55532218f2f0e018b2e45b2c6` | installiertes Ubuntu 22.04.5 |
| `rootfs-dl/ubuntu-base-22.04.5-base-arm64.tar.gz` | 27.671.306 | `075d4abd2817a5023ab0a82f5cb314c5ec0aa64a9c0b40fd3154ca3bfdae979f` | benutzte Base |
| `rootfs-dl/ubuntu-base-26.04.1-base-arm64.tar.gz` | 35.092.106 | `5a1906794ced63a71a8119c3f211ef5f0bbe0a243001b4bbd41fdf80c5b219fd` | geladen, **nicht benutzt** |

Historische Initramfs-Staende:

| Stand | Groesse | SHA256 |
|---|---:|---|
| v1 (nur BusyBox/Telnet) | 988.877 | `75976691f9dfd6b86a847b45401e59af49804ab0dde79d228707a2e83c1a7f62` |
| v2 (DHCP + Dropbear) | 2.003.054 | `ffa05948…0a41` (Kurzform aus Spoke-Notiz) |
| v3 urspruenglich | 3.765.783 | `b9fba3b8…1e01` (Kurzform aus Spoke-Notiz) |

## 4. Boot-Images

Alle mit `mkbootimg` v2, `--pagesize 4096`, `--base 0`,
`kernel_offset 0x8000`, `ramdisk_offset 0x1000000`, `tags_offset 0x100`.

| Datei | Groesse | SHA256 | Zweck / Ergebnis |
|---|---:|---|---|
| `out/test-boot-stock.img` | 36.884.480 | `ac5e8a4109e01cef5e68060e16036643cdd192d0cad8558153d666ef57eadd8e` | Stock-Kernel + Stock-DTB + unser Initramfs; **Smoke-Test bestanden** |
| `out/test-boot-414190.img` | 14.745.600 | `05cb8b46641ad27ecb96996704202f879b5fa92012f8ab4a4e2034910f8ac1fe` | erster Eigenbau-Kernel + Stock-DTB; **bestanden** |
| `out/test-boot-414190-v2.img` | 15.761.408 | `77daedc9c7e941b71a7156dec7805c807a77accd08e88f2e174abf64800e8c01` | v2 Haertung (DHCP/SSH); **bestanden** |
| `out/test-boot-414190-v3-prep.img` | 17.522.688 | `14c05cacf730fb52d48edfb8ff6f61a7727fb978ffe3ae9ffce1bc0b8ec24d7d` | Prep-Initramfs, kein `odessa.boot` |
| `out/test-boot-414190-v3-ubuntu.img` | 17.522.688 | `055cbd1c6f94a47ebb32e68b447777f9d7e5e86e7a6078d73b4e58a2640e339d` | erster Ubuntu-Boot |
| `out/test-boot-414190-v3b-ubuntu.img` | 17.522.688 | `4d8d69f5014df2debe8f3c2f0f82520dfd6956b6482b9a7b0ee1bc62700f3e1d` | Rebuild, tatsaechlich für T12 benutzt; durch `odessa-ubuntu` ersetzt |
| `out/test-boot-odessa-prep.img` | 17.522.688 | `1f9b6c1e67e51df0057ddb4aabe7978c509bdd6c445a5ab206c77411f95dd9fc` | **aktuelles** Prep-/Rescue-Image (auch in `boot_b`) |
| `out/test-boot-odessa-ubuntu.img` | 17.522.688 | `569de7defb65a5aad3eac80b1f632674534e2ad2614399a9e55716eb46ef894e` | **aktuelles** Ubuntu-Boot-Image |
| `out/test-boot-414190-mydtb.img` | 17.133.568 | `90a1a23a165c1cec977d394f199e16c5e49a30011f307ff24aa03c75ed177576` | 4.14 + eigenes Minimal-DTB, **Fehlschlag** |
| `out/test-boot-414190-mydtb2.img` | 17.133.568 | `823b75096d2e8222b32c53cac6c54426309317debc7161527c4adfa773de26c4` | wie oben + `qcom,msm-id/board-id`, **Fehlschlag** |
| `out/test-boot-414190-stockfb.img` | 17.522.688 | `afb33bc4c82fa48b9a22529c38910e5e9089772128e1ff4c39a3c58effca369f` | rekompiliertes Stock-DTB + fb, ohne Padding, **Fehlschlag** |
| `out/test-boot-414190-stockfb2.img` | 17.526.784 | `b2d0bc711151c0c0e179026e127e3e491e5110f6bbefac0a333942d90af7ffe1` | wie oben + `dtc -p 4096`, **Fehlschlag** |
| `out/test-boot-mainline-m0.img` | 18.464.768 | `39f2337142f7da83c95505a2654fa6b91cb93bda825fd6b47559659addb3610f` | Linux 6.12 + Minimal-DTB, **kein Boot** |
| `out/test-boot-mainline-stockdtb.img` | 18.853.888 | `f4a2fc7b11088d050015db208754059287821ae83bbcbbe750200f66bf07f877` | Linux 6.12 + Original-DTB, **kein sichtbarer Boot** |

Gepackte Header (Prep/Ubuntu, mit `unpack_bootimg.py` gegengeprueft):
`ANDROID!`, v2, Page 4096, Kernel 13.356.663, Ramdisk 3.765.922,
DTB 393.031. Prep-Cmdline ohne, Ubuntu-Cmdline mit `odessa.boot=ubuntu`.

## 5. Mainline-Artefakte

| Artefakt | Groesse | SHA256 |
|---|---:|---|
| `mainline/linux-6.12.tar.xz` | 147.906.904 | `b1a2562be56e42afb3f8489d4c2a7ac472ac23098f1ef1c1e40da601f54625eb` |
| `mainline/linux-6.12/arch/arm64/boot/Image.gz` | 14.686.906 | `3f8d929965aed82b2dda1be70c5bc8c0d5c8455a14ec20978e14eef3f4d0fdb7` |
| `.../dts/qcom/sm6150-moto-odessa.dtb` | 2.763 | `e276c0a569eae0bce8f19c181484b891798a4cdfed354af23a1b14de4e27d61e` |
| `.../dts/qcom/sm6150.dtsi` | 2.179 B (93 Zeilen) | Quelltext, kein Hash |
| `.../dts/qcom/sm6150-moto-odessa.dts` | 2.009 B | Quelltext, kein Hash |

`Image.gz` gebaut mit `-j12`, `nice -n 10`, zusaetzlich
`HOSTCFLAGS=-I/srv/miniconda3/include` und
`HOSTLDLIBS_extract-cert`/`HOSTLDLIBS_sign-file` (OpenSSL aus Miniconda).
`CONFIG_MODULE_SIG` deaktiviert; `CONFIG_SYSTEM_TRUSTED_KEYRING=y` bleibt und
erzwingt weiterhin den `extract-cert`-Hostbuild.

DTB-Zwischenstand: erste Version 2.643 B
(`fb4d41af407232329d1f0203f6d45dcd62e44ffc8e2cf8cb58e3eb93fa6ee632`, ohne
`qcom,msm-id`), endgueltige Version 2.763 B mit Vendor-IDs.

## 6. DTB-Experimente

| Datei | Groesse | SHA256 | Inhalt |
|---|---:|---|---|
| `out/stock-fb.dtb` | 396.294 | `6987bc1d4efa353df2d7037fa1507c92d6850446f896614d63de4b4ddf6b242c` | Original-Stock-DTS + `simple-framebuffer`, `dtc -p 4096` |
| `/tmp/stock.dts` | — | — | dekompiliertes Original (nicht dauerhaft, Quelle = `unpacked_boot/dtb`) |
| `/tmp/stockfb.dts` | — | — | dekompilierte Fassung von `stock-fb.dtb` |

Vergleich: Original 393.031 B, rekompiliert ohne Padding 392.198 B, mit
Padding 396.294 B. Root-Properties, `qcom,msm-id`/`board-id`, 1.222 Phandles
und Node-Reihenfolge blieben gleich; trotzdem vom Bootloader abgelehnt.

## 7. Dist-Bundle (host-sichtbar, persistent)

`/home/zero/.local/share/opencode/re-tools/_scratch/odessa/dist/`

Enthaelt: `Image.gz`, `initramfs.cpio.gz`, `rootfs.tar`, `README.md`,
`scripts/`, `id_ed25519.pub`, Prep-/Ubuntu-Images sowie die Mainline- und
DTB-Testimages. Der private SSH-Key liegt eine Ebene hoeher
(`_scratch/odessa/id_ed25519`, Mode 600) und ist **nicht** Teil des Bundes.

Hinweis: Das Dist-Bundle ist ein Komfort-Kopie-Stand. Fuer reproduzierbare
Builds sind `out/` und die Skripte unter `/workspace/work/odessa/` maßgeblich.
`dist/README.md` und `dist/docs/` wurden am 2026-11-06 auf diesen Stand
gebracht; `dist/initramfs.cpio.gz` und `dist/scripts/install-to-device.sh`
wurden mit den aktuellen Fassungen synchronisiert.

## 8. Nicht dauerhaft abgelegte Zwischenartefakte

- Entpacktes Kernel-`Image` (35.489.808 B) — nur fuer Pruefung entpackt.
- `/tmp/boot_a.hdr`, `/tmp/boot_b.hdr` — nur zur Slot-Pruefung gelesen, danach
  geloescht.
- pstore-Snapshots auf dem Geraet (`/tmp/pstore-*`) — fluechtig, werden bei
  jedem Rescue-Boot neu kopiert.
- Build-Logs `/tmp/mainline-build*.log`, `/tmp/defconfig.log`,
  `/tmp/olddef.log` — fluechtig, Inhalte in STATUS.md zusammengefasst.
- `/tmp/stockbase-dtbo0.dts` — aus `/tmp/stock.dts` erzeugte Quelle fuer den
  Stock-Base-Test-DTB; das DTB selbst liegt dauerhaft in `out/`.

## 9. DTBO0-Testartefakte (2026-11-06, nicht geflasht)

Gebaut fuer den Test mit geleertem `dtbo_a` (Slot `a`), `dtbo_b` bleibt
unangetastet. Alle Images: Header v2, Page 4096, Kernel `Image.gz` 6.12,
Ramdisk `out/initramfs.cpio.gz`, Cmdline
`console=tty0 loglevel=8 ignore_loglevel keep_bootcon fbcon=map:0
pstore.backend=ramoops panic=10`.

| Artefakt | Groesse | SHA256 |
|---|---:|---|
| `out/test-boot-mainline-stockbin.img` | 18.870.272 | `c188048a33a157d89383d9dc007b307b330fd21a6d450341c5789ab44140790b` |
| `out/test-boot-414190-stockbin-dtb.img` | 17.539.072 | `81d747080d1dd1940c0a25805c40079f4d1bc8c49af4a8bd3cb112a7c8c74240` |
| `out/test-boot-414190-stockbin-emptycmd.img` | 17.522.688 | `26e1483650944b42077927e9eaa836cdc87fd6dd9f73f67fce731df08d945708` |
| `out/test-boot-414190-stockdtb-emptycmd.img` | 17.522.688 | `cdf72ce9706d11c4ca9251b683c05cf2062cfd9e6ee25cf543786248c63b0454` |
| `out/test-boot-414190-pstore-ro.img` | 17.522.688 | `0bd606e10c84111f2ccec5b1c4a560cb9c76739a7bd60fcb0828503cbfb383a6` |
| `out/test-boot-mainline-stockdtb-usb2.img` | 19.009.536 | `bf0ac350a4f4800c3f0c5a02dd051c28a07ea2a68ecd51800ce9a0dbadc8ed66` |
| `out/test-boot-mainline-stockbin-usb2-fb.img` | 19.009.536 | `2f859a3bb7ee342114da7731d835ccf16e64b0953b2f78f34080292c54c904a4` |
| `out/test-boot-mainline-stockbin-emptycmd.img` | 18.853.888 | `470480ec4ab2bb1c485d93359feb5e830db631a9aa0100343ae73d4ec0cb6f9f` |
| `out/test-boot-mainline-stockdtb-emptycmd.img` | 18.853.888 | `7832c9d0ac9c71eec0509bf3127e65f4c29cc8e6934f7fa68b258ee4eb72bea1` |
| `out/test-boot-mainline-stockbin-cmdline.img` | 18.853.888 | `155ca8e2b20a9ae8cbb55127d6d8cf49bdb20b6f3d6a0ccb8f368d8f1c1d5dd5` |
| `out/test-boot-mainline-stockdtb-cmdline.img` | 18.853.888 | `665f7381fbdf17a5de3d52ff5d3deed0c41c0d686a9e21ca92d54ae54744224e` |
| `out/test-boot-mainline-dtbo0-explicit-cmdline.img` | 18.472.960 | `0aa910d60af5cd2465f71bd874038511ecf4c4d2b858cc7447fe53972a10843c` |
| `out/test-boot-mainline-dtbo0-inject.img` | 18.472.960 | `4da01e7271f310309f2be8dc5740b2e435bef11921578b8b2094a1ecf9fbdc4a` |
| `out/test-boot-mainline-dtbo0-explicit.img` | 18.472.960 | `aff4d8cb378398ef87f897c3418dd583b7db6557417ac82b6eb53005e4d4d179` |
| `out/test-boot-mainline-stockbase-dtbo0.img` | 18.862.080 | `6ebe5f718e3fd974aa1599e491792e9b94e293bd47946e7958937589525ffa79` |
| `out/empty-dtbo-24MiB.img` | 25.165.824 | `95aeaae03b56c171cf88753c821630a3c24f1fcf406cec3e17d56781aa3f8369` |
| `out/mini-dtbo-odessa.img` | 25.165.824 | `e455c919c92fd04c8d2a9a09ff3205032f7aab71f1505c595d2585f879b86e77` |
| `out/mini-dtbo-avb.img` | 25.165.824 | `0fc5347b605d3e84e0822cb2d4eff46c4547cc0595383cfb53ac9b17c713630c` |
| `out/stock-patched-fb.dtb` | 392.185 | `5ee940b03eb50a202c24ee94fb0eb9ed47dba6e9d2a1ac62b31b2c4784206697` |
| `out/stockbin-emptycmd.dtb` | 392.277 | `40131f3853749f3bb228418fa223484c3b9a1aea084e698ed90317f6aefffe1c` |
| `out/stock-emptycmd.dtb` | 392.099 | `807a8d68f6198e3f7dc81c402465f547674d95f5baf6afe5adff8779a6c94073` |
| `out/Image-6.12-original.gz` | 14.686.906 | `3f8d929965aed82b2dda1be70c5bc8c0d5c8455a14ec20978e14eef3f4d0fdb7` |
| `out/Image-6.12-cmdline.gz` | 14.686.184 | `b85573f63daf601b5cdc1aab10a0d03373d8317e9a2b050f01c8fd8ba44fce65` |
| `out/Image-4.14-production.gz` | 13.356.663 | `d13437cbe1244aa5e306544a57643e2764dcd4b3135a4a142bf44e1193f6245d` |
| `out/Image-4.14-pstore-ro.gz` | 13.354.918 | `cd1eeea518241193a0c2e4ad710ca0cf98aac9da6c2bb6985a4cb8d19bffcb68` |
| `out/Image-6.12-usb.gz` | 14.826.870 | `b719e3f7da013a2d5fdf575a665ecaf874cdfc1d6dd918bb223e82e72904e387` |
| `out/Image-6.12-usb2.gz` | 14.842.986 | `9979fd760a6c4c726ccf111b79de2ec3c51b2ea78cdd372fe162cadaf9270ecf` |
| `out/stockbin-usb2.dtb` | 392.273 | `5a69ec01a2aec6262e1a13f251532900b9cf427998d94e08319d4f6dfa70d23e` |
| `out/stock-usb2.dtb` | 392.079 | `5ffca28d15436cd246a8298a481b0612491b922540ae84c11c4ba97d2b003823` |
| `out/stock-patched-fb-pad.dtb` | 408.569 | `b0d4322e6ea6d25b380bb65265e8c0a0e72b2f1137319a102ce3d8cf98aa2538` |
| `out/stockbase-dtbo0.dtb` | 400.561 | `3fa9ba5dc4b9f7a5bd999874128a8c926119d6b139c6fa3502a2eb7587051747` |
| `.../sm6150-moto-odessa-dtbo0-inject.dtb` | 10.823 | `a933751a7023abf0e2d8dc3847ebcc222a04a1b322d22be8ce42ce4bf3e52c51` |
| `.../sm6150-moto-odessa-dtbo0-explicit.dtb` | 11.191 | `b21ef32a2a15d1d16286b7876b6cbf3ce584a25f8980c416bbed6e106148f921` |

Quellen:

- `.../sm6150-moto-odessa-dtbo0-inject.dts` (1.924 B): Minimal-DTB mit
  leerem `/memory`, Board-ID `<0x49 0xc000>`, `model="odessa"`,
  `compatible="qcom,sdmmagpie"`, kein `qcom,pmic-id` (im Stock-DTB, in allen
  DTBO-Entries und im Live-Tree nicht vorhanden), `dtc -@ -p 8192`.
- `.../sm6150-moto-odessa-dtbo0-explicit.dts` (1.861 B): wie oben, aber
  sechs explizite Memory-Ranges aus `/proc/iomem`.
- `stock-patched-fb.dtb`: **binaer** aus `unpacked_boot/dtb` mit `fdtput`
  gepatcht (kein `dtc -I dtb -O dts`-Roundtrip). Alle 1.279
  `__symbols__`-Eintraege und numerischen Phandles bleiben erhalten; alle
  190 Fixup-Labels des DTBO-Entry 2 sind aufloesbar (lokal geprueft). Fuer
  den Test mit **aktivem** `dtbo_a` gedacht. `stock-patched-fb-pad.dtb`
  ergaenzt 16 KiB freien FDT-Platz (nur `totalsize` angepasst), damit der
  ABL-Overlay-Merge Puffer hat; dieses DTB steckt im Testimage.
- `stockbase-dtbo0.dtb`: dekompiliertes Stock-DTS + `simple-framebuffer` +
  `ramoops`, Board-ID `<0x49 0xc000>`, leerer `/memory`-Platzhalter;
  mit `dtc -@ -p 8192` gebaut. Kein Overlay-Merge noetig.

Sicherheitscheck `dtbo_a` (2026-11-06, read-only): Die ersten 24 MiB von
`/dev/block/sde23` sind **byte-identisch** mit `stock_dtbo.img`
(`111c29e9…a3b`); `dtbo_b` (`/dev/block/sdf23`) ebenfalls. Die 82 Extrabytes
beim `adb exec-out dd` waren nur Toybox-`dd`-Statistik auf stdout, keine
Partitionsdaten.

**ABL-Befund (2026-11-06, logfs cycles 626–637):**

- `out/empty-dtbo-24MiB.img` ist **unbrauchbar**. ABL liest
  `Dtbo hdr magic mismatch 0, with D7B7AB1E`, dann
  `Error: Device Tree blob not found` und `BootLinux() failed: Not Found`.
  Ein genulltes `dtbo_a` wird also nicht als „skip" behandelt, sondern
  verworfen. Die „Boot-Loop" von `explicit` war ABL-Retry, kein Kernel-Panic.
- Der erste `stockbin`-Test (Zyklus 627) wurde durch
  `ERROR: NO ACTIVE SLOT FOUND` / `No bootable A/B slot` abgebrochen, bevor
  das Image bewertet wurde. Der Test ist daher **nicht** aussagekräftig.
- `out/mini-dtbo-odessa.img` (valider DTBO-Header, ein No-Op-Overlay, aber
  ohne AVB-Metadaten) ist ein Zwischenstand; ABL verlangt beim Flashen
  `dtbo salt/digest`. `out/mini-dtbo-avb.img` behaelt den Stock-AVB-Footer
  und die Stock-`vbmeta`-Struktur; die AVB-Hashes passen allerdings nicht
  mehr zum geaenderten DTBO-Inhalt. Ob ABL das im Orange-State akzeptiert,
  ist **nicht getestet**.

**Cmdline-Hypothese (extern, Gemini, 2026-11-06):** Der `boota (786)`-Assert
soll durch eine nicht-leere `--cmdline` im `boot.img`-Header ausgeloest
werden (Motorolas `UpdateCmdLine()`/`StrCatS`-Puffer). Dagegen gebaute
Varianten mit **leerem Header-Cmdline** und Kernel-Args in
`/chosen/bootargs`:

- `test-boot-414190-stockbin-emptycmd.img` (4.14 + gepatchtes Stock-DTB),
- `test-boot-mainline-stockbin-emptycmd.img` (6.12 + gepatchtes Stock-DTB),
- `test-boot-mainline-stockdtb-emptycmd.img` (6.12 + Original-Stock-DTB),
- `stockbin-emptycmd.dtb` / `stock-emptycmd.dtb` mit
  `chosen/bootargs = "console=tty0 ... clk_ignore_unused pd_ignore_unused
  panic=5"`.

Zusaetzlich wurde 6.12 mit eingebauter Cmdline gebaut:
`CONFIG_CMDLINE="console=tty0 loglevel=8 ... panic=5"`,
`CONFIG_CMDLINE_FORCE=y`, `CONFIG_CMDLINE_FROM_BOOTLOADER` aus ->
`out/Image-6.12-cmdline.gz` (14.686.184 B,
`b85573f6…ce65`). Die Original-`Image.gz` liegt als
`out/Image-6.12-original.gz` (`3f8d9299…fdb7`) daneben. Damit existieren
Images mit Original-Kernel + leerer Header-Cmdline sowie mit
Force-Cmdline-Kernel + leerer Header-Cmdline.

Diese Hypothese ist **nicht lokal verifiziert**; die Tests stehen aus.

**Read-only-pstore-Rettung:** Der 6.12-Log im pstore wurde beim naechsten
4.14-Boot teilweise ueberschrieben. Dafuer wurde `Image-4.14-pstore-ro.gz`
gebaut (`CONFIG_PSTORE_CONSOLE` und `CONFIG_PSTORE_PMSG` **aus**,
`CONFIG_PSTORE_RAM=y`); das Initramfs kopiert die vorhandenen
pstore-Records, ohne den Console-Ringpuffer neu zu beschreiben. Image:
`test-boot-414190-pstore-ro.img`. Die Produktions-Config wurde danach
wiederhergestellt; `build/arch/arm64/boot/Image.gz` ist aktuell der
RO-Kernel, die Produktionskopie liegt als `out/Image-4.14-production.gz`
(`d13437cb…6245d`).

**6.12-USB2/Display-Build (2026-11-06):** Der 6.12-Log zeigt, dass der
Kernel bis `/init` kommt, aber `CONFIG_USB_CONFIGFS`, `USB_F_NCM`,
`PHY_QCOM_QUSB2`, `PHY_QCOM_QMP*`, `PHY_QCOM_USB_HS` und
`SCSI_UFS_QCOM` nur `=m` waren (Initramfs laedt keine Module). Neu gebaut:
- `Image-6.12-usb.gz`: USB/PHY/UFS als `=y`.
- `Image-6.12-usb2.gz`: zusaetzlich `SM_GCC_7150=y`, `PINCTRL_SM7150=y`.
- `stockbin-usb2.dtb` / `stock-usb2.dtb`: Stock-DTB mit
  `qcom,sm7150-gcc`, `qcom,sm7150-tlmm`, `qcom,dwc3`,
  `qcom,qusb2-v2-phy`, `dr_mode=peripheral`, `maximum-speed=high-speed`,
  nur QUSB2-PHY; `stockbin-usb2.dtb` zusaetzlich
  `memory-region=<&cont_splash_region>` am Framebuffer.
- `test-boot-mainline-stockdtb-usb2.img` (Original-DTB, USB2) und
  `test-boot-mainline-stockbin-usb2-fb.img` (gepatchtes DTB, USB2 + fb).

Hintergrund: `simple-framebuffer` scheiterte mit
`could not acquire memory region [mem 0x9c000000-0x9c9e33ff]` und
`probe ... failed with error -12`, weil die Region durch `reserved-memory`
belegt ist. `simpledrm` bevorzugt `memory-region` gegenueber `reg` und
nutzt dann `devm_memremap`; die DTB-Variante setzt diesen Phandle auf
`cont_splash_region` (`0x4c2`).

**Ergebnis:** Auch mit `memory-region` bleibt `simpledrm` mit einem
`memremap`-Calltrace haengen; `/init` meldet `no UDC found`, und im Log
gibt es **keine** `dwc3`/`qusb2`-Probe. Der Vendor-DTB-Pfad ist fuer
USB/Display damit ausgereizt.

**Mini-DTBO-Test:** ABL lehnt ein selbstgebautes DTBO per AVB ab:
`dtbo: Hash of data mismatch digest in descriptor. Image corrupted?` ->
`erasing dtbo_a`. Ein Custom-DTBO ist ohne Motorola-Signatur nicht
flashbar. `dtbo_a` ist aktuell leer; das Stock-Overlay (ramoops) fehlt,
deshalb kein pstore. Naechster Pfad: Stock-DTBO wiederherstellen und
mainline USB-Nodes in das **Boot.img-DTB** (unsigned) einbauen oder
U-Boot chainloaden.

`qcom,pmic-id`: **nicht vorhanden** — weder im Stock-DTB (`/tmp/stock.dts`),
noch in einem der drei DTBO-Entries, noch unter `/proc/device-tree`. Es wird
daher bewusst nicht erfunden; die Abwesenheit entspricht exakt dem
funktionierenden Stock-DTB.

Wiederherstellung:

```bash
fastboot flash dtbo_a /workspace/firmeware/stock_dtbo.img
# oder falls unterstuetzt:
fastboot erase dtbo_a
```

`stock_dtbo.img` hat SHA256 `111c29e9ddaa3d910360b03dfe518c3d0adec26e3d7698c4aa606f994c9b8a3b`
und exakt 25.165.824 B.

---

## 10. U-Boot-Chainload-Artefakte (Vorbereitung, 2026-11-06)

Ablage: `/workspace/work/odessa/.re/uboot/` (abgeleitete Daten, Originale
unveraendert). Detailplan: `orchestrator/UBOOT-PLAN.md`.

| Datei | Groesse | SHA256 | Zweck |
|---|---:|---|---|
| `stock-dtbo-entry0.dtbo` | 267.025 | `91b70dfc11b349fe0eba988afbbe367d9e04acb5fc8fa8bf6e7b0210d976f406` | Stock-DTBO Entry 0 (`<0x48 0xb200>`) |
| `stock-dtbo-entry1.dtbo` | 267.025 | `dfa2887c78c3599cb6557ec0b1da58816c1dcf1c0a6dc2f2899ceaf45c444c2e` | Stock-DTBO Entry 1 (`<0x48 0xa100>`) |
| `stock-dtbo-entry2.dtbo` | 266.333 | `6d96c774b56d63aa696c547f0b17a4fcb89b24d513e0b9b22ef30e5ea4e1681d` | Stock-DTBO Entry 2 (`<0x49 0xc000>`, odessa) |
| `stock-dtbo-entry2.dts` | 427.451 | `bf0df6cfce2cd5d877526eb23906a2ff2ef1aaec0ab2980859028fc44adade08` | decompiliertes Entry-2-Overlay |
| `stock-base.dts` | 502.431 | `e56d8795b71b4e1f8627c786adc40614381793dd194953715b2aef3130689798` | decompilierter Stock-DTB |
| `fit-6.12.its` | — | — | FIT-Quelle (Kernel 6.12, minimales DTB, Initramfs) |
| `build-fit.sh` | — | — | `mkimage -f fit-6.12.its` |
| `pack-uboot-bootimg.sh` | — | — | `u-boot.bin` + FIT -> `boot.img` v2 |

**Bekanntes Problem:** `fdtoverlay` (Host 1.6.1 und Kernel-6.12-Build)
scheitert beim Merge von Entry 2 auf den Stock-DTB mit
`FDT_ERR_BADOVERLAY`. Fuer den ersten U-Boot-Test wird daher das minimale
odessa-DTB (`sm6150-moto-odessa-dtbo0-explicit.dtb`, 11.191 B) mit
`ramoops@af000000` und `simple-framebuffer` verwendet.

**FIT-Ladeadressen:** Kernel `0x90000000`, FDT `0x8F000000`, Ramdisk
`0xA0000000`; FIT-Quelle bei `0x85367000` (ABL-Ramdisk-Adresse).

### 10.1 Gebaute U-Boot-Artefakte (2026-11-06)

Ablage: `/workspace/work/odessa/.re/uboot/`.

| Datei | Groesse | SHA256 | Zweck |
|---|---:|---|---|
| `build-odessa/u-boot.bin` | 1.509.904 | `7e7a4416a5f5831e43eeb20be8e0464d7eaba3f98a776f88c82ca22b9574597b` | U-Boot ARM64-Image (kombiniert, prevbl/scan) |
| `build-odessa/u-boot-dtb.bin` | 1.509.904 | `7e7a4416…` | identisch, als Boot.img-Payload verwendet |
| `build-odessa/u-boot.dtb` | 82.696 | `8fa3d1cb186d8df8950bd6698b1cdc31b8f9f725b4fd4a5f704e0b15c5f9d20a` | odessa-U-Boot-DTB |
| `fit-6.12.itb` | 18.465.493 | `0a62cebb80b1e16a488f928cba930a837ffb51d076a0149a3e238ca9b915427a` | FIT (6.12 + odessa-DTB + Initramfs) |
| `test-boot-uboot-odessa.img` | 20.377.600 | `14350385d3b1028a66652b03c6f7c93424d644f6a8f7d3802de45abd4b690f1c` | **Test-Boot.img** (RAM only, prevbl/scan) |

**Image-Header:** `text_offset=0x0`, `image_size=0x2b5dc8`, `flags=0xa`,
`ARMd` @ `0x38`.

**Boot.img-Header:** `ANDROID!` v2, Page 4096, Kernel 1.509.904 @
`0x8000`, Ramdisk 18.465.493 @ `0x1000000`, DTB 393.031 @ `0x1f00000`,
leere Cmdline.

**DTB-Knoten:** `memory@80000000` zwei Baenke
(`0x80000000+0x80000000`, `0x100000000+0x7dd00000`),
`simple-framebuffer` @ `0x9c000000` (1080×2400, stride 4320,
`a8r8g8b8`), `uart6@a88000` `qcom,geni-debug-uart` okay (ohne Pinctrl),
`usb@a600000` `qcom,snps-dwc3` peripheral/HS, `phy@88e2000`
`qcom,qcs615-qusb2-phy` okay.

**Quellen:** `dts/qcs615-odessa.dts`,
`dts/qcs615-odessa-u-boot.dtsi`, `qcom_qcs615_odessa_defconfig`,
`odessa.env`, `build-odessa.sh`.

**Test-Hinweis:** Das FIT-FDT ist
`sm6150-moto-odessa-dtbo0-explicit.dtb` (11.191 B) mit `ramoops` und
`simple-framebuffer`, aber **ohne USB/UFS/GCC**. Der 6.12-Kernel
erreicht damit `/init` und pstore, aber **ohne UDC/SSH**. USB/SSH sind
der naechste Mainline-DTB-Port (USB/UFS/Display); U-Boot selbst hat
USB-ACM als Fallback-Konsole in seinem eigenen DTB.

## Revision 2026-11-06 21:45 UTC — Fix1 (Timer + simplefb)

| Artefakt | Groesse | SHA256 |
|---|---|---|
| `odessa-6.12-fix1.dtb` | 598.071 B | `d96694dc59dd44945d25c0e42d7c659c3a635d775af13a66da31ae76582d81c8` |
| `fit-6.12-fix1.itb` | 19.052.413 B | `7fe12ecf6ea518ff7b63a6f26abf589ae3269bb8cbbafb5047792bbbeb2b4d2c` |
| `test-boot-uboot-odessa-fix1.img` | 20.963.328 B | `07694cedb4dd75342af4f120e39b79a060b8e421c906ff9128fb1a78321d5e7b` |

Basis: `odessa-abl-merged.dtb` (598.039 B,
`a9df99e80d1ad7e3fc1a8a1b8e5bd91e0b5ba090e39a45a2134f65db6e0c22f9`),
unveraendert; Fix1 ist eine per `fdtput` erzeugte Kopie.

Diff (3 Aenderungen):
1. `/soc/timer` -> `interrupt-parent = <0x1a>` (GIC statt PDC).
2. `/framebuffer@9c000000` -> `width=1080`, `height=2400`, `stride=4320`.
3. `/reserved-memory/cont_splash_region@9c000000` -> `no-map`.

Teststatus: gebaut, **nicht geflasht**, RAM-only via `fastboot boot`.

## Fix13 — SM6150 GCC port (2026-11-07)

| Artefakt | Groesse | SHA256 |
|---|---|---|
| `out/Image-6.12-gcc.gz` | 14.585.686 | `419dfc0fb4c92dc0814eb33bd2ebc7317cee50b37604d07968c5675884bbc0c0` |
| `out/initramfs.cpio.gz` | - | `60a91e0bdab009466937dad1fb6a25627c9dffadc7327539b0b74820614abe28` |
| `.re/uboot/odessa-6.12-fix13.dtb` | 589.256 | `708c33a054ebb3448f7590a8733ee66328e90cd8bd53ef11fac9bab56507f2f6` |
| `.re/uboot/fit-6.12-fix13.itb` | 18.943.0xx | `c05a46a342e7079d82acd2cb1c3a3fdae26e85e615781f5986d3540d3bb930d8` |
| `.re/uboot/test-boot-uboot-odessa-fix13.img` | 20.852.736 | `c377379647f5d97da8c925ebdd5ad6b7dc64c3688569da2aff51173f565fd9a7` |

Quellen: `scripts/port-gcc-sdmmagpie.py`,
`drivers/clk/qcom/gcc-sdmmagpie.c`,
`include/dt-bindings/clock/qcom,gcc-sdmmagpie.h`,
`abl-merged-gcc.dts`.

## Fix20 — funktionierender USB/SSH-Stand (2026-11-07)

| Artefakt | SHA256 |
|---|---|
| `out/Image-6.12-gcc.gz` | `419dfc0fb4c92dc0814eb33bd2ebc7317cee50b37604d07968c5675884bbc0c0` |
| `out/initramfs.cpio.gz` | `31235f5366458a6224f883d2c1037ad3c7ffa47bf957c2d688d40f0678d42105` |
| `.re/uboot/odessa-6.12-fix20.dtb` | `a47a64c74348bbc0a6f6e777e6877eee5eaf807f631d457640babc9b76f0cc8b` |
| `.re/uboot/fit-6.12-fix20.itb` | `507bd06d73283caa8b1db6c43bc29d1493dce9a734bb64a98de4d66a4561c4a2` |
| `.re/uboot/test-boot-uboot-odessa-fix20.img` | `eab1be4942c79763caa2a63b6bab2e18e47e8ba4b41d7d4afb20a6ab4242b993` |

## 2026-11-07 — W1/W2/W3 (Keeper Fix35)

| Artefakt | SHA256 | Status |
|---|---|---|
| `test-boot-uboot-odessa-fix35.img` | `145bb97c96c0f40042dd367ac0ed05645cf33bf29dde1a901085f0c2e4fcf925` | **KEEPER** (PDC + 31 RPMh-Regler + 0 IRQ-Warnungen, UFS fixed rails) |
| `odessa-6.12-fix35.dtb` | `a1d18b512220514c9508dedde0a4962fcba7f163546d3032ef52cd39406a493c` | DTB des Keepers |
| `fit-6.12-fix35.itb` | s. `fit-6.12-fix35.itb` | FIT |
| `test-boot-uboot-odessa-fix36.img` | `42b31a877ffa8fb2e788d1d81661cbc17e9cb5bbdfe51006ad1234e93dbc3d8e` | UFS-RPMh-Rails, haengt |
| `test-boot-uboot-odessa-fix37.img` | `7356eda774323e430570c0f21836610dcfc128651eb1e367179a3ce5043e04f2` | nur PHY-Rails, haengt |
| `test-boot-uboot-odessa-fix38.img` | `31d0bc066396db80b4d26beab81e7a96b3b74e288c98f71a20d739eeb885234e` | nur HC-Rails, haengt |
| `test-boot-uboot-odessa-fix39.img` | `3c7e012a5ddb916c97dc3356c85f91527bc88dae139d6b60083f5fb6702c333a` | ohne min/max, haengt |

## Vollstaendiger Artefakt-Index (generiert 2026-11-07)

Alle Boot-Images unter `.re/uboot/`. Status aus dem Run-Protokoll; Fix7/8/15/18/19 sind Zwischenstaende ohne eigenen STATUS-Eintrag (ehrlich als solche markiert).

| Datei | SHA256 | Bytes | Zweck / Status |
|---|---|---|---|
| `test-boot-uboot-odessa-fix1.img` | `07694cedb4dd75342af4f120e39b79a060b8e421c906ff9128fb1a78321d5e7b` | 20963328 | DTB-Fix1: Timer/GIC + simplefb-Geometrie (RAM-only) |
| `test-boot-uboot-odessa-fix2.img` | `b88a42065e15befd4b54594c90119ee2e5f55dec2319475a700a4b98142c33a2` | 20963328 | Fix2: panic=0 |
| `test-boot-uboot-odessa-fix3.img` | `e9f77ab97960c2051a94f0b62151ac2b3c4733991d7e36a4ded3dd7f911d5c2b` | 20963328 | Fix3: korrigierte Framebuffer-Geometrie (Hex->Dezimal), bestaetigt |
| `test-boot-uboot-odessa-fix4.img` | `140f7aac6b97e01d2ccd0a1556a1453c89006981d65377e56dcc4527bbe89dae` | 20963328 | Fix4: RPMh/cmd-db aus /proc/iomem |
| `test-boot-uboot-odessa-fix5.img` | `818ace8194da617350f4ab39abffbad94303573f169ab1a3a6efdc6915701e65` | 20963328 | Fix5: Initramfs-Diagnose (Regler/cmd-db) |
| `test-boot-uboot-odessa-fix6.img` | `9738a2f95a5489ccafc5b64d902c3de7d183ba9ea5c7f224cfc789f3cd595693` | 21123072 | Fix6: 16x32-Font (TER16x32) |
| `test-boot-uboot-odessa-fix7.img` | `854efe12e849a50dbdd4b07c3c7ce726ed31ca245bde273bf0a9993b66890c92` | 21123072 | Zwischenstand (kein separater STATUS-Eintrag) |
| `test-boot-uboot-odessa-fix8.img` | `588a901784513558caf296736b247459b28d02d7b768cb4dddd40e2538d289e8` | 21123072 | Zwischenstand (kein separater STATUS-Eintrag) |
| `test-boot-uboot-odessa-fix9.img` | `73921a6c8f049e980fd4f00355c147ec62910992e189ef81de8792439da3cf14` | 21118976 | Fix9: mainline PMIC-Reglergruppen (RPMh-Registrierung scheitert) |
| `test-boot-uboot-odessa-fix10.img` | `e814ebcc33bc7df2b0049a98636896a63d9bc18390ab3d3ffc22fab39a648f03` | 21114880 | Fix10: USB-Handoff, haengt bei 0.504 s (Dead End) |
| `test-boot-uboot-odessa-fix11.img` | `9a1925802cc36115ca82236a10900ebaacf7c6e52d7b25fe1b5f00f31b99bf34` | 21114880 | Fix11: U-Boot-USB-Handoff (Dead End) |
| `test-boot-uboot-odessa-fix12.img` | `2ed9ad3311964ba07ed21c7078d581e974e0a4a2369158aca7a1ef32dfd94570` | 21114880 | Fix12: U-Boot-USB-Handoff Variante (Dead End) |
| `test-boot-uboot-odessa-fix13.img` | `d1f001fffc41f3fdc35c549e56af2195e948ee6fbd1bc2c047cdb3f3a0d4cfb6` | 20852736 | Fix13: GCC-Bindungstest (fw_devlink-Blockade) |
| `test-boot-uboot-odessa-fix14.img` | `27e101fddb9a3df9b8f838ba5e52d53fc907ca6dd07616e94c99ab2de1ce1767` | 20852736 | Fix14: Cmdline-/ramoops-Korrektur |
| `test-boot-uboot-odessa-fix15.img` | `ee6e282ae9fd73117d014f47c3b457b729828a61d6f39745f2d43064b2678bcb` | 20852736 | Zwischenstand (kein separater STATUS-Eintrag) |
| `test-boot-uboot-odessa-fix16.img` | `ee67ae47fbf7e96510e0b86958c7ec49d4ef9447214fc86228dfd002188e5055` | 20852736 | Fix16: GCC-Blockade via fw_devlink aufgeloest |
| `test-boot-uboot-odessa-fix17.img` | `041c4fcd7fee1d570402b765045dc921c8c2e30c3702466cef53eea9ad82f64e` | 20852736 | Fix17: USB mit echten GCC-Clocks/Resets |
| `test-boot-uboot-odessa-fix18.img` | `b744a77478a4d77ee59c018f98c9750249c5505d85f3a717e92f856e6e45bd4c` | 20852736 | Zwischenstand (kein separater STATUS-Eintrag) |
| `test-boot-uboot-odessa-fix19.img` | `93d204ba480fcbce2f1526dbf079c73b2fb7e61e78a73d3b66d890e5404bc982` | 20852736 | Zwischenstand (kein separater STATUS-Eintrag) |
| `test-boot-uboot-odessa-fix20.img` | `eab1be4942c79763caa2a63b6bab2e18e47e8ba4b41d7d4afb20a6ab4242b993` | 20852736 | Fix20: DWC3-Deferral (PDC) aufgeloest |
| `test-boot-uboot-odessa-fix21.img` | `1c5b28f3aa01de81d3d65b983d01c72f7fcc20d50e32ca7d5b32fa3986b915bd` | 20852736 | Fix21: DWC3-IRQ LEVEL_HIGH |
| `test-boot-uboot-odessa-fix22.img` | `c090fc5ee5a79d78716797933d37b40780ae5259181b9df87586208042ab3d88` | 20852736 | Fix22: Root-IRQ -> GIC, SPMI probt |
| `test-boot-uboot-odessa-fix23.img` | `1ab191ecf682dba655118ef1e9658554b2579b484ce9aa770fe78a1b75af84f4` | 20852736 | Fix23: XO-Rename xo_board, clk-rpmh bi_tcxo |
| `test-boot-uboot-odessa-fix24.img` | `e9336509254ff5023b5f2894f534edc2c07848c324e5cd964c8ad37d3f7b162a` | 20852736 | Fix24: UFS HC/PHY mainline-konform |
| `test-boot-uboot-odessa-fix25.img` | `3dd4b65da0d921ae9c20529ee20f6a263acb4352b05579258fd249fec4bf127b` | 20852736 | Fix25: UFS ref_clk auf xo_board |
| `test-boot-uboot-odessa-fix26.img` | `7429bdd0a31944fcb0716ab71bb3fe9cdd3ff4073a4ccc1b6614119f03ad3473` | 20860928 | Fix26: QMP-UFS-PHY builtin, UFS-LUNs |
| `test-boot-uboot-odessa-fix27.img` | `1a9bc2a5e09cc40ab8aad1ac5b7b301b163cb7d650e3c6c64bfabca8507958e0` | 20860928 | Fix27: odessa.boot=ubuntu (switch_root) |
| `test-boot-uboot-odessa-fix28.img` | `5cd60228b9f6c0d02817bb7bbbef5f8718963ff4fc0cbe87fa8085a4cf7b7b0c` | 20860928 | Fix28: CMDLINE_FROM_BOOTLOADER, Ubuntu 22.04.5 (Keeper #1) |
| `test-boot-uboot-odessa-fix29.img` | `cda5dea7ae8d758d275745d8137af03c3297c83f176f738e3c40f6450e886e6c` | 20860928 | Fix29: PDC mainline (qcom,pdc + ranges) |
| `test-boot-uboot-odessa-fix30.img` | `f763eb1137739eecd98fc6b5208bf281766ff564b624b10eb8b3222356453e60` | 20856832 | Fix30: PM8009-Container entfernt |
| `test-boot-uboot-odessa-fix31.img` | `e9e467e6d55bc526d71cad52dc1c22d51f9570ba89d286d38fc1ba2f8dd86570` | 20856832 | Fix31: ldo17/bob-Werte + SPMI LEVEL_HIGH (haengt) |
| `test-boot-uboot-odessa-fix32.img` | `6f809fe2ab9c199687aa49628c2ebc16646dff5029cef92b7bfe755e66aea760` | 20860928 | Fix32: Fix30 + SPMI (bootet) |
| `test-boot-uboot-odessa-fix33.img` | `2f6a0342738c604c9eabab305c1d04827324ad1e0823eeafe2e68de1c2803361` | 20860928 | Fix33: Fix31 + regulator_ignore_unused (haengt) |
| `test-boot-uboot-odessa-fix34.img` | `b8096568a0279f7a96bb9b46334fb57f461790961481661d31476d565995d5f0` | 20860928 | Fix34: Fix33 + ignore_loglevel/initcall_debug (haengt) |
| `test-boot-uboot-odessa-fix35.img` | `145bb97c96c0f40042dd367ac0ed05645cf33bf29dde1a901085f0c2e4fcf925` | 20856832 | Fix35: 31 RPMh-Regler registriert (KEEPER #2, UFS auf Fixed-Rails) |
| `test-boot-uboot-odessa-fix36.img` | `42b31a877ffa8fb2e788d1d81661cbc17e9cb5bbdfe51006ad1234e93dbc3d8e` | 20856832 | Fix36: UFS auf RPMh-Rails (haengt) |
| `test-boot-uboot-odessa-fix37.img` | `7356eda774323e430570c0f21836610dcfc128651eb1e367179a3ce5043e04f2` | 20856832 | Fix37: nur PHY-Rails (haengt) |
| `test-boot-uboot-odessa-fix38.img` | `31d0bc066396db80b4d26beab81e7a96b3b74e288c98f71a20d739eeb885234e` | 20860928 | Fix38: nur HC-Rails (haengt) |
| `test-boot-uboot-odessa-fix39.img` | `3c7e012a5ddb916c97dc3356c85f91527bc88dae139d6b60083f5fb6702c333a` | 20856832 | Fix39: UFS-Rails ohne min/max (haengt) |
| `test-boot-uboot-odessa-fix40.img` | `8b250adb6f5a7433135033ba915a95a3532d29492d97eebe4e8fa4cfefb48213` | 20856832 | Fix40: Recovery ohne switch_root (Initramfs/SSH) |

### DTBs

| Datei | SHA256 | Bytes |
|---|---|---|
| `odessa-6.12-fix1.dtb` | `d96694dc59dd44945d25c0e42d7c659c3a635d775af13a66da31ae76582d81c8` | 598071 |
| `odessa-6.12-fix2.dtb` | `b29fb87e120f393a01503257dd901577dd7accf02ab0de71c16b2606637e65c7` | 598071 |
| `odessa-6.12-fix3.dtb` | `242b143be6f7e5b32ba7be823b5016d5d9a70ffd4c68f696319925266e368bf4` | 598071 |
| `odessa-6.12-fix4.dtb` | `6b771aba18facf24c319460c56482ee7e2ee8f70e9ac68d3b653515a10045108` | 597808 |
| `odessa-6.12-fix6.dtb` | `d25eda1257776923d1ca1aced1164804e56746eb558d87080ac55fe6d37b5e44` | 597816 |
| `odessa-6.12-fix9.dtb` | `ede697f10a0c68851ab037cee9c78bd5d581e317af3e4a32f05e5da10b0185e7` | 590947 |
| `odessa-6.12-fix10.dtb` | `a92f2e9d2c775afbeacd2bcd157fea88c50f85fbf1b89e3a06c425d0f0a99101` | 589172 |
| `odessa-6.12-fix13.dtb` | `708c33a054ebb3448f7590a8733ee66328e90cd8bd53ef11fac9bab56507f2f6` | 589272 |
| `odessa-6.12-fix14.dtb` | `afbf660ac2f451cca39d75105505fd7fe34eaab0b389162f7cf579845b9cb119` | 589272 |
| `odessa-6.12-fix15.dtb` | `708c33a054ebb3448f7590a8733ee66328e90cd8bd53ef11fac9bab56507f2f6` | 589272 |
| `odessa-6.12-fix16.dtb` | `2bdf152443339f6f157c7774038457dc8b8a2a7c977f5f8349c24aa99a99d409` | 589207 |
| `odessa-6.12-fix17.dtb` | `a1b781baaebb1765d9c05cc1e1792ef142fb756afa96d7b4aa0e0fe4e7b9302f` | 589351 |
| `odessa-6.12-fix20.dtb` | `a47a64c74348bbc0a6f6e777e6877eee5eaf807f631d457640babc9b76f0cc8b` | 589239 |
| `odessa-6.12-fix21.dtb` | `266410583b42937a11e14e2206a1a6556b8e155cdf87eda0cd87ecad948547a8` | 589239 |
| `odessa-6.12-fix22.dtb` | `67a7185d1db14178ee40b9a0212c207b0f4cbf89a72712788891996ddf7b1b74` | 589159 |
| `odessa-6.12-fix23.dtb` | `da0c46b9df7f7723fc481741400e1bc0ceabcde95025ba9dc6fd0d5ef5c8e551` | 589163 |
| `odessa-6.12-fix24.dtb` | `2975329be9236068cf5f50e743459a89d1294380f2f64db7dbc554c2409968d5` | 588170 |
| `odessa-6.12-fix25.dtb` | `392754a4920b10df239abd2c6391537d62081d7f4fc9da227cbe92d83788e430` | 588166 |
| `odessa-6.12-fix27.dtb` | `c9d4ca4c586b22e903843cf2f1c05470df005a97f2011eb383b0e7cac9f6622d` | 588182 |
| `odessa-6.12-fix29.dtb` | `a5178e1b0b444fc63495dc82fd48520c7d8365e189a87f3e24ef018f57309524` | 588254 |
| `odessa-6.12-fix30.dtb` | `1d107b49197d1f30d3282747238fec1ed394589772db5d4aa1a151fe279c1136` | 587194 |
| `odessa-6.12-fix31.dtb` | `d585b9aa268d2c8c1e90f0993eedcf6307a936a7415a7503c5b7af46ffa16ff9` | 587194 |
| `odessa-6.12-fix32.dtb` | `e4a9ad19a756bc6a86e5db907bb235339259069c9a4bcbb98fe6df1a65d58bf5` | 587194 |
| `odessa-6.12-fix35.dtb` | `a1d18b512220514c9508dedde0a4962fcba7f163546d3032ef52cd39406a493c` | 587152 |
| `odessa-6.12-fix36.dtb` | `f78a5621063d59897d4fcadb2ea2777197b6ca0bf83fc79726059d0557b5ee41` | 586912 |
| `odessa-6.12-fix37.dtb` | `139539bd4234ecb5f20a98a661e107cf7cba30fab4f977bc15b9a6f6eeb79ffe` | 586856 |
| `odessa-6.12-fix38.dtb` | `25bfa336aa924c3e794513271e5d473afb0476874ad7fcd7f30e5f3fe31a963c` | 587208 |
| `odessa-6.12-fix39.dtb` | `e8d949dbb7a41a6cf1765e76637a72a372ba66ad2f9af08e030b743fcf832350` | 586784 |

## Release 2026-11-07 (flashbar)

| Artefakt | SHA256 |
|---|---|
| `out/odessa-6.12-boot.img` | `444e07c90b1de8b68c84f85f4bd006427e50901fb7162954830a3997263e39db` |
| `out/odessa-6.12-rootfs.img` | `2418b497c9d03932bb18d3dd3086a39c57566e357023cfe3b4e813a66d3b6ab1` |
| `out/flash-odessa.sh` | (Skript) |

## Release final 2026-11-07 (validiert)

| Artefakt | SHA256 |
|---|---|
| `out/odessa-6.12-boot.img` (61,4 MB, self-install) | `5c3d26e4e35c6506a777ba0fc35a6534a1934f1e48dc2073748c594416c93a86` |
| `out/odessa-6.12-rootfs.img` (2,0 GB) | `197d43a1f73f32bd572cd9fcc627993af2f1b6440b3b902cbfc3cbcdfed909b3` |
| `out/odessa-6.12-rootfs.simg` (140 MB) | `e6926f9d979474ae02085793d83df361f5dbd8f31af0f9e0a4aad753501eb8b5` |
| `out/rootfs.tar` (Installer) | `483eff3c629260018d6d1e646e20dcfc175f7a8a0a222e565d444ca0f220ff4b` |
| `out/flash-odessa.sh` | `75f87bc79b9d30e50433fd20e386e5508c5b291d9d1fd50576897cd2ea931fbf` |

## 26.04 Release-Kandidat 2026-11-07 (Validierung offen)

| Artefakt | Groesse | SHA256 |
|---|---|---|
| `out/odessa-6.12-boot-2604.img` | 61,68 MiB (64.675.840 B) | `293533942759a466b0193645bb74e989be78e59988508b9dd2fce54744731f15` |
| `out/odessa-6.12-rootfs-2604.img` | 2,0 GB | `ac5cf5ec532863600f585489e9862151c28daeeb73d0be3b77c16193beb1adc2` |
| `out/odessa-6.12-rootfs-2604.simg` | 125 MiB | `08682cb205f8c2de8c1d55c7a6cfdbdee0b97e88041bbc0069699033972e7a7e` |
| `out/rootfs-2604.tar` (Installer) | 141 MiB | `d0b8af09a8d1b4bf942531c27634297b653c10fc4823421c63ea3b28bf927d70` |
| `out/rootfs-install.tar.gz` (Payload im Boot-Image) | 42,19 MiB | `0d000d5df6a58bed5c3d94079f111b9545f6d24b49f16b96bf09b52e9fcaee07` |
| `out/initramfs.cpio.gz` | 47,58 MB | `0f3a684faf54ad3c3cf1302d3ff758b47b7b4a08e2fd4f5774d743572a16e97f` |
| `out/flash-odessa-2604.sh` | Skript | (flash boot_b + set_active b + reboot) |

Inhalt: Ubuntu 26.04.1, systemd 259.9, iproute2, dropbear, usb-gadget,
growfs; `/etc/machine-id` leer, keine Hostkeys (werden beim ersten Boot
erzeugt), `etc/modules-load.d/modules.conf` entfernt.

## RELEASE FINAL 2026-11-07 (26.04, validiert)

| Artefakt | Groesse | SHA256 |
|---|---|---|
| `out/odessa-6.12-boot.img` | 61,68 MiB | `293533942759a466b0193645bb74e989be78e59988508b9dd2fce54744731f15` |
| `out/odessa-6.12-rootfs.img` | 2,0 GB | `ac5cf5ec532863600f585489e9862151c28daeeb73d0be3b77c16193beb1adc2` |
| `out/odessa-6.12-rootfs.simg` | 125 MiB | `08682cb205f8c2de8c1d55c7a6cfdbdee0b97e88041bbc0069699033972e7a7e` |
| `out/rootfs.tar` | 141 MiB | `d0b8af09a8d1b4bf942531c27634297b653c10fc4823421c63ea3b28bf927d70` |
| `out/rootfs-install.tar.gz` | 42,19 MiB | `0d000d5df6a58bed5c3d94079f111b9545f6d24b49f16b96bf09b52e9fcaee07` |
| `out/flash-odessa.sh` | — | `d47478839bd1ec80ca2ba68cd1007407df00b671733a222a0e03eb4d8c6a9835` |

22.04-Fallback: `out/legacy-2204/` (boot `5c3d26e4…`, rootfs `197d43a1…`,
simg `e6926f9d…`, flash `75f87bc7…`).
