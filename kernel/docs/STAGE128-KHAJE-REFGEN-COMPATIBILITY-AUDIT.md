# Stage 128 — Khaje REFGEN regulator compatibility audit

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: static vendor/Mainline source and build-artifact audit only.

## Vendor hardware description

The vendor Khaje regulator DTS defines REFGEN at `0x01600000` with size `0x84`, compatible `qcom,refgen-kona-regulator`, a 5 µs enable ramp, and a proxy-consumer self-reference. The vendor driver implements the Kona variant by setting bit 0 at register offset `0x80` to enable and clearing it to disable. The SPES Mainline DTS uses the same register base and size.

The vendor Khaje SDE DSI0 node consumes `refgen-supply = <&refgen>`, alongside the 1.232 V controller analog supply. The Mainline SPES DSI0 node likewise declares `refgen-supply = <&spes_refgen>` and `vdda-supply = <&pm6125_l18>`.

## Mainline implementation equivalence

Mainline's `qcom,sm8250-refgen-regulator` match uses `REFGEN_REG_PWRDWN_CTRL5 = 0x80`, `BIT(0)`, enable value 1 and disable value 0. This is register/bit/value-equivalent to the vendor Kona implementation for the REFGEN block used by Khaje. The Mainline regulator binding accepts `qcom,sm8250-refgen-regulator` as a standalone compatible. The SPES node therefore uses a supported Mainline driver instead of copying the vendor-only compatible string.

The vendor proxy-consumer self-reference is not reproduced. Mainline's generic REFGEN driver does not implement that vendor proxy-consumer facility; the DSI Host is an explicit regulator consumer and enables/disables REFGEN through its `refgen` supply. Do not add the vendor proxy properties without a Mainline consumer model and evidence that the boot-time proxy vote is required.

## Build/module availability

- Build config: `CONFIG_REGULATOR_QCOM_REFGEN=m`.
- Built module exists: `build/spes/drivers/regulator/qcom-refgen-regulator.ko`.
- The module is present in `build/spes-module-staging/lib/modules/7.3.0-rc4-gc545b9e890d7-dirty/kernel/drivers/regulator/qcom-refgen-regulator.ko`.

The module being staged is necessary for this DT regulator provider to bind on a modular build. A final boot image/package must retain the module and its dependency metadata; this audit does not prove the target root filesystem will load it.

## Disposition

The current SPES REFGEN base, range, compatible, enable bit and DSI Host consumer wiring are consistent with the vendor implementation. No DTS or driver change is proposed from this comparison. Keep the node and DSI host disabled until the complete display power sequence is validated on hardware.

## Validation / safety

- Static source/DTS and existing module-artifact inspection only.
- No source/DT changes, no new build and no hardware test.
- MDSS/DSI0/DSI PHY remain disabled; FPC remains disabled.
- No flash, Recovery ZIP or installable release artifact.
