# public-api Specification

## Purpose
TBD - created by archiving change export-spc-utility-functions. Update Purpose after archive.
## Requirements
### Requirement: Package SHALL export SPC statistics extraction function

The package SHALL provide a public API function for extracting SPC statistics from qic summary data to support downstream packages.

**Rationale:**
- Downstream packages (SPCify) need to access SPC statistics without using `:::` accessor
- Enables stable API contract with semantic versioning guarantees
- Separates public API from internal implementation details

#### Scenario: Extract SPC statistics from valid summary

**Given** a qic summary data frame with SPC statistics columns
**When** `bfh_extract_spc_stats(summary)` is called
**Then** the function SHALL return a list with extracted statistics
**And** the list SHALL contain runs_expected, runs_actual, crossings_expected, crossings_actual
**And** the function SHALL be exported and documented

**Test Cases:**
```r
summary <- data.frame(
  længste_løb_max = 8,
  længste_løb = 6,
  antal_kryds_min = 10,
  antal_kryds = 12
)

stats <- bfh_extract_spc_stats(summary)
# Returns:
# list(
#   runs_expected = 8,
#   runs_actual = 6,
#   crossings_expected = 10,
#   crossings_actual = 12,
#   outliers_expected = NULL,
#   outliers_actual = NULL
# )
```

#### Scenario: Handle NULL or empty summary gracefully

**Given** a NULL summary or empty data frame
**When** `bfh_extract_spc_stats(summary)` is called
**Then** the function SHALL return a list with all NULLs
**And** the function SHALL NOT throw an error

**Test Cases:**
```r
bfh_extract_spc_stats(NULL)
# Returns: list with all NULL values

bfh_extract_spc_stats(data.frame())
# Returns: list with all NULL values
```

#### Scenario: Handle missing columns gracefully

**Given** a summary data frame with some missing SPC columns
**When** `bfh_extract_spc_stats(summary)` is called
**Then** the function SHALL set corresponding list elements to NULL
**And** the function SHALL extract available columns

**Test Cases:**
```r
summary <- data.frame(længste_løb = 6)  # Missing other columns

stats <- bfh_extract_spc_stats(summary)
# Returns:
# list(
#   runs_expected = NULL,
#   runs_actual = 6,
#   crossings_expected = NULL,
#   ...
# )
```

### Requirement: Package SHALL export metadata merging function

The package SHALL provide a public API function for merging user-provided metadata with default values to support PDF generation workflows.

**Rationale:**
- Downstream packages need consistent metadata handling
- Prevents code duplication across packages
- Centralizes default values in BFHcharts

#### Scenario: Merge user metadata with defaults

**Given** user-provided metadata and a chart title
**When** `bfh_merge_metadata(metadata, chart_title)` is called
**Then** the function SHALL return merged metadata list
**And** user values SHALL override defaults
**And** missing fields SHALL use default values

**Test Cases:**
```r
metadata <- list(
  department = "Kvalitetsafdeling",
  analysis = "Signifikant fald"
)

merged <- bfh_merge_metadata(metadata, chart_title = "Infektioner")
# Returns:
# list(
#   hospital = "Bispebjerg og Frederiksberg Hospital",  # default
#   department = "Kvalitetsafdeling",                    # user override
#   title = "Infektioner",                               # from chart_title
#   analysis = "Signifikant fald",                       # user override
#   details = NULL,                                       # default
#   author = NULL,                                        # default
#   date = Sys.Date(),                                    # default
#   data_definition = NULL                                # default
# )
```

#### Scenario: Handle empty metadata

**Given** an empty metadata list
**When** `bfh_merge_metadata(list(), chart_title)` is called
**Then** the function SHALL return defaults only
**And** title SHALL be set from chart_title parameter

**Test Cases:**
```r
merged <- bfh_merge_metadata(list(), "Test Chart")
# Returns: all defaults with title = "Test Chart"
```

#### Scenario: Handle NULL chart title

