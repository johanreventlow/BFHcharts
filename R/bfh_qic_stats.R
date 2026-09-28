# ============================================================================
# bfh_qic_stats(): SPC-tal uden graf
# ============================================================================
# Samme beregning som bfh_qic() (via den faelles bfh_qic_compute()), men
# uden plot-konstruktion og label-placering. Til kaldere der kun laeser
# $summary og $qic_data - fx signal-scanning over tusindvis af serier.
# Kontrakten er beskrevet i OpenSpec-forslaget add-qic-stats-compute-only.

#' Compute SPC Statistics Without Building a Plot
#'
#' `bfh_qic_stats()` runs the same computation as [bfh_qic()] - input
#' validation, qicharts2 (or pbcharts for `chart_type = "ip"`), auto-mean
#' substitution for run charts and summary formatting - but skips plot
#' construction and label placement. Use it when only the numbers are
#' needed, e.g. when scanning many series for Anhoej signals.
#'
#' For the same computation arguments, `$summary` (including its
#' `cl_user_supplied` and `cl_auto_mean` attributes) and `$qic_data` are
#' identical to those returned by [bfh_qic()]. Both functions share one
#' internal computation phase, so they cannot drift apart.
#'
#' @inheritParams bfh_qic
#' @return An object of class `bfh_qic_stats`: a list with
#'   - `summary`: data.frame with one row per phase, as `bfh_qic()$summary`
#'   - `qic_data`: data.frame with the raw qic calculations, as
#'     `bfh_qic()$qic_data`
#'   - `config`: list with the computation settings (`chart_type`,
#'     `y_axis_unit`, `target_value`, `part`, `freeze`, `exclude`, `cl`,
#'     `multiply`, `agg.fun`, `has_denominator`)
#'
#'   The object has no plot and is not a `bfh_qic_result`; use [bfh_qic()]
#'   when a chart or an export is needed.
#' @seealso [bfh_qic()] for the full result with a plot,
#'   [bfh_extract_spc_stats()] for extracting key statistics.
#' @export
#' @examples
#' data <- data.frame(
#'   month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
#'   infections = c(15, 18, 14, 16, 19, 13, 17, 20, 15, 18, 16, 14,
#'                  17, 19, 15, 16, 18, 14, 13, 17, 16, 15, 19, 18)
#' )
#'
#' stats <- bfh_qic_stats(data, x = month, y = infections, chart_type = "i")
#' stats$summary
#' bfh_extract_spc_stats(stats)
bfh_qic_stats <- function(data,
                          x,
                          y,
                          n = NULL,
                          chart_type = "run",
                          y_axis_unit = "count",
                          target_value = NULL,
                          notes = NULL,
                          part = NULL,
                          freeze = NULL,
                          exclude = NULL,
                          cl = NULL,
                          multiply = 1,
                          agg_fun = NULL) {
  # ---- NSE fanges i DETTE scope (som i bfh_qic()) ----
  qic_envir <- parent.frame()
  x_expr <- validate_column_name_expr(substitute(x), "x")
  y_expr <- validate_column_name_expr(substitute(y), "y")
  n_expr <- if (!missing(n) && !is.null(substitute(n))) {
    validate_column_name_expr(substitute(n), "n")
  } else {
    NULL
  }
  agg_fun_supplied <- !is.null(agg_fun)

  computed <- bfh_qic_compute(
    data = data,
    x_expr = x_expr,
    y_expr = y_expr,
    n_expr = n_expr,
    chart_type = chart_type,
    y_axis_unit = y_axis_unit,
    part = part,
    freeze = freeze,
    exclude = exclude,
    cl = cl,
    multiply = multiply,
    # Samme default som bfh_qic()'s agg.fun-formal
    agg.fun = if (agg_fun_supplied) {
      agg_fun
    } else {
      c("mean", "median", "sum", "sd")
    },
    agg_fun_supplied = agg_fun_supplied,
    target_value = target_value,
    target_text = NULL,
    notes = notes,
    return.data = FALSE,
    # Tegne-argumenter valideres af den faelles fase, men bruges ikke her:
    # bfh_qic()'s defaults.
    base_size = 14,
    width = NULL,
    height = NULL,
    plot_margin = NULL,
    qic_envir = qic_envir
  )

  summary_result <- format_qic_summary(computed$qic_data,
                                       y_axis_unit = y_axis_unit)
  # Samme attributter som build_bfh_qic_return() saetter paa bfh_qic()$summary
  attr(summary_result, "cl_user_supplied") <- !is.null(cl)
  attr(summary_result, "cl_auto_mean") <- isTRUE(computed$cl_auto_mean)

  new_bfh_qic_stats(
    summary = summary_result,
    qic_data = computed$qic_data,
    config = list(
      chart_type = chart_type,
      y_axis_unit = y_axis_unit,
      target_value = target_value,
      part = part,
      freeze = freeze,
      exclude = exclude,
      cl = cl,
      multiply = multiply,
      agg.fun = computed$agg.fun,
      has_denominator = !is.null(n_expr)
    )
  )
}

#' Constructor for bfh_qic_stats objects
#'
#' @param summary data.frame (one row per phase)
#' @param qic_data data.frame with qic calculations
#' @param config list with computation settings
#' @return object of class `bfh_qic_stats`
#' @keywords internal
#' @noRd
new_bfh_qic_stats <- function(summary, qic_data, config) {
  if (!is.data.frame(summary)) {
    stop("summary must be a data.frame or tibble", call. = FALSE)
  }
  if (!is.data.frame(qic_data)) {
    stop("qic_data must be a data.frame", call. = FALSE)
  }
  if (!is.list(config)) {
    stop("config must be a list", call. = FALSE)
  }
  structure(
    list(summary = summary, qic_data = qic_data, config = config),
    class = "bfh_qic_stats"
  )
}

#' Print Method for bfh_qic_stats
#'
#' Prints a one-line header and the per-phase summary. No plot is drawn.
#'
#' @param x A `bfh_qic_stats` object
#' @param ... Passed to `print()` for the summary data.frame
#' @return `x`, invisibly
#' @export
print.bfh_qic_stats <- function(x, ...) {
  cat(sprintf(
    "<bfh_qic_stats> chart_type = %s, %d observations, %d phase(s)\n",
    x$config$chart_type, nrow(x$qic_data), nrow(x$summary)
  ))
  print(x$summary, ...)
  invisible(x)
}
