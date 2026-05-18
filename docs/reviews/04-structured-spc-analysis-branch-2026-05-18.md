# Cycle 04 — Structured SPC Analysis Branch (Final Review, 2026-05-18)

**Område:** Hele `feat/structured-spc-analysis`-branch.
**Subject:** 17 commits, +8409/-140 LOC over 64 filer.
**Baseline:** master `392ff20`. Head: HEAD (efter cycle-04 simplify).
**Trigger:** Bruger-anmodet `/dual-review-cycle` på samlet diff inden release-godkendelse.

---

## Scope

Komplet branch-review før eventuel release (per WIP-direktiv: ingen merge/PR endnu).

Verificerer:
1. Arkitektonisk konsistens på tværs af 16 commits
2. Spec-vs-implementation-drift
3. Cross-cutting bugs spc_features → spc_compose → spc_render
4. Cross-repo contract til biSPCharts
5. Schema-stability claims

**Phase 1 fund** (Claude + code-analyzer + Explore-agent). **Phase 3 Codex-pass** afventes inden reconcile.

---

## H1 [HIGH] — Mixed decimal-separators ved language="en"

**Lokation:** `R/spc_features.R:451-462` (.format_centerline_for_render),
`R/spc_render.R:189-197` (.render_baseline_delta_modifier),
`R/spc_render.R:282` (.build_placeholder_data centerline-placeholder).

**Symptom:** `render_context$centerline_formatted` præ-computes på extract-time med hardcoded `language = "da"`. Renderen substituerer værdien verbatim i caller's sprog. For non-integer centerline + language="en" producerer output **mixed decimal-separators**.

**Verifikation (kode-citat):**

```r
# R/spc_features.R:457 (.format_centerline_for_render)
format_target_value(cl,
  y_axis_unit = context$y_axis_unit,
  language = "da"        # <-- HARDCODED
)
```

```r
# R/spc_render.R:189-197 (.render_baseline_delta_modifier)
baseline_value <- format_target_value(baseline_cl,
  y_axis_unit = y_axis_unit, language = language)   # caller-language
current_value <- analysis$render_context$centerline_formatted  # hardcoded da
```

For language="en", baseline=12.34, current=13.45:
- baseline_value = "11.50" (engelsk punktum)
- current_value = "13,45" (dansk komma — hardcoded)

**Konsekvens:** Klinisk-vendt engelsk output mixer decimal-syntax. Specifikt rammer baseline-delta-modifier (Slice 5) hvor begge værdier vises i samme sætning.

**Foreslået fix:** Re-format ved render-time. Strip `centerline_formatted` fra render_context, eller pass `language` til `.format_centerline_for_render`. Render-lag har `analysis$language`, `analysis$aux$centerline`, `analysis$render_context$y_axis_unit` — alle nødvendige inputs.

---

## H2 [MEDIUM] — Magnitude near-zero sigma giver falsk "large"-klassifikation

**Lokation:** `R/spc_features.R:585-598` (.compute_magnitude).

**Symptom:** Sigma-guard accepterer `> 0` ej `> noise-threshold`. Real-world: næsten-konstant data med UCL≈LCL kan give `sigma_hat ≈ 1e-12`. Enhver baseline-delta over `2e-12` klassificeres som `"large"` magnitude.

**Verifikation:**

```r
# R/spc_features.R:585-592
sigma <- if (is_valid_scalar(sigma_hat) && is.finite(sigma_hat) && sigma_hat > 0) {
    sigma_hat
  } else if (is_valid_scalar(sigma_data) && is.finite(sigma_data) && sigma_data > 0) {
    sigma_data
  } ...
ratio <- abs(baseline_delta) / sigma
```

**Konsekvens:** False-confidence i klinisk prose. Konstante eller næsten-konstante data der får mikroskopisk baseline-skift (float-noise eller rounding) renderes som "(en betydelig forandring på ~X%)".

**Foreslået fix:** Minimum-sigma-floor relativt til centerline-skala:

```r
sigma_min <- max(1e-6, 1e-9 * abs(centerline %||% 1))
sigma <- if (... && sigma_hat > sigma_min) sigma_hat
         else if (... && sigma_data > sigma_min) sigma_data
         else return(NA_character_)
```

Alternativt: sanity-check på ratio (`if (ratio > 100) return(NA_character_)` med advarsel).

---

## H3 [MEDIUM] — Spec-drift: `aux$data_age_days` ikke implementeret

