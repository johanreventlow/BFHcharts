# Tasks: stabilize-default-test-suite

## 1. Infrastructure

- [ ] 1.1 Opret/udvid `tests/testthat/helper-skip.R` med `skip_if_not_render_test()`
- [ ] 1.2 Tilføj `skip_if_not_full_test()` helper
- [ ] 1.3 Tilføj `skip_if_no_quarto()` helper (wrapper om existing quarto check)
- [ ] 1.4 Tilføj `skip_if_no_mari_font()` helper
- [ ] 1.5 Dokumentér env-var-navne: `BFHCHARTS_RUN_RENDER_TESTS`, `BFHCHARTS_RUN_FULL_TESTS`

## 2. Audit og migration

- [ ] 2.1 Audit alle `test-*.R` filer: list alle der kalder Quarto/system2/ggsave
- [ ] 2.2 Tilføj `skip_if_not_render_test()` i render-tests
- [ ] 2.3 Tilføj `skip_if_not_full_test()` i heavy export-chains
- [ ] 2.4 Verify `test-export_pdf-content.R` skipper uden env-gate
- [ ] 2.5 Verify `test-quarto-isolation.R` skipper uden quarto

## 3. CI

- [ ] 3.1 Opdatér `.github/workflows/R-CMD-check.yml` til at sætte render-gate env-var
- [ ] 3.2 Tilføj separat "full-suite" job (ugentlig cron eller manual trigger)
- [ ] 3.3 Dokumentér i README hvordan full suite køres lokalt

## 4. Documentation

- [ ] 4.1 Opdatér `tests/testthat/README.md` med test-tier-tabel
- [ ] 4.2 NEWS.md: testsuite stabilisering (internal)
