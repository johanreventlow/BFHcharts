## REMOVED Requirements

### Requirement: bfh_interpret_spc_signals SHALL generate Danish standard texts for Anhøj signals

**Reason**: Funktionen producerer duplikeret tekst via hardcoded `sprintf()`-kald. Dens output (`context$signal_interpretations`) læses aldrig af `build_fallback_analysis()` i praksis — den er en død kodesti bevaret udelukkende pga. denne specifikation og de tilhørende tests. Alle Anhøj-fortolkninger genereres nu via YAML-skabelonerne i `inst/texts/spc_analysis.yml` og `build_fallback_analysis()`, der er eneste tekst-generator.

**Migration**: Eksterne kaldere (ingen fundet i BFHcharts-koden pr. review) skal i stedet bruge `bfh_generate_analysis()` der returnerer den samlede analysetekst. Hvis kun Anhøj-del ønskes, kan `bfh_extract_spc_stats()` kaldes direkte for at få `runs_actual`, `crossings_actual`, `outliers_recent_count` osv., og teksten genereres via YAML-opslag.

## MODIFIED Requirements

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

The function SHALL generate analysis text using AI when available, with automatic fallback to YAML-based standard texts. When target direction is known (via operator-prefixed `metadata$target`), the fallback text SHALL describe whether the goal is met or not met instead of value-neutral "over/under" wording.

**Function Signature:**
```r
bfh_generate_analysis(x, metadata = list(), use_ai = NULL,
                      min_chars = 300, max_chars = 375,
                      target_tolerance = 0.05)
```

**Parameters:**
- `x`: `bfh_qic_result` object (required)
- `metadata`: Optional context list; `target` may be numeric or character (supports operator prefixes)
- `use_ai`: Logical; NULL = auto-detect BFHllm
- `min_chars` / `max_chars`: Output length bounds
- `target_tolerance`: Fractional tolerance for `at_target` classification when direction is unknown (default 0.05)

**Returns:** Character string with analysis text bounded by `[min_chars, max_chars]` characters.

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

## ADDED Requirements

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
