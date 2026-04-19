# test-infrastructure Specification Delta

## ADDED Requirements

### Requirement: Package SHALL have automated CI/CD pipeline

The package SHALL have a GitHub Actions-based CI/CD pipeline that runs on every pull request and push to `main`, acting as a required merge-gate.

**Rationale:**
- Without CI, test-suite quality depends entirely on developer discipline
- A "production" package needs automated, remote-verifiable quality gates
- Multi-platform compatibility cannot be verified without CI matrix
- Coverage and linting status need automated tracking

#### Scenario: CI runs R CMD check on pull requests

- **GIVEN** a pull request is opened against `main`
- **WHEN** GitHub Actions workflow triggers
- **THEN** `R CMD check --as-cran` SHALL run on Ubuntu-latest with R-release
- **AND** `devtools::test()` SHALL run on Ubuntu-latest with R-release
- **AND** the workflow SHALL block merge if any required check fails

#### Scenario: CI reports coverage metrics

- **GIVEN** test suite completes on CI
- **WHEN** coverage workflow runs
- **THEN** `covr::codecov()` SHALL upload coverage data to Codecov
- **AND** coverage data SHALL be accessible via Codecov badge in README
- **AND** coverage changes SHALL be reported on pull requests as comments

#### Scenario: CI enforces linting as advisory check

- **GIVEN** a pull request contains R code changes
- **WHEN** lint workflow runs
- **THEN** `lintr::lint_package()` SHALL run
- **AND** findings SHALL be reported as annotations on the pull request
- **AND** the workflow SHALL NOT fail initially (advisory mode)

#### Scenario: CI installs required system dependencies

- **GIVEN** CI workflow starts
- **WHEN** environment is being prepared
- **THEN** Quarto CLI SHALL be installed via `quarto-dev/quarto-actions/setup@v2`
- **AND** required fonts (Mari or approved open fallback) SHALL be installed
- **AND** R dependencies SHALL be restored from DESCRIPTION

### Requirement: Test suite SHALL be portable across environments

The test suite SHALL run reliably on CI without silent skipping of substantive tests. Environment-dependent skips SHALL be intentional, documented, and minimal.

**Rationale:**
- 17+ `skip_on_ci()` calls without an active CI creates false "green" status when CI is enabled
- `skip_if_not_installed("qicharts2")` is misleading since qicharts2 is a hard `Imports` dependency
- Tests must fail rather than skip when dependencies are missing in error

#### Scenario: Hard dependency failures are not silently skipped

- **GIVEN** a test uses qicharts2 functionality
- **WHEN** qicharts2 is missing from the environment
- **THEN** the test SHALL fail rather than skip
- **AND** `skip_if_not_installed("qicharts2")` SHALL be removed from all tests

#### Scenario: Font-dependent tests run on CI when fonts are installed

- **GIVEN** CI workflow installs required fonts
- **WHEN** rendering tests execute
- **THEN** `skip_on_ci()` SHALL be removed from tests that CI can now support
- **AND** remaining `skip_on_ci()` calls SHALL have inline justification comments

#### Scenario: Test suite supports layered execution via environment variables

- **GIVEN** a developer runs `devtools::test()` locally
- **WHEN** no environment variables are set
- **THEN** fast unit tests SHALL complete in under 10 seconds
- **AND** heavy render/integration tests SHALL be skipped by default
- **WHEN** `BFHCHARTS_TEST_FULL=true` is set
- **THEN** all non-rendering tests SHALL execute
- **WHEN** `BFHCHARTS_TEST_RENDER=true` is set
- **THEN** all tests including live Quarto render tests SHALL execute
- **AND** CI SHALL set both environment variables by default

### Requirement: Test fixtures SHALL be centralized and deterministic

Common test data generators, mocks, and assertions SHALL be centralized in helper files. Tests that verify specific numeric values SHALL use hand-crafted deterministic inputs rather than seeded RNG.

**Rationale:**
- 5+ near-identical `make_*()` helpers are currently duplicated across test files
- RNG-based determinism is fragile across R version upgrades (e.g., R 3.6 → 4.0 RNGkind change)
- Centralization reduces maintenance burden and divergence risk

#### Scenario: Fixture helpers are loaded automatically

- **GIVEN** the test suite starts
- **WHEN** testthat bootstraps
- **THEN** `tests/testthat/helper-fixtures.R` SHALL provide shared factories
- **AND** `tests/testthat/helper-mocks.R` SHALL provide shared mock factories
- **AND** `tests/testthat/helper-assertions.R` SHALL provide custom expectations
- **AND** `tests/testthat/setup.R` SHALL configure locale, timezone, and RNGkind

#### Scenario: Deterministic test inputs are used for numerical verification

- **GIVEN** a test verifies a specific UCL/LCL/centerline value
- **WHEN** the test constructs input data
- **THEN** input SHALL be a hand-crafted vector (not `rnorm()` or `rpois()` with `set.seed()`)
- **AND** the test SHALL document expected values with references where applicable

