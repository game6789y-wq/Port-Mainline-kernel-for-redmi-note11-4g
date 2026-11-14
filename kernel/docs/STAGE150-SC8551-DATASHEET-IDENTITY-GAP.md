# Stage 150 — SC8551 Datasheet and Silicon Identity Gap

Target: Xiaomi Redmi Note 11 4G (SPES / Qualcomm SM6225)
Scope: identify authoritative public documentation available for the SC8551 family before implementing register-level charging control.

## Public documentation located

Southchip's official website provides a one-page document titled **SC8551A DATASHEET DRAFT**, explicitly marked **SOUTHCHIP CONFIDENTIAL, SUBJECT TO CHANGE**. It describes SC8551A as a single-cell 8-A switched-capacitor direct charger, lists protection feature groups and seven 12-bit ADC channels, and names part number SC8551ACFFR. It does not expose the detailed register map, bit fields, threshold encodings, reset values or I2C timing needed to validate the Vendor driver's programming sequence.

Official sources:
- https://www.southchip.com/upload/file/SC8551A_datasheet_brief_en.pdf
- https://www.southchip.com/en/product/SC8551A

## Critical identity distinction

The available public document is for **SC8551A**, not a complete SC8551 register-level datasheet. Mainline read-only identification currently accepts raw ID 0x00 as SC8551 and 0x51 as SC8551A. Vendor driver source contains a silicon-detection path, but the exact SPES silicon revision and register-map equivalence must be confirmed from actual device identification or board/vendor evidence.

Do not infer that SC8551 and SC8551A have identical register maps or protection threshold encodings merely because the Vendor driver handles both names. The public SC8551A brief is not enough to validate the existing Vendor constants.

## Consequences for the port

- Keep the existing read-only identification driver until the full silicon identity and register map are confirmed.
- Do not enable the new charge-control driver or alter SPES protection thresholds based only on the SC8551A brief.
- Obtain the released SC8551 datasheet/register map or a verified vendor source package for the exact SPES silicon.
- At first controlled hardware test, read register 0x13 and record the exact ID/revision before any configuration write.
- Make driver initialization conditional on supported silicon/revision and reject unknown values.
- Preserve all protection defaults and fail probe if mandatory protection programming or verification fails.
- The SC8551A product page's marketing-level voltage/current ranges do not validate the SPES board's charging configuration.

## Current status

No SC8551 control writes, new Mainline driver, DTS changes, build or hardware tests were performed in this stage. This is a documentation/evidence gate, not a claim that charging support is complete.