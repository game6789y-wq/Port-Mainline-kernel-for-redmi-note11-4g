# SPES Mainline Kernel — Source and Engineering Package

Target: Xiaomi Redmi Note 11 4G (SPES, Qualcomm SM6225)

## Package contents

- `spes-mainline-port.patch` — complete source/DTS patch against upstream base revision `c545b9e890d723b5dd0beb6a7a067a0e16088e65`; includes tracked edits and new source/binding/reference files.
- `BUILD-MANIFEST.txt` — build metadata, validation notes and artifact checksums.
- `k7-38-0c-0a-panel-command-audit.txt` — K7 panel command-table analysis.
- `k7-38-0c-0a-panel-driver-design.md` — panel driver design and Stages 1–118 audit notes.
- `k7-sm6225-display-clock-power-map.md` — display clock and power dependency map.
- `spes-max77729-sc8551-port-audit.md` — PMIC/charger and related port audit.
- `STAGE119-120-RUNTIME-PM-SHUTDOWN-AUDIT.md` — K7 shutdown ordering and DSI Host Runtime-PM acquisition semantics.
- `STAGE121-DSI-HOST-POWER-ON-UNWIND.md` — DSI Host power-on error-path unwind audit.
- `STAGE122-SM6225-DSI-DT-SFPB-CLOCK-AUDIT.md` — SM6225 DSI/PHY DT, optional SFPB and clock/power wiring.
- `STAGE123-DSI-PM-PROBE-TRANSFER-AUDIT.md` — probe-time PM acquisition and transfer-preparation error propagation.
- `STAGE124-SM6375-PHY-POWER-AUDIT.md` — SM6375 7nm PHY runtime PM, supply and power-tree audit.

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

### Stage 112 — DRM / ESD worker lifecycle
- Audited DSI-manager/K7 bridge ordering and established K7 `atomic_disable` as the safe synchronous cancel boundary before OFF; K7 `atomic_post_disable` precedes host shutdown.
- Documented delayed-work start/stop protocol, mutex/cancel ordering, LP-mode DCS read requirements and exact one-byte validation. No worker implementation or source changes in this stage.

### Stage 113 — DSI/DPU failure classification
- Audited K7 ON/PPS/refresh/backlight failures, MSM DSI error worker behavior and DPU flush timeout handling.
- Documented why host FIFO reset, PLL/PHY errors and DPU timeouts must not be treated as panel ESD or trigger a blind panel reset. Defined a controlled DRM disable/re-enable sequence for future hardware validation; no recovery code implemented.

### Stage 114 — Backlight and frame-completion audit
- Initially flagged a possible DBV byte-order mismatch; Stage 115 subsequently verified that vendor inversion plus its legacy little-endian helper is wire-equivalent to Mainline's large-brightness big-endian helper. The preliminary mismatch warning is superseded; no payload patch is required.
- Audited LP-mode backlight writes, `ctx->lock`/host `cmd_mutex` serialization, host power gate, DPU vblank/CTL flush/frame-done path and disable VSYNC wait. Kept brightness errors distinct from DSI link and DPU frame errors.
- Audit only: no source/DTS edits, rebuild or hardware test.

### Stage 115 — Corrected brightness byte-order verification
- Reconciled vendor DBV inversion with the actual legacy little-endian helper and Mainline large-brightness big-endian helper. Both produce the same DCS 0x51 payload (`0x07ff` -> `07 ff`).
- Supersedes Stage 114's preliminary mismatch warning. No source change required; visual brightness remains unverified on hardware.
- Static audit only; no rebuild or hardware test.

### Stage 116 — Vendor HBM and brightness policy
- Audited K7 vendor HBM LP command sequences and the required brightness restore after HBM-off. Mainline has no HBM implementation; keep it unsupported rather than adding unvalidated stateful commands.
- Recorded vendor 1..2047 metadata vs Mainline 0..2047 blanking behavior and noted project-specific scaling caveat.
- Static audit only; no source/DTS changes, rebuild or hardware test.

### Stage 117 update
- `k7-38-0c-0a-panel-driver-design.md`: normal brightness byte-order equivalence, Vendor HBM on/off and brightness restore sequence, Mainline backlight state handling, and DRM bridge enable/disable ordering.
- `BUILD-MANIFEST.txt`: records Stage 117 as static source audit only; no rebuild or hardware test.

### Stage 118 update
- `k7-38-0c-0a-panel-driver-design.md`: MIPI-DSI shutdown callback support, device shutdown ordering, K7 remove-path caveat, and conditions required before implementing shutdown-time DCS OFF.
- `BUILD-MANIFEST.txt`: records Stage 118 as static audit only; no source change or rebuild.

### Stage 119–120 update
- Added `STAGE119-120-RUNTIME-PM-SHUTDOWN-AUDIT.md`: shutdown ordering, DSI host transfer power gate, unchecked Runtime-PM acquisition, and the proposed `pm_runtime_resume_and_get()` error path.
- Confirmed the DSI Host power-on path must not continue into link-clock/register operations after bus-clock resume failure.

### Stage 121 update
- Added `STAGE121-DSI-HOST-POWER-ON-UNWIND.md`: regulator, Runtime-PM, link-clock and SFPB cleanup ordering. Stage 122 later qualifies SFPB as absent/unused in current SPES DTS.

### Stage 122 update
- Added `STAGE122-SM6225-DSI-DT-SFPB-CLOCK-AUDIT.md`: DSI0/PHY addresses, clock names, OPP/power-domain wiring and confirmation that no `syscon-sfpb` phandle exists in the current Qualcomm DTS set.

### Stage 123 update
- Added `STAGE123-DSI-PM-PROBE-TRANSFER-AUDIT.md`: `dsi_get_config()` probe path, runtime PM cleanup on init failures, and DSI transfer prepare error propagation.
- Corrected Stage 120: `msm_dsi_host_xfer_prepare()` returns `int`, not `void`; callers already check its return.

### Stage 124 update
- Added `STAGE124-SM6375-PHY-POWER-AUDIT.md`: 7nm V4.1 PHY configuration, PM6125 L4 0.88 V supply, separate host L18/refgen rails, and the PHY driver's already-correct Runtime-PM acquisition/unwind pattern.
- Stock-device logs show the K7 panel and 90/60 Hz modes, but do not provide the DSI host hardware-version register value; exact host clock-ops selection remains unconfirmed.
