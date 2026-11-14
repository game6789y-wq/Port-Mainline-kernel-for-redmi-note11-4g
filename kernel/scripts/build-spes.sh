#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SPES_WORKSPACE_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SRC="$ROOT/src/linux-sm6225-mainline"
OUT="$ROOT/build/spes"
STAGE="$ROOT/build/spes-module-staging"
if [[ -f "$ROOT/refs/spes-android.config" ]]; then
  FRAGMENT="$ROOT/refs/spes-android.config"
else
  FRAGMENT="$SCRIPT_DIR/../config/spes-android.config"
fi
CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
JOBS="${JOBS:-2}"
ARCH=arm64

if [[ ! -f "$SRC/Makefile" || ! -f "$FRAGMENT" ]]; then
  echo "Missing Mainline source or SPES config fragment" >&2
  exit 1
fi
mkdir -p "$OUT" "$STAGE"

make -C "$SRC" O="$OUT" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" defconfig
"$SRC/scripts/kconfig/merge_config.sh" -m -O "$OUT" "$OUT/.config" "$FRAGMENT"
make -C "$SRC" O="$OUT" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" olddefconfig

require_enabled() {
  local opt="$1"
  if ! grep -Eq "^${opt}=(y|m)$" "$OUT/.config"; then
    echo "Required option is not enabled: $opt" >&2
    exit 1
  fi
}

require_module() {
  local opt="$1"
  if ! grep -q "^${opt}=m$" "$OUT/.config"; then
    echo "Required module option is not set to m: $opt" >&2
    exit 1
  fi
}

for opt in CONFIG_ARM64 CONFIG_ARCH_QCOM CONFIG_OF CONFIG_ANDROID_BINDER_IPC \
           CONFIG_ANDROID_BINDERFS CONFIG_SECURITY_SELINUX CONFIG_DM_VERITY \
           CONFIG_EXT4_FS CONFIG_F2FS_FS CONFIG_MODULES CONFIG_DRM_MSM \
           CONFIG_DRM_MSM_DSI CONFIG_DRM_MSM_DSI_7NM_PHY \
           CONFIG_RPMSG_QCOM_GLINK_RPM CONFIG_QCOM_SMD_RPM \
           CONFIG_REGULATOR_QCOM_SMD_RPM CONFIG_SPMI \
           CONFIG_SPMI_MSM_PMIC_ARB CONFIG_MFD_SPMI_PMIC \
           CONFIG_PINCTRL_QCOM_SPMI_PMIC CONFIG_REGULATOR_QCOM_SPMI; do
  require_enabled "$opt"
done

for opt in CONFIG_DRM_PANEL_XIAOMI_K7_38_0C_0A CONFIG_REGULATOR_QCOM_REFGEN \
           CONFIG_TOUCHSCREEN_FOCALTECH_FT3418 CONFIG_MFD_MAX77729_CORE \
           CONFIG_CHARGER_SC8551_ID_ONLY; do
  require_module "$opt"
done

if grep -q '^CONFIG_FPC1020_PLATFORM=[ym]$' "$OUT/.config"; then
  echo "FPC fingerprint support must remain disabled" >&2
  exit 1
fi

make -C "$SRC" -j"$JOBS" O="$OUT" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" Image modules qcom/sm6225-xiaomi-spes.dtb

IMAGE="$OUT/arch/arm64/boot/Image"
DTB="$OUT/arch/arm64/boot/dts/qcom/sm6225-xiaomi-spes.dtb"
[[ -s "$IMAGE" ]] || { echo "Kernel Image missing" >&2; exit 1; }
[[ -s "$DTB" ]] || { echo "SPES DTB missing" >&2; exit 1; }

KERNELRELEASE="$(make -s -C "$SRC" O="$OUT" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" kernelrelease)"
MODLIB="$STAGE/lib/modules/$KERNELRELEASE"
rm -rf "$MODLIB"
make -C "$SRC" O="$OUT" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
  INSTALL_MOD_PATH="$STAGE" modules_install
depmod -b "$STAGE" "$KERNELRELEASE"

[[ -s "$MODLIB/kernel/drivers/gpu/drm/panel/panel-k7-38-0c-0a.ko" ]] || {
  echo "K7 panel module missing from staging" >&2; exit 1;
}
[[ -s "$MODLIB/kernel/drivers/regulator/qcom-refgen-regulator.ko" ]] || {
  echo "REFGEN regulator module missing from staging" >&2; exit 1;
}
[[ -s "$MODLIB/kernel/drivers/gpu/drm/msm/msm.ko" ]] || {
  echo "MSM DRM module missing from staging" >&2; exit 1;
}

grep -q 'xiaomi,k7-38-0c-0a' "$MODLIB/modules.alias" || {
  echo "K7 OF module alias missing" >&2; exit 1;
}
grep -q 'qcom,sm8250-refgen-regulator' "$MODLIB/modules.alias" || {
  echo "REFGEN OF module alias missing" >&2; exit 1;
}
grep -q 'qcom,mdss-dsi-ctrl' "$MODLIB/modules.alias" || {
  echo "MSM DSI fallback OF module alias missing" >&2; exit 1;
}

if find "$MODLIB/kernel" -type f -iname '*fpc*' -print -quit | grep -q .; then
  echo "Unexpected FPC module in staging" >&2
  exit 1
fi

if command -v modprobe >/dev/null 2>&1; then
  modprobe -d "$STAGE" -S "$KERNELRELEASE" --show-depends panel_k7_38_0c_0a >/dev/null
  modprobe -d "$STAGE" -S "$KERNELRELEASE" --show-depends msm >/dev/null
fi

MODULE_COUNT="$(find "$MODLIB/kernel" -type f -name '*.ko' | wc -l)"
echo "Build outputs:"
ls -lh "$IMAGE" "$DTB"
echo "Kernel release: $KERNELRELEASE"
echo "Staged modules: $MODULE_COUNT"
echo "Module staging: $MODLIB"
echo "WARNING: compile and module staging do not establish hardware bring-up or Android compatibility. Do not flash this experimental port."