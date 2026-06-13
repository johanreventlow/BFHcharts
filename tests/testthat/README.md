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

Workflows og hvilke miljøvariabler de sætter:

| Workflow | `BFHCHARTS_TEST_FULL` | `BFHCHARTS_TEST_RENDER` | Formål |
|----------|-----------------------|-------------------------|--------|
| `R-CMD-check.yaml` | `"true"` | **ikke sat** | R CMD check + testthat (PR-blocking) |
| `pdf-smoke.yaml` | `"true"` | `"true"` | PDF smoke render via Quarto/Typst (PR-blocking) |
| `render-tests.yaml` | `"true"` | `"true"` | Ugentlig live render-test suite (cron) |
| `test-coverage.yml` | ikke sat | ikke sat | covr::codecov() rapportering |
| `lint.yaml` | ikke sat | ikke sat | lintr (advisory) |
| `vdiffr.yaml` | ikke sat | ikke sat | vdiffr visuel regression-tracking, push til develop/main (non-blocking, se nedenfor) |

`BFHCHARTS_TEST_RENDER` er bevidst **ikke sat** i `R-CMD-check.yaml`: production-template render
kræver Mari-fonts (proprietære, kun tilgængelige via BFHchartsAssets). Render-dækning håndteres
af `pdf-smoke.yaml` med åbne fallback-fonts (DejaVu/Liberation).

`pdf-smoke.yaml` installerer Quarto + åbne fallback-fonts (DejaVu, Liberation, Noto).

#### CI Font-fallback strategi

Mari-fonts (BFHtheme) er proprietære og ikke tilgængelige på public GitHub-runners.
CI anvender to komplementære strategier:

**R-CMD-check + pdf-smoke workflows:**
- Installerer åbne fallback-fonts via `apt-get`: DejaVu, Liberation, Liberation2, Noto, Roboto
- `setup.R` registrerer Mari/Arial/Roboto som Helvetica-aliaser i grDevices PS/PDF font-databaser
  (matcher `R/zzz.R register_bfh_font_aliases()`)
- `bfh_export_pdf()` bruger `font_path` til at pege Typst på de installerede åbne fonts
- `ignore_system_fonts=TRUE` (Typst 0.13+) sikrer Typst kun bruger leverede fonts

**vdiffr snapshot-tests:**
- `skip_if_no_mari_font()` per test — skipper på CI (ingen Mari) i R-CMD-check og andre
  standard-workflows. `vdiffr.yaml` sætter `BFHCHARTS_VDIFFR_CI=true` for at
  bypass dette og køre tests med substitute-fonts (regression-detektion).
- Snapshots re-baselinet ved: BFHtheme version-bump (forventede font-metric ændringer),
  bevidst layout-ændring, regression-fix
- Commit-beskeden skal dokumentere årsag ved re-baseline

**Opsummering af skip-logik for font-afhængige tests:**

| Test type | R-CMD-check CI | vdiffr.yaml CI | Lokal (med Mari) |
|-----------|----------------|----------------|-----------------|
| vdiffr snapshots | SKIP | FAIL/PASS (font-diffs forventede) | PASS mod baselines |
| PDF smoke render | PASS (åbne fallback-fonts) | ikke relevant | PASS (Mari) |
| Render-tests (ugentlig) | PASS (åbne fallback-fonts) | ikke relevant | PASS (Mari) |

**vdiffr.yaml er altid rød** pga. font-metric-forskelle mellem Mari-baselines og DejaVu/Liberation
substitute-fonts på CI. Det er korrekt og forventet. Nyt at bekymre sig om: ændringer i
geometri, layer-rækkefølge, label-placering — ikke font-diffs alene.

---

## Miljøvariabler til test-lag-kontrol

| Variabel | Default | Effekt |
|----------|---------|--------|
| `BFHCHARTS_TEST_FULL` | ikke sat | Kører integration-tests ud over unit-tests |
| `BFHCHARTS_TEST_RENDER` | ikke sat | Kører live render-tests (Quarto, PDF, PNG) |
| `BFHCHARTS_VDIFFR_CI` | ikke sat | Bypass CI-skip i `skip_if_no_mari_font()` — bruges kun af `vdiffr.yaml` |

**Status (2026-04-24):** Alle render/PDF-tests er migreret til de kanoniske helpers (`skip_if_not_render_test()` + `skip_if_no_quarto()`). Nye helpers `skip_if_no_quarto()` og `skip_if_no_mari_font()` tilføjet til `helper-skips.R`. Se CI-tabellen ovenfor for hvilke workflows der sætter hvilke variabler.

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
R/bfh_qic.R                ↔ tests/testthat/test-bfh_qic_*.R + test-integration.R
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

## Visuel regression

Vdiffr-snapshots beskytter mod utilsigtede visuelle regressioner i BFHcharts' plot-output.
Golden images er i `tests/testthat/_snaps/visual-regression/`.

**Tests kræver Mari-fonts lokalt.** I standard-CI-workflows (R-CMD-check, pdf-smoke osv.)
skipper `skip_if_no_mari_font()` alle tests når `CI=true` (ingen Mari tilgængelig). Se
CI Font-fallback strategi ovenfor for den dedikerede `vdiffr.yaml`-workflow der kører
tests med substitute-fonts til regression-detektion.

### Snapshot-politik

**`.new.svg` filer commits ALDRIG** — de er temporære review-artefakter (`.gitignore`-listede).
Når en test fejler, genererer vdiffr en `<name>.new.svg` til sammenligning. Workflows:

```r
# Inspicér alle diffs interaktivt
vdiffr::manage_cases()

# Accept alle diffs som nye baselines (efter visuel review)
testthat::snapshot_accept()

# Accept kun visual-regression-filen
testthat::snapshot_accept("visual-regression")
```

**Commits der re-baseliner snapshots SKAL dokumentere årsag i commit-beskeden:**
- BFHtheme version-bump → koordinat-skift er forventede
- Bevidst layout-ændring → beskriv hvad der ændrede sig
- Regression-fix → beskriv hvad der var forkert

### Font-warnings

Under visuel regression-kørsel ses typisk `"font family 'Mari' not found in PostScript font database"`.
Disse er harmlose (ggplot2 falder tilbage til system default) og suppresseres globalt via `setup.R`.
Genuine warnings propageres stadig — kun den specifikke PostScript-lookup-advarsel undertrykkes.

### Tilføjelse af nye snapshots

```r
# 1. Tilføj vdiffr::expect_doppelganger() til test-visual-regression.R
# 2. Kør devtools::test() — første kørsel genererer .svg baseline
# 3. Verificér snapshot visuelt
# 4. Commit .svg filen med begrundelse
```

---

## Referencer

- `openspec/changes/strengthen-test-infrastructure/proposal.md` — løbende forbedringsplan
- `openspec/changes/strengthen-test-infrastructure/design.md` — tekniske beslutninger (D1-D10)
- `openspec/changes/strengthen-test-infrastructure/tasks.md` — opgaver og status

**Sidst opdateret:** 2026-06-12
