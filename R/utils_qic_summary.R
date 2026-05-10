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
#' @return Data frame with Danish column names and formatted values.
#'   One row per phase (part). Columns present depend on chart type:
#'
#'   **Always present:**
#'   - `fase` -- phase number (integer)
#'   - `antal_observationer` -- total observations per phase
#'   - `anvendelige_observationer` -- usable observations per phase
#'   - `laengste_loeb`, `laengste_loeb_max` -- run-length statistics
#'   - `antal_kryds`, `antal_kryds_min` -- crossing-count statistics
#'   - `anhoej_signal` -- combined Anhoej signal (runs OR crossings violation),
#'     sourced directly from `qicharts2::runs.signal` (logical)
#'   - `runs_signal` -- runs-rule outcome alone, derived per phase as
#'     `laengste_loeb > laengste_loeb_max` (logical, NA when inputs are NA)
#'   - `crossings_signal` -- crossings-rule outcome alone, derived per phase as
#'     `antal_kryds < antal_kryds_min` (logical, NA when inputs are NA)
#'   - `sigma_signal` -- sigma-rule signal aggregated per phase (logical)
#'   - `centerlinje` -- center line value
#'
#'   **Control limit columns (if lcl/ucl present in qic_data):**
#'   - `kontrolgraenser_konstante` -- logical, TRUE if control limits are
#'     identical for all observations within this phase. FALSE for p/u-charts
#'     with varying denominators.
#'
#'   *When ALL phases have constant limits* (e.g. I-charts, C-charts):
#'   - `nedre_kontrolgraense` -- scalar lower control limit per phase
#'   - `oevre_kontrolgraense` -- scalar upper control limit per phase
#'
#'   *When ANY phase has variable limits* (e.g. P-charts with varying n):
#'   - `nedre_kontrolgraense_min` / `nedre_kontrolgraense_max` -- range of LCL
#'   - `oevre_kontrolgraense_min` / `oevre_kontrolgraense_max` -- range of UCL
#'
#'   Run charts (no lcl/ucl) receive no control limit columns at all.
#'
#' @keywords internal
#' @noRd
#'
#' @details
#' **Column Translations:**
#' - part -> fase
#' - n.obs -> antal_observationer
#' - n.useful -> anvendelige_observationer
#' - cl -> centerlinje
#' - lcl / ucl -> se @return for kontrolgraense-kolonner
#' - runs.signal -> anhoej_signal (combined runs-or-crossings)
#'   - runs_signal (derived: laengste_loeb > laengste_loeb_max)
#'   - crossings_signal (derived: antal_kryds < antal_kryds_min)
#' - sigma.signal -> sigma_signal
#'
#' **Numeric precision:**
#' - Control limits and centerline are returned at raw `qicharts2::qic()`
#'   precision (no rounding). Display-layer consumers SHALL apply rounding when
#'   formatting strings (e.g. `format_target_value()`,
#'   `format_centerline_for_details()`); logic-layer consumers benefit from raw
#'   values for target-comparison precision (cf. issue #290).
#' - Counts: integers.
#' - Signals: converted to logical (TRUE/FALSE).
#'
#' **Control limits constancy:**
#' Constancy is checked per phase using `round(x, decimal_places + 2)` to
#' handle floating-point drift in qicharts2 output. A global column-branch
#' decision is made: if all phases are constant, scalar columns are used
#' (backward compatible); if any phase is variable, min/max columns are used
#' for all phases (with min == max for phases that happen to be constant).
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
  summary_cols <- c(
    "facet1", "facet2", "part", "n.obs", "n.useful",
    "longest.run", "longest.run.max", "n.crossings", "n.crossings.min",
    "runs.signal", "cl", "lcl", "ucl", "sigma.signal"
  )

  # Check which columns exist (run charts don't have lcl/ucl)
  available_cols <- intersect(summary_cols, names(qic_data))

  # Defensive early-return for empty qic_data. bfh_qic() blocks
  # nrow(data) == 0 upstream (utils_bfh_qic_helpers.R:310), so this only
  # triggers if qicharts2 itself returns zero rows (extreme exclude=
  # configuration). Without this, qic_data[1, ] returns a 1-row NA frame
  # that propagates NAs into runs_signal / crossings_signal columns.
  # Cycle 01 finding E6.
  if (nrow(qic_data) == 0L) {
    empty <- as.data.frame(setNames(
      replicate(length(available_cols), logical(0), simplify = FALSE),
      available_cols
    ), stringsAsFactors = FALSE)
    return(empty)
  }

  # Extract unique summary rows per part
  # Use split + per-part aggregation for correct Anhoej statistics
  if ("part" %in% names(qic_data)) {
    parts <- split(qic_data[, available_cols, drop = FALSE], qic_data$part)
    raw_summary <- dplyr::bind_rows(lapply(parts, function(x) {
      row <- x[1, , drop = FALSE]
      # Genberegn Anhoej-stats per part (qicharts2 beregner globalt)
      if ("longest.run" %in% names(x)) {
        row$longest.run <- safe_max(x$longest.run)
      }
      if ("longest.run.max" %in% names(x)) {
        row$longest.run.max <- safe_max(x$longest.run.max)
      }
      if ("n.crossings" %in% names(x)) {
        row$n.crossings <- safe_max(x$n.crossings)
      }
      if ("n.crossings.min" %in% names(x)) {
        row$n.crossings.min <- safe_max(x$n.crossings.min)
      }
      if ("runs.signal" %in% names(x)) {
        row$runs.signal <- any(x$runs.signal, na.rm = TRUE)
      }
      # sigma.signal varies per row (unlike longest.run which is per-phase constant).
      # Aggregate with any() so a single outlier in the phase is correctly reflected.
      if ("sigma.signal" %in% names(x)) {
        row$sigma.signal <- any(x$sigma.signal, na.rm = TRUE)
      }
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
    2 # default
  )

  # Create formatted summary with Danish column names
  formatted <- data.frame(
    fase = as.integer(raw_summary$part),
    antal_observationer = as.integer(raw_summary$n.obs),
    anvendelige_observationer = as.integer(raw_summary$n.useful),
    stringsAsFactors = FALSE
  )

  # Add Anhoej rules statistics
  formatted[["l\u00e6ngste_l\u00f8b"]] <- as.integer(raw_summary$longest.run)
  formatted[["l\u00e6ngste_l\u00f8b_max"]] <- as.integer(raw_summary$longest.run.max)
  formatted$antal_kryds <- as.integer(raw_summary$n.crossings)
  formatted$antal_kryds_min <- as.integer(raw_summary$n.crossings.min)

  # Add signals as logical values.
  # anhoej_signal is qicharts2's combined signal (runs OR crossings violation):
  # see qicharts2:::runs.analysis() where runs.signal = crsignal(...).
  # runs_signal and crossings_signal decompose the combined flag for diagnostic
  # clarity; both are pure derivations from already-formatted columns and inherit
  # NA from their inputs (degenerate phases where qicharts2 cannot compute).
  formatted$anhoej_signal <- as.logical(raw_summary$runs.signal)
  formatted$runs_signal <- formatted[["l\u00e6ngste_l\u00f8b"]] >
    formatted[["l\u00e6ngste_l\u00f8b_max"]]
  formatted$crossings_signal <- formatted$antal_kryds < formatted$antal_kryds_min
  formatted$sigma_signal <- as.logical(raw_summary$sigma.signal)

  # Add aggregated outlier counts per part when sigma.signal is available.
  has_sigma_signal <- "sigma.signal" %in% names(qic_data) &&
    any(!is.na(qic_data$sigma.signal))

  part_key <- as.character(raw_summary$part)

  if (has_sigma_signal) {
    if ("part" %in% names(qic_data)) {
      outliers_by_part <- vapply(
        split(qic_data$sigma.signal, qic_data$part),
        function(x) sum(x, na.rm = TRUE),
        integer(1)
      )
      formatted$forventede_outliers <- unname(as.integer(rep(0L, length(part_key))))
      formatted$antal_outliers <- unname(as.integer(outliers_by_part[part_key]))
    } else {
      formatted$forventede_outliers <- 0L
      formatted$antal_outliers <- as.integer(sum(qic_data$sigma.signal, na.rm = TRUE))
    }
  }

  # Add control limits at raw qicharts2 precision (no rounding).
  # Display-layer consumers (format_target_value, format_centerline_for_details)
  # apply their own rounding when emitting strings. Logic-layer consumers
  # (e.g. spc_analysis::.evaluate_target_arm) need raw values to avoid
  # round-off bugs near target-comparison boundaries (cf. issue #290).
  if ("cl" %in% names(raw_summary)) {
    formatted$centerlinje <- raw_summary$cl
  }

  if ("lcl" %in% names(raw_summary) && "ucl" %in% names(raw_summary)) {
    # decimal_places + 2 afrundingsprecision: tolerance ved konstans-detektion
    # for at absorbere floating-point drift fra qicharts2 (per-row "konstante"
    # graenser kan afvige i 4. decimal). Detektion ROUNDS, men den lagrede
    # vaerdi forbliver raa.
    round_prec <- decimal_places + 2

    lcl_split <- split(qic_data$lcl, qic_data$part)
    ucl_split <- split(qic_data$ucl, qic_data$part)

    # Er graenser konstante inden for den paagaeldende fase?
    lcl_const_per_part <- vapply(part_key, function(p) {
      length(unique(round(lcl_split[[p]], round_prec))) <= 1
    }, logical(1))
    ucl_const_per_part <- vapply(part_key, function(p) {
      length(unique(round(ucl_split[[p]], round_prec))) <= 1
    }, logical(1))

    # Per-row flag: TRUE kun hvis BEGGE lcl og ucl er konstante i den fase
    part_konstant <- lcl_const_per_part & ucl_const_per_part

    # Global beslutning: er ALLE faser konstante?
    alle_konstante <- all(part_konstant)

    # Tilfoej per-row flag
    formatted[["kontrolgr\u00e6nser_konstante"]] <- part_konstant

    if (alle_konstante) {
      # Backward-compat: bevar skalare kolonner (\u00e9n vaerdi per fase) i raa precision
      formatted[["nedre_kontrolgr\u00e6nse"]] <- raw_summary$lcl
      formatted[["\u00f8vre_kontrolgr\u00e6nse"]] <- raw_summary$ucl
    } else {
      # Variable graenser: eksponer min/max per fase i raa precision
      formatted[["nedre_kontrolgr\u00e6nse_min"]] <- vapply(part_key, function(p) {
        min(lcl_split[[p]], na.rm = TRUE)
      }, numeric(1))
      formatted[["nedre_kontrolgr\u00e6nse_max"]] <- vapply(part_key, function(p) {
        max(lcl_split[[p]], na.rm = TRUE)
      }, numeric(1))
      formatted[["\u00f8vre_kontrolgr\u00e6nse_min"]] <- vapply(part_key, function(p) {
        min(ucl_split[[p]], na.rm = TRUE)
      }, numeric(1))
      formatted[["\u00f8vre_kontrolgr\u00e6nse_max"]] <- vapply(part_key, function(p) {
        max(ucl_split[[p]], na.rm = TRUE)
      }, numeric(1))
    }
  }

  # Optionally add 95% limits if present (raa precision)
  if ("lcl.95" %in% names(raw_summary) && "ucl.95" %in% names(raw_summary)) {
    formatted[["nedre_kontrolgr\u00e6nse_95"]] <- raw_summary$lcl.95
    formatted[["\u00f8vre_kontrolgr\u00e6nse_95"]] <- raw_summary$ucl.95
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
