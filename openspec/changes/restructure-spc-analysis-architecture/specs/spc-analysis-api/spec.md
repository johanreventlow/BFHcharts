## ADDED Requirements

### Requirement: bfh_analyse SHALL return a structured bfh_spc_analysis S3 object (key-only model)

The package SHALL export `bfh_analyse(x, metadata, language)` that returns
a structured `bfh_spc_analysis` S3-object using the **key-only model**:
conclusions, caveats and suggested_actions SHALL contain i18n-keys
(not resolved text strings). Text resolution SHALL occur exclusively in
`bfh_render_analysis()` via `texts_loader`.

This model preserves backward compatibility with existing
`bfh_generate_analysis(texts_loader = ...)` tests and enables
language-neutral JSON-export + audit-replay use cases.

**Function Signature:**
```r
bfh_analyse(
  x,
  metadata = list(),
  language = c("da", "en")
)
```

**Parameters:**
- `x`: `bfh_qic_result` object (required)
- `metadata`: Optional list with `data_definition`, `target`, `direction`,
  `hospital`, `department`, `analysis_date`
- `language`: Default language tag stored in object for downstream
  render-defaults; SHALL NOT cause text resolution at this stage

**Returns:** Object of class `bfh_spc_analysis` with documented schema.

The returned object SHALL contain at minimum:

- `schema_version` (character, semver-pattern) — schema version
- `language` (character, "da"/"en") — default for downstream render
- `features` (named list) — ortogonale fortolknings-akser (raw values)
- `aux` (named list) — beregnede hjælpe-værdier inkl. `sigma_hat`,
  `sigma_data`, `n_points`, `centerline`, `baseline_centerline`,
  `baseline_delta`, `latest_obs_date`, `analysis_date` (resolveret via
  3-vejs præcedens), `data_age_days`
- `render_context` (named list) — preserved render-state SHALL inkludere
  `target_display` (uændret user-input), `centerline_formatted`,
  `y_axis_unit`, `operator_unicode`, `outliers_word_key`
  (`"singular"`/`"plural"`), `effective_window`, `chart_type`
- `conclusions` (named list) — i18n-nøgler: `stability_key`,
  `target_key`, `action_key`
- `confidence` (character, "low"/"medium"/"high")
- `caveats` (named list) — nøgle-strings for aktive caveats (NULL hvis
  inaktiv)
- `suggested_actions` (character vector) — i18n-nøgler (ej resolverede
  tekst-strenge)

The object SHALL inherit from `bfh_spc_analysis`-class. `print()`,
`format()` and `as.list()` SHALL be defined as S3 methods. `bfh_analyse()`
SHALL NOT accept a `texts_loader` parameter (loader-ownership lives in
`bfh_render_analysis()`).

#### Scenario: Basic analysis produces structured object

**Given** a valid `bfh_qic_result`
**When** `bfh_analyse(result)` is called
**Then** the result SHALL inherit from `bfh_spc_analysis`
**And** `analysis$schema_version` SHALL match semver pattern
**And** `analysis$features` SHALL contain `stability_pattern`,
       `target_relation`, `confidence_tier`
**And** `analysis$aux` SHALL contain `sigma_hat`, `n_points`, `centerline`

```r
result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
analysis <- bfh_analyse(result)
expect_s3_class(analysis, "bfh_spc_analysis")
expect_match(analysis$schema_version, "^[0-9]+\\.[0-9]+\\.[0-9]+$")
expect_true(all(c("stability_pattern", "target_relation",
                  "confidence_tier") %in% names(analysis$features)))
```

#### Scenario: as.list() returns stable JSON-serializable structure

**Given** a `bfh_spc_analysis`-object
**When** `as.list(analysis)` is called
**Then** the result SHALL be a plain named list
**And** SHALL be JSON-serializable via `jsonlite::toJSON(auto_unbox=TRUE)`
**And** SHALL preserve all top-level fields

```r
analysis <- bfh_analyse(result)
flat <- as.list(analysis)
expect_type(flat, "list")
expect_false(inherits(flat, "bfh_spc_analysis"))
json <- jsonlite::toJSON(flat, auto_unbox = TRUE)
expect_true(jsonlite::validate(json))
```

---

### Requirement: bfh_extract_spc_features SHALL compute orthogonal feature axes

