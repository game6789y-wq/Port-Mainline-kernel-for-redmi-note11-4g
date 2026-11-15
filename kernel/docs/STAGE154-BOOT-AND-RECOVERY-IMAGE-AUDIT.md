# Stage 154 — SPES boot, OrangeFox and vendor_boot image audit

Date: 2026-11-15  
Scope: read-only inspection of the user-supplied `boot_a-stock.img` and `vendor_boot_a-stock.img`. No partition writes, flashing, source edits or kernel build.

## Input integrity

| File | Size | SHA-256 |
|---|---:|---|
| `boot_a-stock.img` | 134,217,728 bytes (128 MiB) | `7ac941c3b866899ab53b5ab920cf75e66861694f1be1ff60b42655ed12d1d70d` |
| `vendor_boot_a-stock.img` | 100,663,296 bytes (96 MiB) | `16d3084234c10e44e0851f7b13790b89e67348d0d035e8f72b368f6fe6449b12` |

Both file sizes match the previously reported partition sizes. These hashes identify the uploaded files; they do not prove that the partitions were pristine factory images.

## boot_a findings

- Android boot image header version 3; 4096-byte page alignment.
- Kernel component: 25,406,305 bytes. Its gzip stream decompresses successfully.
- Ramdisk component: 34,801,146 bytes; legacy LZ4 block stream, 10 blocks, successfully decompressed to 75,800,060 bytes.
- The ramdisk is not a normal Android init ramdisk. Its CPIO contains 5,330 entries, including `system/bin/recovery`, `system/etc/recovery.fstab`, `init.recovery.*.rc`, `twres/`, `system/etc/twrp.flags`, and OrangeFox-specific build metadata.
- Recovery build properties identify device `spes`, product `fox_spes` / `twrp_spes`, build date 2025-05-13, incremental `eng.jassi.20250513.173759`, and Fox codebase `2025-05-06 (4ab8d73a)`. Binary strings also contain OrangeFox-specific markers. Conclusion: the supplied boot image contains an OrangeFox (TWRP-derived) recovery environment.
- `system/etc/twrp.flags` maps `/boot` to `/dev/block/bootdevice/by-name/boot` with `slotselect`, backup and image-flash flags; it also maps `/dtbo`. It does not define a `/vendor_boot` entry. This is a recovery fstab/config observation, not proof that vendor_boot cannot be accessed by another mechanism.
- The embedded AVB footer is present. Its embedded vbmeta block reports algorithm type NONE. Its `boot` hash descriptor does not match SHA-256(salt + uploaded image bytes for the descriptor image_size). This is consistent with stale/repacked image metadata but the exact cause is unproven. Do not treat this file as a verified factory boot image or use the embedded footer alone as proof of the device's AVB chain state.

## vendor_boot_a findings

- Vendor boot image header version 3, 4096-byte page size.
- Vendor ramdisk compressed size: 2,697 bytes; legacy LZ4 decompression succeeds and yields a 6,400-byte CPIO with three entries, including `first_stage_ramdisk/fstab.qcom`.
- DTB region size: 3,858,030 bytes. It contains 12 concatenated valid FDT blobs.
- DTB variants include Bengal 1Gb DDR HD+ (board ID `0x0303`) and Bengal 2Gb DDR HD+ (board ID `0x0403`), plus Bengal-IOT, Bengalp-IOT/Bengalp and Khaje-family variants. The two Bengal variants share the reported MSM-ID but differ in board ID. The active device's exact selected DTB has not yet been identified.
- The embedded AVB footer and `vendor_boot` hash descriptor were parsed. SHA-256(salt + image bytes for the descriptor image_size) matches the embedded digest. This validates that descriptor against this uploaded image only; it does not validate the top-level vbmeta chain or bootloader lock state.

## Packaging implications

1. The supplied `boot_a` is an OrangeFox recovery-bearing image, not a clean stock Android boot image. Do not label it as stock or overwrite its ramdisk blindly.
2. SPES has A/B boot and vendor_boot partitions and no dedicated recovery partition in the user's earlier partition listing. Recovery is therefore coupled to the boot/recovery image arrangement; the exact normal-boot path still needs confirmation because the supplied boot ramdisk is OrangeFox.
3. Do not replace the vendor_boot DTB collection with one guessed Bengal DTB. First identify the runtime `qcom,msm-id` and `qcom,board-id` on the device.
4. Before an installer is designed, inspect the inactive slot and relevant AVB metadata, and confirm whether `init_boot` exists. The installer must preserve the existing recovery capability and must target only the confirmed active slot.
5. Mainline display nodes remain disabled and hardware functionality is not validated. No installable ZIP can be claimed yet.

## Next read-only evidence required

- Runtime root DT properties: `/proc/device-tree/qcom,msm-id`, `/proc/device-tree/qcom,board-id`, `/proc/device-tree/model`, and `/proc/device-tree/compatible`.
- Partition-name listing for `boot`, `vendor_boot`, `init_boot`, `recovery`, `dtbo`, `vbmeta` and `vbmeta_system`, including both slots where present.
- Determine whether the current running environment is Android or OrangeFox and how the normal Android boot path is supplied.

## Validation boundary

Read-only parsing and decompression only. No files were written back to the phone, no partition was modified, no build was run, no kernel was flashed, and no recovery ZIP or release was produced. The user's previous stop-build instruction remains in force.
