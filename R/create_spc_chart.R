#' Create SPC Chart - High-Level Convenience Function
#'
#' One-function approach to create publication-ready SPC charts.
#' Wraps qicharts2 calculation and BFH visualization in a single call.
#'
#' @name create_spc_chart
NULL

# ============================================================================
# HIGH-LEVEL WRAPPER
# ============================================================================

#' Create Complete SPC Chart from Raw Data
#'
#' Convenience function that combines qicharts2::qic() calculation with
#' BFH-styled visualization and automatic label placement. Handles the
#' entire workflow from raw data to finished plot with intelligent labels.
#'
#' @param data Data frame with measurements
#' @param x Name of x-axis column (unquoted, NSE). Usually date/time column.
#' @param y Name of y-axis column (unquoted, NSE). The measurement variable.
#' @param n Name of denominator column for ratio charts (optional, unquoted, NSE)
#' @param chart_type Chart type: "run", "i", "p", "c", "u", "xbar", "s", "t", "g"
#' @param y_axis_unit Unit type: "count", "percent", "rate", or "time"
#' @param chart_title Plot title (optional)
#' @param target_value Numeric target value (optional)
#' @param target_text Target label text (optional)
#' @param notes Character vector of annotations for data points (optional, same length as data)
#' @param part Positions for phase splits (optional numeric vector)
#' @param freeze Position to freeze baseline (optional integer)
#' @param base_size Base font size in points (default: auto-calculated from width/height if provided, otherwise 14)
#' @param width Plot width in inches (optional, enables responsive font scaling and precise label placement)
#' @param height Plot height in inches (optional, enables responsive font scaling and precise label placement)
#'
#' @return ggplot2 object with styled SPC chart
#'
#' @details
#' **Chart Types:**
#' - **run**: Run chart (no control limits)
#' - **i**: I-chart (individuals)
#' - **p**: P-chart (proportions, requires n)
#' - **c**: C-chart (counts)
#' - **u**: U-chart (rates, requires n)
#' - **xbar**: X-bar chart
#' - **s**: S-chart
#' - **t**: T-chart (time between events)
#' - **g**: G-chart (geometric)
#'
#' **Y-Axis Units:**
#' - **count**: Integer counts with K/M notation
#' - **percent**: Percentage values (0-100%)
#' - **rate**: Decimal values with comma notation
#' - **time**: Context-aware minutes/hours/days
#'
#' **Phase Configuration:**
#' - `part`: Vector of positions where phase splits occur (e.g., `c(12, 24)`)
#' - `freeze`: Position to freeze baseline calculation
#'
#' **Responsive Typography:**
#' When `width` and `height` are provided, `base_size` is automatically
#' calculated using geometric mean: `sqrt(width × height) / 3.5`
#' This ensures fonts scale proportionally with plot size.
#' Override by explicitly setting `base_size`.
#'
#' **Automatic Label Placement:**
#' Labels are automatically added to the plot showing:
#' - Current level (CL) from the most recent phase
#' - Target value (if specified via `target_value` or `target_text`)
#' - Intelligent collision avoidance with multi-level fallback strategy
#' - Provide `width` and `height` for optimal label sizing and placement
#'
#' **Arrow Symbol Suppression:**
#' If `target_text` contains arrow symbols (↑ ↓ or < >), the target line will be
#' suppressed and only the directional indicator shown at the plot edge.
#'
#' @export
#' @examples
#' \dontrun{
#' library(BFHcharts)
#'
#' # Example 1: Simple run chart with monthly data
#' data <- data.frame(
#'   month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
#'   infections = rpois(24, lambda = 15),
#'   surgeries = rpois(24, lambda = 100)
#' )
#'
#' plot <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "run",
#'   y_axis_unit = "count",
#'   chart_title = "Monthly Hospital-Acquired Infections"
#' )
#' plot
#'
#' # Example 2: P-chart with target line
#' plot <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   n = surgeries,
#'   chart_type = "p",
#'   y_axis_unit = "percent",
#'   chart_title = "Infection Rate per 100 Surgeries",
#'   target_value = 2.0,
#'   target_text = "↓ Målet: 2%"
#' )
#' plot
#'
#' # Example 3: I-chart with phase splits
#' plot <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Infections with Intervention",
#'   part = c(12), # Phase split after 12 months
#'   freeze = 12 # Freeze baseline at month 12
#' )
#' plot
#'
#' # Example 4: Chart with annotations using notes
#' notes_vec <- rep(NA, 24)
#' notes_vec[3] <- "Start of intervention"
#' notes_vec[12] <- "New protocol implemented"
#' notes_vec[18] <- "Staff training completed"
#'
#' plot <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Infections with Annotated Events",
#'   notes = notes_vec
#' )
#' plot
#'
#' # Example 5: Responsive typography with viewport dimensions
#' # Small plot (6×4 inches) → base_size ≈ 14pt
#' plot_small <- create_spc_chart(
#'   data = data, x = month, y = infections,
#'   chart_type = "i", y_axis_unit = "count",
#'   chart_title = "Small Plot - Auto Scaled Typography",
#'   width = 6, height = 4  # Auto: base_size ≈ 14pt
#' )
#'
#' # Medium plot (10×6 inches) → base_size ≈ 22pt
#' plot_medium <- create_spc_chart(
#'   data = data, x = month, y = infections,
#'   chart_type = "i", y_axis_unit = "count",
#'   chart_title = "Medium Plot - Auto Scaled Typography",
#'   width = 10, height = 6  # Auto: base_size ≈ 22pt
#' )
#'
#' # Large plot (16×9 inches) → base_size ≈ 34pt
#' plot_large <- create_spc_chart(
#'   data = data, x = month, y = infections,
#'   chart_type = "i", y_axis_unit = "count",
#'   chart_title = "Large Plot - Auto Scaled Typography",
#'   width = 16, height = 9  # Auto: base_size ≈ 34pt
#' )
#'
#' # Override auto-scaling with explicit base_size
#' plot_custom <- create_spc_chart(
#'   data = data, x = month, y = infections,
#'   chart_type = "i", y_axis_unit = "count",
#'   chart_title = "Custom Typography Override",
#'   width = 10, height = 6,
#'   base_size = 18  # Explicit override
#' )
#' }
create_spc_chart <- function(data,
                              x,
                              y,
                              n = NULL,
                              chart_type = "run",
                              y_axis_unit = "count",
                              chart_title = NULL,
                              target_value = NULL,
                              target_text = NULL,
                              notes = NULL,
                              part = NULL,
                              freeze = NULL,
                              base_size = 14,
                              width = NULL,
                              height = NULL) {
  # Validate inputs
  if (!is.data.frame(data)) {
    stop("data must be a data frame")
  }

  # Validate chart type
  valid_chart_types <- c("run", "i", "p", "c", "u", "xbar", "s", "t", "g")
  if (!chart_type %in% valid_chart_types) {
    stop(sprintf(
      "chart_type must be one of: %s",
      paste(valid_chart_types, collapse = ", ")
    ))
  }

  # Validate y_axis_unit
  valid_units <- c("count", "percent", "rate", "time")
  if (!y_axis_unit %in% valid_units) {
    stop(sprintf(
      "y_axis_unit must be one of: %s",
      paste(valid_units, collapse = ", ")
    ))
  }

  # Build qicharts2::qic() arguments using NSE
  qic_args <- list(
    data = data,
    x = substitute(x),
    y = substitute(y),
    chart = chart_type,
    return.data = TRUE
  )

  # Add optional arguments
  if (!missing(n) && !is.null(substitute(n))) {
    qic_args$n <- substitute(n)
  }

  if (!is.null(part)) {
    qic_args$part <- part
  }

  if (!is.null(freeze)) {
    qic_args$freeze <- freeze
  }

  if (!is.null(target_value) && is.numeric(target_value)) {
    qic_args$target <- target_value
  }

  if (!is.null(notes)) {
    qic_args$notes <- notes
  }

  # Execute qicharts2::qic() to get calculation results
  qic_data <- do.call(qicharts2::qic, qic_args, envir = parent.frame())

  # Post-process: Add combined anhoej.signal column
  # This combines runs.signal and crossings.signal per part
  if (!is.null(qic_data)) {
    # Use runs.signal directly from qicharts2
    runs_sig_col <- if ("runs.signal" %in% names(qic_data)) {
      qic_data$runs.signal
    } else {
      rep(FALSE, nrow(qic_data))
    }

    # Calculate crossings signal per part using dplyr
    if ("n.crossings" %in% names(qic_data) &&
      "n.crossings.min" %in% names(qic_data) &&
      "part" %in% names(qic_data)) {
      qic_data <- qic_data |>
        dplyr::group_by(part) |>
        dplyr::mutate(
          part_n_cross = max(n.crossings, na.rm = TRUE),
          part_n_cross_min = max(n.crossings.min, na.rm = TRUE),
          crossings_signal = !is.na(part_n_cross) & !is.na(part_n_cross_min) &
            part_n_cross < part_n_cross_min
        ) |>
        dplyr::ungroup()

      # Combine: TRUE if EITHER runs OR crossings signal
      qic_data$anhoej.signal <- runs_sig_col | qic_data$crossings_signal

      # Cleanup intermediate columns
      qic_data$part_n_cross <- NULL
      qic_data$part_n_cross_min <- NULL
      qic_data$crossings_signal <- NULL
    } else {
      # No crossings data - use runs.signal only
      qic_data$anhoej.signal <- runs_sig_col
    }
  }

  # Calculate responsive base_size if viewport dimensions provided
  # Uses geometric mean approach: sqrt(width × height) / divisor
  if (!is.null(width) && !is.null(height)) {
    calculated_base_size <- calculate_base_size(width, height)
    # Use calculated size unless user explicitly provided base_size
    if (missing(base_size)) {
      base_size <- calculated_base_size
    }
  }

  # Create plot configuration
  plot_config <- spc_plot_config(
    chart_type = chart_type,
    y_axis_unit = y_axis_unit,
    chart_title = chart_title,
    target_value = target_value,
    target_text = target_text
  )

  # Create viewport configuration
  viewport <- viewport_dims(base_size = base_size)

  # Generate plot using bfh_spc_plot()
  plot <- bfh_spc_plot(
    qic_data = qic_data,
    plot_config = plot_config,
    viewport = viewport
  )

  # Convert width/height to viewport dimensions (inches)
  # This enables precise label placement even without open graphics device
  viewport_width_inches <- width
  viewport_height_inches <- height

  # Add SPC labels automatically
  plot <- add_spc_labels(
    plot = plot,
    qic_data = qic_data,
    y_axis_unit = y_axis_unit,
    label_size = viewport$base_size / 14 * 6,  # Responsive label sizing
    viewport_width = viewport_width_inches,
    viewport_height = viewport_height_inches,
    target_text = target_text,
    verbose = FALSE
  )

  return(plot)
}
