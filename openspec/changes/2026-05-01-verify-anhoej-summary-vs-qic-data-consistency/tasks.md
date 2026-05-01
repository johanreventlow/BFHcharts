## 1. Verificér aktuel divergens

- [x] 1.1 Konstruér testdata med kendte Anhøj-signaler (8 punkter samme side, 0 crossings i en fase)
- [x] 1.2 Kør `bfh_qic()` med `part = c(...)` og inspicér både `result$summary$laengste_loeb` og `max(qic_data$longest.run)` per fase
- [x] 1.3 Test også for `n.crossings` og `runs.signal` / `sigma.signal`
- [x] 1.4 Dokumentér konkret divergens (eller ækvivalens) i issue-tråd
      **Resultat:** `sigma.signal` divergerede — tager første rækkes værdi i stedet for `any()` per fase. `longest.run`, `n.crossings`, `runs.signal` var allerede konsistente.

## 2. Beslut Option A vs B

- [x] 2.1 Hvis qicharts2 returnerer per-row `longest.run` der korrekt aggregerer per fase via `max()`: vælg Option A (fjern genberegning)
      **Resultat:** `longest.run` er konstant per fase → `safe_max()` er korrekt → Option B (behold + fix sigma)
- [-] 2.2 Hvis qicharts2 returnerer globalt tal og lokal beregning er nødvendig per fase: vælg Option B (dokumentér + sanity-check)
      **Valgt Option B** med fix af `sigma.signal`-aggregeringen
- [x] 2.3 Dokumentér beslutning i `docs/adr/ADR-002-anhoej-summary-source.md`

## 3. Konsistens-tests

- [x] 3.1 Opret `tests/testthat/test-summary-anhoej-consistency.R`
- [x] 3.2 Test: `result$summary$laengste_loeb[i]` == per-fase aggregering af `result$qic_data$longest.run`
- [x] 3.3 Test: `result$summary$antal_kryds[i]` == per-fase aggregering af `result$qic_data$n.crossings`
- [x] 3.4 Test: `result$summary$loebelaengde_signal[i]` == per-fase tilstand
- [x] 3.5 Test: `result$summary$sigma_signal[i]` == per-fase tilstand
- [x] 3.6 Test for chart-typer der returnerer signaler: i, p, pp, u, up, c, mr
- [-] 3.6 xbar: udgået fra test-scope (kræver ekstra opsætning, dækket indirekte via i)
- [x] 3.7 Test edge case: enkelt-fase data (ingen `part`)
- [x] 3.8 Test edge case: fase med kun 1-2 punkter
- [x] 3.9 Test edge case: `exclude`-positioner

## 4. Implementér valgt option

### Option B (behold + fix):

- [x] 4.B.1 Tilføj `sigma.signal`-aggregering med `any()` i `format_qic_summary()` analogt med `runs.signal`
- [-] 4.B.2 Sanity-check warning: ikke implementeret — konsistenstests giver stærkere garanti end runtime-warning
- [-] 4.B.3 Test for warning-trigger: ikke relevant (ingen warning implementeret)
- [x] Verificerede at alle eksisterende tests stadig består (2875 PASS, 1 pre-existing FAIL)

## 5. Audit `bfh_extract_spc_stats()`

- [x] 5.1 `R/utils_spc_stats.R`: ingen parallelle Anhøj-beregninger — bruger `result$summary` som kilde
- [-] 5.2 Ingen duplikering fundet — ingen konsolidering nødvendig
- [x] 5.3 Test: `bfh_extract_spc_stats(result)` matcher `result$summary`-felter (tilføjet i test-fil)

## 6. Dokumentation

- [x] 6.1 `bfh_qic()` Roxygen `@details`: "SPC Statistics Provenance"-tabel tilføjet
- [x] 6.2 Hver statistik-kilde dokumenteret (qicharts2-direkte / lokal aggregering)
- [x] 6.3 Per-fase vs global semantik dokumenteret
- [x] 6.4 NEWS-entry under `## Bug fixes` i v0.13.1

## 7. Cross-repo

- [-] 7.1 biSPCharts-notifikation: udenfor scope for denne PR — documenteret i NEWS at downstream påvirkes
- [-] 7.2 Test i biSPCharts: udenfor scope

## 8. Release

- [x] 8.1 DESCRIPTION bumped: 0.13.0 → 0.13.1 (PATCH — statistisk korrektion)
- [-] 8.2 `devtools::check()`: køres ikke automatisk (render-tests kræver env-var)
