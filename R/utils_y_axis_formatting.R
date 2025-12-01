#' Y-Axis Formatting Utilities
#'
#' Unit-specific Y-axis formatting for SPC plots with Danish number notation.
#'
#' @name y_axis_formatting
#' @keywords internal
#' @noRd
NULL

# ============================================================================
# MAIN FORMATTING FUNCTION
# ============================================================================

#' Apply Y-Axis Formatting to SPC Plot
#'
#' Applies unit-specific Y-axis formatting to an SPC ggplot object.
#' Supports percentage, count, rate, and time units with Danish formatting.
#'
#' @param plot ggplot object to format
#' @param y_axis_unit Unit type: "percent", "count", "rate", or "time"
#' @param qic_data QIC data frame (required for time unit context)
#'
#' @return Modified ggplot object with appropriate y-axis scale
#'
#' @details
#' **Unit Types:**
#' - **percent**: Percentage values (0-100%) with % suffix
#' - **count**: Integers with intelligent K/M/mia. notation
#' - **rate**: Decimal values with comma notation
#' - **time**: Context-aware minutes/hours/days formatting
#'
#' **Danish Formatting:**
#' - Decimal mark: `,` (e.g., "12,5")
#' - Thousand separator: `.` (e.g., "1.250")
#'
#' @keywords internal
#' @noRd
#' @family spc-formatting
#' @seealso [format_y_value()], [get_optimal_formatting()]
#' @examples
#' \dontrun{
#' library(ggplot2)
#'
#' count_data <- data.frame(
#'   x = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
#'   y = seq(5, 16, length.out = 12)
#' )
#'
#' percent_data <- data.frame(
#'   x = count_data$x,
#'   y = seq(0.05, 0.25, length.out = 12)
#' )
#'
#' count_plot <- ggplot(count_data, aes(x = x, y = y)) +
#'   geom_line()
#'
#' # Apply percentage formatting
#' percent_plot <- ggplot(percent_data, aes(x = x, y = y)) +
#'   geom_line()
#' apply_y_axis_formatting(percent_plot, "percent", percent_data)
#'
#' # Apply count formatting
#' apply_y_axis_formatting(count_plot, "count", count_data)
#' }
apply_y_axis_formatting <- function(plot, y_axis_unit = "count", qic_data = NULL) {
  # Validate inputs
  if (!inherits(plot, "ggplot")) {
    warning("apply_y_axis_formatting: plot is not a ggplot object")
    return(plot)
  }

  if (is.null(y_axis_unit) || !is.character(y_axis_unit)) {
    warning("apply_y_axis_formatting: invalid y_axis_unit, defaulting to 'count'")
    y_axis_unit <- "count"
  }

  # Beregn y_range for percent precision context
  y_range <- if (!is.null(qic_data) && "y" %in% names(qic_data)) {
    range(qic_data$y, na.rm = TRUE)
  } else {
    NULL
  }

  # Apply unit-specific formatting
  switch(y_axis_unit,
    percent = plot + format_y_axis_percent(y_range),
    count = plot + format_y_axis_count(),
    rate = plot + format_y_axis_rate(),
    time = plot + format_y_axis_time(qic_data),
    {
      # Unknown unit - warn user
      warning(
        sprintf(
          "Unknown y_axis_unit: '%s'. Valid values are: 'count', 'percent', 'rate', 'time'. No formatting applied.",
          y_axis_unit
        ),
        call. = FALSE
      )
      plot
    }
  )
}

# ============================================================================
# UNIT-SPECIFIC FORMATTERS
# ============================================================================

#' Format Y-Axis for Percentage Data
#'
#' Range-aware precision: viser decimaler når y-aksen spænder < 5 procentpoint.
#'
#' @param y_range numeric(2) y-akse range, eller NULL
#' @return ggplot2 scale layer
#' @keywords internal
#' @noRd
format_y_axis_percent <- function(y_range = NULL) {
  # Bestem om vi skal vise decimaler baseret på range
  # Threshold: 5 procentpoint (0.05 i 0-1 skala)
  use_decimals <- FALSE
  if (!is.null(y_range) && length(y_range) == 2) {
    range_span <- abs(y_range[2] - y_range[1])
    use_decimals <- range_span < 0.05
  }

  accuracy <- if (use_decimals) 0.1 else 1

  BFHtheme::scale_y_continuous_bfh(
    expand = ggplot2::expansion(mult = c(.25, .25)),
    labels = scales::label_percent(accuracy = accuracy)
  )
}

#' Format Y-Axis for Count Data with K/M Notation
#'
#' Intelligent scaling:
#' - < 1,000: Standard notation with thousand separator
#' - ≥ 1,000: K notation (e.g., "1,5K")
#' - ≥ 1,000,000: M notation (e.g., "2,3M")
#' - ≥ 1,000,000,000: mia. notation (e.g., "1,2 mia.")
#'
#' @return ggplot2 scale layer
#' @keywords internal
#' @noRd
format_y_axis_count <- function() {
  BFHtheme::scale_y_continuous_bfh(
    expand = ggplot2::expansion(mult = c(.25, .25)),
    labels = function(x, ...) {
      # Uses canonical format_count_danish() from utils_number_formatting.R
      purrr::map_chr(x, format_count_danish)
    }
  )
}

#' Format Y-Axis for Rate Data
#'
#' @return ggplot2 scale layer
#' @keywords internal
#' @noRd
format_y_axis_rate <- function() {
  BFHtheme::scale_y_continuous_bfh(
    expand = ggplot2::expansion(mult = c(.25, .25)),
    labels = function(x, ...) {
      # Uses canonical format_rate_danish() from utils_number_formatting.R
      purrr::map_chr(x, format_rate_danish)
    }
  )
}

#' Format Y-Axis for Time Data
#'
#' Automatically selects appropriate time unit (minutes, hours, days)
#' based on data range.
#'
#' @param qic_data QIC data frame with y column (time in minutes)
#'
#' @return ggplot2 scale layer
#' @keywords internal
#' @noRd
format_y_axis_time <- function(qic_data) {
  if (is.null(qic_data) || !"y" %in% names(qic_data)) {
    warning("format_y_axis_time: missing qic_data or y column, using default")
    return(BFHtheme::scale_y_continuous_bfh(expand = ggplot2::expansion(mult = c(.25, .25))))
  }

  y_range <- range(qic_data$y, na.rm = TRUE)
  max_minutes <- max(y_range, na.rm = TRUE)

  # Uses canonical determine_time_unit() from utils_time_formatting.R
  time_unit <- determine_time_unit(max_minutes)

  BFHtheme::scale_y_continuous_bfh(
    expand = ggplot2::expansion(mult = c(.25, .25)),
    labels = function(x, ...) {
      # Uses canonical format_time_danish() from utils_time_formatting.R
      purrr::map_chr(x, ~ format_time_danish(.x, time_unit))
    }
  )
}

# ============================================================================
# NOTE: Helper functions moved to canonical files
# ============================================================================
# The following functions have been consolidated into dedicated utility files:
#
# - format_scaled_number() -> R/utils_number_formatting.R
# - format_unscaled_number() -> R/utils_number_formatting.R
# - format_time_with_unit() -> R/utils_time_formatting.R (as format_time_danish())
#
# This ensures DRY compliance with a single source of truth for formatting.
