# Tasks: i18n-chart-strings

## 1. String extraction

- [x] 1.1 Audit `R/*.R`: list alle user-facing danske strings (stringr::str_detect for æøå og danske ord)
- [x] 1.2 Kategoriser strings: analyse-tekster, labels, error-messages, detail-formater
- [x] 1.3 Opret nøgle-schema (fx `analysis.baseline.stable`, `labels.ucl`, `errors.invalid_path`)

## 2. I18n infrastructure

- [x] 2.1 Opret `inst/i18n/da.yaml` med alle danske strings
- [x] 2.2 Opret `inst/i18n/en.yaml` med initial engelsk oversættelse
- [x] 2.3 Opret `R/utils_i18n.R` med `i18n_lookup(key, language)` + `load_translations()`
- [x] 2.4 Cache loaded YAML i package env (`.i18n_cache[[language]]`, reset i `bfh_reset_caches()`)
- [x] 2.5 Fallback til "da" hvis key mangler i target

## 3. Integration

- [x] 3.1 Tilføj `language = "da"` til `bfh_generate_analysis()`
- [x] 3.2 Tilføj `language = "da"` til `bfh_generate_details()`
- [x] 3.3 Tilføj `language = "da"` til `bfh_qic()` (labels/titler)
- [x] 3.4 Erstat inline strings med `i18n_lookup()` kald
- [x] 3.5 Tilføj validation: `language %in% c("da", "en")`

## 4. Testing

- [x] 4.1 Test: alle keys i da.yaml findes også i en.yaml (coverage)
- [x] 4.2 Test: `language = "en"` returnerer engelsk tekst
- [x] 4.3 Test: ukendt `language` giver informativ fejl
- [x] 4.4 Test: fallback til "da" ved missing key

## 5. Documentation

- [ ] 5.1 Vignette eller README-section: supported languages
- [ ] 5.2 Guide til at tilføje nyt sprog (TRANSLATORS.md)
- [x] 5.3 NEWS.md: i18n support (backward-compatible)
