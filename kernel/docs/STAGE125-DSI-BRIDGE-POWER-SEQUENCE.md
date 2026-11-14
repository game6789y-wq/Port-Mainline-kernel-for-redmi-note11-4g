# Stage 125 — DSI bridge power sequence and failure propagation

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: static source audit only.

## Normal pre-enable sequence

`dsi_mgr_bridge_power_on()` enables the PHY first, then calls `msm_dsi_host_power_on()`. In bonded mode it powers the second host after the first. Only after successful host power-up does it enable the host IRQ(s). `dsi_mgr_bridge_pre_enable()` then enables DSI host video/command operation. The K7 bridge sets `pre_enable_prev_first = true`, so the upstream DSI manager pre-enable is ordered before K7 panel pre-enable. This ensures the panel's DCS ON/PPS/refresh writes are attempted only after the host/PHY power sequence succeeds.

Normal power-off order is host disable, IRQ disable, host power-off, then PHY disable. The host power-off path drops link clocks and its retained PM reference before disabling host regulators. PHY disable follows and drops its own PM reference and `vdds` rail.

## Failure unwind

- PHY enable failure: bridge power-on returns the PHY error; host power-on is not attempted.
- Host power-on failure: manager calls PHY disable. The host's `power_on` flag is set only after all host setup succeeds, so `msm_dsi_host_power_off()` is a no-op for a host that never completed power-on. The host's own failure labels must therefore unwind every acquired host resource before returning.
- Bonded second-host failure: manager powers off the first host, then disables the PHY pair.

This confirms why the Host power-on fix must be internally complete and balanced before returning an error; the manager does not call host power-off for the failed host itself.

## DRM failure-propagation limitation

`dsi_mgr_bridge_pre_enable()` is a void DRM bridge callback. If `dsi_mgr_bridge_power_on()` fails, it logs and returns; it cannot propagate the error through this callback to abort the atomic commit. The DRM bridge chain can still proceed to the downstream K7 pre-enable callback. K7 DCS transfers will then be rejected by `dsi_host_transfer()` because `msm_host->power_on` is false, and K7 records the prepare error and powers down its GPIO/reset state.

This is an existing bridge-framework limitation in this path, not a reason to bypass the host power gate. Preserve the gate and make failure visible in logs/state; do not issue DCS commands against an unpowered host. A broader atomic-commit failure-reporting redesign is outside the focused Runtime-PM/unwind correction.

## Patch priorities derived from the sequence

1. Fix `msm_dsi_host_power_on()` acquisition and reverse-order cleanup first.
2. Fix `msm_dsi_host_xfer_prepare()` so it returns PM/rate/clock errors and self-unwinds before the manager handles the error.
3. Make `dsi_get_config()` check its PM acquisition and avoid a put when acquisition failed.
4. Keep PHY PM code unchanged unless later evidence identifies a separate PHY defect; it already uses `pm_runtime_resume_and_get()` and explicit cleanup.

## Validation / safety

- Static source audit only; no source/DT changes.
- No build or hardware test.
- MDSS/DSI0/DSI PHY remain disabled; FPC remains disabled.
- No flash or release artifact.
