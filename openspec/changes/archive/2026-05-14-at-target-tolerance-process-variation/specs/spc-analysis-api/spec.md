## MODIFIED Requirements

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
- `target_tolerance`: **DEPRECATED**. Argument is preserved in the signature for backward compatibility but is ignored by the value-neutral `at_target` classification logic, which now uses process variation (UCL/LCL) instead. Passing a non-default value SHALL emit `lifecycle::deprecate_warn()`. Parameter will be removed in the next major release.

**Returns:** Character string with analysis text bounded by `[min_chars, max_chars]` characters.

**Security rationale:** Implicit AI activation risks leaking `qic_data`, metadata, department, and hospital context to `BFHllm` (and any downstream services) without user consent. Default `FALSE` enforces explicit opt-in for external data processing in healthcare contexts.

#### Scenario: target_tolerance deprecation warning fires when set to non-default

**Given** `target_tolerance` is passed explicitly as a non-default value (e.g. `0.1`)
**When** `bfh_generate_analysis()` is called
**Then** the function SHALL emit a `lifecycle::deprecate_warn()` deprecation warning
**And** the value SHALL be ignored — classification SHALL follow the process-variation rule regardless

```r
expect_warning(
  bfh_generate_analysis(result, target_tolerance = 0.1),
  "deprecat"
)
```

#### Scenario: Default target_tolerance does not warn

**Given** `target_tolerance` is left at its default (`0.05`)
**When** `bfh_generate_analysis()` is called
**Then** no deprecation warning SHALL fire

```r
expect_no_warning(bfh_generate_analysis(result))
```

---

### Requirement: build_fallback_analysis SHALL use direction-aware goal logic when target direction is known

When `context$target_direction` is non-NULL, the internal `build_fallback_analysis()` SHALL compute `goal_met` based on whether the centerline satisfies the directional goal (CL ≥ target for `"higher"`, CL ≤ target for `"lower"`). The target text SHALL be selected from `texts$target$goal_met` or `texts$target$goal_not_met` instead of the value-neutral `over_target` / `under_target` / `at_target` branches. Action text SHALL be selected from `action$*_goal_met` / `action$*_goal_not_met` variants.

When `target_direction` is NULL, the function SHALL fall back to value-neutral logic. The `at_target` classification within the value-neutral branch SHALL use process variation (see separate Requirement: *Value-neutral at_target classification SHALL use process variation as tolerance scale*) rather than a relative-to-target tolerance.

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

## ADDED Requirements

### Requirement: Value-neutral at_target classification SHALL use process variation as tolerance scale

When `context$target_direction` is `NULL` and a target value is present, `.evaluate_target_arm()` SHALL classify the centerline relative to the target using a three-tier cascade rooted in the process's own variation, not in a relative-to-target tolerance:

**Tier 1 — Control-limit-based (primary):**

When control limits are available and `sigma_hat = mean((UCL_i − LCL_i) / 6)` over the last phase is finite and strictly positive:

```text
at_target  ⟺  |centerline − target| ≤ 3 · sigma_hat
```

The `3·sigma_hat` threshold matches the 3-sigma SPC convention for control limits. For constant limits this reduces trivially to `LCL ≤ target ≤ UCL`.

**Tier 2 — Data-σ fallback:**

When control limits are unavailable (e.g. run charts, where `qic_data` has no `ucl`/`lcl` columns) or `sigma_hat` is zero or NA:

```text
at_target  ⟺  |centerline − target| ≤ sd(y)
```

where `sd(y)` is the standard deviation of `y` values over the last phase.

**Tier 3 — Exact-match degenerate case:**

When both `sigma_hat` and `sd(y)` are zero or undefined (constant series, `n = 1`):

```text
at_target  ⟺  |centerline − target| < 1e-9
```

**`over_target` / `under_target` classification:**

These SHALL be determined purely factually from `centerline` vs `target`, without any tolerance:

```text
over_target  ⟺  centerline > target  AND  NOT at_target
under_target ⟺  centerline < target  AND  NOT at_target
```

Only the "close to target" classification requires a scale; over/under are factual observations.

#### Scenario: Small target with tight control limits — bug reproducer

**Given** a chart with `target = 0.01`, `centerline = 0.019`, and tight control limits such that `sigma_hat ≈ 0.0017` (UCL − LCL ≈ 0.01)
**When** `.evaluate_target_arm()` is invoked with `target_direction = NULL`
**Then** the function SHALL classify the centerline as `over_target`, NOT `at_target`
**And** the downstream `action_key` SHALL be one of the `*_not_at_target` variants

