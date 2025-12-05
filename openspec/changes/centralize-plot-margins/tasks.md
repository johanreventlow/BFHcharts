## 1. Implementation

- [x] 1.1 Opdater `apply_spc_theme()` i `R/themes.R`:
  - Tilføj default 5mm margins
  - Tilføj blank axis title removal logic
  - Bevar plot_margin override mulighed
- [x] 1.2 Simplificer `prepare_plot_for_export()` i `R/export_pdf.R`:
  - Fjern axis title logic (nu i themes.R)
  - Behold kun margin-håndtering
- [x] 1.3 Opdater `bfh_export_png()` i `R/export_png.R`:
  - Fjern prepare_plot_for_export() kald
- [x] 1.4 Behold `bfh_export_pdf()` margin override (0mm)

## 2. Tests

- [x] 2.1 Opdater tests for `prepare_plot_for_export()` i `test-export_pdf.R`
- [x] 2.2 Tilføj tests for axis title removal i `apply_spc_theme()`

## 3. Documentation

- [x] 3.1 Opdater roxygen for `apply_spc_theme()`
- [x] 3.2 Opdater roxygen for `bfh_export_png()`

## 4. Validation

- [x] 4.1 Kør `devtools::test()` - alle tests skal bestå
- [x] 4.2 Kør `devtools::document()`
- [x] 4.3 Manuel test: verificer bfh_qic() output har 5mm margins og ingen blanke axis titles

Tracking: GitHub Issue #72
