#' Batch-maal flere label hoejder med en device session
#'
#' @param texts Character vector af marquee-formaterede tekster
#' @param style marquee style object (delt for alle labels)
#' @param panel_height_inches Panel hoejde i inches
#' @param fallback_npc Fallback vaerdi hvis maaling fejler
#' @param return_details Om der skal returneres liste med details
#'
#' @return List af maalinger (samme format som estimate_label_height_npc)
#'
#' @details
#' PERFORMANCE: AAbner kun en device for alle maalinger i stedet for N devices.
#' Dette giver betydelig performance improvement ved multiple labels (2+).
#'
#' Typisk use case: Maaling af CL og Target labels samtidigt
#' - Gamle approach: 2 device aabninger (~20-40ms overhead)
#' - Ny approach: 1 device aabning (~10-20ms overhead)
#' - Saving: ~50% reduction i device overhead
#'
#' @keywords internal
#' @noRd
estimate_label_heights_npc <- function(
  texts,
  style = NULL,
  panel_height_inches = NULL,
  device_width = NULL,
  device_height = NULL,
  marquee_size = NULL,
  fallback_npc = 0.13,
  return_details = FALSE,
  device_ready = FALSE
) {
  # Default style hvis ikke angivet
  if (is.null(style)) {
    style <- marquee::modify_style(
      marquee::classic_style(),
      "p",
      margin = marquee::trbl(0),
      align = "right"
    )
  }

  # Hvis device_ready = TRUE, brug allerede-aktiv device (caller har aabnet den)
  # Ellers aabn en off-screen Cairo PDF device for measurements
  if (!device_ready) {
    # Gem reference til nuvaerende device
    current_dev <- grDevices::dev.cur()

    # Bestem device stoerrelse til maalinger
    using_fallback <- is.null(device_width) || is.null(device_height)

    if (using_fallback && getOption("spc.debug.label_placement", FALSE)) {
      message(
        "[LABEL_HEIGHT_ESTIMATE] WARNING: No actual device dimensions provided - ",
        "using fallback 8x4.5\" (this should not happen in production with viewport guard)"
      )
    }

    meas_width <- if (!is.null(device_width)) device_width else 8
    meas_height <- if (!is.null(device_height)) device_height else 4.5

    # Open ONE off-screen Cairo PDF device for all measurements
    temp_pdf <- tempfile(fileext = ".pdf")
    grDevices::cairo_pdf(filename = temp_pdf, width = meas_width, height = meas_height)
    temp_dev <- grDevices::dev.cur()

    # CRITICAL: on.exit for device cleanup + file removal + device restore
    on.exit(
      {
        # Luk temp device hvis den stadig er aktiv
        if (grDevices::dev.cur() == temp_dev) {
          tryCatch(grDevices::dev.off(), error = function(e) NULL)
        }
        # Restore original device
        if (current_dev > 1 && current_dev != temp_dev &&
          current_dev %in% grDevices::dev.list()) {
          tryCatch(grDevices::dev.set(current_dev), error = function(e) NULL)
        }
        # Slet temp fil
        unlink(temp_pdf, force = TRUE)
      },
      add = TRUE,
      after = FALSE
    )
  }

  # Measure all texts with shared device
  results <- purrr::map(texts, ~ {
    tryCatch(
      {
        .estimate_label_height_npc_internal(
          text = .x,
          style = style,
          panel_height_inches = panel_height_inches,
          device_width = device_width,
          device_height = device_height,
          marquee_size = marquee_size,
          fallback_npc = fallback_npc,
          return_details = return_details
        )
      },
      error = function(e) {
        warning(
          "Grob-baseret h\u00f8jdem\u00e5ling fejlede: ", e$message,
          " - bruger fallback"
        )
        if (return_details) {
          list(npc = fallback_npc, inches = NA_real_, panel_height_inches = panel_height_inches)
        } else {
          fallback_npc
        }
      }
    )
  })

  return(results)
}


# ==============================================================================
# LABEL PLACEMENT - HELPER FUNCTION
# ==============================================================================

