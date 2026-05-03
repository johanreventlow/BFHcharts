# fct_add_spc_labels.R
# Standalone wrapper for advanced label placement system
#
# Simplified interface til add_right_labels_marquee() med reasonable defaults


#' Beregn viewport-skaleret label_size forankret til PDF golden standard
#'
#' Returnerer label_size proportionelt skaleret fra PDF-referencen
#' (label_size=6 ved 191.4mm bredde). Bruger bredde-baseret skalering,
#' da labels er horisontal tekst og laesbarhed afhaenger af tilgaengelig bredde.
#'
#' @param viewport_width_inches Viewport bredde i inches
#' @param viewport_height_inches Viewport hoejde i inches (ubrugt, bevaret for API-kompatibilitet)
#' @return Numerisk label_size
#'
#' @keywords internal
#' @noRd
compute_label_size_for_viewport <- function(viewport_width_inches,
                                            viewport_height_inches) {
  # Bredde-baseret skalering: labels er horisontal tekst - deres laesbarhed
  # afhaenger af tilgaengelig bredde, ikke hoejde. At goere et chart hoejere
  # boer give mere plads til data, ikke stoerre labels/gaps.
  pdf_width_inches <- PDF_CHART_WIDTH_MM / 25.4
  label_size <- PDF_LABEL_SIZE * viewport_width_inches / pdf_width_inches
  # Cap: max label_size = 20 (sikrer value_size <= 100pt ved default value_pt=30)
  min(label_size, 20)
}


