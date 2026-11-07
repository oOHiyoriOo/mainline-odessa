# PDC-REG-MAP-01 — Scout: PDC + RPMh regulator data for mainline 6.12

PROJECT=odessa-usbgadget RUN_ID=20261106-odessa-usbgadget TASK_ID=PDC-REG-MAP-01
TARGET_ID=vendor:/workspace/work/odessa/kernel (4.14.190) ; mainline:/workspace/work/odessa/mainline/linux-6.12
ROLE=scout PHASE=1 LEAD_ID=PDC+REGULATORS STATUS=PARTIAL (budget overrun, see LIMITATIONS)
MODE=read-only, no delegation, MAX_CALL_DEPTH=2

## 0. Suchplan (tatsaechlich ausgefuehrt)

| # | Suchmuster / Frage | Umfang | Ergebnis |
|---|---|---|---|
| S1 | `qcom-pdc.c` im Vendor-Kernel | `kernel/drivers/irqchip/` | NICHT vorhanden (Pfad aus Auftrag existiert nicht) |
| S2 | `qcom,pdc` / `pdc-ranges` in `kernel/drivers` | vendor drivers | PDC liegt in `drivers/irqchip/qcom/` (pdc.c, pdc-sdmmagpie.c, pdc.h) |
| S3 | `xlate|interrupt-cells|irq_domain|pin` in qcom/pdc.c | vendor pdc.c | Treffer: translate delegiert an Parent (GIC) |
| S4 | `qcom,pdc-ranges|interrupt-cells|nr_ranges` mainline qcom-pdc.c | mainline | Treffer: 2-cell translate, ranges-Parser, Fehlerpfad |
| S5 | `pdc|interrupt-parent|interrupt-controller` in abl-merged-gcc.dts | 1 Datei | PDC-Node, Root-Default, 20 Overrides |
| S6 | `interrupt-parent = <0x1>` | abl-merged-gcc.dts | 1 Treffer (Root, Zeile 10) |
| S7 | `^\s+interrupts = <` | abl-merged-gcc.dts | 138 Treffer (Rohwerte erfasst) |
| S8 | `rpmh-regulator|qcom,rpmh-regulator|regulator-name` | abl-merged-gcc.dts | 6 Arc-Wrapper + 3 PMIC-Container |
| S9 | `qcom,resource-name|qcom,pmic-id|qcom,rpmh-arc-regulator` | abl-merged-gcc.dts | 15 Treffer |
| S10 | `rpmh-regulator-smpc8 {` / `ldoa15 {` | vendor dts/qcom | sdmmagpie-regulator.dtsi:148 / :452 |
| S11 | `could not find RPMh address|pm6150.*vreg_data|pmic_id` | mainline qcom-rpmh-regulator.c | Treffer: 441, 1271, 1299, 1548 |
| S12 | Binding `qcom,rpmh-regulator.yaml` | 1 Datei (voll gelesen) | Pflichtprops, Namenslisten, pmic-id enum |
| S13 | `rpmh-arc-regulator` in mainline `drivers/` | mainline drivers | 0 Treffer |
| S14 | `rpmh-vrm-regulator` in mainline `drivers/regulator` | mainline | 0 Treffer |
| S15 | `qcom,pdc-pins|qcom,pdc-sdmmagpie` vendor dts/qcom | vendor dts | sdmmagpie.dtsi:775 (+3 VM-Dateien mit pdc-pins) |

## A) PDC

### A1. Vendor-Tabelle (sdmmagpie)

`kernel/drivers/irqchip/qcom/pdc-sdmmagpie.c:17-145` — `static struct pdc_pin sdmmagpie_data[]`.
Format ist **kein Triple**, sondern ein **Paar** `{pdc_pin, gic_hwirq}` (struct in `qcom/pdc.h:17-20`:
`int pin; irq_hw_number_t hwirq;`), terminiert durch `{-1}` (Zeile 144).

