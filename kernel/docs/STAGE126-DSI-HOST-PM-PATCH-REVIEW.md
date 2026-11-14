# Stage 126 — DSI Host Runtime-PM patch draft and static validation

Target: Xiaomi Redmi Note 11 4G (SPES / SM6225)
Patch: `0001-msm-dsi-host-runtime-pm-unwind.patch`
Base: port working tree based on `c545b9e890d723b5dd0beb6a7a067a0e16088e65`, after applying `spes-mainline-port.patch`.
Status: draft only; not applied to kernel source.

## Changes proposed

1. `dsi_get_config()` uses `pm_runtime_resume_and_get()`, returns an error pointer on acquisition/version/config failure, and only performs the matching PM put after successful acquisition. Its caller checks `IS_ERR()` and preserves the real error.
2. `msm_dsi_host_power_on()` uses `pm_runtime_resume_and_get()`, checks link-clock rate and enable results independently, balances the PM reference on every later failure, disables regulators, and unwinds the optional SFPB setting. The clock-enable helper already unwinds partial clock enables on its own failure, so the caller does not double-disable them.
3. `msm_dsi_host_xfer_prepare()` uses `pm_runtime_resume_and_get()`, propagates PM/rate/clock errors through its existing `int` return value, and drops PM on failure before any DSI register access.

## Static checks performed

- `git apply --check` against the current SPES port working tree: PASS.
- `git apply --stat`: one file (`drivers/gpu/drm/msm/dsi/dsi_host.c`), 52 insertions and 14 deletions.
- `scripts/checkpatch.pl --no-tree --strict`: no style warnings/checks reported; the only remaining error is missing `Signed-off-by`.
- No Signed-off-by line was fabricated. A developer with authority to submit the patch must add their own sign-off before upstream submission.

## Not performed

- Patch has not been applied to the source tree.
- No kernel compile/build or runtime test has been run for this draft.
- No hardware test; MDSS/DSI0/DSI PHY remain disabled.
- No flash or release artifact.

## Revision note — Stage 135

The patch was expanded in Stage 135 to also guard `msm_dsi_host_snapshot()` against failed Runtime-PM resume before reading DSI registers. The current draft therefore covers four PM acquisition sites; the original 52-insertion/14-deletion count above describes the initial Stage 126 revision only. See `STAGE135-DSI-HOST-SNAPSHOT-PM-FIX.md` for the latest patch scope, updated diff statistics, W=1 object compile and full Image/modules integration build. The patch remains unapplied and still requires a developer `Signed-off-by` for upstream submission.

## Review points before applying

- Review error-pointer return semantics for `dsi_get_config()` in the context of the target kernel branch.
- Confirm the DSI host regulator descriptors and optional SFPB behavior for any non-SPES users of this driver.
- After approval, apply to a disposable worktree, build the DSI host object and full Image/modules, then run the existing `git diff --check` and DT validation. Do not enable the display DT nodes or flash without controlled hardware validation.