**Given** metadata with title field and NULL chart_title parameter
**When** `bfh_merge_metadata(metadata, chart_title = NULL)` is called
**Then** the function SHALL use metadata title if provided
**Or** the function SHALL use NULL if metadata title not provided

**Test Cases:**
```r
metadata <- list(title = "Custom Title")
merged <- bfh_merge_metadata(metadata, chart_title = NULL)
# merged$title = "Custom Title"

metadata <- list()
merged <- bfh_merge_metadata(metadata, chart_title = NULL)
# merged$title = NULL
```

### Requirement: Exported functions SHALL follow package naming conventions

All exported utility functions SHALL use the `bfh_` prefix to maintain namespace consistency and clarity.

**Rationale:**
- Consistent with existing exports: `bfh_qic()`, `bfh_export_pdf()`
- Clear namespace ownership when used in downstream packages
- Prevents name collisions with generic function names

#### Scenario: Function naming follows convention

**Given** utility functions being exported
**When** functions are added to NAMESPACE
**Then** function names SHALL start with `bfh_` prefix
**And** names SHALL be descriptive and verb-led

**Examples:**
- ✅ `bfh_extract_spc_stats()` - follows convention
- ✅ `bfh_merge_metadata()` - follows convention
- ❌ `extract_stats()` - too generic, no prefix
- ❌ `merge_meta()` - too generic, no prefix

### Requirement: Exported functions SHALL have comprehensive documentation

All exported functions SHALL include complete roxygen2 documentation with examples.

**Rationale:**
- Users need clear documentation for public API functions
- Examples demonstrate expected usage patterns
- Parameter documentation prevents misuse
- **Documentation SHALL stay synchronized with implementation; parameters that have been removed or whose behavior has changed SHALL have their documentation updated in the same release as the code change.**

**Documentation freshness contract:**

When a parameter's runtime behavior changes (e.g., from "deprecated with warning" to "removed with hard error"), the following SHALL be updated together:

1. `@param` description (current behavior, not historical)
2. `@return` description (only currently supported return shapes)
3. `@examples` (no demonstrations of removed parameters, even within `\dontrun{}`)
4. `man/<function>.Rd` (regenerated via `devtools::document()`)
5. `NEWS.md` entry describing the doc-implementation alignment

#### Scenario: Function documentation includes required sections

**Given** an exported function
**When** `devtools::document()` is run
**Then** the function SHALL have @title, @description, @param, @return, @examples
**And** documentation SHALL be accessible via `?function_name`

**Required sections:**
```r
#' Extract SPC Statistics from QIC Summary
#'
#' Extracts statistical process control metrics from a qic summary data frame.
#'
#' @param summary Data frame with SPC statistics (from bfh_qic result$summary)
#' @return List with SPC statistics: runs_expected, runs_actual, crossings_expected, crossings_actual, outliers_expected, outliers_actual
#' @export
#' @examples
#' \dontrun{
#' result <- bfh_qic(data, x = date, y = value, chart_type = "i")
#' stats <- bfh_extract_spc_stats(result$summary)
#' }
```

#### Scenario: Removed parameters reflect removal status in current docs

- **GIVEN** a parameter that has been removed from runtime behavior in a prior release (e.g., `print.summary` removed in v0.11.0)
- **WHEN** the user reads `?bfh_qic` or `man/bfh_qic.Rd`
- **THEN** the `@param` description SHALL state that calling with the removed argument value raises an error
- **AND** SHALL provide migration instructions to the supported equivalent
- **AND** SHALL NOT describe the parameter as "deprecated with warning" if the runtime now hard-errors

```r
# After update, ?bfh_qic should NOT contain:
#   "When TRUE, triggers deprecation warning"
# It SHALL contain:
#   "Calling with print.summary = TRUE raises an error"
#   "Use return.data = TRUE and access result$qic_summary, or use the
#    default bfh_qic_result object and access result$summary directly."
```

#### Scenario: @examples never demonstrate removed parameters

