# ==============================================================================
# UTILS_NOTE_PLACEMENT.R
# ==============================================================================
# FORMAAL: Deterministisk label placement for SPC chart noter.
#         Placerer labels ved datapunkter og undgaar horisontale linjer
#         (CL, UCL, LCL, target), proceslinjen (geom_line mellem punkter),
#         datapunkter, og andre labels.
#
#         VIGTIGT: Al scoring sker i normaliseret [0,1] space for at
#         haandtere vidt forskellige skalaer paa x- og y-aksen
#         (f.eks. POSIXct sekunder vs. procent-broeker).
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
#' Beregner optimale positioner for note-labels der undgaar horisontale
#' referencelinjer (CL, UCL, LCL, target), proceslinjen mellem datapunkter,
#' selve datapunkterne, og andre allerede placerede labels.
#'
#' Al scoring sker i normaliseret 0-1 space for at haandtere
#' forskellige skalaer (f.eks. Date/POSIXct vs. procent).
#'
#' @param comment_data data.frame med x, y, comment kolonner
#' @param line_positions named numeric vector med y-vaerdier for linjer (kan indeholde NA)
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
  # Guard: y_span/x_span kan vaere 0 hvis alle vaerdier er ens -> undgaa division med nul
  y_span <- diff(y_range)
  x_span <- diff(x_range)
  if (!is.finite(y_span) || y_span == 0) {
    return(empty_result)
  }
  if (!is.finite(x_span) || x_span == 0) {
    return(empty_result)
  }
  norm_x <- function(x) (x - x_range[1]) / x_span
  norm_y <- function(y) (y - y_range[1]) / y_span
  denorm_x <- function(nx) nx * x_span + x_range[1]
  denorm_y <- function(ny) ny * y_span + y_range[1]

  # Normaliser line_positions til [0,1]
  line_y_norm <- norm_y(line_positions[!is.na(line_positions)])

  # Normaliser data_points
  # Vectorized layout: data_points stored as named numeric vectors (dp_x, dp_y);
  # segments stored as decomposed numeric vectors with pre-computed deltas.
  # This avoids per-iteration data.frame row copies (df[s, ]).
  dp_x <- NULL
  dp_y <- NULL
  seg_x1 <- NULL
  seg_y1 <- NULL
  seg_x2 <- NULL
  seg_y2 <- NULL
  seg_dx <- NULL
  seg_dy <- NULL
  seg_x_min <- NULL
  seg_x_max <- NULL
  seg_y_min <- NULL
  seg_y_max <- NULL
  if (!is.null(data_points) && nrow(data_points) > 0) {
    dpx_all <- norm_x(data_points$x)
    dpy_all <- norm_y(data_points$y)
    keep <- !is.na(dpx_all) & !is.na(dpy_all)
    dp_x <- dpx_all[keep]
    dp_y <- dpy_all[keep]

    if (length(dp_x) >= 2) {
      ord <- order(dp_x)
      dp_x_sorted <- dp_x[ord]
      dp_y_sorted <- dp_y[ord]
      n_dp <- length(dp_x_sorted)
      seg_x1 <- dp_x_sorted[-n_dp]
      seg_y1 <- dp_y_sorted[-n_dp]
      seg_x2 <- dp_x_sorted[-1]
      seg_y2 <- dp_y_sorted[-1]
      seg_dx <- seg_x2 - seg_x1
      seg_dy <- seg_y2 - seg_y1
      seg_x_min <- pmin(seg_x1, seg_x2)
      seg_x_max <- pmax(seg_x1, seg_x2)
      seg_y_min <- pmin(seg_y1, seg_y2)
      seg_y_max <- pmax(seg_y1, seg_y2)
    }
  }

  offset <- config$note_label_offset_factor
  buffer <- config$note_line_buffer_factor

  # Pre-filter line_y_norm to finite values once (was filtered per-candidate before)
  line_y_norm <- line_y_norm[is.finite(line_y_norm)]

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

    cand_xy <- generate_candidates_matrix_norm(px, py, offset)
    cand_x <- cand_xy[, 1L]
    cand_y <- cand_xy[, 2L]

    # Vectorized scoring: returns numeric vector of length n_candidates
    all_scores <- score_candidates_vec(
      cand_x = cand_x,
      cand_y = cand_y,
      bbox = bbox,
      line_y_norm = line_y_norm,
      seg_x1 = seg_x1, seg_y1 = seg_y1,
      seg_x2 = seg_x2, seg_y2 = seg_y2,
      seg_dx = seg_dx, seg_dy = seg_dy,
      seg_x_min = seg_x_min, seg_x_max = seg_x_max,
      seg_y_min = seg_y_min, seg_y_max = seg_y_max,
      dp_x = dp_x, dp_y = dp_y,
      placed_labels = placed_labels,
      point_x = px, point_y = py,
      buffer = buffer,
      config = config
    )

    # which.min returns first index of minimum -> matches original
    # `score < best_score` strict-inequality tie-breaking semantics.
    best_idx <- which.min(all_scores)
    best_x <- cand_x[best_idx]
    best_y <- cand_y[best_idx]

    # Konverter bedste position tilbage til data coords
    label_x_data <- denorm_x(best_x)
    label_y_data <- denorm_y(best_y)

    # Arrow: beregn startpunkt paa label-kant (ikke center)
    dist_norm <- sqrt((best_x - px)^2 + (best_y - py)^2)
    draw_arrow <- dist_norm > 0.02

    # Beregn pilens startpunkt: skaering mellem linje (center->punkt) og label-boks
    arrow_start <- compute_arrow_start(best_x, best_y, bbox, px, py)
    arrow_x_data <- denorm_x(arrow_start$x)
    arrow_y_data <- denorm_y(arrow_start$y)

    # Buet pil hvis label er forskudt horisontalt (ikke direkte over/under)
    dx_norm <- best_x - px
    dy_norm <- best_y - py
    is_diagonal <- abs(dx_norm) > 0.01
    if (is_diagonal) {
      # Buen skal bue vaek fra datapunktet:
      # - Label over+hoejre: bue nedad (positiv curvature)
      # - Label over+venstre: bue nedad (negativ curvature)
      # - Label under+hoejre: bue opad (negativ curvature)
      # - Label under+venstre: bue opad (positiv curvature)
      # geom_curve: positiv curvature buer til hoejre set fra start->end
      curvature <- if ((dx_norm > 0) == (dy_norm > 0)) -0.25 else 0.25
    } else {
      curvature <- 0
    }

    placed_labels[[i]] <- list(x = best_x, y = best_y, bbox = bbox)

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


