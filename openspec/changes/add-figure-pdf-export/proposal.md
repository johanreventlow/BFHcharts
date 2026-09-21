# Proposal: add-figure-pdf-export

## Why

BFHcharts' PDF-eksport er bygget til seriediagrammer: den blaa header med
hospital/enhed/titel, analyse-raekken, og et layout hvor grafen deler
raekke 3 med en fast 72,6 mm hoejrekolonne til SPC-statistik (serielaengde,
antal kryds, outliers, caveats, datadefinition).

Brugeren har nu et behov for at bruge **samme brandede skabelon til grafer
der ikke er seriediagrammer** — fx fordelings-, soejle- eller
tidsserie-plots uden Anhoej-analyse — i samme rapportflow som SPC-siderne
(baade enkelt-PDF og samlerapporter).

Det kan pakken ikke i dag, af to grunde:

1. **Skabelonen har ingen fuld-bredde-tilstand.** Hoejrekolonnen rendres
   ubetinget (overskriften "STATISTISK PROCESKONTROL (SPC)" har ingen
   `#if`), og grafkolonnen er defineret som `auto` ved siden af de 72,6 mm.
   Uden statistik faar man en tom kolonne med overskrift og en for smal graf.
2. **R-siden afviser alt der ikke er et `bfh_qic_result`.**
   `bfh_export_pdf()` og `bfh_stage_pdf_page()` har haard klasse-check, og
   pipelinen forudsaetter `x$config`, `x$summary` og SPC-label-genberegning.

Dertil en detalje der let overses: grafen skal **tegnes i et andet format**.
`ggsave()` skriver fysiske dimensioner i SVG'en, og Typst placerer den i
naturlig stoerrelse. En SVG paa 191,4 mm i en 264 mm bred kolonne efterlader
72,6 mm tomrum til hoejre. Fuld bredde kraever derfor en ny
eksport-dimension, ikke blot en skabelonaendring.

## What Changes

- **Skabelon:** `bfh-diagram` faar en boolean-parameter `spc_panel`
  (default `true`). Ved `false` rendres raekke 3 som een kolonne (details-
  linje + graf + footer) uden hoejrekolonne. Blaa header, titel-auto-
  skalering og analyse-raekken er uaendrede. Datadefinition rendres ikke i
  fuld-bredde-tilstand (bevidst fravalg i v1). Default-stien er
  byte-identisk med i dag.
- **Ny eksport-dimension:** `PDF_IMAGE_WIDTH_FULL_MM <- 264` (297 − 26,4 −
  6,6). Hoejde uaendret 109 mm.
- **Ny eksporteret funktion `bfh_export_figure_pdf(plot, output, metadata,
  ...)`:** tager et `ggplot`-objekt, genbruger hele PDF-pipelinen (workspace,
  template-staging, `inject_assets`, `font_path`, `batch_session`,
  Typst-compile) og springer alt SPC-specifikt over. Plottets egen
  titel/undertitel strippes som i SPC-stien (titlen gaar i den blaa top).
- **Ny eksporteret funktion `bfh_stage_figure_page(plot, cache_dir, id,
  ...)`:** batch-modstykket til `bfh_stage_pdf_page()`. Bundles kan blandes
  frit med SPC-bundles i `bfh_export_batch_pdf()` uden aendring af
  compile-funktionen.
- **Flag-transport:** `spc_panel` baeres som `metadata$spc_panel`
  (whitelistes i `bfh_merge_metadata()`), saa det flyder gennem den
  eksisterende parameter-builder og bundle-formatet uden signaturaendringer
  paa eksisterede funktioner. Parametren emitteres kun naar `FALSE`.
- **Intern refaktor:** den del af `compose_typst_document()` /
  `bfh_export_pdf()` der ikke afhaenger af `bfh_qic_result` udtraekkes til
  helpers, saa SPC- og figur-stierne deler een implementation.

## Capabilities

### New Capabilities

<!-- Ingen ny capability — aendringen udvider pdf-export og
     batch-pdf-export. -->

### Modified Capabilities

- `pdf-export`: skabelonen faar fuld-bredde-tilstand (`spc_panel`); ny
  eksporteret figur-eksport der deler pipeline med `bfh_export_pdf()`.
- `batch-pdf-export`: ny staging-funktion for figur-sider; bundle-format
  udvides bagudkompatibelt (metadata-noegle, uaendret `format_version`);
  blandede dokumenter (SPC + figur) er tilladt.
- `public-api`: to nye exports foelger de eksisterende krav til navngivning
  (`bfh_`-praefiks, snake_case), roxygen-dokumentation og validator-
  dokumentation. Ingen delta-spec — kravene er generiske og gaelder
  automatisk.

## Impact

**Kode (BFHcharts):**

- `inst/templates/typst/bfh-template/bfh-template.typ`: `spc_panel`-param +
  betinget raekke-3-layout.
- `tests/smoke/test-template.typ`: samme parameter (Typst afviser ukendte
  named-params; CI's `pdf-smoke` bruger denne).
- `R/globals.R`: `PDF_IMAGE_WIDTH_FULL_MM`.
- `R/utils_metadata.R`: `spc_panel` i `bfh_merge_metadata()`-whitelist.
- `R/utils_typst.R`: `build_typst_page_params()` emitterer `spc_panel: false`.
- `R/export_pdf.R` (eller ny `R/export_figure.R`): `bfh_export_figure_pdf()`.
- `R/export_batch.R`: `bfh_stage_figure_page()`.
- `R/utils_export_helpers.R`: udtraekkede helpers (`export_chart_svg()` faar
  dimensions-parametre; compose-trin uden `x`-afhaengighed).
- `NAMESPACE`/`man/`: regenereres via `devtools::document()`.

**Public API:**

- To nye exports; **ingen** aendring af eksisterende signaturer eller
  defaults. MINOR version bump ved naeste release.

**biSPCharts (downstream):**

- Ingen kodeaendring noedvendig. Ny funktionalitet er opt-in. Maintainer
  orienteres via NEWS.

**Sikkerhed:**

- Samme `validate_export_path()`, `restrict_template`, `inject_assets`-
  validering og temp-workspace-beskyttelse som `bfh_export_pdf()`. Ingen ny
  angrebsflade: `plot` er et R-objekt, ikke en sti eller tekst der naar
  Typst.

**Visuel regression:**

- Ingen vdiffr-aendringer: ggplot-rendering af SPC-charts roeres ikke.
- Ny PDF-tilstand godkendes visuelt af brugeren paa lokalt renderede PDF'er
  (agenten har ikke R/Quarto i sit miljoe).

**Statistisk validering:**

- Ikke paakraevet — ingen beregninger beroeres.
