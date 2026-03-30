#' QIC Summary Formatting Utilities
#'
#' Format summary statistics from qicharts2 for user-friendly Danish output.
#'
#' @name utils_qic_summary
#' @keywords internal
#' @noRd
NULL

# ============================================================================
# QIC SUMMARY FORMATTING
# ============================================================================

#' Format QIC Summary Statistics
#'
#' Extracts and formats summary statistics from qic data frame with
#' Danish column names and appropriate rounding.
#'
#' @param qic_data Data frame from qicharts2::qic(..., return.data = TRUE)
#' @param y_axis_unit Unit type for appropriate rounding ("count", "percent", "rate", "time")
#'
#' @return Data frame with Danish column names and formatted values
#' @keywords internal
#' @noRd
#'
#' @details
#' **Column Translations:**
#' - part → fase
#' - n.obs → antal_observationer
#' - n.useful → anvendelige_observationer
#' - cl → centerlinje
#' - lcl / ucl → nedre_kontrolgrænse / øvre_kontrolgrænse
#' - runs.signal → løbelængde_signal
#' - sigma.signal → sigma_signal
#'
#' **Rounding Rules:**
#' - Control limits: 2 decimals for percent/rate, 1 decimal for count/time
#' - Counts: integers
#' - Signals: converted to logical (TRUE/FALSE)
#'
#' @examples
#' \dontrun{
#' qic_data <- qic(month, infections, data = data, chart = "i", return.data = TRUE)
#' formatted <- format_qic_summary(qic_data, y_axis_unit = "count")
#' }
format_qic_summary <- function(qic_data, y_axis_unit = "count") {
  # Validate input
  if (!is.data.frame(qic_data)) {
    stop("qic_data must be a data frame", call. = FALSE)
  }

  # Define summary columns to extract
  summary_cols <- c('facet1', 'facet2', 'part', 'n.obs', 'n.useful',
                    'longest.run', 'longest.run.max', 'n.crossings', 'n.crossings.min',
                    'runs.signal', 'cl', 'lcl', 'ucl', 'sigma.signal')

  # Check which columns exist (run charts don't have lcl/ucl)
  available_cols <- intersect(summary_cols, names(qic_data))

  # Extract unique summary rows per part
  # Use split + per-part aggregation for correct Anhøj statistics
  if ("part" %in% names(qic_data)) {
    parts <- split(qic_data[, available_cols, drop = FALSE], qic_data$part)
    raw_summary <- dplyr::bind_rows(lapply(parts, function(x) {
      row <- x[1, , drop = FALSE]
      # Genberegn Anh\u00f8j-stats per part (qicharts2 beregner globalt)
      safe_max <- function(v) {
        v <- v[!is.na(v)]
        if (length(v) == 0) return(NA_real_)
        max(v)
      }
      safe_min <- function(v) {
        v <- v[!is.na(v)]
        if (length(v) == 0) return(NA_real_)
        min(v)
      }
      if ("longest.run" %in% names(x))
        row$longest.run <- safe_max(x$longest.run)
      if ("longest.run.max" %in% names(x))
        row$longest.run.max <- safe_max(x$longest.run.max)
      if ("n.crossings" %in% names(x))
        row$n.crossings <- safe_max(x$n.crossings)
      if ("n.crossings.min" %in% names(x))
        row$n.crossings.min <- safe_max(x$n.crossings.min)
      if ("runs.signal" %in% names(x))
        row$runs.signal <- any(x$runs.signal, na.rm = TRUE)
      row
    }))
  } else {
    # No parts - take first row only
    raw_summary <- qic_data[1, available_cols, drop = FALSE]
  }

  # Determine decimal places for control limits based on unit
  decimal_places <- switch(y_axis_unit,
    "percent" = 2,
    "rate" = 2,
    "count" = 1,
    "time" = 1,
    2  # default
  )

  # Create formatted summary with Danish column names
  formatted <- data.frame(
    fase = as.integer(raw_summary$part),
    antal_observationer = as.integer(raw_summary$n.obs),
    anvendelige_observationer = as.integer(raw_summary$n.useful),
    stringsAsFactors = FALSE
  )

  # Add Anhøj rules statistics
  formatted$længste_løb <- as.integer(raw_summary$longest.run)
  formatted$længste_løb_max <- as.integer(raw_summary$longest.run.max)
  formatted$antal_kryds <- as.integer(raw_summary$n.crossings)
  formatted$antal_kryds_min <- as.integer(raw_summary$n.crossings.min)

  # Add signals as logical values
  formatted$løbelængde_signal <- as.logical(raw_summary$runs.signal)
  formatted$sigma_signal <- as.logical(raw_summary$sigma.signal)

  # Add control limits with appropriate rounding (if they exist)
  if ("cl" %in% names(raw_summary)) {
    formatted$centerlinje <- round(raw_summary$cl, decimal_places)
  }

  # Only include lcl/ucl if they are constant across observations
  # For p/u charts, control limits vary per observation based on denominator
  # so showing a single value is misleading
  if ("lcl" %in% names(raw_summary) && "ucl" %in% names(raw_summary)) {
    # Check if control limits are constant by comparing unique values
    # within each part (phase)
    lcl_constant <- all(vapply(split(qic_data$lcl, qic_data$part), function(x) {
      length(unique(round(x, decimal_places + 2))) <= 1
    }, logical(1)))
    ucl_constant <- all(vapply(split(qic_data$ucl, qic_data$part), function(x) {
      length(unique(round(x, decimal_places + 2))) <= 1
    }, logical(1)))

    if (lcl_constant && ucl_constant) {
      formatted$nedre_kontrolgrænse <- round(raw_summary$lcl, decimal_places)
      formatted$øvre_kontrolgrænse <- round(raw_summary$ucl, decimal_places)
    }
    # If not constant, don't include them in summary
  }

  # Optionally add 95% limits if present
  if ("lcl.95" %in% names(raw_summary) && "ucl.95" %in% names(raw_summary)) {
    formatted$nedre_kontrolgrænse_95 <- round(raw_summary$lcl.95, decimal_places)
    formatted$øvre_kontrolgrænse_95 <- round(raw_summary$ucl.95, decimal_places)
  }

  # Add facet columns if present
  if ("facet1" %in% names(raw_summary)) {
    # Insert at beginning
    formatted <- data.frame(
      facet1 = raw_summary$facet1,
      formatted,
      stringsAsFactors = FALSE
    )
  }

  if ("facet2" %in% names(raw_summary)) {
    # Insert after facet1
    col_order <- names(formatted)
    facet1_pos <- which(col_order == "facet1")
    if (length(facet1_pos) > 0) {
      formatted <- data.frame(
        formatted[, 1:facet1_pos, drop = FALSE],
        facet2 = raw_summary$facet2,
        formatted[, (facet1_pos + 1):ncol(formatted), drop = FALSE],
        stringsAsFactors = FALSE
      )
    } else {
      formatted <- data.frame(
        facet2 = raw_summary$facet2,
        formatted,
        stringsAsFactors = FALSE
      )
    }
  }

  return(formatted)
}
