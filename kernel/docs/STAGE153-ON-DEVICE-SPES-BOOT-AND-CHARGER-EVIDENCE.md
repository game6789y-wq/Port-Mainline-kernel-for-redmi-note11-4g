# Stage 153 — On-Device SPES Boot and Charger Evidence

Target device: Xiaomi Redmi Note 11 4G, codename `spes`
Source: user-provided read-only root-shell output on 2026-11-14
No partition was written or read as a full image by this stage.

## Confirmed device / software identity

- `ro.product.device=spes`
- `ro.product.vendor.device=spes`
- Build fingerprint: `Redmi/spes_global/spes:13/TKQ1.221114.001/V14.0.5.0.TGCMIXM:user/release-keys`
- `ro.build.version.release=16`
- Active slot: `_a`
- `ro.boot.slot` was empty.
- `ro.bootmode=unknown`.
- TWRP and OrangeFox version properties were empty.

The fingerprint contains Android 13 / MIUI V14 identifiers while the reported Android release property is 16. This is an unusual mismatch and may reflect a ROM property override; do not infer the installed ROM/recovery compatibility from the fingerprint alone. Recovery version properties being empty does not prove that no custom recovery is installed, only that these properties were not populated in the running OS.

## Partition layout observed

The live `/dev/block/by-name` list contains A/B pairs for:
- `boot_a` / `boot_b`
- `vendor_boot_a` / `vendor_boot_b`
- `dtbo_a` / `dtbo_b`
- `vbmeta_a` / `vbmeta_b`
- `vbmeta_system_a` / `vbmeta_system_b`

No `recovery` partition appears in the supplied list. This supports a boot/vendor_boot-based recovery design, but the installed recovery implementation and exact boot image header/ramdisk contents remain unknown.

Active slot is `_a`; a future installer must not blindly write both slots. It must detect and validate the active slot at install time and preserve the stock boot/vendor_boot images for rollback.

## Charger evidence from kernel log

The supplied `dmesg` excerpt contains:
- Repeated `[sc8551-STANDALONE]` messages reading register `0x0c = 0x06`.
- Vendor charger logic reports `sc8551 charger disable` and `POWER_SUPPLY_PROP_CHARGING_ENABLED: disable`.
- MAX77729 reports PD detach events.

This is strong evidence that the currently running Vendor kernel has a live SC8551 standalone charger driver and a separate MAX77729 companion path. It supports the project requirement to retain SC8551 as the charging-control IC and MAX77729 for its separate companion role. It does not establish the electrical meaning of register 0x0c value 0x06 by itself, nor does it prove that the charger is currently enabled or that the Mainline driver works.

## Mainline source/build implications

The workspace Mainline build helper currently requires `CONFIG_CHARGER_SC8551_ID_ONLY=m`, and the corresponding driver is explicitly read-only. No SC8551 charge-control driver is present in the Mainline config or source. The helper also explicitly leaves the candidate K7 panel driver disabled and refuses to enable FPC1020.

The existing Image hash is `0398622b885007bb72214085970e16605685c320c2d340a65a2f1adf02ab7058`; existing SPES DTB hash is `061f11f73a3b4d531bdca2aa78a15f43be89716e362bd1420a7b89a75bcc2788`. Their timestamps predate the incomplete latest build attempt, so they are not evidence of a newly completed build.

## Next required read-only device checks

Before packaging, collect exact byte sizes and boot image headers for the active slot, without writing to any partition:
- `blockdev --getsize64 /dev/block/by-name/boot_a`
- `blockdev --getsize64 /dev/block/by-name/vendor_boot_a`
- `blockdev --getsize64 /dev/block/by-name/dtbo_a`
- `blockdev --getsize64 /dev/block/by-name/vbmeta_a`
- Read only the first 64 bytes of boot_a and vendor_boot_a for header identification.
- Identify the currently installed recovery app/version from installed apps or recovery UI, and obtain exact matching stock boot/vendor_boot images from the installed ROM package.

No flashable ZIP was created or tested. No device partition was modified.