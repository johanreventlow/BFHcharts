## Why

BFHcharts har en substantiel test-suite (~640 test_that-blokke fordelt på 35 filer), men et uafhængigt review (både egen og Codex-review) identificerer, at *operative test-modenhed* ikke matcher pakkens "Status: Production"-betegnelse. Kernemanglerne er:

- **Ingen CI/CD-gate**: `.github/workflows/` eksisterer ikke. 18 `skip_on_ci()` og 32 `skip_on_cran()` forbereder en CI der aldrig blev opsat. Test-suiten er ikke en reel merge-/release-gate.
- **Overfladiske render-tests**: Eksport-tests verificerer typisk kun `file.exists() + size > 0` — ikke at PDF/PNG-indholdet er korrekt. `pdftools` er i Suggests men bruges ikke.
- **Svag ekstern isolation**: Quarto/Typst/system2-kald (`R/utils_quarto.R:38`, `R/utils_typst.R:230`) testes som live-integration, ikke som isoleret logik. BFHllm-stien er aldrig eksekveret i test.
- **Statistisk korrekthed ikke numerisk verificeret**: Ingen tests for kendte UCL/LCL-værdier for p/u/c-charts. Pakken stoler på qicharts2 uden at verificere kontrakten.
- **Manglende chart-type-dækning**: `mr, pp, up, g, xbar, s, t` findes i konstanter og NAMESPACE, men har stort set ingen funktionel integration-test.
- **Duplikerede fixtures**: `make_qic_data`, `make_fixture_result`, `make_ctx`, `create_test_chart`, `setup_test_data` er gen-implementeret lokalt i 5+ filer.
- **Ingen visuel regression**: `vdiffr` er i Suggests men bruges ikke. For en visualiseringspakke er dette en blind vinkel.
- **Signal-støj**: 119 `suppressWarnings()`-brug maskerer potentielt reelle advarsler. Stale forventninger i `tests/testthat/test-export_pdf.R:421` peger på drift.

Som hjælpepakke til biSPCharts-Shiny-appen er pakke-logikken rimeligt dækket, men uden CI-gate, content-verifikation og ekstern isolation er suiten ikke et solidt sikkerhedsnet for refactoring, dependency-opgraderinger eller Typst/Quarto-pipelineændringer.

## What Changes

Dette change etablerer produktionsklar test-infrastruktur i tre faser, implementeret sekventielt:

**Fase 1 — Høj prioritet (blokker for "professionelt moden")**
- Etablér GitHub Actions CI-workflow med R CMD check, testthat og coverage
- Mock Quarto/system2-kald så fejlveje kan testes uden live-binary
- Fjern misvisende `skip_if_not_installed("qicharts2")` (qicharts2 er hard dependency)
- Afklar `skip_on_ci()`-strategi (enten installer fonts i CI eller redesign tests)
- Split `test-export_pdf.R` (1739 linjer) i mindre fokuserede filer
- Ret stale forventninger i `test-export_pdf.R:421`
- Tilføj PDF-indholdsverifikation via `pdftools::pdf_text()`

**Fase 2 — Mellem prioritet (kvalitetsløft)**
- Centralisér fixtures i `helper-fixtures.R` og `tests/testthat/fixtures/`
- Tilføj `setup.R` med locale/timezone/RNGkind-kontrol for determinisme
- Introducér vdiffr visual regression — mindst én golden image pr. chart-type
- Statistisk accuracy-suite med numerisk verificerede UCL/LCL for p/u/c/i charts
- Integration-tests for manglende chart-typer (mr, pp, up, g, xbar, s, t)
- Styrk weak integration-asserts med numeriske værdier (centerlinje, UCL, signal-count)
- Mock BFHllm-integration så `use_ai = TRUE`-stien får coverage
- Erstat blanket `suppressWarnings()` med eksplicit `expect_warning()` eller `regexp = NA`
- Opdel tests i hurtige unit-tests og tunge external/render-tests

**Fase 3 — Lavere prioritet (fuld modenhed)**
- CI-matrix på flere R-versioner og OS'er (Ubuntu/macOS/Windows)
- Performance-smoke-tests for tungeste render/export-flows
- Dedikeret NA-handling-suite for kliniske data-scenarier
- Ryd warning-støj og `tests/testthat/Rplots.pdf`-artifact-problem

**Ingen breaking changes** til public API — ændringerne er rent test-infrastruktur, CI-tilføjelser og udvidet coverage.

## Impact

**Affected specs:**
- **NEW**: `test-infrastructure` (ny capability, dækker CI, fixtures, mocking, verification, coverage)

**Affected code:**
- `.github/workflows/` — nye CI-workflows (oprettes)
- `tests/testthat/` — omorganisering, nye helpers, nye test-filer, oprydning
- `tests/testthat/fixtures/` — ny mappe med deterministiske golden datasets
- `DESCRIPTION` — flyt `vdiffr`, `pdftools`, `withr` fra Suggests til aktivt brug; potentielt `mockery`/`mockr` tilføjes
- `R/utils_quarto.R`, `R/utils_typst.R` — mindre testbarheds-justeringer (inject-points for system2-mocking hvis nødvendigt)

**Non-impact:**
- Ingen ændringer til public API (`bfh_qic`, `bfh_export_pdf`, etc.)
- Ingen ændringer til eksisterende statistisk logik
- Ingen ændringer til Typst-templates eller rendering-pipeline
- Eksisterende test-filer beholdes (suppleret, ikke erstattet)

**Risiko:**
- CI-opsætning kan afsløre latente miljøafhængigheder — forventeligt, fixable under fase 1
- Font-strategien for CI skal afgøres (install Mari-fonts i CI vs. bruge test-alternativer) — håndteres i design.md
- vdiffr golden images kan give false-positive ved mindre ggplot2-opgraderinger — accepteret trade-off med dokumenteret re-baseline-proces

## Related

- GitHub Issue: [#142](https://github.com/johanreventlow/BFHcharts/issues/142)
- Source reviews: Intern test-review (2026-04-18) + Codex test-review-syntese
- Baseline: BFHcharts v0.8.0
