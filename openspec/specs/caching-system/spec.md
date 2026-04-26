# caching-system Specification

## Purpose
TBD - created by archiving change document-caching-system. Update Purpose after archive.
## Requirements
### Requirement: Cache configuration functions SHALL include global state warnings

All cache configuration functions SHALL include Roxygen `@details` sections warning about global state mutations and thread safety.

**Rationale:**
- Users must understand side effects before enabling caching
- Prevents unexpected behavior in concurrent environments
- Follows R package best practices for documenting global state

#### Scenario: User views help for configure_grob_cache

**Given** a user wants to enable grob caching
**When** they view `?configure_grob_cache`
**Then** the help page SHALL display warnings about:
  - Global state mutation
  - Session-level persistence
  - Thread safety limitations
  - Manual cleanup responsibility

**Implementation:**
```r
#' @details
#' **Global State Warning:** This function mutates package-level global state.
#' Cache configuration persists for the entire R session across all BFHcharts
#' plotting operations.
#'
#' **Thread Safety:** The cache is NOT thread-safe. Avoid enabling caching in
#' concurrent environments (e.g., parallel processing, some Shiny configurations).
#'
#' **Cleanup:** Cache is not automatically cleared between plots. Call
#' `clear_grob_cache()` to manually purge cached entries.
```

**Validation:**
- `?configure_grob_cache` displays all warnings
- Warnings are prominently visible in documentation

### Requirement: Caching documentation SHALL include troubleshooting guide

The `docs/CACHING_SYSTEM.MD` file SHALL include a troubleshooting section with common issues and solutions.

**Rationale:**
- Users need guidance when caching causes unexpected behavior
- Reduces support burden
- Enables self-service problem resolution

#### Scenario: User experiences stale cache issue

**Given** documentation about caching troubleshooting
**When** a user experiences stale cache data
**Then** the documentation SHALL provide:
  - Problem description
  - Root cause explanation
  - Solution with code example

### Requirement: Cache keys SHALL incorporate all inputs affecting cached value

All package-level caches SHALL construct keys from every input that affects the cached value, including font measurement, style resolution, Quarto path, and text grob measurement caches.

**Rationale:**
- Stale cache hits on changed inputs produce visual regressions
- Parallel/sequential rendering must yield identical results
- Tests modifying fonts or devices must not see stale cache

**Required key components (non-exhaustive):**
- Font-related caches: fontfamily, font size, device type (pdf/svg/png/cairo)
- Quarto path cache: env-var snapshot of `QUARTO_PATH` and `PATH`
- Style caches: theme name + override list hash
- Text grob caches: text + fontfamily + size + device

#### Scenario: Changed fontfamily causes cache miss

**Given** a cached label measurement for fontfamily "Mari"
**When** the same text is measured with fontfamily "Roboto"
**Then** the cache SHALL miss and re-measure
**And** the two cached entries SHALL coexist (different keys)

### Requirement: Package SHALL provide canonical cache-reset helper

The package SHALL expose an internal helper `bfh_reset_caches()` that clears all package-level caches.

**Rationale:**
- Tests need deterministic reset without leaking implementation details
- Long-running Shiny sessions need a supported way to reclaim memory

The helper SHALL be:
- Marked `@keywords internal`
- Documented with a list of cleared caches
- Called automatically by the test helper (`tests/testthat/helper-cache.R`)

#### Scenario: Reset clears all caches

**Given** one or more caches contain entries
**When** `bfh_reset_caches()` is called
**Then** every package-level cache environment SHALL be empty

```r
# Populate caches via normal rendering
bfh_qic(test_data, x = date, y = value, chart_type = "i") |> plot()
# Verify cache non-empty, then reset
BFHcharts:::bfh_reset_caches()
# Caches are empty
```

#### Scenario: Test helper resets before each test

**Given** a test file sourcing `helper-cache.R`
**When** `test_that()` blocks run
**Then** each block SHALL start with clean caches
**And** cache state from prior tests SHALL NOT leak

