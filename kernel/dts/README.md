# Runtime device tree

The runtime DTB is not the kernel's `arch/arm64/boot/dts/qcom` board file. ABL
passes its own merged DTB/DTBO to the boot chain and the bootloader rejects
some recompiled variants; the validated tree is therefore maintained as a
decompiled DTS and patched in place.

- `odessa-6.12.dts` — decompiled form of the validated runtime DTB
  (`fix35`, sha256 `a1d18b51…6a493c`). Reference only.
- `odessa-6.12-wled.dts` — release source. Same tree with the PM6150L WLED
  node switched to the mainline binding (`qcom,pm6150l-wled`) plus
  `qcom,enabled-strings`, `current-limit-microamp`, `ovp-millivolt`,
  `current-boost-limit`, `cabc` and `default-brightness`.

Build: `./kernel/build-dtb.sh` (uses the bundled `dtc`).

Do not edit the kernel's `sm6150-moto-odessa.dts` for runtime changes; it is
not used by the FIT.
