#' Generate Details Text for PDF Export
#'
#' Automatically generates a details string based on chart data, including
#' period range, averages, latest values, and current level (centerline).
#'
#' @param x A \code{bfh_qic_result} object from \code{bfh_qic()}
#' @param language Character string specifying output language. One of \code{"da"} (Danish, default) or \code{"en"} (English). Default \code{"da"} preserves backward compatibility.
#'
#' @return Character string with formatted details, e.g.:
#'   "Periode: feb. 2019 - mar. 2022 * Gns. maaned: 58938/97266 *
#'    Seneste maaned: 60756/88509 * Nuvaerende niveau: 64,5%"
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
#' - Labels adapt: "maaned", "uge", "dag", "kvartal", "aar"
#'
#' **Fail-early contract:**
#' - If `qic_data$x` contains no finite/non-NA values (empty, all-NA, or
#'   all-Inf for numeric), the function stops with a `bfhcharts_config_error`.
#' - Calls with valid data are unaffected.
#'
#' @examples
#' \dontrun{
#' result <- bfh_qic(data, x = date, y = value, chart_type = "i")
#' details <- bfh_generate_details(result)
#' # "Periode: jan. 2024 - dec. 2024 * Gns. maaned: 50 * ..."
#' }
#'
#' @family utility-functions
#' @seealso [bfh_export_pdf()] for PDF export functionality
#' @export
bfh_generate_details <- function(x, language = "da") {
  if (!inherits(x, "bfh_qic_result")) {
    stop("x must be a bfh_qic_result object from bfh_qic()", call. = FALSE)
  }

  validate_language(language)

  qic_data <- x$qic_data
  config <- x$config

  # Validate that the x column contains at least one usable value
  x_col <- qic_data$x
  has_valid_x <- if (inherits(x_col, c("Date", "POSIXct", "POSIXlt"))) {
    any(!is.na(x_col))
  } else {
    any(is.finite(x_col))
  }
  if (!has_valid_x) {
    stop_config_error(sprintf(
      "bfh_generate_details(): qic_data$x has no finite/non-NA values (column class: %s). ",
      paste(class(x_col), collapse = "/")
    ))
  }

  interval_info <- detect_date_interval(qic_data$x)
  interval_label <- get_danish_interval_label(interval_info$type, language)

  start_date <- format_danish_date_short(min(qic_data$x, na.rm = TRUE))
  end_date <- format_danish_date_short(max(qic_data$x, na.rm = TRUE))
  periode <- sprintf(
    "%s: %s \u2013 %s",
    i18n_lookup("labels.details.periode", language), start_date, end_date
  )

  chart_type <- config$chart_type

  has_denominator_data <- "y.sum" %in% names(qic_data) &&
    "n" %in% names(qic_data) &&
    !all(is.na(qic_data$n))

  # run charts med naevnerdata viser broek, ligesom p/u-charts
  uses_denominator <- (chart_type %in% c("p", "u")) ||
    (chart_type == "run" && has_denominator_data)

  lbl_gns <- i18n_lookup("labels.details.gns", language)
  lbl_seneste <- i18n_lookup("labels.details.seneste", language)

  if (uses_denominator) {
    avg_num <- round(mean(qic_data$y.sum, na.rm = TRUE))
    avg_den <- round(mean(qic_data$n, na.rm = TRUE))
    gns <- sprintf(
      "%s %s: %s/%s", lbl_gns, interval_label,
      format(avg_num, big.mark = ".", decimal.mark = ","),
      format(avg_den, big.mark = ".", decimal.mark = ",")
    )
  } else {
    avg_val <- round(mean(qic_data$y, na.rm = TRUE))
    gns <- sprintf(
      "%s %s: %s", lbl_gns, interval_label,
      format(avg_val, big.mark = ".", decimal.mark = ",")
    )
  }

  last_row <- utils::tail(qic_data, 1)

  if (uses_denominator) {
    last_num <- round(last_row$y.sum)
    last_den <- round(last_row$n)
    seneste <- sprintf(
      "%s %s: %s/%s", lbl_seneste, interval_label,
      format(last_num, big.mark = ".", decimal.mark = ","),
      format(last_den, big.mark = ".", decimal.mark = ",")
    )
  } else {
    last_val <- round(last_row$y)
    seneste <- sprintf(
      "%s %s: %s", lbl_seneste, interval_label,
      format(last_val, big.mark = ".", decimal.mark = ",")
    )
  }

  cl_value <- last_row$cl
  y_axis_unit <- config$y_axis_unit %||% "count"

  niveau <- format_centerline_for_details(cl_value, y_axis_unit, language)

  paste(periode, gns, seneste, niveau, sep = " \u2022 ")
}

#' Format Centerline Value for Details
#'
#' Formats the centerline value based on y_axis_unit with appropriate
#' decimal places and unit suffix.
#'
#' @param cl_value Numeric centerline value
#' @param y_axis_unit Character string: "percent", "count", "rate", etc.
#'
#' @return Formatted string, e.g., "Nuvaerende niveau: 64,5%"
#'
#' @keywords internal
#' @noRd
format_centerline_for_details <- function(cl_value, y_axis_unit, language = "da") {
  if (is.null(cl_value) || is.na(cl_value)) {
    return(i18n_lookup("labels.details.niveau_unknown", language))
  }

  formatted <- switch(y_axis_unit,
    "percent" = {
      # cl_value kan vaere 0-1 (proportion) eller 0-100 (pct) afhaengigt af kilde
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

  sprintf("%s: %s", i18n_lookup("labels.details.niveau_label", language), formatted)
}
