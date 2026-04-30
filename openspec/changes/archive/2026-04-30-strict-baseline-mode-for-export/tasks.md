## 1. Parameter design

- [x] 1.1 Add `strict_baseline = TRUE` to `bfh_export_pdf()` signature
- [x] 1.2 Add `strict_baseline = TRUE` to `bfh_create_export_session()` signature
- [x] 1.3 Define inheritance: `bfh_export_pdf(session = s)` uses `s$strict_baseline` unless explicit per-call override (via missing()-flag)
- [x] 1.4 Document via Roxygen with rationale + cross-link to `MIN_BASELINE_N`

## 2. Validation logic

- [x] 2.1 In `bfh_export_pdf()` (or its early validation step), inspect the `bfh_qic_result` for `config$freeze` and detected phase sizes
- [x] 2.2 If `strict_baseline = TRUE` and `config$freeze < MIN_BASELINE_N`: stop with informative error
- [x] 2.3 If `strict_baseline = TRUE` and any phase < MIN_BASELINE_N (deduce from `qic_data` rows per phase): stop
- [x] 2.4 Error message format: `"freeze = N: baseline har faerre end N punkter (MIN_BASELINE_N); set strict_baseline = FALSE to override"`
- [x] 2.5 If `strict_baseline = FALSE`: preserve current warning behavior, no error

## 3. Tests

- [x] 3.1 Test: `bfh_export_pdf(x, ..., metadata = list())` with `freeze = 5` errors by default
- [x] 3.2 Test: error message mentions `strict_baseline = FALSE` opt-out
- [x] 3.3 Test: `bfh_export_pdf(x, ..., strict_baseline = FALSE)` succeeds with warning only (render-only — gated by skip_if_not_render_test)
- [x] 3.4 Test: `bfh_create_export_session(strict_baseline = FALSE)` inherits to per-export calls (render-only)
- [x] 3.5 Test: per-call `strict_baseline = TRUE` override beats session-level FALSE
- [x] 3.6 Test: phase with 4 points errors when `strict_baseline = TRUE`
- [x] 3.7 Test: `bfh_qic()` direct call still emits warning, not error (regression for interactive flow)
- [x] 3.8 Test: NEWS entry references the new flag (covered by NEWS task 4.4)

## 4. Documentation

- [x] 4.1 Roxygen for `bfh_export_pdf()` — document `strict_baseline` with full rationale
- [x] 4.2 Roxygen for `bfh_create_export_session()` — same
- [x] 4.3 Update `vignettes/phases-and-freeze.Rmd` with new "Strict baseline mode" subsection
- [x] 4.4 NEWS entry under `## Breaking changes` for v0.12.0

## 5. Cross-repo coordination

- [ ] 5.1 Audit biSPCharts batch-export for short-baseline indicators
- [ ] 5.2 Document migration: either add explicit `strict_baseline = FALSE` per-indicator or surface error to user
- [ ] 5.3 Open companion biSPCharts issue

## 6. Release

- [x] 6.1 Bump `DESCRIPTION` 0.11.1 → 0.12.0
- [x] 6.2 `devtools::test()` passes
- [ ] 6.3 `devtools::check()` no new WARN/ERROR
- [ ] 6.4 Tag v0.12.0 after merge

Tracking: GitHub Issue #TBD
