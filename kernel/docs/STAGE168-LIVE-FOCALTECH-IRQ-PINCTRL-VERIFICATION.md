# Stage 168 — Live FocalTech IRQ and Pinctrl Evidence

Date: 2026-11-15
Device: Redmi Note 11 4G (spes), Android 16 runtime
Method: user-supplied read-only shell output; no device-side writes.

## 1. Live interrupt registration

The supplied `/proc/interrupts` output contains:

```text
252: 359253 0 0 0 0 0 0 0 msmgpio 80 Edge fts_ts
```

This confirms that the running vendor touchscreen driver is registered as `fts_ts` on MSM GPIO80 with edge-triggered IRQ handling. The displayed count is 359,253 at the time of capture. It is a cumulative counter, not an interrupt rate; the single snapshot does not establish how quickly the counter is increasing or whether every event corresponds to a touch.

This live result agrees with Stage 167's source trace: vendor `fts_parse_dt()` consumes `focaltech,irq-gpio`, and `fts_irq_registration()` obtains the IRQ using `gpio_to_irq(pdata->irq_gpio)`. The Khaje vendor DTS value for that property is GPIO80.

## 2. I2C client IRQ sysfs result

The command:

```sh
cat /sys/bus/i2c/devices/1-0038/irq 2>/dev/null
```

produced no visible output. Therefore this capture provides no sysfs IRQ value for the I2C client. It does not disprove the GPIO80 registration shown in `/proc/interrupts`; the vendor driver may register its IRQ from the separate GPIO property rather than from `client->irq`.

## 3. GPIO ownership and pinctrl visibility

The filtered `/sys/kernel/debug/gpio` query produced no visible lines for GPIO80, GPIO89, GPIO86, or GPIO98.

The filtered `pinmux-pins` and `pinconf-pins` queries also produced no visible lines for those GPIOs.

These empty results are inconclusive. The capture does not establish whether the debugfs files were unavailable, the relevant entries were absent, or the grep patterns did not match the kernel's output format. It is not evidence that the pins are unowned or unconfigured.

## 4. Updated assessment

- **GPIO80 IRQ registration: confirmed at runtime** by the `fts_ts` entry in `/proc/interrupts`.
- **GPIO89 as the active touchscreen IRQ: not supported by this capture.** Stage 167's vendor source analysis says the driver uses GPIO80.
- **GPIO80/89/86/98 ownership and electrical pin configuration: unresolved.**
- **Mainline pinctrl integration: remains a blocker** until the Khaje TLMM configuration is independently verified and the appropriate active/suspend states are designed and reviewed.
- Keep the experimental Mainline touchscreen node disabled. Do not enable it solely because the IRQ registration is now confirmed.

## 5. Next safe verification

If further runtime evidence is needed, first establish whether debugfs is mounted and whether the full GPIO/pinctrl files are readable; then inspect their unfiltered headers and relevant sections. Keep this read-only. Do not request GPIO exports, direction changes, value writes, reset toggles, or interrupt reconfiguration.

## 6. Safety and project constraints

- Read-only user-supplied runtime evidence and documentation only.
- No source edits, builds, GPIO toggles, register reads, firmware updates, flashing, partition writes, or installer ZIP creation.
- The previous explicit build stop remains in force.
- FPC remains disabled/skipped in the Mainline plan.
- Preserve SC8551 as the main charge-pump IC and MAX77729 as its companion; do not substitute one for the other.

Status: Stage 168 confirms that the live `fts_ts` IRQ is GPIO80. Pinctrl and GPIO ownership remain unverified, so Mainline touch enablement is still blocked.
