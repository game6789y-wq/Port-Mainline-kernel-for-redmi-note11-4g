<!--
  Project documentation for Xiaomi Redmi Note 11 4G (spes).
  Keep all build and hardware-support claims tied to verified results.
-->

<div align="center">

# Linux Mainline on Redmi Note 11 4G

### Porting upstream Linux to Xiaomi Redmi Note 11 4G — `spes`

<p>
  <img src="https://img.shields.io/badge/Device-Redmi%20Note%2011%204G-2563eb?style=for-the-badge" alt="Device">
  <img src="https://img.shields.io/badge/SoC-SM6225-0f766e?style=for-the-badge" alt="Qualcomm SM6225">
  <img src="https://img.shields.io/badge/Architecture-ARM64-7c3aed?style=for-the-badge" alt="ARM64">
  <img src="https://img.shields.io/badge/Kernel-7.3.0--rc4-0891b2?style=for-the-badge" alt="Linux 7.3.0-rc4">
  <img src="https://img.shields.io/badge/Status-Experimental-orange?style=for-the-badge" alt="Experimental">
</p>

**An experimental device-enablement project. Not a daily-driver kernel or installable release.**

[Project status](#-current-status) · [Device](#-target-device) · [Architecture](#-technical-approach) · [Roadmap](#-roadmap) · [Safety](#-safety-first)

</div>

---

## 🎯 Project goal

This repository tracks the work to port **mainline Linux** to the **Xiaomi Redmi Note 11 4G (`spes`)**.

The current integration target is **Evolution X based on Android 16**. This is a development goal—not a claim that upstream Linux can already boot Android 16 or replace the ROM's vendor kernel. Android userspace, Android boot image formats, device firmware, kernel interfaces and hardware drivers all need separate compatibility work.

The priority is to establish correct hardware support and a reproducible kernel build before attempting any device boot.

## 📱 Target device

| Property | Target |
|---|---|
| Device | Xiaomi Redmi Note 11 4G |
| Codename | `spes` |
| SoC | Qualcomm Snapdragon 680 |
| Platform | Qualcomm SM6225 |
| Architecture | ARM64 |
| Kernel family | Mainline Linux |
| Current source version | **7.3.0-rc4** |
| Android integration goal | Evolution X / Android 16 |

> **Variant matters:** Do not assume that `spes`, `spesn`, or another SM6225 device uses identical panels, touch controllers, GPIOs, regulators or firmware.

## 🔎 Current status

<details open>
<summary><strong>Active development — kernel and device-tree bring-up</strong></summary>

| Item | Status |
|---|---|
| Mainline source branch | `xiaomi-spes-mainline` |
| Source revision | `c545b9e890d723b5dd0beb6a7a067a0e16088e65` |
| Kernel version | `7.3.0-rc4` |
| ARM64 cross-compiler | GCC / AArch64 |
| Kernel `Image` build | In progress; output not yet verified |
| Device Tree source | Initial `sm6225-xiaomi-spes.dts` and related DTSI present |
| Redmi Note 11 boot test | Not performed |
| Evolution X Android 16 compatibility | Not established |
| Flashable package | Not available |

### Verified work

- [x] Mainline development source and cross-compilation workspace prepared.
- [x] Xiaomi SM6225 vendor sources inspected as hardware reference.
- [x] Initial `spes` Device Tree source added to the mainline tree.
- [x] Mainline build started for `Image` and Device Tree targets.

### Still pending

- [ ] Complete the kernel `Image` build and inspect the final artifact.
- [ ] Confirm that the `spes` DTB is selected and compiles successfully.
- [ ] Validate board-level regulators, pinctrl, storage and interrupt mappings.
- [ ] Bring up display, touchscreen, USB, charging, audio and sensors.
- [ ] Investigate Android 16 / Evolution X kernel and boot-image integration.
- [ ] Perform controlled boot testing with a verified recovery path.

</details>

> **Status is intentionally conservative:** compiling generic platform files or DTBs for other devices does not prove that the Redmi Note 11 DTB or kernel is ready.

## 🧩 Technical approach

1. **Mainline first** — use upstream Linux and existing Qualcomm SM6225 support as the foundation.
2. **Vendor tree as reference** — inspect Xiaomi's downstream kernel for board-specific hardware details; do not copy vendor code blindly.
3. **Device-specific validation** — verify panel IDs, touch controller, GPIOs, regulators, clocks and firmware against the exact `spes` hardware.
4. **Incremental bring-up** — enable and test one hardware subsystem at a time.
5. **Android integration later** — evaluate Android-specific interfaces, modules, boot image layout and SELinux expectations only after the basic kernel and device tree are sound.

### Main hardware challenges

| Subsystem | Work required |
|---|---|
| Device Tree | Complete and validate the SM6225 / `spes` board description |
| Display | Identify panel and implement a compatible display path |
| Touch | Identify controller, GPIOs, interrupts and driver support |
| Storage | Validate UFS controller, PHY, power rails and boot storage |
| Power | Regulators, clocks, thermal and charging support |
| Connectivity | USB, Wi-Fi, Bluetooth and related firmware |
| Peripherals | Audio, sensors, camera and other device-specific components |

## 🗺️ Roadmap

- [x] **Phase 0 — Workspace:** source, toolchain and initial build environment.
- [ ] **Phase 1 — Kernel build:** produce and verify a complete ARM64 kernel image.
- [ ] **Phase 2 — Device Tree:** complete and validate the `spes` DTB.
- [ ] **Phase 3 — Core platform:** storage, regulators, pinctrl, clocks and USB.
- [ ] **Phase 4 — User interface:** display and touchscreen.
- [ ] **Phase 5 — Peripherals:** audio, sensors, camera, connectivity and power management.
- [ ] **Phase 6 — Android integration:** assess Evolution X Android 16 compatibility.
- [ ] **Phase 7 — Device testing:** controlled boot tests, logs and recovery validation.

## 🛠️ Build information

The current build is performed in an ARM64 cross-compilation environment.

Expected primary outputs:

- `Image` — uncompressed ARM64 kernel image.
- `*.dtb` — compiled device tree blobs.
- `*.dtbo` — device tree overlays, if required by the final device design.

A file existing in the build directory is not sufficient evidence of device compatibility. Each artifact must be checked for the correct target, configuration and source revision.

Build scripts and reproducible instructions will be documented here after they are verified against the current source tree.

## 🛡️ Safety first

**Do not flash this project to your phone.**

This port is experimental and has not been confirmed to boot on the Redmi Note 11 4G. An incomplete or incorrect kernel/Device Tree can cause a boot failure or loss of hardware functionality.

- Do not write to `boot`, `vendor_boot`, `dtbo` or other device partitions with experimental artifacts.
- Keep the known-good Evolution X boot images and a tested recovery method.
- Do not distribute a build as a working release until it has passed device-specific validation.
- No installation or flashing instructions are provided at this stage.

## 🤝 Contributing

Hardware research, documentation, testing and carefully reviewed patches are welcome.

When submitting a change, include:

1. Exact device variant (`spes`) and hardware component.
2. Evidence or source for hardware-specific values.
3. Kernel version and commit.
4. Relevant build or boot logs, with personal data removed.
5. What was actually tested and what remains unverified.

## 📄 Disclaimer

This is an independent community research project. It is not affiliated with, endorsed by or supported by Xiaomi, Qualcomm or Evolution X. All trademarks belong to their respective owners.

---

<div align="center">

**MAINLINE LINUX · QUALCOMM SM6225 · REDMI NOTE 11 4G**

<sub>Build success is only one milestone. Verified hardware support is the real measure of progress.</sub>

</div>
