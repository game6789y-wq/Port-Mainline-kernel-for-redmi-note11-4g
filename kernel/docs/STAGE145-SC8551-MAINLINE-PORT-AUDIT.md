# Stage 145 — SC8551 full charger driver port audit

## Scope and safety

This stage audits the SPES vendor SC8551 driver against the current SM6225 mainline tree. It does not start a build, enable the charger DT node, write to charger registers, flash a device, or publish a kernel image. The existing read-only `sc8551-id` driver remains read-only until a reviewed full driver is ready.

The intended hardware arrangement is unchanged: MAX77729 remains on QUP SE1 I2C at `0x66` for its existing USB-C/MUIC/fuel-gauge functions; the separate SC8551 charge-pump is on the same controller at `0x65`, with GPIO84 interrupt, as described by the leading SPES vendor DTS. Do not apply the sibling SPES-SM5602/SPESN address `0x66` to this SPES board.

## Source inventory

- Vendor implementation: `src/vendor-sm6225/drivers/power/supply/nopmi/sc8551_charger.c` (2,323 lines).
- Vendor register definitions: `src/vendor-sm6225/drivers/power/supply/nopmi/sc8551_reg.h` (722 lines).
- Vendor DT node: `src/vendor-sm6225/arch/arm64/boot/dts/vendor/qcom/spes.dtsi`, `sc8551-charger@65`, compatible `sc,sc8551-standalone`, I2C address `0x65`, GPIO84 IRQ, sense resistor 5 mΩ, and the protection thresholds.
- Mainline currently has only `drivers/power/supply/sc8551-id.c`, compatible `sc,sc8551-id-only`; it reads register `0x13` and intentionally performs no writes.
- Mainline SPES DTS currently enables MAX77729 at `&i2c1`/`0x66` and deliberately omits SC8551 pending a complete driver and binding.

## Confirmed porting blockers

1. **Power-supply ABI mismatch.** Vendor driver uses private `POWER_SUPPLY_PROP_SC_*` enum values (battery/VBUS presence, SC ADC channels, alarm/fault and chip vendor). These enum additions exist only in the vendor `include/linux/power_supply.h`; mainline does not define them. Vendor `pd_policy_manager.c` and SM5602 fuel-gauge code consume some of these properties. Do not copy vendor enum additions into the global mainline power-supply ABI. Design a mainline-facing standard property set and decide separately whether a dedicated interface (IIO or another subsystem) is needed for charger-specific telemetry.

2. **ARM64 NEON API mismatch and floating point.** Vendor code includes `<asm/neon.h>`, calls the legacy no-argument `kernel_neon_begin()`/`kernel_neon_end()`, and multiplies ADC values by `float` LSB constants. This mainline tree's ARM64 declaration requires `kernel_neon_begin(struct user_fpsimd_state *)`; the normal driver port should remove floating point and NEON entirely. Use integer/fixed-point conversion with documented units and rounding.

3. **Error handling in vendor initialization is unsafe.** `sc8551_init_protection()` overwrites each return code and always returns zero, while `sc8551_init_adc()`, `sc8551_init_regulation()`, and `sc8551_init_device()` also ignore several register-write failures. A failed safety-threshold write must fail probe rather than report a working charger. The port must propagate the first error and unwind safely.

4. **ADC read correctness.** `sc8551_get_adc_data()` overwrites the first I2C read result with the second read result, so failure reading the high byte can be hidden. Invalid channel handling returns success with no valid sample. Both reads and the channel range need strict error checks. The vendor `sc8551_set_adc_scanrate()` also appears to pass `SC8551_ADC_EN_MASK` instead of the rate mask; verify register definitions and correct it before porting.

5. **Power-supply lifetime.** Vendor code uses `devm_power_supply_register()` but also calls `power_supply_unregister()` explicitly in remove/error paths. The managed registration must not be unregistered twice. Use managed cleanup consistently or switch to a non-managed registration with one explicit unregister path.

6. **Probe/API modernization.** Vendor I2C probe takes the legacy `(client, id)` form and manually calls `of_match_node()`. Port to the I2C probe signature and match-data pattern supported by this mainline tree, handle missing OF nodes safely, and remove manual `devm_kfree()`/mutex teardown where managed allocation already owns lifetime.

7. **IRQ and suspend state.** The vendor threaded IRQ handler currently only marks state; its suspend/resume bookkeeping and IRQ wake handling need a concurrency review. Ensure the handler does not deadlock against resume, only enable an IRQ that was disabled by this driver, and cleanly balance wake enablement. Do not claim alarm/fault reporting is operational until it is implemented and tested.

8. **Shutdown behavior.** Vendor shutdown only disables ADC, not charging. A safe mainline shutdown policy must be reviewed against the charge-pump role and system power path; do not blindly turn off charge or write registers without checking the hardware design and expected poweroff sequence.

## Hardware / Device Tree constraints

- SPES (leading variant): SC8551 is at `0x65`, GPIO84 IRQ, `sc,sc8551-standalone`.
- MAX77729 remains at `0x66`; no address collision on this board.
- SPES-SM5602 and SPESN siblings place SC8551 at `0x66`; those DTS files are not interchangeable with SPES.
- Preserve the vendor protection values only as source evidence; independently validate units, register encoding, and safety limits before enabling writes.
- The full driver binding must describe the compatible, reg, interrupt, pinctrl and all consumed threshold properties. Keep the node disabled/absent until driver and binding review passes.

## Port plan

1. Split register definitions from vendor-only platform data; retain only documented SC8551/SC8551A register definitions and license provenance.
2. Implement a small mainline I2C driver using regmap or checked SMBus operations, with exact device-ID validation and no implicit register writes before configuration is validated.
3. Add robust DT parsing and range checks for every protection threshold; reject missing or out-of-range values.
4. Convert ADC scaling to integer math and standard Linux units; propagate both-byte read failures.
5. Implement power-supply properties that exist in mainline; avoid private global enum additions. Defer proprietary PD-policy integration until a mainline consumer interface is designed.
6. Make initialization transactional: configure protection first, verify each write/readback where supported, then enable ADC/interrupts; unwind on any error.
7. Correct IRQ, suspend/resume, remove and shutdown lifetimes; use devm resources consistently.
8. Add `CHARGER_SC8551` Kconfig/Makefile integration and a DT schema binding; retain the read-only ID driver only as a temporary fallback, not a second driver bound to the same node.
9. Run static checks and targeted W=1 builds only after the user authorizes resuming builds; then validate on real hardware before enabling the DT node or publishing a release.

## Current status

- Static source audit: completed for the identified areas above.
- Full driver port: not started.
- Mainline DTS SC8551 node: not enabled.
- Build: stopped by user; no active build process was found during this audit. No build was restarted.
- Hardware validation / flashing / release: not performed.
[exit status 0]