# ==============================================================================
# PANEL MEASUREMENT
# ==============================================================================


#' Mål panel højde fra gtable
#'
#' Kernefunktion der måler panel højde fra en pre-built gtable.
#' Bruges direkte af add_right_labels_marquee() med en allerede bygget gtable.
#'
#' @keywords internal
#' @noRd
measure_panel_height_from_gtable <- function(gt, panel = 1, device_width = 7, device_height = 7,
                                             device_ready = FALSE) {
  # Find panel viewport navn fra gtable layout
  panel_layout <- gt$layout[gt$layout$name == "panel", , drop = FALSE]

  if (nrow(panel_layout) == 0) {
    stop("Kunne ikke finde panel i plot layout")
  }

  if (panel > nrow(panel_layout)) {
    stop(sprintf("Panel %d findes ikke (plot har %d panels)", panel, nrow(panel_layout)))
  }

  # Construct panel viewport navn (typisk format: "panel.t-l-b-r")
  panel_row <- panel_layout[panel, , drop = FALSE]
  panel_vp_name <- sprintf(
    "panel.%s-%s-%s-%s",
    panel_row$t, panel_row$l,
    panel_row$b, panel_row$r
  )

  # Hvis device_ready = TRUE, brug allerede-aktiv device (caller har åbnet den)
  # Ellers åbn en off-screen Cairo PDF device for measurements
  if (!device_ready) {
    # Gem den nuværende device
    current_dev <- grDevices::dev.cur()

    temp_file <- tempfile(fileext = ".pdf")
    grDevices::cairo_pdf(filename = temp_file, width = device_width, height = device_height)
    temp_dev <- grDevices::dev.cur()

    on.exit(
      {
        # Luk vores temp device hvis den stadig er aktiv
        if (grDevices::dev.cur() == temp_dev) {
          grDevices::dev.off()
        }

        # Vend tilbage til oprindelig device hvis den var reel
        if (current_dev > 1 && current_dev != temp_dev) {
          if (current_dev %in% grDevices::dev.list()) {
            tryCatch(
              {
                grDevices::dev.set(current_dev)
              },
              error = function(e) {
                # Ignorer hvis device ikke findes
              }
            )
          }
        }

        # Slet temp fil
        unlink(temp_file, force = TRUE)
      },
      add = TRUE
    )
  }

  # Render plot til device
  grid::grid.newpage()
  grid::grid.draw(gt)

  # Force all grobs to be evaluated
  grid::grid.force()

  # Navigate til panel viewport
  # NOTE: seekViewport() finder viewport i hele tree
  tryCatch(
    {
      grid::seekViewport(panel_vp_name)
    },
    error = function(e) {
      # Fallback: prøv generisk "panel" navn
      grid::seekViewport("panel")
    }
  )

  # Mål højde i current (panel) viewport
  panel_height <- grid::convertHeight(
    grid::unit(1, "npc"),
    "inches",
    valueOnly = TRUE
  )

  # Navigate tilbage til ROOT
  grid::upViewport(0)

  return(panel_height)
}

#' INTERN: Mål label højde med aktiv device (ingen device management)
#'
#' Forventer at en graphics device allerede er åben.
#'
#' @keywords internal
#' @noRd
.estimate_label_height_npc_internal <- function(
  text,
  style,
  panel_height_inches = NULL,
  device_width = NULL,
  device_height = NULL,
  marquee_size = NULL,
  fallback_npc = 0.13,
  return_details = FALSE
) {
  # Create grob and measure (assumes active device exists)
  # FIX: Apply marquee_size scaling to style if provided
  # marquee_grob uses style-based sizing, not explicit size parameter
  if (!is.null(marquee_size)) {
    # Scale all font sizes in style by marquee_size / default_size ratio
    # Default geom_marquee size is approximately 6, so we scale from that baseline
    size_scale <- marquee_size / 6

    # Modify style to apply size scaling
    # We need to scale all font-related attributes
    style <- marquee::modify_style(
      style,
      "body",
      size = marquee_size # This should set the base font size
    )
  }

  g <- marquee::marquee_grob(
    text = text,
    x = 0.5,
    y = 0.5,
    style = style
  )

  # FIX (#93): Sikr at h_native ALTID er defineret, selv ved dobbelt-fejl.
  # Marquee grobs bruger lazy evaluation - makeContent forcerer rendering.
  h_native <- tryCatch(
    {
      g_rendered <- grid::makeContent(g)
      grid::grobHeight(g_rendered)
    },
    error = function(e) {
      # Fallback til direkte måling hvis makeContent fejler
      tryCatch(
        grid::grobHeight(g),
        error = function(e2) {
          # Dobbelt-fejl: returner fallback som grid unit
          grid::unit(fallback_npc, "npc")
        }
      )
    }
  )

  # Convert to NPC
  if (!is.null(panel_height_inches)) {
    h_inches <- grid::convertHeight(h_native, "inches", valueOnly = TRUE)
    h_npc <- h_inches / panel_height_inches
  } else {
    h_npc <- grid::convertHeight(h_native, "npc", valueOnly = TRUE)
    h_inches <- grid::convertHeight(h_native, "inches", valueOnly = TRUE)
    # message(sprintf(
  }

  # Safety margin fra config (altid tilgængelig i pakken)
  cfg <- get_label_placement_config()
  value <- cfg[["height_safety_margin"]]
  safety_margin <- if (is.null(value)) 1.05 else value
  h_npc <- h_npc * safety_margin
  h_inches_with_margin <- h_inches * safety_margin

  # Validation
  if (!is.finite(h_npc) || h_npc <= 0) {
    # Silently use fallback when grob measurement fails
    # This can happen with empty labels or certain edge cases
    if (return_details) {
      return(list(
        npc = fallback_npc,
        inches = NA_real_,
        panel_height_inches = panel_height_inches
      ))
    }
    return(fallback_npc)
  }

  # Warn if very large
  if (h_npc > 0.5 && !is.null(panel_height_inches)) {
    warning(
      sprintf(
        "Label optager %.1f%% af panel højde (%.2f inches). ",
        h_npc * 100, panel_height_inches
      )
    )
  }

  # Prepare result
  if (return_details) {
    result <- list(
      npc = as.numeric(h_npc),
      inches = as.numeric(h_inches_with_margin),
      panel_height_inches = panel_height_inches
    )
  } else {
    result <- as.numeric(h_npc)
  }

  return(result)
}
