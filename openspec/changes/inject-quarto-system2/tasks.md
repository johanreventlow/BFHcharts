# Tasks: inject-quarto-system2

## 1. Implementation

- [ ] 1.1 Tilføj `.system2 = system2` parameter til `bfh_compile_typst()`
- [ ] 1.2 Tilføj `.quarto_path = NULL` parameter; resolve via `get_quarto_path()` hvis NULL
- [ ] 1.3 Opdatér `system2(...)` kald til `.system2(...)` internt
- [ ] 1.4 Dokumentér DI-parametre som `@keywords internal` — kun til test
- [ ] 1.5 Audit alle steder der spawner external process (find, quarto --version, m.v.) og anvend samme pattern

## 2. Testing

- [ ] 2.1 Unit test: mock `.system2` returning success — verify argument construction
- [ ] 2.2 Unit test: mock `.system2` returning stderr/stdout — verify error-wrapping
- [ ] 2.3 Unit test: mock `.system2` raising error — verify graceful surface
- [ ] 2.4 Integration test (env-gated): real Quarto still works
- [ ] 2.5 Fjern eller opdatér workaround-kommentarer i `test-quarto-isolation.R`

## 3. Documentation

- [ ] 3.1 Test-auteur guide: hvordan mock `.system2` i egne tests
- [ ] 3.2 NEWS.md: internal testability improvements (ikke breaking)
