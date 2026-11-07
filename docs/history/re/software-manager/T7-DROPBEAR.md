# T7-DROPBEAR — statisches aarch64-Dropbear + Cross-Toolchain

TASK_ID: T7-DROPBEAR
STATUS: INSTALLED
PROJECT: odessa-usbgadget
RUN_ID: 20261106-odessa-usbgadget
TARGET_ID: odessa initramfs (aarch64, kernel 4.14.190)
ROLE: software-manager
DATE: 2026-11-06 (UTC)

## Kurzfassung (Pflichtfelder)

- CROSS: Debian bookworm cross-gcc 12.2.0 (aarch64-linux-gnu) + glibc 2.36
  arm64-sysroot + binutils 2.40, entpackt nach
  `/home/zero/.local/share/opencode/re-tools/cross-aarch64/` (`./usr`-Layout,
  kein dpkg-Install, kein sudo). Alle .deb-SHA256 gegen
  `dists/bookworm/main/binary-amd64/Packages.xz` geprueft; dessen SHA256
  (`9e0b5aab…b588c5`) stimmt mit `dists/bookworm/Release` ueberein.
- DROPBEAR: **2026.94** (latest stable im offiziellen Release-Index), Tarball
  `dropbear-2026.94.tar.bz2` sha256
  `e098034a843699200c8c977a991fff73159735bf795d5f72ef672c41a6b1ae81`,
  GPG **GOODSIG** Key `F7347EF2EE2E07A267628CA944931494F29C6773`
  ("Dropbear SSH Release Signing <matt@ucc.asn.au>"), zusaetzlich
  `SHA256SUM.asc` GOODSIG mit demselben Schluessel.
- Binaerpfade: `/home/zero/.local/share/opencode/re-tools/bin/aarch64/dropbear`
  und `.../dropbearkey` (beide 755, gestrippt).
- CHECK: `file` = "ELF 64-bit LSB executable, ARM aarch64, … statically
  linked, stripped"; `readelf -d` = "There is no dynamic section"; kein
  INTERP; `ldd` = "not a dynamic executable". Ausfuehrung: NOT_RUN (kein
  qemu-aarch64, laut Auftrag nicht versucht).

## 1. Cross-Toolchain (Schritt 1)

Installationswurzel (persistent, Host-Share):
`/home/zero/.local/share/opencode/re-tools/cross-aarch64/`

| Paket | Version | Arch | .deb sha256 |
|---|---|---|---|
| gcc-aarch64-linux-gnu | 4:12.2.0-3 | amd64 | 4456013f03831e2cd58e3114d797b1a9a4b2b5f95130a15d3dc8a14499861163 |
| gcc-12-aarch64-linux-gnu | 12.2.0-14cross1 | amd64 | 43747bbcd46a4062e66e855090b8ed9c2e06a93ae5a69fb304beebbc8c36d11f |
| gcc-12-aarch64-linux-gnu-base | 12.2.0-14cross1 | amd64 | 6ede94430fde75ca023be50b3f5a94aa4a063b2d5c3a359bee169a934930f130 |
| cpp-12-aarch64-linux-gnu | 12.2.0-14cross1 | amd64 | 5921df4ad56e34e6257a1caf862474845aab6548ba7ae7852e8cdd7cb622394e |
| libgcc-12-dev-arm64-cross | 12.2.0-14cross1 | all | ff1324e262bae2c3aad685c2ed52bd531ab0a2a337a0fe35c3b720947d55b2ba |
| libc6-dev-arm64-cross (glibc 2.36-8cross1) | 2.36-8cross1 | all | 5e4cf6abf0e89e89c4b3006bb8b7dc47aa831df25d94df9134929b8b968cacb4 |
| libc6-arm64-cross | 2.36-8cross1 | all | 91936cbbee75771c360ed16513f6e734a25ca5517fe7c3e13dfd7835d7553186 |
| linux-libc-dev-arm64-cross | 6.1.4-1cross1 | all | 66457f015d16b7d372db6591cff38db0da928362ff2ea1fa75491e28f6904d81 |
| binutils-aarch64-linux-gnu | 2.40-2 | amd64 | 3d6f64a7a4ed6d73719f8fa2e85fd896f58ff7f211a6683942ba93de690aaa66 |
| libbinutils (Host-Runtime fuer Cross-as: libsframe.so.0) | 2.40-2 | amd64 | fcf55b99e5f8a78f3c8ce9b6957f1024f394cf20c196b100d308a57e43547710 |

