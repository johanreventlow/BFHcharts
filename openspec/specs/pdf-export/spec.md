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

### Requirement: Typst template SHALL render conditionally on logo presence

The `bfh-diagram` Typst template SHALL accept a `logo_path` parameter
(default `none`) and SHALL render the foreground hospital logo only
when `logo_path` is supplied with a non-`none` value.

**Rationale:**
- Mirrors the font-fallback graceful-degradation contract: branding
  assets injected by companion packages take precedence; absence of
  assets does not block PDF rendering.
- `bfh_export_pdf()` succeeds out-of-the-box on a clean install
  without requiring `inject_assets` callback or
  `BFHchartsAssets` companion package.
- Layout calibration of header bar + title block is unchanged
  (foreground `place()` slot uses fixed offsets, not relative-to-image
  positioning).

#### Scenario: PDF compiles without logo when no companion assets present

- **GIVEN** a clean BFHcharts install without `BFHchartsAssets`
  companion package
- **AND** no `metadata$logo_path` is supplied
- **AND** no `inject_assets` callback creates `images/` subdirectory
- **WHEN** `bfh_export_pdf(result, "out.pdf")` is called
- **THEN** the Typst compile SHALL succeed (no file-not-found error)
- **AND** the PDF SHALL render with the calibrated header bar + title
- **AND** the foreground logo slot SHALL be empty (no broken-image
  marker)

```r
result <- bfh_qic(test_data, x = month, y = value, chart_type = "i")
bfh_export_pdf(result, "out.pdf")
# PDF compiles successfully; no logo visible
```

#### Scenario: PDF renders with logo when companion injects asset

- **GIVEN** an `inject_assets` callback that writes
  `<staged-template>/images/Hospital_Maerke_RGB_A1_str.png`
- **AND** no explicit `metadata$logo_path` is supplied
- **WHEN** `bfh_export_pdf(result, "out.pdf", inject_assets = MyAssets::inject_logo)`
  is called
- **THEN** R-side auto-detect SHALL discover the staged logo file
- **AND** R-side SHALL populate `metadata$logo_path` automatically
- **AND** the PDF SHALL render with the hospital logo at the
  calibrated foreground position

```r
result <- bfh_qic(test_data, x = month, y = value, chart_type = "i")
bfh_export_pdf(result, "out.pdf",
               inject_assets = BFHchartsAssets::inject_bfh_assets)
# PDF compiles with hospital logo embedded
```

#### Scenario: PDF renders with explicit logo_path

- **GIVEN** a caller-supplied logo path via metadata
- **WHEN** `bfh_export_pdf(result, "out.pdf", metadata = list(logo_path = "/abs/path/logo.png"))`
  is called
- **THEN** the PDF SHALL render with the supplied image
- **AND** the explicit `logo_path` SHALL override any auto-detected
  staged logo

#### Scenario: Invalid logo_path surfaces clear error

- **GIVEN** a `metadata$logo_path` pointing to a non-existent file
- **WHEN** `bfh_export_pdf(result, "out.pdf", metadata = list(logo_path = "/no/such/file.png"))`
  is called
- **THEN** the Typst compile SHALL fail with the underlying
  file-not-found error surfaced to the caller via the existing
  `bfh_compile_typst()` error reporting
- **AND** the error message SHALL contain enough information to
  identify the missing path

### Requirement: R wrapper SHALL auto-detect packaged logo

`bfh_compile_typst()` and `compose_typst_document()` SHALL include a helper
`.detect_packaged_logo()` that mirrors the existing `.detect_packaged_fonts()`
semantics.

When `metadata$logo_path` is not supplied AND
`<staged-template>/images/Hospital_Maerke_RGB_A1_str.png` exists, the
wrapper SHALL populate `metadata$logo_path` automatically before
emitting the Typst document.

When `metadata$logo_path` IS supplied (non-NULL), the wrapper SHALL
NOT override it (explicit takes precedence over auto-detect).

**Rationale:** Symmetric with `--font-path` auto-detect for fonts.
Companion-package callbacks that write the image file at the standard
staged path get logo rendering "for free" without requiring callers to
thread `logo_path` through their code.

The detected path SHALL be returned RELATIVE TO THE TEMPLATE FILE
(`images/Hospital_Maerke_RGB_A1_str.png`), not relative to the calling
document, because Typst resolves `#image()` calls relative to the .typ
file that contains the call -- the template file, not the calling
document. A path relative to the calling document would double-prefix
at compile time and produce a file-not-found error.

