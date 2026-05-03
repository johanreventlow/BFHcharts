# ADR-002: Anhoej Summary Statistics Source

Status: Accepted

## Kontekst

`format_qic_summary()` (`R/utils_qic_summary.R`) producerer `result$summary` med
Anhoej-statistik pr. fase (`laengste_loeb`, `antal_kryds`, `loebelaengde_signal`,
`sigma_signal`). Funktionen splitter `qic_data` per fase og kalder `safe_max()`
pa `qic_data$longest.run` / `n.crossings` per fase.

Spoergsmalet var: Er denne per-fase-aggregering konsistent med hvad qicharts2
returnerer? Og er der risiko for divergens?

## Verifikation (2026-05-01)

Empirisk gennemgang afsloerede:

### Konsistente felter

1. **`longest.run` og `n.crossings`: per-fase konstanter.**
   qicharts2 gemmer fasens globale loebtal som en per-row konstant -- alle
   raekker i samme fase har identisk vaerdi. `safe_max()` pa en konstant
   raekke returnerer den ene vaerdi, aekvivalent med `any()`/`max()` over
   hele fasen.

2. **`longest.run.max` og `n.crossings.min`: globale konstanter.**
   qicharts2 beregner disse pa tvaers af hele datasaettet (ikke per fase).
   De er identiske for alle raekker uanset fase.

3. **`runs.signal`: korrekt aggregeret med `any()`.**
   `format_qic_summary()` haandterede allerede `runs.signal` korrekt
   (L114-116 kalder `any(x$runs.signal, na.rm = TRUE)`).

4. **NA-faenomenet er forventet adfaerd.**
   Naar alle vaerdier i en fase er identiske, kan qicharts2 ikke beregne
   meningsfulde lob/krydstal. Den returnerer NA for disse raekker.
   `safe_max(NA-vektor)` returnerer NA -- korrekt og konsistent med qic_data.

### Fejl fundet

**`sigma.signal`: per-row variabel -- IKKE per-fase konstant.**

I modsaetning til `longest.run` varierer `sigma.signal` fra raekke til
raekke inden for en fase (det er en per-observation flag for outliers).
Den tidligere kode tog den FOERSTE raekkes vaerdi
(`row <- x[1, , drop = FALSE]`) og overskrev aldrig `row$sigma.signal`.

Konsekvens: Hvis den foerste raekke i en fase ikke er et outlier, men
en eller flere efterfoelgende raekker er det, rapporterede
`summary$sigma_signal` fejlagtigt `FALSE` for fasen.

## Beslutning

`sigma.signal` tilfoejedes eksplicit til aggregeringsblokken med `any()`,
analogt med `runs.signal`. Alle ovrige felter var allerede korrekte.

Koden forbliver i den `safe_max()`-baserede splitstruktur (ikke refaktoreret
til `dplyr::group_by |> summarise`), da strukturen er korrekt og
tilgangen haandterer edge cases (NA-faser) korrekt.

## Konsekvenser

**Fordele:**
- `summary$sigma_signal` rapporterer nu korrekt `TRUE` for en fase, hvis
  NOGEN observation i fasen er et outlier (ikke kun den foerste).
- Eksplicitte konsistenstests vaagter fremover (22 nye tests).
- Proveniens dokumenteret i `bfh_qic()` Roxygen `@details`.

**Afledte virkninger:**
- biSPCharts: `result$summary$sigma_signal` kan aendre vaerdi for faser
  hvor det foerste punkt IKKE er et outlier men et eller flere efterfoelgende
  er det. Dette er en statistisk korrektion -- dokumenteret i NEWS.
- `bfh_extract_spc_stats()` paavirkes indirekte: bruger `result$summary`
  som kilde, og faar nu korrekte vaerdier automatisk.

## Relateret

- OpenSpec change: `2026-05-01-verify-anhoej-summary-vs-qic-data-consistency`
- Test: `tests/testthat/test-summary-anhoej-consistency.R`
- Kode: `R/utils_qic_summary.R` L99-122

Dato: 2026-05-01

## Addendum 2026-05-03 (anhoej-signals-and-summary-precision)

Codex code-review afsloerede to opfoelgende defekter:

### 1. Semantik-fejl i signal-mapping

`qicharts2::runs.signal` er det KOMBINEREDE Anhoej-signal
(`crsignal(n.useful, n.crossings, longest.run)`, sat ved enten runs- ELLER
crossings-violation). BFHcharts mappede det til et felt navngivet
`loebelaengde_signal` ("run-length signal"), som klinikere laeste bogstaveligt
og fejlattribuerede crossings-only-violationer som niveauskift.

**Fix:**
- `loebelaengde_signal` omdoebt til `anhoej_signal` (samme kombinerede semantik).
- Tilfoejet `runs_signal` (deriveret per fase: `laengste_loeb > laengste_loeb_max`).
- Tilfoejet `crossings_signal` (deriveret per fase: `antal_kryds < antal_kryds_min`).
- Regression-test for crossings-only-data (4 alternerende blokke a 5 punkter).

### 2. Praesentationsformat lakkerer beregningskilde

`format_qic_summary()` afrundede `cl/lcl/ucl/lcl.95/ucl.95` til 1-2 decimaler.
Konsumenter, der bruger `summary$centerlinje` til logisk vurdering (target-
sammenligning, statistisk videreanalyse), ramte forkert side af afrundings-
graensen. biSPCharts #470 oplevede dette downstream.

**Fix:**
- `format_qic_summary()` returnerer raa qicharts2-precision for alle numeriske
  kolonner.
- Display-formattere (`format_target_value`, `format_centerline_for_details`)
  afrunder selv ved string-emission.
- `kontrolgraenser_konstante`-detektion bevarer `decimal_places + 2`-tolerance
  for at absorbere floating-point drift -- men de lagrede vaerdier forbliver raa.

### Konsekvenser

- Public API breaking change i v0.15.0 (pre-1.0 MINOR med tydelig NEWS-markering).
- biSPCharts: opdaterer `BFHcharts (>= 0.15.0)` lower-bound + omdoeber
  `loebelaengde_signal`-references (sporet i biSPCharts #468); #470's workaround
  bliver redundant og kan fjernes hvis oenskes.

## Relateret (addendum)

- OpenSpec change: `anhoej-signals-and-summary-precision`
- Test: `tests/testthat/test-anhoej-decomposed-signals.R`,
  `tests/testthat/test-summary-precision.R`
- Issue: johanreventlow/BFHcharts#290

Dato: 2026-05-03
