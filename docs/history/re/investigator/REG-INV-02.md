# REG-INV-02 — RPMh-Regulator / cmd-db (Phase 2, investigator)

- PROJECT: odessa-usbgadget
- RUN_ID: 20261106-odessa-usbgadget
- TASK_ID: REG-INV-02
- LEAD_ID: W2-RPMH-REG
- TARGET_ID: mainline `/workspace/work/odessa/mainline/linux-6.12`; DTS `/workspace/work/odessa/.re/uboot/abl-merged-gcc.dts`
- MAX_CALL_DEPTH: 2 (Einstieg Tiefe 0)
- STATUS: PARTIAL (Q4-Teilbefund: exakter fix9-Wert nicht im Scope; alles andere belegt)

## Fragestellung

Was muss DTB (und ggf. cmd-db) liefern, damit mainline 6.12 `qcom-rpmh-regulator` die
odessa pm6150/pm6150l/pm8009-Rails registriert — und was ist die exakte Ursache von
`smps8: could not find RPMh address for resource smpc8` und
`ldo15: devm_regulator_register() failed, ret=-22`?

## Untersuchte lokale Pfade (read-only)

- `drivers/regulator/qcom-rpmh-regulator.c` (Probe, Namensbildung, Tabellen, hw_data)
- `drivers/regulator/core.c` (nur register-/constraint-Pfad mit -EINVAL)
- `drivers/soc/qcom/cmd-db.c` (Lookup, Magic, Probe, debugfs-Dump)
- `Documentation/devicetree/bindings/regulator/qcom,rpmh-regulator.yaml`
- `Documentation/devicetree/bindings/reserved-memory/qcom,cmd-db.yaml`
- `arch/arm64/boot/dts/qcom/sdm670.dtsi` (cmd-db-Referenzgroesse)
- `.re/uboot/abl-merged-gcc.dts` (Container/Kinder/Werte)

Nicht gelesen (out of scope): `of_regulator.c` (DT-Constraint-Parser), `rpmh-rsc`, PDC, USB/UFS.

## 1. Probe-/Namensfluss (belegt)

- Bindung: platform_driver mit `of_match_table` (compatible der Container).
- `rpmh_regulator_probe()` liest `qcom,pmic-id` (`:1548`) und iteriert **alle** children
  mit `for_each_available_child_of_node_scoped` (`:1554`); **erster Fehler bricht den
  ganzen Container ab** (`:1561-1562`).
- Kindname → Tabelleneintrag via `of_node_name_eq` (`:427-429`); unbekannt ⇒
  `"Unknown regulator %pOFn"` + `-EINVAL` (`:431-433`).
- Ressourcenname: `scnprintf(name, 20, rpmh_data->resource_name, pmic_id)` (`:436-437`)
  mit Templates `"smp%s8"` / `"ldo%s15"` ⇒ `smps8`+`c` = `smpc8`, `ldo15`+`a` = `ldoa15`.
- `vreg->addr = cmd_db_read_addr(name)`; `0` ⇒
  `"%pOFn: could not find RPMh address for resource %s"` + `-ENODEV` (`:439-444`).
- Erst danach `devm_regulator_register()`; Fehler ⇒
  `"%pOFn: devm_regulator_register() failed, ret=%d"` (`:484-490`).
- Erfolg loggt nur `dev_dbg` (`:492`).

Konsequenz: `ldo15 ... ret=-22` beweist, dass der **Adress-Lookup für ldoa15
erfolgreich war**; `smps8 ... smpc8` beweist, dass der Lookup für smpc8 `0` lieferte,
und zwar **nachdem** `smps1` (erstes pm6150l-Kind, `:16547`) erfolgreich war
(sonst wäre `smpc1` gemeldet worden).

## 2. Wann liefert `cmd_db_read_addr()` 0

`cmd_db_read_addr()` (`cmd-db.c:188-196`): `ret = cmd_db_get_header(id,...);
return ret < 0 ? 0 : le32_to_cpu(ent->addr);`