#### Scenario: Auto-detect populates logo_path when staged image exists

- **GIVEN** a staged template directory containing
  `images/Hospital_Maerke_RGB_A1_str.png`
- **AND** `metadata$logo_path` is not supplied (NULL)
- **WHEN** `compose_typst_document()` is invoked for the packaged template
- **THEN** `metadata$logo_path` SHALL be populated with
  `"images/Hospital_Maerke_RGB_A1_str.png"` (relative to the template file)
- **AND** the rendered PDF SHALL include the hospital logo

#### Scenario: Explicit logo_path takes precedence over auto-detect

- **GIVEN** a staged template directory containing
  `images/Hospital_Maerke_RGB_A1_str.png`
- **AND** the caller supplies `metadata$logo_path = "/custom/path/logo.png"`
- **WHEN** `compose_typst_document()` is invoked
- **THEN** `metadata$logo_path` SHALL remain `"/custom/path/logo.png"`
- **AND** auto-detect SHALL NOT override the caller-supplied value

#### Scenario: Auto-detect skips when staged image is absent

- **GIVEN** a staged template directory WITHOUT
  `images/Hospital_Maerke_RGB_A1_str.png`
- **AND** `metadata$logo_path` is not supplied (NULL)
- **WHEN** `compose_typst_document()` is invoked
- **THEN** `metadata$logo_path` SHALL remain NULL
- **AND** the Typst template SHALL render the conditional foreground
  block as no-logo (template default `logo_path: none`)
- **AND** the PDF SHALL compile successfully without a hospital-logo asset

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
- Paths where any path-separator-delimited component equals exactly `..` (path traversal)
- Shell metacharacters: `;`, `|`, `&`, backtick, `$`, `(`, `)`, `{`, `}`, `<`, `>`, newline, carriage return
- Extensions not in the format-specific whitelist
- Symlinks that resolve outside the configured allowlist root (when root is configured)

**The helper SHALL NOT reject:**
- Filenames containing `..` as part of a longer string (e.g., `report..v2.pdf`, `..hidden.pdf`, `analyse..final.pdf`) — these are legitimate filename patterns
- Paths with spaces, underscores, dashes, or unicode characters (already accepted)

**The helper SHALL return:**
- A normalized absolute path on success (when `normalize = TRUE`)
- An informative error (with class `bfhcharts_path_policy_error`) on rejection

#### Scenario: Path traversal rejected at component level

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

#### Scenario: Embedded subdirectory traversal rejected

**Given** a user supplies `output/../secret.pdf`
**When** validation runs
**Then** the helper SHALL reject the path

```r
expect_error(
  bfh_export_pdf(result, "output/../secret.pdf"),
  "path|traversal"
)
```

#### Scenario: Filenames containing double-dot substring accepted

**Given** a user supplies `report..v2.pdf` (component is the whole filename, not `..`)
**When** validation runs
**Then** the helper SHALL accept the path
**And** export SHALL proceed normally

```r
expect_no_error(
  bfh_export_pdf(result, file.path(tempdir(), "report..v2.pdf"))
)
```

#### Scenario: Dotfile prefix accepted

**Given** a user supplies `..hidden.pdf` as filename (single component, not traversal)
**When** validation runs
**Then** the helper SHALL accept the path

```r
expect_no_error(
  bfh_export_pdf(result, file.path(tempdir(), "..hidden.pdf"))
)
```

#### Scenario: Shell metacharacters rejected

**Given** a user supplies a path containing shell metacharacters
**When** validation runs
**Then** the helper SHALL reject the path regardless of file extension

```r
expect_error(
  bfh_export_pdf(result, "output;rm -rf /.pdf"),
  "invalid|character|disallowed"
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
**When** validation succeeds with normalize = TRUE
**Then** the helper SHALL return an absolute, normalized path

```r
normalized <- validate_export_path("./out/./chart.pdf", extension = "pdf", normalize = TRUE)
expect_true(startsWith(normalized, "/"))
expect_false(grepl("/./", normalized, fixed = TRUE))
```

#### Scenario: Cross-platform separator handling

**Given** a Windows-style path `..\\evil.pdf`
**When** validation runs
**Then** the helper SHALL recognize `..` as a path component
**And** SHALL reject the path

### Requirement: Markdown SHALL be converted to Typst via AST-based parser

The package SHALL convert user-supplied markdown text to Typst markup via an AST-based parser (built on `commonmark`), not via regex substitution.

**Rationale:**
- Regex-based conversion is fragile against Typst-markup injection
- AST parsing yields deterministic, testable node-mapping
- All Typst special characters must be escaped in text nodes

**Escaped characters in text nodes:** `#`, `$`, `@`, `[`, `]`, `<`, `>`, `` ` ``, `\`

