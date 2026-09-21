## ADDED Requirements

### Requirement: Typst template SHALL support a full-width figure layout

The `bfh-diagram` Typst template SHALL accept a boolean parameter
`spc_panel` (default `true`). When `false`, the chart row SHALL render as a
single full-width column containing the details line, the chart and the
footer, and SHALL NOT render the SPC statistics column (heading, statistics
table, centerline caveat, data definition). The header block (hospital,
department, auto-scaled title) and the analysis row SHALL be unchanged in
both modes.

**Rationale:**
- Non-SPC figures (distributions, bar charts, plain time series) need the
  same branded page without an empty statistics column.
- A flag on the existing template keeps the calibrated header/title code
  single-sourced and lets one batch document mix SPC and figure pages under
  one template import.

#### Scenario: Default mode is unchanged

- **GIVEN** a Typst document that does not pass `spc_panel`
- **WHEN** it is compiled
- **THEN** the page SHALL render exactly as before this change (two-column
  chart row with the 72.6 mm SPC column)

#### Scenario: Full-width mode omits the SPC column

- **GIVEN** a Typst document passing `spc_panel: false`
- **WHEN** it is compiled
- **THEN** the chart row SHALL contain no "Statistisk Proceskontrol"
  heading, no statistics table, no centerline caveat and no data definition
- **AND** the chart SHALL occupy the width between the 26.4 mm left inset
  and the 6.6 mm right inset (264 mm on A4 landscape)
- **AND** the header block and analysis row SHALL render identically to
  default mode

#### Scenario: Smoke template accepts the parameter

- **GIVEN** the CI smoke template (`tests/smoke/test-template.typ`)
- **WHEN** a document passes `spc_panel: false`
- **THEN** compilation SHALL succeed (Typst rejects unknown named
  parameters, so the smoke template mirrors the production signature)

### Requirement: Package SHALL export a figure PDF export function

The package SHALL export `bfh_export_figure_pdf(plot, output, metadata,
...)` which renders an arbitrary `ggplot` object to a single-page branded
PDF using the packaged template in full-width mode.

The function SHALL:
- accept a `ggplot` object as `plot` and reject any other class with a
  classed BFHcharts export error naming the argument;
- require a non-empty `metadata$title` (the template title has no other
  source for figures) and abort before any filesystem operation when it is
  missing;
- strip the plot's own title and subtitle and apply zero plot margins,
  mirroring `bfh_export_pdf()` (the title is rendered in the header);
- render the chart SVG at the full-width dimensions (264 mm × 109 mm), not
  the SPC chart dimensions;
- send `spc_panel: false` and no SPC statistics parameters to the template;
- reuse the existing export pipeline: output path validation
  (`validate_export_path()`), `restrict_template` semantics, `inject_assets`
  validation, font auto-detection and `font_path`, logo auto-detection,
  `batch_session` reuse, temp-workspace protection and cleanup.

The function SHALL NOT offer SPC-specific arguments (`auto_analysis`,
`use_ai`, `strict_baseline` and related) and SHALL NOT perform SPC label
recalculation or statistics extraction.

#### Scenario: Figure exported with branding

- **GIVEN** a `ggplot` object and `metadata = list(title = "Ventetid",
  department = "Kirurgi", analysis = "...", details = "2025")`
- **WHEN** `bfh_export_figure_pdf(p, "out.pdf", metadata = metadata)` is
  called
- **THEN** one PDF SHALL be written whose page shows the blue header with
  hospital/department/title, the analysis row, the details line, the
  figure across the full chart width, and the footer
- **AND** no SPC statistics column SHALL be present

#### Scenario: Non-ggplot input is rejected

- **WHEN** `bfh_export_figure_pdf(data.frame(), "out.pdf", metadata =
  list(title = "x"))` is called
- **THEN** it SHALL abort with a classed export error naming `plot`
- **AND** no file SHALL be written

#### Scenario: Missing title is rejected

- **WHEN** `bfh_export_figure_pdf(p, "out.pdf")` is called without
  `metadata$title`
- **THEN** it SHALL abort with a classed export error naming `title`
- **AND** no Typst compile process SHALL be spawned

#### Scenario: Plot title does not appear twice

- **GIVEN** a `ggplot` with `labs(title = "A", subtitle = "B")`
- **WHEN** it is exported with `metadata$title = "C"`
- **THEN** the rendered chart SHALL contain neither "A" nor "B"
- **AND** the header SHALL show "C"

#### Scenario: Chart SVG uses full-width dimensions

- **WHEN** a figure is exported
- **THEN** the intermediate SVG SHALL declare a width of 264 mm and a
  height of 109 mm

#### Scenario: Security guards match single-chart export

- **WHEN** `bfh_export_figure_pdf()` is called with a traversal output path,
  a `template_path` without `restrict_template = FALSE`, or an
  `inject_assets` callback failing validation
- **THEN** it SHALL abort with the same classed errors and messages as
  `bfh_export_pdf()` in the same situations

## MODIFIED Requirements

### Requirement: Existing single-chart export behavior SHALL be unchanged

Introducing the full-width template mode and the figure export functions
SHALL NOT change the observable behavior, signatures, defaults or generated
Typst output of `bfh_export_pdf()`, `bfh_create_export_session()`,
`bfh_create_typst_document()` or `bfh_stage_pdf_page()`. In particular, the
`spc_panel` parameter SHALL be emitted to the template only when explicitly
`FALSE`, so Typst documents generated for SPC charts are byte-identical to
those generated before this change.

#### Scenario: Single-chart export regression guard

- **GIVEN** the existing single-chart export test suite
- **WHEN** this change is implemented
- **THEN** all existing pdf-export tests SHALL pass without modification of
  their expectations

#### Scenario: SPC documents carry no spc_panel parameter

- **GIVEN** a `bfh_qic_result` exported via `bfh_export_pdf()` or staged via
  `bfh_stage_pdf_page()`
- **WHEN** the Typst document is generated
- **THEN** it SHALL NOT contain a `spc_panel` parameter
