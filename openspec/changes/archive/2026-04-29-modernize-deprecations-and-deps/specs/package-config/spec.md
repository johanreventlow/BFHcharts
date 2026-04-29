## MODIFIED Requirements

### Requirement: Deprecation lifecycle SHALL name target removal version

When a function argument or behavior is deprecated, the deprecation warning SHALL name the target version for removal. Deprecations SHALL NOT remain unscheduled across multiple minor releases.

#### Scenario: print.summary deprecation names removal version

- **GIVEN** `bfh_qic(..., print.summary = TRUE)` in v0.10.x or later
- **WHEN** the call executes during the deprecation window
- **THEN** the warning SHALL include "to be removed in v0.11.0" (or the agreed version)
- **AND** the legacy `list(plot, summary)` return-format SHALL be unavailable in the target version

### Requirement: Imports SHALL contain only packages used in R/

`DESCRIPTION` `Imports:` SHALL list only packages whose namespace is actually called from R code in `R/`. Packages used only in tests, vignettes, or `inst/` SHALL be in `Suggests`.

#### Scenario: lemon placement matches usage

- **GIVEN** the result of `grep -rn "lemon::" R/`
- **WHEN** zero hits in `R/`
- **THEN** `lemon` SHALL NOT appear in `DESCRIPTION` `Imports:`
- **AND** SHALL appear in `Suggests:` only if used in tests/vignettes, or be removed entirely otherwise

### Requirement: Remotes SHALL declare only required runtime dependencies

`DESCRIPTION` `Remotes:` SHALL list only GitHub sources for packages that are required to be installed automatically (i.e. listed in `Imports:` or `Depends:`). Packages in `Suggests:` SHALL NOT have `Remotes:` entries; manual installation hints SHALL be provided in function-level documentation instead.

#### Scenario: BFHllm not in Remotes

- **GIVEN** `BFHllm` is in `Suggests:` only (not `Imports:`)
- **WHEN** `DESCRIPTION` is parsed
- **THEN** `Remotes:` SHALL NOT include `johanreventlow/BFHllm`
- **AND** the manual-install hint SHALL appear in `bfh_generate_analysis()` Roxygen

### Requirement: Config objects SHALL maintain a single canonical source

`build_bfh_qic_config()` SHALL store `cl`, `freeze`, `part` at exactly one location in the returned config object. Sub-keys derived from these values SHALL be computed via accessor functions, not mirrored as static copies.

#### Scenario: mutation propagates without desync

- **GIVEN** a config object produced by `build_bfh_qic_config()`
- **WHEN** the top-level `config$cl` is mutated
- **THEN** any accessor reading the centerline value SHALL return the new value
- **AND** there SHALL be no static `config$label_config$centerline_value` field that holds the stale value

### Requirement: Width/height auto-detection SHALL emit a feedback message

When `bfh_export_pdf()` (or `bfh_qic()`) auto-detects whether `width`/`height` arguments are inches or centimeters, the function SHALL emit a single `message()` naming the inferred unit and recommending the explicit `units` argument.

#### Scenario: missing units triggers message

- **GIVEN** `bfh_export_pdf(plot, "out.pdf", width = 10)` (no `units`)
- **WHEN** the call executes
- **THEN** a `message()` SHALL be emitted naming the inferred unit
- **AND** the message SHALL recommend passing `units = "in"` or `units = "cm"` explicitly

#### Scenario: explicit units does not trigger message

- **GIVEN** `bfh_export_pdf(plot, "out.pdf", width = 10, units = "in")`
- **WHEN** the call executes
- **THEN** no auto-detection message SHALL be emitted