#### Scenario: Injection attempt is neutralized

**Given** user-supplied text contains `#import "x": *`
**When** `markdown_to_typst()` converts the text
**Then** the resulting Typst text SHALL escape `#` so `#import` renders as literal text
**And** the Typst compiler SHALL NOT execute the import directive

```r
input <- "Analyse: #import \"evil\": *"
output <- markdown_to_typst(input)
expect_false(grepl("^#import", output))
expect_match(output, "\\\\#import", fixed = FALSE)
```

#### Scenario: Canonical markdown renders correctly

**Given** well-formed markdown with emphasis, bold, code, and lists
**When** `markdown_to_typst()` is called
**Then** output SHALL preserve semantic structure as Typst markup

```r
input <- "**Bold** and *emphasis* with `code` and\n\n- item 1\n- item 2"
output <- markdown_to_typst(input)
expect_match(output, "\\*Bold\\*")
expect_match(output, "_emphasis_")
```

#### Scenario: Unicode and Danish characters pass through

**Given** markdown containing Danish characters (æ, ø, å, Æ, Ø, Å)
**When** parsed
**Then** characters SHALL appear verbatim in Typst output without mojibake

```r
input <- "Gennemsnittet er på nåleøjet"
output <- markdown_to_typst(input)
expect_match(output, "nåleøjet", fixed = TRUE)
```

### Requirement: Batch export SHALL support Typst template asset reuse

The package SHALL provide an opt-in batch-session mechanism that reuses the
Typst template directory across multiple PDF exports, avoiding repeated
recursive directory copy.

**Rationale:**
- Recursive asset copy per export is the dominant I/O cost for batch workflows
- Healthcare reports often require hundreds of exports (per-department)
- Repeated copy grows linearly with export count

**Session lifecycle:**
- `bfh_create_export_session()` creates one template-populated tmpdir + handle
- Passing handle as `batch_session` to `bfh_export_pdf()` reuses assets
- Closing the session (or `on.exit`) removes the tmpdir

#### Scenario: Batch session reuses template directory

**Given** a batch export session
**When** `bfh_export_pdf()` is called 10 times with the same `batch_session`
**Then** the Typst template directory SHALL be copied exactly once
**And** 10 PDFs SHALL be produced

```r
session <- bfh_create_export_session()
on.exit(close(session))
for (dept in departments) {
  bfh_export_pdf(results[[dept]], paste0(dept, ".pdf"),
                 batch_session = session)
}
# Template tmpdir populated once; ten PDFs generated
```

#### Scenario: Single export without session preserves legacy behavior

**Given** `bfh_export_pdf()` is called without `batch_session`
**When** export runs
**Then** the function SHALL copy the template, export, and tear down tmpdir
**And** behavior SHALL be identical to the pre-change implementation

#### Scenario: Session close cleans up tmpdir

**Given** an open batch session
**When** `close(session)` is called
**Then** the session tmpdir SHALL be removed
**And** subsequent use of the session SHALL raise an error

### Requirement: Temp directory protection SHALL rely on tempfile() + Sys.chmod(0700)

The temp directory created by `prepare_temp_workspace()` for PDF export SHALL be protected against other-user access by:

1. Use of `tempfile()` for path generation, which produces a path under per-user `tempdir()` (OS-isolated)
2. `Sys.chmod(temp_dir, mode = "0700", use_umask = FALSE)` to remove group/other read/write/execute permissions

The implementation SHALL NOT rely on `Sys.getenv("UID")`-based ownership validation, because `UID` is a shell-internal environment variable that is typically not exported to non-interactive R sessions (Rscript, RStudio Server, knitr, Shiny apps, GitHub Actions runners). Such checks evaluate as `integer(0)` or `NA_integer_` and silently skip without ever firing the protective error branch — providing misleading defense-in-depth without actual protection.

**Rationale:**

