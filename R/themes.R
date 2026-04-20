#' SPC Theme Utilities
#'
#' Theme-related utilities specific to SPC charts. General theming is handled
#' by the BFHtheme package.
#'
#' @name spc_themes
#' @keywords internal
#' @noRd
NULL

# ============================================================================
# SPC-SPECIFIC THEME APPLICATION
# ============================================================================

#' Apply SPC-Specific Theme Styling
#'
#' Internal function that applies BFH theme with SPC-specific adjustments.
#' Used to ensure consistent SPC chart styling.
#'
#' Uses BFHtheme::theme_bfh() as base and adds SPC-specific modifications:
#' - Capped coordinate system (via lemon::coord_capped_cart)
#' - Default 5mm plot margins for visual balance
#' - Automatic removal of blank axis titles (NULL or empty strings)
#' - Custom plot margins if specified (overrides default)
#'
#' @param plot ggplot2 object
#' @param base_size Base font size
#' @param plot_margin Numeric vector of length 4 (top, right, bottom, left) in mm,
#'   or a margin object from ggplot2::margin(), or NULL for default (5mm all sides)
#'
#' @return Modified ggplot2 object with theme applied
#'
#' @keywords internal
#' @noRd
apply_spc_theme <- function(plot, base_size = 14, plot_margin = NULL) {
  # Use BFHtheme's theme_bfh as base
  plot <- plot +
    BFHtheme::theme_bfh(base_size = base_size) +
    lemon::coord_capped_cart(bottom = "right", gap = 0)

  # Apply margins: use custom if provided, otherwise default 5mm
  if (!is.null(plot_margin)) {
    if (inherits(plot_margin, "margin")) {
      # User provided a margin object - use directly
      plot <- plot + ggplot2::theme(plot.margin = plot_margin)
    } else if (is.numeric(plot_margin) && length(plot_margin) == 4) {
      # User provided numeric vector - convert to margin with mm unit
      plot <- plot + ggplot2::theme(
        plot.margin = ggplot2::margin(
          t = plot_margin[1],
          r = plot_margin[2],
          b = plot_margin[3],
          l = plot_margin[4],
          unit = "mm"
        )
      )
    }
  } else {
    # Default: 5mm margins for visual balance
    plot <- plot + ggplot2::theme(
      plot.margin = ggplot2::margin(5, 5, 5, 5, "mm")
    )
  }


  return(plot)
}

