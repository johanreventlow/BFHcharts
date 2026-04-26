# Tasks: cache-keying-and-reset

## 1. Audit

- [x] 1.1 List alle package-level cache environments (grep for `new.env`, `.cache`)
- [x] 1.2 Dokumentér hver caches nuværende key-design + alle inputs der påvirker værdi
- [x] 1.3 Identificér inputs der IKKE er i nøglen (= stale-risiko)

## 2. Implementation

- [x] 2.1 Refaktorér font-cache: key = hash(fontfamily, size, device_type)
- [x] 2.2 Refaktorér style/text-caches med komplette keys
- [x] 2.3 Opret `R/cache_reset.R` med `bfh_reset_caches()` helper (`@keywords internal`)
- [x] 2.4 Opret `tests/testthat/helper-cache.R` der kalder reset før/efter tests

## 3. Testing

- [x] 3.1 Test: ændret fontfamily → cache miss (ny beregning)
- [x] 3.2 Test: `bfh_reset_caches()` tømmer alle caches
- [x] 3.3 Test: parallel/sequential render giver identiske resultater
- [ ] 3.4 Benchmark: hit-rate før/efter refaktor
      (deferred — one-time pre/post-refactor exercise, not an ongoing test;
      refactor landed in commit b17de64)

## 4. Documentation

- [x] 4.1 Roxygen for `bfh_reset_caches()`
- [x] 4.2 Cache-key-design dokumenteret i `R/utils_add_right_labels_marquee.R` header
- [x] 4.3 NEWS.md: cache reproducibility fix
