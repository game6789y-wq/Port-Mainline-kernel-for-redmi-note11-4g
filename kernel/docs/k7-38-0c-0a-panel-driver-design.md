# K7 38-0C-0A Mainline DRM bridge driver design

Status: design only; not wired into SPES Device Tree and not enabled in Kconfig.

## Confirmed target

- Runtime active panel: `dsi_panel_k7_38_0c_0a_fhdp_video_display`.
- 1080x2400, 4-lane DSI video/burst, 24-bit input, DSC 1.1 pre-SCR, 8 bpc / 8 bpp, 540x20 slices, two slices per line, one slice per packet.
- Vendor dynamic refresh: 60 Hz and 90 Hz. Panel ON sequence selects 60 Hz (`0x60 = 0x21`). 90 Hz sequence writes `0x60 = 0x01`; both transitions use F1 unlock, register write, F7 `07`, F1 relock.
- Reset TLMM GPIO82; panel enable PM6125 physical GPIO9; separate LCM 1.8V enable TLMM GPIO54; TE GPIO81. GPIO99 is not an IRQ for this panel's `reg_read` ESD mode. ESD status is DCS `0x0A == 0x9D`.
- GPIO54/9 ownership is vendor-source evidence only. Board-level regulator/load-switch topology and safe Linux GPIO acquisition still need final review. Do not add a guessed L9 supply link.

## Driver architecture

Use a standalone `struct drm_bridge` registered against the panel node, rather than registering both a `drm_panel` and a bridge for the same node. `drm_of_find_panel_or_bridge()` checks for a panel first; if both were registered it would return the panel and `devm_drm_of_get_bridge()` would synthesize the generic panel bridge, bypassing the custom K7 bridge.

Suggested private structure:

- `struct drm_bridge bridge`
- `struct mipi_dsi_device *dsi`
- reset / panel-enable / LCM-1.8V-enable GPIO descriptors (only after DT ownership is confirmed)
- optional backlight handle
- mutex for panel power and command serialization
- `prepared`, `enabled`, `refresh_state_valid`, `current_refresh`, and `last_error` state

The custom bridge owns mode enumeration and panel sequencing. Its `get_modes` returns 1080x2400 60/90Hz modes; `mode_valid` rejects unsupported timings. Do not expose either mode until DPU/DSI clocks, DSC, pinctrl and power sequencing are validated.

## Atomic refresh-rate state

Do not use deprecated `drm_bridge_funcs.mode_set()` for a new driver. Implement a private subclass of `drm_bridge_state` with a `target_refresh` field. `atomic_check(bridge, bridge_state, crtc_state, conn_state)` validates the selected mode and stores its refresh in the per-commit bridge state. `atomic_enable(bridge, commit)` reads the new bridge state using `drm_atomic_get_new_bridge_state()` and sends the 60/90-Hz DCS sequence. This avoids mutable global target-mode state and handles concurrent atomic checks correctly.

The bridge must implement atomic state create/duplicate/destroy hooks if it implements atomic hooks. Use the DRM bridge helper duplication/destruction routines and copy the private refresh field explicitly.

## Power / command lifecycle

- `atomic_pre_enable`: enable verified external LCM rail and panel-enable control, apply reset sequence with vendor delays, configure DSI device mode flags, send vendor init command table and DSC PPS in the correct order. Keep all command packet boundaries, LP/HS flags and waits. Do not invent PPS bytes: derive from the validated upstream DSC helper and compare against vendor generated PPS.
- `atomic_enable`: after DSI host/encoder enable, program the selected refresh using HS DCS writes before first DPU kickoff. Record the new refresh only after every command succeeds. On failure mark refresh state unknown and log; no automatic retry or unsafe mode claim.
- `atomic_disable` / `atomic_post_disable`: stop panel output and sequence reset/enable/rail down in an order proven against the vendor path. Ensure host remains available for any required DCS display-off command.
- ESD: initially diagnostic/manual DCS status read only. Do not wire GPIO99 IRQ or implement automatic recovery until synchronization with disable/suspend/modeset is designed.

