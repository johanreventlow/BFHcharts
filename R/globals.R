#' @importFrom rlang .data
NULL

# Global variables for NSE in ggplot2/dplyr
# Suppresses R CMD check NOTEs about "no visible binding"

utils::globalVariables(c(
  # ggplot2 aesthetics
  "x", "y", "lcl", "ucl", "target", "cl",
  "label", "color", "vjust",

  # dplyr/qicharts2 columns
  "part", "anhoej.signal",
  "n.crossings", "n.crossings.min",
  "part_n_cross", "part_n_cross_min",

  # From stats/utils
  "median", "var", "head", "tail"
))

# ============================================================================
# SIZING CONSTANTS
# ============================================================================

# ============================================================================
# LABEL SIZING CONSTANTS
# ============================================================================

# Line extension factor - hvor langt CL/target forlaenges forbi sidste datapunkt
LINE_EXTENSION_FACTOR <- 0.20

# Default y-axis expansion for chart scales - holdes lav for at minimere
# tom whitespace. Boundary labels kan stadig udvide skalaen dynamisk.
Y_AXIS_BASE_EXPANSION_MULT <- 0.05

# Y-axis expansion multiplier - matcher ggplot2 expansion(mult = ...)
Y_AXIS_EXPANSION_MULT <- 0.25

# Arrow endpoint padding - afstand fra datapunkt i normaliserede koordinater
ARROW_PADDING_NORM <- 0.03

# ============================================================================
# PDF EXPORT DIMENSIONS
# ============================================================================

# PNG image dimensions for ggsave (what gets embedded in Typst)
# These dimensions should match the available chart area in the Typst template
# Based on 6.6mm grid layout:
# - A4 landscape: 297x210mm
# - Page margins: bottom 6.6mm, rest 0mm
# - Chart area inset left: 26.4mm (4x grid)
# - Chart area inset right: 6.6mm (1x grid)
# - SPC column width: 72.6mm (11x grid)
# Image width: 297 - 26.4 - 6.6 - 72.6 = 191.4mm
# Image height: 210 - 6.6 (bottom margin) - 52.8 - 26.4 - 2 (top inset) - 13.2 (bottom space) = 109mm
PDF_IMAGE_WIDTH_MM <- 191.4
PDF_IMAGE_HEIGHT_MM <- 109

# NOTE: Chart width/height matcher image dimensions i den nuvaerende Typst-layout.
# Vi beholder separate konstanter for semantisk tydelighed:
# - PDF_IMAGE_* bruges ved eksport-rendering (ggsave output)
# - PDF_CHART_* bruges ved label-placement beregninger
# Hvis template-layout divergerer i fremtiden, kan de aendres uafhaengigt.

# Target dimensions for label placement calculation (in mm)
# These represent the actual visible chart area in the Typst template
# Based on bfh-diagram 6.6mm grid layout:
# - A4 landscape: 297x210mm
# - Page margins: bottom 6.6mm, rest 0mm
# - Header row: 59.4mm (9x grid)
# - Analysis row: 26.4mm (4x grid)
# - Chart area insets: left 26.4mm, right 6.6mm, top 6.6mm
# - SPC table column: 72.6mm (11x grid)
# Chart width: 297 - 26.4 - 6.6 - 72.6 = 191.4mm
# Chart height: 210 - 6.6 (bottom margin) - 52.8 - 26.4 - 2 (top inset) - 13.2 (bottom space) = 109mm
# Labels should be positioned for how they appear in final PDF
PDF_CHART_WIDTH_MM <- 191.4
PDF_CHART_HEIGHT_MM <- 109

# Fixed label size for PDF export
# This ensures consistent, readable labels regardless of how the chart was created
# Value of 6 is calibrated for the PDF template dimensions
PDF_LABEL_SIZE <- 6
