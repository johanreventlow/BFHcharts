# Implementation Tasks: refactor-x-axis-formatting

**GitHub Issue:** #43
**Estimated Effort:** 4-6 hours

## Phase 1: Setup & Preparation

- [x] 1.1 Create `R/utils_x_axis_formatting.R` file
- [x] 1.2 Create `tests/testthat/test-utils_x_axis_formatting.R`
- [x] 1.3 Run baseline tests to confirm current behavior

## Phase 2: Extract Helper Functions

- [x] 2.1 Extract `normalize_to_posixct()` (Date → POSIXct conversion)
  - **File:** `R/utils_x_axis_formatting.R`
  - **Lines:** 8 lines
  - **Test:** Date input, POSIXct passthrough

- [x] 2.2 Extract `round_to_interval_start()` (date flooring)
  - **File:** `R/utils_x_axis_formatting.R`
  - **Lines:** 11 lines
  - **Test:** monthly, weekly, daily intervals

- [x] 2.3 Extract `calculate_base_interval_secs()` (interval → seconds)
  - **File:** `R/utils_x_axis_formatting.R`
  - **Lines:** 8 lines
  - **Test:** daily=86400, weekly=604800, monthly=2592000

- [x] 2.4 Extract `calculate_interval_multiplier()` (density adjustment)
  - **File:** `R/utils_x_axis_formatting.R`
  - **Lines:** 19 lines
  - **Test:** >15 breaks → multiplier applied

## Phase 3: Extract Break Calculator

- [x] 3.1 Extract `calculate_date_breaks()` (main break logic)
  - **File:** `R/utils_x_axis_formatting.R`
  - **Lines:** 46 lines
  - **Dependencies:** Uses 2.1-2.4
  - **Test:** daily, weekly, monthly data ranges

## Phase 4: Extract Axis Formatters

- [x] 4.1 Extract `apply_temporal_x_axis()` (temporal orchestrator)
  - **File:** `R/utils_x_axis_formatting.R`
  - **Lines:** 35 lines
  - **Uses:** normalize_to_posixct, detect_date_interval, calculate_date_breaks
  - **Test:** Integration with ggplot

- [x] 4.2 Extract `apply_numeric_x_axis()` (numeric handler)
  - **File:** `R/utils_x_axis_formatting.R`
  - **Lines:** 5 lines
  - **Test:** Returns ggplot with pretty_breaks

## Phase 5: Refactor Main Function

- [x] 5.1 Simplify `apply_x_axis_formatting()` to dispatcher
  - **File:** `R/plot_core.R`
  - **Target:** 18 lines (within ≤20 tolerance)
  - **Logic:** Type check → dispatch to appropriate formatter

## Phase 6: Verification

- [x] 6.1 Run full test suite
  - **Command:** `devtools::test()`
  - **Validation:** New tests pass (26/26), pre-existing failures unchanged (8 failures)

- [x] 6.2 Run R CMD check
  - **Command:** `devtools::check()`
  - **Validation:** Pre-existing warnings unchanged, no new errors introduced

- [x] 6.3 Verify code metrics
  - **Main function:** 18 lines (6 code + 12 structure)
  - **Max nesting:** 1 level
  - **Test coverage:** 26 new unit tests added

## Phase 7: Deploy

- [x] 7.1 Update documentation
  - Run `devtools::document()`

- [x] 7.2 Commit changes
  - Message: `refactor: extract x-axis formatting into modular functions (#43)`

- [x] 7.3 Push to remote

- [x] 7.4 Close GitHub issue #43

- [x] 7.5 Archive OpenSpec change

## Dependencies

- Phases 2-4 must be sequential (each builds on previous)
- Phase 5 depends on 4 being complete
- Phase 6-7 are final validation and deploy

## Risk Mitigation

- Run tests after each extraction to catch regressions early
- Keep original code commented until Phase 6 passes
- Visual comparison of sample charts before/after
