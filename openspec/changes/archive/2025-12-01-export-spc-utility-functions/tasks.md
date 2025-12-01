# Implementation Tasks: export-spc-utility-functions

Tracking: GitHub Issue #64

## Phase 1: Create Public API Functions

- [ ] 1.1 Create `bfh_extract_spc_stats()` in `R/export_pdf.R`
  - Add comprehensive roxygen documentation with @export
  - Add parameter validation (check summary is data frame or NULL)
  - Add @param, @return, @examples documentation
  - Keep backward compatibility with internal version
  - **File:** `R/export_pdf.R` (after line 660)
  - **Validation:** Function exported, documentation complete

- [ ] 1.2 Create `bfh_merge_metadata()` in `R/export_pdf.R`
  - Add comprehensive roxygen documentation with @export
  - Add parameter validation (check metadata is list)
  - Add @param, @return, @examples documentation
  - Keep backward compatibility with internal version
  - **File:** `R/export_pdf.R` (after line 707)
  - **Validation:** Function exported, documentation complete

- [ ] 1.3 Update internal functions to call public API
  - Change `extract_spc_stats` to call `bfh_extract_spc_stats`
  - Change `merge_metadata` to call `bfh_merge_metadata`
  - Keep internal versions as deprecated aliases
  - **File:** `R/export_pdf.R:661, 707`
  - **Validation:** No logic duplication, internal versions delegate

## Phase 2: Documentation

- [ ] 2.1 Regenerate package documentation
  - Execute: `devtools::document()`
  - Verify: NAMESPACE updated with new exports
  - **Validation:** man/bfh_extract_spc_stats.Rd created

- [ ] 2.2 Update package exports
  - Verify NAMESPACE contains `export(bfh_extract_spc_stats)`
  - Verify NAMESPACE contains `export(bfh_merge_metadata)`
  - **File:** `NAMESPACE` (auto-generated)
  - **Validation:** Both functions exported

## Phase 3: Testing

- [ ] 3.1 Add tests for `bfh_extract_spc_stats()`
  - Test with valid summary data frame
  - Test with NULL summary
  - Test with empty summary (0 rows)
  - Test with missing columns (graceful handling)
  - **File:** `tests/testthat/test-export_pdf.R`
  - **Validation:** All test cases pass

- [ ] 3.2 Add tests for `bfh_merge_metadata()`
  - Test with valid metadata list
  - Test with empty metadata list
  - Test metadata override of defaults
  - Test with chart_title parameter
  - **File:** `tests/testthat/test-export_pdf.R`
  - **Validation:** All test cases pass

- [ ] 3.3 Run full test suite
  - Execute: `devtools::test()`
  - Verify: No regressions, all tests pass
  - **Validation:** 0 failures

## Phase 4: Quality Checks

- [ ] 4.1 Run R CMD check
  - Execute: `devtools::check()`
  - Verify: 0 errors, 0 warnings, 0 notes
  - **Validation:** Clean check output

- [ ] 4.2 Verify function exports
  - Check functions appear in package help: `?bfh_extract_spc_stats`
  - Check functions listed in package index
  - **Validation:** Documentation accessible

## Phase 5: Version and Documentation

- [ ] 5.1 Update NEWS.md
  - Add entry under new minor version (0.4.0 - new exported functions)
  - Document: "Export bfh_extract_spc_stats() and bfh_merge_metadata() as public API"
  - Reference GitHub issue #64
  - **File:** `NEWS.md`
  - **Validation:** Entry follows existing format

- [ ] 5.2 Bump package version
  - Update DESCRIPTION version field (minor bump: 0.3.6 → 0.4.0)
  - New exported functions = minor version bump (semver)
  - **File:** `DESCRIPTION:3`
  - **Validation:** Version follows semver

- [ ] 5.3 Commit changes
  - Commit message: `feat(api): export bfh_extract_spc_stats and bfh_merge_metadata (#64)`
  - Include all modified files
  - **Validation:** Git status clean, commit message follows conventions

## Phase 6: Deployment

- [ ] 6.1 Push to remote
  - Execute: `git push origin main`
  - **Validation:** Remote updated successfully

- [ ] 6.2 Update GitHub issue #64
  - Add label: `openspec-deployed`
  - Close with comment referencing commit
  - **Validation:** Issue closed and labeled

- [ ] 6.3 Archive OpenSpec change
  - Execute: `openspec archive export-spc-utility-functions --yes`
  - **Validation:** Change moved to archive

## Dependencies

**Sequential dependencies:**
- Phase 1 → Phase 2 (functions must exist before documenting)
- Phase 2 → Phase 3 (exports must exist before testing)
- Phase 3 → Phase 4 (tests must pass before quality checks)
- Phase 4 → Phase 5 (quality verified before versioning)
- Phase 5 → Phase 6 (changes committed before deployment)

**No parallel work:** All phases are sequential.

## Validation Criteria

**Phase 1 complete when:**
- `bfh_extract_spc_stats()` and `bfh_merge_metadata()` defined
- Functions have @export tags
- Internal versions delegate to public API

**Phase 2 complete when:**
- `devtools::document()` succeeds
- NAMESPACE contains both exports
- Man pages created for both functions

**Phase 3 complete when:**
- All new tests pass
- `devtools::test()` shows 0 failures
- Test coverage maintained

**Phase 4 complete when:**
- `devtools::check()` shows 0 errors/warnings/notes
- Functions accessible via `?bfh_extract_spc_stats`

**Phase 5 complete when:**
- Version bumped to 0.4.0
- NEWS.md updated
- Changes committed

**Phase 6 complete when:**
- Remote repository updated
- GitHub issue closed and labeled
- OpenSpec change archived

## SPCify Migration Path

After this change is deployed, SPCify can migrate:

**Before:**
```r
stats <- BFHcharts:::extract_spc_stats(result$summary)
meta <- BFHcharts:::merge_metadata(metadata, chart_title)
```

**After:**
```r
stats <- BFHcharts::bfh_extract_spc_stats(result$summary)
meta <- BFHcharts::bfh_merge_metadata(metadata, chart_title)
```

**Migration PR in SPCify:**
- Update `R/utils_server_export.R:376-379`
- Update DESCRIPTION to require `BFHcharts (>= 0.4.0)`
- Close SPCify issue #97

## Notes

- **API expansion** - no breaking changes
- **Minor version bump** - new exported functions (semver)
- **SPCify impact** - removes `:::` usage, improves stability
- **Backward compatible** - internal versions still work (deprecated)
