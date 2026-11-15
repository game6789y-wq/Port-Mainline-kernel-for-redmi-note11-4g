# Stage 155 — Runtime Khaje identity and vendor_boot DTB match audit

Date: 2026-11-15  
Scope: compare user-provided live device-tree identity with the DTB candidates parsed from the uploaded `vendor_boot_a-stock.img`. Read-only; no build, partition write or flash.

## Runtime identity supplied by the device

- `ro.boot.slot_suffix`: `_a`
- `ro.build.version.sdk`: `36`
- `ro.bootmode`: `unknown`
- `ro.build.fingerprint` and `ro.bootimage.build.fingerprint`: `Redmi/spes_global/spes:13/TKQ1.221114.001/V14.0.5.0.TGCMIXM:user/release-keys`
- Root `model`: `Qualcomm Technologies, Inc. SPES KHAJE IDP nopmi`
- Root `compatible`: `qcom,khaje-idp qcom,khaje qcom,idp`
- Runtime `qcom,msm-id` cells: `0x00000206, 0x00010000`
- Runtime `qcom,board-id` cells: `0x00020022, 0x00000000`

The SDK value and Android 13-style build fingerprint disagree at the release-label level. The supplied properties alone do not resolve whether this is a custom ROM spoofing the fingerprint or a mixed system/vendor image. Recovery-specific properties are empty and bootmode is unknown, so those fields do not conclusively identify the current execution environment.

## Parsed vendor_boot DTB candidates

The uploaded vendor_boot image is header v3, page size 4096, vendor ramdisk size 2697, header size 2112 and DTB payload size 3,858,030 bytes at file offset 8192. Twelve concatenated FDT blobs parse successfully.

Candidate 9 (1-based order; offset 2,512,298; size 338,399 bytes):
- model: `Qualcomm Technologies, Inc. Khaje SoC`
- compatible: `qcom,khaje`
- `qcom,msm-id`: `0x00000206, 0x00010000` — exact match to the runtime MSM ID.
- `qcom,board-id`: `0x00000000, 0x00000000` — not an exact match to the runtime board ID `0x00020022, 0x00000000`.

Other Khaje-family candidates are Khajeg, Khajep and Khajeq, with different MSM IDs; they do not match the supplied runtime MSM ID. The other Bengal/Bengalp candidates also do not match it.

## Interpretation and unresolved point

The runtime MSM ID and compatible strings identify the Khaje family, and candidate 9 is the only vendor_boot DTB candidate with the exact MSM ID. However, its board-id cells differ from the live board-id. It is therefore safe to identify candidate 9 as the Khaje-family candidate, but not to claim that it is conclusively the selected final hardware DTB or that all board overlays have been accounted for.

The live board-id may be represented/consumed through bootloader-specific selection and DTBO overlay logic; the uploaded vendor_boot alone does not prove which DTBO entry is active. Inspect the active `dtbo_a` image and its table entries/overlay properties before deciding the exact final device tree.

## Partition-layout evidence

The user-provided partition listing shows `boot_a/b`, `vendor_boot_a/b`, `dtbo_a/b`, `vbmeta_a/b` and `vbmeta_system_a/b`. No `init_boot` or dedicated `recovery` entry appeared in that filtered listing. This is evidence from the visible by-name links, not a full GPT dump.

## Next required read-only evidence

1. Inspect active `dtbo_a` size and create a read-only backup for parsing. Do not flash or modify it.
2. Parse the DTBO table and identify overlay entries carrying board-id `0x00020022` or compatible Khaje/SPES board metadata.
3. Confirm the full partition-name list and boot environment before choosing an installer target.

## Validation boundary

No kernel build was started (the user's earlier stop-build instruction remains active). No source code, device-tree source, partition or recovery image was modified. No flashable ZIP or release is produced.
