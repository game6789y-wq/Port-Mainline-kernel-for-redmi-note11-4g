# Stage 140 — reproducible SPES build and module-staging script

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: build helper and config fragment updated, syntax-checked and executed successfully.

## Problem addressed

The previous `scripts/build-spes.sh` built only `Image dtbs`; it did not build modules or refresh module staging. Its config fragment also omitted several SPES-specific modules, including the K7 panel and custom FT3418/Max77729/SC8551 drivers. This allowed a stale staging tree to omit `panel-k7-38-0c-0a.ko` even though the module existed in the build output.

## Changes made

- Updated `scripts/build-spes.sh` to build `Image`, `modules`, and only the target `qcom/sm6225-xiaomi-spes.dtb` rather than every ARM64 DTB.
- Added checks for MSM DSI/7nm PHY, Qualcomm GLINK/RPM/SPMI providers, K7 panel, REFGEN, FT3418, MAX77729 core and SC8551 ID-only modules.
- Added an explicit guard that FPC1020 remains disabled.
- Added `modules_install` into the isolated `build/spes-module-staging` tree, cleaning only the current kernel-release staging directory, then running `depmod -b`.
- Added verification of K7, REFGEN and MSM module presence/OF aliases, K7/MSM dependency resolution with `modprobe --show-depends`, and zero FPC-named modules.
- Updated `refs/spes-android.config` to include the SPES-specific K7, REFGEN, FT3418, MAX77729 and SC8551 module options and explicitly keep FPC disabled.
- Added the script/config copies and usage guide to GitHub under `kernel/scripts/` and `kernel/config/`.

## Test performed

Executed the updated script in the Boxadd workspace. Result: exit status 0.

- `defconfig` + merge + `olddefconfig`: passed.
- `Image modules qcom/sm6225-xiaomi-spes.dtb`: passed.
- `modules_install`: passed.
- `depmod -b`: passed.
- K7, REFGEN and MSM module/alias/dependency checks: passed.
- Staged modules: 1,681 `.ko`.
- FPC-named modules: 0.
- Target DTB: MDSS, DSI0, DSI PHY and FPC remain disabled.

## Safety boundary

The script produces build outputs and a staged module tree only. It does not build a Recovery ZIP, create an installer, flash the device or enable display DT nodes. Successful script execution does not prove hardware boot or panel operation.
