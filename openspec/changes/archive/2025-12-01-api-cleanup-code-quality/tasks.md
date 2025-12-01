# Tasks: API Cleanup and Code Quality

**Status:** pending
**Priority:** High
**Tracking:** GitHub Issue #66

## Phase 1: API Export Cleanup

- [ ] 1.1 Change `quarto_available()` from `@export` to `@keywords internal` only
- [ ] 1.2 Change `bfh_create_typst_document()` from `@export` to `@keywords internal` only
- [ ] 1.3 Change `bfh_compile_typst()` from `@export` to `@keywords internal` only
- [ ] 1.4 Run `devtools::document()` to regenerate NAMESPACE
- [ ] 1.5 Verify functions still accessible via `BFHcharts:::`
- [ ] 1.6 Update any documentation referencing these as exported functions

## Phase 2: Dead Code Removal

- [ ] 2.1 Verify `escape_typst_path()` is unused (grep codebase)
- [ ] 2.2 Remove `escape_typst_path()` OR document its purpose
- [ ] 2.3 Consolidate escaping functions if both kept

## Phase 3: Error Handling Improvements

- [ ] 3.1 Wrap `ggplot2::ggsave()` in `tryCatch()` (line ~174)
- [ ] 3.2 Wrap `writeLines()` in `tryCatch()` (line ~398)
- [ ] 3.3 Add `tryCatch()` to `system2()` in `bfh_compile_typst()` (line ~426)
- [ ] 3.4 Check `system2()` exit status and report errors
- [ ] 3.5 Fix version check fallback: change line 276 from `TRUE` to `FALSE`
- [ ] 3.6 Fix `on.exit()` timing - register before `dir.create()` (line ~163)

## Phase 4: Test Coverage for Error Paths

- [ ] 4.1 Add test for `ggsave()` failure handling
- [ ] 4.2 Add test for Quarto compilation failure
- [ ] 4.3 Add test for unparseable version (expects FALSE)
- [ ] 4.4 Add test for malformed `bfh_qic_result` structure

## Phase 5: Documentation and Release

- [ ] 5.1 Run `devtools::document()`
- [ ] 5.2 Run `devtools::check()` - no new warnings
- [ ] 5.3 Update NEWS.md
- [ ] 5.4 Bump version

## Critical Files

### Modified
1. `R/export_pdf.R` - API cleanup, error handling
2. `NAMESPACE` - Remove exports (auto-generated)
3. `man/*.Rd` - Updated docs (auto-generated)
4. `tests/testthat/test-export_pdf.R` - Error handling tests

## Priority Order

| Task | Priority | Effort |
|------|----------|--------|
| API export cleanup | HIGH | 30 min |
| Dead code removal | MEDIUM | 15 min |
| Error handling | HIGH | 1 hour |
| Test coverage | MEDIUM | 1 hour |