- `tempfile()` + `Sys.chmod(0700)` is the canonical and sufficient mechanism in R for per-user temp directory isolation
- Adding an unreliable check creates a false sense of security and increases maintenance burden
- This requirement aligns `prepare_temp_workspace()` with the simpler implementation already in `bfh_create_export_session()` (which uses only `Sys.chmod(0700)`)

#### Scenario: Temp directory has 0700 mode on Unix

- **GIVEN** `prepare_temp_workspace(NULL)` is called on a Unix system
- **WHEN** the function returns
- **THEN** `file.info(temp_dir)$mode` SHALL have permission bits `0700`
- **AND** group/other SHALL have no read/write/execute permission

```r
test_that("prepare_temp_workspace creates 0700 directory on Unix", {
  skip_on_os(c("windows"))
  ws <- prepare_temp_workspace(NULL)
  on.exit(unlink(ws$temp_dir, recursive = TRUE))
  mode_octal <- as.integer(file.info(ws$temp_dir)$mode) %% (8^3)
  expect_equal(mode_octal, strtoi("700", 8L))
})
```

#### Scenario: Temp directory path is under tempdir()

- **GIVEN** `prepare_temp_workspace(NULL)` is called
- **WHEN** the function returns
- **THEN** `temp_dir` SHALL start with `tempdir()` (per-user isolated parent)

```r
test_that("temp_dir is under tempdir()", {
  ws <- prepare_temp_workspace(NULL)
  on.exit(unlink(ws$temp_dir, recursive = TRUE))
  expect_true(startsWith(
    normalizePath(ws$temp_dir, mustWork = FALSE),
    normalizePath(tempdir(), mustWork = TRUE)
  ))
})
```

#### Scenario: Implementation does not rely on Sys.getenv("UID")

- **GIVEN** the source of `R/utils_export_helpers.R`
- **WHEN** the file is read
- **THEN** the implementation SHALL NOT contain `Sys.getenv("UID")` calls or UID-based ownership comparisons in `prepare_temp_workspace()` or any related helper
- **AND** any prior ownership-check code SHALL be replaced with an inline comment documenting why `tempfile()` + `Sys.chmod(0700)` is sufficient

```r
# Verification (regression test):
test_that("prepare_temp_workspace does not use Sys.getenv UID check", {
  src_path <- system.file("R", "utils_export_helpers.R", package = "BFHcharts")
  if (nchar(src_path) == 0) skip("source not installed")
  src <- readLines(src_path)
  expect_false(any(grepl('Sys.getenv\\("UID"\\)', src)))
})
```

### Requirement: Organizational asset distribution SHALL use companion package pattern

For organizations that need to bundle proprietary fonts and branding assets (logos, hospital identifiers) with BFHcharts-based deployments, the asset distribution SHALL use a private companion R package pattern. BFHcharts itself SHALL NOT bundle proprietary assets, and consumer applications SHALL NOT hardcode absolute paths to assets in `inject_assets` callbacks. The companion package SHALL:

1. Hosts the proprietary assets in `inst/assets/fonts/` and `inst/assets/images/`
2. Exports a single function (e.g. `inject_bfh_assets(template_dir)`) that copies all bundled assets into a Typst template staging directory
3. Is installed as a private dependency by the consumer application (e.g. biSPCharts on Posit Connect Cloud)
4. Plugs into BFHcharts via the existing `inject_assets` callback parameter on `bfh_export_pdf()` and `bfh_create_export_session()`

**Rationale:**

- BFHcharts itself is GPL-3 and publicly distributed; it cannot bundle proprietary fonts (Mari, Arial) or third-party-owned hospital logos
- The `inject_assets` callback was designed precisely for this asset-runtime-injection pattern but lacked an officially recommended distribution mechanism
- A companion package gives organizations versioned, audit-trackable, dependency-managed asset distribution that integrates cleanly with R's package ecosystem (renv, manifest.json on Posit Connect)
- Compared to ad-hoc deploy-bundle staging, companion packages provide: source-of-truth versioning, reusability across multiple consumer applications, and clean separation of GPL-distributable code from proprietary brand assets

**Anti-patterns this requirement formalizes against:**

- Hardcoded absolute paths in `inject_assets` callbacks (breaks on cloud deployments)
- Manual asset staging in deploy bundles via `.gitignore` + pre-deploy copy scripts (no audit trail; easily forgotten)
- Direct commit of proprietary fonts/logos into BFHcharts (license violations) or into consumer application repos that are public (same violations)

