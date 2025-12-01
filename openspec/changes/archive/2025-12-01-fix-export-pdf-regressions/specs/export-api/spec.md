# Specification: PDF Export API Fixes

**Parent:** [proposal.md](../../proposal.md)
**Status:** draft

## MODIFIED Requirements

### REQ-EXPORT-1: Chart Image Path Handling [MODIFIED]

**Priority:** High

`bfh_create_typst_document()` MUST accept chart images from any valid file path, copying them to the output directory before generating Typst content.

#### Scenario: Chart image from different directory

**Given** a chart image exists at `/path/a/chart.png`
**And** output directory is `/path/b/`
**When** `bfh_create_typst_document(chart_image = "/path/a/chart.png", output = "/path/b/doc.typ", ...)` is called
**Then** the chart image MUST be copied to `/path/b/chart.png`
**And** the generated Typst MUST reference `image("chart.png")` (relative path)
**And** the original chart image MUST NOT be modified

#### Scenario: Chart image copy failure

**Given** a chart image path that cannot be copied (e.g., permission denied)
**When** `bfh_create_typst_document()` is called
**Then** the function MUST stop with a clear error message including the source path

---

### REQ-EXPORT-2: Quarto Version Parsing [MODIFIED]

**Priority:** High

`check_quarto_version()` MUST correctly parse version strings in various formats returned by different Quarto installations.

#### Scenario: Version-only string

**Given** version string "1.4.557"
**When** `check_quarto_version("1.4.557", "1.4.0")` is called
**Then** it MUST return TRUE

#### Scenario: Prefixed version string

**Given** version string "Quarto 1.4.557"
**When** `check_quarto_version("Quarto 1.4.557", "1.4.0")` is called
**Then** it MUST return TRUE

#### Scenario: Version below minimum

**Given** version string "1.3.340" or "Quarto 1.3.340"
**When** `check_quarto_version(version, "1.4.0")` is called
**Then** it MUST return FALSE

#### Scenario: Two-part version

**Given** version string "1.4"
**When** `check_quarto_version("1.4", "1.4.0")` is called
**Then** it MUST return TRUE

---

### REQ-EXPORT-3: Template Path Validation [MODIFIED]

**Priority:** Medium

`bfh_export_pdf()` and `bfh_create_typst_document()` MUST validate custom template paths thoroughly before attempting to use them.

#### Scenario: Directory passed as template

**Given** `template_path` points to a directory (not a file)
**When** `bfh_export_pdf(..., template_path = "/some/directory")` is called
**Then** the function MUST stop with error message indicating "must be a file, not a directory"

#### Scenario: Non-.typ file passed as template

**Given** `template_path` points to a file without .typ extension
**When** `bfh_export_pdf(..., template_path = "/path/to/file.txt")` is called
**Then** the function MUST stop with error message indicating ".typ extension required"

#### Scenario: Template copy failure

**Given** a valid template file that cannot be copied to temp directory
**When** `bfh_create_typst_document()` attempts to copy it
**Then** the function MUST stop with clear error message including the template path

---

### REQ-EXPORT-4: Path Escaping for Custom Paths [MODIFIED]

**Priority:** Medium

All user-provided paths that appear in generated Typst content MUST be properly escaped using `escape_typst_path()`.

#### Scenario: Windows backslash path

**Given** a template path "C:\Users\Test\template.typ"
**When** the path is used in a Typst import statement
**Then** it MUST be escaped to "C:/Users/Test/template.typ"

#### Scenario: Path with quotes

**Given** a path containing quotes `/path/with "name"/file.typ`
**When** the path is used in Typst content
**Then** quotes MUST be escaped as `\"`

#### Scenario: Path with spaces

**Given** a path with spaces `/path/with spaces/file.typ`
**When** the path is used in Typst content
**Then** the path MUST work correctly (spaces are valid in Typst strings)

---

## ADDED Requirements

### REQ-EXPORT-5: Test Content Verification [NEW]

**Priority:** Low

Tests MUST verify that generated Typst content contains correct references and metadata, not just that files exist.

#### Scenario: Verify chart reference in Typst

**Given** a generated .typ file from `bfh_create_typst_document()`
**When** the file content is read
**Then** it MUST contain an `image("...")` reference to the chart

#### Scenario: Verify metadata in Typst

**Given** metadata with title="Test Title", hospital="Test Hospital", date="2025-01-15"
**When** `bfh_create_typst_document()` generates a .typ file
**Then** the content MUST contain "Test Title", "Test Hospital", and "2025-01-15"

#### Scenario: Verify template import

**Given** a generated .typ file
**When** the file content is read
**Then** it MUST contain `#import "bfh-template/bfh-template.typ"` or similar valid import

---

## Implementation Notes

See `tasks.md` for detailed implementation steps.
