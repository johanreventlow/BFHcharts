# ==============================================================================
# UTILS_NOTE_PLACEMENT.R
# ==============================================================================
# FORMÅL: Deterministisk label placement for SPC chart noter.
#         Placerer labels ved datapunkter og undgår horisontale linjer
#         (CL, UCL, LCL, target) samt andre labels.
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
#' referencelinjer (CL, UCL, LCL, target) og andre labels.
#'
#' @param comment_data data.frame med x, y, comment kolonner (fra extract_comment_data())
#' @param line_positions named numeric vector med y-værdier for linjer (kan indeholde NA)
#' @param y_range numeric(2) plot y-range
#' @param x_range numeric(2) plot x-range
#' @param config list med placement parametre (fra get_label_placement_config())
#' @return data.frame med label_x, label_y, point_x, point_y, label_text, draw_arrow
#'
#' @keywords internal
#' @noRd
place_note_labels <- function(comment_data,
                              line_positions,
                              y_range,
                              x_range,
                              config = NULL) {
  # Tom result structure
  empty_result <- data.frame(
    label_x = numeric(0),
    label_y = numeric(0),
    point_x = numeric(0),
    point_y = numeric(0),
    label_text = character(0),
    draw_arrow = logical(0),
    stringsAsFactors = FALSE
  )

  # Håndter NULL/tom input
  if (is.null(comment_data) || nrow(comment_data) == 0) {
    return(empty_result)
  }

  # Hent config
  if (is.null(config)) {
    if (exists("get_label_placement_config", mode = "function")) {
      config <- get_label_placement_config()
    } else {
      # Fallback defaults
      config <- list(
        note_label_offset_factor = 0.06,
        note_line_buffer_factor = 0.03,
        note_max_label_width = 25,
        note_line_penalty_weight = 100,
        note_label_overlap_weight = 80,
        note_distance_weight = 1,
        note_bounds_penalty = 1000,
        note_char_width_factor = 0.008,
        note_line_height_factor = 0.04
      )
    }
  }

  # Fjern NA fra line_positions
  line_y_values <- line_positions[!is.na(line_positions)]

  # Beregn afstande i data-enheder
  y_span <- diff(y_range)
  x_span <- diff(x_range)
  label_offset <- y_span * config$note_label_offset_factor
  line_buffer <- y_span * config$note_line_buffer_factor

  # Placer labels greedy (en ad gangen)
  placed_labels <- list()
  results <- vector("list", nrow(comment_data))

  for (i in seq_len(nrow(comment_data))) {
    row <- comment_data[i, ]
    px <- row$x
    py <- row$y

    # Word-wrap tekst
    wrapped_text <- stringr::str_wrap(row$comment, width = config$note_max_label_width)

    # Beregn bounding box
    bbox <- estimate_label_bbox(
      wrapped_text, x_span, y_span,
      config$note_char_width_factor,
      config$note_line_height_factor
    )

    # Generer 8 kandidatpositioner
    candidates <- generate_candidates(px, py, label_offset, bbox, x_span)

    # Scor hver kandidat
    best_score <- Inf
    best_candidate <- candidates[[1]]

    for (candidate in candidates) {
      score <- score_candidate(
        candidate_x = candidate$x,
        candidate_y = candidate$y,
        bbox = bbox,
        line_y_values = line_y_values,
        placed_labels = placed_labels,
        point_x = px,
        point_y = py,
        y_range = y_range,
        x_range = x_range,
        line_buffer = line_buffer,
        config = config
      )

      if (score < best_score) {
        best_score <- score
        best_candidate <- candidate
      }
    }

    # Gem placering
    # Beregn om arrow skal tegnes (label er forskudt fra punkt)
    dist_from_point <- sqrt(
      ((best_candidate$x - px) / x_span)^2 +
        ((best_candidate$y - py) / y_span)^2
    )
    draw_arrow <- dist_from_point > 0.01

    placed_labels[[i]] <- list(
      x = best_candidate$x,
      y = best_candidate$y,
      bbox = bbox
    )

    results[[i]] <- data.frame(
      label_x = best_candidate$x,
      label_y = best_candidate$y,
      point_x = px,
      point_y = py,
      label_text = wrapped_text,
      draw_arrow = draw_arrow,
      stringsAsFactors = FALSE
    )
  }

  dplyr::bind_rows(results)
}


