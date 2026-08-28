# Tasks: add-batch-pdf-export

## 1. Refactor shared Typst composition helpers

- [x] 1.1 Extract per-page parameter rendering from `build_typst_content()`
      into internal `build_typst_page_call()` (emits one `#bfh-diagram(...)`
      call incl. escaping + spc_stats type guards); verify all existing
      `tests/testthat/test-*typst*` and pdf-export tests pass unchanged.
- [x] 1.2 Generalize workspace/template staging so a batch workspace can stage
      the template once and reuse it (`skip_template_copy = TRUE` path,
      `inject_assets` run once, logo/font auto-detect factored to run per
      workspace instead of per document); verify single-export behavior is
      byte-identical via existing tests plus a targeted regression test.

## 2. Page staging (`bfh_stage_pdf_page()`)

- [x] 2.1 Add `BATCH_CACHE_FORMAT_VERSION <- 1L` to `R/globals.R` and create
      `R/export_batch.R` with `bfh_stage_pdf_page()` running validate →
      `prepare_export_metadata()` → `prepare_export_plot()` →
      `export_chart_svg()` → `bfh_extract_spc_stats()` and writing
      `chart.svg` + `page.rds` (format_version, id, order, metadata,
      spc_stats, template, created_at, bfhcharts_version); verify a unit test
      stages a bundle and round-trips `page.rds` contents.
- [x] 2.2 Implement id validation (`^[A-Za-z0-9][A-Za-z0-9_-]*$`), default id
      (zero-padded next index) and default order (staging sequence); verify
      tests reject `../evil`, path separators, metachars, and confirm default
      id/order sequencing.
- [x] 2.3 Implement atomic stage-and-rename (`.staging-<id>-<pid>` → bundle
      dir) with `overwrite` semantics; verify tests: interrupted staging
      leaves no visible bundle, overwrite replaces cleanly, `overwrite =
      FALSE` errors on duplicate id.
- [x] 2.4 Input validation errors as classed `bfhcharts_export_error` for
      non-result `x`, missing/unwritable `cache_dir`; verify tests assert
      error class and argument naming.

## 3. Batch compile (`bfh_export_batch_pdf()`)

- [x] 3.1 Implement bundle discovery + validation: read `page.rds` files,
      check format version, plain-list type validation, presence of
      `chart.svg`; sort by `(order, id)`; verify unit tests cover empty cache
      error, corrupt bundle error naming the bundle, unsupported version error
      naming versions and remedy, and `skip_invalid = TRUE` warning listing
      skipped ids.
- [x] 3.2 Implement batch document composition: stage template once, copy
      SVGs to `charts/<id>.svg`, emit one `document.typ` with N
      `build_typst_page_call()` invocations; verify a unit test snapshot of
      the generated .typ for 3 bundles (deterministic order, correct relative
      paths, escaping applied).
- [x] 3.3 Wire compilation through `bfh_compile_typst()` with
      `font_path`/`ignore_system_fonts`/`inject_assets`/`restrict_template`/
      `template_path` semantics matching `bfh_export_pdf()`; verify tests:
      custom `template_path` under `restrict_template = TRUE` raises the same
      classed error, and (smoke, CI fallback fonts) a 3-page batch compiles to
      a 3-page PDF.
- [x] 3.4 Implement manifest selection (`ids` + `order_by`): exact inclusion,
      error listing ALL missing ids before compilation, silent exclusion of
      unlisted bundles, `order_by = "ids"` ordering; verify tests cover the
      retired-chart exclusion scenario, missing-id error, re-staged corrected
      page appearing with updated content alongside untouched pages, and both
      ordering modes.
- [x] 3.5 Implement `pages_per_chunk` chunked compile + `qpdf::pdf_combine()`
      concatenation (qpdf added to `Suggests`, `rlang::check_installed()`
      gate); verify tests: chunked run produces same page count/order as
      single compile, intermediates removed on success and on simulated error,
      helpful error when qpdf is absent.

- [x] 3.6 Implement `bfh_prune_page_cache()` (keep-list, `older_than` on
      `created_at`, `dry_run`, id validation on keep-list entries, bundle-only
      deletion); verify tests: keep-list prune, age prune, dry run deletes
      nothing and lists candidates, foreign files in cache_dir untouched,
      return value contains removed ids.

## 4. Equivalence, fonts, and scale verification

- [x] 4.1 Rendering-equivalence check: stage one chart and batch-compile vs
      `bfh_export_pdf()` on the same result (CI fallback fonts); verify page
      count, page size, and text content match (pdftools text extraction or
      existing smoke harness); add `pagebreak(weak: true)` handling if the
      comparison reveals layout drift.
- [x] 4.2 Font-embedding assertion: batch-compile >= 2 pages and verify via
      `pdffonts`/pdftools that each face appears at most once (and at most
      chunk-count times in a chunked run); skip on runners without the
      tooling.
- [x] 4.3 Scale benchmark (manual/nightly, not PR-blocking): synthetic
      500–1,000 page batch on CI fallback fonts measuring compile time, peak
      memory, and output size; record results in the change notes and derive
      the documented `pages_per_chunk` recommendation.

## 5. Documentation and package hygiene

- [x] 5.1 Roxygen for all three exports (trust model of cache_dir, ordering
      semantics, manifest-as-source-of-truth workflow, chunking guidance,
      cross-refs to `bfh_export_pdf()` / `bfh_create_export_session()`), run
      `devtools::document()`; verify NAMESPACE gains exactly the three new
      exports and `R CMD check` documentation checks pass.
- [x] 5.2 Update `vignettes/safe-exports.Rmd` (cache trust model) and add a
      batch-report section to the export vignette/README with an end-to-end
      example (stage new/corrected pages → `bfh_export_batch_pdf(ids = ...)`
      → optional `bfh_prune_page_cache(keep = ids)`); verify vignette builds
      via `devtools::build_vignettes()`.
- [x] 5.3 Add `NEWS.md` entry describing the new capability and the
      font-embedding motivation; verify entry present under the dev version
      heading.
- [x] 5.4 ASCII policy + coverage: verify `tests/testthat/test-source-ascii.R`
      passes for new files and coverage on the two new exports is 100%
      (`covr::package_coverage()`); run full `devtools::test()` +
      `devtools::check()` clean.
