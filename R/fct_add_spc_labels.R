# fct_add_spc_labels.R
# Standalone wrapper for advanced label placement system
#
# Simplified interface til add_right_labels_marquee() med reasonable defaults

#' Add SPC labels to plot using advanced placement system
#'
#' Wrapper funktion der tilføjer CL og Target labels til SPC plot
#' ved hjælp af NPC-baseret collision avoidance system.
#'
#' @param plot ggplot object (SPC plot uden labels)
#' @param qic_data data.frame fra qicharts2::qic() med columns: cl, target, part
#' @param y_axis_unit character unit for y-akse ("count", "percent", "rate", "time", eller andet)
#' @param label_size numeric base font size for responsive sizing (default 6)
#' @param viewport_width numeric viewport width in inches (optional, for precise placement)
#' @param viewport_height numeric viewport height in inches (optional, for precise placement)
#' @param target_text character original målværdi text from user input (optional, for operator parsing)
#' @param centerline_value numeric centerline value from user input (optional, for BASELINE label logic)
#' @param has_frys_column logical TRUE if Frys column is selected (optional, for BASELINE label logic)
#' @param has_skift_column logical TRUE if Skift column is selected (optional, for BASELINE label logic)
#' @param verbose logical print placement warnings (default FALSE)
#' @param debug_mode logical add visual debug annotations (default FALSE)
#' @return ggplot object med tilføjede labels
#'
#' @details
#' Funktionen:
#' 1. Ekstraherer CL værdi fra seneste part i qic_data
#' 2. Ekstraherer Target værdi fra qic_data
#' 3. Formaterer værdier baseret på y_axis_unit
#' 4. Opretter responsive marquee-formaterede labels
#' 5. Kalder add_right_labels_marquee() med intelligent collision avoidance
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' plot <- qic(x, y, data = df, chart = "i", return.data = TRUE)
#' plot_with_labels <- add_spc_labels(plot, plot$data, y_axis_unit = "count")
#'
#' # With debug mode
#' plot_with_labels <- add_spc_labels(
#'   plot, plot$data,
#'   y_axis_unit = "percent",
#'   verbose = TRUE,
#'   debug_mode = TRUE
#' )
#' }
#'
#' @keywords internal
#' @noRd
#' @family label-placement
#' @seealso [add_right_labels_marquee()], [create_responsive_label()], [format_y_value()]
add_spc_labels <- function(
    plot,
    qic_data,
    y_axis_unit = "count",
    label_size = 6,
    viewport_width = NULL,
    viewport_height = NULL,
    target_text = NULL,
    centerline_value = NULL,
    has_frys_column = FALSE,
    has_skift_column = FALSE,
    verbose = FALSE,
    debug_mode = FALSE) {

  # Viewport dimensions are now in inches (direct input from create_spc_chart)
  viewport_width_inches <- viewport_width
  viewport_height_inches <- viewport_height

  # Input validation ----
  if (!inherits(plot, "gg")) {
    stop("plot skal være et ggplot object")
  }

  if (!is.data.frame(qic_data)) {
    stop("qic_data skal være en data.frame")
  }

  # Validate y_axis_unit
  valid_units <- c("count", "percent", "rate", "time")
  if (!y_axis_unit %in% valid_units && verbose) {
    message(sprintf("Non-standard y_axis_unit: %s (valid: %s)",
                    y_axis_unit, paste(valid_units, collapse = ", ")))
  }

  # Device info (non-blocking) ----
  device_info <- tryCatch(
    {
      dev_cur <- grDevices::dev.cur()
      dev_open <- dev_cur > 1

      if (dev_open) {
        dev_size <- grDevices::dev.size("in")
        list(
          open = TRUE,
          dev_num = dev_cur,
          width = dev_size[1],
          height = dev_size[2]
        )
      } else {
        list(
          open = FALSE,
          dev_num = dev_cur,
          width = NA_real_,
          height = NA_real_
        )
      }
    },
    error = function(e) {
      list(
        open = FALSE,
        dev_num = 1,
        width = NA_real_,
        height = NA_real_,
        error = e$message
      )
    }
  )

  # Auto-scale label_size baseret på device height (hvis tilgængelig)
  device_height_baseline <- 7.8 # inches (reference: 751px @ 96dpi)

  if (device_info$open && !is.na(device_info$height)) {
    dev_height <- device_info$height
    scale_factor <- pmax(1.0, dev_height / device_height_baseline)
    label_size <- label_size * scale_factor
  }

  # Beregn y_range for time formatting context
  y_range <- if (y_axis_unit == "time" && !is.null(qic_data$y)) {
    range(qic_data$y, na.rm = TRUE)
  } else {
    NULL
  }

  # Ekstrahér CL værdi fra seneste part ----
  cl_value <- NA_real_
  if (!is.null(qic_data$cl) && any(!is.na(qic_data$cl))) {
    if ("part" %in% names(qic_data)) {
      latest_part <- max(qic_data$part, na.rm = TRUE)
      part_data <- qic_data[qic_data$part == latest_part & !is.na(qic_data$part), ]

      if (nrow(part_data) > 0) {
        last_row <- part_data[nrow(part_data), ]
        cl_value <- last_row$cl
      }
    } else {
      cl_value <- tail(stats::na.omit(qic_data$cl), 1)
    }
  }

  # Ekstrahér Target værdi ----
  target_value <- NA_real_
  if (!is.null(qic_data$target) && any(!is.na(qic_data$target))) {
    target_value <- qic_data$target[!is.na(qic_data$target)][1]
  }

  # Valider at vi har mindst én værdi ----
  if (is.na(cl_value) && is.na(target_value)) {
    warning("Ingen CL eller Target værdier fundet i qic_data. Returnerer plot uændret.")
    return(plot)
  }

  # Formatér labels ----
  label_cl <- NULL
  if (!is.na(cl_value)) {
    # Bestem CL header baseret på baseline-logik
    cl_header <- if (!is.null(centerline_value) && !is.na(centerline_value)) {
      "BASELINE"
    } else if (has_frys_column && !has_skift_column) {
      "BASELINE"
    } else {
      "NUV. NIVEAU"
    }

    formatted_cl <- format_y_value(round(cl_value), y_axis_unit, y_range)
    label_cl <- create_responsive_label(
      header = cl_header,
      value = formatted_cl,
      label_size = label_size
    )
  }

  label_target <- NULL
  has_arrow <- FALSE
  arrow_type <- NULL

  if (!is.na(target_value)) {
    if (!is.null(target_text) && nchar(trimws(target_text)) > 0) {
      formatted_target_with_prefix <- format_target_prefix(target_text)
      has_arrow <- has_arrow_symbol(formatted_target_with_prefix)

      # AUTO-ADD PERCENT SUFFIX
      if (y_axis_unit == "percent" && !has_arrow && !grepl("%", formatted_target_with_prefix, fixed = TRUE)) {
        formatted_target_with_prefix <- paste0(formatted_target_with_prefix, "%")
      }

      if (has_arrow) {
        arrow_down_char <- "\U2193"
        arrow_up_char <- "\U2191"

        arrow_type <- if (formatted_target_with_prefix == arrow_down_char) {
          "down"
        } else if (formatted_target_with_prefix == arrow_up_char) {
          "up"
        } else {
          warning(sprintf("Unexpected arrow format: '%s'", formatted_target_with_prefix))
          "down"
        }
      }
    } else {
      formatted_target <- format_y_value(target_value, y_axis_unit, y_range)
      formatted_target_with_prefix <- formatted_target
    }

    label_target <- create_responsive_label(
      header = "UDVIKLINGSMÅL",
      value = formatted_target_with_prefix,
      label_size = label_size
    )
  }

  # Håndter pil-positioning ----
  if (has_arrow) {
    y_min <- min(qic_data$y, na.rm = TRUE)
    y_max <- max(qic_data$y, na.rm = TRUE)
    y_range_plot <- y_max - y_min

    inset_margin_factor <- 0.01
    arrow_y_position <- if (arrow_type == "down") {
      y_min + (y_range_plot * inset_margin_factor)
    } else {
      y_max - (y_range_plot * inset_margin_factor)
    }

    target_value <- arrow_y_position
  }

  # Håndter edge case: kun én label ----
  if (is.null(label_cl) || is.na(cl_value)) {
    yA <- target_value
    yB <- NA_real_
    textA <- label_target
    textB <- ""
  } else if (is.null(label_target) || is.na(target_value)) {
    yA <- cl_value
    yB <- NA_real_
    textA <- label_cl
    textB <- ""
  } else {
    yA <- cl_value
    yB <- target_value
    textA <- label_cl
    textB <- label_target
  }

  # Placer labels med advanced placement system ----
  if (has_arrow) {
    label_params <- list(
      pad_top = 0.01,
      pad_bot = 0.01,
      gap_labels = 0, # CRITICAL: Disable collision avoidance for arrows
      pref_pos = c("under", "under"),
      priority = "A"
    )
  } else {
    label_params <- list(
      pad_top = 0.01,
      pad_bot = 0.01,
      pref_pos = c("under", "under"),
      priority = "A"
    )
  }

  # PERFORMANCE: Build plot én gang og genbruge
  built_plot <- ggplot2::ggplot_build(plot)

  plot_with_labels <- add_right_labels_marquee(
    p = plot,
    yA = yA,
    yB = yB,
    textA = textA,
    textB = textB,
    params = label_params,
    gpA = grid::gpar(col = BFHtheme::bfh_cols("hospital_blue")),
    gpB = grid::gpar(col = BFHtheme::bfh_cols("hospital_dark_grey")),
    label_size = label_size,
    viewport_width = viewport_width_inches,
    viewport_height = viewport_height_inches,
    verbose = verbose,
    debug_mode = debug_mode,
    .built_plot = built_plot
  )

  # Attach metadata about arrow detection for targetline suppression
  attr(plot_with_labels, "suppress_targetline") <- has_arrow
  attr(plot_with_labels, "arrow_type") <- arrow_type

  return(plot_with_labels)
}