Kopf und Fuss der Tabelle (wortgetreu):
```
17: static struct pdc_pin sdmmagpie_data[] = {
18: 	{0, 512},/*rpmh_wake*/
19: 	{1, 513},/*ee0_apps_hlos_spmi_periph_irq*/
...
142: 	{124, 671},/*core_bi_px_gpio_59*/
143: 	{125, 95},/*core_bi_px_gpio_6*/
144: 	{-1}
145: };
```
Semantik: Pin 0..93 → hwirq 512..605 (lueckenlos), Pin 94..124 → hwirq 641..671
(lueckenlos), Pin 125 → hwirq 95 (Sonderfall, einziger nicht-monotoner Eintrag).
`hwirq` ist die **GIC-Hwirq-Nummer** (SPI-Nummer + 32), nicht die DT-Interrupt-Nummer:
GIC-3-Translate im selben Baum rechnet `*hwirq = fwspec->param[1] + 32`
(`kernel/drivers/irqchip/irq-gic-v3.c:1073`).

### A2. Vendor `#interrupt-cells` und translate()

Node (`kernel/arch/arm64/boot/dts/qcom/sdmmagpie.dtsi:774-780`, identisch in
`abl-merged-gcc.dts:492-499`):
```
775: 		compatible = "qcom,pdc-sdmmagpie";
776: 		reg = <0xb220000 0x400>;
777: 		#interrupt-cells = <3>;
778: 		interrupt-parent = <&intc>;
```
- 3 Zellen, exakt GIC-Format `(type, number, flags)`; **keine** Pin-Nummerierung.
- `qcom_pdc_translate()` reicht unveraendert an den Parent weiter:
  `pdc.c:254-258` → `return d->parent->ops->translate(d->parent, fwspec, hwirq, type);`
- `qcom_pdc_alloc()` uebernimmt dieselbe fwspec fuer den Parent (`pdc.c:278-282`),
  d.h. die Interrupts werden **immer** als GIC-SPI weitergereicht.
- Pin-Zuordnung passiert nur beim Enable/Type-Config ueber `get_pdc_pin(d->hwirq,...)`
  (`pdc.c:55-66`); ist der hwirq nicht in der Tabelle, wird die PDC-Programmierung
  stillschweigend uebersprungen: `pdc.c:75-76` `if (pin_out < 0) return 0;`.
  ⇒ Vendor-PDC ist ein **transparenter Pass-through** fuer alle GIC-SPIs;
  nur die 126 gelisteten Pins werden zusaetzlich als Wakeup-Quellen scharf geschaltet.
- Root des Vendor-Baums setzt PDC als Default:
  `sdmmagpie.dtsi:36  interrupt-parent = <&pdc>;` bzw. `abl-merged-gcc.dts:10  interrupt-parent = <0x01>;`

### A3. Mainline qcom-pdc: Pflicht-Properties, Format, Fehlerpfad

`mainline/linux-6.12/drivers/irqchip/qcom-pdc.c`
- Match nur ueber `"qcom,pdc"`: `370: IRQCHIP_MATCH("qcom,pdc", qcom_pdc_init)`.
- `qcom,pdc-ranges` = Tripel `(pin_base, parent_base, cnt)`, Laenge muss durch 3 teilbar sein:
```
275: 	n = of_property_count_elems_of_size(np, "qcom,pdc-ranges", sizeof(u32));
276: 	if (n <= 0 || n % 3)
277: 		return -EINVAL;
...
289: 						 &pdc_region[n].pin_base);
294: 						 &pdc_region[n].parent_base);
299: 						 &pdc_region[n].cnt);
```
- Mapping-Formel: `45: #define pin_to_hwirq(r, p) ((r)->parent_base + (p) - (r)->pin_base)`
- `#interrupt-cells = <2>` (`sdm670.dtsi:1380`), Translate ist
  `266: .translate = irq_domain_translate_twocell` ⇒ Zelle 0 = **PDC-Pin**, Zelle 1 = Typ.
- Fehlerpfad wenn ranges fehlen/falsch: `pdc_setup_pin_mapping()` → `-EINVAL` →
  `342-346: if (ret) { pr_err("%pOF: failed to init PDC pin-hwirq mapping\n", node); goto fail; }`
  → `fail:` `kfree(pdc_region); iounmap(pdc_base); return ret;` ⇒ Domain wird **nicht**
  erzeugt, jedes `interrupt-parent = <&pdc>` bleibt unaufloesbar.
