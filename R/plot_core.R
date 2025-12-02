#' Core SPC Plot Generation
#'
#' Main function for creating beautifully styled SPC charts from qicharts2 output.
#' Takes pre-calculated QIC data and builds a publication-ready ggplot.
#'
#' @name plot_core
#' @keywords internal
#' @noRd
NULL

# ============================================================================
# MAIN PLOT FUNCTION
# ============================================================================

#' Create BFH-Styled SPC Plot from QIC Data
#'
#' Builds a complete SPC chart visualization from qicharts2 calculation results.
#' This function handles plot construction, intelligent X-axis formatting,
#' Y-axis unit formatting, control limits, and enhancements.
#'
#' @param qic_data Data frame from qicharts2::qic() with return.data = TRUE
#' @param plot_config Plot configuration from [spc_plot_config()]
#' @param viewport Viewport dimensions from [viewport_dims()]
#' @param phase Optional phase configuration from [phase_config()]
#' @param plot_margin Numeric vector of length 4 (top, right, bottom, left) in mm,
#'   or a margin object from ggplot2::margin(), or NULL for default
#'
#' @return ggplot2 object
#'
#' @details
#' **Required columns in qic_data:**
#' - `x`: X-axis values (Date, POSIXct, or numeric)
#' - `y`: Y-axis values (numeric)
#' - `cl`: Centerline values
#' - `part`: Phase identifiers
#'
#' **Optional columns:**
#' - `ucl`, `lcl`: Control limits
#' - `target`: Target line
#' - `anhoej.signal`: Anhoej signal detection (logical)
#' - `.original_row_id`: For comment mapping
#'
#' **Intelligent Features:**
#' - Automatic date interval detection and formatting
#' - Unit-aware Y-axis formatting (count/percent/rate/time)
#' - Extended lines (20% beyond last data point)
#' - Anhoej signal linetype switching
#'
#' @keywords internal
#' @noRd
#' @family spc-plotting
#' @seealso [bfh_qic()], [spc_plot_config()], [viewport_dims()], [phase_config()]
#' @examples
#' \dontrun{
#' library(qicharts2)
#' library(BFHcharts)
#'
#' # Calculate QIC data
#' data <- data.frame(
#'   month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
#'   value = rnorm(24, 100, 10)
#' )
#'
#' qic_result <- qic(
#'   x = month,
#'   y = value,
#'   data = data,
#'   chart = "i",
#'   return.data = TRUE
#' )
#'
#' # Create plot
#' config <- spc_plot_config(
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Monthly Performance"
#' )
#'
#' viewport <- viewport_dims(base_size = 14)
#'
#' plot <- bfh_spc_plot(qic_result, config, viewport)
#' plot
#' }
bfh_spc_plot <- function(qic_data,
                         plot_config = spc_plot_config(),
                         viewport = viewport_dims(),
                         phase = NULL,
                         plot_margin = NULL) {
  # Validate inputs
  if (!is.data.frame(qic_data)) {
    stop("qic_data must be a data frame from qicharts2::qic(return.data = TRUE)")
  }

  required_cols <- c("x", "y", "cl", "part")
  missing_cols <- setdiff(required_cols, names(qic_data))
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "qic_data missing required columns: %s",
      paste(missing_cols, collapse = ", ")
    ))
  }

  # Add anhoej.signal column if missing (for linetype switching)
  if (!"anhoej.signal" %in% names(qic_data)) {
    qic_data$anhoej.signal <- FALSE
  }

  # Calculate responsive geom sizes based on base_size
  scale_factor <- viewport$base_size / 14

  ucl_linewidth <- 2.5 * scale_factor
  target_linewidth <- 1 * scale_factor
  data_linewidth <- 1 * scale_factor
  cl_linewidth <- 1 * scale_factor
  point_size <- 2 * scale_factor
  comment_size <- 6 * scale_factor

  # Detect arrow symbols in target_text for target line suppression
  suppress_targetline <- FALSE
  if (!is.null(plot_config$target_text) && nchar(trimws(plot_config$target_text)) > 0) {
    suppress_targetline <- has_arrow_symbol(plot_config$target_text)
  }

  # Extract comment data from qic notes column if present
  comment_data <- extract_comment_data(qic_data, max_length = 100)

  # Build base plot ----
  plot <- ggplot2::ggplot(qic_data, ggplot2::aes(x = x, y = y))

  # Pre-compute layers for performance
  plot_layers <- list()

  # Control limits ribbon and text lines ----
  if (!is.null(qic_data$ucl) && !all(is.na(qic_data$ucl)) &&
    !is.null(qic_data$lcl) && !all(is.na(qic_data$lcl))) {
    plot_layers <- c(plot_layers, list(
      ggplot2::geom_ribbon(
        ggplot2::aes(ymin = lcl, ymax = ucl),
        fill = BFHtheme::bfh_cols("very_light_blue"),
        alpha = 0.5
      ),
      geomtextpath::geom_textline(
        ggplot2::aes(y = ucl, x = x, label = "\u00d8vre kontrolgr\u00e6nse"),
        inherit.aes = FALSE,
        hjust = 0.05,
        vjust = -0.2,
        linewidth = ucl_linewidth,
        linecolour = NA,
        textcolour = BFHtheme::bfh_cols("hospital_grey"),
        size = 3.0,
        na.rm = TRUE
      ),
      geomtextpath::geom_textline(
        ggplot2::aes(y = lcl, x = x, label = "Nedre kontrolgr\u00e6nse"),
        inherit.aes = FALSE,
        hjust = 0.05,
        vjust = 1.2,
        linewidth = ucl_linewidth,
        linecolour = NA,
        textcolour = BFHtheme::bfh_cols("hospital_grey"),
        size = 3.0,
        na.rm = TRUE
      )
    ))
  }

  # Target line (conditionally suppressed) ----
  if (!suppress_targetline) {
    plot_layers <- c(plot_layers, list(
      ggplot2::geom_line(
        ggplot2::aes(y = target, x = x),
        inherit.aes = FALSE,
        linewidth = target_linewidth,
        colour = BFHtheme::bfh_cols("hospital_dark_grey"),
        linetype = "42",
        na.rm = TRUE
      )
    ))
  }

  # Core data visualization layers ----
  plot_layers <- c(plot_layers, list(
    ggplot2::geom_line(
      ggplot2::aes(y = y, group = part),
      colour = BFHtheme::bfh_cols("hospital_grey"),
      linewidth = data_linewidth,
      na.rm = TRUE
    ),
    ggplot2::geom_point(
      ggplot2::aes(y = y, group = part),
      colour = BFHtheme::bfh_cols("hospital_grey"),
      size = point_size,
      na.rm = TRUE
    ),
    ggplot2::geom_line(
      ggplot2::aes(y = cl, group = part, linetype = anhoej.signal),
      color = BFHtheme::bfh_cols("hospital_blue"),
      linewidth = cl_linewidth
    )
  ))

  # Labels and scale configuration ----
  # Use BFHtheme::bfh_labs() for automatic uppercase formatting per BFH typography guidelines
  # (title remains unchanged, x/y/subtitle/caption are uppercased)
  plot_layers <- c(plot_layers, list(
    BFHtheme::bfh_labs(
      title = plot_config$chart_title,
      x = plot_config$xlab,
      y = plot_config$ylab,
      subtitle = plot_config$subtitle,
      caption = plot_config$caption
    ),
    ggplot2::scale_linetype_manual(
      values = c("FALSE" = "solid", "TRUE" = "12"),
      guide = "none"
    )
  ))

  # Add all layers in single operation (performance optimization)
  plot <- plot + plot_layers

  # Intelligent X-axis formatting ----
  plot <- apply_x_axis_formatting(plot, qic_data, viewport)

  # Y-axis formatting based on unit type ----
  plot <- apply_y_axis_formatting(plot, plot_config$y_axis_unit, qic_data)

  # Add plot enhancements (extended lines, comments) ----
  plot <- add_plot_enhancements(
    plot = plot,
    qic_data = qic_data,
    comment_data = comment_data,
    cl_linewidth = cl_linewidth,
    target_linewidth = target_linewidth,
    comment_size = comment_size,
    suppress_targetline = suppress_targetline
  )

  # Apply theme ----
  plot <- apply_spc_theme(plot, viewport$base_size, plot_margin)

  return(plot)
}

# ============================================================================
# X-AXIS FORMATTING
# ============================================================================

#' Apply Intelligent X-Axis Formatting
#'
#' Handles date-based and numeric X-axis formatting with intelligent
#' interval detection and break calculation.
#'
#' @param plot ggplot object
#' @param qic_data QIC data frame
#' @param viewport Viewport dimensions with base_size
#'
#' @return Modified ggplot object
#' @keywords internal
#' @noRd
apply_x_axis_formatting <- function(plot, qic_data, viewport) {
  x_col <- qic_data$x

  # Dispatch to appropriate formatter based on x-column type
  if (inherits(x_col, c("POSIXct", "POSIXt", "Date"))) {
    # Compute min/max and normalize to POSIXct for temporal formatter
    data_x_min <- min(x_col, na.rm = TRUE)
    data_x_max <- max(x_col, na.rm = TRUE)
    data_x_min <- normalize_to_posixct(data_x_min)
    data_x_max <- normalize_to_posixct(data_x_max)

    apply_temporal_x_axis(plot, x_col, data_x_min, data_x_max)
  } else if (is.numeric(x_col)) {
    apply_numeric_x_axis(plot)
  } else {
    plot  # Unknown type → return unchanged
  }
}
