# Stage 141 — SPES custom module alias and dependency audit

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: existing staged module metadata inspection.

## Custom modules present

All four board-specific modules below are staged with the expected kernel vermagic `7.3.0-rc4-gc545b9e890d7-dirty SMP preempt mod_unload aarch64`:

- `max77729-core.ko` — OF alias `maxim,max77729`, I2C alias `max77729`.
- `focaltech-ft3418.ko` — OF alias `focaltech,ft3418`.
- `sc8551-id.ko` — OF alias `sc,sc8551-id-only`, I2C alias `sc8551-id-only`.
- `panel-k7-38-0c-0a.ko` — OF alias `xiaomi,k7-38-0c-0a`.

REFGEN provider `qcom-refgen-regulator.ko` is also staged with OF alias `qcom,sm8250-refgen-regulator`.

## Dependency dry-run

`modprobe -d <staging> -S <release> --show-depends` completed successfully for:

- `max77729_core`
- `focaltech_ft3418`
- `sc8551_id`
- `panel_k7_38_0c_0a`
- `qcom_refgen_regulator`

The K7 panel dry-run resolves `drm_kms_helper`, `cec`, `drm_display_helper`, then the panel module. The other three custom modules have no additional module dependencies in the generated metadata.

## Disposition

The custom SPES modules are present and their OF/I2C autoload aliases and dependency metadata resolve. This does not prove their devices are enabled in the final DTB, that firmware is available, or that the drivers operate correctly on hardware. FPC remains intentionally excluded; the staging tree contains zero FPC-named modules.

## Validation / safety

- Existing staging inspection only; no source change or new build.
- No device boot, touchscreen, charger, PMIC or panel runtime test.
- MDSS/DSI0/DSI PHY remain disabled; FPC remains disabled.
- No flash or release artifact.
