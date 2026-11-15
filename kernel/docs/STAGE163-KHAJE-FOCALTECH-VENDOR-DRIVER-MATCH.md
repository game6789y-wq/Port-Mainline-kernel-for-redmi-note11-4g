# Stage 163 — Khaje FocalTech Vendor Driver Match and Stage 161 Correction

Date: 2026-11-15
Workspace inspected read-only: `/workspace/ubuntu-spes-mainline`
No source files modified. No build run.

## 1. Correction to Stage 161

Stage 161's initial source scan did not inspect the complete `ft3418_i2c` vendor driver directory and incorrectly concluded that no matching vendor FocalTech driver source had been identified.

A deeper read-only inspection found the exact matching driver:
`src/vendor-sm6225/drivers/input/touchscreen/ft3418_i2c/focaltech_core.c`

The driver defines:
- `FTS_DRIVER_NAME = "fts_ts"`
- OF compatible `focaltech,fts`
- I2C driver name `fts_ts`

This exactly matches the runtime inventory from Stage 162:
- I2C client `1-0038`
- name `fts`
- OF compatible `focaltech,fts`
- bound driver `fts_ts`

This establishes the vendor driver family and its binding for the active touchscreen. It does not by itself prove the exact silicon revision or that the existing mainline FT3418 implementation is compatible.

## 2. Khaje vendor DTS match

File:
`src/vendor-sm6225/arch/arm64/boot/dts/vendor/qcom/khaje-idp.dtsi`

The Khaje DTS defines the touchscreen under `&qupv3_se2_i2c`:
- `status = "ok"`
- `compatible = "focaltech,fts"`
- `reg = <0x38>`
- `vcc_i2c-supply = <&L9A>`
- `interrupts = <89 2>`
- `focaltech,avdd-gpio = <&tlmm 98 0>`
- `focaltech,reset-gpio = <&tlmm 86 1>`
- `focaltech,irq-gpio = <&tlmm 80 2>`
- `focaltech,max-touch-number = <10>`
- `focaltech,display-coords = <0 0 1080 2400>`
- `panel1 = <&dsi_k7_38_0c_0a_video>`
- `panel2 = <&dsi_k7_38_0c_0b_video>`
- pinctrl states: active, suspend, release

The DTS also defines the generic `xiaomi-touch` node separately.

## 3. Mainline compatibility gap

The existing mainline source previously inspected:
`drivers/input/touchscreen/focaltech-ft3418.c`

Its OF match table contains `focaltech,ft3418`, not `focaltech,fts`. Therefore, the mainline driver does not currently match the runtime compatible string without a reviewed compatibility change.

Do not simply add `focaltech,fts` to the mainline match table yet. The vendor source directory name and an upgrade helper filename mentioning FT5452 are not conclusive proof of the exact silicon. The vendor driver performs chip-ID discovery through registers; exact accepted IDs and initialization sequence need review before any port decision.

## 4. Next static review

Review:
1. FocalTech vendor chip-ID tables and accepted silicon IDs.
2. Probe sequence and firmware handling.
3. GPIO/regulator/pinctrl acquisition and power sequencing.
4. Touch event format, multitouch reporting, suspend/resume, gesture and ESD behavior.
5. Existing mainline driver support versus the vendor protocol.

Do not perform live register reads or firmware upgrades on the phone for this identification step.

## 5. Safety

- Read-only source inspection only.
- No source edits, build, flash, partition writes, or installer ZIP.
- Previous explicit build stop remains active.
- Keep FPC disabled in mainline; preserve SC8551 + MAX77729.

Status: Exact vendor driver binding for the active FocalTech touchscreen is found. Exact silicon ID and mainline-port feasibility remain under static review.
