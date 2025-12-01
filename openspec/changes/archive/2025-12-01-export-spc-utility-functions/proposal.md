# export-spc-utility-functions

## Why

**Problem:** SPCify (downstream package) uses BFHcharts internal functions via `:::` accessor, breaking public API contract and making SPCify vulnerable to upstream changes.

**Current situation:**
- SPCify calls `BFHcharts:::extract_spc_stats()` to extract SPC statistics
- SPCify calls `BFHcharts:::merge_metadata()` to merge metadata with chart title
- Both functions are marked `@keywords internal` and not exported
- This creates tight coupling and breaks R package best practices

**Impact:**
- SPCify code is fragile and breaks with BFHcharts internal refactoring
- No API stability guarantees for downstream packages
- Violates separation of concerns (SPCify shouldn't access internals)
- Testing becomes difficult (can't mock/stub internal functions easily)

**Use case in SPCify:**
```r
# R/utils_server_export.R:376-379
generate_pdf_preview <- function(result, metadata) {
  stats <- BFHcharts:::extract_spc_stats(result$summary)  # BAD
  meta <- BFHcharts:::merge_metadata(metadata, result$config$chart_title)  # BAD
  # ... generate PDF
}
```

## What Changes

**Export two utility functions as public API:**

1. **`bfh_extract_spc_stats()`** - Extract SPC statistics from qic summary
   - Rename: `extract_spc_stats` → `bfh_extract_spc_stats`
   - Add `@export` tag
   - Add comprehensive roxygen documentation
   - Add parameter validation
   - Keep internal version as alias for backward compatibility

2. **`bfh_merge_metadata()`** - Merge user metadata with defaults
   - Rename: `merge_metadata` → `bfh_merge_metadata`
   - Add `@export` tag
   - Add comprehensive roxygen documentation
   - Add parameter validation
   - Keep internal version as alias for backward compatibility

**Rationale for naming:**
- Prefix with `bfh_` for namespace consistency (matches `bfh_qic`, `bfh_export_pdf`)
- Makes it clear these are BFHcharts functions when used in downstream packages
- Follows tidyverse naming conventions

## Impact

**Affected specs:**
- `public-api` (new requirements for exported utility functions)

**Affected code:**
- `R/export_pdf.R` - Add public API versions with documentation
- `tests/testthat/test-export_pdf.R` - Add public API tests
- `NAMESPACE` - Auto-generated exports via roxygen2

**User-visible changes:**
- ✅ SPCify can call `BFHcharts::bfh_extract_spc_stats()` instead of `:::`
- ✅ SPCify can call `BFHcharts::bfh_merge_metadata()` instead of `:::`
- ✅ Functions appear in package documentation
- ✅ API stability guarantees via semantic versioning

**Breaking changes:**
- ⚠️ None - this is additive API expansion
- ⚠️ Internal functions remain for backward compatibility (deprecated)
- ⚠️ Future major version can remove internal versions

**Compatibility:**
- Fully backward compatible
- SPCify can migrate gradually (internal versions still work)
- No impact on existing BFHcharts users

## Alternatives Considered

**Alternative 1: Export with original names**
```r
#' @export
extract_spc_stats <- function(summary) { ... }
```
**Rejected because:**
- Doesn't follow BFHcharts naming convention (`bfh_` prefix)
- Generic names risk namespace conflicts
- Inconsistent with `bfh_qic()`, `bfh_export_pdf()`

**Alternative 2: Create wrapper functions in SPCify**
```r
# In SPCify:
spcify_extract_stats <- function(result) {
  BFHcharts:::extract_spc_stats(result$summary)
}
```
**Rejected because:**
- Still uses `:::` accessor (problem remains)
- Adds maintenance burden to SPCify
- Doesn't solve root cause (internal dependency)

**Alternative 3: Duplicate code in SPCify**
```r
# Copy extract_spc_stats logic to SPCify
```
**Rejected because:**
- Code duplication violates DRY principle
- Logic drift between packages over time
- Increases maintenance burden

**Chosen approach: Export with `bfh_` prefix**
- ✅ Follows package naming conventions
- ✅ Clear namespace ownership
- ✅ API stability guarantees
- ✅ Minimal code changes
- ✅ Backward compatible

## Related

- GitHub Issue: [#64](https://github.com/johanreventlow/BFHcharts/issues/64)
- SPCify Issue: #97 (Export code review issues)
- SPCify File: `R/utils_server_export.R:376-379`
