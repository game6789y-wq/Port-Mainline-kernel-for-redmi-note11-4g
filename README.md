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

[Project status](#-current-status) · [Device](#-target-device) · [Sources](#-source-code--credits) · [Roadmap](#-roadmap) · [Safety](#-safety-first)

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
| Mainline source repository | [W-Floyd/linux](https://github.com/W-Floyd/linux) |
| Upstream source branch | `fogona-mainline` |
| Local working branch | `xiaomi-spes-mainline` |
| Pinned source revision | [`c545b9e890d723b5dd0beb6a7a067a0e16088e65`](https://github.com/W-Floyd/linux/commit/c545b9e890d723b5dd0beb6a7a067a0e16088e65) |
| Kernel version | `7.3.0-rc4` |
| ARM64 cross-compiler | GCC / AArch64 |
| Full kernel `Image modules` build | **Completed successfully — exit code 0** (latest recorded build) |
| Kernel `Image` | Build output present; SHA-256 `de1d6ef64d1870b674c831d90e0c0814cb19351e981aa1f8dfdccbfe96522266` |
| `spes` DTB | Latest target build passed; SHA-256 `4eae7c455a7572ac877785d02b79f745c78dc7f63189b57ca32a48380889ff64` |
| K7 38-0C-0A display bridge | Driver built; 90Hz fixed mode only; no hardware test |
| Fingerprint | **Intentionally skipped / disabled**; no fingerprint scanning, TEE or HAL work in this porting phase |
| Redmi Note 11 boot test | Not performed; MDSS, DSI0 and DSI PHY remain disabled in the board DT |
| Evolution X Android 16 compatibility | Not established |
| Flashable package | Not available |

**Source clarification:** the selected `fogona-mainline` branch is an SM6225 / Motorola Fogona mainline development base. It is being adapted for `spes`; it is not an already completed Redmi Note 11 mainline port.

### Verified work

- [x] Mainline development source and cross-compilation workspace prepared.
- [x] Xiaomi SM6225 vendor sources inspected as hardware reference.
- [x] Initial `spes` Device Tree source added to the mainline tree.
- [x] Kernel `Image` and module builds completed successfully (exit code 0).
- [x] K7 38-0C-0A panel bridge driver and dormant board display graph added.
- [x] SM6375 DSI PHY / PLL, DSI clock path, regulator and power-domain dependencies audited.
- [x] DSI DSC-adjusted clock estimate corrected; 90Hz remains an unvalidated analytical target.
- [x] K7 DSC 1.1 PPS parameters, one-slice-per-packet transport and SM6225 one-encoder/two-slice DPU path audited in source.
- [x] SM6225 DPU DSC → PingPong → INTF → DSI kickoff and CTL flush sequence audited in source.

### Latest build artifacts and validation

| Artifact | SHA-256 | Status |
|---|---|---|
| Kernel `Image` | `de1d6ef64d1870b674c831d90e0c0814cb19351e981aa1f8dfdccbfe96522266` | Build output; not boot-tested |
| `sm6225-xiaomi-spes.dtb` | `4eae7c455a7572ac877785d02b79f745c78dc7f63189b57ca32a48380889ff64` | DTB build passed; display graph remains dormant |
| `panel-k7-38-0c-0a.ko` | `8f092d6c81f90e2f818402474bdef8d2f9f8f62abbc5658d3cd76f4c97e525a0` | Module build passed; no hardware test |

**Display engineering notes:** the active stock panel is K7 38-0C-0A, 1080×2400. The port currently targets a fixed 90Hz mode. The corrected Mainline DSI host estimate for the DSC mode is approximately 136.581MHz byte clock and 1.093Gbps per lane; these are calculated values, not measurements. PLL lock, first frame, brightness and ESD behavior have not been validated on the phone.

**Validation caveat:** binding documentation validation passed with `dt-doc-validate`. Full `dtbs_check` remains blocked by an internal error in the installed dtschema 2024.4 (`AttributeError: 'bool' object has no attribute 'pop'`), so full schema validation is not claimed. `git diff --check` passed.

The latest build manifest and engineering audit are maintained in the development workspace. Static audits confirm the software path configures a 128-byte DSC PPS (type 0x0A, LP mode) after panel initialization, with 540-byte slice chunks and two packets per line. The SM6225 DPU catalog has one DSC block; its software path assigns both slices to that encoder. Source-level follow-up (Stage 108) confirms one DSC_0 / PINGPONG_0 / LM_0 / INTF_1 route to DSI0; DPU configures DSC and PingPong, flushes DSC_0 and INTF_1 through CTL, then starts the encoder. These are source-level findings only, not proof of hardware operation. No Recovery ZIP, installable package or tested release is available.

### Still pending

- [x] Finish the full `Image modules dtbs` build and verify exit code `0`.
- [x] Rebuild and record SHA-256 for the fresh kernel `Image`.
- [ ] Confirm that the `spes` DTB is selected by the actual device and validate the overlay.
- [ ] Complete full Device Tree schema validation after repairing/updating the local dtschema toolchain.
- [ ] Validate board-level regulators, pinctrl, storage and interrupt mappings.
- [ ] Validate the K7 panel on hardware: regulator sequencing, DSI PLL lock, DSC PPS, first frame, brightness and ESD.
- [ ] Complete Wi-Fi firmware/calibration, Bluetooth UART and charger integration.
- [ ] Bring up USB, audio and remaining sensors.
- [ ] Investigate Android 16 / Evolution X kernel and boot-image integration.
- [ ] Perform controlled boot testing with a verified recovery path.

</details>

> **Status is intentionally conservative:** successful compilation and static driver audits do not prove that the Redmi Note 11 DTB or kernel is ready to boot.

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
- [x] **Phase 1 — Kernel build:** produce and verify a complete ARM64 kernel image (build-only; no device boot).
- [ ] **Phase 2 — Device Tree:** complete and validate the `spes` DTB.
- [ ] **Phase 3 — Core platform:** storage, regulators, pinctrl, clocks and USB.
- [ ] **Phase 4 — User interface:** validate K7 display and touchscreen on hardware.
- [ ] **Phase 5 — Peripherals:** audio, sensors, camera, connectivity and power management.
- [ ] **Phase 6 — Android integration:** assess Evolution X Android 16 compatibility.
- [ ] **Phase 7 — Device testing:** controlled boot tests, logs and recovery validation.

## 📚 Source code & credits

This project uses a Mainline development base and separate device-specific repositories for hardware research. **These sources have different roles; reference repositories are not automatically code dependencies.**

| Source | Purpose |
|---|---|
| [W-Floyd/linux — `fogona-mainline`](https://github.com/W-Floyd/linux/tree/fogona-mainline) | Current Mainline development base; pinned commit shown above |
| [Linux kernel upstream](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git) | Official upstream kernel reference |
| [Xiaomi Spes/n Devs](https://github.com/xiaomi-spes-devs) | Device-specific Android development resources |
| [Xiaomi Spes/n kernel tree](https://github.com/xiaomi-spes-devs/android_kernel_xiaomi_spes) | Downstream kernel and hardware-driver research |
| [sayann70 Android 16 kernel](https://github.com/sayann70/kernel_xiaomi_spes/tree/16) | Android 16 vendor-kernel comparison/reference |
| [sayann70 device tree](https://github.com/sayann70/device_xiaomi_spes) | Redmi Note 11 device configuration reference |
| [Linux kernel documentation](https://docs.kernel.org/) | Kernel development and driver documentation |

See **[SOURCES.md](SOURCES.md)** for detailed provenance, pinned revision, reference roles and license notes.

### Attribution & licensing

- Preserve original copyright notices and license headers in all reused code.
- Check the license of each source file and repository before copying or redistributing code.
- The Linux kernel is primarily GPL-2.0-only; individual files may carry other compatible or separately stated licenses. Follow the license actually present in each file.
- Hardware research references do not imply endorsement or authorship by their maintainers.

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

This is an independent community research project. It is not affiliated with, endorsed by or supported by Xiaomi, Qualcomm, Evolution X or the maintainers of the referenced repositories. All trademarks belong to their respective owners.

---

<div align="center">

**MAINLINE LINUX · QUALCOMM SM6225 · REDMI NOTE 11 4G**

<sub>Build success is only one milestone. Verified hardware support is the real measure of progress.</sub>

</div>
