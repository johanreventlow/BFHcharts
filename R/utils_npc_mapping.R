# ==============================================================================
# INTELLIGENT LABEL PLACEMENT SYSTEM - STANDALONE VERSION
# ==============================================================================
#
# Intelligent label placement system med NPC-koordinater og multi-level
# collision avoidance.
#
# Kan genbruges i ethvert R plotting projekt til at placere labels ved
# horisontale linjer uden overlaps.
#
# FEATURES:
# - Ingen overlaps mellem labels eller med linjer
# - Multi-level collision avoidance (3 niveauer)
# - Auto-adaptive parametre baseret på font sizes
# - Device-independent (NPC koordinater 0-1)
# - Robust på tværs af ggplot2 versioner
# - Edge case handling (sammenfaldende linjer, bounds violations)
#
# DEPENDENCIES:
# - ggplot2
# - stringr
#
# USAGE:
# library(ggplot2)
#
# # Opret plot
# p <- ggplot(mtcars, aes(x = wt, y = mpg)) +
#   geom_point() +
#   geom_hline(yintercept = 20, color = "blue") +
#   geom_hline(yintercept = 25, color = "red") +
#   theme_minimal()
#
# # Opret NPC mapper
# mapper <- npc_mapper_from_built(ggplot2::ggplot_build(p), original_plot = p)
#
# # Definer labels (marquee format)
# label_A <- "{.8 **CL**}  \n{.24 **20 mpg**}"
# label_B <- "{.8 **Target**}  \n{.24 **25 mpg**}"
#
# # Auto-beregn label height
# label_height <- estimate_label_height_npc(label_A)
#
# # Placer labels
# result <- place_two_labels_npc(
#   yA_npc = mapper$y_to_npc(20),
#   yB_npc = mapper$y_to_npc(25),
#   label_height_npc = label_height,
#   gap_line = label_height * 0.08,     # 8% af label height
#   gap_labels = label_height * 0.3,    # 30% af label height
#   priority = "A",
#   pref_pos = c("under", "under")
# )
#
# # Konverter NPC tilbage til data coordinates
# yA_data <- mapper$npc_to_y(result$yA)
# yB_data <- mapper$npc_to_y(result$yB)
#
# EXPORTS:
# Core placement functions:
# - npc_mapper_from_built()
# - estimate_label_height_npc()
# - place_two_labels_npc()
# - propose_single_label()
# - clamp01()
#
# NOTE: Cache management functions removed in v0.4.1 (see GitHub issue #42)
# Caching was disabled by default and added complexity without measurable benefit.
#
# ==============================================================================


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Clamp værdi til interval `[0, 1]`
#'
#' @param x Numerisk værdi eller vektor
#' @return Værdi begrænset til `[0, 1]`
#' @keywords internal
#' @noRd
clamp01 <- function(x) {
  # Input validation
  if (is.null(x) || length(x) == 0) {
    stop("clamp01: x må ikke være NULL eller tom")
  }

  if (!is.numeric(x)) {
    stop("clamp01: x skal være numerisk, modtog: ", class(x)[1])
  }

  if (any(!is.finite(x[!is.na(x)]))) {
    warning("clamp01: Ikke-finite værdier (Inf/-Inf) detekteret")
    x[!is.finite(x)] <- NA_real_
  }

  pmax(0, pmin(1, x))
}

#' Clamp værdi til custom bounds interval
#'
#' Bruges til at sikre at labels respekterer panel padding (pad_top/pad_bot)
#' også ved flip-scenarios.
#'
#' @param x Numerisk værdi eller vektor
#' @param low_bound Nedre grænse
#' @param high_bound Øvre grænse
#' @return Værdi begrænset til `[low_bound, high_bound]`
#' @keywords internal
#' @noRd
clamp_to_bounds <- function(x, low_bound, high_bound) {
  # Input validation
  if (is.null(x) || length(x) == 0) {
    stop("clamp_to_bounds: x må ikke være NULL eller tom")
  }

  if (!is.numeric(x) || !is.numeric(low_bound) || !is.numeric(high_bound)) {
    stop("clamp_to_bounds: Alle parametre skal være numeriske")
  }

  # Når labels er større end panelet kan bounds invertere - returner midtpunktet
  if (low_bound >= high_bound) {
    return(rep((low_bound + high_bound) / 2, length(x)))
  }

  pmax(low_bound, pmin(high_bound, x))
}


# ==============================================================================
# NPC MAPPING
# ==============================================================================

