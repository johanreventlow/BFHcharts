## ADDED Requirements

### Requirement: bfh_generate_details SHALL fail early on inevaluable x-range

`bfh_generate_details()` SHALL validate that the x-column of `qic_data` contains at least one finite (or, for date types, non-NA parseable) value before invoking `min`/`max`. When the column has no usable values, the function SHALL `stop()` with an informative message naming the column and reason. The function SHALL NOT silently return ranges containing `Inf` / `-Inf`.

**Rationale:** Cleanup scenarios in batch sessions, all-NA filters, and partially-failed exports can produce empty or all-NA `qic_data$x`. `min(c(NA, NA), na.rm = TRUE)` returns `Inf` with a warning; the resulting detail string `"Inf - -Inf"` ends up in the PDF metadata. Fail-early prevents the silent corruption.

#### Scenario: empty x column raises informative error

- **GIVEN** a `qic_data` frame where `qic_data$x` is `numeric(0)` or `as.Date(character(0))`
- **WHEN** `bfh_generate_details(qic_data, ...)` is called
- **THEN** the call SHALL stop with an error message naming the column and the missing-finite-values cause

#### Scenario: all-NA x column raises informative error

- **GIVEN** `qic_data$x = c(NA, NA, NA)` (numeric or date)
- **WHEN** `bfh_generate_details(qic_data, ...)` is called
- **THEN** the call SHALL stop with the same error class as the empty case

#### Scenario: single valid x value succeeds

- **GIVEN** `qic_data$x = c(NA, NA, as.Date("2025-01-01"))`
- **WHEN** `bfh_generate_details(qic_data, ...)` is called
- **THEN** the call SHALL succeed
- **AND** the rendered details SHALL show the single date as both range start and end

#### Scenario: bfh_export_pdf surfaces the error cleanly

- **GIVEN** a call to `bfh_export_pdf()` whose `qic_data$x` is empty or all-NA
- **WHEN** the export pipeline reaches `bfh_generate_details()`
- **THEN** the resulting error SHALL propagate via the standard BFHcharts error class hierarchy
- **AND** SHALL NOT leave temp files or partially-written PDFs (cleanup via `on.exit` SHALL run)
