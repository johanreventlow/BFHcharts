# batch-pdf-export — Delta Spec

## Purpose

Enables assembly of large multi-page SPC report PDFs (hundreds to ~1,800 pages)
without duplicated embedded fonts: individual charts are staged to a persistent
on-disk page cache (chart SVG + serialized metadata/stats) at generation time,
and a separate batch compile step composes all staged pages into one Typst
compilation, so each font face is embedded exactly once per compiled document.

## ADDED Requirements

### Requirement: Package SHALL export a page staging function

The package SHALL export a function that stages a single `bfh_qic_result` as a
persistent "page bundle" in a caller-supplied cache directory, performing the
same chart preparation as single-chart PDF export (metadata finalization, title
strip, label recalculation, SVG rendering, SPC stats extraction) but producing
no PDF.

A page bundle SHALL consist of:
- the rendered chart SVG, and
- a serialized data file containing finalized template metadata, extracted SPC
  statistics, template selection, a page ordering key, and a cache format
  version.

Staging SHALL NOT recompute SPC statistics and SHALL NOT serialize ggplot
objects; only render output and plain data are persisted, so bundles remain
readable across ggplot2/BFHtheme upgrades.

#### Scenario: Stage a chart to an empty cache directory

- **GIVEN** a valid `bfh_qic_result` and an existing writable cache directory
- **WHEN** the staging function is called with the result, the cache directory,
  and a unique page identifier
- **THEN** the cache directory SHALL contain a page bundle for that identifier
  holding the chart SVG and the serialized metadata/stats file
- **AND** no PDF SHALL be produced
- **AND** the returned value SHALL identify the staged bundle (invisibly)

#### Scenario: Staging accepts the same metadata inputs as single export

- **GIVEN** a `bfh_qic_result` and metadata overrides (e.g., department, author,
  data definition) accepted by `bfh_export_pdf()`
- **WHEN** the chart is staged with those metadata values
- **THEN** the staged bundle SHALL contain the finalized metadata so that batch
  compilation reproduces the same page content as a single-chart export with
  identical inputs

#### Scenario: Duplicate page identifier

- **GIVEN** a cache directory already containing a bundle with identifier "x"
- **WHEN** the staging function is called again with identifier "x" and default
  overwrite behavior
- **THEN** the existing bundle SHALL be replaced atomically (no mixed old/new
  bundle contents on failure)

#### Scenario: Invalid inputs are rejected

- **WHEN** the staging function is called with an object that is not a
  `bfh_qic_result`, or with a non-existent/non-writable cache directory
- **THEN** it SHALL abort with a classed BFHcharts export error naming the
  offending argument

### Requirement: Package SHALL export a batch compile function

The package SHALL export a function that reads all page bundles from a cache
directory and compiles them into ONE multi-page PDF using the packaged Typst
template's page-level function, one page per bundle, via a single Typst
compilation (or a bounded number of chunked compilations — see chunking
requirement).

Fonts SHALL resolve through the existing font infrastructure (staged template
`fonts/` auto-detect, `font_path` override, `ignore_system_fonts` default TRUE,
`inject_assets` hook), so a batch-compiled document embeds each required font
face exactly once per compilation.

#### Scenario: Compile staged bundles into one PDF

- **GIVEN** a cache directory containing N staged page bundles (N >= 1)
- **WHEN** the batch compile function is called with the cache directory and an
  output path
- **THEN** exactly one PDF SHALL be written to the output path containing N
  pages, each rendered by the packaged template with that bundle's chart and
  metadata
- **AND** each font face used SHALL be embedded at most once in the PDF

#### Scenario: Page order is deterministic

- **GIVEN** staged bundles with ordering keys
- **WHEN** the batch PDF is compiled
- **THEN** pages SHALL appear sorted by ordering key (ties broken by page
  identifier), independent of filesystem enumeration order

#### Scenario: Empty cache directory

- **GIVEN** a cache directory containing no valid page bundles
- **WHEN** the batch compile function is called
- **THEN** it SHALL abort with a classed BFHcharts export error stating that no
  staged pages were found (no empty PDF is produced)

#### Scenario: Corrupt or incomplete bundle

- **GIVEN** a cache directory where one bundle is unreadable, incomplete
  (missing SVG or metadata file), or fails validation
- **WHEN** the batch compile function is called with default settings
- **THEN** it SHALL abort with an error identifying the offending bundle before
  any PDF is written
- **AND** an opt-in argument SHALL allow skipping invalid bundles with a warning
  that lists each skipped identifier

### Requirement: Batch compilation SHALL support manifest-based page selection

The batch compile function SHALL accept an optional character vector of page
identifiers (a manifest). When supplied, the compiled document SHALL contain
exactly the pages named in the manifest — no more, no fewer:

- an identifier in the manifest with no valid bundle in the cache SHALL cause
  an error before any PDF is written, listing every missing identifier;
- bundles present in the cache but not named in the manifest SHALL be excluded
  from the document without warning (stale or retired bundles in the cache
  cannot affect the output);
- page order SHALL follow the staged ordering keys by default, with an option
  to order pages by manifest position instead.

When no manifest is supplied, all valid bundles in the cache directory are
compiled (existing default behavior).

#### Scenario: Retired charts excluded via manifest

