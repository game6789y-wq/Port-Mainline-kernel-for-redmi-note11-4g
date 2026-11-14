# Stage 148 — SC8551 Protection Initialization Audit

Target: Xiaomi Redmi Note 11 4G (SPES / Qualcomm SM6225)
Scope: static review of the Vendor SC8551 protection configuration path. No source file was modified or applied in this stage.

## Confirmed findings

1. `sc8551_init_protection()` performs a sequence of safety-critical register operations: battery OVP/OCP enables and alarms, battery UCP alarm, bus OVP/OCP and alarms, battery/bus thermal enables, and battery/bus/die/AC OVP thresholds.
2. The function overwrites `ret` after each operation, logs failures, continues with later writes, and unconditionally returns 0. An early I2C failure can therefore be hidden by a later successful operation.
3. `sc8551_init_device()` ignores the return from `sc8551_init_protection()` and also ignores return values from reset, watchdog, soft-start timeout, sense-resistor, ADC, interrupt-source, regulation and optional VBUS-range setup. It unconditionally returns 0.
4. The SPES Vendor DTS contains:
   - `sc,sc8551,bat-therm-disable = <0>`
   - `sc,sc8551,bus-therm-disable = <0>`
   The Vendor parser reads both with `of_property_read_bool()`. For OF boolean properties, presence means true; the encoded cell value is not read. Thus the current DTS encoding and parser semantics conflict. The intended enabled/disabled state must be confirmed against the original vendor device behavior and SC8551 register defaults before changing either side.
5. The protection thresholds currently encoded for SPES include battery OVP 4525mV, battery OVP alarm 4400mV, battery OCP 8000mA, battery OCP alarm 7500mA, bus OVP 12000mV, bus OVP alarm 11000mV, bus OCP 3750mA, bus OCP alarm 3500mA, battery UCP alarm 2000mA, battery/bus thermal threshold 21, die thermal threshold 125 and AC OVP selector 17. These are Vendor DTS values, not independently validated datasheet limits.
6. The Vendor setter helpers return I2C/update errors, so the primary defect is failure propagation in the initialization call chain rather than lack of error information at each setter.

## Mainline port requirements

- Preserve SC8551 as the charging-control IC. MAX77729 remains a separate companion device and must not be substituted for SC8551.
- Convert initialization into a fail-fast sequence: stop at the first failed safety-critical register operation and return the original negative errno to probe.
- Propagate failures from reset, watchdog, timing, sense-resistor, protection, ADC, interrupt and regulation initialization. Do not report a successful probe after partial safety configuration.
- Avoid blindly rolling back protection bits after an I2C failure: the bus state is unknown. Keep the device unavailable and report the failing register/operation.
- Resolve the thermal property representation explicitly. Prefer documented boolean properties with no value cells, or parse a defined u32 value if the original binding requires numeric 0/1. Do not silently reinterpret the existing DTS.
- Validate every threshold range and encoding against the SC8551 datasheet/register definitions before porting; do not assume Vendor comments or units are authoritative.
- Keep charging disabled until required protection configuration has completed successfully. Do not enable charging as a side effect of this audit.
- Expose standard Linux Power Supply properties only after the driver state model and units are reviewed. Vendor-only property ABI must not be copied blindly.

## Build and packaging status observed during Stage 148

- A new `Image dtbs` build was observed in progress at 14:39 UTC on 2026-11-14, with the build log `logs/spes-mainline-build.log`.
- The process was no longer present on the subsequent check, while the log ended during compilation of BPF/MM objects and had no final success/failure marker. This run is **incomplete / unverified**; it must not be counted as a successful build.
- The pre-existing Image and DTB timestamps predate this run; they are not evidence that this run completed.
- No Recovery ZIP or AnyKernel-style installer exists in the inspected workspace at this stage.
- No boot image, recovery ramdisk integration, installer script, partition backup/restore test, or custom-recovery installation test has been verified.

## Validation boundary

Static source inspection only. No patch applied, no driver compiled in this stage, no hardware I2C test, no charging test, no flashing and no release. The ADC draft from Stage 147 remains separate and unapplied to Mainline.

## Next work

1. Build a reviewed SC8551 Mainline driver design around fail-fast probe and standard Power Supply ABI.
2. Resolve thermal DT semantics from authoritative SPES behavior before changing DTS.
3. Implement and compile the charging driver only after the safety-critical register model is reviewed.
4. Re-run a clean source-matched Image/modules/DTB build and record explicit exit status and hashes.
5. Prepare a recovery installer only after confirming the exact boot image format, partition layout, recovery compatibility, module strategy and rollback path.