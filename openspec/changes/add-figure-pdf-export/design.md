# Design: add-figure-pdf-export

## Context

Skabelonen `bfh-diagram` (`inst/templates/typst/bfh-template/bfh-template.typ`)
er et 3-raekkers grid paa A4 landscape:

| Raekke | Hoejde | Indhold |
| ------ | ------ | ------- |
| 1 | 52,8 mm | Blaa blok: hospital + enhed (13 pt) og auto-skaleret titel (24–38 pt) |
| 2 | 26,4 mm | Analyse-tekst (15 pt), tom hvis `analysis == none` |
| 3 | `1fr` | 2-kolonne-grid: venstre `auto` (details-linje, graf, footer), hoejre **72,6 mm** (SPC-overskrift, stat-tabel, caveat, datadefinition) |

Hoejrekolonnen er ubetinget: overskriften `STATISTISK PROCESKONTROL (SPC)`
har ingen `#if`, kun tabellen og caveaten er betingede.

R-pipelinen (`bfh_export_pdf()` → `prepare_export_plot()` →
`export_chart_svg()` → `compose_typst_document()` → `bfh_compile_typst()`)
er bundet til `bfh_qic_result` paa tre steder: klasse-validering,
`x$config$chart_title`/`x$config$language` i compose-trinnet, og
`recalculate_labels_for_export()` som genberegner SPC-labels til
PDF-dimensionerne. Grafen eksporteres i `PDF_IMAGE_WIDTH_MM = 191.4` ×
`PDF_IMAGE_HEIGHT_MM = 109` — praecis grafkolonnens bredde.

Batch-stien (`bfh_stage_pdf_page()` → bundle med `chart.svg` + `page.rds`
→ `bfh_export_batch_pdf()`) genbruger samme helpers og emitterer per side
`build_typst_page_call()`, som gaar gennem samme `build_typst_page_params()`
som enkelt-stien.

Verificerede forudsaetninger (kodelaesning 2026-09-21):

- `build_typst_page_params()` er det **eneste** sted parametre til
  skabelonen produceres, delt af enkelt- og batch-sti.
- `bfh_merge_metadata()` filtrerer ukendte metadata-noegler fra via
  `intersect()` — et nyt flag kan derfor ikke komme ind via kalderens
  `metadata`; det skal saettes efter merge (D3).
- Bundle-laeseren validerer `format_version`, ikke metadata-noegler; en ny
  noegle i `metadata` er bagudkompatibel i begge retninger.
- `tests/smoke/test-template.typ` skal acceptere praecis samme named-params
  som produktionsskabelonen (Typst fejler paa ukendte).

## Goals / Non-Goals

**Goals:**

- Vilkaarlige `ggplot`-objekter kan eksporteres med fuld BFH-branding
  (blaa top, analyse-raekke, details-linje, footer, logo, fonte) og grafen
  i fuld bredde.
- Baade enkelt-PDF og batch-samlerapport; SPC- og figur-sider kan blandes.
- Eksisterende PDF-output er byte-identisk (default-sti uaendret).
- Ingen aendring af eksporterede signaturer.

**Non-Goals:**

- Datadefinition i fuld-bredde-tilstand (droppes i v1; kan tilfoejes under
  grafen senere).
- Andre inputtyper end `ggplot` (fx billedfiler, grid-grobs, patchwork).
  Patchwork/gtable er ggplot-kompatible nok til `ggsave()`, men testes ikke
  eksplicit.
- Auto-analyse/AI-tekst for figurer (`auto_analysis`, `use_ai`) — kraever
  SPC-kontekst.
- Aendring af raekkehoejder eller grafhoejden (109 mm) — kun bredden aendres.
- PNG-eksport af figurer (`bfh_export_png()` er `bfh_qic_result`-bundet og
  udenfor scope).

## Decisions

### D1: Eén skabelonfunktion med `spc_panel`-flag, ikke en ny funktion

`bfh-diagram` faar `spc_panel: true` som named-param. Ved `false` rendres
raekke 3 som een `grid.cell` med samme inset som venstrekolonnen i dag
(`left: 26.4mm, top: 2mm, right: 6.6mm`), indeholdende details-linje, graf
og footer-grid. Hoejrekolonnens indhold udelades helt.

