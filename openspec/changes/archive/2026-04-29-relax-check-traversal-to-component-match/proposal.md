## Why

`.check_traversal()` in `R/utils_path_policy.R:83-91` rejects every filename containing `..` as a literal substring:

```r
.check_traversal <- function(path) {
  if (grepl("..", path, fixed = TRUE)) {
    stop("path cannot contain '..' (path traversal attempt detected)...")
  }
}
```

This is a **usability bug**, not a security hole. It rejects legitimate filenames:
- `report..v2.pdf` — false positive
- `analyse..final.pdf` — false positive
- `..hidden.pdf` — false positive (legitimate dotfile pattern)
- `data..backup.csv` — false positive

The over-restrictive match errs on the safe side (no path traversal can occur), but produces confusing errors for valid filenames. Claude code review #6, severity medium.

## What Changes

- Replace literal substring match with **path-component** match
- A path is rejected only if any path-separator-delimited component equals exactly `..`
- Existing rejections preserved:
  - `../etc/passwd` → rejected (component `..`)
  - `output/../secret.pdf` → rejected (component `..`)
  - `../../../sensitive.pdf` → rejected
- Newly accepted (false positives fixed):
  - `report..v2.pdf` → accepted (component is `report..v2.pdf`, not `..`)
  - `..hidden.pdf` → accepted (component is `..hidden.pdf`)
  - `analyse..final.pdf` → accepted

**Implementation:**
```r
.check_traversal <- function(path) {
  parts <- strsplit(path, "[/\\\\]")[[1]]
  if (any(parts == "..")) {
    stop(
      "path cannot contain '..' as a path component (traversal attempt)\n",
      "  Provided path: ", basename(path),
      call. = FALSE
    )
  }
}
```

Cross-platform (handles both `/` and `\` separators) — matches existing behavior.

## Impact

**Affected specs:**
- `pdf-export` — MODIFIED requirement: path traversal rejection (component-based, not substring)

**Affected code:**
- `R/utils_path_policy.R:83-91` — replace match logic
- `tests/testthat/test-path-policy.R` — extend with positive tests for legitimate `..` filenames + preserve existing negative tests

**Non-breaking** for security:
- All previously-rejected attacks still rejected
- Legitimate filenames now accepted
- Pre-1.0 → PATCH bump (bug fix)

## Cross-repo impact (biSPCharts)

None expected. biSPCharts unlikely to use double-dot filenames in normal flows.

## Related

- GitHub Issue: #214
- Source: BFHcharts code review 2026-04-27 (Claude finding #6)
