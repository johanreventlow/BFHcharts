# BFHcharts 0.3.3

## Security Hardening

**IMPORTANT:** This release addresses critical security vulnerabilities in PDF export functionality. Healthcare organizations using BFHcharts in production environments should update immediately.

### Critical Path Validation
* **Path traversal prevention:** All file paths now reject `..` directory traversal attempts
* **Shell injection protection:** Path parameters are validated against shell metacharacters (`;`, `|`, `&`, `$`, etc.) before being passed to system commands
* **Template path validation:** Custom Typst template paths undergo strict security checks before file operations

### Input Validation Strengthening
* **Metadata type checking:** All metadata fields now validate type constraints (string or Date for date field)
* **Length limits:** Metadata fields limited to 10,000 characters to prevent DoS attacks
* **Unknown field warnings:** Unknown metadata fields now trigger warnings to catch typos and misuse
* **Symlink resolution:** Template paths are now resolved through `normalizePath()` to prevent TOCTOU attacks

### Defense in Depth
* **Restrictive temp permissions:** Temporary directories created with mode 0700 (owner-only) to protect sensitive healthcare data
* **Ownership verification:** Temp directory ownership validated on Unix systems to prevent directory substitution attacks
* **File copy integrity:** All file copy operations verified with size checks to detect corruption or tampering
* **Path sanitization:** Error messages use `basename()` to avoid exposing sensitive full paths

### Testing
* Added comprehensive security test suite with 20 tests covering:
  - Path traversal rejection
  - Shell metacharacter validation
  - Metadata type and length validation
  - All tests passing with 0 failures

**Compliance:** These changes strengthen BFHcharts for HIPAA/GDPR compliance requirements in healthcare environments.

---

# BFHcharts 0.3.2

## Bug Fixes

* **Fixed chart path handling regression:** `bfh_create_typst_document()` now correctly handles chart images from any location. Charts are copied to the output directory before Typst generation, fixing the regression where only charts in the same directory worked.

* **Fixed Quarto version parsing:** `check_quarto_version()` now correctly parses version strings in formats like "Quarto 1.4.557" (prefixed) and "1.4" (two-part). Previously, prefixed version strings would bypass the version guard.

* **Strengthened template validation:** `bfh_export_pdf()` now properly rejects directories and non-.typ files as `template_path`. Added validation for file copy success with clear error messages.

* **Consistent path escaping:** All user-provided paths in generated Typst content are now properly escaped, including custom template paths and chart filenames with special characters.

## Improvements

* Added comprehensive content verification tests that check for metadata, chart references, and template imports in generated Typst (not just file existence)
* Tests now verify version parsing with prefixed formats and edge cases
* All 63 tests pass (7 skipped without Quarto)

---

# BFHcharts 0.3.1

## Bug Fixes

* **Fixed Windows path handling:** Typst import and image paths are now properly escaped for Windows paths and paths containing spaces. Previously, Windows-style backslashes would cause invalid Typst escape sequences.

* **Fixed date metadata propagation:** User-supplied `metadata$date` is now correctly forwarded to the Typst template. Previously, the PDF always showed today's date from the template, ignoring user-supplied dates.

* **Enhanced Quarto version checking:** `quarto_available()` now verifies that Quarto version is >= 1.4.0 (required for Typst support). Previously, only binary existence was checked, leading to opaque errors with older Quarto versions.

## New Features

* **Custom template support:** Added `template_path` parameter to `bfh_export_pdf()` allowing users to specify custom Typst template files instead of using the packaged BFH template.

## Improvements

* Added comprehensive unit tests for path escaping, version checking, and metadata propagation
* Improved error messages for Quarto version requirements

---

# BFHcharts 0.3.0

## Breaking Changes

* **Return type changed:** `bfh_qic()` now returns a `bfh_qic_result` S3 object instead of a ggplot object
  - **Rationale:** Enables pipe-compatible export workflows (`bfh_qic() |> bfh_export_pdf()`) and preserves SPC statistics for PDF metadata
  - **Migration:** Access plot with `result$plot` - see Migration Guide below
  - Print method maintains backwards-compatible console display (plot still shows when printing result)

* **Deprecated parameter:** `print.summary` parameter is deprecated
  - Summary is now always included in `bfh_qic_result$summary`
  - Using `print.summary = TRUE` will trigger a deprecation warning but still works (legacy behavior)
  - This parameter will be removed in a future version

## New Features

### Export Functionality

* **PNG Export:** `bfh_export_png()` - Export charts to PNG with configurable dimensions
  - MM-based dimensions (Danish/European standard)
  - Configurable DPI resolution (96-600)
  - Pipe-compatible workflow
  - Title rendered in PNG image