Begruendung der zwei Zusatzpakete ausserhalb der Auftragsliste:
- `binutils-aarch64-linux-gnu`: der gcc-Treiber braucht `aarch64-linux-gnu-as`
  und `ld`; eigenes, verifiziertes Exemplar statt Abhaengigkeit vom
  Scratch-Baum eines anderen Auftrags (`build/t2-root`).
- `libbinutils`: liefert `libsframe.so.0`, das der bookworm-`as` 2.40
  dynamisch laedt; der Host (Ubuntu 24.04) hat nur `libsframe.so.1`.

Quellen/Integritaet:
- `https://deb.debian.org/debian/dists/bookworm/Release` →
  `main/binary-amd64/Packages.xz` sha256
  `9e0b5aabb2465b3d2e7a7fe27f9913846277833f7a2826e7767acccff5b588c5`
  (in Release gelistet, lokal nachgerechnet).
- Jede .deb-SHA256 einzeln aus dieser Packages-Datei entnommen und nach dem
  Download mit `sha256sum` verglichen (alle OK, siehe
  `/workspace/work/odessa/dropbear-build/SHA256SUMS`).
- Entpacken ausschliesslich mit `dpkg -x` (kein `dpkg -i`, kein sudo).

Aufrufumgebung: `/workspace/work/odessa/cross-env.sh`
```sh
. /workspace/work/odessa/cross-env.sh      # PATH + LD_LIBRARY_PATH + CC/AR/RANLIB/STRIP
```
Der gcc-Treiber relokalisiert sich selbst (kein `--sysroot`/`-B` noetig);
`LD_LIBRARY_PATH=$CROSS_ROOT/usr/lib/x86_64-linux-gnu` wird nur fuer die
x86_64-Hilfsbibliotheken der Cross-binutils gesetzt.

Pruefung Schritt 1 (statisches Hello-World):
```
$ aarch64-linux-gnu-gcc -O2 -static hello.c -o hello
$ file hello
hello: ELF 64-bit LSB executable, ARM aarch64, version 1 (GNU/Linux),
       statically linked, BuildID[sha1]=a2c9885e…, for GNU/Linux 3.7.0, not stripped
$ readelf -d hello
There is no dynamic section in this file.
```
→ Kriterium erfuellt. Zusaetzlich in komplett leerer Umgebung
(`env -i /bin/sh -c '. /workspace/work/odessa/cross-env.sh; …'`) reproduziert:
identisches `hello.cleanenv` (BuildID `a2c9885e…`), `CC=aarch64-linux-gnu-gcc`.

## 2. Dropbear-Build (Schritt 2)

- Version: **2026.94** (23 July 2026), hoechste Version im offiziellen
  Verzeichnis `https://matt.ucc.asn.au/dropbear/releases/`. Im CHANGES-Kopf
  keine Test-/pre-Markierung; Vorgaenger 2026.93/2026.92/… sind regulaere
  Releases, `2026.94` ist der Nachfolger mit Fixes.
- Quellen:
  - `https://matt.ucc.asn.au/dropbear/releases/dropbear-2026.94.tar.bz2`
    (2386978 B) sha256 `e098034a843699200c8c977a991fff73159735bf795d5f72ef672c41a6b1ae81`
  - `…tar.bz2.asc` sha256 `e5971e62ee25f3cce66a09bf5ab2411e76c258b960be832159473f3395116695`
  - `https://matt.ucc.asn.au/dropbear/releases/SHA256SUM.asc`
    sha256 `a2937d72356a574687539f9ad40e82bcc5430f67eaba935ffcb78a317bc4426c`,
    enthaelt o. g. Tarball-Hash (Abgleich OK).
