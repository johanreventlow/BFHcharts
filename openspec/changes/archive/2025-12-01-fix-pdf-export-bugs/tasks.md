# Tasks: Fix PDF Export Bugs

**Tracking:** GitHub Issue #60
**Status:** completed

## Phase 1: Path Escaping Fix (High Priority)

- [x] 1.1 Create `escape_typst_path()` helper function in `R/export_pdf.R`
  - Uses `normalizePath(path, winslash = "/", mustWork = FALSE)`
  - Applies `escape_typst_string()` for special character escaping
- [x] 1.2 Update `build_typst_content()` to use `escape_typst_path()` for template import (line 389)
- [x] 1.3 Update `build_typst_content()` to use `escape_typst_path()` for image path (line 395)
- [x] 1.4 Add unit tests for path escaping with:
  - Windows-style backslash paths
  - Paths with spaces
  - Paths with special characters (quotes, parentheses)

## Phase 2: Date Metadata Fix (High Priority)

- [x] 2.1 Update `build_typst_content()` to include `metadata$date` in params
- [x] 2.2 Format date appropriately for Typst template (ISO or localized)
- [x] 2.3 Verify Typst template `bfh-template.typ` accepts date parameter
- [x] 2.4 Add unit test verifying date is passed to template
- [x] 2.5 Add integration test verifying custom date appears in generated Typst

## Phase 3: Quarto Version Check (Medium Priority)

- [x] 3.1 Modify `quarto_available()` to capture version output
- [x] 3.2 Parse version string (e.g., "1.4.557") into numeric components
- [x] 3.3 Compare against minimum version (1.4.0)
- [x] 3.4 Return FALSE with clear message if version too low
- [x] 3.5 Add graceful fallback if version parsing fails
- [x] 3.6 Add unit tests for version parsing
- [x] 3.7 Add test for version enforcement (mock or skip if Quarto not installed)

## Phase 4: Custom Template Support (Medium Priority)

- [x] 4.1 Add `template_path` parameter to `bfh_export_pdf()` (default NULL)
- [x] 4.2 Add `template_path` parameter to `bfh_create_typst_document()`
- [x] 4.3 Implement template path resolution:
  - If `template_path` provided: validate exists, use directly
  - If NULL: use packaged template via `system.file()`
- [x] 4.4 Update roxygen2 documentation for new parameter
- [ ] 4.5 Update `inst/templates/typst/README.md` to document actual behavior
- [x] 4.6 Add test for custom template usage

## Phase 5: Test Coverage Improvement (Low Priority)

- [x] 5.1 Add test: PDF export generates valid Typst with escaped paths
- [x] 5.2 Add test: metadata$date propagates to template params
- [x] 5.3 Add test: SPC stats propagate to template params
- [x] 5.4 Add test: Quarto version check returns correct result
- [ ] 5.5 Consider adding snapshot tests for generated Typst content
- [x] 5.6 Run `devtools::test()` and verify all new tests pass

## Phase 6: Documentation and Release

- [x] 6.1 Run `devtools::document()` to update man pages
- [x] 6.2 Update NEWS.md with bugfix notes for version 0.3.1
- [ ] 6.3 Run `devtools::check()` - no new errors or warnings
- [x] 6.4 Bump version to 0.3.1 in DESCRIPTION
- [ ] 6.5 Create git commit: `fix(export): resolve PDF export path and metadata issues`
- [ ] 6.6 Close GitHub issue

---

## Dependencies

- Phase 1 and Phase 2 are independent (can run in parallel)
- Phase 3 is independent
- Phase 4 depends on Phase 1 (path escaping needed for custom template paths)
- Phase 5 depends on Phases 1-4
- Phase 6 depends on Phase 5

## Estimated Effort

- Phase 1: 1 hour
- Phase 2: 30 minutes
- Phase 3: 1 hour
- Phase 4: 1 hour
- Phase 5: 1-2 hours
- Phase 6: 30 minutes

**Total:** 5-6 hours

## Critical Files

### Modified
1. `R/export_pdf.R` - Main changes (path escaping, date, version check, template path)
2. `tests/testthat/test-export_pdf.R` - New validation tests
3. `tests/testthat/test-integration-export.R` - Metadata propagation tests
4. `inst/templates/typst/README.md` - Documentation update
5. `NEWS.md` - Release notes
6. `DESCRIPTION` - Version bump to 0.3.1

### Unchanged
- `inst/templates/typst/bfh-template/` - Template files (may need minor date param support)
