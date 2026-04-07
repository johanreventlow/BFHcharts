# ==============================================================================
# UTILS_NOTE_PLACEMENT.R
# ==============================================================================
# FORMÅL: Deterministisk label placement for SPC chart noter.
#         Placerer labels ved datapunkter og undgår horisontale linjer
#         (CL, UCL, LCL, target), proceslinjen (geom_line mellem punkter),
#         datapunkter, og andre labels.
#
#         VIGTIGT: Al scoring sker i normaliseret [0,1] space for at
#         håndtere vidt forskellige skalaer på x- og y-aksen
#         (f.eks. POSIXct sekunder vs. procent-brøker).
#
# ANVENDES AF:
#   - plot_enhancements.R (comment rendering)
#
# RELATERET:
#   - config_label_placement.R (parametre)
#   - utils_helpers.R (extract_comment_data)
# ==============================================================================

#' Placer note-labels med intelligent collision avoidance
#'
#' Beregner optimale positioner for note-labels der undgår horisontale
#' referencelinjer (CL, UCL, LCL, target), proceslinjen mellem datapunkter,
#' selve datapunkterne, og andre allerede placerede labels.
#'
#' Al scoring sker i normaliseret [0,1] space for at håndtere
#' forskellige skalaer (f.eks. Date/POSIXct vs. procent).
#'
#' @param comment_data data.frame med x, y, comment kolonner
#' @param line_positions named numeric vector med y-værdier for linjer (kan indeholde NA)
#' @param y_range numeric(2) plot y-range
#' @param x_range numeric(2) plot x-range
#' @param data_points data.frame med x, y for alle datapunkter
#' @param config list med placement parametre (fra get_label_placement_config())
#' @return data.frame med label_x, label_y, point_x, point_y, label_text, draw_arrow
#'
#' @keywords internal
#' @noRd
place_note_labels <- function(comment_data,
                              line_positions,
                              y_range,
                              x_range,
                              data_points = NULL,
                              config = NULL) {
  empty_result <- data.frame(
    label_x = numeric(0),
    label_y = numeric(0),
    arrow_x = numeric(0),
    arrow_y = numeric(0),
    point_x = numeric(0),
    point_y = numeric(0),
    label_text = character(0),
    draw_arrow = logical(0),
    curvature = numeric(0),
    stringsAsFactors = FALSE
  )

  if (is.null(comment_data) || nrow(comment_data) == 0) {
    return(empty_result)
  }

  # Hent config
  if (is.null(config)) {
    config <- get_label_placement_config()
  }

  # Normaliserings-funktioner: data coords -> [0,1]
  # Guard: y_span/x_span kan være 0 hvis alle værdier er ens → undgå division med nul
  y_span <- diff(y_range)
  x_span <- diff(x_range)
  if (!is.finite(y_span) || y_span == 0) return(empty_result)
  if (!is.finite(x_span) || x_span == 0) return(empty_result)
  norm_x <- function(x) (x - x_range[1]) / x_span
  norm_y <- function(y) (y - y_range[1]) / y_span
  denorm_x <- function(nx) nx * x_span + x_range[1]
  denorm_y <- function(ny) ny * y_span + y_range[1]

  # Normaliser line_positions til [0,1]
  line_y_norm <- norm_y(line_positions[!is.na(line_positions)])

  # Normaliser data_points
  segments_norm <- NULL
  data_points_norm <- NULL
  if (!is.null(data_points) && nrow(data_points) > 0) {
    data_points_norm <- data.frame(
      x = norm_x(data_points$x),
      y = norm_y(data_points$y),
      stringsAsFactors = FALSE
    )
    data_points_norm <- data_points_norm[!is.na(data_points_norm$x) & !is.na(data_points_norm$y), ]

    # Byg segmenter i normaliseret space
    if (nrow(data_points_norm) >= 2) {
      dp <- data_points_norm[order(data_points_norm$x), ]
      n <- nrow(dp)
      segments_norm <- data.frame(
        x1 = dp$x[-n], y1 = dp$y[-n],
        x2 = dp$x[-1], y2 = dp$y[-1],
        stringsAsFactors = FALSE
      )
    }
  }

  offset <- config$note_label_offset_factor
  buffer <- config$note_line_buffer_factor

  placed_labels <- list()
  results <- vector("list", nrow(comment_data))

  for (i in seq_len(nrow(comment_data))) {
    row <- comment_data[i, ]
    px_data <- row$x
    py_data <- row$y
    px <- norm_x(px_data)
    py <- norm_y(py_data)

    wrapped_text <- stringr::str_wrap(row$comment, width = config$note_max_label_width)
    bbox <- estimate_label_bbox_norm(
      wrapped_text,
      config$note_char_width_factor,
      config$note_line_height_factor
    )

    candidates <- generate_candidates_norm(px, py, offset)

    best_score <- Inf
    best_candidate <- candidates[[1]]

    all_scores <- numeric(length(candidates))
    for (ci in seq_along(candidates)) {
      candidate <- candidates[[ci]]
      score <- score_candidate_norm(
        cx = candidate$x,
        cy = candidate$y,
        bbox = bbox,
        line_y_norm = line_y_norm,
        segments_norm = segments_norm,
        data_points_norm = data_points_norm,
        placed_labels = placed_labels,
        point_x = px,
        point_y = py,
        buffer = buffer,
        config = config
      )
      all_scores[ci] <- score

      if (score < best_score) {
        best_score <- score
        best_candidate <- candidate
      }
    }

    # Konverter bedste position tilbage til data coords
    label_x_data <- denorm_x(best_candidate$x)
    label_y_data <- denorm_y(best_candidate$y)

    # Arrow: beregn startpunkt på label-kant (ikke center)
    dist_norm <- sqrt((best_candidate$x - px)^2 + (best_candidate$y - py)^2)
    draw_arrow <- dist_norm > 0.02

    # Beregn pilens startpunkt: skæring mellem linje (center->punkt) og label-boks
    arrow_start <- compute_arrow_start(
      best_candidate$x, best_candidate$y, bbox, px, py
    )
    arrow_x_data <- denorm_x(arrow_start$x)
    arrow_y_data <- denorm_y(arrow_start$y)

    # Buet pil hvis label er forskudt horisontalt (ikke direkte over/under)
    dx_norm <- best_candidate$x - px
    dy_norm <- best_candidate$y - py
    is_diagonal <- abs(dx_norm) > 0.01
    if (is_diagonal) {
      # Buen skal bue væk fra datapunktet:
      # - Label over+højre: bue nedad (positiv curvature)
      # - Label over+venstre: bue nedad (negativ curvature)
      # - Label under+højre: bue opad (negativ curvature)
      # - Label under+venstre: bue opad (positiv curvature)
      # geom_curve: positiv curvature buer til højre set fra start→end
      curvature <- if ((dx_norm > 0) == (dy_norm > 0)) -0.25 else 0.25
    } else {
      curvature <- 0
    }

    placed_labels[[i]] <- list(x = best_candidate$x, y = best_candidate$y, bbox = bbox)

    results[[i]] <- data.frame(
      label_x = label_x_data,
      label_y = label_y_data,
      arrow_x = arrow_x_data,
      arrow_y = arrow_y_data,
      point_x = px_data,
      point_y = py_data,
      label_text = wrapped_text,
      draw_arrow = draw_arrow,
      curvature = curvature,
      stringsAsFactors = FALSE
    )
  }

  dplyr::bind_rows(results)
}


