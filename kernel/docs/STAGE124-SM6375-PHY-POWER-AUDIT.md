# Stage 124 — SM6375 7nm DSI PHY power and supply audit

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: static source/DT audit only.

## PHY match and hardware configuration

The SPES SoC DTSI uses `qcom,sm6375-dsi-phy-7nm` at `0x05e94400`. The Mainline PHY match selects `dsi_phy_7nm_6375_cfgs`, which identifies one PHY instance at the same base address, uses the 7nm PHY enable/disable and PLL-init/save/restore operations, and applies the V4.1 PHY quirk. The config specifies a minimum PLL rate of 600 MHz and a 5 GHz maximum on 64-bit builds.

The PHY configuration's regulator bulk entry is `vdds` with a 36 mA initial load. The SPES board DTSI connects `vdds-supply` to PM6125 L4 and sets that rail to exactly 880 mV with adjustable load. This is the dedicated 0.9 V-class DSI PHY analog rail; it is distinct from panel I/O L9 and DSI host analog L18.

## Runtime-PM design is already stronger than the DSI Host path

The PHY driver uses `devm_pm_runtime_enable()`, `devm_pm_clk_create()`, and `pm_clk_add(dev, "iface")`. PLL initialization explicitly obtains a PM reference with `pm_runtime_resume_and_get()` before touching PLL state, then releases it with `pm_runtime_put_sync()`.

`msm_dsi_phy_enable()` also uses `pm_runtime_resume_and_get()`. If resume fails, it returns without a put. If regulator enable fails, it drops the acquired PM reference. If PHY enable fails, it disables the regulator and drops PM. If PLL state restore fails after PHY enable, it calls the PHY disable operation, disables the regulator, and drops PM. The normal disable path turns off PHY, regulator and PM in reverse order.

This provides a useful in-tree pattern for the DSI Host correction: acquire with `pm_runtime_resume_and_get()`, then unwind only resources that were successfully acquired, in reverse order.

## Power tree separation

- DSI host: `vdda-supply = <&pm6125_l18>` (1.232 V) and `refgen-supply = <&spes_refgen>`.
- DSI PHY: `vdds-supply = <&pm6125_l4>` (0.88 V).
- Panel: PM6125 physical GPIO9 controls panel enable; TLMM GPIO54 is external LCM 1.8 V enable. L9 remains always-on and is not added as a switchable panel supply.

Do not merge these rails or substitute L9 for PHY `vdds`. Keep the DSI PHY node disabled until the complete DSI/MDSS path is ready.

## Runtime evidence boundary

Previously supplied stock-device output identifies DSI0 controller/PHY/PLL sysfs devices and a K7 38-0C-0A panel with 1080x2400 90/60 Hz modes. However, the captured output does not include the DSI host hardware-version register value. The host's exact `msm_dsi_cfg_handler` is selected from that register at runtime, so it must not be guessed from the DT compatible string alone.

## Validation / safety

- Static source/DT audit only; no source or DT edits.
- No build, runtime test or hardware measurement in this stage.
- MDSS/DSI0/DSI PHY remain disabled; FPC remains disabled.
- No flash, Recovery ZIP or installable release artifact.
