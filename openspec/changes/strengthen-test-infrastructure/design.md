## Context

BFHcharts er en hjælpepakke til biSPCharts-Shiny-appen med ~10.500 linjer kildekode, ~780 test_that-blokke og 35 testfiler. Pakken er versioneret som "Status: Production" (CLAUDE.md) med bruger-krav om ≥90% coverage og 100% på eksporterede funktioner (DEVELOPMENT_PHILOSOPHY.md).

To uafhængige reviews konvergerer på at test-suitens *operative modenhed* ikke matcher produktionsbetegnelsen. Specifikt er der huller i CI-automation, visuel regression, ekstern isolation, content-verifikation og statistisk accuracy-verifikation.

**Begrænsninger:**
- Manglende `gh` CLI på Windows-arbejdspladser (enkelte udviklere) — CI skal derfor være self-contained
- Mari-fontafhængighed i BFHtheme gør font-rendering miljøfølsom
- Quarto CLI som SystemRequirement giver krav om hvordan CI installerer det
- qicharts2 er hard Imports — tests skal respektere dette

**Stakeholders:**
- Pakke-vedligeholder (Johan Reventlow)
- biSPCharts-app-udviklere (downstream dependents)
- Kliniske brugere (slut-konsumenter via app)

## Goals / Non-Goals

**Goals:**
- Automatiseret merge-gate via GitHub Actions på hver PR
- Reducer miljøfølsomhed i testsuite så >95% af tests kan køres pålideligt på CI
- Faktisk content-verifikation af genererede PDF/PNG-output
- Numerisk verificerede statistiske beregninger for alle chart-typer i pakken
- Centraliserede, genbrugelige fixtures der reducerer test-maintenance
- Visuel regression-beskyttelse for ggplot-rendering
- Ekstern isolation så Quarto/system2/BFHllm-stier testes uden live-afhængigheder
- Coverage ≥90% på pakke-niveau, 100% på eksporterede funktioner (som målsætning i project.md)

**Non-Goals:**
- Breaking changes til public API
- Ændring af Typst-templates eller rendering-pipeline
- Migrering til en anden SPC-beregningspakke (qicharts2 forbliver)
- End-to-end-tests af biSPCharts-appen (hører hjemme i app-repoet)
- Deprecation/fjernelse af eksisterende tests (tilføjer, reorganiserer, styrker)
- Omskrivning af kernelogik "for at gøre den mere testbar" — mindre testbarheds-injection points accepteres, større arkitektur-ændringer udskydes

## Decisions

### D1: GitHub Actions som CI-platform

**Beslutning**: Brug GitHub Actions med `r-lib/actions/setup-r-dependencies` og `r-lib/actions/check-r-package`.

**Begrundelse**: Repoet er på GitHub. Native integration, gratis for offentlige repos. `r-lib/actions` er de facto standard for R-pakker og håndterer `renv` / DESCRIPTION-baserede dependencies out-of-the-box.

**Alternativer overvejet**:
- GitLab CI: Ikke relevant (repo er på GitHub)
- CircleCI: Ekstra konto-overhead, ingen fordel
- Manuel pre-commit hooks: Gate skal være remote og uafhængig af udvikler-miljø

### D2: Test-lag-opdeling via miljøvariabel

**Beslutning**: Introducer test-lag via miljøvariabler:
- Default (intet sat): Kører hurtige unit-tests (< 10s samlet)
- `BFHCHARTS_TEST_FULL=true`: Kører også integration-tests
- `BFHCHARTS_TEST_RENDER=true`: Kører også live render-tests (kræver Quarto + fonts)
- CI kører alle lag efter installation af eksterne afhængigheder

**Begrundelse**: Udviklere kan iterere hurtigt lokalt uden at skulle skippe tests manuelt. CI kører fuldt. Ingen tvungne afhængigheder lokalt.

**Alternativer overvejet**:
- `skip_on_cran()` (eksisterende mønster): Utilstrækkeligt — dækker ikke "fast local" vs "full".
- Separate test-mapper (`tests/fast/`, `tests/slow/`): Bryder testthat-konventioner, mere friktion.

### D3: Font-strategi i CI

**Beslutning**: Installer Mari-font (eller ækvivalent åben font-fallback) i CI-workflow via eksplicit `apt install` eller download-step. Fallback-logik i `BFHtheme` bruges som sekundær beskyttelse.

