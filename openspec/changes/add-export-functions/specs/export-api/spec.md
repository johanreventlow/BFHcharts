# Export API Specification

## ADDED Requirements

### Requirement: S3 Result Class

The package MUST define a `bfh_qic_result` S3 class that wraps the SPC chart output. The `bfh_qic()` function SHALL return this class instead of a plain ggplot object. The class MUST include a print method that displays the plot for backwards compatibility.

#### Scenario: Creating an SPC chart returns result object

**Given** a valid data frame with date and value columns
**When** calling `bfh_qic(data, x = date, y = value, chart_type = "i")`
**Then** the return value MUST be of class `bfh_qic_result`
**And** the return value MUST contain `$plot` (ggplot object)
**And** the return value MUST contain `$summary` (tibble with SPC statistics)
**And** the return value MUST contain `$config` (list with original parameters)

#### Scenario: Print method displays plot

**Given** a `bfh_qic_result` object from `bfh_qic()`
**When** the object is printed (implicitly or via `print()`)
**Then** the ggplot chart SHALL be displayed in the console/viewer
**And** the function SHALL return the object invisibly for pipe chaining

---

### Requirement: PNG Export Function

The package MUST export a `bfh_export_png()` function that generates PNG images from SPC charts. The function SHALL accept dimension parameters in millimeters and DPI resolution.

#### Scenario: Export chart to PNG

**Given** a `bfh_qic_result` object with a chart titled "Monthly Infections"
**When** calling `bfh_export_png(result, "chart.png", width_mm = 200, height_mm = 120, dpi = 300)`
**Then** a PNG file SHALL be created at the specified path
**And** the image dimensions SHALL match the specified width and height at the given DPI
**And** the chart title SHALL be visible in the PNG image

#### Scenario: PNG export in pipe workflow

**Given** valid SPC data
**When** executing `bfh_qic(data, x, y) |> bfh_export_png("chart.png")`
**Then** a PNG file SHALL be created successfully
**And** the function SHALL return the input object invisibly for further chaining

#### Scenario: Invalid input to PNG export

**Given** an object that is not a `bfh_qic_result`
**When** calling `bfh_export_png(invalid_object, "chart.png")`
**Then** the function SHALL throw an informative error message

---

### Requirement: PDF Export Function

The package MUST export a `bfh_export_pdf()` function that generates PDF documents via Typst templates. The function SHALL require Quarto CLI for compilation.

#### Scenario: Export chart to PDF

**Given** a `bfh_qic_result` object with chart title and SPC statistics
**And** Quarto CLI is installed on the system
**When** calling `bfh_export_pdf(result, "report.pdf", metadata = list(hospital = "BFH"))`
**Then** a PDF file SHALL be created at the specified path
**And** the chart title SHALL appear in the PDF document (not in the chart image)
**And** SPC statistics (runs, crossings) SHALL appear in the PDF document

#### Scenario: PDF export without Quarto

**Given** a `bfh_qic_result` object
**And** Quarto CLI is NOT installed on the system
**When** calling `bfh_export_pdf(result, "report.pdf")`
**Then** the function SHALL throw an informative error message
**And** the error message SHALL include instructions for installing Quarto

#### Scenario: PDF export in pipe workflow

**Given** valid SPC data and Quarto CLI installed
**When** executing `bfh_qic(data, x, y, chart_title = "Test") |> bfh_export_pdf("report.pdf")`
**Then** a PDF file SHALL be created successfully
**And** the function SHALL return the input object invisibly

---

### Requirement: Typst Document Creation

The package MUST export a `bfh_create_typst_document()` function for low-level Typst document generation. This allows advanced users to customize the Typst workflow.

#### Scenario: Create Typst document

**Given** a chart PNG image and metadata
**When** calling `bfh_create_typst_document(chart_image, output, metadata, spc_stats)`
**Then** a valid .typ file SHALL be created
**And** the file SHALL reference the chart image
**And** the file SHALL include the provided metadata

---

### Requirement: Typst Templates

The package MUST include Typst templates in `inst/templates/typst/`. Templates SHALL follow BFH hospital branding guidelines.

#### Scenario: Template availability

**Given** a fresh BFHcharts installation
**When** calling `system.file("templates/typst/bfh-template", package = "BFHcharts")`
**Then** the function SHALL return a valid path to the template directory
**And** the directory SHALL contain `bfh-template.typ`

## MODIFIED Requirements

### Requirement: bfh_qic Return Type

The `bfh_qic()` function MUST return a `bfh_qic_result` S3 object instead of a plain ggplot object. The `print.summary` parameter SHALL be deprecated as the summary is always included.

#### Scenario: Migration from ggplot return

**Given** existing code that expects a ggplot return: `p <- bfh_qic(data, x, y)`
**When** upgrading to version 0.3.0
**Then** `p$plot` SHALL provide access to the ggplot object
**And** `p + theme_minimal()` SHALL produce an informative error suggesting `p$plot + theme_minimal()`
