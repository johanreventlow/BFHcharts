#' Plot Enhancements
#'
#' Add extended lines and comment annotations to SPC plots.
#'
#' @name plot_enhancements
#' @keywords internal
#' @noRd
NULL

# ============================================================================
# PLOT ENHANCEMENTS
# ============================================================================

#' Add Extended Lines and Comments to SPC Plot
#'
#' Extends centerline and target lines 20% beyond the last data point
#' and adds comment annotations with line-aware placement.
#'
#' @param plot ggplot object
#' @param qic_data QIC data frame
#' @param comment_data Comment data frame (from extract_comment_data())
#' @param cl_linewidth Centerline width (default: 1)
#' @param target_linewidth Target line width (default: 1)
#' @param comment_size Comment text size (default: 6)
#' @param suppress_targetline Logical, suppress target line if arrow symbols present
#'
#' @return Modified ggplot object
#' @keywords internal
#' @noRd
add_plot_enhancements <- function(plot,
                                  qic_data,
                                  comment_data = NULL,
                                  cl_linewidth = 1,
                                  target_linewidth = 1,
                                  comment_size = 6,
                                  suppress_targetline = FALSE,
                                  line_positions = NULL) {
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
          color = BFHtheme::bfh_cols("hospital_blue"),
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
          color = BFHtheme::bfh_cols("hospital_dark_grey"),
          linewidth = target_linewidth,
          linetype = "42",
          inherit.aes = FALSE
        )
    }
  }

  # Add comments med intelligent placement
  if (!is.null(comment_data) && nrow(comment_data) > 0) {
    # Beregn y_range og x_range fra data
    y_vals <- qic_data$y[!is.na(qic_data$y)]
    all_y <- c(y_vals, qic_data$ucl, qic_data$lcl)
    all_y <- all_y[!is.na(all_y)]
    y_range <- range(all_y)
    x_range <- range(qic_data$x, na.rm = TRUE)

    # Konverter x_range til numerisk for placement (håndter Date/POSIXct)
    if (inherits(x_range, c("Date", "POSIXct", "POSIXt"))) {
      x_range_num <- as.numeric(x_range)
      comment_data_num <- comment_data
      comment_data_num$x <- as.numeric(comment_data$x)
    } else {
      x_range_num <- x_range
      comment_data_num <- comment_data
    }

    # Forbered datapunkter for processlinje-undgåelse
    data_points_num <- data.frame(
      x = if (inherits(qic_data$x, c("Date", "POSIXct", "POSIXt"))) {
        as.numeric(qic_data$x)
      } else {
        qic_data$x
      },
      y = qic_data$y,
      stringsAsFactors = FALSE
    )

    # Placer labels
    label_data <- place_note_labels(
      comment_data = comment_data_num,
      line_positions = if (!is.null(line_positions)) line_positions else numeric(0),
      y_range = y_range,
      x_range = x_range_num,
      data_points = data_points_num
    )

    if (nrow(label_data) > 0) {
      # Helper: konverter numerisk x tilbage til original type (Date/POSIXct)
      tz <- if (inherits(x_range, c("POSIXct", "POSIXt"))) {
        attr(x_range, "tzone") %||% "UTC"
      } else {
        "UTC"
      }
      restore_x <- function(values) {
        if (inherits(x_range, "Date")) as.Date(values, origin = "1970-01-01")
        else if (inherits(x_range, c("POSIXct", "POSIXt"))) as.POSIXct(values, origin = "1970-01-01", tz = tz)
        else values
      }

      label_data$label_x <- restore_x(label_data$label_x)
      label_data$point_x <- restore_x(label_data$point_x)
      label_data$arrow_x <- restore_x(label_data$arrow_x)

      arrow_data <- label_data[label_data$draw_arrow, ]
      if (nrow(arrow_data) > 0) {
        # Forkort pilens endpoint med fast afstand (3% af plottet) fra datapunktet
        x_span <- diff(as.numeric(x_range))
        y_span_arrow <- diff(y_range)
        pad_norm <- 0.03

        for (r in seq_len(nrow(arrow_data))) {
          dx_norm <- (as.numeric(arrow_data$point_x[r]) - as.numeric(arrow_data$arrow_x[r])) / x_span
          dy_norm <- (arrow_data$point_y[r] - arrow_data$arrow_y[r]) / y_span_arrow
          seg_len_norm <- sqrt(dx_norm^2 + dy_norm^2)
          if (seg_len_norm > 1e-10) {
            shrink <- min(pad_norm / seg_len_norm, 0.4)
            arrow_data$end_x[r] <- as.numeric(arrow_data$point_x[r]) - shrink * (as.numeric(arrow_data$point_x[r]) - as.numeric(arrow_data$arrow_x[r]))
            arrow_data$end_y[r] <- arrow_data$point_y[r] - shrink * (arrow_data$point_y[r] - arrow_data$arrow_y[r])
          } else {
            arrow_data$end_x[r] <- as.numeric(arrow_data$point_x[r])
            arrow_data$end_y[r] <- arrow_data$point_y[r]
          }
        }

        arrow_data$end_x <- restore_x(arrow_data$end_x)

        plot <- plot +
          ggplot2::geom_segment(
            data = arrow_data,
            ggplot2::aes(
              x = arrow_x, y = arrow_y,
              xend = end_x, yend = end_y
            ),
            colour = BFHtheme::bfh_cols("hospital_grey"),
            linewidth = 0.3,
            arrow = grid::arrow(length = grid::unit(1.5, "mm"), type = "closed"),
            inherit.aes = FALSE
          )
      }

      # Tegn labels
      plot <- plot +
        ggplot2::geom_text(
          data = label_data,
          ggplot2::aes(x = label_x, y = label_y, label = label_text),
          size = comment_size,
          colour = BFHtheme::bfh_cols("hospital_dark_grey"),
          lineheight = 0.9,
          inherit.aes = FALSE
        )
    }
  }

  return(plot)
}
