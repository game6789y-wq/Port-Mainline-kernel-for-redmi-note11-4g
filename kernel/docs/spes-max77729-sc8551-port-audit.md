# Redmi Note 11 4G (spes) — MAX77729 / SC8551 port audit

Date: 2026-11-13. Target: Mainline port for Android 16 Evolution X.
Reference source: `src/vendor-sm6225` Linux 4.19.325, cross-checked against `src/android-kernel-spes-a16`.

## MAX77729 (confirmed from vendor `arch/arm64/boot/dts/vendor/qcom/spes.dtsi`)
- Controller: `&qupv3_se1_i2c`; address `0x66`; compatible `maxim,max77729`.
- IRQ: TLMM GPIO 105, flags `8`; vendor driver also reads `max77729,irq-gpio`.
- Driver: `drivers/mfd/maxim/max77729.c` and `max77729-irq.c`.
- Vendor driver uses child functions for USB-C/MUIC, charger and fuel gauge, and parses product/firmware/wakeup properties.
- Mainline has MAX77705/MAX77714/MAX77759 support but no matching MAX77729 driver. These parts must not be treated as interchangeable.

## SC8551 (confirmed from the same vendor DTS)
- Controller: `&qupv3_se1_i2c`; address `0x65`; compatible `sc,sc8551-standalone`.
- IRQ: TLMM GPIO 84, flags `0`.
- Driver: `drivers/power/supply/nopmi/sc8551_charger.c`; supported vendor compatibles include standalone/master/slave, with spes selecting standalone.
- Driver parses many `sc,sc8551,*` threshold properties and registers a power_supply. Vendor DTS includes battery OVP 4525 mV, battery OVP alarm 4400 mV, battery OCP 8000 mA, bus OVP 12000 mV, bus OCP 3750 mA, AC OVP 17 (driver-specific units), and sense resistor 5 mΩ.

## Port plan and safety
1. Preserve the bus, addresses, compatible strings, IRQ GPIOs and SC8551 operating mode from vendor DTS.
2. Do not enable these devices in Mainline DTS until matching drivers and DT bindings are implemented and validated.
3. Map every charger threshold to register encoding, units and documented limits before reusing it; do not blindly copy the vendor properties.
4. MAX77729 requires a new MFD/core + IRQ design and individually validated child functions. SC8551 requires a Mainline power-supply port with conservative fault handling and no unverified charge-enable path.
5. A successful compile does not authorize flashing or a recovery ZIP.

## Validation
- Vendor DTS nodes and compatible strings confirmed in both source trees.
- Vendor driver property parsing and compatible tables inspected.
- Mainline driver inventory checked; no matching MAX77729 or SC8551 driver/binding found.
- No driver changes made in this audit step. This is intentional: incomplete PMIC/charger support can affect USB-C, charging, thermal protection and battery safety.

## Additional source review (probe and register access)

### MAX77729 probe hazards found in the vendor implementation

- The vendor core allocates a private IRQ descriptor range and implements a custom nested IRQ controller with legacy `gpio_to_irq()`, `gpio_request()` and `irq_set_chip_and_handler()` APIs. Mainline port should use the I2C client's firmware-described IRQ (`client->irq`) and a managed regmap IRQ domain (`devm_regmap_add_irq_chip()`), after the MAX77729 interrupt status/mask register map has been checked against the datasheet.
- The core creates secondary I2C dummy clients at 7-bit addresses `0x25` (MUIC), `0x69` (charger), `0x36` (fuel gauge), and `0x62` (debug), in addition to the primary `0x66` client. A port must explicitly reserve/manage these addresses and ensure they do not collide with other devices on `qupv3_se1_i2c`.
- Vendor probe calls `max77729_usbc_fw_setting()` and may write firmware during probe. This must not be carried over into the initial Mainline bring-up. Firmware update must be a separately reviewed, explicitly gated operation with a known-good image and recovery strategy.
- Vendor probe has incomplete error handling around workqueue creation, dummy-client creation, pinctrl acquisition and IRQ teardown. Do not transplant it verbatim.
- The vendor OF parser consumes legacy properties (`max77729,irq-gpio`, `max77729,wakeup`, `max77729,fw_product_id`, etc.). The Mainline binding should instead use standard `interrupts`, `wakeup-source` and only retain documented device-specific properties that are actually required.

