# Proposal: Fix PDF Export Regressions and Validation Gaps

**Status:** draft
**Created:** 2025-12-01
**Tracking:** GitHub Issue #62

## Summary

Code review identified 5 issues in the PDF export implementation that cause regressions, incomplete validation, and insufficient test coverage. These need to be fixed before v0.3.2 release.

## Motivation

The recent PDF export fixes introduced new regressions:

1. **Public API regression** - `bfh_create_typst_document()` no longer works with arbitrary chart paths
2. **Incomplete version check** - Quarto versions like "Quarto 1.3.340" bypass the >=1.4 guard
3. **Weak template validation** - Directories and non-.typ files pass validation
4. **Path escaping not applied** - Custom paths with backslashes/quotes still break
5. **Tests don't verify content** - Regressions pass CI because tests only check file existence

## Proposed Changes

### 1. Fix chart_image path handling (High Priority)

**Problem:** `build_typst_content()` uses `basename(chart_image)` assuming the image is in the same directory as the .typ file. But `bfh_create_typst_document()` is exported and documented to accept arbitrary paths.

**Solution:**
- Copy chart image to temp directory in `bfh_create_typst_document()` (like we do for templates)
- Or use relative path calculation from .typ location to chart location
- Keep `basename()` approach but ensure copy happens first

### 2. Fix Quarto version parsing (High Priority)

**Problem:** `check_quarto_version()` regex `^[0-9]+\\.[0-9]+\\.?[0-9]*` fails on strings like "Quarto 1.3.340" because they don't start with digits.

**Solution:**
- Use more flexible regex that extracts version from anywhere in the string
- Pattern: `[0-9]+\\.[0-9]+\\.?[0-9]*` without `^` anchor
- Add test cases for various Quarto output formats

### 3. Strengthen template_path validation (Medium Priority)

**Problem:**
- `file.exists()` returns TRUE for directories
- No check that file has .typ extension
- `file.copy()` failure not checked

**Solution:**
- Add `!dir.exists(template_path)` check
- Add `.typ` extension validation
- Check `file.copy()` return value and stop with clear error

### 4. Apply escape_typst_path() consistently (Medium Priority)

**Problem:** The escaping function exists but isn't used for:
- Custom template paths in import statements
- Custom chart paths (if we support them)

**Solution:**
- Apply `escape_typst_path()` to template_file in import statement
- Apply to any user-provided paths that end up in Typst content

### 5. Improve test assertions (Low Priority)

**Problem:** Tests only check `file.exists()`, not content. Regressions pass CI.

**Solution:**
- Add tests that read generated .typ content and verify:
  - Chart image reference is present and valid
  - Metadata (date, hospital, etc.) appears in content
  - Template import is correct
- Consider parsing PDF text with pdftools to verify output

## Impact

- **API Compatibility:** Fixes regression in `bfh_create_typst_document()` public API
- **Robustness:** Better error messages for invalid inputs
- **Windows Support:** Path escaping works for all path formats
- **Test Coverage:** Catches future regressions

## Alternatives Considered

1. **Make bfh_create_typst_document() internal-only** - Rejected; it's already exported and documented
2. **Require chart image in same directory** - Rejected; breaks documented API contract
3. **Skip Windows path testing** - Rejected; need cross-platform support

## References

- Code review findings (2025-12-01)
- Previous fix: GitHub Issue #60, #61
