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
- Set DSI mode to video + burst, 4 lanes, RGB888. Do not set `MIPI_DSI_MODE_DSC_ALL_SLICES_IN_PKT`: vendor uses one DSC slice per packet (`slice_per_pkt=1`). Do not disable EoT because vendor explicitly appends EoT packets.
- Set `dsi->dsc` before `mipi_dsi_attach()`: DSC 1.1 pre-SCR, 8 bpc, `bits_per_pixel = 8 << 4`, slice 540x20, slice_count=2, block prediction enabled. The MSM DSI host attach stores this pointer.
- The MSM host calls `dsi_populate_dsc_params()` from its timing setup after the adjusted DRM mode is installed. It fills `pic_width`/`pic_height`, line buffer depth, RC model, transmit/decoder delay, scale values and computed BPG/RC parameters. Because the DSI manager pre-enable powers/configures the host before the downstream panel bridge pre-enable (`pre_enable_prev_first=true`), the panel bridge can pack the fully populated `dsi->dsc` into PPS during its pre-enable callback.
- Use `drm_dsc_pps_payload_pack()` on the computed `dsi->dsc`, then transmit a 128-byte `MIPI_DSI_PICTURE_PARAMETER_SET` message in LP mode and wait 10 ms. The PPS is separate from the 45-packet ON table and follows it, as in the vendor implementation.

## DRM bridge shutdown ordering and initial refresh scope (added at stage 91)

- With panel bridge after MSM DSI manager bridge and `pre_enable_prev_first=true`, atomic pre-enable runs DSI host first, then K7 panel. Atomic disable runs in reverse chain order, so K7 panel receives `.atomic_disable()` before encoder disable. Atomic post-disable normally runs forward, but the panel bridge's `pre_enable_prev_first` causes its `.atomic_post_disable()` to run before the previous DSI manager bridge's `.atomic_post_disable()`. Thus K7 can send DCS display-off/sleep-in while host is still active, then sequence reset/enable/LCM rail down before MSM DSI host is disabled and PHY powered off.
- The exact intended callbacks are: `.atomic_pre_enable()` power/reset/init/PPS; `.atomic_enable()` HS refresh selection before DPU kickoff; `.atomic_disable()` DCS off sequence; `.atomic_post_disable()` panel reset/enable/rail shutdown. Host/encoder ordering is source-confirmed.
- A 60-to-90 or 90-to-60 change represented as a normal full modeset will invoke disable/post-disable and pre-enable/enable; the panel will power-cycle and run its full initialization sequence. This can be used for initial functional testing but is not seamless dynamic refresh and may visibly blank the screen.
- Initial bring-up should expose only one fixed mode (prefer 90 Hz once the 90 Hz clock/PHY path is validated) and keep the refresh-batch code available but unused, or explicitly document full-power-cycle switching if both modes are temporarily exposed. Do not advertise seamless 60/90 until an MSM/DPU pre-kickoff hook is added for refresh-only commits.

## SPES GPIO and DCS backlight details (added at stage 92)

- Mainline SPES includes `pm6125.dtsi`, whose PM6125 SPMI GPIO provider is `qcom,pm6125-gpio` with nine GPIOs. Use physical PMIC GPIO9 in the DT specifier (`<&pm6125_gpios 9 GPIO_ACTIVE_HIGH>`); the upstream SPMI GPIO translator handles the physical-to-chip offset.
- Vendor K7 panel enable is PM6125 physical GPIO9, active high. The separate LCM 1.8V enable is TLMM GPIO54, active high. Vendor pinctrl active state: GPIO mode, 2 mA, pull-up, output-high; suspend state: GPIO mode, 2 mA, pull-down, output-low. Do not model GPIO54 as PM6125 L9 regulator supply.
- Reset is TLMM GPIO82, with vendor sequence high 10 ms, low 10 ms, high 10 ms. Active pad setting is GPIO mode, 8 mA, no pull; suspend uses 2 mA pull-down. The Mainline SM6115 TLMM pinctrl supports GPIO54 and GPIO82. The panel driver should own these states on the panel node and select active/suspend at panel power transitions.
- Vendor modern Techpack confirms DCS brightness uses a 16-bit brightness value and `bl_inverted_dbv` swaps its two bytes: `((level & 0xff) << 8) | (level >> 8)`. K7 max brightness is 2047, min 1, DCS backlight. The legacy framebuffer helper's one-byte `0x51` path is not the authoritative modern implementation; port the 16-bit behavior.
- PM6125 GPIO provider exists in Mainline, but the external LCM 1.8V electrical rail/load switch still lacks schematic proof. The GPIO54 active/suspend state is vendor-source evidence; keep L9 disconnected from panel supply until proven.

