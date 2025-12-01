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

