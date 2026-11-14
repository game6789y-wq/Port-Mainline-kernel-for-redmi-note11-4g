# Stage 130 — Khaje DSI controller version mapping

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: vendor-DT to Mainline source mapping; hardware register value not directly measured.

## Vendor declaration

The vendor Khaje SDE DTS declares DSI0 at `0x05e94000` with compatible `qcom,dsi-ctrl-hw-v2.4`, controller index 0, and supplies `vdda-1p2` plus `refgen`. This is stronger evidence for the controller generation than the Mainline DT compatible string alone.

## Mainline mapping

Mainline `dsi_cfg.c` maps both `MSM_DSI_6G_VER_MINOR_V2_4_0` and `MSM_DSI_6G_VER_MINOR_V2_4_1` to:

- `sdm845_dsi_cfg`
- `msm_dsi_6g_v2_host_ops`

The `sdm845_dsi_cfg` explicitly includes IO base `0x5e94000` for QCM2290 / SM6115 / SM6125 / SM6375. It uses the v2.4 regulator list (`vdda`, `refgen`) and bus-clock names `iface`, `bus`. The SPES Mainline DT's `vdda-supply = <&pm6125_l18>` and `refgen-supply = <&spes_refgen>` align with the vendor DSI controller supply names/roles. The remaining `byte`, `byte_intf`, `pixel` and `core` clocks are link clocks acquired separately by the host clock initialization path.

Therefore, the vendor's v2.4 declaration predicts that the Mainline runtime version lookup should select the 6G v2.4.0 or v2.4.1 entry, both of which share the same host operations and regulator/clock config. The exact step cannot be proven without the DSI hardware-version register value; do not hardcode a version or bypass `dsi_get_config()`.

## Runtime evidence boundary

Prior stock-device logs identify DSI0 at `0x5e94000`, PHY at `0x5e94400`, and the K7 panel modes, but no raw DSI HW version register was included. The vendor DT v2.4 string is family-level evidence, not a measured register dump.

## Disposition

No Mainline DSI config table change is indicated by the vendor v2.4 declaration. Keep runtime register detection authoritative. Continue to use the v2.4 supply/clock mapping as the expected configuration for static review, and verify the actual version on device before enabling DSI0.

## Validation / safety

- Static vendor/Mainline source and DT audit only.
- No source/DT change, rebuild or hardware test.
- MDSS/DSI0/DSI PHY remain disabled; FPC remains disabled.
- No flash or release artifact.
