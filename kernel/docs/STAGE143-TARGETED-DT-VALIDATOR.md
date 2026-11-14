# Stage 143 — repeatable targeted SPES Device Tree validator

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Status: validation helper created, syntax-checked and executed successfully.

## Helper added

Added `scripts/validate-spes-dt.sh` and uploaded it as `kernel/scripts/validate-spes-dt.sh`. It uses the isolated dtschema 2024.11 environment and:

1. Runs `dt_binding_check` for the six SPES project bindings: K7, FT3418, MAX77729, FPC1020 compatibility, SC8551 ID-only and Qualcomm REFGEN.
2. Uses the kernel-supported `CHECK_DTBS=1` path with `DT_SCHEMA_FILES` and the single `qcom/sm6225-xiaomi-spes.dtb` target. This avoids compiling every ARM64 board DTB.
3. Checks with `fdtget` that MDSS, DSI0, DSI PHY and FPC nodes all remain disabled.
4. Runs `git diff --check` and prints the target DTB SHA-256.

## Test result

Executed in the Boxadd workspace with:

- `SPES_WORKSPACE_ROOT=/workspace/ubuntu-spes-mainline`
- `DTS_SCHEMA_BIN=/workspace/ubuntu-spes-mainline/.venv-dtschema-2024.11/bin`

Result: PASS. All six binding checks completed; the targeted SPES DTB custom-schema check completed; all four safety-gate nodes were confirmed disabled; `git diff --check` passed.

Target DTB SHA-256: `4eae7c455a7572ac877785d02b79f745c78dc7f63189b57ca32a48380889ff64`.

## Validation boundary

This is a targeted SPES check, not the aggregate all-ARM64 `dtbs_check`. Full unfiltered validation still reports unrelated UFS/CoreSight schema mismatches. No hardware test, display enablement or flash was performed.
