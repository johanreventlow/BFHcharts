## ADDED Requirements

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
