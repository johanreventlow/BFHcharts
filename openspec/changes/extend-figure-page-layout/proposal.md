# Change: Bundpanel, streg-nøgler og SPC-dato-akse på figursider

## Why

Brugerens gennemgang af de første rigtige udredningsret-figursider
(2026-09-30):

- x-aksen skal se ud som på seriediagrammerne: ugenumre over aksen og
  måned/år under. Figurerne tegner i dag deres egne ugeetiketter.
- Ikke-udredte, flow og prognose skal have grafen i fuld bredde med
  nøgletal, tegnforklaring og datadefinition i en række nedenunder, som i
  de gamle sider.
- Prognosens tegnforklaring skal vise linjetypen (tynd/tyk streg), ikke kun
  farven.

## What Changes

- Ny eksporteret `bfh_apply_date_axis(plot, x, language)`. Den genbruger
  SPC-aksens `apply_temporal_x_axis()` (samme brud, måneder og ugenumre).
- `bfh_figure_panel()`:
  - `placement = c("side", "bottom")`.
  - `legend$key` ("box"/"line") og `legend$linewidth`.
- Templatet:
  - Med `figure_panel.placement: "bottom"` er grafen 264 mm bred.
  - Under grafen kommer en række på 31,5 mm (+ 3,3 mm afstand) med nøgletal
    side om side, tegnforklaring og datadefinition.
  - Tegnforklaringen kan tegne en kort streg i en given tykkelse.
  - Sidepanel og SPC-sider er uændrede (verificeret pixel-identiske).
- `figure_chart_dims()`: grafen bliver `PDF_FIGURE_BOTTOM_PANEL_MM` (34,8 mm)
  lavere med bundpanel.

## Impact

- **Affected specs:** `pdf-export` (tilføjer "figure bottom panel" og "figure date axis")
- **Affected code:**
  - `R/figure_axis.R` (ny)
  - `R/figure_panel.R`
  - `R/utils_typst.R`
  - `R/globals.R`
  - `inst/templates/typst/bfh-template/bfh-template.typ`
