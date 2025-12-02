#' Plot Configuration Objects
#'
#' Parameter objects for reducing function signature complexity.
#'
#' ## Architecture
#'
#' Instead of functions with 15+ parameters, this module provides **parameter
#' objects** that group related configuration into logical units.
#'
#' **Benefits**:
#' - Reduced function signatures (15 params → 3-5 params)
#' - Logical parameter grouping (easier to understand)
#' - Easier to extend (add fields without changing signatures)
#' - Self-documenting code (object names describe purpose)
#'
#' ## Usage
#'
#' ```r
#' # Before (15 parameters - hard to read):
#' plot <- bfh_qic(
#'   data, x = "Date", y = "Value", chart_type = "p",
#'   target_value = 50, centerline_value = NULL,
#'   show_phases = FALSE, y_axis_unit = "percent",
#'   base_size = 14, width = 800, height = 600
#' )
#'
#' # After (3 parameter objects - clear and maintainable):
#' plot_cfg <- spc_plot_config(
#'   chart_type = "p",
#'   y_axis_unit = "percent",
#'   target_value = 50
#' )
#'
#' viewport <- viewport_dims(width = 800, height = 600, base_size = 14)
#' phases <- phase_config(show_phases = FALSE)
#'
#' plot <- bfh_spc_plot(qic_data, plot_cfg, viewport, phases)
#' ```
#'
#' @name config_objects
#' @keywords internal
#' @noRd
NULL

# ============================================================================
# SPC PLOT CONFIGURATION
# ============================================================================

#' Create SPC Plot Configuration
#'
#' Creates a configuration object for SPC plot generation.
#'
#' @param chart_type Chart type (run, i, p, c, u, etc.)
#' @param y_axis_unit Y-axis unit ("count", "percent", "rate", "time")
#' @param target_value Numeric target value (optional)
#' @param target_text Text description of target (optional)
#' @param centerline_value Custom centerline value (optional)
#' @param chart_title Chart title (optional)
#' @param ylab Y-axis label (default: "" for blank)
#' @param xlab X-axis label (default: "" for blank)
#' @param subtitle Plot subtitle text (optional)
#' @param caption Plot caption text (optional)
#'
#' @return List with class "spc_plot_config"
#'
#' @details
#' This object groups all plot-specific configuration that controls
#' the appearance and behavior of the SPC chart.
#'
#' **Validation**:
#' - `chart_type` must be one of the valid SPC chart types
#' - `y_axis_unit` must be one of: count, percent, rate, time
#' - `target_value` must be numeric if provided
#'
#' @keywords internal
#' @noRd
#' @examples
#' # Basic configuration
#' cfg <- spc_plot_config(chart_type = "run", y_axis_unit = "count")
#'
#' # With target
#' cfg <- spc_plot_config(
#'   chart_type = "p",
#'   y_axis_unit = "percent",
#'   target_value = 95,
#'   target_text = "Target: 95%"
#' )
spc_plot_config <- function(
    chart_type = "run",
    y_axis_unit = "count",
    target_value = NULL,
    target_text = NULL,
    centerline_value = NULL,
    chart_title = NULL,
    ylab = "",
    xlab = "",
    subtitle = NULL,
    caption = NULL) {
  # Validation
  valid_chart_types <- c("run", "i", "mr", "xbar", "s", "t", "p", "pp", "c", "u", "up", "g")
  if (!chart_type %in% valid_chart_types) {
    warning(sprintf(
      "Invalid chart_type: '%s'. Valid types are: %s",
      chart_type,
      paste(valid_chart_types, collapse = ", ")
    ))
  }

  valid_units <- c("count", "percent", "rate", "time")
  if (!y_axis_unit %in% valid_units) {
    warning(sprintf(
      "Invalid y_axis_unit: '%s'. Valid units are: %s",
      y_axis_unit,
      paste(valid_units, collapse = ", ")
    ))
  }

  if (!is.null(target_value) && !is.numeric(target_value)) {
    warning("target_value must be numeric - setting to NULL")
    target_value <- NULL
  }

  structure(
    list(
      chart_type = chart_type,
      y_axis_unit = y_axis_unit,
      target_value = target_value,
      target_text = target_text,
      centerline_value = centerline_value,
      chart_title = chart_title,
      ylab = ylab,
      xlab = xlab,
      subtitle = subtitle,
      caption = caption
    ),
    class = "spc_plot_config"
  )
}

#' Print SPC Plot Configuration
#'
#' @param x SPC plot configuration object
#' @param ... Additional arguments (ignored)
#'
#' @return Invisibly returns x
#' @export
#' @keywords internal
#' @noRd
print.spc_plot_config <- function(x, ...) {
  cat("SPC Plot Configuration:\n")
  cat("  Chart Type:", x$chart_type, "\n")
  cat("  Y-Axis Unit:", x$y_axis_unit, "\n")
  cat("  Target Value:", if (is.null(x$target_value)) "NULL" else x$target_value, "\n")
  cat("  Target Text:", if (is.null(x$target_text)) "NULL" else x$target_text, "\n")
  cat("  Centerline:", if (is.null(x$centerline_value)) "NULL" else x$centerline_value, "\n")
  invisible(x)
}

