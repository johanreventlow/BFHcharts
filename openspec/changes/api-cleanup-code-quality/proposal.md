# Proposal: API Cleanup and Code Quality Improvements

**Status:** draft
**Created:** 2025-12-01
**Priority:** High
**Tracking:** GitHub Issue #66
**Source:** R Package Code Review + Error Handling Review (automated agent analysis)

## Summary

Code review identified API inconsistencies, dead code, and error handling gaps in the PDF export module. These issues violate the project's documented API design principles and could lead to confusing behavior.

## Motivation

### 1. API Export Inconsistency (MAJOR)

Per `CLAUDE.md`, the package should have:
- **Public API (1 function):** `bfh_qic()` only
- **Internal API:** Functions marked `@keywords internal` accessible via `:::`

However, three PDF export functions are incorrectly `@export`ed:
- `quarto_available()` (line 217-218)
- `bfh_create_typst_document()` (line 298-299)
- `bfh_compile_typst()` (line 413-414)

### 2. Dead Code

`escape_typst_path()` function (lines 644-660) appears unused - `build_typst_content()` uses `escape_typst_string()` instead.

### 3. Inconsistent Error Handling

- `ggplot2::ggsave()` not wrapped in error handling
- `writeLines()` not wrapped in error handling
- `system2()` in `bfh_compile_typst()` missing `tryCatch()`
- Version check fallback returns TRUE on parse failure (should be FALSE)

## Proposed Changes

### 1. Fix API Exports

Change from `@export` to `@keywords internal` only:
```r
#' @keywords internal
quarto_available <- function(...) { }

#' @keywords internal
bfh_create_typst_document <- function(...) { }

#' @keywords internal
bfh_compile_typst <- function(...) { }
```

Then run `devtools::document()` to update NAMESPACE.

### 2. Remove Dead Code

Either:
- Remove `escape_typst_path()` if unused
- Or use it and document when to use each escaping function

### 3. Add Error Handling

Wrap file operations in `tryCatch()`:
```r
tryCatch({
  ggplot2::ggsave(...)
}, error = function(e) {
  stop("Failed to save chart image: ", e$message, call. = FALSE)
})
```

### 4. Fix Version Check Fallback

Change line 276 from `return(TRUE)` to `return(FALSE)` for fail-safe behavior.

## Impact

- **API:** Makes internal functions truly internal (advanced users use `:::`)
- **Maintenance:** Removes dead code, improves error messages
- **Reliability:** Better error handling catches issues earlier

## Testing Requirements

- Verify internal functions still accessible via `BFHcharts:::`
- Add tests for error handling paths
- Test version check fallback behavior

## References

- R Package Code Review (2025-12-01)
- Error Handling Review (2025-12-01)
- CLAUDE.md API Design Principles
