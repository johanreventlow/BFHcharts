# code-organization Specification

## Purpose
TBD - created by archiving change consolidate-formatting-utilities. Update Purpose after archive.
## Requirements
### Requirement: Time formatting SHALL have single canonical implementation

All time formatting in the package SHALL use a single canonical implementation in `R/utils_time_formatting.R`.

**Rationale:**
- Prevents code duplication
- Ensures consistent formatting across package
- Reduces maintenance burden
- Enables centralized testing

#### Scenario: Format time value in Danish

**Given** a time value in minutes
**When** `format_time_danish()` is called
**Then** the function SHALL return correctly formatted Danish time string
**And** the function SHALL select appropriate unit (sekunder, minutter, timer, dage)
**And** the function SHALL use Danish decimal formatting (comma as separator)

**Implementation:**
```r
#' Format Time Value in Danish
#'
#' Formats a time value with appropriate Danish unit and formatting.
#'
#' @param value_minutes Numeric time value in minutes
#' @param context Optional context for unit selection hints
#' @return Character string with formatted time and Danish unit
#' @export
#' @examples
#' format_time_danish(30)      # "30 min"
#' format_time_danish(90)      # "1,5 timer"
#' format_time_danish(1440)    # "1 dag"
format_time_danish <- function(value_minutes, context = NULL) {
  unit <- determine_time_unit(value_minutes, context)
  scaled_value <- scale_to_unit(value_minutes, unit)
  unit_label <- get_danish_time_label(unit)
  format_with_decimals(scaled_value, unit_label)
}
```

**Validation:**
- Single `format_time_danish()` function exists
- No other time formatting implementations in package
- All time formatting call sites use this function

#### Scenario: Legacy code migrated to canonical function

**Given** existing code that uses duplicate time formatting
**When** the consolidation is complete
**Then** all call sites SHALL use `format_time_danish()`
**And** no duplicate implementations SHALL remain

**Validation:**
- `grep -r "format_time" R/` returns only `utils_time_formatting.R`
- All tests pass after migration

### Requirement: Number formatting SHALL have single canonical implementation

All number formatting with K/M/mia notation SHALL use a single canonical implementation in `R/utils_number_formatting.R`.

**Rationale:**
- Consistent magnitude notation across package
- Danish-specific formatting (tusinde, millioner, milliarder)
- Single point of maintenance

#### Scenario: Format large number in Danish

**Given** a numeric value
**When** `format_count_danish()` is called
**Then** the function SHALL format with appropriate magnitude suffix
**And** the function SHALL use K for thousands
**And** the function SHALL use M for millions
**And** the function SHALL use mia for billions

**Implementation:**
```r
#' Format Count with Danish Magnitude Notation
#'
#' Formats numeric values with K/M/mia suffixes for readability.
#'
#' @param value Numeric value to format
#' @param use_big_mark Logical, whether to use thousand separator
#' @return Character string with formatted value
#' @export
#' @examples
#' format_count_danish(1500)         # "1,5K"
#' format_count_danish(1500000)      # "1,5M"
#' format_count_danish(1500000000)   # "1,5 mia"
format_count_danish <- function(value, use_big_mark = TRUE) {
  magnitude <- determine_magnitude(value)
  scaled <- value / magnitude$divisor
  paste0(format_decimal(scaled), magnitude$suffix)
}
```

**Validation:**
- Single `format_count_danish()` function exists
- No other K/M/mia implementations in package
- All number formatting call sites use this function

### Requirement: bfh_qic SHALL delegate distinct post-processing responsibilities to internal helpers

The implementation of `bfh_qic()` SHALL isolate data post-processing and
return-routing in dedicated internal helpers so the public entrypoint can
focus on orchestration.

**Rationale:**
- Keeps the package's main chart-construction API readable
- Makes legacy return behavior testable in isolation
- Reduces regression risk in Anhøj signal computation

#### Scenario: Anhøj signal post-processing has a canonical helper

**Given** a `qicharts2::qic()` result data frame
**When** BFHcharts needs to derive `anhoej.signal`
**Then** that logic SHALL live in a dedicated internal helper
**And** `bfh_qic()` SHALL call that helper instead of inlining the full
mutation block

#### Scenario: Return routing has a canonical helper

**Given** `bfh_qic()` has produced `plot`, `summary`, `qic_data`, and
`config`
**When** it must return output for combinations of `return.data` and
`print.summary`
**Then** the routing logic SHALL live in a dedicated internal helper
**And** the helper SHALL preserve the documented legacy return formats and
warnings

