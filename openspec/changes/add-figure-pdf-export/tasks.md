# Tasks: add-figure-pdf-export

## 1. Forudsaetninger

- [ ] 1.1 Feature-branch fra `origin/develop`: `feat/figure-pdf-export`
- [ ] 1.2 Ny konstant i `R/globals.R`: `PDF_IMAGE_WIDTH_FULL_MM <- 264` med
      kommentar der udleder tallet (297 − 26,4 − 6,6) parallelt med de
      eksisterende konstanter
- [ ] 1.3 Regressionstest: `bfh_merge_metadata()` er uaendret —
      `names()` paa resultatet er de samme 10 felter, og en bruger-leveret
      `spc_panel` filtreres fra (flaget saettes kun af figur-stierne efter
      merge, jf. design D3)

## 2. Skabelon (kan verificeres i CI uafhaengigt af R-koden)

- [ ] 2.1 `bfh-template.typ`: tilfoej `spc_panel: true` til signaturen +
      parameter-dokumentation i fil-headeren
- [ ] 2.2 `bfh-template.typ`: raekke 3 rendres betinget — `spc_panel == true`
      → eksisterende 2-kolonne-grid uaendret; `false` → een `grid.cell`
      med venstrekolonnens inset (`left: 26.4mm, top: 2mm, right: 6.6mm`)
      indeholdende details-linje, graf og footer-grid. Hoejrekolonnens
      indhold (SPC-overskrift, tabel, caveat, datadefinition) udelades
- [ ] 2.3 `tests/smoke/test-template.typ`: tilfoej `spc_panel: true` og skip
      SPC-summary-blokken naar `false`
- [ ] 2.4 Verificér at default-stien er byte-identisk: diff af det
      genererede `.typ` for et eksisterende test-fixture foer/efter (ingen
      `spc_panel`-param emitteres ved `TRUE`)

## 3. Parameter-builder

- [ ] 3.1 Test: `build_typst_page_params()` emitterer `spc_panel: false` naar
      `metadata$spc_panel` er `FALSE`; emitterer **intet** ved `TRUE` og
      `NULL` (regression: eksisterende param-output uaendret)
- [ ] 3.2 Implementér i `build_typst_page_params()` (`R/utils_typst.R`)

## 4. Refaktor af delt pipeline (egen commit, groen suite foer trin 5)

- [ ] 4.1 `export_chart_svg(plot_for_export, chart_svg, dpi, width_mm =
      PDF_IMAGE_WIDTH_MM, height_mm = PDF_IMAGE_HEIGHT_MM)` — defaults
      bevarer nuvaerende adfaerd; test at eksisterende mock-baserede
      batch-tests (`local_mocked_bindings(export_chart_svg = ...)`) stadig
      passerer
- [ ] 4.2 Udtraek `compose_typst_from_parts(metadata_full, spc_stats,
      chart_svg, typst_file, template, template_path, batch_session,
      font_path, inject_assets)` fra `compose_typst_document()`; sidstnaevnte
      bliver wrapper der udleder titel/sprog/caveat fra `x`. Signatur og
      returvaerdi (effektiv `font_path`) uaendret
- [ ] 4.3 Udtraek de `x`-uafhaengige tjek fra `validate_bfh_export_pdf_inputs()`
      til `validate_export_common_inputs(output, metadata, dpi, font_path,
      inject_assets, batch_session, template_path)`; wrapper bevarer
      klasse-tjek + fejltekst
- [ ] 4.4 Fuld testsuite groen paa refaktoren alene (`devtools::test()` —
      koeres af brugeren lokalt eller verificeres via CI paa branchen)

## 5. `bfh_export_figure_pdf()` (TDD)

- [ ] 5.1 Tests (uden Quarto): afviser ikke-`ggplot` med klassificeret fejl
      der naevner `plot`; afviser `patchwork`-objekt (D10;
      `skip_if_not_installed("patchwork")`, eller konstruér klassen manuelt
      med `structure()`); afviser manglende/tom `metadata$title`; afviser
      `template_path` uden `restrict_template = FALSE` (samme tekst som
      `bfh_export_pdf()`); output-sti valideres via `validate_export_path()`
- [ ] 5.2 Tests (uden Quarto, mock `bfh_compile_typst` + fang `.typ`):
      genereret dokument indeholder `spc_panel: false`, ingen
      `runs_*`/`crossings_*`/`outliers_*`/`is_run_chart`-params, titel fra
      `metadata$title`, `analysis`/`details`/`footer_content` sendes igennem;
      SVG'en er renderet i 264 × 109 mm (laes `width`/`height` fra SVG-root)
- [ ] 5.3 Tests: plottets `title`/`subtitle` er strippet og margins er 0 mm
      (inspicér `plot_for_export`, ikke SVG); blank aksetitel (`labs(x =
      "")`) fjernes; aksetitler udledt af `aes()` uden `labs()` **bevares**
      (regression mod `plot$labels`-faelden i ggplot2 >= 4.0, jf. D6).
      Afklar her om `ggplot2::get_labs()` findes i mindste understoettede
      ggplot2-version; ellers fallback via `ggplot_build()`
