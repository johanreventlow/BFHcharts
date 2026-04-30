#' Extract SPC Statistics
#'
#' S3 generic that extracts statistical process control metrics. The extraction
#' logic depends on the input type:
#'
#' * `data.frame` (typically `bfh_qic_result$summary`): Returns runs and
#'   crossings from the summary. `outliers_actual` and `outliers_recent_count`
#'   remain `NULL` because outlier counts require access to `qic_data`.
#' * `bfh_qic_result`: Returns runs, crossings, and outlier counts. Outliers are
#'   split into two fields so that the PDF table and the analysis text can be
#'   driven from consistent - but distinct - numbers.
#' * `NULL`: Returns an empty stats list (backward compatible).
#'
#' Downstream packages should prefer the `bfh_qic_result` method so the PDF
#' export and any on-screen preview agree on the outlier count.
#'
#' @param x Either a data frame (typically `bfh_qic_result$summary`), a
#'   `bfh_qic_result` object from [bfh_qic()], or `NULL`.
#'
#' @return Named list with SPC statistics:
#' \describe{
#'   \item{runs_expected}{Expected maximum run length (`laengste_loeb_max`)}
#'   \item{runs_actual}{Actual longest run length (`laengste_loeb`)}
#'   \item{crossings_expected}{Expected minimum crossings (`antal_kryds_min`)}
#'   \item{crossings_actual}{Actual number of crossings (`antal_kryds`)}
#'   \item{outliers_expected}{Expected number of outliers (0 for non-run charts,
#'     `NULL` otherwise)}
#'   \item{outliers_actual}{Total number of points outside control limits in the
#'     latest part (used by the PDF table). `NULL` for `data.frame` input, run
#'     charts, or when `sigma.signal` is unavailable.}
#'   \item{outliers_recent_count}{Number of outliers within the last 6
#'     observations of the latest part (used by the analysis text, so stale
#'     outliers are not discussed as if they were current). Present only for
#'     `bfh_qic_result` input on non-run charts.}
#'   \item{is_run_chart}{Logical indicating run chart. Present only for
#'     `bfh_qic_result` input.}
#' }
#'
#' @details
#' Stats are computed on x-sorted observations; input row order is not
#' significant. When `qic_data` contains an `x` column, rows are sorted
#' ascending by `x` before the recency-window slice for
#' `outliers_recent_count` is applied. This ensures that reversed or
#' scrambled input yields identical results to chronologically ordered input.
#'
#' @export
#' @examples
#' \dontrun{
#' result <- bfh_qic(data, x = date, y = value, chart_type = "i")
#'
#' # Full stats (recommended - populates outliers_actual for the table)
#' stats <- bfh_extract_spc_stats(result)
#'
#' # Backward-compatible summary-only dispatch
#' stats_summary_only <- bfh_extract_spc_stats(result$summary)
#' }
#'
#' @family utility-functions
#' @seealso [bfh_qic()] for creating SPC charts
bfh_extract_spc_stats <- function(x) {
  UseMethod("bfh_extract_spc_stats")
}

#' @export
#' @rdname bfh_extract_spc_stats
bfh_extract_spc_stats.default <- function(x) {
  if (is.null(x)) {
    return(empty_spc_stats())
  }
  stop(
    "bfh_extract_spc_stats(): x must be a data.frame (summary) or a ",
    "bfh_qic_result object, not a ", paste(class(x), collapse = "/"),
    call. = FALSE
  )
}

