# Cycle 05 — User-led audit af `feat/structured-spc-analysis` post cycle 04

**Område:** Hele branch efter cycle 04 dual-review block-fixes (commit `1e8096c`).
**Trigger:** Bruger kørte selvstændig audit post cycle 04 og afviste merge.
**Reviewer:** Bruger (Johan), klinisk-faglig + arkitektonisk perspektiv.
**Verdict:** `no-ship`. Algoritme + tekster har klinisk-misvisende fund.

---

## Scope

Bruger reviewede hele `feat/structured-spc-analysis`-branch efter cycle 04
block-fixes blev anvendt. Cycle 04 reviewede arkitektonisk konsistens +
spec-drift; cycle 05 fokuserede på **algorithm correctness + klinisk
sprog** -- domæner cycle 04 underprioriterede.

---

## Findings

### #1 [HIGH] — variable_cl falsk caveat på I-charts med faseskift

**Lokation:** `R/spc_features.R:481` (.detect_variable_cl).

**Symptom:** Funktionen så på `sd(ucl-lcl)/mean(ucl-lcl)` over hele
`qic_data` uden chart-class-gating. Ved phase-split (i-chart med
`part=12`) varierer CL mellem faser -> CV > 10% -> caveat udløst med
tekst "Kontrolgrænserne varierer fordi stikprøvestørrelsen ændrer sig" --
men `n` ændrer sig IKKE. Klinisk misvisende.

**Brugers repro:** `chart_type="i"` med `part=12` → 
`features$data_quality$variable_cl == TRUE` + forkert n-caveat.

**Fix:** Chart-class-gate. Variable_cl-caveat aktiv kun på subgrouped
chart-classes (proportion/rate/subgrouped) hvor n-variation er
dominerende driver af CL-bredde. Phase-shift-detektion er Slice 5's
ansvar (baseline-delta).

---

### #2 [HIGH/MEDIUM] — Modifier-sammensætning producerer grammatisk brudt prosa

**Lokation:** `R/spc_render.R:95` (paste-konkatenering).

**Symptom:** Eksempel-output:
> ... uden tegn på systematiske ændringer. (en betydelig forandring på ~10%). i den ønskede retning. Fra 49,75 til 54,87.

Fragments med parens, lowercase-leadings, dobbelt-periode. Direction-
templates begyndte med "i ..." (sætningsfragment), magnitude med "(..." 
(parentes), baseline-delta med "Fra ..." (capitalized standalone). Resultat:
inkonsistent stil, grammatisk brudt.

**Fix:** `.compose_modifier_sentence()` bygger EN sammenhængende
sætning. Templates redesignet til clause-form (lowercase, ingen
trailing period); composer vælger sentence-frame baseret på hvilke
modifiers er aktive:

| Aktive modifiers | Frame |
|---|---|
| baseline + (mag eller dir) | "{lead}, {mag} {dir}." |
| baseline alene | "{standalone}." |
| mag + dir (no baseline) | "Niveauet viser {mag} {dir}." |
| mag alene | "Niveauet viser {mag}." |
| dir alene | "Niveauet bevæger sig {dir}." |

Eksempel post-fix:
> Sammenlignet med tidligere fase er niveauet flyttet fra 50,11 til 54,98, en betydelig forandring på ~10% i niveauet i den ønskede retning.

---

### #3 [MEDIUM] — Magnitude falsk "large" ved mikroskopisk sigma

**Lokation:** `R/spc_features.R:595` (.compute_magnitude).

**Symptom:** `.compute_magnitude(1e-8, 1e-12, NA)` returnerer `"large"`.
Near-constant data med UCL≈LCL kan give `sigma_hat ≈ 1e-12`; enhver
baseline-delta over `2e-12` klassificeres som `"large"`.

**Brugers repro:** `.compute_magnitude(1e-8, 1e-12, NA)` → `"large"`.

**Fix:** `MAGNITUDE_RATIO_CAP = 100`. Ratios > cap returnerer NA i
stedet for magnitude-bucket. Foreløbigt safety-net; permanent løsning
kræver sigma-floor med scale/unit-awareness.

---

### #4 [MEDIUM] — AI-path sender forkert signals_detected for data-quality states

**Lokation:** `R/spc_analysis.R:580` (use_ai branch).

**Symptom:** `has_signals` udledtes af `stability_pattern !=
no_signals/no_variation`. Men `not_evaluable` og
`majority_at_centerline` er IKKE SPC-signaler -- de er
evaluerbarhed/data-form-states. BFHllm fik fejlsignal: "der er
detekteret special-cause variation" når der reelt var datakvalitets-
problemer.