- **GIVEN** a function with examples in roxygen
- **WHEN** the package is built
- **THEN** no `@examples` block SHALL pass a value to a parameter that triggers a hard error at runtime
- **AND** this SHALL hold even when the example is wrapped in `\dontrun{}` (since `\dontrun` examples are still copy-pasted by users)

```r
# Verification: regression test in test-public-api-contract.R
test_that("bfh_qic Rd does not advertise removed print.summary as deprecated", {
  rd_content <- readLines(system.file("man", "bfh_qic.Rd", package = "BFHcharts"))
  expect_false(any(grepl("deprecated, will warn", rd_content, fixed = TRUE)))
  expect_false(any(grepl("print.summary = TRUE", rd_content, fixed = TRUE)))
})
```

### Requirement: Public functions SHALL support language selection via language parameter

Public-facing text-producing functions SHALL accept a `language` parameter selecting the output language, covering `bfh_qic()`, `bfh_generate_analysis()`, and `bfh_generate_details()`. All user-facing strings SHALL be resolved via a central i18n lookup in `inst/i18n/<lang>.yaml`.

**Rationale:**
- Hardcoded Danish strings block international use
- Translation lookup decouples rendering logic from locale
- YAML catalog enables non-developers to contribute translations

**Parameter:**
- `language` — character scalar, one of `"da"` (default) or `"en"`
- Invalid values SHALL raise an error
- Missing keys in target language SHALL fall back to Danish with a single warning per session

#### Scenario: Default language preserves Danish output

**Given** `bfh_generate_analysis(result)` is called without `language`
**When** the function executes
**Then** output text SHALL be in Danish (backward-compatible)

```r
analysis <- bfh_generate_analysis(result)
expect_match(analysis, "[æøåÆØÅ]|niveau|stabil")
```

#### Scenario: English language returns English strings

**Given** `language = "en"` is passed
**When** the function executes
**Then** output SHALL resolve from `inst/i18n/en.yaml`

```r
analysis <- bfh_generate_analysis(result, language = "en")
expect_match(analysis, "level|stable|process")
expect_false(grepl("[æøåÆØÅ]", analysis))
```

#### Scenario: Unknown language rejected

**Given** `language = "xx"`
**When** the function validates input
**Then** it SHALL raise an informative error listing supported languages

```r
expect_error(
  bfh_generate_analysis(result, language = "xx"),
  "da|en"
)
```

#### Scenario: Missing translation falls back to Danish

**Given** a key exists in `da.yaml` but not in `en.yaml`
**When** the function resolves the key with `language = "en"`
**Then** it SHALL return the Danish string
**And** SHALL emit a single warning per session for that key

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

### Requirement: Summary SHALL expose variable control limits via min/max columns

When control limits vary across observations within a part (typical for P-charts and U-charts with varying denominators), the summary returned by `bfh_qic()$summary` SHALL include explicit per-part minimum and maximum bounds plus a flag indicating whether limits are constant.

**Rationale:**
- Healthcare-typical P/U charts have variable denominators per period
- Without exposed bounds, downstream consumers cannot distinguish "no limits available" from "limits vary"
- Silent omission can be misread as a stable process when limits actually fluctuated
- Exposing min/max preserves correctness while keeping summary actionable for reports

**Contract:**

| Limit constancy in part | `kontrolgrænser_konstante` | `nedre_/øvre_kontrolgrænse` (scalar) | `*_min`/`*_max` columns |
|---|---|---|---|
| Constant | `TRUE` | populated with single value | absent or NA |
| Variable | `FALSE` | absent or NA | populated with min/max across part |

#### Scenario: constant limits expose scalar columns and TRUE flag

- **GIVEN** an i-chart with constant control limits within a single part
- **WHEN** `format_qic_summary(...)` is called
- **THEN** the summary SHALL contain `nedre_kontrolgrænse` and `øvre_kontrolgrænse` as scalar columns
- **AND** `kontrolgrænser_konstante` SHALL be `TRUE`

