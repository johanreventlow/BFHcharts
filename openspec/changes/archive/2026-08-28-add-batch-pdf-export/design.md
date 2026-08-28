# Design: add-batch-pdf-export

## Context

See `proposal.md` — Why. Current state relevant to the approach:

- `bfh_export_pdf()` is a linear orchestrator (`R/export_pdf.R`): validate →
  `prepare_export_metadata()` → `prepare_export_plot()` (title strip + label
  recalc) → `export_chart_svg()` → `bfh_extract_spc_stats()` →
  `compose_typst_document()` → `compile_pdf_via_quarto()`. Steps up to and
  including stats extraction are exactly what a staged page bundle needs; the
  last two steps are what the batch compiler replaces.
- The packaged template already exposes a callable page-level function
  `bfh-diagram(...)` (`inst/templates/typst/bfh-template/bfh-template.typ`).
  Today's generated main document invokes it once via
  `#show: bfh-diagram.with(<params>)` + body (`build_typst_content()`,
  `R/utils_typst.R`). A multi-page document can instead call the function
  directly N times: `#bfh-diagram(<params>)[<chart>]`.
- Font resolution (staged `bfh-template/fonts/` auto-detect, `--font-path`,
  `--ignore-system-fonts`, `inject_assets` hook) lives in
  `compose_typst_document()` / `bfh_compile_typst()` and is per-compilation,
  not per-page — it transfers to batch compile unchanged.
- Typst embeds one font subset per face per compilation; the whole point of
  the change is to reduce compilations from N to 1 (or to ceil(N/chunk)).

Constraints: additive-only public API; ASCII-only `R/*.R`; existing export
security guards (`validate_export_path()`, `.check_traversal()`,
`.check_metachars()`, `restrict_template`, `.redact_paths()`) must apply to all
new user-supplied paths; no new hard dependencies.

## Goals / Non-Goals

**Goals:**

- Page bundles that survive time, process boundaries, and ggplot2/BFHtheme
  upgrades (no ggplot serialization).
- One (or few) Typst compilations for arbitrarily many staged pages, with
  identical per-page rendering to today's single-chart export.
- Reuse of the existing pipeline helpers rather than a parallel implementation.

**Non-Goals:**

- No cache invalidation/expiry logic (the cache directory is user-managed; the
  user decides when to delete or re-stage).
- No cross-version bundle migration — an incompatible bundle is an error asking
  for a re-stage, not a conversion target.
- No parallel/multi-process compile orchestration.
- No change to PNG export or to the in-memory label measurement cache
  (`caching-system` spec is untouched).
- No table of contents / cover page for the combined document (possible
  follow-up; keep the first version to pure page concatenation).

## Decisions

### D1: Cache the SVG + plain data, not `bfh_qic_result` objects

`saveRDS()` of full result objects would work but drags multi-MB ggplot
environments to disk (GBs at 1,800 pages), is slow, and breaks silently across
ggplot2 upgrades. The Typst layer only needs the chart SVG plus plain-data
template arguments, all of which exist mid-pipeline today. So a bundle stores:

```
<cache_dir>/<id>/chart.svg    # output of export_chart_svg()
<cache_dir>/<id>/page.rds     # list(format_version, id, order, metadata,
                              #      spc_stats, template, created_at,
                              #      bfhcharts_version)
```

`page.rds` contains only atomic vectors/lists (finalized metadata from
`prepare_export_metadata()`, stats from `bfh_extract_spc_stats()`) — RDS here
is a container for plain data, not for R objects with behavior.

*Alternative considered:* JSON sidecar instead of RDS — rejected: adds a
serialization dependency (jsonlite is not currently imported), loses R type
fidelity (integer vs double matters for the Typst injection guards in
`bfh_create_typst_document()`), and the trust model is unchanged since the SVG
must be trusted anyway.

### D2: Public API — `bfh_stage_pdf_page()`, `bfh_export_batch_pdf()`, `bfh_prune_page_cache()`

```r
bfh_stage_pdf_page(x, cache_dir,
                   id = NULL,          # default: zero-padded next index
                   order = NULL,       # default: staging sequence
                   metadata = list(),
                   template = "bfh-diagram",
                   auto_analysis = FALSE, ..., # same metadata knobs as bfh_export_pdf
                   dpi = 150,
                   overwrite = TRUE)
# -> invisible bfh_staged_page (list: id, path, order)

bfh_export_batch_pdf(cache_dir, output,
                     ids = NULL,          # manifest: exactly these pages (D8)
                     order_by = c("staged", "ids"),
                     pages_per_chunk = NULL,
                     skip_invalid = FALSE,
                     font_path = NULL,
                     ignore_system_fonts = TRUE,
                     inject_assets = NULL,
                     restrict_template = TRUE,
                     template_path = NULL)
# -> invisible output path

bfh_prune_page_cache(cache_dir,
                     keep = NULL,         # delete bundles NOT in keep
                     older_than = NULL,   # or: staged before this POSIXct/Date
                     dry_run = FALSE)
# -> character vector of removed (or would-be removed) ids
```

