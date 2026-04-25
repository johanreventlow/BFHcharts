# stabilize-default-test-suite

## Why

`devtools::test()` er ikke stabil som default i alle udviklingsmiljøer —
codex-review noterede PDF/Quarto-test-fejl (`test-export_pdf-content.R`).
`tests/testthat/README.md:17` anerkender selv at tunge render/export tests
bør skippe automatisk, men gate-infrastruktur er inkonsistent.

Konsekvens: udviklere mister tillid til testrunneren, TDD-reglen svækkes,
og CI vs. lokale kørsler divergerer.

## What Changes

- Indfør konsekvente `skip_if_*` helpers:
  - `skip_if_not_render_test()` (PDF/Quarto/visual render)
  - `skip_if_not_full_test()` (heavy export chains)
  - `skip_if_no_quarto()` (binary check)
  - `skip_if_no_mari_font()` (visual regression)
- Environment-variabler: `BFHCHARTS_RUN_RENDER_TESTS`, `BFHCHARTS_RUN_FULL_TESTS`
- Audit alle tests og anvend gates konsekvent
- Dokumentér test-tiers i `tests/testthat/README.md`
- Default `devtools::test()` SKAL kunne køres på ethvert dev-miljø uden external deps

## Impact

**Affected specs:**
- `test-infrastructure`

**Affected code:**
- `tests/testthat/helper-skip.R` (ny eller udvidet)
- Alle test-filer der kalder Quarto/render/PDF/PNG
- `tests/testthat/README.md`
- CI-workflows (sætter env-vars)

**User-visible changes:**
- Ingen runtime-ændringer
- Udviklere får konsistent, reproducerbart default-test-run

## Related

- Codex review issue #3 (testsuite ikke stabil)
- `tests/testthat/README.md:17` (eksisterende erkendelse af problem)
