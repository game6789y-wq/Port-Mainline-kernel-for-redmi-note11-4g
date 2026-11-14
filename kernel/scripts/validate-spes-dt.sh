#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SPES_WORKSPACE_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SRC="$ROOT/src/linux-sm6225-mainline"
OUT="$ROOT/build/spes"
DTS_SCHEMA_BIN="${DTS_SCHEMA_BIN:-$ROOT/.venv-dtschema-2024.11/bin}"
CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
ARCH=arm64
DTB="$OUT/arch/arm64/boot/dts/qcom/sm6225-xiaomi-spes.dtb"
SCHEMA_LIMITS='fpc,fpc1020:xiaomi,k7-38-0c-0a:focaltech,ft3418:maxim,max77729:southchip,sc8551-id-only:qcom,sdm845-refgen-regulator'

if [[ ! -f "$SRC/Makefile" || ! -x "$DTS_SCHEMA_BIN/dt-validate" ]]; then
  echo "Missing kernel source or dtschema tools. Install dtschema==2024.11 in $DTS_SCHEMA_BIN or set DTS_SCHEMA_BIN." >&2
  exit 1
fi
export PATH="$DTS_SCHEMA_BIN:$PATH"

schemas=(
  Documentation/devicetree/bindings/display/panel/xiaomi,k7-38-0c-0a.yaml
  Documentation/devicetree/bindings/input/touchscreen/focaltech,ft3418.yaml
  Documentation/devicetree/bindings/mfd/maxim,max77729.yaml
  Documentation/devicetree/bindings/misc/fpc,fpc1020.yaml
  Documentation/devicetree/bindings/power/supply/southchip,sc8551-id-only.yaml
  Documentation/devicetree/bindings/regulator/qcom,sdm845-refgen-regulator.yaml
)

for schema in "${schemas[@]}"; do
  echo "Checking binding: $schema"
  make -C "$SRC" O="$OUT" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
    DT_SCHEMA_FILES="$schema" dt_binding_check
done

make -C "$SRC" O="$OUT" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
  CHECK_DTBS=1 DT_SCHEMA_FILES="$SCHEMA_LIMITS" qcom/sm6225-xiaomi-spes.dtb

[[ -s "$DTB" ]] || { echo "SPES DTB missing" >&2; exit 1; }

check_disabled() {
  local path="$1"
  local value
  value="$(fdtget "$DTB" "$path" status)"
  if [[ "$value" != "disabled" ]]; then
    echo "Expected disabled DT node: $path (status=$value)" >&2
    exit 1
  fi
  echo "Verified disabled: $path"
}

check_disabled /soc/display-subsystem@5e00000
check_disabled /soc/display-subsystem@5e00000/dsi@5e94000
check_disabled /soc/display-subsystem@5e00000/phy@5e94400
check_disabled /soc/fpc1020

git -C "$SRC" diff --check
sha256sum "$DTB"
echo "PASS: six targeted bindings, SPES DTB custom-schema check, and disabled-node safety gates."
echo "Note: this is not an aggregate all-ARM64 dtbs_check or a hardware test."