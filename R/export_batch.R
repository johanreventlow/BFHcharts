# ============================================================================
# BATCH PDF EXPORT
#
# Staging of per-chart "page bundles" (chart SVG + serialized metadata/stats)
# into a persistent, caller-owned cache directory, plus single-compile
# assembly of a multi-page PDF from staged bundles. One Typst compilation
# embeds each font face exactly once, eliminating the duplicated font
# subsets that arise when hundreds of single-chart PDFs are merged with
# external tools.
#
# See openspec: batch-pdf-export capability for the behavior contract.
# ============================================================================

#' Stage a Chart as a Page Bundle for Batch PDF Export
#'
#' Renders one \code{bfh_qic_result} into a persistent "page bundle" in
#' \code{cache_dir}, performing the same chart preparation as
#' \code{\link{bfh_export_pdf}} (metadata finalization, title strip, label
#' recalculation, SVG rendering, SPC stats extraction) but producing no PDF.
#' Staged bundles are later assembled into one multi-page PDF by
#' \code{\link{bfh_export_batch_pdf}}.
#'
#' A bundle consists of the rendered chart SVG plus a serialized data file
#' (\code{page.rds}) holding finalized template metadata, extracted SPC
#' statistics, the template selection, an ordering key, and a cache format
#' version. No SPC statistics are recomputed and no ggplot objects are
#' serialized, so bundles remain readable across ggplot2/BFHtheme upgrades.
#'
#' Staging is atomic: the bundle is written to a hidden staging directory and
#' renamed into place, so a failed or interrupted staging never leaves a
#' half-written bundle visible to \code{bfh_export_batch_pdf()}. Re-staging
#' an existing \code{id} (with \code{overwrite = TRUE}, the default) replaces
#' the bundle atomically -- the supported way to correct individual pages
#' before recompiling a combined report.
#'
#' @section Trust model:
#' The cache directory is trusted input: bundles are deserialized (RDS) in
#' the calling R session by \code{bfh_export_batch_pdf()}. Never populate a
#' cache directory from untrusted sources, and do not point \code{cache_dir}
#' at world-writable locations in multi-tenant deployments.
#'
#' @param x A \code{bfh_qic_result} object from \code{\link{bfh_qic}}.
#' @param cache_dir Existing, writable directory holding the page cache.
#'   Persistent and caller-owned: bundles survive R sessions and processes.
#' @param id Bundle identifier (single string matching
#'   \code{^[A-Za-z0-9][A-Za-z0-9_-]*$}; it becomes a directory name).
#'   Default: a zero-padded sequence id (\code{"page-0001"}, ...) one past
#'   the highest existing default id in the cache.
#' @param order Numeric ordering key for page sorting at compile time
#'   (ties broken by \code{id}). Default: one past the highest order
#'   currently staged in the cache (staging sequence).
#' @param metadata Named list of template metadata, same fields as
#'   \code{\link{bfh_export_pdf}} (hospital, department, analysis, ...).
#' @param template Typst template function name (default \code{"bfh-diagram"}).
#'   All bundles compiled into one document must share the same template.
#' @param auto_analysis,use_ai,data_consent,use_rag,analysis_min_chars,analysis_max_chars
#'   Auto-generated analysis controls, identical to
#'   \code{\link{bfh_export_pdf}}. AI/RAG analysis runs at staging time (the
#'   chart data is available here), never at batch compile time.
#' @param dpi Resolution passed to the SVG device (default 150).
#' @param overwrite Logical. Replace an existing bundle with this \code{id}
#'   (default TRUE). \code{FALSE} raises an error on duplicate ids.
#' @param strict_baseline Logical. Same baseline validation as
#'   \code{\link{bfh_export_pdf}}; default TRUE.
#'
#' @return Invisibly, a \code{bfh_staged_page} object: a list with
#'   \code{id}, \code{path} (bundle directory), and \code{order}.
#'
#' @examples
#' \dontrun{
#' cache_dir <- "~/reports/spc-cache"
#' dir.create(cache_dir, showWarnings = FALSE)
#' result <- bfh_qic(data, x = date, y = value, chart_type = "p")
#' bfh_stage_pdf_page(result, cache_dir,
#'   id = "afd-a-infektioner",
#'   metadata = list(department = "Afdeling A")
#' )
#' }
#'
#' @export
#' @family export-functions
#' @seealso [bfh_export_batch_pdf()] to compile staged bundles,
#'   [bfh_prune_page_cache()] to remove stale bundles,
#'   [bfh_export_pdf()] for single-chart export.
bfh_stage_pdf_page <- function(x, cache_dir,
                               id = NULL,
                               order = NULL,
                               metadata = list(),
                               template = "bfh-diagram",
                               auto_analysis = FALSE,
                               use_ai = FALSE,
                               data_consent = NULL,
                               use_rag = FALSE,
                               analysis_min_chars = 300,
                               analysis_max_chars = 375,
                               dpi = 150,
                               overwrite = TRUE,
                               strict_baseline = TRUE) {
  # ---- 1. Input validation ---------------------------------------------------
  if (!inherits(x, "bfh_qic_result")) {
    bfh_abort(
      paste0(
        "x must be a bfh_qic_result object from bfh_qic().\n",
        "  Got class: ", paste(class(x), collapse = ", ")
      ),
      class = "bfhcharts_export_error"
    )
  }
  cache_dir <- .validate_cache_dir(cache_dir, require_writable = TRUE)
  if (!is.list(metadata)) {
    bfh_abort("metadata must be a list", class = "bfhcharts_export_error")
  }
  if (!is.numeric(dpi) || length(dpi) != 1L || is.na(dpi) || dpi <= 0) {
    bfh_abort("dpi must be a single positive number",
      class = "bfhcharts_export_error"
    )
  }
  if (!is.character(template) || length(template) != 1L ||
    !grepl("^[a-zA-Z][a-zA-Z0-9_-]*$", template)) {
    bfh_abort(
      "template must be a valid Typst identifier (letters, numbers, hyphens, underscores)",
      class = "bfhcharts_export_error"
    )
  }
  if (!is.logical(overwrite) || length(overwrite) != 1L || is.na(overwrite)) {
    bfh_abort("overwrite must be TRUE or FALSE", class = "bfhcharts_export_error")
  }
  if (!is.logical(strict_baseline) || length(strict_baseline) != 1L ||
    is.na(strict_baseline)) {
    bfh_abort("strict_baseline must be TRUE or FALSE",
      class = "bfhcharts_export_error"
    )
  }
  .validate_strict_baseline(x, strict_baseline)

  # ---- 2. Resolve id + order -------------------------------------------------
  existing <- .list_bundle_ids(cache_dir)
  if (is.null(id)) {
    id <- .next_default_page_id(existing)
  }
  .validate_page_id(id)
  target <- file.path(cache_dir, id)
  if (dir.exists(target) && !overwrite) {
    bfh_abort(
      paste0(
        "A page bundle with id '", id, "' already exists in the cache.\n",
        "  Pass overwrite = TRUE to replace it, or choose another id."
      ),
      class = "bfhcharts_export_error"
    )
  }
  if (is.null(order)) {
    order <- .next_default_order(cache_dir, existing)
  }
  if (!is.numeric(order) || length(order) != 1L || is.na(order)) {
    bfh_abort("order must be a single non-NA number",
      class = "bfhcharts_export_error"
    )
  }
  order <- as.numeric(order)

  # ---- 3. Finalize metadata + stats (same pipeline as bfh_export_pdf) --------
  metadata <- prepare_export_metadata(
    x, metadata, auto_analysis, use_ai, analysis_min_chars, analysis_max_chars,
    data_consent = data_consent, use_rag = use_rag
  )
  chart_title <- x$config$chart_title
  if (is.null(chart_title)) chart_title <- ""
  metadata_full <- bfh_merge_metadata(metadata, chart_title)
  spc_stats <- bfh_extract_spc_stats(x)

  # Resolve centerline-caveat text server-side (mirrors
  # compose_typst_document(); the bundle must carry the final string since
  # the result object is gone at compile time).
  caveat_lang <- x$config$language %||% "da"
  if (isTRUE(spc_stats$cl_user_supplied)) {
    metadata_full$cl_caveat_text <- i18n_lookup(
      "labels.caveats.cl_user_supplied", caveat_lang
    )
  } else if (isTRUE(spc_stats$cl_auto_mean)) {
    metadata_full$cl_caveat_text <- i18n_lookup(
      "labels.caveats.cl_auto_mean", caveat_lang
    )
  }

  # ---- 4. Render chart SVG into a hidden staging dir -------------------------
  staging <- file.path(
    cache_dir, sprintf(".staging-%s-%d", id, Sys.getpid())
  )
  if (dir.exists(staging)) unlink(staging, recursive = TRUE)
  dir.create(staging, recursive = TRUE, mode = "0700")
  on.exit(
    if (dir.exists(staging)) unlink(staging, recursive = TRUE),
    add = TRUE
  )

  plot_for_export <- prepare_export_plot(x)
  export_chart_svg(plot_for_export, file.path(staging, "chart.svg"), dpi)

  bundle <- list(
    format_version = BATCH_CACHE_FORMAT_VERSION,
    id = id,
    order = order,
    metadata = metadata_full,
    spc_stats = spc_stats,
    template = template,
    created_at = Sys.time(),
    bfhcharts_version = as.character(utils::packageVersion("BFHcharts"))
  )
  saveRDS(bundle, file.path(staging, "page.rds"))

  # ---- 5. Atomic rename into place ------------------------------------------
  backup <- NULL
  if (dir.exists(target)) {
    backup <- file.path(cache_dir, sprintf(".replaced-%s-%d", id, Sys.getpid()))
    if (dir.exists(backup)) unlink(backup, recursive = TRUE)
    if (!file.rename(target, backup)) {
      bfh_abort(
        paste0("Failed to displace existing bundle for overwrite: id '", id, "'"),
        class = "bfhcharts_export_error"
      )
    }
  }
  if (!file.rename(staging, target)) {
    # Restore the previous bundle so overwrite failure is not destructive.
    if (!is.null(backup) && dir.exists(backup)) file.rename(backup, target)
    bfh_abort(
      paste0("Failed to move staged bundle into place: id '", id, "'"),
      class = "bfhcharts_export_error"
    )
  }
  if (!is.null(backup) && dir.exists(backup)) unlink(backup, recursive = TRUE)

  invisible(structure(
    list(id = id, path = target, order = order),
    class = "bfh_staged_page"
  ))
}


