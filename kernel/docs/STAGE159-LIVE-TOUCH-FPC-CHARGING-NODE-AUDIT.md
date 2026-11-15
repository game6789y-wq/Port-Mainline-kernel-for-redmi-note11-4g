# Stage 159 — Live Touch, Fingerprint and Charging Node Audit

Date: 2026-11-15
Target: Xiaomi Redmi Note 11 4G (SPES), Qualcomm SM6225 / Khaje
Evidence: user-supplied live `/sys/firmware/devicetree/base` query.

## 1. Nodes found in the live device tree

| Path | Compatible | Status / address evidence |
|---|---|---|
| `/soc/xiaomi_touch` | `xiaomi-touch` | `status = "ok"` |
| `/soc/fpc1020` | `fpc,fpc1020` | `status = "ok"` |
| `/soc/i2c@4a84000/sc8551-charger@65` | `sc,sc8551-standalone` | Node name indicates I2C address 0x65; raw `reg` property was printed as non-text |
| `/soc/i2c@4a84000/max77729@66` | `maxim,max77729` | `status = "okay"`; node name indicates I2C address 0x66 |
| `/soc/i2c@4a84000/max77729@66/max77729-usbc` | `maxim,max77729-usbc` | Child function node found |

The command output does not show a panel-compatible node matching the searched strings. This does not disprove the panel: boot arguments identify the selected panel separately as `qcom,mdss_dsi_panel_k7_38_0c_0a_fhdp_video`, with LCM identifier `dsi_panel_c3q_45_02_0c_fhdp_video_display`.

## 2. Touchscreen finding

The live tree exposes a generic Xiaomi touch node:
- Path: `/soc/xiaomi_touch`
- Compatible: `xiaomi-touch`
- Status: `ok`

This does not identify the underlying touch controller IC. More properties, child nodes, firmware names, and driver binding evidence are needed before selecting a mainline touchscreen driver.

## 3. Fingerprint finding

The live stock tree exposes:
- Path: `/soc/fpc1020`
- Compatible: `fpc,fpc1020`
- Status: `ok`

This confirms the stock runtime tree enables the FPC node. Project requirement remains to keep fingerprint scanning disabled/skipped in the mainline device tree and build configuration. Do not copy the stock FPC enablement.

## 4. Charging topology

The live tree confirms:
- SC8551 standalone charger at I2C node `@65`.
- MAX77729 at I2C node `@66`.
- MAX77729 USB-C child node.

This supports preserving both devices and the user's established requirement that SC8551 remains the charge-pump controller with MAX77729 retained as its companion. It does not establish safe mainline driver behavior or charging operation.

## 5. Next evidence required

1. Inspect the complete property list and child nodes under `/soc/xiaomi_touch`.
2. Find DSI/panel nodes by node path names, not only compatible-string filtering; inspect compatible, status, panel model, and phandle references.
3. Inspect kernel driver bindings and runtime logs for the Xiaomi touch node to identify the actual controller.
4. Keep FPC disabled in mainline.
5. No source changes, builds, flashing, partition writes, or installer ZIP are authorized by this audit.

Status: Live stock-tree topology for touch, FPC, SC8551 and MAX77729 is confirmed. Exact touch IC and live panel-node mapping remain unresolved.
