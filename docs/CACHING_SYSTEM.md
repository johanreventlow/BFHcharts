# BFHcharts Caching System

BFHcharts uses a minimal caching strategy focused on simplicity and reliability.

## Overview

The package uses **1 cache layer**:

- **Marquee Style Cache** - Caches marquee style objects (always active, ~10 lines of code)

Previous complex TTL-based caching systems (grob height cache, panel height cache) were **removed** in v0.5.0 to simplify the codebase. Profiling showed caching was rarely beneficial for typical standalone package usage patterns.

---

## Marquee Style Cache

**Purpose:** Eliminates redundant creation of marquee style objects.

**Location:** `R/utils_label_helpers.R`

**Implementation:**
```r
.marquee_style_cache <- new.env(parent = emptyenv())
```

**What gets cached:**
- Marquee style objects keyed by `lineheight` parameter
- Styles are immutable based on lineheight, so caching is safe

**Performance:**
- Style creation: ~1-2ms
- Cache hit: < 0.01ms
- **~100-200x speedup** on cache hit

**API:**
```r
# Automatic caching (transparent)
style <- get_right_aligned_marquee_style(lineheight = 0.9)

# Manual cache management (for testing)
clear_marquee_style_cache()  # Clear all entries
```

**Lifecycle:**
- Cache entries persist for the entire R session
- No TTL (styles are immutable)
- No max size limit (typically < 10 entries)
- Memory footprint: negligible (~50 KB max)

---

## Why We Removed Complex Caching

The previous system had ~1,500 lines of code for:
- TTL-based cache management
- Auto-purge strategies
- Statistics tracking
- Configuration APIs
- Global state management

**Problems identified:**
1. **Disabled by default** - never actually used in production
2. **Over-engineered** - complexity outweighed benefits for a standalone package
3. **Global state concerns** - problematic in multi-session Shiny apps
4. **Thread safety issues** - not safe for parallel processing
5. **Maintenance burden** - significant code to maintain with little benefit

**Decision:** Remove complex caching, keep only the simple marquee style cache which is always beneficial and has no downsides.

---

## For Users

No configuration needed. The marquee style cache works automatically and transparently. Simply use:

```r
library(BFHcharts)
plot <- bfh_qic(data, x, y, ...)
```

If you need to clear the cache (rare):

```r
BFHcharts:::clear_marquee_style_cache()
```

---

## Summary

**Current state:**
- 1 simple cache (~10 LOC)
- Always active
- No configuration required
- No global state concerns
- Thread-safe (immutable objects)

**Previous state (removed in v0.5.0):**
- 3 caches (~1,500 LOC)
- Disabled by default
- Complex configuration API
- Global state mutations
- Not thread-safe