**Begrundelse**: At beholde `skip_on_ci()` silent-skip er uacceptabelt — 17+ tests ville usynligt passere når CI aktiveres. Mari-fonts er licenseret til BFH; CI-workflow bruger åbne alternativer der tester *rendering-pipelinen* ikke *eksakt font-match*.

**Alternativer overvejet**:
- Beholde `skip_on_ci()`: Giver falsk "grøn" status → afvises
- Browser-rendering i headless-mode: Over-engineered for package-level tests

**Open question**: Om Mari-font kan distribueres i CI via encrypted secret? → Besluttes under Fase 1 implementation; default-tilgang er åben fallback-font.

### D4: Mocking-framework

**Beslutning**: Brug `mockery` (eller indbygget `withr::with_mocked_bindings` hvis R ≥ 4.4) til at mocke `system2()`, `quarto_available()`, `BFHllm::*` og lignende grænseflader.

**Begrundelse**: `mockery` er standard-mocking-pakke i R-økosystemet, veltestet, minimal overhead. Giver klar adskillelse mellem unit- og integration-tests.

**Alternativer overvejet**:
- `testthat::local_mocked_bindings`: Nyere testthat 3.2+ feature; bruges hvor muligt. `mockery` som fallback for ældre R.
- Manuel `assign()`-patching: Skrøbeligt, ikke anbefalet.

### D5: Visuel regression via vdiffr

**Beslutning**: Brug `vdiffr::expect_doppelganger()` med én golden image pr. (chart-type × y-unit)-kombination. Golden images gemmes i `tests/testthat/_snaps/`. Re-baseline via `testthat::snapshot_accept()`.

**Begrundelse**: `vdiffr` er allerede i Suggests. Testthat 3 edition er aktiveret. Standard mønster i ggplot-økosystemet. SVG-baserede snapshots er tekstfiler → git-venlige diffs.

**Re-baseline-proces (dokumenteres)**:
1. Manuel visuel gennemgang af diff
2. Bevidst acceptance via `testthat::snapshot_accept()`
3. Commit dokumenteret med begrundelse

**Alternativer overvejet**:
- Pixel-diff via `magick`: Binært format, dårlig diff-oplevelse
- PNG-checksums: For skrøbelig over forskellige graphics devices

### D6: Statistisk accuracy via golden fixtures

**Beslutning**: Opret `tests/testthat/fixtures/statistical_cases.rds` med 10-15 kendte cases hvor UCL/LCL/centerlinje er beregnet manuelt efter standardformler og dokumenteret. Tests verificerer `bfh_qic`-output matcher disse med tolerance `1e-6`.

**Begrundelse**: Fanger to risici — (a) fejl i egen logik, (b) ændring i qicharts2's outputsemantik ved version-upgrades.

**Format**:
```r
# fixtures/statistical_cases.rds
list(
  p_chart_standard = list(
    input = data.frame(...),
    expected = list(cl = 0.100, ucl = 0.190, lcl = 0.010),
    reference = "Montgomery SPC ch. 7, example 7.1"
  ),
  ...
)
```

### D7: PDF-indholdsverifikation-omfang

**Beslutning**: `pdftools::pdf_text()` bruges til at verificere at:
1. Chart-titel findes i PDF
2. Hospital-string findes (hvis leveret)
3. Department-string findes (hvis leveret)
4. Data-definition findes (hvis leveret)
5. Summary-tabel har forventede statistik-rækker

