# utils_add_right_labels_marquee.R
# Core label placement function using NPC-based collision avoidance
#
# Extracted from bfh_layout_reference_dev.R POC

# Cache for resolved font family per device-type
# (systemfonts-registrering != PostScript font database)
.font_cache <- new.env(parent = emptyenv())

.resolve_font_family <- function(family = NULL) {
  # Detektér device-type: "cairo", "postscript" eller "other"
  dev_type <- tryCatch(
    {
      dev_name <- names(grDevices::dev.cur())
      if (is.null(dev_name) || dev_name == "null device") {
        "other"
      } else if (grepl("cairo", dev_name, ignore.case = TRUE)) {
        "cairo"
      } else if (grepl("pdf|postscript", dev_name, ignore.case = TRUE)) {
        "postscript"
      } else {
        "other"
      }
    },
    error = function(e) "other"
  )

  cache_key <- paste0("resolved_", dev_type)
  if (exists(cache_key, envir = .font_cache)) {
    return(.font_cache[[cache_key]])
  }

  resolved <- tryCatch(
    {
      f <- family %||% BFHtheme::theme_bfh()$text$family
      if (is.null(f) || length(f) == 0 || nchar(f) == 0) {
        "sans"
      } else if (dev_type == "postscript") {
        # PostScript/PDF devices har egen font-database - check der
        ps_fonts <- names(grDevices::pdfFonts())
        if (!f %in% ps_fonts) {
          warning(sprintf(
            "[FONT_FALLBACK] Font '%s' ikke i PostScript font database - bruger 'sans'",
            f
          ))
          "sans"
        } else {
          f
        }
      } else if (requireNamespace("systemfonts", quietly = TRUE)) {
        available <- unique(c(
          systemfonts::system_fonts()$family,
          systemfonts::registry_fonts()$family
        ))
        if (!f %in% available) {
          warning(sprintf(
            "[FONT_FALLBACK] Font '%s' ikke registreret på systemet - bruger 'sans'",
            f
          ))
          "sans"
        } else {
          f
        }
      } else {
        f
      }
    },
    error = function(e) "sans"
  )

  .font_cache[[cache_key]] <- resolved
  resolved
}

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
#' @param .built_plot Optional pre-built ggplot object (from ggplot_build). If provided,
#'   avoids redundant ggplot_build() call for performance (50-150ms improvement per plot)
#' @return ggplot object med marquee labels
#'
#' @details
#' Funktionen benytter `marquee::geom_marquee()` til to-linjers tekster og
#' forventer, at `get_label_placement_config()` er tilgængelig for at hente
#' cache'et placerings-setup. Hvis viewport-dimensioner (`viewport_width`,
#' `viewport_height`) gives, anvendes de til præcise grob-målinger; ellers falder
#' funktionen tilbage til aktivt grafisk device.
#'
#' @keywords internal
#' @noRd
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
    gpA = NULL,
    gpB = NULL,
    label_size = 6,
    viewport_width = NULL,
    viewport_height = NULL,
    verbose = TRUE,
    debug_mode = FALSE,
    .built_plot = NULL,
    .mapper = NULL) {
  # Resolve default farver i ét opslag (undgår gentagne bfh_cols-kald)
  if (is.null(gpA) || is.null(gpB)) {
    default_cols <- BFHtheme::bfh_cols(c("hospital_blue", "regionh_dark"))
    if (is.null(gpA)) {
      gpA <- grid::gpar(col = default_cols[[1]])
    }
    if (is.null(gpB)) {
      gpB <- grid::gpar(col = default_cols[[2]])
    }
  }

  # Beregn responsive størrelser baseret på label_size (baseline = 6)
  scale_factor <- label_size / 6

  # PERFORMANCE: Load config ÉN gang i starten
  placement_cfg <- list()
  config_available <- FALSE

  placement_cfg <- get_label_placement_config()
  config_available <- TRUE

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

  # PERFORMANCE: Use cached build if provided, otherwise build plot
  built_plot <- if (!is.null(.built_plot)) {
    .built_plot
  } else {
    ggplot2::ggplot_build(p)
  }

  # Gem device-state FØR ggplot_gtable (som kan åbne side-effect devices)
  pre_gtable_devs <- grDevices::dev.list()
  gtable <- ggplot2::ggplot_gtable(built_plot)

  # Luk evt. side-effect devices åbnet af ggplot_gtable
  post_gtable_devs <- grDevices::dev.list()
  leaked_devs <- setdiff(post_gtable_devs, pre_gtable_devs)
  if (length(leaked_devs) > 0) {
    on.exit(
      {
        for (dev_id in leaked_devs) {
          if (dev_id %in% grDevices::dev.list()) {
            tryCatch(grDevices::dev.off(dev_id), error = function(e) NULL)
          }
        }
      },
      add = TRUE
    )
  }

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
        message("[VIEWPORT_STRATEGY] Opening temporary Cairo PDF device for grob measurements")
      }
      temp_pdf <- tempfile(fileext = ".pdf")
      grDevices::cairo_pdf(filename = temp_pdf, width = viewport_width, height = viewport_height)
      temp_dev_num <- grDevices::dev.cur()
      temp_device_opened <- TRUE

      # on.exit lukker specifikt den device vi åbnede (ikke blot current device)
      on.exit(
        {
          if (temp_device_opened && temp_dev_num %in% grDevices::dev.list()) {
            tryCatch(grDevices::dev.off(temp_dev_num), error = function(e) NULL)
          }
          if (exists("temp_pdf")) unlink(temp_pdf, force = TRUE)
        },
        add = TRUE
      )
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
          device_height = device_size$height,
          device_ready = temp_device_opened
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
      return_details = TRUE,
      device_ready = temp_device_opened
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
  mapper <- if (!is.null(.mapper)) .mapper else npc_mapper_from_built(built_plot, original_plot = p)

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

  # Detektér om x-aksen er Date, POSIXct/datetime, eller numerisk
  # CRITICAL: Efter ggplot_build() er temporal værdier transformeret til plain numeric.
  # Vi skelner Date fra POSIXct for at undgå unødvendig POSIXct-coercion på Date-skalaer
  # (som kan introducere timezone/DST-forskydninger).
  x_is_date <- FALSE
  x_is_datetime <- FALSE
  x_scale <- NULL

  tryCatch(
    {
      x_scale <- built_plot$layout$panel_scales_x[[1]]

      if (!is.null(x_scale)) {
        scale_class <- class(x_scale)[1]
        trans_name <- if (!is.null(x_scale$trans)) x_scale$trans$name else ""

        # Date-skalaer: trans name er typisk "date" (uden "time")
        # Datetime-skalaer: trans name er typisk "time" eller "hms"
        if (grepl("^date$", tolower(trans_name)) ||
            (grepl("Date", scale_class) && !grepl("Time|time", scale_class))) {
          x_is_date <- TRUE
        } else if (grepl("time|hms", tolower(trans_name)) ||
                   grepl("Time", scale_class)) {
          x_is_datetime <- TRUE
        }
      }
    },
    error = function(e) {
      # Fallback: hvis scale detection fejler, antag numerisk
    }
  )

  if (x_is_date && !is.null(x_scale)) {
    # Date path: konvertér direkte til Date (ingen timezone involveret)
    if (!is.null(x_scale$trans) && !is.null(x_scale$trans$inverse)) {
      x_max <- x_scale$trans$inverse(x_max_value)
      if (!inherits(x_max, "Date")) {
        x_max <- as.Date(x_max, origin = "1970-01-01")
      }
    } else {
      x_max <- as.Date(x_max_value, origin = "1970-01-01")
    }
  } else if (x_is_datetime && !is.null(x_scale)) {
    # POSIXct path: brug scale's inverse transformation + timezone
    tz <- if (!is.null(x_scale$timezone)) x_scale$timezone else "UTC"

    if (!is.null(x_scale$trans) && !is.null(x_scale$trans$inverse)) {
      x_max <- x_scale$trans$inverse(x_max_value)
      x_max <- as.POSIXct(x_max, origin = "1970-01-01")
      attr(x_max, "tzone") <- tz
    } else {
      x_max <- as.POSIXct(x_max_value, origin = "1970-01-01", tz = tz)
    }
  } else {
    # Numerisk x-akse - brug værdi direkte
    x_max <- x_max_value
  }

  # Opret label data med korrekt x-type (matcher den detekterede scale)
  if (x_is_date) {
    label_data <- tibble::tibble(
      x = as.Date(character()),
      y = numeric(),
      label = character(),
      color = character()
    )
  } else if (x_is_datetime) {
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
    label_data <- label_data |>
      dplyr::bind_rows(tibble::tibble(
        x = x_max,
        y = yA_data,
        label = textA,
        color = color_A,
        vjust = 0.5
      ))
  }

  if (!is.na(yB_data)) {
    label_data <- label_data |>
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
    font_family <- .resolve_font_family()

    result <- result +
      marquee::geom_marquee(
        data = label_data,
        ggplot2::aes(x = x, y = y, label = label, color = color, vjust = vjust),
        hjust = 1,
        style = right_aligned_style,
        size = marquee_size,
        lineheight = marquee_lineheight,
        family = font_family,
        inherit.aes = FALSE
      )

    # marquee geom bruger color aesthetic — undgå duplicate scale warning
    has_colour_scale <- any(vapply(result$scales$scales, function(s) {
      "colour" %in% s$aesthetics
    }, logical(1)))
    if (!has_colour_scale) {
      result <- result + ggplot2::scale_color_identity()
    }
  }

  # Normal-path cleanup: luk specifik device og markér som lukket
  # (on.exit håndterer error-path; vi sætter flag til FALSE så on.exit er no-op)
  if (temp_device_opened && exists("temp_dev_num")) {
    if (temp_dev_num %in% grDevices::dev.list()) {
      tryCatch(grDevices::dev.off(temp_dev_num), error = function(e) NULL)
    }
    if (exists("temp_pdf")) unlink(temp_pdf, force = TRUE)
    temp_device_opened <- FALSE
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
