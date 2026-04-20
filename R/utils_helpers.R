#' Helper Utilities
#'
#' General helper functions for SPC plot generation.
#'
#' @name utils_helpers
#' @keywords internal
#' @noRd
NULL

# ============================================================================
# SAFE AGGREGATION
# ============================================================================

#' Safe Max — returnerer NA_real_ i stedet for -Inf når alle værdier er NA
#' @param v Numerisk vektor
#' @return Numerisk skalar
#' @keywords internal
#' @noRd
safe_max <- function(v) {
  v <- v[!is.na(v)]
  if (length(v) == 0) return(NA_real_)
  max(v)
}

#' Safe Min — returnerer NA_real_ i stedet for Inf når alle værdier er NA
#' @param v Numerisk vektor
#' @return Numerisk skalar
#' @keywords internal
#' @noRd
safe_min <- function(v) {
  v <- v[!is.na(v)]
  if (length(v) == 0) return(NA_real_)
  min(v)
}

# ============================================================================
# ARROW SYMBOL DETECTION
# ============================================================================
# has_arrow_symbol() og parse_target_input() er defineret i utils_label_helpers.R

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

#' Check om numerisk værdi effektivt er heltal (tolerance-baseret)
#'
#' Central helper for heltalsdetektion på tværs af formatteringsfunktioner.
#' Undgår duplikeret `all.equal(..., round(...))` logik.
#'
#' @param x Numeric skalar.
#' @param tolerance Numerisk tolerance til floating-point sammenligning.
#'
#' @return Logical. TRUE hvis `x` er numerisk og inden for tolerance af nærmeste heltal.
#' @keywords internal
#' @noRd
is_effective_integer <- function(x, tolerance = 1e-10) {
  if (!is.numeric(x) || length(x) != 1 || is.na(x) || !is.finite(x)) {
    return(FALSE)
  }

  isTRUE(all.equal(x, round(x), tolerance = tolerance))
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
  # Parameter-specifikke fejlbeskeder (DRY — defineret én gang)
  PARAM_MESSAGES <- list(
    multiply = "multiply must be a single positive number",
    cl = "cl must be a single numeric value"
  )

  # Helper: hent parameter-specifik besked eller generisk
  param_msg <- function(generic) {
    PARAM_MESSAGES[[param_name]] %||% generic
  }

  # Check NULL
  if (is.null(value)) {
    if (allow_null) {
      return(invisible(TRUE))
    }
    stop(sprintf("%s cannot be NULL", param_name), call. = FALSE)
  }

  # Check type and NA
  if (!is.numeric(value) || any(is.na(value))) {
    stop(param_msg(sprintf(
      "%s must be numeric without NAs, got: %s",
      param_name, paste(value, collapse = ", ")
    )), call. = FALSE)
  }

  # Check length
  if (!is.null(len) && length(value) != len) {
    stop(param_msg(sprintf(
      "%s must have length %d, got: %d",
      param_name, len, length(value)
    )), call. = FALSE)
  }

  # Check bounds
  if (any(value < min) || any(value > max)) {
    if (!is.null(context)) {
      # Kontekst-baserede fejlbeskeder (part, freeze, exclude)
      ctx_msgs <- list(
        freeze = "freeze position must be a positive integer within data bounds (%s), got: %s",
        part = "part positions must be positive integers within data bounds (%s), got: %s",
        exclude = "exclude positions must be positive integers within data bounds (%s), got: %s"
      )
      fmt <- ctx_msgs[[param_name]] %||%
        "%s must be within data bounds (%s), got: %s"

      if (param_name %in% names(ctx_msgs)) {
        stop(sprintf(fmt, context, paste(value, collapse = ", ")), call. = FALSE)
      } else {
        stop(sprintf(fmt, param_name, context, paste(value, collapse = ", ")), call. = FALSE)
      }
    } else {
      # Bounds-fejl uden kontekst
      if (param_name %in% c("width", "height")) {
        range_str <- sprintf("between 0 and 1000 inches")
        stop(sprintf("%s must be %s", param_name, range_str), call. = FALSE)
      }
      stop(param_msg(sprintf("%s must be between %s and %s", param_name, min, max)),
           call. = FALSE)
    }
  }

  invisible(TRUE)
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