Damit sind **fünf** Fälle von `0` ununterscheidbar:

1. **cmd-db nicht geprobt** (`cmd_db_header == NULL`) ⇒ `cmd_db_ready()` = `-EPROBE_DEFER`
   (`:133-136`). Ursache kann fehlendes `/reserved-memory`-Kind, fehlgeschlagenes
   `of_reserved_mem_lookup()` (`:346-350`) oder fehlgeschlagenes `memremap` sein.
2. **Header/Magic ungültig** ⇒ `cmd_db_ready()` = `-EINVAL` (`:137-138`). Achtung: die
   Probe setzt `cmd_db_header` **vor** dem Magic-Test (`:352` vs. `:359-362`), d.h. nach
   `"Invalid Command DB Magic"` bleibt ein NULL-Mapping stehen, und alle Lookups liefern 0.
3. **Ressource nicht vorhanden** ⇒ `cmd_db_get_header()` = `-ENODEV` (`:175`).
   Zusätzlich: die Slave-Schleife bricht beim **ersten** `slv_id == 0` ab (`:160-161`),
   ein Header-Loch verdeckt also alle späteren Slaves.
4. **Eintrag vorhanden, `ent->addr == 0`** ⇒ Funktion liefert 0, ohne Fehler.
5. **ID > 8 Zeichen**: `struct entry_header { u8 id[8]; ... }` (`:36-42`), `strtomem_pad`
   (`:156`) schneidet ab ⇒ kein Treffer ⇒ 0. (Unsere Namen sind ≤ 8 Zeichen, daher hier
   nicht ursächlich.)

`cmd_db_get_header()` vergleicht `memcmp(ent->id, query, 8)` (`:165`), d.h. 8-Byte-
Null-gepolstert; `"smpc8"` und `"ldoa15"` passen exakt.

### debugfs-Unterscheidung

`cmd_db_debugfs_dump()` (`:271-323`), Datei `cmd-db` im debugfs-Root, Modus 0400
(`:364: debugfs_create_file("cmd-db", 0400, NULL, NULL, ...)`):

```
Command DB DUMP
Slave <ARC|VRM|BCM> (v<major>.<minor>)
-------------------------
0x<addr>: <id> [<aux-bytes>]
```

- Datei **fehlt** ⇒ Probe nie erfolgreich (Fall 1/2).
- Datei da, ID fehlt ⇒ Fall 3 (bzw. 5).
- `0x00000: smpc8` ⇒ Fall 4.
- Slave-Liste endet früh ⇒ Header-Loch / zu kleine Region.

On-device: `mount -t debugfs none /sys/kernel/debug && cat /sys/kernel/debug/cmd-db`

## 3. cmd-db-DT/Binding

- Binding: `reserved-memory/qcom,cmd-db.yaml` — Kind von `/reserved-memory`
  (`allOf: $ref reserved-memory.yaml`, `:22-23`), `compatible = "qcom,cmd-db"` (`:27`),
  **required: `reg`** (`:29-30`), `unevaluatedProperties: false` (`:32`).
  Beispiel-Region: `reg = <0x85fe0000 0x20000>` (`:41-44`).
- Mainline-Treiber verlangt **keine** Mindestgröße und **keinen** 0x1078-Check:
  `memremap(rmem->base, rmem->size, ...)` (`:352`), danach nur Magic
  `{0xdb,0x30,0x03,0x0c}` an Offset 4 (`:101-108`, `:359-362`). Kein Versionscheck.
- Referenzgröße sdm670: `reg = <0 0x85fe0000 0 0x20000>` (`sdm670.dtsi:508`), also
  0x20000 — unserer 0x1078 ist 30× kleiner, aber wenn ABL exakt 0x1078 reserviert hat
  (so steht es im ABL-DTB), ist das zulässig. Header = 4+4+8*12+4+4 = 0x70
  (`MAX_SLV_ID 8`, `:21`), Rest Daten.