#' Helper: propose single label placement
#'
#' Foreslaar en position for en label ved en linje, med foretrukken side.
#' Flipper automatisk til modsatte side hvis foretrukken side er udenfor bounds.
#'
#' @param y_line_npc Linje position i NPC
#' @param pref_side Foretrukken side: "under" eller "over"
#' @param label_h Label hoejde i NPC
#' @param gap Min gap fra label edge til linje
#' @param pad_top Top padding
#' @param pad_bot Bottom padding
#'
#' @return List med:
#'   - `center`: NPC position for label center
#'   - `side`: Faktisk side ("under" eller "over")
#' @keywords internal
#' @noRd
propose_single_label <- function(y_line_npc, pref_side, label_h, gap, pad_top, pad_bot) {
  half <- label_h / 2
  low_bound <- pad_bot + half
  high_bound <- 1 - pad_top - half

  # Proev foretrukket side foerst
  if (pref_side == "under") {
    y <- y_line_npc - gap - half
    if (y >= low_bound) {
      return(list(center = y, side = "under"))
    }
    # Label passer ikke helt inden for standard bounds, men hvis centeret
    # stadig er over pad_bot, tillad placering i expansion-zonen.
    # Kun en lille del af label-bunden kan blive clippet.
    if (y >= pad_bot) {
      return(list(center = y, side = "under"))
    }
    # Flip til over - label ville vaere overvejende uden for panel
    y <- y_line_npc + gap + half
    return(list(center = clamp_to_bounds(y, low_bound, high_bound), side = "over"))
  } else {
    y <- y_line_npc + gap + half
    if (y <= high_bound) {
      return(list(center = y, side = "over"))
    }
    # Symmetrisk: tillad placering i oevre expansion-zone
    if (y <= 1 - pad_top) {
      return(list(center = y, side = "over"))
    }
    # Flip til under - label ville vaere overvejende uden for panel
    y <- y_line_npc - gap - half
    return(list(center = clamp_to_bounds(y, low_bound, high_bound), side = "under"))
  }
}


# ==============================================================================
# LABEL PLACEMENT - INTERNAL HELPERS (NIVEAU CASCADE)
# ==============================================================================
# The 3-niveau collision cascade is invoked by `place_two_labels_npc()` only
# when an initial collision-push followed by line-gap enforcement creates a
# new collision (lines 728-737 of the orchestrator). The helpers below are
# pure functions: each takes an explicit subset of state (proposed positions,
# bounds, geometry config) and returns either a "success" record with the
# resolved positions or a sentinel `list(success = FALSE)` indicating the
# next niveau should be tried.
#
# Algorithm summary:
#   NIVEAU 1: Try shrinking the inter-label gap by configured reduction
#             factors (50% -> 30% -> 15% by default). First factor that
#             clears the line-gap-induced collision wins.
#   NIVEAU 2: Try flipping label A, then label B, then both, to the opposite
#             side of the corresponding line. Each candidate must produce
#             non-overlapping labels.
#   NIVEAU 3: Last resort. Pin the priority label near its line; pin the
#             other label to the opposite shelf (top or bottom of panel).

#' Verify whether a label position respects the line-gap constraint
#'
#' Standalone version of the closure-form helper used inside
#' `place_two_labels_npc()`. Returns the corrected center plus a `violated`
#' flag so callers can decide whether to apply the correction.
#'
#' @keywords internal
#' @noRd
.verify_line_gap_npc <- function(y_center, y_line, side, label_h, gap_line) {
  half <- label_h / 2
  if (side == "under") {
    required_max <- y_line - gap_line - half
    if (y_center > required_max) {
      return(list(y = required_max, violated = TRUE))
    }
  } else {
    required_min <- y_line + gap_line + half
    if (y_center < required_min) {
      return(list(y = required_min, violated = TRUE))
    }
  }
  list(y = y_center, violated = FALSE)
}

#' NIVEAU 1: Try gap-reduction collision resolution
#'
#' Iterates over `reduction_factors` (default 50%/30%/15%). For each factor,
#' tests whether the proposed positions clear the reduced inter-label gap.
#' First factor that clears the gap wins.
#'
#' @return list with `success` (logical). On success, also `yA`, `yB`,
#'   `placement_quality`, and `warning` (single string).
#' @keywords internal
#' @noRd
.try_niveau_1_gap_reduction <- function(proposed_yA, proposed_yB,
                                        label_height_npc_value, gap_labels,
                                        low_bound, high_bound,
                                        reduction_factors) {
  for (reduction_factor in reduction_factors) {
    reduced_min_gap <- label_height_npc_value + gap_labels * reduction_factor
    if (abs(proposed_yA - proposed_yB) >= reduced_min_gap) {
      return(list(
        success = TRUE,
        yA = clamp_to_bounds(proposed_yA, low_bound, high_bound),
        yB = clamp_to_bounds(proposed_yB, low_bound, high_bound),
        placement_quality = "acceptable",
        warning = paste0(
          "NIVEAU 1: Reduceret label gap til ",
          round(reduction_factor * 100), "% - line-gaps overholdt"
        )
      ))
    }
  }
  list(success = FALSE)
}

