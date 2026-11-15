# Stage 165 — FocalTech FT3418 Protocol and Mainline Driver Gap Audit

Date: 2026-11-15
Workspace: `/workspace/ubuntu-spes-mainline`
Method: read-only comparison of vendor and mainline source, plus external Linux binding/driver references.
No source edits or builds.

## 1. Chip identity evidence — stronger, but not live silicon proof

Vendor configuration:
- `focaltech_config.h` selects `FTS_CHIP_TYPE = _FT3418`.
- `_FT3418` is defined as `0x34180481`.
- `focaltech_common.h` maps one chip entry:
  - firmware/runtime ID: `0x81:0x54`
  - ROM ID: `0x52:0x54`
  - PB ID: `0x00:0x00`
  - bootloader ID: `0x54:0x5c`
- Vendor ID registers are `0xA3` and `0x9F`.

The in-tree mainline `focaltech-ft3418.c` expects `0x81:0x54`, which agrees with the configured vendor firmware/runtime ID mapping. This is a meaningful source-level match and supports retaining an FT3418-specific driver candidate.

However, the device's actual ID has not been read from hardware in this investigation. Runtime driver binding only proves `fts_ts` is bound. Therefore the exact silicon/revision remains unconfirmed until there is a trustworthy existing boot log or an explicitly authorized, safe read-only diagnostic. Do not run a firmware upgrade or bootloader command.

## 2. Touch report layout comparison

Vendor constants in `focaltech_core.h`:
- Header length: 3 bytes
- Per-contact record: 6 bytes
- Maximum contacts: 10
- Total report length: 63 bytes
- Point count: byte 2, low nibble
- Event/X-high: byte 3 + 6*i
- X-low: byte 4 + 6*i
- Y-high/ID: byte 5 + 6*i
- Y-low: byte 6 + 6*i
- Pressure: byte 7 + 6*i
- Area: byte 8 + 6*i
- Valid contact IDs: 0–9; vendor parser stops when ID >= 0x0A.

The current mainline driver uses the same header size, six-byte record size, point-count byte, coordinate bitfields, event field, ID field, pressure and area positions. This is a strong protocol-layout match.

## 3. Mainline parser differences to resolve before enabling

The mainline implementation currently:
- Treats only contact ID `0x0f` as the end-of-record sentinel.
- Treats IDs 10–14 as invalid and releases all contacts.
- The vendor parser stops parsing for any ID >= 10 (`FTS_MAX_ID = 0x0A`).

This is a real behavior mismatch. It should be reviewed against the actual controller report convention; safest source-level alignment is to use the vendor's ID boundary semantics, while retaining strict bounds checks.

The mainline driver validates point count <= 10 but does not check consistency between point count and active DOWN/CONTACT records. Vendor parser explicitly rejects a DOWN/CONTACT event when point count is zero. Add equivalent malformed-frame validation in a reviewed patch.

The mainline driver otherwise follows the same six-byte event structure and reports ten multitouch slots. This is still static comparison, not proof of live touch functionality.

## 4. GPIO, regulator and interrupt mapping

Khaje DTS resources:
- Reset GPIO 86, active-low.
- AVDD enable GPIO 98, active-high.
- IRQ GPIO 80; interrupt specifier `<89 2>` (edge falling in the vendor driver configuration).
- I/O supply `vcc_i2c-supply = <&L9A>`.
- Pinctrl states: `pmx_ts_active`, `pmx_ts_suspend`, `pmx_ts_release`.

The mainline driver requests reset as logical asserted initially, sets AVDD low then high, enables `vcc_i2c`, releases reset, and waits 200 ms. This is directionally consistent with the vendor GPIO polarity and supply usage.

Before using this driver, DTS must correctly translate the legacy vendor GPIO and pinctrl resources into descriptor-based GPIOs, regulator supply, interrupt mapping, and pinctrl states. The mainline driver currently does not explicitly select the vendor's three named pinctrl states. No DTS changes were made.

## 5. Firmware update code must remain out of scope

The vendor tree registers an upgrade function named `upgrade_func_ft5452` and uses an FT5452-named upgrade routine even though the configured chip type is `_FT3418` and the runtime ID mapping is `0x81:0x54`.

This naming mismatch is not sufficient evidence that the physical controller is FT5452; it may reflect shared or reused upgrade code. Firmware update is not needed for a basic mainline input driver and must remain excluded. No firmware file was flashed or modified.

## 6. Upstream Linux reference comparison

External Linux references show:
- Older downstream FocalTech binding documentation uses the generic compatible `focaltech,fts` and describes the I2C, IRQ, reset, supply and display-coordinate properties.
- The newer upstream FocalTech FTS binding proposal used model-specific compatibles such as `focaltech,fts5452` and `focaltech,fts8719`, not a blanket claim that every `focaltech,fts` controller is compatible.
- Mainline EDT FT5x06 support includes selected FocalTech models, but model-specific compatible entries are not proof that this controller's report protocol or ID is supported.

Therefore, do not simply bind the generic runtime compatible to an unrelated upstream driver. Keep the custom FT3418 candidate isolated until exact hardware ID and report behavior are confirmed.

## 7. Recommended next static work

1. Review the mainline driver's parser and create a small proposed patch/diff for sentinel and malformed-frame handling only; do not apply it yet.
2. Review suspend/resume behavior and ensure reset/AVDD/I/O supply and pinctrl states are handled safely.
3. Review the device-tree binding schema against the actual Khaje DTS resources.
4. Keep FPC disabled and preserve SC8551 + MAX77729.
5. Continue to keep display/DSI disabled until separately validated.

## 8. Safety

- Read-only inspection and documentation only.
- No source modifications, builds, device register access, firmware update, flashing, partition writes, or ZIP creation.
- Previous explicit build stop remains active.

Status: FT3418 vendor configuration and report layout strongly align with the custom mainline driver. Exact live chip ID remains unverified. Two parser behavior gaps are identified for a proposed patch review.
