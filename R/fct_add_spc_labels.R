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

  # Auto-scale label_size baseret på viewport/device height
  # FIX (#90): Kun auto-scale når viewport IKKE er givet.
  # Viewport-dimensioner er den autoritative kilde til sizing.
  # Uden dette fix er label_size ikke-deterministisk (afhænger af åben device).
  device_height_baseline <- 7.8 # inches (reference: 751px @ 96dpi)

  if (!is.null(viewport_height)) {
    # Viewport er givet - brug den som autoritativ kilde (deterministisk)
    scale_factor <- pmax(1.0, viewport_height / device_height_baseline)
    label_size <- label_size * scale_factor
  } else if (device_info$open && !is.na(device_info$height)) {
    # Legacy path: ingen viewport, brug åben device (ikke-deterministisk men nødvendigt)
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
  # INTENTIONEL ASYMMETRI: CL hentes fra seneste part (centerlinjen ændres ved
  # faseovergange), mens target hentes som første non-NA (target er typisk
  # konstant og sat af brugeren uafhængigt af faser).
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

    # Kontekstuel præcision for procent: send target hvis tilgængelig
    target_for_precision <- if (y_axis_unit == "percent" && !is.na(target_value)) {
      target_value
    } else {
      NULL
    }
    formatted_cl <- format_y_value(cl_value, y_axis_unit, y_range, target = target_for_precision)
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
      # Struktureret parsing: operator og value separeres, så sanitizeren
      # aldrig ser rå <, >, >=, <= (de er allerede Unicode-symboler).
      # Operatoren bypasser sanitizeren via operator_prefix parameter.
      parsed <- parse_target_input(target_text)
      has_arrow <- parsed$is_arrow

      if (has_arrow) {
        arrow_type <- if (parsed$operator == "\U2193") "down" else "up"
        target_operator <- parsed$operator
        target_value_text <- ""
      } else {
        target_operator <- parsed$operator
        target_value_text <- parsed$value

        # AUTO-ADD PERCENT SUFFIX til value-delen (ikke operator)
        if (y_axis_unit == "percent" && !grepl("%", target_value_text, fixed = TRUE)) {
          target_value_text <- paste0(target_value_text, "%")
        }
      }
    } else {
      formatted_target <- format_y_value(target_value, y_axis_unit, y_range)
      target_operator <- ""
      target_value_text <- formatted_target
    }

    label_target <- create_responsive_label(
      header = "UDVIKLINGSMÅL",
      value = target_value_text,
      label_size = label_size,
      operator_prefix = target_operator
    )
  }

  # Build plot og mapper én gang - genbrug til arrow-placering + labels
  built_plot <- ggplot2::ggplot_build(plot)
  shared_mapper <- npc_mapper_from_built(built_plot, original_plot = plot)

  # Håndter pil-positioning via NPC panel bounds (ikke rå data-ekstremer,
  # som afviger ved axis expansion eller manuelle limits)
  if (has_arrow) {
    inset_npc <- 0.01
    arrow_y_position <- if (arrow_type == "down") {
      shared_mapper$npc_to_y(inset_npc)
    } else {
      shared_mapper$npc_to_y(1 - inset_npc)
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

  # Boundary-aware pref_pos: Når begge linjer er nær bund/top af plottet,
  # spred labels ved at placere den nederste "under" og den øverste "over".
  # Når kun én linje er nær kanten, foretruk den side med mest plads.
  boundary_threshold <- 0.30
  pref_A <- "under"
  pref_B <- "under"

  if (!is.na(yA) && !is.na(yB)) {
    npc_A <- shared_mapper$y_to_npc(yA)
    npc_B <- shared_mapper$y_to_npc(yB)

    if (!is.null(npc_A) && !is.na(npc_A) &&
        !is.null(npc_B) && !is.na(npc_B)) {
      both_near_bottom <- npc_A < boundary_threshold && npc_B < boundary_threshold
      both_near_top <- npc_A > (1 - boundary_threshold) && npc_B > (1 - boundary_threshold)

      if (both_near_bottom) {
        # Spred: nederste label under sin linje, øverste over sin linje
        if (npc_A <= npc_B) {
          pref_A <- "under"
          pref_B <- "over"
        } else {
          pref_A <- "over"
          pref_B <- "under"
        }
      } else if (both_near_top) {
        # Spred: øverste label over sin linje, nederste under sin linje
        if (npc_A >= npc_B) {
          pref_A <- "over"
          pref_B <- "under"
        } else {
          pref_A <- "under"
          pref_B <- "over"
        }
      } else {
        # Kun én nær kanten: foretruk den side med mest plads
        if (npc_A < boundary_threshold) pref_A <- "over"
        if (npc_B < boundary_threshold) pref_B <- "over"
        if (npc_A > (1 - boundary_threshold)) pref_A <- "under"
        if (npc_B > (1 - boundary_threshold)) pref_B <- "under"
      }
    }
  }

  label_params <- list(
    pad_top = 0.01,
    pad_bot = 0.01,
    pref_pos = c(pref_A, pref_B),
    priority = "A"
  )
  if (has_arrow) label_params$gap_labels <- 0

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
    viewport_width = viewport_width,
    viewport_height = viewport_height,
    verbose = verbose,
    debug_mode = debug_mode,
    .built_plot = built_plot,
    .mapper = shared_mapper
  )

  # Attach metadata about arrow detection for targetline suppression
  attr(plot_with_labels, "suppress_targetline") <- has_arrow
  attr(plot_with_labels, "arrow_type") <- arrow_type

  return(plot_with_labels)
}
