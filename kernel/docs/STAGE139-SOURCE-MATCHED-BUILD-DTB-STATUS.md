# Stage 139 — source-matched build, module staging and DTB safety status

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: source-matched build and staging verification; no hardware test.

## Build state

The DSI Host PM draft was reversed before this build. `drivers/gpu/drm/msm/dsi/dsi_host.c` source SHA-256 is `50f7d8e640615c627db25ed69154bc4cf66dcc08635469f60595f1b94c2eebfc`. The current build outputs and staged modules were rebuilt from that unpatched source.

- `Image` SHA-256: `3315ba5191cb5a7cdeb3c365cfca7dc24af1e44b9369e7e2d82054058a6e37d4`.
- `sm6225-xiaomi-spes.dtb` SHA-256: `4eae7c455a7572ac877785d02b79f745c78dc7f63189b57ca32a48380889ff64`.
- `drivers/gpu/drm/msm/msm.ko` SHA-256: `64f070ad98a587d02e6acec52e1a001a3ab2312d18070135e68bbbf57421e6bd`.
- Staged K7 panel module SHA-256: `8f092d6c81f90e2f818402474bdef8d2f9f8f62abbc5658d3cd76f4c97e525a0`.
- Staged REFGEN regulator module SHA-256: `483d00e12a46a5e0d80448e3decb0371aeb9354382bf47bd0d1394a1e43370cf`.
- Staging release: `7.3.0-rc4-gc545b9e890d7-dirty`.
- Staged modules: 1,681 `.ko`; FPC-named modules: 0.

`Image modules` completed successfully; `modules_install` and `depmod -b` completed successfully. The K7 module and all display module aliases/dependencies are present in staging.

## Compiled DTB safety gates

`fdtget` on the freshly checked SPES DTB confirms:

- `/soc/display-subsystem@5e00000`: `status = "disabled"`.
- `/soc/display-subsystem@5e00000/dsi@5e94000`: `status = "disabled"`.
- `/soc/display-subsystem@5e00000/phy@5e94400`: `status = "disabled"`.
- `/soc/fpc1020`: `status = "disabled"`.

The display-controller child has no explicit status property, but its parent display-subsystem is disabled. Therefore, this DTB does not activate the MDSS/DSI/PHY path. FPC remains disabled both in DT and in build config/module staging.

## Remaining boundary

- Build success and module autoload metadata do not prove the panel powers on or displays a frame.
- No hardware boot, regulator/GPIO measurement, panel DCS validation, runtime suspend/resume test or flash.
- No Recovery ZIP or installable release artifact.
- The DSI Host PM fix remains an un-applied draft patch; current source-matched Image/modules are built from the original port source.
