# Stage 167 — Khaje FocalTech IRQ GPIO Discrepancy and Mainline DTS Audit

Date: 2026-11-15
Workspace: `/workspace/ubuntu-spes-mainline`
Method: read-only comparison of Khaje vendor DTS, vendor driver, and current experimental mainline SPES DTS.
No source edits or builds.

## 1. Vendor DTS contains two different IRQ GPIO numbers

In `src/vendor-sm6225/arch/arm64/boot/dts/vendor/qcom/khaje-idp.dtsi`, the FocalTech node has:
- `interrupt-parent = <&tlmm>`
- `interrupts = <89 2>`
- `focaltech,irq-gpio = <&tlmm 80 2>`

These are inconsistent: the generic I2C client IRQ property points to TLMM GPIO89, while the vendor driver's own IRQ GPIO property points to GPIO80.

## 2. Vendor driver actually consumes GPIO80

The vendor driver's `fts_parse_dt()` reads `focaltech,irq-gpio` into `pdata->irq_gpio`.
Then `fts_gpio_configure()` requests that GPIO and configures it as input.
Finally, `fts_irq_registration()` calls `gpio_to_irq(pdata->irq_gpio)` and registers the threaded interrupt.

Therefore the active vendor driver uses GPIO80 for its IRQ and does not use `client->irq` from the separate `interrupts = <89 2>` property for registration.

This is strong source evidence for GPIO80 as the downstream driver's intended interrupt line, but the live electrical line should still be confirmed before a flashable image is enabled.

## 3. Mainline experimental DTS choice

The existing experimental `sm6225-xiaomi-spes.dtsi` touchscreen node is under `&i2c2`, which maps to controller address `0x4a88000`. This matches the runtime touchscreen I2C bus path `/soc/i2c@4a88000` and the user-provided I2C client `1-0038`.

The current mainline node uses:
- `interrupts = <80 IRQ_TYPE_EDGE_FALLING>`
- reset GPIO86 active-low
- AVDD GPIO98 active-high
- `vcc_i2c-supply = <&pm6125_l9>`
- coordinates 1080 x 2400

Using GPIO80 in the mainline `interrupts` property aligns with the GPIO actually consumed by the vendor driver, unlike the vendor DTS's separate generic IRQ property.

## 4. Missing pinctrl state in mainline candidate

The vendor node references:
- active: `ts_int_active`, `ts_reset_active`, `ts_avdd`
- suspend: `ts_int_suspend`, `ts_reset_suspend`
- release: `ts_release`

Vendor Khaje pinctrl inherits Bengal touch pin definitions:
- GPIO80 active input with pull-up and 8 mA drive
- GPIO98 AVDD output-high with pull-up and 8 mA drive
- GPIO86 reset active with pull-up and 8 mA drive
- suspend/release configurations for the touch pins

The current experimental mainline SPES DTS defines no corresponding FocalTech pinctrl states and the touchscreen node has no `pinctrl-names` or `pinctrl-0`. The mainline driver also does not explicitly select active/suspend/release states.

This is a hardware-integration gap. GPIO descriptor acquisition alone does not recreate the vendor's pin electrical configuration. Before enabling touch, define and validate appropriate Khaje TLMM states for GPIO80, GPIO86, and GPIO98, and coordinate them with the PM sequence.

## 5. Required resolution before touch enable

1. Preserve GPIO80 as the leading IRQ candidate because it is what the bound vendor driver actually requests.
2. Keep the vendor DTS GPIO89 discrepancy explicitly documented; do not copy GPIO89 into mainline without new hardware evidence.
3. Confirm the live interrupt mapping using existing read-only sysfs/proc interrupt information, not by toggling GPIOs.
4. Add reviewed mainline pinctrl active/suspend states only after matching the correct Khaje pin table and verifying no conflict with other consumers.
5. Keep the touchscreen node disabled until IRQ and pinctrl are resolved.

## 6. Safety

- Read-only inspection and documentation only.
- No source modifications, builds, live GPIO toggles, register reads, firmware update, flashing, partition writes, or ZIP creation.
- Previous explicit build stop remains active.
- FPC remains disabled; SC8551 and MAX77729 remain preserved.

Status: Mainline I2C controller mapping matches runtime. GPIO80 is the vendor driver's actual IRQ input; GPIO89 is an unused/conflicting generic DT IRQ declaration. Mainline pinctrl states are still missing and block safe touch enable.
