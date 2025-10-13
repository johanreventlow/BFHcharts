# utils_colors.R
# Internal color utilities for BFHtheme integration

#' Get Default SPC Colors from BFHtheme
#'
#' Internal helper to get BFHtheme colors for SPC charts.
#' Maps BFHtheme color names to the structure expected by BFHcharts functions.
#'
#' @return Named list of colors compatible with BFHcharts plotting functions
#' @keywords internal
#' @noRd
get_spc_colors <- function() {
  list(
    primary = BFHtheme::bfh_cols("hospital_blue"),         # "#009ce8" - main SPC line color
    secondary = BFHtheme::bfh_cols("hospital_grey"),       # "#646c6f" - subtitles
    darkgrey = BFHtheme::bfh_cols("hospital_dark_grey"),   # "#333333" - target lines, comments
    lightgrey = BFHtheme::bfh_cols("hospital_light_blue1"),# "#cce5f1" - data lines, axis
    mediumgrey = BFHtheme::bfh_cols("hospital_grey"),      # "#646c6f" - points, segments
    dark = BFHtheme::bfh_cols("hospital_dark_grey")        # "#333333" - text
  )
}

#' Ensure Color Palette Has Required Names
#'
#' Internal helper to validate and fill in missing colors from default palette.
#' Allows users to pass custom colors while ensuring all required names exist.
#'
#' @param colors User-provided color palette (named list or NULL)
#' @return Complete color palette with all required names
#' @keywords internal
#' @noRd
ensure_color_names <- function(colors = NULL) {
  # Get default BFHtheme colors
  default_colors <- get_spc_colors()

  # If user didn't provide colors, use defaults
  if (is.null(colors)) {
    return(default_colors)
  }

  # If colors is a named list, merge with defaults
  if (is.list(colors) && !is.null(names(colors))) {
    # Fill in missing colors from defaults
    for (name in names(default_colors)) {
      if (!name %in% names(colors)) {
        colors[[name]] <- default_colors[[name]]
      }
    }
    return(colors)
  }

  # If invalid input, return defaults with warning
  warning("Invalid colors parameter. Using default BFHtheme colors.")
  return(default_colors)
}