#' NIVEAU 2: Try label-flip collision resolution
#'
#' Three strategies tried in order:
#'   2a: Flip label A only.
#'   2b: Flip label B only (if 2a failed).
#'   2c: Flip both labels (if 2a and 2b failed).
#' Each candidate must produce labels separated by at least `label_height_npc_value`
#' (no overlap).
#'
#' @return list with `success` (logical). On success, also `yA`, `yB`,
#'   `sideA`, `sideB`, `placement_quality`, and `warning`.
#' @keywords internal
#' @noRd
.try_niveau_2_flip <- function(proposed_yA, proposed_yB,
                               yA_npc, yB_npc,
                               sideA, sideB,
                               label_height_npc_value,
                               gap_line, pad_top, pad_bot,
                               low_bound, high_bound) {
  # Strategy 2a: flip A
  new_side_A <- if (sideA == "under") "over" else "under"
  propA_flipped <- propose_single_label(
    yA_npc, new_side_A, label_height_npc_value, gap_line, pad_top, pad_bot
  )
  verifyA_flipped <- .verify_line_gap_npc(
    propA_flipped$center, yA_npc, propA_flipped$side,
    label_height_npc_value, gap_line
  )
  test_yA <- if (verifyA_flipped$violated) verifyA_flipped$y else propA_flipped$center

  if (abs(test_yA - proposed_yB) >= label_height_npc_value) {
    return(list(
      success = TRUE,
      yA = clamp_to_bounds(test_yA, low_bound, high_bound),
      yB = clamp_to_bounds(proposed_yB, low_bound, high_bound),
      sideA = propA_flipped$side,
      sideB = sideB,
      placement_quality = "acceptable",
      warning = "NIVEAU 2a: Flippet label A til modsatte side - konflikt l\u00f8st"
    ))
  }

  # Strategy 2b: flip B
  new_side_B <- if (sideB == "under") "over" else "under"
  propB_flipped <- propose_single_label(
    yB_npc, new_side_B, label_height_npc_value, gap_line, pad_top, pad_bot
  )
  verifyB_flipped <- .verify_line_gap_npc(
    propB_flipped$center, yB_npc, propB_flipped$side,
    label_height_npc_value, gap_line
  )
  test_yB <- if (verifyB_flipped$violated) verifyB_flipped$y else propB_flipped$center

  if (abs(proposed_yA - test_yB) >= label_height_npc_value) {
    return(list(
      success = TRUE,
      yA = clamp_to_bounds(proposed_yA, low_bound, high_bound),
      yB = clamp_to_bounds(test_yB, low_bound, high_bound),
      sideA = sideA,
      sideB = propB_flipped$side,
      placement_quality = "acceptable",
      warning = "NIVEAU 2b: Flippet label B til modsatte side - konflikt l\u00f8st"
    ))
  }

  # Strategy 2c: flip both
  if (abs(test_yA - test_yB) >= label_height_npc_value) {
    return(list(
      success = TRUE,
      yA = clamp_to_bounds(test_yA, low_bound, high_bound),
      yB = clamp_to_bounds(test_yB, low_bound, high_bound),
      sideA = propA_flipped$side,
      sideB = propB_flipped$side,
      placement_quality = "suboptimal",
      warning = "NIVEAU 2c: Flippet BEGGE labels til modsatte side - konflikt l\u00f8st"
    ))
  }

  list(success = FALSE)
}

#' NIVEAU 3: Last-resort shelf placement
#'
#' Pins the priority label near its proposed position; pins the
#' non-priority label to the opposite shelf (top vs bottom of panel)
#' based on whether the priority label sits below the configured shelf
#' center threshold.
#'
#' @return list with `yA`, `yB`, `placement_quality` (always "degraded").
#' @keywords internal
#' @noRd
.apply_niveau_3_shelf <- function(proposed_yA, proposed_yB,
                                  low_bound, high_bound,
                                  priority, shelf_threshold) {
  if (priority == "A") {
    yA <- clamp_to_bounds(proposed_yA, low_bound, high_bound)
    yB <- if (yA < shelf_threshold) high_bound else low_bound
  } else {
    yB <- clamp_to_bounds(proposed_yB, low_bound, high_bound)
    yA <- if (yB < shelf_threshold) high_bound else low_bound
  }
  list(yA = yA, yB = yB, placement_quality = "degraded")
}


# ==============================================================================
# LABEL PLACEMENT - PURE HELPERS (lag 1 + lag 2)
# ==============================================================================