#' Opret NPC mapper fra ggplot object
#'
#' Denne funktion bygger ggplot og udtræker scale information for at konvertere
#' mellem data-koordinater og NPC (Normalized Parent Coordinates, 0-1).
#'
#' @param p ggplot object
#' @param panel Panel nummer (default = 1)
#'
#' @return List med:
#'   - `y_to_npc`: function(y_data) → NPC
#'   - `npc_to_y`: function(npc) → y_data
#'   - `limits`: c(ymin, ymax)
#'   - `trans_name`: transformation navn (fx "identity", "log10")
#'
#' Opret NPC mapper fra et pre-built ggplot object (PERFORMANCE OPTIMIZED)
#'
#' Denne funktion accepterer et allerede bygget plot (ggplot_built object)
#' og opretter mapper direkte fra et bygget plot uden ekstra build-overhead
#' fra at bygge plottet igen.
#'
#' @param built_plot ggplot_built object fra ggplot2::ggplot_build()
#' @param panel Panel index (default 1)
#' @param original_plot Optional: Original ggplot object (kun nødvendigt for fallback scale extraction)
#'
#' @return List med y_to_npc og npc_to_y funktioner
#'
#' @keywords internal
#' @noRd
npc_mapper_from_built <- function(built_plot, panel = 1, original_plot = NULL) {
  # Validate built plot object
  if (is.null(built_plot) || !inherits(built_plot, "ggplot_built")) {
    stop("npc_mapper_from_built: built_plot skal være et ggplot_built object")
  }

  # Validate panel parameter
  if (!is.numeric(panel) || length(panel) != 1 || panel < 1 || panel != floor(panel)) {
    stop("npc_mapper_from_built: panel skal være et positivt heltal, modtog: ", panel)
  }

  if (is.null(built_plot$layout) || is.null(built_plot$layout$panel_params)) {
    stop("npc_mapper_from_built: Plot mangler layout information")
  }

  # Validate panel exists
  if (panel > length(built_plot$layout$panel_params)) {
    stop(sprintf(
      "npc_mapper_from_built: Panel %d eksisterer ikke (plot har kun %d panels)",
      panel, length(built_plot$layout$panel_params)
    ))
  }

  # Prøv forskellige metoder til at få panel params (robust på tværs af ggplot2 versioner)
  pp <- tryCatch(
    {
      built_plot$layout$panel_params[[panel]]
    },
    error = function(e) {
      tryCatch(
        {
          built_plot$layout$panel_scales_y[[panel]]
        },
        error = function(e2) NULL
      )
    }
  )

  if (is.null(pp)) {
    stop("Kunne ikke hente panel parameters fra built plot. Tjek ggplot2 version.")
  }

  # Udtræk limits og transformation
  get_scale_info <- function(pp, original_plot) {
    lims <- NULL
    trans <- NULL
    trans_name <- "identity"

    # Prøv struktureret y scale i panel params
    if (!is.null(pp$y) && !is.null(pp$y$range)) {
      lims <- tryCatch(pp$y$range$range, error = function(e) NULL)
      trans <- tryCatch(pp$y$trans, error = function(e) NULL)
      if (!is.null(trans)) {
        trans_name <- if (is.character(trans)) trans else if (!is.null(trans$name)) trans$name else "identity"
      }
    }

    if (is.null(lims) && !is.null(pp$y.range)) {
      lims <- pp$y.range
    }

    # Fallback til original plot scale (hvis tilgængeligt)
    if (is.null(lims) && !is.null(original_plot)) {
      y_scales <- Filter(function(s) "y" %in% s$aesthetics, original_plot$scales$scales)
      if (length(y_scales) > 0) {
        lims <- y_scales[[1]]$get_limits()
        trans <- y_scales[[1]]$trans
        if (!is.null(trans)) {
          trans_name <- if (!is.null(trans$name)) trans$name else "identity"
        }
      }
    }

    if (is.null(lims) || length(lims) != 2) {
      stop("Kunne ikke bestemme y-akse limits fra built plot.")
    }

    # Trans function
    trans_fun <- if (!is.null(trans) && !is.null(trans$transform)) {
      trans$transform
    } else {
      function(x) x
    }

    # Inverse trans function
    inv_trans_fun <- if (!is.null(trans) && !is.null(trans$inverse)) {
      trans$inverse
    } else {
      function(x) x
    }

    list(lims = lims, trans = trans_fun, inv_trans = inv_trans_fun, trans_name = trans_name)
  }

  info <- get_scale_info(pp, original_plot)
  ymin <- info$lims[1]
  ymax <- info$lims[2]

  if (!is.finite(ymin) || !is.finite(ymax) || ymax <= ymin) {
    stop("Ugyldige y-akse limits: [", ymin, ", ", ymax, "]")
  }

  # Pre-compute transformerede limits (faste ved mapper-oprettelse)
  y0 <- info$trans(ymin)
  y1 <- info$trans(ymax)
  y_range_trans <- y1 - y0

  if (abs(y_range_trans) < .Machine$double.eps) {
    stop(sprintf(
      "Y-akse range er praktisk talt nul efter transformation: y0=%.10f, y1=%.10f",
      y0, y1
    ))
  }

  # Y-data → NPC mapper
  y_to_npc <- function(y) {
    if (any(is.na(y))) {
      result <- rep(NA_real_, length(y))
      valid <- !is.na(y)
      if (any(valid)) {
        result[valid] <- (info$trans(y[valid]) - y0) / y_range_trans
      }
      return(result)
    }
    (info$trans(y) - y0) / y_range_trans
  }

  # NPC → Y-data inverse mapper
  npc_to_y <- function(npc) {
    if (any(is.na(npc))) {
      result <- rep(NA_real_, length(npc))
      valid <- !is.na(npc)
      if (any(valid)) {
        result[valid] <- info$inv_trans(y0 + npc[valid] * y_range_trans)
      }
      return(result)
    }
    info$inv_trans(y0 + npc * y_range_trans)
  }

  list(
    y_to_npc = y_to_npc,
    npc_to_y = npc_to_y,
    limits = c(ymin, ymax),
    trans_name = info$trans_name
  )
}
