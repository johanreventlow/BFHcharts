# Specification: pdf-export

## Purpose

This specification defines font handling for PDF export in BFHcharts, ensuring legal compliance by not bundling copyrighted fonts while maintaining functionality for both internal users (with Mari font) and external users (without Mari font).
## Requirements
### Requirement: Typst template SHALL use font fallback chain

The Typst template SHALL use a font fallback chain to support both internal users (with Mari font) and external users (without Mari).

**Font Fallback Chain:**
```typst
font: ("Mari", "Roboto", "Arial", "Helvetica", "sans-serif")
```

#### Scenario: PDF generated with Mari font (internal user)

**Given** Mari font is installed on the system
**When** `bfh_export_pdf()` is called
**Then** the PDF SHALL use Mari font for body text
**And** the PDF SHALL display hospital branding correctly

```r
# On a machine with Mari installed
result <- bfh_qic(test_data, x = month, y = value, chart_type = "i")
bfh_export_pdf(result, "test.pdf")
# PDF uses Mari font
```

#### Scenario: PDF generated with fallback font (external user)

**Given** Mari font is NOT installed on the system
**When** `bfh_export_pdf()` is called
**Then** the PDF SHALL use Roboto, Arial, Helvetica, or sans-serif (in order of preference)
**And** the PDF SHALL be readable and properly formatted

```r
# On a machine without Mari (e.g., Docker, CI)
result <- bfh_qic(test_data, x = month, y = value, chart_type = "i")
bfh_export_pdf(result, "test.pdf")
# PDF uses fallback font (Roboto/Arial)
```

---

### Requirement: Package SHALL NOT bundle copyrighted Mari fonts

The package SHALL NOT include Mari font files in the distribution.

#### Scenario: Package built without font files

**Given** the package is built with `devtools::build()`
**When** the tarball is inspected
**Then** the `inst/templates/typst/bfh-template/fonts/` directory SHALL NOT exist
**And** the package size SHALL be reduced by approximately 5 MB

```r
# Build package
devtools::build()

# Verify no fonts directory in built package
built_pkg <- list.files("..", pattern = "BFHcharts.*\\.tar\\.gz$", full.names = TRUE)
contents <- untar(built_pkg, list = TRUE)
font_files <- grep("fonts/", contents, value = TRUE)
length(font_files) == 0  # TRUE - no font files
```

---

### Requirement: PDF export SHALL apply zero plot margins

When exporting charts to PDF via `bfh_export_pdf()`, the system SHALL apply zero margins to the ggplot object before rendering to PNG for optimal fit in the Typst template.

**Margin Configuration:**
```r
ggplot2::theme(plot.margin = ggplot2::margin(0, 0, 0, 0, "mm"))
```

#### Scenario: PDF generated with zero margins

**Given** a valid `bfh_qic_result` object
**When** `bfh_export_pdf()` is called
**Then** the chart PNG SHALL have no whitespace margins around the plot area
**And** the chart SHALL fit precisely within the Typst template layout

```r
result <- bfh_qic(data, x = month, y = value, chart_type = "i")
bfh_export_pdf(result, "test.pdf")
# Chart in PDF has zero margins
```

---

### Requirement: PNG export SHALL apply 5mm plot margins

When exporting charts to PNG via `bfh_export_png()`, the system SHALL apply 5mm margins to the ggplot object for visual balance in standalone images.

**Margin Configuration:**
```r
ggplot2::theme(plot.margin = ggplot2::margin(5, 5, 5, 5, "mm"))
```

#### Scenario: PNG generated with 5mm margins

**Given** a valid `bfh_qic_result` object
**When** `bfh_export_png()` is called
**Then** the chart PNG SHALL have 5mm margins around the plot area
**And** the chart SHALL have balanced visual appearance as standalone image

```r
result <- bfh_qic(data, x = month, y = value, chart_type = "i")
bfh_export_png(result, "test.png")
# Chart PNG has 5mm margins on all sides
```

---

### Requirement: Export functions SHALL conditionally remove blank axis titles

When exporting charts to PDF or PNG, the system SHALL remove axis titles that are blank or NULL, but SHALL preserve user-defined axis titles.

**Conditional Removal Logic:**
- If x-axis title is blank/NULL → apply `axis.title.x.bottom = element_blank()`
- If y-axis title is blank/NULL → apply `axis.title.y.left = element_blank()`
- If axis title is set by user → preserve the title as-is

#### Scenario: Export without axis titles (default case)

**Given** a `bfh_qic_result` with no custom axis titles set
**When** `bfh_export_pdf()` or `bfh_export_png()` is called
**Then** the x-axis title SHALL be removed (not just invisible)
**And** the y-axis title SHALL be removed (not just invisible)
**And** no whitespace SHALL remain where titles would have been

```r
# Default - no axis titles
result <- bfh_qic(data, x = month, y = value, chart_type = "i")
bfh_export_pdf(result, "no_titles.pdf")
bfh_export_png(result, "no_titles.png")
# Both axis titles removed in both outputs
```

#### Scenario: Export with custom y-axis title only

**Given** a `bfh_qic_result` with a custom y-axis label
**When** `bfh_export_pdf()` or `bfh_export_png()` is called
**Then** the y-axis title SHALL be preserved and visible
**And** the x-axis title SHALL be removed (if blank)

```r
result <- bfh_qic(data, x = month, y = value, chart_type = "i",
                  y_axis_label = "Antal infektioner")
bfh_export_pdf(result, "with_y_title.pdf")
bfh_export_png(result, "with_y_title.png")
# Y-axis shows "Antal infektioner", x-axis title removed
```

#### Scenario: Export with custom x-axis title only

**Given** a `bfh_qic_result` with a custom x-axis label
**When** `bfh_export_pdf()` or `bfh_export_png()` is called
**Then** the x-axis title SHALL be preserved and visible
**And** the y-axis title SHALL be removed (if blank)

```r
result <- bfh_qic(data, x = month, y = value, chart_type = "i",
                  x_axis_label = "Måned")
bfh_export_pdf(result, "with_x_title.pdf")
bfh_export_png(result, "with_x_title.png")
# X-axis shows "Måned", y-axis title removed
```

#### Scenario: Export with both axis titles

**Given** a `bfh_qic_result` with both custom axis labels
**When** `bfh_export_pdf()` or `bfh_export_png()` is called
**Then** both axis titles SHALL be preserved and visible

```r
result <- bfh_qic(data, x = month, y = value, chart_type = "i",
                  x_axis_label = "Måned",
                  y_axis_label = "Antal infektioner")
bfh_export_pdf(result, "with_both_titles.pdf")
bfh_export_png(result, "with_both_titles.png")
# Both axis titles visible in both outputs
```

---

