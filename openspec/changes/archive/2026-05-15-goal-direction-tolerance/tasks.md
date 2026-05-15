## 1. Slice 1 — Direction-aware tolerance cascade

- [ ] 1.1 Tilføj 3-vejs cascade til retningsbevidst gren i
      `.evaluate_target_arm()` ([R/spc_analysis.R:818-829](../../R/spc_analysis.R#L818-L829)):
      - Beregn `delta = abs(centerline - target_value)` før direction-check.
      - Cascade-rangering (tolerance FØRST, derefter strikt comparison):
        1. `sigma_hat > 0` finite → `near_target ⟺ delta <= 3·sigma_hat`
        2. `sigma_data > 0` finite → `near_target ⟺ delta <= sigma_data`
        3. ellers → `near_target ⟺ delta < 1e-9`
      - Hvis `near_target`: brug `texts$target$near_target` + sæt
        `result$near_target <- TRUE` (nyt felt i return).
      - Ellers strikt direction-comparison som hidtil (`goal_met` /
        `goal_not_met`).
- [ ] 1.2 Udvid return-liste fra `.evaluate_target_arm()` med
      `near_target`-flag.
- [ ] 1.3 Tests: process-variation-aware `near_target`-klassifikation
      for begge directions.

## 2. Slice 2 — i18n + action-arm-keys

- [ ] 2.1 Tilføj `analysis.target.near_target` til `inst/i18n/da.yaml`:
      ```yaml
      near_target:
        short: "Niveauet ligger lige {level_direction} udviklingsmålet ({target})."
        standard: "Det nuværende niveau ligger lige {level_direction} udviklingsmålet ({target})."
        detailed: "Det nuværende niveau på {centerline} ligger lige {level_direction} udviklingsmålet ({target})."
      ```
- [ ] 2.2 Tilføj parallel `analysis.action.stable_near_target` og
      `analysis.action.unstable_near_target` til `da.yaml`.
- [ ] 2.3 Speil ændringer i `inst/i18n/en.yaml`.
- [ ] 2.4 Udvid `.select_action_key()` ([R/spc_analysis.R:739](../../R/spc_analysis.R#L739)):
      - Tilføj `near_target`-parameter.
      - Når `near_target == TRUE` og `target_direction` non-NULL:
        return "stable_near_target" / "unstable_near_target".
      - Prioritet: `near_target > goal_met > goal_not_met`.
- [ ] 2.5 `build_fallback_analysis()`: thread `near_target` fra
      `.evaluate_target_arm()`-resultat til `.select_action_key()`.

## 3. Slice 3 — Majority at centerline (additive)

- [ ] 3.1 Udvid `.detect_signal_flags()` ([R/spc_analysis.R:618-657](../../R/spc_analysis.R#L618-L657)):
      - Beregn `n_on_cl_ratio` fra `context$qic_data` eller via
        `context$spc_stats` (afhænger af tilgængelighed):
        ```r
        # Eksakt-match: |y - cl| < 1e-9, ej tolerance-baseret
        y <- qic_data$y[last_phase_filter]
        cl_values <- qic_data$cl[last_phase_filter]
        n_on_cl <- sum(abs(y - cl_values) < 1e-9, na.rm = TRUE)
        n_total <- sum(!is.na(y), na.rm = TRUE)
        n_on_cl_ratio <- n_on_cl / n_total
        ```
      - Tilføj `majority_at_cl <- n_on_cl_ratio >= 0.5 && !no_variation`
        til returned flags.
- [ ] 3.2 Opdatér `build_fallback_analysis()`-stability-dispatcher
      ([R/spc_analysis.R:968-988](../../R/spc_analysis.R#L968-L988)):
      ```r
      if (no_variation) → texts$stability$no_variation
      else if (majority_at_cl) → texts$stability$majority_at_centerline (NY)
      else → .select_stability_key(flags)
      ```
- [ ] 3.3 Tilføj `analysis.stability.majority_at_centerline` til begge
      YAML-filer (da + en) med short/standard/detailed-varianter der
      flagger "data-kvalitets-symptom" (grov skala, diskret rapportering).
- [ ] 3.4 Tests: edge cases — eksakt 50%, 49%, 99%, no_variation tager
      fortrinsret over majority_at_cl.

## 4. Verifikation + dokumentation

- [ ] 4.1 Kør `dev/analyze_i18n_budget.R` — verificér budget-allokering
      stadig optimal med nye keys (kan kræve action-budget-bump hvis
      `stable_near_target.detailed` rammer >132 tegn).
- [ ] 4.2 Tilføj NEWS.md-entry under "Nye features" (Slice 1+2) og
      "Bug fixes"/"Interne ændringer" (Slice 3).
- [ ] 4.3 Kør `devtools::test()` — adresser eventuelle test-failures
      fra path B-tolerance-ændringen.
- [ ] 4.4 Verificér mod konkret repro-scenarie:
      - `target = ">= 90%"`, `centerline = 0.895`, `sigma_hat = 0.02`
      - Forventet: `near_target` action vises, NEW `stable_near_target.detailed`
        tekst rendret.

## 5. Archive

- [ ] 5.1 Bekræft alle scenarier i `specs/spc-analysis-api/spec.md` er
      dækkede af tests.
- [ ] 5.2 `openspec validate goal-direction-tolerance --strict`.
- [ ] 5.3 Merge til `main` via PR, derefter `openspec archive
      goal-direction-tolerance --yes`.
