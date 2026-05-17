# Analysis-date resolution helper
#
# Resolves the canonical "now" date used by feature-extraction (notably
# the freshness-axis, see openspec change restructure-spc-analysis-
# architecture, Slice 10) via a 3-vejs praecedens.
#
# Determinism requirement: bfh_extract_spc_features() SHALL be
# deterministic for identical inputs. Sys.Date() alone breaks this in
# audit-replay scenarios (re-render of archived report 6 months later
# would produce different freshness-feature than the original run).
# Therefore callers can pin the analysis-anchor explicitly.
#
# ASCII-only source (CRAN policy).


#' Resolve analysis_date with 3-vejs praecedens
#'
#' Internal helper. Returns the canonical "now"-anchor Date used by
#' feature-extraction. Resolution order:
#'
#' 1. `metadata$analysis_date` -- eksplicit per-call (vinder altid)
#' 2. `getOption(BFHCHARTS_OPT_ANALYSIS_DATE)` -- global override
#'    (typisk i test-suites)
#' 3. `Sys.Date()` -- production-default
#'
#' The resolved value is intended to be stored in
#' `analysis$aux$analysis_date` for audit-replay traceability.
#'
#' Accepted input types (coerced to Date if possible):
#' - `Date` -- returned as-is
#' - character (`YYYY-MM-DD`) -- coerced via `as.Date()`
#' - `POSIXct`/`POSIXlt` -- coerced via `as.Date()`
#'
#' Invalid input (un-coercible character, NA after coercion, length != 1)
#' triggers an informative error before falling through to the next
#' praecedens-level. This ensures callers do not silently get a
#' `Sys.Date()`-fallback when they intended to pin the date but passed
#' a malformed value.
#'
#' @param metadata Optional named list. If `metadata$analysis_date` is
#'   set, it is resolved first.
#'
#' @return Single-length Date object.
#'
#' @examples
#' \dontrun{
#' # Production default
#' .resolve_analysis_date(list())
#' # -> Sys.Date()
#'
#' # Per-call override
#' .resolve_analysis_date(list(analysis_date = as.Date("2026-01-15")))
#' # -> "2026-01-15"
#'
#' # Global test-suite override
#' withr::with_options(
#'   list(BFHcharts.analysis_date = as.Date("2025-12-31")),
#'   .resolve_analysis_date(list())
#' )
#' # -> "2025-12-31"
#'
#' # Metadata vinder over option
#' withr::with_options(
#'   list(BFHcharts.analysis_date = as.Date("2025-12-31")),
#'   .resolve_analysis_date(list(analysis_date = as.Date("2026-01-15")))
#' )
#' # -> "2026-01-15"
#' }
#'
#' @keywords internal
#' @noRd
.resolve_analysis_date <- function(metadata = list()) {
  # Level 1: metadata$analysis_date
  if (!is.null(metadata) && !is.null(metadata$analysis_date)) {
    return(.coerce_analysis_date(metadata$analysis_date, source = "metadata$analysis_date"))
  }

  # Level 2: getOption(BFHCHARTS_OPT_ANALYSIS_DATE)
  opt_value <- getOption(BFHCHARTS_OPT_ANALYSIS_DATE, default = NULL)
  if (!is.null(opt_value)) {
    return(.coerce_analysis_date(opt_value, source = paste0("getOption(\"", BFHCHARTS_OPT_ANALYSIS_DATE, "\")")))
  }

  # Level 3: Sys.Date() production-default
  Sys.Date()
}


# Coerce input til Date eller error med informativ besked
.coerce_analysis_date <- function(value, source = "analysis_date") {
  if (inherits(value, "Date")) {
    if (length(value) != 1L || is.na(value)) {
      stop(
        sprintf(
          "%s must be a single non-NA Date (got length=%d, NA=%s)",
          source, length(value), is.na(value)[1L]
        ),
        call. = FALSE
      )
    }
    return(value)
  }

  if (inherits(value, c("POSIXct", "POSIXlt"))) {
    coerced <- as.Date(value)
    if (length(coerced) != 1L || is.na(coerced)) {
      stop(
        sprintf("%s must coerce to a single non-NA Date", source),
        call. = FALSE
      )
    }
    return(coerced)
  }

  if (is.character(value) && length(value) == 1L && !is.na(value)) {
    coerced <- tryCatch(
      suppressWarnings(as.Date(value)),
      error = function(e) NA
    )
    if (length(coerced) != 1L || is.na(coerced)) {
      stop(
        sprintf(
          "%s = %s could not be coerced to Date (expected YYYY-MM-DD)",
          source, sQuote(value)
        ),
        call. = FALSE
      )
    }
    return(coerced)
  }

  stop(
    sprintf(
      "%s must be a Date, POSIXct/POSIXlt, or YYYY-MM-DD character; got class %s",
      source, paste(class(value), collapse = "/")
    ),
    call. = FALSE
  )
}
