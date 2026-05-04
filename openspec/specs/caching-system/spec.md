# caching-system Specification

## Purpose

BFHcharts maintains four package-private cache environments to avoid
recomputing expensive operations across plotting calls within a single
R session: font lookups, marquee styles, Quarto-CLI detection, and
i18n translation tables. This capability governs the cache-key contract
(keys MUST include every input that affects the cached value) and the
canonical reset helper (`bfh_reset_caches()`) used by the test
infrastructure for deterministic state.

The legacy public `configure_grob_cache()` / `clear_grob_cache()`
helpers were removed in v0.5.0; no exported cache-configuration API
exists today. Cache state is internal-only and not configurable via
the public surface.

## Requirements

### Requirement: Caching documentation SHALL describe current cache topology

The package SHALL document the four active package-private caches
(`font`, `marquee_style`, `quarto`, `i18n`) and the canonical reset
helper in a single discoverable file (`docs/CACHING_SYSTEM.md` or
equivalent reference).

**Rationale:**
- New contributors need a one-page overview of caching strategy without
  reading every `R/cache_*.R` file.
- Current implementation: `.font_cache`, `.marquee_style_cache`,
  `.quarto_cache`, `.i18n_cache` (per `R/cache_reset.R::bfh_reset_caches()`).
- The legacy grob-cache was removed in v0.5.0; documentation SHALL
  reflect the simplified topology rather than retaining stale
  configuration references.

#### Scenario: Documentation lists active caches

- **GIVEN** the caching documentation file (currently
  `docs/CACHING_SYSTEM.md`)
- **WHEN** a contributor reads it
- **THEN** the file SHALL list all four package-private caches by name
  and purpose (`font`, `marquee_style`, `quarto`, `i18n`)
- **AND** the file SHALL NOT reference removed helpers
  (`configure_grob_cache()`, `clear_grob_cache()`)
- **AND** the file SHALL document `bfh_reset_caches()` as the canonical
  reset helper (internal API only)

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
