# T10-E2FSPROGS — statische aarch64 e2fsprogs (mke2fs/tune2fs/dumpe2fs)

- PROJECT: odessa-usbgadget
- RUN_ID: 20261106-odessa-usbgadget
- TASK_ID: T10-E2FSPROGS
- TARGET_ID: odessa initramfs (aarch64)
- PHASE: Build
- ROLE: software-manager
- STATUS: **INSTALLED**

## 1. Quelle und Integritaet

| Feld | Wert |
|---|---|
| Tool | e2fsprogs 1.47.4 (latest stable in 1.47.x at build time) |
| URL | https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v1.47.4/e2fsprogs-1.47.4.tar.xz |
| Tarball sha256 | `fd5bf388cbdbe006a3d3b318d983b2948382440acc85a87f1e7d108653e8db0b` |
| Upstream-Manifest | `sha256sums.asc` (GPG-signiert, tytso), Zeile 5 enthaelt exakt diesen sha256 |
| Sidecar | `e2fsprogs-1.47.4.tar.sign` (detached, RSA key 2B69B954DBFE0879288137C9F2F95956950D81A3) heruntergeladen |
| GPG-Pruefung | **NOT_VERIFIED** — kein passender Public Key lokal vorhanden (`Can't check signature: No public key`); Keyserver-Abruf ist keine freigegebene Quelle dieses Auftrags. Integritaet daher ueber den sha256-Abgleich gegen das offizielle, signierte `sha256sums.asc` belegt. |
| Download-Ablage | `/home/zero/.local/share/opencode/re-tools/_downloads/SW-E2FSPROGS/` |

Kein `curl | sh`, kein sudo, keine Systeminstallation.

## 2. Toolchain (T7)

```
$ . /workspace/work/odessa/cross-env.sh
$ aarch64-linux-gnu-gcc --version
aarch64-linux-gnu-gcc (Debian 12.2.0-14) 12.2.0
```

GCC-Pfad: `/home/zero/.local/share/opencode/re-tools/cross-aarch64/usr/bin/aarch64-linux-gnu-gcc`

## 3. Build

Workdir: `/workspace/work/odessa/e2fsprogs-build/e2fsprogs-1.47.4` (frisch aus dem Tarball entpackt; die zwei HTML-Indexdateien des abgebrochenen Vorversuchs wurden ignoriert).

**Abweichung (minimal, dokumentiert):** Der Auftrag verlangt `--disable-libuuid --disable-libblkid`. e2fsprogs 1.47.4 prueft in genau diesen beiden Zweigen zwingend `pkg-config` und bricht sonst mit
`configure: error: pkg-config not installed; please install it.` ab (configure Zeilen 6357/6651). `pkg-config` ist im Container nicht vorhanden. Statt ein weiteres Build-Tool nachzuinstallieren, wurden **nur diese zwei Flags weggelassen**; e2fsprogs baut dann seine eigenen internen `libuuid.a` / `libblkid.a` (durch `--disable-elf-shlibs` statisch) und linkt sie ein. Kein Source-Patch, keine Logikaenderung.

Tatsaechlich verwendete configure-Zeile:

```
./configure --host=aarch64-linux-gnu \
  --disable-nls --disable-elf-shlibs \
  --disable-uuidd --disable-fsck --disable-e2initrd-helper --disable-debugfs \
  --disable-imager --disable-resizer --disable-defrag \
  CC=aarch64-linux-gnu-gcc LDFLAGS=-static
```

- configure exit: **0** (Log: `/tmp/e2-configure2.log`)
- Ergebnis: `STATIC_LIBUUID='$(LIB)/libuuid.a'`, `STATIC_LIBBLKID='$(LIB)/libblkid.a'`
- Build:
  - `nice -n 10 make -j8 libs` → exit 0
  - `nice -n 10 make -C misc -j8 mke2fs tune2fs dumpe2fs` → exit 0
- Fehlversuche: 1 (Top-Level `make mke2fs` existiert nicht; Ziel liegt in `misc/`), danach korrigiert. Keine Error-Klasse 3x verletzt.
- Linker-Warnungen (nicht fatal): `Using 'getpwuid'/'getgrgid'/'getpwnam'/'getgrnam' in statically linked applications requires at runtime the shared libraries from the glibc version used for linking` — bekannte glibc-NSS-Einschraenkung statischer Builds, fuer ext4-Formatierung nicht relevant (keine Benutzer-/Gruppenaufloesung noetig).

## 4. Installierte Binaries

Ziel: `/home/zero/.local/share/opencode/re-tools/bin/aarch64/` (gestrippt, Modus 755)