The package SHALL provide an internal pure function
`bfh_extract_spc_features(x, metadata)` that computes named feature-axes
from a `bfh_qic_result` and metadata. The function SHALL be
deterministic: identical input SHALL produce identical output.

**Feature axes (initial implementation):**

The function SHALL produce at minimum the following axes:

- `stability_pattern`: one of 10 values
  `c("no_signals", "runs_only", "crossings_only", "outliers_only",
    "runs_crossings", "runs_outliers", "crossings_outliers",
    "all_signals", "no_variation", "not_evaluable")`
- `target_relation`: one of `c("met", "near", "not_met", "none")`
- `confidence_tier`: one of `c("low", "medium", "high")`

Additional axes (`magnitude`, `direction`, `phase_context`, `freshness`,
`chart_class`, `cl_source`, `outlier_history`, `trend_form`,
`data_quality`) SHALL be present in the returned structure with
`NA`/empty values when their detection is not yet activated. This
guarantees schema stability across feature-slice activation.

**`confidence_tier` SHALL be computed deterministically AND
chart-type-aware:**

Run-charts have `sigma_hat = NA` by design (no control limits) — this is
NOT a degenerate state. The equivalent spread-estimate for run-charts is
`sigma_data` (`sd(y)`). Confidence-tier rules:

- `"high"` when `n_points >= 20` AND has finite spread-estimate
  (`sigma_hat` for control-charts; `sigma_data` for run-charts)
- `"medium"` when `n_points ∈ [12, 19]` AND has finite spread-estimate
- `"low"` when:
  - `n_points < N_MIN` (default 12, see `R/globals.R`) OR
  - centerline is not finite OR
  - both `sigma_hat` AND `sigma_data` are NA

**Forbid-pattern:** `is.na(sigma_hat)` alone SHALL NOT trigger `"low"` —
this would erroneously classify valid run-charts (sigma_hat=NA by design)
as `"low"`-confidence / not_evaluable. Existing test
`test-spc_analysis.R:1148` asserts run-chart `sigma_hat = NA` invariant.

`bfh_extract_spc_features()` SHALL accept `metadata$analysis_date` (or
fall back to `getOption("BFHcharts.analysis_date")` or `Sys.Date()`) and
SHALL store the resolved value in `aux$analysis_date`. Same `x` +
`metadata` SHALL produce identical features regardless of calendar day,
provided `analysis_date` is pinned.

#### Scenario: Feature extraction is deterministic

**Given** identical `bfh_qic_result` and metadata
**When** `bfh_extract_spc_features()` is called twice
**Then** both calls SHALL return identical structures (incl. all aux
       fields)

```r
features1 <- bfh_extract_spc_features(result)
features2 <- bfh_extract_spc_features(result)
expect_identical(features1, features2)
```

#### Scenario: Confidence tier reflects observation count

**Given** `bfh_qic_result` with n_points = 8
**When** `bfh_extract_spc_features()` is called
**Then** `features$confidence_tier` SHALL equal `"low"`

```r
result_short <- bfh_qic(test_data_n8, x = date, y = value, chart_type = "i")
features <- bfh_extract_spc_features(result_short)
expect_equal(features$confidence_tier, "low")
```

#### Scenario: Run-chart with sigma_hat=NA SHALL NOT be marked low confidence

**Given** `bfh_qic_result` from a 24-point run-chart (sigma_hat=NA, sigma_data finite)
**When** `bfh_extract_spc_features()` is called
**Then** `features$confidence_tier` SHALL equal `"high"`
**And** `aux$sigma_hat` SHALL be `NA_real_`
**And** `aux$sigma_data` SHALL be finite

```r
result_run <- bfh_qic(test_data_n24, x = date, y = value, chart_type = "run")
features <- bfh_extract_spc_features(result_run)
expect_equal(features$confidence_tier, "high")
expect_true(is.na(features$aux$sigma_hat) || is.na(result_run$qic_data$ucl[1]))
expect_true(is.finite(features$aux$sigma_data))
```

#### Scenario: analysis_date injection preserves determinism

**Given** identical `bfh_qic_result` and `metadata$analysis_date = "2026-01-15"`
**When** `bfh_extract_spc_features()` is called on different calendar days
**Then** both calls SHALL return identical `aux$analysis_date`
**And** identical `features$freshness`
**And** identical full feature vector

