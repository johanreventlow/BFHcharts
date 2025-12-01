# Specification: cache-architecture

## Overview

This specification defines requirements for cache system architecture in BFHcharts. It ensures cache implementations are simple, maintainable, and justified by data.

## MODIFIED Requirements

### Requirement: Cache systems SHALL be justified by profiling data

Any caching implementation SHALL be justified by measured performance benefits before introduction or retention.

**Rationale:**
- Prevents premature optimization
- Ensures complexity is warranted
- Data-driven architecture decisions

#### Scenario: Cache hit rate measurement

**Given** a cache system is implemented
**When** the test suite is executed
**Then** cache hit/miss statistics SHALL be logged
**And** hit rate SHALL be documented for decision-making

**Implementation:**
```r
# Temporary profiling wrapper
profile_cache_usage <- function() {
  hits <- 0
  misses <- 0

  # Wrap cache_get with counter
  original_get <- cache_get
  cache_get <<- function(...) {
    result <- original_get(...)
    if (is.null(result)) misses <<- misses + 1 else hits <<- hits + 1
    result
  }

  # Return profiling results
  list(
    hit_rate = hits / (hits + misses),
    total_accesses = hits + misses
  )
}
```

**Validation:**
- Profiling code can be temporarily added
- Hit rate is measured during test suite
- Decision documented in proposal

#### Scenario: Low hit rate leads to cache removal

**Given** cache hit rate is below 50%
**When** architectural decision is made
**Then** cache system SHALL be removed
**And** code complexity SHALL be reduced

**Implementation:**
```r
# BEFORE: Complex cache with TTL, stats, purge
.grob_height_cache <- new.env(parent = emptyenv())
attr(.grob_height_cache, "created") <- Sys.time()
attr(.grob_height_cache, "hits") <- 0
attr(.grob_height_cache, "misses") <- 0
# ... 500+ more lines

# AFTER: Direct computation (no caching)
measure_grob_height <- function(text, style) {
  grid::convertHeight(
    grid::grobHeight(grid::textGrob(text, gp = style)),
    "inches", valueOnly = TRUE
  )
}
```

**Validation:**
- No cache-related code remains
- Tests still pass
- Performance acceptable for use case

### Requirement: Cache implementations SHALL use standard libraries

If caching is justified (hit rate >50%), implementations SHALL use established packages rather than custom code.

**Rationale:**
- Reduces maintenance burden
- Benefits from community testing
- Follows DRY principle

#### Scenario: Using cachem for value caching

**Given** caching is justified by profiling
**When** cache implementation is needed
**Then** `cachem` package SHALL be used
**And** custom TTL/stats/purge logic SHALL NOT be implemented

**Implementation:**
```r
#' @importFrom cachem cache_mem
.grob_cache <- cachem::cache_mem(
  max_size = 100 * 1024^2,  # 100 MB
  max_age = 3600             # 1 hour TTL
)

get_cached_grob_height <- function(text, style) {
  key <- digest::digest(list(text, style))

  cached <- .grob_cache$get(key)
  if (!is.null(cached)) return(cached)

  value <- measure_grob_height(text, style)
  .grob_cache$set(key, value)
  value
}
```

**Validation:**
- `cachem` in DESCRIPTION Imports
- No custom TTL implementation
- No custom stats tracking
- No custom purge logic

### Requirement: Cache configuration SHALL be minimal

Cache configuration interfaces SHALL be simple with sensible defaults.

**Rationale:**
- Reduces API surface
- Prevents over-configuration
- Users rarely need to tune cache

#### Scenario: Simple cache control

**Given** caching is implemented
**When** user needs to control cache
**Then** only essential operations SHALL be exposed
**And** advanced tuning SHALL NOT be required

**Implementation:**
```r
#' Clear all caches
#'
#' @export
clear_bfh_caches <- function() {
  .grob_cache$reset()
  .panel_cache$reset()
  invisible(TRUE)
}

# NO LONGER NEEDED:
# - configure_grob_cache(enabled, ttl, max_size, stats_enabled, ...)
# - configure_panel_cache(enabled, ttl, max_size, stats_enabled, ...)
# - get_cache_stats()
# - purge_expired_entries()
# - etc.
```

**Validation:**
- Maximum 2 exported cache functions (clear, info)
- No TTL configuration exposed
- No size configuration exposed
- Sensible defaults handle 99% of cases

## Implementation Notes

**Decision tree:**

```
Profile cache hit rates
         │
         ▼
    Hit rate?
    ┌────┴────┐
   <50%      >50%
    │         │
    ▼         ▼
 Remove    Use cachem
 caching   package
    │         │
    ▼         ▼
 ~100 LOC  ~200 LOC
```

**Files to modify:**
- `R/utils_label_placement.R` - Major refactoring
- `R/utils_label_helpers.R` - Remove marquee cache
- `DESCRIPTION` - Add cachem if Phase C

**Testing requirements:**
- All existing tests must pass
- Performance must be acceptable
- No regression in chart quality

## Validation

**Profiling complete when:**
- Hit rates documented for all 3 caches
- Decision justified by data

**Refactoring complete when:**
- Code reduced by 80%+ (1,500 → 200-300 lines)
- All tests pass
- `devtools::check()` clean

**Quality checks:**
- No custom TTL logic
- No custom stats tracking
- No custom purge logic
- Uses cachem OR no caching

## Dependencies

**R packages:**
- `cachem` (only if Phase C chosen)
- `digest` (only if Phase C chosen, for cache keys)

**Related issues:**
- Issue #23 (Document caching) - Complete first for context
