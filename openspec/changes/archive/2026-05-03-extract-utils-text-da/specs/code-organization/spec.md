## ADDED Requirements

### Requirement: Language-specific text utilities SHALL live in dedicated files

Internal helpers for language-specific text formatting (pluralization, branched text selection, placeholder substitution, length padding, length truncation) SHALL live in dedicated files named `R/utils_text_<lang>.R` rather than embedded inside larger pipeline files.

The current Danish text-formatting helpers — `pluralize_da()`, `pick_text()`, `substitute_placeholders()`, `pad_to_minimum()`, `ensure_within_max()` — SHALL be located in `R/utils_text_da.R` (not in `R/spc_analysis.R` or any other pipeline file).

Helpers SHALL retain `@keywords internal @noRd` annotations and SHALL NOT be exported. Tests for these helpers MAY remain in their existing location (typically `tests/testthat/test-spc_analysis.R`) if the helpers are exercised primarily through their original integration path.

#### Scenario: Danish text helpers live in dedicated file

- **WHEN** the package source is inspected
- **THEN** `R/utils_text_da.R` SHALL exist and SHALL contain at minimum: `pluralize_da()`, `pick_text()`, `substitute_placeholders()`, `pad_to_minimum()`, `ensure_within_max()`
- **AND** `R/spc_analysis.R` SHALL NOT contain any of these five function definitions

#### Scenario: existing call sites resolve correctly after relocation

- **WHEN** `devtools::load_all()` runs after the relocation
- **THEN** all internal call sites of the five helpers SHALL resolve correctly via R's namespace lookup
- **AND** all existing tests covering these helpers SHALL pass without modification

#### Scenario: future English-specific text utilities follow the same pattern

- **WHEN** new language-specific text-formatting helpers are introduced for English (e.g. `pluralize_en()`)
- **THEN** they SHALL be placed in `R/utils_text_en.R`, not embedded in pipeline files