```r
metadata <- list(analysis_date = as.Date("2026-01-15"))
features1 <- bfh_extract_spc_features(result, metadata)
features2 <- bfh_extract_spc_features(result, metadata)
expect_identical(features1, features2)
expect_equal(features1$aux$analysis_date, as.Date("2026-01-15"))
```

---

### Requirement: bfh_render_analysis SHALL compose text via deterministic modifier cascade

The package SHALL provide `bfh_render_analysis(analysis, max_chars,
texts_loader = NULL)` that renders a `bfh_spc_analysis`-object to
character output via a deterministic composition cascade.

`bfh_render_analysis()` SHALL own all i18n-resolution: keys in
`analysis$conclusions`, `analysis$caveats` and `analysis$suggested_actions`
are resolved to text via the supplied `texts_loader` (or the default
`load_spc_texts(analysis$language)` when `texts_loader = NULL`).

`bfh_render_analysis()` SHALL use values from `analysis$render_context`
(target_display, centerline_formatted, y_axis_unit, operator_unicode,
outliers_word_key) when rendering placeholders. It SHALL NOT re-derive
these values from `analysis$features` or `analysis$aux`, since that would
risk display-drift (eg. changing `">= 90%"` to a different operator-form
or losing singular/plural agreement).

**Composition order (kanonisk, dokumenteret):**

1. **Blocking caveat check**: if `confidence_tier == "low"` →
   `not_evaluable`-base SHALL replace standard stability base;
   if `features$stability_pattern == "no_variation"` →
   `no_variation`-base SHALL replace standard stability base;
   if `features$data_quality$discrete_scale == "extreme"` →
   `discrete_scale_extreme`-base SHALL replace standard stability base
2. **Base sentence**: from `stability_pattern` (one of 10 values)
3. **Modifier-pool** (deterministisk prioritets-rækkefølge):
   `magnitude_clause` → `direction_clause` → `baseline_delta_clause` →
   `phase_intervention_clause` → `chart_class_modifier`
4. **Target clause**: from `target_relation` (eksisterende
   target-arm-logik, retning-aware)
5. **Action clause**: from action-key valgt baseret på alle features
   (eksisterende action-arm, modifier-context-aware)
6. **Tail caveats** (lavest prioritet, droppes først ved budget-pres):
   `variable_cl_caveat` → `cl_disclosure_caveat` → `freshness_caveat` →
   `historic_outliers_clause` → `seasonality_caveat`

**Budget-allokering:**
- Base + target + action: ~60% af `max_chars`
- Modifier-pool: ~25% af `max_chars`
- Tail caveats: ~15% af `max_chars`

Budget-trim sker fra bunden (tail caveats først, derefter modifier-pool,
aldrig base+target+action under deres minimum).

Output SHALL NEVER eksceed `max_chars`. `ensure_within_max()`-kontrakten
fra eksisterende spec opretholdes.

#### Scenario: Render produces deterministic output

**Given** identical `bfh_spc_analysis`-objekt og `max_chars`
**When** `bfh_render_analysis()` kaldes to gange
**Then** begge kald SHALL returnere identisk character

```r
analysis <- bfh_analyse(result)
text1 <- bfh_render_analysis(analysis, max_chars = 375)
text2 <- bfh_render_analysis(analysis, max_chars = 375)
expect_identical(text1, text2)
expect_lte(nchar(text1), 375)
```

#### Scenario: Low confidence tier overrides stability base

**Given** `bfh_spc_analysis` with `features$confidence_tier == "low"`
**When** `bfh_render_analysis()` kaldes
**Then** output SHALL indeholde `not_evaluable`-base
**And** SHALL NOT indeholde `runs_only`/`crossings_only`/`all_signals`-
       formuleringer (selv hvis `stability_pattern` har den værdi)

```r
analysis_low <- bfh_analyse(result_n8)
text <- bfh_render_analysis(analysis_low)
expect_match(text, "for kort serie|ikke evaluerbar")
expect_no_match(text, "skift i niveau")
```

---

### Requirement: bfh_spc_analysis schema_version SHALL follow semver