#' Generer 8 kandidatpositioner i normaliseret [0,1] space
#'
#' @keywords internal
#' @noRd
generate_candidates_norm <- function(px, py, offset) {
  x_off <- offset * 0.5
  off2 <- offset * 1.8
  off3 <- offset * 2.5  # Meget langt væk - sikrer altid en overlap-fri mulighed

  # Alle kandidater har vertikal komponent - undgår at pilen krydser teksten
  list(
    list(x = px, y = py + offset),                  # 1. Over
    list(x = px, y = py - offset),                  # 2. Under
    list(x = px + x_off, y = py + offset),          # 3. Over-højre
    list(x = px + x_off, y = py - offset),          # 4. Under-højre
    list(x = px - x_off, y = py + offset),          # 5. Over-venstre
    list(x = px - x_off, y = py - offset),          # 6. Under-venstre
    list(x = px + x_off, y = py + offset * 0.7),    # 7. Skråt højre-op
    list(x = px - x_off, y = py - offset * 0.7),    # 8. Skråt venstre-ned
    list(x = px + x_off * 1.3, y = py + offset * 0.7),  # 9. Skråt højre-op (længere)
    list(x = px - x_off * 1.3, y = py - offset * 0.7),  # 10. Skråt venstre-ned (længere)
    list(x = px, y = py + off2),                    # 11. Langt over
    list(x = px, y = py - off2),                    # 12. Langt under
    list(x = px + x_off, y = py + off2),            # 13. Langt over-højre
    list(x = px + x_off, y = py - off2),            # 14. Langt under-højre
    list(x = px - x_off, y = py + off2),            # 15. Langt over-venstre
    list(x = px - x_off, y = py - off2),            # 16. Langt under-venstre
    list(x = px, y = py + off3),                    # 17. Meget langt over
    list(x = px, y = py - off3),                    # 18. Meget langt under
    list(x = px + x_off, y = py + off3),            # 19. Meget langt over-højre
    list(x = px - x_off, y = py - off3)             # 20. Meget langt under-venstre
  )
}


