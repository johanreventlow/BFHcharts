# OpenSpec Proposal: Refactor X-Axis Formatting

**Status:** PROPOSED
**GitHub Issue:** [#43](https://github.com/johanreventlow/BFHcharts/issues/43)
**Created:** 2025-12-02

## Problem Statement

The `apply_x_axis_formatting()` function in `R/plot_core.R` (lines 261-419) is 158 lines with high cyclomatic complexity:

- 4-5 levels of nesting
- Multiple responsibilities mixed in one function
- Hard to test edge cases in isolation
- Violates Single Responsibility Principle

### Current Responsibilities (5 in 1 function)

1. **Date conversion** - Date → POSIXct handling
2. **Interval detection** - daily/weekly/monthly pattern recognition
3. **Break calculation** - Adaptive interval sizing based on data density
4. **Format config selection** - Smart labels vs standard formatting
5. **Scale application** - Branching logic for different interval types

## Proposed Solution

Extract into cohesive, single-responsibility modules using a formatter strategy pattern:

```r
apply_x_axis_formatting <- function(plot, qic_data, viewport) {
  x_col <- qic_data$x

  if (inherits(x_col, c("POSIXct", "POSIXt", "Date"))) {
    apply_temporal_x_axis(plot, x_col)
  } else if (is.numeric(x_col)) {
    apply_numeric_x_axis(plot, x_col)
  } else {
    plot
  }
}
```

### Extracted Modules

1. **`apply_temporal_x_axis()`** - Orchestrates temporal formatting
2. **`apply_numeric_x_axis()`** - Simple numeric axis (already ~5 lines)
3. **`calculate_date_breaks()`** - Break calculation logic (~40 lines)
4. **`select_format_config()`** - Format selection logic (~20 lines)
5. **`normalize_to_posixct()`** - Date/POSIXct conversion (~10 lines)

## Scope

### In Scope

- Refactor `apply_x_axis_formatting()` into smaller functions
- Maintain identical external behavior (no API changes)
- Add unit tests for each extracted function
- Update internal documentation

### Out of Scope

- Changes to BFHtheme scale functions
- New formatting options or features
- Performance optimization (unless incidental)

## Success Criteria

1. No function exceeds 50 lines
2. Maximum 2 levels of nesting in any function
3. All existing tests pass unchanged
4. New unit tests for each extracted function
5. Code coverage maintained or improved

## Risk Assessment

**Low risk refactoring:**
- Internal function only (not exported)
- No API changes
- Behavior must be identical
- Existing integration tests provide safety net

## Estimated Effort

4-6 hours

## Design Document

See `specs/x-axis-api/spec.md` for detailed requirements.