## TE source and brightness helper mapping (added at stage 93)

- Vendor Khaje pinctrl selects GPIO81 function `mdp_vsync` in both active and suspend states, 2 mA with pull-down. Vendor does not set `qcom,te-source` on the K7 panel endpoint. Mainline DPU defaults to `DPU_VSYNC_SOURCE_GPIO_0` (`mdp_vsync_p`) when that property is absent. Keep the endpoint property absent and mux TLMM GPIO81 to `mdp_vsync`; do not invent a non-existent `qcom,te-source` string.
- Mainline `mipi_dsi_dcs_set_display_brightness_large()` transmits the 16-bit value big-endian. This exactly matches modern Vendor Techpack's `bl_inverted_dbv` byte-swap followed by its little-endian `mipi_dsi_dcs_set_display_brightness()` helper. Therefore the K7 backlight driver can call the Mainline `*_large()` helper directly with the logical 0..2047 level; do not byte-swap a second time.
- Brightness updates must be deferred while the panel is unprepared/disabled and applied after panel enable. The backlight interface should expose min 1 and max 2047; zero remains the off/blank state.

## Initial K7 fixed-90-Hz bridge driver implementation (stage 94)

Implemented source (not enabled in SPES DTS):

- `drivers/gpu/drm/panel/panel-k7-38-0c-0a.c` is a standalone DRM bridge, not a `drm_panel`, to preserve per-commit refresh state and own the required callback ordering.
- Embeds the exact 570-byte / 45-packet vendor ON command table and the exact two-packet OFF table. It validates descriptor lengths/VC/ACK/last flags and preserves each packet type and wait. The ON array was programmatically compared byte-for-byte with the Vendor DTS.
- Configures `dsi->dsc` before attach for DSC 1.1, 8bpc/8bpp, 540x20, two slices, block prediction. Panel pre-enable packs the computed host-populated DSC config into a 128-byte PPS and sends it in LP mode after the ON table.
- Uses per-message LP for init/off/PPS, HS for the four-packet 90-Hz sequence through native `mipi_dsi_device_transfer_multi()`, and 16-bit DCS brightness through `mipi_dsi_dcs_set_display_brightness_large()` (temporarily LP).
- Uses PMIC `enable-gpios` for physical GPIO9, TLMM `reset-gpios` GPIO82, and `default`/`sleep` pinctrl states for GPIO54 LCM 1.8V enable, GPIO82 reset pad and GPIO81 MDP_VSYNC. No PM6125 L9 regulator link is added.
- Exposes only a fixed 1080x2400 90-Hz mode (clock 339702 kHz, H total 1552, V total 2432). It intentionally does not expose 60 Hz or claim seamless switching. It implements panel off/power-down callback order and a fail-safe panel shutdown if the 90-Hz command batch fails.
- Added `CONFIG_DRM_PANEL_XIAOMI_K7_38_0C_0A` and Makefile integration, plus binding `Documentation/devicetree/bindings/display/panel/xiaomi,k7-38-0c-0a.yaml`.

Verification:

