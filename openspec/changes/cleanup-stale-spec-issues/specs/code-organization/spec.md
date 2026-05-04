## MODIFIED Requirements

### Requirement: Label-pipeline orchestrators SHALL follow 3-layer decomposition

Internal label-pipeline functions SHALL be decomposed into a thin
orchestrator plus named private helpers, mirroring the 3-layer split
pattern established in v0.13.0 for `place_two_labels_npc()` (NIVEAU 1/2/3
cascade).

The orchestrator's responsibilities are limited to: parameter binding,
helper invocation in pipeline order, and result aggregation. All
substantive work -- geometry resolution, device acquisition, measurement,
x-axis-type detection, label-data construction, placement, grob
construction -- SHALL live in named helpers prefixed with `.` and marked
`@keywords internal @noRd`.

Helpers SHALL accept injected dependencies (config providers, device
handles, measurement estimators, logging flags) so each can be
unit-tested in isolation without real graphics-device side effects.
Side-effecting helpers (e.g. those that open a graphics device) SHALL
return a cleanup closure that the orchestrator binds via
`on.exit(..., add = TRUE)` (or `withr::defer()` where used); manual
scattered `dev.off()` patterns SHALL be consolidated through the cleanup
closure.

**Note on file size:** A hard line-count cap (e.g. orchestrator <=220
lines) is NOT a requirement. The 3-layer pattern controls complexity via
single-responsibility helpers, not via file fragmentation. A file
containing one orchestrator plus 10-15 named helpers may legitimately
exceed 700 lines without violating the structural contract -- the
metric is _what each function does_, not _how many lines the file
holds_.

#### Scenario: orchestrator contains no inline substantive work

- **GIVEN** an orchestrator function in a label-pipeline file (e.g.
  `add_right_labels_marquee()`, `place_two_labels_npc()`)
- **WHEN** the function body is inspected
- **THEN** the orchestrator SHALL only invoke named helpers (no inline
  gpar resolution, device acquisition, panel-height measurement,
  label-height estimation, x-axis-type detection, label-data tibble
  construction, or grob construction logic)
- **AND** each invoked helper SHALL exist as a separate named function
  in the same file or in a co-located helpers file

#### Scenario: helpers are unit-testable without a real graphics device

- **WHEN** unit tests for non-side-effect helpers (e.g.
  `.resolve_label_geometry()`, `.measure_label_heights()`) are run
- **THEN** the tests SHALL pass without opening any graphics device
  (no `Rplots.pdf` produced, no `dev.cur()` change observable from
  outside the test)

#### Scenario: device-acquiring helpers return a cleanup closure

- **WHEN** a helper opens a fallback graphics device (e.g.
  `.acquire_device_for_measurement()`)
- **THEN** it SHALL return a list containing a `cleanup_fn` closure that
  closes the device when invoked
- **AND** the orchestrator SHALL register the closure via
  `on.exit(..., add = TRUE)` or `withr::defer()` so it fires on both
  normal exit and error exit

#### Scenario: helper module file size is not bounded

- **GIVEN** a file containing a label-pipeline orchestrator and its
  named helpers (e.g. `R/utils_add_right_labels_marquee.R`)
- **WHEN** the file is inspected
- **THEN** the file SHALL pass review purely on structural grounds
  (orchestrator role, named helpers, dependency injection, cleanup
  closures)
- **AND** the review SHALL NOT reject the file solely on the basis of
  line count
