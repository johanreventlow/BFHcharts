# inject-quarto-system2

## Why

`bfh_compile_typst()` kalder `system2(get_quarto_path(), ...)` direkte
(`R/utils_typst.R:231`). Det betyder:

- Unit tests kan ikke isoleres fra Quarto-installation
- Fejl i Quarto (manglende binary, arkitektur-mismatch, miljø) lækker direkte til testrunner
- CI/Mac/Linux forskelle giver uklare brugerfejl
- PDF/Quarto-tests fejlede i codex-review-miljø under standard `devtools::test()`

Dependency injection af `system2` og quarto-path som interne parametre
gør compile-logikken testbar i isolation, uden at faktisk Quarto køres.

## What Changes

- Tilføj `.system2 = system2` og `.quarto_path = get_quarto_path` parameter-hooks på `bfh_compile_typst()`
- Parametre markeres `@keywords internal` og dokumenteres som DI-hooks kun til test
- Opdatér kald internt (primært tests) til at injicere mocks
- Tilføj testsuite-dækning for compile-logic uden faktisk Quarto

## Impact

**Affected specs:**
- `pdf-export`
- `test-infrastructure`

**Affected code:**
- `R/utils_typst.R` (bfh_compile_typst signatur)
- `R/utils_quarto.R` (hvis relevant)
- `tests/testthat/test-quarto-isolation.R` (nye unit tests med mocks)

**User-visible changes:**
- Ingen — public API uændret (DI-parametre er interne)

## Related

- Codex review issue #4 (dependency injection for Quarto)
- `tests/testthat/test-quarto-isolation.R:303` (noterer selv problemet)
