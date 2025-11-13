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
#' @param exclude Integer vector of data point positions to exclude from calculations (optional)
#' @param cl Numeric value to set a custom centerline instead of calculating from data (optional)
#' @param multiply Numeric multiplier for y-axis values, e.g. 100 to convert proportions to percentages (default: 1)
#' @param agg.fun Aggregation function for run/I charts with multiple observations per subgroup: "mean" (default), "median", "sum", "sd"
#' @param base_size Base font size in points (default: auto-calculated from width/height if provided, otherwise 14)
#' @param width Plot width (optional). Supports smart unit detection or explicit units parameter. See Details.
#' @param height Plot height (optional). Supports smart unit detection or explicit units parameter. See Details.
#' @param units Unit type for width/height: "cm" (centimeters), "mm" (millimeters), "in" (inches), "px" (pixels), or NULL for smart auto-detection (default)
#' @param dpi Dots per inch for pixel conversion (default: 96). Only used when units = "px"
#' @param plot_margin Plot margins as either: (1) numeric vector c(top, right, bottom, left) in mm, or (2) ggplot2::margin() object. Default NULL uses BFHtheme defaults.
#' @param ylab Y-axis label (default: "" for blank)
#' @param xlab X-axis label (default: "" for blank)
#' @param subtitle Plot subtitle text (default: NULL for no subtitle)
#' @param caption Plot caption text (default: NULL for no caption)
#' @param return.data Logical. If TRUE, return the raw qic data frame instead of ggplot. If FALSE (default), return ggplot object. Can be combined with print.summary.
#' @param print.summary Logical. If TRUE, return formatted summary statistics. When combined with return.data, returns list(data, summary). When alone, returns list(plot, summary). Default FALSE returns only plot.
#'
#' @return
#' - Default (return.data = FALSE, print.summary = FALSE): ggplot2 object
#' - return.data = TRUE: data.frame with qic calculations
#' - print.summary = TRUE: list(plot = ggplot, summary = data.frame)
#' - Both TRUE: list(data = data.frame, summary = data.frame)
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
#' **Unit Support (Danish-friendly):**
#' Width and height support multiple units for convenience:
#' - **Smart auto-detection** (default, `units = NULL`):
#'   - Values > 100 → pixels (e.g., `width = 800` → 800px)
#'   - Values 10-100 → centimeters (e.g., `width = 25` → 25cm)
#'   - Values < 10 → inches (e.g., `width = 10` → 10in, legacy)
#' - **Explicit units** (`units = "cm"`, `"mm"`, `"in"`, `"px"`):
#'   - Centimeters: `width = 25, height = 15, units = "cm"` (Danish standard)
#'   - Millimeters: `width = 250, height = 150, units = "mm"`
#'   - Inches: `width = 10, height = 6, units = "in"` (legacy)
#'   - Pixels: `width = 800, height = 600, units = "px", dpi = 96` (web/Shiny)
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
#' @family spc-plotting
#' @seealso
#'   - [bfh_spc_plot()] for low-level plot generation
#'   - [spc_plot_config()] for plot configuration
#'   - [apply_y_axis_formatting()] for Y-axis formatting
#'   - [BFHtheme::theme_bfh()] for BFHtheme styling
#'   - [BFHtheme::add_bfh_logo()] to add hospital branding
#' @importFrom BFHtheme theme_bfh add_bfh_logo
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
#'
#' # Example 6: Exclude outliers from calculations
#' plot_exclude <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "I-Chart with Excluded Outliers",
#'   exclude = c(3, 15)  # Exclude data points 3 and 15
#' )
#'
#' # Example 7: Use median instead of mean for aggregation
#' plot_median <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "I-Chart Using Median",
#'   agg.fun = "median"
#' )
#'
#' # Example 8: Multiply y-values for unit conversion
#' # Convert proportions (0-1) to percentages (0-100)
#' data_prop <- data.frame(
#'   month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
#'   proportion = runif(24, 0.01, 0.05)  # Proportions 0.01-0.05
#' )
#'
#' plot_multiply <- create_spc_chart(
#'   data = data_prop,
#'   x = month,
#'   y = proportion,
#'   chart_type = "i",
#'   y_axis_unit = "percent",
#'   chart_title = "Proportions Converted to Percentages",
#'   multiply = 100  # Convert 0.01 → 1%
#' )
#'
#' # Example 9: Custom centerline (cl parameter)
#' # Use a fixed benchmark or standard instead of calculating from data
#' plot_cl <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Infections with Custom Centerline",
#'   cl = 10  # Set centerline to fixed benchmark of 10
#' )
#'
#' # Example 10: Custom plot margins (numeric vector in mm)
#' plot_tight <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Chart with Tight Margins",
#'   plot_margin = c(2, 2, 2, 2)  # 2mm on all sides
#' )
#'
#' # Example 11: Custom margins with margin() object
#' plot_custom_margin <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Chart with Custom Margins",
#'   plot_margin = ggplot2::margin(t = 5, r = 15, b = 5, l = 10, unit = "mm")
#' )
#'
#' # Example 12: Responsive margins using lines (scales with base_size)
#' plot_responsive <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   base_size = 18,
#'   plot_margin = ggplot2::margin(t = 0.5, r = 1, b = 0.5, l = 1, unit = "lines")
#' )
#'
#' # Example 13: Custom axis labels, subtitle, and caption
#' plot_labels <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Hospital-Acquired Infections",
#'   ylab = "Antal infektioner",
#'   xlab = "Måned",
#'   subtitle = "Kirurgisk afdeling - 2024",
#'   caption = "Data: EPJ system | Analyse: Kvalitetsafdelingen"
#' )
#'
#' # Example 14: Add BFHtheme branding (hospital logo, custom styling)
#' plot_branded <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Hospital-Acquired Infections - Official Report",
#'   base_size = 14
#' ) |>
#'   BFHtheme::add_bfh_logo()  # Add hospital branding
#'
#' # Alternate BFHtheme styles available:
#' # - BFHtheme::theme_bfh_dark() for dark theme
#' # - BFHtheme::theme_bfh_print() for print-optimized theme
#' # - BFHtheme::theme_bfh_presentation() for presentations
#'
#' # Example 15: Danish-friendly unit support (centimeters)
#' plot_cm <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Plot in Centimeters (Danish Standard)",
#'   width = 25,   # 25 cm (auto-detected as cm)
#'   height = 15   # 15 cm
#' )
#'
#' # Example 16: Explicit unit specification
#' plot_explicit <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Explicit Centimeters",
#'   width = 25, height = 15, units = "cm"
#' )
#'
#' # Example 17: Pixel dimensions for web/Shiny
#' plot_px <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Plot for Web Display",
#'   width = 800,   # 800 px (auto-detected as px)
#'   height = 600,  # 600 px
#'   dpi = 96
#' )
#'
#' # Example 18: Backward compatibility (inches still work)
#' plot_inches <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Legacy Inches Format",
#'   width = 10,    # 10 inches (auto-detected as in)
#'   height = 6     # 6 inches
#' )
#'
#' # Example 19: Get raw qic data for further analysis
#' qic_data <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   return.data = TRUE  # Return data.frame instead of plot
#' )
#'
#' # Now you can access all qic calculations
#' head(qic_data)
#' # Available columns: cl, ucl, lcl, runs.signal, sigma.signal, etc.
#'
#' # Example 20: Get summary statistics with Danish column names
#' result <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Infections - With Summary",
#'   print.summary = TRUE  # Return list(plot, summary)
#' )
#'
#' # Access the plot
#' result$plot
#'
#' # Access the summary statistics (Danish column names)
#' print(result$summary)
#' # Columns: fase, antal_observationer, anvendelige_observationer,
#' #          centerlinje, nedre_kontrolgrænse, øvre_kontrolgrænse,
#' #          længste_løb, antal_kryds, løbelængde_signal, sigma_signal
#'
#' # Example 21: Get both raw data and summary
#' result <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   part = c(12),  # Split into phases
#'   return.data = TRUE,
#'   print.summary = TRUE  # Return list(data, summary)
#' )
#'
#' # Access raw qic data
#' result$data
#'
#' # Access summary statistics (one row per phase)
#' result$summary
#' # fase 1: baseline period
#' # fase 2: intervention period
#'
#' # Example 22: Use summary for reporting
#' result <- create_spc_chart(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   n = surgeries,
#'   chart_type = "p",
#'   y_axis_unit = "percent",
#'   chart_title = "Infection Rate - Multi-phase Analysis",
#'   part = c(12),
#'   print.summary = TRUE
#' )
#'
#' # Extract key metrics for reporting
#' summary_stats <- result$summary
#' cat("Fase 1 centerlinje:", summary_stats$centerlinje[1], "%\n")
#' cat("Fase 2 centerlinje:", summary_stats$centerlinje[2], "%\n")
#' cat("Forbedring:", summary_stats$centerlinje[1] - summary_stats$centerlinje[2], "%-point\n")
#'
#' if (summary_stats$sigma_signal[2]) {
#'   cat("VIGTIG: Special cause variation detekteret i fase 2!\n")
#' }
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
                              exclude = NULL,
                              cl = NULL,
                              multiply = 1,
                              agg.fun = c("mean", "median", "sum", "sd"),
                              base_size = 14,
                              width = NULL,
                              height = NULL,
                              units = NULL,
                              dpi = 96,
                              plot_margin = NULL,
                              ylab = "",
                              xlab = "",
                              subtitle = NULL,
                              caption = NULL,
                              return.data = FALSE,
                              print.summary = FALSE) {
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

  # SECURITY: Validate column names are simple identifiers
  # Prevents NSE injection attacks where malicious code could be passed
  validate_column_name <- function(col_expr, param_name) {
    col_str <- deparse(col_expr)
    # Allow only simple identifiers: letters, numbers, dots, underscores
    # No parentheses, operators, or function calls
    valid_pattern <- "^[a-zA-Z][a-zA-Z0-9._]*$"
    if (!grepl(valid_pattern, col_str)) {
      stop(sprintf(
        "%s must be a simple column name, got: %s\nAvoid special characters, spaces, or expressions",
        param_name, col_str
      ), call. = FALSE)
    }
  }

  # Validate x and y column names
  validate_column_name(substitute(x), "x")
  validate_column_name(substitute(y), "y")

  # SECURITY: Validate numeric parameters for bounds and sanity
  # Prevents DoS attacks via memory exhaustion or crashes
  # Using centralized validate_numeric_parameter() function to reduce code duplication
  validate_numeric_parameter(
    part, "part",
    min = 1, max = nrow(data),
    allow_null = TRUE,
    context = sprintf("1-%d", nrow(data))
  )

  validate_numeric_parameter(
    freeze, "freeze",
    min = 1, max = nrow(data),
    allow_null = TRUE,
    context = sprintf("1-%d", nrow(data))
  )

  validate_numeric_parameter(
    base_size, "base_size",
    min = 1, max = 100,
    allow_null = FALSE,
    len = 1
  )

  validate_numeric_parameter(
    width, "width",
    min = 0.1, max = 3000,  # Allow up to 3000 for pixels (typical: 600-2000px)
    allow_null = TRUE,
    len = 1
  )

  validate_numeric_parameter(
    height, "height",
    min = 0.1, max = 3000,  # Allow up to 3000 for pixels (typical: 600-2000px)
    allow_null = TRUE,
    len = 1
  )

  validate_numeric_parameter(
    exclude, "exclude",
    min = 1, max = nrow(data),
    allow_null = TRUE,
    context = sprintf("1-%d", nrow(data))
  )

  validate_numeric_parameter(
    cl, "cl",
    min = -Inf, max = Inf,
    allow_null = TRUE,
    len = 1
  )

  validate_numeric_parameter(
    multiply, "multiply",
    min = 0.1, max = 1000,
    allow_null = FALSE,
    len = 1
  )

  # Validate agg.fun parameter
  agg.fun <- match.arg(agg.fun)

  # Validate return.data parameter
  if (!is.logical(return.data) || length(return.data) != 1 || is.na(return.data)) {
    stop("return.data must be TRUE or FALSE", call. = FALSE)
  }

  # Validate print.summary parameter
  if (!is.logical(print.summary) || length(print.summary) != 1 || is.na(print.summary)) {
    stop("print.summary must be TRUE or FALSE", call. = FALSE)
  }

  # Validate plot_margin parameter
  if (!is.null(plot_margin)) {
    # Check if it's a margin object (from ggplot2::margin())
    if (inherits(plot_margin, "ggplot2::margin")) {
      # margin() object - trust that user used it correctly
      # Note: margin objects are grid::unit objects, cannot be compared with > or <
    } else if (is.numeric(plot_margin)) {
      # Numeric vector - validate length and values
      if (length(plot_margin) != 4) {
        stop(
          "plot_margin must be either:\n",
          "  - A numeric vector of length 4: c(top, right, bottom, left) in mm\n",
          "  - A margin object: margin(t, r, b, l, unit = '...')",
          call. = FALSE
        )
      }
      if (any(plot_margin < 0)) {
        stop("plot_margin values must be non-negative", call. = FALSE)
      }
      if (any(plot_margin > 100)) {
        warning(
          "plot_margin values > 100mm detected. This may result in very large margins.\n",
          "Consider using smaller values or checking your input.",
          call. = FALSE
        )
      }
    } else {
      stop(
        "plot_margin must be either:\n",
        "  - A numeric vector of length 4: c(top, right, bottom, left) in mm\n",
        "  - A margin object: margin(t, r, b, l, unit = '...')\n",
        "Got: ", class(plot_margin)[1],
        call. = FALSE
      )
    }
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
    validate_column_name(substitute(n), "n")
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

  if (!is.null(exclude)) {
    qic_args$exclude <- exclude
  }

  if (!is.null(cl)) {
    qic_args$cl <- cl
  }

  if (!is.null(multiply) && multiply != 1) {
    qic_args$multiply <- multiply
  }

  if (!missing(agg.fun)) {
    qic_args$agg.fun <- agg.fun
  }

  # Map y_axis_unit to qicharts2's y.percent parameter
  # This enables percentage formatting (75% instead of 0.75) for compatible chart types
  if (!is.null(y_axis_unit) && y_axis_unit == "percent") {
    qic_args$y.percent <- TRUE
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

  # Convert width/height to inches using unit conversion
  # Supports cm, mm, in, px with smart auto-detection
  if (!is.null(width) && !is.null(height)) {
    conversion_result <- convert_to_inches(width, height, units, dpi)
    width_inches <- conversion_result$width_inches
    height_inches <- conversion_result$height_inches
    # detected_unit <- conversion_result$detected_unit  # For potential logging
  } else {
    width_inches <- NULL
    height_inches <- NULL
  }

  # Calculate responsive base_size if viewport dimensions provided
  # Uses geometric mean approach: sqrt(width × height) / divisor
  if (!is.null(width_inches) && !is.null(height_inches)) {
    calculated_base_size <- calculate_base_size(width_inches, height_inches)
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
    target_text = target_text,
    ylab = ylab,
    xlab = xlab,
    subtitle = subtitle,
    caption = caption
  )

  # Create viewport configuration
  viewport <- viewport_dims(base_size = base_size)

  # Generate plot using bfh_spc_plot()
  # Suppress ggplot2 warning about numeric values passed to datetime scale
  # This occurs when target_value is used with datetime x-axis and is harmless
  plot <- suppressWarnings(
    bfh_spc_plot(
      qic_data = qic_data,
      plot_config = plot_config,
      viewport = viewport,
      plot_margin = plot_margin
    )
  )

  # Use converted dimensions for viewport
  # This enables precise label placement even without open graphics device
  viewport_width_inches <- width_inches
  viewport_height_inches <- height_inches

  # Add SPC labels automatically
  # Responsive label sizing: scales based on viewport base_size
  label_size <- viewport$base_size / REFERENCE_BASE_SIZE * DEFAULT_LABEL_SIZE_MULTIPLIER

  plot <- add_spc_labels(
    plot = plot,
    qic_data = qic_data,
    y_axis_unit = y_axis_unit,
    label_size = label_size,
    viewport_width = viewport_width_inches,
    viewport_height = viewport_height_inches,
    target_text = target_text,
    verbose = FALSE
  )

  # Handle return based on parameters
  # Get summary if requested
  summary_result <- NULL
  if (print.summary) {
    # Extract and format summary from qic_data
    summary_result <- format_qic_summary(qic_data, y_axis_unit = y_axis_unit)
  }

  # Return based on user parameters
  if (return.data && print.summary) {
    return(list(data = qic_data, summary = summary_result))
  } else if (return.data) {
    return(qic_data)
  } else if (print.summary) {
    return(list(plot = plot, summary = summary_result))
  } else {
    return(plot)
  }
}
