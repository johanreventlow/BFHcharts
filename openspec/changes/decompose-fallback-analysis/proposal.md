## Why

`build_fallback_analysis()` in `R/spc_analysis.R` is a 210-line function that mixes four abstraction levels (signal-flag detection, text-budget allocation, key dispatch, padding) inside three sequential boolean cascades that map signal tuples to template keys. Every time a new chart-type signal or stability state is added, the cascade must be edited in three coordinated places — exactly the kind of code that grows bugs.

Decomposing the cascade into named helpers makes the dispatch table-test friendly: each helper accepts a typed flag struct and returns a string key. New signals become a single new test row, not a multi-place edit.

## What Changes

- Extract `.detect_signal_flags(spc_stats)` returning a named-logical struct: `(has_runs, has_crossings, has_outliers, is_stable, has_target, target_direction, goal_met, at_target)`.
- Extract `.allocate_text_budget(max_chars, has_target)` returning numeric `(budget_stability, budget_action)`.
- Extract `.select_stability_key(flags)` returning string key for the stability-narrative arm of the cascade.
- Extract `.select_action_key(flags, has_target, target_direction, goal_met, at_target, is_stable)` returning string key for the action-narrative arm.
- Reduce orchestrator `build_fallback_analysis()` to ≤60 lines: detect flags → allocate budgets → select keys → look up i18n strings → assemble markdown → pad.
- Each helper is pure: same inputs always produce same key. Suitable for `expect_equal()` table tests.
- Behavior unchanged: no observable change to fallback narrative output. Existing snapshot/integration tests must continue to pass.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `spc-analysis-api`: refines `bfh_generate_analysis()` fallback-pipeline organization. Current spec describes the user-visible behavior; this change adds an internal-structure requirement that the cascade dispatch lives in named pure helpers.

## Impact

- `R/spc_analysis.R`: file grows from 1 to 5 functions in the fallback-analysis section; LOC roughly unchanged.
- `tests/testthat/test-spc_analysis.R` (extension): table-driven tests for `.detect_signal_flags()` and the two `.select_*_key()` helpers covering at least one row per current cascade arm.
- biSPCharts: no public API change. `bfh_generate_analysis()` signature stable.
- No statistical validation needed (no Anhøj-rule or control-limit logic touched).
- No NEWS.md user-visible entry (internal refactor); add bullet under `## Internal changes` for next release.
- Future extension benefit: when biSPCharts maintainer requests a new fallback-narrative arm (e.g. for a new chart type), edit becomes a single new key + one i18n string + one new test row — no multi-place cascade edit.
