# SPES Mainline Kernel — Source and Engineering Package

Target: Xiaomi Redmi Note 11 4G (SPES, Qualcomm SM6225)

## Package contents

- `spes-mainline-port.patch` — complete source/DTS patch against upstream base revision `c545b9e890d723b5dd0beb6a7a067a0e16088e65`; includes tracked edits and new source/binding/reference files.
- `BUILD-MANIFEST.txt` — build metadata, validation notes and artifact checksums.
- `k7-38-0c-0a-panel-command-audit.txt` — K7 panel command-table analysis.
- `k7-38-0c-0a-panel-driver-design.md` — panel driver design and Stages 1–111 audit notes.
- `k7-sm6225-display-clock-power-map.md` — display clock and power dependency map.
- `spes-max77729-sc8551-port-audit.md` — PMIC/charger and related port audit.

## Apply the source patch

```sh
git checkout c545b9e890d723b5dd0beb6a7a067a0e16088e65
git apply --check spes-mainline-port.patch
git apply spes-mainline-port.patch
```

## Validation status

- Kernel Image and modules were previously built successfully; see the manifest for the exact revision, release string and hashes.
- `git diff --check` passed during the latest source audit.
- Device-tree binding documentation validation passed for the checked bindings.
- Full `dtbs_check` remains blocked by an internal error in the installed dtschema 2024.4; this is not reported as a pass.
- Stage 111 confirms DCS read success must return exactly one byte (`0x9D`); future ESD work must be cancelled before OFF/host shutdown and must not perform blind recovery. No worker is implemented yet.
- Display/MDSS/DSI/PHY nodes remain disabled pending controlled hardware validation. The display path is source-audited only; no first-frame or panel operation is claimed.
- Fingerprint scanning is intentionally skipped and FPC remains disabled.
- This package is not a flashable image, Recovery ZIP, installer or tested release.

## Binary artifacts

The 54.7 MB kernel Image and other build outputs remain in the build workspace. They are not included here because this is an engineering/source snapshot, not a hardware-validated release. Use the manifest hashes to identify the local build outputs.
