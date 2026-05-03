## ADDED Requirements

### Requirement: Label-pipeline orchestrators SHALL follow 3-layer decomposition

Internal label-pipeline functions that exceed 200 lines SHALL be decomposed into a thin orchestrator (≤220 lines) plus named private helpers, mirroring the 3-layer split pattern established in v0.13.0 for `place_two_labels_npc()` (NIVEAU 1/2/3 cascade).

The orchestrator's responsibilities are limited to: parameter binding, helper invocation in pipeline order, and result aggregation. All substantive work — geometry resolution, device acquisition, measurement, x-axis-type detection, label-data construction, placement, grob construction — SHALL live in named helpers prefixed with `.` and marked `@keywords internal @noRd`.

Helpers SHALL accept injected dependencies (config providers, device handles, measurement estimators, logging flags) so each can be unit-tested in isolation without real graphics-device side effects. Side-effecting helpers (e.g. those that open a graphics device) SHALL return a cleanup closure that the orchestrator binds via `on.exit(..., add = TRUE)` (or `withr::defer()` where used); manual scattered `dev.off()` patterns SHALL be consolidated through the cleanup closure.

#### Scenario: add_right_labels_marquee respects the orchestrator-helper boundary

- **WHEN** the package source is inspected for `R/utils_add_right_labels_marquee.R`
- **THEN** `add_right_labels_marquee()` SHALL be ≤220 lines and SHALL only invoke named helpers (no inline gpar resolution, device acquisition, panel-height measurement, label-height estimation, x-axis type detection, label-data tibble construction, or grob construction logic)
- **AND** at minimum these private helpers SHALL exist in the same file: `.resolve_label_geometry()`, `.acquire_device_for_measurement()`, `.measure_label_heights()`, `.detect_x_axis_type()`, `.build_label_data()`

#### Scenario: helpers are unit-testable without a real graphics device

- **WHEN** unit tests for `.resolve_label_geometry()` and `.measure_label_heights()` are run
- **THEN** the tests SHALL pass without opening any graphics device (no `Rplots.pdf` produced, no `dev.cur()` change observable from outside the test)

#### Scenario: device-acquiring helpers return a cleanup closure

- **WHEN** `.acquire_device_for_measurement()` opens a fallback graphics device
- **THEN** it SHALL return a list containing a `cleanup_fn` closure that closes the device when invoked
- **AND** the orchestrator SHALL register the closure via `on.exit(..., add = TRUE)` or `withr::defer()` so it fires on both normal exit and error exit

#### Scenario: visual regression baselines remain unchanged after decomposition

- **WHEN** the pre-push hook runs `PREPUSH_MODE=full` (vdiffr with `NOT_CRAN=true`) on a refactor commit
- **THEN** zero `.new.svg` files SHALL be produced under `tests/testthat/_snaps/visual-regression/`
- **AND** all 9 canonical chart-scenario snapshots SHALL match byte-for-byte against the baselines refreshed in v0.14.2 (PR #279)