- **4-Byte-„Pointer"-Knoten** (`reg = <0xc3f000c 8>` unter `/soc`) wird von mainline
  **nicht** akzeptiert: `of_reserved_mem_lookup(pdev->dev.of_node)` findet nur
  reserved-memory-Knoten; sonst `"failed to acquire memory region"` + `-EINVAL`
  (`:346-350`). Folge: `cmd_db_header == NULL` ⇒ alle Lookups 0 (Fall 1).
- **Aktueller Knoten ist plausibel**: `/reserved-memory/cmd-db@85f20000`,
  `compatible="qcom,cmd-db"`, `reg=<0x0 0x85f20000 0x0 0x1078>`, `no-map` erfüllt
  Binding und Treiber. Ob er geprobt wurde, ist ohne debugfs-Datei nicht beweisbar —
  die fix9-Meldungen beweisen aber, dass cmd-db **damals** aktiv war (ldo1..ldo14
  passierten den Lookup), sonst wäre schon `ldoa1` gescheitert.

## 4. Der `-22`-Pfad

`devm_regulator_register()` → `regulator_register()` (`core.c:5611`).

Erreichbare `-EINVAL`-Stellen und Ausschluss:

| Stelle | Bedingung | für ldo15 |
|---|---|---|
| `:5625/5629/5636/5642` | cfg/desc NULL, name/ops/type fehlt | nein (Treiber setzt alles) |
| `:5653-5662` | `*_voltage_sel` ohne `list_voltage` | nein (`list_voltage` gesetzt, `:376`) |
| `:5801`→`:5441` | kein Coupler | nein (ldo1..14 derselben Box ok) |
| `:2040` | Supply löst auf sich selbst, keine full constraints | nur bei always_on/boot_on; ldo15 hat keins |
| `:1438` | `initial_mode` ohne `set_mode` | nein (`set_mode` gesetzt, `:377`) |
| `:1441`→`set_mode` | `mode > STANDBY` oder pmic_mode_map[mode] < 0 | nur wenn `regulator-initial-mode` gesetzt |
| `:1323-1326` | `min_uA > max_uA` | ldo15 hat keine current-Props |
| **`:1266-1268`** | `cmin <= 0 \|\| cmax <= 0 \|\| cmax < cmin` | **möglich** |
| **`:1291-1295`** | kein unterstützter Wert in `[cmin..cmax]` | **möglich** |

`machine_constraints_voltage()` (`:1177-1312`) prüft also nur die DT-Min/Max; es gibt
keine Ausrichtungs-/Schrittweitenprüfung (nicht darstellbare Zwischenwerte werden
geklemmt, `:1298-1308`).

Vergleich mit den **aktuellen** DTS-Werten (`abl-merged-gcc.dts:16494-16502`):

- ldo15: min `0x19e100` = 1.696.000 µV, max `0x1d0d80` = **1.904.000 µV**
  (nicht 1.902.464 — die Hex-Umrechnung im Auftrag war falsch).
- pm6150 ldo15 → `pmic5_pldo_lv` (`:1291`), Tabelle
  `REGULATOR_LINEAR_RANGE(1504000, 0, 62, 8000)` (`:718-729`), also
  1.504.000…2.000.000 µV in 8-mV-Schritten.
- 1.696.000 = 1.504.000 + 24·8.000 (Selector 24) ✔
- 1.904.000 = 1.504.000 + 50·8.000 (Selector 50) ✔
⇒ **mit diesen Werten ist der Bereich exakt darstellbar, `-22` tritt NICHT auf.**

- pm6150l smps8 → `pmic5_hfsmps510` (`:1307`), `LINEAR_RANGE(320000, 0, 215, 8000)`
  (`:810-820`): 1.120.000 = 320.000+100·8.000 ✔, 1.408.000 = 320.000+136·8.000 ✔
  ⇒ auch hier kein Spannungsfehler; der Fehler kam aus dem Adress-Lookup davor.