```r
data <- data.frame(period = 1:10, value = c(10, 11, 10, 11, 10, 11, 10, 11, 10, 11))
result <- bfh_qic(data, x = period, y = value, chart_type = "i")
expect_true(result$summary$kontrolgrænser_konstante[1])
expect_true("nedre_kontrolgrænse" %in% names(result$summary))
expect_false(is.na(result$summary$nedre_kontrolgrænse[1]))
```

#### Scenario: variable limits expose min/max columns and FALSE flag

- **GIVEN** a P-chart with varying denominators within a part (e.g., `n = c(100, 200, 50)`)
- **WHEN** `format_qic_summary(...)` is called
- **THEN** the summary SHALL contain `nedre_kontrolgrænse_min`, `nedre_kontrolgrænse_max`, `øvre_kontrolgrænse_min`, `øvre_kontrolgrænse_max` columns
- **AND** `kontrolgrænser_konstante` SHALL be `FALSE`
- **AND** the min ≤ max relationship SHALL hold

```r
data <- data.frame(
  period = 1:6,
  events = c(5, 10, 5, 10, 5, 10),
  total = c(100, 200, 50, 200, 100, 50)  # varying n
)
result <- bfh_qic(data, x = period, y = events, n = total,
                  chart_type = "p", y_axis_unit = "percent")
expect_false(result$summary$kontrolgrænser_konstante[1])
expect_true("nedre_kontrolgrænse_min" %in% names(result$summary))
expect_lte(result$summary$nedre_kontrolgrænse_min[1],
           result$summary$nedre_kontrolgrænse_max[1])
```

#### Scenario: backward-compatible reads on constant-limit summaries

- **GIVEN** existing downstream code that reads `summary$nedre_kontrolgrænse` for a constant-limit chart
- **WHEN** `format_qic_summary(...)` is called
- **THEN** the column SHALL be present and populated as before
- **AND** existing tests SHALL pass without modification

#### Scenario: mixed constancy across multi-part summary

- **GIVEN** a multi-part chart where part 1 has constant limits and part 2 has variable limits
- **WHEN** `format_qic_summary(...)` is called
- **THEN** `kontrolgrænser_konstante` SHALL be `TRUE` for part 1 and `FALSE` for part 2
- **AND** scalar columns SHALL be populated for part 1 (NA or absent for part 2)
- **AND** min/max columns SHALL be populated for part 2 (NA for part 1)

### Requirement: Public API SHALL validate target_value scale against y_axis_unit contract

The package SHALL validate `target_value` against an explicit scale derived from `y_axis_unit` and `multiply` to prevent silent unit-mismatch bugs that produce clinically misleading target lines.

**Rationale:**
- Healthcare context: silent magic is more dangerous than a clear, actionable error
- Most common user-intuition error: passing `target_value = 2.0` for "2%" instead of `0.02`
- Without validation, target line renders at 200% on a 0-100% axis — clinically misleading and a real risk for quality reports

**Contract:**

| `y_axis_unit` | `multiply` | Expected `target_value` range |
|---|---|---|
| `"percent"` | `1` (default) | `[0, 1.5]` (proportion) |
| `"percent"` | `100` | `[0, 150]` (percent) |
| `"percent"` | other `m` | `[0, m * 1.5]` |
| `"count"` / `"rate"` / `"time"` | any | not validated against scale (subject to existing numeric validation only) |

The 1.5x slack on the upper bound permits legitimate targets near the edge (e.g., aspirational stretch targets at 105%) while still catching the common 100x mismatch.

The contract applies uniformly across all chart types — including run-chart, which has no control limits but still renders a target line.

#### Scenario: percent target_value > 1.5 with default multiply rejected

- **GIVEN** `y_axis_unit = "percent"`, `multiply = 1`, `target_value = 2.0`
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised
- **AND** the error message SHALL identify the expected scale (`[0, 1.5]`)
- **AND** the error message SHALL include an actionable migration hint suggesting `target_value = 0.02` or `multiply = 100`

```r
expect_error(
  bfh_qic(data, x = period, y = events, n = total,
          chart_type = "p", y_axis_unit = "percent",
          target_value = 2.0),
  "uden for forventet skala"
)
```

