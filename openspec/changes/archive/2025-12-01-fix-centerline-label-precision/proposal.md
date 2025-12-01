# fix-centerline-label-precision

## Why

**Problem:** Centerline (CL) labels on SPC charts with percent units display rounded whole percentages instead of showing decimal precision, causing misleading visual representations.

**Current behavior:**
- A centerline value of 0.987 (98.7%) displays as "99%"
- A centerline value of 0.456 (45.6%) displays as "46%"
- Users cannot see the actual precise centerline value

**Root cause:**
- `format_y_value()` in `R/utils_label_formatting.R:54` uses `scales::label_percent()` without specifying the `accuracy` parameter
- `scales::label_percent()` defaults to `accuracy = 1`, which rounds to whole percentages

**Impact:**
- Misleading visual representation on healthcare quality charts
- Loss of precision for centerline values that are critical decision points
- Inconsistent with user expectations for statistical accuracy

**Example scenario:**
```r
# Chart showing infection rate with CL = 98.7%
data <- data.frame(
  date = seq.Date(Sys.Date() - 30, Sys.Date(), by = "day"),
  infections = rbinom(31, 100, 0.987) / 100
)

chart <- bfh_qic(data, x = date, y = infections, chart_type = "p")
# Centerline label shows "99%" instead of "98.7%"
```

## What Changes

**Code changes:**
1. Modify `format_y_value()` function in `R/utils_label_formatting.R` (line 54)
   - Change: `scales::label_percent()(val)`
   - To: `scales::label_percent(accuracy = 0.1)(val)`

**Test changes:**
2. Update existing tests in `tests/testthat/test-utils_label_formatting.R`
   - Modify line 27: `expect_equal(format_y_value(0.456, "percent"), "45.6%")`
   - Modify line 28: `expect_equal(format_y_value(0.987, "percent"), "98.7%")` (new test)
   - Keep line 28 (0.999): `expect_equal(format_y_value(0.999, "percent"), "100%")`

3. Add new test cases for decimal precision
   - Test centerline-specific scenarios (values near but not at 100%)
   - Verify Danish decimal notation if applicable

**Documentation changes:**
4. Update roxygen documentation in `R/utils_label_formatting.R`
   - Update @examples to reflect new behavior: `0.456 → "45.6%"` instead of `"46%"`

## Impact

**Affected specs:**
- `label-formatting` (new spec) - Percent label formatting requirements

**Affected code:**
- `R/utils_label_formatting.R` - Core formatting function
- `tests/testthat/test-utils_label_formatting.R` - Test expectations
- All SPC charts using percent units (p-charts, u-charts with percent display)

**User-visible changes:**
- ✅ Percent labels will show one decimal place (e.g., "98.7%" instead of "99%")
- ✅ Improved precision for centerline labels
- ✅ Consistent with y-axis tick labels (if they also use `scales::label_percent()`)

**Breaking changes:**
- ⚠️ Visual change - existing charts will display different label text
- ⚠️ NOT a breaking API change (same function signature)
- ⚠️ May require visual regression test updates if using `vdiffr`

**Compatibility:**
- No impact on SPCify application (purely visual change)
- No impact on statistical calculations (only affects display)
- Backward compatible from API perspective

## Alternatives Considered

**Alternative 1: Make accuracy configurable**
```r
format_y_value <- function(val, y_unit, y_range = NULL, percent_accuracy = 0.1) {
  if (y_unit == "percent") {
    return(scales::label_percent(accuracy = percent_accuracy)(val))
  }
  ...
}
```
**Rejected because:**
- Adds unnecessary complexity to internal API
- No current use case for varying precision
- Healthcare quality metrics typically use one decimal place

**Alternative 2: Use different accuracy based on value magnitude**
```r
if (y_unit == "percent") {
  accuracy <- if (abs(val - round(val)) < 0.01) 1 else 0.1
  return(scales::label_percent(accuracy = accuracy)(val))
}
```
**Rejected because:**
- Inconsistent label formatting (some whole, some decimal)
- Confusing for users
- Complex logic for minimal benefit

**Chosen approach: Fixed accuracy = 0.1**
- ✅ Simple, predictable behavior
- ✅ Matches common healthcare reporting standards
- ✅ Consistent across all percent labels

## Related

- GitHub Issue: [#63](https://github.com/johanreventlow/BFHcharts/issues/63)
