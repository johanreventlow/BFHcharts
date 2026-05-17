# Design: Structured SPC Analysis Architecture

Dette dokument fungerer som **ADR-kandidat**. Når change arkiveres,
kopieres indholdet til `docs/adr/ADR-XXX-structured-spc-analysis.md`.

## Status

Proposed (2026-05-17)

## Context

### Nuværende arkitektur

`bfh_generate_analysis()` orkestrerer tre cascade-grene:

```
bfh_qic_result ─→ bfh_build_analysis_context()
                          │
                          ▼
                  build_fallback_analysis()
                          │
              ┌───────────┼───────────┐
              ▼           ▼           ▼
        .select_     .evaluate_   .select_
        stability    target_arm   action_key
        _key()
              │           │           │
              ▼           ▼           ▼
        texts$       texts$      texts$
        stability    target      action
              │           │           │
              └───────────┼───────────┘
                          ▼
                pick_text + budget + paste
                          ▼
                    character output
```

**Karakteristik:**
- Monolitisk cascade: hver arm vælger én nøgle ud af lukket sæt.
- 8 stability × 3 target-veje × 7 action-veje ≈ 56 effektive
  output-kombinationer per chart.
- Tilstands-baseret (her-og-nu snapshot) — ingen historik-kontekst
  (baseline-delta, signal-rejse over tid, freshness).
- Detection (`.detect_signal_flags()`) og formulering (templates) er
  delvist sammenflettet via dispatch-funktioner.
- Caveats (`cl_user_supplied`, `cl_auto_mean`) lever uden for prose,
  kun i PDF-rendering-lag.

### Strukturelle huller (jf. proposal.md)

Tolv distinkte fortolknings-dimensioner mangler eller er delvist
dækket. Naivt fix → dispatch-eksplosion: 8 × 12 × N_modifiers
multiplikativt. Hver ny dimension dobbelt-tester corpus.

### Klinisk kontekst

SPC-fortolkning i healthcare har etablerede principper (NHS Improvement,
IHI):
- Special vs common cause adskillelse.
- Magnitude relativt til naturlig variation.
- Direction i klinisk kontekst (favorable vs unfavorable).
- Duration/persistens af signal.
- Sammenligning mod baseline / mål.
- Eksplicit confidence ved få observationer.

Disse dimensioner er ortogonale — bør modelleres som features, ikke som
nøgler.

## Decision

Refactor til **tre-lags arkitektur**: feature-extraction → composition →
render. Eksponér struktureret analyse-objekt som primær output;
rentekst er én af flere views.

```
┌──────────────────────────────────────────────────────────────┐
│                bfh_qic_result + metadata                      │
└──────────────────────────┬────────────────────────────────────┘
                           ▼
       ┌───────────────────────────────────────┐
       │  bfh_extract_spc_features()           │
       │  (R/spc_features.R)                   │
       │                                       │
       │  Pure deterministisk computation.     │
       │  Returnerer named list med:           │
       │                                       │
       │  Akser (12):                          │
       │  - stability_pattern (8 værdier)      │
       │  - trend_form (step/gradual/none)     │
       │  - magnitude (sigma-shift bucket)     │
       │  - direction (favorable/unf./neutral) │
       │  - target_relation (met/near/not/no)  │
       │  - confidence_tier (low/med/high)     │
       │  - phase_context (single/multi)       │
       │  - freshness (current/stale)          │
       │  - chart_class (run/i/rate/prop/...)  │
       │  - data_quality (flags)               │
       │  - cl_source (data/user/auto-mean)    │
       │  - outlier_history (current/historic) │
       │                                       │
       │  Aux-felter: sigma_hat, baseline_cl,  │
       │  baseline_delta, n_points, ...        │
       └─────────┬─────────────────────────────┘
                 │
                 ▼
   ┌──────────────────────────────────────┐
   │  bfh_analyse()  (R/spc_analysis.R)   │
   │                                      │
   │  Composes structured analysis from   │
   │  features + texts. Returns:          │
   │                                      │
   │  bfh_spc_analysis-objekt:            │
   │  - features (alle ortogonale akser)  │
   │  - conclusions (named list)          │
   │  - confidence ("low"/"med"/"high")   │
   │  - caveats (list of named caveats)   │
   │  - suggested_actions (list)          │
   │  - language ("da"/"en")              │
   │  - schema_version (semver)           │
   └─────────┬────────────────────────────┘
             │
             ▼
   ┌──────────────────────────────────────┐
   │  bfh_render_analysis()               │
   │  (R/spc_render.R)                    │
   │                                      │
   │  Composition-regler:                 │
   │  1. Base-template fra stability_     │
   │     pattern (eller no_variation /    │
   │     not_evaluable override)          │
   │  2. Modifier-cascade (deterministisk │
   │     prioritets-rækkefølge):          │
   │     - magnitude_clause               │
   │     - direction_clause               │
   │     - baseline_delta_clause          │
   │     - phase_intervention_clause      │
   │     - chart_class_modifier           │
   │     - variable_cl_caveat             │
   │     - freshness_caveat               │
   │     - few_obs_caveat                 │
   │     - cl_disclosure_caveat           │
   │     - discrete_scale_caveat          │
   │     - historic_outliers_clause       │
   │     - seasonality_caveat             │
   │  3. Target-arm (eksisterende        │
   │     evaluation, retning-aware)       │
   │  4. Action-arm (modifier-context-    │
   │     aware action-valg)               │
   │  5. Budget-allokering med            │
   │     prioritets-trimming              │
   └─────────┬────────────────────────────┘
             ▼
   character (tegnbudget-styret, sprog-aware)

   ┌──────────────────────────────────────┐
   │  bfh_generate_analysis()             │
   │  (legacy wrapper, signatur uændret)  │
   │                                      │
   │  bfh_analyse() → bfh_render_analysis │
   │       │                              │
   │       └─→ AI-fallback hvis use_ai    │
   └──────────────────────────────────────┘
```