#### Scenario: percent target_value as proportion accepted

- **GIVEN** `y_axis_unit = "percent"`, `multiply = 1`, `target_value = 0.02`
- **WHEN** `bfh_qic(...)` is called
- **THEN** the function SHALL succeed
- **AND** the underlying `qic_data$target` SHALL equal `0.02`

```r
result <- bfh_qic(data, x = period, y = events, n = total,
                  chart_type = "p", y_axis_unit = "percent",
                  target_value = 0.02)
expect_equal(unique(result$qic_data$target[!is.na(result$qic_data$target)]), 0.02)
```

#### Scenario: percent target_value with multiply=100 accepted as percent

- **GIVEN** `y_axis_unit = "percent"`, `multiply = 100`, `target_value = 2.0`
- **WHEN** `bfh_qic(...)` is called
- **THEN** the function SHALL succeed
- **AND** the underlying `qic_data$target` SHALL equal `2.0`

```r
result <- bfh_qic(data, x = period, y = events, n = total,
                  chart_type = "p", y_axis_unit = "percent",
                  target_value = 2.0, multiply = 100)
expect_equal(unique(result$qic_data$target[!is.na(result$qic_data$target)]), 2.0)
```

#### Scenario: negative target_value rejected for percent

- **GIVEN** `y_axis_unit = "percent"`, `target_value = -0.1`
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised
- **AND** the error message SHALL state that proportion targets must be non-negative

```r
expect_error(
  bfh_qic(data, x = period, y = events, n = total,
          chart_type = "p", y_axis_unit = "percent",
          target_value = -0.1),
  "non-negative|ikke-negativ"
)
```

#### Scenario: boundary values within contract accepted

- **GIVEN** `y_axis_unit = "percent"`, `multiply = 1`
- **WHEN** `target_value = 1.0` (valid 100% target) OR `target_value = 1.5` (boundary)
- **THEN** the function SHALL succeed for both
- **AND** the underlying `qic_data$target` SHALL preserve the input value

```r
# 100% target
result_100 <- bfh_qic(data, x = period, y = events, n = total,
                      chart_type = "p", y_axis_unit = "percent",
                      target_value = 1.0)
expect_equal(unique(result_100$qic_data$target[!is.na(result_100$qic_data$target)]), 1.0)

# Upper boundary
result_boundary <- bfh_qic(data, x = period, y = events, n = total,
                           chart_type = "p", y_axis_unit = "percent",
                           target_value = 1.5)
expect_equal(unique(result_boundary$qic_data$target[!is.na(result_boundary$qic_data$target)]), 1.5)
```

#### Scenario: non-percent units skip scale validation

- **GIVEN** `y_axis_unit = "count"`, `target_value = 9999`
- **WHEN** `bfh_qic(...)` is called
- **THEN** the function SHALL NOT validate target_value against any scale ceiling
- **AND** the function SHALL succeed (subject to existing numeric parameter validation)

```r
data <- data.frame(period = 1:10, value = rpois(10, lambda = 50))
result <- bfh_qic(data, x = period, y = value,
                  chart_type = "i", y_axis_unit = "count",
                  target_value = 9999)
expect_s3_class(result, "bfh_qic_result")
```

#### Scenario: contract applies to run-chart despite no control limits

- **GIVEN** `chart_type = "run"`, `y_axis_unit = "percent"`, `target_value = 2.0`, `multiply = 1`
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised
- **AND** the contract SHALL be enforced regardless of chart type

```r
expect_error(
  bfh_qic(data, x = period, y = events, n = total,
          chart_type = "run", y_axis_unit = "percent",
          target_value = 2.0),
  "uden for forventet skala"
)
```

### Requirement: Public API SHALL validate denominator column content for ratio charts

The package SHALL validate the content of the denominator column (`n` argument) for ratio chart types (`p`, `pp`, `u`, `up`) to prevent silently misleading rate plots from invalid denominator data.