#### Scenario: Companion package exposes single inject_assets-compatible function

- **GIVEN** a private companion package (e.g. `BFHchartsAssets`)
- **WHEN** the package is installed
- **THEN** it SHALL export a function with signature `function(template_dir)` that:
  - Validates `template_dir` is a single character path to an existing directory
  - Copies all bundled fonts from `system.file("assets/fonts", package = "<pkg>")` to `<template_dir>/fonts/`
  - Copies all bundled images from `system.file("assets/images", package = "<pkg>")` to `<template_dir>/images/`
  - Creates `fonts/` and `images/` subdirectories if they do not exist
  - Errors clearly if any file copy fails

```r
# Reference implementation
inject_bfh_assets <- function(template_dir) {
  stopifnot(is.character(template_dir), length(template_dir) == 1, dir.exists(template_dir))

  fonts_src  <- system.file("assets/fonts",  package = "BFHchartsAssets", mustWork = TRUE)
  images_src <- system.file("assets/images", package = "BFHchartsAssets", mustWork = TRUE)

  fonts_dst  <- file.path(template_dir, "fonts")
  images_dst <- file.path(template_dir, "images")
  dir.create(fonts_dst,  showWarnings = FALSE, recursive = TRUE)
  dir.create(images_dst, showWarnings = FALSE, recursive = TRUE)

  fonts_ok  <- all(file.copy(list.files(fonts_src,  full.names = TRUE), fonts_dst,  overwrite = TRUE))
  images_ok <- all(file.copy(list.files(images_src, full.names = TRUE), images_dst, overwrite = TRUE))

  if (!fonts_ok || !images_ok) {
    stop("Failed to inject one or more asset files", call. = FALSE)
  }

  invisible(NULL)
}
```

#### Scenario: Consumer integrates companion via inject_assets parameter

- **GIVEN** a consumer Shiny app (biSPCharts) deployed to Posit Connect Cloud
- **AND** the consumer has `BFHchartsAssets` in its `Imports` and `Remotes`
- **WHEN** the consumer calls `BFHcharts::bfh_export_pdf(..., inject_assets = BFHchartsAssets::inject_bfh_assets)`
- **THEN** the rendered PDF SHALL display full hospital branding with Mari fonts and Region Hovedstaden logos
- **AND** BFHcharts itself SHALL NOT have any code that references `BFHchartsAssets` (clean dependency direction: consumer → BFHcharts; consumer → BFHchartsAssets)

```r
# Consumer code pattern (biSPCharts):
result <- BFHcharts::bfh_qic(data, x = month, y = infections, chart_type = "i")
BFHcharts::bfh_export_pdf(
  result, output_pdf,
  metadata = list(hospital = "Bispebjerg og Frederiksberg Hospital", department = dept),
  inject_assets = BFHchartsAssets::inject_bfh_assets
)
```

#### Scenario: BFHcharts documentation references companion pattern as canonical

- **GIVEN** a user reads `?bfh_export_pdf` or `README.md`
- **WHEN** the user reaches the security/branding section
- **THEN** the documentation SHALL describe the companion-package pattern as the recommended approach for organizations needing proprietary branding
- **AND** SHALL explicitly state that BFHcharts does not bundle Mari fonts or hospital logos

#### Scenario: Companion package is independent of BFHcharts release cadence

- **GIVEN** the companion package and BFHcharts are versioned independently
- **WHEN** BFHcharts releases a patch version
- **THEN** the companion package SHALL NOT need to be re-released unless the `inject_assets`-callback contract changes
- **AND** the companion package's `DESCRIPTION` SHALL specify `BFHcharts (>= <minimum-version>)` to assert the callback contract version it supports

This decoupling allows BFHcharts to evolve its public API freely while organizations control their branding-asset release cadence separately.

### Requirement: Batch session SHALL use per-export unique intermediate filenames

The package SHALL generate per-export unique filenames for intermediate artifacts (`chart.svg`, `document.typ`) within a shared `batch_session` tmpdir to eliminate filename collisions between exports and to make race conditions impossible by construction.

**Rationale:**
- Fixed filenames create a guaranteed collision if any caller violates the documented sequential-only contract (e.g., calling from `future_lapply()`)
- Even sequential semantics benefit: a crashed export leaves orphan files only for its own filenames, preventing pollution of subsequent exports
- Unique names cost only one `tempfile()` call per export — negligible overhead