- Verhalten fuer Pins ohne Region (wichtig!): **kein** Pass-through wie im Vendor-Treiber,
  sondern Hierarchie wird getrennt:
```
245: 	region = get_pin_region(hwirq);
246: 	if (!region)
247: 		return irq_domain_disconnect_hierarchy(domain->parent, virq);
```
  ⇒ Vendor-`interrupts`-Werte, die nur zufaellig als GIC-SPI gemeint waren, funktionieren
  unter `&pdc` **nicht** mehr; sie muessen auf `&intc` zeigen.
- `reg`-Groesse: `310: #define QCOM_PDC_SIZE 0x30000` + Warnung bei kleinerem reg
  (`323-325`), Vendor-`reg = <0xb220000 0x400>` erzeugt also nur eine Warnung.
- Abgeleitete ranges fuer sdmmagpie (aus A1 gerechnet, **nicht** aus sdm670 kopieren):
  `<0 512 94>, <94 641 31>`; Pin 125→95 ist damit nicht darstellbar.
  Vergleich mainline sdm670: `sdm670.dtsi:1377-1379` `<0 480 40>, <41 521 7>, ...` —
  andere Basis (480 vs 512), also **nicht** wiederverwendbar.
- Mainline-Muster fuer Nutzung: PDC haengt als `wakeup-parent` am TLMM, nicht als
  `interrupt-parent` an Peripherie:
  `sdm670.dtsi:1163-1169` `interrupts = <GIC_SPI 208 ...>; ... #interrupt-cells = <2>; wakeup-parent = <&pdc>;`

### A4. PDC-Konsumenten in abl-merged-gcc.dts

Root-Default: `abl-merged-gcc.dts:10  interrupt-parent = <0x01>;` (PDC = phandle 1,
definiert `:498  phandle = <0x01>;`). Ein explizites `interrupt-parent = <0x1>` gibt es
ausserdem **nirgends** (S6: 1 Treffer = Root).

Explizite Overrides (brechen die PDC-Vererbung) — Zeile / Parent:
`488,496,531` = 0x1a (GIC) · `906` = 0x51d · `4008` = 0x1a · `4460` = 0x99 (TLMM) ·
`8968,9196,9279,9318,9433` = 0x178 · `11974,12019,12061,12168` = 0x1aa ·
`19569` = 0x1a · `22340,22474,22714` = 0x178.

Damit erben alle Knoten, deren naechster Vorfahre mit `interrupt-parent` die Root ist,
den PDC. Beispiele (Rohwert, 3 Zellen, GIC-Format):
```
4763: ufshc@1d84000 {              4768: interrupts = <0x00 0x109 0x00>;   /* SPI 265 */
19551: usb@a6f8800 (dwc3-Kind)      19570: interrupts = <0x00 0x85 0x04>;  /* SPI 133, ABER Parent 0x1a */
11974..12168 (qup/i2c-Block)       interrupts = <0x02 0x00>; ...  /* 2 Zellen, Parent 0x1aa */
21430: gpu@...                     interrupts = <0x00 0x130 0x04 0x00 0x131 0x04>;
```
Bewertung:
- Alle vom PDC geerbten Eintraege sind **3-Zellen-GIC-SPIs mit Nummern >= 32**
  (Beispiele 0x109=265, 0x1e1=481, 0x281=641, 0x53=83, 0x32=50).
- Die einzigen 2-Zellen-Eintraege liegen unter fremden 2-Cell-Controllern
  (0x178: `<0x25 0x00>`, `<0x05 0x00>`, `<0x5d 0x2002>`, `<0x09 0x02>`, `<0x5a 0x00>`,
  `<0x39 0x2002>`; 0x1aa: `<0x02 0x00>`, `<0x04 0x00>`, `<0x05 0x00>`, `<0x0c 0x00>`).
- **Kein** Wert sieht nach PDC-Pin-Nummerierung (<128 als Pin-Index) aus.
Vollstaendige 1:1-Liste aller erbenden Knoten (138 `interrupts`-Properties) wurde wegen
Budget nicht erstellt → LIMITATIONS; die 138 Rohwerte liegen oben in S7 als Suchprotokoll.

