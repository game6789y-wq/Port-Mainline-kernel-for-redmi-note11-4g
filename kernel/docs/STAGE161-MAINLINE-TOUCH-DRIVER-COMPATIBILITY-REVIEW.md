# Stage 161 — Mainline Touch Driver Compatibility Review

Date: 2026-11-15
Workspace inspected read-only: `/workspace/ubuntu-spes-mainline`
Kernel source: `src/linux-sm6225-mainline`
No source files were modified and no build was run.

## 1. Existing mainline touchscreen drivers

Workspace contains:
- `drivers/input/touchscreen/focaltech-ft3418.c`
- `drivers/input/touchscreen/novatek-nvt-ts.c`
- No Synaptics TCM touchscreen driver source was found in the touchscreen directory.

The existing config reports:
- `CONFIG_TOUCHSCREEN_FOCALTECH_FT3418=m`
- `CONFIG_TOUCHSCREEN_NOVATEK_NVT_TS` is not set
- No Synaptics TCM driver selected/found in the inspected directory.
- A `focaltech-ft3418.ko` and object files exist in the build tree. Their presence does not prove the running phone uses FT3418 or that this module matches the current source/configuration.

## 2. Runtime compatible strings versus driver match tables

Runtime device-tree candidates from Stage 160:
- FocalTech: `focaltech,fts`
- Novatek: `novatek,NVT-ts`
- Synaptics: `synaptics,tcm-i2c`

Existing mainline driver OF match tables:
- FocalTech FT3418 driver matches only `focaltech,ft3418`.
- Novatek driver matches only `novatek,nt11205-ts` and `novatek,nt36672a-ts`.
- No Synaptics TCM driver source was found in the inspected directory.

Therefore, none of the runtime compatible strings exactly matches the inspected mainline drivers' OF match tables. The project DTS currently describes a FocalTech FT3418 candidate as `focaltech,ft3418`, but this is not yet confirmed to be the active hardware. Do not change compatibles to force binding without identifying the actual controller and verifying its ID/protocol.

## 3. Current SPES DTS state observed

The existing `sm6225-xiaomi-spes.dtsi`:
- Describes an FT3418 candidate at I2C address 0x38, with GPIO-based IRQ/reset resources.
- Keeps the FPC1020 node `status = "disabled"`.
- Keeps the candidate K7 38-0C-0A panel disabled.
- Keeps MDSS/DSI/DSI PHY disabled pending verification.
- Contains a comment that none of these nodes has been validated by booting this DT on hardware.

This aligns with the project's safety rule not to enable unverified display/fingerprint paths.

## 4. Findings and blockers

1. Actual touchscreen controller remains unidentified. Three vendor alternatives in the live DT do not map to the current mainline driver matches.
2. FocalTech module being configured as `m` does not resolve the runtime compatible mismatch.
3. Novatek source exists but is disabled in the inspected .config and does not match `novatek,NVT-ts`.
4. Synaptics TCM driver is absent from the inspected mainline touchscreen directory.
5. Panel naming mismatch remains: runtime command line says `...0a...`, live tree path shows `...0b...`, and the in-tree candidate node is disabled.

## 5. Next evidence needed

From the running phone, collect read-only:
- `/sys/bus/i2c/devices/*` entries and their `name`, `modalias`, `driver`, `uevent` files for buses/addresses associated with the touchscreen candidates.
- Kernel log lines for `novatek`, `focaltech`, `synaptics`, `touchscreen`, `fts`, `nvt`, and `tcm`.
- Runtime status and selected panel properties for both the `0a` and `0b` panel nodes.

Do not read/write controller registers directly and do not reset or power-cycle devices for this identification step.

## 6. Safety

- Static source/config inspection only.
- No source edits, build, flash, partition writes, or installer ZIP.
- Previous explicit build stop remains active.
- FPC remains disabled; SC8551 + MAX77729 roles remain unchanged.

Status: Mainline driver source compatibility gaps identified. No touchscreen controller or panel variant is yet safe to enable.
