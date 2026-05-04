# spc-analysis-api Specification

## Purpose

This capability owns internal signal-detection logic and analysis-text generation for BFHcharts: Anhøj rule interpretation, fallback-narrative dispatch, threshold semantics, target-direction parsing, and percent-target normalization. It governs _what signals mean_ — when they fire, how they map to clinician-facing analysis text, and how user-supplied parameters (custom centerline, target direction) influence interpretation.

Exported API surface contracts (function signatures, return types, attribute existence) are governed by the `public-api` capability. When a contract spans both (e.g. the `cl_user_supplied` attribute), `public-api` documents the API surface; this spec documents the underlying semantic meaning.

## Requirements
### Requirement: bfh_build_analysis_context SHALL collect complete context from bfh_qic_result

The function SHALL extract all relevant metadata from a `bfh_qic_result` object for analysis generation, including resolved target information with optional direction parsed from operator-prefixed strings.

**Function Signature:**
```r
bfh_build_analysis_context(x, metadata = list())
```

**Parameters:**
- `x`: `bfh_qic_result` object (required)
- `metadata`: Optional list with `data_definition`, `target`, `hospital`, `department`

**Returns:** Named list with complete context including `chart_title`, `chart_type`, `y_axis_unit`, `n_points`, `centerline`, `spc_stats`, `has_signals`, `target_value`, `target_direction`, `target_display`, plus user metadata.

The returned list SHALL NOT contain `signal_interpretations` (removed — see REMOVED Requirements).

When `metadata$target` is a character string, the function SHALL resolve it via the internal `resolve_target()` helper, which parses operators (`<=`, `>=`, `<`, `>`, `≤`, `≥`) to derive `target_direction`. Numeric `metadata$target` values SHALL yield `target_direction = NULL` for backward compatibility.

#### Scenario: Context built from bfh_qic_result

**Given** a valid `bfh_qic_result` object
**When** `bfh_build_analysis_context()` is called
**Then** the returned list SHALL contain: `chart_title`, `chart_type`, `n_points`, `spc_stats`, `has_signals`, `target_value`, `target_direction`, `target_display`

```r
result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
ctx <- bfh_build_analysis_context(result)
expect_true("chart_title" %in% names(ctx))
expect_true("spc_stats" %in% names(ctx))
expect_true("has_signals" %in% names(ctx))
expect_true("target_direction" %in% names(ctx))
expect_false("signal_interpretations" %in% names(ctx))
```

#### Scenario: Numeric target preserves backward compatibility

**Given** a `bfh_qic_result` with `metadata = list(target = 2.5)`
**When** `bfh_build_analysis_context()` is called
**Then** `target_value` SHALL equal `2.5` and `target_direction` SHALL be `NULL`

```r
ctx <- bfh_build_analysis_context(result, metadata = list(target = 2.5))
expect_equal(ctx$target_value, 2.5)
expect_null(ctx$target_direction)
```

#### Scenario: Operator-prefixed target yields direction

**Given** a `bfh_qic_result` with `metadata = list(target = "<= 2,5")`
**When** `bfh_build_analysis_context()` is called
**Then** `target_value` SHALL equal `2.5`, `target_direction` SHALL equal `"lower"`, and `target_display` SHALL equal `"<= 2,5"`

```r
ctx <- bfh_build_analysis_context(result, metadata = list(target = "<= 2,5"))
expect_equal(ctx$target_value, 2.5)
expect_equal(ctx$target_direction, "lower")
expect_equal(ctx$target_display, "<= 2,5")
```

#### Scenario: Invalid input rejected

**Given** a non-bfh_qic_result object
**When** `bfh_build_analysis_context()` is called
**Then** it SHALL throw an error mentioning "bfh_qic_result"

```r
expect_error(bfh_build_analysis_context(data.frame()), "bfh_qic_result")
```

---

### Requirement: bfh_generate_analysis SHALL produce analysis with graceful fallback

