# Proposal: Performance Optimization for PDF Export

**Status:** draft
**Created:** 2025-12-01
**Priority:** Medium
**Tracking:** GitHub Issue #67
**Source:** Performance Review (automated agent analysis)

## Summary

Performance analysis identified opportunities to improve PDF export speed by 40-50% through more efficient file operations, reduced image resolution, and caching of system checks.

## Current Performance Profile

**Single PDF export: ~500-800ms**
- Template directory copy: ~100ms (inefficient recursive loop)
- PNG generation at 300 DPI: ~150-200ms (unnecessarily high)
- Typst compilation: ~200-300ms (external, cannot optimize)
- Quarto availability check: ~50ms (repeated every call)
- File operations: ~50ms (sequential instead of batch)

**Batch export (10 PDFs): ~6-7 seconds**

## Proposed Optimizations

### 1. Fix Recursive Template Copy (HIGH IMPACT)

**Problem:** Manual `for` loop copies files one by one (lines 341-361).

**Solution:** Use `file.copy(..., recursive = TRUE)`:
```r
# Instead of manual iteration
file.copy(template_dir, output_dir, recursive = TRUE)
```

**Expected:** 5-10x faster template copy (~100ms → ~10-20ms)

### 2. Reduce PNG Resolution (HIGH IMPACT)

**Problem:** 300 DPI generates ~15-25 MB temp files unnecessarily.

**Solution:** Reduce to 150 DPI for PDF output:
```r
ggplot2::ggsave(..., dpi = 150)  # Was 300
```

**Expected:** 75% smaller temp files, 4x faster PNG generation

### 3. Cache Quarto Availability Check (MEDIUM IMPACT)

**Problem:** `system2("quarto", "--version")` spawns process every call.

**Solution:** Session-level caching:
```r
.quarto_cache <- new.env(parent = emptyenv())

quarto_available <- function(min_version = "1.4.0") {
  cache_key <- paste0("available_", min_version)
  if (exists(cache_key, envir = .quarto_cache)) {
    return(get(cache_key, envir = .quarto_cache))
  }
  # ... check and cache result
}
```

**Expected:** 95% reduction in check time for repeated exports

### 4. Batch File Operations (LOW IMPACT)

**Problem:** Sequential `file.copy()` calls have syscall overhead.

**Solution:** Batch copy operations where possible.

### 5. Pre-allocate String Vectors (MINIMAL)

**Problem:** Growing vector with `c()` in loop (lines 598-602).

**Solution:** Use `character(length(params))` or `mapply()`.

## Expected Results

**After Optimizations:**
- Single PDF export: ~300-400ms (**40-50% improvement**)
- Batch export (10 PDFs): ~3-4 seconds (**45% improvement**)

## Impact

- **Performance:** Significant speedup for batch operations
- **Resource Usage:** Lower temp disk usage (smaller PNG files)
- **User Experience:** Faster PDF generation in Shiny apps

## Testing Requirements

- Add benchmark suite for export functions
- Verify 150 DPI quality is acceptable for PDF output
- Profile memory usage with `profvis` for large charts
- Test batch export performance

## References

- Performance Review (2025-12-01)