- `W=1` panel object compilation passed.
- `make modules` exited 0; `panel-k7-38-0c-0a.ko` linked, has OF aliases for `xiaomi,k7-38-0c-0a`, and modpost resolved the exported `mipi_dsi_device_transfer_multi` symbol. No matching compiler warning/error or modpost diagnostic.
- `dt-doc-validate` passes for the new binding. `dt_binding_check` remains blocked before processing this binding by the installed dtschema 2024.4 internal error (`AttributeError: 'bool' object has no attribute 'pop'`), previously encountered on the full schema set. Do not claim full schema/example validation.

Remaining before enabling: inspect bridge probe/attach ordering on a real DT, verify the GPIO54/PMIC9 electrical behavior and DSI PHY/90-Hz clocks, verify PPS and panel-on sequence on hardware, and decide ESD diagnostic integration. No panel node or display `status = "okay"` has been added; no module staging, flash, Recovery ZIP, release, commit or push.

## Safe default pinctrl correction (stage 95)

- Linux device core automatically selects the `default` pinctrl state before the panel driver's probe callback. Therefore `default` must not drive GPIO54 high. The binding now requires three states: `default` (safe/low), `active` (GPIO54 high with active reset/TE pad configuration), and `sleep` (safe/low). The driver explicitly selects `active` only in panel pre-enable and selects `sleep` at probe and post-disable.
- This prevents the LCM 1.8V enable from briefly asserting merely because the DSI child device was probed. GPIO9 panel-enable and GPIO82 reset remain requested output-low initially.
- `dt-doc-validate` passes. Full `make modules` after this correction exited 0 and linked the updated panel module. No panel DTS node is present yet.

## SPES board-level K7 panel graph added without enabling display (stage 96)

- Added K7 pinctrl groups to `sm6225-xiaomi-spes.dtsi`: GPIO54 default/sleep low and active high; GPIO82 reset active 8mA/no-pull and sleep 2mA/pull-down; GPIO81 `mdp_vsync` 2mA/pull-down in active/sleep.
- Added the K7 panel child under `&mdss_dsi0` with `compatible`, `reg=<0>`, PM6125 physical GPIO9 `enable-gpios`, TLMM GPIO82 `reset-gpios`, and the required default/active/sleep pinctrl states. Added reciprocal panel/DSI0 graph endpoints and explicit four-lane mapping.
- Critically, no `status = "okay"` was added. Effective compiled DTB inspection confirms MDSS parent, DSI0 and DSI PHY0 all remain `status = "disabled"`; therefore the panel driver cannot probe and GPIO54/PMIC9 will not be driven by this disabled display graph.
- Target DTB compiled with DTC, Exit Code 0, no DTC warning/error. `dt-doc-validate` passes. Full `dt_binding_check` remains blocked by the dtschema 2024.4 internal error described above.
- DTB SHA256 after adding the dormant panel graph: recorded in build manifest. No runtime hardware test or display enablement.

## SM6225/Khaje display clocks, OPP and analog-rail audit (stage 97)

Clock-rate calculation for the fixed K7 mode (1080x2400, H total 1552, V total 2432, 90 Hz, DSC 8 bpp, four DSI data lanes):

- Pixel clock: 339.702 MHz (matches the mode clock in the K7 driver).
- Mainline `dsi_byte_clk_get_rate()` computes the DSC-adjusted host pixel clock times RGB888 bpp divided by (8 * lanes); the corrected result is 136.581216 MHz (Stage 103).
- The prior 679.404Mbps/lane estimate is superseded by Stage 103. The corrected host-derived estimate is 1.09265Gbps/lane; the PHY VCO min/max does not itself validate this lane rate.
- Mainline DSI OPP table has 187.5, 300 and 358 MHz. Mode validation uses `dev_pm_opp_find_freq_ceil()` on byte clock; 84.93 MHz is covered by the first 187.5 MHz OPP. Runtime DSI host uses `dev_pm_opp_set_rate()` on the byte clock.
- Mainline DPU OPP table has 19.2, 200, 300, 383, 470 and 560 MHz; 339.7 MHz is below its 383 MHz level and 560 MHz maximum. This is a structural rate check, not a measured PLL lock or bandwidth test.
- `dispcc-sm6225.c` has the expected MDSS byte0, pixel0 and MDP clock objects; SM6225 SoC DTS already wires DSI byte/pixel sources to DSI PHY output clocks and the display controller to the MDSS clocks. The SoC-level display graph has a coherent upstream clock topology.

