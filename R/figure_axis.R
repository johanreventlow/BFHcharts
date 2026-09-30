# ============================================================================
# DATE AXIS FOR FIGURES
#
# The two-level x-axis of the SPC charts (week numbers above the axis, month
# and year below) for arbitrary ggplot figures, e.g. the stacked bars and
# flow charts BFHddl draws for non-SPC indicators.
# ============================================================================

#' Date Axis Like the SPC Charts
#'
#' Adds the x-axis BFHcharts uses on SPC charts to any ggplot with a date
#' x-axis: month labels (and the year at the first month and at year shifts)
#' below the axis, and ISO week numbers ("UGE 08", then every few weeks) just
#' above it. Breaks, label cadence and locale follow \code{\link{bfh_qic}}
#' exactly, so figures and SPC charts in the same report read the same way.
#'
#' The plot's x aesthetics must be \code{POSIXct} (convert \code{Date} with
#' \code{as.POSIXct(x, tz = "UTC")}), because a datetime scale is added. Set
#' x-limits with \code{coord_cartesian(xlim = )}, not on the scale. Add the
#' theme (e.g. \code{BFHtheme::theme_bfh()}) before or after - tick styling
#' comes from the theme.
#'
#' @param plot A ggplot object.
#' @param x The x values the axis should cover (Date or POSIXct), typically
#'   all dates in the plot.
#' @param language Language of the week prefix and month names ("da" or "en").
#' @return The ggplot with a datetime x-scale and week-number labels.
#' @export
#' @family export-functions
#' @examples
#' d <- data.frame(
#'   x = as.POSIXct(seq(as.Date("2026-01-05"), by = "week", length.out = 30), tz = "UTC"),
#'   y = rpois(30, 20)
#' )
#' p <- ggplot2::ggplot(d, ggplot2::aes(x, y)) + ggplot2::geom_col()
#' bfh_apply_date_axis(p, d$x)
bfh_apply_date_axis <- function(plot, x, language = "da") {
  if (!inherits(plot, "ggplot")) {
    bfh_abort("plot must be a ggplot object.", class = "bfhcharts_input_error")
  }
  if (!inherits(x, c("Date", "POSIXct", "POSIXt"))) {
    bfh_abort("x must be a Date or POSIXct vector.", class = "bfhcharts_input_error")
  }
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    bfh_abort("x must contain at least one non-missing date.",
      class = "bfhcharts_input_error"
    )
  }
  x <- sort(unique(normalize_to_posixct(x)))
  apply_temporal_x_axis(plot, x, min(x), max(x), language = language)
}