### SC8551 threshold property inventory from `spes.dtsi`

The standalone node supplies battery OVP 4525 mV / alarm 4400 mV; battery OCP 8000 mA / alarm 7500 mA; bus OVP 12000 mV / alarm 11000 mV; bus OCP 3750 mA / alarm 3500 mA; battery UCP alarm 2000 mA; battery/bus thermal threshold selectors 21; die thermal threshold 125; AC OVP selector 17; and sense resistor 5 mΩ. Both battery and bus thermistor-disable properties are explicitly zero.

The driver also recognizes additional `*-disable` boolean properties that are not all present in the spes node. Do not infer their defaults: check the vendor parser defaults and the SC8551 datasheet/register encoding before defining a Mainline binding. In particular, the AC OVP value `17` is a selector, not a voltage in mV.

## Next implementation gates

- MAX77729: obtain/check the exact MAX77729 register map and IRQ semantics; then implement a read-only regmap-backed core that validates chip ID/revision without firmware update or child charging functions. Only after that build and test the core with the device node still disabled. Child functions are separate follow-up work.
- SC8551: map every DT property to the vendor configuration structure and register field; verify selector units and safe defaults from the chip datasheet. Then port the driver with power_supply/regmap APIs and fault handling. Do not enable charging controls until validated.


## MAX77729 read-only core implementation (stage 1)

- Added `drivers/mfd/max77729-core.c`, gated by `CONFIG_MFD_MAX77729_CORE`.
- Uses an I2C regmap with only registers `0x00` (PMICID1) and `0x01` (PMICREV) readable; no register writes are implemented.
- Probe reads and logs both values and rejects read errors or a zero revision, matching the vendor probe's zero-revision rejection.
- The vendor source does not publish an expected PMICID1 constant or compare the returned ID. The new core therefore reports the raw ID but does not invent an ID match value. Exact chip-ID validation remains blocked on a MAX77729-specific datasheet/register specification.
- Added a minimal DT binding for `maxim,max77729`; the spes DTS node remains absent/disabled, and no IRQ, MFD children, charger, fuel-gauge, USB-C or firmware-update paths are present.
- This is a compile-testable skeleton only; it is not authorized for device testing or flashing.


### Stage 1 compile validation

- `drivers/mfd/max77729-core.c` compiled successfully as an AArch64 object with `W=1` using the existing `build/spes` output tree. No compiler warnings were emitted for this object.
- The object exists at `build/spes/drivers/mfd/max77729-core.o` (21 KiB).
- `git diff --check` passed. The new binding parses as YAML with PyYAML. `dt-doc-validate` / dtschema validation is still pending because `dt-doc-validate` is not installed in the workspace.
- The existing build `.config` was not changed to enable this driver. The spes DTS node remains absent; this is compile-only validation.


## SC8551 read-only identification core (stage 1)

- Vendor source `drivers/power/supply/nopmi/sc8551_reg.h` defines device ID register `0x13`; `sc8551_detect_device()` accepts raw IDs `0x00` (SC8551) and `0x51` (SC8551A).
- Added `drivers/power/supply/sc8551-id.c`, gated by `CONFIG_CHARGER_SC8551_ID_ONLY`. It reads only register `0x13` through an I2C regmap and rejects all other values. No register writes, ADC setup, interrupt setup, power_supply registration or charge control are implemented.
- Added a temporary `sc,sc8551-id-only` binding. It intentionally does not match the existing vendor compatible `sc,sc8551-standalone`; no DTS node was enabled or modified.
- This is a compile-testable identification stage only, not a functional charger driver and not suitable for device deployment.
- SC8551A public brief is not proof that the exact device on spes is SC8551A; the port follows the exact vendor driver's two accepted IDs and must confirm the fitted component marking/revision before enabling.


### SC8551 read-only core compile validation

