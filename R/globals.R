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

# Reference base_size for label sizing calculations
# Used to scale labels responsively based on viewport
REFERENCE_BASE_SIZE <- 14

# Default label size multiplier at reference base_size
# Produces optimal label sizing across different viewport sizes
DEFAULT_LABEL_SIZE_MULTIPLIER <- 6

# ============================================================================
# PDF EXPORT DIMENSIONS
# ============================================================================

# PNG image dimensions for ggsave (what gets embedded in Typst)
# These are the original dimensions that work with the Typst template
# Height reduced from 140mm to 115mm to allow space for footer_content
PDF_IMAGE_WIDTH_MM <- 250
PDF_IMAGE_HEIGHT_MM <- 115

# Target dimensions for label placement calculation (in mm)
# These represent the actual visible chart area in the Typst template
# Based on bfh-diagram layout:
# - A4 landscape: 297x210mm
# - Page margins: 4.67mm each side
# - SPC table column: 62mm
# - Chart area insets: left 18.67mm, right 4.67mm
# Labels should be positioned for how they appear in final PDF
PDF_CHART_WIDTH_MM <- 202
PDF_CHART_HEIGHT_MM <- 115

# Fixed label size for PDF export
# This ensures consistent, readable labels regardless of how the chart was created
# Value of 6 is calibrated for the PDF template dimensions
PDF_LABEL_SIZE <- 6
