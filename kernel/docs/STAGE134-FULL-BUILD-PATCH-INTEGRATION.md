# Stage 134 — full Image/modules build with DSI Host PM patch draft

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Patch: `0001-msm-dsi-host-runtime-pm-unwind.patch`
Status: full build passed with patch temporarily applied; patch was then reversed.

## Procedure

- Recorded the source file SHA-256 before applying the draft patch.
- Temporarily applied the draft patch to `drivers/gpu/drm/msm/dsi/dsi_host.c`.
- Ran:

  `make O=/workspace/ubuntu-spes-mainline/build/spes ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j2 Image modules`

- Build completed with exit status 0. The log shows successful DSI Host object compilation, MSM DRM module link, MODPOST, vmlinux link and ARM64 Image generation.
- Reversed the patch and verified the source file SHA-256 returned to the exact pre-test value.

## Results

- Full `Image modules` target: PASS (exit 0).
- DSI Host object and `drivers/gpu/drm/msm/msm.ko`: compiled/linked.
- Image SHA-256 from this temporary patched build: `abeb50f1978bc5cb3865bf5a63e4e9519f2349c16787ad817bd0a967492781cc`.
- MSM module SHA-256 from this temporary patched build: `0dcdbb6f81bc71b76835f2699b1c9618eaaa30b295f9395faeb872391354a69b`.
- Source file SHA-256 before and after patch reversal: `50f7d8e640615c627db25ed69154bc4cf66dcc08635469f60595f1b94c2eebfc`.

## Important artifact boundary

The Image and `msm.ko` in `build/spes` were produced while the draft patch was temporarily applied. The patch is not applied to the source tree now. These outputs are integration-test artifacts only; do not treat them as the current source-matched release package. The module staging directory was not refreshed from this test build.

## Not performed

- No hardware boot, display test or flash.
- MDSS/DSI0/DSI PHY remain disabled; FPC remains disabled.
- No Recovery ZIP or installable release artifact.
- Patch remains a draft without developer Signed-off-by.
