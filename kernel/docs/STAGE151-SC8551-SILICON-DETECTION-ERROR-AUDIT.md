# Stage 151 — SC8551 Silicon Detection Error Audit

Target: Xiaomi Redmi Note 11 4G (SPES / Qualcomm SM6225)
Reference: Vendor `sc8551_charger.c` and `sc8551_reg.h`
Scope: static analysis of chip identity and probe gating. No source changes.

## Confirmed Vendor detection behavior

The Vendor driver reads register 0x13 into a local `u8 data`. On a successful read it assigns the masked part number and sets `chip_vendor = SC8551` only when the full byte equals `SC8551_DEVICE_ID (0x00)` or `SC8551A_DEVICE_ID (0x51)`.

However:
- If the register read succeeds with any other value, `sc8551_detect_device()` still returns 0. Probe then continues toward configuration writes despite an unsupported ID.
- If the register read fails, the function still prints `data` in the error log even though the local variable may be uninitialized.
- Probe sets `sc->is_sc8551 = true` before calling detection, rather than deriving capabilities from a validated ID/revision.
- The current code does not establish a validated revision-specific register map before applying configuration.

The Mainline read-only identification driver is safer in this narrow respect: it rejects IDs other than 0x00 and 0x51 and does not perform configuration writes.

## Required Mainline behavior

1. Initialize the ID variable to a known value, but never use it as a substitute for checking the I2C return.
2. Return the original I2C errno immediately if register 0x13 cannot be read.
3. Accept only explicitly supported full-byte IDs and revisions. Unknown values must return `-ENODEV` before any configuration write.
4. Keep SC8551 and SC8551A capability data separate unless an authoritative register specification proves equivalence.
5. Select any silicon-specific quirks only after successful identification.
6. Log the actual ID only after a successful read; do not print uninitialized or stale data.
7. Do not set a generic `is_sc8551` flag before the silicon has been validated.

## Evidence boundary

This audit confirms a Vendor source defect, not the actual silicon fitted to the user's phone. SPES hardware ID has not been read in this session. Publicly located Southchip documentation is only an SC8551A one-page draft, not a complete register-level specification. No charge-control writes, source edits, build, hardware test or flash occurred.