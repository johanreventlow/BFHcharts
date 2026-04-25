# cache-keying-and-reset

## Why

Font/style/Quarto/text-caches i `R/utils_add_right_labels_marquee.R:10` er
package-level environments. Font-cache er device-orienteret og kan give
stale resultater ved ændret `fontfamily`. Quarto-cache kan holde en
path der ikke længere gælder efter env-ændring.

Konsekvens:
- Svær reproducerbarhed i Shiny / parallel rendering / tests
- Tests der ændrer fonts kan se stale cache
- Ingen standardiseret reset-mekanisme til testmiljø

## What Changes

- Cache-nøgler SKAL inkludere alle relevante inputs (fontfamily, size, device, text-kontekst)
- Tilføj `bfh_reset_caches()` helper (internal, `@keywords internal`)
- Kald `bfh_reset_caches()` automatisk i `helper-setup.R` før hver test (teardown)
- Dokumentér cache-nøgle-design i roxygen + ADR-style note
- Audit: quarto-cache, font-cache, style-cache, text-cache

## Impact

**Affected specs:**
- `caching-system`

**Affected code:**
- `R/utils_add_right_labels_marquee.R` (cache key refactor)
- `R/utils_quarto.R` (quarto cache key)
- `R/cache_reset.R` (ny helper)
- `tests/testthat/helper-cache.R` (ny)

**User-visible changes:**
- Ingen public API-ændringer
- Potentielt hurtigere/langsommere caches afhængigt af key-cardinality (bench før-efter)

## Related

- Codex review (skjult global cache/state i rendering)
