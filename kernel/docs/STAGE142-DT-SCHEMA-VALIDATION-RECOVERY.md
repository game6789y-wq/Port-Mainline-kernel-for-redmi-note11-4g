# Stage 142 — Device Tree schema validation recovery

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: custom binding checks and custom-node DT validation passed with dtschema 2024.11.

## Toolchain issue resolved

The original isolated dtschema 2024.4 environment failed during schema generation with an internal `AttributeError: 'bool' object has no attribute 'pop'`. A separate virtual environment was created with `dtschema==2024.11`; the system Python and original environment were not modified.

With dtschema 2024.11, schema generation completes and the following targeted `dt_binding_check` targets all exit 0:

- K7 panel: `xiaomi,k7-38-0c-0a.yaml`
- FocalTech FT3418 touchscreen: `focaltech,ft3418.yaml`
- MAX77729 MFD: `maxim,max77729.yaml`
- FPC1020 compatibility binding: `fpc,fpc1020.yaml`
- SC8551 ID-only: `southchip,sc8551-id-only.yaml`
- Qualcomm REFGEN: `qcom,sdm845-refgen-regulator.yaml`

The K7 binding example initially emitted `unit_address_vs_reg` warnings because two example nodes had unit addresses but no `reg` property. The example-only node names were cleaned (`pinctrl@f100000` -> `pinctrl`, `dsi@5e94000` -> `dsi`); targeted K7 binding check now completes without those DTC warnings.

## Vendor-prefix correction

Full DT validation flagged the FPC-specific `fpc,enable-on-boot` property because `fpc` was not registered in `vendor-prefixes.yaml`. Added the vendor-prefix entry `fpc` — Fingerprint Cards AB. This is schema metadata only: it does not enable the FPC node or driver. FPC remains disabled in the DT and build config, and no FPC module is staged.

The two small schema changes are captured in draft patch `kernel/patches/drafts/0002-dt-vendor-prefix-and-example-cleanup.patch`. Reverse/apply checks passed and file hashes were unchanged after the patch verification cycle.

## Target-specific DTB schema check

The generated `processed-schema.json` was used with the kernel build system's targeted check path:

`CHECK_DTBS=1 DT_SCHEMA_FILES='fpc,fpc1020:xiaomi,k7-38-0c-0a:focaltech,ft3418:maxim,max77729:southchip,sc8551-id-only:qcom,sdm845-refgen-regulator' make O=build/spes ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/sm6225-xiaomi-spes.dtb`

This target-specific check completed with exit status 0. It compiles only the SPES DTB and runs `dt-validate` limited to the six project-specific schemas. The same six schema limits were also run directly against the DTB and passed:

- `fpc,fpc1020`
- `xiaomi,k7-38-0c-0a`
- `focaltech,ft3418`
- `maxim,max77729`
- `southchip,sc8551-id-only`
- `qcom,sdm845-refgen-regulator`

A full unfiltered `dt-validate` still reports unrelated existing upstream schema mismatches in the UFS `clocks`/`clock-names` and CoreSight ETR `iommus` nodes. The aggregate `dtbs_check` target builds all ARM64 DTBs; it was not run to completion. Do not report full-tree `dtbs_check` as passed. The target-specific SPES DTB schema check above is the validation that passed.

## Validation / safety

- Targeted `dt_binding_check`: all six project-specific bindings PASS.
- Targeted `dt-validate`: all six project-specific schemas PASS on the SPES DTB.
- `git diff --check`: PASS.
- No display source/DT activation; MDSS/DSI0/DSI PHY remain disabled.
- FPC remains disabled/skipped; no hardware test or flash.
