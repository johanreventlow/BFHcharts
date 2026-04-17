## 1. Arkitektur-konsolidering (BREAKING)

- [ ] 1.1 Slet funktion `bfh_interpret_spc_signals()` i `R/spc_analysis.R`
- [ ] 1.2 Fjern `signal_interpretations` fra `bfh_build_analysis_context()` return-list
- [ ] 1.3 Slet tests for `bfh_interpret_spc_signals()` og `signal_interpretations` i `tests/testthat/test-spc_analysis.R`
- [ ] 1.4 Regenerér `man/` via `devtools::document()` (sletter `bfh_interpret_spc_signals.Rd`)
- [ ] 1.5 Opdater `NEWS.md` med breaking change-entry

## 2. Algoritmiske fixes (B)

- [ ] 2.1 Tilføj intern `pluralize_da(n, singular, plural)` helper i `R/spc_analysis.R`
- [ ] 2.2 Tilføj intern `ensure_within_max(text, max_chars)` helper (trim ved sætningsgrænse)
- [ ] 2.3 Udvid `placeholder_data` med `outliers_word` i `build_fallback_analysis()`
- [ ] 2.4 Tilføj parameter `target_tolerance = 0.05` til `bfh_generate_analysis()` og propagér til `build_fallback_analysis()`
- [ ] 2.5 Implementér budget-reallokering: `has_target == FALSE` → `stability_budget = 0.65 * max_chars`, `action_budget = resten`
- [ ] 2.6 Kald `ensure_within_max()` efter `paste(parts, collapse = " ")` og før `pad_to_minimum()`
- [ ] 2.7 Skriv tests for alle fire helpers/justeringer

## 3. Retningsfølsomhed (E)

- [ ] 3.1 Tilføj intern `resolve_target(target_input)` helper i `R/spc_analysis.R`
- [ ] 3.2 Udvid `bfh_build_analysis_context()`: parse `metadata$target` via `resolve_target()`, tilføj `target_direction` og `target_display` til context
- [ ] 3.3 Opdater `build_fallback_analysis()` målvurderings-sektion: ved `target_direction != NULL`, beregn `goal_met` og vælg `target$goal_met` / `target$goal_not_met`
- [ ] 3.4 Opdater action-logik: ved kendt retning, vælg `*_goal_met` / `*_goal_not_met` i stedet for `*_at_target` / `*_not_at_target`
- [ ] 3.5 Bevar bagudkompatibel sti (numerisk target, NULL direction → nuværende at/over/under-tekst)
- [ ] 3.6 Skriv tests for `resolve_target()` (numerisk, streng, operator-parsing, dansk komma, edge cases)
- [ ] 3.7 Skriv tests for goal_met/goal_not_met-logik i `build_fallback_analysis()`

## 4. Sprogvask YAML (A)

- [ ] 4.1 Indfør `{outliers_word}` placeholder i `outliers_only`, `runs_outliers`, `crossings_outliers`, `all_signals`
- [ ] 4.2 Standardisér outlier-terminologi til "observationer uden for kontrolgrænserne" overalt
- [ ] 4.3 Fjern komma før "og" i opremsninger (dansk tegnsætning)
- [ ] 4.4 Klinikervenliggør "gruppering i data" (fx "punkterne fordeler sig i klumper over eller under centrallinjen")
- [ ] 4.5 Tilføj manglende `detailed`-varianter til `target.*` (hvor kun short/standard findes)
- [ ] 4.6 Skarpere differentiering mellem `unstable_not_at_target` og `unstable_no_target`
- [ ] 4.7 Erstat vage formuleringer ("En grundig analyse anbefales") med konkrete instrukser
- [ ] 4.8 Fjern redundans i `detailed`-varianter (fx `runs_only.detailed`'s "Dette indikerer...")
- [ ] 4.9 Tilføj nye keys: `target$goal_met`, `target$goal_not_met`, `action$stable_goal_met`, `action$stable_goal_not_met`, `action$unstable_goal_met`, `action$unstable_goal_not_met` — alle med short/standard/detailed
- [ ] 4.10 Brugergodkendelse af sprogvask blokvis (stability → target → action → padding) før commit

## 5. Validering og dokumentation

- [ ] 5.1 `devtools::document()` — regenerér roxygen-docs
- [ ] 5.2 `devtools::test()` — alle tests skal passere
- [ ] 5.3 `devtools::check()` — ingen NOTE/WARNING/ERROR
- [ ] 5.4 Manuel end-to-end: test alle fire scenarier (retning-nået, retning-ikke-nået, numerisk backward-compat, ental)
- [ ] 5.5 `openspec validate refactor-spc-analysis-texts --strict` uden fejl
- [ ] 5.6 Opdater `openspec/specs/spc-analysis-api/spec.md` ved archive

Tracking: GitHub Issue #137
