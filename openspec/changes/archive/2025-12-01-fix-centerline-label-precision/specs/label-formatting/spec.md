# Specification: label-formatting

## Overview

This specification defines the formatting requirements for SPC chart labels, including centerline labels, data point labels, and axis tick labels. Consistent, precise label formatting is critical for accurate interpretation of healthcare quality metrics.

## MODIFIED Requirements

### Requirement: Percent labels SHALL display one decimal place for precision

Percent labels SHALL use `accuracy = 0.1` formatting to display one decimal place (e.g., "98.7%") rather than rounding to whole percentages (e.g., "99%").

**Rationale:**
- Healthcare quality metrics often have centerlines near but not exactly at target values (e.g., 98.7% vs 99%)
- Whole number rounding obscures meaningful differences in process performance
- One decimal place balances precision with readability

**Modified from:** Previous behavior used whole number rounding (accuracy = 1)

#### Scenario: Centerline label shows precise percent value

**Given** an SPC chart with percent y-axis unit
**And** a centerline value of 0.987 (98.7%)
**When** the centerline label is rendered
**Then** the label MUST display "98.7%"
**And** NOT display "99%"

**Acceptance Criteria:**
- `format_y_value(0.987, "percent")` returns `"98.7%"`
- `format_y_value(0.456, "percent")` returns `"45.6%"`
- `format_y_value(0.999, "percent")` returns `"100%"` (rounds to whole when appropriate)
- Label text matches y-axis tick label precision

#### Scenario: Percent labels use consistent decimal precision

**Given** an SPC chart with multiple percent labels (CL, tick marks, annotations)
**When** labels are formatted
**Then** all percent labels MUST use `accuracy = 0.1` precision
**And** display format MUST be consistent across label types

**Acceptance Criteria:**
- `scales::label_percent(accuracy = 0.1)` used for all percent formatting
- Centerline labels, y-axis ticks, and annotations have matching precision
- No mixing of whole number and decimal formats

#### Scenario: Edge case percentages display correctly

**Given** percent values near boundaries (0%, 100%)
**When** labels are formatted
**Then** values MUST round to appropriate precision

**Test Cases:**
- `format_y_value(0.001, "percent")` → `"0.1%"` (rounds up from 0.1%)
- `format_y_value(0.0001, "percent")` → `"0.0%"` (rounds down)
- `format_y_value(0.995, "percent")` → `"99.5%"`
- `format_y_value(0.9999, "percent")` → `"100%"` (rounds to whole)
- `format_y_value(1.0, "percent")` → `"100%"`

## Existing Requirements (Unchanged)

### Requirement: Count labels use K/M/mia notation

**Status:** Existing (no changes)

Count labels MUST use abbreviated notation for large values to maintain readability.

**Notation rules:**
- Values ≥ 1,000: Display as "K" (thousands)
- Values ≥ 1,000,000: Display as "M" (millions)
- Values ≥ 1,000,000,000: Display as "mia" (billions)
- Danish decimal separator (comma)

**Examples:**
- `format_y_value(1234, "count")` → `"1,2K"`
- `format_y_value(1500000, "count")` → `"1,5M"`
- `format_y_value(2e9, "count")` → `"2 mia"`

### Requirement: Rate labels show minimal decimals

**Status:** Existing (no changes)

Rate labels MUST show decimals only when necessary.

**Rules:**
- Integer values: No decimal places
- Non-integer values: One decimal place minimum
- Danish decimal notation (comma)

**Examples:**
- `format_y_value(10, "rate")` → `"10"`
- `format_y_value(10.5, "rate")` → `"10,5"`

### Requirement: Time labels use context-aware units

**Status:** Existing (no changes)

Time labels MUST adapt units based on y-axis range for optimal readability.

**Unit selection:**
- Range < 60 minutes: Display in minutes ("min")
- Range 60-1440 minutes: Display in hours ("timer")
- Range > 1440 minutes: Display in days ("dage")

**Examples:**
- `format_y_value(45, "time", c(0, 50))` → `"45 min"`
- `format_y_value(90, "time", c(0, 500))` → `"1,5 timer"`
- `format_y_value(1440, "time", c(0, 5000))` → `"1 dage"`

## Implementation Notes

**File:** `R/utils_label_formatting.R`

**Function:** `format_y_value(val, y_unit, y_range = NULL)`

**Change required:**
```r
# Line 54 - BEFORE:
return(scales::label_percent()(val))

# Line 54 - AFTER:
return(scales::label_percent(accuracy = 0.1)(val))
```

**Test file:** `tests/testthat/test-utils_label_formatting.R`

**Tests to update:**
- Line 27: Update expected value from `"46%"` to `"45.6%"`
- Add new test for 0.987 → `"98.7%"`
- Verify 0.999 still rounds to `"100%"`

## Validation

**Unit tests:**
- ✅ All percent formatting tests pass with new expectations
- ✅ Edge case tests cover boundary values (0%, 100%)
- ✅ Existing count/rate/time tests remain unchanged

**Integration tests:**
- ✅ Visual verification on demo p-chart
- ✅ Y-axis tick labels match centerline label precision
- ✅ No regressions in other chart types

**Quality checks:**
- ✅ `devtools::check()` passes with 0 errors/warnings
- ✅ Test coverage maintained ≥90%
- ✅ Documentation updated (roxygen examples)

## Dependencies

**R packages:**
- `scales` (≥1.2.0) - Provides `label_percent()` function with `accuracy` parameter

**Related capabilities:**
- `y-axis-formatting` - Y-axis tick labels must use same precision
- `spc-labels` - Centerline label rendering depends on this specification

## Backward Compatibility

**Visual changes:**
- ⚠️ Existing charts will display different label text
- ⚠️ "99%" becomes "98.7%" for CL = 0.987

**API compatibility:**
- ✅ No function signature changes
- ✅ No breaking changes to public API
- ✅ Purely internal implementation change

**Impact assessment:**
- Low risk: Isolated to label formatting
- No SPCify changes required
- May require visual regression test updates (`vdiffr`)

## Future Considerations

**Potential enhancements:**
- Make `accuracy` configurable via chart config object
- Support locale-specific decimal separators (currently hardcoded to Danish comma)
- Adaptive precision based on value magnitude (e.g., 99.9% vs 10.3%)

**Not in scope for this change:**
- Configurable precision (keeping simple: fixed 0.1)
- Alternative rounding strategies (keeping scales::label_percent default)
- Non-percent label types (count/rate/time unchanged)
