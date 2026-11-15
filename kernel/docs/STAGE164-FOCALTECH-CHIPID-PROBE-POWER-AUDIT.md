# Stage 164 — FocalTech Chip-ID, Probe and Power-Sequence Audit

Date: 2026-11-15
Workspace: `/workspace/ubuntu-spes-mainline`
Inspection was read-only; no build or source edits.

## 1. Vendor driver chip-ID mapping

Files:
- `src/vendor-sm6225/drivers/input/touchscreen/ft3418_i2c/focaltech_common.h`
- `src/vendor-sm6225/drivers/input/touchscreen/ft3418_i2c/focaltech_config.h`
- `src/vendor-sm6225/drivers/input/touchscreen/ft3418_i2c/focaltech_core.c`

Observed definitions:
- `FTS_CHIP_TYPE_MAPPING` contains one mapping entry with values `0x81, 0x54, 0x52, 0x54, 0x52, 0x00, 0x00, 0x54, 0x5C`.
- `focaltech_config.h` defines `_FT3418 = 0x34180481` and selects `FTS_CHIP_TYPE = _FT3418`.
- Upgrade helper source is named `focaltech_upgrade_ft3418.c`, but its function/comment identifies the FT5452 upgrade sequence.

These mixed naming/configuration clues do not prove the exact physical controller silicon or revision. The runtime output identifies the bound vendor driver, not the chip ID value. Do not infer the hardware part number from directory or file names.

## 2. Vendor probe and ID validation

The vendor probe sequence:
1. Allocates driver state and parses DT.
2. Creates workqueue and initializes locks.
3. Initializes I2C communication.
4. Initializes input device and report buffer.
5. Configures GPIOs.
6. Optionally initializes power source.
7. Resets the controller when configured as non-incell.
8. Reads firmware chip ID registers and maps the result to the configured chip table.
9. If firmware ID is invalid, may switch HID to standard I2C and read boot ID.
10. Registers sysfs/debug interfaces, gesture/ESD features, IRQ, and firmware-upgrade support.

The ID helper rejects zero IDs and returns `-ENODATA` if no mapping matches. This is useful evidence for a future safe mainline identification strategy, but no live register reads were performed.

## 3. Khaje DTS resource mapping

The Khaje vendor DTS node provides:
- I2C address 0x38
- I2C regulator supply `vcc_i2c-supply = <&L9A>`
- IRQ interrupt specifier `<89 2>`
- AVDD GPIO 98
- Reset GPIO 86
- IRQ GPIO 80
- Maximum 10 touches
- Coordinate bounds 0,0 through 1080,2400
- Panel references to both K7 38-0C-0A and K7 38-0C-0B variants
- Active, suspend, and release pinctrl states

The vendor driver parser reads display coordinates, reset/IRQ/AVDD GPIOs and maximum touch count. Its power code obtains regulator `vcc_i2c`, configures pinctrl and controls AVDD GPIO. The DTS and parser therefore provide concrete resources to map in a future mainline driver.

Caution: the vendor code uses legacy GPIO/regulator APIs and has error-handling patterns that must be reviewed rather than copied mechanically. The displayed source logs an error if DT parsing fails but continues probe entry; the power-init function can log a power-enable error and still return success. These require correction in any new mainline implementation.

## 4. Mainline port decision

- Confirmed active device: FocalTech-compatible controller, I2C 1-0038, bound to vendor `fts_ts`.
- Confirmed vendor compatible: `focaltech,fts`.
- Existing mainline driver inspected earlier matches `focaltech,ft3418`, so it does not currently match the vendor DT compatible.
- Exact silicon remains unknown; do not simply add a compatible alias to the existing mainline driver.
- A reviewed mainline port should use modern GPIO descriptors, regulator APIs, pinctrl, threaded IRQ, input multitouch APIs, runtime/system PM, and strict fail-fast error handling. Firmware update and vendor debug sysfs features should not be carried over by default.

## 5. Safety

- Static source inspection only.
- No source edits, builds, device register access, firmware upgrade, flashing, partition writes, or ZIP creation.
- Previous explicit build stop remains active.
- Keep FPC disabled; preserve SC8551 and MAX77729.

Status: Vendor driver match and DTS resource map are now understood. Physical controller ID and safe mainline implementation remain unresolved.
