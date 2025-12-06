## 1. Implementation

- [ ] 1.1 Opdater `bfh_generate_analysis()` i `R/spc_analysis.R`:
  - Tilføj `min_chars = 300` parameter
  - Opdater `max_chars` default til 400
  - Tilføj validering: min_chars < max_chars
  - Videregiv `min_chars` til `BFHllm::bfhllm_spc_suggestion()`
- [ ] 1.2 Opdater `bfh_export_pdf()` i `R/export_pdf.R`:
  - Tilføj `analysis_min_chars = 300` parameter
  - Tilføj `analysis_max_chars = 400` parameter
  - Videregiv til `bfh_generate_analysis()` når auto_analysis = TRUE
- [ ] 1.3 Verificer BFHllm understøtter `min_chars`:
  - Tjek `BFHllm::bfhllm_spc_suggestion()` signatur
  - Opdater BFHllm hvis nødvendigt

## 2. Tests

- [ ] 2.1 Tilføj tests for `bfh_generate_analysis()` i `test-spc_analysis.R`:
  - Test at min_chars og max_chars accepteres
  - Test at standardværdier er 300/400
  - Test validering af min_chars < max_chars
- [ ] 2.2 Tilføj tests for `bfh_export_pdf()` parametre

## 3. Documentation

- [ ] 3.1 Opdater roxygen for `bfh_generate_analysis()`:
  - Dokumenter min_chars og max_chars parametre
  - Tilføj eksempler
- [ ] 3.2 Opdater roxygen for `bfh_export_pdf()`:
  - Dokumenter analysis_min_chars og analysis_max_chars

## 4. Validation

- [ ] 4.1 Kør `devtools::test()` - alle tests skal bestå
- [ ] 4.2 Kør `devtools::document()`
- [ ] 4.3 Manuel test: verificer at AI-genererede analyser overholder grænser

Tracking: GitHub Issue #75
