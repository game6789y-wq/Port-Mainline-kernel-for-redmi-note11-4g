# Stage 136 — K7 panel module staging correction

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: source-matched rebuild and module staging completed successfully.

## Issue found

`CONFIG_DRM_PANEL_XIAOMI_K7_38_0C_0A=m` and the K7 panel module existed in `build/spes/drivers/gpu/drm/panel/panel-k7-38-0c-0a.ko`, but the previous `spes-module-staging` tree did not contain it. The build's `modules.order` listed the K7 module, while the staging `modules.order`, `modules.dep` and `modules.alias` did not. A final Android root filesystem assembled from that staging tree would therefore be missing the panel driver and its OF autoload alias.

## Correction performed

1. Confirmed the kernel source tree was restored to the unpatched state; DSI Host source SHA-256 is `50f7d8e640615c627db25ed69154bc4cf66dcc08635469f60595f1b94c2eebfc`.
2. Rebuilt `Image modules` from the unpatched source; build completed with exit status 0.
3. Ran `modules_install` into `/workspace/ubuntu-spes-mainline/build/spes-module-staging`.
4. Ran `depmod -b` for release `7.3.0-rc4-gc545b9e890d7-dirty`.

## Verified staging result

- Staged K7 module: `kernel/drivers/gpu/drm/panel/panel-k7-38-0c-0a.ko`.
- K7 module SHA-256: `8f092d6c81f90e2f818402474bdef8d2f9f8f62abbc5658d3cd76f4c97e525a0`.
- K7 vermagic: `7.3.0-rc4-gc545b9e890d7-dirty SMP preempt mod_unload aarch64`.
- OF aliases in `modules.alias`: `xiaomi,k7-38-0c-0a` (including wildcard form).
- `modules.order` and `modules.dep` now contain the K7 module.
- `modprobe -d <staging> -S <release> --show-depends panel_k7_38_0c_0a` resolves the dependency chain and prints `drm_kms_helper`, `cec`, `drm_display_helper`, then the K7 panel module.
- Staged module count: 1,681 `.ko` files.
- FPC module count: 0; fingerprint support remains excluded.
- REFGEN module remains staged with matching release vermagic and OF alias.

## Source-matched build artifacts

- Image SHA-256: `3315ba5191cb5a7cdeb3c365cfca7dc24af1e44b9369e7e2d82054058a6e37d4`.
- MSM DRM module SHA-256: `64f070ad98a587d02e6acec52e1a001a3ab2312d18070135e68bbbf57421e6bd`.
- The Image hash is unchanged because MSM DRM is a separate module; the MSM module hash now corresponds to the restored unpatched source.

## Safety boundary

- This fixes the missing K7 module in staging; it does not enable the display DT nodes.
- No hardware boot, panel operation, runtime test or flash.
- MDSS/DSI0/DSI PHY remain disabled; FPC remains disabled.
- No Recovery ZIP or installable release artifact.
