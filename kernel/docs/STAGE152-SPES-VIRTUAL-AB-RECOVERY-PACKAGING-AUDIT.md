# Stage 152 — SPES Virtual A/B Recovery Packaging Audit

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Scope: public device recovery/partition research for a future Custom Recovery ZIP. No partition was read or written on the user's phone.

## Device layout evidence

A public SPES/SPESN custom-ROM guide identifies Redmi Note 11 as Virtual A/B with no dedicated recovery partition and lists boot, vendor_boot, dtbo, vbmeta and vbmeta_system images in its install flow:
- https://github.com/austin4403/Custom-Roms-For-Redmi-Note-11/blob/main/Xiaomi/Redmi%20Note%2011/README.md
- https://github.com/austin4403/Custom-Roms-For-Redmi-Note-11/blob/main/Xiaomi/Redmi%20Note%2011/flashing_guide.md

AOSP's generic boot documentation explains that devices without a dedicated recovery partition can place recovery resources in vendor_boot, while the kernel is loaded from boot:
- https://source.android.com/docs/core/architecture/partitions/generic-boot

This is useful design evidence, but it does not prove the user's currently installed ROM/recovery has the same exact partition naming, boot header version, active slot, ramdisk layout or installer behavior.

## Packaging implications

- Do not target a nonexistent `recovery` partition by assumption.
- A kernel-only installer may need to update the active `boot_a` or `boot_b` partition while preserving the existing ramdisk and boot header.
- If required modules are placed in vendor_boot/vendor ramdisk, replacing or repacking vendor_boot becomes a separate high-risk operation; it must preserve all recovery resources, fstab, modules, AVB metadata and header fields.
- Do not flash both slots blindly. Virtual A/B OTA may switch the active slot.
- Do not modify dtbo, vbmeta or vbmeta_system as part of a kernel ZIP unless a verified requirement exists.
- A correct installer must check device codename (SPES, not SPESN/VIVA/VEUX), active slot, target partition existence and available image size, then preserve a restorable backup.
- Recovery ZIP compatibility depends on the installed recovery implementation (e.g. OrangeFox/TWRP/recovery), Android version and its update-binary / edify / shell support.

## Workspace gaps

- No stock `boot.img`, `vendor_boot.img`, `dtbo.img`, `vbmeta.img` or recovery image is present in the workspace.
- No AnyKernel3 or other recovery installer tree is present.
- Current build helper compiles only a selected set of modules and explicitly does not stage them into vendor_boot or vendor_dlkm.
- Current Mainline SC8551 driver is read-only identification only, so no charging-capable flash package can be built from current source.
- Latest Image/DTB build attempt has no final status marker and is incomplete/unverified.

## Required on-device evidence before packaging

Collect from the exact phone and current ROM/recovery:
- `ro.product.device`, `ro.build.fingerprint`, Android version and ROM build.
- `getprop ro.boot.slot_suffix` and `getprop ro.boot.slot`.
- `ls -l /dev/block/by-name` (or the recovery's equivalent block links).
- `cat /proc/cmdline`, `cat /proc/bootconfig` where available.
- Recovery name/version and whether it supports the proposed ZIP installer format.
- Current boot and vendor_boot image backups from the active slot, or original images extracted from the exact installed ROM package.

These details are required to produce a ZIP that targets the correct image and preserves the device's recovery/ramdisk layout.

## Safety boundary

No installer was created, no boot/vendor_boot/DTBO/vbmeta partition was written, and no flashing was attempted. A generic AnyKernel ZIP is not a substitute for verifying the exact SPES boot layout and module loading path.