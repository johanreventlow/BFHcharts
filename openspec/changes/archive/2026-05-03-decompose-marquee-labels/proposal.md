## Why

`add_right_labels_marquee()` in `R/utils_add_right_labels_marquee.R` is a 510-line single function that violates SRP across 11 distinct responsibilities (gpar resolution, scale factor, config lookup, ggplot_build, gtable construction, device-leak cleanup, viewport-vs-fallback device strategy, panel-height measurement, label-height estimation, empty-label handling, NPC placement orchestration, grob construction).

This is the largest single readability/testability barrier in the package. The same 3-layer split pattern that succeeded for `place_two_labels_npc()` (NIVEAU 1/2/3 cascade in v0.13.0) is the obvious template — the existing inline comments in `add_right_labels_marquee()` already partition the function along these lines.

## What Changes

- Extract `.resolve_label_geometry(label_size, ...)` from the current label_size + scale_factor + config + sizes block (lines 137-170).
- Extract `.acquire_device_for_measurement(viewport_dims, ...)` from the viewport-vs-fallback device strategy (lines 200-315), with named sub-strategies replacing the inline if/else.
- Extract `.measure_label_heights(textA, textB, style, device)` from the panel-height + label-height-estimation block (lines 320-410).
- Reduce orchestrator `add_right_labels_marquee()` to under 120 lines: parameter-binding -> geometry -> device acquisition -> measurement -> placement -> grob construction.
- Each extracted helper becomes unit-testable in isolation; current device-leak handling preserved via `withr::defer()` at the orchestrator boundary.
- Behavior unchanged: this is pure refactor. Visual regression baselines (PR #279) must continue to pass without snapshot updates.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `code-organization`: refines the labeling-pipeline organization boundary. Current spec section "Function Naming Conventions" + "File Organization" implicitly accepts a single 510-line function; adds a requirement that label-pipeline functions follow the same 3-layer split as `place_two_labels_npc()`.

## Impact

- `R/utils_add_right_labels_marquee.R`: file grows from 1 to 4 functions (orchestrator + 3 helpers); LOC roughly unchanged but distributed.
- `tests/testthat/test-utils_add_right_labels_marquee.R` (new or extension of existing): unit tests for each of the 3 extracted helpers with injected device + config seams.
- `tests/testthat/_snaps/visual-regression/`: must show **zero diff** post-refactor. Pre-push hook `PREPUSH_MODE=full` (which runs vdiffr with `NOT_CRAN=true`) is the authoritative verification gate.
- biSPCharts: no public API change. Internal `:::add_right_labels_marquee()` signature unchanged; only its body decomposes. No migration needed.
- No statistical validation required (no Anhøj-rule or control-limit logic touched).
- No NEWS.md user-visible entry needed (internal refactor); add bullet under `## Internal changes` for next release.