#### Scenario: Golden datasets are available as RDS fixtures

- **GIVEN** a test needs a canonical input dataset
- **WHEN** the test loads from `tests/testthat/fixtures/golden_datasets.rds`
- **THEN** the dataset SHALL be deterministic and version-controlled
- **AND** `tests/testthat/fixtures/README.md` SHALL document format and generation process

### Requirement: External dependencies SHALL be testable in isolation

System-level dependencies (Quarto CLI, `system2` calls, BFHllm) SHALL be mockable in unit tests so that failure paths can be tested without live integration.

**Rationale:**
- `R/utils_quarto.R:38` and `R/utils_typst.R:230` contain `system2()` calls currently tested only via live integration
- BFHllm `use_ai = TRUE` code path has zero test coverage
- Live-only testing cannot cover error paths (non-zero exit codes, missing output files, version mismatches)

#### Scenario: Quarto availability check is mockable

- **GIVEN** a unit test targets logic that depends on Quarto availability
- **WHEN** the test uses `testthat::local_mocked_bindings()` or `mockery::stub()`
- **THEN** `quarto_available()` SHALL return the mocked value
- **AND** both `TRUE` and `FALSE` paths SHALL be tested without requiring Quarto installation

#### Scenario: Quarto compile errors are testable without live Quarto

- **GIVEN** a unit test targets error-handling in the Typst compile path
- **WHEN** `system2()` is mocked to return non-zero exit
- **THEN** the function SHALL produce the documented error message
- **AND** a missing-output-file scenario SHALL produce the documented error

#### Scenario: BFHllm integration paths are mock-tested

- **GIVEN** a unit test targets `bfh_generate_analysis(use_ai = TRUE)`
- **WHEN** `BFHllm` calls are mocked
- **THEN** the success path SHALL return expected analysis text
- **AND** the BFHllm-error path SHALL fall back to standard text
- **AND** the BFHllm-missing path SHALL fall back to standard text

### Requirement: Rendered outputs SHALL have content verification

PDF and PNG export tests SHALL verify that generated outputs contain expected content, not merely that files exist with non-zero size.

**Rationale:**
- Current export tests mostly check `file.exists(temp_file)` + `file.info(temp_file)$size > 0`
- Encoding bugs (æøå), template regressions, and metadata flow bugs go undetected
- `pdftools` is in Suggests but unused

#### Scenario: PDF output contains chart title

- **GIVEN** `bfh_export_pdf()` is called with a `chart_title`
- **WHEN** the generated PDF is parsed with `pdftools::pdf_text()`
- **THEN** the chart title text SHALL appear in the extracted content

#### Scenario: PDF output contains metadata fields

- **GIVEN** `bfh_export_pdf()` is called with metadata (hospital, department, author, data_definition)
- **WHEN** the generated PDF is parsed
- **THEN** each provided metadata field SHALL appear in the extracted text
- **AND** Danish characters (æ, ø, å) SHALL be correctly represented

#### Scenario: PDF output contains SPC summary table

- **GIVEN** `bfh_export_pdf()` generates a report with SPC statistics
- **WHEN** the generated PDF is parsed
- **THEN** centerline value SHALL appear in the extracted text
- **AND** runs and crossings statistics SHALL appear in the extracted text

#### Scenario: PNG output structure is verified

- **GIVEN** `bfh_export_png()` is called with specified dimensions and DPI
- **WHEN** the generated PNG is inspected via `png::readPNG()` or `magick::image_info()`
- **THEN** dimensions and DPI SHALL match the requested values within tolerance
- **AND** the file SHALL be a valid PNG (not merely a non-empty file)

### Requirement: Plot rendering SHALL have visual regression protection

Visual regression of ggplot outputs SHALL be protected via `vdiffr` golden images for canonical chart configurations.

**Rationale:**
- BFHcharts is fundamentally a visualization package
- Rendering regressions in layer order, color mapping, label placement, or theme application are not caught by structural assertions
- `vdiffr` is already in Suggests but unused

#### Scenario: Canonical chart types have golden images

- **GIVEN** the test suite includes visual regression
- **WHEN** `vdiffr::expect_doppelganger()` is called for canonical chart configurations
- **THEN** golden images SHALL exist in `tests/testthat/_snaps/` for:
  - run chart (basic)
  - i-chart (with UCL/LCL)
  - p-chart (with variable limits)
  - u-chart (basic)
  - c-chart (basic)
  - multi-phase chart
  - chart with target line
  - chart with notes/annotations

#### Scenario: Re-baseline process is documented

- **GIVEN** a legitimate rendering change requires golden image update
- **WHEN** a developer runs `testthat::snapshot_accept()` after visual review
- **THEN** the re-baseline SHALL be committed with documented rationale
- **AND** `tests/testthat/README.md` SHALL describe the full re-baseline process

### Requirement: Statistical calculations SHALL have numerical verification