The function SHALL generate analysis text using AI **only when explicitly opted in** via `use_ai = TRUE`, with automatic fallback to YAML-based standard texts. When target direction is known (via operator-prefixed `metadata$target`), the fallback text SHALL describe whether the goal is met or not met instead of value-neutral "over/under" wording.

**Function Signature:**
```r
bfh_generate_analysis(x, metadata = list(), use_ai = FALSE,
                      min_chars = 300, max_chars = 375,
                      target_tolerance = 0.05)
```

**Parameters:**
- `x`: `bfh_qic_result` object (required)
- `metadata`: Optional context list; `target` may be numeric or character (supports operator prefixes)
- `use_ai`: Logical; **default `FALSE`**. Must be set explicitly to `TRUE` to enable external AI processing. The function SHALL NOT auto-detect `BFHllm` availability.
- `min_chars` / `max_chars`: Output length bounds
- `target_tolerance`: Fractional tolerance for `at_target` classification when direction is unknown (default 0.05)

**Returns:** Character string with analysis text bounded by `[min_chars, max_chars]` characters.

**Security rationale:** Implicit AI activation risks leaking `qic_data`, metadata, department, and hospital context to `BFHllm` (and any downstream services) without user consent. Default `FALSE` enforces explicit opt-in for external data processing in healthcare contexts.

#### Scenario: Default disables AI without auto-detection

**Given** `BFHllm` is installed on the system
**When** `bfh_generate_analysis(x)` is called without `use_ai` argument
**Then** the function SHALL NOT call `BFHllm::bfhllm_spc_suggestion()`
**And** it SHALL return fallback standard text

```r
# BFHllm present but no explicit opt-in
result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
with_mocked_bindings(
  bfhllm_spc_suggestion = function(...) stop("AI called without opt-in"),
  .package = "BFHllm",
  {
    analysis <- bfh_generate_analysis(result)
    expect_type(analysis, "character")
  }
)
```

#### Scenario: Fallback when AI disabled

**Given** a valid `bfh_qic_result`
**When** `bfh_generate_analysis()` is called with `use_ai = FALSE`
**Then** it SHALL return non-empty Danish standard text within the character bounds

```r
result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
analysis <- bfh_generate_analysis(result, use_ai = FALSE)
expect_type(analysis, "character")
expect_gte(nchar(analysis), 300)
expect_lte(nchar(analysis), 375)
```

#### Scenario: Explicit opt-in requires BFHllm installed

**Given** `BFHllm` is NOT installed
**When** `bfh_generate_analysis()` is called with `use_ai = TRUE`
**Then** the function SHALL raise an informative error naming the missing package

```r
# Without BFHllm
expect_error(
  bfh_generate_analysis(result, use_ai = TRUE),
  "BFHllm"
)
```

#### Scenario: max_chars is never exceeded

**Given** any valid `bfh_qic_result`
**When** `bfh_generate_analysis()` is called with any `max_chars`
**Then** the returned string SHALL satisfy `nchar(result) <= max_chars`

```r
analysis <- bfh_generate_analysis(result, use_ai = FALSE, max_chars = 250)
expect_lte(nchar(analysis), 250)
```

#### Scenario: Graceful fallback on AI error

**Given** BFHllm is installed but AI call fails
**When** `bfh_generate_analysis()` is called with `use_ai = TRUE`
**Then** it SHALL return standard text
**And** it SHOULD emit a warning

```r
result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
expect_warning(
  analysis <- bfh_generate_analysis(result, use_ai = TRUE),
  "standardtekster"
)
expect_gt(nchar(analysis), 0)
```

### Requirement: resolve_target SHALL parse target input into value and direction

The internal `resolve_target(target_input)` helper SHALL accept numeric, character, or NULL input and return a list with `value`, `direction`, and `display` fields. It SHALL reuse the existing `parse_target_input()` from `R/utils_label_helpers.R` to avoid duplicating parser logic.

