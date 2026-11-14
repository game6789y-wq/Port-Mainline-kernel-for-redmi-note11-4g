# Stage 149 — SC8551 Mainline Driver Implementation Plan

Target: Xiaomi Redmi Note 11 4G (SPES / Qualcomm SM6225)
Reference: Vendor `sc8551_charger.c`, Mainline read-only `sc8551-id.c`
Scope: implementation architecture and safety boundary. No Mainline charging-control source or DTS was changed in this stage.

## Existing Mainline state

- `drivers/power/supply/sc8551-id.c` only reads register 0x13 using regmap and accepts SC8551 ID 0x00 / SC8551A ID 0x51.
- Its compatible is `sc,sc8551-id-only`; it is deliberately not compatible with the live Vendor SPES node `sc,sc8551-standalone`.
- Kconfig `CONFIG_CHARGER_SC8551_ID_ONLY` explicitly describes read-only identification and must not be presented as charging support.
- The SPES Vendor DTS has SC8551 at I2C 0x65, IRQ GPIO84, and MAX77729 at I2C 0x66. Keep the two devices separate.

## Vendor implementation hazards to avoid

1. Vendor driver includes architecture-specific NEON/FPU use for ADC scaling. Mainline implementation must use integer fixed-point math only.
2. Vendor charger Power Supply descriptor exposes Vendor-only `POWER_SUPPLY_PROP_SC_*` properties. These cannot be copied into Mainline. Use standard properties where semantics match, and a documented, minimal ABI only where necessary.
3. Vendor sysfs `registers` attribute is mode 0660 and permits arbitrary writes to registers 0x00–0x31. Do not port this interface; it bypasses safety policy and protection sequencing.
4. Vendor IRQ handler currently records a pending flag but the alarm/fault decoding calls are compiled out. A Mainline IRQ thread must read/ack status with correct clear-on-read semantics, preserve I2C errors, update state, and notify the power_supply only after successful state refresh.
5. Vendor alarm/fault readers reuse `ret` across multiple reads and can lose earlier errors. Mainline must check each read independently and avoid publishing partially refreshed status as authoritative.
6. Vendor probe manually unregisters a devm-registered power_supply on error and manually frees devm-allocated state. Mainline should use devm ownership consistently and avoid double-unregister/free.
7. Vendor `remove()` and shutdown paths disable ADC but do not define a complete charge-safe state transition. Mainline teardown must be designed from the SC8551 datasheet and board topology, not copied mechanically.
8. Vendor suspend/resume uses custom IRQ gating and assumes a valid client IRQ. Mainline must support no-IRQ configurations safely, balance wake enable/disable, and use appropriate threaded IRQ / PM wake semantics.
9. Vendor `sc8551_set_present()` ignores the result of device initialization and always returns success. Any future presence-driven initialization must propagate errors and must not claim charging readiness after partial setup.
10. Vendor `sc8551_init_adc()`, `sc8551_init_regulation()`, and `sc8551_init_device()` contain unchecked register operations. Fail-fast handling is required throughout the initialization graph, not only in protection setup.

## Proposed Mainline structure

- A new `drivers/power/supply/sc8551-charger.c` driver using I2C + regmap.
- Keep the read-only ID driver as a temporary diagnostic only until the full driver is ready; avoid two drivers matching the same I2C client. The final DT must bind exactly one driver to `sc,sc8551-standalone`.
- A dedicated binding for `sc,sc8551-standalone` documenting the verified SPES threshold units, optional IRQ, role, sense resistor and thermal property representation.
- `devm_regmap_init_i2c()` with a reviewed register access policy; volatile/precious/clear-on-read status registers must not be cached.
- Parse and range-check configuration before any register writes. Resolve the two thermal disable properties explicitly; the current Vendor DTS uses numeric cells `<0>` while the Vendor driver treats property presence as true.
- Identify silicon and revision before selecting register quirks. Reject unsupported IDs/revisions.
- Run a strict, ordered initialization state machine: reset and wait; configure watchdog/timing/sense resistor; program protection enables and thresholds; configure ADC; configure interrupt masks; configure regulation; verify critical register readback where safe. Stop and return the first error.
- Keep charging/conversion disabled until protection setup and required readback complete. Do not infer that a successful I2C write means the requested protection mode is active without a datasheet-supported readback.
- Expose the SC8551 charge-pump as a power_supply with only defensible standard properties and correct micro-unit conversions. Do not invent battery measurements when the chip reports bus/charge-pump measurements.
- Use a threaded IRQ, a mutex-protected cached state, explicit error tracking and `power_supply_changed()` after a complete successful status update.
- No writable debug register interface. If diagnostics are needed, use read-only debugfs only when safely gated and not part of the production ABI.
- Add shutdown and PM only after determining the hardware's required safe state and wake requirements.

## Required evidence before implementation is considered safe

- SC8551 / SC8551A datasheet register map and threshold encoding, including reset values, protection enable polarity, clear-on-read status and ADC scaling.
- SPES board schematic or trustworthy vendor DTS/driver behavior confirming SC8551 standalone role, sense resistor, GPIO84 polarity/trigger, charge-pump topology and whether thermal thresholds are active.
- Confirmation of all threshold units and the meaning of Vendor DTS thermal numeric values.
- Compile with W=1, sparse where practical, targeted KUnit or mocked regmap tests for threshold conversion, error propagation and clear-on-read state handling.
- Hardware test with a current-limited supply and battery emulator / controlled test setup before enabling charging on a phone.

## Packaging consequence

The current build helper enables only `CONFIG_CHARGER_SC8551_ID_ONLY=m`. A flashable package must not be produced from this state as a charging-capable kernel. The full driver, final DT binding and SPES node must be reviewed and built together first. The workspace also contains no stock boot/vendor_boot/recovery image or AnyKernel installer at this point, so the final installer format and safe rollback path remain unverified.

No source changes, build, hardware test or flash occurred in Stage 149.