### Feature-objekt schema (formelt)

```r
bfh_spc_analysis <- structure(
  list(
    schema_version = "1.0",
    language = "da",
    features = list(
      stability_pattern = "runs_only",   # 1 af 10 værdier
      trend_form = "step",                # step | gradual | none
      magnitude = "medium",                # small | medium | large | NA
      direction = "favorable",             # favorable | unfavorable | neutral | unknown
      target_relation = "near",            # met | near | not_met | none
      confidence_tier = "high",            # low | medium | high
      phase_context = "post_intervention", # single | multi | post_intervention
      freshness = "current",               # current | stale | very_stale
      chart_class = "individuals",         # run | individuals | rate | proportion | count | rare_events
      data_quality = list(
        few_obs = FALSE,
        variable_cl = FALSE,
        discrete_scale = FALSE,
        missing_denominators = FALSE
      ),
      cl_source = "data_estimated",        # data_estimated | user_supplied | auto_mean
      outlier_history = "current_only"     # current_only | historic_only | both | none
    ),
    aux = list(
      sigma_hat = 0.02,
      sigma_data = 0.018,
      n_points = 24,
      effective_window = 6,
      centerline = 0.87,
      baseline_centerline = 0.92,
      baseline_delta = -0.05,
      baseline_delta_pct = -5.4,
      latest_obs_date = as.Date("2026-04-30"),
      data_age_days = 17
    ),
    conclusions = list(
      stability = "runs_only",
      target = "near_target",
      action = "stable_near_target"
    ),
    confidence = "high",
    caveats = list(
      cl_source = NULL,                    # NULL hvis data_estimated
      freshness = NULL,
      few_obs = NULL,
      variable_cl = NULL
    ),
    suggested_actions = c(
      "Overvåg processen løbende",
      "Vurder om sidste 5% kan accepteres"
    )
  ),
  class = "bfh_spc_analysis"
)
```

### Composition-contract

**Modifier-prioritets-rækkefølge (fast, dokumenteret):**

1. **Blocking caveats** (erstatter base):
   `not_evaluable` (n < N_MIN) → `no_variation` → `discrete_scale_extreme`
2. **Base sentence** (stability_pattern fra 10-værdi sæt)
3. **Magnitude modifier** (hvis `magnitude != NA`)
4. **Direction modifier** (hvis `direction != neutral && direction != unknown`)
5. **Baseline-delta modifier** (hvis `phase_context == "post_intervention"`)
6. **Phase-intervention modifier** (samme betingelse, anden formulering)
7. **Chart-class modifier** (rate/proportion/rare_events specifik prose)
8. **Target clause** (eksisterende target-arm, retning-aware)
9. **Action clause** (eksisterende action-arm, modifier-context-aware)
10. **Tail caveats** (appendes hvis plads):
    `variable_cl` → `cl_disclosure` → `freshness` → `historic_outliers` →
    `seasonality`

**Budget-allokering:**
- Base + target + action: 60% af `max_chars`
- Modifier-pool (3-7): 25% af `max_chars`
- Tail caveats (10): resterende 15%
- Budget-trim sker fra bunden (lavest prioritet drops først).

**Sprog-parity:**
Hver modifier har eksplicit `da`/`en` definition. Test-suite tjekker
placeholder-paritet (samme placeholders i begge sprog), magnitude-
formatering (decimaltegn, %), og semantisk konsistens.

### Confidence-tier semantik

| Tier   | Kriterier (alle skal opfyldes)          | Effekt på output           |
|--------|-----------------------------------------|----------------------------|
| `high` | n ≥ 20, har CL, sigma_hat finite        | Direkte påstande           |
| `med`  | n ∈ [12, 19], har CL                    | Hedge ord: "tegn på", "ser ud til" |
| `low`  | n < 12 ELLER manglende CL/sigma         | `not_evaluable`-base, eksplicit "for kort serie" |

Tier styrer **også om en konklusion overhovedet rapporteres** (lav tier
→ kort tekst med eksplicit usikkerhed, ikke spekulativ påstand).