**Function Signature:**
```r
resolve_target(target_input)
```

**Returns:** `list(value = numeric, direction = c("higher", "lower", NULL), display = character)`

**Direction mapping:**
- `>=`, `≥`, `↑` → `"higher"` (higher is better)
- `<=`, `≤`, `↓` → `"lower"` (lower is better)
- `>`, `<` with numeric value → `"higher"` / `"lower"`
- No operator → `NULL` (value-neutral)

**Numeric parsing:** SHALL accept Danish decimal comma (`"2,5"`) and dot (`"2.5"`) interchangeably.

#### Scenario: NULL input returns empty result

**Given** `target_input = NULL`
**When** `resolve_target()` is called
**Then** it SHALL return `list(value = NA_real_, direction = NULL, display = "")`

```r
r <- resolve_target(NULL)
expect_true(is.na(r$value))
expect_null(r$direction)
expect_equal(r$display, "")
```

#### Scenario: Numeric input preserves backward compatibility

**Given** `target_input = 2.5`
**When** `resolve_target()` is called
**Then** `value` SHALL equal `2.5` and `direction` SHALL be `NULL`

```r
r <- resolve_target(2.5)
expect_equal(r$value, 2.5)
expect_null(r$direction)
```

#### Scenario: Operator prefix yields direction

**Given** `target_input = "<= 2,5"`
**When** `resolve_target()` is called
**Then** `value` SHALL equal `2.5`, `direction` SHALL equal `"lower"`, and `display` SHALL equal `"<= 2,5"`

```r
r <- resolve_target("<= 2,5")
expect_equal(r$value, 2.5)
expect_equal(r$direction, "lower")
expect_equal(r$display, "<= 2,5")
```

#### Scenario: Higher-is-better with Unicode operator

**Given** `target_input = "≥ 90%"`
**When** `resolve_target()` is called
**Then** `direction` SHALL equal `"higher"` and `value` SHALL equal `90`

```r
r <- resolve_target("\U2265 90%")
expect_equal(r$direction, "higher")
expect_equal(r$value, 90)
```

#### Scenario: Plain character without operator

**Given** `target_input = "2,5"`
**When** `resolve_target()` is called
**Then** `value` SHALL equal `2.5` and `direction` SHALL be `NULL`

```r
r <- resolve_target("2,5")
expect_equal(r$value, 2.5)
expect_null(r$direction)
```

---

### Requirement: build_fallback_analysis SHALL use direction-aware goal logic when target direction is known

When `context$target_direction` is non-NULL, the internal `build_fallback_analysis()` SHALL compute `goal_met` based on whether the centerline satisfies the directional goal (CL ≥ target for `"higher"`, CL ≤ target for `"lower"`). The target text SHALL be selected from `texts$target$goal_met` or `texts$target$goal_not_met` instead of the value-neutral `over_target` / `under_target` / `at_target` branches. Action text SHALL be selected from `action$*_goal_met` / `action$*_goal_not_met` variants.

When `target_direction` is NULL, the function SHALL fall back to the pre-existing value-neutral logic (at/over/under within `target_tolerance`) for full backward compatibility.

#### Scenario: Lower-is-better goal met

**Given** `target_direction = "lower"`, `target_value = 2.5`, `centerline = 2.0`
**When** `build_fallback_analysis()` is invoked
**Then** the output SHALL reference "målet" combined with a phrase indicating the goal is met
**And** SHALL NOT contain "ligger under målet" (which is the value-neutral phrasing)

```r
ctx <- list(target_value = 2.5, target_direction = "lower", centerline = 2.0, ...)
txt <- build_fallback_analysis(ctx, ...)
expect_match(txt, "opfylder målet|målet.*nået")
expect_false(grepl("ligger under målet", txt))
```

#### Scenario: Higher-is-better goal not met

**Given** `target_direction = "higher"`, `target_value = 90`, `centerline = 85`
**When** `build_fallback_analysis()` is invoked
**Then** the output SHALL reference that the goal is not yet met

