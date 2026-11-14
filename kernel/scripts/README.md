# SPES build helper

`build-spes.sh` performs a reproducible SPES kernel build and refreshes the isolated module staging tree.

## Workspace layout

The build workspace must contain:

- `src/linux-sm6225-mainline/` — kernel source tree with the SPES port changes.
- `build/spes/` — out-of-tree kernel build directory.
- `build/spes-module-staging/` — isolated module installation root.

The script uses `refs/spes-android.config` from the workspace when present. If it is not present, it uses the copy in `kernel/config/spes-android.config` beside this script in the GitHub repository.

## Run

From the repository checkout, point the script at the existing build workspace:

```sh
SPES_WORKSPACE_ROOT=/workspace/ubuntu-spes-mainline \
CROSS_COMPILE=aarch64-linux-gnu- JOBS=2 \
 bash kernel/scripts/build-spes.sh
```

`SPES_WORKSPACE_ROOT` must be the directory containing `src/` and `build/`; it is not the GitHub repository directory unless the source/build tree is located there.

## What it does

1. Runs `defconfig`, merges the SPES Android config fragment and runs `olddefconfig`.
2. Verifies core Android, Qualcomm RPM/SPMI, MSM DSI/7nm PHY, K7 panel, REFGEN, FT3418, MAX77729 and SC8551 options.
3. Verifies FPC1020 fingerprint support is disabled.
4. Builds `Image`, `modules`, and only `qcom/sm6225-xiaomi-spes.dtb` (not every ARM64 DTB).
5. Installs modules into the isolated staging tree for the current kernel release, regenerates `modules.dep`/`modules.alias`, and verifies the K7, REFGEN and MSM modules and their OF aliases.
6. Verifies no FPC-named module is staged and prints the module count.

The script removes only the current kernel-release directory under `build/spes-module-staging/lib/modules/` before reinstalling it. It does not delete other kernel-release staging directories.

## Safety

A successful compile and module-staging check do not establish hardware bring-up, Android boot compatibility, panel operation or first-frame success. The MDSS/DSI0/DSI PHY nodes remain disabled pending controlled device validation. The script does not create a Recovery ZIP, installer or flash image, and it never flashes the device.

## Validate SPES Device Tree

Install the known-good schema toolchain in an isolated virtual environment:

```sh
python3 -m venv /workspace/ubuntu-spes-mainline/.venv-dtschema-2024.11
/workspace/ubuntu-spes-mainline/.venv-dtschema-2024.11/bin/pip install 'dtschema==2024.11'
```

Then run the targeted validator:

```sh
SPES_WORKSPACE_ROOT=/workspace/ubuntu-spes-mainline \
DTS_SCHEMA_BIN=/workspace/ubuntu-spes-mainline/.venv-dtschema-2024.11/bin \
 bash kernel/scripts/validate-spes-dt.sh
```

The validator checks the six SPES project bindings, validates only the SPES DTB against those schemas, verifies MDSS/DSI0/DSI PHY/FPC remain disabled, and runs `git diff --check`. It intentionally does not run the aggregate all-ARM64 `dtbs_check` target.
