## ADDED Requirements

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