```r
ctx <- list(target_value = 90, target_direction = "higher", centerline = 85, ...)
txt <- build_fallback_analysis(ctx, ...)
expect_match(txt, "opfylder (ikke|endnu ikke) målet|endnu ikke nået")
```

#### Scenario: NULL direction preserves value-neutral behavior

**Given** `target_direction = NULL`, `target_value = 2.5`, `centerline = 3.0`
**When** `build_fallback_analysis()` is invoked
**Then** the output SHALL describe the centerline as "over" / "under" / "tæt på" the target

```r
ctx <- list(target_value = 2.5, target_direction = NULL, centerline = 3.0, ...)
txt <- build_fallback_analysis(ctx, ...)
expect_match(txt, "over|under|tæt på")
```

---

### Requirement: build_fallback_analysis SHALL guarantee output stays within character budget

The function SHALL produce output whose length is bounded by `[min_chars, max_chars]`. An internal `ensure_within_max()` helper SHALL trim at the last sentence or clause boundary (period, comma) before `max_chars` rather than mid-word when the combined parts would exceed the limit. When no target is present, the 25% target budget SHALL be redistributed to stability (65%) and action (35%) rather than being wasted.

#### Scenario: Output never exceeds max_chars

**Given** any valid context and `max_chars = 250`
**When** `build_fallback_analysis()` is invoked
**Then** `nchar(output) <= 250` SHALL hold

```r
for (scenario in test_scenarios) {
  txt <- build_fallback_analysis(scenario, max_chars = 250)
  expect_lte(nchar(txt), 250)
}
```

#### Scenario: Budget reallocation without target

**Given** a context with `target_value = NA` (no target)
**When** `build_fallback_analysis()` is invoked
**Then** stability + action text SHALL use most of `max_chars` (no 25% gap from missing target)

```r
ctx_no_target <- list(target_value = NA_real_, ...)
txt <- build_fallback_analysis(ctx_no_target, max_chars = 400)
expect_gte(nchar(txt), 300)
```

---

### Requirement: Analysis texts SHALL use correct Danish singular/plural for outliers

The YAML templates SHALL support a `{outliers_word}` placeholder that substitutes to `"observation"` when `outliers_actual == 1` and `"observationer"` otherwise. The internal `pluralize_da()` helper SHALL power this substitution.

#### Scenario: Single outlier uses singular form

**Given** a context with exactly 1 recent outlier
**When** `build_fallback_analysis()` is invoked
**Then** the output SHALL contain "1 observation" (not "1 observationer")

```r
ctx <- list(spc_stats = list(outliers_recent_count = 1, ...), ...)
txt <- build_fallback_analysis(ctx, ...)
expect_match(txt, "1 observation\\b")
expect_false(grepl("1 observationer", txt))
```

#### Scenario: Multiple outliers use plural form

**Given** a context with 3 recent outliers
**When** `build_fallback_analysis()` is invoked
**Then** the output SHALL contain "3 observationer"

```r
ctx <- list(spc_stats = list(outliers_recent_count = 3, ...), ...)
txt <- build_fallback_analysis(ctx, ...)
expect_match(txt, "3 observationer")
```

### Requirement: bfh_build_analysis_context SHALL normalize percent targets to proportion scale

The `bfh_build_analysis_context()` function SHALL detect when a target is expressed in percent format (`y_axis_unit = "percent"` AND target display contains `"%"`) and SHALL normalize the stored `target_value` from 0-100 scale to 0-1 (proportion) scale before placing it in the returned context. This ensures downstream consumers (notably `build_fallback_analysis()`) compare `target_value` against `centerline` on a consistent scale.

**Rationale:**

For percent-formatted SPC charts (p, pp), `qicharts2::qic()` returns `centerline` on the proportion scale (`0.91` for 91%), but `parse_target_input("≥ 90%")` strips the percent suffix and returns the raw numeric `90`. Without normalization, the comparison `centerline >= target_value` evaluates `0.91 >= 90 → FALSE`, producing clinically misleading auto-analysis text such as "målet er endnu ikke nået" when the centerline actually exceeds the percent target.