### Requirement: Internal config constructors SHALL fail loudly on invalid input

Internal configuration constructors (`spc_plot_config()`, `viewport_dims()`, and related builders in `R/config_objects.R`) SHALL raise informative errors on invalid input rather than silently coercing or emitting warnings and continuing.

**Rationale:**
- Silent coercion creates latent bugs surfaced far from the root cause
- Internal contracts should fail fast; user-facing APIs (`bfh_qic()`) wrap
  with documented graceful handling where appropriate

**Invalid input categories (SHALL error):**
- Wrong type (e.g. character where numeric required)
- NA, Inf, or negative numeric where a positive dimension is required
- Unknown option keys when the constructor has a fixed key set

#### Scenario: Wrong type raises error

**Given** `spc_plot_config()` expects numeric width
**When** called with `width = "big"`
**Then** it SHALL raise an error identifying the invalid parameter and its expected type

```r
expect_error(
  spc_plot_config(width = "big"),
  "width"
)
```

#### Scenario: Negative dimensions rejected

**Given** `viewport_dims()` expects positive dimensions
**When** called with `width_mm = -10`
**Then** it SHALL raise an error

```r
expect_error(
  viewport_dims(width_mm = -10, height_mm = 100),
  "positive"
)
```

#### Scenario: NULL uses documented default

**Given** a constructor with documented NULL-as-default behavior
**When** called with an argument set to `NULL`
**Then** it SHALL return the default value without error
**And** this SHALL be the only legitimate silent path

### Requirement: PDF export code SHALL be split by responsibility into dedicated modules

The PDF export implementation SHALL separate orchestration from reusable
utility APIs so that each module has a single primary responsibility.

**Rationale:**
- Reduces navigation and review cost in export-related code
- Makes public utility APIs discoverable outside the export pipeline
- Lowers regression risk when changing PDF orchestration versus shared helpers

#### Scenario: Shared utility APIs live outside export_pdf.R

**Given** the package source is inspected
**When** the implementations of `bfh_extract_spc_stats()` and
`bfh_merge_metadata()` are located
**Then** they SHALL live in dedicated `R/utils_*.R` files
**And** `R/export_pdf.R` SHALL NOT be the canonical implementation home for
those functions

#### Scenario: Details generation is isolated from PDF orchestration

**Given** the package source is inspected
**When** `bfh_generate_details()` and its helper formatting functions are
located
**Then** they SHALL live in a dedicated helper module separate from the main
PDF orchestration file

#### Scenario: Export pipeline calls canonical public utility names

**Given** `bfh_export_pdf()` needs SPC stats or merged metadata
**When** the orchestration code invokes those utilities
**Then** it SHALL call `bfh_extract_spc_stats()` and
`bfh_merge_metadata()` directly
**And** duplicate internal alias wrappers SHALL NOT remain

### Requirement: Internal infrastructure SHALL NOT carry unused scaffolding

The package SHALL NOT carry constructor functions, S3 methods, or function parameters that have no production call sites. Internal scaffolding for "future API" SHALL either be (a) wired into an active code path within one minor version, or (b) removed.

**Rationale:**
- Reserved-but-unused infrastructure carries maintenance and review weight without delivering value
- "Future API" tends to drift from current patterns and become incompatible by the time it would be used
- Easier to re-add when actually needed than to maintain dead code under test

**Examples of removed scaffolding:**
- `phase_config()` constructor + `print.phase_config()` method (was reserved, never wired)
- `bfh_spc_plot(phase = NULL)` parameter (read by no code path)

#### Scenario: dead constructor removed

- **GIVEN** an internal constructor function with zero production call sites (verified via grep)
- **WHEN** the next minor release is prepared
- **THEN** the constructor SHALL be either wired into a production code path OR removed entirely
- **AND** removal SHALL include constructor, related S3 methods, NAMESPACE entries, tests, and Rd files

#### Scenario: dead parameter removed from internal function

- **GIVEN** a function parameter that is accepted but never read in the function body
- **WHEN** the parameter is identified during refactor or review
- **THEN** the parameter SHALL be removed from the signature
- **AND** the removal SHALL be safe because the function is internal (not exported in NAMESPACE)

### Requirement: bfh_export_pdf SHALL follow the orchestrator-helper pattern

`bfh_export_pdf()` SHALL be refactored to act as a thin orchestrator delegating distinct responsibilities to internal helpers, mirroring the pattern established by `bfh_qic()` (see `refactor-bfh_qic-orchestrator` change). Function body SHOULD target ≤ 80 lines excluding Roxygen.

