# Implementation Tasks: fix-centerline-label-precision

Tracking: GitHub Issue #63

## Phase 1: Code Implementation

- [ ] 1.1 Modify `format_y_value()` in `R/utils_label_formatting.R`
  - Update line 54: add `accuracy = 0.1` parameter to `scales::label_percent()`
  - Verify change: `scales::label_percent(accuracy = 0.1)(val)`
  - **File:** `R/utils_label_formatting.R:54`
  - **Validation:** Visual inspection, no syntax errors

- [ ] 1.2 Update function documentation
  - Update @examples in roxygen comments to reflect new behavior
  - Change example: `format_y_value(0.456, "percent")` returns `"45.6%"` (not `"46%"`)
  - **File:** `R/utils_label_formatting.R:24-34`
  - **Validation:** `devtools::document()` succeeds, man page updated

## Phase 2: Test Updates

- [ ] 2.1 Update existing percent formatting tests
  - Modify line 27: `expect_equal(format_y_value(0.456, "percent"), "45.6%")`
  - Add line 28.5: `expect_equal(format_y_value(0.987, "percent"), "98.7%")`
  - Verify line 28: `expect_equal(format_y_value(0.999, "percent"), "100%")` still valid
  - **File:** `tests/testthat/test-utils_label_formatting.R:25-30`
  - **Validation:** `devtools::test()` passes

- [ ] 2.2 Add edge case tests for decimal precision
  - Test values near boundaries: 0.001, 0.995, 0.999
  - Test centerline-specific scenarios (values in 0.95-1.0 range)
  - **File:** `tests/testthat/test-utils_label_formatting.R:32-36` (new section)
  - **Validation:** New tests pass

- [ ] 2.3 Run full test suite
  - Execute: `devtools::test()`
  - Verify: All tests pass, no regressions
  - **Validation:** Test output shows 0 failures

## Phase 3: Integration Verification

- [ ] 3.1 Visual verification with demo chart
  - Create test p-chart with CL near but not at 100%
  - Verify centerline label shows decimal precision (e.g., "98.7%")
  - **Script:** Manual test or use `inst/examples/` if exists
  - **Validation:** Visual inspection of rendered chart

- [ ] 3.2 Check consistency with y-axis labels
  - Verify y-axis tick labels use same precision as CL labels
  - Check if `apply_y_axis_formatting()` also needs update
  - **File:** `R/utils_y_axis_formatting.R`
  - **Validation:** Tick labels and CL labels have consistent precision

## Phase 4: Package Quality Checks

- [ ] 4.1 Regenerate documentation
  - Execute: `devtools::document()`
  - Verify: NAMESPACE unchanged, man pages updated
  - **Validation:** Git diff shows only man page changes

- [ ] 4.2 Run R CMD check
  - Execute: `devtools::check()`
  - Verify: 0 errors, 0 warnings, 0 notes
  - **Validation:** Check output clean

- [ ] 4.3 Check test coverage
  - Execute: `covr::package_coverage()`
  - Verify: Coverage maintained or improved
  - **Validation:** Coverage report shows ≥90% overall

## Phase 5: Version and Documentation

- [ ] 5.1 Update NEWS.md
  - Add entry under new patch version (e.g., 0.3.6)
  - Document: "Bug fix: Percent labels now show one decimal place for improved precision"
  - **File:** `NEWS.md`
  - **Validation:** Entry follows existing format

- [ ] 5.2 Bump package version
  - Update DESCRIPTION version field (patch bump)
  - **File:** `DESCRIPTION:3`
  - **Validation:** Version follows semver (0.3.5 → 0.3.6)

- [ ] 5.3 Commit changes
  - Commit message: `fix(labels): show decimal precision in percent labels (#63)`
  - Include all modified files
  - **Validation:** Git status clean, commit message follows conventions

## Phase 6: Deployment

- [ ] 6.1 Push to remote
  - Execute: `git push origin main`
  - **Validation:** Remote updated successfully

- [ ] 6.2 Update GitHub issue #63
  - Add label: `openspec-deployed`
  - Close with comment referencing commit
  - **Validation:** Issue closed and labeled

- [ ] 6.3 Archive OpenSpec change
  - Execute: `openspec archive fix-centerline-label-precision --yes`
  - **Validation:** Change moved to archive, `openspec list` shows removal

## Dependencies

**Sequential dependencies:**
- Phase 1 → Phase 2 (code must exist before testing)
- Phase 2 → Phase 3 (tests must pass before integration)
- Phase 3 → Phase 4 (integration verified before quality checks)
- Phase 4 → Phase 5 (quality verified before versioning)
- Phase 5 → Phase 6 (changes committed before deployment)

**No parallel work:** All phases are sequential due to tight integration.

## Validation Criteria

**Phase 1 complete when:**
- `format_y_value(0.987, "percent")` returns `"98.7%"` (not `"99%"`)
- No R syntax errors in modified file

**Phase 2 complete when:**
- `devtools::test()` exits with 0 failures
- New tests for decimal precision pass

**Phase 3 complete when:**
- Demo chart shows "98.7%" on centerline label (visual verification)
- Y-axis and label precision consistent

**Phase 4 complete when:**
- `devtools::check()` shows 0 errors/warnings/notes
- Test coverage ≥90%

**Phase 5 complete when:**
- VERSION bumped, NEWS.md updated
- Changes committed to version control

**Phase 6 complete when:**
- Remote repository updated
- GitHub issue closed and labeled
- OpenSpec change archived

## Rollback Plan

If issues discovered after deployment:

1. **Revert commit:**
   ```bash
   git revert <commit-hash>
   git push origin main
   ```

2. **Restore from archive:**
   ```bash
   # OpenSpec doesn't support unarchive, but can recreate from archive
   cp -r openspec/changes/archive/YYYY-MM-DD-fix-centerline-label-precision \
         openspec/changes/fix-centerline-label-precision
   ```

3. **Reopen GitHub issue with findings**

## Notes

- **Visual change only** - no API or statistical changes
- **Low risk** - isolated to label formatting
- **No SPCify impact** - purely visual, SPCify unaffected
- **Quick implementation** - estimated 1-2 hour total work
