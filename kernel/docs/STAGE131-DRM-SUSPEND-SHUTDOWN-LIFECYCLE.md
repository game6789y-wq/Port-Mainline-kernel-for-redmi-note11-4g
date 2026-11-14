# Stage 131 — DRM suspend and system-shutdown lifecycle

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: static Mainline driver lifecycle audit.

## System suspend

The DPU driver's `dev_pm_ops` includes `.prepare = msm_kms_pm_prepare` and `.complete = msm_kms_pm_complete`, in addition to its runtime/system PM callbacks. `msm_kms_pm_prepare()` calls `drm_mode_config_helper_suspend()` when the DRM/KMS objects are initialized; the matching complete callback calls `drm_mode_config_helper_resume()`.

This places DRM display shutdown in the system-suspend prepare phase, before the DSI host's later system-sleep `pm_runtime_force_suspend()` callback. The DRM helper disables the active display pipeline through normal atomic bridge callbacks. For K7, that means its normal atomic disable path can send panel OFF while the upstream DSI host is still available, followed by DSI host and PHY power-off. This is safer than relying on DSI Host forced runtime suspend to perform panel protocol shutdown.

The DSI PHY itself uses `pm_runtime_force_suspend/force_resume` for system sleep. Its PM-clock handling is separate from the DSI Host's bulk bus clocks. Normal DRM disable should release active PHY and host references before these forced system-sleep callbacks.

## Reboot / poweroff shutdown

The DPU platform driver registers `.shutdown = msm_kms_shutdown`. When the DRM device is registered and KMS exists, `msm_kms_shutdown()` calls `drm_atomic_helper_shutdown(drm)`. That shuts down active DRM state through the ordinary bridge disable/post-disable path.

For the K7 chain, the ordinary bridge path is the desired shutdown path: K7 `atomic_disable` attempts DCS OFF while the host is still powered, and DSI manager bridge post-disable then disables host and PHY. The DSI host platform driver itself has no `.shutdown` callback in this tree.

This is an important qualification to Stage 118–119's candidate K7 MIPI-DSI `.shutdown` callback: the DRM DPU shutdown hook already provides a normal atomic shutdown path when the DRM device is registered. A second panel-driver shutdown callback may be redundant and could cause duplicate OFF/power-down operations depending on device shutdown order. Do not add it without proving a remaining path where DRM shutdown is not invoked or the DRM device is not registered.

## Failure and fallback boundary

`msm_kms_shutdown()` deliberately skips DRM shutdown if the DRM device is not registered or KMS is unavailable. In that early/incomplete-probe case, the DRM bridge chain may not exist, and no panel OFF guarantee can be made. A panel `.shutdown` callback would need to be evaluated against that specific partial-probe lifecycle and the MIPI child/host ordering before implementation.

## Disposition

- System suspend: DRM helper disables active display before DSI/PHY forced runtime-PM system-sleep callbacks.
- Normal reboot/poweroff: DPU `.shutdown` calls DRM atomic shutdown, which should use the existing K7 OFF and host/PHY teardown callbacks.
- No K7 `.shutdown` callback is proposed at this stage; retain existing atomic disable as the preferred protocol path.

## Validation / safety

- Static source audit only; no source/DT changes.
- No build or hardware test.
- MDSS/DSI0/DSI PHY remain disabled; FPC remains disabled.
- No flash or release artifact.
