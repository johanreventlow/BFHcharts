# Tasks: cache-keying-and-reset

## 1. Audit

- [x] 1.1 List alle package-level cache environments (grep for `new.env`, `.cache`)
- [x] 1.2 Dokumentér hver caches nuværende key-design + alle inputs der påvirker værdi
- [x] 1.3 Identificér inputs der IKKE er i nøglen (= stale-risiko)

**Findings:**
- `.font_cache` i `utils_add_right_labels_marquee.R`: nøgle var `dev_type` — manglede `fontfamily` → stale bug
- `.marquee_style_cache` i `utils_label_helpers.R`: nøgle `lineheight` — korrekt, ingen ændring
- `.quarto_cache` i `utils_quarto.R`: nøgle `min_version` — acceptabelt, ingen ændring
- `.spc_text_cache` i `spc_analysis.R`: enkelt felt `texts` — stabilt YAML, ingen ændring

## 2. Implementation

- [x] 2.1 Refaktorér font-cache: key = `paste0(dev_type, "_", family)` (inkl. fontfamily)
- [x] 2.2 Refaktorér style/text-caches med komplette keys — marquee og text allerede korrekte
- [x] 2.3 Opret `R/cache_reset.R` med `bfh_reset_caches()` helper (`@keywords internal`)
- [x] 2.4 Opret `tests/testthat/helper-cache.R` der kalder reset før test-session

## 3. Testing

- [x] 3.1 Test: ændret fontfamily → separate cache-entries (ikke shared)
- [x] 3.2 Test: `bfh_reset_caches()` tømmer alle caches
- [x] 3.3 Test: gentaget kald med samme args → cache hit (1 entry)
- [ ] 3.4 Benchmark: hit-rate før/efter refaktor — ikke implementeret (lav prioritet)

## 4. Documentation

- [x] 4.1 Roxygen for `bfh_reset_caches()` i `R/cache_reset.R`
- [x] 4.2 Cache-key-design dokumenteret i `R/utils_add_right_labels_marquee.R` header
- [x] 4.3 NEWS.md: cache reproducibility fix under `## Interne ændringer`
