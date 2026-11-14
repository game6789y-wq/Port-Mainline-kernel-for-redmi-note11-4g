# Stage 146 — SC8551 Vendor Driver Deep Review

Date: 2026-11-14
Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Scope: static source review only; no build, no device-tree enablement, no flash.

## Decision

Continue with SC8551 as the charge-pump controller. Keep MAX77729 for its existing Type-C / MUIC / fuel-gauge responsibilities. Do not replace SC8551 with MAX77729 and do not remove either device from the board description.

The SPES vendor DTS node is at I2C address 0x65, compatible `sc,sc8551-standalone`, IRQ GPIO84. The separate SM5602 and SPESN DTS variants use a different SC8551 address (0x66); those variant descriptions must not be copied into SPES.

## Source reviewed

- Vendor driver: `src/vendor-sm6225/drivers/power/supply/nopmi/sc8551_charger.c` (2,323 lines)
- Vendor register definitions: `src/vendor-sm6225/drivers/power/supply/nopmi/sc8551_reg.h`
- SPES DT: `src/vendor-sm6225/arch/arm64/boot/dts/vendor/qcom/spes.dtsi`
- Existing mainline file: `drivers/power/supply/sc8551-id.c` (read-only identification only)

## Confirmed defects / port blockers

1. **ADC read error is overwritten.** `sc8551_get_adc_data()` assigns `ret` from the high-byte read and immediately overwrites it with the low-byte read. A failed high-byte transaction can therefore be hidden. Invalid channel values also return success (0) without producing a valid result. The channel bound in `sc8551_set_adc_scan()` uses `>` instead of `>=`.
2. **Wrong ADC rate mask.** `sc8551_set_adc_scanrate()` updates `SC8551_ADC_EN_MASK` (bit 7) while the rate field is `SC8551_ADC_RATE_MASK` (bit 6). This can modify ADC enable rather than the conversion-rate bit.
3. **Protection initialization ignores failures.** `sc8551_init_protection()` overwrites `ret` repeatedly, logs failures, then always returns 0. `sc8551_init_adc()`, `sc8551_init_regulation()`, and `sc8551_init_device()` also ignore several register-write errors. A partially configured chip can be reported as successfully initialized.
4. **DT boolean semantics mismatch.** The vendor parser uses `of_property_read_bool()` for `sc,sc8551,bat-therm-disable` and `sc,sc8551,bus-therm-disable`. In SPES DTS these are written as `<0>`. Boolean-presence parsing treats a present property as true regardless of its cell value. The port must define and parse these properties consistently (prefer proper boolean presence flags or explicit u32 semantics) before relying on the thermal-protection configuration.
5. **Floating point / NEON use.** ADC scaling is represented by a float table and calculated inside `kernel_neon_begin()/end()`. Replace with documented fixed-point integer scaling and explicit units; do not carry kernel NEON use into the Mainline driver.
6. **Vendor-only Power Supply properties.** `POWER_SUPPLY_PROP_SC_*` properties are not standard upstream ABI. Map supported values to standard power-supply properties where semantics match; otherwise use a documented, reviewed interface rather than copying private enum values.
7. **Probe and teardown lifecycle.** The vendor driver manually unregisters a devm-registered power supply on some error/remove paths, creates a sysfs file without checking/removing it, and calls `enable_irq_wake()` without checking its result. Rework around devm ownership, managed sysfs groups, and balanced IRQ wake handling.
8. **IRQ / PM behavior is incomplete.** The threaded IRQ handler currently mostly marks state and does not publish decoded alarm/fault changes. Suspend/resume bookkeeping and wake handling need to be redesigned for Mainline semantics.
9. **Register debug write interface is unsafe for upstream.** The vendor writable `registers` sysfs node permits arbitrary register writes. Do not port this debug write ABI into a production driver.
10. **Device identification diagnostics.** `sc8551_detect_device()` logs `data` even when the I2C read fails; ensure no uninitialized value is logged in the new implementation.

## Port sequence

1. Build a clean Mainline driver around regmap and the I2C probe lifecycle; keep the existing ID-only driver unbound to the production node until the full driver is ready.
2. Implement checked register access and fixed-point ADC conversions first, with unit tests or host-side arithmetic checks for every channel.
3. Parse and validate DT thresholds, then program protections in a fail-fast order. Probe must fail if any mandatory OVP/OCP/thermal configuration write fails.
4. Add standard power-supply reporting and charge-enable control only after register semantics and safe defaults are verified.
5. Add IRQ alarm/fault decoding, suspend/resume, shutdown, and managed cleanup.
6. Add a binding and SPES DT compatible only after the driver is complete and reviewed. Keep the node disabled in the Mainline DTS until hardware validation is explicitly authorized.

## Safety / current state

- No Mainline source or DTS was changed in this stage.
- No build was started; the earlier user stop-build instruction remains in force.
- No charging-control writes were sent to hardware.
- No kernel was flashed and no release artifact was published.
- SC8551 remains the intended charge-pump controller; MAX77729 remains a separate companion device.
