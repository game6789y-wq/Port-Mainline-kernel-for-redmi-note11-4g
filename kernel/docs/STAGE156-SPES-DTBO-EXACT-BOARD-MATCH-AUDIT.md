# Stage 156 — SPES DTBO Exact Board-Match Audit

Date: 2026-11-15
Target: Xiaomi Redmi Note 11 4G (SPES), Qualcomm SM6225 / Khaje
Source: user-supplied read-only dump `dtbo_a.img`

## 1. Image integrity and DTBO table

- File size: 25,165,824 bytes (24 MiB)
- SHA-256: `562ca9360a7c18c7e3a81a8e3e6a86b9c6d791582947a8a9b22f5fb837893398`
- DTBO magic: `0xd7b7ab1e`
- Header version: 0
- Header size: 32 bytes
- Entry size: 32 bytes
- Entry count: 71
- DTBO declared total size: 7,727,854 bytes
- Page size: 4096 bytes
- All 71 entry payloads parsed as valid flattened device trees (FDT).

The partition image is larger than the declared DTBO table payload; this is not by itself evidence of corruption. The complete partition dump was parsed without relying on a filename or assumed DTB order.

## 2. Exact runtime board match

Runtime values supplied by the device:
- Model: `Qualcomm Technologies, Inc. SPES KHAJE IDP nopmi`
- Compatible: `qcom,khaje-idp qcom,khaje qcom,idp`
- `qcom,msm-id`: `0x206 : 0x10000`
- `qcom,board-id`: `0x20022 : 0x0`

DTBO Entry 20:
- Model: `Qualcomm Technologies, Inc. SPES KHAJE IDP nopmi`
- Compatible: `qcom,khaje-idp qcom,khaje qcom,idp`
- `qcom,msm-id`: `0x206 : 0x10000`
- `qcom,board-id`: `0x20022 : 0x0`
- Entry payload size: 92,025 bytes
- Entry payload offset: 2,057,024 bytes

This is an exact match on model, compatible, MSM ID, and board ID. It resolves the earlier ambiguity from the base Khaje DTB whose board ID was generic `0:0`. Entry 20 is the exact SPES variant represented in the supplied DTBO table. Runtime evidence strongly supports this board variant; the audit does not claim to have independently observed the bootloader's selection log.

Related variants in the same table are not the matching board:
- Entry 38: SPES KHAJE IDP nopmi, board ID `0x40022 : 0`
- Entry 49: SPESN KHAJE IDP nopmi, board ID `0x30022 : 0`

## 3. Important device-tree content in Entry 20

The matching overlay contains:
- DSI display/panel fragments, including TD4330 and NT36672E panel variants.
- Xiaomi touch and FocalTech touchscreen fragments.
- Synaptics TCM and Novatek touch-related fragments.
- MAX77729 node at I2C address `0x66`, compatible `maxim,max77729`, status `okay`.
- SC8551 node at I2C address `0x65`, compatible `sc,sc8551-standalone`.
- FPC1020 fingerprint node, compatible `fpc,fpc1020`, status `ok`.

### FPC requirement conflict

The stock DTBO's exact SPES overlay enables the FPC1020 node (`status = "ok"`). This conflicts with the project requirement that fingerprint support remain disabled/skipped. The mainline device tree and any future packaging must keep FPC disabled; do not copy the stock FPC enablement into the mainline configuration.

### Charging topology

The exact SPES overlay independently confirms the presence of both:
- MAX77729 at I2C 0x66
- SC8551 standalone at I2C 0x65

This supports retaining SC8551 as the charge-pump path and MAX77729 as its companion USB-C/charger/fuel-gauge subsystem. It does not prove that an unvalidated mainline driver can safely control either device. No charge-control code or DT source was changed.

### Display and touch

The overlay contains several display panel alternatives and multiple touch-controller alternatives. Entry 20 alone does not identify which panel/touch fragment was selected at runtime. Preserve the existing no-flash restriction until the active panel and touch configuration are established and the mainline display/touch path is implemented and validated.

## 4. Safety and scope

- Read-only inspection of the supplied DTBO image only.
- No DTB/DTBO source changes.
- No partition writes or flashing.
- No kernel build was run; the previous build stop remains in force.
- No installer ZIP or release artifact was created.
- The stock overlay is evidence for hardware topology, not a template to apply blindly.

## 5. Next required evidence

1. Compare the live `/proc/device-tree` display and touch nodes against the fragments in Entry 20 to identify the selected panel and touch controller.
2. Capture the complete `/dev/block/by-name` listing (not only filtered boot-related names) to confirm the full partition map and absence/presence of `init_boot` or a dedicated recovery partition.
3. Keep all packaging work non-destructive until boot/recovery handling and mainline display/touch support are proven.

Status: Exact SPES DTBO board entry identified. Flashable ZIP remains blocked by unresolved boot/recovery preservation, display/touch support, and validation requirements.
