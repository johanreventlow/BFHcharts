# simplify-cache-system

## Why

**Problem:** Tre separate cache-systemer med duplikeret logik bruger 1,500+ linjer kode. Dette er over-engineering for den nuværende use case.

**Current situation:**

**Cache Systems (3 stk):**
- `.grob_height_cache` - Cacher text measurement grobs
- `.panel_height_cache` - Cacher panel dimensions
- `.marquee_style_cache` - Cacher marquee styles

**Duplikeret logik i hvert system:**
- TTL (time-to-live) management
- Stats tracking (hits, misses, evictions)
- Purge logic
- Configuration functions

**Placering:**
- `R/utils_label_placement.R` (~1,200 linjer cache-relateret)
- `R/utils_label_helpers.R` (~300 linjer marquee cache)

**Impact:**
- **Complexity:** Over-engineering til intern hospital-pakke
- **Maintenance:** Samme logik vedligeholdes 3 steder
- **Unclear benefit:** Cache hit rates er ukendte
- **Code bloat:** 1,500 linjer → potentielt 200 linjer

## What Changes

**Phased approach:**

### Phase A: Profile (Investigation)
1. **Tilføj cache hit/miss logging under test suite**
   - Wrap cache calls med counters
   - Kør `devtools::test()` og `devtools::check()`
   - Dokumentér hit rates

2. **Beslutningspunkt:**
   - Hit rate <50%: Gå til Phase B (fjern caching)
   - Hit rate >50%: Gå til Phase C (konsolider)

### Phase B: Remove Caching (if hit rate <50%)
1. **Fjern cache-relateret kode**
   - Slet `.grob_height_cache`, `.panel_height_cache`, `.marquee_style_cache`
   - Fjern TTL, stats, purge logic
   - Behold kun core functionality

2. **Forventet reduktion:** 1,500 linjer → ~100 linjer

### Phase C: Consolidate (if hit rate >50%)
1. **Erstat med `cachem` package**
   ```r
   # Før: 3 custom caches med 1,500 linjer
   .grob_cache <- cachem::cache_mem(max_size = 100 * 1024^2, max_age = 3600)
   .panel_cache <- cachem::cache_mem(max_size = 50 * 1024^2, max_age = 3600)
   .style_cache <- cachem::cache_mem(max_size = 10 * 1024^2, max_age = 3600)
   ```

2. **Forventet reduktion:** 1,500 linjer → ~200 linjer

## Impact

**Affected specs:**
- `cache-architecture` (cache implementation requirements)

**Affected code:**
- `R/utils_label_placement.R` - Major refactoring
- `R/utils_label_helpers.R` - Fjern marquee cache
- `DESCRIPTION` - Tilføj `cachem` til Imports (Phase C only)

**User-visible changes:**
- Ingen - caching er disabled by default
- Performance unchanged for typical usage

**Breaking changes:**
- `configure_grob_cache()`, `configure_panel_cache()` fjernes
- Internal API only - ikke exported

## Alternatives Considered

**Alternative 1: Behold status quo**
**Rejected because:**
- 1,500 linjer til feature der er disabled by default
- Maintenance burden for duplikeret logik
- Over-engineering for intern pakke

**Alternative 2: Konsolider til én custom cache**
```r
# Unified cache med type-dispatching
.unified_cache <- new.env(parent = emptyenv())
cache_get <- function(type, key) { ... }
cache_set <- function(type, key, value) { ... }
```
**Rejected because:**
- Stadig custom implementation
- `cachem` er battle-tested og vedligeholdt
- Hvorfor genopfinde hjulet?

**Alternative 3: Brug memoise package**
```r
cached_measure_grob <- memoise::memoise(measure_grob)
```
**Rejected because:**
- Memoise er function-level, ikke value-level
- Mindre kontrol over cache størrelse/eviction
- `cachem` er mere fleksibel

**Chosen approach: Profile først, derefter beslut**
- Data-driven decision
- Fjern hvis unødvendig (YAGNI)
- Brug `cachem` hvis nødvendig (DRY)

## Related

- GitHub Issue: [#42](https://github.com/johanreventlow/BFHcharts/issues/42)
- Related: Issue #23 (Document caching system) - Should complete first
- Detected by: Refactoring advisor agent, Performance optimizer agent