This bug was identified in Codex code review 2026-04-29 (FIX NOW severity) with runtime verification that `target = ">= 90%"` on a p-chart with `centerline = 0.91` produced the wrong directional verdict.

**Normalization contract:**

| Input | y_axis_unit | target_display contains "%" | parsed target_value | Stored target_value |
|-------|-------------|----------------------------|---------------------|---------------------|
| `">= 90%"` | `"percent"` | yes | 90 | **0.90** (normalized) |
| `90` (numeric) | `"percent"` | no display, value > 1 | 90 | **0.90** (normalized) |
| `0.9` (numeric) | `"percent"` | no display, value <= 1 | 0.9 | 0.9 (unchanged) |
| `">= 0.9"` | `"percent"` | no | 0.9 | 0.9 (unchanged) |
| `">= 90"` | `"count"` | no | 90 | 90 (unchanged) |
| `"<= 2.5"` | `"rate"` | no | 2.5 | 2.5 (unchanged) |

**Heuristic:**
- Normalize when `y_axis_unit == "percent"` AND (`target_display` contains literal `"%"` OR (`target_value > 1` AND no operator-prefixed display containing `"%"`-stripped value))
- Pure proportion inputs (`target = 0.9`, `target = "≥ 0.9"`) are preserved to allow power-users explicit control

**Implementation note:**

A new internal helper `.normalize_percent_target(value, display, y_axis_unit)` SHALL encapsulate the heuristic to enable direct unit testing independent of the full context-build path. The helper SHALL be called once per `bfh_build_analysis_context()` invocation, between `resolve_target()` and context list construction.

The `target_display` field in the returned context SHALL retain the original (un-normalized) string, so user-facing rendered text continues to display "≥ 90%" rather than "≥ 0.90".

#### Scenario: Percent target normalized to proportion scale

- **GIVEN** a p-chart `bfh_qic_result` with `centerline = 0.91`, `y_axis_unit = "percent"`
- **AND** `metadata$target = ">= 90%"`
- **WHEN** `bfh_build_analysis_context()` is called
- **THEN** `context$target_value` SHALL equal `0.90` (not `90`)
- **AND** `context$target_display` SHALL equal `">= 90%"` (preserved)
- **AND** `context$target_direction` SHALL equal `"higher"`

```r
result <- bfh_qic(p_chart_data, ...)  # centerline = 0.91, y_axis_unit = "percent"
ctx <- bfh_build_analysis_context(result, metadata = list(target = ">= 90%"))

expect_equal(ctx$target_value, 0.90, tolerance = 1e-9)
expect_equal(ctx$target_display, ">= 90%")
expect_equal(ctx$target_direction, "higher")
```

#### Scenario: Higher-is-better goal met after normalization

- **GIVEN** the normalized context from the previous scenario
- **WHEN** `build_fallback_analysis(ctx, ...)` is called
- **THEN** the output SHALL describe the goal as met (not "endnu ikke nået")

```r
ctx <- list(
  target_value = 0.90, target_direction = "higher",
  target_display = ">= 90%", y_axis_unit = "percent",
  centerline = 0.91, ...
)
txt <- build_fallback_analysis(ctx, max_chars = 400, language = "da")

expect_match(txt, "opfylder målet|målet.*opfyldt|målet.*nået")
expect_false(grepl("endnu ikke nået|opfylder ikke", txt))
```

#### Scenario: Lower-is-better percent target normalized

- **GIVEN** a p-chart with `centerline = 0.03`, `y_axis_unit = "percent"`
- **AND** `metadata$target = "<= 5%"`
- **WHEN** `bfh_build_analysis_context()` is called
- **THEN** `context$target_value` SHALL equal `0.05`
- **AND** `context$target_direction` SHALL equal `"lower"`
- **AND** subsequent `build_fallback_analysis()` SHALL describe the goal as met