**Rationale:**
- Healthcare data routinely contain rows with missing or zero denominators (e.g., months with no patients, missing data ingest)
- Without content validation, qicharts2 produces NaN/Inf rates that render as silent gaps or out-of-range points
- For P-charts, `y > n` violates the proportion contract (proportion ≤ 1) but qicharts2 plots it anyway
- Strict failure with row-numbered messages makes invalid data visible to users instead of hidden

**Contract:**

| Chart type | `n` required | Validations on `n` content |
|---|---|---|
| `p`, `pp` | yes | `n > 0`, finite, `y <= n` per row |
| `u`, `up` | yes | `n > 0`, finite |
| `c`, `g`, `t` | no | n/a |
| `i`, `mr`, `run` | no | n/a |
| `xbar`, `s` | no (uses duplicated x as subgrouping) | n/a |

`NA` in individual rows of `n` is permitted (qicharts2 drops them as missing data).

#### Scenario: ratio chart without n rejected

- **GIVEN** `chart_type = "p"` and no `n` argument
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised
- **AND** the message SHALL identify which chart types require `n`

```r
data <- data.frame(period = 1:8, events = rep(5L, 8))
expect_error(
  bfh_qic(data, x = period, y = events, chart_type = "p"),
  "requires denominator"
)
```

#### Scenario: zero denominator rejected

- **GIVEN** `chart_type = "p"`, `n = c(100, 0, 100, 100)`
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised
- **AND** the message SHALL state that `n` must be > 0

```r
data <- data.frame(
  period = 1:4,
  events = c(5L, 0L, 5L, 5L),
  total = c(100L, 0L, 100L, 100L)
)
expect_error(
  bfh_qic(data, x = period, y = events, n = total, chart_type = "p"),
  "must be > 0"
)
```

#### Scenario: negative denominator rejected

- **GIVEN** `chart_type = "u"`, `n = c(100, -5, 100, 100)`
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised

#### Scenario: infinite denominator rejected

- **GIVEN** `n` column contains `Inf`
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised mentioning Inf/-Inf

#### Scenario: NA in individual rows of n permitted

- **GIVEN** `chart_type = "p"`, `n = c(100, NA, 100, 100)`, `y` valid otherwise
- **WHEN** `bfh_qic(...)` is called
- **THEN** the function SHALL succeed
- **AND** qicharts2 SHALL drop the NA row from calculations

```r
data <- data.frame(
  period = 1:4,
  events = c(5L, 5L, 5L, 5L),
  total = c(100L, NA_integer_, 100L, 100L)
)
result <- bfh_qic(data, x = period, y = events, n = total, chart_type = "p")
expect_s3_class(result, "bfh_qic_result")
```

#### Scenario: y greater than n on P-chart rejected with row numbers

- **GIVEN** `chart_type = "p"`, `y = c(5, 6, 200, 8)`, `n = c(100, 100, 100, 100)`
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised
- **AND** the message SHALL identify the violation row(s) (row 3 in this example)

```r
data <- data.frame(
  period = 1:4,
  events = c(5L, 6L, 200L, 8L),
  total = rep(100L, 4)
)
expect_error(
  bfh_qic(data, x = period, y = events, n = total, chart_type = "p"),
  "y <= n"
)
```

#### Scenario: u-chart allows y > n

- **GIVEN** `chart_type = "u"`, `y = c(50, 60, 200)`, `n = c(100, 100, 100)`
- **WHEN** `bfh_qic(...)` is called
- **THEN** the function SHALL succeed
- **AND** rates can exceed 1 (events per unit, not proportion)

```r
data <- data.frame(
  period = 1:3,
  events = c(50L, 60L, 200L),
  exposure = rep(100L, 3)
)
result <- bfh_qic(data, x = period, y = events, n = exposure, chart_type = "u")
expect_s3_class(result, "bfh_qic_result")
```

#### Scenario: xbar chart skips n validation

- **GIVEN** `chart_type = "xbar"` with subgroup data (duplicated x values, no n)
- **WHEN** `bfh_qic(...)` is called
- **THEN** the function SHALL NOT validate denominator content
- **AND** the function SHALL succeed

