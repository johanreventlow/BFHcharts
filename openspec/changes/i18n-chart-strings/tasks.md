# Tasks: i18n-chart-strings

## 1. String extraction

- [ ] 1.1 Audit `R/*.R`: list alle user-facing danske strings (stringr::str_detect for æøå og danske ord)
- [ ] 1.2 Kategoriser strings: analyse-tekster, labels, error-messages, detail-formater
- [ ] 1.3 Opret nøgle-schema (fx `analysis.baseline.stable`, `labels.ucl`, `errors.invalid_path`)

## 2. I18n infrastructure

- [ ] 2.1 Opret `inst/i18n/da.yaml` med alle danske strings
- [ ] 2.2 Opret `inst/i18n/en.yaml` med initial engelsk oversættelse
- [ ] 2.3 Opret `R/utils_i18n.R` med `i18n_lookup(key, language)` + `load_translations()`
- [ ] 2.4 Cache loaded YAML i package env (følg cache-keying-and-reset)
- [ ] 2.5 Fallback til "da" hvis key mangler i target

## 3. Integration

- [ ] 3.1 Tilføj `language = "da"` til `bfh_generate_analysis()`
- [ ] 3.2 Tilføj `language = "da"` til `bfh_generate_details()`
- [ ] 3.3 Tilføj `language = "da"` til `bfh_qic()` (labels/titler)
- [ ] 3.4 Erstat inline strings med `i18n_lookup()` kald
- [ ] 3.5 Tilføj validation: `language %in% c("da", "en")`

## 4. Testing

- [ ] 4.1 Test: alle keys i da.yaml findes også i en.yaml (coverage)
- [ ] 4.2 Test: `language = "en"` returnerer engelsk tekst
- [ ] 4.3 Test: ukendt `language` giver informativ fejl
- [ ] 4.4 Test: fallback til "da" ved missing key

## 5. Documentation

- [ ] 5.1 Vignette eller README-section: supported languages
- [ ] 5.2 Guide til at tilføje nyt sprog (TRANSLATORS.md)
- [ ] 5.3 NEWS.md: i18n support (backward-compatible)
