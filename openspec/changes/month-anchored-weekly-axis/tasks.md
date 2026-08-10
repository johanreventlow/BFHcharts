# Tasks: month-anchored-weekly-axis

## 1. Forudsaetninger + konstant

- [x] 1.1 Bump `DESCRIPTION`: `ggplot2 (>= 3.4.0)` → `(>= 3.5.0)` (kraevet af `guide_axis(minor.ticks)`; verificeret mangler i dag)
- [x] 1.2 Udtraek `BFH_MAX_DATE_BREAKS <- 15L` som intern konstant i `R/utils_x_axis_formatting.R` (`@keywords internal @noRd` — ingen ny export) og brug den i `calculate_interval_multiplier()`
- [x] 1.3 Feature-branch fra `develop`: `feat/month-anchored-weekly-axis`

## 2. Ugestart-fix (mandag)

- [x] 2.1 Skriv test: `round_to_interval_start(<mandag>, "weekly")` returnerer samme mandag (i dag: foregaaende soendag) — daekker eksisterende defekt
- [x] 2.2 Tilfoej `week_start = 1` til `lubridate::floor_date()`-kaldet i `round_to_interval_start()`
- [x] 2.3 Verificér ingen eksisterende tests brister paa den aendrede uge-floor
- [x] 2.4 **[Tilfoejet under implementering]** Assertion-konvention: sammenlign POSIXct-datoer med `format(x, "%Y-%m-%d")`, ALDRIG `as.Date(x)` — `as.Date.POSIXct()` konverterer i UTC og skubber lokal midnat en dag tilbage (CET). Gaelder alle nye tests i denne change

## 3. Break-generering (TDD — tests foerst)

- [x] 3.1 Skriv tests: `calculate_month_anchored_breaks()` giver major breaks paa d. 1. for 37-ugers spaend (PDF-casen 2025-12-01→2026-08-09); midt-i-maaned-start (2025-12-10) → foerste break 2026-01-01; intet break paa `data_x_min`
- [x] 3.2 Skriv tests: 104-ugers spaend giver rene maanedsstarter (ingen 13-ugers-drift bagud gennem kalenderen)
- [x] 3.3 Skriv tests: minor breaks = alle mandage i spaendet (`week_start = 1`); DST-cases (marts + oktober, Europe/Copenhagen) uden 1-times drift — sekvens genereres paa Date-niveau
- [x] 3.4 Skriv tests: breaks trimmes i **begge** ender — 16-ugers data giver ingen breaks efter 2026-04-20 (i dag: 2 stk.)
- [x] 3.5 Skriv tests: > 15 maaneder → major-multiplier 3/6/12 via `calculate_interval_multiplier(n, "monthly")` og minor-unit eskalerer fra week til month
- [x] 3.6 Implementér `calculate_month_anchored_breaks(data_x_min, data_x_max, label_multiplier, minor_unit)` i `R/utils_x_axis_formatting.R` (returnerer list med `major` + `minor` POSIXct-vektorer) — plus intern helper `generate_calendar_sequence()` (Date-niveau-sekvens + trim i begge ender)

## 4. Break-unit-kontrakt

