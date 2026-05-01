#' Create a Batch Export Session
#'
#' Creates a reusable export session that pre-populates Typst template assets
#' once and shares them across multiple [bfh_export_pdf()] calls, eliminating
#' the repeated recursive template directory copy that dominates I/O cost in
#' batch workflows.
#'
#' @param font_path Optional path to directory containing additional fonts.
#'   Applied to all exports in this session. Can be overridden per export via
#'   the \code{font_path} argument of \code{bfh_export_pdf()}.
#' @param inject_assets Optional callback function called once after template
#'   assets are staged. Receives one argument: the path to the template
#'   directory (\code{<session_tmpdir>/bfh-template}). Use this to inject fonts
#'   or images not bundled in BFHcharts (e.g., proprietary fonts from a private
#'   package). If the injected directory contains a \code{fonts/} subdirectory
#'   and \code{font_path} is NULL, \code{font_path} is set automatically.
#' @param strict_baseline Logical. Default for the session: when TRUE
#'   (default), every \code{bfh_export_pdf()} call inheriting this session
#'   errors before render if the result has \code{freeze < MIN_BASELINE_N}
#'   or any phase shorter than \code{MIN_BASELINE_N} (8) data points. Set
#'   FALSE to preserve the legacy warning-only behavior across the batch.
#'   Per-call \code{strict_baseline} on \code{bfh_export_pdf()} overrides
#'   the session value.
#'
#' @return A \code{bfh_export_session} object. Close with \code{close(session)}
#'   to remove the session tmpdir.
#'
#' @details
#' **Usage pattern:**
#' \preformatted{
#' session <- bfh_create_export_session()
#' on.exit(close(session))
#' for (dept in departments) {
#'   bfh_export_pdf(results[[dept]], paste0(dept, ".pdf"),
#'                  batch_session = session)
#' }
#' }
#'
#' **Limitations:**
#' - Session is single-threaded sequential only - do not share across parallel workers.
#' - Not compatible with \code{template_path} (custom templates).
#' - Pass \code{inject_assets} here, not to individual \code{bfh_export_pdf()} calls.
#'
#' @section Security:
#' \strong{\code{inject_assets} is full code execution.} The supplied function
#' runs with the same privileges as the calling R session, with full file-system
#' and network access. It MUST NOT come from user input (Shiny inputs, REST API
#' parameters, configuration files of unknown provenance).
#' \strong{Treat it as trusted-code-only}: pass only code-reviewed,
#' organizationally controlled callbacks.
#'
#' A runtime heuristic warns when \code{inject_assets} originates from
#' \code{.GlobalEnv} or a direct child environment. Suppress with
#' \code{options(BFHcharts.allow_globalenv_inject = TRUE)} in development.
#'
#' See \code{\link{bfh_export_pdf}} for the full security rationale,
#' acceptable/unacceptable sources, and the parallel note for
#' \code{template_path}.
#'
#' \strong{Recommended: companion package for proprietary branding.}
#' Organizations that need consistent proprietary branding across batch
#' exports should pass a companion-package callback here rather than
#' hardcoding asset paths. For example:
#' \code{bfh_create_export_session(inject_assets = MyAssetsPkg::inject_my_assets)}.
#' This keeps proprietary fonts and logos out of public BFHcharts
#' distribution while supporting full branding on Posit Connect Cloud,
#' RStudio Connect, and Docker deployments. The callback is still
#' subject to the trusted-code-only contract above. See
#' \code{\link{bfh_export_pdf}} Security section for full details.
#'
#' @export
#' @seealso
#'   - [bfh_export_pdf()] for single exports and the full security note
#'     covering both `inject_assets` and `template_path`
bfh_create_export_session <- function(font_path = NULL, inject_assets = NULL,
                                      strict_baseline = TRUE) {
  # Runtime security guard: warns if inject_assets is from global environment.
  .validate_inject_assets(inject_assets)
  if (!is.null(font_path)) {
    if (!is.character(font_path) || length(font_path) != 1) {
      stop("font_path must be a single character string or NULL", call. = FALSE)
    }
  }
  if (!is.logical(strict_baseline) || length(strict_baseline) != 1L ||
    is.na(strict_baseline)) {
    stop("strict_baseline must be TRUE or FALSE", call. = FALSE)
  }

  tmpdir <- tempfile("bfh_batch_")
  dir.create(tmpdir, recursive = TRUE)
  # Sikkerhed: tempfile() leverer en per-bruger isoleret sti i tempdir(),
  # og Sys.chmod(0700) fjerner group/other-permissions. UID-baseret
  # ownership validation is intentionally omitted -- UID is shell-internal and typically
  # ikke eksporteret til R-processer (Rscript, RStudio Server, knitr,
  # Shiny, GitHub Actions).
  Sys.chmod(tmpdir, mode = "0700", use_umask = FALSE)

  template_src <- system.file("templates/typst/bfh-template", package = "BFHcharts")
  if (!dir.exists(template_src)) {
    unlink(tmpdir, recursive = TRUE)
    stop("Typst template not found. Please reinstall BFHcharts.", call. = FALSE)
  }
  if (!file.copy(template_src, tmpdir, recursive = TRUE, overwrite = TRUE)) {
    unlink(tmpdir, recursive = TRUE)
    stop("Failed to copy template assets to session tmpdir.", call. = FALSE)
  }

  if (is.function(inject_assets)) {
    local_template <- file.path(tmpdir, "bfh-template")
    inject_assets(local_template)
    if (is.null(font_path)) {
      injected_fonts <- file.path(local_template, "fonts")
      if (dir.exists(injected_fonts)) font_path <- injected_fonts
    }
  }

  closed <- FALSE

  # Use environment (not list) so that reg.finalizer() works --
  # R only permits finalizers on environments and external pointers.
  session <- new.env(parent = emptyenv())
  session$tmpdir <- tmpdir
  session$template_ready <- TRUE
  session$font_path <- font_path
  session$strict_baseline <- strict_baseline
  session$closed <- function() closed
  session$close <- function() {
    if (!closed) {
      unlink(tmpdir, recursive = TRUE)
      closed <<- TRUE
    }
    invisible(NULL)
  }
  class(session) <- "bfh_export_session"

  # Session-finalizer: garanterer cleanup ved GC selv uden eksplicit close()
  reg.finalizer(session, function(s) s$close(), onexit = TRUE)

  session
}

#' @export
close.bfh_export_session <- function(con, ...) {
  con$close()
}

#' @export
print.bfh_export_session <- function(x, ...) {
  status <- if (x$closed()) "closed" else "open"
  cat(sprintf("BFH export session (%s)\n", status))
  if (!x$closed()) cat("  tmpdir:", x$tmpdir, "\n")
  if (!is.null(x$font_path)) cat("  font_path:", x$font_path, "\n")
  invisible(x)
}