#' Parse og valider inputs til place_two_labels_npc
#'
#' Ren valideringsfunktion: parses label_height_npc (numerisk eller list),
#' validerer alle NPC-parametre og returnerer en struktureret parsed-record.
#'
#' @return List med: label_height_npc_value, label_height_inches,
#'   panel_height_inches, label_height_is_list, yA_npc, yB_npc,
#'   pref_pos (normaliseret til length 2)
#'
#' @keywords internal
#' @noRd
.validate_placement_inputs <- function(
  yA_npc,
  yB_npc,
  label_height_npc,
  gap_line,
  gap_labels,
  pad_top,
  pad_bot,
  priority,
  pref_pos,
  debug
) {
  # Parse label_height_npc - kan vaere enten numerisk eller list
  label_height_is_list <- is.list(label_height_npc)

  if (label_height_is_list) {
    if (!all(c("npc", "inches", "panel_height_inches") %in% names(label_height_npc))) {
      stop("label_height_npc list skal indeholde 'npc', 'inches', og 'panel_height_inches'")
    }
    label_height_npc_value <- label_height_npc$npc
    label_height_inches <- label_height_npc$inches
    panel_height_inches <- label_height_npc$panel_height_inches

    if (is.null(panel_height_inches) || is.na(panel_height_inches)) {
      warning("panel_height_inches ikke tilgængelig - falder tilbage til NPC-baseret gap")
      label_height_is_list <- FALSE
      label_height_inches <- NA_real_
    }
  } else {
    label_height_npc_value <- label_height_npc
    label_height_inches <- NA_real_
    panel_height_inches <- NULL
  }

  # Helper: validate single NPC param
  validate_npc_param <- function(value, name, allow_na = TRUE) {
    if (is.null(value)) {
      return(invisible(NULL))
    }
    if (!is.numeric(value)) {
      stop(sprintf("%s skal være numerisk, modtog: %s", name, class(value)[1]))
    }
    if (length(value) != 1) {
      stop(sprintf("%s skal være en enkelt værdi, modtog: %d værdier", name, length(value)))
    }
    if (!allow_na && is.na(value)) {
      stop(sprintf("%s må ikke være NA", name))
    }
    if (!is.na(value) && !is.finite(value)) {
      stop(sprintf("%s skal være finite (ikke Inf/-Inf), modtog: %s", name, value))
    }
    invisible(NULL)
  }

  validate_npc_param(yA_npc, "yA_npc", allow_na = TRUE)
  validate_npc_param(yB_npc, "yB_npc", allow_na = TRUE)
  validate_npc_param(label_height_npc_value, "label_height_npc", allow_na = FALSE)
  validate_npc_param(gap_line, "gap_line", allow_na = FALSE)
  validate_npc_param(gap_labels, "gap_labels", allow_na = FALSE)
  validate_npc_param(pad_top, "pad_top", allow_na = FALSE)
  validate_npc_param(pad_bot, "pad_bot", allow_na = FALSE)

  if (!is.null(label_height_npc_value)) {
    if (label_height_npc_value <= 0) {
      stop("label_height_npc skal være positiv, modtog: ", label_height_npc_value)
    }
    if (label_height_npc_value > 0.5) {
      warning(sprintf(
        "Label optager %.0f%% af panel - degraded placement forventet",
        label_height_npc_value * 100
      ))
    }
  }

  if (!is.null(pad_top) && (pad_top < 0 || pad_top > 0.2)) {
    stop("pad_top skal være mellem 0 og 0.2, modtog: ", pad_top)
  }
  if (!is.null(pad_bot) && (pad_bot < 0 || pad_bot > 0.2)) {
    stop("pad_bot skal være mellem 0 og 0.2, modtog: ", pad_bot)
  }

  priority <- match.arg(priority, choices = c("A", "B"))

  if (!is.character(pref_pos) || length(pref_pos) == 0) {
    stop("pref_pos skal være en character vektor")
  }
  pref_pos <- rep_len(pref_pos, 2)
  if (!all(pref_pos %in% c("under", "over"))) {
    stop("pref_pos skal indeholde 'under' eller 'over', modtog: ", paste(pref_pos, collapse = ", "))
  }

  if (!is.logical(debug) || length(debug) != 1) {
    stop("debug skal være en enkelt logical værdi")
  }

  list(
    label_height_npc_value = label_height_npc_value,
    label_height_inches = label_height_inches,
    panel_height_inches = panel_height_inches,
    label_height_is_list = label_height_is_list,
    yA_npc = yA_npc,
    yB_npc = yB_npc,
    pref_pos = pref_pos,
    priority = priority
  )
}

