## 1. Dependency + chart-type registrering

- [ ] 1.1 Find pbcharts release-tag/SHA (`git ls-remote --tags https://github.com/anhoej/pbcharts`) og notér pin
- [ ] 1.2 Tilfoej `Suggests: pbcharts` + `Remotes: anhoej/pbcharts@<pin>` i `DESCRIPTION`
- [ ] 1.3 Tilfoej `"i'"` til `CHART_TYPES_EN` i `R/chart_types.R`
- [ ] 1.4 Verificér `devtools::load_all()` + at `"i'"` accepteres af `validate_chart_type`-stien (ingen "invalid chart_type")

## 2. Adapter-helpers (TDD — tests foerst)

- [ ] 2.1 Skriv test: `build_pbc_args()` mapper y->num, n->den, part->split, target_value->target, freeze, exclude, cl, multiply, percent->ypct
- [ ] 2.2 Implementér `build_pbc_args()` i `R/utils_bfh_qic_helpers.R` (`@keywords internal @noRd`)
- [ ] 2.3 Skriv test: `invoke_pbcharts()` stop'er med install-hint naar pbcharts mangler (`skip_if_not_installed` for happy-path)
- [ ] 2.4 Implementér `invoke_pbcharts()` med `requireNamespace`-guard, `do.call(pbcharts::pbc, ..., envir)`, extract `$data`
- [ ] 2.5 Skriv test: `map_pbc_to_qic_data()` saetter `n <- den` og notes via x-lookup (inkl. shuffled-orden case)
- [ ] 2.6 Implementér `map_pbc_to_qic_data()` (n<-den, notes-lookup, kontrakt-verifikation)

## 3. bfh_qic branch

- [ ] 3.1 Skriv test: `bfh_qic(chart_type="i'")` returnerer gyldigt `bfh_qic_result` (default) + raa data.frame (`return.data=TRUE`)
- [ ] 3.2 Tilfoej branch i `R/bfh_qic.R` foer `build_qic_args()`: rut `"i'"` til pbc-sti (build_pbc_args -> invoke_pbcharts -> map_pbc_to_qic_data -> add_anhoej_signal)
- [ ] 3.3 Tilfoej guards: `n=NULL` -> `message()` om degenerering; non-default `agg.fun` -> `warning()`
- [ ] 3.4 Verificér auto-mean-stien forbliver inert for `"i'"` (ingen aendring i `detect_majority_at_median_per_phase`)

## 4. Statistisk integritet + acceptance-tests

- [ ] 4.1 Test: `bfh_qic(chart_type="i'")$qic_data` har `cl/ucl/lcl` `identical` til `pbcharts::pbc()`'s egne vaerdier
- [ ] 4.2 Test: varierende `n` -> ikke-konstant `ucl`/`lcl`; konstant/manglende `n` -> konstante graenser
- [ ] 4.3 Test: `runs.signal` mappes korrekt til `anhoej.signal` via `add_anhoej_signal()`
- [ ] 4.4 Test: notes-annotation renderer paa korrekt x-punkt under shuffled input-orden
- [ ] 4.5 Test: kontrakt-fuldstaendighed (alle downstream-laeste kolonner til stede)

## 5. Dokumentation + ASCII-policy

- [ ] 5.1 Opdatér roxygen for `chart_type`-param: tilfoej `"i'"` + note om ratio-semantik (y=taeller, n=naevner, plot=y/n; modsat `"i"`)
- [ ] 5.2 Tilfoej `@examples`-afsnit med `chart_type = "i'"` + varierende `n`
- [ ] 5.3 Kreditér pbcharts i `R/BFHcharts-package.R` / `DESCRIPTION`
- [ ] 5.4 `devtools::document()` (regenerér NAMESPACE/.Rd)
- [ ] 5.5 Verificér ny R-kode passerer `test-source-ascii.R` (apostrof i `"i'"` er ASCII; ingen UTF-8 i kommentarer)

## 6. Versionering + verifikation

- [ ] 6.1 Bump `Version:` i `DESCRIPTION` (MINOR)
- [ ] 6.2 Tilfoej NEWS.md-entry under `## Nye features`
- [ ] 6.3 `devtools::test()` — alle tests bestaaet (pbcharts-tests via `skip_if_not_installed`)
- [ ] 6.4 `devtools::check()` — ren (ingen WARNING/ERROR; NOTEs dokumenteret)
- [ ] 6.5 Aabn draft-PR mod `develop` med `closes`-reference til evt. issue