- [ ] 5.8 Test: ikke-tom `metadata$data_definition` giver klassificeret
      advarsel (`bfhcharts_warning`) og eksporten gennemfoeres; ingen
      advarsel naar feltet er `NULL`/tomt. Samme test for
      `bfh_stage_figure_page()`
- [ ] 5.4 Test: `batch_session` genbruges (template-dir kopieres ikke igen)
      — spejl af eksisterende session-test
- [ ] 5.5 Implementér `bfh_export_figure_pdf()` i ny fil `R/export_figure.R`:
      validering → `prepare_figure_plot()` → `export_chart_svg(..., width_mm
      = PDF_IMAGE_WIDTH_FULL_MM)` → `compose_typst_from_parts()` med
      `bfh_merge_metadata(metadata, metadata$title)`, derefter
      `metadata_full$spc_panel <- FALSE` (efter merge, jf. D3),
      + `empty_spc_stats()` → `bfh_compile_typst()`. Samme temp-workspace-
      og on.exit-oprydning som `bfh_export_pdf()`
- [ ] 5.7 Render-gatet test i `test-production-template-renders.R`
      (`skip_if_not_render_test()`): `bfh_export_figure_pdf()` mod
      produktionsskabelonen giver en gyldig 1-sides PDF. Koeres af
      `pdf-smoke` og `render-tests` i CI og fanger Typst-fejl i
      `spc_panel == false`-grenen, som mock-baserede tests ikke ser.
      Tilsvarende render-gatet blandet batch (SPC + figur) i
      `test-export-batch-render.R` → 2 sider
- [ ] 5.6 Roxygen: `@family export-functions`, eksempel med `ggplot2`,
      dokumentér at datadefinition ikke rendres (og udloeser advarsel), at
      titlen strippes, at `metadata$title` er paakraevet, at patchwork
      afvises, og at kalderen ejer tema/typografi inkl. font-oploesningen
      og anbefalingen af `BFHtheme::theme_bfh()` (D11). Kryds-henvis fra
      `?bfh_export_pdf` ("for grafer uden SPC-statistik, se ...")

## 6. `bfh_stage_figure_page()` (TDD)

- [ ] 6.1 Tests: samme validering som 5.1 for `plot`/`title`; `cache_dir`,
      `id`, `order`, `overwrite`-semantik identisk med `bfh_stage_pdf_page()`
      (genbrug eksisterende testmoenstre)
- [ ] 6.2 Tests: bundle har `format_version == BATCH_CACHE_FORMAT_VERSION`,
      `metadata$spc_panel == FALSE`, `spc_stats` med alle `NULL`, og
      `chart.svg` i 264 × 109 mm
- [ ] 6.3 Test: blandet batch — eét SPC-bundle + eét figur-bundle →
      `bfh_export_batch_pdf()` (mocket compile) producerer eét `.typ` med to
      `bfh-diagram`-kald, hvor kun det andet har `spc_panel: false`
- [ ] 6.4 Implementér i `R/export_batch.R` ved siden af `bfh_stage_pdf_page()`;
      genbrug `.validate_cache_dir()`, `.validate_page_id()`, id/order-
      resolution og den atomiske rename-blok (udtraek til helper hvis
      duplikering ellers overstiger ~15 linjer)
- [ ] 6.5 Roxygen inkl. trust-model-afsnit (som `bfh_stage_pdf_page()`) og
      note om at aeldre BFHcharts-versioner rendrer figur-bundles med
      SPC-layout

## 7. Dokumentation + kvalitet

- [ ] 7.1 `devtools::document()` → NAMESPACE + `man/` regenereret (to nye
      exports); verificér `R CMD check` ikke klager over udokumenterede
      argumenter
- [ ] 7.2 ASCII-check paa alle nye/aendrede `R/*.R` (`test-source-ascii.R`)
- [ ] 7.3 `styler::style_file()` paa aendrede R-filer; lint groen
- [ ] 7.4 NEWS-entry under naeste version, "Nye funktioner": figur-eksport
      (enkelt + batch), `spc_panel`-flaget, og at eksisterende output er
      uaendret
- [ ] 7.5 README: kort afsnit "Eksport af andre grafer end SPC" med
      eksempel
- [ ] 7.6 Opdatér `openspec/specs/pdf-export/spec.md` og
      `openspec/specs/batch-pdf-export/spec.md` med delta-kravene fra denne
      change (ved arkivering)

## 8. Visuel validering + afslutning

- [ ] 8.1 **Bruger** renderer lokalt: (a) en figur-PDF med analyse, details,
      footer og logo via `inject_assets`; (b) en blandet batch-PDF med een
      SPC-side og een figur-side; (c) en eksisterende SPC-PDF foer/efter
      (skal vaere identisk); (d) en figur **uden** `theme_bfh()` (default-
      tema, Arial i SVG'en) med Mari via `font_path`/`inject_assets` —
      notér hvilken font figurteksten faar (D11, Open Questions).
      Godkendelse noteres her med dato
- [ ] 8.2 Justér inset/spacing i fuld-bredde-tilstand efter feedback (kun
      skabelonen; ingen R-aendring forventet)
- [ ] 8.3 Draft-PR mod `develop`; alle CI-jobs groenne (3× R CMD check,
      lint, test-coverage, pdf-smoke, git-archive-render)
