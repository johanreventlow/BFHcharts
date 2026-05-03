## Context

`R/spc_analysis.R` (~929 lines) is the package's largest single file and houses four logically distinct concerns:

1. Target resolution (`resolve_target()`)
2. Danish text formatting utilities (`pluralize_da()`, `pick_text()`, `substitute_placeholders()`, `pad_to_minimum()`, `ensure_within_max()`)
3. Analysis context construction (`bfh_build_analysis_context()`, `bfh_generate_analysis()`)
4. Fallback narrative generation (`build_fallback_analysis()`)

Concern #4 is where the boolean-cascade lives. It owns the logic that picks one of ~15 narrative templates based on a tuple of detected signals (runs, crossings, outliers, stability, target presence, target direction, goal met, at target). Today this is encoded as three nested `if/else if/else if` chains spanning 210 lines (`R/spc_analysis.R:608-817`).

The separate concern #2 (Danish text utilities) is a candidate for extraction in a sibling change `extract-utils-text-da`. This proposal focuses solely on concern #4 — the dispatch decomposition.

Constraints:

- **Behavior must not change.** Existing fallback-narrative tests (`tests/testthat/test-spc_analysis.R`) cover all current cascade arms; they must continue to pass without modification.
- **`bfh_generate_analysis()` is exported.** Its signature and return contract must remain stable. Only internal helpers below the fallback boundary may change.
- **biSPCharts consumes `bfh_generate_analysis()`** via `BFHcharts::bfh_generate_analysis()`. No expected impact since only internals change.

## Goals / Non-Goals

**Goals:**

- Decompose `build_fallback_analysis()` into orchestrator (≤60 lines) + 4 named pure helpers.
- Each helper is unit-testable in isolation via table-driven tests.
- Adding a new cascade arm becomes a single new test row + one new key + one new i18n string — no multi-place edit.
- Zero behavioral change. Same narrative output for every input today.

**Non-Goals:**

- Restructuring `bfh_generate_analysis()` (the AI-vs-fallback dispatch above this layer is out of scope).
- Extracting Danish text utilities (`pluralize_da()`, `pick_text()`, etc.) — covered by sibling proposal `extract-utils-text-da`.
- Adding new cascade arms or new signal types. This is pure refactor.
- Changing the i18n key naming scheme.
- Performance optimization.

## Decisions

### Decision 1: Four pure helpers, all returning typed structs

**Choice:**

1. `.detect_signal_flags(spc_stats)` → named logical list
   ```r
   list(
     has_runs = TRUE/FALSE,
     has_crossings = TRUE/FALSE,
     has_outliers = TRUE/FALSE,
     is_stable = TRUE/FALSE,
     has_target = TRUE/FALSE,
     target_direction = "above"/"below"/NA,
     goal_met = TRUE/FALSE/NA,
     at_target = TRUE/FALSE/NA
   )
   ```
2. `.allocate_text_budget(max_chars, has_target)` → named integer list `(budget_stability, budget_action)`
3. `.select_stability_key(flags)` → character scalar (i18n key into the stability arm)
4. `.select_action_key(flags)` → character scalar (i18n key into the action arm)

**Rationale:** Pure functions with explicit inputs/outputs are testable as data tables. Today's cascade buries the input-to-output mapping in 210 lines of conditional code; expressed as pure functions, the mapping is a literal lookup that any reader can audit by reading the function body top-to-bottom.

The named-list return shape mirrors existing patterns in the codebase (`spc_plot_config()`, `viewport_dims()`, the `placement` result from `place_two_labels_npc()`).

**Alternative considered:** Single function returning both keys at once. Rejected: bundles two independent concerns (stability narrative, action narrative) which today's cascade interleaves. Decoupling clarifies that the two cascades are independent.

### Decision 2: i18n strings stay in `inst/i18n/`, NOT inlined

**Choice:** The selected keys (`stability_key`, `action_key`) are the helpers' output. The orchestrator then calls `i18n_lookup(key, language)` exactly as today.

**Rationale:** i18n separation is already a clean boundary in the package. Mixing translated strings into the dispatch logic would re-introduce the multi-place edit problem we're trying to solve.

**Alternative considered:** Helpers return final strings, not keys. Rejected: ties dispatch to `language` parameter and prevents adding new languages without re-running the cascade.

### Decision 3: Table-driven unit tests via `tibble` + `purrr::pmap()`

**Choice:** Each `.select_*_key()` helper gets a test that defines a tibble of `(flags, expected_key)` rows and uses `purrr::pmap()` to verify each row. New cascade arms extend the tibble.

**Rationale:** The point of decomposition is to make new arms cheap. The test format must reflect that. Today's tests are ad-hoc `expect_equal()` calls per arm; switching to table-driven matches the new dispatch shape.

**Alternative considered:** Keep ad-hoc tests. Rejected: re-introduces the friction we're removing.

### Decision 4: Helpers stay in `R/spc_analysis.R`

**Choice:** All four new helpers live in the same file as `build_fallback_analysis()`.

**Rationale:** Co-location with the orchestrator they serve. This file is the right size to host them without creating a new file. Once `extract-utils-text-da` lands in parallel, this file shrinks substantially anyway.

**Alternative considered:** New file `R/spc_fallback_analysis.R`. Deferred: revisit after `extract-utils-text-da` lands; if `R/spc_analysis.R` is still oversized, consider further file-level decomposition as a separate proposal.

## Risks / Trade-offs

- **[Risk] Behavioral drift on edge cases (e.g. `is.na(target_direction)` propagation).** → Mitigation: the orchestrator wraps NA-aware conditionals where needed. Add explicit test rows for each NA-mixed input.

- **[Risk] Test rewrite friction if existing snapshot tests assert intermediate logging.** → Mitigation: pre-flight grep `tests/testthat/test-spc_analysis.R` and any related test files for verbose-output assertions; ensure none rely on internal cascade state.

- **[Trade-off] Helper count grows from 1 to 5.** → Acceptable: each helper has a single clear responsibility. Discoverability improves (named functions vs anonymous if-arm).

- **[Trade-off] Boilerplate for table tests.** → One-time cost, paid back on first new cascade arm.

## Migration Plan

This is a pure refactor. No deployment migration needed.

**Implementation sequence:**

1. Branch: `refactor/decompose-fallback-analysis` from current develop.
2. Commit 1: Add `.detect_signal_flags()` + table tests covering existing flag combinations. Replace inline detection in orchestrator with helper call.
3. Commit 2: Add `.allocate_text_budget()` + tests. Replace inline budget computation.
4. Commit 3: Add `.select_stability_key()` + table tests. Replace stability cascade in orchestrator.
5. Commit 4: Add `.select_action_key()` + table tests. Replace action cascade. **Largest commit; bisect-friendly via per-arm tests.**
6. Commit 5: Final orchestrator simplification (≤60 lines verification). Update NEWS.md.
7. Open PR. CI must pass. Review.

**Rollback strategy:** `git revert <merge-sha>`. No persistent state.

## Open Questions

- Should `.detect_signal_flags()` accept a `bfh_qic_result` directly or just `spc_stats`? Current code path receives both — propose `spc_stats` to keep the helper minimal and avoid coupling to the S3 class. Discuss at PR review if this becomes awkward.

- Should the table-driven tests live in a new helper file (`tests/testthat/helper-fallback-tables.R`) so they're shareable with future cascade extensions? Defer to PR review.