* **PDF Export:** `bfh_export_pdf()` - Export charts to PDF via Typst templates
  - Hospital-branded PDF reports with BFH styling
  - SPC statistics table (runs, crossings, outliers)
  - Customizable metadata (department, analysis, data definition)
  - Title in PDF template (not in chart image)
  - **Requires:** Quarto CLI (>= 1.4.0)

* **Low-level Functions:**
  - `bfh_create_typst_document()` - Generate Typst documents
  - `bfh_compile_typst()` - Compile Typst to PDF
  - `quarto_available()` - Check Quarto CLI availability

### S3 Class System

* **New S3 class:** `bfh_qic_result`
  - Components: `$plot`, `$summary`, `$qic_data`, `$config`
  - Print method: Displays plot for backwards compatibility
  - Plot method: Extracts and displays ggplot
  - Helper functions: `is_bfh_qic_result()`, `get_plot()`

### Typst Templates

* **Hospital branding templates** included in `inst/templates/typst/`
  - BFH-diagram2 template for A4 landscape reports
  - Mari and Arial fonts bundled
  - Hospital logos and branding assets

## Migration Guide (0.2.0 → 0.3.0)

### Basic Usage (Plot Display)

If you only display plots in console/viewer, no changes needed:

```r
# Works exactly the same in 0.3.0
bfh_qic(data, x = date, y = value, chart_type = "i")
```

### Accessing the ggplot Object

If you need to customize the plot with ggplot2 layers:

```r
# Before (0.2.0):
plot <- bfh_qic(data, x = date, y = value, chart_type = "i")
plot + labs(caption = "Source: EPJ")

# After (0.3.0):
result <- bfh_qic(data, x = date, y = value, chart_type = "i")
result$plot + labs(caption = "Source: EPJ")
```

### Getting Summary Statistics

```r
# Before (0.2.0):
result <- bfh_qic(data, x, y, chart_type = "i", print.summary = TRUE)
summary_stats <- result$summary

# After (0.3.0) - Recommended:
result <- bfh_qic(data, x, y, chart_type = "i")
summary_stats <- result$summary  # Always available

# After (0.3.0) - Legacy (with deprecation warning):
result <- bfh_qic(data, x, y, chart_type = "i", print.summary = TRUE)
summary_stats <- result$summary  # Still works but warns
```

### Using return.data Parameter

```r
# Backwards compatible - no changes needed
qic_data <- bfh_qic(data, x, y, chart_type = "i", return.data = TRUE)
```

### New Export Workflows

```r
# PNG export
bfh_qic(data, x, y, chart_type = "i", chart_title = "Infections") |>
  bfh_export_png("infections.png", width_mm = 200, height_mm = 120, dpi = 300)

# PDF export (requires Quarto CLI)
bfh_qic(data, x, y, chart_type = "i", chart_title = "Infections") |>
  bfh_export_pdf(
    "infections_report.pdf",
    metadata = list(
      hospital = "BFH",
      department = "Kvalitetsafdeling",
      analysis = "Signifikant fald observeret",
      data_definition = "Antal infektioner per måned"
    )
  )
```

## System Requirements

* **New dependency:** Quarto CLI (>= 1.4.0) for PDF export
  - Install from: https://quarto.org
  - Only required for PDF export; PNG export works without Quarto
  - Check availability with `BFHcharts::quarto_available()`

## Documentation

* Added comprehensive README examples for export workflows
* Added Typst template documentation in `inst/templates/typst/README.md`
* Updated function documentation for new S3 class

---

# BFHcharts 0.2.0

## Breaking Changes

* **Function renamed:** `create_spc_chart()` has been renamed to `bfh_qic()`
  - **Rationale:** Shorter, more memorable name (7 vs 17 characters) with clear BFH branding and connection to qicharts2
  - **Migration:** Simple find-and-replace - function signature is unchanged (drop-in replacement)
  - All parameters, defaults, and behavior remain identical

## Migration Guide

Update your code by replacing `create_spc_chart` with `bfh_qic`:

```r
# Before (0.1.0):
plot <- create_spc_chart(
  data = my_data,
  x = date,
  y = value,
  chart_type = "i"
)

# After (0.2.0):
plot <- bfh_qic(
  data = my_data,
  x = date,
  y = value,
  chart_type = "i"
)
```

No other changes required - all parameters work exactly the same.

# BFHcharts 0.1.0

* Initial release
* SPC chart visualization with BFH branding
* Support for multiple chart types (run, i, p, c, u, etc.)
* Intelligent label placement system
* Responsive typography