- `drivers/power/supply/sc8551-id.c` compiled as an AArch64 module with `W=1`; module link and MODPOST succeeded. Output: `drivers/power/supply/sc8551-id.ko`.
- MAX77729 core was also linked as an AArch64 module with `W=1`; module link and MODPOST succeeded. Output: `drivers/mfd/max77729-core.ko`.
- The temporary build config `build/spes/.config` has `CONFIG_MFD_MAX77729_CORE=m` and `CONFIG_CHARGER_SC8551_ID_ONLY=m`. This config change is outside the source repository; no target DTS node was enabled.
- Both new YAML bindings parse with PyYAML. Full dt-schema validation remains unavailable (`dtschema` / `dt-doc-validate` not installed).
- `git diff --check` passes. These module builds verify compile/link only; no hardware interaction or runtime tests were performed.

## SC8551 configuration encoding audit (stage 2)

Reviewed the exact vendor parser, register macros and threshold setter functions in `src/vendor-sm6225/drivers/power/supply/nopmi/sc8551_charger.c` and `sc8551_reg.h`.

### Confirmed conversion of the `spes.dtsi` values

| Vendor property | DTS value | Vendor conversion | Register / encoded value |
|---|---:|---|---|
| `bat-ovp-threshold` | 4525 mV | `(4525 - 3500) / 25` | `0x00: 41` |
| `bat-ovp-alarm-threshold` | 4400 mV | `(4400 - 3500) / 25` | `0x01: 36` |
| `bat-ocp-threshold` | 8000 mA | `(8000 - 2000) / 100` | `0x02: 60` |
| `bat-ocp-alarm-threshold` | 7500 mA | `(7500 - 2000) / 100` | `0x03: 55` |
| `bat-ucp-alarm-threshold` | 2000 mA | `2000 / 50` | `0x04: 40` |
| `ac-ovp-threshold` | 17 | `(17 - 11) / 1` | `0x05: 6` |
| `bus-ovp-threshold` | 12000 mV | `(12000 - 6000) / 50` | `0x06: 120` |
| `bus-ovp-alarm-threshold` | 11000 mV | `(11000 - 6000) / 50` | `0x07: 100` |
| `bus-ocp-threshold` | 3750 mA | `(3750 - 1000) / 250` | `0x08: 11` |
| `bus-ocp-alarm-threshold` | 3500 mA | `3500 / 50` | `0x09: 70` |
| `bat-therm-threshold` | 21 | raw byte write | `0x29: 21` |
| `bus-therm-thr
[... 214625 bytes omitted ...]
uffer and video BLLP limit; one `dsi_cmd_dma_tx()` submits the whole list.
- Existing single-message `transfer` path remains unchanged in behavior (`last=true`, offset zero). K7 refresh payloads can now be represented as four `MIPI_DSI_DCS_LONG_WRITE` messages and submitted atomically through the new helper.
- Build verification: `make O=build/spes ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j2 Image modules` exited 0. Targeted `W=1` object compilation for `drm_mipi_dsi.o`, `dsi_host.o`, and `dsi_manager.o` also exited 0. Build log `/workspace/ubuntu-spes-mainline/logs/spes-k7-dsi-batch-api-build.log` contains no matching warning/error/undefined-reference/modpost-error diagnostics. New symbol is present in `Module.symvers`; `msm.ko` linked successfully.
- New Image SHA256: `6e879ac7af516c6c5ad3aaa2c3d055bba71af565e6a2d5d4ada67de40934d115`.
- Important limits: no K7 panel driver calls the API yet; no panel DT node or display graph enabled; no hardware test. Batch path intentionally rejects bonded/synchronized DSI and mixed flags/channels/read messages. No module staging, Recovery ZIP, flash, release, commit or push.

## SM6225 Mainline display clock/power resource reconciliation (stage 89)

- Confirmed Mainline SoC DTS already defines the core display resource tree: MDSS top with `dispcc MDSS_GDSC`, GCC DISP AHB/HF-AXI and DISPCC MDP clocks, MDP0-to-EBI and CPU-to-display-config interconnects, Apps SMMU streams 0x420/0x421; SM6225 DPU with seven clocks, 19.2 MHz VSYNC assignment, OPPs 19.2/200/300/383/470/560 MHz and RPM VDDCX power domain; DSI0 with byte/byte-intf/pixel/escape/AHB and GCC bus clocks, assigned DSI PHY clock parents, OPPs 187.5/300/358 MHz and VDDCX power domain; SM6375 7nm DSI PHY with DISPCC AHB and RPM XO; and SM6225 DISPCC provider.
- `dispcc-sm6225.c` provides MDSS GDSC at register 0x1004 with `HW_CTRL`; the generic Mainline DISPCC driver does not request the vendor-specific `vdd_cx-supply`. Keep the Mainline power-domain model; do not copy the vendor `qcom,khaje-dispcc` syscon or its supply property.
- Vendor Khaje SDE uses matching MDP/VBIF and DSI0/PHY0 physical blocks and a clock set corresponding to Mainline's GCC/DISPCC resources. Vendor operating rates (MDP 300 MHz, VSYNC 19.2 MHz, LUT 300 MHz, ROT 200 MHz; max 560 MHz) are represented by Mainline DPU OPP entries. This supports the SoC resource mapping but does not prove the 90 Hz mode will be stable.
- Mainline SPES DTS has no display overrides. MDSS parent, DSI0 and DSI PHY0 remain disabled; DSI0 input graph is already connected to DPU interface1 but output endpoint has no remote panel. A K7 panel child and reciprocal output graph remain necessary.
- DSI host parses `data-lanes` and optional `qcom,te-source` from the DSI output endpoint; if lane data is omitted it defaults to four lanes. K7 is four-lane, but physical lane order must be confirmed before setting explicit mapping. Video-mode panel does not justify inventing a TE source.
- Detailed map written to `refs/k7-sm6225-display-clock-power-map.md`. No display status, clock, power or panel DTS edits were made.
- Stage 89 decision: Mainline already has most SoC-level clock/interconnect/OPP/power-domain plumbing; focus next on safe board-level graph/pinctrl/panel power mapping rather than inventing a new display clock tree. Do not enable MDSS until panel node, GPIO ownership and external 1.8 V topology are verified.

## K7 command link states and Mainline DSC handoff (stage 90)

- Confirmed vendor command states: ON and OFF tables are LP; refresh 60/90 command sets are HS. The separate DSC PPS uses `DTYPE_PPS`, VC0, last=1, a 10 ms wait, and LP mode. This is not the 0x9e init-table command.
- Mainline DSI mode should be video + burst, four lanes, RGB888, with EoT enabled (vendor appends EoT). Keep global `MIPI_DSI_MODE_LPM` clear because K7 mixes LP and HS packets. Use per-message `MIPI_DSI_MSG_USE_LPM` for ON/OFF and PPS; use flags clear for HS refresh batch. Keep `MIPI_DSI_MODE_DSC_ALL_SLICES_IN_PKT` clear because vendor uses one slice per packet.
- Mainline panel drivers set `dsi->dsc` before `mipi_dsi_attach()`. MSM DSI host attach stores that pointer. Its timing setup calls `dsi_populate_dsc_params()` after the adjusted mode is installed, filling `pic_width`/`pic_height` and DSC RC/scale/BPG parameters. The DSI manager's pre-enable powers/configures the host before the downstream bridge pre-enable when `pre_enable_prev_first` is true. Thus a custom panel bridge can pack PPS from the populated `dsi->dsc` during its own pre-enable callback.
- `drm_dsc_pps_payload_pack()` plus a 128-byte `MIPI_DSI_PICTURE_PARAMETER_SET` message can reproduce the separate vendor PPS. Send it in LP mode and wait 10 ms after the 45-packet LP ON sequence. The standard PPS helper inherits global LPM, so the panel driver must set the per-message LPM state explicitly (or temporarily toggle device LPM only around the PPS call).
- Stage 90 conclusion: DSI command-state split and DSC config handoff are now source-confirmed; panel driver can preserve LP init/PPS and HS refresh without globally forcing one mode. Still no K7 panel source/DT enablement. Current post-batch build after bonded-link rejection exited 0; see `/workspace/ubuntu-spes-mainline/logs/spes-k7-dsi-batch-api-build-final.log`.

## K7 panel bridge shutdown ordering and seamless refresh boundary (stage 91)

- `drm_atomic_bridge_chain_disable()` invokes bridge atomic-disable callbacks from the last bridge back toward the encoder. `drm_atomic_bridge_chain_post_disable()` normally runs forward but honors `pre_enable_prev_first` by reversing that sub-chain. With K7 panel bridge after MSM DSI manager bridge and `pre_enable_prev_first=true`, K7 `.atomic_disable()` runs before encoder disable, and K7 `.atomic_post_disable()` runs before DSI manager `.atomic_post_disable()` powers down host/PHY.
- This yields a safe panel lifecycle: panel `.atomic_disable()` sends DCS `0x28` / `0x10` while DSI host is still available; panel `.atomic_post_disable()` sequences reset, PMIC panel-enable and verified LCM rail off while host remains powered; then MSM DSI manager shuts down host and PHY. Pre-enable is the reverse: host first, then panel power/reset/init/PPS.
- Important correction to the initial refresh proposal: if 60/90 transitions are ordinary full modesets, the panel is disabled and power-cycled on every transition. This is acceptable only for early bring-up, not seamless dynamic refresh. Initial driver should expose one fixed mode (90 Hz after clock/PHY validation); add seamless 60/90 only with a dedicated MSM/DPU pre-kickoff path.
- Stage 91 conclusion: complete panel power-up/down callback ordering is source-confirmed; no need to modify generic DRM bridge ordering. No new code/DTS changes in this stage.

## K7 board GPIO provider and DCS backlight reconciliation (stage 92)

- Mainline SPES includes `pm6125.dtsi`; its `pm6125_gpios` provider is `qcom,pm6125-gpio` with nine lines. Use PMIC physical GPIO9 in the DT specifier; the upstream SPMI GPIO translator maps the physical pin to its chip offset. Vendor K7 panel-enable is physical GPIO9 active-high.
- Vendor `lcm1p8en_active` and `lcm1p8en_suspend` confirm TLMM GPIO54 is a separate 1.8V enable: active GPIO mode, 2mA, pull-up, output-high; suspend GPIO mode, 2mA, pull-down, output-low. Vendor DSI active state sets reset GPIO82 GPIO mode, 8mA/no pull; suspend uses 2mA/pull-down. Reset sequence is high/10ms, low/10ms, high/10ms.
- Mainline TLMM driver supports GPIO54 and GPIO82; Mainline PM6125 GPIO provider is present. This makes a board-level GPIO descriptor/pinctrl representation possible. Do not attach PM6125 L9 as `vddio`; it is shared and the actual load-switch topology remains unproven.
- Modern Vendor Techpack's DCS backlight path sends 16-bit brightness and swaps bytes when `qcom,mdss-dsi-bl-inverted-dbv` is set: `((level & 0xff) << 8) | (level >> 8)`. K7 uses DCS backlight, min 1, max 2047. This supersedes the legacy one-byte framebuffer helper for the Mainline port.
- Stage 92 conclusion: GPIO9/GPIO54/GPIO82 and 16-bit inverted DCS brightness controls are source-grounded enough to implement as descriptors/pinctrl/backlight; the external 1.8V rail is still not a regulator consumer. No code or DTS changes made.

## K7 TE pin and 16-bit brightness Mainline mapping (stage 93)

- Vendor Khaje pinctrl selects GPIO81 function `mdp_vsync` in both active/suspend states, 2 mA with pull-down. Vendor K7 endpoint does not define `qcom,te-source`. Mainline DPU defaults to `DPU_VSYNC_SOURCE_GPIO_0` / `mdp_vsync_p` when the property is absent. Preserve this default and mux TLMM GPIO81 to `mdp_vsync`; do not invent a `qcom,te-source` value.
- Mainline `mipi_dsi_dcs_set_display_brightness_large()` sends the 16-bit brightness big-endian. Modern Vendor Techpack swaps the logical level's bytes before calling the little-endian helper, which produces the same wire byte order. Call the Mainline large helper directly with logical level 0..2047; do not swap twice.
- Backlight updates should be cached while panel is off and sent only after panel enable. Expose min=1/max=2047, with blank/off handled as zero.
- Stage 93 conclusion: GPIO81 vsync selection and the exact DCS brightness wire format are mapped. No source or DTS changes in this stage.

## K7 fixed-90-Hz custom bridge driver and binding (stage 94)

- Added `drivers/gpu/drm/panel/panel-k7-38-0c-0a.c` as a standalone DRM bridge, deliberately not registering a `drm_panel` on the same OF node. It owns atomic bridge state, exact 90-Hz mode timing, panel lifecycle and backlight.
- Embedded the vendor K7 ON table (570 bytes, 45 packets) and OFF table (16 bytes, 2 packets). A validation script compared the embedded ON bytes exactly to the vendor DTS and parsed all 45 packet headers; waits are packet0=20ms and packet43=100ms. ON/OFF are sent packet-by-packet in LP mode, preserving DCS long-write types including 2-byte payloads.
- Driver sets `dsi->dsc` before `mipi_dsi_attach()` for DSC1.1 8bpc/8bpp, two 540x20 slices, block prediction. Panel pre-enable packs and sends host-computed 128-byte PPS in LP mode after ON. Panel atomic-enable sends the 4-packet 90-Hz HS batch through the new MSM batch API.
- Driver uses standard `enable-gpios` for PMIC physical GPIO9, `reset-gpios` for TLMM GPIO82, and `default`/`sleep` pinctrl states for GPIO54 LCM enable, GPIO82 reset pad and GPIO81 MDP_VSYNC. Backlight uses the 16-bit large DCS helper. No L9 regulator consumer is added.
- Initial mode is fixed 90 Hz only; 60 Hz and seamless refresh are deliberately not exposed. If 90-Hz command transmission fails, driver sends OFF and powers the panel down rather than leaving a 60-Hz panel with 90-Hz host timing.
- Added Kconfig/Makefile integration and `Documentation/devicetree/bindings/display/panel/xiaomi,k7-38-0c-0a.yaml`. The driver is configured as a module in the build tree, not in the board DTS.
- Verification: W=1 panel object compile passed; `make modules` Exit Code 0; `.ko` linked at `/workspace/ubuntu-spes-mainline/build/spes/drivers/gpu/drm/panel/panel-k7-38-0c-0a.ko`, with OF aliases `xiaomi,k7-38-0c-0a`; no matching warnings/errors. `dt-doc-validate` passes. `dt_binding_check` fails in the installed dtschema 2024.4 while processing schemas (`AttributeError: 'bool' object has no attribute 'pop'`), before a binding-specific result can be produced.
- Stage 94 limits: no SPES panel node/graph/pinctrl instance or display enablement yet; no runtime test. No module staging, flash, Recovery ZIP, release, commit or push.

## Pinctrl default-state power safety correction (stage 95)

- Corrected the K7 panel pinctrl contract after reviewing Linux device-core pinctrl binding: the `default` state is auto-selected before driver probe and therefore must be safe. Binding now requires `pinctrl-names = "default", "active", "sleep"`; default and sleep use GPIO54 low, active drives GPIO54 high. Driver looks up `active` and `sleep`, selects sleep at probe, active only in panel pre-enable, and sleep in post-disable.
- This avoids briefly enabling the external LCM 1.8V switch when the DSI child device is merely probed. PMIC GPIO9 and reset GPIO82 are still requested output-low at probe.
- `dt-doc-validate` passes. Full `make modules` after the pinctrl correction exited 0; updated `panel-k7-38-0c-0a.ko` linked and has the expected OF alias. No compiler or modpost warning/error diagnostics in the final full-module log. `git diff --check` passes.
- Targeted single-module modpost without the full in-tree provider module list reported unresolved exported DRM helper symbols; this was a single-module invocation limitation. The full in-tree `make modules` modpost resolved those symbols successfully. No source export changes were needed.
- Stage 95 limits unchanged: no K7 panel node/graph added, MDSS/DSI/PHY still disabled, no hardware runtime test, no module staging/flash/release/commit/push.

## SPES K7 panel child/graph and dormant pinctrl wiring (stage 96)

- Added board pinctrl groups for GPIO54 LCM enable, GPIO82 reset and GPIO81 MDP_VSYNC. Default and sleep states drive GPIO54 low; active state drives GPIO54 high. Reset active is 8mA/no-pull, reset sleep is 2mA/pull-down; TE is `mdp_vsync` 2mA/pull-down.
- Added `panel@0` under `&mdss_dsi0`: `compatible = "xiaomi,k7-38-0c-0a"`, DSI VC0, PM6125 physical GPIO9 active-high `enable-gpios`, TLMM GPIO82 active-high `reset-gpios`, default/active/sleep pinctrl states. Added reciprocal DSI0/panel graph endpoints and four data lanes.
- No display node was enabled. Effective DTB decompile confirms `display-subsystem@5e00000`, DSI0 `dsi@5e94000`, and DSI PHY0 `phy@5e94400` all remain disabled. The panel node is therefore dormant and cannot trigger GPIO/DSI operations.
- Target `qcom/sm6225-xiaomi-spes.dtb` compiled successfully (Exit Code 0), no DTC warning/error. `dt-doc-validate` passes. Full schema/example check remains blocked by dtschema 2024.4 internal `bool.pop` error.
- New DTB SHA256: `eb76463ef19e870e66f77bb8a998a0702d606490cb682e20757062516a12e967`.
- Stage 96 limits: no display `status = "okay"`, no boot/runtime test, no module staging, Recovery ZIP, flash, release, commit or push.

## K7 display clock/OPP and analog supply audit (stage 97)

- Calculated K7 90 Hz pixel clock 339.702 MHz and DSI byte clock 84.9255 MHz (DSC 8 bpp, four lanes); lane bit clock approximately 679.404 Mbps. This lies within the SM6375 7-nm PHY 600 MHz–5 GHz PLL limits.
- Mainline DSI OPP table 187.5/300/358 MHz covers 84.93 MHz byte clock (ceil selects 187.5 MHz); DPU OPP table max 560 MHz covers 339.7 MHz pixel clock. Mainline dispcc has MDSS byte0, pixel0 and MDP clock objects and SoC DTS connects the clock graph. These are structural checks only, not runtime PLL lock.
- Downstream Khaje board reference requires DSI controller `vdda-1p2` from PM6125 L18A at 1.232 V plus separate `refgen`, and DSI PHY `vdda-0p9` from PM6125 L4A at 0.88 V / 36 mA.
- Mainline SM6225 DSI host uses SDM845 DSI config for base 0x5e94000 and requests `vdda` + `refgen`, but SPES DTS has neither supply link nor L18 regulator entry. Upstream refgen provider does not support downstream `qcom,refgen-kona-regulator` compatible.
- Mainline `qcom,sm6375-dsi-phy-7nm` config has no regulator_data (unlike other 7nm PHY variants), so it does not currently request the vendor's external 0.9 V L4 rail. Adding only a DT supply would not make it consumed. Requires a deliberate PHY driver/compatible review.
- No regulator/PHY supply changes made. Do not enable display until these provider and rail dependencies are resolved. Stage 97 did not rebuild; no hardware test, staging, flash, release, commit or push.

## REFGEN and DSI controller analog rail wiring (stage 98)

- Verified vendor Khaje REFGEN operation at offset 0x80, bit0, enable=1/disable=0 is identical to upstream `qcom,sm8250-refgen-regulator` implementation. Added a SPES provider at 0x01600000 size 0x84 using the upstream compatible; did not copy vendor-only proxy properties.
- Added PM6125 L18 fixed at 1.232 V with adjustable load and connected DSI controller `vdda-supply` and `refgen-supply`. This matches vendor Khaje L18A 1.232 V plus separate REFGEN.
- `qcom-refgen-regulator.ko` is built and exposes the required OF alias. Target DTB compiles; REFGEN binding `dt-doc-validate` passes. MDSS/DSI/PHY remain disabled.

## SM6375 7nm PHY 0.9V rail integration (stage 99)

- Vendor Khaje explicitly wires DSI PHY vdda-0p9 to PM6125 L4A at 0.88 V / 36 mA. Upstream PHY binding already names this `vdds-supply`, but the SM6375-compatible PHY config previously had no regulator_data and did not enable the rail.
- Added the existing 36mA 7nm PHY regulator descriptor to `dsi_phy_7nm_6375_cfgs`; added PM6125 L4 fixed at 0.88 V with adjustable load; wired `&mdss_dsi0_phy` `vdds-supply` to L4.
- Full `make modules` Exit Code 0; MSM DRM module linked with updated PHY object and expected SM6375 PHY OF alias. Target SPES DTB compiled Exit Code 0, no DTC diagnostics. `dt-doc-validate` passed for REFGEN, 7nm PHY, SM6375 MDSS and K7 panel bindings. `git diff --check` passes.
- Effective DTB check confirms MDSS, DSI0 and DSI PHY0 all remain disabled. No hardware runtime test or display enablement. Full `dt_binding_check` remains blocked by dtschema 2024.4 internal error. No module staging, Recovery ZIP, flash, release, commit or push.

## Targeted DTBS schema check and W=1 verification (stage 100)

- Individual `dt-doc-validate` passed for REFGEN, 7nm DSI PHY, SM6375 MDSS and K7 panel bindings.
- Targeted `make dtbs_check` exits 2 before validating the DTB because the installed dtschema 2024.4 fails to generate `processed-schema.json` with `AttributeError: 'bool' object has no attribute 'pop'` in `fixup_schema()`. This is a schema-tool internal failure, not a DTC syntax/build failure.
- `W=1` compile of the updated `dsi_phy_7nm.o` passes. Stage 99 full `make modules` exit 0. Target SPES DTB DTC build exit 0 with no warnings/errors. `git diff --check` passes.
- Effective DTB still has MDSS, DSI0 and DSI PHY0 disabled. No hardware test, module staging, Recovery ZIP, flash, release, commit or push.

## Display GDSC, VDDCX, runtime-PM and performance vote audit (stage 101)

- MDSS top node owns DispCC `MDSS_GDSC` (offset 0x1004, `PWRSTS_OFF_ON`, `HW_CTRL`). DPU and DSI0 children request `SM6115_VDDCX`; SoC RPM provider is `qcom,sm6115-rpmpd` and supports VDDCX/OPP indexes. DSI PHY is an MDSS child, uses runtime-PM `iface` clock and its 0.9V `vdds` rail.
- MDSS runtime resume votes minimum MDP-memory and register-bus ICC bandwidth before enabling clocks. DPU/DSI children are populated under MDSS; runtime-PM parent/child dependency preserves MDSS while child is active. DSI PHY runtime resume enables iface via pm_clk, then PHY enable path enables 36mA vdds before PLL operations.
- Corrected DPU clock calculation: the 339.702 MHz panel pixel clock is not the DPU core request. Mainline DPU computes `vtotal * hdisplay * refresh * 105%`; K7 90Hz mode -> 248.210 MHz before plane-specific adjustments, selecting the 300 MHz OPP / SVS. DSI byte clock 84.9255 MHz selects DSI 187.5 MHz OPP / low-SVS. OPP tables and DispCC clock rate points align.
- SM6225 DPU catalog has min DRAM peak vote 1.6 GB/s, bandwidth inefficiency 120%, and low/high limits 5.2/6.2 GB/s. Simple XRGB8888 full-screen scanout estimate is 0.933 GB/s raw / 1.12 GB/s after inefficiency; actual DPU votes derive from plane fetch format/scaling at runtime. No static bus vote change made.
- DPU votes bandwidth before increasing core clock; MDSS votes minimum bus bandwidth before AXI clock enable. Power/performance topology is structurally coherent. No DTS/driver source changes and no rebuild in Stage 101.
- Do not enable MDSS/DSI/PHY yet. Hardware verification remains required for GDSC, VDDCX/rails, runtime-PM probe order, PHY PLL lock, DSC/PPS, first frame and TE. No module staging, Recovery ZIP, flash, release, commit or push.