#' Generer 20 kandidatpositioner som matrix i normaliseret 0-1 space
#'
#' Returns a 20 x 2 numeric matrix where rows are candidates and columns
#' are (x, y). Candidate ordering MUST match the original list-based
#' generate_candidates_norm() so tie-breaking semantics are preserved.
#'
#' @keywords internal
#' @noRd
generate_candidates_matrix_norm <- function(px, py, offset) {
  x_off <- offset * 0.5
  off2 <- offset * 1.8
  off3 <- offset * 2.5 # Meget langt vaek - sikrer altid en overlap-fri mulighed

  # All candidates have vertical component - prevents arrow crossing label text.
  # Order is identical to the original list-based generator (1..20):
  matrix(
    c(
      px,                py + offset, # 1.  Over
      px,                py - offset, # 2.  Under
      px + x_off,        py + offset, # 3.  Over-right
      px + x_off,        py - offset, # 4.  Under-right
      px - x_off,        py + offset, # 5.  Over-left
      px - x_off,        py - offset, # 6.  Under-left
      px + x_off,        py + offset * 0.7, # 7.  Diag right-up
      px - x_off,        py - offset * 0.7, # 8.  Diag left-down
      px + x_off * 1.3,  py + offset * 0.7, # 9.  Diag right-up (longer)
      px - x_off * 1.3,  py - offset * 0.7, # 10. Diag left-down (longer)
      px,                py + off2, # 11. Far over
      px,                py - off2, # 12. Far under
      px + x_off,        py + off2, # 13. Far over-right
      px + x_off,        py - off2, # 14. Far under-right
      px - x_off,        py + off2, # 15. Far over-left
      px - x_off,        py - off2, # 16. Far under-left
      px,                py + off3, # 17. Very far over
      px,                py - off3, # 18. Very far under
      px + x_off,        py + off3, # 19. Very far over-right
      px - x_off,        py - off3 # 20. Very far under-left
    ),
    nrow = 20L, ncol = 2L, byrow = TRUE
  )
}


