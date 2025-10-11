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
#' @param comment_column Name of comment column for annotations (optional, quoted)
#' @param part Positions for phase splits (optional numeric vector)
#' @param freeze Position to freeze baseline (optional integer)
#' @param base_size Base font size for responsive scaling (default: 14)
#' @param width Plot width in inches (optional, improves label placement precision)
#' @param height Plot height in inches (optional, improves label placement precision)
#' @param colors Color palette (default: [BFH_COLORS])
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
#' # Example 4: Custom hospital colors
#' my_colors <- create_color_palette(
#'   primary = "#003366",
#'   secondary = "#808080",
#'   accent = "#FF9900"
#' )
#'
#' plot <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "run",
#'   y_axis_unit = "count",
#'   chart_title = "Custom Branded Chart",
#'   colors = my_colors
#' )
#' plot
#'
#' # Example 5: Specify dimensions for optimal label placement
#' plot <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Infections with Optimal Label Placement",
#'   width = 10,   # inches - matches ggsave width
#'   height = 6,   # inches - matches ggsave height
#'   target_value = 15,
#'   target_text = "<15"
#' )
#'
#' # Save with same dimensions for perfect label sizing
#' ggsave("output.png", plot, width = 10, height = 6, dpi = 300)
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
                              comment_column = NULL,
                              part = NULL,
                              freeze = NULL,
                              base_size = 14,
                              width = NULL,
                              height = NULL,
                              colors = BFH_COLORS) {
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

  # Create plot configuration
  plot_config <- spc_plot_config(
    chart_type = chart_type,
    y_axis_unit = y_axis_unit,
    chart_title = chart_title,
    target_value = target_value,
    target_text = target_text,
    comment_column = comment_column
  )

  # Create viewport configuration
  viewport <- viewport_dims(base_size = base_size)

  # Generate plot using bfh_spc_plot()
  plot <- bfh_spc_plot(
    qic_data = qic_data,
    plot_config = plot_config,
    viewport = viewport,
    colors = colors
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
