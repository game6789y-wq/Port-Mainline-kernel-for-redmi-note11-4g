# SPES K7 DSI shutdown and Runtime-PM audit (Stages 119–120)

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: source-level audit and design only; no source patch applied.

## Stage 119 — shutdown ordering and host power state

- `msm_dsi_host_power_on()` acquires a Runtime-PM usage reference and the normal successful path retains it until `msm_dsi_host_power_off()` releases it.
- DSI command transfers check `msm_host->power_on` before taking `cmd_mutex`; a powered-off host rejects transfers rather than powering itself back up. Transfers while active acquire a temporary PM reference.
- Device shutdown walks the device list backwards. The MIPI-DSI child is expected to receive its driver shutdown callback before the parent platform DSI host shutdown callback. The MIPI-DSI bus itself has no bus-level shutdown callback; the driver `.shutdown` callback is wired by `mipi_dsi_driver_register_full()`.
- Candidate K7 shutdown behavior: best-effort OFF command only while the panel is prepared/active and host is available; log transfer failure; unconditionally assert reset low, disable panel-enable GPIO, select sleep pinctrl, and clear state. This does not guarantee the panel accepted OFF. Callback not implemented.

## Stage 120 — Runtime-PM error semantics

The checked-in `include/linux/pm_runtime.h` documents that `pm_runtime_get_sync()` increments the usage counter even if synchronous resume fails. `pm_runtime_resume_and_get()` is available in this tree and increments the usage counter only after successful resume.

`msm_dsi_runtime_resume()` returns `clk_bulk_prepare_enable()` for DSI bus clocks. Therefore, failed runtime resume can leave the bus clocks needed for DSI register access unavailable.

### Focused `msm_dsi_host_power_on()` issue

Current order: enable SFPB master port, enable regulator bulk, call `pm_runtime_get_sync()` without checking its return, then proceed to link-clock rate/enable and DSI register programming. This continues after a failed bus-clock resume and may retain an unbalanced PM usage reference.

Focused correction design:
1. Replace this acquisition with `pm_runtime_resume_and_get()`.
2. On a negative return, preserve that error and unwind the already-enabled regulator bulk and SFPB master-port setting before unlocking.
3. Do not call `pm_runtime_put()` on this failed acquisition because no usage reference was taken.
4. Also review the existing regulator-enable failure path: SFPB was enabled before regulator enable, but that path currently exits without visibly disabling SFPB.

### Other unchecked call sites

- `dsi_get_config()` ignores `pm_runtime_get_sync()` before interface-clock enable and DSI version register access; it later calls `pm_runtime_put_sync()`.
- `msm_dsi_host_xfer_prepare()` ignores it before link-clock operations and DSI register access; paired restore disables link clocks and calls `pm_runtime_put()`.
- `msm_dsi_host_snapshot()` ignores it before reading DSI registers and then calls `pm_runtime_put_sync()`.

These need separate treatment. In particular, `xfer_prepare()` has a void return type, so error propagation must be traced through transfer framework callers before changing its contract. Do not mechanically replace every call site in the focused power-on patch.

## Validation and safety status

- No kernel source or DT source changed in Stages 119–120; no patch applied.
- No rebuild or hardware test in Stages 119–120.
- MDSS, DSI0 and DSI PHY remain disabled; no panel/display enablement.
- FPC fingerprint support remains disabled/skipped.
- No flash, Recovery ZIP or installable release artifact produced.