#' Vectorized scoring of all candidates for one comment
#'
#' Computes the score for each of the n candidate positions in a single
#' set of vectorized operations. The output is bit-equivalent (modulo
#' floating-point summation order) to summing the per-component
#' contributions used by score_candidate_norm().
#'
#' All segment/data_points inputs are pre-extracted numeric vectors so we
#' avoid per-iteration data.frame row copies. Pass NULL for missing groups.
#'
#' @keywords internal
#' @noRd
score_candidates_vec <- function(cand_x, cand_y, bbox,
                                 line_y_norm,
                                 seg_x1, seg_y1, seg_x2, seg_y2,
                                 seg_dx, seg_dy,
                                 seg_x_min, seg_x_max,
                                 seg_y_min, seg_y_max,
                                 dp_x, dp_y,
                                 placed_labels,
                                 point_x, point_y,
                                 buffer, config) {
  n_cand <- length(cand_x)
  scores <- numeric(n_cand)

  half_h <- bbox$height / 2
  half_w <- bbox$width / 2

  label_top <- cand_y + half_h
  label_bot <- cand_y - half_h
  label_left <- cand_x - half_w
  label_right <- cand_x + half_w

  bounds_penalty <- config$note_bounds_penalty
  line_weight <- config$note_line_penalty_weight
  overlap_weight <- config$note_label_overlap_weight
  distance_weight <- config$note_distance_weight

  # --- 1. Bounds penalty (any edge outside [0,1]) ---
  out_of_bounds <- label_top > 1 | label_bot < 0 |
    label_left < 0 | label_right > 1
  scores <- scores + bounds_penalty * out_of_bounds

  # --- 2. Horisontale referencelinjer ---
  n_lines <- length(line_y_norm)
  if (n_lines > 0L) {
    for (ly in line_y_norm) {
      crosses <- ly >= label_bot & ly <= label_top
      # When line crosses, contribution is line_weight (independent of
      # proximity). When it doesn't, fall back to proximity penalty.
      d_top <- abs(label_top - ly)
      d_bot <- abs(label_bot - ly)
      dist <- pmin(d_top, d_bot)
      proximity <- 1 - (dist / buffer)
      proximity[proximity < 0] <- 0
      contrib <- ifelse(
        crosses,
        line_weight,
        ifelse(dist < buffer, line_weight * proximity^2, 0)
      )
      scores <- scores + contrib
    }
  }

  # --- 3. Proceslinjen (diagonale segmenter) ---
  if (!is.null(seg_x1) && length(seg_x1) > 0L) {
    # Loop over candidates (20). Inside, we vectorize over all segments.
    # This trades the inner segment-loop (was per-iteration) for a single
    # vectorized pass. Original "break on first intersection" semantics
    # are preserved via any() on the segment-vector intersect mask.
    for (ci in seq_len(n_cand)) {
      ll <- label_left[ci]
      lr <- label_right[ci]
      lb <- label_bot[ci]
      lt <- label_top[ci]

      # Segments potentially in horizontal range
      relevant <- !(seg_x_max < (ll - buffer) | seg_x_min > (lr + buffer))
      if (!any(relevant)) next

      idx <- which(relevant)
      sx1 <- seg_x1[idx]
      sx2 <- seg_x2[idx]
      sdx <- seg_dx[idx]
      sdy <- seg_dy[idx]
      sy1_v <- seg_y1[idx]
      syn <- seg_y_min[idx]
      syx <- seg_y_max[idx]

      diagonal <- abs(sdx) > 1e-10
      vertical <- !diagonal

      seg_intersects <- logical(length(idx))
      seg_min_dist <- rep(Inf, length(idx))

      # --- Vertical segments (rare) ---
      if (any(vertical)) {
        v_idx <- which(vertical)
        in_x <- sx1[v_idx] >= ll & sx1[v_idx] <= lr
        y_overlap <- syx[v_idx] >= lb & syn[v_idx] <= lt
        seg_intersects[v_idx] <- in_x & y_overlap
        # No proximity term for vertical case in original code
      }

      # --- Diagonal segments (common) ---
      if (any(diagonal)) {
        d_idx <- which(diagonal)
        m <- length(d_idx)

        dsx1 <- sx1[d_idx]
        dsx2 <- sx2[d_idx]
        dsy1 <- sy1_v[d_idx]
        ddx <- sdx[d_idx]
        ddy <- sdy[d_idx]

        # Per-segment x_check vector: (label_left, label_right, mid,
        # seg.x1 if inside, seg.x2 if inside). Up to 5 entries per segment.
        # Build as a m x 5 matrix; entries that should be skipped are NA.
        mid <- (ll + lr) / 2

        x_chk <- matrix(NA_real_, nrow = m, ncol = 5L)
        x_chk[, 1L] <- ll
        x_chk[, 2L] <- lr
        x_chk[, 3L] <- mid
        # seg.x1 only included if it falls inside the label x-range
        in1 <- dsx1 >= ll & dsx1 <= lr
        x_chk[in1, 4L] <- dsx1[in1]
        in2 <- dsx2 >= ll & dsx2 <= lr
        x_chk[in2, 5L] <- dsx2[in2]

        # Compute t for each (segment, x_check) pair, vectorized.
        # ddx and dsx1 broadcast across columns.
        t_param <- (x_chk - dsx1) / ddx
        # Filter: t in [0, 1] AND not NA (skipped slot)
        in_seg <- !is.na(t_param) & t_param >= 0 & t_param <= 1

        sy <- dsy1 + t_param * ddy
        within_y <- sy >= lb & sy <= lt
        intersects_mat <- in_seg & within_y

        # Original: break on first intersection (per-segment). The early
        # break short-circuits min_dist updates *for slots after* the
        # break. We must preserve that: for each segment, scan x_checks
        # in column order and stop at first intersect.
        # Approach: find first column where intersects is TRUE; for
        # columns before it, accumulate min_dist; if no intersect, scan
        # all valid slots for min_dist.

        # First-intersect column per segment (Inf if none)
        # Use max.col-style trick: find min column index where TRUE.
        first_hit_col <- apply(intersects_mat, 1L, function(r) {
          w <- which(r)
          if (length(w) == 0L) Inf else w[1L]
        })

        any_intersect <- is.finite(first_hit_col)

        # For min_dist: consider only slots with in_seg == TRUE AND
        # column index < first_hit_col. If no intersect, all valid
        # in_seg slots count.
        # Compute distance per slot
        dist_top <- abs(sy - lt)
        dist_bot <- abs(sy - lb)
        dist_slot <- pmin(dist_top, dist_bot)
        # Mask out invalid slots
        col_idx <- matrix(seq_len(5L), nrow = m, ncol = 5L, byrow = TRUE)
        # Valid for min_dist: in_seg AND (no intersect OR col < first_hit)
        valid_mask <- in_seg & (col_idx < first_hit_col |
          is.infinite(first_hit_col))
        # Apply mask (set invalid slots to Inf)
        dist_masked <- dist_slot
        dist_masked[!valid_mask] <- Inf
        seg_min_d <- do.call(pmin, c(
          lapply(seq_len(5L), function(j) dist_masked[, j]),
          list(na.rm = FALSE)
        ))

        seg_intersects[d_idx] <- any_intersect
        seg_min_dist[d_idx] <- seg_min_d
      }

      # Aggregate per-segment penalties for this candidate.
      # Proximity term applies only to non-intersecting segments
      # whose distance is below the buffer.
      contrib_int <- sum(seg_intersects) * line_weight
      not_int <- !seg_intersects
      prox_d <- seg_min_dist[not_int]
      near <- prox_d < buffer
      if (any(near)) {
        proxv <- 1 - (prox_d[near] / buffer)
        contrib_prox <- sum(line_weight * proxv^2)
      } else {
        contrib_prox <- 0
      }
      scores[ci] <- scores[ci] + contrib_int + contrib_prox
    }
  }

  # --- 4. Datapunkt-overlap ---
  if (!is.null(dp_x) && length(dp_x) > 0L) {
    point_radius <- 0.015 # Circular radius in normalized space
    for (k in seq_along(dp_x)) {
      dpx <- dp_x[k]
      dpy <- dp_y[k]
      hit <- dpx >= (label_left - point_radius) &
        dpx <= (label_right + point_radius) &
        dpy >= (label_bot - point_radius) &
        dpy <= (label_top + point_radius)
      scores <- scores + line_weight * 0.5 * hit
    }
  }

  # --- 5. Label-label overlap ---
  if (length(placed_labels) > 0L) {
    label_area <- bbox$width * bbox$height
    inv_area <- 1 / max(label_area, 1e-10)
    for (placed in placed_labels) {
      p_half_h <- placed$bbox$height / 2
      p_half_w <- placed$bbox$width / 2
      px_p <- placed$x
      py_p <- placed$y

      x_overlap <- pmin(cand_x + half_w, px_p + p_half_w) -
        pmax(cand_x - half_w, px_p - p_half_w)
      x_overlap[x_overlap < 0] <- 0
      y_overlap <- pmin(cand_y + half_h, py_p + p_half_h) -
        pmax(cand_y - half_h, py_p - p_half_h)
      y_overlap[y_overlap < 0] <- 0

      pos <- x_overlap > 0 & y_overlap > 0
      if (any(pos)) {
        overlap_area <- x_overlap * y_overlap
        overlap_fraction <- overlap_area * inv_area
        scores <- scores + overlap_weight * overlap_fraction * pos
      }
    }
  }

  # --- 6. Distance preference ---
  norm_dist <- sqrt((cand_x - point_x)^2 + (cand_y - point_y)^2)
  scores <- scores + distance_weight * norm_dist

  scores
}


#' Estimer bounding box i normaliseret 0-1 space
#'
#' @param text character wrappet tekst (kan indeholde newlines)
#' @param char_width_factor numeric bredde per tegn som broekdel af plot-bredde
#' @param line_height_factor numeric hoejde per linje som broekdel af plot-hoejde
#' @return list med width og height i normaliseret 0-1 space
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


#' Beregn pilens startpunkt paa label-kanten
#'
#' Finder skaeringen mellem linjen fra label-center til datapunktet
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

  # Beregn t for skaering med hver kant af boksen
  # Vi soeger den mindste positive t der rammer en kant
  t_candidates <- numeric(0)

  # Venstre/hoejre kanter
  if (abs(dx) > 1e-10) {
    t_right <- half_w / dx # H\u00f8jre kant hvis dx > 0
    t_left <- -half_w / dx # Venstre kant hvis dx < 0
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
    t_top <- half_h / dy # Top kant hvis dy > 0
    t_bot <- -half_h / dy # Bund kant hvis dy < 0
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
