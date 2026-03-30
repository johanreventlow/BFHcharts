#' Helper Utilities
#'
#' General helper functions for SPC plot generation.
#'
#' @name utils_helpers
#' @keywords internal
#' @noRd
NULL

# ============================================================================
# NULL COALESCING
# ============================================================================

#' Null-coalescing Operator
#'
#' Returns the first non-NULL value.
#'
#' @param x First value
#' @param y Second value (returned if x is NULL)
#'
#' @return x if not NULL, otherwise y
#' @name null-coalesce
#' @keywords internal
#' @noRd
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

# ============================================================================
# ARROW SYMBOL DETECTION
# ============================================================================

#' Check for Arrow Symbols in Text
#'
#' Detects if text contains directional arrow symbols (↑ ↓).
#' Used to suppress target lines when direction is indicated symbolically.
#'
#' @param text Character string to check
#'
# has_arrow_symbol() og format_target_prefix() er defineret i utils_label_helpers.R
# (kanonisk placering med fuld implementation inkl. parse_target_input())

# ============================================================================
# DATA VALIDATION
# ============================================================================

#' Check if a scalar value is valid (not NULL, not empty, not NA)
#'
#' @param x Value to check
#' @return logical
#' @keywords internal
#' @noRd
is_valid_scalar <- function(x) {
  !is.null(x) && length(x) > 0 && !is.na(x[1])
}

#' Validate Numeric Parameter
#'
#' Centralized validation for numeric parameters in bfh_qic.
#' Checks for type, range, length, and NA values.
#'
#' @param value Parameter value to validate
#' @param param_name Parameter name for error messages
#' @param min Minimum allowed value (default: -Inf)
#' @param max Maximum allowed value (default: Inf)
#' @param len Expected length, or NULL for any length (default: NULL)
#' @param allow_null Allow NULL values (default: TRUE)
#' @param context Optional context for error messages (e.g., "within data bounds")
#'
#' @return Invisibly returns TRUE if validation passes, or stops with error
#' @keywords internal
#' @noRd
validate_numeric_parameter <- function(value,
                                       param_name,
                                       min = -Inf,
                                       max = Inf,
                                       len = NULL,
                                       allow_null = TRUE,
                                       context = NULL) {
  # Check NULL
  if (is.null(value)) {
    if (allow_null) {
      return(invisible(TRUE))
    }
    stop(sprintf("%s cannot be NULL", param_name), call. = FALSE)
  }

  # Check type and NA
  if (!is.numeric(value) || any(is.na(value))) {
    # Generate parameter-specific error messages
    if (param_name == "multiply") {
      stop(sprintf(
        "multiply must be a single positive number"
      ), call. = FALSE)
    } else if (param_name == "cl") {
      stop(sprintf(
        "cl must be a single numeric value"
      ), call. = FALSE)
    } else {
      stop(sprintf(
        "%s must be numeric without NAs, got: %s",
        param_name,
        paste(value, collapse = ", ")
      ), call. = FALSE)
    }
  }

  # Check length
  if (!is.null(len) && length(value) != len) {
    # Generate parameter-specific error messages
    if (param_name == "multiply") {
      stop(sprintf(
        "multiply must be a single positive number"
      ), call. = FALSE)
    } else if (param_name == "cl") {
      stop(sprintf(
        "cl must be a single numeric value"
      ), call. = FALSE)
    } else {
      stop(sprintf(
        "%s must have length %d, got: %d",
        param_name, len, length(value)
      ), call. = FALSE)
    }
  }

  # Check bounds
  if (any(value < min) || any(value > max)) {
    # Build error message based on parameter type
    if (!is.null(context)) {
      # For parameters with context (part, freeze, exclude)
      # Use appropriate singular/plural form
      if (param_name == "freeze") {
        stop(sprintf(
          "freeze position must be a positive integer within data bounds (%s), got: %s",
          context, paste(value, collapse = ", ")
        ), call. = FALSE)
      } else if (param_name == "part") {
        stop(sprintf(
          "part positions must be positive integers within data bounds (%s), got: %s",
          context, paste(value, collapse = ", ")
        ), call. = FALSE)
      } else if (param_name == "exclude") {
        stop(sprintf(
          "exclude positions must be positive integers within data bounds (%s), got: %s",
          context, paste(value, collapse = ", ")
        ), call. = FALSE)
      } else {
        stop(sprintf(
          "%s must be within data bounds (%s), got: %s",
          param_name, context, paste(value, collapse = ", ")
        ), call. = FALSE)
      }
    } else {
      # For parameters without context (base_size, width, height, multiply, cl, etc.)
      # Use parameter-specific error messages where applicable
      if (param_name == "multiply") {
        stop(sprintf(
          "multiply must be a single positive number"
        ), call. = FALSE)
      } else if (param_name == "cl") {
        stop(sprintf(
          "cl must be a single numeric value"
        ), call. = FALSE)
      } else if (param_name %in% c("width", "height")) {
        range_str <- sprintf("between 0 and 1000 inches")
        stop(sprintf(
          "%s must be %s",
          param_name, range_str
        ), call. = FALSE)
      } else {
        range_str <- sprintf("between %s and %s", min, max)
        stop(sprintf(
          "%s must be %s",
          param_name, range_str
        ), call. = FALSE)
      }
    }
  }

  invisible(TRUE)
}