- [x] 4.1 Skriv tests: `get_optimal_formatting()` weekly-branch returnerer `break_unit = "week"`/`minor_break_unit = NULL` ved <= 15 uger i spaendet og `"month"`/`"week"` derover (threshold fra `timespan_days / 7`, ikke `n_obs`)
- [x] 4.2 Skriv tests: daily-branch returnerer `break_unit = "day"` ved <= 15 dage, `"week"`/`"day"` i mellemtrinnet og `"month"`/`"week"` over 15 uger
- [x] 4.3 Skriv tests: threshold beregnes paa dataspaend ved huller i serien (12 obs over 20 uger → maanedsmode)
- [x] 4.4 Skriv regressionstests: monthly-configs uaendrede (18 + 30 obs paa d. 1. beholder 3-maaneders kadence); config uden `break_unit` falder tilbage til nuvaerende adfaerd
- [x] 4.5 Opdatér `get_optimal_formatting()` i `R/utils_date_formatting.R`: erstat doede `breaks`-strings med `break_unit`/`minor_break_unit`; daily+weekly over threshold bruger maanedsformat `c("%Y", "%b", "", "")`
- [x] 4.6 Skriv tests: `calculate_date_breaks()` dispatcher paa `format_config$break_unit`; force-first-break anvendes ikke laengere for nogen interval-type (inkl. monthly d. 15. → foerste break 01-apr)
- [x] 4.7 Refaktorér `calculate_date_breaks()`: dispatch paa `break_unit`, fjern force-first-break-blok, trim breaks i begge ender
- [x] 4.8 **[Tilfoejet under implementering, godkendt af bruger]** Tre-trins daily-model: `<= 15 dage` = dags-labels; `16-105 dage` = uge-ankrede labels + dags-ticks; `> 105 dage` = maaneds-ankret. Maanedsankring alene gav 0-2 labels for 20-40-dages serier (30 dage indeholder hoejst een maanedsstart). Generator faar `major_unit`-parameter; nye regressionstests garanterer >= 2 labels for alle spaend
- [x] 4.9 **[Tilfoejet under implementering]** Tidszone-fix i `generate_calendar_sequence()`: rekonstruér breaks i inputtets egen tidszone, ikke `Sys.timezone()`. UTC-input gav 1-times-forskudte breaks, saa trimningen smed foerste gyldige break vaek (PDF-casen mistede `01-dec`)

## 5. Scale-anvendelse + minor-tick-rendering

