#' Create BFH-Styled SPC Chart
#'
#' One-function approach to create publication-ready SPC charts.
#' Wraps qicharts2 calculation and BFH visualization in a single call.
#'
#' @name bfh_qic
NULL

# ============================================================================
# HIGH-LEVEL WRAPPER
# ============================================================================

#' Create BFH-Styled SPC Chart from Raw Data
#'
#' Convenience function that combines qicharts2::qic() calculation with
#' BFH-styled visualization and automatic label placement. Handles the
#' entire workflow from raw data to finished plot with intelligent labels.
#'
#' @param data Data frame with measurements
#' @param x Name of x-axis column (unquoted, NSE). Usually date/time column.
#' @param y Name of y-axis column (unquoted, NSE). The measurement variable.
#' @param n Name of denominator column for ratio charts (optional, unquoted, NSE)
#' @param chart_type Chart type: "run", "i", "mr", "p", "pp", "u", "up", "c", "g", "xbar", "s", "t"
#' @param y_axis_unit Unit type: "count", "percent", "rate", or "time"
#' @param chart_title Plot title (optional)
#' @param target_value Numeric target value (optional)
#' @param target_text Target label text (optional)
#' @param notes Character vector of annotations for data points (optional, same length as data)
#' @param part Positions for phase splits (optional numeric vector). Must be
#'   positive integers, strictly increasing, unique, and within
#'   `[2, nrow(data)]`. Non-integer (e.g. `3.5`), duplicated, or unsorted
#'   values raise an error before any qicharts2 call.
#' @param freeze Position to freeze baseline (optional single integer). Must
#'   be a positive integer in `[1, nrow(data) - 1]`. Non-integer values
#'   raise an error.
#' @param exclude Integer vector of data point positions to exclude from
#'   calculations (optional). Must be positive integers, unique, and within
#'   `[1, nrow(data)]`. Sort order is not required.
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
#' @param return.data Logical. If TRUE, return the raw qic data frame instead of bfh_qic_result object. If FALSE (default), return bfh_qic_result S3 object. Legacy parameter maintained for backwards compatibility.
#' @param print.summary \strong{REMOVED in v0.11.0.} Calling with \code{print.summary = TRUE} raises an error. Use \code{return.data = TRUE} and access \code{result$qic_summary}, or use the default \code{bfh_qic_result} object and access \code{result$summary} directly.
#' @param language Character string specifying output language. One of
#'   \code{"da"} (Danish, default) or \code{"en"} (English). Controls
#'   three independent aspects of output (since v0.12.0):
#'   \itemize{
#'     \item Translated labels (control limit text, target prefixes)
#'     \item Y-axis number formatting: decimal separator and thousand
#'       separator (Danish `1.234,5` vs English `1,234.5`); percent suffix
#'       (Danish `12,5 %` vs English `12.5%`)
#'     \item X-axis date formatting: month/weekday abbreviations match the
#'       requested locale on a best-effort basis (depends on platform
#'       locale availability)
#'   }
#'   Default \code{"da"} preserves backward compatibility for Danish users.
#'
#' @return
#' - Default (return.data = FALSE): \code{bfh_qic_result} S3 object with components:
#'   \itemize{
#'     \item \code{$plot}: ggplot2 object with the SPC chart
#'     \item \code{$summary}: data.frame with SPC statistics
#'     \item \code{$qic_data}: data.frame with raw qicharts2 calculations
#'     \item \code{$config}: list with original function parameters
#'   }
#' - return.data = TRUE: data.frame with qic calculations (legacy behavior)
#'
#' @details
#' **Helper map (internal orchestration functions):**
#' - `validate_bfh_qic_inputs()` -- all input validation (type, bounds, NSE, denominator, target)
#' - `build_qic_args()` -- constructs argument list for `qicharts2::qic()`
#' - `invoke_qicharts2()` -- calls `do.call(qicharts2::qic, ...)` + `add_anhoej_signal()`
#' - `compute_viewport_base_size()` -- unit conversion, responsive `base_size`, label normalisation
#' - `render_bfh_plot()` -- plot_config + viewport + `bfh_spc_plot()` with warning suppression
#' - `apply_spc_labels_to_export()` -- label_size computation + `add_spc_labels()` with warning suppression
#' - `build_bfh_qic_return()` -- return value routing (S3 vs. legacy paths)
#'
#' **Chart Types:**
#' - **run**: Run chart (no control limits)
#' - **i**: I-chart (individuals)
#' - **mr**: Moving Range chart -- measures point-to-point variability.
#'   Typically paired with an I-chart to characterise both process level (I)
#'   and short-term variation (MR).
#' - **p**: P-chart (proportions, requires n)
#' - **pp**: P-prime chart (Laney-adjusted proportions) -- use instead of `p`
#'   when denominators are very large (n > 1000 per subgroup) and standard
#'   control limits become artificially tight due to over-dispersion. Requires n.
#' - **u**: U-chart (rates, requires n)
#' - **up**: U-prime chart (Laney-adjusted rates) -- same rationale as `pp`,
#'   applied to count rates. Requires n.
#' - **c**: C-chart (counts)
#' - **g**: G-chart (geometric)
#' - **xbar**: X-bar chart
#' - **s**: S-chart
#' - **t**: T-chart (time between events)
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
#' **Denominator Contract (ratio charts):**
#' Ratio chart types (`p`, `pp`, `u`, `up`) require a denominator column
#' supplied via `n`. The content of `n` is validated to prevent silently
#' misleading rate plots:
#' - `n` must be numeric and finite (no `Inf`/`-Inf`).
#' - All non-`NA` values of `n` must be `> 0` (zero/negative denominators
#'   produce meaningless rates).
#' - For proportion charts (`p`, `pp`): every row with both `y` and `n`
#'   present must satisfy `y <= n` (proportion <= 1).
#' - `NA` in individual rows of `n` is allowed (qicharts2 drops them).
#' - Violations raise an error identifying the offending row number(s) so
#'   the source data can be inspected. Pre-filter or correct invalid rows
#'   before calling `bfh_qic()`.
#' Other chart types (`run`, `i`, `mr`, `c`, `g`, `t`, `xbar`, `s`) are not
#' subject to denominator validation.
#'
#' **Unit Support (Danish-friendly):**
#' Width and height support multiple units for convenience:
#' - **Smart auto-detection** (default, `units = NULL`):
#'   - Values > 100 -> pixels (e.g., `width = 800` -> 800px)
#'   - Values 10-100 -> centimeters (e.g., `width = 25` -> 25cm)
#'   - Values < 10 -> inches (e.g., `width = 10` -> 10in, legacy)
#' - **Explicit units** (`units = "cm"`, `"mm"`, `"in"`, `"px"`):
#'   - Centimeters: `width = 25, height = 15, units = "cm"` (Danish standard)
#'   - Millimeters: `width = 250, height = 150, units = "mm"`
#'   - Inches: `width = 10, height = 6, units = "in"` (legacy)
#'   - Pixels: `width = 800, height = 600, units = "px", dpi = 96` (web/Shiny)
#'
#' **Responsive Typography:**
#' When `width` and `height` are provided, `base_size` is automatically
#' calculated using geometric mean: `sqrt(width x height) / 3.5`
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
#' If `target_text` contains arrow symbols (up down or < >), the target line will be
#' suppressed and only the directional indicator shown at the plot edge.
#'
#' **Percent Target Contract:**
#' When `y_axis_unit = "percent"`, `target_value` is validated against the scale
#' implied by `multiply`:
#' - `multiply = 1` (default): `target_value` must be in `[0, 1.5]` (proportion)
#' - `multiply = 100`: `target_value` must be in `[0, 150]` (percent)
#' - `multiply = m`: `target_value` must be in `[0, m * 1.5]`
#'
#' The most common error is passing `target_value = 2.0` to mean "2%" when
#' `multiply = 1` (proportion scale). Use `target_value = 0.02` instead, or
#' set `multiply = 100` to pass percent values directly.
#' A 1.5x upper slack permits legitimate stretch targets above 100%.
#'
#' @export
#' @importFrom BFHtheme theme_bfh add_bfh_logo
#' @examples
#' # Minimal runnable example with deterministic data
#' df <- data.frame(
#'   maaned = seq.Date(as.Date("2023-01-01"), by = "month", length.out = 12),
#'   vaerdi = c(10, 12, 11, 13, 10, 14, 11, 12, 10, 13, 11, 12)
#' )
#' result <- bfh_qic(df, x = maaned, y = vaerdi, chart_type = "i")
#' class(result) # "bfh_qic_result"
#'
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
#' plot <- bfh_qic(
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
#' plot <- bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   n = surgeries,
#'   chart_type = "p",
#'   y_axis_unit = "percent",
#'   chart_title = "Infection Rate per 100 Surgeries",
#'   target_value = 0.02,
#'   target_text = "down Maalet: 2%"
#' )
#' plot
#'
#' # Example 3: I-chart with phase splits
#' plot <- bfh_qic(
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
#' plot <- bfh_qic(
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
#' # Small plot (6x4 inches) -> base_size ~= 14pt
#' plot_small <- bfh_qic(
#'   data = data, x = month, y = infections,
#'   chart_type = "i", y_axis_unit = "count",
#'   chart_title = "Small Plot - Auto Scaled Typography",
#'   width = 6, height = 4 # Auto: base_size ~= 14pt
#' )
#'
#' # Medium plot (10x6 inches) -> base_size ~= 22pt
#' plot_medium <- bfh_qic(
#'   data = data, x = month, y = infections,
#'   chart_type = "i", y_axis_unit = "count",
#'   chart_title = "Medium Plot - Auto Scaled Typography",
#'   width = 10, height = 6 # Auto: base_size ~= 22pt
#' )
#'
#' # Large plot (16x9 inches) -> base_size ~= 34pt
#' plot_large <- bfh_qic(
#'   data = data, x = month, y = infections,
#'   chart_type = "i", y_axis_unit = "count",
#'   chart_title = "Large Plot - Auto Scaled Typography",
#'   width = 16, height = 9 # Auto: base_size ~= 34pt
#' )
#'
#' # Override auto-scaling with explicit base_size
#' plot_custom <- bfh_qic(
#'   data = data, x = month, y = infections,
#'   chart_type = "i", y_axis_unit = "count",
#'   chart_title = "Custom Typography Override",
#'   width = 10, height = 6,
#'   base_size = 18 # Explicit override
#' )
#'
#' # Example 6: Exclude outliers from calculations
#' plot_exclude <- bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "I-Chart with Excluded Outliers",
#'   exclude = c(3, 15) # Exclude data points 3 and 15
#' )
#'
#' # Example 7: Use median instead of mean for aggregation
#' plot_median <- bfh_qic(
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
#'   proportion = runif(24, 0.01, 0.05) # Proportions 0.01-0.05
#' )
#'
#' plot_multiply <- bfh_qic(
#'   data = data_prop,
#'   x = month,
#'   y = proportion,
#'   chart_type = "i",
#'   y_axis_unit = "percent",
#'   chart_title = "Proportions Converted to Percentages",
#'   multiply = 100 # Convert 0.01 -> 1%
#' )
#'
#' # Example 9: Custom centerline (cl parameter)
#' # Use a fixed benchmark or standard instead of calculating from data
#' plot_cl <- bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Infections with Custom Centerline",
#'   cl = 10 # Set centerline to fixed benchmark of 10
#' )
#'
#' # Example 10: Custom plot margins (numeric vector in mm)
#' plot_tight <- bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Chart with Tight Margins",
#'   plot_margin = c(2, 2, 2, 2) # 2mm on all sides
#' )
#'
#' # Example 11: Custom margins with margin() object
#' plot_custom_margin <- bfh_qic(
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
#' plot_responsive <- bfh_qic(
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
#' plot_labels <- bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Hospital-Acquired Infections",
#'   ylab = "Antal infektioner",
#'   xlab = "Maaned",
#'   subtitle = "Kirurgisk afdeling - 2024",
#'   caption = "Data: EPJ system | Analyse: Kvalitetsafdelingen"
#' )
#'
#' # Example 14: Add BFHtheme branding (hospital logo, custom styling)
#' plot_branded <- bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Hospital-Acquired Infections - Official Report",
#'   base_size = 14
#' ) |>
#'   BFHtheme::add_bfh_logo() # Add hospital branding
#'
#' # Alternate BFHtheme styles available:
#' # - BFHtheme::theme_bfh_dark() for dark theme
#' # - BFHtheme::theme_bfh_print() for print-optimized theme
#' # - BFHtheme::theme_bfh_presentation() for presentations
#'
#' # Example 15: Danish-friendly unit support (centimeters)
#' plot_cm <- bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Plot in Centimeters (Danish Standard)",
#'   width = 25, # 25 cm (auto-detected as cm)
#'   height = 15 # 15 cm
#' )
#'
#' # Example 16: Explicit unit specification
#' plot_explicit <- bfh_qic(
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
#' plot_px <- bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Plot for Web Display",
#'   width = 800, # 800 px (auto-detected as px)
#'   height = 600, # 600 px
#'   dpi = 96
#' )
#'
#' # Example 18: Backward compatibility (inches still work)
#' plot_inches <- bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Legacy Inches Format",
#'   width = 10, # 10 inches (auto-detected as in)
#'   height = 6 # 6 inches
#' )
#'
#' # Example 19: Get raw qic data for further analysis
#' qic_data <- bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   return.data = TRUE # Return data.frame instead of plot
#' )
#'
#' # Now you can access all qic calculations
#' head(qic_data)
#' # Available columns: cl, ucl, lcl, runs.signal, sigma.signal, etc.
#'
#' # Example 20: Get summary statistics with Danish column names
#' result <- bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Infections - With Summary"
#' )
#'
#' # Access the plot
#' result$plot
#'
#' # Access the summary statistics (Danish column names) via S3 object
#' print(result$summary)
#' # Columns: fase, antal_observationer, anvendelige_observationer,
#' #          centerlinje, nedre_kontrolgraense, oevre_kontrolgraense,
#' #          laengste_loeb, antal_kryds, loebelaengde_signal, sigma_signal
#'
#' # Example 21: Get both raw qic data and summary via S3 object
#' result <- bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   part = c(12) # Split into phases
#' )
#'
#' # Access raw qic data (all qicharts2 calculations)
#' result$qic_data
#'
#' # Access summary statistics (one row per phase)
#' result$summary
#' # fase 1: baseline period
#' # fase 2: intervention period
#'
#' # Example 22: Use summary for reporting
#' result <- bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   n = surgeries,
#'   chart_type = "p",
#'   y_axis_unit = "percent",
#'   chart_title = "Infection Rate - Multi-phase Analysis",
#'   part = c(12)
#' )
#'
#' # Extract key metrics for reporting via result$summary
#' summary_stats <- result$summary
#' cat("Fase 1 centerlinje:", summary_stats$centerlinje[1], "%\n")
#' cat("Fase 2 centerlinje:", summary_stats$centerlinje[2], "%\n")
#' cat("Forbedring:", summary_stats$centerlinje[1] - summary_stats$centerlinje[2], "%-point\n")
#'
#' if (summary_stats$sigma_signal[2]) {
#'   cat("VIGTIG: Special cause variation detekteret i fase 2!\n")
#' }
#'
#' # Example 23: P-prime chart for large denominators (Laney-adjusted)
#' data_large_n <- data.frame(
#'   month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
#'   events = rpois(24, lambda = 50),
#'   population = rpois(24, lambda = 5000) # Very large denominators
#' )
#' plot_pp <- bfh_qic(
#'   data = data_large_n,
#'   x = month,
#'   y = events,
#'   n = population,
#'   chart_type = "pp", # Laney-adjusted: prevents artificially tight limits
#'   y_axis_unit = "percent",
#'   chart_title = "Event Rate (Laney P-prime)"
#' )
#'
#' # Example 24: Moving Range chart paired with I-chart
#' # Use MR-chart alongside I-chart for full process variation characterisation
#' plot_i <- bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Infections - Process Level (I-chart)"
#' )
#' plot_mr <- bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "mr", # Moving Range: short-term variation
#'   y_axis_unit = "count",
#'   chart_title = "Infections - Short-term Variation (MR-chart)"
#' )
#' }
bfh_qic <- function(data,
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
                    print.summary = FALSE,
                    language = "da") {
  # ---- NSE + missing() flags kapteres FOERST i bfh_qic()-scopet ----
  # substitute(), missing() og parent.frame() er scope-sensitive:
  # de SKAL evalueres her, ikke inde i helpers.
  agg_fun_supplied <- !missing(agg.fun)
  base_size_supplied <- !missing(base_size)
  qic_envir <- parent.frame()

  x_expr <- validate_column_name_expr(substitute(x), "x")
  y_expr <- validate_column_name_expr(substitute(y), "y")
  n_expr <- if (!missing(n) && !is.null(substitute(n))) {
    validate_column_name_expr(substitute(n), "n")
  } else {
    NULL
  }

  # ---- Valider alle inputs (inkl. language) ----
  validate_language(language)
  agg.fun <- validate_bfh_qic_inputs(
    data = data,
    chart_type = chart_type,
    y_axis_unit = y_axis_unit,
    part = part,
    freeze = freeze,
    base_size = base_size,
    width = width,
    height = height,
    exclude = exclude,
    cl = cl,
    multiply = multiply,
    agg_fun_supplied = agg_fun_supplied,
    agg.fun = agg.fun,
    return.data = return.data,
    print.summary = print.summary,
    plot_margin = plot_margin,
    target_value = target_value,
    y_expr_char = as.character(y_expr),
    n_expr_char = if (!is.null(n_expr)) as.character(n_expr) else NULL
  )

  # ---- Byg qic_args + kald qicharts2 ----
  qic_args <- build_qic_args(
    data = data,
    x_expr = x_expr,
    y_expr = y_expr,
    n_expr = n_expr,
    chart_type = chart_type,
    part = part,
    freeze = freeze,
    target_value = target_value,
    notes = notes,
    exclude = exclude,
    cl = cl,
    multiply = multiply,
    agg.fun = agg.fun,
    y_axis_unit = y_axis_unit
  )
  qic_data <- invoke_qicharts2(qic_args, envir = qic_envir)

  # Warn when custom cl overrides the data-estimated process mean in Anhoej calculation
  if (!is.null(cl) && any(c("runs.signal", "crossings.signal") %in% names(qic_data))) {
    warning(
      "Custom cl supplied: Anhoej run/crossing signals are computed against ",
      "the supplied centerline, not the data-estimated process mean. ",
      "Interpret with caution.",
      call. = FALSE
    )
  }

  # ---- Viewport + responsiv base_size ----
  vp <- compute_viewport_base_size(
    width = width,
    height = height,
    units = units,
    dpi = dpi,
    base_size = base_size,
    base_size_supplied = base_size_supplied,
    xlab = xlab,
    ylab = ylab
  )

  # ---- Render plot ----
  plot <- render_bfh_plot(
    qic_data = qic_data,
    chart_type = chart_type,
    y_axis_unit = y_axis_unit,
    chart_title = chart_title,
    target_value = target_value,
    target_text = target_text,
    ylab = vp$ylab,
    xlab = vp$xlab,
    subtitle = subtitle,
    caption = caption,
    base_size = vp$base_size,
    plot_margin = plot_margin,
    language = language
  )

  # ---- Tilfoej SPC labels ----
  plot <- apply_spc_labels_to_export(
    plot = plot,
    qic_data = qic_data,
    y_axis_unit = y_axis_unit,
    viewport_width_inches = vp$width_inches,
    viewport_height_inches = vp$height_inches,
    target_text = target_text,
    language = language
  )

  # ---- Summary + config ----
  summary_result <- format_qic_summary(qic_data, y_axis_unit = y_axis_unit)
  config <- build_bfh_qic_config(
    chart_type = chart_type,
    chart_title = chart_title,
    y_axis_unit = y_axis_unit,
    language = language,
    target_value = target_value,
    target_text = target_text,
    part = part,
    freeze = freeze,
    exclude = exclude,
    cl = cl,
    multiply = multiply,
    agg.fun = agg.fun,
    viewport_width_inches = vp$width_inches,
    viewport_height_inches = vp$height_inches
  )

  # ---- Return-routing ----
  build_bfh_qic_return(
    qic_data = qic_data,
    plot = plot,
    summary_result = summary_result,
    config = config,
    return.data = return.data,
    print.summary = print.summary
  )
}
