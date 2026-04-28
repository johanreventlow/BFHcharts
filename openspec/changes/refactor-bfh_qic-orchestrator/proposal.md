## Why

`bfh_qic()` in `R/bfh_qic.R:453-834` is 380 lines combining:
- NSE column-name validation
- Numeric parameter validation (×7 calls)
- `qic_args` construction
- `qicharts2::qic()` invocation
- Anhøj signal post-processing
- Dimension/unit conversion
- Responsive base_size calculation
- Axis label normalization
- Plot config + viewport + plot_margin construction
- Plot rendering (`bfh_spc_plot`) with warning suppression
- Label size computation + label addition
- Summary formatting
- Config object construction
- Return-value routing (S3 vs legacy paths)

The `R/utils_bfh_qic_helpers.R` file (created in 2026-04-24, archived) shows the team has already begun extracting helpers (`add_anhoej_signal`, `build_bfh_qic_return`). This proposal continues that work to reduce orchestrator complexity below ~80 lines.

Both code reviews (Codex #5 + Claude #4) identified this as HIGH severity for maintainability.

## What Changes

- **NON-BREAKING refactor**: split `bfh_qic()` into orchestrator + 5–7 helper functions:
  - `validate_bfh_qic_inputs()` — all input validation in one place
  - `build_qic_args()` — construct argument list for `qicharts2::qic()`
  - `invoke_qicharts2()` — wrap `do.call()` with warning suppression
  - `compute_viewport_base_size()` — handle dimension/unit conversion + base_size derivation
  - `render_bfh_plot()` — plot config + viewport + bfh_spc_plot orchestration
  - `apply_spc_labels_to_export()` — label_size + add_spc_labels orchestration
  - `build_bfh_qic_return()` — already exists; preserve
- Public function signature unchanged
- All existing tests continue to pass
- Add unit tests for each helper in isolation
- Update `R/bfh_qic.R` Roxygen with reference to the orchestration map

## Impact

**Affected specs:**
- `code-organization` — ADDED requirement: orchestrator-helper separation pattern for primary entry points

**Affected code:**
- `R/bfh_qic.R` — orchestrator reduced to ≤ 80 lines
- `R/utils_bfh_qic_helpers.R` — extended with new helpers (or split into multiple files if grows large)
- `tests/testthat/test-bfh_qic_helpers.R` — extended with helper-isolation tests

**Non-breaking:**
- Public API identical
- No behavior change
- All existing tests pass without modification

**Test quality improvement:**
- Each helper testable in isolation
- Faster failure localization when validation or rendering breaks
- Lower coupling between concerns

## Cross-repo impact (biSPCharts)

None. Public API unchanged.

## Related

- GitHub Issue: #211
- Prior work: `openspec/changes/archive/2026-04-24-refactor-extract-bfh-qic-helpers/`
- Source: BFHcharts code review 2026-04-27 (Codex #5, Claude #4)
- Companion proposal: `refactor-bfh_export_pdf-orchestrator`
