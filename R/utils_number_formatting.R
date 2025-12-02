#' Number Formatting Utilities
#'
#' Canonical number formatting functions for SPC plots with Danish notation.
#' Single source of truth for K/M/mia notation and Danish decimal/thousand separators.
#'
#' @name utils_number_formatting
#' @keywords internal
#' @noRd
NULL

# ============================================================================
# DANISH NUMBER FORMATTING CONSTANTS
# ============================================================================

# Danish formatting uses comma as decimal mark and dot as thousand separator
# e.g., 1.234,56 instead of 1,234.56

# ============================================================================
# CANONICAL NUMBER FORMATTING
# ============================================================================

#' Determine Number Magnitude
#'
#' Detects if a number should use K, M, or mia notation.
#'
#' @param val Numeric value
#'
#' @return List with scale factor and suffix, or NULL for no scaling
#' @keywords internal
#' @noRd
determine_magnitude <- function(val) {
  if (is.na(val)) {
    return(NULL)
  }

  abs_val <- abs(val)
  if (abs_val >= 1e9) {
    list(scale = 1e9, suffix = " mia.")
  } else if (abs_val >= 1e6) {
    list(scale = 1e6, suffix = "M")
  } else if (abs_val >= 1e3) {
    list(scale = 1e3, suffix = "K")
  } else {
    NULL
  }
}

#' Format Number with Scaled Suffix (Canonical)
#'
#' Formats a number with K/M/mia suffix and Danish decimal notation.
#'
#' @param val Numeric value
#' @param scale Scale factor (1e3, 1e6, 1e9)
#' @param suffix Suffix string ("K", "M", " mia.")
#'
#' @return Formatted string (e.g., "1,5K", "2M", "1,2 mia.")
#' @keywords internal
#' @noRd
format_scaled_number <- function(val, scale, suffix) {
  if (is.na(val)) {
    return(NA_character_)
  }

  scaled <- val / scale
  # Use all.equal() for floating point comparison
  # (e.g., 1000000 / 1e6 = 1.0 exactly)
  if (isTRUE(all.equal(scaled, round(scaled), tolerance = 1e-10))) {
    paste0(round(scaled), suffix)
  } else {
    paste0(format(scaled, decimal.mark = ",", nsmall = 1), suffix)
  }
}

#' Format Number Without Scaling (Canonical)
#'
#' Formats a number with Danish notation (comma decimal, dot thousand).
#'
#' @param val Numeric value
#'
#' @return Formatted string with Danish notation
#' @keywords internal
#' @noRd
format_unscaled_number <- function(val) {
  if (is.na(val)) {
    return(NA_character_)
  }

  # Use all.equal() for floating point comparison
  if (isTRUE(all.equal(val, round(val), tolerance = 1e-10))) {
    format(round(val), big.mark = ".", decimal.mark = ",")
  } else {
    format(val, big.mark = ".", decimal.mark = ",", nsmall = 1)
  }
}

#' Format Count Value with K/M/mia Notation (Canonical)
#'
#' Formats count values with intelligent K/M/mia notation for large numbers
#' and Danish decimal/thousand separators.
#'
#' @param val Numeric value
#'
#' @return Formatted string (e.g., "123", "1,5K", "2M", "1,2 mia.")
#'
#' @details
#' Scaling thresholds: less than 1,000 no scaling, 1,000 or more K notation,
#' 1,000,000 or more M notation, 1,000,000,000 or more mia. notation.
#' Uses Danish formatting: decimal mark `,` and thousand separator `.`
#'
#' @keywords internal
#' @noRd
#' @family spc-formatting
format_count_danish <- function(val) {
  if (is.na(val)) {
    return(NA_character_)
  }

  magnitude <- determine_magnitude(val)

  if (!is.null(magnitude)) {
    format_scaled_number(val, magnitude$scale, magnitude$suffix)
  } else {
    format_unscaled_number(val)
  }
}

#' Format Rate Value with Danish Notation (Canonical)
#'
#' Formats rate values with Danish decimal notation.
#' Shows decimals only when necessary.
#'
#' @param val Numeric value
#'
#' @return Formatted string with Danish decimal notation
#' @keywords internal
#' @noRd
format_rate_danish <- function(val) {
  if (is.na(val)) {
    return(NA_character_)
  }

  # Use all.equal() for floating point comparison
  if (isTRUE(all.equal(val, round(val), tolerance = 1e-10))) {
    format(round(val), decimal.mark = ",")
  } else {
    format(val, decimal.mark = ",", nsmall = 1)
  }
}