Analog supply findings / blockers:

- The active downstream SPES overlay is `spes-khaje-idp-nopmi-overlay.dts`, with MSM ID 518, board ID 0x20022 and PMIC ID 0x2D. It includes the Khaje IDP display stack.
- Downstream Khaje DSI controller requests `vdda-1p2` from PM6125 L18A at 1.232 V and a separate `refgen` supply. Downstream DSI PHY requests `vdda-0p9` from PM6125 L4A at 0.88 V (36 mA). Khaje regulator overlay constrains L4A to 0.72–1.05 V/init 0.88 V and L18A to 1.10–1.30 V/init 1.232 V. These are the correct *vendor board reference* values, but still need to be connected to the mainline consumer interfaces carefully.
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

## Stage 109 — DSI video-mode, panel initialization and first-kickoff ordering

- DRM atomic helper order in this tree is: CRTC atomic enable → bridge-chain pre-enable → encoder atomic enable → bridge-chain atomic enable. The K7 bridge sets `pre_enable_prev_first`, so the DSI manager host pre-enable runs before the panel pre-enable.
- DSI manager pre-enable powers the DSI host/PHY and enables the host video-mode control. The K7 panel pre-enable then asserts LCM enable/reset, sends the vendor ON command table, sends the 128-byte PPS in LP mode, and waits 10ms. The DPU encoder atomic-enable configures/enables its timing path; K7 bridge atomic-enable then submits the 90Hz HS command batch. DPU KMS `flush_commit` calls `dpu_crtc_commit_kickoff()` after the modeset-enable stage, which runs encoder prepare/kickoff and CTL flush/start. Thus panel ON/PPS and refresh selection are ordered before the first DPU kickoff in the standard MSM commit path.
- While video mode is selected, MSM DSI command transfer temporarily enables command mode and restores the saved DSI control afterward. If the video engine is busy, the host waits for VIDEO_DONE (70ms timeout) and a 2–4ms BLLP guard. Single commands and grouped transfers are rejected if their encoded byte count exceeds one horizontal blanking period; the K7 PPS is 128 bytes and the four-command refresh batch is checked as one group.
- Known limitation: DRM bridge `atomic_pre_enable` / `atomic_enable` callbacks are `void`. If K7 power-on, ON-table or PPS transfer fails, the driver records `last_error` and powers the panel down; the later K7 atomic-enable avoids refresh writes, but the generic DRM commit path has no return channel here to veto DPU kickoff. This must be treated as a controlled-test failure condition, not as successful panel initialization.
- The host video-mode bit being enabled before panel initialization is intentional in the current bridge order to establish the DSI link state; command transfers use the host's video/BLLP wait path. Whether the physical SM6225 controller and K7 panel tolerate the complete sequence is still a hardware test requirement.
- No source/DTS changes and no rebuild in Stage 109. MDSS, DSI0 and PHY remain disabled.

## Stage 110 — K7 shutdown, DSI error handling and ESD-read gap

