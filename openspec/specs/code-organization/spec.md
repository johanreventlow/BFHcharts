# code-organization Specification

## Purpose
TBD - created by archiving change consolidate-formatting-utilities. Update Purpose after archive.
## Requirements
### Requirement: Time formatting SHALL have single canonical implementation

All time formatting in the package SHALL use a single canonical implementation in `R/utils_time_formatting.R`.

**Rationale:**
- Prevents code duplication
- Ensures consistent formatting across package
- Reduces maintenance burden
- Enables centralized testing

#### Scenario: Format time value in Danish

**Given** a time value in minutes
**When** `format_time_danish()` is called
**Then** the function SHALL return correctly formatted Danish time string
**And** the function SHALL select appropriate unit (sekunder, minutter, timer, dage)
**And** the function SHALL use Danish decimal formatting (comma as separator)

**Implementation:**
```r
#' Format Time Value in Danish
#'
#' Formats a time value with appropriate Danish unit and formatting.
#'
#' @param value_minutes Numeric time value in minutes
#' @param context Optional context for unit selection hints
#' @return Character string with formatted time and Danish unit
#' @export
#' @examples
#' format_time_danish(30)      # "30 min"
#' format_time_danish(90)      # "1,5 timer"
#' format_time_danish(1440)    # "1 dag"
format_time_danish <- function(value_minutes, context = NULL) {
  unit <- determine_time_unit(value_minutes, context)
  scaled_value <- scale_to_unit(value_minutes, unit)
  unit_label <- get_danish_time_label(unit)
  format_with_decimals(scaled_value, unit_label)
}
```

**Validation:**
- Single `format_time_danish()` function exists
- No other time formatting implementations in package
- All time formatting call sites use this function

#### Scenario: Legacy code migrated to canonical function

**Given** existing code that uses duplicate time formatting
**When** the consolidation is complete
**Then** all call sites SHALL use `format_time_danish()`
**And** no duplicate implementations SHALL remain

**Validation:**
- `grep -r "format_time" R/` returns only `utils_time_formatting.R`
- All tests pass after migration

### Requirement: Number formatting SHALL have single canonical implementation

All number formatting with K/M/mia notation SHALL use a single canonical implementation in `R/utils_number_formatting.R`.

**Rationale:**
- Consistent magnitude notation across package
- Danish-specific formatting (tusinde, millioner, milliarder)
- Single point of maintenance

#### Scenario: Format large number in Danish

**Given** a numeric value
**When** `format_count_danish()` is called
**Then** the function SHALL format with appropriate magnitude suffix
**And** the function SHALL use K for thousands
**And** the function SHALL use M for millions
**And** the function SHALL use mia for billions

**Implementation:**
```r
#' Format Count with Danish Magnitude Notation
#'
#' Formats numeric values with K/M/mia suffixes for readability.
#'
#' @param value Numeric value to format
#' @param use_big_mark Logical, whether to use thousand separator
#' @return Character string with formatted value
#' @export
#' @examples
#' format_count_danish(1500)         # "1,5K"
#' format_count_danish(1500000)      # "1,5M"
#' format_count_danish(1500000000)   # "1,5 mia"
format_count_danish <- function(value, use_big_mark = TRUE) {
  magnitude <- determine_magnitude(value)
  scaled <- value / magnitude$divisor
  paste0(format_decimal(scaled), magnitude$suffix)
}
```

**Validation:**
- Single `format_count_danish()` function exists
- No other K/M/mia implementations in package
- All number formatting call sites use this function

