# Stage 132 — DRM suspend snapshot, restore and failure semantics

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: static source audit only.

## System suspend sequence

The DPU PM `.prepare` callback calls `msm_kms_pm_prepare()`, which calls `drm_mode_config_helper_suspend()`. That helper disables KMS polling when initialized, suspends DRM clients, and calls `drm_atomic_helper_suspend()` to save the active atomic state while disabling the display pipeline. On failure it resumes clients/polling and returns the error from `.prepare`; the system suspend sequence can therefore be aborted instead of proceeding with a still-active display.

After the device suspend phase, the DSI Host and DSI PHY system-sleep callbacks use `pm_runtime_force_suspend()`. The normal DRM disable path should already have run K7 atomic disable and DSI manager host/PHY post-disable, so those forced callbacks should not be the mechanism that turns the panel off.

## Resume sequence

On system resume, device resume callbacks (including DSI Host/PHY forced runtime resume) run before the DPU `.complete` callback. `msm_kms_pm_complete()` calls `drm_mode_config_helper_resume()`, which restores the saved atomic state using `drm_atomic_helper_resume()`, resumes DRM clients and re-enables polling. This is the intended path for restoring the display after sleep.

The K7 driver currently implements a fixed initial 90 Hz mode and does not implement the vendor 60/90 Hz seamless-switch hook. System sleep restore is a full DRM state restore, not evidence that dynamic refresh switching works.

## Reboot / poweroff detail

`drm_atomic_helper_shutdown()` is a wrapper around `drm_atomic_helper_disable_all()`. The latter commits a state with every CRTC inactive, detaches connectors/planes and clears framebuffers. This drives the normal atomic bridge disable/post-disable callbacks. The helper logs a failure but its public shutdown wrapper is void; K7's DCS OFF remains best-effort, while GPIO/reset shutdown still occurs through the bridge post-disable path.

## Disposition

- System suspend: snapshot + atomic disable; a failure is returned to PM prepare and should abort suspend.
- Resume: device power restoration precedes DRM state restore in `.complete`.
- Reboot/poweroff: atomic disable-all drives normal K7 OFF and host/PHY teardown; DCS acceptance is not guaranteed if the transfer itself fails.
- No additional K7 shutdown callback or source patch is justified by this audit.

## Validation / safety

- Static source audit only; no source/DT changes.
- No build or hardware test.
- MDSS/DSI0/DSI PHY remain disabled; FPC remains disabled.
- No flash or release artifact.