## B) RPMh-Regulatoren

### B5. Vendor-Knoten

`abl-merged-gcc.dts` (gemergter ABL-DTB) enthaelt **9** rpmh-Regulator-Knoten:
| Zeile | Node | compatible | Kinder / regulator-name |
|---|---|---|---|
| 16364 | rpmh-regulator-gfxlvl | qcom,rpmh-arc-regulator, resource-name "gfx.lvl" | regulator-pm6150-s2-level → pm6150_s2_level |
| 16379 | rpmh-regulator-mxlvl | qcom,rpmh-arc-regulator, "mx.lvl" | regulator-pm6150-s3 / -s3-level-ao (+mx-cdev-lvl) |
| 16411 | regulators-pm6150 | qcom,pm6150-rpmh-regulators, pmic-id "a" | ldo1..ldo19 → pm6150_l1..l19 |
| 16573 | regulators-pm6150l | qcom,pm6150l-rpmh-regulators, pmic-id "c" | smps1, smps8, ldo1..ldo11, bob |
| 16703 | (pm8009) | qcom,pm8009-rpmh-regulators, pmic-id "f" | smps1, smps2, ldo1, ldo2, ldo4..ldo7 |
| 16775 | rpmh-regulator-cxlvl | qcom,rpmh-arc-regulator, "cx.lvl" | regulator-pm6150l-s2 / -s2-level-ao |
| 16811 | rpmh-regulator-modemlvl | "mss.lvl" | regulator-pm6150l-s7 |
| 16835 | rpmh-regulator-lmxlvl | "lmx.lvl" | regulator-pm6150-l7 |
| 16850 | rpmh-regulator-lcxlvl | "lcx.lvl" | regulator-pm6150-l8 |

Im **Quell-DTSI** sind die Regler dagegen einzeln gekapselt (Vendor-Schema):
`sdmmagpie-regulator.dtsi:148-159`
```
148: 	rpmh-regulator-smpc8 {
149: 		compatible = "qcom,rpmh-vrm-regulator";
150: 		mboxes = <&apps_rsc 0>;
151: 		qcom,resource-name = "smpc8";
152: 		S8C: pm6150l_s8: regulator-pm6150l-s8 {
155: 			regulator-min-microvolt = <1120000>;
```
`sdmmagpie-regulator.dtsi:452-468` analog fuer `rpmh-regulator-ldoa15`,
`qcom,resource-name = "ldoa15"`, `qcom,regulator-type = "pmic5-ldo"`,
`qcom,supported-modes`, `qcom,mode-threshold-currents`.
⇒ Der Vendor-DTB benennt die RPMh-Ressource **explizit**; die Namen (`smpc8`, `ldoa15`)
entsprechen genau den mainline-generierten Namen (s.u.).

### B6. Mainline-Binding

`mainline/linux-6.12/Documentation/devicetree/bindings/regulator/qcom,rpmh-regulator.yaml`
- Zwei Ebenen, Container **muss** in einem RPMh-Device-Node liegen (`:29-33`).
- Erlaubte Regler-Namen (`:35-44`):
  `For PM6150, smps1 - smps5, ldo1 - ldo19` / `For PM6150L, smps1 - smps8, ldo1 - ldo11, bob`
  / `For PM8009, smps1 - smps2, ldo1 - ldo7`.
- compatibles `:63-64` `qcom,pm6150-rpmh-regulators`, `qcom,pm6150l-rpmh-regulators`,
  `:70` `qcom,pm8009-rpmh-regulators`.
- `required: compatible, qcom,pmic-id` (`:132-134`); `qcom,pmic-id` enum `[a..n]` (`:99`).
- Kinder: `patternProperties "^(smps|ldo|lvs|bob)[0-9]+$"` → `$ref: regulator.yaml#`
  (`:123-130`) mit `unevaluatedProperties: false` — d.h. **keine** Vendor-Properties
  (`qcom,set`, `qcom,init-voltage`, `qcom,resource-name`, `qcom,regulator-type`) erlaubt.
  Standard-Props: `regulator-name`, `regulator-min/max-microvolt`,
  `regulator-initial-mode`, `regulator-allowed-modes`, `regulator-allow-set-load`.
