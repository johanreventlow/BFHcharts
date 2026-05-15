## ADDED Requirements

### Requirement: target-direction-aware classification SHALL use process-variation tolerance

`.evaluate_target_arm()` SHALL apply a process-variation cascade BEFORE
the strict direction-comparison when `target_direction ∈ {"higher",
"lower"}` (derived from operator-prefixed `metadata$target` like
`">= 90%"` or `"<= 5"`). Tolerance overrides strict comparison.

**Priority order (strict goal_met > near_target > goal_not_met):**

1. **Strict goal_met:** If direction-condition holds (`CL >= target` for
   higher, `CL <= target` for lower) → `goal_met`. Centerline on the
   correct side of target is always read as "met", regardless of distance.
2. **Near target:** If strict condition fails BUT `delta` is within
   process-variation tolerance → `near_target`. Tolerance cascade:
   - If `sigma_hat > 0` finite: `delta ≤ 3·sigma_hat`
   - Else if `sigma_data > 0` finite: `delta ≤ sigma_data`
   - Else: `delta < 1e-9`
3. **Goal not met:** Strict condition fails AND `delta` exceeds tolerance.

`near_target` thus represents "wrong side but statistically
indistinguishable from target" — used to render "lige under målet"
(higher direction, CL just below) or "lige over målet" (lower
direction, CL just above).

**Returns extended:** `.evaluate_target_arm()` returns named list with
`target_text`, `goal_met`, `at_target`, AND new field `near_target`
(logical).

#### Scenario: Tight process, higher target — near-target overrides goal_not_met

**Given** target `">= 90%"` (target_direction="higher", target_value=0.90)
**And** centerline = 0.895, sigma_hat = 0.02
**When** `.evaluate_target_arm()` evaluates
**Then** `delta = 0.005`, `3·sigma_hat = 0.06`, so `delta <= 3·sigma_hat`
**And** result$near_target SHALL be TRUE
**And** result$target_text SHALL match `texts$target$near_target` rendered
**And** result$goal_met SHALL be FALSE (strict condition failed)

```r
ctx <- fixture_analysis_context(
  target_value = 0.90, target_direction = "higher",
  centerline = 0.895, sigma_hat = 0.02
)
txt <- BFHcharts:::build_fallback_analysis(ctx)
expect_true(grepl("lige under udviklingsmålet", txt))
```

#### Scenario: Wide process, lower target — strict goal_met preserved

**Given** target `"<= 5%"` (target_direction="lower", target_value=0.05)
**And** centerline = 0.04, sigma_hat = 0.005
**When** `.evaluate_target_arm()` evaluates
**Then** centerline <= target strictly → result$goal_met SHALL be TRUE
**And** result$near_target SHALL be FALSE (strict goal_met has precedence)
**And** target template SHALL be `goal_met` (CL on correct side, even if
        delta within tolerance)

#### Scenario: Tight process, lower target — overshoot just above target

**Given** target `"<= 5%"`, centerline = 0.055, sigma_hat = 0.01
**When** `.evaluate_target_arm()` evaluates
**Then** `delta = 0.005, 3·sigma_hat = 0.03 → near_target = TRUE`
**And** target text SHALL contain "lige over udviklingsmålet"
**And** action SHALL be `stable_near_target` or `unstable_near_target`

#### Scenario: Far-from-target retains goal_not_met

**Given** target `">= 90%"`, centerline = 0.70, sigma_hat = 0.02
**When** `.evaluate_target_arm()` evaluates
**Then** `delta = 0.20, 3·sigma_hat = 0.06 → near_target = FALSE`
**And** strict comparison `0.70 < 0.90 → goal_not_met = TRUE`
**And** action SHALL be `stable_goal_not_met` or `unstable_goal_not_met`

### Requirement: Stability arm SHALL detect majority-at-centerline

`build_fallback_analysis()` SHALL detect when ≥ 50% of data points lie
exactly on the centerline (`|y − cl| < 1e-9` per point, no tolerance
parameter), and select a dedicated stability text that flags this
condition as a data-quality symptom.

**Detection priority:**

1. `no_variation` (all points identical, sigma=0) takes precedence
2. `majority_at_centerline`: `≥ 50%` of points exact-match cl AND
   NOT `no_variation`
3. Existing `.select_stability_key(flags)` for regular signal-based
   selection

**Threshold:** Exactly 0.5 (50%) inclusive.
**Tolerance:** Strict exact match (`1e-9`). No sigma-relative tolerance.

#### Scenario: 12 of 20 points exactly on CL — majority detected

**Given** qic_data with 20 points, 12 of which have y exactly equal to cl
**And** remaining 8 points have natural variation
**And** all signal-stats are valid (not no_variation)
**When** `build_fallback_analysis()` evaluates
**Then** stability text SHALL match `texts$stability$majority_at_centerline`
**And** text SHALL flag data-quality concern (e.g. discrete reporting)

#### Scenario: Exactly 50% on CL — boundary included

**Given** 10 of 20 points exact-match cl
**When** stability dispatcher evaluates
**Then** `majority_at_cl SHALL be TRUE` (≥ 50% inclusive)

#### Scenario: 49% on CL — falls through to regular dispatch

**Given** 9 of 20 points exact-match cl (45%)
**When** stability dispatcher evaluates
**Then** `majority_at_cl SHALL be FALSE`
**And** dispatcher SHALL fall through to `.select_stability_key(flags)`

#### Scenario: no_variation takes precedence over majority_at_cl

**Given** all 20 points have identical value (= cl)
**Then** technically 100% on CL → majority_at_cl could match
**But** no_variation takes precedence
**And** stability text SHALL match `texts$stability$no_variation`,
       NOT `majority_at_centerline`

---

### Requirement: action-arm SHALL expose near_target action keys

`.select_action_key()` SHALL return `stable_near_target` or
`unstable_near_target` when `target_direction` is set AND
`result$near_target == TRUE`.

- `stable_near_target` when `is_stable == TRUE`
- `unstable_near_target` when `is_stable == FALSE`

Priority: `near_target > goal_met > goal_not_met > at_target`.

Action templates SHALL use `{level_direction}` placeholder to render
direction-specific phrasing ("lige under målet" for higher-direction
shortfalls, "lige over målet" for lower-direction overshoots, "lige
på målet" for exact match).

#### Scenario: stable + near_target + higher direction

**Given** stable process, target=">=90%", centerline=0.895, sigma_hat=0.02
**When** action key is selected
**Then** key SHALL be `stable_near_target`
**And** rendered text SHALL contain "lige under" (level_direction="under"
        since CL < target)

#### Scenario: unstable + near_target + lower direction

**Given** unstable process, target="<=5%", centerline=0.055, sigma_hat=0.01
**When** action key is selected
**Then** key SHALL be `unstable_near_target`
**And** rendered text SHALL contain "lige over" (level_direction="over"
        since CL > target)
