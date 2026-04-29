## ADDED Requirements

### Requirement: Public functions SHALL document all values their input validators accept

Public exported functions whose parameters are validated against an enumerated set of allowed values SHALL document **all** allowed values in the user-facing roxygen `@param` and `@details` blocks. Discrepancies between validator-accepted values and documented values SHALL be treated as documentation bugs.

**Rationale:**
- API discovery via `?function_name` must surface the full feature surface
- Hidden parameter values force users to read source code
- Inconsistency between validator and docs creates maintenance debt and erodes trust

This requirement specifically addresses the `chart_type` parameter of `bfh_qic()`, but applies to any future enumerated parameters (e.g., `y_axis_unit`, `agg.fun`, `language`).

#### Scenario: chart_type roxygen lists all validated types

- **GIVEN** the validator at `R/utils_bfh_qic_helpers.R:218-223` accepts the set defined by `CHART_TYPES_EN` in `R/chart_types.R:21`
- **WHEN** a user reads `?bfh_qic`
- **THEN** the `@param chart_type` description SHALL list every value in that set: `"run"`, `"i"`, `"mr"`, `"p"`, `"pp"`, `"u"`, `"up"`, `"c"`, `"g"`, `"xbar"`, `"s"`, `"t"`
- **AND** the `@details Chart Types` block SHALL provide a one-line description for each type

```r
# Verification (regression test):
test_that("bfh_qic Rd documents all validated chart types", {
  rd_path <- system.file("man", "bfh_qic.Rd", package = "BFHcharts")
  skip_if(nchar(rd_path) == 0)
  rd_content <- paste(readLines(rd_path), collapse = "\n")
  for (t in BFHcharts:::CHART_TYPES_EN) {
    expect_true(grepl(paste0("\\b", t, "\\b"), rd_content),
                info = paste("Chart type", t, "missing from Rd"))
  }
})
```

#### Scenario: Laney-adjusted variants describe over-dispersion use case

- **GIVEN** chart types `"pp"` and `"up"` exist as Laney-adjusted variants of `"p"` and `"u"`
- **WHEN** a user reads `?bfh_qic`
- **THEN** the documentation SHALL identify `"pp"` and `"up"` as Laney-adjusted variants
- **AND** SHALL provide guidance on when to use them (over-dispersion with very large denominators) so users can choose the appropriate variant without consulting external sources

```
**pp**: P-prime chart (Laney-adjusted proportions) — use instead of `p`
when denominators are very large (n > 1000 per subgroup) and standard
control limits become artificially tight due to over-dispersion.

**up**: U-prime chart (Laney-adjusted rates) — same rationale as `pp`,
applied to count rates.
```

#### Scenario: Moving Range chart documented as I-chart pair

- **GIVEN** chart type `"mr"` exists as the Moving Range counterpart to the I-chart
- **WHEN** a user reads `?bfh_qic`
- **THEN** the documentation SHALL identify `"mr"` as a Moving Range chart
- **AND** SHALL note its typical pairing with an I-chart for full process variation analysis

```
**mr**: Moving Range chart — measures point-to-point variability.
Typically paired with an I-chart to characterize both process level
(I) and short-term variation (MR).
```