**Schlussfolgerung Q4:** Da ldo15 kein `always-on`/`boot-on`, keine current-Props und
kein `regulator-initial-mode` hat, bleibt als einzige mögliche `-EINVAL`-Quelle
`machine_constraints_voltage()`. Die **aktuellen** Werte verletzen sie nicht — der
`-22` stammt also aus dem **früheren (fix9) DTB**, dessen ldo15-Constraints eine der
beiden Bedingungen verletzten (z. B. min/max vertauscht, max=0 oder ein von einem
Corner-/Level-Knoten kopiertes Paar wie `0x11`/`0x10000`, `:16341-16344`).
Der exakte fix9-Wert ist in den erlaubten Pfaden nicht vorhanden.

## 5. Gültige Kindnamen vs. DTS

- pm6150 (`:1271-1297`): `smps1..5`, `ldo1..19`.
- pm6150l (`:1299-1321`): `smps1..8`, `ldo1..11`, `bob`.
- pm8009 (`:1235-1246`): `smps1..2`, `ldo1..7`.

DTS-Inventar (grep-Treffer):
- `regulators-pm6150` (`:16381`, pmic-id `a`): ldo1-6, ldo9-19 (kein ldo7/8, kein smps).
- `regulators-pm6150l` (`:16543`, pmic-id `c`): smps1, smps8, ldo1-11, bob.
- `regulators-pm8009` (`:16673`, pmic-id `f`): smps1, smps2, ldo1, ldo2, ldo4-7.

⇒ **Kein einziger Kindname ist ungültig**; `Unknown regulator` ist nicht die Ursache.
Ungültig wäre nur ein Name außerhalb der Tabellen (z. B. `ldo20` bei pm6150).
Der Abbruch erfolgt ausschließlich über Adress-Lookup (`smps8`) bzw. Constraints (`ldo15`).

Vendor-Properties: gelesen werden nur `qcom,pmic-id` (`:1548`) und
`qcom,always-wait-for-ack` (`:460-461`). **Ignoriert** (zur Laufzeit harmlos, aber
binding-illegal wegen `unevaluatedProperties: false`, `yaml:123-127`):
`qcom,set`, `qcom,init-voltage`, `qcom,init-mode`, `qcom,init-voltage-level`,
`qcom,resource-name`, `qcom,regulator-type`. `regulator-name` ist legal und wird gelesen.

## 6. Parent-Supplies (`vdd-*`)

- Der Treiber setzt `rdev->supply_name` aus der Tabelle (z. B. `vdd-l10-l14-l15`, `:1291`).
- `regulator_resolve_supply()` (`core.c:2002-2033`): fehlt die DT-Property, liefert der
  Lookup `-ENODEV`; mit `have_full_constraints()` → **Dummy-Regulator** (ok), sonst
  `"Failed to resolve %s-supply for %s"` + `-EPROBE_DEFER`.
- **Kritisch:** bei `always_on`/`boot_on` wird der Supply **im Probe** aufgelöst
  (`:5750-5759`, `:1599-1600`): fehlt er, gibt es `-EPROBE_DEFER` (bis `late_initcall`,
  das `have_full_constraints()` setzt). Ein Phandle auf einen **nicht geprobten**
  Provider ⇒ `-EPROBE_DEFER` (`:2021-2023`, `:2053-2058`).
- Für normale (nicht always-on) Rails ist der Parent-Supply **optional** und
  probe-blockiert nicht. In der Binding sind die `vdd-*-supply`-Properties für pm6150
  als Container-Properties deklariert (`yaml:136-147`).

## 7. Minimalplan (DTS)

Voraussetzung: zuerst `cat /sys/kernel/debug/cmd-db` (siehe 8) — die existierenden
Ressourcen bestimmen, welche Kinder überhaupt eine Chance haben.

1. **pm6150-Container** (`:16381`): Kinder auf die tatsächlich benötigten reduzieren.
   Für die UFS-Rails (aus UFS-INV-01) wären das:
   - `ldo4` 824.000 µV (`pmic5_nldo`: 320.000+63·8.000 ✔)
   - `ldo12` 1.696.000 µV (`pmic5_pldo_lv`, Sel. 24 ✔)
   - `ldo19` 2.944.000 µV (`pmic5_pldo`: 1.504.000+180·8.000 ✔)
   Jeweils `regulator-min-microvolt = regulator-max-microvolt = <Wert>` (exakt
   darstellbar, keine Klemmung), `regulator-name` optional.