#' Resolve config og beregn afledte gap-vaerdier
#'
#' Ren konfigurationsfunktion: loader label-placement-config og beregner
#' gap_line, gap_labels, pad_top, pad_bot baseret paa label dimensions.
#'
#' @return List med: gap_line, gap_labels, pad_top, pad_bot, cfg
#'
#' @keywords internal
#' @noRd
.resolve_placement_config <- function(
  label_height_npc_value,
  label_height_inches,
  panel_height_inches,
  label_height_is_list,
  gap_line,
  gap_labels,
  pad_top,
  pad_bot,
  debug = FALSE
) {
  default_cfg <- list(
    relative_gap_line = 0.08,
    relative_gap_labels = 0.30,
    pad_top = 0.01,
    pad_bot = 0.01,
    tight_lines_threshold_factor = LABEL_PLACEMENT_TIGHT_LINES_THRESHOLD_FACTOR,
    coincident_threshold_factor = LABEL_PLACEMENT_COINCIDENT_THRESHOLD_FACTOR,
    gap_reduction_factors = LABEL_PLACEMENT_GAP_REDUCTION_FACTORS,
    shelf_center_threshold = LABEL_PLACEMENT_SHELF_CENTER_THRESHOLD
  )
  cfg <- default_cfg
  loaded_cfg <- get_label_placement_config()
  if (!is.null(loaded_cfg)) {
    for (name in names(default_cfg)) {
      value <- loaded_cfg[[name]]
      if (!is.null(value)) cfg[[name]] <- value
    }
  }

  if (is.null(gap_line)) {
    if (label_height_is_list && !is.na(label_height_inches)) {
      gap_line_inches <- label_height_inches * cfg$relative_gap_line
      min_gap_inches <- 0.01
      gap_line_inches <- max(gap_line_inches, min_gap_inches)
      gap_line <- gap_line_inches / panel_height_inches
      if (debug) {
        message(sprintf(
          "[DEBUG] gap_line beregnet fra config (NY API): %.4f inches x %.2f = %.4f inches (min: %.2f) = %.4f NPC",
          label_height_inches, cfg$relative_gap_line, gap_line_inches, min_gap_inches, gap_line
        ))
      }
    } else {
      gap_line <- label_height_npc_value * cfg$relative_gap_line
      if (debug) {
        message(sprintf(
          "[DEBUG] gap_line beregnet fra config (LEGACY API): %.4f NPC x %.2f = %.4f NPC",
          label_height_npc_value, cfg$relative_gap_line, gap_line
        ))
      }
    }
  } else {
    if (debug) {
      message(sprintf("[DEBUG] gap_line var eksplicit sat til: %.4f NPC (config IKKE brugt)", gap_line))
    }
  }

  if (is.null(gap_labels)) {
    if (label_height_is_list && !is.na(label_height_inches)) {
      gap_labels_inches <- label_height_inches * cfg$relative_gap_labels
      gap_labels <- gap_labels_inches / panel_height_inches
    } else {
      gap_labels <- label_height_npc_value * cfg$relative_gap_labels
    }
  }

  if (is.null(pad_top)) pad_top <- cfg$pad_top
  if (is.null(pad_bot)) pad_bot <- cfg$pad_bot

  list(gap_line = gap_line, gap_labels = gap_labels, pad_top = pad_top, pad_bot = pad_bot, cfg = cfg)
}

