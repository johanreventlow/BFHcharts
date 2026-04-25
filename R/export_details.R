#' Generate Details Text for PDF Export
#'
#' Automatically generates a details string based on chart data, including
#' period range, averages, latest values, and current level (centerline).
#'
#' @param x A \code{bfh_qic_result} object from \code{bfh_qic()}
#'
#' @return Character string with formatted details, e.g.:
#'   "Periode: feb. 2019 – mar. 2022 • Gns. måned: 58938/97266 •
#'    Seneste måned: 60756/88509 • Nuværende niveau: 64,5%"
#'
#' @details
#' **Format:**
#' - Period range with Danish date formatting
#' - Average values per interval (numerator/denominator for p/u-charts)
#' - Latest period values
#' - Current level (centerline value) with appropriate unit formatting
#'
#' **Chart Type Handling:**
#' - p-chart, u-chart: Shows numerator/denominator (e.g., "58938/97266")
#' - Other chart types: Shows only the value (e.g., "127")
#'
#' **Interval Detection:**
#' - Uses detect_date_interval() to determine the interval type
#' - Labels adapt: "måned", "uge", "dag", "kvartal", "år"
#'
#' @examples
#' \dontrun{
#' result <- bfh_qic(data, x = date, y = value, chart_type = "i")
#' details <- bfh_generate_details(result)
#' # "Periode: jan. 2024 – dec. 2024 • Gns. måned: 50 • ..."
#' }
#'
#' @family utility-functions
#' @seealso [bfh_export_pdf()] for PDF export functionality
#' @export
bfh_generate_details <- function(x) {
  if (!inherits(x, "bfh_qic_result")) {
    stop("x must be a bfh_qic_result object from bfh_qic()", call. = FALSE)
  }

  qic_data <- x$qic_data
  config <- x$config

  interval_info <- detect_date_interval(qic_data$x)
  interval_label <- get_danish_interval_label(interval_info$type)

  start_date <- format_danish_date_short(min(qic_data$x, na.rm = TRUE))
  end_date <- format_danish_date_short(max(qic_data$x, na.rm = TRUE))
  periode <- sprintf("Periode: %s – %s", start_date, end_date)

  chart_type <- config$chart_type

  has_denominator_data <- "y.sum" %in% names(qic_data) &&
    "n" %in% names(qic_data) &&
    !all(is.na(qic_data$n))

  # run charts med nævnerdata viser brøk, ligesom p/u-charts
  uses_denominator <- (chart_type %in% c("p", "u")) ||
    (chart_type == "run" && has_denominator_data)

  if (uses_denominator) {
    avg_num <- round(mean(qic_data$y.sum, na.rm = TRUE))
    avg_den <- round(mean(qic_data$n, na.rm = TRUE))
    gns <- sprintf(
      "Gns. %s: %s/%s", interval_label,
      format(avg_num, big.mark = ".", decimal.mark = ","),
      format(avg_den, big.mark = ".", decimal.mark = ",")
    )
  } else {
    avg_val <- round(mean(qic_data$y, na.rm = TRUE))
    gns <- sprintf(
      "Gns. %s: %s", interval_label,
      format(avg_val, big.mark = ".", decimal.mark = ",")
    )
  }

  last_row <- utils::tail(qic_data, 1)

  if (uses_denominator) {
    last_num <- round(last_row$y.sum)
    last_den <- round(last_row$n)
    seneste <- sprintf(
      "Seneste %s: %s/%s", interval_label,
      format(last_num, big.mark = ".", decimal.mark = ","),
      format(last_den, big.mark = ".", decimal.mark = ",")
    )
  } else {
    last_val <- round(last_row$y)
    seneste <- sprintf(
      "Seneste %s: %s", interval_label,
      format(last_val, big.mark = ".", decimal.mark = ",")
    )
  }

  cl_value <- last_row$cl
  y_axis_unit <- config$y_axis_unit %||% "count"

  niveau <- format_centerline_for_details(cl_value, y_axis_unit)

  paste(periode, gns, seneste, niveau, sep = " • ")
}

#' Format Centerline Value for Details
#'
#' Formats the centerline value based on y_axis_unit with appropriate
#' decimal places and unit suffix.
#'
#' @param cl_value Numeric centerline value
#' @param y_axis_unit Character string: "percent", "count", "rate", etc.
#'
#' @return Formatted string, e.g., "Nuværende niveau: 64,5%"
#'
#' @keywords internal
#' @noRd
format_centerline_for_details <- function(cl_value, y_axis_unit) {
  if (is.null(cl_value) || is.na(cl_value)) {
    return("Nuværende niveau: -")
  }

  formatted <- switch(y_axis_unit,
    "percent" = {
      # cl_value kan være 0–1 (proportion) eller 0–100 (pct) afhængigt af kilde
      percent_value <- if (cl_value <= 1) cl_value * 100 else cl_value
      paste0(
        format(
          round(percent_value, 1),
          big.mark = ".",
          decimal.mark = ",",
          nsmall = 1,
          trim = TRUE,
          scientific = FALSE
        ),
        "%"
      )
    },
    "rate" = ,
    "time" = {
      format(
        round(cl_value, 1),
        big.mark = ".",
        decimal.mark = ",",
        nsmall = 1,
        trim = TRUE,
        scientific = FALSE
      )
    },
    {
      if (is_effective_integer(cl_value)) {
        format(
          round(cl_value),
          big.mark = ".",
          decimal.mark = ",",
          trim = TRUE,
          scientific = FALSE
        )
      } else {
        format(
          round(cl_value, 1),
          big.mark = ".",
          decimal.mark = ",",
          nsmall = 1,
          trim = TRUE,
          scientific = FALSE
        )
      }
    }
  )

  sprintf("Nuværende niveau: %s", formatted)
}