- `.yaml` ist mit 523 Zeilen vollstaendig gelesen (Budget!).

### B7. Ursache der beiden Fehlermeldungen

Mainline erzeugt den RPMh-Ressourcennamen **aus Kindname + pmic-id**, nicht aus
`qcom,resource-name`:
```
qcom-rpmh-regulator.c:427  for (rpmh_data = pmic_rpmh_data; rpmh_data->name; rpmh_data++)
428: 		if (of_node_name_eq(node, rpmh_data->name))
436: 	scnprintf(rpmh_resource_name, sizeof(rpmh_resource_name),
437: 		rpmh_data->resource_name, pmic_id);
439: 	vreg->addr = cmd_db_read_addr(rpmh_resource_name);
440: 	if (!vreg->addr) {
441: 		dev_err(dev, "%pOFn: could not find RPMh address for resource %s\n",
```
Tabelleneintraege (Format `RPMH_VREG(node_name, "resource_fmt", hw_data, supply)`):
```
1307: 	RPMH_VREG("smps8",  "smp%s8",  &pmic5_hfsmps510, "vdd-s8"),
1291: 	RPMH_VREG("ldo15",  "ldo%s15", &pmic5_pldo_lv,   "vdd-l10-l14-l15"),
```
- `smpc8` = `smp` + pmic-id `c` + `8` ⇒ pm6150l-Container mit `qcom,pmic-id="c"` und
  Kind `smps8`. Fehler heisst: `cmd_db_read_addr("smpc8") == 0`, also fehlt der Name in
  der **cmd-db-Dictionary des Geraets** (bzw. cmd-db wurde nicht gelesen). Der Vendor-Treiber
  braucht diese Dictionary nicht (Ressource steht explizit im DT: `resource-name="smpc8"`),
  mainline schon ⇒ **kein DT-Umbenennungsproblem, sondern ein cmd-db/Adressproblem**.
  Gegenprobe noetig (Investigator): Inhalt von cmd-db (Region/Node) fuer `smpc8`/`ldoa15`.