- Normal shutdown order is coherent: K7 bridge `atomic_disable` sends the vendor OFF table while DSI host is still available; K7 `atomic_post_disable` then asserts reset low, disables panel-enable GPIO9 and selects sleep pinctrl; because `pre_enable_prev_first` also changes post-disable ordering, DSI host bridge post-disable/power-off follows the panel.
- The K7 driver has no ESD/health worker and does not issue DCS register read 0x0A. Vendor K7 configuration expects status 0x9D, so the known panel ESD check is not implemented.
- MSM DSI host supports command RX, but its response parser returns zero for ACK/error or invalid response packets; callers must validate the expected response byte explicitly. No K7 caller currently performs that check.
- DSI controller error IRQ records PLL-unlocked, FIFO, ACK, timeout, status and lane-0 PHY errors. The worker currently software-resets only for MDP FIFO underflow, logs the collected state and re-enables the error IRQ. It does not automatically recover PLL unlock / lane errors or panel ESD.
- Recommendation for a later implementation: add a serialized, cancellable K7 status-read worker using DCS 0x0A and require exactly one returned byte equal to 0x9D; suspend it before OFF/power-down; report mismatch/read failure without an unsafe blind reset. Recovery policy must be designed and hardware-tested separately.
- No source/DTS changes and no rebuild in Stage 110. MDSS, DSI0 and PHY remain disabled; ESD/first-frame behavior remains unverified.

## Stage 111 — K7 ESD read semantics and safe worker lifecycle

- The generic `mipi_dsi_dcs_read()` constructs a one-byte DCS read request and returns the host transfer result. For a one-byte short response, the MSM parser copies response byte 1 into the caller buffer and returns exactly `1`; callers must reject every other return value and compare the byte to the vendor expected status `0x9D`.
- The MSM RX parser currently returns `0` for `MIPI_DSI_RX_ACKNOWLEDGE_AND_ERROR_REPORT` and for an unrecognized response data type. A zero return is therefore not a healthy status value. A short/failed DMA read can also return zero; a transport error may be negative. K7 ESD logic must treat `ret != 1` as a failed read and must not inspect an uninitialized status byte.
- `dsi_host_transfer()` serializes command transactions with `cmd_mutex` and checks `power_on` before acquiring that mutex. Host power-off is serialized separately with `dev_mutex` and does not take `cmd_mutex`. Therefore the host's transfer-side power check alone is not a sufficient lifetime guarantee for an asynchronous panel worker; the DRM bridge lifecycle must stop and drain the worker before host shutdown.
- K7's existing `ctx->lock` serializes panel commands and power transitions. A worker that takes this mutex before issuing DCS read is compatible with the existing panel serialization, but cancellation must happen before a callback takes `ctx->lock`: calling `cancel_delayed_work_sync()` while holding that mutex could deadlock if the worker is waiting for it. The safe pattern is cancel/drain outside the panel mutex, then take the mutex and perform OFF/power-down. Re-arming must occur only after successful ON/PPS and successful first refresh setup.
- The worker must also be prevented from re-arming after shutdown begins. A dedicated stopping/active state protected consistently with the panel mutex is required; probe/remove and every disable/failure path must synchronously cancel the delayed work before detaching the DSI device. The worker must never run after `atomic_disable` starts the OFF sequence or after host power-off.
- The current MSM host command path does not provide an independent lifetime reference to `power_on`; the design must rely on the DRM bridge's synchronous cancellation ordering rather than assuming `cmd_mutex` prevents power-off races. Lock ordering must remain: cancel/drain without `ctx->lock`, then panel mutex, then host transfer's internal command mutex.
- Initial implementation should be observation-only: read DCS `0x0A` in LP mode at a conservative interval while the panel is confirmed enabled; accept only exactly one byte equal to `0x9D`; log/count mismatch, short response, ACK/error, timeout and transport failure separately. Do not issue reset, reinitialize, or power-cycle automatically until the panel's recovery sequence and concurrent DRM/backlight behavior are tested on hardware.
- No worker or source changes were introduced in this stage. This is a lifecycle and API-semantics audit only. No rebuild or hardware test; MDSS, DSI0 and DSI PHY remain disabled.

