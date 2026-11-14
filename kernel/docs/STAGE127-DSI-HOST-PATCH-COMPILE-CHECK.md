# Stage 127 — DSI Host PM patch object compile check

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Patch: `0001-msm-dsi-host-runtime-pm-unwind.patch`
Status: isolated object compile passed; patch remains unapplied.

## Test procedure

1. Recorded SHA-256 of the working-tree `drivers/gpu/drm/msm/dsi/dsi_host.c` before the test.
2. Temporarily applied the draft patch to the working tree.
3. Ran:

   `make O=/workspace/ubuntu-spes-mainline/build/spes ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j2 drivers/gpu/drm/msm/dsi/dsi_host.o`

4. The compiler completed `CC [M] drivers/gpu/drm/msm/dsi/dsi_host.o` successfully (exit status 0).
5. Reversed the patch immediately and compared the source file SHA-256 before/after.

## Result

- DSI Host object compile: PASS.
- Patch reverse: PASS.
- Source file SHA-256 before and after: identical (`50f7d8e640615c627db25ed69154bc4cf66dcc08635469f60595f1b94c2eebfc`).
- The patch is still only a draft in `kernel/patches/drafts/`; it has not been applied or committed into kernel source.

## Limits

- This is an object-level compile only, not a full Image/modules rebuild.
- No runtime or hardware test; MDSS/DSI0/DSI PHY remain disabled.
- `checkpatch.pl --strict` has no style warnings; the only outstanding error is missing developer `Signed-off-by`.
- No flash, Recovery ZIP or installable release artifact.
