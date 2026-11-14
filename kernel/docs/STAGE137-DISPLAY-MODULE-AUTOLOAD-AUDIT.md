# Stage 137 — MSM display and DSI module autoload audit

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: existing staged module metadata inspection.

## MSM DRM/MDSS/DSI provider

The staged `drivers/gpu/drm/msm/msm.ko` has matching vermagic `7.3.0-rc4-gc545b9e890d7-dirty SMP preempt mod_unload aarch64`. Its OF aliases include:

- `qcom,mdss-dsi-ctrl` — the generic fallback compatible in the SPES DSI0 node (`qcom,sm6115-dsi-ctrl`, `qcom,mdss-dsi-ctrl`).
- `qcom,sm6375-dsi-phy-7nm` — the SPES DSI PHY compatible.
- `qcom,sm6225-mdss` — the MDSS provider.
- `qcom,sm6225-dpu` — the DPU provider.

The exact `qcom,sm6115-dsi-ctrl` string is not a separate alias in this driver; the second compatible `qcom,mdss-dsi-ctrl` matches and loads the MSM module. Both the module's `modinfo` and staged `modules.alias` contain that fallback alias.

`modprobe -d <staging> -S <release> --show-depends msm` resolves the dependency chain and includes `drm_kms_helper`, DRM display helpers, GPU scheduler, Qualcomm OCMEM/LLCC/MDT/UBWC modules, then `msm.ko`.

## K7 and REFGEN providers

- K7 panel is staged separately as `panel-k7-38-0c-0a.ko` with OF alias `xiaomi,k7-38-0c-0a`; Stage 136 verified its `modprobe --show-depends` chain.
- REFGEN is staged as `qcom-refgen-regulator.ko` with alias `qcom,sm8250-refgen-regulator`; Stage 129 verified its module metadata.

## Disposition

The module metadata needed for MSM DSI0/PHY/MDSS/DPU and the K7 panel can now resolve their DT compatible strings. This proves staged module alias/dependency metadata only; it does not prove the final Android root filesystem contains every staged module, loads them at boot, or that the disabled display nodes will bind on hardware.

## Validation / safety

- Existing staged module inspection only; no new build or source change.
- No hardware boot/display test or flash.
- MDSS/DSI0/DSI PHY remain disabled; FPC remains disabled.
