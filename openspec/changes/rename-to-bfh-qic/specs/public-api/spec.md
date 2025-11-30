# Public API

## MODIFIED Requirements

### Requirement: Main Chart Function

The package MUST export a primary function named `bfh_qic()` (renamed from `create_spc_chart()`) for creating SPC charts with BFH branding and intelligent defaults. The function SHALL wrap qicharts2::qic() with enhanced visualization and labeling.

**Function signature:**
```r
bfh_qic(data, x, y, n = NULL, chart_type = "run",
        y_axis_unit = "count", chart_title = NULL,
        target_value = NULL, target_text = NULL,
        notes = NULL, part = NULL, freeze = NULL,
        exclude = NULL, cl = NULL, multiply = 1,
        agg.fun = c("mean", "median", "sum", "sd"),
        base_size = 14, width = NULL, height = NULL,
        units = NULL, dpi = 96, plot_margin = NULL,
        ylab = "", xlab = "", subtitle = NULL,
        caption = NULL, return.data = FALSE,
        print.summary = FALSE)
```

**Returns:**
- Default: ggplot2 object
- `return.data = TRUE`: data.frame with qic calculations
- `print.summary = TRUE`: list(plot, summary)
- Both TRUE: list(data, summary)

**Rationale:**
- Shorter, more memorable name (7 vs 17 characters)
- BFH branding via `bfh_` prefix
- Clear connection to qicharts2::qic() underlying engine
- More efficient for interactive use

#### Scenario: Basic SPC chart creation

**Given:** A data frame with date and measurement columns
**When:** User calls `bfh_qic(data, month, infections, chart_type = "i")`
**Then:** Returns a ggplot2 object with I-chart and BFH styling

#### Scenario: P-chart with target line

**Given:** A data frame with proportions and denominators
**When:** User calls `bfh_qic(data, month, infections, n = surgeries, chart_type = "p", target_value = 2.0)`
**Then:** Returns a ggplot2 p-chart with target line at 2.0

#### Scenario: Chart with phase splits

**Given:** A data frame with baseline and intervention periods
**When:** User calls `bfh_qic(data, month, infections, chart_type = "i", part = c(12), freeze = 12)`
**Then:** Returns a chart with phase split at observation 12 and frozen baseline

#### Scenario: Backward compatibility - old function name fails

**Given:** Legacy code using `create_spc_chart()`
**When:** User runs code after upgrading to v0.2.0
**Then:** R throws error: "could not find function 'create_spc_chart'"

#### Scenario: Migration to new name

**Given:** Legacy code using `create_spc_chart(data, x, y, ...)`
**When:** User replaces with `bfh_qic(data, x, y, ...)`
**Then:** Code runs identically with same output (drop-in replacement)

### Requirement: Package Documentation

Package-level documentation (?BFHcharts-package) MUST reference `bfh_qic()` instead of `create_spc_chart()` and SHALL reflect the renamed function as the primary entry point.

**Files affected:**
- R/BFHcharts-package.R

#### Scenario: User reads package documentation

**Given:** User types `?BFHcharts` or `help(package = "BFHcharts")`
**When:** Documentation renders
**Then:** Examples and descriptions reference `bfh_qic()`, not `create_spc_chart()`

### Requirement: Cross-References

Internal function documentation MUST update all @seealso cross-references to reference `bfh_qic()` instead of `create_spc_chart()`.

**Files affected:**
- R/plot_core.R (bfh_spc_plot @seealso)
- R/fct_add_spc_labels.R (add_spc_labels @seealso)
- R/config_objects.R (spc_plot_config @seealso)
- R/utils_y_axis_formatting.R (apply_y_axis_formatting @seealso)

#### Scenario: User reads internal function documentation

**Given:** User types `?bfh_spc_plot` to read about low-level plotting
**When:** Documentation renders
**Then:** @seealso section references `bfh_qic()` for high-level usage
