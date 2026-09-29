# Change: Sidepanel og fuld højde på figursider

## Why

udredningsret-PDF'erne (dekomponering af henvisninger, ikke-udredte, flow
m.fl.) skal over på BFH-skabelonen og ind i BFHddl's samlerapporter. De
gamle sider har tegnforklaring, store nøgletal og datadefinition i et felt
til højre for figuren. Figur-sporet fra `add-figure-pdf-export` kan kun vise
figuren i fuld bredde og dropper datadefinitionen.

Brugeren påpegede desuden (2026-09-29), at analyse-rækken står tom på
figursider uden analysetekst. Den plads skal gå til figuren.

## What Changes

- Templatet får parameteren `figure_panel` (dictionary, default `none`).
  - Med `spc_panel: false` og et panel får chart-rækken en højre kolonne på
    72,6 mm, samme bredde som SPC-kolonnen.
  - Kolonnen har nøgletal (`kpis`), tegnforklaring (`legend`, med
    gruppeoverskrifter) og datadefinition.
  - Datadefinitionens kaskade-rendering er hævet ud i `definition-block()`
    og deles med SPC-kolonnen.
- Figursider (`spc_panel: false`) uden `analysis` dropper analyse-rækken.
  Chart-rækkens top-inset bliver 6,6 mm, og figuren bliver 130,8 mm høj i
  stedet for 109 mm (`PDF_IMAGE_HEIGHT_FIGURE_MM`).
  - SPC-sider er uændrede. De er verificeret pixel-identiske ved 100 dpi.
- R:
  - Ny eksporteret `bfh_figure_panel(legend, kpis, legend_title, kpi_title, definition_height_mm)` med validering.
  - `bfh_export_figure_pdf()` og `bfh_stage_figure_page()` får et nyt sidste argument, `panel = NULL`.
  - Med panel er figuren 191,4 mm bred, og datadefinitionen vises uden advarsel.
  - Panelet sættes på metadata efter `bfh_merge_metadata()`. Et `figure_panel` i kalderens metadata når aldrig templatet.
  - Batch-bundles bærer panelet. Indlæsning afviser et `figure_panel`, der ikke er et `bfh_figure_panel`.
- Smoke-templatet accepterer `figure_panel`.

## Impact

- **Affected specs:** `pdf-export` (ændrer "full-width figure layout", tilføjer "figure side panel")
- **Affected code:**
  - `inst/templates/typst/bfh-template/bfh-template.typ`
  - `R/figure_panel.R` (ny)
  - `R/export_figure.R`, `R/export_batch.R`, `R/utils_typst.R`, `R/globals.R`
  - `tests/smoke/test-template.typ`
- **Adfærdsændring:** figursider uden analyse får en højere figur (130,8 mm).
  Ældre figur-bundles (109 mm SVG) kompileres stadig, men får tom plads under
  figuren, til de stages igen.
- **Breaking:** Nej. Nye argumenter står sidst med default `NULL`.
- **Downstream:** BFHddl's figur-gren (udredningsret-figurer).