## Blocking prerequisites before code can be enabled

1. Map the SM6225 DPU/MDSS/DSI/PHY clocks, interconnects, OPP and power domains for SPES.
2. Confirm TLMM GPIO54, 81, 82 and PM6125 GPIO9 pinctrl/ownership and safe active/suspend electrical states.
3. Confirm 1.8V LCM rail/load-switch topology; no inferred `vddio-supply = <&pm6125_l9>`.
4. Implement/validate upstream DSC PPS generation and DSI host configuration for the two-slice K7 mode.
5. Translate the full K7 0A vendor init table with exact packet types, payloads, waits and HS/LP selection.
6. Verify atomic full-modeset behavior for 60/90 changes and transfer-failure policy.

No DT enablement, Kconfig selection, kernel build, flash, Recovery ZIP, release, commit or push is authorized by this design document.

## DSI command transport requirements (added at stage 86)

- The 45-packet ON sequence can use individual transfers because every descriptor has `last=1`; retain its DCS data type exactly and apply each descriptor wait after the packet.
- The OFF sequence has two independent DCS short writes: `0x28` + 10 ms, then `0x10` + 150 ms.
- Refresh changes are different: each four-packet sequence has `last=0,0,0,1` and the vendor queues all four packets into one command DMA submission. Four separate Mainline `mipi_dsi_device_transfer()` calls are not equivalent and permit interleaving between unlock/register/F7/relock.
- Proposed narrowly scoped interface: add optional `transfer_multi` to `struct mipi_dsi_host_ops` and a `mipi_dsi_device_transfer_multi()` helper in the MIPI-DSI core. The helper validates arguments and calls the host batch op. This implementation has no single-packet fallback and returns `-EOPNOTSUPP` when the host lacks native batching. Each `mipi_dsi_msg` carries the exact packet type, payload, channel and LPM flag; host batch implementation marks only the final DMA packet as last.
- MSM implementation should take `cmd_mutex` once for the complete array, check `power_on`, build each `mipi_dsi_packet` into the existing TX DMA buffer at an aligned offset, enforce `tx_size` and BLLP constraints on the combined transfer, and call `dsi_cmd_dma_tx()` once. Existing host allocates a 4 KiB TX buffer, while the K7 four-command refresh sequence is only a few dozen bytes, so capacity is ample. Keep the existing single-message path unchanged.
- On 6G hosts, the GEM virtual mapping is acquired/released around each append; the batch helper must preserve one common buffer base and offsets across appends. On V2 coherent buffer, the same base is already stable. Ensure DMA visibility and 4-byte padding for every packet before triggering the one transfer.
- The current MSM host `dsi_wait4video_eng_busy()` waits for video completion and skips the BLLP window before a transfer. The batch transfer should call this once for the whole sequence, not once per packet. The panel bridge must issue the batch before DPU `flush_commit` kickoff, with the host powered and `cmd_mutex` held for the entire sequence.

## MSM manager transaction envelope (added at stage 87)

- The MSM manager wraps every normal transfer in `msm_dsi_host_xfer_prepare()` / `msm_dsi_host_xfer_restore()`. Prepare obtains runtime PM and link clocks, selects HS vs LP from `msg->flags`, temporarily enables command mode and unmasks DMA completion; restore reverses these changes.
- A batch operation must therefore be one manager transaction as well as one DMA transaction: all messages must share the same virtual channel and transfer flags (K7 refresh packets are VC0, HS, write-only); prepare once using the common flags; append all messages; trigger one DMA; restore once. Reject mixed flags/channels and any read messages rather than silently changing semantics.
- Add `msm_dsi_manager_cmd_xfer_multi()` and `msm_dsi_host_cmd_tx_multi()` in MSM's private DSI layer; preserve bonded-link synchronization semantics or explicitly reject bonded hosts until implemented. SPES uses one DSI link, but the host API must not silently break other MSM configurations.
- The panel-facing `mipi_dsi_device_transfer_multi()` should be the only public entry point; it validates each message and dispatches to the optional host op. The K7 bridge checks that `host->ops->transfer_multi` exists and returns `-EOPNOTSUPP` if not.