#' @export
#' @rdname bfh_extract_spc_stats
bfh_extract_spc_stats.data.frame <- function(x) {
  stats <- empty_spc_stats()

  if (nrow(x) == 0) {
    return(stats)
  }

  row <- x[nrow(x), ]

  if ("l\u00e6ngste_l\u00f8b_max" %in% names(row)) {
    stats$runs_expected <- clean_spc_value(row[["l\u00e6ngste_l\u00f8b_max"]])
  }
  if ("l\u00e6ngste_l\u00f8b" %in% names(row)) {
    stats$runs_actual <- clean_spc_value(row[["l\u00e6ngste_l\u00f8b"]])
  }
  if ("antal_kryds_min" %in% names(row)) {
    stats$crossings_expected <- clean_spc_value(row$antal_kryds_min)
  }
  if ("antal_kryds" %in% names(row)) {
    stats$crossings_actual <- clean_spc_value(row$antal_kryds)
  }

  # Outliers kan udledes fra summary, hvis summary-generatoren har tilfoejet
  # aggregerede outlier-kolonner.
  if ("forventede_outliers" %in% names(row)) {
    stats$outliers_expected <- clean_spc_value(row$forventede_outliers)
  } else if ("outliers_expected" %in% names(row)) {
    stats$outliers_expected <- clean_spc_value(row$outliers_expected)
  }
  if ("antal_outliers" %in% names(row)) {
    stats$outliers_actual <- clean_spc_value(row$antal_outliers)
  } else if ("outliers_actual" %in% names(row)) {
    stats$outliers_actual <- clean_spc_value(row$outliers_actual)
  }

  stats
}

#' @export
#' @rdname bfh_extract_spc_stats
bfh_extract_spc_stats.bfh_qic_result <- function(x) {
  stats <- bfh_extract_spc_stats(x$summary)

  is_run_chart <- identical(x$config$chart_type, "run")
  stats$is_run_chart <- is_run_chart

  # Run charts har ingen kontrolgraenser -> outlier-felter skal vaere NULL,
  # selvom format_qic_summary() har tilfoejet aggregerede outlier-kolonner.
  if (is_run_chart) {
    stats$outliers_expected <- NULL
    stats$outliers_actual <- NULL
    stats$outliers_recent_count <- NULL
    return(stats)
  }

  if (is.null(x$qic_data) || !"sigma.signal" %in% names(x$qic_data)) {
    # Uden sigma.signal kan vi ikke taelle outliers; lad felterne forblive NULL
    # saa Typst-templaten skjuler raekken i stedet for at vise "-".
    return(stats)
  }

  qd <- x$qic_data
  if ("part" %in% names(qd)) {
    latest_part <- max(qd$part, na.rm = TRUE)
    qd <- qd[qd$part == latest_part, ]
  }

  # Sorter efter x saa raekkefoelgen af input-data ikke paavirker
  # recency-vinduet. Raekkefoelgen er ubetydelig for outliers_actual (sum),
  # men afgoerende for den positionsbaserede slice i outliers_recent_count.
  if ("x" %in% names(qd)) {
    qd <- qd[order(qd$x, na.last = TRUE), ]
  }

  stats$outliers_expected <- 0

  stats$outliers_actual <- sum(qd$sigma.signal, na.rm = TRUE)

  # outliers_recent_count daekker kun seneste RECENT_OBS_WINDOW obs - aeldre
  # outliers vises visuelt i diagrammet men beskrives ikke som aktuelle i
  # analyseteksten. effective_window = min(RECENT_OBS_WINDOW, n_obs) haandterer
  # korte serier korrekt og eksponeres til i18n-skabeloner.
  n_obs <- nrow(qd)
  effective_window <- min(RECENT_OBS_WINDOW, n_obs)
  stats$effective_window <- effective_window
  if (effective_window > 0L) {
    recent_start <- n_obs - effective_window + 1L
    stats$outliers_recent_count <- sum(
      qd$sigma.signal[recent_start:n_obs],
      na.rm = TRUE
    )
  } else {
    stats$outliers_recent_count <- 0L
  }

  stats
}

# Internal helpers ============================================================

empty_spc_stats <- function() {
  list(
    runs_expected = NULL,
    runs_actual = NULL,
    crossings_expected = NULL,
    crossings_actual = NULL,
    outliers_expected = NULL,
    outliers_actual = NULL
  )
}

clean_spc_value <- function(x) {
  if (is.null(x) || length(x) == 0) {
    return(NULL)
  }
  if (is.na(x) || is.nan(x) || is.infinite(x)) {
    return(NA_real_)
  }
  x
}
