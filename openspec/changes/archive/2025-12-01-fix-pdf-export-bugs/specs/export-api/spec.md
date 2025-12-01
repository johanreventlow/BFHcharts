# Export API Specification (Delta)

## MODIFIED Requirements

### Requirement: Typst Path Escaping

File paths passed to Typst templates MUST be escaped and normalized to use forward slashes. The system SHALL apply `normalizePath(..., winslash = "/")` and escape special characters before emitting `#import` statements and `image()` calls. This ensures cross-platform compatibility, especially on Windows.

#### Scenario: PDF export with spaces in path

**Given** user calls `bfh_export_pdf()` with output path "/tmp/my charts/report.pdf"
**When** the system generates the Typst document
**Then** the image path in the Typst file MUST use forward slashes
**And** special characters MUST be escaped for Typst string literals

#### Scenario: PDF export on Windows

**Given** user runs on Windows with path "C:\Users\Name\Documents\chart.pdf"
**When** the system generates the Typst document
**Then** backslashes MUST be converted to forward slashes
**And** the path MUST NOT produce invalid Typst escape sequences

---

### Requirement: Date Metadata Propagation

The export system MUST forward `metadata$date` to the Typst template. When the user provides a date, that value SHALL appear in the generated PDF. When not provided, the system MUST default to `Sys.Date()` and pass that value to the template.

#### Scenario: User provides custom date

**Given** user calls `bfh_export_pdf()` with `metadata = list(date = as.Date("2025-01-15"))`
**When** the PDF is generated
**Then** the PDF MUST display "2025-01-15" (or localized format)
**And** the template MUST NOT use `datetime.today()`

#### Scenario: Default date behavior

**Given** user calls `bfh_export_pdf()` without specifying date
**When** the PDF is generated
**Then** the PDF MUST display today's date from R (`Sys.Date()`)
**And** the date MUST be passed explicitly to the template

---

### Requirement: Quarto Version Enforcement

The `quarto_available()` function MUST verify that Quarto version is ≥1.4.0. If the version requirement is not met, the function SHALL return FALSE and provide a clear error message. The system MUST NOT proceed to compilation with unsupported Quarto versions.

#### Scenario: Quarto version too old

**Given** user has Quarto 1.3.x installed
**When** user calls `bfh_export_pdf()`
**Then** the function MUST stop with error message
**And** the error MUST indicate minimum version requirement (1.4.0)
**And** the error MUST suggest updating Quarto

#### Scenario: Quarto version check success

**Given** user has Quarto 1.4.0 or newer installed
**When** `quarto_available()` is called
**Then** the function MUST return TRUE
**And** PDF export MUST proceed normally

---

## ADDED Requirements

### Requirement: Custom Template Path

The `bfh_export_pdf()` function SHOULD support an optional `template_path` parameter to specify a custom Typst template file. When provided, the system MUST use that template instead of the packaged default. The system SHALL validate that the custom template file exists before proceeding.

#### Scenario: User provides custom template

**Given** user creates custom template at "/path/to/my-template.typ"
**And** user calls `bfh_export_pdf(..., template_path = "/path/to/my-template.typ")`
**When** PDF generation runs
**Then** the system MUST use the user's template
**And** the packaged template MUST NOT be used

#### Scenario: Custom template file not found

**Given** user provides non-existent template path
**When** `bfh_export_pdf()` is called
**Then** the function MUST stop with clear error message
**And** the error MUST indicate the missing file path

---

### Requirement: PDF Export Test Coverage

The test suite MUST include tests that verify metadata propagation and path escaping. Tests SHALL validate that user-supplied metadata appears in generated outputs and that path handling works across platforms.

#### Scenario: Test validates date propagation

**Given** test creates PDF with custom date metadata
**When** PDF is generated
**Then** test MUST verify the date value was passed to the template
**And** test MUST NOT only check file existence

#### Scenario: Test validates path escaping

**Given** test uses paths with spaces or special characters
**When** Typst document is generated
**Then** test MUST verify paths are properly escaped
**And** test MUST verify no invalid escape sequences are present