- Signaturpruefung: `gpg --verify dropbear-2026.94.tar.bz2.asc …` →
  `Good signature from "Dropbear SSH Release Signing <matt@ucc.asn.au>"`,
  RSA key `F7347EF2EE2E07A267628CA944931494F29C6773`; ebenso
  `gpg --verify SHA256SUM.asc` → GOODSIG. Der Public Key wurde aus
  `dropbear_2022.83-1+deb12u3.debian.tar.xz` → `debian/upstream/signing-key.asc`
  (deb.debian.org, md5 `1c22e72bfecd5a967072f771f2a7e9ff`, in bookworm Sources
  gelistet) importiert; damit ist die Authentizitaet ueber die erlaubte
  Debian-Quelle verankert. GNUPGHOME nur lokal:
  `/workspace/work/odessa/dropbear-build/gnupg`.

### Build-Kommandos (final, erfolgreich)

```sh
cd /workspace/work/odessa/dropbear-build/dropbear-2026.94
. /workspace/work/odessa/cross-env.sh
./configure --host=aarch64-linux-gnu --disable-harden \
  --disable-zlib --disable-syslog --disable-lastlog \
  --disable-utmp --disable-wtmp --disable-utmpx --disable-wtmpx \
  CC=aarch64-linux-gnu-gcc \
  CFLAGS="-O2 -D_FORTIFY_SOURCE=2 -fstack-protector-strong" \
  LDFLAGS="-static"
nice -n 10 make -j8 PROGRAMS="dropbear dropbearkey"
# rc=0
```

Logs: `/workspace/work/odessa/dropbear-build/configure.log`,
`/workspace/work/odessa/dropbear-build/make.log`.

### Zwei bewusste Abweichungen von der Auftragszeile

1. `--disable-harden` (statt default hardening): Dropbears Default-Hardening
   haengt `-Wl,-pie` **vor** `-static` an die Linkzeile
   (`LDFLAGS=-Wl,-z,now -Wl,-z,relro -Wl,-pie -static`), wodurch der Link
   trotz `-static` ein dynamisches PIE mit
   `interpreter /lib/ld-linux-aarch64.so.1` erzeugte. Mit `--disable-harden`
   bleibt `-static` wirksam; `-D_FORTIFY_SOURCE=2 -fstack-protector-strong`
   wurden manuell als CFLAGS gesetzt, um den Schutz (ausser PIE) zu behalten.
   Ergebnis: `Type: EXEC`, kein INTERP, keine Dynamic-Section.
2. `localoptions.h`: `#define DROPBEAR_SVR_PASSWORD_AUTH 0`.
   Grund: `configure` meldet `WARNING: crypt() is not available`, und
   `src/sysoptions.h:350` bricht mit
   `#error "DROPBEAR_SVR_PASSWORD_AUTH requires `crypt()`."` ab. Ein
   arm64-Cross-`libcrypt-dev` existiert in bookworm main nicht
   (`grep '^Package: libcrypt.*arm64' Packages` → keine Treffer). Der Server
   ist damit **key-only** (`DROPBEAR_SVR_PUBKEY_AUTH` bleibt Default 1) — fuer
   ein Initramfs ohne `/etc/shadow` ohnehin die sinnvolle Betriebsart.
   Kein Crypto-Code gepatcht.

Fehlerklassen/Attempts: (a) fehlendes `crypt()` → 1 Fix (Feature-Define),
(b) `-Wl,-pie` neutralisiert `-static` → 2 Flag-Varianten getestet, dann
`--disable-harden`; innerhalb des 3-Versuche-Limits.

### Ergebnis

| Datei | ungestrippt | installiert (stripped) | sha256 (installiert) |
|---|---|---|---|
| dropbear | 1343728 B | **1126088 B** | f04bba03775942933b6ae3dbec4119ca322a24ca339b18c95b029cbe93d52d93 |
| dropbearkey | 1102976 B | **928184 B** | 788957936e1acdff9ffc4f7c8a55e0dddc3b6ab8d49cb9bac19625be2e384ab3 |

```
$ file .../bin/aarch64/dropbear
ELF 64-bit LSB executable, ARM aarch64, version 1 (GNU/Linux), statically
linked, BuildID[sha1]=efefcbc2c9325e34ec55a63dedc373bc0a4e7774,
for GNU/Linux 3.7.0, stripped
$ file .../bin/aarch64/dropbearkey
ELF 64-bit LSB executable, ARM aarch64, version 1 (GNU/Linux), statically
linked, BuildID[sha1]=36f6f4a58eca91dd90377961429ab7c63e14222e,
for GNU/Linux 3.7.0, stripped
$ readelf -d .../bin/aarch64/dropbear
There is no dynamic section in this file.
$ readelf -h .../bin/aarch64/dropbear
  Class: ELF64   Type: EXEC (Executable file)   Machine: AArch64
$ ldd .../bin/aarch64/dropbear
        not a dynamic executable
```

