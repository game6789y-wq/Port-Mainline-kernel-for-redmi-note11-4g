# Stage 166 — FocalTech Suspend/Resume and Power Sequencing Audit

Date: 2026-11-15
Workspace: `/workspace/ubuntu-spes-mainline`
Method: read-only comparison of vendor and current mainline candidate.
No source edits or builds.

## 1. Vendor runtime PM behavior

The vendor configuration selects `_FT3418 = 0x34180481`. This does not set the incell flag, so the vendor code follows its non-incell power-management path.

When gesture mode is not active, vendor suspend:
1. Disables the touchscreen IRQ.
2. Writes sleep mode to register `0xA5` with value `0x03`.
3. Drives reset low (asserted).
4. Waits 1 ms.
5. Drives AVDD enable GPIO low (off).
6. Disables the `vcc_i2c` regulator.
7. Releases all fingers and marks the device suspended.

Vendor resume:
1. Re-enables AVDD and `vcc_i2c`.
2. Toggles reset low for 1 ms then high (released).
3. Waits the requested 200 ms reset delay.
4. Waits for the touchscreen to become valid.
5. Recovers extended modes.
6. Enables IRQ when gesture mode is not active.
7. Clears suspended state.

The configured vendor build has `FTS_GESTURE_EN = 0`, so gesture wake is not enabled by this configuration. ESD checking is also disabled in the inspected config.

## 2. Current mainline candidate behavior

The current `focaltech-ft3418.c` candidate:
- Suspend disables the IRQ, releases all contacts, and marks suspended.
- Resume releases all contacts, clears suspended, and re-enables IRQ.
- It does not write the controller sleep register.
- It does not assert reset, disable AVDD, disable `vcc_i2c`, or select a suspend pinctrl state.
- Probe performs a reset/power-up sequence and waits 200 ms before reading ID.

This is a significant PM behavior difference from the active vendor driver. It may be a deliberate conservative first-pass choice, but it leaves rails on during suspend and does not reproduce vendor sleep/wake behavior.

## 3. Recommended design direction

Before enabling this driver in a device tree:
1. Add a reviewed PM state machine that can stop/drain IRQ processing before power transitions.
2. On suspend, release contacts, send sleep command only if the exact controller protocol is confirmed, assert reset, disable AVDD and I/O rail in a controlled order, and select suspend pinctrl state.
3. On resume, select active pinctrl, enable AVDD and I/O supply, release reset with the verified timing, wait for readiness, then enable IRQ.
4. Propagate every GPIO/regulator/I2C error and roll back partially completed power transitions.
5. Keep gesture wake disabled unless a separate validated implementation and wake IRQ policy are available.
6. Do not copy the vendor driver's ignored-error behavior; use managed resources and balanced regulator enables.

The precise rail sequencing and reset timing must be validated against hardware documentation or observed, known-good vendor behavior before any patch is applied. The vendor source is a reference, not proof that every board revision uses identical timings.

## 4. Device-tree implications

The candidate binding currently describes:
- active-low reset GPIO
- optional active-high AVDD GPIO
- `vcc_i2c-supply`
- interrupt
- touch coordinate properties

The vendor DTS also declares three pinctrl states: `pmx_ts_active`, `pmx_ts_suspend`, and `pmx_ts_release`. The current mainline driver does not explicitly select these states. The final binding/driver should decide whether to model active/suspend states and use the pinctrl framework consistently.

## 5. Safety

- Read-only source review only.
- No source edits, build, live register access, firmware update, flashing, partition writes, or ZIP creation.
- Previous explicit build stop remains active.
- FPC remains disabled; SC8551 and MAX77729 remain preserved.

Status: Mainline candidate currently lacks the vendor-equivalent suspend power-down/resume sequence. PM integration is a required blocker before enabling the touchscreen in a flashable build.