*Rationale:* Header, titel-auto-skalering (`context`/`measure`-loekken) og
analyse-raekken er ~110 linjer der skal vaere identiske i begge tilstande.
En separat `bfh-figur`-funktion ville enten duplikere dem eller kraeve en
refaktor af skabelonen til delte `#let`-helpers — stoerre diff, stoerre
risiko for at forrykke det kalibrerede layout. Et flag holder default-stien
uroert og lader batch-dokumenter blande sidetyper under **eén** import-linje
(`bfh_export_batch_pdf()` kraever i dag praecis eén template-funktion pr.
dokument).

*Alternativ forkastet:* `template = "bfh-figur"` som separat funktion —
ville ogsaa kraeve at batch-compile-funktionens "eén template pr. dokument"-
regel blev loesnet.

### D2: Fuld bredde = 264 mm; hoejde uaendret

`PDF_IMAGE_WIDTH_FULL_MM <- 264` (297 − 26,4 venstre-inset − 6,6 hoejre-
inset). Hoejde forbliver `PDF_IMAGE_HEIGHT_MM` (109 mm), da raekke 1–2 og
footer-pladsen er uaendrede.

`export_chart_svg()` faar `width_mm`/`height_mm`-parametre med defaults lig
de nuvaerende konstanter, saa SPC-stien er uaendret og figur-stien blot
sender den nye bredde.

*Rationale:* `ggsave()` skriver fysiske dimensioner i SVG'en, og Typst
placerer `#image()` i naturlig stoerrelse. Grafens dimensioner skal derfor
matche kolonnen praecis — det er samme princip som de eksisterende
konstanter i `globals.R` dokumenterer. Aspektforholdet bliver ~2,4:1;
ggplot laegger plottet ud til den stoerrelse (ikke straekning).

### D3: Flaget transporteres i `metadata$spc_panel`

De to figur-stier saetter `metadata_full$spc_panel <- FALSE` **efter**
`bfh_merge_metadata()`-kaldet — samme moenster som `cl_caveat_text`, der i
dag saettes paa `metadata_full` efter merge. `bfh_merge_metadata()` roeres
**ikke**: `spc_panel` er fortsat ikke i whitelisten, saa en bruger-leveret
`metadata$spc_panel` filtreres fra i alle stier.
`build_typst_page_params()` emitterer `spc_panel: false` **kun** naar
`isFALSE(metadata$spc_panel)`; ved `TRUE`/`NULL` emitteres intet, saa
eksisterende `.typ`-output er byte-identisk.

*Rationale:* Flaget naar baade enkelt-sti (`compose_typst_from_parts()`) og
batch-sti (bundle → `build_typst_page_call()`) uden at roere signaturen paa
`bfh_create_typst_document()`, `bfh_export_pdf()` eller bundle-laeseren.
Bundles serialiserer allerede `metadata` som liste.

*Alternativ forkastet (review 2026-09-21):* `spc_panel = TRUE` i
`bfh_merge_metadata()`-defaults. `bfh_stage_pdf_page()` gemmer merge-
resultatet uaendret i `page.rds`, saa alle SPC-bundles ville faa
`spc_panel = TRUE` — i strid med batch-deltaens krav om at SPC-bundles ikke
baerer en `spc_panel`-vaerdi. Det ville ogsaa aendre returformen paa en
eksporteret funktion, hvis felter `public-api`-spec'en opregner, og lade en
kalder slaa statistik-kolonnen fra paa et SPC-chart (smal graf i bred
kolonne).

*Konsekvens:* flaget er ikke kalder-styret. Eneste vej til fuld-bredde-
tilstand er de to figur-funktioner.

### D4: To nye exports, ingen udvidelse af eksisterende

`bfh_export_figure_pdf(plot, output, metadata = list(), template =
"bfh-diagram", template_path = NULL, restrict_template = TRUE, dpi = 150,
font_path = NULL, ignore_system_fonts = TRUE, inject_assets = NULL,
batch_session = NULL)` og
`bfh_stage_figure_page(plot, cache_dir, id = NULL, order = NULL, metadata =
list(), template = "bfh-diagram", dpi = 150, overwrite = TRUE)`.

