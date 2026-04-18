# Tasks — strengthen-test-infrastructure

Tracking: [GitHub Issue #142](https://github.com/johanreventlow/BFHcharts/issues/142)

Opgaverne er organiseret i 3 faser svarende til `proposal.md`. Hver fase bør afsluttes med grønne tests før progression.

---

## Fase 1 — Høj prioritet (CI-gate + miljøportabilitet + content-verifikation)

### 1. CI-etablering

- [x] 1.1 Opret `.github/workflows/R-CMD-check.yml` med R-release på Ubuntu-latest — integreret med eksisterende `R-CMD-check.yaml` fra main (commit #140); matrix udvidet til Ubuntu + Windows
- [x] 1.2 ~~Tilføj Quarto-installationsstep~~ — **deferred**: Typst template hardcoder Mari font (proprietær), og Typst returnerer exit 1 på unknown-font warnings. Aktiveres efter font-placeholder-løsning (Fase 2 task 5.4)
- [x] 1.3 Tilføj font-setup-step — åbne fonts installeret (DejaVu, Liberation, Noto, Roboto); Mari-specifik strategi kræver follow-up
- [x] 1.4 Verificér CI kører grønt på en test-PR — iterativt (commits: 633b74b, a10dcce, 8342c19, 1d10407); font-fix + Quarto-deferral + test-fix nødvendige for grøn baseline
- [x] 1.5 Opret `.github/workflows/test-coverage.yml` med `covr::codecov()`-rapportering
- [x] 1.6 Tilføj `codecov.yml` med threshold-konfiguration (advisory første 3 mdr)
- [x] 1.7 Tilføj `.github/workflows/lint.yml` (advisory mode) — eksisterende main-version bevaret; egen advisory-version fjernet som duplikat
- [ ] 1.8 Aktivér branch protection på `main` med CI som required status check — **[MANUELT TRIN]** via GitHub Settings UI efter første grønne CI-run
- [x] 1.9 Tilføj `^openspec$` til `.Rbuildignore` (tilføjet undervejs — ikke oprindeligt i listen, men nødvendig for ren R CMD check)

### 2. Miljøportabilitet

- [x] 2.1 Fjern `skip_if_not_installed("qicharts2")` i alle testfiler (qicharts2 er hard Imports) — 34 forekomster fjernet fra 4 filer
- [x] 2.2 Kortlæg alle `skip_on_ci()`-brug og beslut: font-install i CI vs. test-redesign — 18 kald dokumenteret i `tests/testthat/README.md` med revisit-liste
- [x] 2.3 Implementér valgt strategi (primært: installer fonts i CI-workflow) — åbne fonts (DejaVu, Liberation, Noto) installeres i begge workflows; eksisterende `skip_on_ci()` bevares indtil første CI-baseline verificerer om BFHtheme kan bootstrappe
- [x] 2.4 Dokumentér CI-environment-krav i `tests/testthat/README.md`
- [ ] 2.5 Tilføj test-lag-kontrol via miljøvariabler (`BFHCHARTS_TEST_FULL`, `BFHCHARTS_TEST_RENDER`) — env vars sat i CI, R-side helpers implementeres i Fase 2 task 13 (duplikat)

### 3. Opryd og split store testfiler

- [x] 3.1 Ret stale forventninger i `tests/testthat/test-export_pdf.R:421` (eller migrér til `test-extract-spc-stats-dispatch.R`) — regex-pattern opdateret til S3 dispatch default-method format
- [ ] 3.2 Split `test-export_pdf.R` (1739 linjer) i fokuserede filer:
  - `test-export_pdf-validation.R` (input validation + path safety)
  - `test-export_pdf-rendering.R` (Quarto-live tests, skippable)
  - `test-export_pdf-metadata.R` (merge + extract helpers)
  - `test-export_pdf-spc-stats.R` (extract_spc_stats logik)
- [ ] 3.3 Split `test-spc_analysis.R` (597 linjer) efter funktionsgruppe:
  - `test-spc_analysis-context.R`
  - `test-spc_analysis-pick-text.R`
  - `test-spc_analysis-fallback-analysis.R`
  - `test-spc_analysis-resolve-target.R`
- [ ] 3.4 Split `test-y_axis_formatting.R` (651 linjer) i logiske underfiler
- [x] 3.5 Fjern committed artifact `tests/testthat/Rplots.pdf` (var aldrig tracked — slettet lokalt); `dev.off()`/`withr::local_pdf()`-tilføjelse adresseres i Fase 3 task 17.2

### 4. PDF-indholdsverifikation

- [x] 4.1 ~~Tilføj `pdftools` til DESCRIPTION Imports~~ → **Revideret beslutning:** Holde i Suggests. pdftools har system-dependency (poppler) som pakke-brugere ikke bør tvinges til at installere. Test-filen bruger `skip_if_not_installed("pdftools")` som legitim skip for test-only dep
- [x] 4.2 Opret `tests/testthat/test-export_pdf-content.R`
- [x] 4.3 Implementér `expect_pdf_contains()` helper — inline i `test-export_pdf-content.R` for nu; flyttes til `helper-assertions.R` i Fase 2 task 6.3
- [x] 4.4 Verificér chart-titel i PDF-output
- [x] 4.5 Verificér hospital/department/author/data_definition metadata i output
- [x] 4.6 Verificér SPC summary-tabel tilstedeværelse og indhold (centerlinje + Anhoej-statistik)
- [x] 4.7 Verificér Danish characters (æ, ø, å) rendereres korrekt (titel + metadata + negative case)

### 5. Ekstern isolation — Quarto/system2 mocking

- [x] 5.1 Beslut mocking-framework — valgt: pragmatisk tilgang med `local_mock_quarto_cache()` + `withr::local_envvar()` til env-kontrol. Fuld system2-mock kræver DI-refactor (dokumenteret som future work i testfilen)
- [x] 5.2 Opret `tests/testthat/helper-mocks.R` med standard mock-factories — `local_clean_quarto_cache`, `local_mock_quarto_cache`, `make_system2_*_mock`, `make_bfhllm_*_mock`
- [x] 5.3 Mock `quarto_available()` cache-adfærd i unit-tests (TRUE/FALSE paths, separat cache pr. min_version)
- [ ] 5.4 Mock `system2()` for Quarto-compile fejlveje (non-zero exit, missing output) — **udskudt**: kræver DI-refactor af `bfh_compile_typst`. Mock-factories er klar; refactor implementeres i follow-up task
- [x] 5.5 Tilføj unit-tests for `check_quarto_version()` — 8 tests dækker over/under/eksakt match, version-prefix, uparserbar input
- [x] 5.6 Tilføj unit-tests for Typst-compile-wrapper validation-fasen (shell metachars, path traversal, font_path-typetjek, missing-file detection)

---

## Fase 2 — Mellem prioritet (kvalitetsinfrastruktur)

### 6. Centraliserede fixtures og helpers

- [x] 6.1 Opret `tests/testthat/setup.R` med locale/timezone/RNGkind-kontrol
- [x] 6.2 Opret `tests/testthat/helper-fixtures.R` med konsoliderede funktioner:
  - [x] `fixture_plot_qic_data()` (flyttet fra `test-plot_core.R`, omdøbt fra `make_qic_data`)
  - [x] `fixture_qicharts_summary_data()` (flyttet fra `test-utils_qic_summary.R`, omdøbt — var kollision med test-plot_core.R's version)
  - [x] `fixture_bfh_qic_result()` (flyttet fra `test-extract-spc-stats-dispatch.R`, omdøbt fra `make_fixture_result`)
  - [x] `fixture_analysis_context()` (flyttet fra `test-spc_analysis.R`, omdøbt fra `make_ctx`)
  - [x] `fixture_test_chart()` (flyttet fra `test-security-export-pdf.R`, omdøbt fra `create_test_chart`)
  - [x] `fixture_numeric_data()` (flyttet fra `test-plot_margin.R`, omdøbt fra `setup_test_data`)
  - [x] `fixture_minimal_chart_data()` + `fixture_deterministic_chart_data()` (nye — erstatter 40+ inline-konstruktioner)
- [x] 6.3 Opret `tests/testthat/helper-assertions.R` med custom expectations (`expect_pdf_contains`, `expect_valid_bfh_qic_result`, `expect_summary_value`)
- [ ] 6.4 Opret `tests/testthat/fixtures/` mappe med `README.md` — **udskudt**: kun nødvendig når golden datasets (6.6) introduceres
- [x] 6.5 Erstat lokale `make_*`-funktioner i alle testfiler med centrale versioner (7 filer opdateret)
- [ ] 6.6 Opret deterministiske golden datasets i `fixtures/golden_datasets.rds` — **udskudt**: afhænger af Fase 2 task 8 (statistisk accuracy-suite)
- [ ] 6.7 Dokumentér fixture-generation-proces i `fixtures/README.md` — **udskudt**: sammen med 6.4 + 6.6

### 7. Visuel regression med vdiffr

- [x] 7.1 Verificér `vdiffr` version i Suggests (findes: `vdiffr` uden version-krav)
- [x] 7.2 Opret `tests/testthat/test-visual-regression.R`
- [x] 7.3 Tilføj golden image for run-chart (basic)
- [x] 7.4 Tilføj golden image for i-chart (med UCL/LCL)
- [x] 7.5 Tilføj golden image for p-chart (med variable limits)
- [x] 7.6 Tilføj golden image for u-chart
- [x] 7.7 Tilføj golden image for c-chart
- [x] 7.8 Tilføj golden image for multi-phase chart
- [x] 7.9 Tilføj golden image for chart med target line
- [x] 7.10 Tilføj golden image for chart med notes/annotations
- [x] 7.11 Dokumentér re-baseline-proces i `tests/testthat/README.md` (eksisterer fra Fase 1)
- [x] 7.12 Tests skipper via `skip_if_fonts_unavailable()` på CI (Mari-font ikke tilgængelig)
- [x] 7.13 `skip_if_not_installed("vdiffr")` wrapper for graceful håndtering når vdiffr mangler

**Note:** Initial snapshots genereres på udviklermaskine ved at køre
`testthat::test_dir("tests/testthat", filter = "visual-regression")`
i interaktiv session. Snapshots commits til `tests/testthat/_snaps/visual-regression/`.

### 8. Statistisk accuracy-suite

- [x] 8.1 ~~Opret `fixtures/statistical_cases.rds`~~ → **Revideret:** Håndlavede inline-vektorer foretrækkes (bedre læsbarhed + git-diff-venlige end binær RDS)
- [x] 8.2 Dokumentér reference for hver case (Montgomery 6.4/7.1/7.3/7.4 i docstrings)
- [x] 8.3 Opret `tests/testthat/test-statistical-accuracy.R` — 11 test_that blokke
- [x] 8.4 Verificér p-chart UCL/LCL for p̄=0.10, n=100 (UCL=0.190, LCL=0.01)
- [x] 8.5 Verificér p-chart LCL clippes til 0 ved lille p̄ (bonus over planen)
- [x] 8.6 Verificér u-chart UCL/LCL for ū=0.05, n=100 (UCL≈0.117, LCL=0)
- [x] 8.7 Verificér c-chart UCL/LCL for c̄=5 (UCL≈11.71, LCL=0) + c̄=20 case
- [x] 8.8 Verificér i-chart UCL/LCL med moving-range-metode (2.66 faktor)
- [x] 8.9 Verificér centerlinje-beregning for alle chart-typer (c, i, run, p, u)
- [x] 8.10 Verificér freeze-parameter giver korrekt baseline CL
- [x] 8.11 Bonus: verificér part-parameter giver separate CL'er pr. fase
- [x] 8.12 Bonus: run-chart CL er median (ikke mean)

### 9. Anhøj rule-præcision

- [x] 9.1 Opret `tests/testthat/test-anhoej-precision.R` — 11 test_that blokke
- [x] 9.2 Verificér run-length signal ved 10-punkts run (for n=24); + negativ case
- [x] 9.3 Verificér crossings signal ved få crossings (1 crossing i 24 pt); + negativ case
- [x] 9.4 Verificér sigma.signal detektion ved outlier + negativ case for stabile data
- [x] 9.5 Verificér `outliers_recent_count` mod `outliers_actual` (3 vs. 2 edge case, konstrueret fixture)
- [x] 9.6 Verificér signal-disabled ved stabile mønstre
- [x] 9.7 Bonus: outliers-tælling respekterer part (seneste fase kun)
- [x] 9.8 Bonus: summary indeholder Anhøj-kolonner + længste_løb_max = round(log2(n))+3 validation

### 10. Chart-type integration coverage

- [x] 10.1 Opret `tests/testthat/test-chart_type_integration.R`
- [x] 10.2 Integration-test for `chart_type = "mr"` (moving range) — 2 tests inkl. MR mean + UCL non-negativitet
- [x] 10.3 Integration-test for `chart_type = "pp"` (P-prime) — pooled proportion centerlinje
- [x] 10.4 Integration-test for `chart_type = "up"` (U-prime) — pooled rate centerlinje
- [x] 10.5 Integration-test for `chart_type = "g"` (time-between rare events) — LCL clippet til 0
- [x] 10.6 Integration-test for `chart_type = "xbar"` (subgroup means) — grand average-verifikation
- [x] 10.7 Integration-test for `chart_type = "s"` (subgroup sigma) — CL > 0 + LCL non-negativ
- [x] 10.8 Integration-test for `chart_type = "t"` (time-between events) — mean-based CL + LCL non-negativ
- [x] 10.9 Verificér numeriske værdier (centerlinje, UCL, LCL) for hver chart-type — via `expect_valid_bfh_qic_result` + konkret numerisk assert pr. chart-type
- [x] 10.10 Meta-test: coverage-verifikation af CHART_TYPES_EN vs. testede typer

### 11. Styrk weak integration-assertions

- [x] 11.1 Audit alle `expect_s3_class(plot, "bfh_qic_result")`-only tests — identificeret via awk-script: test-plot_margin.R (13/18), test-integration.R (3/16), test-bfh_qic_result.R (1/7)
- [x] 11.2 Tilføj mindst ét numerisk assertion pr. integration-test — prioriteret test-plot_margin.R og test-integration.R: exact margin-værdier via `expect_plot_margin()`, CL-værdier, phase-split verificering
- [ ] 11.3 Erstat blanket `suppressWarnings()` med eksplicit `expect_warning(..., regexp = NA)` — **defereret**: 119 forekomster, kræver case-by-case audit; pilot udført via deterministisk data i opdaterede tests (erstatter RNG-afhængig `rnorm/rpois` der var årsag til mange warnings)
- [x] 11.4 Fjern duplikeret data-setup — opdaterede tests bruger `fixture_numeric_data()` og deterministiske vektorer i stedet for inline-duplikation
- [x] 11.5 Ny helper `expect_plot_margin()` i helper-assertions.R for præcis margin-verifikation

### 12. BFHllm mock-test

- [x] 12.1 Tilføj mock-factories i `helper-mocks.R` (findes allerede fra Fase 1)
- [x] 12.2 Opret test for `bfh_generate_analysis(use_ai = TRUE)` success-path via `testthat::local_mocked_bindings`
- [x] 12.3 Opret test for `bfh_generate_analysis(use_ai = TRUE)` BFHllm-fejl-fallback
- [x] 12.4 BFHllm-missing-fallback (`use_ai = FALSE` path) dækkes af eksisterende tests i `test-spc_analysis.R`
- [x] 12.5 Bonus: argument-passing test verificerer at min_chars/max_chars/baseline_analysis forwardes korrekt
- [x] 12.6 Bonus: auto-detection test for `use_ai = NULL`

### 13. Test-lag-opdeling

- [x] 13.1 Implementér `skip_if_not_full_test()` helper via `BFHCHARTS_TEST_FULL` — i `helper-skips.R`
- [x] 13.2 Implementér `skip_if_not_render_test()` helper via `BFHCHARTS_TEST_RENDER` — i `helper-skips.R`
- [x] 13.3 Mærk font-afhængige tests med dedikeret helper — 18 `skip_on_ci()`-kald erstattet med `skip_if_fonts_unavailable()` for tydelig semantik (se helper-skips.R)
- [x] 13.4 Quarto-live-tests bruger allerede `skip_if_not(quarto_available())`-mønster + Quarto er deferred fra CI (Fase 1 task 5.4-opfølgning) — dækning via fravær af Quarto i CI-miljø
- [ ] 13.5 Verificér lokal `devtools::test()` kører hurtige tests på <10s — **udskudt**: kræver faktisk kørsel + benchmark-infrastruktur (Fase 3 task 15.1-15.5)
- [x] 13.6 Opdatér CI til at sætte begge miljøvariabler (gjort i Fase 1 R-CMD-check.yaml)

---

## Fase 3 — Lavere prioritet (fuld modenhed)

### 14. CI-matrix og robusthed

- [x] 14.1 Udvid CI-matrix — tilføjet `ubuntu-latest × oldrel-1` som advisory job (ikke branch-protection-required)
- [ ] 14.2 Tilføj `R-devel` som "allowed-to-fail" job — **defereret**: kan tilføjes efter oldrel baseline er stabil
- [x] 14.3 Caching af R-library — håndteres automatisk af `r-lib/actions/setup-r-dependencies@v2` (brug `use-public-rspm: true`)
- [ ] 14.4 Promote coverage-threshold til required ≥85% → ≥90% — **manuelt trin efter 3 mdr baseline**
- [ ] 14.5 Promote lint til required status check — **manuelt trin efter baseline er ren**

### 15. Performance-smoke-tests

- [ ] 15.1 Opret `tests/testthat/test-performance-smoke.R` (gated via `BFHCHARTS_TEST_FULL`)
- [ ] 15.2 Benchmark `bfh_qic` på 1000-punkt dataset (skal være <2s)
- [ ] 15.3 Benchmark `bfh_export_png` på 500-punkt dataset (skal være <3s)
- [ ] 15.4 Benchmark `bfh_export_pdf` på 500-punkt dataset (skal være <10s)
- [ ] 15.5 Dokumentér performance-baseline i `tests/testthat/README.md`

### 16. NA-handling og edge-case-suite

- [x] 16.1 Opret `tests/testthat/test-na-handling.R` — 12 test_that blokke
- [x] 16.2 Test: `y` med blandede NA og tal (drop-rows + warning)
- [x] 16.3 Test: `x` med NA (graceful håndtering)
- [x] 16.4 Test: `n` (denominator) med NA for ratio charts (p-chart)
- [x] 16.5 Test: all-NA kolonne (fejl eller NA centerlinje)
- [x] 16.6 Test: tom data frame (0 rækker) → forventet fejl
- [x] 16.7 Test: én-række data frame (1-række grænsetilfælde) + 3-række minimum for run
- [x] 16.8 Test: duplikerede x-værdier (subgruppe-struktur for xbar)
- [x] 16.9 Test: character-kolonne som y → forventet fejl
- [x] 16.10 Test: navnekollision (input-kolonne hedder "cl")
- [x] 16.11 Bonus: Kombineret edge-case (5 punkter + 2 NA'er)
- [x] 16.12 Bonus: Zero-variance data (alle identiske værdier)

### 17. Oprydning og signal-kvalitet

- [ ] 17.1 Fjern alle unødvendige `suppressWarnings()`-brug (bevar kun hvor eksplicit dokumenteret)
- [ ] 17.2 Fjern `tests/testthat/Rplots.pdf` hvis stadig eksisterende
- [ ] 17.3 Audit alle `set.seed()` — erstat med håndlavede data for tests der verificerer værdier
- [ ] 17.4 Tilføj `tests/testthat/README.md` med test-strategi-dokumentation
- [ ] 17.5 Dokumentér golden image re-baseline-proces
- [ ] 17.6 Dokumentér fixture-update-proces

---

## Validering og afslutning

- [ ] 18.1 Kør `openspec validate strengthen-test-infrastructure --strict` — SKAL passere
- [ ] 18.2 Kør `devtools::test()` lokalt med alle lag aktiveret — SKAL være grøn
- [ ] 18.3 Kør `devtools::check()` — SKAL være uden WARNING/ERROR
- [ ] 18.4 Kør `covr::package_coverage()` — verificér ≥90% total / 100% på exports
- [ ] 18.5 Opdatér NEWS.md med sammenfatning af test-infrastruktur-forbedringer
- [ ] 18.6 Arkiver change via `openspec archive strengthen-test-infrastructure`
