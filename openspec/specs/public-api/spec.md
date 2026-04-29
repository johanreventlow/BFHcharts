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

