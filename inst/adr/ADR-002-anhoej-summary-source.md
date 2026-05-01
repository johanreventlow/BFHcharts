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
