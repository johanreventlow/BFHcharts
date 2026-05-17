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
- **Roughly 50+ reachable text paths** (afhænger af counting-method:
  10 stability-keys × ~5 effektive action-paths, hvor action-dispatch er
  mutually exclusive på target-præsens).
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
       │  - stability_pattern (10 værdier inkl │
       │    no_variation + not_evaluable)      │
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
# Model A (key-only): conclusions, caveats, suggested_actions lagrer
# i18n-noegler --- IKKE resolverede strenge. Render-lag haandterer al
# sprog-/tekst-resolution via texts_loader.

bfh_spc_analysis <- structure(
  list(
    schema_version = "1.0",
    language = "da",                        # default sprog for senere render
    features = list(
      stability_pattern = "runs_only",   # 1 af 10 værdier (inkl. no_variation, not_evaluable)
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
        discrete_scale = "none",           # none | mild | moderate | extreme
        missing_denominators = FALSE
      ),
      cl_source = "data_estimated",        # data_estimated | user_supplied | auto_mean
      outlier_history = "current_only"     # current_only | historic_only | both | none
    ),
    aux = list(
      sigma_hat = 0.02,                    # NA for run-charts (by design)
      sigma_data = 0.018,
      n_points = 24,
      effective_window = 6,
      centerline = 0.87,
      baseline_centerline = 0.92,
      baseline_delta = -0.05,
      baseline_delta_pct = -5.4,
      latest_obs_date = as.Date("2026-04-30"),
      data_age_days = 17,
      analysis_date = as.Date("2026-05-17") # injected via metadata > option > Sys.Date()
    ),
    render_context = list(
      # Render-state der maa bevares for at parity-test + clinical-prose
      # ej drifter. Renderer SKAL bruge disse felter --- ikke re-derive fra
      # features/aux.
      target_display = "\U2265 90%",       # original user-input, ej modificeret
      centerline_formatted = "87%",         # format_target_value-output
      y_axis_unit = "percent",
      operator_unicode = "\U2265",         # ASCII-til-Unicode-konvertering
      outliers_word_key = "plural",        # singular | plural (resolveres af loader)
      effective_window = 6L,
      chart_type = "i"                      # raw chart_type fra config
    ),
    conclusions = list(
      stability_key = "runs_only",          # i18n-noegle, ej tekst
      target_key = "near_target",
      action_key = "stable_near_target"
    ),
    confidence = "high",                    # afspejler features$confidence_tier
    caveats = list(
      # Liste af AKTIVE caveat-noegler (NULL hvis inaktiv). Render-lag
      # resolverer noegle til tekst via texts$labels$caveats[[key]].
      cl_source = NULL,                     # NULL hvis data_estimated
      freshness = NULL,
      few_obs = NULL,
      variable_cl = NULL,
      historic_outliers = NULL,
      seasonality = NULL
    ),
    suggested_actions = c(
      # Character-vektor af i18n-noegler. Render-lag mapper noegle til
      # action-tekst via texts$action[[key]].
      "stable_near_target",
      "monitor_continuously"
    )
  ),
  class = "bfh_spc_analysis"
)
```

**Hvorfor key-only (Model A):**

Mønstret matcher eksisterende `.select_*_key()`-funktioner der returnerer
nøgler. Tekst-resolution sker først ved `pick_text()` + `texts_loader`
ved render-tid. Konsekvenser:

- **JSON-export sprog-neutral**: Audit-objektet ser ens ud uanset sprog.
- **Re-render mulig**: Samme analyse kan rendres på dansk + engelsk uden
  re-extraction af features.
- **Test-isolation**: Feature-extraction testes uden i18n-mocking.
- **`texts_loader` bevaret**: Eksisterende
  `bfh_generate_analysis(texts_loader = ...)`-tests fungerer uændret —
  loader threades fra `bfh_generate_analysis()` til
  `bfh_render_analysis()`.

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

### Confidence-tier semantik (chart-type-aware)

**Vigtigt:** Run-charts har `sigma_hat = NA` by design (ingen
kontrolgrænser). `is.na(sigma_hat)` er ikke en degenereret tilstand for
run-charts — tilsvarende statistik er `sigma_data` (sd(y)) + Anhøj-stats.
Confidence-tier-detektion SKAL være chart-type-aware:

| Tier   | Kriterier (chart-type-aware)            | Effekt på output           |
|--------|-----------------------------------------|----------------------------|
| `high` | n ≥ 20 AND har finite spredning-estimat (sigma_hat for control-charts; sigma_data for run-charts) | Direkte påstande |
| `med`  | n ∈ [12, 19] AND har finite spredning-estimat | Hedge-ord: "tegn på", "ser ud til" |
| `low`  | n < N_MIN (default 12) ELLER manglende centerline ELLER is.na(both sigma_hat and sigma_data) | `not_evaluable`-base, eksplicit "for kort serie" |

**Forbid-pattern:** Brug **ikke** `is.na(sigma_hat)` alene som
low-trigger. Det ville fejlagtigt klassificere alle valide run-charts som
not_evaluable. Eksisterende test asserter dette eksplicit
(`test-spc_analysis.R:1148`).

**Litteratur-reference:**

Confidence-tier thresholds er konsistente med Anhøj-litteraturens
detection-power-analyse. Run-detection-power synker kraftigt under n=12;
over n=20 er detection robust mod outlier-clustering.

> Anhøj J, Olesen AV (2014). Run charts revisited: a simulation study of
> run chart rules for detection of non-random variation in health care
> processes. *PLoS One*. 9(11):e113825.

Tier styrer **også om en konklusion overhovedet rapporteres** (lav tier
→ kort tekst med eksplicit usikkerhed, ikke spekulativ påstand).

### Determinisme + analysis_date-injection

`bfh_extract_spc_features()` SHALL være deterministisk: samme
`bfh_qic_result` + metadata SHALL altid producere samme feature-vector.

**Problem:** Naturlige tids-baserede features (freshness via
`max(x_dato) - Sys.Date()`) bryder determinisme — samme input giver
forskellige features pr. kalenderdag. Audit-replay (re-rendre historisk
rapport fra arkiveret data 6 mdr senere) bliver umulig.

**Løsning:** `analysis_date` injiceres via 3-vejs præcedens-resolution:

1. `metadata$analysis_date` — eksplicit per-call (vinder altid)
2. `getOption("BFHcharts.analysis_date")` — global override (typisk i tests)
3. `Sys.Date()` — production-default

Resolvet `analysis_date` lagres i `analysis$aux$analysis_date` for
sporbarhed. Golden-corpus pinner `analysis_date` eksplicit pr. case.

**Konsekvens for use-cases:**

| Use-case | Mekanisme |
|----------|-----------|
| Production prod-kald | `Sys.Date()`-default — freshness mod nu |
| Golden-test | `metadata$analysis_date = "2026-01-15"` pinned pr. case |
| Test-suite globalt | `options(BFHcharts.analysis_date = ...)` i `setup.R` |
| Audit-replay | `metadata$analysis_date = original_analysis_date` fra arkiveret rapport |

### Backward-compat strategi

**Pre-cut-over (`tasks 1-3`):**
- Ny `bfh_extract_spc_features()` parallel med eksisterende
  `bfh_build_analysis_context()`.
- Ny `bfh_render_analysis(analysis, max_chars, texts_loader)` parallel med
  `build_fallback_analysis()`. `texts_loader`-ownership ligger i
  render-lag (Model A key-only).
- Parity-test på golden-corpus: gammelt output skal **semantisk matche**
  nyt output uden modifikatorer aktiveret. Semantisk match defineres som:
  - Eksakt tekst-equality efter whitespace-normalisering
  - Tegnbudget-trim acceptabel inden for ±5 tegn fra base
  - Decimal-separator-tolerance kun ved intenderet sprog-skift
- Corpus-scope: **~60 cases** (40-50 mekanisk parameter-sweep over
  stability/target/action/sprog/percent/trim-boundary + 10-15 kuraterede
  klinisk-validerede real-world cases).

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

**AI-baseline contract:** Eksisterende kode passerer `baseline_analysis`
som **rendered character** til `BFHllm::bfhllm_spc_suggestion()`
(R/spc_analysis.R:565-567). Denne change bevarer kontrakten: rendered
output fra `bfh_render_analysis()` passes som baseline. Det strukturerede
`bfh_spc_analysis`-objekt sendes **ej** til BFHllm i denne change.
Future-change kan introducere `structured_analysis`-felt i BFHllm-context
når BFHllm-side support + audit-event-test er specificeret.

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
