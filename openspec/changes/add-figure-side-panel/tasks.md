# Tasks

## 1. Template
- [x] 1.1 `figure_panel` param + figur-kolonne (kpis, legend med grupper, datadefinition)
- [x] 1.2 `definition-block()` delt mellem SPC-kolonne og figur-kolonne
- [x] 1.3 Drop analyse-rækken på figursider uden analyse (6,6 mm top-inset)
- [x] 1.4 SPC-side og fuld-bredde-side pixel-identiske før/efter (100 dpi, med analyse)
- [x] 1.5 Smoke-template accepterer `figure_panel`

## 2. R
- [x] 2.1 `bfh_figure_panel()` + print-metode + validering
- [x] 2.2 `figure_panel_to_typst()` (arrays med afsluttende komma, escaping)
- [x] 2.3 `panel`-argument i `bfh_export_figure_pdf()` og `bfh_stage_figure_page()`
- [x] 2.4 `figure_chart_dims()`: bredde 191,4/264 mm, højde 130,8/109 mm
- [x] 2.5 Batch-indlæsning validerer `figure_panel`

## 3. Test og dokumentation
- [x] 3.1 Tests i `test-export-figure.R`; `test-export_pdf.R` følger ny rækkeregel
- [x] 3.2 roxygen/NAMESPACE, NEWS
- [ ] 3.3 Visuel godkendelse af brugeren (render med Quarto på Windows)