Aufrufsyntax fuer den Orchestrator (Host-Pfad ist im Container identisch):
```sh
/home/zero/.local/share/opencode/re-tools/bin/aarch64/dropbear \
    -p 22 -r /etc/dropbear/dropbear_ed25519_host_key -F -E
# Key erzeugen:
/home/zero/.local/share/opencode/re-tools/bin/aarch64/dropbearkey \
    -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key
```
Default-Port ist 22 (`DROPBEAR_DEFPORT "22"`); `-p` ist optional.

## 3. LIMITATIONS / offene Punkte

- **Keine Laufzeitpruefung**: `qemu-aarch64-static` ist nicht vorhanden und
  wurde laut Auftrag nicht verwendet. Versionsausgabe (`dropbear -V`) ist
  daher NOT_RUN; die Version 2026.94 ist nur als String im Binary belegt.
- **Static-glibc-NSS-Warnungen** beim Linken: `getpwuid`, `getspnam`,
  `getaddrinfo` "requires at runtime the shared libraries from the glibc
  version used for linking". Fuer den Initramfs-Betrieb relevant:
  - `/etc/passwd` muss auf dem Ziel existieren und einen Eintrag fuer den
    Login-User (z. B. `root`) enthalten, sonst schlaegt Dropbears
    `fill_passwd()`/`getpwnam()` fehl. Ob glibc 2.36-static die
    `nss_files`-Pfade eingebaut mitbringt oder `libnss_files.so.2` vom Ziel
    braucht, ist **UNVERIFIED_HYPOTHESIS** (nicht ausfuehrbar geprueft).
  - `getaddrinfo` betrifft nur Client-/DNS-Pfade, nicht den Server-Listener.
- **Key-only**: keine Passwort-Authentifizierung (siehe oben); fuer den
  geplanten authorized_keys-Betrieb ausreichend.
- Keine PIE/ASLR-Hardening im Binary (bewusst, wegen `-static`).
- Toolchain ist glibc-2.36-basiert; Ziel-Kernel 4.14.190 ist aelter als die
  Mindestanforderung des Binaries ("for GNU/Linux 3.7.0") → sollte laufen,
  aber nicht auf dem Geraet verifiziert (kein Geraetezugriff im Auftrag).
- Kein Ziel-/Firmware-Pfad veraendert; nichts nach `/usr`, `/opt`,
  `/srv/miniconda3` oder ins Zielprojekt installiert.

## 4. Persistenz-Nachweis

```
$ df -h /home/zero/.local/share/opencode
Filesystem      Size  Used Avail Use% Mounted on
/dev/nvme1n1p1  915G  537G  332G  62% /home/zero/.local/share/opencode
$ findmnt -T /home/zero/.local/share/opencode -o TARGET,SOURCE,FSTYPE,OPTIONS
TARGET                           SOURCE                                           FSTYPE OPTIONS
/home/zero/.local/share/opencode /dev/nvme1n1p1[/home/zero/.local/share/opencode] ext4 rw,relatime
$ ls -l /home/zero/.local/share/opencode/re-tools/bin/aarch64/
-rwxr-xr-x 1 zero zero 1126088 ... dropbear
-rwxr-xr-x 1 zero zero  928184 ... dropbearkey
$ ls -d /home/zero/.local/share/opencode/re-tools/cross-aarch64/usr/bin
/home/zero/.local/share/opencode/re-tools/cross-aarch64/usr/bin
```
Beide Ergebnisse liegen unterhalb von
`/home/zero/.local/share/opencode/re-tools/` (persistenter Share), nicht im
kurzlebigen Container-Layer.

## 5. Artefakt-/Hash-Manifest

Vollstaendig: `/workspace/work/odessa/dropbear-build/SHA256SUMS`
(10 .deb, Dropbear-Tarball + 2 Signaturen, installierte und ungestrippte
Binaries).
