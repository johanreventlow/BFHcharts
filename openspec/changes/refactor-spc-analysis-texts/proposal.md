## Why

Analysetekst-systemet i `R/spc_analysis.R` har to arkitektoniske og sproglige svagheder, samt en manglende klinisk funktionalitet:

1. **Duplikeret tekstgenerering**: `bfh_interpret_spc_signals()` producerer parallel Anhøj-tekst via hardcoded `sprintf()`-kald, men dens output (`context$signal_interpretations`) læses aldrig af `build_fallback_analysis()` — den er død kodesti bevaret udelukkende pga. OpenSpec-specifikation og tests. Resultatet er to tekst-systemer der kan glide fra hinanden.
2. **Manglende retningsfølsomhed**: Nuværende tekst beskriver "over/under målet" værdineutralt. Klinikeren ved ikke om "over mål" er godt (fx overlevelse) eller skidt (fx infektionsrate). Pakken har allerede `parse_target_input()` der udleder retning fra `"≤ 2,5"` / `"≥ 90%"` — infrastrukturen kan genbruges.
3. **Sproglige svagheder**: inkonsistent terminologi (outliers kaldes "ekstreme værdier" / "afvigelser" / "observationer"), engelsk tegnsætning før "og", manglende ental/flertal for `{outliers_actual} = 1`, vage formuleringer ("En grundig analyse anbefales"), abstrakt fagsprog ("gruppering i data") og asymmetri i varianter.
4. **Algoritmiske skavanker**: fast 5%-tolerance, budget-spild uden target, `pad_to_minimum()` trimmer aldrig (kan overskride `max_chars`), og to action-keys nær-identiske.

## What Changes

- **BREAKING**: Fjern `bfh_interpret_spc_signals()`-funktionen og `signal_interpretations`-feltet fra `bfh_build_analysis_context()`'s return-list. Al analysetekst genereres herefter via YAML-skabeloner i `build_fallback_analysis()`.
- **ADDED**: `resolve_target()` (intern) udleder numerisk værdi + retning fra `metadata$target` ved at genbruge `parse_target_input()`. Accepterer både numerisk (bagudkompatibel), ren streng, og streng med operator (`"≤ 2,5"`, `"≥ 90%"`, `"> 2"`).
- **ADDED**: Nye YAML-keys `target$goal_met`, `target$goal_not_met` (med short/standard/detailed) og handlings-varianter `action$stable_goal_met`, `action$stable_goal_not_met`, `action$unstable_goal_met`, `action$unstable_goal_not_met`.
- **ADDED**: Nye context-felter `target_direction` (`"higher"` | `"lower"` | `NULL`) og `target_display` (original streng).
- **MODIFIED**: `build_fallback_analysis()` bruger retningsbevidst logik når `target_direction` er kendt — ellers falder til værdineutral "over/under/at target" (bagudkompatibelt).
- **MODIFIED**: Tolerance for `at_target` er nu parameter `target_tolerance` (default 0.05) i stedet for hardcoded.
- **MODIFIED**: Budget-allokering re-fordeler når `target` er fraværende (25% target-budget → stability/action).
- **ADDED**: Intern `ensure_within_max()` garanterer `nchar(text) <= max_chars` ved at trimme ved sætningsgrænser.
- **ADDED**: Intern `pluralize_da()` helper + `{outliers_word}` placeholder til korrekt ental/flertal.
- **MODIFIED**: Komplet sprogvask af `inst/texts/spc_analysis.yml` — konsistent terminologi, dansk tegnsætning, klinikervenligt fagsprog, symmetriske varianter, handlingsrettede actions.

## Impact

- **Affected specs**: `spc-analysis-api` (REMOVED + MODIFIED + ADDED requirements)
- **Affected code**:
  - `R/spc_analysis.R` (slet funktion, tilføj helpers, opdater build_fallback_analysis)
  - `inst/texts/spc_analysis.yml` (fuld omskrivning)
  - `tests/testthat/test-spc_analysis.R` (slet ~120 linjer, tilføj nye tests)
  - `man/bfh_interpret_spc_signals.Rd` (slettes ved `devtools::document()`)
  - `NEWS.md` (breaking change + feature entries)
- **Affected downstream**: Potentielt biSPCharts-app (hvis den kalder `bfh_interpret_spc_signals()` eller læser `signal_interpretations`-felt). Grep bekræfter ingen eksterne kaldere i BFHcharts-koden; downstream skal verificeres før merge.
- **Backward compat**: `metadata$target` som numerisk værdi fortsætter uændret adfærd (ingen retning → nuværende værdineutrale tekst). Kun tilføjelse af operator-syntax introducerer ny funktionalitet.

## Related

- GitHub Issue: #137