#' Validate QIC Data Structure
#'
#' Checks if qic_data has required columns for plotting.
#'
#' @param qic_data Data frame from qicharts2::qic()
#'
#' @return Logical, TRUE if valid
#' @keywords internal
#' @noRd
validate_qic_data <- function(qic_data) {
  if (is.null(qic_data) || !is.data.frame(qic_data)) {
    stop("qic_data must be a data frame")
  }

  required_cols <- c("x", "y")
  missing_cols <- setdiff(required_cols, names(qic_data))

  if (length(missing_cols) > 0) {
    stop(sprintf(
      "qic_data missing required columns: %s",
      paste(missing_cols, collapse = ", ")
    ))
  }

  if (nrow(qic_data) < 3) {
    stop("qic_data must have at least 3 rows for SPC analysis")
  }

  TRUE
}

# ============================================================================
# Y-AXIS UNITS
# ============================================================================

#' Y-Axis Unit Labels (Danish)
#'
#' Mapping of unit codes to Danish labels.
#'
#' @format Named character vector
#' @keywords internal
#' @noRd
Y_AXIS_UNITS_DA <- c(
  count = "Antal",
  percent = "Procent (%)",
  rate = "Rate",
  time = "Tid",
  ratio = "Ratio"
)

#' Get Y-Axis Unit Label
#'
#' Retrieves Danish label for a given unit code.
#'
#' @param unit_code Unit code ("count", "percent", etc.)
#'
#' @return Danish unit label
#' @keywords internal
#' @noRd
#' @examples
#' \dontrun{
#' get_y_axis_unit_label("percent")  # Returns "Procent (%)"
#' }
get_y_axis_unit_label <- function(unit_code) {
  if (is.null(unit_code) || unit_code == "") {
    return("")
  }

  label <- Y_AXIS_UNITS_DA[unit_code]

  if (is.na(label)) {
    return(unit_code)  # Fallback to code itself
  }

  unname(label)
}

# ============================================================================
# COMMENT DATA EXTRACTION
# ============================================================================

#' Extract Comment Data from QIC Notes Column
#'
#' Processes notes column from qicharts2::qic() output for plot annotations.
#' The notes column is directly provided by qicharts2 and maps 1:1 with data points.
#'
#' @param qic_data QIC result data frame with notes column
#' @param max_length Maximum comment length (default: 100)
#'
#' @return Data frame with x, y, comment columns for plotting, or NULL
#' @keywords internal
#' @noRd
extract_comment_data <- function(qic_data, max_length = 100) {
  # Check if notes column exists in qic_data
  if (!"notes" %in% names(qic_data)) {
    return(NULL)
  }

  # Extract x, y, and notes
  comment_data <- tibble::tibble(
    x = qic_data$x,
    y = qic_data$y,
    comment = qic_data$notes
  )

  # Filter to non-empty comments only
  comment_data <- comment_data[
    !is.na(comment_data$comment) &
      trimws(comment_data$comment) != "",
  ]

  # Truncate long comments
  if (nrow(comment_data) > 0) {
    comment_data$comment <- dplyr::if_else(
      nchar(comment_data$comment) > max_length,
      stringr::str_c(substr(comment_data$comment, 1, max_length - 3), "..."),
      comment_data$comment
    )
  }

  # Return NULL if no valid comments
  if (nrow(comment_data) == 0) {
    return(NULL)
  }

  return(comment_data)
}
