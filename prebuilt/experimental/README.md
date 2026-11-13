# Experimental prebuilt artifacts — Redmi Note 11 4G (spes)

These files are build outputs only. They are **not a bootable kernel package** and have not been tested on-device. Do not flash them.

Build target: Linux Mainline 7.3.0-rc4, ARM64, SM6225 / Xiaomi Redmi Note 11 4G.

| File | Size | SHA-256 | Validation |
|---|---:|---|---|
| focaltech-ft3418.ko | NaN bytes | 7253460ef2b1f15efc53fbd2f740e3abc126a41218c1e7986a50caa382758f83 | Built/compiled; no device test |
| fpc1020-platform.ko | NaN bytes | 0715aff2c13d16547e423dd4bc8bfdb56889074fa16a652abb9b7ffbdaf5f525 | Built/compiled; no device test |
| sm6225-xiaomi-spes.dtb | NaN bytes | 0d9bb6dd130003031f82503e632290ba14c51973cac4fedb5c4cfdd87f4c6cbe | Built/compiled; no device test |

The full Image/modules/DTBs build was still running when these artifacts were collected. The existing Image was stale and is intentionally not included. Wi-Fi firmware/calibration, Bluetooth UART mapping, OLED DRM panel driver, charger integration, Android boot integration, and physical testing remain outstanding.