Control limit and centerline calculations SHALL be verified against hand-computed reference values for canonical chart types.

**Rationale:**
- Current tests verify that `bfh_qic()` returns an `bfh_qic_result` object, not that values are numerically correct
- qicharts2 version upgrades may change semantics without test-suite detection
- Statistical accuracy is the core value proposition of a clinical SPC package

#### Scenario: p-chart control limits match published formulas

- **GIVEN** a test uses known input (p̄ = 0.10, n = 100)
- **WHEN** `bfh_qic(..., chart_type = "p")` is called
- **THEN** the computed UCL SHALL equal 0.190 within tolerance 1e-6
- **AND** the computed LCL SHALL equal 0.010 within tolerance 1e-6
- **AND** the computed centerline SHALL equal 0.100 within tolerance 1e-6

#### Scenario: c-chart control limits match published formulas

- **GIVEN** a test uses known input (c̄ = 5)
- **WHEN** `bfh_qic(..., chart_type = "c")` is called
- **THEN** the computed UCL SHALL equal approximately 11.708 within tolerance 1e-3
- **AND** the computed LCL SHALL equal 0 (clipped from negative)
- **AND** the computed centerline SHALL equal 5 exactly

#### Scenario: Anhøj rule signals fire at known positions

- **GIVEN** a constructed dataset with 9 consecutive points above median
- **WHEN** `bfh_qic(..., chart_type = "run")` is called
- **THEN** `anhoej.signal` SHALL be `TRUE` for those 9 points
- **AND** the summary SHALL report `længste_løb` equal to 9 or higher

#### Scenario: Outlier counts distinguish total vs. recent

- **GIVEN** a `bfh_qic_result` with 3 total outliers, 2 within the most recent 6 observations
- **WHEN** `bfh_extract_spc_stats(result)` is called
- **THEN** `stats$outliers_actual` SHALL equal 3
- **AND** `stats$outliers_recent_count` SHALL equal 2

### Requirement: All exported chart types SHALL have integration coverage

Every chart type listed in `CHART_TYPES_EN` SHALL have at least one integration test verifying end-to-end rendering with numeric output assertions.

**Rationale:**
- `CHART_TYPES_EN` includes: run, i, mr, p, pp, u, up, c, g, xbar, s, t
- Current integration tests cover only: run, i, p, c, u
- Untested chart types (`mr, pp, up, g, xbar, s, t`) may regress silently

#### Scenario: Moving-range chart renders correctly

- **GIVEN** a dataset suitable for moving-range analysis
- **WHEN** `bfh_qic(..., chart_type = "mr")` is called
- **THEN** the result SHALL be a valid `bfh_qic_result`
- **AND** the centerline SHALL match hand-computed moving-range mean
- **AND** the summary SHALL contain expected columns

#### Scenario: P-prime (standardized p) chart renders correctly

- **GIVEN** a dataset with varying denominators
- **WHEN** `bfh_qic(..., chart_type = "pp")` is called
- **THEN** the result SHALL be a valid `bfh_qic_result`
- **AND** control limits SHALL be standardized (constant across observations)

#### Scenario: All remaining chart types have functional tests

- **GIVEN** chart types `up`, `g`, `xbar`, `s`, `t`
- **WHEN** each is used with appropriate test data
- **THEN** each SHALL produce a valid `bfh_qic_result`
- **AND** each SHALL have at least one numeric assertion on output values

### Requirement: Test assertions SHALL be signal-strong

Tests SHALL verify meaningful behavior rather than structural identity. Warnings SHALL be explicitly asserted (either expected or absent) rather than blanket-suppressed.

**Rationale:**
- 119 uses of `suppressWarnings()` currently mask potentially real warnings
- Many integration tests use only `expect_s3_class(..., "bfh_qic_result")` which passes even if statistical outputs are broken
- Stale expectations in `tests/testthat/test-export_pdf.R:421` indicate drift

#### Scenario: Integration tests include numeric assertions

- **GIVEN** an integration test creates a chart
- **WHEN** the test completes
- **THEN** it SHALL include at least one `expect_equal()` on a numeric value (centerline, UCL, LCL, signal count, or row count)
- **AND** it SHALL NOT rely solely on class checks

#### Scenario: Warnings are explicitly asserted

- **GIVEN** a test calls `bfh_qic()` or related API
- **WHEN** warnings are expected
- **THEN** the test SHALL use `expect_warning(..., regexp = "pattern")` with a specific pattern
- **WHEN** warnings are not expected
- **THEN** the test SHALL use `expect_warning(..., regexp = NA)` rather than `suppressWarnings()`
- **AND** blanket `suppressWarnings()` SHALL be used only for documented, justified cases

#### Scenario: Test expectations match current behavior

- **GIVEN** a test file exists in `tests/testthat/`
- **WHEN** the test is executed against current implementation
- **THEN** no test SHALL have stale expectations from previous versions
- **AND** drift between tests (e.g., duplicate coverage with inconsistent assertions) SHALL be consolidated
