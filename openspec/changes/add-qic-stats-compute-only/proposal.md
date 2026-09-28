## Why

Downstream-kode der kun skal bruge SPC-tallene betaler i dag for en fuld
graf. `bfh_qic()` bygger altid plottet (`render_bfh_plot()`) og placerer
labels (`add_spc_labels()` med `ggplot_build()` + `ggplot_gtable()` og
marquee-maaling) — ogsaa naar kalderen kun laeser `$summary` og
`$qic_data`. Kodens egen kommentar anslaar `ggplot_build()` alene til
50-150 ms pr. graf.

Konkret: BFHmetadata's signal-gennemgang kalder `bfh_qic()` for hvert
aktivt diagram (3.518; op til 119 pr. indikator) og bruger aldrig plottet —
grafen paa skaermen tegnes separat ud fra `qic_data`. Tegningen er ren
spildtid og fylder desuden i sessionens cache.

`return_data = TRUE` hjaelper ikke: tegningen sker foer retur-routingen, og
parameteren er deprecated (type-ustabil).

## What Changes

- Ny eksporteret funktion `bfh_qic_stats()`: samme beregningsparametre som
  `bfh_qic()` (`data`, `x`, `y`, `n`, `chart_type`, `y_axis_unit`, `part`,
  `freeze`, `exclude`, `cl`, `multiply`, `agg_fun`, `target_value`, `notes`),
  ingen tegneparametre. Returnerer et `bfh_qic_stats`-objekt med
  `$summary`, `$qic_data` og `$config` — uden at bygge et plot.
- Intern opdeling af `bfh_qic()` i en beregningsfase og en tegnefase.
  Begge funktioner bruger den samme beregningsfase, saa `bfh_qic_stats()`
  ikke kan glide fra `bfh_qic()`.
- `bfh_extract_spc_stats()` faar en metode for `bfh_qic_stats`.
- Ikke breaking: rent additivt. `bfh_qic()`'s output er uaendret
  (verificeret af aekvivalenstests og de eksisterende visuelle snapshots).

## Capabilities

### New Capabilities
<!-- Ingen ny capability: funktionen er en del af public API. -->

### Modified Capabilities
- `public-api`: ny eksporteret funktion `bfh_qic_stats()` med
  aekvivalens-garanti mod `bfh_qic()`.

## Impact

**Kode (BFHcharts):**
- `R/bfh_qic.R`: beregningsfasen flyttes ud i en intern hjaelper;
  `bfh_qic()` kalder hjaelperen og derefter tegnefasen.
- Ny `R/bfh_qic_stats.R`: `bfh_qic_stats()`, konstruktor og print-metode.
- `R/utils_spc_stats.R`: `bfh_extract_spc_stats.bfh_qic_stats()`.
- NAMESPACE + man via roxygen.

**Public API:**
- Ny eksport. `bfh_qic()`-signatur og output uaendret. MINOR bump
  (0.30.0 -> 0.31.0).

**Downstream:**
- BFHmetadata skifter `compute_signal()` til `bfh_qic_stats()` og kraever
  `BFHcharts (>= 0.31.0)` — separat PR efter release.
- biSPCharts og BFHddl: ingen tvungen aendring.
