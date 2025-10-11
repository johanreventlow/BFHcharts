#' Hospital Branding and Themes
#'
#' Configurable theming system for SPC charts with multi-organizational support.
#' Default branding is BFH (Bispebjerg og Frederiksberg Hospital), but can be
#' customized for any healthcare organization.
#'
#' @name themes
NULL

# ============================================================================
# COLOR PALETTES
# ============================================================================

#' BFH Hospital Color Palette
#'
#' Official color palette for Bispebjerg og Frederiksberg Hospital.
#' This is the default palette used by [bfh_theme()].
#'
#' @format Named list of hex color codes
#' @export
#' @examples
#' # Use BFH colors in your own plots
#' library(ggplot2)
#' ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point(color = BFH_COLORS$primary) +
#'   bfh_theme()
BFH_COLORS <- list(
  primary = "#009ce8",        # Hospital blue
  secondary = "#6c757d",      # Medium grey
  accent = "#FF6B35",         # Accent orange
  success = "#00891a",        # Success green
  warning = "#f9b928",        # Warning yellow
  danger = "#c10000",         # Danger red
  info = "#009ce8",           # Info blue
  light = "#f8f8f8",          # Light grey background
  dark = "#202020",           # Dark text
  darkgrey = "#565656",       # Dark grey
  lightgrey = "#AEAEAE",      # Light grey
  mediumgrey = "#858585",     # Medium grey
  regionh_blue = "#00293d"    # Region H official blue
)

#' Create Custom Color Palette
#'
#' Helper function to create a custom hospital color palette with validation.
#'
#' @param primary Primary brand color (hex code)
#' @param secondary Secondary color (hex code)
#' @param accent Accent color for highlights (hex code)
#' @param ... Additional color definitions
#'
#' @return Named list of colors compatible with `bfh_theme()`
#'
#' @export
#' @examples
#' # Create custom palette for another hospital
#' my_colors <- create_color_palette(
#'   primary = "#003366",
#'   secondary = "#808080",
#'   accent = "#FF9900"
#' )
#'
#' # Use with custom theme
#' plot + bfh_theme(colors = my_colors)
create_color_palette <- function(primary, secondary, accent, ...) {
  # Validate hex codes
  validate_hex <- function(color, name) {
    if (!grepl("^#[0-9A-Fa-f]{6}$", color)) {
      stop(sprintf(
        "%s must be a valid hex color code (e.g., '#009ce8'), got: %s",
        name, color
      ))
    }
  }

  validate_hex(primary, "primary")
  validate_hex(secondary, "secondary")
  validate_hex(accent, "accent")

  # Build palette with defaults from BFH
  palette <- list(
    primary = primary,
    secondary = secondary,
    accent = accent,
    ...
  )

  # Fill in missing colors from BFH defaults
  for (color_name in names(BFH_COLORS)) {
    if (!color_name %in% names(palette)) {
      palette[[color_name]] <- BFH_COLORS[[color_name]]
    }
  }

  return(palette)
}

# ============================================================================
# THEME FUNCTIONS
# ============================================================================

#' BFH Hospital Theme for ggplot2
#'
#' Apply BFH hospital branding to SPC charts (or any ggplot2 plot).
#' Inspired by BBC's bbplot design philosophy: beautiful defaults with
#' flexible customization.
#'
#' @param base_size Base font size for responsive scaling (default: 14)
#' @param base_family Font family (default: "Roboto Medium")
#' @param colors Color palette (default: [BFH_COLORS])
#'
#' @return A ggplot2 theme object
#'
#' @details
#' The theme applies:
#' - Minimal background with subtle grid lines
#' - Responsive typography based on `base_size`
#' - Hospital brand colors
#' - Publication-ready styling
#'
#' @export
#' @examples
#' library(ggplot2)
#'
#' # Basic usage
#' ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point() +
#'   bfh_theme()
#'
#' # Larger text for presentations
#' ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point() +
#'   bfh_theme(base_size = 18)
#'
#' # Custom hospital colors
#' my_colors <- create_color_palette(
#'   primary = "#003366",
#'   secondary = "#808080",
#'   accent = "#FF9900"
#' )
#' ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point(color = my_colors$primary) +
#'   bfh_theme(colors = my_colors)
bfh_theme <- function(base_size = 14,
                      base_family = "Roboto Medium",
                      colors = BFH_COLORS) {
  # Fallback if Roboto not available
  if (!base_family %in% systemfonts::system_fonts()$family) {
    warning(sprintf(
      "Font '%s' not found. Falling back to sans. Install Roboto for best results.",
      base_family
    ))
    base_family <- "sans"
  }

  ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      # Text elements with brand colors
      text = ggplot2::element_text(family = base_family, color = colors$dark),
      plot.title = ggplot2::element_text(
        size = ggplot2::rel(1.2),
        face = "bold",
        color = colors$primary
      ),
      plot.subtitle = ggplot2::element_text(
        size = ggplot2::rel(1.0),
        color = colors$secondary
      ),

      # Axes
      axis.title = ggplot2::element_text(size = ggplot2::rel(0.9), color = colors$dark),
      axis.text = ggplot2::element_text(size = ggplot2::rel(0.85), color = colors$mediumgrey),
      axis.text.y = ggplot2::element_text(hjust = 1),
      axis.line.x = ggplot2::element_line(color = colors$lightgrey),
      axis.ticks = ggplot2::element_line(color = colors$lightgrey),

      # Panel
      panel.background = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),

      # Legend
      legend.position = "none",  # SPC charts typically don't need legends
      legend.title = ggplot2::element_text(size = ggplot2::rel(0.9)),
      legend.text = ggplot2::element_text(size = ggplot2::rel(0.85)),

      # Margins
      plot.margin = ggplot2::unit(c(0, 0, 0, 10), "pt")
    )
}

#' Apply SPC-Specific Theme Styling
#'
#' Internal function that applies BFH theme with SPC-specific adjustments.
#' This is used by [bfh_spc_plot()] to ensure consistent SPC chart styling.
#'
#' @param plot ggplot2 object
#' @param base_size Base font size
#' @param colors Color palette
#'
#' @return Modified ggplot2 object with theme applied
#'
#' @keywords internal
#' @noRd
apply_spc_theme <- function(plot, base_size = 14, colors = BFH_COLORS) {
  plot + bfh_theme(base_size = base_size, colors = colors) +
    lemon::coord_capped_cart(bottom = "right", gap = 0)
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

# ============================================================================
# THEME PRESETS
# ============================================================================

#' Alternative Theme Presets
#'
#' Pre-configured theme variations for different use cases.
#'
#' @name theme_presets
#' @keywords internal
NULL

#' Presentation Theme (Larger Text)
#'
#' @param colors Color palette
#' @export
bfh_theme_presentation <- function(colors = BFH_COLORS) {
  bfh_theme(base_size = 18, colors = colors)
}

#' Print Theme (Optimized for Paper)
#'
#' @param colors Color palette
#' @export
bfh_theme_print <- function(colors = BFH_COLORS) {
  bfh_theme(base_size = 12, colors = colors) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", color = NA),
      panel.background = ggplot2::element_rect(fill = "white", color = NA)
    )
}
