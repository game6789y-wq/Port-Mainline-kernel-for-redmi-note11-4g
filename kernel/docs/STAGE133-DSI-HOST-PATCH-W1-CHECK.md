# Stage 133 — DSI Host PM patch W=1 compile check

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Patch: `0001-msm-dsi-host-runtime-pm-unwind.patch`
Status: isolated warning-enabled object compile passed; patch remains unapplied.

## Procedure and result

- Temporarily applied the draft patch to the current SPES port working tree.
- Ran `make O=/workspace/ubuntu-spes-mainline/build/spes ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 -j2 drivers/gpu/drm/msm/dsi/dsi_host.o`.
- The target compiled successfully (`CC [M] drivers/gpu/drm/msm/dsi/dsi_host.o`, exit status 0); no W=1 compiler warnings were emitted for this object.
- Reversed the patch successfully.
- Source SHA-256 before and after was identical: `50f7d8e640615c627db25ed69154bc4cf66dcc08635469f60595f1b94c2eebfc`.

## Limits

- This is an object-level compile, not a full kernel build.
- No runtime or hardware test; MDSS/DSI0/DSI PHY remain disabled.
- Patch still requires a developer Signed-off-by before upstream submission and has not been applied to the source tree.