```r
ctx <- bfh_build_analysis_context(low_p_result, metadata = list(target = "<= 5%"))
expect_equal(ctx$target_value, 0.05, tolerance = 1e-9)
txt <- build_fallback_analysis(ctx, max_chars = 400, language = "da")
expect_match(txt, "opfylder målet|målet.*opfyldt")
```

#### Scenario: Numeric percent target normalized when value exceeds 1

- **GIVEN** a p-chart with `y_axis_unit = "percent"`
- **AND** `metadata$target = 90` (bare numeric, no operator)
- **WHEN** `bfh_build_analysis_context()` is called
- **THEN** `context$target_value` SHALL equal `0.90`

```r
ctx <- bfh_build_analysis_context(p_result, metadata = list(target = 90))
expect_equal(ctx$target_value, 0.90, tolerance = 1e-9)
```

#### Scenario: Numeric proportion target preserved on percent chart

- **GIVEN** a p-chart with `y_axis_unit = "percent"`
- **AND** `metadata$target = 0.9` (numeric, already on proportion scale)
- **WHEN** `bfh_build_analysis_context()` is called
- **THEN** `context$target_value` SHALL equal `0.9` (unchanged — heuristic detects value <= 1)

```r
ctx <- bfh_build_analysis_context(p_result, metadata = list(target = 0.9))
expect_equal(ctx$target_value, 0.9, tolerance = 1e-9)
```

#### Scenario: Non-percent chart targets unchanged

- **GIVEN** an i-chart with `y_axis_unit = "count"`
- **AND** `metadata$target = ">= 90"`
- **WHEN** `bfh_build_analysis_context()` is called
- **THEN** `context$target_value` SHALL equal `90` (no normalization — y_axis_unit is not "percent")

```r
ctx <- bfh_build_analysis_context(i_result, metadata = list(target = ">= 90"))
expect_equal(ctx$target_value, 90)
```

#### Scenario: Explicit proportion string preserved

- **GIVEN** a p-chart with `y_axis_unit = "percent"`
- **AND** `metadata$target = ">= 0.9"` (no `%` in display)
- **WHEN** `bfh_build_analysis_context()` is called
- **THEN** `context$target_value` SHALL equal `0.9` (unchanged — display lacks `%`, allows power-user override)

```r
ctx <- bfh_build_analysis_context(p_result, metadata = list(target = ">= 0.9"))
expect_equal(ctx$target_value, 0.9, tolerance = 1e-9)
expect_equal(ctx$target_display, ">= 0.9")
```

### Requirement: outliers_recent_count window SHALL be configurable via named constant and report effective window

The package SHALL define a named constant `RECENT_OBS_WINDOW` in `R/globals.R` documenting the recency window used by `bfh_extract_spc_stats.bfh_qic_result()` for `outliers_recent_count`. The stats output SHALL include an `effective_window` field reporting the actual number of observations considered (capped by `n_obs`).

**Rationale:**
- The hardcoded "6" lacks documented rationale and is not derived from Anhøj literature
- Downstream consumers and analysis text need to know the actual window used (especially for short parts)
- A named constant enables future configurability without scattering the magic number
- Boundary correctness (n_obs < window) cannot be verified without exposed effective_window

**Contract:**

| `n_obs` | `effective_window` | `outliers_recent_count` |
|---|---|---|
| 0 | 0 | 0 |
| 1 | 1 | sum(sigma.signal[1:1]) |
| 5 | 5 | sum(sigma.signal[1:5]) |
| 6 | 6 | sum(sigma.signal[1:6]) |
| 7 | 6 | sum(sigma.signal[2:7]) |
| 100 | 6 | sum(sigma.signal[95:100]) |

#### Scenario: short part returns truncated effective_window

