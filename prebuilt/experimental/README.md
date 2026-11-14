# Experimental prebuilt artifacts — Redmi Note 11 4G (spes)

Build outputs only. These files are **not a bootable kernel package** and have not been tested on-device. **Do not flash.**

Target: Linux Mainline 7.3.0-rc4, ARM64, Qualcomm SM6225.

## Latest local Full Build — 2026-11-14

The full command `make O=../../build/spes ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j2 Image modules dtbs` completed with **exit code 0**.

| Output | Size | SHA-256 | Verification |
|---|---:|---|---|
| Kernel `Image` (local build output) | 54,704,640 bytes | `0398622b885007bb72214085970e16605685c320c2d340a65a2f1adf02ab7058` | Fresh output; build passed. **Not uploaded to this directory yet.** |
| `sm6225-xiaomi-spes.dtb` (local build output) | 64,639 bytes | `061f11f73a3b4d531bdca2aa78a15f43be89716e362bd1420a7b89a75bcc2788` | DTB target built; active overlay selection not verified. |
| `focaltech-ft3418.ko` (local build output) | 84,200 bytes | `cb0936002ea3a335c38596536c3520b31645a556950b8f5882dfbd5215c3c23a` | Module linked in this build; no device test. |
| `fpc1020-platform.ko` (local build output) | 98,232 bytes | `4c048da16a09269cd6ffe82f90a0e7d2c78aac5efd149da941b5c38fdb485e5f` | Module present; platform resources only; no SPI/TEE/HAL or device test. |

The build directory contains 1,681 `.ko` files and 1,919 `.dtb` files. These counts describe generated build outputs, not a claim that every module or DTB is relevant to this handset.

**Repository status:** the fresh kernel `Image` has not been added here. The binary upload is still pending; do not treat the SHA-256 above as a downloadable repository artifact.

## Previously uploaded experimental artifacts

| File | Size | SHA-256 | Status |
|---|---:|---|---|
| focaltech-ft3418.ko | 80,576 bytes | 7253460ef2b1f15efc53fbd2f740e3abc126a41218c1e7986a50caa382758f83 | W=1 build and checkpatch passed; no device test |
| fpc1020-platform.ko | 99,448 bytes | 0715aff2c13d16547e423dd4bc8bfdb56889074fa16a652abb9b7ffbdaf5f525 | W=1 build and checkpatch passed; platform resources only; no SPI/TEE/HAL or device test |
| sm6225-xiaomi-spes.dtb | 62,144 bytes | 0d9bb6dd130003031f82503e632290ba14c51973cac4fedb5c4cfdd87f4c6cbe | Earlier DTB build; installed overlay selection not verified |

Wi-Fi firmware/calibration, Bluetooth UART mapping, OLED DRM panel driver, charger integration, Android boot integration and physical testing remain outstanding. No flashable ZIP or GitHub Release has been created.