# ============================================================================
# VIEWPORT DIMENSIONS
# ============================================================================

#' Create Viewport Dimensions Configuration
#'
#' Creates a configuration object for plot viewport dimensions.
#'
#' @param width Viewport width in pixels (default: NULL for auto)
#' @param height Viewport height in pixels (default: NULL for auto)
#' @param base_size Base font size for scaling (default: 14)
#'
#' @return List with class "viewport_dims"
#'
#' @details
#' This object controls the physical dimensions and scaling of the plot.
#'
#' **Defaults**:
#' - If width/height are NULL, responsive sizing is used
#' - base_size controls responsive scaling of geoms and text
#' - Reference: base_size 14 provides original sizing
#'
#' @keywords internal
#' @noRd
#' @examples
#' # Auto-sized viewport with default font
#' vp <- viewport_dims()
#'
#' # Fixed size with larger text
#' vp <- viewport_dims(width = 1200, height = 800, base_size = 18)
viewport_dims <- function(
    width = NULL,
    height = NULL,
    base_size = 14) {
  # Validation
  if (!is.null(width) && (!is.numeric(width) || width <= 0)) {
    warning("width must be positive numeric or NULL - setting to NULL")
    width <- NULL
  }

  if (!is.null(height) && (!is.numeric(height) || height <= 0)) {
    warning("height must be positive numeric or NULL - setting to NULL")
    height <- NULL
  }

  if (!is.numeric(base_size) || base_size <= 0) {
    warning("base_size must be positive numeric - defaulting to 14")
    base_size <- 14
  }

  structure(
    list(
      width = width,
      height = height,
      base_size = base_size
    ),
    class = "viewport_dims"
  )
}

#' Print Viewport Dimensions
#'
#' @param x Viewport dimensions object
#' @param ... Additional arguments (ignored)
#'
#' @return Invisibly returns x
#' @export
#' @keywords internal
#' @noRd
print.viewport_dims <- function(x, ...) {
  cat("Viewport Dimensions:\n")
  cat("  Width:", if (is.null(x$width)) "Auto" else paste(x$width, "px"), "\n")
  cat("  Height:", if (is.null(x$height)) "Auto" else paste(x$height, "px"), "\n")
  cat("  Base Size:", x$base_size, "\n")
  invisible(x)
}

# ============================================================================
# PHASE CONFIGURATION
# ============================================================================

#' Create Phase Configuration
#'
#' Creates a configuration object for phase/shift handling in SPC charts.
#'
#' @param part_positions Integer vector of row positions where phase changes occur (optional)
#' @param freeze_position Integer row position where baseline should be frozen (optional)
#'
#' @return List with class "phase_config"
#'
#' @details
#' This object controls phase separation and control limit freezing.
#'
#' **Phase Handling**:
#' - `part_positions` specifies row numbers where new phases begin
#' - `freeze_position` locks the baseline calculation up to a specific row
#' - These are passed directly to qicharts2::qic()
#'
#' @keywords internal
#' @noRd
#' @examples
#' # No phases
#' phases <- phase_config()
#'
#' # Phase shift at row 20
#' phases <- phase_config(part_positions = 20)
#'
#' # Multiple phases with frozen baseline
#' phases <- phase_config(
#'   part_positions = c(15, 30, 45),
#'   freeze_position = 15
#' )
phase_config <- function(
    part_positions = NULL,
    freeze_position = NULL) {
  # Validation
  if (!is.null(part_positions) && (!is.numeric(part_positions) || any(part_positions <= 0))) {
    warning("part_positions must be positive integers - setting to NULL")
    part_positions <- NULL
  }

  if (!is.null(freeze_position) && (!is.numeric(freeze_position) || freeze_position <= 0)) {
    warning("freeze_position must be a positive integer - setting to NULL")
    freeze_position <- NULL
  }

  structure(
    list(
      part_positions = part_positions,
      freeze_position = freeze_position
    ),
    class = "phase_config"
  )
}

#' Print Phase Configuration
#'
#' @param x Phase configuration object
#' @param ... Additional arguments (ignored)
#'
#' @return Invisibly returns x
#' @export
#' @keywords internal
#' @noRd
print.phase_config <- function(x, ...) {
  cat("Phase Configuration:\n")
  cat("  Part Positions:", if (is.null(x$part_positions)) "NULL" else paste(x$part_positions, collapse = ", "), "\n")
  cat("  Freeze Position:", if (is.null(x$freeze_position)) "NULL" else x$freeze_position, "\n")
  invisible(x)
}
