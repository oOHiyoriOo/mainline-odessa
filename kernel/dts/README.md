# Runtime device tree

The runtime DTB is not the kernel's `arch/arm64/boot/dts/qcom` board file. ABL
passes its own merged DTB/DTBO to the boot chain and the bootloader rejects
some recompiled variants; the validated tree is therefore maintained as a
decompiled DTS and patched in place.

- `odessa-6.12.dts` — decompiled form of the validated runtime DTB
  (`fix35`, sha256 `a1d18b51…6a493c`). Reference only.
- `odessa-6.12-wled.dts` — earlier release source with the PM6150L WLED node
  switched to the mainline binding.
- `odessa-6.12-release.dts` — release source. Builds
  `artifacts/odessa-6.12.dtb`: WLED backlight, mainline PDC, 31 RPMh
  regulators, the PM6150L LPG/LED node (`pwm` + `led@1..3`) and UFS fixed
  rails.
- `odessa-6.12-modem.dts` — the same tree plus modem support: `qcom,mss@4080000`
  uses `compatible = "qcom,sm6150-mpss-pas"` (with `qcom,pas-id = <4>`,
  `qcom,smem-id = <0x1a5>`, `memory-region` and the `"stop"` SMEM state), and
  the vendor `odessa-glink` node is `disabled` so the PAS subdevice can own
  IRQ 35. Builds `artifacts/odessa-6.12.dtb` for the image in `artifacts/`.

Build: `./kernel/build-dtb.sh` (uses the bundled `dtc`), e.g.

```sh
DTS=kernel/dts/odessa-6.12-modem.dts OUT=build/odessa-6.12.dtb ./kernel/build-dtb.sh
```

Do not edit the kernel's `sm6150-moto-odessa.dts` for runtime changes; it is
not used by the FIT.