The `schema_version`-field of `bfh_spc_analysis`-objekter SHALL følge
semver 2.0:

- **MAJOR**: Breaking change i top-level struktur (felt fjernet,
  type ændret, semantik flyttet)
- **MINOR**: Tilføjelse af nyt felt (fx ny feature-akse) med
  bagudkompatibel default
- **PATCH**: Klargøring/dokumentation uden struktur-ændring

Downstream-konsumenter (biSPCharts) SHALL kunne tjekke `schema_version`
og advare hvis MAJOR ikke matcher forventet.

`schema_version` SHALL bumpes uafhængigt af pakke-version. Mapping
mellem pakke-version og schema-version SHALL dokumenteres i NEWS.md.

#### Scenario: Schema version is reported on every object

**Given** any call to `bfh_analyse()`
**When** object inspiceres
**Then** `schema_version` SHALL matche semver-pattern

```r
analysis <- bfh_analyse(result)
expect_match(analysis$schema_version, "^\\d+\\.\\d+\\.\\d+$")
```

---

### Requirement: Modifier i18n-keys SHALL maintain language parity

Modifier i18n-keys SHALL exist in both `inst/i18n/da.yaml` and
`inst/i18n/en.yaml` with identical key-paths, identical placeholder-sets
(`{centerline}`, `{target}`, `{level_direction}`, ...) and
language-appropriate magnitude-formatering (decimaltegn,
procent-rendering).

A CI-gate test SHALL fail when any modifier-key is missing in either
language, when placeholder-sets diverge, or when magnitude-formatting
violates language-specific rules.

#### Scenario: Adding modifier key requires both languages

**Given** ny modifier-clause-key tilføjet til `da.yaml`
**When** CI-test køres
**Then** test SHALL fejle hvis tilsvarende key mangler i `en.yaml`

```r
# Test eksempel:
test_that("i18n parity for analysis.modifier keys", {
  da_keys <- collect_yaml_paths(da_yaml, prefix = "analysis.modifier")
  en_keys <- collect_yaml_paths(en_yaml, prefix = "analysis.modifier")
  expect_setequal(da_keys, en_keys)
})
```

## MODIFIED Requirements

### Requirement: bfh_generate_analysis SHALL produce analysis with graceful fallback

The function SHALL generate analysis text for SPC charts with explicit
opt-in AI integration and automatic fallback to standard texts.
**Backward-compatible function signature is preserved.**

**Function Signature (uændret):**
```r
bfh_generate_analysis(
  x,
  metadata = list(),
  use_ai = FALSE,
  data_consent = NULL,
  use_rag = FALSE,
  min_chars = 300,
  max_chars = 375,
  target_tolerance = 0.05,  # deprecated, ignored
  language = "da",
  texts_loader = NULL
)
```

**Internal implementation (NY):**

The function SHALL be implemented as thin wrapper:

```r
bfh_generate_analysis(x, ...) {
  analysis <- bfh_analyse(x, metadata, language)
  baseline <- bfh_render_analysis(analysis, max_chars, texts_loader)
  if (use_ai) {
    # AI-augmented path: pass baseline as anchor to BFHllm
    ...
  } else {
    baseline
  }
}
```

**Backward-compat garantier:**

- Eksisterende output på golden-corpus SHALL bibeholdes bit-for-bit
  ved cut-over (Phase 2 parity-test) — så længe ingen modifier-slice
  er aktiveret.
- `texts_loader`-parameter respekteres og overrides default
  language-aware loader.
- `target_tolerance`-deprecation-warning bevares uændret.
- AI-egress-audit-event bevares uændret.
- `data_consent`-validering uændret.

**Forward-compat ændringer (efter slice-aktivering):**

- Output SHALL kunne indeholde modifier-clauses tilføjet ved aktiverede
  slices.
- `bfh_generate_analysis()`-output SHALL fortsat respektere `max_chars`.
- Når `confidence_tier == "low"`, output SHALL bruge
  `not_evaluable`-base (jf. ADDED Requirement
  `bfh_render_analysis SHALL compose text via deterministic modifier cascade`).

#### Scenario: Existing call signatures continue to work unchanged