## Stage 112 — DRM bridge commit ordering and ESD worker lifecycle

- The encoder bridge chain is ordered DSI manager bridge first, K7 panel bridge next. K7 sets `pre_enable_prev_first = true`: DRM's bridge-chain pre-enable therefore powers/enables the DSI host before K7 `atomic_pre_enable` runs. On shutdown, the bridge-chain post-disable algorithm reverses this dependency: K7 `atomic_post_disable` runs before the DSI manager `atomic_post_disable`, which disables the host, disables IRQs and powers off the PHY/host. This gives the panel a valid host through its OFF/power-down callbacks.
- DRM's atomic disable sequence calls bridge `atomic_disable` callbacks in reverse chain order before encoder atomic-disable; bridge `atomic_post_disable` callbacks run after encoder atomic-disable. K7's `atomic_disable` is therefore the correct synchronous boundary to stop an ESD monitor before sending the panel OFF table. K7 `atomic_post_disable` is too late for the cancellation boundary if host shutdown could follow immediately; keep it for GPIO/reset/pinctrl power-down only.
- Safe worker state proposal (not implemented): add `struct delayed_work esd_work` and a stopping/active flag protected by `ctx->lock`. Initialize with `INIT_DELAYED_WORK` during probe. Arm only after `atomic_enable` has completed the ON/PPS and 90-Hz command path successfully and has set `ctx->enabled = true`.
- Safe stop protocol: in K7 `atomic_disable`, first take `ctx->lock`, set `esd_stopping = true`, then release the lock. Call `cancel_delayed_work_sync()` with no panel mutex held. After the worker is drained, take `ctx->lock` again, clear `ctx->enabled`, send OFF if prepared, and release. This handles both a worker already running (cancel waits) and a worker queued but not started (it sees stopping and exits). The worker must schedule its next delayed instance while still holding `ctx->lock` and only when enabled, prepared and not stopping; this prevents a re-arm from racing the stop flag.
- Worker body: take `ctx->lock`; if stopping/disabled/unprepared, return without bus access. Save `dsi->mode_flags`, set `MIPI_DSI_MODE_LPM`, call `mipi_dsi_dcs_read(dsi, MIPI_DCS_GET_POWER_MODE, &status, 1)`, restore flags on every path, and accept only `ret == 1 && status == 0x9D`. Restore mode flags before unlocking. The current K7 probe configures VIDEO|VIDEO_BURST but not LPM, so an ESD read must explicitly request LP mode like the existing brightness helper does. Do not use `mipi_dsi_dcs_get_power_mode()` for strict one-byte validation: it maps non-positive results to errors but accepts any positive byte count; direct read permits exact `ret == 1` enforcement.
- `ctx->lock` also serializes brightness DCS writes and the proposed ESD read. This avoids concurrent changes to `dsi->mode_flags` and serializes panel commands. Never hold the panel mutex while calling `cancel_delayed_work_sync()`. Host transfer then takes its internal `cmd_mutex`; preserve lock order panel mutex -> host command mutex.
- Re-arm is allowed only after successful full enable. On enable failure, no worker is queued. On every disable path, including a repeated/partially prepared disable, set stopping and synchronously cancel before OFF. On remove, perform the same stop/cancel sequence before taking the panel lock to power down and before `mipi_dsi_detach()`. If a future implementation adds any other error/failure path that powers down the panel, it must use the same stop protocol.
- DRM atomic bridge callbacks are void; ESD monitor must not attempt to veto commits. First implementation remains observation-only: record exact-good, mismatch, short/zero response and negative transport error separately. No reset, panel re-init, host reset or automatic recovery. Select monitor interval only after hardware characterization; no interval is asserted in this design audit.
- Stage 112 is source-level lifecycle analysis only. No source/DTS changes, no rebuild, no runtime test. MDSS, DSI0 and DSI PHY remain disabled; panel is not hardware validated.
