# ==============================================================================
# X-Axis Formatting Utilities
# ==============================================================================
#
# Modular functions for formatting x-axis in SPC charts.
# Extracted from apply_x_axis_formatting() to improve maintainability.
#
# Created: 2025-12-02
# ==============================================================================

#' Normalize Date or POSIXct to POSIXct
#'
#' Converts Date objects to POSIXct while leaving POSIXct unchanged.
#'
#' @param x Date or POSIXct vector
#' @return POSIXct vector
#' @keywords internal
#' @noRd
normalize_to_posixct <- function(x) {
  if (inherits(x, "Date")) {
    return(as.POSIXct(x))
  }
  x
}

#' Round Date to Interval Start
#'
#' Floors a date to the beginning of its interval (day, week, or month).
#'
#' @param date POSIXct date
#' @param interval_type Character: "daily", "weekly", or "monthly"
#' @return POSIXct date rounded to interval start
#' @keywords internal
#' @noRd
round_to_interval_start <- function(date, interval_type) {
  if (interval_type == "monthly") {
    lubridate::floor_date(date, unit = "month")
  } else if (interval_type == "weekly") {
    lubridate::floor_date(date, unit = "week")
  } else {
    date  # daily or unknown → no rounding
  }
}

#' Calculate Base Interval in Seconds
#'
#' Returns the base interval duration in seconds for a given interval type.
#'
#' @param interval_type Character: "daily", "weekly", or "monthly"
#' @return Numeric seconds, or NULL if interval type unknown
#' @keywords internal
#' @noRd
calculate_base_interval_secs <- function(interval_type) {
  switch(interval_type,
    "daily" = 24 * 60 * 60,      # 86400 seconds
    "weekly" = 7 * 24 * 60 * 60,   # 604800 seconds
    "monthly" = 30 * 24 * 60 * 60, # 2592000 seconds (approximate)
    NULL
  )
}

#' Calculate Interval Multiplier for Dense Data
#'
#' Determines the multiplier to apply to base interval when there are >15
#' potential breaks on the axis.
#'
#' @param potential_breaks Numeric: number of breaks without multiplier
#' @param interval_type Character: "daily", "weekly", or "monthly"
#' @return Numeric multiplier (1, 2, 3, 4, 6, 8, 12, or 13)
#' @keywords internal
#' @noRd
calculate_interval_multiplier <- function(potential_breaks, interval_type) {
  if (potential_breaks <= 15) {
    return(1)  # No multiplier needed
  }

  # Define multiplier candidates per interval type
  multipliers <- switch(interval_type,
    "weekly" = c(2, 4, 13),
    "monthly" = c(3, 6, 12),
    c(2, 4, 8)  # daily or fallback
  )

  # Find smallest multiplier that reduces breaks to ≤15
  for (m in multipliers) {
    if (potential_breaks / m <= 15) {
      return(m)
    }
  }

  # If all multipliers still exceed 15 breaks, use largest
  tail(multipliers, 1)
}

