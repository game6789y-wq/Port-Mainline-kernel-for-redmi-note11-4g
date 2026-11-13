# Experimental prebuilt artifacts — Redmi Note 11 4G (spes)

Build outputs only. These files are **not a bootable kernel package** and have not been tested on-device. **Do not flash.**

Target: Linux Mainline 7.3.0-rc4, ARM64, Qualcomm SM6225.

| File | Size | SHA-256 | Status |
|---|---:|---|---|
| focaltech-ft3418.ko | 80,576 bytes | 7253460ef2b1f15efc53fbd2f740e3abc126a41218c1e7986a50caa382758f83 | W=1 build and checkpatch passed; no device test |
| fpc1020-platform.ko | 99,448 bytes | 0715aff2c13d16547e423dd4bc8bfdb56889074fa16a652abb9b7ffbdaf5f525 | W=1 build and checkpatch passed; platform resources only; no SPI/TEE/HAL or device test |
| sm6225-xiaomi-spes.dtb | 62,144 bytes | 0d9bb6dd130003031f82503e632290ba14c51973cac4fedb5c4cfdd87f4c6cbe | DTB compile passed; installed overlay selection not verified |

The full Image/modules/DTBs build was still running when these artifacts were collected. The existing Image was stale and is intentionally not included. Wi-Fi firmware/calibration, Bluetooth UART mapping, OLED DRM panel driver, charger integration, Android boot integration and physical testing remain outstanding.
