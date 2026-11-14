# Stage 138 — PMIC/RPM display power-provider configuration audit

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: build-config and driver-object inspection.

## RPM-controlled PM6125 rails

The SoC DTSI defines the RPM request transport as `qcom,rpm-sm6115` with fallback `qcom,glink-smd-rpm`; its nested clock and power controllers provide RPM clocks and power domains. The SPES board's PM6125 RPM regulator node uses `qcom,rpm-pm6125-regulators`, which is handled by the Qualcomm SMD RPM regulator driver.

The current build config has the required transport/provider stack built in:

- `CONFIG_RPMSG_QCOM_GLINK=y`
- `CONFIG_RPMSG_QCOM_GLINK_RPM=y`
- `CONFIG_QCOM_SMD_RPM=y`
- `CONFIG_REGULATOR_QCOM_SMD_RPM=y`

Thus the PM6125 RPM rails used by the display path (including L18 and L4/L9 references where applicable) do not depend on a separately staged `.ko` module.

## SPMI PMIC GPIO and regulator path

The PM6125 physical GPIO9 panel-enable line is supplied through the PMIC SPMI GPIO controller. The build config has the following required pieces built in:

- `CONFIG_SPMI=y`
- `CONFIG_SPMI_MSM_PMIC_ARB=y`
- `CONFIG_MFD_SPMI_PMIC=y`
- `CONFIG_PINCTRL_QCOM_SPMI_PMIC=y`
- `CONFIG_REGULATOR_QCOM_SPMI=y`

The corresponding `pinctrl-spmi-gpio.o` and `pinctrl-spmi-mpp.o` objects are present in the build output. These providers are built into the kernel, so they do not need a separate staged module alias to service the PMIC GPIO controller.

## Display-path provider split

- PM6125 RPM rails (DSI host analog L18 and other RPM-controlled PMIC rails): built-in SMD RPM regulator stack.
- PM6125 physical GPIO9: built-in SPMI/PMIC GPIO stack.
- Khaje REFGEN at `0x01600000`: separate `qcom-refgen-regulator.ko`, staged and alias-verified in Stages 128–129.
- SM6375 DSI PHY `vdds` rail: PM6125 L4 RPM regulator; PHY consumer/enable is in the MSM module.

This provider split is consistent with the current SPES DT wiring. The build config proves driver availability in the kernel build, not that the physical rails or GPIOs behave correctly on the phone.

## Validation / safety

- Build config and existing object inspection only; no new build or source change.
- No hardware regulator/GPIO measurement or panel power-on test.
- MDSS/DSI0/DSI PHY remain disabled; FPC remains disabled.
- No flash or release artifact.