#' Scor en kandidatposition i normaliseret [0,1] space
#'
#' @keywords internal
#' @noRd
score_candidate_norm <- function(cx, cy, bbox,
                                 line_y_norm, segments_norm,
                                 data_points_norm, placed_labels,
                                 point_x, point_y,
                                 buffer, config) {
  score <- 0

  half_h <- bbox$height / 2
  half_w <- bbox$width / 2

  label_top <- cy + half_h
  label_bot <- cy - half_h
  label_left <- cx - half_w
  label_right <- cx + half_w

  # --- 1. Bounds penalty (0 til 1 space) ---
  if (label_top > 1 || label_bot < 0 || label_left < 0 || label_right > 1) {
    score <- score + config$note_bounds_penalty
  }

  # --- 2. Horisontale referencelinjer ---
  # Filtrér NaN/NA (kan opstå hvis y_span ≈ 0 under normalisering)
  line_y_norm <- line_y_norm[is.finite(line_y_norm)]
  if (length(line_y_norm) > 0) {
    for (ly in line_y_norm) {
      if (ly >= label_bot && ly <= label_top) {
        # Linjen skærer label-boksen
        score <- score + config$note_line_penalty_weight
      } else {
        dist <- min(abs(label_top - ly), abs(label_bot - ly))
        if (dist < buffer) {
          proximity <- 1 - (dist / buffer)
          score <- score + config$note_line_penalty_weight * proximity^2
        }
      }
    }
  }

  # --- 3. Proceslinjen (diagonale segmenter) ---
  # Analytisk check: beregn segmentets y-værdi ved label-boksens x-kanter
  if (!is.null(segments_norm) && nrow(segments_norm) > 0) {
    for (s in seq_len(nrow(segments_norm))) {
      seg <- segments_norm[s, ]
      seg_x_min <- min(seg$x1, seg$x2)
      seg_x_max <- max(seg$x1, seg$x2)
      if (seg_x_max < label_left - buffer || seg_x_min > label_right + buffer) next

      # Beregn segmentets y-værdi ved relevante x-positioner (analytisk)
      seg_dx <- seg$x2 - seg$x1
      intersects <- FALSE
      min_dist <- Inf

      if (abs(seg_dx) > 1e-10) {
        # Samplér y ved label_left, label_right, og midtpunkt
        x_checks <- c(label_left, label_right, (label_left + label_right) / 2)
        # Tilføj segment-endpoints inden for label x-range
        if (seg$x1 >= label_left && seg$x1 <= label_right) x_checks <- c(x_checks, seg$x1)
        if (seg$x2 >= label_left && seg$x2 <= label_right) x_checks <- c(x_checks, seg$x2)

        for (xc in x_checks) {
          t_param <- (xc - seg$x1) / seg_dx
          if (t_param < 0 || t_param > 1) next  # Uden for segmentet
          sy <- seg$y1 + t_param * (seg$y2 - seg$y1)

          if (sy >= label_bot && sy <= label_top) {
            intersects <- TRUE
            break
          }
          dist <- min(abs(sy - label_top), abs(sy - label_bot))
          if (dist < min_dist) min_dist <- dist
        }
      } else {
        # Vertikalt segment - check y-range overlap
        if (seg$x1 >= label_left && seg$x1 <= label_right) {
          seg_y_min <- min(seg$y1, seg$y2)
          seg_y_max <- max(seg$y1, seg$y2)
          if (seg_y_max >= label_bot && seg_y_min <= label_top) {
            intersects <- TRUE
          }
        }
      }

      if (intersects) {
        score <- score + config$note_line_penalty_weight
      } else if (min_dist < buffer) {
        proximity <- 1 - (min_dist / buffer)
        score <- score + config$note_line_penalty_weight * proximity^2
      }
    }
  }

  # --- 4. Datapunkt-overlap ---
  if (!is.null(data_points_norm) && nrow(data_points_norm) > 0) {
    point_radius <- 0.015  # Cirkulær radius i normaliseret space

    for (dp in seq_len(nrow(data_points_norm))) {
      dpx <- data_points_norm$x[dp]
      dpy <- data_points_norm$y[dp]

      # Check om punktet er inden for label-boks + radius
      if (dpx >= (label_left - point_radius) &&
          dpx <= (label_right + point_radius) &&
          dpy >= (label_bot - point_radius) &&
          dpy <= (label_top + point_radius)) {
        score <- score + config$note_line_penalty_weight * 0.5
      }
    }
  }

  # --- 5. Label-label overlap ---
  if (length(placed_labels) > 0) {
    for (placed in placed_labels) {
      p_half_h <- placed$bbox$height / 2
      p_half_w <- placed$bbox$width / 2

      x_overlap <- max(0,
        min(cx + half_w, placed$x + p_half_w) -
          max(cx - half_w, placed$x - p_half_w)
      )
      y_overlap <- max(0,
        min(cy + half_h, placed$y + p_half_h) -
          max(cy - half_h, placed$y - p_half_h)
      )

      if (x_overlap > 0 && y_overlap > 0) {
        overlap_area <- x_overlap * y_overlap
        label_area <- bbox$width * bbox$height
        overlap_fraction <- overlap_area / max(label_area, 1e-10)
        score <- score + config$note_label_overlap_weight * overlap_fraction
      }
    }
  }

  # --- 6. Afstandspræference ---
  norm_dist <- sqrt((cx - point_x)^2 + (cy - point_y)^2)
  score <- score + config$note_distance_weight * norm_dist

  score
}


