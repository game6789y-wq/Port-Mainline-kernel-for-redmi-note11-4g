# Stage 147 — SC8551 ADC fixed-point and error-handling draft

Date: 2026-11-14
Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Scope: vendor-source reference patch only; no production Mainline changes, no build, no device writes.

## Changes drafted

Draft patch: `kernel/patches/drafts/0003-sc8551-adc-fixed-point-and-error-checks.patch`

1. Removes the ARM64 NEON include and floating-point ADC scale table.
2. Replaces scale factors with integer fixed-point coefficients using a denominator of 100000 and `div_u64()`.
3. Checks the high-byte I2C read before attempting the low-byte read, and preserves either read error.
4. Rejects a NULL output pointer and invalid ADC channel with `-EINVAL`.
5. Corrects the ADC conversion-rate update mask from `SC8551_ADC_EN_MASK` (bit 7) to `SC8551_ADC_RATE_MASK` (bit 6).
6. Corrects the scan-channel boundary from `>` to `>=`.

## Conversion factors

| Channel | Vendor LSB | Fixed-point coefficient |
|---|---:|---:|
| IBUS | 1.5625 | 156250 / 100000 |
| VBUS | 3.75 | 375000 / 100000 |
| VAC | 5 | 500000 / 100000 |
| VOUT | 1.25 | 125000 / 100000 |
| VBAT | 1.2575 | 125750 / 100000 |
| IBAT | 3.125 | 312500 / 100000 |
| TBUS | 0.09766 | 9766 / 100000 |
| TBAT | 0.09766 | 9766 / 100000 |
| TDIE | 0.5 | 50000 / 100000 |

The conversion intentionally retains integer truncation, matching the vendor's cast-to-int behavior for non-negative ADC values. Before production use, validate each channel's register width, signedness, physical unit and boundary values against the SC8551 datasheet and hardware.

## Validation performed

- Generated a unified diff against the exact vendor driver source.
- `patch --dry-run -p1` passed against the workspace vendor tree.
- Verified the original vendor source remained unchanged (SHA-256: `0c1a9899c3271a219e2583ba67ac3fde60752935771a6b936a55aa06b73d650d`).
- No compile or build was run; the user's previous stop-build instruction remains active.

## Important limitations

- This is a draft against the vendor source path, not yet a Mainline driver patch.
- It does not implement power-supply registration, protections, IRQ handling, PM, shutdown, or DT parsing.
- It does not enable the SC8551 node in Mainline DTS.
- Do not apply to a production tree until datasheet cross-check, unit tests, code review and build validation are completed.
- SC8551 remains the intended charge-pump controller; MAX77729 remains a separate companion device.
