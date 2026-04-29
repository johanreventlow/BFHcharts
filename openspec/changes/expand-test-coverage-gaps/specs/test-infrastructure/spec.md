## ADDED Requirements

### Requirement: Test-time font alias registration SHALL match production .onLoad

`tests/testthat/setup.R` SHALL register the same font aliases as `R/zzz.R::register_bfh_font_aliases()`. Adding a new alias to production `.onLoad` SHALL be paired with the same addition in `setup.R`.

#### Scenario: Roboto registered in test setup

- **GIVEN** `R/zzz.R:47` registers `c("Mari", "Arial", "Roboto")`
- **WHEN** `tests/testthat/setup.R` is sourced before tests
- **THEN** the same three font aliases SHALL be registered

### Requirement: Every chart type in CHART_TYPES_EN SHALL have at least a smoke test

For each chart type listed in `R/chart_types.R::CHART_TYPES_EN`, the test suite SHALL contain at least one test that:
- invokes `bfh_qic()` with that chart type
- asserts the result is a `bfh_qic_result` S3 instance
- asserts `UCL > CL` and (where applicable) `CL > LCL` for the produced control limits

#### Scenario: g-chart smoke

- **GIVEN** rare-event count data (sparse positive integers)
- **WHEN** `bfh_qic(data, x, y, chart_type = "g")` is called
- **THEN** `result` SHALL be a `bfh_qic_result`
- **AND** `result$qic_data$ucl` > `result$qic_data$cl` for at least one row

#### Scenario: t-chart smoke

- **GIVEN** time-between-events data
- **WHEN** `bfh_qic(data, x, y, chart_type = "t")` is called
- **THEN** the result SHALL be a `bfh_qic_result` with non-negative control limits

#### Scenario: mr-chart smoke

- **GIVEN** continuous numeric data
- **WHEN** `bfh_qic(data, x, y, chart_type = "mr")` is called
- **THEN** the result SHALL be a `bfh_qic_result`
- **AND** UCL > CL > LCL for moving-range computations

### Requirement: i18n parity check SHALL be bidirectional

`test-i18n.R` SHALL verify that the set of i18n keys is identical across `da.yaml` and `en.yaml`. Both `setdiff(da, en)` AND `setdiff(en, da)` SHALL be empty.

#### Scenario: bidirectional parity passes

- **GIVEN** all i18n YAML leaf keys for da and en
- **WHEN** the parity test runs
- **THEN** `setdiff(da_keys, en_keys)` SHALL be empty
- **AND** `setdiff(en_keys, da_keys)` SHALL be empty

### Requirement: PDF render tests SHALL verify content, not just existence

Render-gated tests in `test-export_pdf.R` SHALL assert (via `pdftools::pdf_info()`) that the produced PDF has the expected page count, and SHOULD assert via `pdftools::pdf_text()` that known content (e.g. metadata hospital name) is present.

#### Scenario: empty PDF fails the test

- **GIVEN** a Typst compilation that produces a 0-page PDF
- **WHEN** the render-gated test asserts page count
- **THEN** the test SHALL fail (current behaviour: passes silently)

### Requirement: At least one bfh_qic example SHALL be executable

At least one `@example` block in `R/bfh_qic.R` SHALL execute under `R CMD check` (no `\dontrun{}` wrapper). The example SHALL use `inst/extdata/spc_exampledata.csv` or equivalent on-package data.

#### Scenario: R CMD check exercises the example

- **GIVEN** the package's installed source
- **WHEN** `devtools::run_examples()` runs against `bfh_qic`
- **THEN** at least one example SHALL execute without error
- **AND** SHALL produce a `bfh_qic_result` instance

### Requirement: pp/up control limits SHALL have independent hand-calculated reference

`test-statistical-accuracy-extended.R` SHALL include 2-3 hand-calculated p' and u' (Laney 2002) reference values asserted against BFHcharts output, in addition to the existing qicharts2-cross-verification.

#### Scenario: independent Laney reference matches

- **GIVEN** a fixture with known overdispersion (computed by hand from Laney 2002 §4)
- **WHEN** `bfh_qic(fixture, ..., chart_type = "pp")` is called
- **THEN** the resulting UCL/LCL SHALL match the hand-calculated reference within tolerance 0.001
