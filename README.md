<!--
  Project documentation for Xiaomi Redmi Note 11 4G (spes).
  Keep the status honest: this project is experimental and not yet bootable.
-->

<div align="center">

# Linux Mainline for Redmi Note 11 4G

**Bringing upstream Linux to the Xiaomi Redmi Note 11 4G — codename `spes`.**

<p>
  <img src="https://img.shields.io/badge/Platform-Qualcomm%20SM6225-2563eb?style=for-the-badge" alt="Platform: Qualcomm SM6225">
  <img src="https://img.shields.io/badge/Architecture-ARM64-0f766e?style=for-the-badge" alt="Architecture: ARM64">
  <img src="https://img.shields.io/badge/Status-Work%20in%20Progress-f59e0b?style=for-the-badge" alt="Status: Work in Progress">
</p>

<p>
  <a href="#project-goal">Project goal</a> ·
  <a href="#device">Device</a> ·
  <a href="#development-status">Status</a> ·
  <a href="#roadmap">Roadmap</a> ·
  <a href="#safety-notice">Safety</a>
</p>

</div>

---

## Project goal

This project explores the work required to bring a **mainline Linux kernel** to the
**Xiaomi Redmi Note 11 4G (`spes`)**. The long-term goal is to develop a maintainable
device-specific kernel and, eventually, a usable Linux environment on the phone.

This is an experimental hardware-enablement project. A successful kernel compilation
or Device Tree compilation does **not** mean that the phone can boot it.

## Device

| Item | Details |
|---|---|
| Device | Xiaomi Redmi Note 11 4G |
| Codename | `spes` |
| SoC family | Qualcomm Snapdragon 680 |
| Platform | Qualcomm SM6225 |
| CPU architecture | ARM64 |
| Target | Mainline Linux |

> **Variant warning:** `spes` and related device variants must not be treated as
> interchangeable. Device Tree, panel, touch, GPIO and regulator details must be
> verified against the exact hardware before use.

## Development status

<details open>
<summary><strong>Current stage — early bring-up</strong></summary>

- [x] Set up the kernel development workspace and cross-compilation dependencies.
- [x] Inspect the Xiaomi SM6225 vendor kernel and device-specific source.
- [x] Prepare an initial Xiaomi `spes` Device Tree skeleton.
- [x] Confirm that the initial Device Tree compiles.
- [ ] Complete and verify the ARM64 kernel image build.
- [ ] Validate the final kernel configuration for Android compatibility.
- [ ] Bring up board-specific regulators, pinctrl and storage.
- [ ] Enable display and touchscreen hardware.
- [ ] Validate USB, charging, audio, sensors and other peripherals.
- [ ] Test boot safely without writing to device partitions.

**Important:** The current Device Tree is a bring-up skeleton, not a complete,
verified or boot-ready description of the phone. Hardware support is incomplete.

</details>

## Roadmap

| Phase | Work | Goal |
|---|---|---|
| 1. Foundation | Mainline source, toolchain and build configuration | Reproducible builds |
| 2. Device Tree | SoC and Xiaomi board description | Hardware described accurately |
| 3. Core hardware | Regulators, pinctrl, UFS and USB | Basic platform bring-up |
| 4. User interface | Display, panel and touchscreen | Usable screen and input |
| 5. Peripherals | Audio, sensors, camera and power management | Broader device support |
| 6. Validation | Boot tests, logs and regression checks | Reliable experimental image |

## Technical approach

- Use upstream Linux and existing SM6225 platform support as the foundation.
- Refer to the Xiaomi vendor kernel to understand device-specific hardware.
- Treat other SM6225 devices as references only; do not copy their board wiring blindly.
- Verify GPIOs, regulators, panel identifiers and peripheral configuration against
  device-specific firmware or hardware evidence.
- Keep experimental changes isolated and document the reason for each change.

### Known bring-up challenges

- **Display:** The panel configuration and initialization sequence must be identified
  and implemented for the exact device.
- **Touchscreen:** The vendor tree includes a FocalTech touchscreen implementation;
  compatible mainline support and correct GPIO assignments are still required.
- **Storage:** UFS power rails and PHY/controller configuration need board-level
  validation.
- **Power and peripherals:** Regulators, pinctrl, USB, charging and other devices
  must be brought up incrementally.

## Build environment

Development is organized around an ARM64 cross-compilation environment. Build
instructions and scripts will be documented here as they become reproducible.

Do not treat an intermediate build artifact as a release image. Before any device
test, verify the kernel image, DTB, configuration, logs and recovery procedure.

## Safety notice

> **Do not flash this experimental kernel to your phone at this stage.**

The project is not yet confirmed to boot on the Redmi Note 11 4G. Incorrect Device
Tree data or incomplete hardware support can cause boot failure or loss of device
functionality. Keep a known-good recovery path and make backups before any future
device-level testing.

No partition-writing or installation instructions are provided until a safe,
verified test procedure is available.

## Contributing

Testing, hardware research, documentation and carefully verified patches are welcome.
When proposing a change, include:

1. The exact device variant and hardware component.
2. The source of the hardware information.
3. Kernel version and commit used for testing.
4. Build logs or boot logs, with personal information removed.
5. A clear description of what was tested and what remains unverified.

## Disclaimer

This project is independent and is not affiliated with, endorsed by or supported by
Xiaomi or Qualcomm. All product and company names belong to their respective owners.

---

<div align="center">

**Experimental research • Upstream Linux • Xiaomi Redmi Note 11 4G**

<sub>Progress is measured by verified hardware support — not just a successful build.</sub>

</div>
