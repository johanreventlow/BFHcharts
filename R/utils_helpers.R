#' Helper Utilities
#'
#' General helper functions for SPC plot generation.
#'
#' @name utils_helpers
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
#' @export
#' @examples
#' NULL %||% "default"  # Returns "default"
#' "value" %||% "default"  # Returns "value"
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
#' @return Logical, TRUE if arrows detected
#' @keywords internal
has_arrow_symbol <- function(text) {
  if (is.null(text) || nchar(trimws(text)) == 0) {
    return(FALSE)
  }

  grepl("[\u2191\u2193\u2192\u2190]", text)
}

#' Format Target Prefix with Arrow Symbols
#'
#' Processes target text to handle arrow symbols.
#'
#' @param target_text Raw target text
#'
#' @return Formatted target text
#' @keywords internal
format_target_prefix <- function(target_text) {
  if (is.null(target_text)) {
    return("")
  }

  trimws(target_text)
}

# ============================================================================
# DATA VALIDATION
# ============================================================================

#' Validate QIC Data Structure
#'
#' Checks if qic_data has required columns for plotting.
#'
#' @param qic_data Data frame from qicharts2::qic()
#'
#' @return Logical, TRUE if valid
#' @keywords internal
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
#' @export
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
#' @export
#' @examples
#' get_y_axis_unit_label("percent")  # Returns "Procent (%)"
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
# TIME FORMATTING
# ============================================================================

#' Format Time Values for Display
#'
#' Converts numeric time values (in minutes or hours) to readable format.
#'
#' @param value Numeric time value
#' @param unit Unit of time ("minutes", "hours", "days")
#'
#' @return Formatted time string
#' @keywords internal
format_time_value <- function(value, unit = "minutes") {
  if (is.na(value)) {
    return(NA_character_)
  }

  switch(unit,
    minutes = {
      if (value < 60) {
        sprintf("%.0f min", value)
      } else {
        hours <- floor(value / 60)
        mins <- value %% 60
        if (mins == 0) {
          sprintf("%d t", hours)
        } else {
          sprintf("%d t %d min", hours, mins)
        }
      }
    },
    hours = {
      sprintf("%.1f t", value)
    },
    days = {
      sprintf("%.1f dage", value)
    },
    as.character(value)
  )
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
extract_comment_data <- function(qic_data, max_length = 100) {
  # Check if notes column exists in qic_data
  if (!"notes" %in% names(qic_data)) {
    return(NULL)
  }

  # Extract x, y, and notes
  comment_data <- data.frame(
    x = qic_data$x,
    y = qic_data$y,
    comment = qic_data$notes,
    stringsAsFactors = FALSE
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