Parametre der ikke giver mening for figurer udelades: `auto_analysis`,
`use_ai`, `data_consent`, `use_rag`, `analysis_*`, `strict_baseline`.

*Rationale:* Projektreglen "roer ikke eksporterede signaturer" +
`bfh_export_pdf()`s `x`-parameter er dokumenteret som `bfh_qic_result` i
spec'en (public-api, batch-pdf-export). S3-dispatch paa `x` ville aendre
kontrakten for fejlbeskeder ("x must be a bfh_qic_result") som tests laaser.
Navnet `figure` (ikke `plot`/`chart`) markerer "ikke et SPC-diagram" og
undgaar kollision med `x$plot`-feltet.

### D5: Bundle-format uaendret (`BATCH_CACHE_FORMAT_VERSION` forbliver 1)

Figur-bundles har samme struktur (`chart.svg` + `page.rds` med `metadata`,
`spc_stats`, `template`, `order`, ...). `spc_stats` er `empty_spc_stats()`
(alle `NULL` → ingen stats-params emitteres). `metadata$spc_panel = FALSE`.

*Rationale:* Aeldre BFHcharts-versioner der laeser et figur-bundle ville
rendere det med SPC-layout (tom kolonne + smal graf) — degraderet, ikke
korrupt. Nyere versioner der laeser gamle SPC-bundles ser `spc_panel = NULL`
→ default `TRUE`. Ingen af delene retfaerdiggoer en version-bump med
tvungen re-staging af tusindvis af sider.

### D6: Titel/undertitel strippes fra plottet, som i SPC-stien

`prepare_figure_plot(plot)` = `plot + labs(title = NULL, subtitle = NULL)` +
fjernelse af blanke aksetitler + `prepare_plot_for_export(margin_mm = 0)`.
Ingen label-genberegning.

`prepare_plot_for_export()` saetter **kun** `plot.margin` (verificeret
2026-09-21; aksetitel-fjernelsen ligger i `apply_spc_theme()`,
`R/themes.R:76-87`, som figur-stien ikke gaar igennem). Figur-stien skal
derfor selv opfylde pdf-export-kravet "Export functions SHALL conditionally
remove blank axis titles".

Logikken i `apply_spc_theme()` kan **ikke** genbruges direkte: den laeser
`plot$labels$x`/`$y`, som i ggplot2 >= 4.0 er `NULL` naar titlen udledes af
`aes()` (maalt paa 4.0.3: `plot$labels$x` er `NULL`, `get_labs(plot)$x` er
`"wt"`). Genbrug ville fjerne gyldige aksetitler fra naesten alle figurer.
Figur-stien afgoer "blank" paa de **oploeste** labels
(`ggplot2::get_labs()`; fallback til `ggplot_build(plot)$plot$labels` hvis
den installerede ggplot2 ikke har funktionen — afklares i task 5.3).

*Rationale:* brugerbeslutning — titlen gaar i den blaa top via
`metadata$title`; to titler er en fejl. `metadata$title` er derfor
**paakraevet** for figurer (SPC-stien henter den fra `x$config$chart_title`;
figurer har ingen tilsvarende kilde). Manglende titel → klassificeret
eksport-fejl foer nogen filoperation.

### D7: Datadefinition udelades i fuld-bredde-tilstand

Skabelonen accepterer stadig `data_definition`, men rendrer den ikke naar
`spc_panel == false`. R-siden filtrerer ikke — parametren sendes med, saa
en senere placering under grafen kun kraever en skabelonaendring.

*Rationale:* brugerbeslutning ("drop i foerste omgang"). Eneste alternative
placering er under grafen i footer-omraadet (13,2 mm), som ikke kan baere
den nuvaerende 52,8 mm-hoeje kaskade-rendering.

### D8: Compose-trinnet splittes i en `x`-fri kerne

`compose_typst_document(x, ...)` beholder sin signatur men bliver en tynd
wrapper: den udleder `chart_title`, `language` og caveat-tekst fra `x` og
kalder en ny intern `compose_typst_from_parts(metadata_full, spc_stats,
chart_svg, typst_file, template, template_path, batch_session, font_path,
inject_assets)`, som indeholder template-staging, `inject_assets`, logo-
auto-detect og `bfh_create_typst_document()`-kaldet. Figur-stien kalder
kernen direkte med `bfh_merge_metadata(metadata, chart_title =
metadata$title)` tilfoejet `spc_panel = FALSE` (D3) og `empty_spc_stats()`.

