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
#' - Reduced function signatures (15 params -> 3-5 params)
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
#'
#' plot <- bfh_spc_plot(qic_data, plot_cfg, viewport)
#' ```
#'
#' @name config_objects
#' @keywords internal
#' @noRd
NULL

stop_config_error <- function(msg) {
  cond <- structure(
    class = c("bfhcharts_config_error", "error", "condition"),
    list(message = msg, call = sys.call(-1))
  )
  stop(cond)
}

assert_positive_scalar <- function(x, name) {
  if (!is.numeric(x) || length(x) != 1 || is.na(x) || is.infinite(x) || x <= 0) {
    stop_config_error(sprintf("%s must be a positive numeric value", name))
  }
}

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
#' **Validation** (all raise errors with class `bfhcharts_config_error`):
#' - `chart_type` must be one of the valid SPC chart types
#' - `y_axis_unit` must be one of: count, percent, rate, time
#' - `target_value` must be a single finite numeric value or NULL
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
  caption = NULL,
  language = "da"
) {
  # Validation
  if (!chart_type %in% CHART_TYPES_EN) {
    stop_config_error(sprintf(
      "Invalid chart_type: '%s'. Valid types are: %s",
      chart_type,
      paste(CHART_TYPES_EN, collapse = ", ")
    ))
  }

  valid_units <- Y_AXIS_UNITS
  if (!y_axis_unit %in% valid_units) {
    stop_config_error(sprintf(
      "Invalid y_axis_unit: '%s'. Valid units are: %s",
      y_axis_unit,
      paste(valid_units, collapse = ", ")
    ))
  }

  if (!is.null(target_value) &&
    (!is.numeric(target_value) || length(target_value) != 1 ||
      is.na(target_value) || is.infinite(target_value))) {
    stop_config_error("target_value must be a single finite numeric value or NULL")
  }

  if (!is.character(language) || length(language) != 1L ||
    !language %in% c("da", "en")) {
    stop_config_error(sprintf(
      "language must be 'da' or 'en', got: %s",
      paste(language, collapse = "/")
    ))
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
      caption = caption,
      language = language
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
#' @method print spc_plot_config
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
#' @param width Viewport width in inches (default: NULL for auto)
#' @param height Viewport height in inches (default: NULL for auto)
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
#' **Validation**:
#' - width/height must be positive numeric or NULL; invalid values raise an error
#' - base_size must be positive numeric; invalid values raise an error
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
  base_size = 14
) {
  # Validation
  if (!is.null(width)) assert_positive_scalar(width, "width")
  if (!is.null(height)) assert_positive_scalar(height, "height")
  assert_positive_scalar(base_size, "base_size")

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
#' @method print viewport_dims
#' @noRd
print.viewport_dims <- function(x, ...) {
  cat("Viewport Dimensions:\n")
  cat("  Width:", if (is.null(x$width)) "Auto" else paste(x$width, "px"), "\n")
  cat("  Height:", if (is.null(x$height)) "Auto" else paste(x$height, "px"), "\n")
  cat("  Base Size:", x$base_size, "\n")
  invisible(x)
}