| Binary | Bytes | sha256 | `file` |
|---|---:|---|---|
| `mke2fs` | 1.198.160 | `445744f036b04ac79ce355690c373125bffc36677391af7da3f6028842b56fb5` | ELF 64-bit LSB executable, ARM aarch64, statically linked, stripped |
| `tune2fs` | 1.262.952 | `8f3c345435e0d973402f443039123830b333a246c9c2a3e14dcf13c37a7e43c0` | ELF 64-bit LSB executable, ARM aarch64, statically linked, stripped |
| `dumpe2fs` | 1.131.208 | `199e131a6bdf79d00ed3cfff51df1c6a8535d15cca6b8f5ba6ba4f8e3523472f` | ELF 64-bit LSB executable, ARM aarch64, statically linked, stripped |

`readelf -d` fuer alle drei: **`There is no dynamic section in this file.`**
`readelf -h`: `Class ELF64`, `Type EXEC`, `Machine AArch64`.

Manifest: `/workspace/work/odessa/e2fsprogs-build/SHA256SUMS.bin`

## 5. Checks (ueber qemu-aarch64-static, nur Versions-/Hilfeabfrage)

```
$ qemu-aarch64-static .../bin/aarch64/mke2fs -V
mke2fs 1.47.4 (6-Mar-2025)
        Using EXT2FS Library version 1.47.4

$ qemu-aarch64-static .../bin/aarch64/dumpe2fs -V
dumpe2fs 1.47.4 (6-Mar-2025)
        Using EXT2FS Library version 1.47.4

$ qemu-aarch64-static .../bin/aarch64/tune2fs -V
tune2fs: invalid option -- 'V'   (tune2fs 1.47.4 hat kein -V)
```

tune2fs-Version belegt ueber `strings`: `1.47.4`, `EXT2FS Library version 1.47.4`.

## 6. Default-ext4-Features (filetype / metadata_csum)

**Ja, beide sind im Default-Satz enthalten.**

Da im Initramfs kein `/etc/mke2fs.conf` existiert, nutzt mke2fs das einkompilierte Profil. Beleg:

- `misc/mke2fs.c:1775-1782`: liefert `profile_init(config_fn)` `ENOENT`, wird `profile_set_default(profile, mke2fs_default_profile)` aufgerufen — d. h. bei fehlender Config-Datei greift das eingebaute Profil.
- `misc/default_profile.c:3` und `:15` (generiert aus dem mitgelieferten `mke2fs.conf`):

```
[defaults]
    base_features = sparse_super,large_file,filetype,resize_inode,dir_index,ext_attr
    blocksize = 4096
    inode_size = 256
    ...
[fs_types]
    ext4 = {
        features = has_journal,extent,huge_file,flex_bg,metadata_csum,metadata_csum_seed,64bit,dir_nlink,extra_isize,orphan_file
    }
```

- `filetype` → in `base_features`
- `metadata_csum` (+ `metadata_csum_seed`) → im `ext4`-Feature-Satz, aktiv bei `mke2fs -t ext4`

Damit sind die fuer Docker/overlay2 benoetigten Features `filetype` und `metadata_csum` im Default enthalten. Determinationsmethode: Quell-/Generatcode des einkompilierten Profils; **nicht** durch Ausfuehren von `mke2fs` auf einem Blockgeraet.

## 7. Aufrufsyntax fuer das Initramfs

```
# userdata als ext4 formatieren (Beispiel, noch NICHT ausgefuehrt)
mke2fs -t ext4 -F -L userdata /dev/block/by-name/userdata

# Features pruefen / nachziehen
tune2fs -l /dev/block/by-name/userdata
dumpe2fs -h /dev/block/by-name/userdata
```

Hinweis: `mke2fs`/`tune2fs` benoetigen kein `/etc/mke2fs.conf`; das Default-Profil ist einkompiliert. Ein `mke2fs.conf` im Initramfs wuerde das Profil ueberschreiben.

## 8. LIMITATIONS / BLOCKERS

- Kein Blocker.
- GPG-Signatur der `sha256sums.asc` nicht verifiziert (kein Key lokal, Keyserver nicht autorisiert); sha256-Abgleich gegen das offizielle Manifest ist erfolgt.
- Kein Laufzeit-Smoke-Test von `mke2fs` gegen ein echtes/erzeugtes Image (kein Geraetezugriff, kein Zielskript); nur `-V` / Usage unter qemu.
- Statische glibc-NSS-Linkerwarnungen (getpwuid/getgrgid) — funktional irrelevant fuer die Formatierung.
- `tune2fs` hat kein `-V`; Version ueber `strings` belegt.

## 9. Persistenz

`findmnt -T /home/zero/.local/share/opencode/re-tools` →
`/dev/nvme1n1p1[/home/zero/.local/share/opencode] ext4 rw,relatime` — Host-Mount, uebersteht den Container.