- `ldo15` erreicht `cmd_db_read_addr` erfolgreich, scheitert erst bei
  `qcom-rpmh-regulator.c:484-487`
  `rdev = devm_regulator_register(...); ... "devm_regulator_register() failed, ret=%d"`
  mit -22 (EINVAL). Kandidaten (UNVERIFIED, nicht im erlaubten Pfad pruefbar):
  (a) Kindknoten-Name/Container-Zuordnung inkonsistent (z.B. ldo15 unter falschem
  pmic-id ⇒ anderer Name, aber dann kaeme „Unknown regulator"/-ENODEV);
  (b) Pflicht-Constraints/Properties fehlen im umgebauten Knoten;
  (c) `regulator-min/max-microvolt` aus dem Vendor-DTSI (1.696–1.904 V) passen zwar zu
  `pmic5_pldo_lv` (1504 mV + 0..62*8 mV, `:718-725`), ein falsch zugeordnetes
  `hw_data` (z.B. `pmic5_nldo`) wuerde aber -EINVAL erzeugen.
  ⇒ konkrete Investigator-Frage noetig (siehe FINDINGS/Leads).
- Zusatz-Mismatch, der jeden Container killt: `rpmh_regulator_probe()` bricht beim ersten
  fehlerhaften Kind ab (`1559-1562  ret = rpmh_regulator_init_vreg(...); if (ret < 0) return ret;`).
  Ein einziges Vendor-Extra-Kind (z.B. `mx-cdev-lvl`, `regulator-cdev`) fuehrt zu
  „Unknown regulator" -EINVAL (`431-433`) und verhindert alle Geschwister.

### B8. Reicht eine reine DT-Konvertierung?

- **PDC:** ja, aber DT-Umbau ist noetig, kein Treiberwechsel:
  1. compatible muss `"qcom,pdc"` enthalten (mainline matcht nur das, `:370`).
  2. `#interrupt-cells = <2>` + `qcom,pdc-ranges = <0 512 94>, <94 641 31>`
     (aus `sdmmagpie_data`), `reg` auf 0x30000 vergroessern.
  3. Peripherie-Knoten, die heute den PDC erben, auf `interrupt-parent = <&intc>`
     umstellen (Vendor-Semantik war Pass-through; mainline trennt die Hierarchie).
  4. TLMM bekommt `wakeup-parent = <&pdc>` (mainline-Muster, `sdm670.dtsi:1169`).
- **Regulatoren:** DT-Konvertierung ist **notwendig, aber nicht hinreichend**:
  - notwendig: pro PMIC ein Container mit mainline-compatible + `qcom,pmic-id`,
    Kinder exakt `smps1..8`/`ldo1..19`/`bob`, Vendor-Properties entfernen
    (Binding `unevaluatedProperties: false`), `qcom,rpmh-arc-regulator`-Wrapper
    (gfx/mx/cx/mss/lmx/lcx) haben in 6.12 **keinen Treiber** (S13: 0 Treffer) und
    muessen durch rpmhpd-Power-Domains ersetzt oder aus den Supplies entfernt werden
    (deckt sich mit GCC-ROOTCAUSE-Befund: vdd_cx-Supply blockiert GCC via fw_devlink).
  - nicht hinreichend: `cmd_db_read_addr()` kann per DT nicht beeinflusst werden.
    Fehlt `smpc8` in der cmd-db, bleibt der Regler unprovisioniert ⇒ Treiber-/
    Firmware-/cmd-db-Untersuchung oder ein Treiber-Fallback noetig.
  - Der Treiber selbst braucht fuer PM6150/PM6150L/PM8009 **keine** Aenderung
    (Tabellen vorhanden: 1271, 1299, 1235; compatibles 1631/1635/1574).

## Offene Fragen (fuer Investigator, je 1 Frage)

1. Enthaelt die cmd-db-Dictionary dieses Geraets die Namen `smpc8`, `ldoa15`, `smpa*`,
   `ldoc*`, `ldof*`? Wo liegt die Dictionary (Region/Node) und liest der mainline
   cmd-db-Treiber dieselbe Kopie wie der Vendor-RPMh-Treiber?
2. Warum liefert `devm_regulator_register()` fuer den ldo15-Knoten -EINVAL —
   welcher `rpmh_vreg_hw_data` wird tatsaechlich zugeordnet und welche Constraints
   stehen im verwendeten (fix9-)DTB-Knoten?
3. Ist `qcom-pdc` in 6.12 fuer arm64 standardmaessig gebaut (Kconfig) und akzeptiert
   `qcom,sdmmagpie-pdc` als zusaetzliches compatible neben `qcom,pdc`?

## Grenzen / LIMITATIONS

- `kernel/drivers/irqchip/qcom-pdc.c` existiert nicht; Vendor-Treiber liegt unter
  `kernel/drivers/irqchip/qcom/`.
- Budget ueberschritten: das Binding-YAML wurde mit 523 Zeilen vollstaendig gelesen,
  Gesamt-Leseumfang dadurch > 600 Zeilen (grob 1100). Ab hier keine weiteren
  Volltext-Reads; Folgearbeit muss neu budgetiert werden.
- Die 138 `interrupts`-Properties wurden als Rohwerte erfasst, aber nicht knotenweise
  bis zum naechsten `interrupt-parent`-Vorfahren aufgeloest (Baumtraversierung waere
  Tiefenanalyse). Liste der erbenden Knoten daher unvollstaendig.
- `stock-base.dts` (enthaelt laut Memory a1186601 die 25 Einzel-Wrapper `-smpc8`,
  `-ldoa1..17`) liegt ausserhalb der freigegebenen Pfadliste und wurde nicht gelesen;
  die Vendor-Struktur wurde stattdessen aus `sdmmagpie-regulator.dtsi` belegt.
- Kein DTS-Quelltext des fix9/fix10-Test-DTB vorhanden (nur .dtb/.itb) ⇒ der exakte
  aufgebaute Reglerknoten fuer `ldo15` ist nicht belegbar.
- Keine Aussage zu cmd-db-Treibercode (nicht in ALLOWED_PATHS).
