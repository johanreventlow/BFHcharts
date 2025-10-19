#' SPC Theme Utilities
#'
#' Theme-related utilities specific to SPC charts. General theming is handled
#' by the BFHtheme package.
#'
#' @name spc_themes
#' @seealso [BFHtheme::theme_bfh()] for general BFH theming
NULL

# ============================================================================
# SPC-SPECIFIC THEME APPLICATION
# ============================================================================

#' Apply SPC-Specific Theme Styling
#'
#' Internal function that applies BFH theme with SPC-specific adjustments.
#' This is used by [bfh_spc_plot()] to ensure consistent SPC chart styling.
#'
#' Uses BFHtheme::theme_bfh() as base and adds SPC-specific modifications:
#' - Capped coordinate system (via lemon::coord_capped_cart)
#' - SPC-appropriate margins and spacing
#' - Custom plot margins if specified
#'
#' @param plot ggplot2 object
#' @param base_size Base font size
#' @param plot_margin Numeric vector of length 4 (top, right, bottom, left) in mm,
#'   or a margin object from ggplot2::margin(), or NULL for default
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

  # Apply custom margins if provided
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
  }

  return(plot)
}

# ============================================================================
# PLOT FOOTERS
# ============================================================================

#' Create Plot Footer with Hospital Branding
#'
#' Generate a formatted footer for SPC charts with hospital name,
#' data source, and generation date.
#'
#' @param hospital_name Hospital or organization name (default: "BFH")
#' @param department Department name (optional)
#' @param data_source Data source description (optional)
#' @param date Date to display (default: today)
#'
#' @return Character string with formatted footer
#'
#' @family spc-themes
#' @seealso [bfh_spc_plot()], [BFHtheme::theme_bfh()]
#' @export
#' @examples
#' create_plot_footer(
#'   hospital_name = "Bispebjerg og Frederiksberg Hospital",
#'   department = "Akutafdelingen",
#'   data_source = "EPJ data",
#'   date = Sys.Date()
#' )
create_plot_footer <- function(hospital_name = "BFH",
                               department = NULL,
                               data_source = NULL,
                               date = Sys.Date()) {
  parts <- c(hospital_name)

  if (!is.null(department) && nchar(trimws(department)) > 0) {
    parts <- c(parts, paste("-", department))
  }

  if (!is.null(data_source) && nchar(trimws(data_source)) > 0) {
    parts <- c(parts, paste("| Datakilde:", data_source))
  }

  parts <- c(
    parts,
    paste("| Genereret:", format(date, "%d-%m-%Y")),
    "| SPC analyse med Anhøj-regler"
  )

  paste(parts, collapse = " ")
}