## Batch transport implementation status (stage 88)

Implemented, compiled and linked (not yet used by a panel driver):

- `struct mipi_dsi_host_ops` now has optional `transfer_multi`; `mipi_dsi_device_transfer_multi()` validates write-only messages, checks the DSI virtual channel, applies the device LPM flag, validates packet construction, and returns `-EOPNOTSUPP` if native batching is unavailable.
- MSM DSI now appends packets at aligned offsets in the existing TX DMA buffer, sets the hardware last-packet flag only on the final packet, checks TX buffer capacity and aggregate BLLP length, and submits the entire array with one DMA trigger.
- The MSM transfer path holds `cmd_mutex` for the whole group and the manager performs one runtime-PM/clock/command-mode prepare and one restore. Mixed channels, flags, reads and bonded/synchronized links are rejected by this initial batch path.
- The K7 60/90 sequence is four DCS long-write messages; the panel driver must set the exact payloads and HS flags and call this helper. The ordinary single-message path remains unchanged.
- Full `Image modules` build passed with Exit Code 0; no matching warning/error diagnostics. This validates compilation and module linking only, not panel behavior or hardware.

## K7 command states and DSC attach timing (added at stage 90)

- K7 ON and OFF command tables are explicitly `dsi_lp_mode`. The 60/90 refresh command tables are explicitly `dsi_hs_mode`. The separate DSC PPS packet is `DTYPE_PPS`, VC0, last=1, 10 ms wait, and LP mode.
- The panel must keep global `MIPI_DSI_MODE_LPM` clear because it needs both LP initialization/PPS and HS refresh transactions. Send init/off messages with per-message `MIPI_DSI_MSG_USE_LPM`; send the four-message refresh batch with flags clear. Send PPS with per-message LPM (or temporarily set the device LPM flag only around the PPS helper).
- Set DSI mode to video + burst, 4 lanes, 
[... 11476 bytes omitted ...]
-1p2` from PM6125 L18A at 1.232 V and a separate `refgen` supply. Downstream DSI PHY requests `vdda-0p9` from PM6125 L4A at 0.88 V (36 mA). Khaje regulator overlay constrains L4A to 0.72–1.05 V/init 0.88 V and L18A to 1.10–1.30 V/init 1.232 V. These are the correct *vendor board reference* values, but still need to be connected to the mainline consumer interfaces carefully.
- Mainline SM6225 DSI host matches the SDM845 DSI config for base 0x5e94000, whose regulator list requests `vdda` and `refgen`; the SPES board currently has neither `vdda-supply` nor `refgen-supply` on `&mdss_dsi0` and its PM6125 RPM node has no L18 rail entry. Therefore the current mainline DSI host regulator acquisition is not yet board-complete.
- Mainline `qcom,sm6375-dsi-phy-7nm` selects `dsi_phy_7nm_6375_cfgs`, which currently has no regulator_data entry, despite the downstream Khaje PHY declaring external 0.9 V `vdda-0p9`. The mainline PHY driver currently does not request a `vdds` rail for this compatible. Do not simply add a DT `vdds-supply` and assume it is consumed; this needs a deliberate PHY-driver/compatible review or confirmation that the SoC PHY's own supply arrangement is correct.
- Downstream `qcom,refgen-kona-regulator` is not an upstream compatible in `drivers/regulator/qcom-refgen-regulator.c`; upstream supports IPQ9650, SDM845 and SM8250 refgen variants. Do not add the downstream compatible to the SPES mainline DT without a supported provider driver. The host's `refgen` supply therefore remains an unresolved provider dependency.
- The current board has no PM6125 L4/L18 nodes. A comparable SM6225 board has L4=0.9V and L18=1.2V rail entries and uses them for UFS/CSI, but this does not prove SPES board consumers or power-tree topology. No new L4/L18 consumer or regulator entries were added in this stage.

Stage 97 decision:

- Pixel/byte/PLL/OPP rates are structurally within the existing mainline limits for fixed 90 Hz.
- Do not enable MDSS/DSI/PHY or alter regulator graph yet. Missing/unsupported DSI host `vdda`/`refgen` provider mapping and the 7-nm PHY external 0.9 V supply discrepancy must be resolved first, then full DT schema and clock/power sequencing validated.
- No source/DTS edits or rebuild in Stage 97. No panel enablement, module staging, Recovery ZIP, flash, release, commit or push.

## Mainline REFGEN provider and DSI controller L18 supply wiring (stage 98)

- Inspected the downstream Khaje `qcom,refgen-kona-regulator` implementation: it toggles bit 0 at REFGEN register offset 0x80 to enable/disable and reads the same bit for state. Upstream `qcom,sm8250-refgen-regulator` uses the same register, mask and enable/disable values. The existing upstream provider is therefore an exact register-operation match for this Kona REFGEN block.
- Added a SPES REFGEN provider at SoC address 0x01600000 size 0x84 using `compatible = "qcom,sm8250-refgen-regulator"`, with 5ms ramp delay. No downstream-only proxy properties or self-referential proxy supply were copied.
- Added PM6125 L18 as fixed 1.232 V with adjustable load and wired DSI controller `vdda-supply` to L18 and `refgen-supply` to the REFGEN provider. This matches Khaje's vendor `vdda-1p2-supply = <&L18A>` at 1.232 V and separate refgen consumer.
- DSI host provider is a built module (`qcom-refgen-regulator.ko`, CONFIG_REGULATOR_QCOM_REFGEN=m) with OF alias for `qcom,sm8250-refgen-regulator`.
- Target SPES DTB compiles without DTC warnings/errors. `dt-doc-validate` passes for the upstream REFGEN schema. Effective DTB still has MDSS/DSI0/PHY disabled; no rail is requested by the dormant host.

## Mainline SM6375-compatible 7nm PHY 0.9V supply integration for SPES (stage 99)

- Downstream Khaje panel stack explicitly supplies the 7nm DSI PHY from PM6125 L4A at 0.88 V and 36 mA. Upstream `qcom,dsi-phy-7nm.yaml` already defines `vdds-supply` for the 0.9V PHY rail, but `dsi_phy_7nm_6375_cfgs` previously had no regulator_data and therefore did not acquire or enable this supply.
- Added the existing 36mA 7nm PHY regulator descriptor to `dsi_phy_7nm_6375_cfgs`; this uses the driver's standard `vdds` supply name and 36mA load, matching the vendor board requirement.
- Added PM6125 L4 to SPES at fixed 0.88 V with adjustable load and wired `&mdss_dsi0_phy` `vdds-supply` to it. The SM6375-compatible PHY is only used by the SM6225 SoC DTS in this source tree, so the config change is scoped to the target implementation rather than changing a shared PHY config used by other SoCs.
- `make modules` completed Exit Code 0; MSM DRM module linked with updated PHY object and expected `qcom,sm6375-dsi-phy-7nm` OF alias. No compiler/modpost diagnostics.
- Target SPES DTB compiled Exit Code 0, no DTC warnings/errors. `dt-doc-validate` passes for the 7nm PHY, SM6375 MDSS, REFGEN and K7 panel bindings. Effective DTB confirms MDSS/DSI0/PHY0 remain disabled.
- Remaining: actual board electrical/rail measurement, REFGEN lock/ready verification, DSI PHY PLL lock, panel PPS and init sequence on hardware. Full `dt_binding_check` is still blocked by installed dtschema 2024.4 internal `bool.pop` error. No display enablement, hardware boot, module staging, Recovery ZIP, flash, release, commit or push.

## Targeted DTBS schema check limitation (stage 100)

- `dt-doc-validate` passed individually for the REFGEN, 7nm DSI PHY, SM6375 MDSS and K7 panel schemas.
- Targeted `make dtbs_check` for these schemas fails before any DTB validation while generating `Documentation/devicetree/bindings/processed-schema.json`: dtschema 2024.4 raises `AttributeError: 'bool' object has no attribute 'pop'` in `fixup_schema()`. This reproduces the earlier global schema-tool failure and is not a DTC parse error.
- `W=1` compile of `drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.o` passes. Full `make modules` from Stage 99 exited 0. Target SPES DTB DTC build exited 0 with no warnings/errors. `git diff --check` passes.
- No change to display enablement decision: MDSS/DSI0/PHY0 remain disabled; hardware bring-up is still pending.

## Display power-domain, runtime-PM and performance-vote audit (stage 101)

Power-domain topology:

- MDSS top node owns DispCC `MDSS_GDSC`; `mdss_gdsc` is at DispCC offset 0x1004, `PWRSTS_OFF_ON`, `HW_CTRL`. DPU child and DSI0 child each request RPM `SM6115_VDDCX`; the SoC's `qcom,sm6115-rpmpd` provider exposes the matching VDDCX index and OPP levels. DSI PHY is a child of MDSS and uses its own runtime-PM `iface` clock plus the newly wired 0.9V regulator; it has no separate RPM power-domain property in the current SoC model.
- MDSS runtime resume first votes minimum MDP memory and register-bus bandwidth, then enables its clock bulk. DPU and DSI children are populated under MDSS; Linux runtime-PM parent/child ordering keeps the MDSS parent active while children are active. This is the expected layering for the GDSC and parent clocks, subject to hardware verification.
- DSI PHY runtime resume enables its `iface` clock via `pm_clk`; `msm_dsi_phy_enable()` then enables the 36mA `vdds` rail before running PHY PLL/enable operations. DSI host runtime resume separately enables its bus clocks; host rate setup applies DSI byte-clock OPP before pixel clock programming.
- DispCC's `MDSS_GDSC` is registered by the SM6225 DispCC driver. DispCC clock parents reference PHY output clocks while PHY requests DispCC AHB; clock registration is lazy and `qcom_cc_really_probe()` does not eagerly acquire those parent clocks, so this is not by itself a probe-time dependency cycle. PHY can defer on its `iface` input until DispCC has registered; then probe can complete. This remains a runtime probe-order item to check in dmesg.

Performance recalculation (important correction to stage 97):

- The 339.702 MHz figure is the DSI/panel pixel clock, not the DPU core performance clock request.
- Mainline DPU `_dpu_core_perf_calc_clk()` starts from `vtotal * hdisplay * vrefresh`, then applies the SM6225 catalog `clk_inefficiency_factor = 105`. For the K7 90Hz mode this is `2432 * 1080 * 90 * 1.05 = 248.210 MHz` (before any higher plane-specific clock requirement). Thus the normal mode-only DPU request should round up to the 300 MHz DPU OPP, requiring `rpmpd_opp_svs`, not the 383 MHz OPP. Scaling/plane fetch may request more and is calculated at runtime.
- DPU OPPs: 19.2 MHz -> min-SVS; 200 MHz -> low-SVS; 300 MHz -> SVS; 383 MHz -> SVS+; 470 MHz -> nominal; 560 MHz -> turbo. The DPU OPP table and `disp_cc_mdss_mdp_clk_src` frequency table align at these performance points. The 248.21 MHz mode-only request is within the 300 MHz point.
- DSI OPP is based on the compressed DSI byte clock, not pixel clock. Correction from Stage 103: the earlier 84.9255MHz byte-clock estimate omitted the DSI host horizontal-total adjustment and is superseded. The corrected host-derived byte clock is approximately 136.581MHz; `dev_pm_opp_set_rate()` still selects 187.5MHz / low-SVS.
- SM6225 DPU catalog sets `min_dram_ib = 1.6 GB/s`, `bw_inefficiency_factor = 120%`, `max_bw_low = 5.2 GB/s`, and `max_bw_high = 6.2 GB/s`. For a simple full-screen XRGB8888 1080x2400@90 scanout, raw frame fetch is approximately 0.933 GB/s and the 20% inefficiency factor gives approximately 1.12 GB/s average; the catalog's 1.6 GB/s minimum peak vote is above this simple estimate. Actual vote is calculated from plane fetch format, scaling and composition at runtime; do not hardcode a new bus vote from this estimate.
- DPU code applies bandwidth vote before increasing the core clock, and releases bus bandwidth after commits. MDSS establishes minimum bus votes before enabling AXI clocks. This ordering is correct structurally.

Stage 101 decision:

- Existing MDSS GDSC, VDDCX power-domain, DPU OPP, DSI OPP, DSI PHY runtime-PM and ICC wiring is structurally coherent for a first controlled bring-up.
- Corrected DPU expected mode-only OPP: 300 MHz (SVS), not 383 MHz; 339.702 MHz remains the panel/DSI pixel clock. This corrects the rough comparison in Stage 97; no OPP table change is needed.
- Do not enable display yet. Remaining prerequisites are hardware confirmation of MDSS GDSC power state, VDDCX/rail behavior, DSI PHY PLL lock, DPU/DSI runtime-PM probe sequence, DSC/PPS delivery and first-frame/TE behavior. No hardware boot/test was run in this stage.

## Stage 102 — SM6375 7nm DSI PLL audit

- Confirmed the board-compatible PHY match is `qcom,sm6375-dsi-phy-7nm`, selecting `dsi_phy_7nm_6375_cfgs` with V4.1 quirks, one PHY instance at 0x05e94400, and the SM6375 regulator descriptor (36mA) for the 0.9V analog rail.
- The upstream 7nm PLL implementation programs the VCO decimal/fractional divider from the requested VCO rate using the 19.2MHz reference (`divider = 2 * VCO_REF_CLK_RATE`); SSC is disabled by default.
- The SM6375 configuration advertises a 600MHz minimum and 5GHz maximum VCO rate on 64-bit builds. This is a VCO operating range, not a direct statement of the DSI lane bit-rate range. The corrected Stage 103 estimate is 1.09265Gbps/lane and cannot be declared hardware-validated from the VCO min/max alone.
- PLL start waits for `REG_DSI_7nm_PHY_PLL_COMMON_STATUS_ONE[0]` using atomic polling at 100us intervals with a 5ms timeout. Failure logs the status register and aborts prepare; global PHY clocks are enabled only after lock succeeds.
- The mode-derived 339.702MHz uncompressed pixel clock and Stage 103 corrected 136.581MHz byte clock / 1.09265Gbps lane-rate estimates remain analytical. No live PLL register readback or lock measurement is possible while MDSS/DSI/PHY are disabled.
- No source or DTS changes in Stage 102. No rebuild required. Keep MDSS, DSI0 and DSI PHY disabled until the first controlled hardware validation can verify PLL lock, lane timing and panel response.


## Stage 103 — Correct DSC-adjusted DSI clock calculation

- Re-read `dsi_adjust_pclk_for_compression()` and `dsi_byte_clk_get_rate()` in `drivers/gpu/drm/msm/dsi/dsi_host.c`; the previous estimate incorrectly treated the compressed bpp as if it replaced the host's RGB888 input format in the byte-clock formula.
- For 1080x2400@90Hz with DSC bpp=8 and RGB888 host format: compressed active width = ceil(1080*8/(8*3)) = 360; adjusted horizontal total = 1552 - 1080 + 360 = 832.
- Host-adjusted pixel clock = floor(339702000*832/1552) = 182108288Hz.
- Host byte clock = floor(182108288*24/(8*4)) = 136581216Hz (136.581216MHz). Corresponding per-lane bit clock estimate = 1.092649728Gbps. This replaces the earlier 84.926MHz / 679.404Mbps estimates.
- The DSI OPP table's 187.5MHz low-SVS entry remains the first OPP above 136.581MHz, so the selected OPP conclusion does not change. The PHY VCO rate and divider programming must be confirmed from actual clock-tree rate propagation/readback; the VCO min/max range alone does not validate the lane rate.
- No source or DTS changes and no rebuild in Stage 103. Display nodes remain disabled; no live PLL or panel test.

## Stage 104 — DSI clock programming path audit

- Confirmed the SM6115 DSI host uses the 6G clock path: `dsi_link_clk_set_rate_6g()` rounds the calculated byte clock, requests the matching DSI OPP with `dev_pm_opp_set_rate()`, then sets the pixel clock and byte-interface clock where present.
- For the corrected 136.581216MHz byte clock, the 187.5MHz OPP is still the first available OPP at/above the request. The DSI pixel clock request is 182.108288MHz after DSC horizontal-total adjustment.
- The PHY clock provider exposes byte clock as VCO / output divider / bit divider / 8 and pixel clock through the DSI clock mux and pixel divider. The exact VCO and divider tuple is selected by Common Clock Framework rate propagation; it must be checked from actual `clk_summary` and PLL register readback after a controlled boot.
- SM6375 V4.1 uses `msm_dsi_dphy_timing_calc_v4()` in the 7nm PHY enable path. The timing values are calculated from the requested PHY clock rate at runtime; no vendor timing blob should be copied.
- The 1.09265Gbps/lane estimate is below the driver's 1.5Gbps branch threshold for PHY strength programming, but that code branch is not a guarantee of signal integrity on the physical board.
- No source/DTS changes or rebuild in Stage 104. MDSS/DSI0/PHY remain disabled. Hardware PLL lock, clock divider readback, timing and first-frame behavior remain unverified.

## Stage 105 — DSC 1.1 PPS and packetization audit

- Confirmed the vendor K7 38-0C-0A DTS specifies DSC, slice height 20, slice width 540, one slice per packet, 8bpc, 8bpp and block prediction enabled.
- The Mainline panel config matches those static parameters: DSC 1.1, 1080x2400 picture, two 540x20 slices, 8bpc, fixed-point bpp `8 << 4`, block prediction enabled.
- The SM6115 DSI host attach path defaults to one slice per packet unless `MIPI_DSI_MODE_DSC_ALL_SLICES_IN_PKT` is set. The K7 driver does not set that flag, matching vendor `slice-per-pkt = 1`.
- `dsi_timing_setup()` runs during the DSI host bridge pre-enable. With the panel bridge's `pre_enable_prev_first = true`, the DSI host is pre-enabled before the panel bridge. The host fills `pic_width`, `pic_height`, RC parameters, line buffer depth and `slice_chunk_size` before `k7_send_pps()` executes.
- For 540px at 8bpp, `drm_dsc_compute_rc_parameters()` yields `slice_chunk_size = 540` bytes. Two slices produce 1080 compressed bytes per active line, packetized as two 540-byte packets (one slice per packet); EOL byte remainder is zero.
- `drm_dsc_pps_payload_pack()` produces the 128-byte DSC PPS payload in sink-required big-endian field order. The panel sends DSI data type `MIPI_DSI_PICTURE_PARAMETER_SET` (0x0A) in LP mode after the vendor ON command table, then waits 10ms, matching the vendor PPS sequencing notes.
- Static configuration and software ordering are internally consistent. The vendor source does not provide an independently captured expected 128-byte PPS blob in this DTS, so byte-for-byte comparison against a known-good PPS and actual sink acceptance remain unverified. No hardware test.
- No source/DTS changes and no rebuild in Stage 105. MDSS, DSI0 and DSI PHY remain disabled.

## Stage 106 — SM6225 DPU DSC block and two-slice audit

- Confirmed `qcom,sm6225-dpu` maps to `dpu_sm6225_cfg` (DPU 6.10) and catalog exposes one DSC encoder block (`dsc_0`).
- Mainline DPU encoder topology selects one DSC encoder when there is one interface and fewer than two DSC blocks. Its DSC programming path sets `num_active_slice_per_enc = dsc->slice_count` unless multiplex mode is used; therefore one DSC block is configured to process both 540px slices for the 1080px frame.
- DPU DSC register programming uses the same `drm_dsc_config` filled by the DSI host, including picture size 1080x2400, slice size 540x20, chunk size 540 bytes, 8bpc, 8bpp and block prediction.
- The DPU catalog max line width is 2160, above the 1080px active width. Structurally the one-encoder/two-slice path is supported by the generic DPU code.
- This is a software/catalog compatibility audit only. It does not validate the SM6225 silicon's DSC encoder behavior, DPU-to-DSI data path, bandwidth margin or panel acceptance. Keep display nodes disabled until hardware tests.
- No source/DTS changes and no rebuild in Stage 106.

## Stage 107 — DPU legacy DSC programming and soft-slice audit

- SM6225 DPU catalog core major version is 6, so resource management instantiates the legacy DPU DSC programming block (`dpu_hw_dsc_init()`), not the DPU 1.2-specific helper.
- The legacy block programs DSC bpp in 6.4 format, block prediction, line buffer depth, picture size, slice size, chunk size, RC delays, offsets, thresholds and range tables from the same host-populated DRM DSC config.
- `dpu_encoder_prep_dsc()` computes `this_frame_slices = 1080 / 540 = 2`; with one DPU DSC engine, `enc_ip_w = 1080`, so `soft_slice_per_enc = 2`. The initial-line calculation explicitly accounts for the extra sub-stream-multiplexer delay when more than one soft slice is assigned to an encoder.
- The DPU config routine has no explicit slice-count register; the two-slice operation is represented by the 540px slice width and 1080px encoder input width, with software initial-line handling. This supports the software path but is not a silicon validation.
- The earlier Stage 106 statement that the engine is configured for two active slices should be read as the software two-soft-slice path, not as a literal hardware slice-count field.
- No source/DTS changes and no rebuild in Stage 107. Display graph remains dormant; hardware test still required.

## Stage 108 — DPU DSC → PingPong → Interface → DSI kickoff audit

- SM6225 catalog exposes exactly one `PINGPONG_0`, one `DSC_0`, one `LM_0` and `INTF_1` wired to DSI controller 0. The DPU encoder mode-set path obtains the single assigned PP and DSC resources and stores them at index 0; the physical video encoder uses that PP and its CTL.
- During `prepare_for_kickoff`, the DPU encoder configures DSC from the DSI host's shared `drm_dsc_config`: DSC block registers and RC thresholds are programmed, PingPong data endian swap is set, DSC is bound to `PINGPONG_0`, and `PP_DSC_MODE` is enabled. The DSC block is added to CTL pending flush.
- The video physical encoder configures INTF timing and marks the INTF flush. The CTL v1 path writes `CTL_DSC_FLUSH` with the DSC_0 bit, writes `CTL_INTF_FLUSH` for INTF_1, then writes aggregate `CTL_FLUSH`. The encoder kickoff then triggers `CTL_START` after flush; DSI host video mode is enabled through the DSI manager bridge.
- This confirms a coherent software path for one DSC block / one PingPong / one DSI interface. It does not prove that silicon routing, DSI PHY link, or panel timing works on the physical SPES board.
- Important test gate: the first controlled hardware boot must capture DPU CTL flush masks, DSI video-done/underrun interrupts, DSI PHY PLL lock and panel response. Do not enable the graph as a blind source change.
- No source/DTS changes and no rebuild in Stage 108. MDSS, DSI0 and PHY remain disabled.