# Stage 170 — SM6225 TLMM and FocalTech pinctrl source audit

Date: 2026-11-15

## Scope and safety

Static source inspection only. No source code, Device Tree, configuration, or build files were changed. No kernel build, hardware register access, GPIO toggling, flashing, or partition writes were performed. The previously issued build stop remains in force.

## Executive result

The checked-out Mainline tree contains a native Qualcomm SM6225 TLMM pinctrl/GPIO driver and pin descriptions for GPIO80, GPIO86, GPIO89, and GPIO98. These GPIOs are not in the driver's Khaje reserved-GPIO list. The controller therefore has source-level descriptions for the touch-related pins; the DebugFS mount failure does not establish a missing pinctrl driver.

The vendor Khaje pinctrl include chain inherits the FocalTech IRQ and AVDD pin states from `bengal-pinctrl.dtsi`, while `khaje-pinctrl.dtsi` adds the Khaje-specific reset and release states. The earlier isolated inspection of `khaje-pinctrl.dtsi` was incomplete because it did not account for its include of `bengal-pinctrl.dtsi`.

The experimental Mainline SPES touchscreen node currently has no touchscreen `pinctrl-names` or `pinctrl-*` references. Its GPIO descriptors and interrupt are declared, but the explicit vendor electrical pin configurations are not yet represented in the Mainline DTS. This is a source-level integration gap, not proof of a runtime electrical failure.

## Evidence

### 1. Mainline SM6225 TLMM driver exists

Files:
- `drivers/pinctrl/qcom/pinctrl-sm6225.c`
- `drivers/pinctrl/qcom/Kconfig.msm`
- `arch/arm64/boot/dts/qcom/sm6225.dtsi`

Findings:
- Kconfig symbol: `CONFIG_PINCTRL_SM6225`, default `ARCH_QCOM`.
- OF compatible: `qcom,sm6225-tlmm`.
- The SM6225 driver exposes 114 GPIOs and three register tiles: south, east, west.
- The SPES DTS TLMM node uses `qcom,sm6225-tlmm`, names the three register windows `west`, `south`, `east`, and declares a GPIO controller/range.
- Khaje reserved GPIO list is only GPIO14–GPIO17. GPIO80, 86, 89 and 98 are not reserved.

### 2. Pin groups relevant to FocalTech

The Mainline pin table declares:
- GPIO80: WEST tile; alternate functions include `qup2` and `dac_calib`; GPIO mode is function slot zero.
- GPIO86: WEST tile; alternate functions include `qup0`, `gcc_gp1`, and `atest`; GPIO mode is function slot zero.
- GPIO89: WEST tile; alternate functions include `usb_phy` and `atest`; GPIO mode is function slot zero.
- GPIO98: SOUTH tile; no listed alternate function; GPIO mode remains represented by the standard GPIO group.

The Mainline TLMM pin table therefore has source-level pin descriptions for all four GPIOs. This does not independently prove that the controller successfully probes or that the active runtime mux/electrical state is correct.

### 3. Vendor Khaje pinctrl include chain

- `khaje-pinctrl.dtsi` begins by including `bengal-pinctrl.dtsi`.
- The inherited Bengal pinctrl defines:
  - `ts_int_active`: GPIO80, GPIO function, 8 mA, pull-up.
  - `ts_int_suspend`: GPIO80, GPIO function, 2 mA, pull-down.
  - `ts_avdd`: GPIO98, GPIO function, 8 mA, pull-up, output-high.
- Khaje-specific `khaje-pinctrl.dtsi` adds:
  - `ts_reset_active`: GPIO86, GPIO function, 8 mA, pull-up.
  - `ts_reset_suspend`: GPIO86, GPIO function, 2 mA, pull-down.
  - `ts_release`: GPIO80 and GPIO86, GPIO function, 2 mA, pull-down.
- The Khaje touchscreen node in `khaje-idp.dtsi` selects:
  - active: `ts_int_active`, `ts_reset_active`, `ts_avdd`
  - suspend: `ts_int_suspend`, `ts_reset_suspend`
  - release: `ts_release`

This corrects the earlier apparent missing-label finding: the IRQ and AVDD labels are inherited through the include, not defined directly in `khaje-pinctrl.dtsi`.

### 4. GPIO80 versus GPIO89

The vendor Khaje touchscreen node declares generic `interrupts = <89 2>`, but also supplies `focaltech,irq-gpio = <&tlmm 80 2>`. The vendor FocalTech driver parses the latter and obtains its IRQ using `gpio_to_irq(pdata->irq_gpio)`. Live device evidence independently showed `fts_ts` registered on MSM GPIO80 with a nonzero interrupt count.

The experimental Mainline SPES DTS uses GPIO80 as the interrupt line. That agrees with the observed vendor driver path and runtime IRQ registration. GPIO89 remains an inconsistent legacy generic interrupt property and must not be substituted without evidence.

### 5. Mainline SPES touchscreen pinctrl gap

Current experimental Mainline node:
- I2C address 0x38
- interrupt GPIO80, falling edge
- reset GPIO86, active-low
- AVDD GPIO98, active-high
- I2C supply `pm6125_l9`
- touch geometry 1080 x 2400

However, this node currently has no `pinctrl-names`, `pinctrl-0`, or `pinctrl-1` declarations. It therefore does not encode the vendor active/suspend electrical settings described above. The candidate driver uses GPIO descriptors and regulators but does not currently select explicit pinctrl states.

## Required follow-up before enabling Mainline touch

1. Keep the Mainline touch node/driver isolated and do not enable it in a release build yet.
2. Prepare a reviewed, non-applied DTS proposal that translates the inherited vendor active/suspend states to standard Mainline pinctrl states, using the correct SM6225 TLMM pin names and verified polarities.
3. Review GPIO descriptor polarity and pinctrl output settings together to avoid double-inverting reset or driving AVDD incorrectly.
4. Resolve the suspend/resume mismatch already recorded in Stage166. A pinctrl sleep state alone does not implement the vendor power sequence.
5. Only after source review and authorization, run static DT validation/build tests. Hardware validation remains a separate later gate.

## Current status

- SM6225 TLMM driver and pin descriptions: source-level support found.
- GPIO80 runtime IRQ: confirmed by earlier user-supplied `/proc/interrupts`.
- Vendor active/suspend pin settings: recovered from the include chain.
- Mainline touch pinctrl states: missing from current experimental SPES node.
- Runtime pinmux/electrical state: not verified because DebugFS is inaccessible.
- Source changes/build/flash: none in this stage; build remains stopped.