**Filename pattern:**
```r
chart_svg <- tempfile(pattern = "chart-", tmpdir = temp_dir, fileext = ".svg")
typst_file <- tempfile(pattern = "document-", tmpdir = temp_dir, fileext = ".typ")
```

The Typst document SHALL reference the chart by relative basename (already the case in `build_typst_content()`), so unique filenames cause no document-content changes.

#### Scenario: sequential batch produces unique intermediates per export

- **GIVEN** a batch session and 10 sequential `bfh_export_pdf()` calls
- **WHEN** all calls complete
- **THEN** no two intermediate filenames SHALL have collided
- **AND** all 10 final PDFs SHALL be valid

```r
session <- bfh_create_export_session()
on.exit(close(session))
for (i in 1:10) {
  out <- tempfile(fileext = ".pdf")
  bfh_export_pdf(result, out, batch_session = session)
  expect_true(file.exists(out))
}
```

#### Scenario: crash mid-export leaves only its own intermediates

- **GIVEN** an export that crashes after writing `chart-XYZ.svg` but before completing
- **WHEN** the next export runs in the same session
- **THEN** the next export SHALL use a different chart filename (`chart-ABC.svg`)
- **AND** the crashed export's orphan SHALL be removable independently

#### Scenario: parallel batch isolation by construction

- **GIVEN** two `bfh_export_pdf()` calls run concurrently against the same session (violating documented contract)
- **WHEN** both write intermediates
- **THEN** unique filenames SHALL prevent overwrite
- **AND** both PDFs SHALL be valid OR fail with clear error (not silently corrupted)

> Note: Parallel use is still not officially supported. This requirement removes a class of failure modes but does not promote parallel as a recommended pattern.

### Requirement: Batch session SHALL register a finalizer for orphan tmpdir cleanup

`bfh_create_export_session()` SHALL register a finalizer on the returned session object that calls `close()` if the user drops the reference without explicitly closing.

**Rationale:**
- R has no implicit RAII; users frequently forget `close()` in dashboards or scripts
- Without finalizer, abandoned sessions leave tmpdirs until R session ends
- Finalizer is a backup, not a substitute for `close()` — explicit cleanup is still preferred

#### Scenario: dropped session reference triggers cleanup on GC

- **GIVEN** a session created and reference dropped without `close()`
- **WHEN** garbage collection runs
- **THEN** the session tmpdir SHALL be removed
- **AND** no error SHALL be raised even if `close()` was never called

```r
local({
  session <- bfh_create_export_session()
  tmpdir_path <- session$tmpdir
  rm(session)
  gc()
  expect_false(dir.exists(tmpdir_path))
})
```


### Requirement: `restrict_template` SHALL default to TRUE

`bfh_export_pdf(restrict_template)` SHALL default to `TRUE`. Callers
needing custom Typst templates via `template_path` SHALL explicitly
opt-in by passing `restrict_template = FALSE`.

**Rationale:**
- Custom Typst templates are compiled by the Typst binary with full
  filesystem and network access (equivalent to `source()`).
- A configuration pipeline forwarding user-controlled input to
  `template_path` (e.g. Shiny `input$template`, REST API parameter)
  produces a silent privilege-escalation vector.
- Default-safe matches the established pattern for `inject_assets`
  (which already requires explicit namespace-trusted callbacks).
- Pre-1.0 (0.15.x -> 0.16.0) breaking change is permitted per
  `VERSIONING_POLICY.md` §A; migration is mechanical (one parameter
  add).

#### Scenario: Default rejects template_path without explicit opt-out

- **GIVEN** a `bfh_qic_result` and a custom Typst template path
- **WHEN** `bfh_export_pdf(result, "out.pdf", template_path = "/my/template.typ")`
  is called WITHOUT `restrict_template`
- **THEN** the function SHALL raise an informative error mentioning
  `restrict_template = FALSE` as the explicit opt-out
- **AND** no PDF SHALL be created
- **AND** no Typst compile process SHALL be spawned

```r
expect_error(
  bfh_export_pdf(result, "out.pdf", template_path = "/my/template.typ"),
  "restrict_template"
)
```

#### Scenario: Explicit opt-out allows custom template

- **GIVEN** a `bfh_qic_result` and a custom Typst template path
- **WHEN** `bfh_export_pdf(result, "out.pdf",
  template_path = "/my/template.typ", restrict_template = FALSE)` is called
