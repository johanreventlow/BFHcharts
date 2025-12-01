# Implementation Tasks

## Phase 1: Core Formatting Logic

- [ ] 1.1 Add `format_percent_contextual()` helper function in `R/utils_label_formatting.R`
  - Parameters: `val`, `target = NULL`, `threshold = 0.05`
  - Returns formatted string with Danish notation
  - Decimals only when `!is.null(target) && abs(val - target) <= threshold`

- [ ] 1.2 Update `format_y_value()` to accept optional `target` parameter
  - Default `target = NULL` preserves backward compatibility
  - Delegates to `format_percent_contextual()` for percent unit

- [ ] 1.3 Write unit tests for `format_percent_contextual()`
  - Test: close to target shows decimal
  - Test: far from target shows whole percent
  - Test: no target shows whole percent
  - Test: exact boundary behavior
  - Test: Danish comma notation

## Phase 2: Centerline Label Integration

- [ ] 2.1 Update `add_spc_labels()` in `R/fct_add_spc_labels.R`
  - Pass `target_value` to `format_y_value()` when formatting centerline
  - Only for `y_axis_unit == "percent"`

- [ ] 2.2 Write integration test for centerline label with target
  - Verify label text contains decimal when close to target

## Phase 3: Y-Axis Range-Aware Precision

- [ ] 3.1 Update `format_y_axis_percent()` in `R/utils_y_axis_formatting.R`
  - Accept `y_range` parameter
  - Use `accuracy = 0.1` when range < 0.05

- [ ] 3.2 Update `apply_y_axis_formatting()` to pass range to percent formatter
  - Extract range from qic_data$y

- [ ] 3.3 Write unit tests for range-aware y-axis formatting
  - Test: narrow range shows decimals
  - Test: wide range shows whole percents

## Phase 4: Documentation and Release

- [ ] 4.1 Run full test suite (`devtools::test()`)
- [ ] 4.2 Run package check (`devtools::check()`)
- [ ] 4.3 Update NEWS.md with new feature description
- [ ] 4.4 Bump version in DESCRIPTION (minor version)
- [ ] 4.5 Commit and push changes

---

Tracking: GitHub Issue #68
