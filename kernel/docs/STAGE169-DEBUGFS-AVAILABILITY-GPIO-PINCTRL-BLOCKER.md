# Stage 169 — Debugfs Availability Blocks GPIO/Pinctrl Inspection

Date: 2026-11-15
Device: Redmi Note 11 4G (spes), Android 16 runtime
Method: analysis of user-supplied read-only shell output.

## 1. Observed result

The user ran checks for the debugfs mount and GPIO/pinctrl debug files. Output:

- `mount | grep debugfs`: no matching mount entry.
- `/sys/kernel/debug/gpio`: does not exist.
- `/sys/kernel/debug/pinctrl`: does not exist.
- Reading the GPIO file fails with `No such file or directory`.
- No pinctrl controller directories or pinmux file headers are available.

## 2. Interpretation

The earlier empty GPIO ownership and pinctrl searches cannot be interpreted as evidence that the pins are unowned or unconfigured. The relevant debugfs interface is unavailable because debugfs is not mounted at the inspected path.

This is an observability limitation, not a finding about the electrical state of GPIO80, GPIO86, GPIO89, or GPIO98.

## 3. Evidence retained from Stage 168

The live `/proc/interrupts` snapshot showed:

```text
msmgpio 80 Edge fts_ts
```

with a cumulative count of 359253 at capture time. This confirms the currently running vendor FocalTech driver has an IRQ registered on GPIO80. It does not resolve pinmux/pinconf state or prove the full electrical configuration.

## 4. Next safe step

If the user authorizes it, debugfs can be mounted at `/sys/kernel/debug` for read-only inspection, then the GPIO and pinctrl debug files can be queried. Mounting debugfs changes runtime mount state, so it should not be performed silently as part of a read-only evidence capture.

Do not export GPIOs, change GPIO direction/value, toggle reset, alter pinctrl, read/write touchscreen registers, or modify the device tree as part of this check.

## 5. Mainline decision

- GPIO80 remains the confirmed runtime IRQ line for `fts_ts`.
- GPIO ownership and pin electrical configuration remain unresolved.
- Mainline FocalTech enablement remains blocked pending pinctrl verification and a reviewed active/suspend configuration.
- Keep the experimental Mainline touchscreen node disabled.

## 6. Project safety constraints

- No source edits or builds.
- The previous explicit build stop remains active.
- No flashing, partition writes, or installer ZIP creation.
- FPC remains disabled/skipped.
- Preserve SC8551 as the main charge-pump IC and MAX77729 as its companion.

Status: Stage 169 identifies the missing debugfs mount as the reason GPIO/pinctrl debug data cannot currently be inspected. No hardware pin configuration conclusion can be drawn from this absence.
