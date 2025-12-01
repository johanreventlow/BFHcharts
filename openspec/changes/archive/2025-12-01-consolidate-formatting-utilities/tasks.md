# Implementation Tasks: consolidate-formatting-utilities

Tracking: GitHub Issue #40

## Phase 1: Analysis

- [x] 1.1 Identify all time formatting duplicates
  - Grep for `format_time` patterns
  - Document exact line numbers
  - Note differences between implementations
  - **Validation:** Complete list of duplicates

- [x] 1.2 Identify all number formatting duplicates
  - Grep for K/M/mia patterns
  - Document exact line numbers
  - Note differences between implementations
  - **Validation:** Complete list of duplicates

- [x] 1.3 Identify all call sites
  - Find where each duplicate is called
  - Document for later update
  - **Validation:** Complete call site list

## Phase 2: Create Canonical Time Formatting

- [x] 2.1 Create R/utils_time_formatting.R
  - Add file header with Roxygen
  - Define `format_time_danish()` as main function
  - Add helper functions: `determine_time_unit()`, `scale_to_time_unit()`, `get_danish_time_label()`
  - Add comprehensive Roxygen documentation
  - **File:** `R/utils_time_formatting.R` (NEW)
  - **Validation:** File exists with complete implementation

- [x] 2.2 Write tests for time formatting
  - Tests in `test-y_axis_formatting.R` updated to use canonical functions
  - Tests in `test-utils_label_formatting.R` updated for correct Danish pluralization
  - Test edge cases (0, decimals, singular/plural)
  - Test Danish labels
  - **Validation:** All tests pass

## Phase 3: Create Canonical Number Formatting

- [x] 3.1 Create R/utils_number_formatting.R
  - Add file header with Roxygen
  - Define `format_count_danish()` as main function
  - Add helpers: `determine_magnitude()`, `format_scaled_number()`, `format_unscaled_number()`
  - Handle K (tusinde), M (millioner), mia (milliarder)
  - Added `format_rate_danish()` for rate formatting
  - **File:** `R/utils_number_formatting.R` (NEW)
  - **Validation:** File exists with complete implementation

- [x] 3.2 Write tests for number formatting
  - Tests in `test-utils_label_formatting.R` cover K/M/mia thresholds
  - Test Danish formatting (comma as decimal, dot as thousand)
  - **Validation:** All tests pass

## Phase 4: Update Existing Files

- [x] 4.1 Update R/utils_helpers.R
  - Removed duplicate `format_time_value()` (was unused)
  - **File:** `R/utils_helpers.R`
  - **Validation:** No duplicate, function removed

- [x] 4.2 Update R/utils_y_axis_formatting.R
  - Removed `format_time_with_unit()` duplicate
  - Removed `format_scaled_number()` and `format_unscaled_number()` duplicates
  - Updated `format_y_axis_count()` to use `format_count_danish()`
  - Updated `format_y_axis_rate()` to use `format_rate_danish()`
  - Updated `format_y_axis_time()` to use `determine_time_unit()` and `format_time_danish()`
  - **File:** `R/utils_y_axis_formatting.R`
  - **Validation:** No duplicates, uses canonical functions

- [x] 4.3 Update R/utils_label_formatting.R
  - Refactored `format_y_value()` to delegate to canonical functions
  - Uses `format_count_danish()` for count formatting
  - Uses `format_rate_danish()` for rate formatting
  - Uses `format_time_auto()` for time formatting
  - **File:** `R/utils_label_formatting.R`
  - **Validation:** No duplicates, uses canonical functions

## Phase 5: Verification

- [x] 5.1 Run full test suite
  - Execute: `devtools::test()`
  - Updated tests to use new function names
  - Updated tests for correct Danish pluralization (1 time vs 2 timer, 1 dag vs 2 dage)
  - **Validation:** All formatting tests pass (0 failures)

- [x] 5.2 Run devtools::document()
  - Execute: `devtools::document()`
  - Generated documentation for new files
  - **Validation:** Documentation generated

- [x] 5.3 Verify no remaining duplicates
  - Old function names removed from source files
  - Tests updated to use canonical function names
  - **Validation:** No duplicates found

## Phase 6: Commit and Deploy

- [ ] 6.1 Commit changes
  - Commit message: `refactor: consolidate time and number formatting utilities (#40)`
  - **Validation:** Clean git status

- [ ] 6.2 Push to remote
  - **Validation:** Changes on GitHub

- [ ] 6.3 Close GitHub issue #40
  - Add label: `openspec-deployed`
  - Add closing comment with summary
  - **Validation:** Issue closed

- [ ] 6.4 Archive OpenSpec change
  - Execute: `openspec archive consolidate-formatting-utilities --yes`
  - **Validation:** Change archived

## Dependencies

**Sequential:**
- Phase 1 → Phase 2 (need analysis before implementation)
- Phase 2 → Phase 3 (can be parallel but sequential simpler)
- Phase 2+3 → Phase 4 (need canonical before updating)
- Phase 4 → Phase 5 (need updates before verification)
- Phase 5 → Phase 6 (need verification before deploy)

## Validation Criteria

**Phase 1 complete when:**
- All duplicates documented with file:line
- All call sites documented

**Phase 2 complete when:**
- `R/utils_time_formatting.R` exists
- Tests pass for time formatting

**Phase 3 complete when:**
- `R/utils_number_formatting.R` exists
- Tests pass for number formatting

**Phase 4 complete when:**
- No duplicate implementations remain
- All call sites updated

**Phase 5 complete when:**
- All tests pass
- R CMD check clean

**Phase 6 complete when:**
- Changes committed and pushed
- Issue closed
- OpenSpec archived

## Effort Estimate

- Phase 1: 30 minutes
- Phase 2: 45 minutes
- Phase 3: 45 minutes
- Phase 4: 30 minutes
- Phase 5: 15 minutes
- Phase 6: 10 minutes
- **Total: 2-3 hours**

## Risk Mitigation

**Risk:** Breaking existing functionality
- **Mitigation:** Comprehensive tests before modifying call sites
- **Mitigation:** Run full test suite after each phase

**Risk:** Missing a call site
- **Mitigation:** Thorough grep in Phase 1.3
- **Mitigation:** R CMD check will catch undefined functions