**Rationale:**
- Current 330-line implementation mixes validation, IO, security checks, plot manipulation, Typst generation, and Quarto execution
- Security check ordering is currently spread across the function — risk of regression when modifying any single step
- Companion to `bfh_qic()` refactor for consistency

**Pattern:**

```
bfh_export_pdf(args) [≤ 80 lines]
  ├── validate_bfh_export_pdf_inputs(args)
  ├── metadata <- prepare_export_metadata(x, metadata, auto_analysis, use_ai, ...)
  ├── temp_dir <- prepare_temp_workspace(batch_session)
  ├── plot <- prepare_export_plot(x)
  ├── chart_svg <- export_chart_svg(plot, temp_dir, dpi)
  ├── typst_file <- compose_typst_document(chart_svg, metadata, temp_dir, ...)
  ├── compile_pdf_via_quarto(typst_file, output, font_path)
  └── invisible(x)
```

**Security ordering preserved:**
1. Validation (no IO yet)
2. File system operations
3. Quarto execution
4. Cleanup (registered before any allocation)

#### Scenario: orchestrator under target size after refactor

- **GIVEN** the refactored `bfh_export_pdf()` function
- **WHEN** the function body is measured (excluding Roxygen, blank lines)
- **THEN** the body SHALL be ≤ 80 lines

#### Scenario: helpers callable in isolation

- **GIVEN** any of the new helpers
- **WHEN** called with appropriate arguments
- **THEN** the helper SHALL produce its expected output without invoking the full orchestrator

#### Scenario: security check ordering preserved

- **GIVEN** the refactored function
- **WHEN** an invalid `output` path with shell metachars is passed
- **THEN** validation SHALL fail BEFORE any tempdir is created
- **AND** no Quarto invocation SHALL occur

#### Scenario: public API unchanged after refactor

- **GIVEN** existing tests calling `bfh_export_pdf()` from any caller
- **WHEN** running `devtools::test()` after the refactor
- **THEN** all pre-existing tests SHALL pass without modification

### Requirement: Primary public entry points SHALL be thin orchestrators

Primary public entry points (`bfh_qic()`, `bfh_export_pdf()`, `bfh_export_png()`) SHALL act as thin orchestrators that delegate distinct responsibilities (validation, computation, rendering, IO, return-routing) to internal helpers. Orchestrator function bodies SHOULD target ≤ 80 lines excluding Roxygen.

**Rationale:**
- Single function carrying 380+ lines mixes 8+ concerns and is impossible to test in isolation
- Failure localization is slow when one giant function breaks
- Architectural pattern documented for future entry points

**Pattern:**

```
bfh_qic(args) [≤ 80 lines]
  ├── validate_bfh_qic_inputs(args)
  ├── qic_args <- build_qic_args(args, validated_columns)
  ├── qic_data <- invoke_qicharts2(qic_args)
  ├── viewport_info <- compute_viewport_base_size(args)
  ├── plot <- render_bfh_plot(qic_data, args, viewport_info)
  ├── plot <- apply_spc_labels_to_export(plot, qic_data, args, viewport_info)
  ├── summary <- format_qic_summary(qic_data, args$y_axis_unit)
  └── build_bfh_qic_return(qic_data, plot, summary, config, args$return.data, args$print.summary)
```

#### Scenario: orchestrator under target size after refactor

- **GIVEN** the refactored `bfh_qic()` function in `R/bfh_qic.R`
- **WHEN** the function body is measured (excluding Roxygen, blank lines)
- **THEN** the body SHALL be ≤ 80 lines

#### Scenario: helpers callable in isolation

- **GIVEN** any of the new helpers (`validate_bfh_qic_inputs`, `build_qic_args`, etc.)
- **WHEN** called with appropriate arguments in isolation
- **THEN** the helper SHALL produce its expected output without invoking the full orchestrator
- **AND** unit tests SHALL exercise each helper independently

```r
# Example — validation helper testable alone
expect_error(
  validate_bfh_qic_inputs(args = list(chart_type = "invalid_type", ...)),
  "chart_type must be"
)
```

#### Scenario: public API unchanged after refactor

- **GIVEN** existing tests calling `bfh_qic()` from any caller
- **WHEN** running `devtools::test()` after the refactor
- **THEN** all pre-existing tests SHALL pass without modification
- **AND** `bfh_qic()` signature, return values, and behavior SHALL be identical


### Requirement: Language-specific text utilities SHALL live in dedicated files

