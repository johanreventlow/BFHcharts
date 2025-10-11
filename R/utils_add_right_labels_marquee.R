# utils_add_right_labels_marquee.R
# Core label placement function using NPC-based collision avoidance
#
# Extracted from bfh_layout_reference_dev.R POC

#' Add right-aligned marquee labels med NPC-baseret placering
#'
#' Anvender marquee::geom_marquee for at placere to-linje labels ved højre kant
#' med intelligent collision avoidance.
#'
#' @param p ggplot object
#' @param yA numeric(1) y-værdi (data units) for label A (CL)
#' @param yB numeric(1) y-værdi (data units) for label B (Target)
#' @param textA,textB character marquee markup strings
#' @param params list of placement parameters
#' @param gpA,gpB grid::gpar styling
#' @param label_size numeric label size for responsive sizing (default 6, legacy baseline)
#' @param viewport_width numeric viewport width in inches (optional, from clientData)
#' @param viewport_height numeric viewport height in inches (optional, from clientData)
#' @param verbose logical print placement warnings
#' @param debug_mode logical add visual debug annotations
#' @return ggplot object med marquee labels
#'
#' @export
add_right_labels_marquee <- function(
    p,
    yA,
    yB,
    textA,
    textB,
    params = list(
      label_height_npc = NULL, # Auto-beregnes
      gap_line = NULL, # Auto-beregnes
      gap_labels = NULL, # Auto-beregnes
      pad_top = 0.01,
      pad_bot = 0.01,
      pref_pos = c("under", "under"),
      priority = "A"
    ),
    gpA = grid::gpar(col = "#009CE8"),
    gpB = grid::gpar(col = "#565656"),
    label_size = 6,
    viewport_width = NULL,
    viewport_height = NULL,
    verbose = TRUE,
    debug_mode = FALSE) {
  # Beregn responsive størrelser baseret på label_size (baseline = 6)
  scale_factor <- label_size / 6

  # PERFORMANCE: Load config ÉN gang i starten
  placement_cfg <- list()
  config_available <- FALSE

  if (exists("get_label_placement_config", mode = "function")) {
    placement_cfg <- get_label_placement_config()
    config_available <- TRUE
  } else if (exists("get_label_placement_param", mode = "function")) {
    placement_cfg <- list(
      marquee_lineheight = get_label_placement_param("marquee_lineheight"),
      marquee_size_factor = get_label_placement_param("marquee_size_factor"),
      pad_top = get_label_placement_param("pad_top"),
      pad_bot = get_label_placement_param("pad_bot")
    )
    config_available <- TRUE
  }

  # Hent marquee_lineheight fra config
  marquee_lineheight <- if (config_available && !is.null(placement_cfg$marquee_lineheight)) {
    placement_cfg$marquee_lineheight
  } else {
    0.9
  }

  # PERFORMANCE: Hent cached right-aligned style
  right_aligned_style <- get_right_aligned_marquee_style(lineheight = marquee_lineheight)

  # Beregn marquee_size tidligt, så vi kan bruge den til målinger
  marquee_size_factor <- if (config_available && !is.null(placement_cfg$marquee_size_factor)) {
    placement_cfg$marquee_size_factor
  } else {
    6
  }
  marquee_size <- marquee_size_factor * scale_factor

  # PERFORMANCE: Build plot én gang
  built_plot <- ggplot2::ggplot_build(p)
  gtable <- ggplot2::ggplot_gtable(built_plot)

  # Detektér device størrelse for korrekt panel height measurement
  # STRATEGI:
  # 1. Hvis viewport dimensions provided → brug dem (åbn temporary device hvis nødvendigt)
  # 2. Ellers → detektér existing device (fallback for legacy callers)

  device_size <- NULL
  temp_device_opened <- FALSE

  if (!is.null(viewport_width) && !is.null(viewport_height)) {
    # STRATEGY 1: Viewport dimensions provided (PRIMARY PATH)
    if (verbose) {
      message(sprintf(
        "[VIEWPORT_STRATEGY] Using provided viewport dimensions: %.2f × %.2f inches",
        viewport_width, viewport_height
      ))
    }

    # Check if device is already open with correct dimensions
    device_already_open <- FALSE
    if (grDevices::dev.cur() > 1) {
      current_size <- grDevices::dev.size("in")
      # Allow 1% tolerance for dimension matching
      if (abs(current_size[1] - viewport_width) / viewport_width < 0.01 &&
        abs(current_size[2] - viewport_height) / viewport_height < 0.01) {
        device_already_open <- TRUE
        if (verbose) {
          message("[VIEWPORT_STRATEGY] Device already open with matching dimensions")
        }
      }
    }

    # Open temporary device if needed for grob measurements
    if (!device_already_open) {
      if (verbose) {
        message("[VIEWPORT_STRATEGY] Opening temporary PDF device for grob measurements")
      }
      grDevices::pdf(NULL, width = viewport_width, height = viewport_height)
      temp_device_opened <- TRUE
    }

    device_size <- list(
      width = viewport_width,
      height = viewport_height,
      actual = TRUE,
      source = "viewport"
    )
  } else {
    # STRATEGY 2: Fallback to existing device detection (LEGACY PATH)
    if (verbose) {
      message("[DEVICE_FALLBACK] No viewport dimensions - attempting device detection")
    }

    device_size <- tryCatch(
      {
        if (grDevices::dev.cur() > 1) {
          dev_inches <- grDevices::dev.size("in")
          list(
            width = dev_inches[1],
            height = dev_inches[2],
            actual = TRUE,
            source = "device"
          )
        } else {
          if (verbose) {
            warning(
              "[DEVICE_FALLBACK] No graphics device open - label measurements may be inaccurate"
            )
          }
          list(
            width = NA_real_,
            height = NA_real_,
            actual = FALSE,
            source = "none"
          )
        }
      },
      error = function(e) {
        warning(
          "[DEVICE_FALLBACK] Device size detection failed: ", e$message
        )
        list(
          width = NA_real_,
          height = NA_real_,
          actual = FALSE,
          source = "error"
        )
      }
    )
  }

  if (verbose) {
    if (device_size$actual) {
      message(sprintf(
        "Device size: %.2f × %.2f inches (ACTUAL measurements)",
        device_size$width, device_size$height
      ))
    } else {
      message("[DEVICE_SIZE] WARNING: No actual device size available - proceeding without measurements")
    }
  }

  # Mål panel højde med faktisk device størrelse (kun hvis device er klar)
  panel_height_inches <- NULL

  if (device_size$actual) {
    # Faktiske målinger tilgængelige - mål panel height
    panel_height_inches <- tryCatch(
      {
        measure_panel_height_from_gtable(
          gtable,
          device_width = device_size$width,
          device_height = device_size$height
        )
      },
      error = function(e) {
        if (verbose) {
          message("Panel height measurement failed: ", e$message)
        }
        NULL
      }
    )

    if (verbose && !is.null(panel_height_inches)) {
      message(sprintf(
        "Panel height: %.3f inches (measured from actual device)",
        panel_height_inches
      ))
    }
  } else {
    # Ingen faktiske device dimensioner - kan ikke måle panel height
    if (verbose) {
      message("[PANEL_HEIGHT] Cannot measure without actual device size - skipping measurement")
    }
  }

  # Auto-beregn label_height
  if (is.null(params$label_height_npc)) {
    # VIGTIGT: Hvis device ikke er klar (actual=FALSE), er estimater unøjagtige
    if (!device_size$actual && verbose) {
      warning(
        "[LABEL_HEIGHT] Estimating label heights without actual device measurements - ",
        "results may be inaccurate!"
      )
    }

    # Konverter NA til NULL for estimate_label_heights_npc's fallback mechanism
    # (fallbacks aktiveres kun ved NULL, ikke NA)
    device_width_for_estimate <- if (device_size$actual) device_size$width else NULL
    device_height_for_estimate <- if (device_size$actual) device_size$height else NULL

    heights <- estimate_label_heights_npc(
      texts = c(textA, textB),
      style = right_aligned_style,
      panel_height_inches = panel_height_inches,
      device_width = device_width_for_estimate,
      device_height = device_height_for_estimate,
      marquee_size = marquee_size,
      return_details = TRUE
    )
    height_A <- heights[[1]]
    height_B <- heights[[2]]

    # FIX: Ignorer empty labels ved valg af højde til gap calculation
    # Hvis textB er tom (kun CL label), brug kun height_A
    # Dette sikrer at gap er baseret på faktisk synlig label højde
    textA_is_empty <- is.null(textA) || nchar(trimws(textA)) == 0
    textB_is_empty <- is.null(textB) || nchar(trimws(textB)) == 0

    if (textA_is_empty && textB_is_empty) {
      # Ingen labels - brug fallback
      params$label_height_npc <- height_A
    } else if (textB_is_empty) {
      # Kun textA - brug height_A uanset størrelse
      params$label_height_npc <- height_A
    } else if (textA_is_empty) {
      # Kun textB - brug height_B uanset størrelse
      params$label_height_npc <- height_B
    } else {
      # Begge labels - brug max
      if (height_A$npc > height_B$npc) {
        params$label_height_npc <- height_A
      } else {
        params$label_height_npc <- height_B
      }
    }

    if (verbose) {
      message(
        "Auto-beregnet label_height_npc: ", round(params$label_height_npc$npc, 4),
        " (A: ", round(height_A$npc, 4), ", B: ", round(height_B$npc, 4), ")",
        " [", round(params$label_height_npc$inches, 4), " inches]",
        if (textA_is_empty) " [A tom]" else "",
        if (textB_is_empty) " [B tom]" else ""
      )
    }
  }

  # Default parameters
  if (is.null(params$pad_top)) {
    if (config_available && !is.null(placement_cfg$pad_top)) {
      params$pad_top <- placement_cfg$pad_top
    } else {
      params$pad_top <- 0.01
    }
  }

  if (is.null(params$pad_bot)) {
    if (config_available && !is.null(placement_cfg$pad_bot)) {
      params$pad_bot <- placement_cfg$pad_bot
    } else {
      params$pad_bot <- 0.01
    }
  }

  if (is.null(params$pref_pos)) params$pref_pos <- c("under", "under")
  if (is.null(params$priority)) params$priority <- "A"

  # Build mapper
  mapper <- npc_mapper_from_built(built_plot, original_plot = p)

  # Konverter y-værdier til NPC
  yA_npc <- if (!is.na(yA)) mapper$y_to_npc(yA) else NA_real_
  yB_npc <- if (!is.na(yB)) mapper$y_to_npc(yB) else NA_real_

  # Compute placement
  placement <- place_two_labels_npc(
    yA_npc = yA_npc,
    yB_npc = yB_npc,
    label_height_npc = params$label_height_npc,
    gap_line = params$gap_line,
    gap_labels = params$gap_labels,
    pad_top = params$pad_top,
    pad_bot = params$pad_bot,
    priority = params$priority,
    pref_pos = params$pref_pos,
    debug = debug_mode
  )

  # Print warnings
  if (verbose && length(placement$warnings) > 0) {
    message("Label placement warnings:")
    for (w in placement$warnings) {
      message("  - ", w)
    }
    message("Placement quality: ", placement$placement_quality)
  }

  # Konverter NPC positions til data coordinates
  if (!is.na(placement$yA)) {
    yA_data <- mapper$npc_to_y(placement$yA)
  } else {
    yA_data <- NA_real_
  }

  if (!is.na(placement$yB)) {
    yB_data <- mapper$npc_to_y(placement$yB)
  } else {
    yB_data <- NA_real_
  }

  # Hent x-koordinater og detektér type
  x_range <- built_plot$layout$panel_params[[1]]$x.range
  x_max_value <- x_range[2]

  # FIX: Detektér om x-aksen er Date/POSIXct eller numerisk
  # PROBLEM: Tvungen POSIXct konvertering bryder numeriske x-akser
  # hvor værdier bliver fortolket som sekunder siden 1970
  x_is_temporal <- FALSE
  tryCatch(
    {
      # Check x.range class direkte
      if (inherits(x_max_value, c("POSIXct", "POSIXt", "Date"))) {
        x_is_temporal <- TRUE
      }
      # Alternativ: check scale transformation
      if (!x_is_temporal && !is.null(built_plot$layout$panel_params[[1]]$x.sec.range)) {
        # Secondary axis antyder temporal data
        x_is_temporal <- TRUE
      }
    },
    error = function(e) {
      # Fallback: hvis type detection fejler, brug værdien direkte (numerisk)
      x_is_temporal <- FALSE
    }
  )

  if (x_is_temporal) {
    x_max <- as.POSIXct(x_max_value, origin = "1970-01-01", tz = "UTC")
  } else {
    # Numerisk x-akse - brug værdi direkte
    x_max <- x_max_value
  }

  # Opret label data med korrekt x-type
  if (x_is_temporal) {
    label_data <- tibble::tibble(
      x = as.POSIXct(character()),
      y = numeric(),
      label = character(),
      color = character()
    )
  } else {
    label_data <- tibble::tibble(
      x = numeric(),
      y = numeric(),
      label = character(),
      color = character()
    )
  }

  color_A <- if (!is.null(gpA$col)) gpA$col else "#009CE8"
  color_B <- if (!is.null(gpB$col)) gpB$col else "#565656"

  if (!is.na(yA_data)) {
    label_data <- label_data %>%
      dplyr::bind_rows(tibble::tibble(
        x = x_max,
        y = yA_data,
        label = textA,
        color = color_A,
        vjust = 0.5
      ))
  }

  if (!is.na(yB_data)) {
    label_data <- label_data %>%
      dplyr::bind_rows(tibble::tibble(
        x = x_max,
        y = yB_data,
        label = textB,
        color = color_B,
        vjust = 0.5
      ))
  }

  # Tilføj labels (marquee_size already calculated above)
  result <- p
  if (nrow(label_data) > 0) {
    result <- result +
      marquee::geom_marquee(
        data = label_data,
        ggplot2::aes(x = x, y = y, label = label, color = color, vjust = vjust),
        hjust = 1,
        style = right_aligned_style,
        size = marquee_size,
        lineheight = marquee_lineheight,
        family = "Roboto Medium",
        inherit.aes = FALSE
      ) +
      ggplot2::scale_color_identity()
  }

  # Cleanup temporary device if opened
  if (temp_device_opened) {
    if (verbose) {
      message("[VIEWPORT_STRATEGY] Closing temporary device")
    }
    grDevices::dev.off()
  }

  # Attach metadata
  attr(result, "placement_info") <- placement
  attr(result, "mapper_info") <- list(
    limits = mapper$limits,
    trans_name = mapper$trans_name,
    device_source = device_size$source
  )

  result
}
