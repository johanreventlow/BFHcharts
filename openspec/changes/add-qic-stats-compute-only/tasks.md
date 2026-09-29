## 1. Tests foerst (TDD)

- [x] 1.1 Skriv aekvivalenstest: `bfh_qic_stats()` vs `bfh_qic()` -> `identical()` summary og qic_data for alle `CHART_TYPES_EN`
- [x] 1.2 Udvid med `part`, `freeze`, `exclude`, brugerdefineret `cl`, naevner og en auto-mean-udloesende run-serie
- [x] 1.3 Test: intet `plot`-element, `is_bfh_qic_result()` er FALSE, `bfh_extract_spc_stats()` giver samme liste

## 2. Intern opdeling af bfh_qic

- [x] 2.1 Flyt beregningsfasen (validering, qicharts2/pbcharts, auto-mean, cl-advarsel, summary) til intern hjaelper
- [x] 2.2 NSE-fangst forbliver i den eksporterede funktion; hjaelperen faar udtryk + miljoe
- [x] 2.3 Verificér: hele testpakken uaendret groen. De visuelle snapshots kraever Mari-fonten og skippes uden den; i stedet er 20 grafer renderet til SVG med baade develop og branchen i samme miljoe og sammenlignet byte-for-byte (identiske), og summary/qic_data/config/lag-data er identical()

## 3. bfh_qic_stats

- [x] 3.1 `R/bfh_qic_stats.R`: funktion, konstruktor, print-metode
- [x] 3.2 `bfh_extract_spc_stats.bfh_qic_stats()`
- [x] 3.3 Roxygen + `@examples`; `devtools::document()`
- [x] 3.4 ASCII-politik (`test-source-ascii.R`)

## 4. Version + verifikation

- [x] 4.1 NEWS-entry i development-sektionen (MINOR bump 0.30.0 -> 0.31.0 sker i release-PR'en develop -> main)
- [x] 4.2 Tidsmaaling `bfh_qic()` vs `bfh_qic_stats()` paa 36-punkts serie, noteret i PR
- [x] 4.3 Fuld testpakke groen
