# fct_add_spc_labels.R
# Shiny app wrapper for advanced label placement system
#
# Forenklet interface til add_right_labels_marquee() med Shiny-specifikke defaults

#' Add SPC labels to plot using advanced placement system
#'
#' Wrapper funktion der tilføjer CL og Target labels til SPC plot
#' ved hjælp af NPC-baseret collision avoidance system.
#'
#' @param plot ggplot object (SPC plot uden labels)
#' @param qic_data data.frame fra qicharts2::qic() med columns: cl, target, part
#' @param y_axis_unit character unit for y-akse ("count", "percent", "rate", "time", eller andet)
#' @param label_size numeric base font size for responsive sizing (default 6)
#' @param viewport_width numeric viewport width in pixels (optional, from clientData)
#' @param viewport_height numeric viewport height in pixels (optional, from clientData)
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
#' 5. Kalder add_right_labels_marquee() med Shiny-specifikke defaults
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' plot <- qic(x, y, data = df, chart = "i")
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
#' @export
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
  # Entry logging (conditional)
  if (verbose || getOption("spc.debug.label_placement", FALSE)) {
    log_debug("Function called", .context = "LABEL_PLACEMENT")
    log_debug_kv(
      y_axis_unit = y_axis_unit,
      label_size = label_size,
      .context = "LABEL_PLACEMENT"
    )

    if (!is.null(viewport_width) && !is.null(viewport_height)) {
      log_debug_kv(
        viewport_width_px = viewport_width,
        viewport_height_px = viewport_height,
        message = "Viewport dimensions provided",
        .context = "LABEL_PLACEMENT"
      )
    } else {
      log_debug("No viewport dimensions provided - will use device detection", .context = "LABEL_PLACEMENT")
    }
  }

  # Convert viewport dimensions from pixels to inches (renderPlot uses res=96)
  viewport_width_inches <- if (!is.null(viewport_width)) viewport_width / 96 else NULL
  viewport_height_inches <- if (!is.null(viewport_height)) viewport_height / 96 else NULL

  if (verbose || getOption("spc.debug.label_placement", FALSE)) {
    if (!is.null(viewport_width_inches) && !is.null(viewport_height_inches)) {
      log_debug_kv(
        viewport_width_inches = viewport_width_inches,
        viewport_height_inches = viewport_height_inches,
        message = "Viewport dimensions in inches",
        .context = "LABEL_PLACEMENT"
      )
    }
  }

  # Input validation ----
  if (!inherits(plot, "gg")) {
    log_error("EARLY EXIT: plot is not ggplot object", .context = "LABEL_PLACEMENT")
    stop("plot skal være et ggplot object")
  }

  if (!is.data.frame(qic_data)) {
    log_error("EARLY EXIT: qic_data is not data.frame", .context = "LABEL_PLACEMENT")
    stop("qic_data skal være en data.frame")
  }

  if (verbose || getOption("spc.debug.label_placement", FALSE)) {
    log_debug("Input validation passed", .context = "LABEL_PLACEMENT")
  }

  # Validate y_axis_unit
  valid_units <- c("count", "percent", "rate", "time")
  if (!y_axis_unit %in% valid_units && verbose) {
    log_debug_kv(
      y_axis_unit = y_axis_unit,
      valid_units = paste(valid_units, collapse = ", "),
      message = "Non-standard y_axis_unit",
      .context = "LABEL_PLACEMENT"
    )
  }

  # DEVICE INFO LOGGING (Non-blocking) ----
  # FIX: ggplot objects CAN be built without an active graphics device.
  # Device is only needed when renderPlot() executes, not during plot construction.
  # The downstream functions (add_right_labels_marquee, measure_panel_height_from_gtable)
  # already have fallback logic for missing device (defaults to 7×7 inches).
  #
  # Therefore: NO blocking checks here - just log device status for debugging.

  # Log device status (non-blocking)
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

  # Log device info (conditional on verbose mode)
  if (verbose || getOption("spc.debug.label_placement", FALSE)) {
    log_debug_kv(
      device_status = if (device_info$open) "OPEN" else "NOT OPEN",
      dev_cur = device_info$dev_num,
      .context = "DEVICE_INFO"
    )

    if (device_info$open) {
      log_debug_kv(
        device_width = device_info$width,
        device_height = device_info$height,
        message = "Device size",
        .context = "DEVICE_INFO"
      )
    } else {
      log_debug("No device open - downstream functions will use fallback sizes (7×7 inches)", .context = "DEVICE_INFO")
    }
  }

  # FIX: Auto-scale label_size baseret på device height (hvis tilgængelig)
  # Dette sikrer at labels skalerer proportionelt med plot størrelse
  # Baseline: label_size = 6 for ~7.8" device height (small plot reference)
  device_height_baseline <- 7.8 # inches (reference: 751px @ 96dpi)

  if (device_info$open && !is.na(device_info$height)) {
    # Device aktiv med valid height - skalér label_size
    dev_height <- device_info$height

    # Skalér label_size proportionelt med device height
    # VIGTIGT: Kun skalér opad (scale_factor >= 1.0) for at undgå under-skalering
    # på små plots hvor labels ville blive ulæseligt små
    # Small plot (7.8"): label_size = 6.0 (ikke skaleret ned)
    # Large plot (18.2"): label_size = 6.0 * (18.2/7.8) ≈ 14.0 (skaleret op)
    scale_factor <- pmax(1.0, dev_height / device_height_baseline)
    label_size_scaled <- label_size * scale_factor

    if (verbose) {
      log_debug_kv(
        original_label_size = label_size,
        scaled_label_size = label_size_scaled,
        device_height = dev_height,
        scale_factor = scale_factor,
        message = "Auto-scaled label_size",
        .context = "LABEL_PLACEMENT"
      )
    }

    label_size <- label_size_scaled
  } else {
    # Ingen device eller ingen valid height - brug original label_size
    if (verbose) {
      log_debug_kv(
        label_size = label_size,
        message = "No device height available - using fixed label_size",
        .context = "LABEL_PLACEMENT"
      )
    }
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
    # Find seneste part
    if ("part" %in% names(qic_data)) {
      latest_part <- max(qic_data$part, na.rm = TRUE)
      part_data <- qic_data[qic_data$part == latest_part & !is.na(qic_data$part), ]

      if (nrow(part_data) > 0) {
        # Brug sidste punkt i seneste part
        last_row <- part_data[nrow(part_data), ]
        cl_value <- last_row$cl
      }
    } else {
      # Ingen parts - brug sidste CL værdi
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
    if (verbose || getOption("spc.debug.label_placement", FALSE)) {
      log_error("BLOCKING: Ingen CL eller Target værdier fundet i qic_data", .context = "CL_TARGET_CHECK")
    }
    warning("Ingen CL eller Target værdier fundet i qic_data. Returnerer plot uændret.")
    return(plot)
  }

  # DEBUG: Log extracted values
  if (verbose || getOption("spc.debug.label_placement", FALSE)) {
    log_debug_kv(
      cl_value = ifelse(is.na(cl_value), "NA", sprintf("%.2f", cl_value)),
      target_value = ifelse(is.na(target_value), "NA", sprintf("%.2f", target_value)),
      message = "Values extracted",
      .context = "CL_TARGET_CHECK"
    )
  }

  # Formatér labels med delt formatter ----
  label_cl <- NULL
  if (!is.na(cl_value)) {
    # Bestem CL header baseret på baseline-logik
    # Regel 1: Hvis centerline_value er angivet → "BASELINE"
    # Regel 2: Hvis Frys-kolonne er valgt OG Skift-kolonne IKKE er valgt → "BASELINE"
    # Ellers → "NUV. NIVEAU"
    cl_header <- if (!is.null(centerline_value) && !is.na(centerline_value)) {
      "BASELINE"
    } else if (has_frys_column && !has_skift_column) {
      "BASELINE"
    } else {
      "NUV. NIVEAU"
    }

    if (verbose || getOption("spc.debug.label_placement", FALSE)) {
      log_debug_kv(
        centerline_value = if (!is.null(centerline_value) && !is.na(centerline_value)) sprintf("%.2f", centerline_value) else "NULL",
        has_frys = has_frys_column,
        has_skift = has_skift_column,
        cl_header = cl_header,
        message = "CL header logic",
        .context = "CL_HEADER_LOGIC"
      )
    }

    formatted_cl <- format_y_value(cl_value, y_axis_unit, y_range)
    label_cl <- create_responsive_label(
      header = cl_header,
      value = formatted_cl,
      label_size = label_size
    )
  }

  label_target <- NULL
  has_arrow <- FALSE
  arrow_type <- NULL # "up" or "down"

  if (!is.na(target_value)) {
    # Determiner label value baseret på om vi har target_text
    if (!is.null(target_text) && nchar(trimws(target_text)) > 0) {
      # Debug logging
      if (verbose || getOption("spc.debug.label_placement", FALSE)) {
        log_debug_kv(
          raw_target_text = target_text,
          .context = "TARGET_FORMATTING"
        )
      }

      # Brug target_text med formateret prefix
      formatted_target_with_prefix <- format_target_prefix(target_text)

      # Debug logging
      if (verbose || getOption("spc.debug.label_placement", FALSE)) {
        log_debug_kv(
          formatted_target = formatted_target_with_prefix,
          message = "After format_target_prefix",
          .context = "TARGET_FORMATTING"
        )
      }

      # Detektér om der er pil-symbol
      has_arrow <- has_arrow_symbol(formatted_target_with_prefix)

      # AUTO-ADD PERCENT SUFFIX: If y_axis_unit is "percent" and user didn't include %
      # Only add % if:
      # 1. y_axis_unit == "percent"
      # 2. Text doesn't already contain %
      # 3. It's not an arrow symbol (arrows don't need %)
      if (y_axis_unit == "percent" && !has_arrow && !grepl("%", formatted_target_with_prefix, fixed = TRUE)) {
        formatted_target_with_prefix <- paste0(formatted_target_with_prefix, "%")
        if (verbose || getOption("spc.debug.label_placement", FALSE)) {
          log_debug_kv(
            target_with_percent = formatted_target_with_prefix,
            message = "Auto-added % suffix",
            .context = "TARGET_FORMATTING"
          )
        }
      }

      if (verbose || getOption("spc.debug.label_placement", FALSE)) {
        log_debug_kv(
          has_arrow = has_arrow,
          .context = "TARGET_FORMATTING"
        )
      }

      if (has_arrow) {
        # Check for specific arrow types using direct character comparison
        # For single arrow characters, == is more reliable than grepl
        arrow_down_char <- "\U2193"
        arrow_up_char <- "\U2191"

        # Debug: Show what we're comparing
        if (verbose || getOption("spc.debug.label_placement", FALSE)) {
          log_debug("Comparing arrow types", .context = "ARROW_TYPE_DETECTION")
          log_debug_kv(
            formatted = formatted_target_with_prefix,
            arrow_down = arrow_down_char,
            is_down = formatted_target_with_prefix == arrow_down_char,
            .context = "ARROW_TYPE_DETECTION"
          )
          log_debug_kv(
            formatted = formatted_target_with_prefix,
            arrow_up = arrow_up_char,
            is_up = formatted_target_with_prefix == arrow_up_char,
            .context = "ARROW_TYPE_DETECTION"
          )
        }

        # Direct comparison since formatted_target_with_prefix is exactly the arrow character
        arrow_type <- if (formatted_target_with_prefix == arrow_down_char) {
          "down"
        } else if (formatted_target_with_prefix == arrow_up_char) {
          "up"
        } else {
          # Fallback if neither detected (should not happen)
          warning(sprintf("Unexpected arrow format: '%s'", formatted_target_with_prefix))
          "down"
        }

        if (verbose || getOption("spc.debug.label_placement", FALSE)) {
          log_debug_kv(
            arrow_type = arrow_type,
            arrow_char = formatted_target_with_prefix,
            message = "Arrow detected - targetline will be suppressed",
            .context = "ARROW_DETECTED"
          )
        }
      }
    } else {
      # Fallback: brug formateret numerisk værdi med ≥ prefix (legacy behaviour)
      formatted_target <- format_y_value(target_value, y_axis_unit, y_range)
      formatted_target_with_prefix <- paste0(formatted_target)
    }

    label_target <- create_responsive_label(
      header = "UDVIKLINGSMÅL",
      value = formatted_target_with_prefix,
      label_size = label_size
    )
  }

  # Håndter pil-positioning: beregn y-akse limits for arrow placement ----
  if (has_arrow) {
    if (verbose || getOption("spc.debug.label_placement", FALSE)) {
      log_debug_kv(
        arrow_type = arrow_type,
        message = "Entering arrow positioning block",
        .context = "ARROW_POSITIONING"
      )
    }

    # Get y-axis limits from qic_data
    y_min <- min(qic_data$y, na.rm = TRUE)
    y_max <- max(qic_data$y, na.rm = TRUE)
    y_range_plot <- y_max - y_min

    if (verbose || getOption("spc.debug.label_placement", FALSE)) {
      log_debug_kv(
        y_min = y_min,
        y_max = y_max,
        y_range = y_range_plot,
        message = "Y-axis range",
        .context = "ARROW_POSITIONING"
      )
    }

    # CRITICAL FIX: Position arrow labels INSIDE plot boundaries
    # Labels placed outside y-axis limits may not render due to clipping
    # Use small inset margin (1% from edge) to keep labels visible
    # This ensures labels are always within rendered plot area
    inset_margin_factor <- 0.01 # 1% inset from edge
    arrow_y_position <- if (arrow_type == "down") {
      # Place at bottom with small inset (slightly above y_min)
      y_min + (y_range_plot * inset_margin_factor)
    } else {
      # Place at top with small inset (slightly below y_max)
      y_max - (y_range_plot * inset_margin_factor)
    }

    if (verbose || getOption("spc.debug.label_placement", FALSE)) {
      log_debug_kv(
        arrow_type = arrow_type,
        arrow_y_position = arrow_y_position,
        y_min = y_min,
        y_max = y_max,
        message = "Placing arrow",
        .context = "ARROW_POSITIONING"
      )
    }

    # Override target_value for label positioning
    target_value <- arrow_y_position

    if (verbose || getOption("spc.debug.label_placement", FALSE)) {
      log_debug_kv(
        target_value = target_value,
        message = "target_value overridden",
        .context = "ARROW_POSITIONING"
      )
    }
  }

  # Håndter edge case: kun én label ----
  if (is.null(label_cl) || is.na(cl_value)) {
    # Kun target label
    if (verbose) {
      log_debug("Only Target label available", .context = "LABEL_PLACEMENT")
    }
    # Sæt cl til NA og brug target som primær
    yA <- target_value
    yB <- NA_real_
    textA <- label_target
    textB <- ""
  } else if (is.null(label_target) || is.na(target_value)) {
    # Kun CL label
    if (verbose) {
      log_debug("Only CL label available", .context = "LABEL_PLACEMENT")
    }
    yA <- cl_value
    yB <- NA_real_
    textA <- label_cl
    textB <- ""
  } else {
    # Begge labels tilgængelige
    yA <- cl_value
    yB <- target_value
    textA <- label_cl
    textB <- label_target
  }

  # Placer labels med advanced placement system ----
  if (verbose || getOption("spc.debug.label_placement", FALSE)) {
    log_debug_kv(
      yA = yA,
      yB = ifelse(is.na(yB), "NA", sprintf("%.3f", yB)),
      textA_length = nchar(textA),
      textB_length = nchar(textB),
      message = "Calling add_right_labels_marquee",
      .context = "LABEL_PLACEMENT"
    )
  }

  # CRITICAL FIX: Arrow labels skal holde deres absolutte positioner
  # Når arrows detekteres, skal collision avoidance IKKE flytte labels
  # Dette opnås ved at sætte gap_labels til 0 (ingen spacing enforcement)
  # og lade labels placeres præcist ved deres givne y-koordinater
  if (has_arrow) {
    if (verbose || getOption("spc.debug.label_placement", FALSE)) {
      log_debug("Arrow detected - disabling collision avoidance (gap_labels=0)", .context = "LABEL_PLACEMENT")
    }
    label_params <- list(
      pad_top = 0.01,
      pad_bot = 0.01,
      gap_labels = 0, # CRITICAL: Disable collision avoidance for arrows
      pref_pos = c("under", "under"),
      priority = "A"
    )
  } else {
    # Normal labels: use collision avoidance
    label_params <- list(
      pad_top = 0.01,
      pad_bot = 0.01,
      # gap_labels uses default from config
      pref_pos = c("under", "under"),
      priority = "A"
    )
  }

  plot_with_labels <- add_right_labels_marquee(
    p = plot,
    yA = yA,
    yB = yB,
    textA = textA,
    textB = textB,
    params = label_params,
    gpA = grid::gpar(col = "#009CE8"), # CL label farve (lyseblå)
    gpB = grid::gpar(col = "#565656"), # Target label farve (grå)
    label_size = label_size, # Label sizing (baseline = 6)
    viewport_width = viewport_width_inches, # Viewport width in inches (from clientData)
    viewport_height = viewport_height_inches, # Viewport height in inches (from clientData)
    verbose = verbose, # Print placement warnings
    debug_mode = debug_mode # Visual debugging
  )

  if (verbose || getOption("spc.debug.label_placement", FALSE)) {
    log_debug("add_right_labels_marquee returned successfully", .context = "LABEL_PLACEMENT")
  }

  # Attach metadata about arrow detection for targetline suppression
  attr(plot_with_labels, "suppress_targetline") <- has_arrow
  attr(plot_with_labels, "arrow_type") <- arrow_type

  if (verbose && has_arrow) {
    log_debug_kv(
      suppress_targetline = TRUE,
      arrow_type = arrow_type,
      message = "Setting suppress_targetline",
      .context = "METADATA"
    )
  }

  return(plot_with_labels)
}
