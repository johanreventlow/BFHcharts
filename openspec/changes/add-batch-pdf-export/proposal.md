# Proposal: add-batch-pdf-export

## Why

Users who assemble large combined reports (several hundred up to ~1,800 SPC charts
per document) currently export one single-page PDF per chart via `bfh_export_pdf()`
and merge them with an external tool. Because Typst embeds a fresh, uniquely named
font subset per compiled PDF, the merged document carries one Mari subset (times
number of font faces) per page, inflating file size dramatically. Merge tools cannot
deduplicate these subsets. Additionally, charts are often produced at different times
or in different processes, so any batch solution must not require recomputing SPC
statistics or re-rendering ggplot objects at assembly time.

## What Changes

- **New staging capability (disk cache):** a new exported function stages one
  chart as a "page bundle" into a persistent, user-supplied directory:
  - the rendered chart SVG (already produced today by the export pipeline), and
  - a small serialized metadata file (finalized template metadata + SPC stats +
    template parameters + ordering key).
  Staging reuses the existing pipeline steps (metadata prep, plot prep, SVG
  export, stats extraction) but stops before Typst document creation/compilation.
  No SPC recomputation and no ggplot serialization is involved.
- **New batch compile function:** a new exported function reads all staged page
  bundles from a cache directory, composes ONE Typst document that calls the
  existing page-level template function `bfh-diagram(...)` once per page (the
  template already exposes this function), and compiles ONE multi-page PDF via
  the existing Quarto/Typst infrastructure. Fonts (Mari or fallbacks) are thereby
  embedded exactly once per face for the entire document.
  - **Manifest-based selection:** the caller MAY pass an explicit vector of page
    ids; the combined PDF then contains exactly those pages (missing id =
    error, unlisted bundles are ignored). The caller's
    production list — not the accumulated cache contents — is thereby the source
    of truth for what the combined document contains, so stale/retired bundles
    cannot pollute the output.
  - Optional chunking parameter (pages per compile) as a safety valve for very
    large documents; chunk outputs are concatenated so the font-subset count is
    bounded by the number of chunks, not the number of pages.
- **Cache maintenance:** re-staging an existing id atomically replaces its
  bundle (supports "correct one or two charts, recompile everything"), and a
  new exported pruning helper removes bundles by keep-list or age so retired
  charts can also be deleted from the cache physically.
- **Cache format versioning:** each page bundle records a format version so a
  future BFHcharts can refuse (with a clear error) to compile bundles staged by
  an incompatible version, instead of producing broken output.
- **No changes to existing behavior:** `bfh_export_pdf()` single-call and
  `bfh_create_export_session()` batch-asset semantics are unchanged. The new
  functions are additive.

Not breaking. No existing exported signature changes.

## Capabilities

### New Capabilities

- `batch-pdf-export`: staging of per-chart page bundles (SVG + serialized
  metadata/stats) to a persistent cache directory, cache format validation,
  and single-compile assembly of a multi-page PDF from staged bundles,
  including page ordering, manifest-based page selection, cache pruning,
  chunked compilation, and font-embedding guarantees (one font subset per
  face per compiled document).

### Modified Capabilities

<!-- none: existing pdf-export requirements (single-chart export, font fallback
     chain, asset policy, template security) are unchanged; the new capability
     reuses them without altering their contracts. -->

## Impact

- **Code:**
  - New: `R/export_batch.R` (staging + batch compile), building on
    `prepare_export_metadata()`, `prepare_export_plot()`, `export_chart_svg()`,
    `bfh_extract_spc_stats()`, `bfh_create_typst_document()` /
    `compose_typst_document()` internals, and `bfh_compile_typst()`.
  - Possible small refactor: extract the per-page Typst argument rendering from
    `bfh_create_typst_document()` so it can emit N `bfh-diagram(...)` calls into
    one document (template file `inst/templates/typst/bfh-template/bfh-template.typ`
    already defines `bfh-diagram` as a callable function; no template rewrite
    expected, at most a `pagebreak()` between pages in the generated main file).
- **Public API:** three new exports (naming decided in design.md, working names
  `bfh_stage_pdf_page()`, `bfh_export_batch_pdf()`, `bfh_prune_page_cache()`).
  Additive only; NAMESPACE regenerated via `devtools::document()`.
- **biSPCharts impact:** none required (additive API). biSPCharts MAY adopt the
  staging call in its per-chart export path to enable combined-report generation;
  coordinate via issue with `enhancement` label once merged.
- **Security:** cache directory contents are treated like existing temp-workspace
  inputs; path validation reuses `validate_export_path()` / traversal guards.
  `restrict_template = TRUE` semantics carry over to batch compile. Deserializing
  page bundles uses RDS from a user-controlled directory — same trust model as
  `template_path` (documented, no elevation beyond the calling R session).
- **Statistical validation:** not required — no statistical calculations are
  added or modified; staged SPC stats are the values already computed by
  `bfh_qic()`.
- **Dependencies:** no new hard dependencies (RDS via base R; Typst/Quarto
  already required for PDF export).
