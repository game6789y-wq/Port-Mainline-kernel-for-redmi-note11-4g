# Stage 123 — DSI Runtime-PM probe and transfer-path audit

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: source-level audit only; no source patch applied.

## 1. Probe-time `dsi_get_config()`

`msm_dsi_host_init()` sets `msm_dsi->host` before enabling runtime PM. `dsi_init()` has already stored `msm_dsi` with `platform_set_drvdata()`, so the runtime callbacks can resolve the host/device objects during version discovery.

The host enables runtime PM, then `dsi_get_config()` calls `pm_runtime_get_sync()` without checking the return, separately enables the `iface` clock, reads the DSI version register, disables the interface clock, and unconditionally calls `pm_runtime_put_sync()` on the common cleanup path.

During this early discovery step, `msm_host->cfg_hnd` is still NULL. Both runtime suspend and resume callbacks explicitly return 0 when no config handler is available. Therefore, the runtime-PM callback does not yet enable the bulk DSI bus clocks; the local `iface` clock is explicitly enabled around the version-register read. Once the config handler is assigned, later runtime resume enables the bulk bus-clock group.

A defensive correction should use `pm_runtime_resume_and_get()` and only issue the matching put after successful acquisition. The helper should propagate/log the PM acquisition error rather than continue into register access. The current `dsi_get_config()` return type is a config pointer, so the error design should preserve the actual failure (for example, an error-pointer return with caller-side `IS_ERR()` handling, or a carefully scoped output-error parameter) rather than silently translating every failure to `-EINVAL`.

## 2. Probe failure cleanup

`pm_runtime_enable()` is called before the remainder of `msm_dsi_host_init()`. Later init failures are routed by `dsi_init()` through `dsi_destroy()`, which calls `msm_dsi_host_destroy()` when the host pointer exists; that destroy function calls `pm_runtime_disable()`. The normal failure unwind therefore does disable runtime PM. No separate PM-enable leak was confirmed from this call chain.

## 3. Transfer preparation — correction to Stage 120 note

Correction: `msm_dsi_host_xfer_prepare()` returns `int`, not `void`. Its callers in `dsi_manager.c` check the return value. The Stage 120 statement describing it as a void function was incorrect.

The actual function currently:

1. Calls `pm_runtime_get_sync()` and ignores the result.
2. Calls `link_clk_set_rate()` and ignores the result.
3. Calls `link_clk_enable()` and ignores the result.
4. Proceeds to DSI register access and returns 0.

The return type and callers permit a proper error path. A focused future fix can use `pm_runtime_resume_and_get()`, return immediately on PM failure, check link-clock rate setup, and drop the PM reference on failure. It should check link-clock enable too; the inspected 6G and v2 clock-enable helpers unwind any partial enables internally, so the caller should not call link-clock disable when enable itself fails. Only after all three stages succeed should the function touch DSI registers and return 0.

For synchronized/bonded transfers, `msm_dsi_manager_cmd_xfer()` prepares the non-trigger host first, then the trigger host. If the second prepare fails, the existing manager path restores the first host. The failing `xfer_prepare()` must unwind its own partial resources before returning an error; the manager cannot safely restore a host that never completed preparation.

The multi-command path also checks the prepare return and only restores after successful preparation, so the same self-unwind requirement applies.

## 4. Stage 120 call-site correction

The Stage 120 document's description of `xfer_prepare()` as void is superseded by this Stage 123 correction. The unchecked PM acquisition finding remains valid, but an error can be propagated through its existing int return contract without changing the public function signature.

## Validation / safety

- Static source audit only; no source or DT changes.
- No build, runtime test or hardware measurement.
- MDSS/DSI0/DSI PHY remain disabled; FPC remains disabled.
- No flash, Recovery ZIP or installable release artifact.
