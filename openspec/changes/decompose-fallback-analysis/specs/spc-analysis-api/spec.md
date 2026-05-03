## ADDED Requirements

### Requirement: Fallback-narrative dispatch SHALL use named pure helpers

The dispatch logic that maps detected SPC signals to fallback-narrative i18n keys SHALL be expressed as named pure helpers, not as nested boolean cascades. The orchestrator `build_fallback_analysis()` SHALL be ≤60 lines and SHALL only invoke helpers in pipeline order: detect flags → allocate budget → select keys → look up i18n strings → assemble markdown → pad.

The following private helpers SHALL exist in `R/spc_analysis.R`:

- `.detect_signal_flags(spc_stats)` — pure function returning a named-logical struct with at minimum the fields `(has_runs, has_crossings, has_outliers, is_stable, has_target, target_direction, goal_met, at_target)`
- `.allocate_text_budget(max_chars, has_target)` — pure function returning a named-integer struct `(budget_stability, budget_action)`
- `.select_stability_key(flags)` — pure function returning a character scalar i18n key
- `.select_action_key(flags)` — pure function returning a character scalar i18n key

Helpers SHALL be `@keywords internal @noRd`. The dispatch SHALL emit i18n keys, not translated strings; translation happens at the orchestrator boundary via existing `i18n_lookup()`.

#### Scenario: build_fallback_analysis is a thin orchestrator

- **WHEN** the package source is inspected for `R/spc_analysis.R`
- **THEN** `build_fallback_analysis()` SHALL be ≤60 lines and SHALL contain no nested `if/else if` chains for cascade dispatch (only top-level orchestration calls + i18n lookups + markdown assembly)
- **AND** the four helpers `.detect_signal_flags()`, `.allocate_text_budget()`, `.select_stability_key()`, `.select_action_key()` SHALL exist in the same file

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
