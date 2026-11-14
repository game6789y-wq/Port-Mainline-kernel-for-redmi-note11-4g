# Stage 122 — SM6225 DSI Device Tree, SFPB and clock audit

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: static source/DT audit only.

## DSI host and PHY facts

The SM6225 SoC DTSI declares DSI0 at `0x05e94000` with compatible `qcom,sm6115-dsi-ctrl` plus the generic MDSS DSI controller fallback. Its six clocks are named `byte`, `byte_intf`, `pixel`, `core`, `iface`, and `bus`; the bus clock is GCC `GCC_DISP_HF_AXI_CLK`. The node uses the SM6115 VDDCX power domain and DSI OPP table and remains `status = "disabled"`.

The PHY at `0x05e94400` uses `qcom,sm6375-dsi-phy-7nm`, exposes two PHY clocks, uses MDSS AHB and RPM XO reference clocks, and also remains disabled. The DSI input endpoint connects to DPU interface 1. The board must continue to keep the DPU/MDSS/DSI/PHY path disabled until the display enablement checklist is met.

## SFPB result — important target-specific qualification

The DSI host driver optionally looks up a `syscon-sfpb` phandle. A repository-wide search of `arch/arm64/boot/dts/qcom` found no `syscon-sfpb` property in the DTS sources. Therefore, for the current SM6225/SPES DT configuration, `msm_host->sfpb` is not populated and `msm_dsi_sfpb_config()` returns immediately without touching an SFPB register.

This means the generic driver's SFPB cleanup gaps recorded in Stage 121 do not currently represent an active SFPB resource leak for this target DT. Keep the generic cleanup observation in mind for other SoCs, but do not add a speculative SFPB syscon node or register mapping to SPES. The PM-reference and regulator cleanup defects remain relevant independently of SFPB.

## Clock and power-domain wiring

- DSI bus clocks are provided as a bulk group through the `bus` clock name and runtime resume enables them using `clk_bulk_prepare_enable()`.
- Link clocks are separate DSI clocks (`byte`, `byte_intf`, `pixel`, `core`/escape as interpreted by the host driver); the exact host configuration is selected at runtime from the DSI hardware version register, not from the DT compatible string alone.
- DSI OPP entries are 187.5, 300 and 358 MHz and reference RPM power-domain OPP levels low-SVS, SVS and SVS-plus respectively.
- `power-domains = <&rpmpd SM6115_VDDCX>` is present on DSI0; the DispCC provider is `qcom,sm6225-dispcc` and supplies the MDSS GDSC and DSI clock tree.
- Assigned byte and pixel clock parents point to DSI PHY outputs 0 and 1. Do not enable DSI0 without confirming PHY PLL and DispCC parent readiness.

## Runtime-PM implications

The DSI runtime-resume callback enables the declared bus-clock bulk. A failure here can leave DSI register access unavailable. The Stage 120 finding about unchecked PM acquisition remains valid. The focused Host power-on fix should address PM reference handling and regulator unwind; SFPB should be treated as optional/no-op on SPES unless future DTS evidence changes.

The `dsi_get_config()` path also calls `pm_runtime_get_sync()` without checking the result before enabling the interface clock and reading the hardware version. This is a probe/configuration-time risk distinct from the power-on path and needs a separate design because its helper currently returns a config pointer rather than a direct PM error.

## Validation / safety

- Static DTS and driver-source audit only; no source or DT changes.
- No rebuild, runtime test or hardware measurement.
- MDSS/DSI0/DSI PHY remain disabled; FPC remains disabled.
- No flash, Recovery ZIP or installable release artifact.
