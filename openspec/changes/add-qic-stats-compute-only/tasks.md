## 1. Tests foerst (TDD)

- [ ] 1.1 Skriv aekvivalenstest: `bfh_qic_stats()` vs `bfh_qic()` -> `identical()` summary og qic_data for alle `CHART_TYPES_EN`
- [ ] 1.2 Udvid med `part`, `freeze`, `exclude`, brugerdefineret `cl`, naevner og en auto-mean-udloesende run-serie
- [ ] 1.3 Test: intet `plot`-element, `is_bfh_qic_result()` er FALSE, `bfh_extract_spc_stats()` giver samme liste

## 2. Intern opdeling af bfh_qic

- [ ] 2.1 Flyt beregningsfasen (validering, qicharts2/pbcharts, auto-mean, cl-advarsel, summary) til intern hjaelper
- [ ] 2.2 NSE-fangst forbliver i den eksporterede funktion; hjaelperen faar udtryk + miljoe
- [ ] 2.3 Verificér: hele testpakken + visuelle snapshots uaendret groenne

## 3. bfh_qic_stats

- [ ] 3.1 `R/bfh_qic_stats.R`: funktion, konstruktor, print-metode
- [ ] 3.2 `bfh_extract_spc_stats.bfh_qic_stats()`
- [ ] 3.3 Roxygen + `@examples`; `devtools::document()`
- [ ] 3.4 ASCII-politik (`test-source-ascii.R`)

## 4. Version + verifikation

- [ ] 4.1 MINOR bump 0.30.0 -> 0.31.0, NEWS-entry
- [ ] 4.2 Tidsmaaling `bfh_qic()` vs `bfh_qic_stats()` paa 36-punkts serie, noteret i PR
- [ ] 4.3 Fuld testpakke groen