- **GIVEN** a `bfh_qic_result` whose latest part has only 3 observations
- **WHEN** `bfh_extract_spc_stats(result)` is called
- **THEN** `stats$effective_window` SHALL equal 3
- **AND** `stats$outliers_recent_count` SHALL equal `sum(sigma.signal[1:3])`

```r
sigma <- c(TRUE, FALSE, TRUE)  # 2 outliers in 3 obs
result <- fixture_bfh_qic_result(sigma, chart_type = "i")
stats <- bfh_extract_spc_stats(result)
expect_equal(stats$effective_window, 3)
expect_equal(stats$outliers_recent_count, 2)
```

#### Scenario: long part caps effective_window at RECENT_OBS_WINDOW

- **GIVEN** a `bfh_qic_result` with 100 observations and outliers only at indexes 1–10
- **WHEN** `bfh_extract_spc_stats(result)` is called
- **THEN** `stats$effective_window` SHALL equal `RECENT_OBS_WINDOW` (6)
- **AND** `stats$outliers_recent_count` SHALL equal 0 (none in last 6)

```r
sigma <- c(rep(TRUE, 10), rep(FALSE, 90))
result <- fixture_bfh_qic_result(sigma, chart_type = "i")
stats <- bfh_extract_spc_stats(result)
expect_equal(stats$effective_window, 6)
expect_equal(stats$outliers_recent_count, 0)
```

#### Scenario: empty sigma.signal returns zero values

- **GIVEN** a part with `sigma.signal = logical(0)` or all NA
- **WHEN** `bfh_extract_spc_stats(result)` is called
- **THEN** `stats$outliers_recent_count` SHALL be 0
- **AND** `stats$effective_window` SHALL be 0 or `min(RECENT_OBS_WINDOW, n_obs)`

#### Scenario: fallback analysis text references effective window

- **GIVEN** a part with 3 observations, all outliers
- **WHEN** `bfh_generate_analysis(result)` is called with fallback (no AI)
- **THEN** the output text SHALL reference "seneste 3 observationer" (NOT hardcoded "6")
- **AND** the count SHALL match `effective_window`

```r
result <- fixture_bfh_qic_result(rep(TRUE, 3), chart_type = "i")
text <- bfh_generate_analysis(result, use_ai = FALSE)
expect_match(text, "seneste 3 observationer", ignore.case = TRUE)
expect_false(grepl("seneste 6 observationer", text))
```

### Requirement: Fallback-narrative dispatch SHALL use named pure helpers

The dispatch logic that maps detected SPC signals to fallback-narrative i18n keys SHALL be expressed as named pure helpers, not as nested boolean cascades. The orchestrator `build_fallback_analysis()` SHALL be ≤100 lines and SHALL contain no nested `if/else if` chains for cascade dispatch — only top-level orchestration calls (detect flags → allocate budget → evaluate target arm → select keys → look up i18n strings → assemble markdown → pad).

The following private helpers SHALL exist in `R/spc_analysis.R`:

- `.detect_signal_flags(context)` — pure function returning a named-logical struct with at minimum the fields `(has_runs, has_crossings, has_outliers, is_stable, no_variation, has_target, outliers_for_text)`
- `.allocate_text_budget(max_chars, has_target)` — pure function returning a named-integer struct `(stability_budget, target_budget, action_budget)`
- `.select_stability_key(flags)` — pure function returning a character scalar i18n key
- `.select_action_key(flags, target_direction, goal_met, at_target)` — pure function returning a character scalar i18n key
- `.evaluate_target_arm(context, flags, texts, target_budget, target_tolerance)` — function returning named list `(target_text, goal_met, at_target)` for the target-arm cascade. Performs i18n lookup internally so the orchestrator does not need a separate target cascade.

Helpers SHALL be `@keywords internal @noRd`. The dispatch helpers (`.select_stability_key`, `.select_action_key`) SHALL emit i18n keys, not translated strings; translation happens at the orchestrator boundary via existing `pick_text()` + `i18n_lookup()`. The target-arm helper performs i18n lookup itself because the cascade arms have different placeholder shapes that would be awkward to thread through the orchestrator.

