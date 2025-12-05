## 1. Implementation

- [x] 1.1 Opret helper-funktion `prepare_plot_for_export()` i `R/export_pdf.R` (eller ny utils-fil)
- [x] 1.2 Implementer logik til at detektere om axis titles er blanke/NULL
- [x] 1.3 Implementer margin-parameter (0mm for PDF, 5mm for PNG)
- [x] 1.4 Integrer helper i `bfh_export_pdf()` flow
- [x] 1.5 Integrer helper i `bfh_export_png()` flow
- [x] 1.6 Skriv unit tests for helper-funktionen
- [x] 1.7 Skriv integration tests for begge eksportfunktioner

## 2. Documentation

- [x] 2.1 Opdater roxygen dokumentation for `bfh_export_pdf()`
- [x] 2.2 Opdater roxygen dokumentation for `bfh_export_png()`
- [x] 2.3 Tilføj roxygen dokumentation for `prepare_plot_for_export()`

## 3. Validation

- [x] 3.1 Kør `devtools::test()` - alle tests skal bestå
- [x] 3.2 Kør `devtools::check()` - ingen errors/warnings (font-relaterede fejl er pre-existing)
- [x] 3.3 Manuel test: generer PDF med/uden axis titles
- [x] 3.4 Manuel test: generer PNG med/uden axis titles
- [x] 3.5 Verificer at margins er korrekte i begge output-formater

Tracking: GitHub Issue #71
