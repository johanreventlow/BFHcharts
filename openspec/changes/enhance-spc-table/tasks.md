## 1. Implementation

- [x] 1.1 Udvid `extract_spc_stats()` i `R/export_pdf.R`:
  - Oprettet ny `extract_spc_stats_extended()` funktion
  - Beregner `outliers_actual` fra `sum(qic_data$sigma.signal)`
  - Sætter `outliers_expected` til 0 for ikke-run charts
  - Tilføjer `is_run_chart` flag baseret på `config$chart_type == "run"`
- [x] 1.2 Opdater `bfh_export_pdf()` i `R/export_pdf.R`:
  - Kalder `extract_spc_stats_extended()` med hele result objektet
- [x] 1.3 Opdater `build_typst_content()` i `R/export_pdf.R`:
  - Tilføjer `is_run_chart` parameter til Typst output
- [x] 1.4 Opdater Typst template `bfh-template.typ`:
  - Tilføjer `is_run_chart` parameter
  - Skjuler "OBS. UDEN FOR KONTROLGRÆNSE"-række når `is_run_chart == true`
  - Tilføjer betinget baggrundsfarve på data-celler ved signaler

## 2. Tests

- [x] 2.1 Tilføj tests for `extract_spc_stats_extended()` i `test-export_pdf.R`:
  - Test outliers_actual beregning
  - Test is_run_chart flag for run charts
  - Test alle felter returneres
- [x] 2.2 Tilføj tests for Typst output i `test-export_pdf.R`:
  - Verificer is_run_chart parameter i genereret Typst
  - Test at outliers ikke inkluderes for run charts

## 3. Documentation

- [x] 3.1 Dokumentation tilføjet i koden (roxygen)

## 4. Validation

- [x] 4.1 Kør `devtools::test()` - alle tests bestået (210 PASS)
- [x] 4.2 Kør `devtools::document()`
- [x] 4.3 Verificer Typst output for run chart:
  - `is_run_chart: true` genereres korrekt
  - Ingen `outliers_expected`/`outliers_actual` parametre (forbliver NULL)
  - Typst template skjuler "OBS. UDEN FOR KONTROLGRÆNSE"-rækken
- [x] 4.4 Verificer Typst output for i-chart med outliers:
  - `is_run_chart: false` genereres korrekt
  - `outliers_expected: 0` og `outliers_actual: 2` genereres
  - Signal-cells highlighter værdier når regler er overtrådt

Tracking: GitHub Issue #74