Internal helpers for language-specific text formatting (pluralization, branched text selection, placeholder substitution, length padding, length truncation) SHALL live in dedicated files named `R/utils_text_<lang>.R` rather than embedded inside larger pipeline files.

The current Danish text-formatting helpers — `pluralize_da()`, `pick_text()`, `substitute_placeholders()`, `pad_to_minimum()`, `ensure_within_max()` — SHALL be located in `R/utils_text_da.R` (not in `R/spc_analysis.R` or any other pipeline file).

Helpers SHALL retain `@keywords internal @noRd` annotations and SHALL NOT be exported. Tests for these helpers MAY remain in their existing location (typically `tests/testthat/test-spc_analysis.R`) if the helpers are exercised primarily through their original integration path.

#### Scenario: Danish text helpers live in dedicated file

- **WHEN** the package source is inspected
- **THEN** `R/utils_text_da.R` SHALL exist and SHALL contain at minimum: `pluralize_da()`, `pick_text()`, `substitute_placeholders()`, `pad_to_minimum()`, `ensure_within_max()`
- **AND** `R/spc_analysis.R` SHALL NOT contain any of these five function definitions

#### Scenario: existing call sites resolve correctly after relocation

- **WHEN** `devtools::load_all()` runs after the relocation
- **THEN** all internal call sites of the five helpers SHALL resolve correctly via R's namespace lookup
- **AND** all existing tests covering these helpers SHALL pass without modification

#### Scenario: future English-specific text utilities follow the same pattern

- **WHEN** new language-specific text-formatting helpers are introduced for English (e.g. `pluralize_en()`)
- **THEN** they SHALL be placed in `R/utils_text_en.R`, not embedded in pipeline files
## ADDED Requirements

### Requirement: Label-pipeline orchestrators SHALL follow 3-layer decomposition

Internal label-pipeline functions that exceed 200 lines SHALL be decomposed into a thin orchestrator (≤220 lines) plus named private helpers, mirroring the 3-layer split pattern established in v0.13.0 for `place_two_labels_npc()` (NIVEAU 1/2/3 cascade).

The orchestrator's responsibilities are limited to: parameter binding, helper invocation in pipeline order, and result aggregation. All substantive work — geometry resolution, device acquisition, measurement, x-axis-type detection, label-data construction, placement, grob construction — SHALL live in named helpers prefixed with `.` and marked `@keywords internal @noRd`.

Helpers SHALL accept injected dependencies (config providers, device handles, measurement estimators, logging flags) so each can be unit-tested in isolation without real graphics-device side effects. Side-effecting helpers (e.g. those that open a graphics device) SHALL return a cleanup closure that the orchestrator binds via `on.exit(..., add = TRUE)` (or `withr::defer()` where used); manual scattered `dev.off()` patterns SHALL be consolidated through the cleanup closure.

#### Scenario: add_right_labels_marquee respects the orchestrator-helper boundary

- **WHEN** the package source is inspected for `R/utils_add_right_labels_marquee.R`
- **THEN** `add_right_labels_marquee()` SHALL be ≤220 lines and SHALL only invoke named helpers (no inline gpar resolution, device acquisition, panel-height measurement, label-height estimation, x-axis type detection, label-data tibble construction, or grob construction logic)
- **AND** at minimum these private helpers SHALL exist in the same file: `.resolve_label_geometry()`, `.acquire_device_for_measurement()`, `.measure_label_heights()`, `.detect_x_axis_type()`, `.build_label_data()`

#### Scenario: helpers are unit-testable without a real graphics device

- **WHEN** unit tests for `.resolve_label_geometry()` and `.measure_label_heights()` are run
- **THEN** the tests SHALL pass without opening any graphics device (no `Rplots.pdf` produced, no `dev.cur()` change observable from outside the test)

#### Scenario: device-acquiring helpers return a cleanup closure

- **WHEN** `.acquire_device_for_measurement()` opens a fallback graphics device
- **THEN** it SHALL return a list containing a `cleanup_fn` closure that closes the device when invoked
- **AND** the orchestrator SHALL register the closure via `on.exit(..., add = TRUE)` or `withr::defer()` so it fires on both normal exit and error exit

#### Scenario: visual regression baselines remain unchanged after decomposition

- **WHEN** the pre-push hook runs `PREPUSH_MODE=full` (vdiffr with `NOT_CRAN=true`) on a refactor commit
- **THEN** zero `.new.svg` files SHALL be produced under `tests/testthat/_snaps/visual-regression/`
- **AND** all 9 canonical chart-scenario snapshots SHALL match byte-for-byte against the baselines refreshed in v0.14.2 (PR #279)
