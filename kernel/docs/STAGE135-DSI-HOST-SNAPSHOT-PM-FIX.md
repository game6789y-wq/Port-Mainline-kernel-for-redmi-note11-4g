# Stage 135 — DSI Host snapshot PM guard and refreshed integration build

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Patch: updated `0001-msm-dsi-host-runtime-pm-unwind.patch`
Status: expanded draft passed W=1 object compile and full Image/modules build; patch was reversed afterward.

## New Stage 135 finding and correction

The remaining `msm_dsi_host_snapshot()` path used `pm_runtime_get_sync()` without checking the result before reading DSI controller registers. Because the function returns `void`, the safe behavior is to use `pm_runtime_resume_and_get()`, log and skip the register block if resume fails, and only call `pm_runtime_put_sync()` after a successful acquisition.

The draft patch now covers all four DSI Host PM acquisition paths in `dsi_host.c`:

1. `dsi_get_config()` — checked PM acquisition and error-pointer propagation.
2. `msm_dsi_host_xfer_prepare()` — checked PM/rate/clock setup and error propagation before register access.
3. `msm_dsi_host_power_on()` — checked PM acquisition and reverse-order regulator/clock cleanup.
4. `msm_dsi_host_snapshot()` — skip snapshot register reads when PM resume fails.

The patched temporary copy has no remaining `pm_runtime_get_sync()` calls in `dsi_host.c`; all four sites use `pm_runtime_resume_and_get()` and handle failure.

## Validation

- `git apply --check`: PASS.
- `scripts/checkpatch.pl --no-tree --strict`: only outstanding error is missing developer `Signed-off-by`; no sign-off was invented.
- DSI Host object compile with `W=1`: PASS, no compiler warnings.
- Full `make O=/workspace/ubuntu-spes-mainline/build/spes ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j2 Image modules`: PASS, exit status 0.
- Build log includes DSI Host object compile, MSM DRM module link, MODPOST, vmlinux link and ARM64 Image generation.
- Patch was reversed; source SHA-256 before/after: `50f7d8e640615c627db25ed69154bc4cf66dcc08635469f60595f1b94c2eebfc`.

## Test artifact hashes

These outputs were generated while the updated patch was temporarily applied and are integration-test artifacts, not a release package:

- Image: `3315ba5191cb5a7cdeb3c365cfca7dc24af1e44b9369e7e2d82054058a6e37d4`.
- MSM DRM module: `17aea3446ed9014764cfefb0f6bb5a13ff79d0adb72d393256a428e85b912d15`.

The module staging directory was not refreshed from this test build. The patch remains a draft and has not been applied to the source tree.

## Not performed

- No hardware boot, display runtime test or flash.
- MDSS/DSI0/DSI PHY remain disabled; FPC remains disabled.
- No Recovery ZIP or installable release artifact.
