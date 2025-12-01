# Tasks: Fix PDF Export Regressions

**Tracking:** GitHub Issue #62
**Status:** pending

## Phase 1: Chart Image Path Fix (High Priority)

- [ ] 1.1 Update `bfh_create_typst_document()` to copy chart image to output directory
  - Add `file.copy(chart_image, file.path(output_dir, basename(chart_image)))`
  - Check copy success and stop with clear error if failed
  - Pass only basename to `build_typst_content()`
- [ ] 1.2 Add test for chart image from different directory
- [ ] 1.3 Add test for chart image with spaces in path
- [ ] 1.4 Verify existing tests still pass

## Phase 2: Quarto Version Parsing Fix (High Priority)

- [ ] 2.1 Fix `check_quarto_version()` regex
  - Remove `^` anchor from pattern
  - Pattern: `[0-9]+\\.[0-9]+\\.?[0-9]*` (matches anywhere in string)
- [ ] 2.2 Add test cases for various Quarto version formats:
  - "1.4.557" (version only)
  - "Quarto 1.4.557" (prefixed)
  - "1.4" (two-part)
  - "1.3.340" (should fail)
- [ ] 2.3 Verify version comparison works correctly

## Phase 3: Template Path Validation (Medium Priority)

- [ ] 3.1 Add directory check in `bfh_export_pdf()`
  - `if (dir.exists(template_path)) stop(...)`
- [ ] 3.2 Add .typ extension check
  - `if (!grepl("\\.typ$", template_path)) stop(...)`
- [ ] 3.3 Check `file.copy()` return value in `bfh_create_typst_document()`
  - Stop with clear error if copy fails
- [ ] 3.4 Add tests for validation errors:
  - Directory passed as template_path
  - Non-.typ file passed
  - Copy failure (read-only destination)

## Phase 4: Path Escaping Consistency (Medium Priority)

- [ ] 4.1 Apply `escape_typst_path()` to custom template paths
  - In `build_typst_content()` for import statement
- [ ] 4.2 Verify escaping handles:
  - Windows backslashes (`C:\Users\...`)
  - Paths with spaces
  - Paths with quotes
- [ ] 4.3 Add unit tests for `escape_typst_path()` edge cases

## Phase 5: Test Content Verification (Low Priority)

- [ ] 5.1 Add test that reads generated .typ and verifies chart reference
- [ ] 5.2 Add test that verifies metadata appears in .typ content
- [ ] 5.3 Add test that verifies template import statement
- [ ] 5.4 Consider adding pdftools-based PDF content verification (optional)

## Phase 6: Documentation and Release

- [ ] 6.1 Run `devtools::document()`
- [ ] 6.2 Run `devtools::test()` - all tests pass
- [ ] 6.3 Run `devtools::check()` - no new warnings/errors
- [ ] 6.4 Update NEWS.md with bugfix notes
- [ ] 6.5 Bump version to 0.3.2 in DESCRIPTION
- [ ] 6.6 Commit and push
- [ ] 6.7 Close GitHub issue

---

## Dependencies

- Phase 1 and Phase 2 are independent (can run in parallel)
- Phase 3 is independent
- Phase 4 depends on Phase 1 (chart path handling affects escaping)
- Phase 5 depends on Phases 1-4
- Phase 6 depends on Phase 5

## Critical Files

### Modified
1. `R/export_pdf.R` - Main fixes (path handling, version parsing, validation)
2. `tests/testthat/test-export_pdf.R` - New and improved tests
3. `NEWS.md` - Release notes
4. `DESCRIPTION` - Version bump

### Unchanged
- `inst/templates/typst/bfh-template/` - Template files
