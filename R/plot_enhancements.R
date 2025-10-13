#' Plot Enhancements
#'
#' Add extended lines and comment annotations to SPC plots.
#'
#' @name plot_enhancements
NULL

# ============================================================================
# PLOT ENHANCEMENTS
# ============================================================================

#' Add Extended Lines and Comments to SPC Plot
#'
#' Extends centerline and target lines 20% beyond the last data point
#' and adds comment annotations using ggrepel.
#'
#' @param plot ggplot object
#' @param qic_data QIC data frame
#' @param comment_data Comment data frame (from extract_comment_data())
#' @param colors Color palette (default: NULL, uses BFHtheme colors)
#' @param cl_linewidth Centerline width (default: 1)
#' @param target_linewidth Target line width (default: 1)
#' @param comment_size Comment text size (default: 6)
#' @param suppress_targetline Logical, suppress target line if arrow symbols present
#'
#' @return Modified ggplot object
#' @keywords internal
add_plot_enhancements <- function(plot,
                                  qic_data,
                                  comment_data = NULL,
                                  colors = NULL,
                                  cl_linewidth = 1,
                                  target_linewidth = 1,
                                  comment_size = 6,
                                  suppress_targetline = FALSE) {
  # Ensure colors are set (use BFHtheme defaults if NULL)
  colors <- ensure_color_names(colors)
  # Calculate extended x position (20% beyond last data point)
  last_x <- max(qic_data$x, na.rm = TRUE)
  first_x <- min(qic_data$x, na.rm = TRUE)

  # Handle Date objects
  if (inherits(last_x, "Date")) {
    last_x <- as.POSIXct(last_x)
    first_x <- as.POSIXct(first_x)
  }

  # Calculate 20% extension
  if (inherits(last_x, c("POSIXct", "POSIXt"))) {
    range_secs <- as.numeric(difftime(last_x, first_x, units = "secs"))
    extended_x <- last_x + range_secs * 0.20
  } else {
    x_range <- last_x - first_x
    extended_x <- last_x + (x_range * 0.20)
  }

  # Build extended line data using list then single bind
  extended_lines_list <- list()

  # Centerline extension (only for latest part)
  if (!is.null(qic_data$cl) && any(!is.na(qic_data$cl))) {
    latest_part <- max(qic_data$part, na.rm = TRUE)
    part_data <- qic_data[qic_data$part == latest_part & !is.na(qic_data$part), ]

    if (nrow(part_data) > 0) {
      last_row <- part_data[nrow(part_data), ]
      cl_value <- last_row$cl

      # Determine linetype based on Anhoej signal
      cl_linetype <- if ("anhoej.signal" %in% names(last_row) && isTRUE(last_row$anhoej.signal)) {
        "12"
      } else {
        "solid"
      }

      if (!is.na(cl_value)) {
        extended_lines_list$cl <- tibble::tibble(
          x = c(last_row$x, extended_x),
          y = c(cl_value, cl_value),
          type = "cl",
          linetype = cl_linetype
        )
      }
    }
  }

  # Target extension (only if not suppressed)
  if (!suppress_targetline && !is.null(qic_data$target) && any(!is.na(qic_data$target))) {
    target_value <- qic_data$target[!is.na(qic_data$target)][1]

    extended_lines_list$target <- tibble::tibble(
      x = c(last_x, extended_x),
      y = c(target_value, target_value),
      type = "target",
      linetype = "42"
    )
  }

  # Single bind operation - much more efficient
  extended_lines_data <- dplyr::bind_rows(extended_lines_list)

  # Add extended lines to plot
  if (nrow(extended_lines_data) > 0) {
    # CL extension
    if (any(extended_lines_data$type == "cl")) {
      cl_ext <- extended_lines_data[extended_lines_data$type == "cl", ]
      plot <- plot +
        ggplot2::geom_line(
          data = cl_ext,
          ggplot2::aes(x = x, y = y),
          color = colors$primary,
          linewidth = cl_linewidth,
          linetype = cl_ext$linetype[1],
          inherit.aes = FALSE
        )
    }

    # Target extension
    if (any(extended_lines_data$type == "target")) {
      target_ext <- extended_lines_data[extended_lines_data$type == "target", ]
      plot <- plot +
        ggplot2::geom_line(
          data = target_ext,
          ggplot2::aes(x = x, y = y),
          color = colors$darkgrey,
          linewidth = target_linewidth,
          linetype = "42",
          inherit.aes = FALSE
        )
    }
  }

  # Add comments
  if (!is.null(comment_data) && nrow(comment_data) > 0) {
    plot <- plot +
      ggrepel::geom_text_repel(
        data = comment_data,
        ggplot2::aes(x = x, y = y, label = comment),
        size = comment_size,
        color = colors$darkgrey,
        box.padding = 0.5,
        point.padding = 0.5,
        segment.color = colors$mediumgrey,
        segment.size = 0.3,
        arrow = grid::arrow(length = grid::unit(0.015, "npc")),
        max.overlaps = Inf,
        inherit.aes = FALSE
      )
  }

  return(plot)
}