#' Pure placement strategi: beregn endelige label-positioner
#'
#' Implementerer den fulde collision-avoidance algoritme som en ren funktion.
#' Ingen side effects, ingen device-kald, ingen config-lookup.
#'
#' @param yA_npc,yB_npc Linje-positioner (NPC, begge antages non-NA)
#' @param pref_pos Normaliseret c("under"/"over", "under"/"over")
#' @param label_height_npc_value Numerisk label hoejde (NPC)
#' @param gap_line Minimum gap fra label-kant til linje (NPC)
#' @param gap_labels Minimum gap mellem labels (NPC)
#' @param pad_top,pad_bot Panel padding (NPC)
#' @param priority "A" eller "B"
#' @param cfg Config-list med coincident_threshold_factor, tight_lines_threshold_factor,
#'   gap_reduction_factors, shelf_center_threshold
#'
#' @return List med: yA, yB, sideA, sideB, placement_quality, warnings
#'
#' @keywords internal
#' @noRd
.compute_placement_strategy <- function(
  yA_npc,
  yB_npc,
  pref_pos,
  label_height_npc_value,
  gap_line,
  gap_labels,
  pad_top,
  pad_bot,
  priority,
  cfg
) {
  warnings <- character(0)
  placement_quality <- "optimal"

  half <- label_height_npc_value / 2
  low_bound <- pad_bot + half
  high_bound <- 1 - pad_top - half

  line_gap_npc <- abs(yA_npc - yB_npc)
  min_center_gap <- label_height_npc_value + gap_labels
  tight_threshold_factor <- cfg$tight_lines_threshold_factor

  # Tight-lines strategy: flip pref_pos so one is over, one is under
  if (line_gap_npc < min_center_gap * tight_threshold_factor) {
    warnings <- c(warnings, paste0(
      "Linjer meget tætte (gap=", round(line_gap_npc, 3), ") - bruger over/under strategi"
    ))
    if (yA_npc > yB_npc) {
      pref_pos[1] <- "over"
      pref_pos[2] <- "under"
    } else {
      pref_pos[1] <- "under"
      pref_pos[2] <- "over"
    }
  }

  # Initial proposals
  propA <- propose_single_label(yA_npc, pref_pos[1], label_height_npc_value, gap_line, pad_top, pad_bot)
  propB <- propose_single_label(yB_npc, pref_pos[2], label_height_npc_value, gap_line, pad_top, pad_bot)
  yA <- propA$center
  yB <- propB$center
  sideA <- propA$side
  sideB <- propB$side

  # Coincident lines: place one over, one under
  coincident_threshold <- label_height_npc_value * cfg$coincident_threshold_factor
  if (abs(yA_npc - yB_npc) < coincident_threshold) {
    warnings <- c(warnings, "Sammenfaldende linjer - placerer labels over/under")
    if (pref_pos[1] == "under") {
      yA <- clamp_to_bounds(yA_npc - gap_line - half, low_bound, high_bound)
      yB <- clamp_to_bounds(yA_npc + gap_line + half, low_bound, high_bound)
      sideA <- "under"
      sideB <- "over"
    } else {
      yA <- clamp_to_bounds(yA_npc + gap_line + half, low_bound, high_bound)
      yB <- clamp_to_bounds(yA_npc - gap_line - half, low_bound, high_bound)
      sideA <- "over"
      sideB <- "under"
    }
    if (yA == low_bound || yA == high_bound || yB == low_bound || yB == high_bound) {
      warnings <- c(warnings, "Label(s) justeret til bounds")
      placement_quality <- "acceptable"
    }
    return(list(
      yA = yA, yB = yB, sideA = sideA, sideB = sideB,
      warnings = warnings, placement_quality = placement_quality
    ))
  }

  # Early exit: no collision
  if (abs(yA - yB) >= min_center_gap) {
    return(list(
      yA = yA, yB = yB, sideA = sideA, sideB = sideB,
      warnings = warnings, placement_quality = "optimal"
    ))
  }

  # Collision detected: push upper up or lower down
  warnings <- c(warnings, "Label kollision detekteret - justerer placering")
  if (yA_npc < yB_npc) {
    lower_y <- yA
    upper_y <- yB
    lower_is_A <- TRUE
  } else {
    lower_y <- yB
    upper_y <- yA
    lower_is_A <- FALSE
  }

  new_upper <- lower_y + min_center_gap
  if (new_upper <= high_bound) {
    upper_y <- new_upper
  } else {
    new_lower <- upper_y - min_center_gap
    if (new_lower >= low_bound) {
      lower_y <- new_lower
    } else {
      warnings <- c(warnings, "Umuligt at opfylde alle constraints - bruger shelf placement")
      placement_quality <- "suboptimal"
      if (priority == "A") {
        if (lower_is_A) {
          lower_y <- max(low_bound, min(propA$center, high_bound))
          upper_y <- high_bound
        } else {
          lower_y <- low_bound
          upper_y <- min(high_bound, max(propA$center, low_bound))
        }
      } else {
        if (lower_is_A) {
          lower_y <- low_bound
          upper_y <- min(high_bound, max(propB$center, low_bound))
        } else {
          lower_y <- max(low_bound, min(propB$center, high_bound))
          upper_y <- high_bound
        }
      }
    }
  }

  if (lower_is_A) {
    yA <- lower_y
    yB <- upper_y
  } else {
    yA <- upper_y
    yB <- lower_y
  }

  # Line-gap enforcement with multi-level fallback
  verifyA <- .verify_line_gap_npc(yA, yA_npc, sideA, label_height_npc_value, gap_line)
  verifyB <- .verify_line_gap_npc(yB, yB_npc, sideB, label_height_npc_value, gap_line)

  if (verifyA$violated || verifyB$violated) {
    proposed_yA <- if (verifyA$violated) verifyA$y else yA
    proposed_yB <- if (verifyB$violated) verifyB$y else yB

    if (abs(proposed_yA - proposed_yB) < min_center_gap) {
      warnings <- c(warnings, "Line-gap enforcement ville skabe collision - forsøger multi-level fallback")

      n1 <- .try_niveau_1_gap_reduction(
        proposed_yA, proposed_yB,
        label_height_npc_value, gap_labels,
        low_bound, high_bound,
        cfg$gap_reduction_factors
      )
      if (n1$success) {
        yA <- n1$yA
        yB <- n1$yB
        placement_quality <- n1$placement_quality
        warnings <- c(warnings, n1$warning)
      } else {
        warnings <- c(warnings, "NIVEAU 1 fejlede - forsøger NIVEAU 2: flip labels til modsatte side")
        n2 <- .try_niveau_2_flip(
          proposed_yA, proposed_yB,
          yA_npc, yB_npc,
          sideA, sideB,
          label_height_npc_value,
          gap_line, pad_top, pad_bot,
          low_bound, high_bound
        )
        if (n2$success) {
          yA <- n2$yA
          yB <- n2$yB
          sideA <- n2$sideA
          sideB <- n2$sideB
          placement_quality <- n2$placement_quality
          warnings <- c(warnings, n2$warning)
        } else {
          warnings <- c(warnings, "NIVEAU 2 fejlede - bruger NIVEAU 3: shelf placement")
          n3 <- .apply_niveau_3_shelf(
            proposed_yA, proposed_yB,
            low_bound, high_bound,
            priority, cfg$shelf_center_threshold
          )
          yA <- n3$yA
          yB <- n3$yB
          placement_quality <- n3$placement_quality
        }
      }
    } else {
      if (verifyA$violated) {
        warnings <- c(warnings, "Label A justeret for line-gap compliance")
        yA <- clamp_to_bounds(verifyA$y, low_bound, high_bound)
      }
      if (verifyB$violated) {
        warnings <- c(warnings, "Label B justeret for line-gap compliance")
        yB <- clamp_to_bounds(verifyB$y, low_bound, high_bound)
      }
    }
  }

  list(
    yA = yA, yB = yB, sideA = sideA, sideB = sideB,
    warnings = warnings, placement_quality = placement_quality
  )
}


# ==============================================================================
# LABEL PLACEMENT - CORE ALGORITHM
# ==============================================================================