**Lokation:** `openspec/.../specs/spc-analysis-api/spec.md:41` vs `R/spc_features.R` aux-list.

**Symptom:** spec.md kræver:
> `aux` (named list) — beregnede helpere inkl. ..., `data_age_days`

`grep "data_age_days"` returnerer NUL matches i R/. `aux$analysis_date` + `aux$latest_obs_date` findes, men deres differens er ej pre-computed.

**Konsekvens:** Downstream-konsumenter der følger spec-kontrakten finder ikke feltet → silent NA i features pr. spec, runtime-error hvis access.

**Foreslået fix:** Enten tilføj computation i `bfh_extract_spc_features`:
```r
aux$data_age_days <- as.integer(aux$analysis_date - aux$latest_obs_date)
```
Eller fjern fra spec som SKIP (jf. Slice 10 Freshness SKIP-beslutning — `data_age_days` driver freshness-detektion, så konsistent at fjerne).

---

## H4 [MEDIUM] — Spec-drift: `stability_pattern` enum lover not_evaluable, never set

**Lokation:** `spec.md:108-113` vs `R/spc_features.R:200-205` (.resolve_stability_pattern).

**Symptom:** spec.md siger `stability_pattern` har 10 enum-værdier inkl `"not_evaluable"`. Implementation kalder `.select_stability_key()` → 8 signal-keys + 2 overrides (`no_variation`, `majority_at_centerline`). `"not_evaluable"` sættes ALDRIG som feature-værdi.

`R/spc_render.R:362` håndterer low-confidence ved at **swappe template** (`texts$base$not_evaluable`) men `features$stability_pattern` bevarer signal-baseret key.

**Konsekvens:** Schema-konsumer der læser `features$stability_pattern` for UI-badge ser fx "runs_only" mens render-output siger "for kort serie til vurdering". Inkonsistens mellem struktureret state og rentekst.

**Foreslået fix:** I `.resolve_stability_pattern`, hvis `confidence_tier == "low"` (eller ekvivalent guard), returnér `"not_evaluable"`. Render-lag kan så skippe stability-template-swap (key fortæller render-vej).

---

## H5 [MEDIUM] — Spec-drift: modifier-budget ej proportional

**Lokation:** `spec.md:248-251` vs `R/spc_render.R:161,203` (.render_magnitude_modifier + .render_direction_modifier).

**Symptom:** spec.md foreskriver:
> Modifier-pool: 25% af max_chars
> Tail caveats: 15% af max_chars

Implementation bruger fast `budget = 200L` per modifier:

```r
# R/spc_render.R:161
pick_text(templates, data = data, budget = 200L)
# R/spc_render.R:203
pick_text(templates, data = data, budget = 200L)
```

Ingen proportional allocation. Aggregeret modifier-output kan overflow → `ensure_within_max` trimer i bunden, men `pick_text`-variant-valg er allerede besluttet ud fra 200L.

**Konsekvens:** Ved max_chars=200 (klinisk-rapport-margin) får modifier-pool 200L hver = 200% af total-budget. `ensure_within_max` truncerer aggressivt → klippet prose midt i sætning.

**Foreslået fix:** Compute proportional budget:
```r
modifier_budget <- floor(max_chars * 0.25 / n_active_modifiers)
```
Eller dokumentér spec.md-justering: implementation valgte fixed-200L per modifier som upper-bound (ikke proportional).

---

## M1 [LOW] — `few_obs`-caveat unreachable

**Lokation:** `R/spc_compose.R:204` (.compose_caveats) + `R/spc_render.R:244` (.render_tail_caveats).

**Symptom:** `.compose_caveats` sætter `few_obs = "few_obs"` når `n < N_MIN`. `.render_tail_caveats` itererer over `c("cl_source", "discrete_scale", "variable_cl")` — `few_obs` er IKKE i listen.

**Verifikation:**
```r
# R/spc_compose.R:204
few_obs = if (isTRUE(features$data_quality$few_obs)) "few_obs" else NULL,

# R/spc_render.R:244
caveat_slots <- c("cl_source", "discrete_scale", "variable_cl")
```

**Konsekvens:** Schema-felt advertises som "aktiv" men har ingen render-effekt. Intentionelt skadeskift: low-confidence-override erstatter stability-base (Slice 8) → few_obs-caveat er duplikat. Men API-overflade er forvirrende.