#' Calculate Date Breaks for X-Axis
#'
#' Computes optimal break points for temporal x-axes based on data range
#' and interval type. Applies multipliers for dense data to keep ≤15 breaks.
#'
#' @param data_x_min POSIXct minimum x value
#' @param data_x_max POSIXct maximum x value
#' @param interval_type Character: interval type from detect_date_interval()
#' @param format_config List: format configuration from get_optimal_formatting()
#' @return POSIXct vector of break points
#' @keywords internal
#' @noRd
calculate_date_breaks <- function(data_x_min, data_x_max, interval_type,
                                   format_config) {
  base_interval_secs <- calculate_base_interval_secs(interval_type)

  if (is.null(base_interval_secs)) {
    # Unknown interval type → return NULL (caller will use breaks_pretty)
    return(NULL)
  }

  # Calculate density and multiplier
  timespan_secs <- as.numeric(difftime(data_x_max, data_x_min, units = "secs"))
  potential_breaks <- timespan_secs / base_interval_secs
  mult <- calculate_interval_multiplier(potential_breaks, interval_type)

  # Interval size as difftime
  interval_size <- as.difftime(base_interval_secs * mult, units = "secs")

  # Generate breaks based on interval type
  if (interval_type == "monthly") {
    rounded_start <- round_to_interval_start(data_x_min, "monthly")
    rounded_end <- lubridate::ceiling_date(data_x_max, unit = "month")
    interval_months <- round(as.numeric(interval_size) / (30 * 24 * 60 * 60))
    extended_end <- seq(rounded_end, by = paste(interval_months, "months"),
                       length.out = 2)[2]
    breaks_posix <- seq(from = rounded_start, to = extended_end,
                        by = paste(interval_months, "months"))
  } else if (interval_type == "weekly") {
    rounded_start <- round_to_interval_start(data_x_min, "weekly")
    rounded_end <- lubridate::ceiling_date(data_x_max, unit = "week")
    breaks_posix <- seq(from = rounded_start, to = rounded_end + interval_size,
                        by = interval_size)
  } else {
    # daily
    rounded_start <- round_to_interval_start(data_x_min, interval_type)
    breaks_posix <- seq(from = rounded_start, to = data_x_max + interval_size,
                        by = interval_size)
  }

  # Filter to data range and ensure first break exists
  breaks_posix <- breaks_posix[breaks_posix >= data_x_min]
  if (length(breaks_posix) == 0 || breaks_posix[1] != data_x_min) {
    breaks_posix <- unique(c(data_x_min, breaks_posix))
  }

  # Ensure POSIXct
  as.POSIXct(breaks_posix)
}

#' Apply Temporal X-Axis Formatting
#'
#' Orchestrates temporal x-axis formatting using interval detection,
#' break calculation, and smart label application.
#'
#' @param plot ggplot object
#' @param x_col POSIXct or Date vector
#' @param data_x_min POSIXct minimum (pre-computed)
#' @param data_x_max POSIXct maximum (pre-computed)
#' @return Modified ggplot object with datetime scale
#' @keywords internal
#' @noRd
apply_temporal_x_axis <- function(plot, x_col, data_x_min, data_x_max) {
  # Normalize to POSIXct
  x_col <- normalize_to_posixct(x_col)

  # Detect interval and get format config
  interval_info <- detect_date_interval(x_col)
  format_config <- get_optimal_formatting(interval_info)

  # Calculate breaks if we have format config with breaks enabled
  if (!is.null(format_config$breaks) ||
      (!is.null(format_config$use_smart_labels) && format_config$use_smart_labels)) {
    breaks_posix <- calculate_date_breaks(data_x_min, data_x_max,
                                          interval_info$type, format_config)

    if (!is.null(breaks_posix)) {
      # Apply scale with calculated breaks
      if (!is.null(format_config$use_smart_labels) && format_config$use_smart_labels) {
        plot <- plot + BFHtheme::scale_x_datetime_bfh(
          expand = ggplot2::expansion(mult = c(0.025, 0)),
          labels = format_config$labels,
          breaks = breaks_posix
        )
      } else {
        plot <- plot + BFHtheme::scale_x_datetime_bfh(
          labels = format_config$labels,
          breaks = breaks_posix
        )
      }
      return(plot)
    }
  }

  # Fallback to breaks_pretty
  plot + BFHtheme::scale_x_datetime_bfh(
    labels = format_config$labels,
    breaks = scales::breaks_pretty(n = format_config$n_breaks)
  )
}

#' Apply Numeric X-Axis Formatting
#'
#' Applies pretty breaks to numeric x-axes (observation sequences).
#'
#' @param plot ggplot object
#' @return Modified ggplot object with continuous scale
#' @keywords internal
#' @noRd
apply_numeric_x_axis <- function(plot) {
  plot + BFHtheme::scale_x_continuous_bfh(
    breaks = scales::pretty_breaks(n = 8)
  )
}
