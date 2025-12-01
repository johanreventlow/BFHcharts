# Implementation Tasks: consolidate-formatting-utilities

Tracking: GitHub Issue #40

## Phase 1: Analysis

- [ ] 1.1 Identify all time formatting duplicates
  - Grep for `format_time` patterns
  - Document exact line numbers
  - Note differences between implementations
  - **Validation:** Complete list of duplicates

- [ ] 1.2 Identify all number formatting duplicates
  - Grep for K/M/mia patterns
  - Document exact line numbers
  - Note differences between implementations
  - **Validation:** Complete list of duplicates

- [ ] 1.3 Identify all call sites
  - Find where each duplicate is called
  - Document for later update
  - **Validation:** Complete call site list

## Phase 2: Create Canonical Time Formatting

- [ ] 2.1 Create R/utils_time_formatting.R
  - Add file header with Roxygen
  - Define `format_time_danish()` as main function
  - Add helper functions: `determine_time_unit()`, `scale_to_unit()`, `get_danish_time_label()`
  - Add comprehensive Roxygen documentation
  - **File:** `R/utils_time_formatting.R` (NEW)
  - **Validation:** File exists with complete implementation

- [ ] 2.2 Write tests for time formatting
  - Test various time ranges (seconds, minutes, hours, days)
  - Test edge cases (0, negative, very large)
  - Test Danish labels
  - **File:** `tests/testthat/test-utils_time_formatting.R` (NEW)
  - **Validation:** All tests pass

## Phase 3: Create Canonical Number Formatting

- [ ] 3.1 Create R/utils_number_formatting.R
  - Add file header with Roxygen
  - Define `format_count_danish()` as main function
  - Add helper: `determine_magnitude()`, `format_with_big_mark()`
  - Handle K (tusinde), M (millioner), mia (milliarder)
  - **File:** `R/utils_number_formatting.R` (NEW)
  - **Validation:** File exists with complete implementation

- [ ] 3.2 Write tests for number formatting
  - Test K threshold (1,000+)
  - Test M threshold (1,000,000+)
  - Test mia threshold (1,000,000,000+)
  - Test Danish formatting (comma as decimal, dot as thousand)
  - **File:** `tests/testthat/test-utils_number_formatting.R` (NEW)
  - **Validation:** All tests pass

## Phase 4: Update Existing Files

- [ ] 4.1 Update R/utils_helpers.R
  - Remove duplicate `format_time_value()` (if exists)
  - Add import from `utils_time_formatting.R`
  - Update call sites to use canonical function
  - **File:** `R/utils_helpers.R`
  - **Validation:** No duplicate, uses canonical

- [ ] 4.2 Update R/utils_y_axis_formatting.R
  - Remove `format_time_with_unit()` duplicate
  - Remove K/M/mia duplicate
  - Update call sites
  - **File:** `R/utils_y_axis_formatting.R`
  - **Validation:** No duplicates, uses canonical

- [ ] 4.3 Update R/utils_label_formatting.R
  - Remove embedded time formatting
  - Remove K/M/mia duplicate
  - Update call sites
  - **File:** `R/utils_label_formatting.R`
  - **Validation:** No duplicates, uses canonical

## Phase 5: Verification

- [ ] 5.1 Run full test suite
  - Execute: `devtools::test()`
  - Verify: No regressions
  - **Validation:** All tests pass

- [ ] 5.2 Run R CMD check
  - Execute: `devtools::check()`
  - Verify: 0 errors, 0 warnings
  - **Validation:** Clean check

- [ ] 5.3 Verify no remaining duplicates
  - Grep for old function names
  - Verify only canonical versions remain
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