#' Placer to labels ved horisontale linjer med collision avoidance
#'
#' Core placement algoritme med multi-level collision avoidance:
#' - NIVEAU 1: Reducer label gap (50% -> 30% -> 15%)
#' - NIVEAU 2: Flip labels til modsatte side (3 strategier)
#' - NIVEAU 3: Shelf placement (sidste udvej)
#'
#' @section NIVEAU 2 trigger-betingelser:
#' NIVEAU 2 (label-flip) aktiveres naar ALLE foelgende holder med default config
#' (`relative_gap_line=0.08`, `relative_gap_labels=0.30`,
#' `tight_threshold_factor=0.5`):
#'
#' 1. **Linjer er IKKE "tight"**:
#'    `abs(yA - yB) >= 0.5 * (label_height + gap_labels)` -- ellers flippes
#'    `pref_pos` automatisk til over/under-strategi (linje ~522).
#' 2. **Linjer er IKKE coincident**:
#'    `abs(yA - yB) >= 0.1 * label_height` -- ellers haandteres af coincident-
#'    grenen (linje ~551).
#' 3. **Initial proposals kolliderer**:
#'    `abs(propA - propB) < label_height + gap_labels`.
#' 4. **`pref_pos` matcher** (begge "under" eller begge "over") saa
#'    propA/propB faar samme retning fra deres respektive linjer.
#' 5. **Collision-resolution skubber labels saa line-gap-enforcement
#'    genskaber kollision**.
#' 6. **NIVEAU 1 reduktion (50/30/15%) kan ej lukke gap**.
#'
#' Konkret reproducerbart eksempel (NIVEAU 2b -- flip B):
#' ```
#' place_two_labels_npc(
#'   yA_npc = 0.30, yB_npc = 0.48,
#'   label_height_npc = 0.20,
#'   pref_pos = c("under", "under")
#' )
#' # placement_quality = "acceptable"
#' # warnings inkluderer: "NIVEAU 2b: Flippet label B til modsatte side"
#' ```
#'
#' @section NIVEAU 3 trigger-betingelser:
#' NIVEAU 3 (shelf placement) aktiveres naar NIVEAU 1 OG NIVEAU 2 begge fejler.
#' Dette kraever typisk **store labels relativt til linje-separation**, hvor
#' alle tre flip-strategier (flip A, flip B, flip begge) stadig giver overlap
#' (`abs(test_yA - test_yB) < label_height_npc`).
#'
#' Konkret reproducerbart eksempel (label optager 40% af panel):
#' ```
#' place_two_labels_npc(
#'   yA_npc = 0.20, yB_npc = 0.50,
#'   label_height_npc = 0.40,
#'   pref_pos = c("under", "under")
#' )
#' # placement_quality = "degraded"
#' # warnings inkluderer: "NIVEAU 3: shelf placement"
#' ```
#'
#' Bemaerk: NIVEAU 3 returnerer `placement_quality = "degraded"` -- kaldere
#' boer behandle dette som "best effort" og overveje at oege panel-hoejde
#' eller reducere label-stoerrelse.
#'
#' @param yA_npc Y-position for linje A i NPC (0-1)
#' @param yB_npc Y-position for linje B i NPC (0-1)
#' @param label_height_npc Label hoejde - enten:
#'   - Numerisk vaerdi i NPC (backward compatible)
#'   - List fra estimate_label_height_npc(..., return_details=TRUE) med $npc, $inches, $panel_height_inches
#' @param gap_line Min gap fra label edge til linje (default NULL = auto-beregn fra config)
#'   - Hvis label_height_npc er list: Beregnes som fast % af absolute hoejde (inches)
#'   - Hvis label_height_npc er numerisk: Beregnes som % af NPC (legacy)
#' @param gap_labels Min gap mellem labels (default NULL = auto-beregn fra config)
#' @param pad_top Top panel padding (default NULL = hent fra config)
#' @param pad_bot Bottom panel padding (default NULL = hent fra config)
#' @param priority Prioriteret label: "A" eller "B" (default "A")
#' @param pref_pos Foretrukne positioner: c("under"/"over", "under"/"over") (default c("under", "under"))
#' @param debug Returner debug info? (default FALSE)
#'
#' @return List med:
#'   - `yA`: NPC position for label A center
#'   - `yB`: NPC position for label B center
#'   - `sideA`: "over" eller "under"
#'   - `sideB`: "over" eller "under"
#'   - `placement_quality`: "optimal" / "acceptable" / "suboptimal" / "degraded" / "failed"
#'   - `warnings`: Character vector med warnings
#'   - `debug_info`: (kun hvis debug=TRUE)
#'
#' @keywords internal
#' @noRd
#' @examples
#' \dontrun{
#' # Basic usage (backward compatible - NPC-baseret gap)
#' result <- place_two_labels_npc(
#'   yA_npc = 0.4,
#'   yB_npc = 0.6,
#'   label_height_npc = 0.13
#' )
#'
#' # Ny API (fixed absolute gap baseret paa label inches)
#' height_details <- estimate_label_height_npc(
#'   "{.8 **CL**}  \n{.24 **45%**}",
#'   return_details = TRUE
#' )
#' result <- place_two_labels_npc(
#'   yA_npc = 0.4,
#'   yB_npc = 0.6,
#'   label_height_npc = height_details # List med npc/inches/panel_height
#' )
#' # Gap vil nu vaere fast % af label's faktiske hoejde
#'
#' # Coincident lines (target = CL)
#' result <- place_two_labels_npc(
#'   yA_npc = 0.5,
#'   yB_npc = 0.5, # Samme vaerdi
#'   label_height_npc = 0.13,
#'   pref_pos = c("under", "under")
#' )
#' # Result: sideA = "under", sideB = "over"
#' }
place_two_labels_npc <- function(
  yA_npc,
  yB_npc,
  label_height_npc = 0.114,
  gap_line = NULL,
  gap_labels = NULL,
  pad_top = NULL,
  pad_bot = NULL,
  priority = c("A", "B")[1],
  pref_pos = c("under", "under"),
  debug = FALSE
) {
  # Lag 1: validate + parse inputs
  parsed <- .validate_placement_inputs(
    yA_npc, yB_npc, label_height_npc,
    gap_line, gap_labels, pad_top, pad_bot,
    priority, pref_pos, debug
  )
  yA_npc <- parsed$yA_npc
  yB_npc <- parsed$yB_npc
  pref_pos <- parsed$pref_pos
  priority <- parsed$priority

  # Lag 1: resolve config + derived gaps
  resolved <- .resolve_placement_config(
    parsed$label_height_npc_value,
    parsed$label_height_inches,
    parsed$panel_height_inches,
    parsed$label_height_is_list,
    gap_line, gap_labels, pad_top, pad_bot,
    debug
  )
  gap_line <- resolved$gap_line
  gap_labels <- resolved$gap_labels
  pad_top <- resolved$pad_top
  pad_bot <- resolved$pad_bot
  cfg <- resolved$cfg
  label_height_npc_value <- parsed$label_height_npc_value

  warnings <- character(0)

  # Handle NA / out-of-bounds inputs before entering pure strategy
  if (is.na(yA_npc) && is.na(yB_npc)) {
    return(list(
      yA = NA_real_, yB = NA_real_,
      sideA = NA_character_, sideB = NA_character_,
      warnings = c(warnings, "Begge linjer er NA - ingen labels placeret"),
      placement_quality = "failed"
    ))
  }

  if (!is.na(yA_npc) && (yA_npc < 0 || yA_npc > 1)) {
    warnings <- c(warnings, paste0("Label A linje uden for panel (", round(yA_npc, 3), ")"))
    yA_npc <- NA_real_
  }
  if (!is.na(yB_npc) && (yB_npc < 0 || yB_npc > 1)) {
    warnings <- c(warnings, paste0("Label B linje uden for panel (", round(yB_npc, 3), ")"))
    yB_npc <- NA_real_
  }

  if (is.na(yA_npc) && is.na(yB_npc)) {
    return(list(
      yA = NA_real_, yB = NA_real_,
      sideA = NA_character_, sideB = NA_character_,
      warnings = c(warnings, "Begge linjer uden for panel - ingen labels placeret"),
      placement_quality = "failed"
    ))
  }

  # Single-label cases
  if (is.na(yA_npc) && !is.na(yB_npc)) {
    yB_res <- propose_single_label(yB_npc, pref_pos[2], label_height_npc_value, gap_line, pad_top, pad_bot)
    return(list(
      yA = NA_real_, yB = yB_res$center,
      sideA = NA_character_, sideB = yB_res$side,
      warnings = c(warnings, "Kun label B placeret"),
      placement_quality = "degraded"
    ))
  }
  if (is.na(yB_npc) && !is.na(yA_npc)) {
    yA_res <- propose_single_label(yA_npc, pref_pos[1], label_height_npc_value, gap_line, pad_top, pad_bot)
    return(list(
      yA = yA_res$center, yB = NA_real_,
      sideA = yA_res$side, sideB = NA_character_,
      warnings = c(warnings, "Kun label A placeret"),
      placement_quality = "degraded"
    ))
  }

  # Lag 2: pure placement strategy (begge linjer er valid)
  strat <- .compute_placement_strategy(
    yA_npc, yB_npc,
    pref_pos,
    label_height_npc_value,
    gap_line, gap_labels,
    pad_top, pad_bot,
    priority, cfg
  )

  result <- list(
    yA = strat$yA,
    yB = strat$yB,
    sideA = strat$sideA,
    sideB = strat$sideB,
    warnings = c(warnings, strat$warnings),
    placement_quality = strat$placement_quality
  )

  if (debug) {
    result$debug_info <- list(
      yA_npc = yA_npc,
      yB_npc = yB_npc,
      bounds = c(
        pad_bot + label_height_npc_value / 2,
        1 - pad_top - label_height_npc_value / 2
      )
    )
  }

  result
}
