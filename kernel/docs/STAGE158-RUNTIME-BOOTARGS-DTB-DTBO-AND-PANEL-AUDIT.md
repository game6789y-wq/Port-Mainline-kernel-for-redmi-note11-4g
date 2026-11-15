# Stage 158 — Runtime Boot Arguments and Device Tree Path Audit

Date: 2026-11-15
Target: Xiaomi Redmi Note 11 4G (SPES), Qualcomm SM6225 / Khaje
Evidence: user-supplied live Android output.

## 1. Runtime boot arguments

The supplied `/proc/cmdline` reports:
- `androidboot.slot_suffix=_a`
- `androidboot.dtbo_idx=20`
- `androidboot.dtb_idx=8`
- `androidboot.force_normal_boot=1`
- `androidboot.lcmtype=dsi_panel_c3q_45_02_0c_fhdp_video_display`
- `msm_drm.dsi_display0=qcom,mdss_dsi_panel_k7_38_0c_0a_fhdp_video:`
- `androidboot.fpsensor=fpc`
- `androidboot.verifiedbootstate=orange`
- `androidboot.bootdevice=4804000.ufshc`
- `androidboot.hwname=spes`
- `androidboot.product.hardware.sku=k7t`

The runtime `dtbo_idx=20` agrees with the exact SPES DTBO entry identified in Stage 156. The runtime `dtb_idx=8` agrees with the Khaje base DTB's zero-based position in the previously parsed vendor_boot DTB concatenation (the ninth human-counted FDT). Together with the runtime MSM and board IDs, this provides strong evidence that the expected Khaje/SPES DTB and SPES DTBO variant are selected.

The boot arguments identify the selected panel:
- LCM: `dsi_panel_c3q_45_02_0c_fhdp_video_display`
- DRM DSI compatible: `qcom,mdss_dsi_panel_k7_38_0c_0a_fhdp_video`

This is stronger than inferring the panel from a list of alternative overlay fragments, but the live panel node and touch controller should still be inspected in the expanded device-tree path.

The flag `androidboot.fpsensor=fpc` indicates the platform boot argument names an FPC fingerprint sensor. It does not prove that the fingerprint driver is enabled or operational. Project requirement remains: keep FPC disabled/skipped in mainline.

## 2. Device-tree path correction

The output shows:
- `/proc/device-tree` is a symlink to `/sys/firmware/devicetree/base`.
- `/sys/firmware/devicetree/base` is a directory.
- `/sys/firmware/fdt` exists and is 402,053 bytes.
- `find /sys/firmware/devicetree/base -name compatible` reports 673 files.

The earlier zero count under `/proc/device-tree` was caused by searching through a symlink without following it. It was not evidence that the device tree was absent.

## 3. Boot context and rescue partition

- `ro.bootmode` reports `unknown`.
- `ro.boot.slot_suffix` reports `_a`.
- `androidboot.force_normal_boot=1` is present in kernel command line.
- `rescue` resolves to `/dev/block/sda13`.
- Rescue partition size: 134,217,728 bytes (128 MiB).

The rescue partition's purpose and contents are not established. Do not assume it is a recovery partition and do not write to it. No rescue image was read or modified.

## 4. Safety and scope

- Read-only runtime properties and metadata only.
- No partition contents dumped in this stage.
- No source or device-tree modifications.
- No flashing, build, or installer ZIP.
- The previous explicit build stop remains in force.

## 5. Next evidence required

Search the real directory `/sys/firmware/devicetree/base` (not the symlink) and report exact paths and status for:
- the selected DSI panel `k7_38_0c_0a_fhdp_video`
- touchscreen nodes and their compatible strings
- SC8551 and MAX77729 nodes
- FPC1020 node and status

Also inspect only the `rescue` partition's symlink and size for now; do not dump it. The normal-boot and OrangeFox recovery preservation strategy remains unresolved.

Status: Runtime DTBO index 20 and DTB index 8 are now evidenced by the device's own boot command line. Exact panel identifier is known. Live node details and touch-controller identity remain to be collected.
