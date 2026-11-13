# Source references

This project combines upstream Linux development with device-specific research. These links have different roles; a reference repository is not automatically a code dependency.

## 1. Mainline kernel base

- **W-Floyd/linux — `fogona-mainline` branch**  
  https://github.com/W-Floyd/linux/tree/fogona-mainline  
  Current local checkout is pinned to commit `c545b9e890d723b5dd0beb6a7a067a0e16088e65` (`7.3.0-rc4`). This branch is an SM6225 / Motorola Fogona mainline development base, used here as a starting point for the Redmi Note 11 port—not an upstream Redmi Note 11 release.

- **Linux kernel upstream**  
  https://kernel.org/  
  https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git  
  Official upstream kernel project and reference for mainline changes.

## 2. Redmi Note 11 / SM6225 hardware references

- **Xiaomi Spes/n Devs — organization**  
  https://github.com/xiaomi-spes-devs  
  Device-specific Android development resources for Redmi Note 11 / NFC (`spes` / `spesn`).

- **Xiaomi Spes/n Devs — kernel source**  
  https://github.com/xiaomi-spes-devs/android_kernel_xiaomi_spes  
  Downstream Android kernel tree; useful for investigating vendor drivers, board configuration and device-specific behavior. It is not the mainline kernel being built in this project.

- **sayann70 — Android 16 kernel reference**  
  https://github.com/sayann70/kernel_xiaomi_spes/tree/16  
  Android 16-compatible downstream kernel reference for `spes/spesn`; use for hardware research and comparison, not as the Mainline source.

- **sayann70 — device tree**  
  https://github.com/sayann70/device_xiaomi_spes  
  Android device configuration reference for `spes/spesn`.

## 3. Platform documentation

- **Linux kernel documentation**  
  https://docs.kernel.org/
- **Qualcomm Linux / platform code references**  
  https://github.com/torvalds/linux/tree/master/arch/arm64/boot/dts/qcom

## Provenance and attribution

- The current Mainline build source is the `W-Floyd/linux` repository, local branch `xiaomi-spes-mainline`, at the exact commit listed above. The corresponding upstream repository branch is `fogona-mainline`.
- Redmi Note 11 vendor-kernel and Android device-tree repositories are research references. Their code, firmware, configuration and licenses must be reviewed individually before reuse.
- Linux kernel code is distributed under the licenses stated in the relevant source files and top-level `COPYING` / `LICENSES` files. Preserve copyright notices and comply with the applicable license when copying or modifying code.
- This project is independent and is not affiliated with W-Floyd, Xiaomi, Qualcomm, sayann70, Xiaomi Spes/n Devs or Evolution X.

## Scope note

The target is Redmi Note 11 4G (`spes`), with Evolution X Android 16 as a future integration goal. A Mainline kernel build or a hardware reference does **not** establish Android compatibility or boot readiness.