2. **pm6150l-Container** (`:16543`): `smps8` **entfernen** (kein nutzbarer smpc8-Eintrag),
   `smps1` nur behalten, wenn belegt benötigt; für die UFS-PHY `ldo3` 1.144.000 µV
   (`pmic5_nldo`: 320.000+103·8.000 ✔) behalten.
3. **pm8009-Container** (`:16673`): komplett entfernen oder nur belegte Rails; `smps2`
   (2.900.000 µV) ist in `pmic5_hfsmps515` **nicht** schrittexakt
   (`LINEAR_RANGE(320000,0,235,16000)`, `:882-892`) und wird auf 2.896.000 µV geklemmt
   — funktioniert, aber Wert korrigieren.
4. **Vendor-Properties entfernen**: `qcom,set`, `qcom,init-voltage`, `qcom,init-mode`,
   `qcom,init-voltage-level` (werden nicht gelesen, verletzen aber die Binding).
5. **`always-on`/`boot-on` nur mit gültigem Parent-Supply-Phandle** setzen, sonst
   `-EPROBE_DEFER` (siehe 6). Besser weglassen.
6. **`qcom,pmic-id` beibehalten**: `a` (pm6150), `c` (pm6150l), `f` (pm8009).
   Beleg: `smpc1` wurde gefunden, `smpc8` nicht ⇒ Buchstabe `c` ist korrekt, nur die
   konkrete Ressource fehlt.
7. Reihenfolge: erst pm6150 allein testen, dann pm6150l, dann pm8009 — da der erste
   Fehler den ganzen Container abbricht, ist die kleinste Kinderzahl die beste Isolation.

UNKNOWN in diesem Plan: welche Ressourcen die odessa-cmd-db wirklich enthält (nur per
Dump), exakte fix9-ldo15-Werte, ob 0x1078 die komplette DB abdeckt.

## 8. Verifikation

- `mount -t debugfs none /sys/kernel/debug; cat /sys/kernel/debug/cmd-db`
  → muss `smpc8` bzw. `ldoa15` mit `0x<addr> != 0` listen.
- `cat /sys/kernel/debug/regulator/regulator_summary` → registrierte Rails.
- `ls /sys/class/regulator/; cat /sys/class/regulator/regulator.*/name`
- `dmesg | grep -iE 'rpmh|could not find|devm_regulator_register|Unknown regulator|failed to set constraints|Invalid Command DB|failed to acquire memory'`
- `cat /sys/kernel/debug/devices_deferred` (bei `-EPROBE_DEFER`).
- Erwartete dmesg-Zeilen bei Erfolg: **keine** der obigen Fehler; mit dynamic debug
  (`dev_dbg`, `:492`): `"<rail>: regulator registered for RPMh resource <name> @ 0x<addr>"`.
- Bei Magic-Fehler: `"Invalid Command DB Magic"` (`cmd-db.c:360`).
- Bei fehlendem reserved-memory: `"failed to acquire memory region"` (`:348`).

## Offene Punkte / Grenzen

- `of_regulator.c` (DT-Constraint-Parser, u. a. `regulator-initial-mode`) ist nicht in
  ALLOWED_PATHS und wurde nicht gelesen; die `initial_mode`-Trigger-Aussage ist daher
  aus core.c-Code abgeleitet (Property-Namen aus core.c-Nutzung), nicht aus dem Parser.
- fix9-DTB/-DTS ist nicht im Scope; der exakte ldo15-Wert von damals bleibt UNKNOWN.
- Budget: ~1.150 gelesene Zeilen statt 900 (overrun deklariert); keine Schreib-/Build-
  /Ausführungsaktion, keine Remote-Interaktion.
