# Stage 121 — DSI Host power-on unwind audit

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: source-level audit and patch design only.

## Confirmed unwind defects in `msm_dsi_host_power_on()`

The current function enables the SFPB master port before regulator bulk enable. The error paths do not consistently unwind resources acquired earlier:

1. `regulator_bulk_enable()` failure jumps directly to `unlock_ret`; the SFPB master port is not disabled.
2. `pm_runtime_get_sync()` is unchecked. If it fails, the function continues toward link-clock and register operations.
3. `link_clk_set_rate()` or `link_clk_enable()` failure jumps to `fail_disable_reg`, which disables regulators but does not drop the PM usage reference acquired immediately before it, and does not disable SFPB.
4. `pinctrl_pm_select_default_state()` failure reaches `fail_disable_clk`, disables link clocks and drops PM, then disables regulators; it still does not disable SFPB.

The clock-enable helpers inspected (`dsi_link_clk_enable_6g()` and `dsi_link_clk_enable_v2()`) unwind clocks they successfully enabled before a later clock-enable failure. Therefore, the caller should not blindly call `link_clk_disable()` when `link_clk_enable()` itself returns an error; the helper already rolls back its partial enables. Conversely, after a successful `link_clk_enable()`, a later pinctrl failure must call `link_clk_disable()`.

## Cleanup structure for a focused patch

Use explicit acquisition stages and reverse-order labels. A safe conceptual order is:

- SFPB enable
- regulator bulk enable
- `pm_runtime_resume_and_get()`
- link-clock rate setup
- link-clock enable
- default pinctrl selection
- DSI timing/reset/controller programming

Required unwind behavior:

- Regulator enable failure: disable SFPB, then unlock.
- Runtime-PM resume failure: do not call PM put; disable regulators, disable SFPB, then unlock.
- Link-clock rate or link-clock enable failure: release the successfully acquired PM reference, disable regulators, disable SFPB, then unlock. Do not call link-clock disable after a failed link-clock enable because the helper rolls back partial enables.
- Pinctrl failure after successful link-clock enable: disable link clocks, PM put, disable regulators, disable SFPB, then unlock.

Preserve the original error code from the operation that failed. `msm_dsi_sfpb_config()` currently returns void and ignores `regmap_update_bits()` errors; changing that contract is a separate decision and should be considered before claiming SFPB rollback is guaranteed.

## Additional detail requiring follow-up

`dsi_link_clk_set_rate_6g_v2_9()` logs `clk_set_parent()` failures but proceeds to `dsi_link_clk_set_rate_6g()`. This is a separate clock-parenting error-propagation concern; do not fold it into the PM/unwind patch without checking whether the source-parent clocks are mandatory for this target and how existing users depend on the current behavior.

## Validation / safety

- No source or DT changes; no patch applied.
- No build or hardware test.
- MDSS/DSI0/DSI PHY remain disabled; FPC remains disabled.
- No flash or release artifact.