**Fix:** Brug `runs_actual > runs_expected` (runs-signal),
`crossings_actual < crossings_expected` (crossings-signal), og
`outliers_recent_count > 0` (outlier-signal) direkte. `has_signals`
er nu sande Anhøj-flag-aktivering.

---

### #5 [MEDIUM] — not_evaluable-prose matcher ikke alle low-confidence-årsager

**Lokation:** `R/spc_features.R:329` (`.compute_confidence_tier`) +
`inst/i18n/da.yaml:131` (`base.not_evaluable`).

**Symptom:** `confidence_tier == "low"` triggeres af n < N_MIN OR
manglende centerline OR manglende spread. Men teksten sagde altid
"Med kun {n_points} observationer..." -- forkert når n ≥ 12 men
centerline/spread mangler.

**Fix:** Ny `low_confidence_reason`-feature-akse med værdier
`few_obs|no_centerline|no_spread|NA`. Templates splittet per reason:

- **few_obs**: "Med kun {n_points} observationer..."
- **no_centerline**: "Serien kan ikke vurderes pålideligt med
  statistisk proceskontrol, fordi der ikke kan beregnes en
  centerlinje."
- **no_spread**: "Serien kan ikke vurderes pålideligt med statistisk
  proceskontrol, fordi variationen i data ikke kan estimeres."

Render-lag dispatcher template-variant på reason.

---

### #6 [LOW] — chart_class forkert for xbar/s

**Lokation:** `R/spc_features.R:454` (.resolve_chart_class).

**Symptom:** xbar/s mappede til "individuals". Klasserne refererer
til hvordan sigma/CL beregnes:
- individuals = i/mr (single obs per time-point)
- subgrouped = xbar/s (mean/sd af subgroup ved hvert time-point)

**Fix:** xbar/s → "subgrouped". Bonus: variable_cl-gate (finding #1)
aktiveres nu korrekt for xbar/s.

---

## Tekst-stramninger

| Sted | Før | Efter | Rationale |
|---|---|---|---|
| direction.unfavorable | "i forkert retning"/"i den modsatte..." | "i uønsket retning"/"væk fra den ønskede retning" | Mindre hårdt; klinisk-neutralt sprog |
| stable_near_target.detailed | "acceptér den lille difference" | "Vurdér, om forskellen er praktisk betydende" | Mindre normativt; lader klinikeren afgøre |
| unstable_near_target.standard | "naturlige variation" | "særlige årsager til variation" | Anhøj/Shewhart-terminologi (common-cause ≠ special-cause) |
| not_evaluable.few_obs.detailed | "detektions-styrke" | "detektionsstyrke" | Korrekt sammensat ord på dansk |

---

## Test-status post cycle 05

| | Antal |
|---|---|
| PASS | 5431 |
| FAIL | 0 |
| WARN | 8 |
| SKIP | 101 |

Test-cleanup: `test-spc_parity_phase1.R` 12 tests skip'es med
rationale (tautologisk post-Phase-2-cut-over: 
`bfh_generate_analysis()` delegerer internt til samme pipeline som
`bfh_render_analysis(bfh_analyse(x))`). Determinism-test bevares som
idempotens-gate.

---

## Spec-opdateringer

`openspec/.../spec.md`:
- Tilføjet `low_confidence_reason`-axis med enum
  `c("few_obs", "no_centerline", "no_spread", NA_character_)`
- Fjernet `data_age_days` fra aux-required-list (Slice 10 SKIP-konsekvens)

---

## Lære

Cycle 04 dual-review fokuserede arkitektonisk konsistens + spec-drift,
men missede tre klinisk-vigtige fund:

1. **Algorithm scoping (finding #1)**: Detection logic uden chart-
   class-gating producerer falske positives. Codex + Claude fangede
   spec-drift men ikke algoritmisk-scoping-fejl.
2. **Prose composition (finding #2)**: Per-template testing (substring-
   match på `forandring`, `ønskede retning`) ser ikke at sætningen
   som helhed er brudt. Klinisk fagligt review af outputtet -- ikke
   bare unit-tests -- afslørede problemet.
3. **Klinisk faglig terminologi (tekst-stramninger)**: "Naturlige
   variation" vs "særlige årsager" er teknisk-statistisk distinction
   som ikke fanges af automated checks. Bruger-review er
   uerstatteligt.

**Cycle 05 = case for bruger-led audit som komplement til automated
dual-review.** Codex + Claude er gode til mekanisk konsistens-check;
mennesker er nødvendige for domain-correctness.

---

## Fixes anvendt i cycle 05

Commits:
- `34282e8` fix(spc-analysis): cycle 04 deferred H2 + H3 + N1 fixture regression
- (kommende commit for cycle 05 finding #1, #2, #4, #5, #6 + tekst-stramninger)
