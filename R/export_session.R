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
#' - Session is single-threaded sequential only — do not share across parallel workers.
#' - Not compatible with \code{template_path} (custom templates).
#' - Pass \code{inject_assets} here, not to individual \code{bfh_export_pdf()} calls.
#'
#' @export
bfh_create_export_session <- function(font_path = NULL, inject_assets = NULL) {
  if (!is.null(inject_assets) && !is.function(inject_assets)) {
    stop("inject_assets must be a function or NULL", call. = FALSE)
  }
  if (!is.null(font_path)) {
    if (!is.character(font_path) || length(font_path) != 1) {
      stop("font_path must be a single character string or NULL", call. = FALSE)
    }
  }

  tmpdir <- tempfile("bfh_batch_")
  dir.create(tmpdir, recursive = TRUE)
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

  session <- list(
    tmpdir = tmpdir,
    template_ready = TRUE,
    font_path = font_path,
    closed = function() closed,
    close = function() {
      if (!closed) {
        unlink(tmpdir, recursive = TRUE)
        closed <<- TRUE
      }
      invisible(NULL)
    }
  )
  class(session) <- "bfh_export_session"
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
