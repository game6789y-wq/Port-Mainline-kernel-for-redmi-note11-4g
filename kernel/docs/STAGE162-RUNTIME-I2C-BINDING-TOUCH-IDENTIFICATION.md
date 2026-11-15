# Stage 162 — Runtime I2C Driver Binding and Touch Identification

Date: 2026-11-15
Target: Xiaomi Redmi Note 11 4G (SPES), Qualcomm SM6225 / Khaje
Evidence: user-supplied `/sys/bus/i2c/devices` output and live device-tree panel properties.

## 1. Active touchscreen identification

The runtime I2C inventory shows:
- Device: `1-0038`
- Name: `fts`
- OF compatible: `focaltech,fts`
- Driver: `fts_ts`
- OF path: `/soc/i2c@4a88000/touchscreen`

This is direct evidence that the FocalTech-compatible touchscreen at I2C bus 1, address 0x38 is bound to the running vendor driver `fts_ts`. It is the best-supported hardware target for further touchscreen port research.

Important distinction: this does not establish that the in-tree mainline `focaltech-ft3418` driver supports this exact controller. Stage 161 found its OF match table expects `focaltech,ft3418`, not `focaltech,fts`. The controller silicon/model and protocol must still be identified from vendor driver source, firmware, and device properties before choosing or adapting a mainline driver.

## 2. Other touchscreen candidates

- Novatek node at I2C address 0x62 appears as `0-0062`, name `dummy`, driver `dummy`. It is not bound to a Novatek touchscreen driver in this runtime inventory.
- No Synaptics TCM I2C client appears in the supplied I2C inventory.
- The Xiaomi generic touch node remains present in the device tree, but no separate I2C binding was shown for it.

The lack of a matching dmesg output in the supplied command is inconclusive; it does not prove no probe logs exist.

## 3. Charging device binding confirmation

Runtime I2C inventory confirms:
- SC8551 at `0-0065`, name `sc8551-standalone`, driver `sc8551-charger`, compatible `sc,sc8551-standalone`.
- MAX77729 at `0-0066`, name `max77729`, driver `max77729`, compatible `maxim,max77729`.

This confirms both devices are bound in the currently running vendor kernel. It does not validate the mainline SC8551 implementation or actual charging behavior.

## 4. Panel node properties

Both panel nodes exist in the live device tree:
- `...k7_38_0c_0a_fhdp_video`: model `xiaomi 38 0c 0a VIDEO PANEL`
- `...k7_38_0c_0b_fhdp_video`: model `xiaomi 38 0c 0b VIDEO PANEL`

The boot command line names the 0a panel:
`qcom,mdss_dsi_panel_k7_38_0c_0a_fhdp_video`

The panel query did not print a `status` property for either node. In a device tree, absence of a status property is not equivalent to a literal disabled status; nevertheless, node presence alone does not prove which panel driver registered or which panel initialized. Runtime DRM/DSI registration and panel sysfs evidence are still needed.

## 5. Mainline port implications

1. Prioritize analysis of the vendor `fts_ts` implementation and identify the exact controller chip before adapting mainline FocalTech code.
2. Do not force `focaltech,fts` to bind to the existing FT3418 driver until compatibility is proven.
3. Retain SC8551 and MAX77729 as separate required devices.
4. Keep FPC disabled in the mainline tree.
5. Treat the 0a panel as the boot-argument-selected candidate, but do not enable it until display controller/PHY and panel sequencing are validated.

## 6. Safety

- Read-only analysis only.
- No source edits, builds, flashing, partition writes, or ZIP creation.
- Previous explicit build stop remains active.

Status: Active FocalTech-compatible touch binding identified at I2C 1-0038. Exact controller silicon and mainline driver compatibility remain unresolved. Runtime charging-driver bindings confirmed. Panel variant selection has a strong 0a candidate from boot arguments but still needs runtime display registration evidence.