`bfh_export_*` prefix matches `bfh_export_pdf()` / `bfh_export_png()`;
"stage" matches the vocabulary already used internally (staged template,
staged fonts). AI/RAG analysis parameters are accepted at staging time (that
is when the result object with its data is available), never at compile time.

*Alternative considered:* overloading `bfh_export_pdf(output = NULL,
stage_dir = ...)` — rejected: muddies the single-export contract that the
`pdf-export` spec locks down, and staging has a different return type.

*Alternative considered:* binding staging to `bfh_create_export_session()` —
rejected: the session is ephemeral (tmpdir, finalizer-cleaned) by design,
while the page cache must be persistent and cross-process. The batch compiler
MAY internally use a session-like staged workspace, but the public cache is a
plain directory.

### D3: Bundle IDs are filename-safe; atomicity via stage-and-rename

`id` must match `^[A-Za-z0-9][A-Za-z0-9_-]*$` (validated before any filesystem
use; rejects traversal by construction). Ordering is a numeric `order` key in
`page.rds` — sort by `(order, id)` — so callers can re-stage a single page
without renaming others. Staging writes into `<cache_dir>/.staging-<id>-<pid>/`
and `file.rename()`s into place after both files are complete; on overwrite the
old bundle directory is removed after the rename target is prepared. This makes
concurrent staging from multiple R processes into one cache directory safe
(distinct ids) and prevents half-written bundles from ever being visible to the
compiler.

### D4: Multi-page document via direct `#bfh-diagram(...)` calls

The batch composer generates one `document.typ`:

```typst
#import "bfh-template/bfh-template.typ": bfh-diagram

#bfh-diagram(<params page 1>)[<chart 1>]
#bfh-diagram(<params page 2>)[<chart 2>]
...
```

Implementation refactor: extract the per-page parameter-block rendering from
`build_typst_content()` into an internal `build_typst_page_call()` used by both
the existing single-page `#show`-based path (unchanged output) and the new
batch composer. All existing escaping and injection guards
(`escape_typst_string()`, numeric-type validation of `spc_stats`) run per page.
Chart SVGs are copied into the compile workspace under their bundle id
(`charts/<id>.svg`) to avoid basename collisions.

The template's internal `set page(...)`/`set text(...)` rules are scoped to
each function call; repeated calls start on fresh pages (a `#pagebreak(weak:
true)` between calls is added if verification shows trailing-content edge
cases). Verifying identical single-page output between the `#show` path and a
one-page direct-call batch is an explicit task (vdiffr-style PDF smoke
comparison on CI fallback fonts).

*Alternative considered:* concatenating N generated single-page documents with
`#include` — rejected: `#show`-based files are whole-document templates and
would conflict; direct calls are the intended Typst composition model.

### D5: Template assets staged once per batch compile

`bfh_export_batch_pdf()` creates one temp workspace, stages the packaged
template once (session cache reuse via `.get_or_stage_template_cache()`), runs
`inject_assets` once, resolves `font_path`/logo auto-detect once, then writes
`document.typ` and calls `bfh_compile_typst()`. This mirrors what
`bfh_create_export_session()` already does for per-export staging, so the
existing helpers (`prepare_temp_workspace()`, `skip_template_copy = TRUE`
branch of `bfh_create_typst_document()`) are reusable with minor generalization.

### D6: Chunking concatenates with the qpdf package (Suggests)

When `pages_per_chunk` is set and exceeded, compile ceil(N/chunk) documents in
the same workspace and concatenate with `qpdf::pdf_combine()`. `qpdf` goes in
`Suggests` with an `rlang::check_installed()` gate — only callers who opt into
chunking need it, keeping zero new hard dependencies. Font subsets in the final
PDF are then bounded by chunk count. Intermediate chunk PDFs live in the batch
temp workspace and are removed by the existing on.exit cleanup.

*Alternative considered:* shelling out to a system `qpdf`/`gs` binary —
rejected: unmanaged external dependency and shell-quoting surface; the qpdf R
package bundles libqpdf with no system requirement.

*Alternative considered:* making chunking automatic above a page threshold —
rejected for v1: silent behavior changes in font-subset count are hard to
reason about; an explicit parameter with a documented recommendation
(200–500 pages/chunk if memory becomes an issue) is predictable.

### D7: Cache format version is a package constant

`BATCH_CACHE_FORMAT_VERSION <- 1L` (in `R/globals.R`), written into every
`page.rds` and checked by the compiler with an error naming bundle id, found
version, supported version, and the re-stage remedy. Bump the constant whenever
the bundle contract changes shape.

### D8: The manifest, not the cache, is the source of truth for inclusion

A persistent cache accumulates: pages staged last week for charts that have
since been retired would silently reappear in every future combined PDF if
"compile everything in the directory" were the only mode. The `ids` manifest
inverts the relationship: the caller derives the authoritative page list from
their production data source each run and passes it to
`bfh_export_batch_pdf()`; the cache is merely a materialization layer. Strict
semantics make drift visible in both directions — a manifest id without a
bundle is an error (the caller forgot to stage or mistyped), a bundle without a
manifest entry is silently excluded (retired charts need no cleanup before
compiling). The recommended workflow becomes:

```r
ids <- production_chart_ids()                 # caller's source of truth
for (id in ids_needing_restaging) {           # new or corrected charts only
  bfh_stage_pdf_page(result_for(id), cache_dir, id = id)
}
bfh_export_batch_pdf(cache_dir, "samlet.pdf", ids = ids)
```

Corrected charts are handled by re-staging under the same id (atomic overwrite
per D3); untouched charts are reused from the cache with zero recomputation.
`order_by = "ids"` lets the manifest double as page ordering; the default keeps
the staged `order` keys so a partial re-stage cannot reshuffle the document.

*Alternative considered:* freshness filters (`max_age` / staged-after cutoffs)
as the primary staleness mechanism — rejected: age is a proxy, not truth; an
old-but-current chart would be dropped and a freshly staged retired chart kept.
Age-based cleanup exists only in the pruning helper (D9), where it is an
explicit maintenance action.

*Alternative considered:* compiler-side content hashing (stage-if-changed
convenience that skips re-rendering unchanged charts) — deferred: it optimizes
staging cost, not correctness, and requires hashing input data + config with
stable semantics across versions. Additive later; noted under Open Questions.

### D9: Cache pruning is an explicit, separate helper

`bfh_prune_page_cache()` deletes bundles by keep-list (typically the same
manifest vector) or by `older_than` staging timestamp (`created_at` in
`page.rds`), with `dry_run = TRUE` for inspection. Pruning is deliberately NOT
folded into `bfh_export_batch_pdf()` (no `prune = TRUE` argument): compiling a
subset is a read operation and deleting data is a destructive one, and coupling
them means a typo in a manifest both breaks the document AND destroys staged
work. Only directories that validate as page bundles are candidates — foreign
files in the cache directory are never touched. Identifier validation (D3
regex) applies to keep-list entries before any filesystem match.

*Alternative considered:* automatic garbage collection (delete bundles not
compiled in N days) — rejected: implicit deletion in a package that renders
clinical quality reports is a footgun; the two explicit selectors cover the
"udgaaede grafer" case predictably.

## Risks / Trade-offs

- [Typst compile time/memory at ~1,800 svglite SVGs in one document] →
  `pages_per_chunk` safety valve (D6); tasks include a synthetic 1,000+-page
  benchmark on CI fallback fonts before release notes recommend a default.
- [Direct-call rendering differs subtly from `#show`-based rendering (page
  margins, trailing whitespace)] → explicit equivalence verification task
  (single staged page vs `bfh_export_pdf()` output); fix with `pagebreak(weak:
  true)` and/or scoped set-rules in the composer, not by editing per-page
  template content.
- [RDS deserialization from a user-controlled directory] → same trust model as
  `template_path`, documented in roxygen + `vignettes/safe-exports.Rmd`;
  bundles contain plain data only, and compile-side type guards
  (`spc_stats` numeric checks, `escape_typst_string()`) still run per page, so
  a tampered bundle degrades to a Typst compile error, not code execution.
  Residual risk: RDS can technically encode promises/closures — mitigated by
  validating the deserialized object is a plain list of expected types before
  use.
- [Concurrent staging of the SAME id from two processes] → last rename wins;
  documented. Cross-process locking is out of scope.
- [Metadata staged today, template improved tomorrow: batch output reflects
  compile-time template + staged data] → documented as intended semantics;
  format version (D7) guards the structural contract, not cosmetic template
  evolution.
- [Disk footprint of the cache (~100–350 MB at 1,800 pages)] → user-managed
  directory; `bfh_prune_page_cache()` (keep-list or age) plus docs on
  measuring/clearing it.
- [Manifest typo excludes a wanted page silently (unlisted = ignored)] →
  missing-id direction is strict (error), and docs recommend deriving `ids`
  programmatically from the production source, never hand-typing; `dry_run`
  pruning against the same vector reveals what the manifest excludes.

## Migration Plan

Additive feature — no migration. Rollout: implement behind no flag, document in
`NEWS.md`, `devtools::document()` for NAMESPACE. biSPCharts adoption is
optional and coordinated via an `enhancement`-labelled issue after merge.
Rollback = removing the two exports before any release ships them.

## Benchmark (task 4.3, run 2026-08-28, Linux container, fallback fonts)

500-page batch (replicated bundle, real Quarto/Typst pipeline):
compile 5.4 s, output 5.1 MB, 2 embedded font objects in total; staging one
real chart 0.8 s; single `bfh_export_pdf()` 1.2 s and 27 KB, i.e. a naive
500-file merge would be ~13.6 MB even with small fallback-font subsets.
Extrapolated 1,800 pages: ~20 s single compile. Conclusion: chunking is not
needed for correctness or speed at the target scale; document
`pages_per_chunk` as an opt-in memory safety valve (suggest 250-500 per
chunk) rather than a default.

## Open Questions
- Whether a stage-if-changed convenience (content hash of data + config in the
  bundle, skipping re-render when unchanged) is worth adding for callers who
  re-stage everything defensively — deferable, additive (see D8).