**Foreslået fix:** Enten:
- Drop `few_obs` fra `.compose_caveats` (sæt altid NULL); dokumentér at low-confidence-override er primær mekanisme
- Eller tilføj `"few_obs"` til `caveat_slots` (kun aktiv hvis render-policy ønsker dobbelt-flagging)

Anbefaling: drop. Slice 8's base-override er stærkere kontrakt.

---

## M2 [LOW] — Test-fixtures bruger bare `set.seed()` (pre-/simplify bug genopstår)

**Lokation:** `tests/testthat/test-spc_features.R:16-21`, `test-spc_compose.R:8`, `test-spc_render.R:8`.

**Symptom:** Module-load-time `set.seed(42L)` etc i test-fil top. Hvis test-runner ændrer file-execution-order, kan RNG-state lække mellem test-filer.

**Verifikation:** `git grep "^set\.seed" tests/testthat/test-spc_*.R` viser 4 forekomster. Slice 14 fix flyttede set.seed inside-function via withr; pattern ej anvendt i Phase 1-test-filerne.

**Konsekvens:** Test-isolation-fragilitet. Allerede observeret i Slice 14 cycle. Test-suite passer nu, men risiko ved fremtidig file-tilføjelse / reordering.

**Foreslået fix:** Migrer 4 testfiler til `withr::with_seed(seed, fixture-construction)` pattern (samme som helper-fixtures.R).

---

## M3 [LOW] — Test-cache aldrig invalideret

**Lokation:** `tests/testthat/helper-fixtures.R:383-384` (.fixture_qic_cache, .fixture_analyse_cache).

**Symptom:** Cache er package-env. Levetid = R-session. Hvis to tests bruger samme `cache_key` med forskellig metadata, returnerer cache stale-objekt.

**Verifikation:**
```r
# helper-fixtures.R:383-384
.fixture_qic_cache <- new.env(parent = emptyenv())
.fixture_analyse_cache <- new.env(parent = emptyenv())
```

Ingen cleanup mellem tests. `bfh_reset_caches()`-call findes ikke i helper-cache.R for disse caches.

**Konsekvens:** Hvis fremtidig test specificerer ny `metadata$direction = "lower_better"` med samme cache_key som tidligere kald uden direction, returneres stale-objekt → falsk pass.

**Foreslået fix:** Tilføj `bfh_reset_fixture_cache()` invocation i `tests/testthat/setup.R` (eller equivalent), ELLER inkluder hash-fingerprint af alle args i cache_key.

---

## M4 [LOW] — Hardcoded ANALYSIS_DATE drift-risk

**Lokation:** `test-spc_golden_corpus.R:12` (`ANALYSIS_DATE <- as.Date("2026-05-18")`) vs `helper-fixtures.R:417` (`metadata$analysis_date <- as.Date("2026-05-18")`).

**Symptom:** To distinkte hardcoded dato-konstanter. Hvis én opdateres, drifter test-suite.

**Foreslået fix:** Single source-of-truth i helper-fixtures.R:
```r
TEST_ANALYSIS_DATE <- as.Date("2026-05-18")
```
Importér via `cat -E` til golden_corpus.

---

## Sammenfatning før Codex-pass

| ID | Severity | Type | Status |
|----|----------|------|--------|
| H1 | HIGH | Faktuel bug (mixed decimals) | Verified empirisk |
| H2 | MEDIUM | Edge-case (sigma-floor) | Verified math |
| H3 | MEDIUM | Spec-drift (data_age_days) | Verified via grep |
| H4 | MEDIUM | Spec-drift (not_evaluable enum) | Verified via code-read |
| H5 | MEDIUM | Spec-drift (budget proportional) | Verified via code-read |
| M1 | LOW | Unreachable caveat-slot | Verified |
| M2 | LOW | Test-fixture set.seed pattern | Verified via grep |
| M3 | LOW | Test-cache uden invalidation | Verified |
| M4 | LOW | Hardcoded ANALYSIS_DATE drift | Verified |

**Verdict foreløbig:** Solid arkitektur, men 1 HIGH-bug + 4 MEDIUM spec-drifts + 3 LOW process-issues.

**Anbefaling:** Fix H1 + H2 før eventuel release. H3-H5 spec-drift: enten implementer eller justér spec.md. M1-M4: ryd op før biSPCharts adopterer.

---

## Codex adversarial-review konsekvens (2026-05-18)

**Verdict: needs-attention / no-ship**

Codex bekræftede 8 af 9 fund + introducerede 1 NYT MEDIUM. Verdict skærpes:
H4 reklassificeret som **HIGH** (downstream-contract failure, ej kun cosmetic).

