#' SPC Chart Type Definitions
#'
#' Constants for valid SPC chart type codes used by qicharts2.
#'
#' @name chart_types
#' @keywords internal
#' @noRd
NULL

# ============================================================================
# CHART TYPE MAPPINGS
# ============================================================================

#' English Chart Type Codes
#'
#' Valid qicharts2 chart type codes.
#'
#' @format Character vector of valid chart codes
#' @keywords internal
#' @noRd
CHART_TYPES_EN <- c("run", "i", "mr", "p", "pp", "u", "up", "c", "g", "xbar", "s", "t")

#' Y-Axis Unit Codes
#'
#' Valid y_axis_unit values accepted by `bfh_qic()` and downstream label
#' helpers. Single source of truth referenced by validators and config
#' objects.
#'
#' @format Character vector of valid y-axis unit codes
#' @keywords internal
#' @noRd
Y_AXIS_UNITS <- c("count", "percent", "rate", "time")
