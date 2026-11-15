# Stage 171 — FocalTech pinctrl state lifecycle and Mainline integration gap

Date: 2026-11-15

## Scope

Static inspection of the vendor FocalTech driver and experimental Mainline FT3418 driver. No source or DTS files were edited. No build, GPIO access, runtime test, flash, or partition write was performed. The existing build stop remains active.

## Findings

### 1. Vendor driver explicitly manages pinctrl states

In `src/vendor-sm6225/drivers/input/touchscreen/ft3418_i2c/focaltech_core.c`:

- `fts_pinctrl_init()` obtains a pinctrl handle and looks up the named states `pmx_ts_active`, `pmx_ts_suspend`, and `pmx_ts_release`.
- `fts_pinctrl_select_normal()` selects the active state.
- `fts_pinctrl_select_suspend()` selects the suspend state.
- `fts_pinctrl_select_release()` selects the release state.
- The vendor power resume path selects the normal state before enabling power.
- Vendor suspend/resume has a coordinated pinctrl and power lifecycle (detailed separately in Stage166).

The pinctrl names in the Khaje DTS are not generic `default`/`sleep`; they are vendor-specific names selected by this driver. Mainline cannot assume these names are automatically selected by the device core.

### 2. Mainline driver currently does not manage pinctrl

The experimental `drivers/input/touchscreen/focaltech-ft3418.c`:
- obtains reset and AVDD GPIO descriptors;
- enables the I2C regulator;
- resets and reads the controller ID;
- requests a threaded IRQ;
- does not obtain a pinctrl handle or select active/suspend states;
- suspend/resume currently disables/enables IRQ and releases contacts, without the vendor sleep command, reset, AVDD off, or I2C regulator disable.

This confirms two separate integration gaps:
1. The SPES touchscreen DTS lacks explicit active/sleep pinctrl mappings.
2. The Mainline driver does not reproduce the vendor's pinctrl and power-state lifecycle.

### 3. GPIO and pinctrl ownership must be coordinated

The same physical lines appear in both pinctrl and GPIO APIs:
- GPIO80: IRQ input
- GPIO86: active-low reset output
- GPIO98: AVDD enable output

The vendor pinctrl active configuration includes GPIO98 as output-high. The Mainline driver independently requests AVDD with an output-low initial value and then drives it high during probe. Before adding a Mainline default pinctrl state, the ordering and interaction between pinconf output settings and the GPIO descriptor's initial direction/value must be reviewed. Avoid defining contradictory initial output levels.

Similarly, GPIO86's pinctrl bias/output state must agree with the active-low logical GPIO descriptor. A pull configuration is not a substitute for the driver's reset sequence.

### 4. Recommended integration architecture (proposal only)

Do not copy vendor state names or legacy GPIO handling directly. A reviewed Mainline design should:

- define standard `default` and `sleep` pinctrl states for the touchscreen device in the SPES DTS;
- use GPIO80 input with the vendor-derived active pull-up/drive-strength and sleep pull-down configuration, subject to hardware review;
- define GPIO86 electrical settings consistent with active-low reset and the actual reset timing;
- define GPIO98 electrical settings without fighting the AVDD GPIO descriptor's initial output state;
- make suspend/resume select the appropriate pinctrl state and execute a reviewed power sequence with correct rollback on errors;
- keep all state selection and GPIO requests under the device's managed resource lifecycle;
- retain GPIO80 as the interrupt source; do not switch to GPIO89 based solely on the inconsistent generic vendor `interrupts = <89 2>` property.

This is a design checklist, not an approved patch. No values should be applied to the device until the pin electrical requirements and driver sequencing are reviewed.

## Blockers before enabling touch

1. Actual FT3418 silicon ID has not yet been read from the handset.
2. Runtime pinmux/pinconf cannot currently be inspected because DebugFS access is denied.
3. Mainline lacks explicit touchscreen pinctrl states.
4. Mainline PM/power sequencing differs materially from the vendor driver (Stage166).
5. AVDD GPIO descriptor initialization must be reconciled with the vendor GPIO98 output-high pinctrl state.
6. The candidate driver and DTS have not been built or hardware-tested.

## Current status

The SM6225 TLMM controller and GPIO pin descriptions are present in the Mainline source (Stage170). The FocalTech candidate remains isolated and must not be considered production-ready. No build or flash is authorized by this stage.


## Additional verification — vendor feature flags and call order

A follow-up search confirmed that the vendor configuration sets both `FTS_PINCTRL_EN=1` and `FTS_POWER_SOURCE_CUST_EN=1`. The probe's custom power initialization calls `fts_pinctrl_init()`, then `fts_pinctrl_select_normal()`, before enabling the power source. The suspend path selects the suspend pinctrl state before disabling power; resume selects the normal state before enabling power. The exit path selects the release state before power-off.

This confirms that the vendor pinctrl lifecycle is compiled in and actively called in the inspected configuration, rather than being unused helper code. The vendor init function's return value is not checked at its call site, so the mere presence of the calls does not prove pinctrl setup succeeded at runtime.
