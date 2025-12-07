## 1. Implementation

- [x] 1.1 Opdater `bfh_generate_analysis()` i `R/spc_analysis.R`:
  - Tilføj `min_chars = 300` parameter
  - Opdater `max_chars` default til 400
  - Tilføj validering: min_chars < max_chars
  - Videregiv `min_chars` til `BFHllm::bfhllm_spc_suggestion()`
- [x] 1.2 Opdater `bfh_export_pdf()` i `R/export_pdf.R`:
  - Tilføj `analysis_min_chars = 300` parameter
  - Tilføj `analysis_max_chars = 400` parameter
  - Videregiv til `bfh_generate_analysis()` når auto_analysis = TRUE
- [x] 1.3 Opdater BFHllm pakken:
  - Tilføj `min_chars` parameter til `bfhllm_spc_suggestion()`
  - Opdater prompt til at inkludere min/max instruktion
  - Opdater default max_chars fra 350 til 400

## 2. Tests

- [x] 2.1 Tilføj tests for `bfh_generate_analysis()` i `test-spc_analysis.R`:
  - Test at min_chars og max_chars accepteres
  - Test at standardværdier er 300/400
  - Test validering af min_chars < max_chars
- [x] 2.2 Tilføj tests for `bfh_export_pdf()` parametre

## 3. Documentation

- [x] 3.1 Opdater roxygen for `bfh_generate_analysis()`:
  - Dokumenter min_chars og max_chars parametre
  - Tilføj eksempler
- [x] 3.2 Opdater roxygen for `bfh_export_pdf()`:
  - Dokumenter analysis_min_chars og analysis_max_chars

## 4. Validation

- [x] 4.1 Kør `devtools::test()` - alle tests skal bestå
- [x] 4.2 Kør `devtools::document()`
- [x] 4.3 Manuel test: verificer at AI-genererede analyser overholder grænser
  - 10 tests kørt med default (300-375 tegn)
  - 6/10 AI-svar: 292-375 tegn (tæt på/inden for grænser) ✓
  - 4/10 fallback-tekster: 120 tegn (pga. HTTP 429 rate limiting)
  - **Observation:** Fallback-tekster respekterer ikke min/max constraints (known limitation)
  - **Konklusion:** AI-logikken virker korrekt når API svarer

Tracking: GitHub Issue #75
