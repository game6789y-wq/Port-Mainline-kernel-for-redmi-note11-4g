# Stage 157 — Live Device Tree Visibility and Complete Partition Map

Date: 2026-11-15
Target: Xiaomi Redmi Note 11 4G (SPES), Qualcomm SM6225 / Khaje
Evidence: user-supplied command output from the running Android environment.

## 1. Live Device Tree query result

The user's query searched `/proc/device-tree` for files named `compatible`, then filtered compatible strings containing:
- dsi, panel
- touch, fpc
- sc8551, max77729

The command returned no matching nodes and no compatible strings.

This is an inconclusive visibility/query result. It does not establish that the hardware or nodes are absent. The next step is to verify which device-tree mount/path is exposed in the current environment and whether the process can read it.

## 2. Complete visible by-name partition listing

The supplied `ls -1 /dev/block/by-name` output includes:
- `boot_a`, `boot_b`
- `vendor_boot_a`, `vendor_boot_b`
- `dtbo_a`, `dtbo_b`
- `vbmeta_a`, `vbmeta_b`
- `vbmeta_system_a`, `vbmeta_system_b`
- `rescue`
- `super`, `userdata`, `metadata`, and other platform partitions.

No partition named `recovery` or `init_boot` appears in the supplied complete listing.

The presence of a partition named `rescue` is noted, but its content and role are not established by this listing. Do not treat it as a recovery partition without inspection.

## 3. Packaging implications

- The visible layout is consistent with an A/B boot arrangement using boot and vendor_boot slots.
- There is no separately named recovery or init_boot partition in the supplied listing.
- The previous boot image inspection found an OrangeFox recovery ramdisk in the supplied `boot_a` image. That makes preserving the current recovery-capable boot image especially important.
- No installer target or slot-write strategy should be selected until the current boot context, active slot, recovery behavior, and rescue partition role are established.

## 4. Safety and scope

- Read-only evidence only.
- No source/device-tree modifications.
- No partition writes, flashing, or build execution.
- The prior explicit build stop remains in force.
- No flashable ZIP has been created or validated.

## 5. Next evidence required

Run a read-only diagnostic to establish:
1. Whether `/proc/device-tree`, `/sys/firmware/devicetree/base`, or another device-tree path is mounted and readable.
2. Current boot context and recovery indicators.
3. The `rescue` partition's size and metadata only; do not dump or write it yet.

Status: Partition names are now fully enumerated. Live hardware-node discovery remains blocked by device-tree visibility.