Tilsvarende splittes `validate_bfh_export_pdf_inputs()` saa sti/dpi/
font_path/inject_assets/session-tjekkene kan genbruges af
`validate_bfh_export_figure_inputs()` (som i stedet tjekker
`inherits(plot, "ggplot")` og `metadata$title`).

*Rationale:* eén implementation af staging/inject/logo-rekkefoelgen (den
har allerede haft een regression: logo-detect foer inject). Wrapper-
signaturen bevares saa eksisterende tests og mocks
(`local_mocked_bindings(export_chart_svg = ...)`) er upaavirkede.

### D9: Smoke-templaten spejler flaget minimalt

`tests/smoke/test-template.typ` faar `spc_panel: true` i signaturen og
udelader SPC-summary-blokken naar `false`. Ingen layout-aendring i oevrigt —
smoke-templaten validerer kun at pipelinen kompilerer, ikke udseende.

## Risks / Trade-offs

- **Visuel kalibrering kan ikke verificeres af den foreslaaende agent**
  (ingen R/Quarto i dens miljoe). *Kompilerbarhed* kan derimod verificeres
  i CI: `pdf-smoke` saetter `BFHCHARTS_SMOKE_USE_PRODUCTION_TEMPLATE=true`
  og koerer `tests/testthat/test-production-template-renders.R` mod
  produktionsskabelonen; `render-tests` koerer de render-gatede tests.
  (Kun `git-archive-render` bruger smoke-templaten.) Mitigering: (a)
  render-gatet test der kompilerer produktionsskabelonen med `spc_panel:
  false` (task 5.7), saa Typst-fejl i den nye gren fanges i CI; (b)
  eksplicit brugergodkendelse af udseendet paa lokalt renderede PDF'er
  (enkelt + blandet batch) foer merge.
  *Review 2026-09-21:* layoutet er afproevet paa en patchet skabelonkopi
  (raekke 3 som een kolonne): 264 mm SVG fylder kolonnen praecis, 191,4 mm
  SVG efterlader ~72 mm tomrum (Typst opskalerer ikke), og 264 mm SVG i den
  nuvaerende skabelon skaleres ned uden clipping (understoetter D5).
- **Bredt aspektforhold (2,4:1).** Nogle figurtyper (fx hoeje soejlediagrammer)
  passer daarligt. Accepteret: samme betingelse som SPC-charts, og brugeren
  ejer plottet. Hoejde/bredde eksponeres ikke som parametre i v1 (ville
  bryde "grafen passer praecis i skabelonen"-invarianten).
- **Refaktor af compose/validate (D8)** roerer den mest testede del af
  eksport-koden. Mitigering: wrapper-signaturer bevares; eksisterende
  export-tests skal passere uden aendrede forventninger (regression guard
  fra batch-pdf-export-spec'en gaelder).
- **Figur-bundles laest af aeldre BFHcharts** rendres med SPC-layout (D5).
  Kun relevant hvis cache deles paa tvaers af versioner; noteres i roxygen
  for `bfh_stage_figure_page()`.

## Migration Plan

Ingen migration — additiv aendring.

1. `feat/figure-pdf-export` fra `develop`.
2. Skabelon + smoke-template + konstant foerst (kan verificeres via
   `pdf-smoke` i CI uafhaengigt af R-koden).
3. Refaktor (D8) i egen commit med groen testsuite, foer nye funktioner.
4. Nye funktioner + tests + roxygen (`devtools::document()`).
5. Brugerens visuelle godkendelse → PR mod `develop` (draft). MINOR-bump
   ved naeste release-PR.

## Open Questions

- Skal `bfh_export_figure_pdf()` acceptere et allerede renderet billede
  (SVG/PNG-sti) som alternativ til `ggplot`? Udenfor v1; kan tilfoejes som
  S3-metode senere uden at bryde signaturen.
- Boer `details`-linjen for figurer have en default (SPC-stien auto-
  genererer "periode / gennemsnit / aktuelt niveau" via
  `prepare_export_metadata()`)? V1: ingen default — kalderen saetter
  `metadata$details` selv.
