# Tasks: stabilize-default-test-suite

## 1. Infrastructure

- [x] 1.1 Opret/udvid `tests/testthat/helper-skips.R` med `skip_if_not_render_test()` (fandtes allerede; bekræftet)
- [x] 1.2 Tilføj `skip_if_not_full_test()` helper (fandtes allerede; bekræftet)
- [x] 1.3 Tilføj `skip_if_no_quarto()` helper (wrapper om `quarto_available()`)
- [x] 1.4 Tilføj `skip_if_no_mari_font()` helper (systemfonts-baseret detektion + CI-fallback)
- [x] 1.5 Dokumentér env-var-navne: `BFHCHARTS_TEST_RENDER`, `BFHCHARTS_TEST_FULL`
       (NOTE: eksisterende navne bibeholdt — afveg fra proposal for konsistens med CI og README)

## 2. Audit og migration

- [x] 2.1 Audit alle `test-*.R` filer: `test-export_pdf-content.R`, `test-export_pdf.R`,
       `test-integration-export.R`, `test-security-export-pdf.R`, `test-quarto-isolation.R`
- [x] 2.2 Tilføj `skip_if_not_render_test()` i render-tests (alle PDF/Quarto-tests)
- [x] 2.3 `skip_if_not_full_test()` fandtes allerede i integration-export
- [x] 2.4 Verify `test-export_pdf-content.R` skipper uden env-gate (alle 10 blokke migreret)
- [x] 2.5 Verify `test-quarto-isolation.R` linje 112 migreret til `skip_if_no_quarto()`

## 3. CI

- [x] 3.1 `.github/workflows/R-CMD-check.yaml` sætter `BFHCHARTS_TEST_FULL: "true"` og
       `BFHCHARTS_TEST_RENDER: "true"` (verificeret — allerede implementeret)
- [ ] 3.2 Separat "full-suite" job (ugentlig cron / manual trigger) — UDSAT:
       CI kører allerede fuld suite på hvert check; separat job er fremtidig forbedring
- [x] 3.3 Dokumenteret i `tests/testthat/README.md` (lokal fuld kørsel + env-var tabel)

## 4. Documentation

- [x] 4.1 `tests/testthat/README.md` opdateret med test-tier-tabel og canonical helpers
- [x] 4.2 NEWS.md: testsuite stabilisering tilføjet under v0.8.2 interne ændringer
