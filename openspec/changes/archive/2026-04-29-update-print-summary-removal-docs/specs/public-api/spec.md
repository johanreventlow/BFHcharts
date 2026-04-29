## MODIFIED Requirements

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
