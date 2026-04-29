# Tasks: add-pr-blocking-pdf-smoke-render

## Status: Implemented (2026-04-29)

---

## Task 1: Resolve vdiffr failures

- [x] 1.1 Kør `devtools::test(filter = "visual-regression")` — 9 failures identificeret
- [x] 1.2 Verificér at failures skyldes font-metric drift (Roboto-alias i v0.10.5) via SVG-diff
- [x] 1.3 Acceptér alle 9 snapshots (kopier `.new.svg` over `.svg`) — font-drift er intentionel

## Task 2: CI fallback-font path

- [x] 2.1 Sync `tests/testthat/setup.R` font-alias-sæt med `R/zzz.R`
      (tilføj Roboto til `c("Mari", "Arial")` → `c("Mari", "Arial", "Roboto")`)
- [x] 2.2 Tilføj `skip_if_no_pdf_render_deps()` til `tests/testthat/helper-skips.R`
      (tjekker `BFHcharts:::quarto_available()` + `pdftools` tilgængelighed)
- [x] 2.3 Konverter `test-visual-regression.R:28` fil-scope `skip_if_fonts_unavailable()`
      til per-test `skip_if_no_mari_font()` på alle 9 tests

## Task 3: PR-blocking smoke-render workflow

- [x] 3.1 Opret `.github/workflows/pdf-smoke.yaml`
      (trigger: pull_request branches main/develop + workflow_dispatch)
- [x] 3.2 Installer fallback-fonts + Quarto pre-release i workflow
- [x] 3.3 Kald `Rscript tests/smoke/render_smoke.R` som CI-step

## Task 4: Smoke-render fixtures

- [x] 4.1 Opret `tests/smoke/render_smoke.R`
- [x] 4.2 3 repræsentative kald: p-chart (eksempeldata), i-chart (metadata), run-chart (target)
- [x] 4.3 Assertions: file.exists(), file.size() > 0, pdftools::pdf_info()$pages >= 1
- [x] 4.4 Cleanup via on.exit()
- [x] 4.5 BFHCHARTS_SMOKE_FONT_PATH env-var for CI font-path override

## Task 5: Deferred

- [ ] 5.1 Lokal smoke-render kørsel verificeret — kræver Quarto og Typst >= 0.13 (ikke tilgængeligt lokalt)

## Task 6: Dokumentation

- [x] 6.1 Opdatér `tests/testthat/README.md` med CI font-fallback strategi
- [x] 6.2 NEWS entry under `## CI`

## Manuel follow-up (kræves af ejer)

- [ ] M1 Tilføj "pdf-smoke (ubuntu-latest)" til required-status-checks i
      branch protection rules for `main` og `develop` på GitHub:
        Settings → Branches → Branch protection rules → [main/develop]
        → "Require status checks to pass before merging"
        → Søg og tilføj: "pdf-smoke (ubuntu-latest)"

## DESCRIPTION bump

- [x] D1 Version: 0.10.5 → 0.10.6
