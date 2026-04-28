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

#' Safe Max - returnerer NA_real_ i stedet for -Inf naar alle vaerdier er NA
#' @param v Numerisk vektor
#' @return Numerisk skalar
#' @keywords internal
#' @noRd
safe_max <- function(v) {
  v <- v[!is.na(v)]
  if (length(v) == 0) {
    return(NA_real_)
  }
  max(v)
}

#' Safe Min - returnerer NA_real_ i stedet for Inf naar alle vaerdier er NA
#' @param v Numerisk vektor
#' @return Numerisk skalar
#' @keywords internal
#' @noRd
safe_min <- function(v) {
  v <- v[!is.na(v)]
  if (length(v) == 0) {
    return(NA_real_)
  }
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

#' Check om numerisk vaerdi effektivt er heltal (tolerance-baseret)
#'
#' Central helper for heltalsdetektion paa tvaers af formatteringsfunktioner.
#' Undgaar duplikeret `all.equal(..., round(...))` logik.
#'
#' @param x Numeric skalar.
#' @param tolerance Numerisk tolerance til floating-point sammenligning.
#'
#' @return Logical. TRUE hvis `x` er numerisk og inden for tolerance af naermeste heltal.
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
  # Parameter-specifikke fejlbeskeder (DRY - defineret en gang)
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
        call. = FALSE
      )
    }
  }

  invisible(TRUE)
}


# ============================================================================
# PERCENT TARGET CONTRACT VALIDATION
# ============================================================================

#' Validate target_value against y_axis_unit scale contract
#'
#' Enforces the percent target contract: when `y_axis_unit = "percent"`,
#' `target_value` must be in the proportion/percent scale implied by `multiply`.
#'
#' **Contract:**
#' - `multiply = 1` (default): `target_value` must be in `[0, 1.5]` (proportion)
#' - `multiply = 100`: `target_value` must be in `[0, 150]` (percent)
#' - `multiply = m`: `target_value` must be in `[0, m * 1.5]`
#'
#' The 1.5x slack on the upper bound permits legitimate stretch targets above
#' 100% (e.g., 105%) while still catching the 100x mismatch - the most common
#' user error where `target_value = 2.0` is passed intending "2%" instead of
#' the required proportion `0.02` (when `multiply = 1`).
#'
#' @param target_value Numeric target value passed to `bfh_qic()`.
#' @param y_axis_unit Unit type string from `bfh_qic()`.
#' @param multiply Numeric multiplier from `bfh_qic()`.
#'
#' @return Invisibly NULL on success. Stops with error on violation.
#' @keywords internal
#' @noRd
validate_target_for_unit <- function(target_value, y_axis_unit, multiply) {
  if (is.null(target_value) || !identical(y_axis_unit, "percent")) {
    return(invisible(NULL))
  }

  # Negativ check
  if (target_value < 0) {
    stop(
      sprintf(
        "target_value must be non-negative for y_axis_unit=\"percent\", got: %s",
        target_value
      ),
      call. = FALSE
    )
  }

  # Skala check
  upper_bound <- multiply * 1.5
  if (target_value > upper_bound) {
    hint <- if (isTRUE(all.equal(multiply, 1))) {
      sprintf(
        "Did you mean target_value = %s? Or set multiply = 100 to pass percent values.",
        target_value / 100
      )
    } else {
      sprintf(
        "Expected target_value in [0, %s] for multiply = %s.",
        upper_bound, multiply
      )
    }
    stop(
      sprintf(
        "target_value = %s er uden for forventet skala [0, %s] for y_axis_unit=\"percent\" med multiply = %s. %s",
        target_value, upper_bound, multiply, hint
      ),
      call. = FALSE
    )
  }

  invisible(NULL)
}

# ============================================================================
# DENOMINATOR CONTENT VALIDATION
# ============================================================================

#' Validate denominator column content for ratio charts
#'
#' Validates the content of the denominator column (`n`) for ratio chart types
#' (`p`, `pp`, `u`, `up`). Prevents silently misleading rate plots when input
#' data contains zero, negative, infinite, or proportion-violating denominators.
#'
#' **Contract:**
#' - Ratio charts (`p`, `pp`, `u`, `up`) require `n_col` non-NULL.
#' - `n` must be numeric.
#' - `n` must be finite (no `Inf`/`-Inf`).
#' - All non-`NA` values must satisfy `n > 0`.
#' - For proportion charts (`p`, `pp`): every row with both `y` and `n` present
#'   must satisfy `y <= n`.
#' - `NA` in individual rows of `n` is permitted (qicharts2 drops them).
#' - All other chart types skip validation.
#'
#' **Error format:** Violation messages identify offending row numbers
#' (1-indexed) so users can locate problematic rows in the source data.
#'
#' @param chart_type Character. SPC chart type (e.g., "p", "u", "i").
#' @param data Data frame passed to `bfh_qic()`.
#' @param y_col Character. Name of y-axis column in `data`.
#' @param n_col Character or NULL. Name of denominator column in `data`,
#'   or NULL if not supplied.
#'
#' @return Invisibly NULL on success. Stops with error on violation.
#' @keywords internal
#' @noRd
validate_denominator_data <- function(chart_type, data, y_col, n_col) {
  RATIO_CHARTS <- c("p", "pp", "u", "up")
  PROPORTION_CHARTS <- c("p", "pp")

  if (!chart_type %in% RATIO_CHARTS) {
    return(invisible(NULL))
  }

  if (is.null(n_col)) {
    stop(sprintf(
      "chart_type = \"%s\" requires denominator column `n`. Ratio charts (%s) need n.",
      chart_type, paste(RATIO_CHARTS, collapse = ", ")
    ), call. = FALSE)
  }

  if (!n_col %in% names(data)) {
    stop(sprintf(
      "denominator column `%s` not found in data",
      n_col
    ), call. = FALSE)
  }
  n_data <- data[[n_col]]

  if (!is.numeric(n_data)) {
    stop(sprintf(
      "denominator column `%s` must be numeric, got: %s",
      n_col, class(n_data)[1]
    ), call. = FALSE)
  }

  non_na <- !is.na(n_data)

  inf_rows <- which(non_na & is.infinite(n_data))
  if (length(inf_rows) > 0) {
    stop(sprintf(
      "denominator column `%s` contains Inf/-Inf at row(s): %s. Denominators must be finite.",
      n_col, paste(inf_rows, collapse = ", ")
    ), call. = FALSE)
  }

  zero_neg_rows <- which(non_na & is.finite(n_data) & n_data <= 0)
  if (length(zero_neg_rows) > 0) {
    stop(sprintf(
      "denominator column `%s` must be > 0, got %s at row(s): %s",
      n_col,
      paste(n_data[zero_neg_rows], collapse = ", "),
      paste(zero_neg_rows, collapse = ", ")
    ), call. = FALSE)
  }

  if (chart_type %in% PROPORTION_CHARTS) {
    if (!y_col %in% names(data)) {
      return(invisible(NULL))
    }
    y_data <- data[[y_col]]
    if (!is.numeric(y_data)) {
      return(invisible(NULL))
    }

    both_present <- !is.na(y_data) & !is.na(n_data)
    violation_rows <- which(both_present & y_data > n_data)
    if (length(violation_rows) > 0) {
      stop(sprintf(
        "Proportion chart \"%s\" requires y <= n. Violation at row(s): %s (y = %s, n = %s)",
        chart_type,
        paste(violation_rows, collapse = ", "),
        paste(y_data[violation_rows], collapse = ", "),
        paste(n_data[violation_rows], collapse = ", ")
      ), call. = FALSE)
    }
  }

  invisible(NULL)
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
