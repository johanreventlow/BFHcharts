# Proposal: Fix PDF Export Bugs

**Status:** proposed
**Created:** 2025-12-01
**Author:** Claude (from code review)

## Why

A code review identified 5 issues in the PDF export functionality (`R/export_pdf.R`) that cause failures or unexpected behavior. Two are high severity (Windows path handling, missing date metadata), two are medium severity (custom templates, Quarto version check), and one is low severity (insufficient test coverage). These issues prevent reliable cross-platform use and violate documented API contracts.

## Problem Statement

### High Severity

1. **Path Escaping for Typst (lines 389, 395)**: Typst import and image paths are written without escaping Windows-style backslashes or paths with spaces. This yields invalid Typst strings (`\U…` escapes) and Quarto compilation fails on Windows or with paths containing spaces.

2. **metadata$date Not Forwarded (line 356)**: The `metadata$date` parameter is documented and defaults to `Sys.Date()`, but is never passed to the Typst template. The PDF always shows `datetime.today()` from the template, making user-supplied dates impossible.

### Medium Severity

3. **Custom Template Paths Not Supported (line 216)**: Documentation advertises custom template support ("Pass custom template path to bfh_export_pdf()"), but `bfh_create_typst_document()` hardcodes the packaged template via `system.file()`. No parameter exists to specify a user template.

4. **Quarto Version Check Incomplete (line 181)**: `quarto_available()` only checks that the binary exists, not that version is ≥1.4.0 as documented. Users on older Quarto without Typst support get opaque compile errors instead of clear upfront guidance.

### Low Severity

5. **PDF Tests Insufficient**: Current tests only assert that a PDF file exists after export. They don't validate metadata propagation (date, stats) or path escaping, so the above regressions wouldn't be caught automatically.

## Proposed Solution

### Path Escaping Fix

Apply `escape_typst_string()` with `normalizePath(..., winslash = "/")` to both:
- The `#import` line (line 389)
- The `image(...)` call (line 395)

### Date Metadata Fix

Add `metadata$date` to the parameters passed in `build_typst_content()` and emit it to the Typst template.

### Custom Template Fix

**Option A (Recommended):** Add `template_path` parameter to `bfh_export_pdf()` that overrides the default packaged template.

**Option B:** Update documentation to match current behavior (packaged templates only).

### Quarto Version Check Fix

Modify `quarto_available()` to:
1. Run `quarto --version`
2. Parse version output
3. Compare against minimum (1.4.0)
4. Return FALSE with informative message if version too low

### Test Coverage Improvement

Add tests for:
- Path escaping with spaces and backslashes
- Date metadata propagation to PDF
- SPC stats metadata propagation
- Quarto version requirement enforcement

## Impact Analysis

### Files Modified

1. `R/export_pdf.R`
   - `escape_typst_string()` - Apply to file paths
   - `build_typst_content()` - Add date parameter
   - `bfh_export_pdf()` - Add optional `template_path` parameter
   - `quarto_available()` - Add version checking

2. `tests/testthat/test-export_pdf.R` - Add validation tests
3. `tests/testthat/test-integration-export.R` - Add metadata tests

### Breaking Changes

**None** - All changes are backward compatible. New parameters have sensible defaults.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Path escaping breaks Unix paths | Low | Use `normalizePath()` with `winslash = "/"` works on all platforms |
| Quarto version parsing fails | Low | Graceful fallback to current behavior if parsing fails |
| Template path validation | Low | Check file existence before proceeding |

## Success Criteria

- [ ] PDF export works on Windows with paths containing spaces
- [ ] User-supplied `metadata$date` appears in PDF
- [ ] Custom template path can be specified (or docs updated)
- [ ] Quarto version <1.4 gives clear error message
- [ ] Tests verify all above behaviors

## Related

- Code Review: External review findings dated 2025-12-01
- GitHub Issue: #60
