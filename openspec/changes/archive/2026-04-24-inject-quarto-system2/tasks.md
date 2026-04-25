# Tasks: inject-quarto-system2

## 1. Implementation

- [x] 1.1 Tilføj `.system2 = system2` parameter til `bfh_compile_typst()`
- [x] 1.2 Tilføj `.quarto_path = NULL` parameter; resolve via `get_quarto_path()` hvis NULL
- [x] 1.3 Opdatér `system2(...)` kald til `.system2(...)` internt
- [x] 1.4 Dokumentér DI-parametre som `@keywords internal` — kun til test
- [x] 1.5 Audit alle steder der spawner external process (find, quarto --version, m.v.) og anvend samme pattern

## 2. Testing

- [x] 2.1 Unit test: mock `.system2` returning success — verify argument construction
- [x] 2.2 Unit test: mock `.system2` returning stderr/stdout — verify error-wrapping
- [x] 2.3 Unit test: mock `.system2` raising error — verify graceful surface
- [x] 2.4 Integration test (env-gated): real Quarto still works
- [x] 2.5 Fjern eller opdatér workaround-kommentarer i `test-quarto-isolation.R`

## 3. Documentation

- [x] 3.1 Test-auteur guide: hvordan mock `.system2` i egne tests
- [x] 3.2 NEWS.md: internal testability improvements (ikke breaking)