### Backward-compat strategi

**Pre-cut-over (`tasks 1-3`):**
- Ny `bfh_extract_spc_features()` parallel med eksisterende
  `bfh_build_analysis_context()`.
- Ny `bfh_render_analysis()` parallel med
  `build_fallback_analysis()`.
- Parity-test på golden-corpus: gammelt output skal **bit-for-bit
  matche** ny output uden modifikatorer aktiveret.

**Cut-over (`tasks 4`):**
- `bfh_generate_analysis()` rebindes til ny pipeline.
- Eksisterende cascade-funktioner fjernes eller markeres
  `@keywords internal @noRd`.

**Post-cut-over (`tasks 5+`):**
- Hver modifier aktiveres separat. Hver aktivering har dedikeret
  test-corpus-udvidelse og klinisk review.
- Slice-baseret implementation tillader bruger at definere SKIP /
  DEFER på modifier-niveau.

## Alternatives Considered

### A. Patch-cascade approach (afvist)

Tilføj nye nøgler til eksisterende `texts$stability/target/action`-
strukturer. Tilføj nye dispatch-arme i `.select_*_key()`.

**Afvist fordi:**
- Multiplikativ matrix-eksplosion: 8 × 12 dimensioner × 7-vejs
  cascade = tusinder af kombinationer.
- Test-corpus skal vokse multiplikativt for at dække alle stier.
- YAML-corpus bliver uvedligeholdeligt.
- Hver ny dimension kræver dispatch-refactor.

### B. LLM-only (afvist)

Erstat templates med kald til BFHllm; lad AI håndtere alle
fortolknings-dimensioner.

**Afvist fordi:**
- Healthcare deployment kræver determinisme + audit-spor.
- BFHllm-kald er privacy-følsomme (kræver `data_consent = "explicit"`).
- AI-output kan hallucinere statistiske påstande — fagligt risikabelt.
- Eksisterende `use_ai = TRUE`-flow bevares som **polering** af
  template-output, ej erstatning.

### C. Atomisk sætnings-bibliotek + composition-regler (delvist adopteret)

Bibliotek af korte fakta-sætninger; render-lag plukker og komponerer
baseret på feature-objekt.

**Delvist adopteret:**
- Modifier-clauses ER atomiske sætninger der appendes.
- MEN: base + target + action bevares som strukturerede templates for
  at sikre coherens og læsbarhed. Ren atomisk composition risikerer
  robotisk stitched prose.

### D. Multi-pass refinement (afvist)

Pass 1: skelet. Pass 2: enrichment. Pass 3: polering.

**Afvist fordi:**
- Mod-deterministisk: samme input kan give forskelligt output afhængigt
  af hvor langt pass 3 når.
- Test-strategi bliver kompleks.
- Bidragyder forvirring: hvor lever hvilken logik?

## Consequences

### Positive

- **Klinisk-faglig dækning** af alle outcome-rum (alle 12 huller løses).
- **Skalerbar** tilføjelse af nye dimensioner uden cascade-refactor.
- **Audit-spor** for klinisk regulering (feature-objekt logges).
- **Genbrug** på tværs af PDF, app-UI, AI-prompt, JSON-export.
- **Bilingual parity** som design-egenskab, ej eftertanke.
- **Test-strategi forenklet**: features testes isoleret fra prose;
  modifier-clauses testes individuelt.

### Negative

- **Betydelig refactor**: ~2-3 ugers udvikling for full migrering.
- **Golden-corpus skal kurateres** med klinisk validering — ej trivielt.
- **i18n-corpus dobbeltspores** indtil cut-over (gammel + ny struktur
  side om side).
- **Schema-version vedligehold**: `bfh_spc_analysis`-objekt får sin egen
  semver-evolution.

### Risici og mitigation

| Risiko | Mitigation |
|--------|------------|
| Parity-test fanger ikke subtile output-ændringer | Snapshot-test på golden-corpus + manuel klinisk review-runde før cut-over |
| Modifier-interaktion giver inkoherent prose | Composition-test pr. modifier-kombination; eksplicit læsbarheds-review |
| Klinisk corpus drift fra implementation | Logging i staging: features → tekst-valg; klinikere flag'er afvigelser; corpus revideres månedligt |
| Schema-bump breaker downstream | `schema_version`-felt + `attr(.., "schema_version")` på objekt; downstream tjekker compatibility |
| Bilingual parity bryder | Test-suite tjekker placeholder-sæt + nøgle-paritet; CI-gate |

## References

- Archived change: `2026-05-15-goal-direction-tolerance` (direction-aware
  pattern præcedens for orthogonal axis dispatch).
- Archived change: `2026-05-14-at-target-tolerance-process-variation`
  (sigma-baseret tolerance — fundament for confidence-tier).
- NHS Improvement: "Making Data Count" — SPC interpretation principles.
- IHI: "The Improvement Guide" — clinical SPC text conventions.
- BFHcharts `spc-analysis-api`-spec — eksisterende kontrakter bevares
  som base; nye requirements lægges på.
