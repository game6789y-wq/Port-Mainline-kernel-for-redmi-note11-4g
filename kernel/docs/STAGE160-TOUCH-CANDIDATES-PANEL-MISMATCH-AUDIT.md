# Stage 160 — Touch Controller Candidates and Panel Name Mismatch

Date: 2026-11-15
Target: Xiaomi Redmi Note 11 4G (SPES), Qualcomm SM6225 / Khaje
Evidence: user-supplied live device-tree path and compatible scan.

## 1. Live touchscreen-related nodes

The live tree contains these compatible strings:
- `/soc/i2c@4a88000/novatek@62`: `novatek,NVT-ts`
- `/soc/i2c@4a88000/touchscreen`: `focaltech,fts`
- `/soc/i2c@4a88000/synaptics_tcm@20`: `synaptics,tcm-i2c`
- `/soc/xiaomi_touch`: `xiaomi-touch`

A separate node was also found:
- `/soc/goodix_fp`: `goodix,fingerprint`

The scan output did not include each candidate's `status`, resources, driver binding, or runtime probe logs. Therefore, it does not establish which touchscreen controller is physically populated or active. Do not select one driver based on compatible presence alone.

## 2. Panel identifier mismatch

Boot command line previously supplied by the user:
- `msm_drm.dsi_display0=qcom,mdss_dsi_panel_k7_38_0c_0a_fhdp_video:`
- `androidboot.lcmtype=dsi_panel_c3q_45_02_0c_fhdp_video_display`

The live device-tree path listing instead showed:
- `/soc/qcom,mdss_mdp/qcom,mdss_dsi_panel_k7_38_0c_0b_fhdp_video`

The `0a` versus `0b` mismatch is unresolved. Possible explanations include a boot argument alias, alternate panel node, overlay modification, or mismatch between selected runtime configuration and the visible node. No explanation is established from the supplied output. Do not choose a panel driver or port panel data until status, model/name properties, phandles, and relevant runtime logs are checked.

## 3. Other fingerprint node

The scan includes `/soc/goodix_fp` with compatible `goodix,fingerprint`, in addition to the previously confirmed `/soc/fpc1020`. The project's requirement remains to disable/skip fingerprint support entirely in mainline. Do not enable either fingerprint implementation.

## 4. Next evidence

Collect:
1. `status`, `reg`, `interrupts`, `reset-gpios`, `compatible`, and all readable property names for the three touchscreen candidate nodes.
2. The panel node's `status`, `qcom,mdss-dsi-panel-name`, `qcom,mdss-dsi-panel-model`, and any references to it from display-controller nodes.
3. Read-only runtime driver/probe evidence from `/sys/bus/i2c/devices` and kernel log entries mentioning novatek, focaltech, synaptics, touchscreen, and panel.

No device-tree source changes, builds, flashing, partition writes, or ZIP creation were performed. The previous explicit build stop remains in force.

Status: Three touchscreen driver candidates are identified; active controller is not yet known. Panel identifier mismatch must be resolved before mainline display integration.
