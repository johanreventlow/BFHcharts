## 1. metadata$target validation

- [x] 1.1 Add `.validate_metadata_target(x)` in `R/utils_export_helpers.R`
- [x] 1.2 Wire into `bfh_export_pdf()`, `bfh_generate_analysis()`, `bfh_build_analysis_context()` entry points
- [x] 1.3 Test: `target = c(1, 2)` errors with "must be a scalar"
- [x] 1.4 Test: `target = Inf` / `NA` / `NaN` error
- [x] 1.5 Test: `target = "≥ 90%"` succeeds (length-1 character) — covered by existing tests in test-spc_analysis.R

## 2. Empty data validation

- [x] 2.1 In `validate_bfh_qic_inputs()` (`R/utils_bfh_qic_helpers.R:~214`), insert `if (nrow(data) == 0) stop("'data' is empty; bfh_qic() requires at least one row")` immediately after `is.data.frame()` check
- [x] 2.2 Test: `bfh_qic(data.frame(), x = a, y = b)` errors with "empty" before qicharts2

## 3. Integer/sorted/unique index validation

- [x] 3.1 Add `validate_position_indices(x, name, nrow_data, allow_unsorted = FALSE)` helper in `R/utils_bfh_qic_helpers.R`
- [x] 3.2 Validate `part`: positive integer, strictly increasing, unique, bounded `[2, nrow(data)]`
- [x] 3.3 Validate `freeze`: single positive integer, bounded `[1, nrow(data) - 1]`
- [x] 3.4 Validate `exclude`: positive integers, unique, bounded `[1, nrow(data)]` (no sort requirement)
- [x] 3.5 Test: `part = 3.5` → error mentions "integer"
- [x] 3.6 Test: `part = c(12, 12)` → error mentions "unique"
- [x] 3.7 Test: `part = c(12, 6)` → error mentions "increasing"
- [x] 3.8 Test: `freeze = 5.5` → error mentions "integer"
- [x] 3.9 Test: `exclude = c(2, 2, 5)` → error mentions "unique"

## 4. y column numeric check

- [x] 4.1 In `validate_bfh_qic_inputs()`, after column-name validation, fetch `y_data <- data[[y_col]]` and require `is.numeric(y_data)` (integers OK)
- [x] 4.2 Error: `"column 'y' must be numeric, got <class>"`
- [x] 4.3 Test: y_col selecting character column errors before qic invocation

## 5. Documentation

- [x] 5.1 Update `bfh_qic()` Roxygen `@details` to document validation contract for `part`, `freeze`, `exclude`
- [x] 5.2 Update `bfh_export_pdf()` Roxygen for `metadata$target` scalar contract
- [x] 5.3 NEWS entry under `## Breaking changes` for v0.12.0

## 6. Cross-repo coordination

- [ ] 6.1 Audit biSPCharts data-prep for non-scalar metadata$target patterns
- [ ] 6.2 Audit biSPCharts phase-splitter UI for non-integer outputs
- [ ] 6.3 Open companion biSPCharts issue with migration patterns

## 7. Release

- [x] 7.1 Bump `DESCRIPTION` 0.11.1 → 0.12.0 (combined with chart-target-fallback proposal)
- [x] 7.2 `devtools::test()` passes
- [ ] 7.3 `devtools::check()` no new WARN/ERROR
- [ ] 7.4 Tag v0.12.0 after merge

Tracking: GitHub Issue #TBD
