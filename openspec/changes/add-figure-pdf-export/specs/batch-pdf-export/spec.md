## ADDED Requirements

### Requirement: Package SHALL export a figure page staging function

The package SHALL export `bfh_stage_figure_page(plot, cache_dir, id, order,
metadata, ...)` which stages an arbitrary `ggplot` object as a page bundle
in the same cache format as `bfh_stage_pdf_page()`, for inclusion in batch
documents compiled by `bfh_export_batch_pdf()`.

A figure page bundle SHALL:
- use the same on-disk structure and `format_version` as an SPC page bundle
  (chart SVG plus serialized metadata/stats file);
- carry `metadata$spc_panel = FALSE` and empty SPC statistics (all `NULL`),
  so the batch compiler renders the page in full-width mode without any
  page-type branching;
- contain a chart SVG rendered at the full-width dimensions (equivalent to
  264 mm × 109 mm within 0.1 mm; svglite declares them in points);
- be subject to the same input validation as `bfh_export_figure_pdf()`
  (`ggplot` class, non-empty `metadata$title`) and the same cache-directory,
  page-identifier, ordering, overwrite and atomic-replacement semantics as
  `bfh_stage_pdf_page()`.

#### Scenario: Stage a figure to a cache directory

- **GIVEN** a `ggplot` object, `metadata = list(title = "Ventetid")` and an
  existing writable cache directory
- **WHEN** `bfh_stage_figure_page(p, cache_dir, id = "fig-1")` is called
- **THEN** the cache directory SHALL contain a bundle `fig-1` holding the
  chart SVG and the serialized page data
- **AND** the page data SHALL record `spc_panel = FALSE` and no SPC
  statistics values
- **AND** no PDF SHALL be produced

#### Scenario: Figure bundles share the cache format version

- **GIVEN** a staged figure bundle
- **WHEN** its page data is read
- **THEN** `format_version` SHALL equal the current
  `BATCH_CACHE_FORMAT_VERSION`
- **AND** `bfh_export_batch_pdf()` SHALL accept it without a format error

#### Scenario: Invalid figure inputs are rejected

- **WHEN** `bfh_stage_figure_page()` is called with a non-`ggplot` object,
  without `metadata$title`, with an invalid page identifier, or with a
  non-writable cache directory
- **THEN** it SHALL abort with a classed BFHcharts export error naming the
  offending argument
- **AND** nothing SHALL be written to the cache

### Requirement: Batch documents SHALL support mixed SPC and figure pages

`bfh_export_batch_pdf()` SHALL compile SPC page bundles and figure page
bundles into one document without any change to its interface. Page order,
manifest selection, chunking, pruning and security guards SHALL apply to
figure bundles exactly as to SPC bundles.

#### Scenario: Mixed batch renders each page in its own mode

- **GIVEN** a cache directory with an SPC bundle "spc-1" and a figure bundle
  "fig-1"
- **WHEN** `bfh_export_batch_pdf(cache_dir, "out.pdf", ids = c("spc-1",
  "fig-1"))` is called
- **THEN** the generated Typst document SHALL contain two template calls
  under a single template import
- **AND** only the call for "fig-1" SHALL pass `spc_panel: false`
- **AND** the call for "spc-1" SHALL be identical to what it was before this
  change

#### Scenario: Manifest and pruning treat figure bundles as pages

- **GIVEN** a cache directory with figure bundle "fig-1"
- **WHEN** `bfh_prune_page_cache(cache_dir, keep = character(0))` is called
- **THEN** "fig-1" SHALL be removed like any other bundle
- **AND** `bfh_export_batch_pdf(cache_dir, "out.pdf", ids = "fig-1")` before
  pruning SHALL include it, and after pruning SHALL abort listing "fig-1" as
  missing

## MODIFIED Requirements

### Requirement: Package SHALL export a page staging function

The package SHALL export a function that stages a single `bfh_qic_result` as
a persistent "page bundle" in a caller-supplied cache directory, performing
the same chart preparation as single-chart PDF export (metadata
finalization, title strip, label recalculation, SVG rendering, SPC stats
extraction) but producing no PDF.

A page bundle SHALL consist of:
- the rendered chart SVG, and
- a serialized data file containing finalized template metadata, extracted
  SPC statistics, template selection, a page ordering key, and a cache
  format version.

Staging SHALL NOT recompute SPC statistics and SHALL NOT serialize ggplot
objects; only render output and plain data are persisted, so bundles remain
readable across ggplot2/BFHtheme upgrades.

Bundles staged from a `bfh_qic_result` SHALL NOT carry a `spc_panel`
metadata value (the template default applies), so bundles written before
this change and bundles written after it are indistinguishable for SPC
pages.

#### Scenario: Stage a chart to an empty cache directory

- **GIVEN** a valid `bfh_qic_result` and an existing writable cache directory
- **WHEN** the staging function is called with the result, the cache
  directory, and a unique page identifier
- **THEN** the cache directory SHALL contain a page bundle for that
  identifier holding the chart SVG and the serialized metadata/stats file
- **AND** no PDF SHALL be produced
- **AND** the returned value SHALL identify the staged bundle (invisibly)

#### Scenario: Staging accepts the same metadata inputs as single export

- **GIVEN** a `bfh_qic_result` and metadata overrides (e.g., department,
  author, data definition) accepted by `bfh_export_pdf()`
- **WHEN** the chart is staged with those metadata values
- **THEN** the staged bundle SHALL contain the finalized metadata so that
  batch compilation reproduces the same page content as a single-chart
  export with identical inputs

#### Scenario: Duplicate page identifier

- **GIVEN** a cache directory already containing a bundle with identifier "x"
- **WHEN** the staging function is called again with identifier "x" and
  default overwrite behavior
- **THEN** the existing bundle SHALL be replaced atomically (no mixed old/new
  bundle contents on failure)

#### Scenario: Invalid inputs are rejected

- **WHEN** the staging function is called with an object that is not a
  `bfh_qic_result`, or with a non-existent/non-writable cache directory
- **THEN** it SHALL abort with a classed BFHcharts export error naming the
  offending argument

#### Scenario: SPC bundles are unchanged by the figure feature

- **GIVEN** a `bfh_qic_result` staged after this change
- **WHEN** its page data is read
- **THEN** it SHALL contain no `spc_panel` value
- **AND** its Typst page call SHALL be identical to one generated before
  this change