- [x] 5.1 Skriv tests: `apply_temporal_x_axis()` paa > 15-ugers ugedata producerer ggplot med maaneds-major-breaks, uge-minor-breaks og `guide_axis(minor.ticks = TRUE)` (inspicér scale-objektet); <= 15 uger → ingen minor-guide (regression); plus `ggplot_build()`-test der fanger ugyldige scale/guide-kombinationer
- [x] 5.2 Opdatér `apply_temporal_x_axis()`: send `minor_breaks` + `guide` gennem `BFHtheme::scale_x_datetime_bfh(...)` via `do.call`; ny helper `calculate_minor_breaks()` + `has_x_minor_breaks()`
- [x] 5.3 Verificér labels stadig locale-wrappes via `with_lc_time_labeler()` (dansk maanedsnavne-test med `skip_if` naar da-locale mangler paa host)
- [x] 5.4 **[Tilfoejet under implementering — BLOKERET, brugerbeslutning]** Minor-tick-SYNLIGHED leveres ikke i denne change. `BFHtheme::theme_bfh()` saetter `axis.ticks = element_blank()`; minor ticks arver blankingen. Verificeret at hverken theme-raekkefoelge eller `lemon::coord_capped_cart()` er aarsagen. Bruger valgte at rejse spoergsmaalet i BFHtheme-repoet frem for lokal override. `minor_breaks` + `guide_axis(minor.ticks = TRUE)` vedhaeftes scalen, saa ticks renderer automatisk naar BFHtheme understoetter dem
- [x] 5.5 **[Opfoelgning, andet repo]** Issue oprettet: [BFHtheme#80](https://github.com/johanreventlow/BFHtheme/issues/80). Verificeret mod v0.5.4-kilden (`R/themes.R:108`): `axis.ticks.x = element_blank()`, mens `axis.minor.ticks.x.bottom` slet ikke saettes — minor ticks blankes altsaa som *sideeffekt* af arv, ikke ved bevidst valg. Y-aksen har aktive ticks (`R/themes.R:106-107`), saa "ingen ticks" er ikke et gennemgaaende princip. Forslag i issue: saet `axis.minor.ticks.x.bottom` eksplicit uden at roere major ticks. Ingen kodeaendring noedvendig i BFHcharts naar det lander

## 6. Visuel validering + snapshots

- [x] 6.1 Render foer/efter for: 12, 16, 26, 37 (PDF-casen), 52 og 104 uger; 20, 30, 60 og 120 dage; 18 maaneder fra d. 1. og fra d. 15. — alle 12 cases renderer fejlfrit; PDF-casen giver `DEC 2025 | JAN 2026 | FEB | ...` mod tidligere `01, 28, 25, 22, ...`
- [x] 6.2 Vurdér eksplicit om daily-threshold paa 15 dage giver et for groft udtryk — JA, bekraeftet: ren maanedsankring gav 0-2 labels. Loest med uge-ankret mellemtrin (task 4.8), ikke ved at haeve threshold
- [x] 6.3 vdiffr-snapshots: genereret og verificeret i CI (`ubuntu-latest release` + `oldrel-1`, `windows-latest release` — alle gronne, ingen visuelle diffs paa eksisterende chart-typer). Kunne ikke koeres lokalt (`{vdiffr}` ej installeret). **NB:** en lokal testkoersel uden vdiffr SLETTER `_snaps/visual-regression/*.svg`; gendan med `git checkout -- tests/testthat/_snaps/` foer commit
- [x] 6.4 Fuld testkoersel paa endelig kode: `devtools::test()` exit 0 — **0 failures**, 89 skips (render-tests + vdiffr), 8 forventede warnings fra eksisterende tests
- [x] 6.5 `devtools::check()` uden WARNINGs/ERRORs — **gron i CI** paa tre R-versioner/platforme (`ubuntu release`, `ubuntu oldrel-1`, `windows release`). Kunne ikke koeres lokalt: hverken Pandoc (vignette-build) eller Rtools (pakke-build) er installeret paa maskinen; uafhaengigt af denne change
- [x] 6.6 **[Brugergodkendelse 2026-08-10]** Layoutet godkendt af bruger paa baggrund af renderede cases (`daily-30`, `weekly-104`, `monthly-18-15th`, `weekly-16`, `daily-120`, `weekly-37-PDF`). Inkluderer eksplicit accept af D8-konsekvensen: maanedsdata der ikke starter d. 1. mister foerste label (`monthly-18-15th` viser foerste label `APR 2025` for data fra 15. jan)
- [x] 6.7 **[Undersoegt]** Flaky test observeret: `test-quarto-isolation.R:500` (`.system2 mock: success path`, forventer 7 args, faar 9) fejlede i fuld-suite-koersler paa tre uafhaengige branches. **Ikke en regression fra denne change** — diffen roerer ingen Quarto-filer, testen kommer fra upstream (`8cb2f63`), isolerede koersler giver 0 failures, og CI's `windows-latest (release)` (samme platform, fuld suite) er gron. Konklusion: mock-state der laekker mellem testfiler. Foreslaas rapporteret separat

## 7. Dokumentation + afslutning

- [x] 7.1 Verificér al ny kode passerer `test-source-ascii.R` (ASCII-only i `R/*.R`) — `tools::showNonASCIIfile()` ren paa alle tre aendrede R-filer
- [x] 7.2 Opdatér roxygen for beroerte interne funktioner (alle nye er `@noRd`, saa ingen NAMESPACE/.Rd-regenerering noedvendig)
- [x] 7.3 NEWS-entry (dansk) under `# BFHcharts (development)`: "Nye features" + "Bug fixes" (4 stk.) + "Kendte begraensninger" (tick-synlighed)
- [x] 7.4 `styler::style_file()` paa de fire aendrede filer
- [x] 7.5 PR mod `develop`: **#506** merged — alle 7 CI-jobs gronne (3x R CMD check, lint, test-coverage, pdf-smoke, git-archive-render). MINOR-bump haandteres ved naeste release-PR
- [x] 7.7 **[Tilfoejet]** Rebased paa `origin/develop` foer push: lokal `develop` var 70 commits bagud (op til v0.26.1). Een konflikt i `NEWS.md` (begge sider tilfoejede entries oeverst) loest ved at placere `(development)`-sektionen over 0.26.1. Upstream-refactor af locale-caching i samme fil sameksisterer uden problemer
- [x] 7.6 **[Tilfoejet]** Omdoebt `calculate_month_anchored_breaks()` → `calculate_anchored_breaks()` da den nu ogsaa haandterer uge-ankring