#' Generer 8 kandidatpositioner for en label
#'
#' @param px numeric datapunkt x
#' @param py numeric datapunkt y
#' @param offset numeric label offset i y-enheder
#' @param bbox list med width og height
#' @param x_span numeric x-range bredde
#' @return list af candidates med x og y
#'
#' @keywords internal
#' @noRd
generate_candidates <- function(px, py, offset, bbox, x_span) {
  x_offset <- x_span * 0.03  # Horisontal forskydning

  list(
    list(x = px, y = py + offset),                  # 1. Over
    list(x = px, y = py - offset),                  # 2. Under
    list(x = px + x_offset, y = py + offset),       # 3. Over-højre
    list(x = px + x_offset, y = py - offset),       # 4. Under-højre
    list(x = px - x_offset, y = py + offset),       # 5. Over-venstre
    list(x = px - x_offset, y = py - offset),       # 6. Under-venstre
    list(x = px + x_offset * 1.5, y = py),          # 7. Højre
    list(x = px - x_offset * 1.5, y = py)           # 8. Venstre
  )
}


#' Scor en kandidatposition
#'
#' Lavere score er bedre. Scorer baseret på nærhed til linjer,
#' overlap med andre labels, afstand fra datapunkt, og bounds.
#'
#' @param candidate_x numeric kandidat x-position
#' @param candidate_y numeric kandidat y-position
#' @param bbox list med width og height
#' @param line_y_values numeric vector af linje y-positioner (uden NA)
#' @param placed_labels list af allerede placerede labels
#' @param point_x numeric datapunkt x
#' @param point_y numeric datapunkt y
#' @param y_range numeric(2) y-axis range
#' @param x_range numeric(2) x-axis range
#' @param line_buffer numeric minimumsafstand til linje
#' @param config list med penalty weights
#' @return numeric score (lavere er bedre)
#'
#' @keywords internal
#' @noRd
score_candidate <- function(candidate_x, candidate_y, bbox,
                            line_y_values, placed_labels,
                            point_x, point_y,
                            y_range, x_range,
                            line_buffer, config) {
  score <- 0
  y_span <- diff(y_range)
  x_span <- diff(x_range)

  half_h <- bbox$height / 2
  half_w <- bbox$width / 2

  # --- Bounds penalty ---
  label_top <- candidate_y + half_h
  label_bot <- candidate_y - half_h
  label_left <- candidate_x - half_w
  label_right <- candidate_x + half_w

  if (label_top > y_range[2] || label_bot < y_range[1] ||
      label_left < x_range[1] || label_right > x_range[2]) {
    score <- score + config$note_bounds_penalty
  }

  # --- Linje-overlap penalty ---
  if (length(line_y_values) > 0) {
    for (line_y in line_y_values) {
      # Afstand fra label-kant til linje
      dist_to_line <- min(abs(label_top - line_y), abs(label_bot - line_y))
      # Hvis linjen er INDE i label-boksen, dist = 0
      if (line_y >= label_bot && line_y <= label_top) {
        dist_to_line <- 0
      }

      if (dist_to_line < line_buffer) {
        # Penalty stiger kraftigt jo tættere vi er
        proximity <- 1 - (dist_to_line / line_buffer)
        score <- score + config$note_line_penalty_weight * proximity^2
      }
    }
  }

  # --- Label-label overlap penalty ---
  if (length(placed_labels) > 0) {
    for (placed in placed_labels) {
      p_half_h <- placed$bbox$height / 2
      p_half_w <- placed$bbox$width / 2

      # Check bounding box overlap
      x_overlap <- max(0,
        min(candidate_x + half_w, placed$x + p_half_w) -
          max(candidate_x - half_w, placed$x - p_half_w)
      )
      y_overlap <- max(0,
        min(candidate_y + half_h, placed$y + p_half_h) -
          max(candidate_y - half_h, placed$y - p_half_h)
      )

      if (x_overlap > 0 && y_overlap > 0) {
        overlap_area <- x_overlap * y_overlap
        label_area <- bbox$width * bbox$height
        overlap_fraction <- overlap_area / max(label_area, 1e-10)
        score <- score + config$note_label_overlap_weight * overlap_fraction
      }
    }
  }

  # --- Afstandspræference (normaliseret) ---
  norm_dist <- sqrt(
    ((candidate_x - point_x) / x_span)^2 +
      ((candidate_y - point_y) / y_span)^2
  )
  score <- score + config$note_distance_weight * norm_dist

  score
}


#' Estimér bounding box for wrappet tekst
#'
#' Approksimerer bredde og højde i data-enheder baseret på tegnantal.
#'
#' @param text character wrappet tekst (kan indeholde newlines)
#' @param x_span numeric x-range bredde
#' @param y_span numeric y-range højde
#' @param char_width_factor numeric bredde per tegn som andel af x_span
#' @param line_height_factor numeric højde per linje som andel af y_span
#' @return list med width og height i data-enheder
#'
#' @keywords internal
#' @noRd
estimate_label_bbox <- function(text, x_span, y_span,
                                char_width_factor, line_height_factor) {
  lines <- strsplit(text, "\n")[[1]]
  n_lines <- length(lines)
  max_chars <- max(nchar(lines))

  list(
    width = max_chars * char_width_factor * x_span,
    height = n_lines * line_height_factor * y_span
  )
}
