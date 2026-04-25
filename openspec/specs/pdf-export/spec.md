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

### Requirement: Typst compilation SHALL support dependency-injected system2 and quarto path

`bfh_compile_typst()` SHALL accept internal dependency-injection parameters
`.system2` (default `base::system2`) and `.quarto_path` (default resolved via
`get_quarto_path()`) to enable isolated unit testing without requiring a real
Quarto installation.

**Rationale:**
- Tests must not depend on Quarto binary availability or version
- External process failures must be reproducible in unit tests
- Compile logic must be verifiable independent of system state

The DI parameters SHALL be marked `@keywords internal` and documented as
test-only hooks.

#### Scenario: Compile logic unit-tested with mocked system2

**Given** a Typst document and mocked `.system2`
**When** `bfh_compile_typst(doc, output, .system2 = mock_fn)` is called
**Then** `mock_fn` SHALL receive the constructed quarto arguments
**And** no real Quarto process SHALL be spawned

```r
captured <- NULL
mock_fn <- function(command, args, ...) {
  captured <<- list(command = command, args = args)
  0L  # success
}
bfh_compile_typst(doc, tmpfile, .system2 = mock_fn, .quarto_path = "/fake/quarto")
expect_equal(captured$command, "/fake/quarto")
expect_true(any(grepl("render", captured$args)))
```

#### Scenario: Quarto errors surface as informative R errors

**Given** mocked `.system2` returning non-zero exit code with stderr
**When** compile is called
**Then** the function SHALL raise an informative R error
**And** the error message SHALL reference the captured stderr content

```r
mock_fail <- function(...) {
  attr(result <- 1L, "errmsg") <- "compilation failed: syntax error"
  result
}
expect_error(
  bfh_compile_typst(doc, tmpfile, .system2 = mock_fail),
  "compilation failed"
)
```

### Requirement: Export paths SHALL be validated via centralized helper

All export entry points SHALL validate user-supplied output paths via a single canonical helper `validate_export_path()` in `R/utils_path_policy.R`, covering `bfh_export_pdf()`, `bfh_export_png()`, and internal Typst helpers.

**Rationale:**
- Single source of truth prevents policy drift between formats
- Consistent security posture across export surfaces
- Central place to tighten rules in response to future threats

**The helper SHALL reject:**
- Paths containing `..` segments (path traversal)
- Shell metacharacters: `;`, `|`, `&`, backtick, `$`, `(`, `)`, newline
- Extensions not in the format-specific whitelist
- Symlinks that resolve outside the configured allowlist root (when root is configured)

**The helper SHALL return:**
- A normalized absolute path on success
- An informative error (with class `bfhcharts_path_policy_error`) on rejection

#### Scenario: Path traversal rejected

**Given** a user supplies `../../etc/passwd` as output path
**When** any export function validates the path
**Then** it SHALL raise an error mentioning path traversal
**And** no file SHALL be written

```r
expect_error(
  bfh_export_pdf(result, "../../etc/passwd.pdf"),
  "path|traversal"
)
```

#### Scenario: Shell metacharacters rejected

**Given** a user supplies a path containing shell metacharacters
**When** validation runs
**Then** the helper SHALL reject the path regardless of file extension

```r
expect_error(
  bfh_export_pdf(result, "output;rm -rf /.pdf"),
  "invalid|character"
)
```

#### Scenario: Wrong extension for format rejected

**Given** a user calls `bfh_export_pdf()` with path `output.png`
**When** validation runs
**Then** the helper SHALL reject with message naming expected extension

```r
expect_error(
  bfh_export_pdf(result, "output.png"),
  "pdf"
)
```

#### Scenario: Valid path returned normalized

**Given** a legitimate path with `.` segments
**When** validation succeeds
**Then** the helper SHALL return an absolute, normalized path

```r
normalized <- validate_export_path("./out/./chart.pdf", extension = "pdf")
expect_true(startsWith(normalized, "/"))
expect_false(grepl("/./", normalized, fixed = TRUE))
```