```r
# Tight process with target = 1%, CL = 1.9% — historically misclassified as at_target
ctx <- list(target_value = 0.01, target_direction = NULL, centerline = 0.019, ...)
# sigma_hat ≈ 0.0017 → 3·sigma_hat ≈ 0.005
# |0.019 - 0.01| = 0.009 > 0.005 → NOT at_target
result <- .evaluate_target_arm(ctx, ...)
expect_false(result$at_target)
expect_match(result$target_text, "over målet")
```

#### Scenario: Wide control limits — target inside band

**Given** a chart with `target = 5`, `centerline = 7`, and wide control limits (UCL = 12, LCL = 2, sigma_hat ≈ 1.67)
**When** `.evaluate_target_arm()` is invoked with `target_direction = NULL`
**Then** the function SHALL classify the centerline as `at_target`
**And** the target text SHALL contain "tæt på målet"

```r
ctx <- list(target_value = 5, target_direction = NULL, centerline = 7, ...)
# 3·sigma_hat ≈ 5; |7 - 5| = 2 < 5 → at_target
result <- .evaluate_target_arm(ctx, ...)
expect_true(result$at_target)
expect_match(result$target_text, "tæt på målet")
```

#### Scenario: Run chart falls back to data sd

**Given** a `chart_type = "run"` chart where `qic_data` has no `ucl`/`lcl` columns, `target = 10`, `centerline = 11`, and `sd(y) ≈ 2`
**When** `.evaluate_target_arm()` is invoked with `target_direction = NULL`
**Then** the function SHALL fall back to the data-σ tier
**And** classify the centerline as `at_target` (since `|11 - 10| = 1 < sd(y) = 2`)

```r
ctx <- list(target_value = 10, target_direction = NULL, centerline = 11,
            chart_type = "run", sigma_hat = NA_real_, sigma_data = 2, ...)
result <- .evaluate_target_arm(ctx, ...)
expect_true(result$at_target)
```

#### Scenario: Degenerate constant series

**Given** a chart with `centerline = 5`, `target = 5`, and zero variation (all `y = 5`, so `sigma_hat = 0` and `sd(y) = 0`)
**When** `.evaluate_target_arm()` is invoked with `target_direction = NULL`
**Then** the function SHALL apply the exact-match tier
**And** classify the centerline as `at_target`

```r
ctx <- list(target_value = 5, target_direction = NULL, centerline = 5,
            sigma_hat = 0, sigma_data = 0, ...)
result <- .evaluate_target_arm(ctx, ...)
expect_true(result$at_target)
```

#### Scenario: Variable-n p-chart uses mean sigma_hat over last phase

**Given** a p-chart with variable subgroup sizes such that UCL/LCL vary per row, with rows in the last phase having `(UCL - LCL)/6` values of `c(0.01, 0.02, 0.015)`
**When** `build_analysis_context()` populates `sigma_hat`
**Then** `sigma_hat` SHALL equal `mean(c(0.01, 0.02, 0.015)) = 0.015`

```r
qic_data <- data.frame(
  ucl = c(0.06, 0.07, 0.065),
  lcl = c(0.00, 0.01, 0.005),
  part = c(1, 1, 1),
  ...
)
ctx <- build_analysis_context(qic_result, ...)
expect_equal(ctx$sigma_hat, mean(c(0.01, 0.01, 0.01)), tolerance = 1e-9)
```

#### Scenario: Target precisely on UCL boundary

**Given** `target` is exactly equal to UCL (so `|CL − target| = 3·sigma_hat` exactly)
**When** `.evaluate_target_arm()` is invoked
**Then** the boundary SHALL be inclusive — classification is `at_target` (using `≤`, not `<`)

```r
# CL = 5, UCL = 8, LCL = 2 → sigma_hat = 1; 3·sigma_hat = 3
# target = 8 → |5 - 8| = 3 ≤ 3 → at_target
ctx <- list(target_value = 8, target_direction = NULL, centerline = 5,
            sigma_hat = 1, ...)
result <- .evaluate_target_arm(ctx, ...)
expect_true(result$at_target)
```

#### Scenario: Multi-phase chart uses last phase only

**Given** a median-split chart with two phases, where phase 1 has UCL−LCL = 4 and phase 2 has UCL−LCL = 1
**When** `build_analysis_context()` populates `sigma_hat`
**Then** `sigma_hat` SHALL be computed from phase 2 alone (last phase), matching the `centerline` choice

```r
# Phase 1 has wider variation (already excluded from CL choice)
# Phase 2 is the operative phase
qic_data <- data.frame(
  ucl = c(8, 8, 8, 6, 6, 6),
  lcl = c(4, 4, 4, 5, 5, 5),
  part = c(1, 1, 1, 2, 2, 2),
  ...
)
ctx <- build_analysis_context(qic_result, ...)
# Phase 2: (UCL - LCL)/6 = 1/6 ≈ 0.167
expect_equal(ctx$sigma_hat, 1/6, tolerance = 1e-9)
```