### Bekræftet (verified empirisk i denne reconcile):

| ID | Codex-verdict | Severity-aendring |
|----|---------------|-------------------|
| H1 | confirmed | HIGH (unaendret) |
| H2 | confirmed + fix-recalibration | MEDIUM (unaendret) — proposed sigma_min formula skal redesignes |
| H3 | recalibrated | MEDIUM — primaert spec-drift, ej implementation-bug |
| H4 | confirmed | **HIGH** (eskaleret fra MEDIUM) — implementation-bug ej cosmetic |
| H5 | confirmed worse | MEDIUM — produces broken prose ved max_chars=200, ej kun spec-drift |
| M1-M3 | confirmed | LOW (unaendret) |
| M4 | confirmed broader | LOW — `2026-05-18` appears beyond 2 locations |

### NYT fund (Codex caught):

#### N1 [MEDIUM] — `render_context$effective_window` spec-drift

**Lokation:** `R/spc_features.R:156-167` vs `spec.md` ADDED-section.

**Reproduktion:** Spec siger render_context SHALL include `effective_window`. Implementation builds render_context uden field. Class-validator + schema-stability-test BEGGE omit field fra required-listen. Drift er masked.

**Konsekvens:** Spec-konsumenter forventer `effective_window` i render_context; faar NULL trods vaerdien er tilgaengelig i `aux$effective_window`. Bug fra-tre-sider: spec, implementation, og test.

**Foreslået fix:** Implementation-side: tilfoej `effective_window` til render_context. Validator + test opdateres til at krave det. Alternativ: fjern fra spec hvis aux er kanonisk kilde.

### Impact-bucketing for Codex-saves:

| Bucket | Findings |
|--------|----------|
| Hard runtime / user-visible regression | H1 (mixed decimals i engelsk output) |
| Downstream-contract break | H4 (downstream UI badges baseret paa stability_pattern faar forkert state for low-confidence) |
| Silent corruption / semantic drift | H2 (microscopic sigma -> false large), H5 (broken prose ved max_chars=200) |
| Spec-contract drift | H3 (data_age_days), N1 (effective_window) |
| Process / cleanup | M1, M2, M3, M4 |

**Real ROI: Codex caught 5 saves (2 hard + 2 silent + 1 spec) der havde brudt downstream-konsumenter eller produceret klinisk-fejlagtig prose hvis branch var shipped.**

### Recalibreret fix-strategi

**FØR release:** Block-fixes (H1, H4, H5, N1) — alle producerer downstream-failure.
**Felter at fixe:**
1. **H1** — Move centerline-formatering til render-time. Strip `render_context$centerline_formatted`. Compute lokalt i `.build_placeholder_data` og `.render_baseline_delta_modifier` med `analysis$language`.
2. **H4** — `.resolve_stability_pattern` returnerer `"not_evaluable"` naar `confidence_tier == "low"`. Render-lag tjekker key (ej confidence) for template-selection.
3. **H5** — Proportional modifier-budget. Compute `modifier_budget <- floor(max_chars * 0.25 / n_active_modifiers)`. Pass til hver modifier-renderer.
4. **N1** — Tilfoej `effective_window` til render_context + opdater validator + schema-test.
5. **M1** — Drop `few_obs` fra `.compose_caveats` (sæt altid NULL). Low-confidence override er primaer mekanisme.

**Defer til foelg-op:**
6. **H2** — Sigma-floor design kraever scale/unit-awareness. Brug ratio-cap (`ratio > 100 -> NA`) som midlertidigt safety-net.
7. **H3** — Beslut: implementere `aux$data_age_days = analysis_date - latest_obs_date` ELLER fjern fra spec som Slice 10 SKIP-consequence.
8. **M2-M4** — Test-pattern-cleanup; ikke blocking.

### Læring

Branch-wide dual-review på final state fanger fund per-commit-review missede. Specifikt:
- Spec-vs-implementation drift kraever hele-branch perspektiv
- Cross-cutting bugs (centerline_formatted hardcoded "da") rammer KUN paa specific code-path (en-render + baseline-delta)
- Codex catched implementation-bugs reklassificeret fra spec-drift (H4) — eksplicit asking "implementation-bug or spec-bug?" var critical prompt-element.

### Pending implementations

Forsoeger fixes H1, H4, H5, N1, M1 i denne session. H2 + H3 deferreres med konkret follow-up-plan.
