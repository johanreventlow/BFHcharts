## ADDED Requirements

### Requirement: Every exported symbol SHALL have non-internal Roxygen documentation

For each function in `NAMESPACE` (excluding S3 method registrations whose generic is exported), the source Roxygen block SHALL NOT contain `@keywords internal`. Each exported function SHALL declare a lifecycle status: `stable`, `experimental`, or `deprecated`.

**Rationale:** A symbol in `NAMESPACE` is callable as `BFHcharts::name()`. Marking it `@keywords internal` while exporting it produces a contradiction: callable but undocumented stability. Pre-1.0 packages need explicit lifecycle to set caller expectations for breakage.

#### Scenario: every export has a stability label

- **GIVEN** the union of `getNamespaceExports("BFHcharts")` and the package's Roxygen sources
- **WHEN** a CI test inspects each export's Roxygen
- **THEN** each export SHALL contain one of `@lifecycle stable`, `@lifecycle experimental`, `@lifecycle deprecated`
- **AND** none SHALL contain `@keywords internal`

### Requirement: Rd pages SHALL exist only for exported or explicitly-documented internal symbols

Rd files in `man/` SHALL correspond to either (a) a function in `NAMESPACE`, or (b) a function whose Roxygen explicitly documents it as a developer-facing internal with a clear stability statement. Functions intended as private SHALL use `@noRd` to suppress Rd generation.

#### Scenario: orphan Rd pages are removed

- **GIVEN** `man/bfh_compile_typst.Rd` exists but `bfh_compile_typst` is not exported
- **WHEN** `devtools::document()` is run after the source Roxygen is updated
- **THEN** if the function is decided private, the source SHALL include `@noRd` and the Rd file SHALL be removed
- **AND** if decided public, `@export` and a `@lifecycle` tag SHALL be added

### Requirement: README low-level API examples SHALL match NAMESPACE

Code snippets in `README.md` referencing low-level functions SHALL use only symbols actually exported in `NAMESPACE`. Any non-exported symbol referenced in the README SHALL either be exported or removed from the README.

#### Scenario: README quick-start runs without modification

- **GIVEN** the code snippets shown in README "Low-Level API" or equivalent section
- **WHEN** a fresh user copy-pastes the snippets after `library(BFHcharts)`
- **THEN** every function call SHALL resolve via the public namespace (no `:::` required)
- **AND** the snippets SHALL execute without `Error: object 'X' not found`

### Requirement: bfh_qic_result $qic_data columns SHALL have a documented contract

The `bfh_qic_result` class documentation SHALL include a `@section qic_data columns` listing the canonical columns the package guarantees to expose, along with the qicharts2 lower-bound version that supplies them.

**Rationale:** Downstream consumers (biSPCharts) read `$qic_data` columns directly. Without a documented contract, qicharts2 minor-version column renames silently break consumers.

#### Scenario: documented columns exist on smoke fixture

- **GIVEN** a smoke `bfh_qic_result` produced by `bfh_qic(simple_data, x, y, chart_type = "i")`
- **WHEN** the test inspects `result$qic_data`
- **THEN** the columns named in the documented contract SHALL all exist
- **AND** their types SHALL match the contract (numeric for cl/ucl/lcl, logical for *.signal)

#### Scenario: qicharts2 lower-bound matches the contract

- **GIVEN** the qicharts2 version named in `DESCRIPTION` Imports
- **WHEN** a CI test reads the version range and queries the package
- **THEN** the documented contract SHALL hold for that lower-bound version
