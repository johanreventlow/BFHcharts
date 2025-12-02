# Implementation Tasks: refactor-x-axis-formatting

**GitHub Issue:** #43
**Estimated Effort:** 4-6 hours

## Phase 1: Setup & Preparation

- [ ] 1.1 Create `R/utils_x_axis_formatting.R` file
- [ ] 1.2 Create `tests/testthat/test-utils_x_axis_formatting.R`
- [ ] 1.3 Run baseline tests to confirm current behavior

## Phase 2: Extract Helper Functions

- [ ] 2.1 Extract `normalize_to_posixct()` (Date → POSIXct conversion)
  - **File:** `R/utils_x_axis_formatting.R`
  - **Lines:** ~10
  - **Test:** Date input, POSIXct passthrough

- [ ] 2.2 Extract `round_to_interval_start()` (date flooring)
  - **File:** `R/utils_x_axis_formatting.R`
  - **Lines:** ~15
  - **Test:** monthly, weekly, daily intervals

- [ ] 2.3 Extract `calculate_base_interval_secs()` (interval → seconds)
  - **File:** `R/utils_x_axis_formatting.R`
  - **Lines:** ~15
  - **Test:** daily=86400, weekly=604800, monthly=2592000

- [ ] 2.4 Extract `calculate_interval_multiplier()` (density adjustment)
  - **File:** `R/utils_x_axis_formatting.R`
  - **Lines:** ~20
  - **Test:** >15 breaks → multiplier applied

## Phase 3: Extract Break Calculator

- [ ] 3.1 Extract `calculate_date_breaks()` (main break logic)
  - **File:** `R/utils_x_axis_formatting.R`
  - **Lines:** ~50
  - **Dependencies:** Uses 2.1-2.4
  - **Test:** daily, weekly, monthly data ranges

## Phase 4: Extract Axis Formatters

- [ ] 4.1 Extract `apply_temporal_x_axis()` (temporal orchestrator)
  - **File:** `R/utils_x_axis_formatting.R`
  - **Lines:** ~40
  - **Uses:** normalize_to_posixct, detect_date_interval, calculate_date_breaks
  - **Test:** Integration with ggplot

- [ ] 4.2 Extract `apply_numeric_x_axis()` (numeric handler)
  - **File:** `R/utils_x_axis_formatting.R`
  - **Lines:** ~10
  - **Test:** Returns ggplot with pretty_breaks

## Phase 5: Refactor Main Function

- [ ] 5.1 Simplify `apply_x_axis_formatting()` to dispatcher
  - **File:** `R/plot_core.R`
  - **Target:** ≤15 lines
  - **Logic:** Type check → dispatch to appropriate formatter

## Phase 6: Verification

- [ ] 6.1 Run full test suite
  - **Command:** `devtools::test()`
  - **Validation:** All tests pass

- [ ] 6.2 Run R CMD check
  - **Command:** `devtools::check()`
  - **Validation:** 0 errors, 0 warnings

- [ ] 6.3 Verify code metrics
  - **Main function:** ≤15 lines
  - **Max nesting:** ≤2 levels
  - **Test coverage:** ≥90%

## Phase 7: Deploy

- [ ] 7.1 Update documentation
  - Run `devtools::document()`

- [ ] 7.2 Commit changes
  - Message: `refactor: extract x-axis formatting into modular functions (#43)`

- [ ] 7.3 Push to remote

- [ ] 7.4 Close GitHub issue #43

- [ ] 7.5 Archive OpenSpec change

## Dependencies

- Phases 2-4 must be sequential (each builds on previous)
- Phase 5 depends on 4 being complete
- Phase 6-7 are final validation and deploy

## Risk Mitigation

- Run tests after each extraction to catch regressions early
- Keep original code commented until Phase 6 passes
- Visual comparison of sample charts before/after
