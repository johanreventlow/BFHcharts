# Specification: pdf-export

## Overview

This specification defines font handling for PDF export in BFHcharts.

---

## MODIFIED Requirements

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

## Non-Functional Requirements

### Requirement: Backward compatibility SHALL be maintained

Existing code using `bfh_export_pdf()` SHALL continue to work without modification.

#### Scenario: Existing PDF export code works unchanged

**Given** existing code that calls `bfh_export_pdf()`
**When** the code is run after the font removal
**Then** the PDF SHALL be generated successfully
**And** no API changes SHALL be required

```r
# Existing code - should work unchanged
result <- bfh_qic(data, x = month, y = infections, chart_type = "i")
bfh_export_pdf(result, "report.pdf",
  metadata = list(
    hospital = "BFH",
    department = "Quality",
    analysis = "Process stable"
  )
)
expect_true(file.exists("report.pdf"))
```
