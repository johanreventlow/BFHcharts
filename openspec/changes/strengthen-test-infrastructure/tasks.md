# Tasks — strengthen-test-infrastructure

Tracking: [GitHub Issue #142](https://github.com/johanreventlow/BFHcharts/issues/142)

Opgaverne er organiseret i 3 faser svarende til `proposal.md`. Hver fase bør afsluttes med grønne tests før progression.

---

## Fase 1 — Høj prioritet (CI-gate + miljøportabilitet + content-verifikation)

### 1. CI-etablering

- [x] 1.1 Opret `.github/workflows/R-CMD-check.yml` med R-release på Ubuntu-latest
- [x] 1.2 Tilføj Quarto-installationsstep (`quarto-dev/quarto-actions/setup@v2`)
- [x] 1.3 Tilføj font-setup-step (åben fallback-font via `apt install` eller download)
- [ ] 1.4 Verificér CI kører grønt på en test-PR (allowed-failures acceptabelt i første iteration) — **[MANUELT TRIN]** efter push af denne branch
- [x] 1.5 Opret `.github/workflows/test-coverage.yml` med `covr::codecov()`-rapportering
- [x] 1.6 Tilføj `codecov.yml` med threshold-konfiguration (advisory første 3 mdr)
- [x] 1.7 Tilføj `.github/workflows/lint.yml` (advisory mode)
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

- [ ] 6.1 Opret `tests/testthat/setup.R` med locale/timezone/RNGkind-kontrol
- [ ] 6.2 Opret `tests/testthat/helper-fixtures.R` med konsoliderede funktioner:
  - [ ] `make_qic_data()` (flyttet fra `test-plot_core.R`)
  - [ ] `make_fixture_result()` (flyttet fra `test-extract-spc-stats-dispatch.R`)
  - [ ] `make_ctx()` (flyttet fra `test-spc_analysis.R`)
  - [ ] `create_test_chart()` (flyttet fra `test-security-export-pdf.R`)
  - [ ] `setup_test_data()` (flyttet fra `test-plot_margin.R`)
- [ ] 6.3 Opret `tests/testthat/helper-assertions.R` med custom expectations
- [ ] 6.4 Opret `tests/testthat/fixtures/` mappe med `README.md`
- [ ] 6.5 Erstat lokale `make_*`-funktioner i alle testfiler med centrale versioner
- [ ] 6.6 Opret deterministiske golden datasets i `fixtures/golden_datasets.rds`
- [ ] 6.7 Dokumentér fixture-generation-proces i `fixtures/README.md`

### 7. Visuel regression med vdiffr

- [ ] 7.1 Verificér `vdiffr` version i Suggests (≥1.0.0)
- [ ] 7.2 Opret `tests/testthat/test-visual-regression.R`
- [ ] 7.3 Tilføj golden image for run-chart (basic)
- [ ] 7.4 Tilføj golden image for i-chart (med UCL/LCL)
- [ ] 7.5 Tilføj golden image for p-chart (med variable limits)
- [ ] 7.6 Tilføj golden image for u-chart
- [ ] 7.7 Tilføj golden image for c-chart
- [ ] 7.8 Tilføj golden image for multi-phase chart
- [ ] 7.9 Tilføj golden image for chart med target line
- [ ] 7.10 Tilføj golden image for chart med notes/annotations
- [ ] 7.11 Dokumentér re-baseline-proces i `tests/testthat/README.md`

### 8. Statistisk accuracy-suite

- [ ] 8.1 Opret `tests/testthat/fixtures/statistical_cases.rds` med kendte cases
- [ ] 8.2 Dokumentér reference for hver case (Montgomery SPC, Provost & Murray, etc.)
- [ ] 8.3 Opret `tests/testthat/test-statistical-accuracy.R`
- [ ] 8.4 Verificér p-chart UCL/LCL for p̄=0.10, n=100 (forventet UCL≈0.190)
- [ ] 8.5 Verificér p-chart UCL/LCL for p̄=0.05, n=500
- [ ] 8.6 Verificér u-chart UCL/LCL for kendt u-bar og n
- [ ] 8.7 Verificér c-chart UCL/LCL for c̄=5 (forventet UCL≈11.71)
- [ ] 8.8 Verificér i-chart UCL/LCL med moving-range-metode
- [ ] 8.9 Verificér centerlinje-beregning for alle chart-typer
- [ ] 8.10 Verificér freeze-parameter giver korrekt baseline CL

### 9. Anhøj rule-præcision

- [ ] 9.1 Opret `tests/testthat/test-anhoej-rules-precision.R`
- [ ] 9.2 Verificér run-length signal ved konstrueret 9-punkts serie
- [ ] 9.3 Verificér crossings signal ved kendt antal crossings
- [ ] 9.4 Verificér outlier-detection ved sigma.signal-baserede cases
- [ ] 9.5 Verificér `outliers_recent_count` mod `outliers_actual` for edge cases
- [ ] 9.6 Verificér signal-disabled ved stabil alternerende data

### 10. Chart-type integration coverage

- [ ] 10.1 Opret `tests/testthat/test-chart_type_integration.R`
- [ ] 10.2 Integration-test for `chart_type = "mr"` (moving range)
- [ ] 10.3 Integration-test for `chart_type = "pp"` (P-prime)
- [ ] 10.4 Integration-test for `chart_type = "up"` (U-prime)
- [ ] 10.5 Integration-test for `chart_type = "g"` (time-between rare events)
- [ ] 10.6 Integration-test for `chart_type = "xbar"` (subgroup means)
- [ ] 10.7 Integration-test for `chart_type = "s"` (subgroup sigma)
- [ ] 10.8 Integration-test for `chart_type = "t"` (time-between events)
- [ ] 10.9 Verificér numeriske værdier (centerlinje, UCL, LCL) for hver chart-type

### 11. Styrk weak integration-assertions

- [ ] 11.1 Audit alle `expect_s3_class(plot, "bfh_qic_result")`-only tests
- [ ] 11.2 Tilføj mindst ét numerisk assertion pr. integration-test (CL, UCL, eller signal-count)
- [ ] 11.3 Erstat blanket `suppressWarnings()` med eksplicit `expect_warning(..., regexp = NA)` eller specific match
- [ ] 11.4 Fjern duplikeret data-setup til fordel for fixture-helpers

### 12. BFHllm mock-test

- [ ] 12.1 Tilføj `helper-mocks.R` mock for `BFHllm::*`-kald
- [ ] 12.2 Opret test for `bfh_generate_analysis(use_ai = TRUE)` success-path
- [ ] 12.3 Opret test for `bfh_generate_analysis(use_ai = TRUE)` BFHllm-fejl-fallback
- [ ] 12.4 Opret test for `bfh_generate_analysis(use_ai = TRUE)` BFHllm-missing-fallback

### 13. Test-lag-opdeling

- [ ] 13.1 Implementér `skip_if_not_full_test()` helper via `BFHCHARTS_TEST_FULL`
- [ ] 13.2 Implementér `skip_if_not_render_test()` helper via `BFHCHARTS_TEST_RENDER`
- [ ] 13.3 Mærk tunge render-tests med `skip_if_not_render_test()`
- [ ] 13.4 Mærk Quarto-live-tests med `skip_if_not_render_test()`
- [ ] 13.5 Verificér lokal `devtools::test()` kører hurtige tests på <10s
- [ ] 13.6 Opdatér CI til at sætte begge miljøvariabler

---

## Fase 3 — Lavere prioritet (fuld modenhed)

### 14. CI-matrix og robusthed

- [ ] 14.1 Udvid CI til matrix: {ubuntu, macos, windows} × {R-release, R-oldrel-1}
- [ ] 14.2 Tilføj `R-devel` som "allowed-to-fail" job
- [ ] 14.3 Konfigurér caching af `renv` / R-library for hurtigere CI-kørsler
- [ ] 14.4 Promote coverage-threshold til required ≥85% (efter 1 mdr) → ≥90% (efter 3 mdr)
- [ ] 14.5 Promote lint til required status check efter baseline er ren

### 15. Performance-smoke-tests

- [ ] 15.1 Opret `tests/testthat/test-performance-smoke.R` (gated via `BFHCHARTS_TEST_FULL`)
- [ ] 15.2 Benchmark `bfh_qic` på 1000-punkt dataset (skal være <2s)
- [ ] 15.3 Benchmark `bfh_export_png` på 500-punkt dataset (skal være <3s)
- [ ] 15.4 Benchmark `bfh_export_pdf` på 500-punkt dataset (skal være <10s)
- [ ] 15.5 Dokumentér performance-baseline i `tests/testthat/README.md`

### 16. NA-handling og edge-case-suite

- [ ] 16.1 Opret `tests/testthat/test-na-handling.R`
- [ ] 16.2 Test: `y` med blandede NA og tal
- [ ] 16.3 Test: `x` med NA (forventet fejl eller håndtering)
- [ ] 16.4 Test: `n` (denominator) med NA for ratio charts
- [ ] 16.5 Test: all-NA kolonne
- [ ] 16.6 Test: tom data frame (0 rækker)
- [ ] 16.7 Test: én-række data frame
- [ ] 16.8 Test: duplikerede x-værdier
- [ ] 16.9 Test: character-kolonne som y (forventet fejl)
- [ ] 16.10 Test: navnekollision (input-kolonne hedder "cl", "ucl", "lcl")

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
