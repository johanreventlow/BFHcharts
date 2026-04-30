## ADDED Requirements

### Requirement: bfh_qic SHALL reject empty data with a clear error

`bfh_qic()` SHALL reject `data` arguments where `nrow(data) == 0` with an error that explicitly identifies the cause.

**Rationale:**
- Empty input is almost always a data-pipeline bug upstream
- qicharts2 accepts empty input and produces a cryptic plot-construction error far from the source
- Early failure with named cause shortens debugging time for clinical users

#### Scenario: Empty data frame rejected

- **GIVEN** `data = data.frame(period = integer(0), value = numeric(0))`
- **WHEN** `bfh_qic(data, x = period, y = value)` is called
- **THEN** an error SHALL be raised
- **AND** the error message SHALL contain "empty"

### Requirement: bfh_qic SHALL validate y column is numeric

`bfh_qic()` SHALL coerce-test the column referenced by `y` and reject non-numeric data with an error before any qicharts2 call.

#### Scenario: Character y column rejected

- **GIVEN** `data = data.frame(period = 1:5, value = c("a", "b", "c", "d", "e"))`
- **WHEN** `bfh_qic(data, x = period, y = value)` is called
- **THEN** an error SHALL be raised
- **AND** the error message SHALL identify the offending column class

### Requirement: bfh_qic SHALL validate part / freeze / exclude as integer position indices

`bfh_qic()` SHALL validate phase-control arguments as integer position indices into the data:

- `part`: positive integers, strictly increasing, unique, in `[2, nrow(data)]`
- `freeze`: single positive integer, in `[MIN_BASELINE_N, nrow(data) - 1]`
- `exclude`: positive integers, unique, in `[1, nrow(data)]` (sort order not required)

Non-integer values, duplicates, unsorted `part`, and out-of-range values SHALL each produce a distinct error message.

**Rationale:**
- Phase-control arguments are interpreted as row positions; fractional values produce undefined behavior in qicharts2
- Duplicate or unsorted `part` produces overlapping or backward phases that misrepresent the SPC analysis
- A separate, named error for each violation type guides users to the precise fix

#### Scenario: Non-integer part rejected

- **GIVEN** `bfh_qic(data, x, y, part = 3.5)`
- **WHEN** the call is made
- **THEN** an error SHALL be raised mentioning "integer"

#### Scenario: Duplicated part rejected

- **GIVEN** `bfh_qic(data, x, y, part = c(12, 12))` where data has 24 rows
- **WHEN** the call is made
- **THEN** an error SHALL be raised mentioning "unique"

#### Scenario: Unsorted part rejected

- **GIVEN** `bfh_qic(data, x, y, part = c(12, 6))` where data has 24 rows
- **WHEN** the call is made
- **THEN** an error SHALL be raised mentioning "increasing"

#### Scenario: Out-of-range freeze rejected

- **GIVEN** data with 12 rows, `freeze = 12`
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised because freeze must leave at least one post-baseline point

### Requirement: metadata$target SHALL be a scalar finite numeric or scalar character

In all entry points that accept `metadata$target` (`bfh_export_pdf()`, `bfh_generate_analysis()`, `bfh_build_analysis_context()`), the target value SHALL be:

- `NULL` (no target), OR
- A single finite numeric (`length(x) == 1`, `is.finite(x)`), OR
- A single character string (`length(x) == 1`, not `NA`)

Vectors of length > 1, non-finite numerics, and `NA` values SHALL be rejected with informative errors.

**Rationale:**
- A target represents a single clinical goal — multi-element targets have no defined semantic
- Non-finite numerics (Inf/NaN) propagate as silently broken comparisons in analysis text
- Early rejection prevents downstream warnings that don't trace back to the root cause

#### Scenario: Multi-element numeric target rejected

- **GIVEN** `metadata = list(target = c(0.9, 0.95))`
- **WHEN** `bfh_export_pdf(x, "/tmp/out.pdf", metadata = metadata)` is called
- **THEN** an error SHALL be raised mentioning "scalar" or "length 1"

#### Scenario: Inf target rejected

- **GIVEN** `metadata = list(target = Inf)`
- **WHEN** `bfh_generate_analysis(x, metadata = metadata)` is called
- **THEN** an error SHALL be raised mentioning "finite"

#### Scenario: NA character target rejected

- **GIVEN** `metadata = list(target = NA_character_)`
- **WHEN** the call is made
- **THEN** an error SHALL be raised