**Given** existing caller code:
```r
analysis <- bfh_generate_analysis(
  result,
  metadata = list(target = ">= 90%"),
  language = "da",
  max_chars = 300
)
```
**When** package is upgraded with restructured implementation
**Then** call SHALL succeed without error
**And** output SHALL be character of length 1
**And** `nchar(output) <= 300`

```r
analysis <- bfh_generate_analysis(result, metadata = list(target = ">= 90%"))
expect_type(analysis, "character")
expect_length(analysis, 1)
expect_lte(nchar(analysis), 375)
```

#### Scenario: AI-path uses rendered character as baseline

**Given** `use_ai = TRUE` and `data_consent = "explicit"`
**When** `bfh_generate_analysis()` is called
**Then** internt SHALL `bfh_analyse()` kaldes først
**And** `bfh_render_analysis()` SHALL kaldes for at producere rendered
       character output
**And** den rendered character SHALL passes til BFHllm som
       `baseline_analysis` i `llm_context`-objektet (matcher eksisterende
       BFHllm-contract — `context$baseline_analysis` er character, ej
       struktureret objekt)
**And** audit-event SHALL emittes som hidtil

```r
# Mocked test — verificerer call-pattern
mock_bfhllm <- function(spc_result, context, ...) {
  expect_type(context$baseline_analysis, "character")
  expect_true(nchar(context$baseline_analysis) > 0)
  "AI-generated text"
}
# ... test setup ...
```

**Note:** Det strukturerede `bfh_spc_analysis`-objekt sendes IKKE til
BFHllm i denne change. Future-change kan introducere
`structured_analysis`-felt i BFHllm-context når BFHllm-side support +
audit-event-test er specificeret.

---

### Requirement: bfh_build_analysis_context SHALL collect complete context from bfh_qic_result

Eksisterende krav bibeholdes uændret. Funktionen SHALL fortsat være
public API-stable. **NY**: implementation refactores til at delegere
til `bfh_extract_spc_features()` internt; returneret struktur er
backward-compatible (samme felt-navne, samme typer).

Returneret liste SHALL bevare alle eksisterende felter
(`chart_title`, `chart_type`, `y_axis_unit`, `n_points`, `centerline`,
`spc_stats`, `has_signals`, `target_value`, `target_direction`,
`target_display`, `data_definition`, `hospital`, `department`).

`bfh_build_analysis_context()` MÅ tilføje yderligere felter
(`sigma_hat`, `sigma_data`, `n_on_cl_ratio` — disse eksisterer
allerede). Yderligere additive felter er tilladt, sletning er ikke.

#### Scenario: Existing context fields preserved

**Given** call to `bfh_build_analysis_context(result)`
**When** function returns
**Then** named-list SHALL contain alle eksisterende dokumenterede felter

```r
ctx <- bfh_build_analysis_context(result)
expected_fields <- c("chart_title", "chart_type", "y_axis_unit",
                     "n_points", "centerline", "spc_stats", "has_signals",
                     "target_value", "target_direction", "target_display")
expect_true(all(expected_fields %in% names(ctx)))
```

---

### Requirement: Fallback-narrative dispatch SHALL use named pure helpers

The named helpers SHALL remain callable through internal API gennem Phase 2 cut-over for backward compatibility med eksisterende parity-tests. Affected helpers: `.detect_signal_flags`, `.select_stability_key`, `.evaluate_target_arm`, `.select_action_key`, `.allocate_text_budget`. The helpers MUST continue to honor their existing
return-contracts. The helpers MAY be relocated to act as internal
implementation-helpers for `bfh_extract_spc_features()` og
`bfh_render_analysis()` snarere end direkte kaldt af
`build_fallback_analysis()`.

Post-Phase-2 cleanup: hvis disse helpers fjernes endeligt, SHALL det
ske i separat major-version-cycle med deprecation-warnings og NEWS-
markering.

#### Scenario: Helpers continue to be callable in Phase 1-2

**Given** code calling `BFHcharts:::.detect_signal_flags(context)`
**When** package is upgraded with new architecture (pre-cleanup)
**Then** call SHALL succeed
**And** return-struktur SHALL match eksisterende dokumenteret kontrakt

```r
flags <- BFHcharts:::.detect_signal_flags(ctx)
expect_true(all(c("has_runs", "has_crossings", "has_outliers",
                  "is_stable", "no_variation", "has_target") %in%
                names(flags)))
```
