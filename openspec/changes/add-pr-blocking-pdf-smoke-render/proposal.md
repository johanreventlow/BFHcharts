# Proposal: add-pr-blocking-pdf-smoke-render

**Status:** Implemented
**Dato:** 2026-04-29

## Problem

`render-tests.yaml` kører kun ugentligt (cron) og ved workflow_dispatch.
En catastrophic Quarto/Typst-regression i `bfh_export_pdf()` kan dermed
slippe igennem til `main` i op til 7 dage uden CI-detektion.

Primær årsag til at render-tests er adskilt fra R-CMD-check: Typst-templaten
bruger Mari-font (proprietær), og Typst returnerer exit 1 på ukendte fonts
med `--ignore-system-fonts`. Det blokerer Quarto-rendering på public runners.

## Løsning

Tilføj en PR-blocking PDF smoke-render workflow (`.github/workflows/pdf-smoke.yaml`):

1. Installerer åbne fallback-fonts (DejaVu/Liberation/Noto/Roboto)
2. Installerer Quarto pre-release (Typst >= 0.13 for `--ignore-system-fonts`)
3. Kører `tests/smoke/render_smoke.R` med 3 repræsentative `bfh_export_pdf()`-kald
4. Asserter: fil eksisterer, `file.size() > 0`, `pdftools::pdf_info()$pages >= 1`

Smoke-render tester pipeline-integritet (Quarto + Typst + R), ikke visuel
korrekthed (som kræver Mari og håndteres af vdiffr).

## Relaterede ændringer

- Sync `tests/testthat/setup.R` font-alias-sæt med `R/zzz.R` (tilføj Roboto)
- Tilføj `skip_if_no_pdf_render_deps()` til `helper-skips.R`
- Konverter `test-visual-regression.R` fra fil-scope `skip_if_fonts_unavailable()`
  til per-test `skip_if_no_mari_font()`
- Re-baseline 9 vdiffr-snapshots (font-metric drift fra Roboto-alias i v0.10.5)
- Bump version til 0.10.6
