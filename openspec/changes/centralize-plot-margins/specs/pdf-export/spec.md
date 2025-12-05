## MODIFIED Requirements

### Requirement: Export functions SHALL conditionally remove blank axis titles

When exporting charts to PDF or PNG, the system SHALL remove axis titles that are blank or NULL, but SHALL preserve user-defined axis titles.

**MODIFICATION:** This logic is now centralized in `apply_spc_theme()` which is called by `bfh_qic()`. Export functions no longer need to handle axis title removal as it is done automatically when the plot is created.

**Updated Conditional Removal Logic:**
- Axis title removal now occurs in `apply_spc_theme()` (called by `bfh_qic()`)
- `bfh_export_pdf()` and `bfh_export_png()` receive plots with axis titles already handled
- PDF export still applies 0mm margin override for Typst template compatibility

#### Scenario: bfh_qic() creates plot with blank axis titles removed

**Given** a call to `bfh_qic()` with no custom axis titles set
**When** the plot is created via `apply_spc_theme()`
**Then** the x-axis title SHALL be removed (not just invisible)
**And** the y-axis title SHALL be removed (not just invisible)
**And** the plot SHALL have 5mm margins by default

```r
# Default - no axis titles
result <- bfh_qic(data, x = month, y = value, chart_type = "i")
# Plot already has blank axis titles removed and 5mm margins
# No additional processing needed for PNG export
```

#### Scenario: PDF export overrides margins to 0mm

**Given** a `bfh_qic_result` object (with axis titles already handled)
**When** `bfh_export_pdf()` is called
**Then** the plot margins SHALL be overridden to 0mm for Typst template
**And** axis titles SHALL remain as set by `bfh_qic()` (no additional processing)

```r
result <- bfh_qic(data, x = month, y = value, chart_type = "i")
bfh_export_pdf(result, "output.pdf")
# Margins changed from 5mm to 0mm, axis titles unchanged
```

#### Scenario: PNG export uses default 5mm margins from bfh_qic()

**Given** a `bfh_qic_result` object (with 5mm margins and axis titles handled)
**When** `bfh_export_png()` is called
**Then** the plot SHALL be exported as-is without additional processing
**And** margins SHALL remain at 5mm (default from bfh_qic)

```r
result <- bfh_qic(data, x = month, y = value, chart_type = "i")
bfh_export_png(result, "output.png")
# No modification needed - plot already has correct margins
```

---

### Requirement: PNG export SHALL use inherited 5mm plot margins

The `bfh_export_png()` function SHALL use the 5mm margins already applied by `bfh_qic()` via `apply_spc_theme()`. The export function SHALL NOT apply additional margin processing.

**MODIFICATION:** This requirement is now handled by `bfh_qic()` via `apply_spc_theme()`. The `bfh_export_png()` function no longer needs to apply margins as they are set when the plot is created.

#### Scenario: PNG exported with default 5mm margins from bfh_qic

**Given** a valid `bfh_qic_result` object
**When** `bfh_export_png()` is called
**Then** the chart PNG SHALL have 5mm margins (inherited from bfh_qic)
**And** no additional margin processing SHALL be performed

```r
result <- bfh_qic(data, x = month, y = value, chart_type = "i")
bfh_export_png(result, "test.png")
# Chart PNG has 5mm margins from bfh_qic(), not from export function
```

---