- **THEN** the function SHALL accept the custom template
- **AND** the PDF SHALL render using the supplied template

```r
expect_no_error(
  bfh_export_pdf(result, "out.pdf",
                 template_path = "/path/to/valid/template.typ",
                 restrict_template = FALSE)
)
```

#### Scenario: Default packaged template unaffected

- **GIVEN** a `bfh_qic_result` and no `template_path`
- **WHEN** `bfh_export_pdf(result, "out.pdf")` is called (default)
- **THEN** the packaged BFH template SHALL render normally
- **AND** the new `restrict_template = TRUE` default SHALL have no
  effect (no `template_path` to restrict)

```r
expect_no_error(
  bfh_export_pdf(result, "out.pdf")
)
```

### Requirement: PDF SHALL render caveat when centerline is user-supplied

The rendered PDF SHALL display a caveat block below the SPC table when `attr(bfh_qic_result$summary, "cl_user_supplied") == TRUE`, indicating that the centerline was manually specified and Anhoej signals were computed against the user-supplied centerline rather than the data-estimated process mean.

**Rationale:**
- The R-side warning (at `R/bfh_qic.R:674-682`) surfaces to interactive
  users only; clinical PDF readers never see R warnings.
- Clinicians correctly assume the SPC table reflects data-driven
  analysis. Without the caveat, they may misattribute Anhoej signals
  as clinically meaningful when they are artifacts of an arbitrary
  user-set centerline.
- Caveat-text is i18n-able via `inst/i18n/*.yaml`. Default Danish:
  `"Centerlinje fastsat manuelt -- Anhoej-signal beregnet mod denne,
  ikke data-estimeret middelvaerdi"`. English when `language = "en"`:
  `"Centerline manually specified -- Anhoej signal computed against
  user-supplied centerline, not data-estimated process mean"`.
- The R-side warning is RETAINED -- the PDF caveat is the SECOND
  surface, not a replacement.

The caveat block SHALL be visually distinguished (italic, smaller font,
grey colour) to match existing data-definition styling and SHALL be
positioned directly below the SPC statistics table.

#### Scenario: PDF with user-supplied cl renders caveat

- **GIVEN** `result <- bfh_qic(data, x, y, chart_type = "i", cl = 50)`
- **WHEN** `bfh_export_pdf(result, "out.pdf")` is called
- **THEN** the rendered PDF SHALL contain caveat text matching the
  i18n key `cl_user_supplied_caveat`
- **AND** the caveat SHALL appear below the SPC statistics table
- **AND** in Danish when `language = "da"` (default)

```r
result <- bfh_qic(data, x, y, chart_type = "i", cl = 50)
out <- tempfile(fileext = ".pdf")
bfh_export_pdf(result, out)
text <- pdftools::pdf_text(out)
expect_match(paste(text, collapse = "\n"), "fastsat manuelt")
```

#### Scenario: PDF without user-supplied cl does NOT render caveat

- **GIVEN** `result <- bfh_qic(data, x, y, chart_type = "i")` (no `cl`)
- **WHEN** `bfh_export_pdf(result, "out.pdf")` is called
- **THEN** the rendered PDF SHALL NOT contain caveat text
- **AND** the SPC table footer SHALL render unchanged from prior
  versions

```r
result <- bfh_qic(data, x, y, chart_type = "i")
out <- tempfile(fileext = ".pdf")
bfh_export_pdf(result, out)
text <- pdftools::pdf_text(out)
expect_no_match(paste(text, collapse = "\n"), "fastsat manuelt")
```

#### Scenario: PDF caveat renders in English when language = "en"

- **GIVEN** `result <- bfh_qic(data, x, y, chart_type = "i", cl = 50, language = "en")`
- **WHEN** `bfh_export_pdf(result, "out.pdf")` is called
- **THEN** the rendered PDF SHALL contain English caveat text
  ("Centerline manually specified ...")
- **AND** SHALL NOT contain Danish caveat text

```r
result <- bfh_qic(data, x, y, chart_type = "i", cl = 50, language = "en")
out <- tempfile(fileext = ".pdf")
bfh_export_pdf(result, out)
text <- pdftools::pdf_text(out)
expect_match(paste(text, collapse = "\n"), "manually specified")
expect_no_match(paste(text, collapse = "\n"), "fastsat manuelt")
```
