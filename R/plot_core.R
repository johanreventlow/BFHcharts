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
#' @seealso [create_spc_chart()], [spc_plot_config()], [viewport_dims()], [phase_config()]
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
  data_x_min <- min(qic_data$x, na.rm = TRUE)
  data_x_max <- max(qic_data$x, na.rm = TRUE)

  # Convert Date to POSIXct for uniform handling
  if (inherits(data_x_max, "Date")) {
    data_x_max <- as.POSIXct(data_x_max)
    data_x_min <- as.POSIXct(data_x_min)
  }

  # Intelligent date formatting for Date/POSIXct columns
  if (inherits(qic_data$x, c("POSIXct", "POSIXt", "Date"))) {
    # Convert Date to POSIXct
    if (inherits(qic_data$x, "Date")) {
      qic_data$x <- as.POSIXct(qic_data$x)
    }

    # Detect interval pattern and get optimal formatting
    interval_info <- detect_date_interval(qic_data$x)
    format_config <- get_optimal_formatting(interval_info)

    # Helper function to round dates to interval start
    round_to_interval_start <- function(date, interval_type) {
      if (interval_type == "monthly") {
        lubridate::floor_date(date, unit = "month")
      } else if (interval_type == "weekly") {
        lubridate::floor_date(date, unit = "week")
      } else {
        date
      }
    }

    # Calculate adaptive interval size based on data density
    base_interval_secs <- if (interval_info$type == "weekly") {
      7 * 24 * 60 * 60
    } else if (interval_info$type == "monthly") {
      30 * 24 * 60 * 60
    } else if (interval_info$type == "daily") {
      24 * 60 * 60
    } else {
      NULL
    }

    interval_size <- if (!is.null(base_interval_secs)) {
      timespan_secs <- as.numeric(difftime(data_x_max, data_x_min, units = "secs"))
      potential_breaks <- timespan_secs / base_interval_secs

      if (potential_breaks > 15) {
        multipliers <- if (interval_info$type == "weekly") {
          c(2, 4, 13)
        } else if (interval_info$type == "monthly") {
          c(3, 6, 12)
        } else {
          c(2, 4, 8)
        }

        mult <- tail(multipliers, 1)
        for (m in multipliers) {
          if (potential_breaks / m <= 15) {
            mult <- m
            break
          }
        }

        # Convert to difftime for proper POSIXct seq() behavior
        as.difftime(base_interval_secs * mult, units = "secs")
      } else {
        # Convert to difftime for proper POSIXct seq() behavior
        as.difftime(base_interval_secs, units = "secs")
      }
    } else {
      NULL
    }

    # Apply scale based on interval type and smart labels configuration
    if (interval_info$type == "weekly" && !is.null(format_config$use_smart_labels) && format_config$use_smart_labels) {
      rounded_start <- round_to_interval_start(data_x_min, "weekly")
      rounded_end <- lubridate::ceiling_date(data_x_max, unit = "week")
      breaks_posix <- seq(from = rounded_start, to = rounded_end + interval_size, by = interval_size)
      breaks_posix <- breaks_posix[breaks_posix >= data_x_min]

      if (length(breaks_posix) == 0 || breaks_posix[1] != data_x_min) {
        breaks_posix <- unique(c(data_x_min, breaks_posix))
      }

      # Ensure breaks are POSIXct (seq with difftime should return POSIXct, but be explicit)
      breaks_posix <- as.POSIXct(breaks_posix)

      plot <- plot + BFHtheme::scale_x_datetime_bfh(
        expand = ggplot2::expansion(mult = c(0.025, 0)),
        labels = format_config$labels,
        breaks = breaks_posix
      )
    } else if (interval_info$type == "monthly" && !is.null(format_config$use_smart_labels) && format_config$use_smart_labels) {
      rounded_start <- round_to_interval_start(data_x_min, "monthly")
      rounded_end <- lubridate::ceiling_date(data_x_max, unit = "month")

      interval_months <- round(as.numeric(interval_size) / (30 * 24 * 60 * 60))
      extended_end <- seq(rounded_end, by = paste(interval_months, "months"), length.out = 2)[2]
      breaks_posix <- seq(from = rounded_start, to = extended_end, by = paste(interval_months, "months"))
      breaks_posix <- breaks_posix[breaks_posix >= data_x_min]

      if (length(breaks_posix) == 0 || breaks_posix[1] != data_x_min) {
        breaks_posix <- unique(c(data_x_min, breaks_posix))
      }

      # Ensure breaks are POSIXct
      breaks_posix <- as.POSIXct(breaks_posix)

      plot <- plot + BFHtheme::scale_x_datetime_bfh(
        expand = ggplot2::expansion(mult = c(0.025, 0)),
        labels = format_config$labels,
        breaks = breaks_posix
      )
    } else if (!is.null(format_config$breaks) && !is.null(interval_size)) {
      # Standard intelligent formatting with calculated breaks
      if (interval_info$type == "monthly") {
        rounded_start <- round_to_interval_start(data_x_min, "monthly")
        rounded_end <- lubridate::ceiling_date(data_x_max, unit = "month")
        interval_months <- round(as.numeric(interval_size) / (30 * 24 * 60 * 60))
        extended_end <- seq(rounded_end, by = paste(interval_months, "months"), length.out = 2)[2]
        breaks_posix <- seq(from = rounded_start, to = extended_end, by = paste(interval_months, "months"))
        breaks_posix <- breaks_posix[breaks_posix >= data_x_min]

        if (length(breaks_posix) == 0 || breaks_posix[1] != data_x_min) {
          breaks_posix <- unique(c(data_x_min, breaks_posix))
        }
      } else {
        rounded_start <- round_to_interval_start(data_x_min, interval_info$type)
        breaks_posix <- seq(from = rounded_start, to = data_x_max + interval_size, by = interval_size)
        breaks_posix <- breaks_posix[breaks_posix >= data_x_min]

        if (length(breaks_posix) == 0 || breaks_posix[1] != data_x_min) {
          breaks_posix <- unique(c(data_x_min, breaks_posix))
        }
      }

      # Ensure breaks are POSIXct
      breaks_posix <- as.POSIXct(breaks_posix)

      plot <- plot + BFHtheme::scale_x_datetime_bfh(
        labels = format_config$labels,
        breaks = breaks_posix
      )
    } else {
      # Fallback to breaks_pretty with intelligent count
      plot <- plot + BFHtheme::scale_x_datetime_bfh(
        labels = format_config$labels,
        breaks = scales::breaks_pretty(n = format_config$n_breaks)
      )
    }
  } else if (is.numeric(qic_data$x)) {
    # Numeric X-axis (observation sequence)
    plot <- plot + BFHtheme::scale_x_continuous_bfh(
      breaks = scales::pretty_breaks(n = 8)
    )
  }

  return(plot)
}
