## MODIFIED Requirements

### Requirement: Warning muffling SHALL match only documented benign patterns

Internal warning-muffling helpers SHALL match warning messages against an explicit, anchored set of patterns covering only known benign ggplot2/scales/font-registration warnings. Bare unanchored substring matches (e.g. `"numeric"`, `"datetime"`) SHALL NOT be used.

**Rationale:** Clinical SPC depends on data-quality warnings reaching the caller. Coercion warnings (e.g. `"NAs introduced by coercion to numeric"`) signal malformed denominators or wrong-type columns and must not be silently swallowed.

#### Scenario: numeric coercion warning propagates to caller

- **GIVEN** input data where the denominator column is character-typed
- **WHEN** `bfh_qic()` is invoked
- **THEN** the qicharts2/base R warning `"NAs introduced by coercion to numeric"` SHALL propagate to the caller (visible via `withCallingHandlers` or `tryCatch`)
- **AND** the warning SHALL NOT be muffled by `.muffle_expected_warnings()`

#### Scenario: ggplot2 scale warnings remain muffled

- **GIVEN** a chart rendering that emits `"scale_x_date: Removed 3 rows containing missing values"`
- **WHEN** the rendering occurs inside `.muffle_expected_warnings()`
- **THEN** the warning SHALL be muffled (not visible to caller)

#### Scenario: PostScript font-database warning remains muffled

- **GIVEN** font-metric lookup emits `"font family Mari not found in PostScript font database"`
- **WHEN** rendering occurs inside the muffler
- **THEN** the warning SHALL be muffled

### Requirement: Deprecation warnings SHALL fire at most once per call

Deprecated argument paths in `bfh_qic()` (e.g. `print.summary = TRUE, return.data = FALSE`) SHALL emit at most one `warning()` per call, consolidating deprecation context and migration hint into a single message.

#### Scenario: legacy print.summary path emits one warning

- **GIVEN** `bfh_qic(data, ..., print.summary = TRUE, return.data = FALSE)`
- **WHEN** the call executes
- **THEN** exactly one warning SHALL be captured by `withCallingHandlers`
- **AND** the warning SHALL include both the "deprecated" notice and the migration instruction