#' Add SPC labels to plot using advanced placement system
#'
#' Wrapper funktion der tilfoejer CL og Target labels til SPC plot
#' ved hjaelp af NPC-baseret collision avoidance system.
#'
#' @param plot ggplot object (SPC plot uden labels)
#' @param qic_data data.frame fra qicharts2::qic() med columns: cl, target, part
#' @param y_axis_unit character unit for y-akse ("count", "percent", "rate", "time", eller andet)
#' @param label_size numeric base font size for responsive sizing (default 6)
#' @param viewport_width numeric viewport width in inches (optional, for precise placement)
#' @param viewport_height numeric viewport height in inches (optional, for precise placement)
#' @param target_text character original maalvaerdi text from user input (optional, for operator parsing)
#' @param centerline_value numeric centerline value from user input (optional, for BASELINE label logic)
#' @param has_frys_column logical TRUE if Frys column is selected (optional, for BASELINE label logic)
#' @param has_skift_column logical TRUE if Skift column is selected (optional, for BASELINE label logic)
#' @param verbose logical print placement warnings (default FALSE)
#' @param debug_mode logical add visual debug annotations (default FALSE)
#' @return ggplot object med tilfoejede labels
#'
#' @details
#' Funktionen:
#' 1. Ekstraherer CL vaerdi fra seneste part i qic_data
#' 2. Ekstraherer Target vaerdi fra qic_data
#' 3. Formaterer vaerdier baseret paa y_axis_unit
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
  debug_mode = FALSE,
  language = "da"
) {
  .ensure_bfhtheme()
  # Input validation ----
  if (!inherits(plot, "gg")) {
    stop("plot must be a ggplot object", call. = FALSE)
  }

  if (!is.data.frame(qic_data)) {
    stop("qic_data must be a data frame", call. = FALSE)
  }

  # Validate y_axis_unit
  valid_units <- c("count", "percent", "rate", "time")
  if (!y_axis_unit %in% valid_units && verbose) {
    message(sprintf(
      "Non-standard y_axis_unit: %s (valid: %s)",
      y_axis_unit, paste(valid_units, collapse = ", ")
    ))
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

  # Label_size auto-scaling:
  # Primaer sti (bfh_qic med dimensioner, export): label_size er allerede korrekt
  # beregnet via compute_label_size_for_viewport() - ingen skalering noedvendig.
  # Legacy sti (Shiny preview, ingen viewport): beregn fra aaben device.
  if (is.null(viewport_width) && is.null(viewport_height)) {
    if (device_info$open && !is.na(device_info$width) && !is.na(device_info$height)) {
      label_size <- compute_label_size_for_viewport(
        device_info$width, device_info$height
      )
    }
  }

  # Beregn y_range for time formatting context
  y_range <- if (y_axis_unit == "time" && !is.null(qic_data$y)) {
    range(qic_data$y, na.rm = TRUE)
  } else {
    NULL
  }

  # Ekstraher CL vaerdi fra seneste part ----
  # INTENTIONEL ASYMMETRI: CL hentes fra seneste part (centerlinjen aendres ved
  # faseovergange), mens target hentes som foerste non-NA (target er typisk
  # konstant og sat af brugeren uafhaengigt af faser).
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

  # Ekstraher Target vaerdi ----
  target_value <- NA_real_
  if (!is.null(qic_data$target) && any(!is.na(qic_data$target))) {
    target_value <- qic_data$target[!is.na(qic_data$target)][1]
  }

  # Valider at vi har mindst en vaerdi ----
  if (is.na(cl_value) && is.na(target_value)) {
    warning(
      "No CL or Target values found in qic_data; returning plot unchanged.",
      call. = FALSE
    )
    return(plot)
  }

  # Formater labels ----
  label_cl <- NULL
  if (!is.na(cl_value)) {
    # Bestem CL header baseret paa baseline-logik
    cl_header <- if (!is.null(centerline_value) && !is.na(centerline_value)) {
      i18n_lookup("labels.chart.baseline", language)
    } else if (has_frys_column && !has_skift_column) {
      i18n_lookup("labels.chart.baseline", language)
    } else {
      i18n_lookup("labels.chart.current_level", language)
    }

    # Kontekstuel praecision for procent: send target hvis tilgaengelig
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
      # Struktureret parsing: operator og value separeres, saa sanitizeren
      # aldrig ser raa <, >, >=, <= (de er allerede Unicode-symboler).
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
      header = i18n_lookup("labels.chart.development_goal", language),
      value = target_value_text,
      label_size = label_size,
      operator_prefix = target_operator
    )
  }

  # Build plot og mapper en gang - genbrug til arrow-placering + labels
  built_plot <- ggplot2::ggplot_build(plot)
  shared_mapper <- npc_mapper_from_built(built_plot, original_plot = plot)

  # Haandter pil-positioning via NPC panel bounds (ikke raa data-ekstremer,
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

  # Haandter edge case: kun en label ----
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

  # Boundary-aware pref_pos: Naar begge linjer er naer bund/top af plottet,
  # spred labels ved at placere den nederste "under" og den oeverste "over".
  # Naar kun en linje er naer kanten, foretruk den side med mest plads.
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
        # Spred: nederste label under sin linje, oeverste over sin linje
        if (npc_A <= npc_B) {
          pref_A <- "under"
          pref_B <- "over"
        } else {
          pref_A <- "over"
          pref_B <- "under"
        }
      } else if (both_near_top) {
        # Spred: oeverste label over sin linje, nederste under sin linje
        if (npc_A >= npc_B) {
          pref_A <- "over"
          pref_B <- "under"
        } else {
          pref_A <- "under"
          pref_B <- "over"
        }
      } else {
        # En linje naer kanten: send den mod kanten (ind i expansion-zonen),
        # og den anden linje den modsatte vej - det spreder labels maksimalt.
        if (npc_A < boundary_threshold) {
          pref_A <- "under" # CL n\u00e6r bund -> under (ind i expansion)
          pref_B <- "over" # Target -> over (v\u00e6k fra CL)
        } else if (npc_B < boundary_threshold) {
          pref_B <- "under"
          pref_A <- "over"
        }
        if (npc_A > (1 - boundary_threshold)) {
          pref_A <- "over" # CL n\u00e6r top -> over (ind i expansion)
          pref_B <- "under" # Target -> under (v\u00e6k fra CL)
        } else if (npc_B > (1 - boundary_threshold)) {
          pref_B <- "over"
          pref_A <- "under"
        }
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

  label_cols <- BFHtheme::bfh_cols(c("hospital_blue", "regionh_dark"))

  plot_with_labels <- add_right_labels_marquee(
    p = plot,
    yA = yA,
    yB = yB,
    textA = textA,
    textB = textB,
    params = label_params,
    gpA = grid::gpar(col = label_cols[[1]]),
    gpB = grid::gpar(col = label_cols[[2]]),
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