**Ikke-mål**: Pixel-perfekt layout-verifikation (overlader til vdiffr for PNG'en)

**Begrundelse**: Fanger encoding-bugs (æøå), template-regressioner, og metadata-flow-bugs uden at være skrøbelig over for layout-ændringer.

### D8: Deterministiske testdata via håndlavede vektorer

**Beslutning**: For tests der verificerer specifikke numeriske værdier: erstat `rnorm()/rpois()` + `set.seed()` med håndlavede vektorer. Bevares `set.seed()` kun for tests der verificerer *strukturelle* invariants (kolonner eksisterer, type er rigtig).

**Begrundelse**: `set.seed()`-baseret determinisme er skrøbelig over R RNG-ændringer (som skete mellem R 3.6 og 4.0). Håndlavede data giver eksplicit dokumenteret intent.

### D9: Kvalitetsgates i CI

**Beslutning**: CI-failure-kriterier:
- `R CMD check` med `--as-cran` på mindst Ubuntu-latest + R-release (required)
- `devtools::test()` på ubuntu/macos/windows × R-release (required)
- Coverage < 85% → warning (ikke fail, første iteration). Efter 3 måneder → required ≥90%
- `lintr::lint_package()` warnings rapporteres men fejler ikke initielt
- Breaking spec-delta-validering (`openspec validate --strict`) SKAL passere

### D10: Centraliserede fixtures-struktur

**Beslutning**:
```
tests/testthat/
├── setup.R                    # Locale, TZ, RNGkind, temp-dir cleanup
├── helper-fixtures.R          # make_qic_data, make_fixture_result, create_test_chart
├── helper-mocks.R             # mock_quarto_available, mock_system2, etc.
├── helper-assertions.R        # expect_valid_bfh_qic_result(), custom expectations
├── fixtures/
│   ├── golden_datasets.rds    # Deterministiske test-inputs
│   ├── statistical_cases.rds  # Kendte UCL/LCL cases
│   └── README.md              # Format og generation-proces
├── _snaps/                    # vdiffr golden images (auto-genereret)
└── test-*.R                   # Eksisterende tests (gradvist opdateres)
```

## Risks / Trade-offs

| Risiko | Sandsynlighed | Impact | Mitigering |
|--------|---------------|--------|------------|
| CI afslører latente bugs der blokker merge | Høj | Medium | Fase 1 accepterer at nye tests først kan være `continue-on-error`; eskalér til required gate efter grøn baseline |
| vdiffr golden images bryder ved ggplot2-upgrade | Medium | Lav | Dokumenteret re-baseline-proces; månedlig manuel verifikation |
| CI-tid bliver for lang (>10 min) | Medium | Medium | Cache `renv`, parallel jobs, test-lag-opdeling (D2) |
| Mari-font-strategi i CI er kompleks | Medium | Lav | Start med åben fallback (D3); revurder hvis skarpere match nødvendigt |
| Statistisk fixtures divergerer fra qicharts2 ved upgrades | Lav | Medium | Dokumenter qicharts2-version ved baseline; eksplicit version-pin i CI indtil re-verificeret |
| Eksisterende stale tests afsløres i bredt omfang | Medium | Medium | Fase 1 inkluderer "ret stale forventninger" som eksplicit task |

## Migration Plan

**Fase 1 (uge 1-2)**: CI + miljøportabilitet + content-verifikation
- Opret `.github/workflows/R-CMD-check.yml`
- Opret `.github/workflows/test-coverage.yml`
- Installer Quarto + åbne fonts i CI
- Fjern `skip_if_not_installed("qicharts2")`
- Split `test-export_pdf.R`
- Ret stale forventninger (`test-export_pdf.R:421`)
- Tilføj `pdftools` til Imports/Suggests og implementér PDF-content-tests
- Baseline CI grøn før progression

**Fase 2 (uge 3-5)**: Kvalitetsinfrastruktur
- Opret `helper-*.R`, `setup.R`, `fixtures/`
- Migrer lokale `make_*`-helpers til centrale
- Tilføj vdiffr golden images pr. chart-type
- Tilføj statistisk accuracy-suite med kendte cases
- Tilføj integration-tests for manglende chart-typer
- Mock BFHllm-path
- Opdel test-lag via miljøvariabler

**Fase 3 (uge 6-8)**: Fuld modenhed
- Matrix CI (Ubuntu/macOS/Windows × R-release/oldrel/devel)
- Performance-smoke-tests
- NA-handling-suite
- Warning-oprydning og Rplots.pdf-artifact-fix

**Rollback**: Hvis fase 1 afslører større issues end forventet, kan CI-gate demoteres fra required til advisory i op til 4 uger mens årsager adresseres. Test-filerne har ingen run-time impact på pakken.

## Open Questions

1. Skal Mari-font distribueres til CI via GitHub Secrets (encrypted), eller er åben fallback-font tilstrækkelig? → Besluttes under Fase 1
2. Hvilken R-version skal være "primary" i CI? Forslag: R-release (nyeste stable). Matrix udvides i Fase 3.
3. Skal coverage-threshold håndhæves fra start eller gradvist? Forslag: advisory i 3 mdr → required ≥90%.
4. Skal `mockery` tilføjes som Suggest, eller bruges kun `testthat::local_mocked_bindings` (testthat 3.2+)? Forslag: Foretræk testthat native; tilføj `mockery` kun hvis nødvendigt for ældre R-support.