#### Scenario: build_fallback_analysis is a thin orchestrator

- **WHEN** the package source is inspected for `R/spc_analysis.R`
- **THEN** `build_fallback_analysis()` SHALL be ≤100 lines and SHALL contain no nested `if/else if` chains for cascade dispatch (only top-level orchestration calls + placeholder construction + markdown assembly)
- **AND** the five helpers `.detect_signal_flags()`, `.allocate_text_budget()`, `.select_stability_key()`, `.select_action_key()`, `.evaluate_target_arm()` SHALL exist in the same file

#### Scenario: dispatch helpers are unit-testable as data tables

- **WHEN** unit tests for `.select_stability_key()` and `.select_action_key()` are run
- **THEN** the tests SHALL exercise each helper via a table of `(flag_combination, expected_key)` rows covering at minimum every key currently produced by the cascade
- **AND** the tests SHALL pass without invoking `bfh_generate_analysis()` or any function above the dispatch layer

#### Scenario: adding a new fallback-narrative arm is a single-file edit

- **WHEN** a new cascade arm is added (e.g. for a new chart type or signal combination)
- **THEN** the change SHALL consist of: one new key in the appropriate `.select_*_key()` helper, one new i18n string in `inst/i18n/`, and one new test row in the table-driven test
- **AND** no edit to `build_fallback_analysis()` or to other dispatch helpers SHALL be required

#### Scenario: existing fallback narrative output is unchanged

- **WHEN** the existing fallback-analysis tests in `tests/testthat/test-spc_analysis.R` are run after refactor
- **THEN** all tests SHALL pass without modification (zero behavioral change)
- **AND** the integration tests covering `bfh_generate_analysis(use_ai = FALSE)` SHALL produce byte-identical narrative output for every existing input scenario

### Requirement: SPC analysis API specification ownership

The `spc-analysis-api` capability SHALL govern internal signal-detection logic and analysis-text generation: Anhøj rule interpretation, fallback-narrative dispatch, threshold semantics, target-direction parsing, and percent-target normalization rules. It SHALL NOT govern exported API surfaces (function signatures, return types, attribute existence) — those concerns are owned by `public-api`.

When a contract spans both capabilities, this spec SHALL document the underlying meaning (when a signal fires, what semantic interpretation applies, how thresholds are evaluated) without restating the API surface details documented in `public-api`.

Cross-references SHALL be expressed as prose ("See public-api Requirement: X for the API contract") rather than formal links.

**Rationale:**
- Anhøj rule interpretation, narrative-text dispatch, and target-direction semantics evolve as the package gains nuance from clinical feedback — these refinements are typically additive or clarifying, not breaking.
- API stability concerns (does the function exist? what does it return?) belong with the user-facing surface contract.
- Without explicit ownership boundaries, requirements describing the same thing from different angles drift apart over time.

#### Scenario: Purpose section identifies ownership

- **WHEN** a contributor reads `openspec/specs/spc-analysis-api/spec.md`
- **THEN** the `## Purpose` section SHALL state that this capability owns internal signal-detection logic, fallback-narrative dispatch, and threshold/target semantics
- **AND** the Purpose SHALL explicitly delegate exported API surface contracts (signatures, return types, attribute existence) to `public-api`

#### Scenario: Cross-reference rather than duplication

- **WHEN** an `spc-analysis-api` requirement describes signal semantics whose API surface is governed by `public-api` (e.g. `cl_user_supplied` attribute meaning, custom-`cl` Anhøj-signal caveat)
- **THEN** the `spc-analysis-api` requirement SHALL state the semantic meaning (what the signal implies for interpretation)
- **AND** SHALL include a prose cross-reference like "See public-api Requirement: <name> for the API surface contract"
- **AND** SHALL NOT duplicate signature or return-type details
