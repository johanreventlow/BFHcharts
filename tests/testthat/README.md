# BFHcharts Test Suite

Dokumentation af test-strategi, kørselsmodus og skip-politik for BFHcharts' testsuite.

Se også: `openspec/changes/strengthen-test-infrastructure/` for den løbende test-infrastruktur-forbedringsplan.

---

## Kørsel af tests

### Lokal udvikling (hurtige tests)

```r
devtools::test()
```

Standard-kørsel uden miljøvariabler kører hurtige unit-tests. Tunge render-/eksport-tests skippes automatisk.

### Fuld lokal kørsel

```r
Sys.setenv(BFHCHARTS_TEST_FULL = "true")
Sys.setenv(BFHCHARTS_TEST_RENDER = "true")
devtools::test()
```

Kører alle tests, inklusive live Quarto PDF-rendering. Kræver lokal Quarto-installation (≥1.4.0).

### Enkelt testfil

```r
testthat::test_file("tests/testthat/test-spc_analysis.R")
```

### CI (GitHub Actions)

CI kører automatisk med begge miljøvariabler sat til `"true"` og installerer Quarto + åbne fallback-fonts (DejaVu, Liberation, Noto).

Workflows:
- `.github/workflows/R-CMD-check.yml` — R CMD check + testthat
- `.github/workflows/test-coverage.yml` — covr::codecov() rapportering
- `.github/workflows/lint.yml` — lintr (advisory)

---

## Miljøvariabler til test-lag-kontrol

| Variabel | Default | Effekt |
|----------|---------|--------|
| `BFHCHARTS_TEST_FULL` | ikke sat | Kører integration-tests ud over unit-tests |
| `BFHCHARTS_TEST_RENDER` | ikke sat | Kører live render-tests (Quarto, PDF, PNG) |

**Status (2026-04-24):** Alle render/PDF-tests er migreret til de kanoniske helpers (`skip_if_not_render_test()` + `skip_if_no_quarto()`). Nye helpers `skip_if_no_quarto()` og `skip_if_no_mari_font()` tilføjet til `helper-skips.R`. Miljøvariablerne er sat i CI.

---

## Skip-politik

### Kanoniske skip-helpers (kilde: `helper-skips.R`)

Alle skip-helpers er centraliseret i `tests/testthat/helper-skips.R`. Brug kun dem — bespoke skip-logik i individuelle testfiler er et anti-mønster.

| Helper | Gate | Brug |
|--------|------|------|
| `skip_if_not_render_test()` | `BFHCHARTS_TEST_RENDER=true` | PDF/Quarto/Typst render-tests |
| `skip_if_not_full_test()` | `BFHCHARTS_TEST_FULL=true` | Tunge integration-/export-kæder |
| `skip_if_no_quarto()` | Quarto CLI binær til stede | Sekundær check efter env-gate |
| `skip_if_no_mari_font()` | Mari-fonts installeret | Font-afhængig rendering |
| `skip_if_fonts_unavailable()` | CI-detektion (legacy) | Bevar for eksisterende tests |
| `skip_on_cran()` | CRAN-check | Fil-system-writes, live renders |
| `skip_if(!file.exists(...))` | Fixture-fil | Template-parsing tests |

**Render-tests (PDF/Quarto) bruger altid to gates i denne rækkefølge:**
```r
skip_if_not_render_test()  # env-gate — hurtig exit hvis ikke sat
skip_if_no_quarto()        # binær check — Quarto CLI til stede?
skip_on_cran()             # CRAN-sikring
```

### Font-afhængige tests

Tests der kræver Mari-fonts (BFHtheme) bruger `skip_if_fonts_unavailable()` (eksisterende tests) eller `skip_if_no_mari_font()` (nye tests). Sidstnævnte bruger faktisk font-detektion via `systemfonts::system_fonts()` hvis tilgængeligt.

### Anti-mønstre der IKKE accepteres

- ❌ `skip_if_not_installed("qicharts2")` — qicharts2 er hard `Imports`. Skipping maskerer setup-fejl. **FJERNET 2026-04-18** (Fase 1 task 2.1).
- ❌ `skip_on_ci()` uden inline begrundelse — skal altid have `# Reason: ...` kommentar.
- ❌ Blanket `suppressWarnings()` uden dokumentation — erstattes gradvist med `expect_warning(..., regexp = NA)` (Fase 2 task 11.3).

---

## Test-fil-struktur

Aktuelt er 1-til-1 mapping mellem `R/<module>.R` og `tests/testthat/test-<module>.R`:

```
R/create_spc_chart.R       ↔ tests/testthat/test-bfh_qic_*.R + test-integration.R
R/spc_analysis.R           ↔ tests/testthat/test-spc_analysis.R
R/plot_core.R              ↔ tests/testthat/test-plot_core.R
R/export_pdf.R             ↔ tests/testthat/test-export_pdf*.R
...
```

**Pågående omorganisering (Fase 1 task 3):** Store testfiler splittes efter funktionsgruppe:
- `test-export_pdf.R` (1739 linjer) → validation / rendering / metadata / spc-stats
- `test-spc_analysis.R` (597 linjer) → context / pick-text / fallback-analysis / resolve-target
- `test-y_axis_formatting.R` (651 linjer) → logiske underfiler

---

## Testdata og fixtures

**Aktuel tilstand:** Testdata genereres inline i hver testfil. Fælles fixture-helpers som `make_qic_data()`, `make_fixture_result()`, `make_ctx()`, `create_test_chart()`, `setup_test_data()` er duplikeret lokalt.

**Pågående centralisering (Fase 2 task 6):**
- `tests/testthat/setup.R` — locale/timezone/RNGkind-kontrol
- `tests/testthat/helper-fixtures.R` — konsoliderede factories
- `tests/testthat/helper-mocks.R` — mock-factories for Quarto, system2, BFHllm
- `tests/testthat/helper-assertions.R` — custom expectations
- `tests/testthat/fixtures/` — deterministiske golden datasets

---

## Coverage-mål

- **≥90%** samlet pakke-coverage
- **100%** på eksporterede funktioner
- **Statistisk accuracy**: alle control-limit-beregninger verificeret numerisk (Fase 2 task 8)

Coverage måles via `covr::package_coverage()` og rapporteres til Codecov på hvert push/PR.

```r
# Lokal coverage-kørsel
cov <- covr::package_coverage()
covr::report(cov)
```

---

## Visuel regression (planlagt — Fase 2 task 7)

Når vdiffr integreres, tilføjes golden images i `tests/testthat/_snaps/` for kanoniske chart-konfigurationer.

**Re-baseline-proces** (kør kun efter manuel visuel review):

```r
testthat::snapshot_accept()  # Accept alle diffs
# eller
testthat::snapshot_accept("test-visual-regression")  # Kun specifik fil
```

Commits der re-baseliner golden images SKAL have dokumenteret begrundelse i commit-besked.

---

## Referencer

- `openspec/changes/strengthen-test-infrastructure/proposal.md` — løbende forbedringsplan
- `openspec/changes/strengthen-test-infrastructure/design.md` — tekniske beslutninger (D1-D10)
- `openspec/changes/strengthen-test-infrastructure/tasks.md` — opgaver og status

**Sidst opdateret:** 2026-04-24
