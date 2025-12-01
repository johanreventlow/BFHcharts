#' Time Formatting Utilities
#'
#' Canonical time formatting functions for SPC plots with Danish labels.
#' Single source of truth for all time-related formatting in the package.
#'
#' @name utils_time_formatting
#' @keywords internal
#' @noRd
NULL

# ============================================================================
# CANONICAL TIME FORMATTING
# ============================================================================

#' Determine Appropriate Time Unit Based on Data Range
#'
#' Selects minutes, hours, or days based on the maximum value in the range.
#'
#' @param max_minutes Maximum time value in minutes
#'
#' @return Character: "minutes", "hours", or "days"
#' @keywords internal
#' @noRd
determine_time_unit <- function(max_minutes) {
  if (is.na(max_minutes) || max_minutes < 60) {
    "minutes"
  } else if (max_minutes < 1440) {
    "hours"
  } else {
    "days"
  }
}

#' Scale Time Value to Appropriate Unit
#'
#' Converts minutes to the specified time unit.
#'
#' @param val_minutes Time value in minutes
#' @param time_unit Target unit: "minutes", "hours", or "days"
#'
#' @return Scaled numeric value
#' @keywords internal
#' @noRd
scale_to_time_unit <- function(val_minutes, time_unit) {
  switch(time_unit,
    minutes = val_minutes,
    hours = val_minutes / 60,
    days = val_minutes / 1440,
    val_minutes
  )
}

#' Get Danish Time Unit Label
#'
#' Returns the appropriate Danish label for a time unit with pluralization.
#'
#' @param time_unit Unit: "minutes", "hours", or "days"
#' @param value Numeric value (for pluralization)
#' @param is_decimal Logical, whether value has decimals (always plural)
#'
#' @return Danish unit label string
#' @keywords internal
#' @noRd
get_danish_time_label <- function(time_unit, value = 2, is_decimal = FALSE) {
  # Decimals always use plural form (e.g., "1,5 timer")
  if (is_decimal) {
    return(switch(time_unit,
      minutes = " minutter",
      hours = " timer",
      days = " dage",
      " min"
    ))
  }

  # Integer pluralization: 1 = singular, others = plural
  switch(time_unit,
    minutes = if (value == 1) " minut" else " minutter",
    hours = if (value == 1) " time" else " timer",
    days = if (value == 1) " dag" else " dage",
    " min"
  )
}

#' Format Time Value with Danish Labels (Canonical)
#'
#' Converts time in minutes to a formatted string with appropriate unit and
#' Danish labels. This is the single source of truth for time formatting.
#'
#' @param val_minutes Time value in minutes
#' @param time_unit Unit: "minutes", "hours", or "days". If NULL, uses "minutes".
#'
#' @return Formatted string (e.g., "30 min", "1 time", "2 timer", "1 dag", "2 dage")
#'
#' @details
#' **Pluralization rules (Danish):**
#' - 1 minut / 2+ minutter
#' - 1 time / 2+ timer
#' - 1 dag / 2+ dage
#' - Decimals always use plural (e.g., "1,5 timer")
#'
#' @keywords internal
#' @noRd
#' @family spc-formatting
format_time_danish <- function(val_minutes, time_unit = "minutes") {
  if (is.na(val_minutes)) {
    return(NA_character_)
  }

  # Handle NULL time_unit
  if (is.null(time_unit)) {
    time_unit <- "minutes"
  }

  # Scale to appropriate unit

  scaled <- scale_to_time_unit(val_minutes, time_unit)

  # Check if value is integer or decimal
  is_integer <- isTRUE(all.equal(scaled, round(scaled), tolerance = 1e-10))

  if (is_integer) {
    num <- round(scaled)
    unit_label <- get_danish_time_label(time_unit, num, is_decimal = FALSE)
    paste0(num, unit_label)
  } else {
    unit_label <- get_danish_time_label(time_unit, scaled, is_decimal = TRUE)
    paste0(format(scaled, decimal.mark = ",", nsmall = 1), unit_label)
  }
}

#' Format Time Value with Auto-Detection (Canonical)
#'
#' Formats time value with automatic unit selection based on y_range context.
#' Used by label formatting when the optimal unit should be auto-determined.
#'
#' @param val_minutes Time value in minutes
#' @param y_range Numeric vector with min/max of y-axis (for context)
#'
#' @return Formatted time string
#' @keywords internal
#' @noRd
format_time_auto <- function(val_minutes, y_range = NULL) {
  if (is.na(val_minutes)) {
    return(NA_character_)
  }

  # Determine unit from range context

  if (is.null(y_range) || length(y_range) < 2) {
    time_unit <- "minutes"
  } else {
    max_minutes <- max(y_range, na.rm = TRUE)
    time_unit <- determine_time_unit(max_minutes)
  }

  format_time_danish(val_minutes, time_unit)
}