#' @export
print.bfh_staged_page <- function(x, ...) {
  cat(sprintf(
    "<bfh_staged_page> id: %s (order %s)\n  %s\n",
    x$id, format(x$order), x$path
  ))
  invisible(x)
}


#' Compile Staged Page Bundles into One Multi-Page PDF
#'
#' Reads page bundles staged by \code{\link{bfh_stage_pdf_page}} from
#' \code{cache_dir} and compiles them into a single multi-page PDF through
#' ONE Typst compilation (or a bounded number of chunked compilations, see
#' \code{pages_per_chunk}). Each required font face is embedded at most once
#' per compilation -- the reason to prefer this over merging single-chart
#' PDFs with external tools, which duplicates embedded font subsets per page.
#'
#' @section The manifest is the source of truth:
#' A persistent cache accumulates bundles, including pages for charts that
#' have since been retired. Pass \code{ids} -- derived programmatically from
#' your production data source, not hand-typed -- to make the document
#' contain exactly those pages: an id without a bundle is an error (listing
#' every missing id), and bundles not named are silently excluded. Without
#' \code{ids}, all valid bundles in the cache are compiled.
#'
#' Typical workflow:
#' \preformatted{
#' ids <- production_chart_ids()          # caller's source of truth
#' for (id in ids_needing_restaging) {    # new or corrected charts only
#'   bfh_stage_pdf_page(result_for(id), cache_dir, id = id)
#' }
#' bfh_export_batch_pdf(cache_dir, "combined.pdf", ids = ids)
#' }
#'
#' @param cache_dir Directory holding page bundles staged by
#'   \code{\link{bfh_stage_pdf_page}}. Trusted input; see that function's
#'   trust-model section.
#' @param output Output PDF path.
#' @param ids Optional character vector of bundle ids (the manifest). When
#'   supplied, the document contains exactly these pages. Default NULL
#'   compiles every valid bundle in the cache.
#' @param order_by \code{"staged"} (default) sorts pages by their staged
#'   \code{order} keys (ties broken by id) so a partial re-stage cannot
#'   reshuffle the document; \code{"ids"} orders pages by manifest position
#'   (requires \code{ids}).
#' @param pages_per_chunk Optional positive integer. When set and exceeded,
#'   compilation runs in chunks of at most this many pages and the chunk
#'   PDFs are concatenated (requires the \code{qpdf} package). Font subsets
#'   in the final document are then bounded by the number of chunks. Default
#'   NULL compiles everything in a single Typst run.
#' @param skip_invalid Logical. When TRUE, unreadable/incomplete bundles are
#'   skipped with a warning listing each skipped id; when FALSE (default)
#'   any invalid bundle aborts the export before a PDF is written.
#' @param font_path,ignore_system_fonts,inject_assets,restrict_template,template_path
#'   Same semantics as \code{\link{bfh_export_pdf}}. Template staging and
#'   \code{inject_assets} run once per batch compile, not once per page.
#'
#' @return Invisibly, the output path.
#'
#' @examples
#' \dontrun{
#' bfh_export_batch_pdf("~/reports/spc-cache", "samlet.pdf",
#'   ids = c("afd-a-infektioner", "afd-b-tryksaar")
#' )
#' }
#'
#' @export
#' @family export-functions
#' @seealso [bfh_stage_pdf_page()], [bfh_prune_page_cache()],
#'   [bfh_export_pdf()]
bfh_export_batch_pdf <- function(cache_dir, output,
                                 ids = NULL,
                                 order_by = c("staged", "ids"),
                                 pages_per_chunk = NULL,
                                 skip_invalid = FALSE,
                                 font_path = NULL,
                                 ignore_system_fonts = TRUE,
                                 inject_assets = NULL,
                                 restrict_template = TRUE,
                                 template_path = NULL) {
  rlang::check_installed(
    c("commonmark", "xml2"),
    reason = "for PDF/Typst export (markdown rendering in document fields)"
  )
  order_by <- match.arg(order_by)

  # ---- 1. restrict_template guard (same threat model as bfh_export_pdf) -----
  if (!is.logical(restrict_template) || length(restrict_template) != 1L ||
    is.na(restrict_template)) {
    bfh_abort(
      paste0(
        "restrict_template must be TRUE or FALSE (single non-NA logical)",
        "\n  Got: ", paste(class(restrict_template), collapse = "/"),
        " (length ", length(restrict_template), ")"
      ),
      class = "bfhcharts_export_error"
    )
  }
  if (restrict_template && !is.null(template_path)) {
    bfh_abort(
      paste0(
        "template_path is not allowed when restrict_template = TRUE.",
        "\n  Only the packaged BFHcharts template may be used in this configuration.",
        "\n  To opt in to a trusted custom Typst template, pass",
        " restrict_template = FALSE explicitly.",
        "\n  WARNING: custom templates are compiled with full filesystem access",
        " (equivalent to source()) -- never forward user-supplied input to",
        " template_path."
      ),
      class = "bfhcharts_export_error"
    )
  }

  # ---- 2. Input validation ---------------------------------------------------
  cache_dir <- .validate_cache_dir(cache_dir, require_writable = FALSE)
  validate_export_path(output, extension = "pdf", ext_action = "warn")
  .validate_inject_assets(inject_assets)
  template_path <- validate_template_path(template_path)
  if (!is.null(ids)) {
    if (!is.character(ids) || length(ids) == 0L || anyNA(ids)) {
      bfh_abort("ids must be a non-empty character vector without NA",
        class = "bfhcharts_export_error"
      )
    }
    for (one_id in unique(ids)) .validate_page_id(one_id)
    ids <- unique(ids)
  }
  if (order_by == "ids" && is.null(ids)) {
    bfh_abort("order_by = \"ids\" requires the ids manifest",
      class = "bfhcharts_export_error"
    )
  }
  if (!is.null(pages_per_chunk)) {
    if (!is.numeric(pages_per_chunk) || length(pages_per_chunk) != 1L ||
      is.na(pages_per_chunk) || pages_per_chunk < 1) {
      bfh_abort("pages_per_chunk must be a single positive number or NULL",
        class = "bfhcharts_export_error"
      )
    }
    pages_per_chunk <- as.integer(pages_per_chunk)
  }
  # ---- 3. Discover + validate bundles ----------------------------------------
  bundles <- .read_page_bundles(cache_dir, skip_invalid = skip_invalid)

  # ---- 4. Manifest selection + ordering --------------------------------------
  if (!is.null(ids)) {
    missing_ids <- setdiff(ids, names(bundles))
    if (length(missing_ids) > 0L) {
      bfh_abort(
        paste0(
          "Manifest ids without a staged bundle in the cache:\n",
          paste0("  - ", missing_ids, collapse = "\n"), "\n",
          "  Stage the missing pages with bfh_stage_pdf_page() and retry."
        ),
        class = "bfhcharts_export_error"
      )
    }
    bundles <- bundles[ids]
  }
  if (length(bundles) == 0L) {
    bfh_abort(
      paste0(
        "No staged page bundles found in cache directory.\n",
        "  Stage pages with bfh_stage_pdf_page() before compiling."
      ),
      class = "bfhcharts_export_error"
    )
  }
  if (order_by == "staged") {
    orders <- vapply(bundles, function(b) b$order, numeric(1))
    bundles <- bundles[order(orders, names(bundles))]
  }
  # order_by == "ids": bundles[ids] above already fixed manifest order.

  # All pages must target the same template function (one import line).
  templates <- unique(vapply(bundles, function(b) b$template, character(1)))
  if (length(templates) != 1L) {
    bfh_abort(
      paste0(
        "Staged bundles use different templates (",
        paste(templates, collapse = ", "),
        "); a batch document must use exactly one."
      ),
      class = "bfhcharts_export_error"
    )
  }
  template <- templates[[1L]]

  # Quarto check runs after bundle/manifest validation so callers get the
  # actionable staging errors first even on machines without Quarto.
  if (!quarto_available()) {
    bfh_abort(
      paste0(
        "Quarto CLI not found or version too old. PDF export requires Quarto >= 1.4.0.\n",
        "  Install or update from: https://quarto.org\n",
        "  After installation, restart R and try again.\n",
        "  Typst support was added in Quarto 1.4."
      ),
      class = "bfhcharts_export_error"
    )
  }

  # ---- 5. Batch workspace + template staging (once) --------------------------
  temp_dir <- tempfile("bfh_batch_pdf_")
  dir.create(temp_dir, recursive = TRUE, mode = "0700")
  Sys.chmod(temp_dir, mode = "0700", use_umask = FALSE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  effective_font_path <- font_path
  detected_logo <- NULL
  if (is.null(template_path)) {
    .stage_packaged_template_dir(temp_dir, skip_copy = FALSE)
    if (is.function(inject_assets)) {
      inject_assets(file.path(temp_dir, "bfh-template"))
      if (is.null(effective_font_path)) {
        injected_fonts <- file.path(temp_dir, "bfh-template", "fonts")
        if (dir.exists(injected_fonts)) {
          effective_font_path <- injected_fonts
        }
      }
    }
    # Logo auto-detect relative to a .typ file in temp_dir (all chunk
    # documents live there).
    detected_logo <- .detect_packaged_logo(file.path(temp_dir, "document.typ"))
    template_file <- "bfh-template/bfh-template.typ"
  } else {
    template_basename <- basename(template_path)
    if (!file.copy(template_path, file.path(temp_dir, template_basename),
      overwrite = TRUE
    )) {
      bfh_abort("Failed to copy custom template to batch workspace.",
        class = "bfhcharts_export_error"
      )
    }
    template_file <- template_basename
  }

  # ---- 6. Copy chart SVGs into the workspace ---------------------------------
  charts_dir <- file.path(temp_dir, "charts")
  dir.create(charts_dir)
  for (id in names(bundles)) {
    src <- file.path(cache_dir, id, "chart.svg")
    src_norm <- normalizePath(src, mustWork = TRUE)
    validate_export_path(src_norm)
    if (!file.copy(src_norm, file.path(charts_dir, paste0(id, ".svg")))) {
      bfh_abort(
        paste0("Failed to copy chart SVG for bundle '", id, "' into workspace."),
        class = "bfhcharts_export_error"
      )
    }
  }

  # ---- 7. Compose + compile (single run or chunks) ---------------------------
  n_pages <- length(bundles)
  chunk_starts <- if (is.null(pages_per_chunk) || n_pages <= pages_per_chunk) {
    1L
  } else {
    seq.int(1L, n_pages, by = pages_per_chunk)
  }
  n_chunks <- length(chunk_starts)
  if (n_chunks > 1L) {
    rlang::check_installed("qpdf",
      reason = "to concatenate chunked batch PDF output (pages_per_chunk)"
    )
  }

  chunk_outputs <- character(0)
  for (chunk_i in seq_len(n_chunks)) {
    from <- chunk_starts[[chunk_i]]
    to <- min(from + (pages_per_chunk %||% n_pages) - 1L, n_pages)
    chunk_bundles <- bundles[from:to]

    content <- c(
      sprintf(
        '#import "%s": %s',
        escape_typst_string(template_file), template
      ),
      ""
    )
    first <- TRUE
    for (id in names(chunk_bundles)) {
      b <- chunk_bundles[[id]]
      page_metadata <- b$metadata
      if (is.null(page_metadata$logo_path) && !is.null(detected_logo)) {
        page_metadata$logo_path <- detected_logo
      }
      if (!first) {
        content <- c(content, "", "#pagebreak(weak: true)", "")
      }
      first <- FALSE
      content <- c(
        content,
        build_typst_page_call(
          chart_image = paste0("charts/", id, ".svg"),
          metadata = page_metadata,
          spc_stats = b$spc_stats,
          template = template
        )
      )
    }

    typst_file <- file.path(temp_dir, sprintf("document-%03d.typ", chunk_i))
    writeLines(content, typst_file)

    chunk_pdf <- if (n_chunks == 1L) {
      output
    } else {
      file.path(temp_dir, sprintf("chunk-%03d.pdf", chunk_i))
    }
    bfh_compile_typst(
      typst_file, chunk_pdf,
      font_path = effective_font_path,
      ignore_system_fonts = ignore_system_fonts
    )
    chunk_outputs <- c(chunk_outputs, chunk_pdf)
  }

  if (n_chunks > 1L) {
    qpdf::pdf_combine(chunk_outputs, output = output)
  }
  # Chunk intermediates and documents are removed with temp_dir by on.exit.

  invisible(output)
}


#' Prune Page Bundles from a Batch Export Cache
#'
#' Removes page bundles staged by \code{\link{bfh_stage_pdf_page}} from
#' \code{cache_dir}, selected either by an explicit keep-list (delete every
#' bundle NOT named -- typically the same manifest vector passed to
#' \code{\link{bfh_export_batch_pdf}}) or by staging age (delete bundles
#' staged before a cutoff). Exactly one selector must be supplied.
#'
#' Pruning is deliberately separate from compilation: compiling a subset via
#' the \code{ids} manifest is a read operation, while pruning deletes data.
#' Only directories that look like page bundles (containing \code{page.rds})
#' are candidates; other files in the cache directory are never touched.
#'
#' @param cache_dir The page cache directory.
#' @param keep Character vector of bundle ids to keep; every other bundle is
#'   removed. Mutually exclusive with \code{older_than}.
#' @param older_than A \code{Date}/\code{POSIXct} (or string coercible to
#'   one): bundles staged before this time are removed. Bundles whose
#'   staging time cannot be read are skipped with a warning, never deleted.
#'   Mutually exclusive with \code{keep}.
#' @param dry_run Logical. When TRUE, nothing is deleted; the return value
#'   lists the bundles that WOULD be removed. Default FALSE.
#'
#' @return Character vector of removed (or, under \code{dry_run}, would-be
#'   removed) bundle ids, sorted.
#'
#' @examples
#' \dontrun{
#' ids <- production_chart_ids()
#' # Inspect first, then delete retired bundles:
#' bfh_prune_page_cache("~/reports/spc-cache", keep = ids, dry_run = TRUE)
#' bfh_prune_page_cache("~/reports/spc-cache", keep = ids)
#' }
#'
#' @export
#' @family export-functions
#' @seealso [bfh_stage_pdf_page()], [bfh_export_batch_pdf()]
bfh_prune_page_cache <- function(cache_dir,
                                 keep = NULL,
                                 older_than = NULL,
                                 dry_run = FALSE) {
  cache_dir <- .validate_cache_dir(cache_dir, require_writable = !isTRUE(dry_run))
  if (is.null(keep) == is.null(older_than)) {
    bfh_abort(
      "Supply exactly one of keep or older_than to select bundles for pruning",
      class = "bfhcharts_export_error"
    )
  }
  if (!is.logical(dry_run) || length(dry_run) != 1L || is.na(dry_run)) {
    bfh_abort("dry_run must be TRUE or FALSE", class = "bfhcharts_export_error")
  }

  bundle_ids <- .list_bundle_ids(cache_dir)

  if (!is.null(keep)) {
    if (!is.character(keep) || anyNA(keep)) {
      bfh_abort("keep must be a character vector without NA",
        class = "bfhcharts_export_error"
      )
    }
    for (one_id in unique(keep)) .validate_page_id(one_id)
    to_remove <- setdiff(bundle_ids, keep)
  } else {
    cutoff <- tryCatch(as.POSIXct(older_than), error = function(e) NULL)
    if (is.null(cutoff) || length(cutoff) != 1L || is.na(cutoff)) {
      bfh_abort(
        "older_than must be a single Date/POSIXct (or a string coercible to one)",
        class = "bfhcharts_export_error"
      )
    }
    to_remove <- character(0)
    unreadable <- character(0)
    for (id in bundle_ids) {
      created_at <- tryCatch(
        readRDS(file.path(cache_dir, id, "page.rds"))$created_at,
        error = function(e) NULL
      )
      if (is.null(created_at) || !inherits(created_at, c("POSIXct", "POSIXt"))) {
        unreadable <- c(unreadable, id)
        next
      }
      if (created_at < cutoff) to_remove <- c(to_remove, id)
    }
    if (length(unreadable) > 0L) {
      warning(
        "Skipped bundles with unreadable staging time (not deleted): ",
        paste(unreadable, collapse = ", "),
        call. = FALSE
      )
    }
  }

  to_remove <- sort(to_remove)
  if (!isTRUE(dry_run)) {
    for (id in to_remove) {
      unlink(file.path(cache_dir, id), recursive = TRUE)
    }
  }
  to_remove
}


# ============================================================================
# INTERNAL HELPERS
# ============================================================================

# Validate the cache directory path (traversal + metachar guards, existence,
# and optionally writability). Returns the path unchanged.
.validate_cache_dir <- function(cache_dir, require_writable = TRUE) {
  if (!is.character(cache_dir) || length(cache_dir) != 1L || !nzchar(cache_dir)) {
    bfh_abort("cache_dir must be a single non-empty character string",
      class = "bfhcharts_export_error"
    )
  }
  cache_dir <- path.expand(cache_dir)
  .check_traversal(cache_dir)
  .check_metachars(cache_dir)
  if (!dir.exists(cache_dir)) {
    bfh_abort(
      paste0(
        "cache_dir does not exist: ", .redact_paths(cache_dir), "\n",
        "  Create the directory first; the page cache is caller-owned."
      ),
      class = "bfhcharts_export_error"
    )
  }
  if (require_writable && file.access(cache_dir, mode = 2L) != 0L) {
    bfh_abort(
      paste0("cache_dir is not writable: ", .redact_paths(cache_dir)),
      class = "bfhcharts_export_error"
    )
  }
  cache_dir
}

# Validate one page id against the filename-safe pattern. Rejects path
# separators and traversal by construction.
.validate_page_id <- function(id) {
  if (!is.character(id) || length(id) != 1L || is.na(id) ||
    !grepl(BATCH_PAGE_ID_PATTERN, id)) {
    bfh_abort(
      paste0(
        "Invalid page id: ", if (is.character(id) && length(id) == 1L) id else "<non-string>",
        "\n  Ids must match ", BATCH_PAGE_ID_PATTERN,
        " (letters, digits, hyphen, underscore; no path separators)."
      ),
      class = "bfhcharts_export_error"
    )
  }
  invisible(id)
}

# List bundle ids in a cache directory: immediate subdirectories that carry
# a page.rds file and a pattern-valid name. Hidden staging/backup dirs
# (dot-prefixed) fail the pattern and are excluded by construction.
.list_bundle_ids <- function(cache_dir) {
  dirs <- list.dirs(cache_dir, full.names = FALSE, recursive = FALSE)
  dirs <- dirs[grepl(BATCH_PAGE_ID_PATTERN, dirs)]
  dirs[file.exists(file.path(cache_dir, dirs, "page.rds"))]
}

# Next default id in the "page-NNNN" series (one past the highest existing).
.next_default_page_id <- function(existing_ids) {
  defaults <- grep("^page-[0-9]{4,}$", existing_ids, value = TRUE)
  n <- if (length(defaults) == 0L) {
    0L
  } else {
    max(as.integer(sub("^page-", "", defaults)))
  }
  sprintf("page-%04d", n + 1L)
}

# Next default order key: one past the highest order staged so far.
# Unreadable bundles are ignored here (they surface at compile time).
.next_default_order <- function(cache_dir, existing_ids) {
  orders <- vapply(existing_ids, function(id) {
    val <- tryCatch(
      readRDS(file.path(cache_dir, id, "page.rds"))$order,
      error = function(e) NULL
    )
    if (is.numeric(val) && length(val) == 1L && !is.na(val)) val else NA_real_
  }, numeric(1))
  orders <- orders[!is.na(orders)]
  if (length(orders) == 0L) 1 else max(orders) + 1
}

# Read + validate every bundle in the cache. Returns a named list of bundle
# data keyed by id. skip_invalid = TRUE drops broken bundles with one
# warning listing them; FALSE aborts naming every offender.
.read_page_bundles <- function(cache_dir, skip_invalid = FALSE) {
  ids <- .list_bundle_ids(cache_dir)
  bundles <- list()
  invalid <- character(0)
  reasons <- character(0)
  for (id in ids) {
    res <- .read_one_bundle(cache_dir, id)
    if (is.null(res$error)) {
      bundles[[id]] <- res$data
    } else {
      invalid <- c(invalid, id)
      reasons <- c(reasons, res$error)
    }
  }
  if (length(invalid) > 0L) {
    detail <- paste0("  - ", invalid, ": ", reasons, collapse = "\n")
    if (skip_invalid) {
      warning(
        "Skipped invalid page bundles:\n", detail,
        call. = FALSE
      )
    } else {
      bfh_abort(
        paste0(
          "Invalid page bundles in cache (re-stage with bfh_stage_pdf_page(),",
          " or pass skip_invalid = TRUE to drop them):\n", detail
        ),
        class = "bfhcharts_export_error"
      )
    }
  }
  bundles
}

# Read and validate a single bundle. Returns list(data, error): error is a
# short reason string, or NULL on success. Validation enforces the plain-
# data contract before any value flows into Typst content generation.
.read_one_bundle <- function(cache_dir, id) {
  bundle_dir <- file.path(cache_dir, id)
  if (!file.exists(file.path(bundle_dir, "chart.svg"))) {
    return(list(data = NULL, error = "missing chart.svg"))
  }
  data <- tryCatch(
    readRDS(file.path(bundle_dir, "page.rds")),
    error = function(e) NULL
  )
  if (is.null(data) || !is.list(data)) {
    return(list(data = NULL, error = "unreadable page.rds"))
  }
  fv <- data$format_version
  if (!is.numeric(fv) || length(fv) != 1L || is.na(fv)) {
    return(list(data = NULL, error = "missing format_version"))
  }
  if (as.integer(fv) != BATCH_CACHE_FORMAT_VERSION) {
    return(list(data = NULL, error = sprintf(
      "unsupported cache format version %s (this BFHcharts supports %d); re-stage this page",
      format(fv), BATCH_CACHE_FORMAT_VERSION
    )))
  }
  if (!is.list(data$metadata)) {
    return(list(data = NULL, error = "metadata is not a list"))
  }
  if (!is.list(data$spc_stats)) {
    return(list(data = NULL, error = "spc_stats is not a list"))
  }
  if (!is.character(data$template) || length(data$template) != 1L ||
    !grepl("^[a-zA-Z][a-zA-Z0-9_-]*$", data$template)) {
    return(list(data = NULL, error = "invalid template name"))
  }
  if (!is.numeric(data$order) || length(data$order) != 1L || is.na(data$order)) {
    return(list(data = NULL, error = "invalid order key"))
  }
  # Type guards mirrored from bfh_create_typst_document(): the batch path
  # bypasses that function, so numeric/logical stats must be enforced here
  # before build_typst_page_call() stringifies them.
  for (f in c(
    "runs_expected", "runs_actual", "crossings_expected",
    "crossings_actual", "outliers_expected", "outliers_actual"
  )) {
    val <- data$spc_stats[[f]]
    if (!is.null(val) && !is.numeric(val)) {
      return(list(data = NULL, error = sprintf("spc_stats$%s is not numeric", f)))
    }
  }
  if (!is.null(data$spc_stats$is_run_chart) &&
    !is.logical(data$spc_stats$is_run_chart)) {
    return(list(data = NULL, error = "spc_stats$is_run_chart is not logical"))
  }
  # Character metadata fields must be scalar strings when present (a list or
  # vector here would corrupt the generated Typst parameter block).
  for (f in c(
    "hospital", "department", "details", "author", "data_definition",
    "title", "analysis", "footer_content", "logo_path", "cl_caveat_text"
  )) {
    val <- data$metadata[[f]]
    if (!is.null(val) && (!is.character(val) || length(val) != 1L || is.na(val))) {
      return(list(data = NULL, error = sprintf("metadata$%s is not a single string", f)))
    }
  }
  list(data = data, error = NULL)
}