- **GIVEN** a cache directory with bundles "a", "b", "c" where "c" is retired
- **WHEN** the batch compile function is called with the manifest `c("a", "b")`
- **THEN** the output PDF SHALL contain exactly the pages for "a" and "b"
- **AND** bundle "c" SHALL remain untouched in the cache and absent from the PDF

#### Scenario: Manifest names a missing page

- **GIVEN** a cache directory with bundles "a" and "b"
- **WHEN** the batch compile function is called with the manifest
  `c("a", "b", "d")`
- **THEN** it SHALL abort before compilation with an error listing "d" as
  missing, and no PDF SHALL be written

#### Scenario: Corrected pages after re-staging

- **GIVEN** bundles "a" and "b" compiled previously, after which "b" is
  re-staged with corrected content under the same identifier
- **WHEN** the batch compile function is called with the manifest `c("a", "b")`
- **THEN** the output PDF SHALL contain the corrected content for "b" and the
  unchanged content for "a", with no re-staging of "a" required

### Requirement: Package SHALL export a cache pruning function

The package SHALL export a function that removes page bundles from a cache
directory, selected by an explicit keep-list (delete everything not named) or
by staging age (delete bundles staged before a cutoff). It SHALL support a
dry-run mode that reports which bundles would be removed without deleting
anything, and SHALL return the identifiers of removed (or would-be removed)
bundles. Non-bundle files in the cache directory SHALL never be deleted.

#### Scenario: Prune to a keep-list

- **GIVEN** a cache directory with bundles "a", "b", "c"
- **WHEN** the pruning function is called with keep-list `c("a", "b")`
- **THEN** bundle "c" SHALL be deleted, bundles "a" and "b" SHALL remain, and
  the returned value SHALL contain "c"

#### Scenario: Dry run deletes nothing

- **GIVEN** a cache directory with bundles "a", "b", "c"
- **WHEN** the pruning function is called with keep-list `c("a")` and dry-run
  enabled
- **THEN** all three bundles SHALL remain on disk and the returned value SHALL
  list "b" and "c" as removal candidates

### Requirement: Batch compilation SHALL support chunked compilation

The batch compile function SHALL accept an optional pages-per-chunk limit. When
set and the page count exceeds the limit, compilation SHALL proceed in chunks
of at most that many pages, and the chunk PDFs SHALL be concatenated into the
single output PDF. The number of embedded subsets per font face in the final
document SHALL then be at most the number of chunks.

#### Scenario: Chunked compile of a large batch

- **GIVEN** 1,000 staged bundles and a pages-per-chunk limit of 250
- **WHEN** the batch compile function is called
- **THEN** the output SHALL be one 1,000-page PDF in the specified page order
- **AND** each font face SHALL be embedded at most 4 times
- **AND** intermediate chunk files SHALL be removed on success and on error

#### Scenario: Default is a single compilation

- **GIVEN** staged bundles and no pages-per-chunk argument
- **WHEN** the batch compile function is called
- **THEN** all pages SHALL be compiled in a single Typst compilation

### Requirement: Page bundles SHALL carry a validated cache format version

Each page bundle SHALL record the cache format version it was written with.
The batch compile function SHALL validate bundle versions before composing the
document and SHALL abort with a clear, actionable error (naming the bundle, its
version, and the supported version) when a bundle's format is unsupported,
rather than producing incorrect output.

#### Scenario: Bundle from an incompatible format version

- **GIVEN** a cache directory containing a bundle staged with an unsupported
  format version
- **WHEN** the batch compile function is called
- **THEN** it SHALL abort before compilation with an error identifying the
  bundle, its recorded version, and the version(s) supported by the installed
  BFHcharts, and advising the user to re-stage that page

### Requirement: Batch functions SHALL preserve existing export security guarantees

Staging, batch compilation, and cache pruning SHALL apply the same path
validation (traversal and shell-metacharacter guards) as existing export entry
points to all user-supplied paths and identifiers (cache directory, page
identifiers used in paths — including manifest and keep-list entries — output
path, `font_path`). Batch compilation SHALL use only the packaged template
unless the caller explicitly opts out via the same `restrict_template`
mechanism and semantics as `bfh_export_pdf()`. Documentation SHALL state that
the cache directory is trusted input (bundles are deserialized in the calling
R session) and must not be populated from untrusted sources.

#### Scenario: Path traversal in page identifier

- **WHEN** the staging function is called with a page identifier containing
  path separators or traversal sequences (e.g., `../evil`)
- **THEN** it SHALL abort with a validation error and write nothing

#### Scenario: Custom template requires explicit opt-out

- **GIVEN** default settings (`restrict_template = TRUE`)
- **WHEN** the batch compile function is called with a custom `template_path`
- **THEN** it SHALL abort with the same classed error and warning text
  semantics as `bfh_export_pdf()`

### Requirement: Existing single-chart export behavior SHALL be unchanged

Introducing staging and batch compilation SHALL NOT change the observable
behavior, signatures, or defaults of `bfh_export_pdf()`,
`bfh_create_export_session()`, or `bfh_create_typst_document()`.

#### Scenario: Single-chart export regression guard

- **GIVEN** the existing single-chart export test suite
- **WHEN** the batch-pdf-export change is implemented
- **THEN** all existing pdf-export tests SHALL pass without modification of
  their expectations
