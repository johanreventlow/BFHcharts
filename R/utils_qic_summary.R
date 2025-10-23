#' QIC Summary Formatting Utilities
#'
#' Format summary statistics from qicharts2 for user-friendly Danish output.
#'
#' @name utils_qic_summary
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
  # Use split + first row approach to handle variable control limits in p/u charts
  if ("part" %in% names(qic_data)) {
    # Split by part and take first row of each group
    parts <- split(qic_data[, available_cols, drop = FALSE], qic_data$part)
    raw_summary <- do.call(rbind, lapply(parts, function(x) x[1, , drop = FALSE]))
    row.names(raw_summary) <- NULL
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

  if ("lcl" %in% names(raw_summary)) {
    formatted$nedre_kontrolgrænse <- round(raw_summary$lcl, decimal_places)
  }

  if ("ucl" %in% names(raw_summary)) {
    formatted$øvre_kontrolgrænse <- round(raw_summary$ucl, decimal_places)
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
