# Contextual Percent Precision

## Status
PROPOSED

## Why

The current percent formatting always rounds to whole percentages (e.g., "99%" instead of "98.7%"). This loses precision that is important in healthcare quality improvement contexts:

1. **Centerline labels near target**: When a process centerline is close to the target (within 5 percentage points), each decimal matters. Showing "89%" vs "88.7%" when the target is 90% obscures meaningful progress.

2. **Y-axis with narrow range**: When the y-axis spans only 1-2 percentage points (e.g., 98%-100%), whole-number ticks become indistinguishable or repeat the same value.

A previous fix (commit 476cbc7) added `accuracy = 0.1` globally, but this caused all percentages to show decimals unnecessarily (e.g., "50.0%" instead of "50%"), which looked awkward.

## What Changes

Implement **contextual precision** that shows decimals only when meaningful:

### Centerline Labels
- **With target set**: Show one decimal if `abs(centerline - target) <= 0.05` (5 percentage points)
- **Without target**: Use whole percentages (current behavior)
- Only affects centerline labels, not UCL/LCL (which don't have labels)

### Y-Axis Ticks
- **Narrow range**: Show one decimal if `y_max - y_min < 0.05` (5 percentage points)
- **Wide range**: Use whole percentages (current behavior)

### Examples

| Component | Value | Target | Range | Output |
|-----------|-------|--------|-------|--------|
| Centerline | 0.887 | 0.90 | - | "88,7%" |
| Centerline | 0.634 | 0.90 | - | "63%" |
| Centerline | 0.500 | NULL | - | "50%" |
| Y-axis tick | 0.985 | - | 0.98-1.00 | "98,5%" |
| Y-axis tick | 0.50 | - | 0.00-1.00 | "50%" |

## Impact

- **Affected specs**: label-formatting (new)
- **Affected code**:
  - `R/utils_label_formatting.R` - Add `format_percent_contextual()` function
  - `R/fct_add_spc_labels.R` - Pass target to centerline formatting
  - `R/utils_y_axis_formatting.R` - Add range-aware precision for y-axis
- **Breaking changes**: None (behavior improves but defaults remain compatible)
- **Dependencies**: None

## Alternatives Considered

1. **Always show decimals** (rejected): Looks awkward for round values like "50.0%"
2. **User-configurable precision** (rejected): Adds complexity; contextual logic handles most cases
3. **Threshold as parameter** (deferred): 5 percentage points is sensible default; can add parameter later if needed

## Related

- Reverts behavior from commit 476cbc7
- GitHub Issue: #68