#' Estimér bounding box i normaliseret [0,1] space
#'
#' @param text character wrappet tekst (kan indeholde newlines)
#' @param char_width_factor numeric bredde per tegn som brøkdel af plot-bredde
#' @param line_height_factor numeric højde per linje som brøkdel af plot-højde
#' @return list med width og height i normaliseret [0,1] space
#'
#' @keywords internal
#' @noRd
estimate_label_bbox_norm <- function(text, char_width_factor, line_height_factor) {
  lines <- strsplit(text, "\n")[[1]]
  n_lines <- length(lines)
  max_chars <- max(nchar(lines))

  list(
    width = max_chars * char_width_factor,
    height = n_lines * line_height_factor
  )
}


#' Beregn pilens startpunkt på label-kanten
#'
#' Finder skæringen mellem linjen fra label-center til datapunktet
#' og label-boksens kant. Pilen starter fra kanten, ikke fra center.
#'
#' @param cx,cy label center i normaliseret space
#' @param bbox list med width og height
#' @param px,py datapunkt i normaliseret space
#' @return list med x, y for pilens startpunkt
#'
#' @keywords internal
#' @noRd
compute_arrow_start <- function(cx, cy, bbox, px, py) {
  dx <- px - cx
  dy <- py - cy

  # Hvis punkt og center er sammenfaldende, returner center
  if (abs(dx) < 1e-10 && abs(dy) < 1e-10) {
    return(list(x = cx, y = cy))
  }

  half_w <- bbox$width / 2
  half_h <- bbox$height / 2

  # Beregn t for skæring med hver kant af boksen
  # Vi søger den mindste positive t der rammer en kant
  t_candidates <- numeric(0)

  # Venstre/højre kanter
  if (abs(dx) > 1e-10) {
    t_right <- half_w / dx   # Højre kant hvis dx > 0
    t_left <- -half_w / dx   # Venstre kant hvis dx < 0
    for (t in c(t_right, t_left)) {
      if (t > 0) {
        hit_y <- cy + t * dy
        if (abs(hit_y - cy) <= half_h + 1e-10) {
          t_candidates <- c(t_candidates, t)
        }
      }
    }
  }

  # Top/bund kanter
  if (abs(dy) > 1e-10) {
    t_top <- half_h / dy     # Top kant hvis dy > 0
    t_bot <- -half_h / dy    # Bund kant hvis dy < 0
    for (t in c(t_top, t_bot)) {
      if (t > 0) {
        hit_x <- cx + t * dx
        if (abs(hit_x - cx) <= half_w + 1e-10) {
          t_candidates <- c(t_candidates, t)
        }
      }
    }
  }

  if (length(t_candidates) == 0) {
    return(list(x = cx, y = cy))
  }

  t_min <- min(t_candidates)
  list(
    x = cx + t_min * dx,
    y = cy + t_min * dy
  )
}
