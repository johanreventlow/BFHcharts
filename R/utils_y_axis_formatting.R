#' Y-Axis Formatting Utilities
#'
#' Unit-specific Y-axis formatting for SPC plots with Danish number notation.
#'
#' @name y_axis_formatting
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
#' @export
#' @examples
#' \dontrun{
#' library(ggplot2)
#' plot <- ggplot(qic_data, aes(x = x, y = y)) + geom_point()
#'
#' # Percentage formatting
#' plot + apply_y_axis_formatting("percent", qic_data)
#'
#' # Count with K/M notation
#' plot + apply_y_axis_formatting("count", qic_data)
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

  # Apply unit-specific formatting
  switch(y_axis_unit,
    percent = plot + format_y_axis_percent(),
    count = plot + format_y_axis_count(),
    rate = plot + format_y_axis_rate(),
    time = plot + format_y_axis_time(qic_data),
    plot # Default: no special formatting
  )
}

# ============================================================================
# UNIT-SPECIFIC FORMATTERS
# ============================================================================

#' Format Y-Axis for Percentage Data
#'
#' @return ggplot2 scale layer
#' @keywords internal
format_y_axis_percent <- function() {
  ggplot2::scale_y_continuous(
    expand = ggplot2::expansion(mult = c(.25, .25)),
    labels = scales::label_percent()
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
format_y_axis_count <- function() {
  ggplot2::scale_y_continuous(
    expand = ggplot2::expansion(mult = c(.25, .25)),
    labels = function(x) {
      x |>
        purrr::map_chr(~ {
          dplyr::case_when(
            is.na(.x) ~ NA_character_,
            abs(.x) >= 1e9 ~ format_scaled_number(.x, 1e9, " mia."),
            abs(.x) >= 1e6 ~ format_scaled_number(.x, 1e6, "M"),
            abs(.x) >= 1e3 ~ format_scaled_number(.x, 1e3, "K"),
            TRUE ~ format_unscaled_number(.x)
          )
        })
    }
  )
}

#' Format Y-Axis for Rate Data
#'
#' @return ggplot2 scale layer
#' @keywords internal
format_y_axis_rate <- function() {
  ggplot2::scale_y_continuous(
    expand = ggplot2::expansion(mult = c(.25, .25)),
    labels = function(x) {
      ifelse(x == round(x),
        format(round(x), decimal.mark = ","),
        format(x, decimal.mark = ",", nsmall = 1)
      )
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
format_y_axis_time <- function(qic_data) {
  if (is.null(qic_data) || !"y" %in% names(qic_data)) {
    warning("format_y_axis_time: missing qic_data or y column, using default")
    return(ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(.25, .25))))
  }

  y_range <- range(qic_data$y, na.rm = TRUE)
  max_minutes <- max(y_range, na.rm = TRUE)

  # Determine appropriate time unit
  time_unit <- if (max_minutes < 60) {
    "minutes"
  } else if (max_minutes < 1440) {
    "hours"
  } else {
    "days"
  }

  ggplot2::scale_y_continuous(
    expand = ggplot2::expansion(mult = c(.25, .25)),
    labels = function(x) {
      purrr::map_chr(x, ~ format_time_with_unit(.x, time_unit))
    }
  )
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

#' Format Scaled Number with Suffix
#'
#' @param val Numeric value
#' @param scale Scale factor (1e3, 1e6, 1e9)
#' @param suffix Suffix string ("K", "M", " mia.")
#'
#' @return Formatted string
#' @keywords internal
format_scaled_number <- function(val, scale, suffix) {
  if (is.na(val)) {
    return(NA_character_)
  }

  scaled <- val / scale
  if (scaled == round(scaled)) {
    paste0(round(scaled), suffix)
  } else {
    paste0(format(scaled, decimal.mark = ",", nsmall = 1), suffix)
  }
}

#' Format Unscaled Number with Danish Notation
#'
#' @param val Numeric value
#'
#' @return Formatted string
#' @keywords internal
format_unscaled_number <- function(val) {
  if (is.na(val)) {
    return(NA_character_)
  }

  if (val == round(val)) {
    format(round(val), big.mark = ".", decimal.mark = ",")
  } else {
    format(val, big.mark = ".", decimal.mark = ",", nsmall = 1)
  }
}

#' Format Time Value with Unit
#'
#' Converts time in minutes to appropriate unit with Danish labels.
#'
#' @param val_minutes Time value in minutes
#' @param time_unit Unit: "minutes", "hours", or "days"
#'
#' @return Formatted string (e.g., "30 min", "1,5 timer", "2 dage")
#' @keywords internal
format_time_with_unit <- function(val_minutes, time_unit) {
  if (is.na(val_minutes)) {
    return(NA_character_)
  }

  # Scale to appropriate unit
  scaled <- switch(time_unit,
    minutes = val_minutes,
    hours = val_minutes / 60,
    days = val_minutes / 1440,
    val_minutes
  )

  # Danish unit labels
  unit_label <- switch(time_unit,
    minutes = " min",
    hours = " timer",
    days = " dage",
    " min"
  )

  # Format with or without decimals
  if (scaled == round(scaled)) {
    paste0(round(scaled), unit_label)
  } else {
    paste0(format(scaled, decimal.mark = ",", nsmall = 1), unit_label)
  }
}
