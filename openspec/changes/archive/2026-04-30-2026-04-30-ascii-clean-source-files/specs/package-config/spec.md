## ADDED Requirements

### Requirement: R source files SHALL contain only ASCII characters

All files under `R/*.R` SHALL contain only bytes in the ASCII range (0x00–0x7F). Non-ASCII content (Danish letters æ/ø/å, mathematical operators ≥/≤/±, Unicode arrows, etc.) is forbidden in `.R` files and SHALL be relocated to:

- **Roxygen blocks** (`#'` lines) — allowed because `Encoding: UTF-8` in DESCRIPTION covers exported documentation
- **i18n YAML** (`inst/i18n/*.yaml`) — for user-facing strings translated at runtime
- **`æ` style escapes** — for literal Unicode strings inside R code
- **NEWS.md / vignettes / README** — UTF-8 in markdown is permitted

**Rationale:**
- `R CMD check --as-cran` issues a WARNING for non-ASCII in R sources, blocking warning-clean releases
- CRAN policy actively discourages non-ASCII in code; r-universe inherits similar gates
- Mixed-encoding `.R` files cause line-ending and encoding-detection issues on Windows + CI
- Documentation and i18n channels are the correct home for natural-language Danish content

**Enforcement:** A test `tests/testthat/test-source-ascii.R` SHALL scan all `R/*.R` files and fail with file:line:char location for any non-ASCII byte. The test runs on every `devtools::test()` invocation.

#### Scenario: ASCII guard rejects non-ASCII source

- **GIVEN** a file `R/foo.R` containing the byte sequence for `æ`
- **WHEN** `devtools::test()` runs
- **THEN** the test `test-source-ascii.R` SHALL fail
- **AND** the failure message SHALL identify file path, line number, and character position

#### Scenario: Roxygen retains Danish prose

- **GIVEN** an exported function `bfh_qic()` with `#' Skaber et SPC-diagram til kvalitetsforbedring`
- **WHEN** `R CMD check --as-cran` runs
- **THEN** no WARNING SHALL be raised for non-ASCII
- **AND** the help page SHALL render Danish characters correctly

#### Scenario: i18n YAML retains Danish keys/values

- **GIVEN** `inst/i18n/da.yaml` containing `centerline: "Centrallinje"`
- **WHEN** the test guard runs
- **THEN** no failure SHALL be raised because the guard scans only `R/*.R`
- **AND** runtime `i18n_lookup("centerline", lang = "da")` SHALL return `"Centrallinje"`
