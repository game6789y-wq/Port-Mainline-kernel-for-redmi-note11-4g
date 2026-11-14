# SPES SM6225 display clock / power / interconnect map

Status: source-level audit only. No display node is enabled by this document.

## Mainline SoC resources already described

| Block | Mainline node | Mainline resources |
|---|---|---|
| MDSS top | `display-subsystem@5e00000` (`qcom,sm6225-mdss`) | `dispcc MDSS_GDSC`; GCC DISP AHB/HF-AXI + DISPCC MDP; MDSS IRQ controller; MDP0-to-EBI and CPU-to-display-config interconnects; Apps SMMU streams 0x420/0x421 |
| DPU | `display-controller@5e01000` (`qcom,sm6225-dpu`) | GCC DISP HF-AXI; DISPCC AHB/ROT/LUT/MDP/VSYNC; GCC throttle; VSYNC assigned 19.2 MHz; MDP OPP 19.2/200/300/383/470/560 MHz mapped to RPM VDDCX OPP; `SM6115_VDDCX`; DPU intf1 -> DSI0 input graph |
| DSI0 | `dsi@5e94000` (`qcom,sm6115-dsi-ctrl`) | DISPCC byte0/byte0-intf/pixel0/esc0/AHB; GCC DISP HF-AXI bus; byte and pixel source clocks parented to DSI PHY outputs; DSI OPP 187.5/300/358 MHz; `SM6115_VDDCX`; four-lane default if no `data-lanes` on endpoint |
| DSI PHY0 | `phy@5e94400` (`qcom,sm6375-dsi-phy-7nm`) | PHY, lane and PLL register windows; DISPCC AHB iface + RPM XO ref; exports byte and DSICLK clock parents |
| DISPCC | `clock-controller@5f00000` (`qcom,sm6225-dispcc`) | Generic SM6225 DISPCC provider; XO, GCC DISP GPLL0-div, DSI PHY byte and DSICLK parents; MDSS GDSC at register 0x1004 with hardware-control flag |

## Vendor cross-check

- Vendor Khaje SDE uses the same MDP/VBIF physical windows and DSI0/PHY0 blocks. Its MDP clock list corresponds to GCC DISP AHB/HF-AXI/throttle/GPLL0-div plus DISPCC AHB/MDP/VSYNC/LUT/ROT.
- Vendor default clock-rate tuple corresponds to MDP core 300 MHz, VSYNC 19.2 MHz, LUT 300 MHz and ROT 200 MHz; vendor maximums reach 560 MHz. Mainline DPU OPP table contains these working points and higher performance levels.
- Vendor display glue uses DSI0 PLL mux/source/shadow clocks; Mainline represents the PHY outputs as clock parents for DISPCC byte/pixel source clocks and assigns those parents in the DSI node. Do not copy vendor-only shadow clock names into Mainline.
- Vendor uses custom `qcom,khaje-dispcc` syscon with `vdd_cx-supply`; Mainline has a dedicated `qcom,sm6225-dispcc` clock driver and MDSS GDSC power-domain provider. Do not transplant the vendor `vdd_cx-supply` or custom clock provider properties into the Mainline node.

## Board-level enablement gaps

- Mainline SoC `mdss` parent is `status = "disabled"`; DSI0 and DSI PHY0 are also explicitly disabled. The DPU is under the disabled MDSS parent. SPES board DTS currently has no display overrides.
- DSI0 input graph is already connected to DPU interface1, but DSI0 output endpoint has no `remote-endpoint`; a K7 panel child node and reciprocal graph endpoint are still required.
- The DSI host reads optional `qcom,te-source` and `data-lanes` from its output endpoint. It defaults to four lanes if `data-lanes` is absent. The K7 panel is four-lane video; use explicit lane mapping only after confirming physical lane order.
- The SoC DTS already provides most core clocks, OPPs, interconnects, IOMMU and power-domain relationships. Do not invent a second display clock tree or add guessed rails. Still validate DPU OPP/DSI PHY timing at 90 Hz, the actual power-domain behavior, GPIO54/82/PMIC9 control path and 1.8 V load-switch topology before enabling nodes.

## Safety decision

No `status = "okay"` edits are made. First add a reviewable panel node/graph and board pinctrl only after exact ownership is confirmed; then validate DT schema and clock/power probe order before attempting any boot test.